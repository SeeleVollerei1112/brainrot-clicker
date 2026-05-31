-- ============================================================
-- Controllers/GameController.lua
-- Orchestrates player sessions, engine triggers, systems and views.
-- ============================================================

local CharacterView = require("UI.CharacterView")
local ComboBar = require("UI.ComboBar")
local ComboSystem = require("Systems.ComboSystem")
local CurrencySystem = require("Systems.CurrencySystem")
local FloatText = require("UI.FloatText")
local GameConfig = require("Data.GameConfig")
local GameState = require("Systems.GameState")
local HeadsUpDisplay = require("UI.HeadsUpDisplay")
local ShopPanel = require("UI.ShopPanel")
local ShopSystem = require("Systems.ShopSystem")
local UIConfig = require("Data.UIConfig")
local UINodes = require("Data.UINodes")

---@class PlayerSession
---@field role_id RoleID
---@field role Role
---@field state PlayerGameState
---@field click_canvas_open boolean

local GameController = {}

---@type table<RoleID, PlayerSession>
local player_sessions = {}

---@type integer[]
local registered_trigger_ids = {}

local initialized = false
local world_canvas = nil
local click_canvas = nil
local launch_button = nil
local exit_button = nil

---Register and retain one engine trigger for centralized shutdown.
---@param event_arguments table
---@param callback function
---@return integer trigger_id
local function register_trigger(event_arguments, callback)
    local trigger_id = LuaAPI.global_register_trigger_event(event_arguments, callback)
    table.insert(registered_trigger_ids, trigger_id)
    return trigger_id
end

---@param role Role
---@return RoleID|nil role_id
local function get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

---@param parent ENode|nil
---@param name string
---@return ENode|nil node
local function fetch_child(parent, name)
    if not parent then
        return nil
    end
    return GameAPI.get_eui_child_by_name(parent, name)
end

---@param session PlayerSession
local function render_shop(session)
    ShopPanel.render(session.role, ShopSystem.get_display_data(session.state))
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
local function initialize_session_views(session)
    local role = session.role
    HeadsUpDisplay.render(role, session.state)
    FloatText.initialize_role(role)
    CharacterView.initialize_role(role)
    ComboBar.initialize_role(role)
    ShopPanel.initialize_role(role)

    if launch_button then
        role.set_button_text(launch_button, UIConfig.APP.text.launch)
    end
    if exit_button then
        role.set_button_text(exit_button, UIConfig.APP.text.exit)
    end
end

---@param role Role
local function register_role_exit_handler(role)
    register_trigger(
        { EVENT.SPEC_ROLE_EXIT_GAME, role },
        function(event_name, actor, data)
            GameController.remove_player_session((data and data.role) or role)
        end
    )
end

---Return a player's existing session or lazily create an isolated one.
---@param role Role
---@return PlayerSession|nil session
function GameController.get_or_create_player_session(role)
    local role_id = get_role_id(role)
    if not role_id then
        LuaAPI.log("[GameController] 无法获取 Role ID，跳过玩家会话创建", 1)
        return nil
    end

    local existing_session = player_sessions[role_id]
    if existing_session then
        return existing_session
    end

    local state = GameState.new()
    ShopSystem.initialize(state)
    local session = {
        role_id = role_id,
        role = role,
        state = state,
        click_canvas_open = false,
    }
    player_sessions[role_id] = session
    initialize_session_views(session)
    register_role_exit_handler(role)
    LuaAPI.log("[GameController] 玩家会话已创建: " .. tostring(role_id), 0)
    return session
end

---Drop one player's state after the engine reports their exit.
---@param role Role
function GameController.remove_player_session(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    player_sessions[role_id] = nil
    LuaAPI.log("[GameController] 玩家会话已移除: " .. tostring(role_id), 0)
end

---Handle one character click and refresh only the originating player.
---@param role Role
function GameController.handle_character_click(role)
    local session = GameController.get_or_create_player_session(role)
    if not session then
        return
    end

    local income = CurrencySystem.add_click_income(session.state)
    FloatText.show(role, income)
    CharacterView.play_click_feedback(role)
    HeadsUpDisplay.render(role, session.state)
    if session.click_canvas_open then
        render_shop(session)
    end

    render_combo_update(session, ComboSystem.add_click(session.state))
end

---Handle one shop-card interaction and refresh only the buyer.
---@param role Role
---@param item_id integer
function GameController.handle_shop_purchase(role, item_id)
    local session = GameController.get_or_create_player_session(role)
    if not session then
        return
    end

    local result = ShopSystem.purchase(session.state, item_id)
    if not result.success then
        LuaAPI.log(
            "[GameController] 购买失败 item=" .. tostring(item_id) .. " reason=" .. result.reason,
            0
        )
    end

    HeadsUpDisplay.render(role, session.state)
    render_shop(session)
end

---Open the click canvas for one role and render its current values.
---@param role Role
function GameController.handle_open_click_canvas(role)
    local session = GameController.get_or_create_player_session(role)
    if not session then
        return
    end

    session.click_canvas_open = true
    role.send_ui_custom_event(UIConfig.APP.events.open_click_canvas, {})
    HeadsUpDisplay.render(role, session.state)
    render_shop(session)
end

---Close the click canvas for one role.
---@param role Role
function GameController.handle_close_click_canvas(role)
    local session = GameController.get_or_create_player_session(role)
    if not session then
        return
    end

    session.click_canvas_open = false
    role.send_ui_custom_event(UIConfig.APP.events.close_click_canvas, {})
end

local function bind_ui_interactions()
    CharacterView.bind_click_handler(GameController.handle_character_click, register_trigger)
    ShopPanel.bind_purchase_handler(GameController.handle_shop_purchase, register_trigger)

    if launch_button then
        register_trigger(
            { EVENT.EUI_NODE_TOUCH_EVENT, launch_button, UIConfig.TOUCH.CLICK },
            function(event_name, actor, data)
                if data and data.role then
                    GameController.handle_open_click_canvas(data.role)
                end
            end
        )
    else
        LuaAPI.log("[GameController] 缺少世界画布节点: " .. UIConfig.APP.buttons.launch, 1)
    end

    if exit_button then
        register_trigger(
            { EVENT.EUI_NODE_TOUCH_EVENT, exit_button, UIConfig.TOUCH.CLICK },
            function(event_name, actor, data)
                if data and data.role then
                    GameController.handle_close_click_canvas(data.role)
                end
            end
        )
    else
        LuaAPI.log("[GameController] 缺少点击画布节点: " .. UIConfig.APP.buttons.exit, 1)
    end
end

local function register_timers()
    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(GameConfig.BRAINROT_PER_SECOND_TICK_INTERVAL) },
        function()
            for _, session in pairs(player_sessions) do
                CurrencySystem.add_passive_income(session.state)
                HeadsUpDisplay.render(session.role, session.state)
                if session.click_canvas_open then
                    render_shop(session)
                end
            end
        end
    )

    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(GameConfig.COMBO_TICK_INTERVAL) },
        function()
            for _, session in pairs(player_sessions) do
                render_combo_update(session, ComboSystem.decay(session.state))
            end
        end
    )
end

---Initialize shared views, triggers and currently connected players.
function GameController.initialize()
    if initialized then
        GameController.shutdown()
    end

    world_canvas = UINodes[UIConfig.APP.canvases.world]
    click_canvas = UINodes[UIConfig.APP.canvases.click]
    if not click_canvas then
        LuaAPI.log("[GameController] 缺少画布: " .. UIConfig.APP.canvases.click, 1)
        return
    end

    launch_button = fetch_child(world_canvas, UIConfig.APP.buttons.launch)
    exit_button = fetch_child(click_canvas, UIConfig.APP.buttons.exit)
    CharacterView.initialize(click_canvas)
    HeadsUpDisplay.initialize(click_canvas)
    FloatText.initialize(click_canvas)
    ShopPanel.initialize(click_canvas)
    ComboBar.initialize(click_canvas)

    bind_ui_interactions()
    register_timers()
    initialized = true

    for _, role in ipairs(GameAPI.get_all_valid_roles()) do
        GameController.get_or_create_player_session(role)
    end

    LuaAPI.log("[GameController] Brainrot Clicker 初始化完成", 0)
end

---Unregister controller-owned triggers and invalidate UI animations.
function GameController.shutdown()
    for trigger_index = #registered_trigger_ids, 1, -1 do
        LuaAPI.global_unregister_trigger_event(registered_trigger_ids[trigger_index])
    end

    registered_trigger_ids = {}
    player_sessions = {}
    initialized = false
    CharacterView.shutdown()
    ComboBar.shutdown()
    FloatText.shutdown()
    LuaAPI.log("[GameController] Brainrot Clicker 已关闭", 0)
end

return GameController
