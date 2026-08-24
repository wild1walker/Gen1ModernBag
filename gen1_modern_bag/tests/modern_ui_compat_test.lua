package.preload["src.inventory.Bag"] = function()
  local Bag = {}
  function Bag.order(save)
    save.bagOrder = save.bagOrder or {}
    return save.bagOrder
  end
  function Bag.isBadge(id) return false end
  function Bag.capacity() return 20 end
  function Bag.add(save, id, qty)
    save.inventory[id] = (save.inventory[id] or 0) + (qty or 1)
    return true
  end
  return Bag
end

package.preload["src.core.Sound"] = function()
  return { play = function() end }
end

package.preload["src.render.Font"] = function()
  local Font = {}
  function Font.split(text)
    local out = {}
    for _, cp in utf8.codes(tostring(text)) do out[#out + 1] = utf8.char(cp) end
    return out
  end
  function Font.width(text) return #Font.split(text) * 8 end
  function Font.draw() end
  function Font.drawCode() end
  function Font.drawBox() end
  return Font
end

-- src/ui/Menu.lua, the engine's framed menu widget.
package.preload["src.ui.Menu"] = function()
  local M = {}
  function M.new(game, items, opts)
    local self = { game = game, items = items or {}, opts = opts or {} }
    self.title = self.opts.title
    function self:close()
      if game.stack:top() == self then game.stack:pop() end
    end
    function self:choose(i)
      local item = self.items[i]
      assert(item, "no menu row " .. tostring(i))
      if not item.keepOpen then self:close() end
      if item.onSelect then item.onSelect() end
      return item
    end
    return self
  end
  return M
end

package.preload["src.ui.ListMenu"] = function()
  local ListMenu = {}
  function ListMenu.new(game, title, items, opts)
    local list = {
      game = game, title = title, items = items or {}, opts = opts or {},
      index = 1, scroll = 0, rows = 7, pageJump = opts and opts.pageJump,
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
      screenId = "BagMenu",
      game = game, items = {}, index = 1, scroll = 0, rows = 7,
      update = function() end, draw = function() end, close = function() end,
    }
  end
  return BagMenu
end

local adapterSpec
local modernExports = {
  compatibilityApiVersion = 1,
  registerAdapter = function(spec)
    adapterSpec = spec
    return true
  end,
}

local saved = {}
local ready
local mod = {
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
function mod.find(id)
  if id == "gen1_modern_ui" then return { exports = modernExports } end
  if id == "gen1_modern_bag" then return { exports = mod.exports } end
end

local pressed = {}
local input = {}
function input:wasPressed(name)
  local value = pressed[name]
  pressed[name] = false
  return value or false
end
function input:sourcePress(name) pressed[name] = true end
function input:sourceRelease(name) pressed[name] = false end
function input:keypressed() end
function input:keyreleased() end
function input:gamepadpressed() end
function input:gamepadreleased() end

local stack = { items = {} }
function stack:push(value) self.items[#self.items + 1] = value end
function stack:pop() return table.remove(self.items) end
function stack:top() return self.items[#self.items] end

local game = {
  save = {
    inventory = { POTION = 2, TM_FLAMETHROWER = 1 },
    bagOrder = { "POTION", "TM_FLAMETHROWER" },
  },
  data = {
    constants = {},
    items = {
      POTION = { name = "POTION", effect = "HEAL_HP" },
      TM_FLAMETHROWER = {
        name = "TM35",
        machine = { kind = "TM", number = 35, move = "FLAMETHROWER" },
      },
    },
    moves = {
      FLAMETHROWER = {
        name = "FLAMETHROWER", type = "FIRE", power = 95,
        accuracy = 100, pp = 15, effect = "BURN_SIDE_EFFECT1",
      },
    },
    types = { FIRE = { name = "FIRE" } },
  },
  input = input,
  stack = stack,
}

local entry = assert(loadfile("main.lua"))()
entry(mod)
assert(adapterSpec, "Modern UI adapter was not registered at load")
assert(adapterSpec.owner == "gen1_modern_bag", "wrong adapter owner")
assert(adapterSpec.version == "1.6.0", "wrong adapter version")
local contract = assert(mod.exports.gen1ModernUi, "missing gen1ModernUi export")
assert(contract.apiVersion == 1, "wrong compatibility API")
assert(type(ready) == "function", "game.ready hook missing")
ready({ game = game })

local infoDesc = assert(contract.screens.gen1_modern_bag_move_info,
  "Move Information adapter missing")
assert(contract.screens.gen1_modern_bag_quick_search == nil,
  "Quick Search should use Modern UI's native naming-keyboard presenter")
assert(contract.screens.gen1_modern_bag_machine_name_search == nil,
  "there is no TM/HM move-name search any more: the one keyboard covers it")
assert(infoDesc.canSuppressNative, "Move Information screen must be suppressible")

local BagMenu = require("src.ui.BagMenu")
local bag = BagMenu.new(game, {})
assert(bag.modernBag, "bag decoration missing")
assert(bag.modernBag.searchAvailable == true, "search availability marker missing")
assert(bag.modernBag.startActionLabel == "TOOLS", "item tools label missing")
assert(bag.modernBag.selectActionLabel == "SEARCH", "normal pocket search label missing")

-- Non-TM pocket SELECT opens a real grid-keyboard search state.  Its screen
-- id contains "Nickname" and exposes glyphs/grid/row/col so Gen1 Modern UI
-- 0.8.1+ recognizes it through the native naming-keyboard presenter.
pressed.select = true
bag:update(0)
local quick = assert(stack:top(), "Quick Search did not open")
assert(quick.screenId == "ModernBagNicknameSearch", "Quick Search screen id missing")
assert(type(quick.grid) == "function" and type(quick.glyphs) == "table",
  "Quick Search does not expose naming-keyboard state")
assert(quick.modernBagSearchKeyboard == true, "Quick Search keyboard marker missing")
local grid = quick:grid()
assert(grid[1][1] == "A" and grid[5][3] == "GO", "Quick Search grid mismatch")
pressed.right = true
quick:update(0)
assert(quick.col == 2, "Quick Search right input did not move key")
pressed.a = true
quick:update(0)
assert(quick.query == "B" and quick.glyphs[1] == "B",
  "Quick Search selected key was not entered")
pressed.b = true
quick:update(0)
assert(quick.query == "", "Quick Search B did not delete")
pressed.b = true
quick:update(0)
assert(stack:top() ~= quick, "Quick Search did not close on B with empty query")

-- TM/HM pocket Y/I opens the custom move information screen.
bag.modernBag.pocket = 4
bag:update(0)
assert(bag.modernBag.startActionLabel == "TOOLS", "TM/HM item tools label missing")
-- One search on every pocket, so one label for it.
assert(bag.modernBag.selectActionLabel == "SEARCH", "TM/HM search label missing")
assert(bag.items[1] and bag.items[1].value == "TM_FLAMETHROWER",
  "TM/HM pocket did not refresh")
pressed.gen1_modern_bag_move_info = true
bag:update(0)
local info = assert(stack:top(), "Move Information did not open")
assert(info.screenId == "ModernBagMoveInfo", "Move Information screen id missing")
assert(infoDesc.match(info), "Move Information adapter did not match")
local infoModel = infoDesc.model(game, info)
assert(infoModel.rows[1].label:find("FLAMETHROWER", 1, true),
  "Move Information move header missing")
assert(infoModel.rows[2].value == "FIRE", "Move Information type missing")
assert(infoDesc.actions.back(game, info), "Move Information back failed")
assert(stack:top() ~= info, "Move Information did not close")

-- TM/HM pocket SELECT opens the same grid keyboard as every other pocket.
-- There is no separate move-name keyboard any more: a machine answers to its
-- move, that move's type and its damage class from the one search box.
pressed.select = true
bag:update(0)
local machineSearch = assert(stack:top(), "SELECT did not open a search in TM/HM")
assert(machineSearch.screenId == "ModernBagNicknameSearch",
  "TM/HM opened its own screen again: " .. tostring(machineSearch.screenId))
assert(type(machineSearch.grid) == "function" and type(machineSearch.glyphs) == "table",
  "the search does not expose naming-keyboard state")
local machineGrid = machineSearch:grid()
assert(#machineGrid == 5, "the keyboard grid is not five rows")
assert(machineGrid[5][3] == "GO", "the action row moved")
machineSearch:close()

assert(mod.exports.ensureModernUiAdapter(), "adapter retry export failed")
assert(adapterSpec.version == "1.6.0", "adapter retry version mismatch")

print("gen1_modern_bag modern ui compatibility ok")
