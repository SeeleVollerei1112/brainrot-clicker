-- ============================================================
-- Lottery/LotteryController.lua
-- 编排层：绑定转盘画布的抽奖按钮，按权重预定结果后驱动转盘动画，
-- 落定时弹出中奖提示。
-- ============================================================

local ItemSynthesisSystem = require("Inventory.ItemSynthesisSystem")
local LotteryConfig = require("Lottery.LotteryConfig")
local LotterySystem = require("Lottery.LotterySystem")
local LotteryView = require("Lottery.LotteryView")
local UINodes = require("Data.UINodes")
local AppConfig = require("App.AppConfig")

local LotteryController = {}

---发放中奖物件到玩家持有物（装备栏优先、可堆叠、自动落盘），
---等级按配置经合成成长曲线折算属性，与合成产物数值一致。
---@param role Role
---@param prize LotteryPrize
---@return string|nil granted_text 发放成功返回 "名字 Lv.N"，未配置/失败返回 nil
local function grant_prize(role, prize)
    local reward = prize.reward
    if not reward then
        return nil
    end

    local attrs = ItemSynthesisSystem.attrs_at_level(reward.item_id, reward.level)
    if not attrs then
        LuaAPI.log("[LotteryController] 奖励物件未配置: item=" .. tostring(reward.item_id), 1)
        return nil
    end

    local equipment = ItemSynthesisSystem.give_item_preferred_slots(role, reward.item_id, attrs, 1)
    if not equipment then
        LuaAPI.log("[LotteryController] 奖励发放失败: item=" .. tostring(reward.item_id), 1)
        return nil
    end

    LuaAPI.log("[LotteryController] 发放奖励 item=" .. tostring(reward.item_id)
        .. " level=" .. tostring(attrs.level), 0)
    return tostring(attrs.name) .. " Lv." .. tostring(attrs.level)
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
        local granted_text = grant_prize(role, result.prize)
        role.show_tips(
            "恭喜获得：" .. (granted_text or result.prize.name),
            LotteryConfig.TIP_DURATION
        )
    end)
end

---打开转盘画布（发送自定义消息，画布在编辑器中绑定了 show_event）。
---@param role Role
local function handle_open(role)
    role.send_ui_custom_event(LotteryConfig.EVENTS.open, {})
end

---关闭转盘画布（发送自定义消息，画布在编辑器中绑定了 hide_event）。
---@param role Role
local function handle_close(role)
    role.send_ui_custom_event(LotteryConfig.EVENTS.close, {})
end

---绑定转盘画布的开关导航与抽奖按钮。
---@param application Application
function LotteryController.initialize(application)
    local register_trigger = application.register_trigger
    LotteryView.initialize()

    -- 世界画布的入口按钮：点击弹出转盘画布
    local open_button = UINodes[LotteryConfig.BUTTONS.open]
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
        LuaAPI.log("[LotteryController] 缺少入口按钮节点: " .. LotteryConfig.BUTTONS.open, 1)
    end

    -- 转盘画布内的关闭按钮：点击退出转盘画布
    local lottery_canvas = UINodes[LotteryConfig.CANVAS_NAME]
    local close_button = lottery_canvas
        and GameAPI.get_eui_child_by_name(lottery_canvas, LotteryConfig.BUTTONS.close)
        or nil
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
        LuaAPI.log("[LotteryController] 缺少关闭按钮节点: " .. LotteryConfig.BUTTONS.close, 1)
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
    LotteryView.initialize_role(session.role)
end

---玩家离开时清理其转盘视图状态。
---@param session PlayerSession
function LotteryController.cleanup_session(session)
    LotteryView.cleanup_role(session.role)
end

return LotteryController
