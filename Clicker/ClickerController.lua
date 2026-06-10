--[[
Clicker/ClickerController.lua

点击主玩法编排层。
负责角色点击、飘字、HUD、连击、被动收益和升级商店的联动。
]]

local AppConfig = require("App.AppConfig")
local ClickerConfig = require("Clicker.ClickerConfig")
local ClickerState = require("Clicker.ClickerState")
local ClickerView = require("Clicker.ClickerView")
local SessionStateRegistry = require("App.SessionStateRegistry")
local UINodes = require("Data.UINodes")
local UpgradeShopView = require("Clicker.UpgradeShop.UpgradeShopView")
local UpgradeShopSystem = require("Clicker.UpgradeShop.UpgradeShopSystem")

local ClickerController = {}

-- 点击玩法状态片：纯内存态，不持久化。
SessionStateRegistry.declare("clicker", {
    create = function()
        local state = ClickerState.new()
        UpgradeShopSystem.initialize(state)
        return state
    end,
})

ClickerController.PASSIVE_INCOME_INTERVAL = ClickerConfig.PASSIVE_INCOME.tick_interval
ClickerController.COMBO_INTERVAL = ClickerConfig.COMBO.TICK_INTERVAL

---@type fun(role: Role): PlayerSession|nil
local find_session = nil

local launch_button = nil
local exit_button = nil

---@param session PlayerSession
local function render_shop(session)
    UpgradeShopView.render(
        session.role,
        UpgradeShopSystem.get_display_data(session:get_or_create_state("clicker"))
    )
end

---@param session PlayerSession
---@param result ComboUpdateResult
local function render_combo_update(session, result)
    if not result.state_changed then
        return
    end

    ClickerView.render_progress(session.role, session:get_or_create_state("clicker"))
    if result.tier_changed then
        ClickerView.handle_tier_change(session.role, result.old_tier, result.new_tier)
    elseif result.should_pop then
        ClickerView.pop(session.role)
    end
end

---@param session PlayerSession
local function refresh_skin(session)
    local state = session:get_or_create_state("clicker")
    if ClickerView.update_skin(session.role, state.currency.total_brainrot) then
        ClickerView.set_color(session.role, ClickerView.get_active_float_color(session.role))
    end
end

---@param session PlayerSession
function ClickerController.handle_character_click(session)
    local role = session.role
    local state = session:get_or_create_state("clicker")
    local income = ClickerState.add_click_income(state)
    ClickerView.show(role, income)
    ClickerView.play_click_feedback(role)
    refresh_skin(session)
    ClickerView.render(role, state)
    if session.click_canvas_open then
        render_shop(session)
    end

    render_combo_update(session, ClickerState.add_combo_click(state))
end

---@param session PlayerSession
---@param item_id integer
function ClickerController.handle_shop_purchase(session, item_id)
    local state = session:get_or_create_state("clicker")
    local result = UpgradeShopSystem.purchase(state, item_id)
    if not result.success then
        LuaAPI.log(
            "[ClickerController] 购买失败 item=" .. tostring(item_id) .. " reason=" .. result.reason,
            0
        )
    end

    ClickerView.render(session.role, state)
    render_shop(session)
end

---@param session PlayerSession
function ClickerController.handle_open_click_canvas(session)
    local role = session.role
    session.click_canvas_open = true
    role.send_ui_custom_event(ClickerConfig.EVENTS.open_click_canvas, {})
    ClickerView.render(role, session:get_or_create_state("clicker"))
    render_shop(session)
end

---@param session PlayerSession
function ClickerController.handle_close_click_canvas(session)
    session.click_canvas_open = false
    session.role.send_ui_custom_event(ClickerConfig.EVENTS.close_click_canvas, {})
end

---@param register_trigger fun(event_arguments: table, callback: function): integer
local function bind_ui_interactions(register_trigger)
    ClickerView.bind_click_handler(function(role)
        local session = find_session(role)
        if session then
            ClickerController.handle_character_click(session)
        end
    end, register_trigger)

    UpgradeShopView.bind_purchase_handler(function(role, item_id)
        local session = find_session(role)
        if session then
            ClickerController.handle_shop_purchase(session, item_id)
        end
    end, register_trigger)

    if launch_button then
        register_trigger(
            { EVENT.EUI_NODE_TOUCH_EVENT, launch_button, AppConfig.TOUCH.CLICK },
            function(event_name, actor, data)
                local session = data and find_session(data.role)
                if session then
                    ClickerController.handle_open_click_canvas(session)
                end
            end
        )
    else
        LuaAPI.log("[ClickerController] 缺少世界画布节点: " .. ClickerConfig.BUTTONS.launch, 1)
    end

    if exit_button then
        register_trigger(
            { EVENT.EUI_NODE_TOUCH_EVENT, exit_button, AppConfig.TOUCH.CLICK },
            function(event_name, actor, data)
                local session = data and find_session(data.role)
                if session then
                    ClickerController.handle_close_click_canvas(session)
                end
            end
        )
    else
        LuaAPI.log("[ClickerController] 缺少点击画布节点: " .. ClickerConfig.BUTTONS.exit, 1)
    end
end

---@param session PlayerSession
function ClickerController.tick_passive_income(session)
    local state = session:get_or_create_state("clicker")
    ClickerState.add_passive_income(state)
    ClickerView.render(session.role, state)
    refresh_skin(session)
    if session.click_canvas_open then
        render_shop(session)
    end
end

---@param session PlayerSession
function ClickerController.tick_combo_decay(session)
    render_combo_update(session, ClickerState.decay_combo(session:get_or_create_state("clicker")))
end

---@param application Application
function ClickerController.initialize(application)
    local register_trigger = application.register_trigger
    local world_canvas = UINodes[AppConfig.APP.canvases.world]
    local click_canvas = UINodes[AppConfig.APP.canvases.click]
    if not click_canvas then
        LuaAPI.log("[ClickerController] 缺少画布: " .. AppConfig.APP.canvases.click, 1)
        return
    end

    launch_button = GameAPI.get_eui_child_by_name(world_canvas, ClickerConfig.BUTTONS.launch)
    exit_button = GameAPI.get_eui_child_by_name(click_canvas, ClickerConfig.BUTTONS.exit)
    find_session = application.sessions.find_by_role

    ClickerView.initialize(click_canvas)
    UpgradeShopView.initialize(click_canvas)

    bind_ui_interactions(register_trigger)

    -- 被动收益与连击衰减定时器（自注册：间隔/回调/会话遍历都收归本控制器）
    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(ClickerController.PASSIVE_INCOME_INTERVAL) },
        function()
            application.sessions.for_each(ClickerController.tick_passive_income)
        end
    )
    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(ClickerController.COMBO_INTERVAL) },
        function()
            application.sessions.for_each(ClickerController.tick_combo_decay)
        end
    )
end

---@param session PlayerSession
function ClickerController.setup_session(session)
    local role = session.role
    ClickerView.render(role, session:get_or_create_state("clicker"))
    ClickerView.initialize_role(role)
    refresh_skin(session)
    UpgradeShopView.initialize_role(role)

    if launch_button then
        role.set_button_text(launch_button, ClickerConfig.BUTTON_TEXT.launch)
    end
    if exit_button then
        role.set_button_text(exit_button, ClickerConfig.BUTTON_TEXT.exit)
    end
end

---@param session PlayerSession
function ClickerController.cleanup_session(session)
    ClickerView.cleanup_role(session.role)
end

function ClickerController.shutdown()
    ClickerView.shutdown()
    find_session = nil
    launch_button = nil
    exit_button = nil
end

return ClickerController
