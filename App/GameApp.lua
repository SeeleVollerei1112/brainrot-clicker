--[[
App/GameApp.lua

应用生命周期与功能装配入口。
负责应用生命周期、玩家会话创建入口，并协调注册表清理。
]]

local ControllerRegistry = require("App.ControllerRegistry")
local PlayerSessionRegistry = require("App.PlayerSessionRegistry")
local SessionStateRegistry = require("App.SessionStateRegistry")
local TriggerRegistry = require("App.TriggerRegistry")
local get_role_id = require("Util.RoleUtil").get_role_id

---@class PlayerSession
---@field role Role 玩家对象
---@field states table<string, any> 各功能状态片（键与工厂见 SessionStateRegistry 声明）
---@field click_canvas_open boolean 点击界面是否打开
---@field get_or_create_state fun(self: PlayerSession, key: string): any

local GameApp = {}

local initialized = false

---惰性取功能状态片：首次访问时调用 SessionStateRegistry 声明的工厂创建。
---@param self PlayerSession
---@param key string
---@return any state
local function get_or_create_state(self, key)
    local state = self.states[key]
    if state == nil then
        state = SessionStateRegistry.create(key, self)
        self.states[key] = state
    end
    return state
end

---@class Application
---@field register_trigger fun(event_arguments: table, callback: function): integer
---@field sessions table

---@param role Role
local function register_role_exit_handler(role)
    TriggerRegistry.register(
        { EVENT.SPEC_ROLE_EXIT_GAME, role },
        function(event_name, actor, data)
            GameApp.remove_player_session(data.role)
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

    local session = PlayerSessionRegistry.find_by_role(role)
    if session then return session end

    session = {
        role = role,
        states = {},
        click_canvas_open = false,
        get_or_create_state = get_or_create_state,
    }

    PlayerSessionRegistry.set(session)
    SessionStateRegistry.restore_all(session)
    ControllerRegistry.setup_session(session)
    register_role_exit_handler(role)
    LuaAPI.log("[GameApp] 玩家会话已创建: " .. tostring(role_id), 0)
    return session
end

---@param role Role
function GameApp.remove_player_session(role)
    local role_id = get_role_id(role)
    local session = PlayerSessionRegistry.remove_by_role(role)
    if not session then return end

    ControllerRegistry.cleanup_session(session)
    SessionStateRegistry.save_all(session)
    LuaAPI.log("[GameApp] 玩家会话已移除: " .. tostring(role_id), 0)
end

function GameApp.initialize()
    if initialized then GameApp.shutdown() end

    local application = {
        register_trigger = TriggerRegistry.register,
        sessions = PlayerSessionRegistry,
    }

    ControllerRegistry.initialize_all(application)
    initialized = true

    for _, role in ipairs(GameAPI.get_all_valid_roles()) do
        GameApp.get_or_create_player_session(role)
    end

    LuaAPI.log("[GameApp] Brainrot Clicker 初始化完成", 0)
end

function GameApp.shutdown()
    TriggerRegistry.clear()
    PlayerSessionRegistry.clear()
    initialized = false
    ControllerRegistry.shutdown_all()
    LuaAPI.log("[GameApp] Brainrot Clicker 已关闭", 0)
end

return GameApp
