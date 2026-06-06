--[[
App/GameApp.lua

应用生命周期与功能装配入口。
这里直接持有玩家会话表和触发器编号，避免为了简单表操作再包一层模块。
]]

local BoothController = require("Booth.BoothController")
local ClickerController = require("Clicker.ClickerController")
local InventoryController = require("Inventory.InventoryController")
local LotteryController = require("Lottery.LotteryController")
local MallController = require("Mall.MallController")
local PlayerState = require("Clicker.PlayerState")

---@class PlayerSession
---@field role_id RoleID 玩家 ID
---@field role Role 玩家对象
---@field state PlayerGameState 玩家运行时状态
---@field click_canvas_open boolean 点击界面是否打开

local GameApp = {}

---@type table<RoleID, PlayerSession>
local player_sessions = {}

---@param role Role
---@return PlayerSession|nil
local function find_session(role)
    local control_unit = role and role.get_ctrl_unit()
    local role_id = control_unit and control_unit.get_role_id()
    return role_id and player_sessions[role_id] or nil
end

---@type integer[]
local trigger_ids = {}

local initialized = false

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

---@param callback fun(session: PlayerSession)
local function for_each_session(callback)
    for _, session in pairs(player_sessions) do
        callback(session)
    end
end

---@param session PlayerSession
local function setup_player(session)
    local role = session.role

    ClickerController.initialize_role(session)
    MallController.initialize_role(role)
    InventoryController.initialize_role(role)
    LotteryController.initialize_role(role)
    BoothController.initialize_role(role)
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
    setup_player(session)
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
    BoothController.cleanup_role(role)
    LuaAPI.log("[GameApp] 玩家会话已移除: " .. tostring(role_id), 0)
end

local function setup_controllers()
    ClickerController.initialize(register_trigger, find_session)

    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(ClickerController.PASSIVE_INCOME_INTERVAL) },
        function()
            for_each_session(ClickerController.tick_passive_income)
        end
    )

    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(ClickerController.COMBO_INTERVAL) },
        function()
            for_each_session(ClickerController.tick_combo_decay)
        end
    )

    LotteryController.initialize(register_trigger)
    MallController.initialize(register_trigger)
    InventoryController.initialize(register_trigger)
    BoothController.initialize(register_trigger)

    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(BoothController.INCOME_TICK_INTERVAL) },
        function()
            for_each_session(function(session)
                BoothController.tick_income(session.role)
            end)
        end
    )

    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(BoothController.AUTOSAVE_INTERVAL) },
        function()
            for_each_session(function(session)
                BoothController.save_now(session.role)
            end)
        end
    )
end

function GameApp.initialize()
    if initialized then
        GameApp.shutdown()
    end

    setup_controllers()
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
