--[[
Booth/BoothPlacement.lua

展台「放置 / 回收」世界逻辑层：把背包里的物品放到展台位（在场景中创建
物品到该展台触发区域的位置），或从展台位回收到背包。状态变更与存档统一
走 BoothController（复用其 place_item / remove_item，二者自动存档）。

红线（用户约定）：不使用 drop（丢弃）功能，放置一律用
  GameAPI.create_equipment(prefab, pos) 把物品创建到指定区域；
  回收用 character.create_equipment_to_slot(prefab, BACKPACK) 回到背包。

运行时句柄（world_equipment）只在内存维护、不入档：会话开始时按存档里的
placements 重新 spawn（spawn_saved）。展台位的世界坐标按触发区域名反查
（LuaAPI.query_unit）并缓存。
]]

local BoothConfig = require("Booth.BoothConfig")
local BoothController = require("Booth.BoothController")

local BoothPlacement = {}

local BACKPACK = Enums.EquipmentSlotType.BACKPACK

-- 已放置的世界物品句柄：world_equipment[role_id]["zone|booth"] = Equipment
---@type table<RoleID, table<string, Equipment>>
local world_equipment = {}

-- 展台位世界坐标缓存：booth_pos["zone|booth"] = Vector3
local booth_pos = {}

---@param role Role
---@return RoleID|nil
local function get_role_id(role)
    local ctrl = role and role.get_ctrl_unit()
    return ctrl and ctrl.get_role_id() or nil
end

---@param zone_id integer
---@param booth_index integer
---@return string
local function slot_key(zone_id, booth_index)
    return tostring(zone_id) .. "|" .. tostring(booth_index)
end

---解析某展台位的放置坐标（触发区域中心 + 配置的 Y 偏移）。失败返回 nil。
---@param zone_id integer
---@param booth_index integer
---@return Vector3|nil
local function resolve_booth_position(zone_id, booth_index)
    local key = slot_key(zone_id, booth_index)
    if booth_pos[key] then
        return booth_pos[key]
    end
    local name = BoothConfig.booth_trigger_name(zone_id, booth_index)
    if not name then
        return nil
    end
    local unit = LuaAPI.query_unit(name)
    if not unit then
        LuaAPI.log("[BoothPlacement] 找不到展台触发区域: " .. name, 1)
        return nil
    end
    local p = unit.get_position()
    local pos = math.Vector3(p.x, p.y + BoothConfig.PLACEMENT_Y_OFFSET, p.z)
    booth_pos[key] = pos
    return pos
end

---记录/读取某展台位上的世界物品句柄。
---@param role_id RoleID
---@param zone_id integer
---@param booth_index integer
---@param equipment Equipment|nil
local function set_world_equipment(role_id, zone_id, booth_index, equipment)
    local by_slot = world_equipment[role_id]
    if not by_slot then
        by_slot = {}
        world_equipment[role_id] = by_slot
    end
    by_slot[slot_key(zone_id, booth_index)] = equipment
end

---@param role_id RoleID
---@param zone_id integer
---@param booth_index integer
---@return Equipment|nil
local function get_world_equipment(role_id, zone_id, booth_index)
    local by_slot = world_equipment[role_id]
    return by_slot and by_slot[slot_key(zone_id, booth_index)] or nil
end

---销毁一个世界物品句柄。
---@param equipment Equipment|nil
local function destroy_equipment(equipment)
    if equipment then
        equipment.destroy_equipment()
    end
end

---从玩家背包里挑一件「可放置」的物品（优先当前选中格）。
---@param character Character
---@return Equipment|nil equipment, BoothItemConfig|nil item
local function pick_backpack_item(character)
    local selected = character.get_selected_equipment()
    if selected then
        local item = BoothConfig.find_item_by_prefab(selected.get_key())
        if item then
            return selected, item
        end
    end

    local list = character.get_equipment_list_by_slot_type(BACKPACK)
    if type(list) == "table" then
        for _, equipment in ipairs(list) do
            local item = BoothConfig.find_item_by_prefab(equipment.get_key())
            if item then
                return equipment, item
            end
        end
    end
    return nil, nil
end

-- ---------- 查询 ----------

---该展台位是否已放置物品（依据存档状态）。
---@param role Role
---@param zone_id integer
---@param booth_index integer
---@return boolean
function BoothPlacement.is_occupied(role, zone_id, booth_index)
    return BoothController.get_placement(role, zone_id, booth_index) ~= nil
end

---玩家背包里当前是否有可放置的展台物品。
---@param role Role
---@return boolean
function BoothPlacement.has_placeable_item(role)
    local character = role and role.get_ctrl_unit()
    if not character then
        return false
    end
    local equipment = select(1, pick_backpack_item(character))
    return equipment ~= nil
end

-- ---------- 放置 / 回收 ----------

---把背包里一件展台物品放置到指定展台位。
---@param role Role
---@param zone_id integer
---@param booth_index integer
---@return boolean success, string reason
function BoothPlacement.place(role, zone_id, booth_index)
    local role_id = get_role_id(role)
    local character = role and role.get_ctrl_unit()
    if not role_id or not character then
        return false, "no_role"
    end
    if BoothPlacement.is_occupied(role, zone_id, booth_index) then
        return false, "occupied"
    end

    local equipment, item = pick_backpack_item(character)
    if not equipment or not item then
        return false, "no_item"
    end
    if not item.prefab_id then
        return false, "prefab_missing"
    end

    local pos = resolve_booth_position(zone_id, booth_index)
    if not pos then
        return false, "no_position"
    end

    -- 1) 写状态 + 存档（校验区已解锁 / 展台位合法 / 物品已配置）。
    if not BoothController.place_item(role, zone_id, booth_index, item.id, nil) then
        return false, "state_rejected"
    end

    -- 2) 在展台位创建世界物品（不使用 drop）。
    local world = GameAPI.create_equipment(item.prefab_id, pos)
    set_world_equipment(role_id, zone_id, booth_index, world)

    -- 3) 背包里那件物品移除（创建到场景 = 从背包取出）。
    destroy_equipment(equipment)

    LuaAPI.log("[BoothPlacement] 放置成功 z=" .. zone_id .. " b=" .. booth_index
        .. " item=" .. item.id, 0)
    return true, "ok"
end

---把展台位上的物品回收回背包。
---@param role Role
---@param zone_id integer
---@param booth_index integer
---@return boolean success, string reason
function BoothPlacement.recycle(role, zone_id, booth_index)
    local role_id = get_role_id(role)
    local character = role and role.get_ctrl_unit()
    if not role_id or not character then
        return false, "no_role"
    end

    local placement = BoothController.get_placement(role, zone_id, booth_index)
    if not placement then
        return false, "empty"
    end
    local item = BoothConfig.find_item(placement.item_id)
    local prefab_id = item and item.prefab_id

    -- 1) 回到背包。
    if prefab_id then
        character.create_equipment_to_slot(prefab_id, BACKPACK)
    else
        LuaAPI.log("[BoothPlacement] 回收物品缺少 prefab_id, 仅清状态 item="
            .. tostring(placement.item_id), 1)
    end

    -- 2) 销毁展台位上的世界物品。
    destroy_equipment(get_world_equipment(role_id, zone_id, booth_index))
    set_world_equipment(role_id, zone_id, booth_index, nil)

    -- 3) 清状态 + 存档。
    BoothController.remove_item(role, zone_id, booth_index)

    LuaAPI.log("[BoothPlacement] 回收成功 z=" .. zone_id .. " b=" .. booth_index, 0)
    return true, "ok"
end

-- ---------- 会话生命周期 ----------

---会话开始/读档后：按存档里的 placements 把世界物品重新创建出来。
---@param role Role
function BoothPlacement.spawn_saved(role)
    local role_id = get_role_id(role)
    local state = role and BoothController.get_state(role)
    if not role_id or not state then
        return
    end

    -- 清掉旧句柄（避免重复 spawn）。
    BoothPlacement.clear_role(role)

    for zone_id, zone_placements in pairs(state.placements) do
        for booth_index, placement in pairs(zone_placements) do
            local item = BoothConfig.find_item(placement.item_id)
            local prefab_id = item and item.prefab_id
            local pos = prefab_id and resolve_booth_position(zone_id, booth_index)
            if prefab_id and pos then
                local world = GameAPI.create_equipment(prefab_id, pos)
                set_world_equipment(role_id, zone_id, booth_index, world)
            end
        end
    end
end

---会话结束：销毁该玩家所有展台世界物品并清句柄。
---@param role Role
function BoothPlacement.clear_role(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end
    local by_slot = world_equipment[role_id]
    if by_slot then
        for _, equipment in pairs(by_slot) do
            destroy_equipment(equipment)
        end
    end
    world_equipment[role_id] = nil
end

return BoothPlacement
