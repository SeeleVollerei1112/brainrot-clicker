--[[
App/ControllerRegistry.lua

Controller 装配注册表。
集中管理全局初始化、玩家会话初始化、玩家会话清理和关闭顺序。
]]

local BoothController = require("Booth.BoothController")
local ClickerController = require("Clicker.ClickerController")
local InventoryController = require("Inventory.InventoryController")
local LotteryController = require("Lottery.LotteryController")
local MallController = require("Mall.MallController")
local PlayerState = require("Clicker.PlayerState")

local ControllerRegistry = {}

---@param state PlayerGameState
local function initialize_state(state)
    ClickerController.initialize_state(state)
end

---@param application Application
local function initialize_clicker(application)
    ClickerController.initialize(application.register_trigger, application.sessions.find_by_role)

    application.register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(ClickerController.PASSIVE_INCOME_INTERVAL) },
        function()
            application.sessions.for_each(ClickerController.tick_passive_income)
        end
    )

    application.register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(ClickerController.COMBO_INTERVAL) },
        function()
            application.sessions.for_each(ClickerController.tick_combo_decay)
        end
    )
end

---@param application Application
local function initialize_booth(application)
    BoothController.initialize(application.register_trigger)

    application.register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(BoothController.INCOME_TICK_INTERVAL) },
        function()
            application.sessions.for_each(function(session)
                BoothController.tick_income(session.role)
            end)
        end
    )

    application.register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(BoothController.AUTOSAVE_INTERVAL) },
        function()
            application.sessions.for_each(function(session)
                BoothController.save_now(session.role)
            end)
        end
    )
end

---@return PlayerGameState state
function ControllerRegistry.create_player_state()
    local state = PlayerState.new()
    initialize_state(state)
    return state
end

---@param application Application
function ControllerRegistry.initialize_all(application)
    initialize_clicker(application)
    LotteryController.initialize(application.register_trigger)
    MallController.initialize(application.register_trigger)
    InventoryController.initialize(application.register_trigger)
    initialize_booth(application)
end

---@param session PlayerSession
function ControllerRegistry.setup_session(session)
    ClickerController.setup_session(session)
    MallController.setup_session(session)
    InventoryController.setup_session(session)
    LotteryController.setup_session(session)
    BoothController.setup_session(session)
end

---@param session PlayerSession
function ControllerRegistry.cleanup_session(session)
    ClickerController.cleanup_session(session)
    LotteryController.cleanup_session(session)
    BoothController.cleanup_session(session)
end

function ControllerRegistry.shutdown_all()
    ClickerController.shutdown()
end

return ControllerRegistry
