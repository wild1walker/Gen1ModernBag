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
  -- A search fills this one and puts you on it; it is not in the ring until
  -- then, and it is gone the next time the Bag opens.
  { id = "results", label = "RESULTS", virtual = true, transient = true },
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
-- It goes on the box's own top border, which is where Gen 1 titles a window:
-- the border line runs up to the label and continues after it.
--
-- LIST_MENU_BOX is tiles 4,2 - 19,12, so that border is the row at y = 16 and
-- the corners are the columns at x = 32 and x = 152. The fourteen columns
-- between them are the label's, and the arrows take the first and the last.
local HEADER_Y = 16
local HEADER_LEFT_X = 40
local HEADER_RIGHT_X = 144
local HEADER_NAME_X = 48
local HEADER_NAME_WIDTH = HEADER_RIGHT_X - HEADER_NAME_X

-- Knock the border line out from under a label.
--
-- Glyphs are drawn as a mask -- Font.draw paints them in whatever colour is
-- set, which is how black text lands on the box's white fill -- so a label
-- drawn straight onto a border would have the line running through the
-- letters. Painting the cells white first leaves the line either side of the
-- label and nothing behind it.
--
-- Knock out exactly the width of the text and the line ends flush against the
-- first glyph and restarts flush against the last, which reads as the frame
-- touching the letters. src/ui/Menu.lua's own title does this. A tile of
-- clearance at each end is what buys the gap; the label itself does not move.
local BORDER_LABEL_PAD = 8

local function clearBorderRun(x, y, width)
  if width <= 0 then return end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", x, y, width, 8)
end

-- The padded run, clamped so it can never rub out a corner glyph: those are
-- the columns at tx and tx + tw - 1, and the run lives between them.
local function clearLabelRun(x, y, width, tx, tw)
  local left = math.max((tx + 1) * 8, x - BORDER_LABEL_PAD)
  local right = math.min((tx + tw - 1) * 8, x + width + BORDER_LABEL_PAD)
  clearBorderRun(left, y, right - left)
end

-- Centre a label between a box's corner columns, on the 8px column grid the
-- rest of the box sits on.
local function borderLabelX(Font, text, tx, tw)
  local slack = math.max(0, (tw - 2) * 8 - Font.width(text))
  return (tx + 1) * 8 + math.floor(slack / 16) * 8
end

-- Label a box on its top border row: knock the line out, then draw.
local function drawBorderLabel(Font, text, tx, ty, tw)
  local x = borderLabelX(Font, text, tx, tw)
  clearLabelRun(x, ty * 8, Font.width(text), tx, tw)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(text, x, ty * 8)
  return x
end

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
--
-- Trim by glyphs, not by bytes. A label can carry a multi-byte character --
-- POKé, the ¥ -- or a Gen 1 control code, and half of one of those is not a
-- character. Font.split is the engine's own glyph split, the same one Menu
-- measures its title with; it is used when it round-trips, so a build without
-- it still trims the old way rather than breaking.
local function labelGlyphs(Font, label)
  if type(Font.split) ~= "function" then return nil end
  local ok, glyphs = pcall(Font.split, label)
  if not ok or type(glyphs) ~= "table" then return nil end
  local joined = table.concat(glyphs)
  if joined ~= label then return nil end
  return glyphs
end

local function fitLabel(Font, label, budget)
  if Font.width(label) <= budget then return label end
  local glyphs = labelGlyphs(Font, label)
  if glyphs then
    while #glyphs > 0 and Font.width(table.concat(glyphs)) > budget do
      table.remove(glyphs)
    end
    return table.concat(glyphs)
  end
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
  -- Two of the field's twelve columns are the name's clearance.
  local label = fitLabel(Font, pocket.label,
    HEADER_NAME_WIDTH - BORDER_LABEL_PAD * 2)
  -- Centre the name between the arrows, which keep their own columns on every
  -- pocket so the keys that change pocket never move.
  local slack = math.max(0, HEADER_NAME_WIDTH - Font.width(label))
  local nameX = HEADER_NAME_X + math.floor(slack / 16) * 8

  -- One run per glyph group, so the border survives in the gaps between them.
  -- The name is padded; the arrows are not, because they sit against the
  -- corner glyphs and clearance on their outer side would rub one out.
  clearBorderRun(HEADER_LEFT_X, HEADER_Y, 8)
  clearBorderRun(nameX - BORDER_LABEL_PAD, HEADER_Y,
    Font.width(label) + BORDER_LABEL_PAD * 2)
  clearBorderRun(HEADER_RIGHT_X, HEADER_Y, 8)

  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(label, nameX, HEADER_Y)
  drawMirroredCode(Font, Theme.cursor, HEADER_LEFT_X, HEADER_Y)
  Font.drawCode(Theme.cursor, HEADER_RIGHT_X, HEADER_Y)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Money.
--
-- On the item window's bottom border, right-aligned, the same way the pocket
-- name sits on the top one. 1.2.0 gave it a little window of its own hanging
-- under that corner; on the border there is no second frame at all, and the
-- amount lands exactly where the bottom-right of the item window is.
--
-- LIST_MENU_BOX ends on tile row 12, so that border is the row at y = 96, and
-- The amount stops one column short of the corner, at x = 144, so the tile
-- between it and the corner glyph is its clearance -- the same tile the rule
-- gives it at the other end.
local MONEY_Y = 96
local MONEY_RIGHT_X = 144

local function moneyText(game)
  local amount = math.floor(tonumber(game and game.save and game.save.money) or 0)
  return ("¥%d"):format(math.max(0, amount))
end

local function drawBagMoney(list)
  local text = list.footer
  if type(text) ~= "string" or text == "" then return end
  local Font = require("src.render.Font")
  -- Never past its own clearance at the other end, however wide the glyphs
  -- are: x = 40 is the column the Left arrow sits in on the top border.
  local x = math.max(HEADER_LEFT_X + BORDER_LABEL_PAD,
    MONEY_RIGHT_X - Font.width(text))
  clearBorderRun(x - BORDER_LABEL_PAD,
    MONEY_Y, (MONEY_RIGHT_X - x) + BORDER_LABEL_PAD * 2)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(text, x, MONEY_Y)
  love.graphics.setColor(1, 1, 1, 1)
end

-- Pop-up menus.
--
-- These are src/ui/Menu.lua, the engine's own framed menu widget: it draws the
-- frame, the title on the top border and the more-arrow on the bottom one, and
-- it owns the cursor, the scrolling and the input. A mod hands it a list of
-- { label, onSelect } and a corner to put it in.
--
-- Up to 1.3.0 these were ListMenus with their `draw` replaced by a frame this
-- mod painted itself, because ListMenu's full-screen branch fills all 160x144
-- white and paints no frame at all. Menu is the widget that was wanted all
-- along.
local SCREEN_TILES_W = 20
local SCREEN_TILES_H = 18

-- A window over the whole screen, for the two screens that have more to say
-- than a corner will hold. Its interior is the eighteen columns from x = 8 and
-- the sixteen rows from y = 8.
local WINDOW_BOX = { tx = 0, ty = 0, tw = SCREEN_TILES_W, th = SCREEN_TILES_H }
local WINDOW_LEFT_X = 8
local WINDOW_TOP_Y = 8
local WINDOW_BOTTOM_Y = 128
local WINDOW_INNER_W = 144

-- RESULTS only exists while a search is loaded into it. Everything else is
-- always in the ring.
local function pocketVisible(state, pocket)
  if not pocket then return false end
  if pocket.transient then return state ~= nil and state.results ~= nil end
  return true
end

local function rememberPocket(state)
  if not state or not state.mod or not state.mod.save then return end
  local pocket = POCKETS[state.pocket]
  -- A transient pocket is not somewhere to reopen the Bag on: it is empty by
  -- the time the Bag opens again, so LAST USED keeps the pocket before it.
  if pocket and not pocket.transient then
    state.mod.save:set("last_pocket", pocket.id)
  end
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
  -- The results page is rebuilt from the search that filled it rather than
  -- from a snapshot, so its counts follow the Bag as items are used up.
  local rows = pocket.transient
    and state.results and state.results.build(list.game, state)
    or itemRows(list.game, pocket.id, state)
  list.items = rows
  -- Not drawn by the engine for an item-box list (see the pocket header
  -- above), but Gen1 Modern UI and the compatibility contract read it.
  list.title = pocket.label
  -- START opens the item tools on every pocket; SELECT opens that pocket's
  -- search, which for TM/HM is the filter hub. The labels are published for
  -- Gen1 Modern UI, which puts a touch button on each of them; nothing is
  -- spelled out on the Bag itself any more.
  state.startActionLabel = "TOOLS"
  if pocket.id == "machines" or (pocket.transient and state.results
      and state.results.machines) then
    state.selectActionLabel = "FILTER"
    state.machineSortLabel = (state.machineSort or "NUMBER"):gsub("_", " ")
  else
    state.selectActionLabel = "SEARCH"
    state.machineSortLabel = nil
  end
  -- The whole footer is now the amount on the window's bottom border.
  list.footer = moneyText(list.game)
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
  local index = state.pocket
  for _ = 1, #POCKETS do
    index = ((index - 1 + delta) % #POCKETS) + 1
    if pocketVisible(state, POCKETS[index]) then break end
  end
  state.pocket = index
  rememberPocket(state)
  refreshPocket(list)
end

-- Load a search into the results page and put the Bag on it.
local function showResults(list, results)
  local state = list.modernBag
  if not state then return end
  saveCursor(list)
  state.swapId = nil
  list.hollowIndex = nil
  state.results = results
  -- A fresh search starts at the top rather than where the last one was left.
  state.cursors.results = { index = 1, scroll = 0 }
  state.pocket = pocketIndexById("results")
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

-- The search keyboard.
--
-- 1.1.1 drew this as a bare white page. There was no frame; the three header
-- lines sat on a 12px pitch the 8px font does not land on; and the last row --
-- DEL, CLR, GO and EXIT, which are words rather than single glyphs -- was laid
-- out on the same 16px pitch as the letters, so the four keys were drawn on
-- top of one another and read as "DECLBOEXIT".
--
-- The screen is now one framed window with everything on the 8px grid. Its
-- title sits on the window's top border, the letters keep a cell per key with
-- the cursor in the column to the left of the glyph, and the action row is
-- measured and centred so no two words can share a column whatever the font.
local KEYBOARD_LEFT_X = WINDOW_LEFT_X
local KEYBOARD_INNER_W = WINDOW_INNER_W
local KEYBOARD_CELL_W = 16     -- cursor column + glyph column
local KEYBOARD_HEADER_Y = WINDOW_TOP_Y
local KEYBOARD_GRID_TOP = 40
local KEYBOARD_ROW_H = 16
local KEYBOARD_ACTION_Y = 104
local KEYBOARD_HINT_Y = 120

-- Eighteen columns each; both keyboards take the same keys.
local KEYBOARD_HINTS = {
  "A TYPE  B DEL/EXIT",
  "SEL CLR  START GO",
}

local function drawKeyboardGrid(screen, Font, Theme)
  local actionRow = #SEARCH_GRID
  for r = 1, actionRow - 1 do
    local y = KEYBOARD_GRID_TOP + (r - 1) * KEYBOARD_ROW_H
    for c, key in ipairs(SEARCH_GRID[r]) do
      local x = KEYBOARD_LEFT_X + (c - 1) * KEYBOARD_CELL_W
      if r == screen.row and c == screen.col then Font.drawCode(Theme.cursor, x, y) end
      Font.draw(key, x + 8, y)
    end
  end

  local keys = SEARCH_GRID[actionRow]
  local run = 0
  for _, key in ipairs(keys) do run = run + 8 + Font.width(key) end
  -- Centre the measured run on the 8px column grid the rest of the box uses.
  local x = KEYBOARD_LEFT_X
    + math.max(0, math.floor((KEYBOARD_INNER_W - run) / 16)) * 8
  for c, key in ipairs(keys) do
    if screen.row == actionRow and c == screen.col then
      Font.drawCode(Theme.cursor, x, KEYBOARD_ACTION_Y)
    end
    Font.draw(key, x + 8, KEYBOARD_ACTION_Y)
    x = x + 8 + Font.width(key)
  end
end

local function drawSearchKeyboard(screen, headerLines)
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")
  love.graphics.setColor(1, 1, 1, 1)
  Font.drawBox(WINDOW_BOX.tx, WINDOW_BOX.ty, WINDOW_BOX.tw, WINDOW_BOX.th)
  drawBorderLabel(Font, tostring(screen.title or ""),
    WINDOW_BOX.tx, WINDOW_BOX.ty, WINDOW_BOX.tw)
  love.graphics.setColor(0, 0, 0, 1)
  local y = KEYBOARD_HEADER_Y
  for _, line in ipairs(headerLines) do
    Font.draw(line, KEYBOARD_LEFT_X, y)
    y = y + 8
  end
  drawKeyboardGrid(screen, Font, Theme)
  for i, hint in ipairs(KEYBOARD_HINTS) do
    Font.draw(hint, KEYBOARD_LEFT_X, KEYBOARD_HINT_Y + (i - 1) * 8)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

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

-- GO does not open a page of its own. The matches are loaded into the Bag's
-- results page and the Bag is put on it, so they are read where every other
-- item is read -- in the item window, with the pocket header, the counts and
-- the markers -- instead of on an undecorated full-screen list.
function QuickSearch:openResults()
  syncSearchQuery(self)
  local bag = self.bagList
  local query = self.query
  self:close()
  if not bag or not bag.modernBag then return end
  showResults(bag, {
    query = query,
    build = function(game, state) return searchRows(game, query, state) end,
  })
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

-- Recomputed only when the query changes: the count is drawn every frame and
-- the Bag it counts cannot change while the keyboard is open.
function QuickSearch:matchCount()
  if self.matchQuery ~= self.query then
    self.matchQuery = self.query
    self.matchTotal = #searchRows(self.game, self.query, self.bagList.modernBag)
  end
  return self.matchTotal or 0
end

function QuickSearch:draw()
  drawSearchKeyboard(self, {
    -- "FIND: " plus the twelve glyphs the query is capped at is eighteen.
    "FIND: " .. (self.query == "" and "ALL" or self.query),
    "MATCHES: " .. tostring(self:matchCount()),
  })
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

-- Move Information.
--
-- The last of the mod's screens to be drawn as a bare white page: no frame,
-- and eleven lines on a 14px pitch the 8px font does not land on, so every row
-- but one sat between the rows the rest of the game draws on. A machine with
-- no move data also escaped through an early return that never put the draw
-- colour back, leaving black set for whatever drew next.
--
-- It is the same screen-filling window the search keyboard uses, titled on
-- its top border, with the sixteen interior rows spent on the machine and its
-- move, the five stats, the effect over four wrapped lines and the way out --
-- each block separated by a blank row.
local INFO_MOVE_Y = WINDOW_TOP_Y              --   8
local INFO_STATS_Y = WINDOW_TOP_Y + 16        --  24
local INFO_EFFECT_LABEL_Y = WINDOW_TOP_Y + 64 --  72
local INFO_EFFECT_Y = WINDOW_TOP_Y + 72       --  80
local INFO_EFFECT_LINES = 4
local INFO_EFFECT_COLS = 18
local INFO_BACK_HINT = "Y/I OR A/B BACK"

function MoveInfoScreen:draw()
  local Font = require("src.render.Font")
  local info = self.info
  love.graphics.setColor(1, 1, 1, 1)
  Font.drawBox(WINDOW_BOX.tx, WINDOW_BOX.ty, WINDOW_BOX.tw, WINDOW_BOX.th)
  drawBorderLabel(Font, "MOVE INFORMATION",
    WINDOW_BOX.tx, WINDOW_BOX.ty, WINDOW_BOX.tw)
  love.graphics.setColor(0, 0, 0, 1)

  if info then
    -- Four for the code, two for the gap, twelve for the longest Gen 1 move
    -- name: eighteen, which is the interior exactly.
    Font.draw(info.code .. "  " .. info.name, WINDOW_LEFT_X, INFO_MOVE_Y)
    local stats = {
      "TYPE: " .. info.typeLabel,
      "CLASS: " .. info.damageClass,
      "POWER: " .. (info.power > 0 and tostring(info.power) or "--"),
      "ACCURACY: " .. (info.accuracy and (tostring(info.accuracy) .. "%") or "--"),
      "PP: " .. tostring(info.pp),
    }
    for i, line in ipairs(stats) do
      Font.draw(line, WINDOW_LEFT_X, INFO_STATS_Y + (i - 1) * 8)
    end
    Font.draw("EFFECT:", WINDOW_LEFT_X, INFO_EFFECT_LABEL_Y)
    local lines = wrapWords(info.effect, INFO_EFFECT_COLS, INFO_EFFECT_LINES)
    for i = 1, math.min(#lines, INFO_EFFECT_LINES) do
      Font.draw(lines[i], WINDOW_LEFT_X, INFO_EFFECT_Y + (i - 1) * 8)
    end
  else
    Font.draw("NO MOVE DATA", WINDOW_LEFT_X, INFO_MOVE_Y)
  end

  Font.draw(INFO_BACK_HINT, WINDOW_LEFT_X, WINDOW_BOTTOM_Y)
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
  drawSearchKeyboard(self, {
    "FIND: " .. (self.query == "" and "ALL" or self.query),
  })
end


-- Opening a Menu.
--
-- Menu knocks out exactly the title's width for it, so the rule ends flush
-- against the first and last letter -- the frame appearing to touch them. A
-- space at each end is what buys the clearance, and it is added here at the
-- call site: a title is a catalog key elsewhere in the engine, and padding it
-- inside the string would make the padding part of the key.
--
-- Menu grows tw to the widest label + 3 and never accounts for the title, so
-- the width has to be asked for. The title starts a fixed three tiles in, so
-- the padded title has to stay within tw - 4 or it runs into the top-right
-- corner glyph -- the same defect at the other end.
local MENU_LABEL_MARGIN = 3
local MENU_TITLE_MARGIN = 4

-- Four rows of options, opened clear of the pocket header on the item
-- window's top border. Menu works its own height out from the rows.
local ITEM_TOOLS_TY = 6

local function menuTitle(title)
  return " " .. tostring(title or "") .. " "
end

local function menuTiles(Font, text)
  return math.ceil(Font.width(text) / 8)
end

local function menuWidth(Font, title, items)
  local widest = 0
  for _, item in ipairs(items) do
    local tiles = menuTiles(Font, tostring(item.label or ""))
    if tiles > widest then widest = tiles end
  end
  return math.min(SCREEN_TILES_W, math.max(
    widest + MENU_LABEL_MARGIN,
    menuTiles(Font, menuTitle(title)) + MENU_TITLE_MARGIN))
end

-- Labels are held to the width that was asked for: Menu sizes itself from the
-- widest one, so a long label would otherwise grow the menu off the screen.
local function fitMenuLabels(Font, items, tw)
  local budget = (tw - MENU_LABEL_MARGIN) * 8
  for _, item in ipairs(items) do
    item.label = fitLabel(Font, tostring(item.label or ""), budget)
  end
end

local function openMenu(game, title, items, opts)
  opts = opts or {}
  local Font = require("src.render.Font")
  local Menu = require("src.ui.Menu")
  local tw = opts.tw or menuWidth(Font, title, items)
  fitMenuLabels(Font, items, tw)
  local menu = Menu.new(game, items, {
    -- Against the right edge, the corner Gen 1 opens a menu into.
    tx = SCREEN_TILES_W - tw,
    ty = opts.ty or 0,
    tw = tw,
    title = menuTitle(title),
    maxVisible = opts.maxVisible,
    onCancel = opts.onCancel,
  })
  game.stack:push(menu)
  return menu
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

local MACHINE_SORT_LABELS = {
  NUMBER = "NUMBER", NAME = "MOVE NAME",
  POWER_DESC = "POWER HIGH", POWER_ASC = "POWER LOW",
}

-- The hub is a fixed seven rows whose labels carry the current filters, so
-- they are rewritten in place rather than the menu being rebuilt: Menu sizes
-- itself once, from the rows it was handed.
local MACHINE_HUB_TW = SCREEN_TILES_W
local MACHINE_HUB_TY = 1
local MACHINE_PICKER_TY = 6
local MACHINE_TYPE_MAX_VISIBLE = 5
local MACHINE_HUB_LABEL_BUDGET = (MACHINE_HUB_TW - MENU_LABEL_MARGIN) * 8

local function updateMachineHub(hub, bagList)
  local state = bagList.modernBag
  local filters = machineFilters(state)
  local Font = require("src.render.Font")
  local labels = {
    "NAME: " .. (filters.query == "" and "ANY" or filters.query),
    "TYPE: " .. filters.type,
    "CLASS: " .. filters.damageClass,
    "SORT: " .. (MACHINE_SORT_LABELS[state.machineSort] or "NUMBER"),
    "RESULTS: " .. tostring(#machineFilteredRows(bagList.game, state)),
    "RESET FILTERS",
    "CANCEL",
  }
  for i, label in ipairs(labels) do
    local row = hub.items and hub.items[i]
    -- The query can be twelve glyphs, so this is where a row gets too wide.
    if row then row.label = fitLabel(Font, label, MACHINE_HUB_LABEL_BUDGET) end
  end
end

local function openMachineSearch(bagList)
  local state = bagList.modernBag
  state.swapId = nil
  bagList.hollowIndex = nil
  local game = bagList.game
  local hub

  -- keepOpen on every row that opens a picker: the hub has to still be there
  -- when the picker closes, with its labels caught up.
  local function picker(build)
    return function()
      build()
      updateMachineHub(hub, bagList)
    end
  end

  local function choices(values, labelFor, apply)
    local rows = {}
    for _, value in ipairs(values) do
      rows[#rows + 1] = {
        label = labelFor(value),
        onSelect = function()
          apply(value)
          updateMachineHub(hub, bagList)
        end,
      }
    end
    return rows
  end

  local items = {
    {
      label = "", keepOpen = true,
      onSelect = picker(function()
        local filters = machineFilters(state)
        game.stack:push(MachineNameSearch.new(game, filters.query, function(query)
          machineFilters(state).query = query
          updateMachineHub(hub, bagList)
        end))
      end),
    },
    {
      label = "", keepOpen = true,
      onSelect = picker(function()
        local values, labels = {}, {}
        for _, row in ipairs(machineTypeRows(game, state)) do
          values[#values + 1] = row.value
          labels[row.value] = row.label
        end
        openMenu(game, "MOVE TYPE",
          choices(values, function(v) return labels[v] end,
            function(v) machineFilters(state).type = v end),
          { ty = MACHINE_PICKER_TY, maxVisible = MACHINE_TYPE_MAX_VISIBLE })
      end),
    },
    {
      label = "", keepOpen = true,
      onSelect = picker(function()
        openMenu(game, "DAMAGE CLASS",
          choices({ "ANY", "PHYSICAL", "SPECIAL", "STATUS" },
            function(v) return v == "ANY" and "ANY CLASS" or v end,
            function(v) machineFilters(state).damageClass = v end),
          { ty = MACHINE_PICKER_TY })
      end),
    },
    {
      label = "", keepOpen = true,
      onSelect = picker(function()
        openMenu(game, "SORT TM HM",
          choices({ "NUMBER", "NAME", "POWER_DESC", "POWER_ASC" },
            function(v) return MACHINE_SORT_LABELS[v] end,
            function(v)
              setMachineSort(state, v)
              refreshPocket(bagList, selectedId(bagList))
            end),
          { ty = MACHINE_PICKER_TY })
      end),
    },
    {
      label = "",
      onSelect = function()
        showResults(bagList, {
          machines = true,
          build = function(g, current) return machineFilteredRows(g, current) end,
        })
      end,
    },
    {
      label = "", keepOpen = true,
      onSelect = function()
        state.machineFilters = { query = "", type = "ANY", damageClass = "ANY" }
        setMachineSort(state, "NUMBER")
        refreshPocket(bagList, selectedId(bagList))
        updateMachineHub(hub, bagList)
      end,
    },
    { label = "" },
  }

  hub = openMenu(game, "TM HM SEARCH", items,
    { tw = MACHINE_HUB_TW, ty = MACHINE_HUB_TY })
  updateMachineHub(hub, bagList)
  return hub
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
  local state = list.modernBag
  local id = item.value
  local favorite = state.favoriteSet[id] ~= nil
  local pinned = state.pinnedSet[id] ~= nil

  local function swapSound()
    pcall(function() require("src.core.Sound").play(list.game.data, "Swap") end)
  end

  -- Menu closes itself around onSelect unless the row asks to stay open, so
  -- none of these close it by hand. Nothing here depends on which side of
  -- onSelect that happens.
  openMenu(list.game, "ITEM OPTIONS", {
    {
      label = favorite and "REMOVE FAVORITE" or "ADD FAVORITE",
      onSelect = function()
        toggleOrderedItem(state.favoriteOrder, id)
        rebuildPreferenceIndexes(state)
        persistPreferences(state)
        swapSound()
        refreshPocket(list, id)
      end,
    },
    {
      label = pinned and "UNPIN ITEM" or "PIN TO TOP",
      onSelect = function()
        toggleOrderedItem(state.pinnedOrder, id)
        rebuildPreferenceIndexes(state)
        persistPreferences(state)
        autoSortBag(list.game, state)
        swapSound()
        refreshPocket(list, id)
      end,
    },
    { label = "MOVE ITEM", onSelect = function() reorderWithinBag(item, list) end },
    { label = "CANCEL" },
  }, { ty = ITEM_TOOLS_TY })
end

-- START. In swap mode the press lands the item being moved; otherwise it
-- opens that item's tools.
local function openBagTools(list)
  local item = list.items and list.items[list.index or 1]
  if not item then return end
  if list.modernBag and list.modernBag.swapId then
    reorderWithinBag(item, list)
  else
    openItemTools(item, list)
  end
end

-- SELECT. Each pocket's search: the TM/HM pocket's is its filter hub.
local function openBagSearch(list)
  local state = list.modernBag
  local pocket = state and POCKETS[state.pocket]
  if pocket and pocket.id == "machines" then
    openMachineSearch(list)
  else
    openQuickSearch(list)
  end
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
    startActionLabel = "TOOLS",
    selectActionLabel = "SEARCH",
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
    if input:wasPressed(INFO_ACTION) then
      -- Machine data, not the pocket, is what decides this: a TM reached
      -- through FAVORITES or the results page answers Y/I the same way it
      -- does in TM/HM.
      local id = selectedId(self)
      if id and machineInfo(self.game, id) then
        openMoveInfo(self.game, id)
        return
      end
    end
    if input:wasPressed("select") then
      openBagSearch(self)
      return
    elseif input:wasPressed("start") then
      openBagTools(self)
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
      drawBagMoney(self)
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

  -- The pockets an item can live in. The results page is not one of them:
  -- nothing is filed there, a search puts things there for one Bag session.
  mod.exports.pockets = function()
    local out = {}
    for _, pocket in ipairs(POCKETS) do
      if not pocket.transient then
        out[#out + 1] = { id = pocket.id, label = pocket.label }
      end
    end
    return out
  end

  -- Register immediately when load order permits it; game.ready retries after
  -- the full mod set is active, and Gen1 Modern UI can also discover this
  -- public export on reload/enable changes.
  ensureModernUiAdapter()
end
