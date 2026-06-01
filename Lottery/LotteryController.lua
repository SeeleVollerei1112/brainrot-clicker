-- ============================================================
-- Lottery/LotteryController.lua
-- Binds the world-canvas lottery button to the basic draw flow.
-- ============================================================

local LotteryConfig = require("Lottery.LotteryConfig")
local LotterySystem = require("Lottery.LotterySystem")

local LotteryController = {}

---@param parent ENode|nil
---@param name string
---@return ENode|nil node
local function fetch_child(parent, name)
    if not parent then
        return nil
    end
    return GameAPI.get_eui_child_by_name(parent, name)
end

---@param role Role
local function handle_spin(role)
    local result = LotterySystem.draw()
    if not result.success or not result.prize then
        LuaAPI.log("[LotteryController] 抽奖失败: " .. tostring(result.reason), 1)
        role.show_tips("抽奖失败，请稍后再试", LotteryConfig.TIP_DURATION)
        return
    end

    role.show_tips("恭喜获得：" .. result.prize.name, LotteryConfig.TIP_DURATION)
end

---Bind the optional lottery button on the world canvas.
---@param world_canvas ECanvas|nil
---@param register_trigger fun(event_arguments: table, callback: function): integer
function LotteryController.initialize(world_canvas, register_trigger)
    local spin_button = fetch_child(world_canvas, LotteryConfig.BUTTON_NODE_NAME)
    if not spin_button then
        LuaAPI.log("[LotteryController] 缺少世界画布节点: " .. LotteryConfig.BUTTON_NODE_NAME, 1)
        return
    end

    register_trigger(
        { EVENT.EUI_NODE_TOUCH_EVENT, spin_button, LotteryConfig.TOUCH_CLICK },
        function(event_name, actor, data)
            if data and data.role then
                handle_spin(data.role)
            end
        end
    )
end

return LotteryController
