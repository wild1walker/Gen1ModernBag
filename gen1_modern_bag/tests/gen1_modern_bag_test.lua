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
local painted = { text = {}, codes = {}, boxes = {}, clears = {} }
local function resetPaint()
  painted.text, painted.codes, painted.boxes, painted.clears = {}, {}, {}, {}
end

-- A label on a border row is only legible because the line is knocked out
-- under it first, so the knock-outs have to be observable too.
local function clearedAt(x, y)
  for _, c in ipairs(painted.clears) do
    if y >= c.y and y < c.y + c.h and x >= c.x and x < c.x + c.w then return true end
  end
  return false
end
local function clearsOnRow(y)
  local n = 0
  for _, c in ipairs(painted.clears) do
    if c.y == y then n = n + 1 end
  end
  return n
end
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
function love.graphics.rectangle(_, x, y, w, h)
  painted.clears[#painted.clears + 1] = { x = x, y = y, w = w, h = h }
end

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
  -- The engine's own glyph split: one entry per drawn tile.
  function Font.split(text)
    local out = {}
    for _, cp in utf8.codes(tostring(text)) do out[#out + 1] = utf8.char(cp) end
    return out
  end
  function Font.width(text)
    return #Font.split(text) * 8
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

-- src/ui/Menu.lua, the engine's framed menu widget. It draws its own frame,
-- title and cursor and owns the input, so a test can only see what it was
-- handed. Modelled on the stub the shipped mods that use it carry.
package.preload["src.ui.Menu"] = function()
  local M = {}
  function M.new(game, items, opts)
    local self = { game = game, items = items or {}, opts = opts or {} }
    self.title = self.opts.title
    function self:close()
      if game.stack:top() == self then game.stack:pop() end
    end
    -- Menu closes itself around onSelect unless the item asks to stay open.
    -- Nothing here depends on which side of onSelect that happens.
    function self:choose(i)
      local item = self.items[i]
      assert(item, "no menu row " .. tostring(i))
      if not item.keepOpen then self:close() end
      if item.onSelect then item.onSelect() end
      return item
    end
    -- The widget paints the frame, the rows and the cursor. A title is not
    -- handed to it any more, so anything drawn here comes from the mod.
    function self:draw() end
    return self
  end
  return M
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
-- No title on the item tools: four rows that name themselves do not need one.
assert(tools.opts.title == nil, "the item tools grew a title again")
assert(tools.items[1].label == "ADD FAVORITE")
tools:choose(1)
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
tools:choose(2)
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
--
-- It sits on the item window's own top border, which is where Gen 1 titles a
-- window. LIST_MENU_BOX is tiles 4,2-19,12, so that border is the row at
-- y = 16.
-- The frame's outer white margin is that tile's first pixel row, and Gen 1
-- glyphs ink rows 0 to 6 of their cell, so the label is drawn a pixel lower to
-- stay off it. The knock-out stays on the tile.
local ITEM_BOX_TOP_Y = 16
local WINDOW_EDGE = 1
local HEADER_TEXT_Y = ITEM_BOX_TOP_Y + WINDOW_EDGE

local function headerPaint(list)
  resetPaint()
  list:draw()
  local name
  for _, call in ipairs(painted.text) do
    if call.y == HEADER_TEXT_Y then name = call end
  end
  local arrows = {}
  for _, call in ipairs(painted.codes) do
    if call.y == HEADER_TEXT_Y then arrows[#arrows + 1] = call end
  end
  table.sort(arrows, function(a, b) return a.x < b.x end)
  return name, arrows
end

local name, arrows = headerPaint(ballsOpen)
assert(name, "the pocket header painted no name on the border, a pixel down")
-- Nothing may sit on the margin itself.
for _, call in ipairs(painted.text) do
  assert(call.y ~= ITEM_BOX_TOP_Y,
    ("%q sits on the frame's outer white margin"):format(call.text))
end
assert(name.text == "BALLS", "wrong pocket name: " .. tostring(name.text))
-- Nothing else is on that border. Up to 1.3.1 the Left/Right arrows took the
-- outermost column at each end, which left a nine-letter pocket name a single
-- column of rule to sit in.
assert(#arrows == 0, "the pocket header still paints arrows")

-- Centred between the corners, on the 8px grid the rest of the box sits on.
-- The fourteen columns between them are the label's, and BALLS is five of
-- them, so it starts four columns in: x = 40 + 32.
assert(name.x == 72, "pocket name is not centred: x = " .. tostring(name.x))

-- The border line is knocked out under the label and survives either side, so
-- the line runs up to it and continues after it. Without the knock-out the
-- line would strike through the letters: glyphs are drawn as a mask, in
-- whatever colour is set.
assert(clearsOnRow(ITEM_BOX_TOP_Y) == 1,
  "expected one knock-out, got " .. clearsOnRow(ITEM_BOX_TOP_Y))
assert(clearedAt(72, ITEM_BOX_TOP_Y), "the pocket name was drawn onto the border line")
-- The knock-out runs a tile past each end of the name, so the rule stops
-- short of the letters instead of ending flush against them. Knocking out
-- exactly the text's width is what src/ui/Menu.lua does with its own title,
-- and it is what makes the frame look like it is touching the letters.
local nameRight = name.x + (utf8.len(name.text) or #name.text) * 8
assert(clearedAt(name.x - 8, ITEM_BOX_TOP_Y),
  "the rule runs up flush against the first letter of the pocket name")
assert(clearedAt(nameRight, ITEM_BOX_TOP_Y),
  "the rule restarts flush against the last letter of the pocket name")
-- And no further: the rule still survives either side of that clearance.
assert(not clearedAt(name.x - 16, ITEM_BOX_TOP_Y),
  "the name's knock-out ran past its own clearance")
assert(not clearedAt(nameRight + 8, ITEM_BOX_TOP_Y),
  "the name's knock-out ran past its own clearance")
-- Which the longest pocket labels now get too: without the arrows there are
-- four spare columns even for a nine-letter name.
for _, longPocket in ipairs({ 1, 6 }) do        -- FAVORITES, KEY ITEMS
  ballsOpen.modernBag.pocket = longPocket
  ballsOpen:update(0)
  local longName = headerPaint(ballsOpen)
  local right = longName.x + (utf8.len(longName.text) or 0) * 8
  assert(utf8.len(longName.text) == 9, "expected a nine-letter pocket name")
  assert(not clearedAt(longName.x - 16, ITEM_BOX_TOP_Y)
    and not clearedAt(right + 8, ITEM_BOX_TOP_Y),
    ("%q leaves no rule either side of it"):format(longName.text))
end
ballsOpen.modernBag.pocket = 3
ballsOpen:update(0)

-- A pocket name is trimmed to leave room for its own clearance, not just to
-- the space between the corners: the label has to fit tw - 4 tiles, or its
-- padded run would be clamped and lose the clearance at one end. No stock
-- label is long enough to tell the two budgets apart, but a font mod with
-- wider glyphs is, so measure with one.
local ITEM_BOX_TW = 16
local Font = require("src.render.Font")
local realWidth = Font.width
Font.width = function(text) return #Font.split(text) * 16 end
ballsOpen.modernBag.pocket = 1          -- FAVORITES, the longest label
local wideName = headerPaint(ballsOpen)
assert(wideName, "the header painted nothing with a wide font")
assert(Font.width(wideName.text) <= (ITEM_BOX_TW - 4) * 8,
  ("%q is %dpx, over the %dpx that leaves room for its clearance")
    :format(wideName.text, Font.width(wideName.text), (ITEM_BOX_TW - 4) * 8))
Font.width = realWidth
ballsOpen.modernBag.pocket = 3
ballsOpen:update(0)
assert(ballsOpen.title == "BALLS",
  "wrong pocket title: " .. tostring(ballsOpen.title))

-- LAST USED remembers pocket changes.
pressed.right = true
ballsOpen:update(0)
assert(ballsOpen.modernBag.pocket == 4, "right pocket switch failed")
name = headerPaint(ballsOpen)
assert(name and name.text == "TM/HM",
  "the pocket header did not follow the pocket switch: " .. tostring(name and name.text))
assert(ballsOpen.title == "TM/HM",
  "pocket title did not follow the pocket switch: " .. tostring(ballsOpen.title))

-- The money is the header's twin, on the item window's other border. 1.1.1
-- drew it in the standard bottom text box -- a full-width white bar carrying
-- the amount and a legend for START and SELECT; 1.2.0 dropped the legend and
-- gave the amount a little window of its own hanging under the corner. It is
-- now on the bottom border itself, right-aligned, so there is no second frame
-- at all.
--
-- LIST_MENU_BOX ends on tile row 12, so that border is the row at y = 96, and
-- its last column before the corner ends at x = 152.
local MONEY_Y = 96
local MONEY_RIGHT_X = 144

local function moneyPaint(list)
  resetPaint()
  list:draw()
  local amount
  local below = {}
  for _, call in ipairs(painted.text) do
    if call.y == MONEY_Y then amount = call end
    if call.y > MONEY_Y then below[#below + 1] = call end
  end
  return amount, below
end

local amount, below = moneyPaint(ballsOpen)
assert(amount, "the money was not painted")
assert(amount.text == "¥1234", "wrong money line: " .. amount.text)
-- Right-aligned, stopping one column short of the corner so the tile between
-- the two is the amount's clearance.
assert(amount.x + (utf8.len(amount.text) or #amount.text) * 8 == MONEY_RIGHT_X,
  "the money is not right-aligned in the border: x = " .. amount.x)
-- No shift on a bottom border: its margin is the tile's last pixel row, which
-- is the row Gen 1 glyphs already leave empty.
assert(amount.y == MONEY_Y, "the money was shifted off its border row")
assert(clearedAt(amount.x, MONEY_Y), "the money was drawn onto the border line")
assert(clearsOnRow(MONEY_Y) == 1, "the money knocked out more than one run")
assert(clearedAt(amount.x - 8, MONEY_Y),
  "the rule runs up flush against the first digit")
assert(clearedAt(MONEY_RIGHT_X, MONEY_Y),
  "the corner glyph sits flush against the last digit")
assert(not clearedAt(MONEY_RIGHT_X + 8, MONEY_Y),
  "the money's knock-out reached the corner glyph")
-- Nothing hangs below the item window any more: no second frame, no legend.
assert(#below == 0, "something is still drawn below the item window")
assert(#painted.boxes == 0, "the Bag drew a window of its own again")

-- Every pocket paints the amount, and it stays inside the window at the Gen 1
-- money cap, which is the widest it can get.
game.save.money = 999999
for pocket = 1, 7 do
  ballsOpen.modernBag.pocket = pocket
  ballsOpen:update(0)
  local capped, extra = moneyPaint(ballsOpen)
  assert(capped and capped.text == "¥999999",
    "pocket " .. pocket .. " painted the wrong money line")
  assert(#extra == 0, "pocket " .. pocket .. " drew below the item window")
  -- Its clearance starts a column earlier, and x = 40 is the frame's own.
  assert(capped.x >= 48, "the money ran past the window's left edge: x = " .. capped.x)
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
local sortAmount, sortExtra = moneyPaint(ballsOpen)
assert(sortAmount and sortAmount.text:find("¥", 1, true) and #sortExtra == 0,
  "the TM/HM pocket painted more than the amount on the window's borders")
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
tools:choose(2)
bag:update(0)
assert(bag.items[1].value == "TM_SWORDS_DANCE", "pinned machine must stay above power sorting")

-- Y / I opens the full move-information screen.
pressed.gen1_modern_bag_move_info = true
bag:update(0)
local infoScreen = assert(stack:top(), "move information screen did not open")
assert(infoScreen.info and infoScreen.info.moveId == "SWORDS_DANCE", "move information targeted the wrong machine")

-- Move Information was the last screen drawn as a bare white page: no frame,
-- and eleven lines on a 14px pitch the 8px font does not land on. It is now
-- the same framed window as the search keyboard, titled on its top border,
-- everything on the grid.
--
-- A 20x18 window's top border is the row at y = 0; its interior is columns
-- 8..152 and rows 8..128.
local WIN_LEFT, WIN_RIGHT, WIN_TOP, WIN_BOTTOM = 8, 152, 8, 128
local WIN_BORDER_Y = 0

local function windowPaint(screen)
  resetPaint()
  screen:draw()
  assert(#painted.boxes == 1, "the screen should be one framed window")
  local frame = painted.boxes[1]
  assert(frame.tx == 0 and frame.ty == 0 and frame.tw == 20 and frame.th == 18,
    "the window does not frame the screen")
  -- The title is on that border, and the line is knocked out under it.
  local title
  for _, call in ipairs(painted.text) do
    if call.y == WIN_BORDER_Y + WINDOW_EDGE then title = call end
  end
  assert(title, "the window is not titled on its top border, a pixel down")
  assert(clearedAt(title.x, WIN_BORDER_Y), "the title was drawn onto the border line")
  -- A tile of clearance at each end, so the rule stops short of the letters.
  local titleRight = title.x + (utf8.len(title.text) or #title.text) * 8
  assert(clearedAt(title.x - 8, WIN_BORDER_Y),
    "the rule runs up flush against the first letter of the title")
  assert(clearedAt(titleRight, WIN_BORDER_Y),
    "the rule restarts flush against the last letter of the title")
  -- Never onto the corner glyphs, which are the columns at x = 0 and x = 152.
  assert(not clearedAt(0, WIN_BORDER_Y) and not clearedAt(152, WIN_BORDER_Y),
    "the title's knock-out rubbed out a corner glyph")
  -- Text is drawn black; every screen has to hand the colour back white or
  -- whatever draws next inherits the black. The no-data path used to escape
  -- through an early return that never did.
  assert(drawColorIsWhite(), "the screen left the draw colour set to its text colour")
  local rows = { [WIN_BORDER_Y] = title.text }
  for _, call in ipairs(painted.text) do
    -- The border label is the one line deliberately off the grid, by the pixel
    -- that keeps it clear of the frame's margin.
    local onBorder = call.y == WIN_BORDER_Y + WINDOW_EDGE
    assert(onBorder or call.y % 8 == 0,
      ("%q is off the 8px grid at y = %d"):format(call.text, call.y))
    assert(onBorder or (call.y >= WIN_TOP and call.y <= WIN_BOTTOM),
      ("%q is outside the window at y = %d"):format(call.text, call.y))
    assert(call.x >= WIN_LEFT, ("%q starts left of the window"):format(call.text))
    local right = call.x + (utf8.len(call.text) or #call.text) * 8
    assert(right <= WIN_RIGHT, ("%q overruns the window"):format(call.text))
    assert(onBorder or rows[call.y] == nil, ("two lines share row %d"):format(call.y))
    rows[call.y] = call.text
  end
  return rows
end

local infoRows = windowPaint(infoScreen)
assert(infoRows[0] == "MOVE INFORMATION", "wrong window title: " .. tostring(infoRows[0]))
assert(infoRows[8] == "TM03  SWORDS DANCE", "wrong machine line: " .. tostring(infoRows[8]))
assert(infoRows[24] == "TYPE: NORMAL" and infoRows[32] == "CLASS: STATUS"
  and infoRows[40] == "POWER: --" and infoRows[48] == "ACCURACY: 100%"
  and infoRows[56] == "PP: 30", "the stat block is wrong")
assert(infoRows[72] == "EFFECT:" and infoRows[80] == "ATTACK UP2", "the effect block is wrong")
assert(infoRows[128] == "Y/I OR A/B BACK", "the way out is not on the last interior row")

-- A machine with no move data takes the same window, and hands the colour
-- back like every other path.
local savedInfo = infoScreen.info
infoScreen.info = nil
local blankRows = windowPaint(infoScreen)
assert(blankRows[8] == "NO MOVE DATA", "the no-data screen lost its message")
assert(blankRows[128] == "Y/I OR A/B BACK", "the no-data screen lost its way out")
infoScreen.info = savedInfo

stack:pop()

-- SELECT in the TM/HM pocket opens the dedicated filter/sort hub: it is that
-- pocket's search, and SELECT is the search key on every pocket.
pressed.select = true
bag:update(0)
local hub = assert(stack:top(), "TM/HM search hub did not open")
assert(hub.opts.title == nil, "the hub title was handed to Menu")
assert(hub.items[1].label:find("NAME:", 1, true), "move-name filter missing")
assert(hub.items[2].label:find("TYPE:", 1, true), "type filter missing")
assert(hub.items[3].label:find("CLASS:", 1, true), "damage-class filter missing")
assert(hub.items[4].label:find("SORT:", 1, true), "power sort missing")

-- Menus this mod opens are src/ui/Menu.lua, the engine's own framed menu
-- widget: it draws the frame, the rows, the cursor and the more-arrow. What a
-- test can check is what it was handed -- the geometry asked for and the rows
-- -- plus the title, which is drawn by the mod rather than handed over.
local MENU_LABEL_MARGIN = 3   -- Menu grows tw to the widest label + 3

local function menuTiles(text) return utf8.len(text) or #text end

-- The title is not given to Menu: Menu would draw it at the border tile's own
-- y and knock out exactly its width, putting ink on the frame's outer margin
-- and ending the rule flush against the letters. It goes through the mod's own
-- drawBorderLabel instead -- a pixel lower, a tile of clearance at each end.
local function assertBorderTitle(menu, name)
  assert(menu.opts.title == nil,
    name .. "'s title was handed to Menu, which draws it on the margin")
  resetPaint()
  menu:draw()
  local borderY = menu.opts.ty * 8
  local title
  for _, call in ipairs(painted.text) do
    if call.y == borderY + WINDOW_EDGE then title = call end
    assert(call.y ~= borderY,
      ("%q sits on the frame's outer white margin"):format(call.text))
  end
  assert(title and title.text == name,
    ("%s is not titled on its border: %s"):format(name, tostring(title and title.text)))
  local right = title.x + menuTiles(title.text) * 8
  assert(clearedAt(title.x - 8, borderY) and clearedAt(right, borderY),
    name .. "'s title has no clearance from the rule")
  assert(not clearedAt(menu.opts.tx * 8, borderY)
    and not clearedAt((menu.opts.tx + menu.opts.tw - 1) * 8, borderY),
    name .. "'s title rubbed out a corner glyph")
  -- Which needs the width to have been asked for with the clearance counted.
  assert(menuTiles(title.text) <= menu.opts.tw - 4,
    ("%s is %d tiles wide, too narrow for its title plus clearance")
      :format(name, menu.opts.tw))
end

local function assertUntitled(menu, name)
  assert(menu.opts.title == nil, name .. " was handed a title")
  resetPaint()
  menu:draw()
  assert(#painted.text == 0, name .. " drew a title of its own")
end

-- And a label wider than the width asked for would grow the menu off the
-- screen, because Menu sizes itself from the widest label.
local function assertFits(menu, name)
  assert(menu.opts.tw <= 20 and menu.opts.tx >= 0
    and menu.opts.tx + menu.opts.tw == 20,
    name .. " is not anchored inside the right edge of the screen")
  for i, row in ipairs(menu.items) do
    assert(menuTiles(row.label) <= menu.opts.tw - MENU_LABEL_MARGIN,
      ("%s row %d (%q) would grow the menu past the width it asked for")
        :format(name, i, row.label))
  end
end

assertBorderTitle(hub, "TM/HM SEARCH")
assertFits(hub, "TM/HM SEARCH")
assert(#hub.items == 7, "the TM/HM hub is not seven rows")
-- The rows that open a picker have to leave the hub standing under it.
for i = 1, 4 do
  assert(hub.items[i].keepOpen, "TM/HM hub row " .. i .. " closes the hub behind its picker")
end
assert(not hub.items[5].keepOpen, "the RESULTS row should close the hub")
assert(hub.items[7].onSelect == nil, "CANCEL should do nothing but close")

-- The item tools carry no title at all.
pressed.start = true
bag:update(0)
local optionsMenu = assert(stack:top(), "START did not open ITEM OPTIONS")
assertUntitled(optionsMenu, "ITEM OPTIONS")
assertFits(optionsMenu, "ITEM OPTIONS")
optionsMenu:close()

-- Labels too wide for the menu are trimmed by glyphs, not by bytes: a label
-- can carry a multi-byte character -- POKe with the accent, the currency sign
-- -- or a Gen 1 control code, and half of one of those is not a character.
-- The NAME row is the one that grows, because it carries the query.
local liveFilters = bag.modernBag.machineFilters
liveFilters.query = ("\u{00e9}"):rep(30)
hub:choose(2)                       -- opens the TYPE picker, and relabels
assert(stack:top() ~= hub, "the TYPE picker did not open")
stack:top():close()
assert(utf8.len(hub.items[1].label),
  "a label was trimmed mid-character: " .. hub.items[1].label)
assertFits(hub, "TM/HM SEARCH")
liveFilters.query = ""
hub:choose(2)
stack:top():close()

-- The search keyboard. 1.1.1 drew it as a bare white page and laid the
-- DEL/CLR/GO/EXIT row out on the same 16px pitch as the single-glyph letters,
-- so the four words were drawn on top of one another and read as "DECLBOEXIT".
bag.modernBag.pocket = 2
bag:update(0)
pressed.select = true
bag:update(0)
local keyboard = assert(stack:top(), "SELECT did not open Quick Search")
assert(keyboard.screenId == "ModernBagNicknameSearch", "SELECT opened the wrong screen")

resetPaint()
keyboard:draw()
assert(#painted.boxes == 1, "the keyboard should be one framed window")
local kb = painted.boxes[1]
assert(kb.tx == 0 and kb.ty == 0 and kb.tw == 20 and kb.th == 18,
  "the keyboard window does not frame the screen")

-- A 20x18 window's top border is the row at y = 0; its interior is columns
-- 8..152 and rows 8..128.
local KB_LEFT, KB_RIGHT, KB_TOP, KB_BOTTOM = 8, 152, 8, 128
local function textRight(call)
  return call.x + (utf8.len(call.text) or #call.text) * 8
end

-- The keyboard is titled on its border like every other window here, a pixel
-- down so it clears the frame's outer white margin.
local kbTitle
for _, call in ipairs(painted.text) do
  if call.y == WINDOW_EDGE then kbTitle = call end
end
assert(kbTitle and kbTitle.text == "QUICK SEARCH",
  "the keyboard is not titled on its top border: " .. tostring(kbTitle and kbTitle.text))
assert(clearedAt(kbTitle.x, 0), "the keyboard title was drawn onto the border line")

-- FIND sits a row below the window's first interior row, so the query is not
-- crowded up against the title on the border above it. The match count is
-- gone: the results page shows the matches themselves.
local findLine, firstRowLine
for _, call in ipairs(painted.text) do
  if call.y == 16 then findLine = call end
  if call.y == 8 then firstRowLine = call end
  assert(not call.text:find("MATCHES", 1, true), "the match count is still drawn")
end
assert(findLine and findLine.text:find("FIND:", 1, true),
  "FIND is not on the row below the window's first: " .. tostring(findLine and findLine.text))
assert(not firstRowLine, "something is still drawn tight under the title")
for _, call in ipairs(painted.text) do
  assert(call.y ~= 0, ("%q sits on the frame's outer white margin"):format(call.text))
end

local byRow = {}
for _, call in ipairs(painted.text) do
  local onBorder = call.y == WINDOW_EDGE
  assert(onBorder or call.y % 8 == 0,
    ("%q is off the 8px grid at y = %d"):format(call.text, call.y))
  assert(onBorder or (call.y >= KB_TOP and call.y <= KB_BOTTOM),
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

-- A title too wide for its window still cannot rub out a corner glyph: the
-- clearance is clamped to the columns between them. A font mod with wider
-- glyphs, or a translation, is how a title gets there.
local realTitle = keyboard.title
keyboard.title = ("W"):rep(20)
resetPaint()
keyboard:draw()
assert(not clearedAt(0, 0) and not clearedAt(152, 0),
  "an over-wide title rubbed out a corner glyph")
-- Still a pixel clear of the margin, however wide it got.
for _, call in ipairs(painted.text) do
  assert(call.y ~= 0, "an over-wide title sat on the frame's outer white margin")
end
keyboard.title = realTitle
assert(painted.codes[1].x == 8 and painted.codes[1].y == 40,
  "the cursor is not in the column left of the first key")
keyboard:close()

print("gen1_modern_bag_search_keyboard_test: ok")

print("gen1_modern_bag_tm_search_test: ok")

-- The results page.
--
-- A search used to push a ListMenu of its own -- one more undecorated
-- full-screen page. It now hands its matches to the Bag, which grows a
-- RESULTS page for them, so they are read in the item window with the pocket
-- header, the counts and the row markers like everything else.
while stack:top() do stack:pop() end
bag.modernBag.pocket = 2
bag:update(0)

-- Before a search there is no such page, and Left/Right cannot reach it.
local ringSeen = {}
for _ = 1, 7 do
  pressed.right = true
  bag:update(0)
  ringSeen[bag.title] = true
end
assert(not ringSeen.RESULTS, "the results page is in the ring before any search")
assert(ringSeen.MEDICINE and ringSeen["TM/HM"] and ringSeen.FAVORITES,
  "stepping over the hidden page skipped a real pocket")

bag.modernBag.pocket = 2
bag:update(0)
pressed.select = true
bag:update(0)
local search = assert(stack:top(), "SELECT did not open Quick Search")
search.glyphs = { "P", "O", "T" }
pressed.start = true
search:update(0)

assert(stack:top() ~= search, "the keyboard stayed open behind the results")
assert(stack:top() == nil, "the search pushed a page of its own instead of using the Bag")
assert(bag.title == "RESULTS", "the Bag is not on the results page: " .. tostring(bag.title))
assert(#bag.items == 1 and bag.items[1].value == "POTION",
  "the results page does not hold the matches")
assert(bag.items[1].right:find("x1", 1, true), "the results page lost the count")
assert(bag.items[1].right:find("PF", 1, true), "the results page lost the row markers")

-- Now it is in the ring, and Left comes back to it.
pressed.right = true
bag:update(0)
assert(bag.title ~= "RESULTS", "Right did not leave the results page")
pressed.left = true
bag:update(0)
assert(bag.title == "RESULTS", "Left did not come back to the results page")

-- It is rebuilt from the search rather than held as a snapshot, so it follows
-- the Bag as items are used up and reacquired.
game.save.inventory.POTION = nil
bag:update(0)
assert(#bag.items == 0, "the results page kept an item that had left the Bag")
-- Reacquiring goes through Bag.add, which the mod patches to put the id back
-- in the Bag order itself.
require("src.inventory.Bag").add(game.save, "POTION", 1)
bag:update(0)
assert(#bag.items == 1, "the results page did not pick the item back up")

-- LAST USED never reopens the Bag on it: it is empty by then.
assert(saved.last_pocket ~= "results", "a transient page was saved as the last pocket")
local reopenedAfterSearch = BagMenu.new(game, {})
assert(reopenedAfterSearch.title ~= "RESULTS", "a reopened Bag came back on the results page")
assert(reopenedAfterSearch.modernBag.results == nil, "the results survived reopening the Bag")

-- And it is not one of the pockets an item can be filed in.
local ringPockets = mod.exports.pockets()
assert(#ringPockets == 7, "the results page leaked into the pocket export")
for _, entry in ipairs(ringPockets) do
  assert(entry.id ~= "results", "the results page leaked into the pocket export")
end

-- The TM/HM filters fill the same page instead of a list of their own.
bag.modernBag.pocket = 4
bag:update(0)
pressed.select = true
bag:update(0)
local filters = assert(stack:top(), "the TM/HM hub did not open")
local showRowIndex
for i, row in ipairs(filters.items) do
  if row.label:find("RESULTS", 1, true) then showRowIndex = i end
end
assert(showRowIndex, "the RESULTS row is missing from the TM/HM hub")
filters:choose(showRowIndex)
assert(stack:top() == nil, "the TM/HM filters pushed a page of their own")
assert(bag.title == "RESULTS", "the TM/HM filters did not fill the results page")
assert(#bag.items == 4, "wrong TM/HM result count: " .. #bag.items)
for _, row in ipairs(bag.items) do
  assert(row.modernMachine, "a TM/HM result lost its machine data")
end

-- Y/I reads a machine wherever it is reached, not only in the TM/HM pocket,
-- so it still answers on the results page.
pressed.gen1_modern_bag_move_info = true
bag:update(0)
local resultInfo = assert(stack:top(), "Y/I did not open move information from the results")
assert(resultInfo.screenId == "ModernBagMoveInfo", "Y/I opened the wrong screen")
stack:pop()

print("gen1_modern_bag_results_page_test: ok")
