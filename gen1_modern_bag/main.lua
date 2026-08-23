-- Gen1ModernBag for Gen1Recomp
-- Splits the vanilla BagMenu into pockets while delegating every item action
-- to the original menu, preserving engine and inter-mod item behavior.

local PATCH_KEY = "__gen1_modern_bag_dispatch_v1"
local BAG_PATCH_KEY = "__gen1_modern_bag_unlimited_inventory_v1"
local INPUT_PATCH_KEY = "__gen1_modern_bag_move_info_input_v1"
local INFO_ACTION = "gen1_modern_bag_move_info"
local SEARCH_QUERY_LIMIT = 12

local QUICK_SEARCH_SCREEN_ID = "ModernBagNicknameSearch"
local MOVE_INFO_SCREEN_ID = "ModernBagMoveInfo"
local MACHINE_NAME_SEARCH_SCREEN_ID = "ModernBagNicknameMachineSearch"

local POCKETS = {
  { id = "favorites", label = "FAVORITES", virtual = true },
  { id = "medicine", label = "MEDICINE" },
  { id = "balls", label = "BALLS" },
  { id = "machines", label = "TM HM" },
  { id = "battle", label = "BATTLE" },
  { id = "key", label = "KEY ITEMS" },
  { id = "other", label = "OTHER" },
}

local OPENING_POCKET_VALUES = {
  favorites = true, medicine = true, balls = true, machines = true,
  battle = true, key = true, other = true, last = true,
}

local SCROLL_SPEEDS = {
  off = { enabled = false, delay = 16, rate = 4 },
  normal = { enabled = true, delay = 16, rate = 4 },
  fast = { enabled = true, delay = 10, rate = 2 },
  very_fast = { enabled = true, delay = 6, rate = 1 },
}

local function optionValue(mod, key, default)
  if mod and mod.options and type(mod.options.get) == "function" then
    local ok, value = pcall(mod.options.get, mod.options, key)
    if ok and value ~= nil then return value end
  end
  return default
end

local function pocketIndexById(id)
  for i, pocket in ipairs(POCKETS) do
    if pocket.id == id then return i end
  end
  return 2
end

local function openingPocketIndex(mod)
  local wanted = tostring(optionValue(mod, "opening_pocket", "medicine") or "medicine")
  if not OPENING_POCKET_VALUES[wanted] then wanted = "medicine" end
  if wanted == "last" then
    local saved = mod and mod.save and mod.save:get("last_pocket", "medicine") or "medicine"
    if not OPENING_POCKET_VALUES[saved] or saved == "last" then saved = "medicine" end
    wanted = saved
  end
  return pocketIndexById(wanted)
end

local function scrollConfig(mod)
  local speed = tostring(optionValue(mod, "hold_scroll_speed", "fast") or "fast")
  return SCROLL_SPEEDS[speed] or SCROLL_SPEEDS.fast
end

-- Pocket header.
--
-- The Bag is a ListMenu the engine opens with itemBox = true, and that path
-- draws the LIST_MENU_BOX, its rows, the quantities and the cursor -- and
-- nothing else. `self.title` is only ever drawn by ListMenu:draw's plain
-- full-screen branch (src/ui/ListMenu.lua), which the Bag returns before
-- reaching, so a title assigned to the Bag list never reaches the screen.
-- The name has to be drawn here; refreshPocket still keeps list.title in
-- step for Gen1 Modern UI and anything else that reads it.
--
-- LIST_MENU_BOX is tiles 4,2 - 19,12: its interior starts at y = 24 and the
-- first item name is drawn at y = 32, so the row at y = 24 is empty and sits
-- inside the box's own white fill. The interior spans x = 40 to x = 152 --
-- fourteen 8px columns -- and the arrows take the first and the last.
local HEADER_Y = 24
local HEADER_LEFT_X = 40
local HEADER_RIGHT_X = 144
local HEADER_NAME_X = 48
local HEADER_NAME_WIDTH = HEADER_RIGHT_X - HEADER_NAME_X

-- Angle brackets are not glyphs. Gen 1 text encodes control tokens as
-- <PK>, <PLAYER>, <LINE> and the like, and charmap.asm has no '<' or '>' of
-- its own, so "<  MEDICINE  >" cannot be drawn as text at all.
--
-- There is no left-pointing arrow either: the arrow glyphs stop at
-- ▷ $EC, ▶ $ED and ▼ $EE. The Left arrow is therefore the cursor glyph
-- mirrored about its own cell, which is the shape a left arrow would have.
local function drawMirroredCode(Font, code, x, y)
  love.graphics.push()
  love.graphics.translate(x + 8, 0)
  love.graphics.scale(-1, 1)
  Font.drawCode(code, 0, y)
  love.graphics.pop()
end

-- Trim to a pixel budget rather than a character count: a font mod can ship
-- variable-width glyphs, and Font.width is what measures them.
local function fitLabel(Font, label, budget)
  while #label > 0 and Font.width(label) > budget do
    label = label:sub(1, #label - 1)
  end
  return label
end

local function drawPocketHeader(list)
  local state = list.modernBag
  local pocket = state and POCKETS[state.pocket]
  if not pocket then return end
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")
  local label = fitLabel(Font, pocket.label, HEADER_NAME_WIDTH)

  -- drawItemBox leaves the colour white; text in this box is black.
  love.graphics.setColor(0, 0, 0, 1)
  -- Centre on the 8px column grid the rest of the box sits on.
  local slack = math.max(0, HEADER_NAME_WIDTH - Font.width(label))
  Font.draw(label, HEADER_NAME_X + math.floor(slack / 16) * 8, HEADER_Y)
  drawMirroredCode(Font, Theme.cursor, HEADER_LEFT_X, HEADER_Y)
  Font.drawCode(Theme.cursor, HEADER_RIGHT_X, HEADER_Y)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Pocket footer.
--
-- Same story as the header: ListMenu:draw paints a footer in its plain
-- full-screen branch, below the `return self:drawItemBox()` the Bag takes, so
-- the control hints and the money line were never on screen either.
--
-- They go in the standard bottom text box, TEXT_BOX at tiles 0,12 - 19,17.
-- Its top row is the row LIST_MENU_BOX ends on, which is how the two stack in
-- vanilla when a message opens under the list. The interior is four 8px rows
-- from y = 104, and text starts at x = 8, leaving the eighteen columns
-- Theme.textBox.maxCols budgets for.
local FOOTER_BOX = { tx = 0, ty = 12, tw = 20, th = 6 }
local FOOTER_X = 8
local FOOTER_TOP_Y = 104
local FOOTER_ROWS = 4

-- The engine's own wrapper, so a font mod's wider glyphs fold the same way
-- here as they do in every other box.
local function footerLines(text)
  local TextBox = require("src.render.TextBox")
  local lines = {}
  for _, page in ipairs(TextBox.paginate(text)) do
    for _, line in ipairs(page) do lines[#lines + 1] = line end
  end
  return lines
end

local function drawBagFooter(list)
  local text = list.footer
  if type(text) ~= "string" or text == "" then return end
  local lines = footerLines(text)
  local shown = math.min(#lines, FOOTER_ROWS)
  if shown == 0 then return end

  local Font = require("src.render.Font")
  love.graphics.setColor(1, 1, 1, 1)
  Font.drawBox(FOOTER_BOX.tx, FOOTER_BOX.ty, FOOTER_BOX.tw, FOOTER_BOX.th)
  love.graphics.setColor(0, 0, 0, 1)
  -- Centre the block in the interior: two lines sit on the middle two rows.
  local y = FOOTER_TOP_Y + math.floor((FOOTER_ROWS - shown) / 2) * 8
  for i = 1, shown do
    Font.draw(lines[i], FOOTER_X, y)
    y = y + 8
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function rememberPocket(state)
  if not state or not state.mod or not state.mod.save then return end
  local pocket = POCKETS[state.pocket]
  if pocket then state.mod.save:set("last_pocket", pocket.id) end
end

local MEDICINE = {
  POTION = true, SUPER_POTION = true, HYPER_POTION = true,
  MAX_POTION = true, FULL_RESTORE = true,
  ANTIDOTE = true, BURN_HEAL = true, ICE_HEAL = true,
  AWAKENING = true, PARLYZ_HEAL = true, FULL_HEAL = true,
  REVIVE = true, MAX_REVIVE = true,
  FRESH_WATER = true, SODA_POP = true, LEMONADE = true,
  ETHER = true, MAX_ETHER = true, ELIXER = true, MAX_ELIXER = true,
  HP_UP = true, PROTEIN = true, IRON = true, CARBOS = true,
  CALCIUM = true, RARE_CANDY = true, PP_UP = true,
}

local BATTLE_ITEMS = {
  X_ATTACK = true, X_DEFEND = true, X_SPEED = true, X_SPECIAL = true,
  X_ACCURACY = true, DIRE_HIT = true, GUARD_SPEC = true,
  POKE_DOLL = true,
}

local BALL_IDS = {
  MASTER_BALL = true, ULTRA_BALL = true, GREAT_BALL = true,
  POKE_BALL = true, SAFARI_BALL = true,
}

local STONES = {
  FIRE_STONE = true, WATER_STONE = true, THUNDER_STONE = true,
  LEAF_STONE = true, MOON_STONE = true,
}

local function upper(value)
  return tostring(value or ""):upper()
end

local function pocketFor(id, def)
  def = def or {}
  if def.machine then return "machines" end
  if def.ball or BALL_IDS[id] then return "balls" end
  if BATTLE_ITEMS[id] then return "battle" end
  if MEDICINE[id] then return "medicine" end

  -- Friendly inference for modded records. Explicit engine fields win; the
  -- name/effect fallback only catches conventional custom medicines.
  local effect = upper(def.effect)
  if not STONES[id] and (
       effect:find("HEAL", 1, true)
    or effect:find("REVIVE", 1, true)
    or effect:find("MEDIC", 1, true)
    or effect:find("VITAMIN", 1, true)
    or effect:find("ETHER", 1, true)
    or effect:find("ELIX", 1, true)
    or effect:find("CANDY", 1, true)
    or effect:find("PP_UP", 1, true)) then
    return "medicine"
  end

  if def.keyItem or def.tossable == false then return "key" end
  return "other"
end

local function countOf(save, id)
  local value = save and save.inventory and save.inventory[id]
  value = math.floor(tonumber(value) or 0)
  return math.max(0, value)
end

local function positionOf(order, id)
  for i, value in ipairs(order or {}) do
    if value == id then return i end
  end
  return nil
end

local function cleanSavedOrder(value)
  local out, seen = {}, {}
  if type(value) ~= "table" then return out end
  for _, id in ipairs(value) do
    if type(id) == "string" and id ~= "" and not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  return out
end

local function orderIndex(order)
  local out = {}
  for i, id in ipairs(order or {}) do out[id] = i end
  return out
end

local MACHINE_SORT_VALUES = {
  NUMBER = true, NAME = true, POWER_DESC = true, POWER_ASC = true,
}

local function loadPreferenceState(mod)
  local favorites = cleanSavedOrder(mod.save:get("favorite_items", {}))
  local pinned = cleanSavedOrder(mod.save:get("pinned_items", {}))
  local machineSort = upper(mod.save:get("machine_sort", "NUMBER"))
  if not MACHINE_SORT_VALUES[machineSort] then machineSort = "NUMBER" end
  return {
    mod = mod,
    favoriteOrder = favorites,
    favoriteSet = orderIndex(favorites),
    pinnedOrder = pinned,
    pinnedSet = orderIndex(pinned),
    machineSort = machineSort,
  }
end

local function persistPreferences(state)
  if not state or not state.mod then return end
  state.mod.save:set("favorite_items", cleanSavedOrder(state.favoriteOrder))
  state.mod.save:set("pinned_items", cleanSavedOrder(state.pinnedOrder))
end

local function rebuildPreferenceIndexes(state)
  state.favoriteOrder = cleanSavedOrder(state.favoriteOrder)
  state.pinnedOrder = cleanSavedOrder(state.pinnedOrder)
  state.favoriteSet = orderIndex(state.favoriteOrder)
  state.pinnedSet = orderIndex(state.pinnedOrder)
end

local function toggleOrderedItem(order, id)
  local index = positionOf(order, id)
  if index then
    table.remove(order, index)
    return false
  end
  order[#order + 1] = id
  return true
end

local function pocketIndexFor(id, def)
  local wanted = pocketFor(id, def)
  for i, pocket in ipairs(POCKETS) do
    if pocket.id == wanted then return i end
  end
  return #POCKETS
end

local function normalizedSearch(value)
  local text = upper(value)
  text = text:gsub("é", "E"):gsub("É", "E")
  return text:gsub("[^A-Z0-9]", "")
end


-- Generation I determines physical/special damage from the move type.
-- Non-damaging moves are exposed as STATUS so filters never hide them in an
-- arbitrary damage class.
local PHYSICAL_TYPES = {
  NORMAL = true, FIGHTING = true, FLYING = true, POISON = true,
  GROUND = true, ROCK = true, BUG = true, GHOST = true,
}

local function moveDamageClass(move)
  move = move or {}
  local power = math.floor(tonumber(move.power) or 0)
  if power <= 0 then return "STATUS" end
  return PHYSICAL_TYPES[upper(move.type)] and "PHYSICAL" or "SPECIAL"
end

local function displayType(game, typeId)
  local types = game and game.data and game.data.types
  local def = types and types[typeId]
  return upper((def and def.name) or typeId or "UNKNOWN")
end

local function machineCode(id, def)
  local machine = def and def.machine or {}
  local kind = upper(machine.kind)
  if kind ~= "TM" and kind ~= "HM" then kind = upper(tostring(id):match("^(%a%a)")) end
  local number = tonumber(machine.number)
  if not number then number = tonumber(tostring(def and def.name or id):match("(%d+)")) end
  if not number then number = tonumber(tostring(id):match("(%d+)$")) end
  number = number or 999
  return kind .. (number < 100 and ("%02d"):format(number) or tostring(number)), kind, number
end

local function readableEffect(effect)
  local label = upper(effect or "NO ADDITIONAL EFFECT")
  label = label:gsub("_EFFECT$", ""):gsub("_", " ")
  return label
end

local function machineInfo(game, id, def)
  def = def or (game and game.data and game.data.items and game.data.items[id]) or {}
  if not def.machine then return nil end
  local moveId = def.machine.move
  local move = game and game.data and game.data.moves and game.data.moves[moveId] or {}
  local code, kind, number = machineCode(id, def)
  local moveName = (move and move.name) or moveId or id
  local typeId = move and move.type or "UNKNOWN"
  local power = math.floor(tonumber(move and move.power) or 0)
  local accuracy = tonumber(move and move.accuracy)
  local pp = math.floor(tonumber(move and move.pp) or 0)
  local damageClass = moveDamageClass(move)
  local nameKey = normalizedSearch(moveName)
  local kindRank = kind == "HM" and 0 or 1
  return {
    id = id,
    item = def,
    move = move,
    moveId = moveId,
    code = code,
    kind = kind,
    number = number,
    numberKey = kindRank * 1000 + number,
    name = moveName,
    nameKey = nameKey,
    type = typeId,
    typeLabel = displayType(game, typeId),
    damageClass = damageClass,
    power = power,
    accuracy = accuracy,
    pp = pp,
    effect = readableEffect(move and move.effect),
    searchKey = normalizedSearch(code .. " " .. moveName .. " " .. tostring(moveId or "") .. " " .. tostring(id)),
  }
end

-- Drawable width of a machine row. The 20-tile item window also spends
-- columns on the selection cursor and the window border, so the usable run
-- is ~13 glyphs, not 15. The marker variant reserves room for "P"/"F"/"PF".
-- Lower these if your display still clips.
local MACHINE_LABEL_WIDTH = 13
local MACHINE_LABEL_WIDTH_MARKED = 9

local function compactMachineLabel(info, markers)
  local maxChars = markers ~= "" and MACHINE_LABEL_WIDTH_MARKED
    or MACHINE_LABEL_WIDTH
  local label = info.code .. " " .. info.name
  if #label > maxChars then label = label:sub(1, maxChars - 1) .. "." end
  return label
end

local function machineSortLess(a, b, mode)
  local ma, mb = a.modernMachine, b.modernMachine
  if not ma or not mb then return tostring(a.value) < tostring(b.value) end
  if mode == "NAME" then
    if ma.nameKey ~= mb.nameKey then return ma.nameKey < mb.nameKey end
  elseif mode == "POWER_DESC" then
    if ma.power ~= mb.power then return ma.power > mb.power end
    if ma.nameKey ~= mb.nameKey then return ma.nameKey < mb.nameKey end
  elseif mode == "POWER_ASC" then
    if ma.power ~= mb.power then return ma.power < mb.power end
    if ma.nameKey ~= mb.nameKey then return ma.nameKey < mb.nameKey end
  else
    if ma.numberKey ~= mb.numberKey then return ma.numberKey < mb.numberKey end
  end
  return ma.numberKey < mb.numberKey
end

local function setMachineSort(state, mode)
  mode = upper(mode)
  if not MACHINE_SORT_VALUES[mode] then mode = "NUMBER" end
  state.machineSort = mode
  if state.mod then state.mod.save:set("machine_sort", mode) end
end

local function inventorySignature(game)
  local Bag = require("src.inventory.Bag")
  local ids = {}
  for id, count in pairs(game.save.inventory or {}) do
    local amount = math.floor(tonumber(count) or 0)
    local badge = type(Bag.isBadge) == "function"
                  and Bag.isBadge(id)
                  or tostring(id):find("BADGE", 1, true) ~= nil
    if amount > 0 and not badge then ids[#ids + 1] = tostring(id) end
  end
  table.sort(ids)
  return table.concat(ids, "\0")
end

local function automaticSortKey(id, def)
  def = def or {}
  local label = normalizedSearch(def.name or id)
  if def.machine then
    local kind = upper(def.machine.kind)
    local kindRank = kind == "HM" and "0" or "1"
    local number = tonumber(tostring(id):match("(%d+)$")) or 999
    return kindRank .. ("%03d"):format(number) .. label
  end
  return label .. "\0" .. tostring(id)
end

local function autoSortBag(game, preferences)
  local Bag = require("src.inventory.Bag")
  local order = Bag.order(game.save)
  local sortable = {}
  local pinned = preferences and preferences.pinnedSet or {}
  for originalIndex, id in ipairs(order) do
    if countOf(game.save, id) > 0 then
      local def = game.data.items[id]
      sortable[#sortable + 1] = {
        id = id,
        pocket = pocketIndexFor(id, def),
        pin = pinned[id],
        key = automaticSortKey(id, def),
        original = originalIndex,
      }
    end
  end
  table.sort(sortable, function(a, b)
    if a.pocket ~= b.pocket then return a.pocket < b.pocket end
    if (a.pin ~= nil) ~= (b.pin ~= nil) then return a.pin ~= nil end
    if a.pin and b.pin and a.pin ~= b.pin then return a.pin < b.pin end
    if a.key ~= b.key then return a.key < b.key end
    return a.original < b.original
  end)
  local changed = #sortable ~= #order
  for i, row in ipairs(sortable) do
    if order[i] ~= row.id then changed = true end
    order[i] = row.id
  end
  for i = #order, #sortable + 1, -1 do order[i] = nil end
  return changed
end

local function itemRows(game, pocketId, state)
  local Bag = require("src.inventory.Bag")
  local order = Bag.order(game.save)
  local rows = {}
  local favoriteSet = state and state.favoriteSet or {}
  local pinnedSet = state and state.pinnedSet or {}
  for globalIndex, id in ipairs(order) do
    local count = countOf(game.save, id)
    if count > 0 then
      local def = game.data.items[id]
      local actualPocket = pocketFor(id, def)
      local included = pocketId == "favorites"
        and favoriteSet[id] ~= nil
        or actualPocket == pocketId
      if included then
        local favorite = favoriteSet[id] ~= nil
        local pinned = pinnedSet[id] ~= nil
        local markers = (pinned and "P" or "") .. (favorite and "F" or "")
        local info = actualPocket == "machines" and machineInfo(game, id, def) or nil
        local label = (def and def.name) or id
        if pocketId == "machines" and info then
          label = compactMachineLabel(info, markers)
        end
        rows[#rows + 1] = {
          label = label,
          right = (markers ~= "" and (markers .. " ") or "") .. "x" .. tostring(count),
          value = id,
          modernGlobalIndex = globalIndex,
          modernPocket = pocketIndexFor(id, def),
          modernPinned = pinned,
          modernFavorite = favorite,
          modernPinRank = pinnedSet[id],
          modernFavoriteRank = favoriteSet[id],
          modernSourceIndex = globalIndex,
          modernMachine = info,
        }
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.modernPinned ~= b.modernPinned then return a.modernPinned end
    if a.modernPinned and b.modernPinned
       and a.modernPinRank ~= b.modernPinRank then
      return a.modernPinRank < b.modernPinRank
    end
    if pocketId == "favorites"
       and a.modernFavoriteRank ~= b.modernFavoriteRank then
      return a.modernFavoriteRank < b.modernFavoriteRank
    end
    if pocketId == "machines" then
      return machineSortLess(a, b, state and state.machineSort or "NUMBER")
    end
    return a.modernSourceIndex < b.modernSourceIndex
  end)
  return rows
end

local function selectedId(list)
  local item = list.items and list.items[list.index or 1]
  return item and item.value or nil
end

local function cursorBucket(state, pocketId)
  state.cursors[pocketId] = state.cursors[pocketId] or { index = 1, scroll = 0 }
  return state.cursors[pocketId]
end

local function saveCursor(list)
  local state = list.modernBag
  local pocket = POCKETS[state.pocket]
  if not pocket then return end
  local cursor = cursorBucket(state, pocket.id)
  cursor.index = list.index or 1
  cursor.scroll = list.scroll or 0
  cursor.selected = selectedId(list)
end

local function restoreCursor(list, rows, preserveId)
  local state = list.modernBag
  local pocket = POCKETS[state.pocket]
  local cursor = cursorBucket(state, pocket.id)
  local wanted = preserveId or cursor.selected
  local index
  if wanted then
    for i, row in ipairs(rows) do
      if row.value == wanted then index = i break end
    end
  end
  list.index = index or math.max(1, math.min(cursor.index or 1, #rows))
  if #rows == 0 then list.index = 1 end
  list.scroll = math.max(0, cursor.scroll or 0)
  local maxScroll = math.max(0, #rows - (list.rows or 7))
  if list.scroll > maxScroll then list.scroll = maxScroll end
  if list.index - list.scroll < 1 then list.scroll = list.index - 1 end
  if list.index - list.scroll > (list.rows or 7) then
    list.scroll = list.index - (list.rows or 7)
  end
end

local function refreshPocket(list, preserveId)
  local state = list.modernBag
  local pocket = POCKETS[state.pocket]
  local rows = itemRows(list.game, pocket.id, state)
  list.items = rows
  -- Not drawn by the engine for an item-box list (see the pocket header
  -- above), but Gen1 Modern UI and the compatibility contract read it.
  list.title = pocket.label
  if pocket.id == "machines" then
    local sortLabel = (state.machineSort or "NUMBER"):gsub("_", " ")
    state.startActionLabel = "FILTER"
    -- One hint per line: the box is eighteen columns, and "START FILTER" and
    -- "Y/I INFO" together are twenty-one.
    list.footer = "START FILTER\nY/I INFO\nSORT " .. sortLabel
  else
    state.startActionLabel = "SEARCH"
    -- "SEL TOOLS  ¥999999" is exactly eighteen, the widest this can get.
    list.footer = ("START SEARCH\nSEL TOOLS  ¥%d"):format(list.game.save.money or 0)
  end
  restoreCursor(list, rows, preserveId)

  if state.swapId then
    list.hollowIndex = nil
    for i, row in ipairs(rows) do
      if row.value == state.swapId then list.hollowIndex = i break end
    end
    if not list.hollowIndex then state.swapId = nil end
  else
    list.hollowIndex = nil
  end
end

local function switchPocket(list, delta)
  saveCursor(list)
  local state = list.modernBag
  state.swapId = nil
  list.hollowIndex = nil
  state.pocket = ((state.pocket - 1 + delta) % #POCKETS) + 1
  rememberPocket(state)
  refreshPocket(list)
end

local function searchRows(game, query, state)
  local Bag = require("src.inventory.Bag")
  local wanted = normalizedSearch(query)
  local rows = {}
  local favoriteSet = state and state.favoriteSet or {}
  local pinnedSet = state and state.pinnedSet or {}
  for _, id in ipairs(Bag.order(game.save)) do
    local count = countOf(game.save, id)
    if count > 0 then
      local def = game.data.items[id]
      local label = (def and def.name) or id
      local haystack = normalizedSearch(label .. " " .. id)
      if wanted == "" or haystack:find(wanted, 1, true) then
        local markers = (pinnedSet[id] and "P" or "")
          .. (favoriteSet[id] and "F" or "")
        rows[#rows + 1] = {
          label = label,
          right = (markers ~= "" and (markers .. " ") or "") .. "x" .. tostring(count),
          value = id,
          modernPocket = pocketIndexFor(id, def),
          modernSort = normalizedSearch(label) .. "\0" .. tostring(id),
        }
      end
    end
  end
  table.sort(rows, function(a, b) return a.modernSort < b.modernSort end)
  return rows
end

local SEARCH_GRID = {
  { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
  { "J", "K", "L", "M", "N", "O", "P", "Q", "R" },
  { "S", "T", "U", "V", "W", "X", "Y", "Z", "0" },
  { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
  { "DEL", "CLR", "GO", "EXIT" },
}

local QuickSearch = {}
QuickSearch.__index = QuickSearch
QuickSearch.isOpaque = true

local function syncSearchQuery(state)
  state.query = table.concat(state.glyphs or {})
  return state.query
end

function QuickSearch.new(game, bagList)
  return setmetatable({
    screenId = QUICK_SEARCH_SCREEN_ID,
    game = game,
    bagList = bagList,
    title = "QUICK SEARCH",
    query = "",
    glyphs = {},
    maxLen = SEARCH_QUERY_LIMIT,
    row = 1,
    col = 1,
    lower = false,
    modernBagSearchKeyboard = true,
    modernBagSearchActionLabel = "SEARCH",
    modernBagSearchHint = "A TYPE   B DELETE/EXIT   SELECT CLEAR   START SEARCH",
  }, QuickSearch)
end

function QuickSearch:grid()
  return SEARCH_GRID
end

function QuickSearch:close()
  if self.game.stack:top() == self then self.game.stack:pop() end
end

local function searchSound(game, name)
  pcall(function() require("src.core.Sound").play(game.data, name) end)
end

function QuickSearch:openResults()
  syncSearchQuery(self)
  local ListMenu = require("src.ui.ListMenu")
  local rows = searchRows(self.game, self.query, self.bagList.modernBag)
  local title = self.query == "" and "ALL ITEMS"
                or ("SEARCH " .. self.query)
  local search = self
  self.game.stack:push(ListMenu.new(self.game, title, rows, {
    onChoose = function(item, resultList)
      resultList:close()
      search:close()
      local bag = search.bagList
      if not bag or not bag.modernBag then return end
      saveCursor(bag)
      bag.modernBag.swapId = nil
      bag.hollowIndex = nil
      bag.modernBag.pocket = item.modernPocket or 1
      rememberPocket(bag.modernBag)
      refreshPocket(bag, item.value)
    end,
  }))
end

function QuickSearch:activateCurrentKey()
  local row = SEARCH_GRID[self.row]
  local key = row and row[self.col]
  if not key then return false end
  if key == "DEL" then
    table.remove(self.glyphs)
  elseif key == "CLR" then
    self.glyphs = {}
  elseif key == "GO" then
    self:openResults()
    return true
  elseif key == "EXIT" then
    self:close()
    return true
  elseif #self.glyphs < SEARCH_QUERY_LIMIT then
    self.glyphs[#self.glyphs + 1] = key
  end
  syncSearchQuery(self)
  return true
end

function QuickSearch:update(dt)
  local input = self.game.input
  local row = SEARCH_GRID[self.row]
  if input:wasPressed("left") then
    self.col = ((self.col - 2) % #row) + 1
  elseif input:wasPressed("right") then
    self.col = (self.col % #row) + 1
  elseif input:wasPressed("up") then
    self.row = ((self.row - 2) % #SEARCH_GRID) + 1
    self.col = math.min(self.col, #SEARCH_GRID[self.row])
  elseif input:wasPressed("down") then
    self.row = (self.row % #SEARCH_GRID) + 1
    self.col = math.min(self.col, #SEARCH_GRID[self.row])
  elseif input:wasPressed("select") then
    self.glyphs = {}
    syncSearchQuery(self)
    searchSound(self.game, "Swap")
  elseif input:wasPressed("start") then
    searchSound(self.game, "Press_AB")
    self:openResults()
  elseif input:wasPressed("b") then
    searchSound(self.game, "Press_AB")
    if #self.glyphs > 0 then
      table.remove(self.glyphs)
      syncSearchQuery(self)
    else
      self:close()
    end
  elseif input:wasPressed("a") then
    searchSound(self.game, "Press_AB")
    self:activateCurrentKey()
  end
end

function QuickSearch:draw()
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(self.title, 8, 2)
  Font.draw("FIND: " .. (self.query == "" and "ALL" or self.query), 8, 14)
  Font.draw("MATCHES: " .. tostring(#searchRows(self.game, self.query, self.bagList.modernBag)), 8, 26)
  for r, keys in ipairs(SEARCH_GRID) do
    for c, key in ipairs(keys) do
      local x = 16 + (c - 1) * 16
      local y = 38 + (r - 1) * 16
      if r == self.row and c == self.col then
        Font.drawCode(Theme.cursor, x - 8, y)
      end
      Font.draw(key, x, y)
    end
  end
  Font.draw("A TYPE  START/GO", 8, 122)
  Font.draw("B DEL/EXIT  SEL CLR", 8, 134)
  love.graphics.setColor(1, 1, 1, 1)
end

local function openQuickSearch(list)
  local state = list.modernBag
  state.swapId = nil
  list.hollowIndex = nil
  list.game.stack:push(QuickSearch.new(list.game, list))
end


local function wrapWords(text, width, maxLines)
  local lines, current = {}, ""
  for word in tostring(text or ""):gmatch("%S+") do
    local candidate = current == "" and word or (current .. " " .. word)
    if #candidate > width and current ~= "" then
      lines[#lines + 1] = current
      current = word
      if maxLines and #lines >= maxLines then break end
    else
      current = candidate
    end
  end
  if current ~= "" and (not maxLines or #lines < maxLines) then lines[#lines + 1] = current end
  if #lines == 0 then lines[1] = "--" end
  return lines
end

local MoveInfoScreen = {}
MoveInfoScreen.__index = MoveInfoScreen
MoveInfoScreen.isOpaque = true

function MoveInfoScreen.new(game, id)
  return setmetatable({
    screenId = MOVE_INFO_SCREEN_ID,
    game = game,
    id = id,
    info = machineInfo(game, id),
  }, MoveInfoScreen)
end

function MoveInfoScreen:update(dt)
  local input = self.game.input
  if input:wasPressed(INFO_ACTION) or input:wasPressed("b")
     or input:wasPressed("a") or input:wasPressed("start") then
    self.game.stack:pop()
  end
end

function MoveInfoScreen:draw()
  local Font = require("src.render.Font")
  local info = self.info
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw("MOVE INFORMATION", 8, 4)
  if not info then
    Font.draw("NO MOVE DATA", 8, 32)
    Font.draw("B BACK", 8, 132)
    return
  end
  Font.draw(info.code .. "  " .. info.name, 8, 18)
  Font.draw("TYPE: " .. info.typeLabel, 8, 34)
  Font.draw("CLASS: " .. info.damageClass, 8, 48)
  Font.draw("POWER: " .. (info.power > 0 and tostring(info.power) or "--"), 8, 62)
  Font.draw("ACCURACY: " .. (info.accuracy and (tostring(info.accuracy) .. "%") or "--"), 8, 76)
  Font.draw("PP: " .. tostring(info.pp), 8, 90)
  Font.draw("EFFECT:", 8, 104)
  local effectLines = wrapWords(info.effect, 18, 2)
  Font.draw(effectLines[1] or "--", 8, 116)
  if effectLines[2] then Font.draw(effectLines[2], 8, 128) end
  Font.draw("Y/I OR B: BACK", 48, 136)
  love.graphics.setColor(1, 1, 1, 1)
end

local function openMoveInfo(game, id)
  if not id then return end
  game.stack:push(MoveInfoScreen.new(game, id))
end

local MachineNameSearch = {}
MachineNameSearch.__index = MachineNameSearch
MachineNameSearch.isOpaque = true

function MachineNameSearch.new(game, initial, onDone)
  local glyphs = {}
  local seed = normalizedSearch(initial or "")
  for i = 1, math.min(#seed, SEARCH_QUERY_LIMIT) do
    glyphs[#glyphs + 1] = seed:sub(i, i)
  end
  return setmetatable({
    screenId = MACHINE_NAME_SEARCH_SCREEN_ID,
    game = game,
    title = "TM HM MOVE NAME",
    query = table.concat(glyphs),
    glyphs = glyphs,
    maxLen = SEARCH_QUERY_LIMIT,
    row = 1,
    col = 1,
    lower = false,
    onDone = onDone,
    modernBagSearchKeyboard = true,
    modernBagSearchActionLabel = "APPLY",
    modernBagSearchHint = "A TYPE   B DELETE/EXIT   SELECT CLEAR   START APPLY",
  }, MachineNameSearch)
end

function MachineNameSearch:grid()
  return SEARCH_GRID
end

function MachineNameSearch:finish()
  syncSearchQuery(self)
  self.game.stack:pop()
  if self.onDone then self.onDone(self.query) end
end

function MachineNameSearch:activateCurrentKey()
  local row = SEARCH_GRID[self.row]
  local key = row and row[self.col]
  if not key then return false end
  if key == "DEL" then
    table.remove(self.glyphs)
  elseif key == "CLR" then
    self.glyphs = {}
  elseif key == "GO" then
    self:finish()
    return true
  elseif key == "EXIT" then
    self.game.stack:pop()
    return true
  elseif #self.glyphs < SEARCH_QUERY_LIMIT then
    self.glyphs[#self.glyphs + 1] = key
  end
  syncSearchQuery(self)
  return true
end

function MachineNameSearch:update(dt)
  local input = self.game.input
  local row = SEARCH_GRID[self.row]
  if input:wasPressed("left") then
    self.col = ((self.col - 2) % #row) + 1
  elseif input:wasPressed("right") then
    self.col = (self.col % #row) + 1
  elseif input:wasPressed("up") then
    self.row = ((self.row - 2) % #SEARCH_GRID) + 1
    self.col = math.min(self.col, #SEARCH_GRID[self.row])
  elseif input:wasPressed("down") then
    self.row = (self.row % #SEARCH_GRID) + 1
    self.col = math.min(self.col, #SEARCH_GRID[self.row])
  elseif input:wasPressed("select") then
    self.glyphs = {}
    syncSearchQuery(self)
    searchSound(self.game, "Swap")
  elseif input:wasPressed("start") then
    searchSound(self.game, "Press_AB")
    self:finish()
  elseif input:wasPressed("b") then
    searchSound(self.game, "Press_AB")
    if #self.glyphs > 0 then
      table.remove(self.glyphs)
      syncSearchQuery(self)
    else
      self.game.stack:pop()
    end
  elseif input:wasPressed("a") then
    searchSound(self.game, "Press_AB")
    self:activateCurrentKey()
  end
end

function MachineNameSearch:draw()
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(self.title, 8, 2)
  Font.draw("FIND: " .. (self.query == "" and "ALL" or self.query), 8, 16)
  for r, keys in ipairs(SEARCH_GRID) do
    for c, key in ipairs(keys) do
      local x = 16 + (c - 1) * 16
      local y = 32 + (r - 1) * 16
      if r == self.row and c == self.col then Font.drawCode(Theme.cursor, x - 8, y) end
      Font.draw(key, x, y)
    end
  end
  Font.draw("START/GO APPLY", 8, 122)
  Font.draw("B DEL/EXIT  SEL CLR", 8, 134)
  love.graphics.setColor(1, 1, 1, 1)
end


local function machineFilters(state)
  if type(state.machineFilters) ~= "table" then
    state.machineFilters = { query = "", type = "ANY", damageClass = "ANY" }
  end
  return state.machineFilters
end

local function machineFilteredRows(game, state)
  local filters = machineFilters(state)
  local wanted = normalizedSearch(filters.query)
  local rows = {}
  for _, row in ipairs(itemRows(game, "machines", state)) do
    local info = row.modernMachine
    if info and (wanted == "" or info.searchKey:find(wanted, 1, true))
       and (filters.type == "ANY" or info.typeLabel == filters.type)
       and (filters.damageClass == "ANY" or info.damageClass == filters.damageClass) then
      rows[#rows + 1] = row
    end
  end
  return rows
end

local function machineTypeRows(game, state)
  local found = {}
  for _, row in ipairs(itemRows(game, "machines", state)) do
    if row.modernMachine then found[row.modernMachine.typeLabel] = true end
  end
  local names = {}
  for name in pairs(found) do names[#names + 1] = name end
  table.sort(names)
  local rows = { { label = "ANY TYPE", value = "ANY" } }
  for _, name in ipairs(names) do rows[#rows + 1] = { label = name, value = name } end
  return rows
end

local function decorateMachineResultList(list)
  local baseUpdate = list.update
  function list:update(dt)
    if self.game.input:wasPressed(INFO_ACTION) then
      local item = self.items and self.items[self.index or 1]
      if item then openMoveInfo(self.game, item.value) end
      return
    end
    baseUpdate(self, dt)
  end
  list.footer = "Y/I MOVE INFO"
  return list
end

local function updateMachineHub(hub, bagList)
  local state = bagList.modernBag
  local filters = machineFilters(state)
  local sortLabels = {
    NUMBER = "NUMBER", NAME = "MOVE NAME",
    POWER_DESC = "POWER HIGH", POWER_ASC = "POWER LOW",
  }
  hub.items = {
    { label = "NAME: " .. (filters.query == "" and "ANY" or filters.query), value = "name" },
    { label = "TYPE: " .. filters.type, value = "type" },
    { label = "CLASS: " .. filters.damageClass, value = "class" },
    { label = "SORT: " .. (sortLabels[state.machineSort] or "NUMBER"), value = "sort" },
    { label = "SHOW RESULTS (" .. tostring(#machineFilteredRows(bagList.game, state)) .. ")", value = "results" },
    { label = "RESET FILTERS", value = "reset" },
    { label = "CANCEL", value = "cancel" },
  }
end

local function openMachineSearch(bagList)
  local ListMenu = require("src.ui.ListMenu")
  local state = bagList.modernBag
  state.swapId = nil
  bagList.hollowIndex = nil
  local hub
  hub = ListMenu.new(bagList.game, "TM HM SEARCH", {}, {
    onChoose = function(choice, menu)
      local filters = machineFilters(state)
      if choice.value == "name" then
        bagList.game.stack:push(MachineNameSearch.new(bagList.game, filters.query, function(query)
          filters.query = query
          updateMachineHub(hub, bagList)
        end))
      elseif choice.value == "type" then
        local typeMenu
        typeMenu = ListMenu.new(bagList.game, "MOVE TYPE", machineTypeRows(bagList.game, state), {
          onChoose = function(row, current)
            current:close()
            filters.type = row.value
            updateMachineHub(hub, bagList)
          end,
        })
        bagList.game.stack:push(typeMenu)
      elseif choice.value == "class" then
        local classRows = {
          { label = "ANY CLASS", value = "ANY" },
          { label = "PHYSICAL", value = "PHYSICAL" },
          { label = "SPECIAL", value = "SPECIAL" },
          { label = "STATUS", value = "STATUS" },
        }
        bagList.game.stack:push(ListMenu.new(bagList.game, "DAMAGE CLASS", classRows, {
          onChoose = function(row, current)
            current:close()
            filters.damageClass = row.value
            updateMachineHub(hub, bagList)
          end,
        }))
      elseif choice.value == "sort" then
        local sortRows = {
          { label = "MACHINE NUMBER", value = "NUMBER" },
          { label = "MOVE NAME", value = "NAME" },
          { label = "POWER HIGH TO LOW", value = "POWER_DESC" },
          { label = "POWER LOW TO HIGH", value = "POWER_ASC" },
        }
        bagList.game.stack:push(ListMenu.new(bagList.game, "SORT TM HM", sortRows, {
          onChoose = function(row, current)
            current:close()
            setMachineSort(state, row.value)
            refreshPocket(bagList, selectedId(bagList))
            updateMachineHub(hub, bagList)
          end,
        }))
      elseif choice.value == "results" then
        local rows = machineFilteredRows(bagList.game, state)
        local resultList
        resultList = ListMenu.new(bagList.game, "TM HM RESULTS", rows, {
          onChoose = function(item, current)
            current:close()
            hub:close()
            refreshPocket(bagList, item.value)
          end,
        })
        bagList.game.stack:push(decorateMachineResultList(resultList))
      elseif choice.value == "reset" then
        state.machineFilters = { query = "", type = "ANY", damageClass = "ANY" }
        setMachineSort(state, "NUMBER")
        refreshPocket(bagList, selectedId(bagList))
        updateMachineHub(hub, bagList)
      elseif choice.value == "cancel" then
        hub:close()
      end
    end,
  })
  updateMachineHub(hub, bagList)
  bagList.game.stack:push(hub)
end

local function reorderWithinBag(item, list)
  if not item then return end
  local state = list.modernBag
  if not state.swapId then
    state.swapId = item.value
    list.hollowIndex = list.index
    return
  end
  if state.swapId == item.value then
    state.swapId = nil
    list.hollowIndex = nil
    return
  end

  local pocket = POCKETS[state.pocket]
  local order
  if pocket and pocket.id == "favorites" then
    order = state.favoriteOrder
  else
    local Bag = require("src.inventory.Bag")
    order = Bag.order(list.game.save)
  end
  local from = positionOf(order, state.swapId)
  local to = positionOf(order, item.value)
  if from and to then
    order[from], order[to] = order[to], order[from]
    if pocket and pocket.id == "favorites" then
      rebuildPreferenceIndexes(state)
      persistPreferences(state)
    end
    pcall(function() require("src.core.Sound").play(list.game.data, "Swap") end)
  end
  state.swapId = nil
  list.hollowIndex = nil
  refreshPocket(list, item.value)
end

local function openItemTools(item, list)
  if not item or not list or not list.modernBag then return end
  local ListMenu = require("src.ui.ListMenu")
  local state = list.modernBag
  local id = item.value
  local favorite = state.favoriteSet[id] ~= nil
  local pinned = state.pinnedSet[id] ~= nil
  local rows = {
    { label = favorite and "REMOVE FAVORITE" or "ADD FAVORITE", value = "favorite" },
    { label = pinned and "UNPIN ITEM" or "PIN TO TOP", value = "pin" },
    { label = "MOVE ITEM", value = "move" },
    { label = "CANCEL", value = "cancel" },
  }
  list.game.stack:push(ListMenu.new(list.game, "ITEM OPTIONS", rows, {
    onChoose = function(choice, menu)
      menu:close()
      if choice.value == "favorite" then
        toggleOrderedItem(state.favoriteOrder, id)
        rebuildPreferenceIndexes(state)
        persistPreferences(state)
        pcall(function() require("src.core.Sound").play(list.game.data, "Swap") end)
        refreshPocket(list, id)
      elseif choice.value == "pin" then
        toggleOrderedItem(state.pinnedOrder, id)
        rebuildPreferenceIndexes(state)
        persistPreferences(state)
        autoSortBag(list.game, state)
        pcall(function() require("src.core.Sound").play(list.game.data, "Swap") end)
        refreshPocket(list, id)
      elseif choice.value == "move" then
        reorderWithinBag(item, list)
      end
    end,
  }))
end

local function decorateBag(game, opts, list, mod)
  if type(list) ~= "table" or list.modernBag then return list end

  local baseUpdate = list.update
  local baseDraw = list.draw
  if type(baseUpdate) ~= "function" or type(baseDraw) ~= "function" then
    return list
  end

  local preferences = loadPreferenceState(mod)
  local initialPocket = openingPocketIndex(mod)
  local repeatConfig = scrollConfig(mod)
  autoSortBag(game, preferences)
  list.modernBag = {
    pocket = initialPocket,
    cursors = {},
    swapId = nil,
    battle = opts and opts.battle or nil,
    inventorySignature = inventorySignature(game),
    mod = mod,
    favoriteOrder = preferences.favoriteOrder,
    favoriteSet = preferences.favoriteSet,
    pinnedOrder = preferences.pinnedOrder,
    pinnedSet = preferences.pinnedSet,
    machineSort = preferences.machineSort,
    machineFilters = { query = "", type = "ANY", damageClass = "ANY" },
    searchAvailable = true,
    startActionLabel = "SEARCH",
  }
  list.pageJump = false

  -- Gen1Recomp ListMenu has native hold-to-scroll support. Enabling it here
  -- keeps remapped keyboards/controllers and future input backends working
  -- through the engine's own input state instead of polling device keys.
  list.keyRepeat = repeatConfig.enabled
  list.repeatDelay = repeatConfig.delay
  list.repeatRate = repeatConfig.rate
  list.holdDir = nil
  list.holdFrames = 0

  list.onSelectKey = function(item, currentList)
    if currentList.modernBag and currentList.modernBag.swapId then
      reorderWithinBag(item, currentList)
    else
      openItemTools(item, currentList)
    end
  end

  function list:update(dt)
    local state = self.modernBag
    local signature = inventorySignature(self.game)
    if state and signature ~= state.inventorySignature then
      autoSortBag(self.game, state)
      state.inventorySignature = inventorySignature(self.game)
    end

    local current = selectedId(self)
    refreshPocket(self, current)
    local input = self.game.input
    local pocket = POCKETS[state.pocket]
    if pocket and pocket.id == "machines" and input:wasPressed(INFO_ACTION) then
      openMoveInfo(self.game, selectedId(self))
      return
    elseif input:wasPressed("start") then
      if pocket and pocket.id == "machines" then openMachineSearch(self)
      else openQuickSearch(self) end
      return
    elseif input:wasPressed("left") then
      switchPocket(self, -1)
      return
    elseif input:wasPressed("right") then
      switchPocket(self, 1)
      return
    end
    baseUpdate(self, dt)
    if self.modernBag then saveCursor(self) end
  end

  function list:draw()
    baseDraw(self)
    -- Only the item-box path leaves the title and footer rows unpainted. If a
    -- build ever draws them itself, leave it alone rather than doubling up.
    if self.itemBox then
      drawPocketHeader(self)
      drawBagFooter(self)
    end
  end

  refreshPocket(list)
  return list
end

local function pressInfoAction(input, source)
  if type(input.sourcePress) == "function" then
    input:sourcePress(INFO_ACTION, source)
  elseif type(input.pressQueue) == "table" then
    input.pressQueue[#input.pressQueue + 1] = INFO_ACTION
  end
end

local function releaseInfoAction(input, source)
  if type(input.sourceRelease) == "function" then
    input:sourceRelease(INFO_ACTION, source)
  elseif type(input.state) == "table" then
    input.state[INFO_ACTION] = false
  end
end

local function installMoveInfoBindings(input)
  if type(input) ~= "table" then return false end
  local patch = rawget(_G, INPUT_PATCH_KEY)
  if not patch then
    patch = {
      baseKeyPressed = input.keypressed,
      baseKeyReleased = input.keyreleased,
      basePadPressed = input.gamepadpressed,
      basePadReleased = input.gamepadreleased,
    }
    rawset(_G, INPUT_PATCH_KEY, patch)

    if type(input.keypressed) == "function" then
      input.keypressed = function(self, key, ...)
        local result = patch.baseKeyPressed(self, key, ...)
        if key == "i" then pressInfoAction(self, "modern-bag-key:i") end
        return result
      end
    end
    if type(input.keyreleased) == "function" then
      input.keyreleased = function(self, key, ...)
        local result = patch.baseKeyReleased(self, key, ...)
        if key == "i" then releaseInfoAction(self, "modern-bag-key:i") end
        return result
      end
    end
    if type(input.gamepadpressed) == "function" then
      input.gamepadpressed = function(self, joystick, button, ...)
        local result = patch.basePadPressed(self, joystick, button, ...)
        if button == "y" then pressInfoAction(self, "modern-bag-pad:y") end
        return result
      end
    end
    if type(input.gamepadreleased) == "function" then
      input.gamepadreleased = function(self, joystick, button, ...)
        local result = patch.basePadReleased(self, joystick, button, ...)
        if button == "y" then releaseInfoAction(self, "modern-bag-pad:y") end
        return result
      end
    end
  end
  return true
end

local function installUnlimitedInventory(Bag, game, mod)
  if type(Bag) ~= "table" then return false end

  -- Compatibility with older engine builds that exposed a writable constant.
  Bag.CAPACITY = math.huge

  -- Current builds read the distinct-slot capacity from Data.constants.
  game.data.constants = game.data.constants or {}
  game.data.constants.bagSize = 2147483647

  local patch = rawget(_G, BAG_PATCH_KEY)
  if not patch then
    patch = {
      baseAdd = Bag.add,
      baseCapacity = Bag.capacity,
    }
    rawset(_G, BAG_PATCH_KEY, patch)

    if type(Bag.capacity) == "function" then
      Bag.capacity = function()
        return math.huge
      end
    end

    if type(Bag.add) == "function" then
      Bag.add = function(save, id, qty, data)
        local handler = patch.add
        if handler then return handler(save, id, qty, data) end
        return patch.baseAdd(save, id, qty, data)
      end
    end
  end

  patch.add = function(save, id, qty, data)
    if type(save) ~= "table" or type(save.inventory) ~= "table"
       or type(id) ~= "string" or id == "" then
      return patch.baseAdd(save, id, qty, data)
    end

    local amount = qty == nil and 1 or tonumber(qty)
    if not amount or amount <= 0 then
      return patch.baseAdd(save, id, qty, data)
    end
    amount = math.floor(amount)

    local inventory = save.inventory
    local isNew = inventory[id] == nil
    inventory[id] = (tonumber(inventory[id]) or 0) + amount

    local badge = type(Bag.isBadge) == "function"
                  and Bag.isBadge(id)
                  or id:find("BADGE", 1, true) ~= nil
    if isNew and not badge then
      table.insert(Bag.order(save), id)
    end
    return true
  end

  return true
end

local function modernMoveInfoModel(state)
  local info = state.info
  if not info then
    return {
      title = "MOVE INFORMATION",
      rows = { { label = "NO MOVE DATA", enabled = false } },
      index = 1,
      scroll = 0,
      footer = { "A/B BACK" },
    }
  end
  return {
    title = "MOVE INFORMATION",
    rows = {
      { label = info.code .. "  " .. info.name, header = true, enabled = false },
      { label = "TYPE", value = info.typeLabel, enabled = false },
      { label = "CLASS", value = info.damageClass, enabled = false },
      { label = "POWER", value = info.power > 0 and tostring(info.power) or "--",
        enabled = false },
      { label = "ACCURACY", value = info.accuracy
          and (tostring(info.accuracy) .. "%") or "--", enabled = false },
      { label = "PP", value = tostring(info.pp), enabled = false },
      { label = "EFFECT", header = true, enabled = false },
      { label = info.effect or "--", enabled = false },
    },
    index = 1,
    scroll = 0,
    footer = { "Y/I OR A/B BACK" },
  }
end

local modernUiContract = {
  apiVersion = 1,
  screens = {
    gen1_modern_bag_move_info = {
      match = function(state)
        return type(state) == "table" and state.screenId == MOVE_INFO_SCREEN_ID
          and state.game ~= nil
      end,
      canSuppressNative = true,
      model = function(_, state) return modernMoveInfoModel(state) end,
      actions = {
        select = function(_, state)
          state.game.stack:pop()
          return true
        end,
        start = function(_, state)
          state.game.stack:pop()
          return true
        end,
        back = function(_, state)
          state.game.stack:pop()
          return true
        end,
      },
    },
  },
}

return function(mod)
  if mod.options and type(mod.options.define) == "function" then
    mod.options:define({
      {
        key = "opening_pocket",
        type = "choice",
        label = "Opening Pocket",
        default = "medicine",
        choices = {
          { "Favorites", "favorites" },
          { "Medicine", "medicine" },
          { "Balls", "balls" },
          { "TM / HM", "machines" },
          { "Battle", "battle" },
          { "Key Items", "key" },
          { "Other", "other" },
          { "Last Used", "last" },
        },
      },
      {
        key = "hold_scroll_speed",
        type = "choice",
        label = "Hold Scroll Speed",
        default = "fast",
        choices = {
          { "Off", "off" },
          { "Normal", "normal" },
          { "Fast", "fast" },
          { "Very Fast", "very_fast" },
        },
      },
    })
  end
  local modernUiExports
  local modernUiRegistered = false
  local function ensureModernUiAdapter()
    if type(mod.find) ~= "function" then return false end
    local okFind, handle = pcall(mod.find, "gen1_modern_ui")
    if not okFind or type(handle) ~= "table" or type(handle.exports) ~= "table" then
      modernUiExports, modernUiRegistered = nil, false
      return false
    end
    local ex = handle.exports
    if tonumber(ex.compatibilityApiVersion or 1) ~= 1
        or type(ex.registerAdapter) ~= "function" then
      modernUiExports, modernUiRegistered = ex, false
      return false
    end
    if modernUiRegistered and modernUiExports == ex then return true end
    local ok, registered, reason = pcall(ex.registerAdapter, {
      owner = "gen1_modern_bag",
      version = "1.6.0",
      contract = modernUiContract,
    })
    if ok and registered ~= false then
      modernUiExports, modernUiRegistered = ex, true
      return true
    end
    modernUiExports, modernUiRegistered = ex, false
    if mod.log then
      mod.log:warn("Gen1 Modern UI adapter unavailable: %s",
        tostring(ok and reason or registered))
    end
    return false
  end

  mod.exports.gen1ModernUi = modernUiContract
  mod.exports.ensureModernUiAdapter = ensureModernUiAdapter
  mod.exports.openingPocketIndex = function()
    return openingPocketIndex(mod)
  end
  mod.exports.scrollConfig = function()
    local cfg = scrollConfig(mod)
    return { enabled = cfg.enabled, delay = cfg.delay, rate = cfg.rate }
  end

  mod.events:on("game.ready", function(event)
    local game = event and event.game
    if not game then
      mod.log:warn("Gen1ModernBag could not install: game.ready had no game object; restart with the mod enabled")
      return
    end

    ensureModernUiAdapter()

    if not installMoveInfoBindings(game.input) then
      mod.log:warn("Gen1ModernBag could not bind Y / I for move information")
    end

    -- Remove both vanilla inventory limits: the number of distinct item ids
    -- and the 99-unit cap for each individual stack. Item effects and removal
    -- still run through the engine's normal inventory functions.
    local bagOk, Bag = pcall(require, "src.inventory.Bag")
    if not bagOk or not installUnlimitedInventory(Bag, game, mod) then
      mod.log:warn("Gen1ModernBag could not remove inventory limits; src.inventory.Bag was unavailable")
    end

    local ok, BagMenu = pcall(require, "src.ui.BagMenu")
    if not ok or type(BagMenu) ~= "table" or type(BagMenu.new) ~= "function" then
      mod.log:warn("Gen1ModernBag could not find src.ui.BagMenu; check game compatibility and restart")
      return
    end

    local dispatch = rawget(_G, PATCH_KEY)
    if not dispatch then
      dispatch = { baseNew = BagMenu.new }
      rawset(_G, PATCH_KEY, dispatch)
      BagMenu.new = function(currentGame, opts)
        local list = dispatch.baseNew(currentGame, opts)
        local decorator = dispatch.decorate
        if decorator then return decorator(currentGame, opts, list) end
        return list
      end
    end
    dispatch.decorate = function(currentGame, opts, list)
      return decorateBag(currentGame, opts, list, mod)
    end
    mod.log:info("Gen1ModernBag installed with " .. tostring(#POCKETS)
      .. " pockets, configurable opening pocket, hold scrolling, favorites, pinned items, TM/HM filters, move data, power sorting and unlimited inventory")
  end)

  mod.exports.pocketFor = pocketFor
  mod.exports.autoSort = function(game)
    return autoSortBag(game, loadPreferenceState(mod))
  end
  mod.exports.search = function(game, query)
    return searchRows(game, query, loadPreferenceState(mod))
  end
  mod.exports.machineInfo = function(game, id)
    return machineInfo(game, id)
  end
  mod.exports.machineRows = function(game, filters, sortMode)
    local state = loadPreferenceState(mod)
    if sortMode then setMachineSort(state, sortMode) end
    state.machineFilters = filters or { query = "", type = "ANY", damageClass = "ANY" }
    return machineFilteredRows(game, state)
  end
  mod.exports.moveDamageClass = moveDamageClass
  mod.exports.isFavorite = function(id)
    return loadPreferenceState(mod).favoriteSet[id] ~= nil
  end
  mod.exports.isPinned = function(id)
    return loadPreferenceState(mod).pinnedSet[id] ~= nil
  end

  mod.exports.pockets = function()
    local out = {}
    for i, pocket in ipairs(POCKETS) do
      out[i] = { id = pocket.id, label = pocket.label }
    end
    return out
  end

  -- Register immediately when load order permits it; game.ready retries after
  -- the full mod set is active, and Gen1 Modern UI can also discover this
  -- public export on reload/enable changes.
  ensureModernUiAdapter()
end
