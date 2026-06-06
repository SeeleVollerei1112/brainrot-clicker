-- ============================================================
-- Lottery/LotteryController.lua
-- 编排层：绑定转盘画布的抽奖按钮，按权重预定结果后驱动转盘动画，
-- 落定时弹出中奖提示。
-- ============================================================

local LotteryConfig = require("Lottery.LotteryConfig")
local LotterySystem = require("Lottery.LotterySystem")
local LotteryView = require("Lottery.LotteryView")
local UINodes = require("Data.UINodes")
local AppConfig = require("App.AppConfig")

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
    if LotteryView.is_spinning(role) then
        return
    end

    local result = LotterySystem.draw()
    if not result.success or not result.prize then
        LuaAPI.log("[LotteryController] 抽奖失败: " .. tostring(result.reason), 1)
        role.show_tips("抽奖失败，请稍后再试", LotteryConfig.TIP_DURATION)
        return
    end

    local target_index = LotterySystem.index_of_prize(result.prize.id)
    if not target_index then
        LuaAPI.log("[LotteryController] 奖励未配置对应卡片: " .. tostring(result.prize.id), 1)
        role.show_tips("恭喜获得：" .. result.prize.name, LotteryConfig.TIP_DURATION)
        return
    end

    LotteryView.play_spin(role, target_index, function()
        role.show_tips("恭喜获得：" .. result.prize.name, LotteryConfig.TIP_DURATION)
        -- TODO: 实际发放奖励（接 CurrencySystem 等），当前仅提示。
    end)
end

---打开转盘画布（发送自定义消息，画布在编辑器中绑定了 show_event）。
---@param role Role
local function handle_open(role)
    role.send_ui_custom_event(AppConfig.APP.events.open_lottery, {})
end

---关闭转盘画布（发送自定义消息，画布在编辑器中绑定了 hide_event）。
---@param role Role
local function handle_close(role)
    role.send_ui_custom_event(AppConfig.APP.events.close_lottery, {})
end

---绑定转盘画布的开关导航与抽奖按钮。
---@param register_trigger fun(event_arguments: table, callback: function): integer
function LotteryController.initialize(register_trigger)
    LotteryView.initialize()

    -- 世界画布的入口按钮：点击弹出转盘画布
    local open_button = UINodes[AppConfig.APP.buttons.lottery_open]
    if open_button then
        register_trigger(
            { EVENT.EUI_NODE_TOUCH_EVENT, open_button, AppConfig.TOUCH.CLICK },
            function(event_name, actor, data)
                if data and data.role then
                    handle_open(data.role)
                end
            end
        )
    else
        LuaAPI.log("[LotteryController] 缺少入口按钮节点: " .. AppConfig.APP.buttons.lottery_open, 1)
    end

    -- 转盘画布内的关闭按钮：点击退出转盘画布
    local close_button = fetch_child(UINodes[LotteryConfig.CANVAS_NAME], AppConfig.APP.buttons.lottery_close)
    if close_button then
        register_trigger(
            { EVENT.EUI_NODE_TOUCH_EVENT, close_button, AppConfig.TOUCH.CLICK },
            function(event_name, actor, data)
                if data and data.role then
                    handle_close(data.role)
                end
            end
        )
    else
        LuaAPI.log("[LotteryController] 缺少关闭按钮节点: " .. AppConfig.APP.buttons.lottery_close, 1)
    end

    local spin_button = LotteryView.get_button()
    if not spin_button then
        LuaAPI.log("[LotteryController] 缺少抽奖按钮节点: " .. LotteryConfig.BUTTON_NAME, 1)
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

---为加入的玩家初始化转盘视图（隐藏选中框、重置该玩家转动状态）。
---@param session PlayerSession
function LotteryController.setup_session(session)
    local role = session and session.role
    if not role then
        return
    end
    LotteryView.initialize_role(role)
end

---@param role Role
function LotteryController.initialize_role(role)
    LotteryController.setup_session({ role = role })
end

---玩家离开时清理其转盘视图状态。
---@param session PlayerSession
function LotteryController.cleanup_session(session)
    local role = session and session.role
    if not role then
        return
    end
    LotteryView.cleanup_role(role)
end

---@param role Role
function LotteryController.cleanup_role(role)
    LotteryController.cleanup_session({ role = role })
end

return LotteryController
