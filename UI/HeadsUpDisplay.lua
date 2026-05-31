-- ============================================================
-- UI/HeadsUpDisplay.lua
-- Render-only HUD for brainrot and passive income.
-- ============================================================

local HeadsUpDisplay = {}
local UIConfig = require("Data.UIConfig")
local configuration = UIConfig.HUD
local nodes = {}

---@param node any
---@return boolean valid
local function is_node(node)
    return node ~= nil and node ~= false and node ~= 0 and node ~= ""
end

---@param value number
---@return string formatted_value
local function format_integer(value)
    return tostring(math.tointeger(value) or 0)
end

---@param parent ENode
---@param name string
---@return ENode|nil node
local function fetch_child(parent, name)
    local node = GameAPI.get_eui_child_by_name(parent, name)
    if not is_node(node) then
        LuaAPI.log("[HeadsUpDisplay] 缺少画布节点: " .. name, 1)
        return nil
    end
    return node
end

---Bind editor-authored HUD nodes once during game initialization.
---@param canvas ECanvas
function HeadsUpDisplay.initialize(canvas)
    nodes.coin = fetch_child(canvas, configuration.nodes.coin)
    nodes.brainrot = fetch_child(canvas, configuration.nodes.brainrot)
    nodes.brainrot_per_second = fetch_child(canvas, configuration.nodes.brainrot_per_second)
end

---Render one player's HUD values.
---@param role Role
---@param state PlayerGameState
function HeadsUpDisplay.render(role, state)
    if not role or not state then
        return
    end
    if not is_node(nodes.brainrot) or not is_node(nodes.brainrot_per_second) then
        return
    end

    role.set_label_text(nodes.brainrot, format_integer(state.currency.brainrot))
    role.set_label_text(
        nodes.brainrot_per_second,
        configuration.brainrot_per_second_prefix .. format_integer(state.currency.brainrot_per_second)
    )
end

return HeadsUpDisplay
