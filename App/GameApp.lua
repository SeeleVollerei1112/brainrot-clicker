--[[
App/GameApp.lua

应用生命周期与功能装配入口。
这里直接持有玩家会话表和触发器编号，避免为了简单表操作再包一层模块。
]]

local AppConfig = require("App.AppConfig")
local BoothController = require("Booth.BoothController")
local BoothInteraction = require("Booth.BoothInteraction")
local BoothPlacement = require("Booth.BoothPlacement")
local BoothZoneView = require("Booth.BoothZoneView")
local ClickerController = require("Clicker.ClickerController")
local InventoryController = require("Inventory.InventoryController")
local LotteryController = require("Lottery.LotteryController")
local MallController = require("Mall.MallController")
local PlayerState = require("Clicker.PlayerState")
local UINodes = require("Data.UINodes")

---@class PlayerSession
---@field role_id RoleID 玩家 ID
---@field role Role 玩家对象
---@field state PlayerGameState 玩家运行时状态
---@field click_canvas_open boolean 点击界面是否打开

local GameApp = {}

---@type table<RoleID, PlayerSession>
local player_sessions = {}

---@type integer[]
local trigger_ids = {}

local initialized = false
local world_canvas = nil
local click_canvas = nil
local launch_button = nil
local exit_button = nil

---@param event_arguments table
---@param callback function
---@return integer trigger_id
local function register_trigger(event_arguments, callback)
    local trigger_id = LuaAPI.global_register_trigger_event(event_arguments, callback)
    trigger_ids[#trigger_ids + 1] = trigger_id
    return trigger_id
end

local function clear_triggers()
    for index = #trigger_ids, 1, -1 do
        LuaAPI.global_unregister_trigger_event(trigger_ids[index])
    end
    trigger_ids = {}
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
local function child(parent, name)
    if not parent then
        return nil
    end
    return GameAPI.get_eui_child_by_name(parent, name)
end

---@param callback fun(session: PlayerSession)
local function for_each_session(callback)
    for _, session in pairs(player_sessions) do
        callback(session)
    end
end

---@param session PlayerSession
local function initialize_session_features(session)
    local role = session.role

    ClickerController.initialize_role(session)
    MallController.initialize_role(role)
    InventoryController.initialize_role(role)
    LotteryController.initialize_role(role)
    BoothController.initialize_role(role)
    BoothInteraction.initialize_role(role)
    BoothPlacement.spawn_saved(role)
    BoothZoneView.refresh_all(role)
end

---@param role Role
local function register_role_exit_handler(role)
    register_trigger(
        { EVENT.SPEC_ROLE_EXIT_GAME, role },
        function(event_name, actor, data)
            GameApp.remove_player_session((data and data.role) or role)
        end
    )
end

---@param role Role
---@return PlayerSession|nil session
function GameApp.get_or_create_player_session(role)
    local role_id = get_role_id(role)
    if not role_id then
        LuaAPI.log("[GameApp] 无法获取 Role ID，跳过玩家会话创建", 1)
        return nil
    end

    local session = player_sessions[role_id]
    if session then
        return session
    end

    local state = PlayerState.new()
    ClickerController.initialize_state(state)
    session = {
        role_id = role_id,
        role = role,
        state = state,
        click_canvas_open = false,
    }

    player_sessions[role_id] = session
    initialize_session_features(session)
    register_role_exit_handler(role)
    LuaAPI.log("[GameApp] 玩家会话已创建: " .. tostring(role_id), 0)
    return session
end

---@param role Role
function GameApp.remove_player_session(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    player_sessions[role_id] = nil
    ClickerController.cleanup_role(role)
    LotteryController.cleanup_role(role)
    BoothPlacement.clear_role(role)
    BoothInteraction.cleanup_role(role)
    BoothController.cleanup_role(role)
    LuaAPI.log("[GameApp] 玩家会话已移除: " .. tostring(role_id), 0)
end

---@return boolean
local function resolve_app_nodes()
    world_canvas = UINodes[AppConfig.APP.canvases.world]
    click_canvas = UINodes[AppConfig.APP.canvases.click]
    if not click_canvas then
        LuaAPI.log("[GameApp] 缺少画布: " .. AppConfig.APP.canvases.click, 1)
        return false
    end

    launch_button = child(world_canvas, AppConfig.APP.buttons.launch)
    exit_button = child(click_canvas, AppConfig.APP.buttons.exit)
    return true
end

local function initialize_features()
    ClickerController.initialize(
        click_canvas,
        {
            launch = launch_button,
            exit = exit_button,
        },
        register_trigger,
        GameApp.get_or_create_player_session,
        for_each_session
    )

    LotteryController.initialize(register_trigger)
    MallController.initialize(register_trigger)
    InventoryController.initialize(register_trigger)
    BoothController.initialize(register_trigger)
    BoothZoneView.initialize()
    BoothInteraction.initialize(register_trigger)
end

function GameApp.initialize()
    if initialized then
        GameApp.shutdown()
    end

    if not resolve_app_nodes() then
        return
    end

    initialize_features()
    initialized = true

    for _, role in ipairs(GameAPI.get_all_valid_roles()) do
        GameApp.get_or_create_player_session(role)
    end

    LuaAPI.log("[GameApp] Brainrot Clicker 初始化完成", 0)
end

function GameApp.shutdown()
    clear_triggers()
    player_sessions = {}
    initialized = false
    ClickerController.shutdown()
    LuaAPI.log("[GameApp] Brainrot Clicker 已关闭", 0)
end

return GameApp
