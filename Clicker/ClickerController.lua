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
local UINodes = require("Data.UINodes")
local UpgradeShopView = require("Clicker.UpgradeShop.UpgradeShopView")
local UpgradeShopSystem = require("Clicker.UpgradeShop.UpgradeShopSystem")

local ClickerController = {}

ClickerController.PASSIVE_INCOME_INTERVAL = ClickerConfig.PASSIVE_INCOME.tick_interval
ClickerController.COMBO_INTERVAL = ComboConfig.TICK_INTERVAL

---@type fun(role: Role): PlayerSession|nil
local find_session = nil

local launch_button = nil
local exit_button = nil

---@param session PlayerSession
local function render_shop(session)
    UpgradeShopView.render(session.role, UpgradeShopSystem.get_display_data(session.state))
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

---@param session PlayerSession
function ClickerController.handle_character_click(session)
    if not session then
        return
    end

    local role = session.role
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

---@param session PlayerSession
---@param item_id integer
function ClickerController.handle_shop_purchase(session, item_id)
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

    HeadsUpDisplay.render(session.role, session.state)
    render_shop(session)
end

---@param session PlayerSession
function ClickerController.handle_open_click_canvas(session)
    if not session then
        return
    end

    local role = session.role
    session.click_canvas_open = true
    role.send_ui_custom_event(ClickerConfig.EVENTS.open_click_canvas, {})
    HeadsUpDisplay.render(role, session.state)
    render_shop(session)
end

---@param session PlayerSession
function ClickerController.handle_close_click_canvas(session)
    if not session then
        return
    end

    session.click_canvas_open = false
    session.role.send_ui_custom_event(ClickerConfig.EVENTS.close_click_canvas, {})
end

---@param register_trigger fun(event_arguments: table, callback: function): integer
local function bind_ui_interactions(register_trigger)
    CharacterView.bind_click_handler(function(role)
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
    CurrencySystem.add_passive_income(session.state)
    HeadsUpDisplay.render(session.role, session.state)
    refresh_skin(session)
    if session.click_canvas_open then
        render_shop(session)
    end
end

---@param session PlayerSession
function ClickerController.tick_combo_decay(session)
    render_combo_update(session, ComboSystem.decay(session.state))
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

    CharacterView.initialize(click_canvas)
    HeadsUpDisplay.initialize(click_canvas)
    FloatText.initialize(click_canvas)
    UpgradeShopView.initialize(click_canvas)
    ComboBar.initialize(click_canvas)

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

---@param state PlayerGameState
function ClickerController.initialize_state(state)
    UpgradeShopSystem.initialize(state)
end

---@param session PlayerSession
function ClickerController.setup_session(session)
    local role = session.role
    HeadsUpDisplay.render(role, session.state)
    FloatText.initialize_role(role)
    CharacterView.initialize_role(role)
    refresh_skin(session)
    ComboBar.initialize_role(role)
    UpgradeShopView.initialize_role(role)

    if launch_button then
        role.set_button_text(launch_button, ClickerConfig.BUTTON_TEXT.launch)
    end
    if exit_button then
        role.set_button_text(exit_button, ClickerConfig.BUTTON_TEXT.exit)
    end
end

---@param session PlayerSession
function ClickerController.initialize_role(session)
    ClickerController.setup_session(session)
end

---@param session PlayerSession
function ClickerController.cleanup_session(session)
    local role = session and session.role
    if not role then
        return
    end
    FloatText.cleanup_role(role)
    CharacterView.cleanup_role(role)
end

---@param role Role
function ClickerController.cleanup_role(role)
    ClickerController.cleanup_session({ role = role })
end

function ClickerController.shutdown()
    CharacterView.shutdown()
    ComboBar.shutdown()
    FloatText.shutdown()
    find_session = nil
    launch_button = nil
    exit_button = nil
end

return ClickerController
