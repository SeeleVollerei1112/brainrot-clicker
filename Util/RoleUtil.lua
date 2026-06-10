--[[
Util/RoleUtil.lua

Role 通用工具：role -> role_id 的统一取法（原先 6 个文件各抄一份）。
]]

local RoleUtil = {}

---@param role Role|nil
---@return RoleID|nil role_id
function RoleUtil.get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

return RoleUtil
