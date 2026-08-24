package.preload["src.inventory.Bag"] = function()
  local Bag = {}
  function Bag.order(save)
    save.bagOrder = save.bagOrder or {}
    return save.bagOrder
  end
  function Bag.isBadge(id) return tostring(id):find("BADGE", 1, true) ~= nil end
  function Bag.capacity() return 20 end
  function Bag.add(save, id, qty)
    save.inventory[id] = (save.inventory[id] or 0) + (qty or 1)
    return true
  end
  return Bag
end

-- The Bag draws its own pocket header (the engine's item-box path paints no
-- title), so the render calls have to be observable here.
--
-- love.graphics is stubbed with a real transform stack rather than no-ops:
-- the Left arrow is the cursor glyph mirrored about its own cell, and a
-- no-op translate/scale would report it wherever it was asked to draw
-- instead of where it lands.
local painted = { text = {}, codes = {}, boxes = {} }
local transform = { tx = 0, sx = 1 }
local transformStack = {}

love = love or {}
love.graphics = love.graphics or {}
function love.graphics.push()
  transformStack[#transformStack + 1] = { tx = transform.tx, sx = transform.sx }
end
function love.graphics.pop()
  transform = table.remove(transformStack) or { tx = 0, sx = 1 }
end
function love.graphics.translate(dx) transform.tx = transform.tx + transform.sx * dx end
function love.graphics.scale(sx) transform.sx = transform.sx * sx end
local drawColor = { 1, 1, 1, 1 }
function love.graphics.setColor(r, g, b, a) drawColor = { r, g, b, a } end
local function drawColorIsWhite()
  return drawColor[1] == 1 and drawColor[2] == 1 and drawColor[3] == 1
end
function love.graphics.rectangle() end

-- The screen column an 8px cell drawn at local `x` covers; a mirrored cell
-- grows to the left of its origin.
local function screenCell(x)
  local origin = transform.tx + transform.sx * x
  if transform.sx < 0 then return origin - 8 end
  return origin
end

package.preload["src.render.Font"] = function()
  local Font = {}
  function Font.draw(text, x, y)
    painted.text[#painted.text + 1] = { text = tostring(text), x = screenCell(x), y = y }
  end
  function Font.drawCode(code, x, y)
    painted.codes[#painted.codes + 1] =
      { code = code, x = screenCell(x), y = y, mirrored = transform.sx < 0 }
  end
  function Font.drawBox(tx, ty, tw, th)
    painted.boxes[#painted.boxes + 1] = { tx = tx, ty = ty, tw = tw, th = th }
  end
  function Font.width(text)
    text = tostring(text)
    return (utf8.len(text) or #text) * 8
  end
  return Font
end

-- The engine's paginate folds a line that overruns the box; these fit by
-- construction, so splitting on newlines is the whole of its behaviour here.
-- The width assertions below are what keep that true.
package.preload["src.render.TextBox"] = function()
  return {
    paginate = function(text)
      local lines = {}
      for line in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then lines[#lines + 1] = line end
      end
      return { lines }
    end,
  }
end

package.preload["src.ui.Theme"] = function()
  return { cursor = 0xED, cursorHollow = 0xEC, moreArrow = 0xEE }
end

package.preload["src.core.Sound"] = function()
  return { play = function() end }
end

package.preload["src.ui.ListMenu"] = function()
  local ListMenu = {}
  function ListMenu.new(game, title, items, opts)
    local list = {
      game = game,
      title = title,
      items = items or {},
      opts = opts or {},
      index = 1,
      scroll = 0,
      rows = 7,
    }
    list.onChoose = list.opts.onChoose
    function list:close()
      if self.game.stack:top() == self then self.game.stack:pop() end
    end
    function list:update() end
    function list:draw() end
    return list
  end
  return ListMenu
end

package.preload["src.ui.BagMenu"] = function()
  local BagMenu = {}
  function BagMenu.new(game, opts)
    return {
      game = game,
      items = {},
      index = 1,
      scroll = 0,
      -- src/ui/BagMenu.lua builds its ListMenu with itemBox = true, which is
      -- the branch of ListMenu:draw that paints no title and only four rows.
      itemBox = true,
      rows = 4,
      update = function() end,
      draw = function() end,
      close = function() end,
    }
  end
  return BagMenu
end

local saved = {}
local optionValues = {
  opening_pocket = "medicine",
  hold_scroll_speed = "fast",
}
local optionSchema
local ready
local mod = {
  options = {
    define = function(_, schema) optionSchema = schema end,
    get = function(_, key) return optionValues[key] end,
  },
  save = {
    get = function(_, key, default)
      local value = saved[key]
      if value == nil then return default end
      return value
    end,
    set = function(_, key, value) saved[key] = value end,
  },
  events = {
    on = function(_, name, fn)
      if name == "game.ready" then ready = fn end
    end,
  },
  log = { warn = function() end, info = function() end },
  exports = {},
}

local pressed = {}
local input = {}
function input:wasPressed(name)
  local value = pressed[name]
  pressed[name] = false
  return value or false
end
function input:isDown(name)
  return pressed[name] == true
end
function input:sourcePress(name) pressed[name] = true end
function input:sourceRelease(name) pressed[name] = false end
function input:keypressed(key) self.lastBaseKey = key end
function input:keyreleased(key) self.lastBaseRelease = key end
function input:gamepadpressed(_, button) self.lastBasePad = button end
function input:gamepadreleased(_, button) self.lastBasePadRelease = button end

local stack = { items = {} }
function stack:push(value) self.items[#self.items + 1] = value end
function stack:pop() return table.remove(self.items) end
function stack:top() return self.items[#self.items] end

local game = {
  save = {
    inventory = {
      ANTIDOTE = 2,
      POTION = 5,
      POKE_BALL = 10,
      ESCAPE_ROPE = 1,
      TM_MEGA_PUNCH = 1,
      TM_FLAMETHROWER = 2,
      TM_SWORDS_DANCE = 1,
      HM_SURF = 1,
    },
    bagOrder = {
      "POKE_BALL", "POTION", "ANTIDOTE", "ESCAPE_ROPE",
      "TM_MEGA_PUNCH", "TM_FLAMETHROWER", "TM_SWORDS_DANCE", "HM_SURF",
    },
    money = 1234,
  },
  data = {
    constants = {},
    items = {
      ANTIDOTE = { name = "ANTIDOTE", effect = "HEAL_POISON" },
      POTION = { name = "POTION", effect = "HEAL_HP" },
      POKE_BALL = { name = "POKé BALL", ball = true },
      ESCAPE_ROPE = { name = "ESCAPE ROPE" },
      TM_MEGA_PUNCH = { name = "TM01", machine = { kind = "TM", number = 1, move = "MEGA_PUNCH" } },
      TM_SWORDS_DANCE = { name = "TM03", machine = { kind = "TM", number = 3, move = "SWORDS_DANCE" } },
      TM_FLAMETHROWER = { name = "TM35", machine = { kind = "TM", number = 35, move = "FLAMETHROWER" } },
      HM_SURF = { name = "HM03", machine = { kind = "HM", number = 3, move = "SURF" } },
    },
    moves = {
      MEGA_PUNCH = { name = "MEGA PUNCH", type = "NORMAL", power = 80, accuracy = 85, pp = 20, effect = "NO_ADDITIONAL_EFFECT" },
      SWORDS_DANCE = { name = "SWORDS DANCE", type = "NORMAL", power = 0, accuracy = 100, pp = 30, effect = "ATTACK_UP2_EFFECT" },
      FLAMETHROWER = { name = "FLAMETHROWER", type = "FIRE", power = 95, accuracy = 100, pp = 15, effect = "BURN_SIDE_EFFECT1" },
      SURF = { name = "SURF", type = "WATER", power = 95, accuracy = 100, pp = 15, effect = "NO_ADDITIONAL_EFFECT" },
    },
    types = {
      NORMAL = { name = "NORMAL" }, FIRE = { name = "FIRE" }, WATER = { name = "WATER" },
    },
  },
  input = input,
  stack = stack,
}

local chunk, err = loadfile("main.lua")
assert(chunk, err)
chunk()(mod)
assert(type(ready) == "function", "game.ready hook missing")
ready({ game = game })
assert(type(optionSchema) == "table" and #optionSchema == 2, "Gen1ModernBag options were not defined")
assert(optionSchema[1].key == "opening_pocket", "opening pocket option missing")
assert(optionSchema[2].key == "hold_scroll_speed", "hold scroll option missing")

-- The extra shortcuts preserve the engine's original keyboard/gamepad handlers.
input:keypressed("i")
assert(input.lastBaseKey == "i", "I shortcut replaced the base keyboard handler")
assert(input:wasPressed("gen1_modern_bag_move_info"), "I did not emit the move-info action")
input:gamepadpressed(nil, "y")
assert(input.lastBasePad == "y", "Y shortcut replaced the base gamepad handler")
assert(input:wasPressed("gen1_modern_bag_move_info"), "Y did not emit the move-info action")

local pockets = mod.exports.pockets()
assert(#pockets == 7, "expected seven pockets")
assert(pockets[1].id == "favorites", "favorites pocket must be first")
assert(pockets[2].id == "medicine", "medicine pocket should remain the default")

local BagMenu = require("src.ui.BagMenu")
local bag = BagMenu.new(game, {})
assert(bag.modernBag, "bag was not decorated")
assert(bag.modernBag.pocket == 2, "bag should open on medicine")
assert(bag.keyRepeat == true, "fast hold scrolling should be enabled")
assert(bag.repeatDelay == 10 and bag.repeatRate == 2, "fast hold-scroll timing is incorrect")
assert(bag.items[1].value == "ANTIDOTE", "automatic alphabetical sorting failed")
assert(bag.items[2].value == "POTION", "medicine row missing")

-- Add POTION to Favorites through START -> ITEM OPTIONS. START opens the
-- tools and SELECT opens the search; before 1.2.0 it was the other way round.
bag.index = 2
pressed.start = true
bag:update(0)
local tools = assert(stack:top(), "item tools did not open")
assert(tools.title == "ITEM OPTIONS")
assert(tools.isOpaque == false, "ITEM OPTIONS must be a window over the Bag, not a page")
assert(tools.items[1].label == "ADD FAVORITE")
tools.opts.onChoose(tools.items[1], tools)
assert(saved.favorite_items[1] == "POTION", "favorite was not persisted")
assert(mod.exports.isFavorite("POTION"), "favorite export returned false")

-- The Favorites pocket displays the item and preserves normal item rows.
bag.modernBag.pocket = 1
bag:update(0)
assert(#bag.items == 1 and bag.items[1].value == "POTION", "favorites pocket is incorrect")
assert(bag.items[1].right:find("F", 1, true), "favorite marker missing")

-- Pin POTION and ensure it is above ANTIDOTE despite alphabetical sorting.
bag.modernBag.pocket = 2
bag:update(0)
local potionIndex
for i, row in ipairs(bag.items) do if row.value == "POTION" then potionIndex = i end end
assert(potionIndex, "potion missing before pin")
bag.index = potionIndex
pressed.start = true
bag:update(0)
tools = assert(stack:top(), "pin tools did not open")
assert(tools.items[2].label == "PIN TO TOP")
tools.opts.onChoose(tools.items[2], tools)
assert(saved.pinned_items[1] == "POTION", "pin was not persisted")
assert(mod.exports.isPinned("POTION"), "pin export returned false")
bag:update(0)
assert(bag.items[1].value == "POTION", "pinned item did not stay at the top")
assert(bag.items[1].right:find("P", 1, true), "pin marker missing")

-- Favorites remain saved while an unavailable item is hidden.
game.save.inventory.POTION = nil
bag.modernBag.pocket = 1
bag:update(0)
assert(#bag.items == 0, "unavailable favorite should be hidden")
assert(saved.favorite_items[1] == "POTION", "favorite should survive item depletion")

-- Reacquiring the item restores it to Favorites and keeps it pinned.
game.save.inventory.POTION = 1
game.save.bagOrder[#game.save.bagOrder + 1] = "POTION"
bag:update(0)
assert(#bag.items == 1 and bag.items[1].value == "POTION", "reacquired favorite did not return")
assert(bag.items[1].right:find("PF", 1, true), "favorite/pin markers did not persist")

-- Closing and reopening the Bag reloads persistent preferences.
local reopened = BagMenu.new(game, {})
assert(reopened.modernBag.pocket == 2, "reopened bag should default to medicine")
assert(reopened.items[1].value == "POTION", "pin did not survive reopening")
assert(reopened.items[1].right:find("PF", 1, true), "saved markers did not reload")

-- Opening Pocket can target a fixed pocket.
optionValues.opening_pocket = "balls"
local ballsOpen = BagMenu.new(game, {})
assert(ballsOpen.modernBag.pocket == 3, "Opening Pocket=BALLS was ignored")
assert(ballsOpen.items[1].value == "POKE_BALL", "BALLS did not open to the correct rows")

-- The pocket header. The engine paints no title for an item-box list, so the
-- name only reaches the screen if the Bag's own draw puts it there: assert on
-- what is painted, not just on the title field a previous release set and
-- nothing ever drew.
local function headerPaint(list)
  painted.text, painted.codes, painted.boxes = {}, {}, {}
  list:draw()
  local name
  for _, call in ipairs(painted.text) do
    if call.y == 24 then name = call end
  end
  local arrows = {}
  for _, call in ipairs(painted.codes) do
    if call.y == 24 then arrows[#arrows + 1] = call end
  end
  table.sort(arrows, function(a, b) return a.x < b.x end)
  return name, arrows
end

local name, arrows = headerPaint(ballsOpen)
assert(name, "the pocket header painted no name")
assert(name.text == "BALLS", "wrong pocket name: " .. tostring(name.text))
-- Centred on the 8px grid inside the item box: 40 is the left arrow's column,
-- 144 the right arrow's, and the name is centred in the twelve between them.
-- BALLS is 5 of those 12, so it starts 3 columns in, at x = 48 + 24.
assert(name.x == 72, "pocket name is not centred: x = " .. tostring(name.x))
assert(#arrows == 2, "the pocket header did not paint both arrows")
-- Gen 1 has no left-pointing arrow, so the Left one is the cursor glyph
-- mirrored: same code, landing in the column left of the name.
assert(arrows[1].x == 40 and arrows[1].mirrored,
  "the Left arrow is not mirrored into column 40: x = " .. tostring(arrows[1].x))
assert(arrows[2].x == 144 and not arrows[2].mirrored,
  "the Right arrow is not in column 144: x = " .. tostring(arrows[2].x))
assert(arrows[1].code == arrows[2].code, "the two arrows should be one glyph")
assert(ballsOpen.title == "BALLS",
  "wrong pocket title: " .. tostring(ballsOpen.title))

-- LAST USED remembers pocket changes.
pressed.right = true
ballsOpen:update(0)
assert(ballsOpen.modernBag.pocket == 4, "right pocket switch failed")
name = headerPaint(ballsOpen)
assert(name and name.text == "TM HM",
  "the pocket header did not follow the pocket switch: " .. tostring(name and name.text))
assert(ballsOpen.title == "TM HM",
  "pocket title did not follow the pocket switch: " .. tostring(ballsOpen.title))

-- The money window is the header's twin: the item-box path paints no footer
-- either, so the amount only reaches the screen because the Bag draws it.
--
-- 1.1.1 drew it in the standard bottom text box -- a full-width white bar
-- carrying the amount and a legend for START and SELECT. The legend is gone
-- and the bar with it; what is left is a window sized to the amount, tucked
-- under the item window's bottom-right corner.
local ITEM_BOX_RIGHT_TX = 19   -- LIST_MENU_BOX is tiles 4,2-19,12
local ITEM_BOX_BOTTOM_TY = 12
local MONEY_TEXT_Y = 112

local function moneyPaint(list)
  painted.text, painted.codes, painted.boxes = {}, {}, {}
  list:draw()
  local box
  for _, b in ipairs(painted.boxes) do
    if b.ty > ITEM_BOX_BOTTOM_TY then box = b end
  end
  local below = {}
  for _, call in ipairs(painted.text) do
    if call.y >= 104 then below[#below + 1] = call end
  end
  table.sort(below, function(a, b) return a.y < b.y end)
  return box, below
end

local box, below = moneyPaint(ballsOpen)
assert(box, "the money window was not painted")
assert(box.th == 3, "the money window holds one interior row, not " .. (box.th - 2))
assert(#below == 1, "the money window should carry the amount and nothing else, painted " .. #below)
assert(below[1].text == "¥1234", "wrong money line: " .. below[1].text)
-- Sized to the amount: five glyphs plus the two frame columns.
assert(box.tw == 7, "the money window is not sized to the amount: tw = " .. box.tw)
assert(box.tx + box.tw - 1 == ITEM_BOX_RIGHT_TX,
  "the money window is not flush with the item window's right edge: tx = " .. box.tx)
assert(below[1].x == (box.tx + 1) * 8 and below[1].y == MONEY_TEXT_Y,
  "the amount is not on the window's interior row")
-- It starts below the item window rather than redrawing its bottom border:
-- sharing tile 19,12 would replace that window's corner with this one's.
assert(box.ty == ITEM_BOX_BOTTOM_TY + 1,
  "the money window overlaps the item window's frame: ty = " .. box.ty)

-- Every pocket paints the amount, and the window stays on screen at the Gen 1
-- money cap, which is the widest it can get.
game.save.money = 999999
for pocket = 1, 7 do
  ballsOpen.modernBag.pocket = pocket
  ballsOpen:update(0)
  local capped, lines = moneyPaint(ballsOpen)
  assert(capped, "pocket " .. pocket .. " painted no money window")
  assert(#lines == 1 and lines[1].text == "¥999999",
    "pocket " .. pocket .. " painted the wrong money line")
  assert(capped.tx >= 0 and capped.tx + capped.tw <= 20,
    "the money window ran off the screen: tx = " .. capped.tx .. " tw = " .. capped.tw)
  -- Columns, not bytes: the ¥ is one glyph and two bytes.
  local cols = utf8.len(lines[1].text) or #lines[1].text
  assert(cols <= capped.tw - 2,
    ("%q is %d columns, over the %d the window holds"):format(lines[1].text, cols, capped.tw - 2))
end
game.save.money = 1234
ballsOpen.modernBag.pocket = 4
ballsOpen:update(0)

-- The sort mode is no longer spelled out on the Bag -- it is a row in the
-- TM/HM tools -- but it is still published for Gen1 Modern UI to present.
ballsOpen.modernBag.machineSort = "POWER_DESC"
ballsOpen:update(0)
assert(ballsOpen.modernBag.machineSortLabel == "POWER DESC",
  "wrong sort label: " .. tostring(ballsOpen.modernBag.machineSortLabel))
local _, sortLines = moneyPaint(ballsOpen)
assert(#sortLines == 1 and sortLines[1].text:find("¥", 1, true),
  "the TM/HM pocket painted more than the amount below the item window")
ballsOpen.modernBag.machineSort = "NUMBER"
ballsOpen:update(0)
assert(saved.last_pocket == "machines", "last-used pocket was not persisted")
optionValues.opening_pocket = "last"
local lastOpen = BagMenu.new(game, {})
assert(lastOpen.modernBag.pocket == 4, "LAST USED did not restore the saved pocket")

-- Scroll speed can be disabled or changed.
optionValues.hold_scroll_speed = "off"
local noRepeat = BagMenu.new(game, {})
assert(noRepeat.keyRepeat == false, "Hold Scroll Speed=OFF was ignored")
optionValues.hold_scroll_speed = "very_fast"
local veryFast = BagMenu.new(game, {})
assert(veryFast.keyRepeat == true and veryFast.repeatDelay == 6 and veryFast.repeatRate == 1,
  "VERY FAST hold-scroll timing is incorrect")

-- Restore test defaults for the remaining assertions.
optionValues.opening_pocket = "medicine"
optionValues.hold_scroll_speed = "fast"

-- Search remains available and resolves the item's real pocket.
local rows = mod.exports.search(game, "POT")
assert(#rows == 1 and rows[1].value == "POTION", "search failed")
assert(rows[1].modernPocket == 2, "search should return the medicine pocket")

print("gen1_modern_bag_test: ok")

-- TM/HM metadata uses move data and Generation I's type-based damage split.
local mega = assert(mod.exports.machineInfo(game, "TM_MEGA_PUNCH"), "machine metadata missing")
assert(mega.name == "MEGA PUNCH", "move name lookup failed")
assert(mega.typeLabel == "NORMAL", "move type lookup failed")
assert(mega.damageClass == "PHYSICAL", "normal attacks must be physical in Gen I")
assert(mod.exports.machineInfo(game, "TM_FLAMETHROWER").damageClass == "SPECIAL", "fire attacks must be special in Gen I")
assert(mod.exports.machineInfo(game, "TM_SWORDS_DANCE").damageClass == "STATUS", "zero-power moves must be status")

-- Dedicated filters search by move name, elemental type and damage class.
local machineRows = mod.exports.machineRows(game, { query = "FLAME", type = "ANY", damageClass = "ANY" }, "NUMBER")
assert(#machineRows == 1 and machineRows[1].value == "TM_FLAMETHROWER", "move-name filter failed")
machineRows = mod.exports.machineRows(game, { query = "", type = "WATER", damageClass = "SPECIAL" }, "NUMBER")
assert(#machineRows == 1 and machineRows[1].value == "HM_SURF", "type/class filters failed")
machineRows = mod.exports.machineRows(game, { query = "", type = "ANY", damageClass = "STATUS" }, "NUMBER")
assert(#machineRows == 1 and machineRows[1].value == "TM_SWORDS_DANCE", "status filter failed")

-- The TM/HM pocket shows move names and supports power ordering.
bag.modernBag.pocket = 4
bag:update(0)
assert(bag.items[1].label:find("HM03 SURF", 1, true), "machine row should include move name")
bag.modernBag.machineSort = "POWER_DESC"
bag:update(0)
assert(bag.items[1].modernMachine.power == 95, "power sorting did not put strongest moves first")
assert(bag.items[#bag.items].value == "TM_SWORDS_DANCE", "status move should sort last by descending power")

-- Pinning still wins over the selected power sort.
local swordsIndex
for i, row in ipairs(bag.items) do if row.value == "TM_SWORDS_DANCE" then swordsIndex = i end end
assert(swordsIndex, "swords dance missing")
bag.index = swordsIndex
pressed.start = true
bag:update(0)
tools = assert(stack:top(), "machine item tools did not open")
tools.opts.onChoose(tools.items[2], tools)
bag:update(0)
assert(bag.items[1].value == "TM_SWORDS_DANCE", "pinned machine must stay above power sorting")

-- Y / I opens the full move-information screen.
pressed.gen1_modern_bag_move_info = true
bag:update(0)
local infoScreen = assert(stack:top(), "move information screen did not open")
assert(infoScreen.info and infoScreen.info.moveId == "SWORDS_DANCE", "move information targeted the wrong machine")

-- Move Information was the last screen drawn as a bare white page: no frame,
-- and eleven lines on a 14px pitch the 8px font does not land on. It is now
-- the same framed window as the search keyboard, everything on the grid.
--
-- A 20x18 window's interior is columns 8..152 and rows 8..128.
local WIN_LEFT, WIN_RIGHT, WIN_TOP, WIN_BOTTOM = 8, 152, 8, 128

local function windowPaint(screen)
  painted.text, painted.codes, painted.boxes = {}, {}, {}
  screen:draw()
  assert(#painted.boxes == 1, "the screen should be one framed window")
  local frame = painted.boxes[1]
  assert(frame.tx == 0 and frame.ty == 0 and frame.tw == 20 and frame.th == 18,
    "the window does not frame the screen")
  -- Text is drawn black; every screen has to hand the colour back white or
  -- whatever draws next inherits the black. The no-data path used to escape
  -- through an early return that never did.
  assert(drawColorIsWhite(), "the screen left the draw colour set to its text colour")
  local rows = {}
  for _, call in ipairs(painted.text) do
    assert(call.y % 8 == 0, ("%q is off the 8px grid at y = %d"):format(call.text, call.y))
    assert(call.y >= WIN_TOP and call.y <= WIN_BOTTOM,
      ("%q is outside the window at y = %d"):format(call.text, call.y))
    assert(call.x >= WIN_LEFT, ("%q starts left of the window"):format(call.text))
    local right = call.x + (utf8.len(call.text) or #call.text) * 8
    assert(right <= WIN_RIGHT, ("%q overruns the window"):format(call.text))
    assert(rows[call.y] == nil, ("two lines share row %d"):format(call.y))
    rows[call.y] = call.text
  end
  return rows
end

local infoRows = windowPaint(infoScreen)
assert(infoRows[8] == "MOVE INFORMATION", "the title is not on the first interior row")
assert(infoRows[24] == "TM03  SWORDS DANCE", "wrong machine line: " .. tostring(infoRows[24]))
assert(infoRows[40] == "TYPE: NORMAL" and infoRows[48] == "CLASS: STATUS"
  and infoRows[56] == "POWER: --" and infoRows[64] == "ACCURACY: 100%"
  and infoRows[72] == "PP: 30", "the stat block is wrong")
assert(infoRows[88] == "EFFECT:" and infoRows[96] == "ATTACK UP2", "the effect block is wrong")
assert(infoRows[128] == "Y/I OR A/B BACK", "the way out is not on the last interior row")

-- A machine with no move data takes the same window, and hands the colour
-- back like every other path.
local savedInfo = infoScreen.info
infoScreen.info = nil
local blankRows = windowPaint(infoScreen)
assert(blankRows[24] == "NO MOVE DATA", "the no-data screen lost its message")
assert(blankRows[128] == "Y/I OR A/B BACK", "the no-data screen lost its way out")
infoScreen.info = savedInfo

stack:pop()

-- SELECT in the TM/HM pocket opens the dedicated filter/sort hub: it is that
-- pocket's search, and SELECT is the search key on every pocket.
pressed.select = true
bag:update(0)
local hub = assert(stack:top(), "TM/HM search hub did not open")
assert(hub.title == "TM HM SEARCH", "wrong TM/HM search title")
assert(hub.items[2].label:find("TYPE:", 1, true), "type filter missing")
assert(hub.items[3].label:find("CLASS:", 1, true), "damage-class filter missing")
assert(hub.items[4].label:find("SORT:", 1, true), "power sort missing")

-- Menus this mod opens are framed windows over the Bag, not the undecorated
-- white full-screen page ListMenu paints for itself. They are sized to their
-- own contents and anchored to the bottom-right corner.
local function popupPaint(menu)
  painted.text, painted.codes, painted.boxes = {}, {}, {}
  menu:draw()
  return painted.boxes[1], painted.text, painted.codes
end

assert(hub.isOpaque == false, "a popup menu must let the Bag draw underneath it")
local hubBox, hubText = popupPaint(hub)
assert(hubBox, "the TM/HM hub painted no window")
assert(hubBox.tx + hubBox.tw == 20 and hubBox.ty + hubBox.th == 18,
  "the popup is not anchored to the bottom-right corner")
assert(hubBox.tw < 20 or hubBox.th < 18, "the popup still covers the whole screen")
-- Frame, title row, blank row, then one row per option.
assert(hubBox.th == #hub.items + 4,
  "the window is not sized to its options: th = " .. hubBox.th)
assert(hubText[1].text == "TM HM SEARCH", "the popup did not draw its title")
-- The title is on the first interior row; the options start two rows below it,
-- one per row, indented by the cursor column.
local titleY = (hubBox.ty + 1) * 8
assert(hubText[1].y == titleY, "the title is not on the first interior row")
assert(hubText[2].y == titleY + 16, "the options do not start below a blank row")
assert(hubText[2].x == hubText[1].x + 8, "the options are not indented for the cursor")
for i = 2, #hubText do
  assert(hubText[i].y == titleY + 16 + (i - 2) * 8, "popup row " .. i .. " is off the grid")
  local right = hubText[i].x + (utf8.len(hubText[i].text) or #hubText[i].text) * 8
  assert(right <= (hubBox.tx + hubBox.tw - 1) * 8,
    ("popup row %q overruns the window"):format(hubText[i].text))
end

-- The search keyboard. 1.1.1 drew it as a bare white page and laid the
-- DEL/CLR/GO/EXIT row out on the same 16px pitch as the single-glyph letters,
-- so the four words were drawn on top of one another and read as "DECLBOEXIT".
bag.modernBag.pocket = 2
bag:update(0)
pressed.select = true
bag:update(0)
local keyboard = assert(stack:top(), "SELECT did not open Quick Search")
assert(keyboard.screenId == "ModernBagNicknameSearch", "SELECT opened the wrong screen")

painted.text, painted.codes, painted.boxes = {}, {}, {}
keyboard:draw()
assert(#painted.boxes == 1, "the keyboard should be one framed window")
local kb = painted.boxes[1]
assert(kb.tx == 0 and kb.ty == 0 and kb.tw == 20 and kb.th == 18,
  "the keyboard window does not frame the screen")

-- A 20x18 window's interior is columns 8..152 and rows 8..128.
local KB_LEFT, KB_RIGHT, KB_TOP, KB_BOTTOM = 8, 152, 8, 128
local function textRight(call)
  return call.x + (utf8.len(call.text) or #call.text) * 8
end

local byRow = {}
for _, call in ipairs(painted.text) do
  assert(call.y % 8 == 0, ("%q is off the 8px grid at y = %d"):format(call.text, call.y))
  assert(call.y >= KB_TOP and call.y <= KB_BOTTOM,
    ("%q is outside the window at y = %d"):format(call.text, call.y))
  assert(call.x >= KB_LEFT, ("%q starts left of the window"):format(call.text))
  assert(textRight(call) <= KB_RIGHT, ("%q overruns the window"):format(call.text))
  byRow[call.y] = byRow[call.y] or {}
  table.insert(byRow[call.y], call)
end

-- Nothing on any row may start before the word to its left has ended.
for y, calls in pairs(byRow) do
  table.sort(calls, function(a, b) return a.x < b.x end)
  for i = 2, #calls do
    assert(calls[i].x >= textRight(calls[i - 1]),
      ("%q and %q overlap on row %d"):format(calls[i - 1].text, calls[i].text, y))
  end
end

-- All four action words survive, on one row of their own.
local actions = {}
for _, call in ipairs(byRow[104] or {}) do actions[#actions + 1] = call.text end
table.sort(actions)
assert(table.concat(actions, " ") == "CLR DEL EXIT GO",
  "the action row is not DEL/CLR/GO/EXIT: " .. table.concat(actions, " "))

-- The letters keep a cell each, on the 16px pitch, with the cursor drawn in
-- the column to the left of the key it sits on.
local letters = byRow[40] or {}
table.sort(letters, function(a, b) return a.x < b.x end)
assert(#letters == 9 and letters[1].text == "A" and letters[9].text == "I",
  "the first keyboard row is not A-I")
for i, call in ipairs(letters) do
  assert(call.x == 16 + (i - 1) * 16, "letter " .. call.text .. " is off the cell pitch")
end
assert(#painted.codes == 1, "the keyboard should draw exactly one cursor")
assert(painted.codes[1].x == 8 and painted.codes[1].y == 40,
  "the cursor is not in the column left of the first key")
keyboard:close()

print("gen1_modern_bag_search_keyboard_test: ok")

print("gen1_modern_bag_tm_search_test: ok")

