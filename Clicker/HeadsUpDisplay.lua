--[[
Clicker/HeadsUpDisplay.lua

HUD 表现层：只负责渲染脑腐值和每秒收益。
]]

local HeadsUpDisplay = {}
local ClickerConfig = require("Clicker.ClickerConfig")
local configuration = ClickerConfig.HUD
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

---游戏初始化时绑定编辑器内已搭好的 HUD 节点。
---@param canvas ENode
function HeadsUpDisplay.initialize(canvas)
    nodes.coin = fetch_child(canvas, configuration.nodes.coin)
    nodes.brainrot = fetch_child(canvas, configuration.nodes.brainrot)
    nodes.brainrot_per_second = fetch_child(canvas, configuration.nodes.brainrot_per_second)
end

---渲染单个玩家的 HUD 数值。
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
