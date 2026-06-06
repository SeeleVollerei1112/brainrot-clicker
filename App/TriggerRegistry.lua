--[[
App/TriggerRegistry.lua

全局触发器托管。
统一记录 App 生命周期内注册的触发器，便于 shutdown / 重新初始化时清理。
]]

local TriggerRegistry = {}

---@type integer[]
local trigger_ids = {}

---@param event_arguments table
---@param callback function
---@return integer trigger_id
function TriggerRegistry.register(event_arguments, callback)
    local trigger_id = LuaAPI.global_register_trigger_event(event_arguments, callback)
    trigger_ids[#trigger_ids + 1] = trigger_id
    return trigger_id
end

function TriggerRegistry.clear()
    for index = #trigger_ids, 1, -1 do
        LuaAPI.global_unregister_trigger_event(trigger_ids[index])
    end
    trigger_ids = {}
end

return TriggerRegistry
