--[[
App/PlayerSessionRegistry.lua

玩家会话注册表。
负责按 RoleID 保存、查询、遍历和移除 PlayerSession。
]]

local PlayerSessionRegistry = {}

---@type table<RoleID, PlayerSession>
local player_sessions = {}

---@param role Role
---@return RoleID|nil role_id
function PlayerSessionRegistry.get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

---@param role Role
---@return PlayerSession|nil session
function PlayerSessionRegistry.find_by_role(role)
    local role_id = PlayerSessionRegistry.get_role_id(role)
    return role_id and player_sessions[role_id] or nil
end

---@param role_id RoleID
---@return PlayerSession|nil session
function PlayerSessionRegistry.find_by_role_id(role_id)
    return player_sessions[role_id]
end

---@param session PlayerSession
function PlayerSessionRegistry.set(session)
    player_sessions[session.role_id] = session
end

---@param role Role
---@return PlayerSession|nil session
function PlayerSessionRegistry.remove_by_role(role)
    local role_id = PlayerSessionRegistry.get_role_id(role)
    if not role_id then
        return nil
    end

    local session = player_sessions[role_id]
    player_sessions[role_id] = nil
    return session
end

---@param callback fun(session: PlayerSession)
function PlayerSessionRegistry.for_each(callback)
    for _, session in pairs(player_sessions) do
        callback(session)
    end
end

function PlayerSessionRegistry.clear()
    player_sessions = {}
end

return PlayerSessionRegistry
