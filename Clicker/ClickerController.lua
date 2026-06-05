--[[
Clicker/ClickerController.lua

点击主玩法编排层。
负责角色点击、飘字、HUD、连击、被动收益和升级商店的联动。
]]

local AppConfig = require("App.AppConfig")
local CharacterView = require("Clicker.CharacterView")
local ClickerConfig = require("Clicker.ClickerConfig")
local ComboBar = require("Combo.ComboBar")
local ComboConfig = require("Combo.ComboConfig")
local ComboSystem = require("Combo.ComboSystem")
local CurrencySystem = require("Clicker.CurrencySystem")
local FloatText = require("Clicker.FloatTextView")
local HeadsUpDisplay = require("Clicker.HeadsUpDisplay")
local UpgradeShopPanel = require("UpgradeShop.UpgradeShopPanel")
local UpgradeShopSystem = require("UpgradeShop.UpgradeShopSystem")

local ClickerController = {}

---@type fun(role: Role): PlayerSession|nil
local get_or_create_session = nil

---@type fun(callback: fun(session: PlayerSession))
local for_each_session = nil

local launch_button = nil
local exit_button = nil

---@param session PlayerSession
local function render_shop(session)
    UpgradeShopPanel.render(session.role, UpgradeShopSystem.get_display_data(session.state))
end

---@param session PlayerSession
---@param result ComboUpdateResult
local function render_combo_update(session, result)
    if not result.state_changed then
        return
    end

    ComboBar.render_progress(session.role, session.state)
    if result.tier_changed then
        ComboBar.handle_tier_change(session.role, result.old_tier, result.new_tier)
    elseif result.should_pop then
        ComboBar.pop(session.role)
    end
end

---@param session PlayerSession
local function refresh_skin(session)
    if CharacterView.update_skin(session.role, session.state.currency.total_brainrot) then
        FloatText.set_color(session.role, CharacterView.get_active_float_color(session.role))
    end
end

---@param role Role
function ClickerController.handle_character_click(role)
    local session = get_or_create_session(role)
    if not session then
        return
    end

    local income = CurrencySystem.add_click_income(session.state)
    FloatText.show(role, income)
    CharacterView.play_click_feedback(role)
    refresh_skin(session)
    HeadsUpDisplay.render(role, session.state)
    if session.click_canvas_open then
        render_shop(session)
    end

    render_combo_update(session, ComboSystem.add_click(session.state))
end

---@param role Role
---@param item_id integer
function ClickerController.handle_shop_purchase(role, item_id)
    local session = get_or_create_session(role)
    if not session then
        return
    end

    local result = UpgradeShopSystem.purchase(session.state, item_id)
    if not result.success then
        LuaAPI.log(
            "[ClickerController] 购买失败 item=" .. tostring(item_id) .. " reason=" .. result.reason,
            0
        )
    end

    HeadsUpDisplay.render(role, session.state)
    render_shop(session)
end

---@param role Role
function ClickerController.handle_open_click_canvas(role)
    local session = get_or_create_session(role)
    if not session then
        return
    end

    session.click_canvas_open = true
    role.send_ui_custom_event(AppConfig.APP.events.open_click_canvas, {})
    HeadsUpDisplay.render(role, session.state)
    render_shop(session)
end

---@param role Role
function ClickerController.handle_close_click_canvas(role)
    local session = get_or_create_session(role)
    if not session then
        return
    end

    session.click_canvas_open = false
    role.send_ui_custom_event(AppConfig.APP.events.close_click_canvas, {})
end

---@param register_trigger fun(event_arguments: table, callback: function): integer
local function bind_ui_interactions(register_trigger)
    CharacterView.bind_click_handler(ClickerController.handle_character_click, register_trigger)
    UpgradeShopPanel.bind_purchase_handler(ClickerController.handle_shop_purchase, register_trigger)

    if launch_button then
        register_trigger(
            { EVENT.EUI_NODE_TOUCH_EVENT, launch_button, AppConfig.TOUCH.CLICK },
            function(event_name, actor, data)
                if data and data.role then
                    ClickerController.handle_open_click_canvas(data.role)
                end
            end
        )
    else
        LuaAPI.log("[ClickerController] 缺少世界画布节点: " .. AppConfig.APP.buttons.launch, 1)
    end

    if exit_button then
        register_trigger(
            { EVENT.EUI_NODE_TOUCH_EVENT, exit_button, AppConfig.TOUCH.CLICK },
            function(event_name, actor, data)
                if data and data.role then
                    ClickerController.handle_close_click_canvas(data.role)
                end
            end
        )
    else
        LuaAPI.log("[ClickerController] 缺少点击画布节点: " .. AppConfig.APP.buttons.exit, 1)
    end
end

---@param register_trigger fun(event_arguments: table, callback: function): integer
local function register_timers(register_trigger)
    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(ClickerConfig.PASSIVE_INCOME.tick_interval) },
        function()
            for_each_session(function(session)
                CurrencySystem.add_passive_income(session.state)
                HeadsUpDisplay.render(session.role, session.state)
                refresh_skin(session)
                if session.click_canvas_open then
                    render_shop(session)
                end
            end)
        end
    )

    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(ComboConfig.TICK_INTERVAL) },
        function()
            for_each_session(function(session)
                render_combo_update(session, ComboSystem.decay(session.state))
            end)
        end
    )
end

---@param canvas ECanvas
---@param buttons table
---@param register_trigger fun(event_arguments: table, callback: function): integer
---@param session_getter fun(role: Role): PlayerSession|nil
---@param session_iterator fun(callback: fun(session: PlayerSession))
function ClickerController.initialize(canvas, buttons, register_trigger, session_getter, session_iterator)
    launch_button = buttons.launch
    exit_button = buttons.exit
    get_or_create_session = session_getter
    for_each_session = session_iterator

    CharacterView.initialize(canvas)
    HeadsUpDisplay.initialize(canvas)
    FloatText.initialize(canvas)
    UpgradeShopPanel.initialize(canvas)
    ComboBar.initialize(canvas)

    bind_ui_interactions(register_trigger)
    register_timers(register_trigger)
end

---@param state PlayerGameState
function ClickerController.initialize_state(state)
    UpgradeShopSystem.initialize(state)
end

---@param session PlayerSession
function ClickerController.initialize_role(session)
    local role = session.role
    HeadsUpDisplay.render(role, session.state)
    FloatText.initialize_role(role)
    CharacterView.initialize_role(role)
    refresh_skin(session)
    ComboBar.initialize_role(role)
    UpgradeShopPanel.initialize_role(role)

    if launch_button then
        role.set_button_text(launch_button, AppConfig.APP.text.launch)
    end
    if exit_button then
        role.set_button_text(exit_button, AppConfig.APP.text.exit)
    end
end

---@param role Role
function ClickerController.cleanup_role(role)
    FloatText.cleanup_role(role)
    CharacterView.cleanup_role(role)
end

function ClickerController.shutdown()
    CharacterView.shutdown()
    ComboBar.shutdown()
    FloatText.shutdown()
    get_or_create_session = nil
    for_each_session = nil
    launch_button = nil
    exit_button = nil
end

return ClickerController
