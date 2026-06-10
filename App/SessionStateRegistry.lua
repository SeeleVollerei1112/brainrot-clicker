--[[
App/SessionStateRegistry.lua

玩家会话状态注册表。
各功能在此集中声明自己的状态钩子（均为可选子集）：
  create(session)  -- 状态工厂：session:get_or_create_state(key) 首次访问时调用
  restore(session) -- 会话创建时恢复（用于状态在引擎侧、无内存态的功能）
  save(session)    -- 会话移除时保存

restore_all / save_all 按声明顺序串行执行——帧同步要求确定性，
不能用 pairs 遍历哈希表。
]]

local SessionStateRegistry = {}

---@class SessionStateSpec
---@field create nil|fun(session: PlayerSession): any
---@field restore nil|fun(session: PlayerSession)
---@field save nil|fun(session: PlayerSession)

---@type table<string, SessionStateSpec>
local specs = {}
---@type string[] 声明顺序（保证遍历确定性）
local declared_keys = {}

---@param key string
---@param spec SessionStateSpec
function SessionStateRegistry.declare(key, spec)
    if not specs[key] then
        declared_keys[#declared_keys + 1] = key
    end
    specs[key] = spec
end

---由 session:get_or_create_state 调用，外部不直接使用。
---@param key string
---@param session PlayerSession
---@return any state
function SessionStateRegistry.create(key, session)
    return specs[key].create(session)
end

---@param session PlayerSession
function SessionStateRegistry.restore_all(session)
    for _, key in ipairs(declared_keys) do
        local restore = specs[key].restore
        if restore then
            restore(session)
        end
    end
end

---@param session PlayerSession
function SessionStateRegistry.save_all(session)
    for _, key in ipairs(declared_keys) do
        local save = specs[key].save
        if save then
            save(session)
        end
    end
end

return SessionStateRegistry
