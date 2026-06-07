--[[
App/ControllerRegistry.lua

Controller 装配注册表。
集中管理全局初始化、玩家会话初始化、玩家会话清理和关闭顺序。

各 Controller 遵循统一接口（钩子均为可选）：
  initialize(application)   -- 全局初始化 + 自注册定时器
  setup_session(session)    -- 玩家会话级初始化
  cleanup_session(session)  -- 玩家会话级清理
  shutdown()                -- 全局关闭
定时器（REPEAT_TIMEOUT）由各 Controller 在自己的 initialize 内通过
application.register_trigger + application.sessions.for_each 自注册，本注册表
不再承担任何功能专属的定时编排。
]]

local BoothController = require("Booth.BoothController")
local ClickerController = require("Clicker.ClickerController")
local InventoryController = require("Inventory.InventoryController")
local LotteryController = require("Lottery.LotteryController")
local MallController = require("Mall.MallController")
local PlayerState = require("Clicker.PlayerState")

local ControllerRegistry = {}

-- 装配顺序：initialize / setup_session 按此正序，cleanup_session / shutdown 按逆序拆解。
local controllers = {
    ClickerController,
    LotteryController,
    MallController,
    InventoryController,
    BoothController,
}

---@return PlayerGameState state
function ControllerRegistry.create_player_state()
    local state = PlayerState.new()
    ClickerController.initialize_state(state)
    return state
end

---@param application Application
function ControllerRegistry.initialize_all(application)
    for _, controller in ipairs(controllers) do
        if controller.initialize then
            controller.initialize(application)
        end
    end
end

---@param session PlayerSession
function ControllerRegistry.setup_session(session)
    for _, controller in ipairs(controllers) do
        if controller.setup_session then
            controller.setup_session(session)
        end
    end
end

---@param session PlayerSession
function ControllerRegistry.cleanup_session(session)
    for index = #controllers, 1, -1 do
        local controller = controllers[index]
        if controller.cleanup_session then
            controller.cleanup_session(session)
        end
    end
end

function ControllerRegistry.shutdown_all()
    for index = #controllers, 1, -1 do
        local controller = controllers[index]
        if controller.shutdown then
            controller.shutdown()
        end
    end
end

return ControllerRegistry
