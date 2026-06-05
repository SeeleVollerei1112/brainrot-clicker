-- ============================================================
-- Systems/BoothState.lua
-- Per-player booth runtime state and pure state operations.
--
-- State shape (see ---@class below):
--   unlocked[zone_id]                = true            -- 已解锁区（只存标记）
--   placements[zone_id][booth_index] = { item_id, attrs }  -- 放置的物品实例
--
-- Pure functions mutate a passed-in state, never global — mirrors
-- Systems/ShopSystem.lua. Persistence/serialization lives elsewhere
-- (Systems/BoothPersistence.lua).
-- ============================================================

local BoothConfig = require("Data.BoothConfig")

---@alias BoothAttrValue integer|string

---@class BoothItemInstance
---@field item_id integer
---@field attrs table<string, BoothAttrValue>

---@class BoothState
---@field unlocked table<integer, boolean>
---@field placements table<integer, table<integer, BoothItemInstance>>

local BoothState = {}

---Shallow-copy a flat attribute table.
---@param attrs table<string, BoothAttrValue>|nil
---@return table<string, BoothAttrValue>
local function copy_attrs(attrs)
    local result = {}
    if attrs then
        for key, value in pairs(attrs) do
            result[key] = value
        end
    end
    return result
end

---Create a fresh state: only the default zone unlocked, nothing placed.
---@return BoothState state
function BoothState.new()
    return {
        unlocked = { [BoothConfig.DEFAULT_UNLOCKED_ZONE_ID] = true },
        placements = {},
    }
end

---@param state BoothState
---@param zone_id integer
---@return boolean
function BoothState.is_zone_unlocked(state, zone_id)
    return state.unlocked[zone_id] == true
end

---Mark a zone unlocked. Returns false if the zone id is not configured.
---This is the unconditional path (used by DebugTools / 后台强制解锁)。
---@param state BoothState
---@param zone_id integer
---@return boolean success
function BoothState.unlock_zone(state, zone_id)
    if not BoothConfig.find_zone(zone_id) then
        return false
    end
    state.unlocked[zone_id] = true
    return true
end

---重新锁定某展台区（撤销解锁）。默认解锁区不允许被锁，避免开局无可用区。
---主要供调试/重置使用（DebugTools）。
---@param state BoothState
---@param zone_id integer
---@return boolean success
function BoothState.lock_zone(state, zone_id)
    if not BoothConfig.find_zone(zone_id) then
        return false
    end
    if zone_id == BoothConfig.DEFAULT_UNLOCKED_ZONE_ID then
        return false
    end
    state.unlocked[zone_id] = nil
    return true
end

---判定某展台区当前「是否满足解锁条件」。
---
---解锁条件字段（BoothZoneConfig.unlock_condition / unlock_cost）目前留空，
---本函数即为条件判定的接入点：后续策划把条件填进 config 后，在这里读取
---`condition` 求值即可，无需改动调用方。成本(unlock_cost)涉及货币，属于
---有副作用的检查，放在控制层（BoothController.try_unlock_zone）处理。
---@param state BoothState
---@param zone_id integer
---@return boolean ok, string reason
function BoothState.can_unlock(state, zone_id)
    if not BoothConfig.find_zone(zone_id) then
        return false, "zone_not_found"
    end
    if BoothState.is_zone_unlocked(state, zone_id) then
        return false, "already_unlocked"
    end

    local condition = select(1, BoothConfig.get_unlock(zone_id))
    -- 条件占位：目前 unlock_condition 为空表，恒视为满足。
    -- TODO(策划/玩法)：在此读取 condition 字段做真实判定（前置区、收集数等）。
    if type(condition) == "table" and next(condition) ~= nil then
        -- 预留分支：一旦条件非空，默认未实现的条件视为不满足，避免误放行。
        return false, "condition_unimplemented"
    end

    return true, "ok"
end

---按解锁条件尝试解锁（满足条件才解锁）。成本扣除由控制层完成。
---@param state BoothState
---@param zone_id integer
---@return boolean success, string reason
function BoothState.try_unlock(state, zone_id)
    local ok, reason = BoothState.can_unlock(state, zone_id)
    if not ok then
        return false, reason
    end
    state.unlocked[zone_id] = true
    return true, "ok"
end

---@param state BoothState
---@param zone_id integer
---@param booth_index integer
---@return BoothItemInstance|nil
function BoothState.get_placement(state, zone_id, booth_index)
    local zone_placements = state.placements[zone_id]
    if not zone_placements then
        return nil
    end
    return zone_placements[booth_index]
end

---Place an item on a booth. Requires the zone unlocked, the booth valid,
---and the item configured. The item's configured base_attrs are copied
---first, then any passed-in attrs override them.
---@param state BoothState
---@param zone_id integer
---@param booth_index integer
---@param item_id integer
---@param attrs table<string, BoothAttrValue>|nil
---@return boolean success
function BoothState.place_item(state, zone_id, booth_index, item_id, attrs)
    if not BoothState.is_zone_unlocked(state, zone_id) then
        return false
    end
    if not BoothConfig.is_valid_booth(zone_id, booth_index) then
        return false
    end
    local item = BoothConfig.find_item(item_id)
    if not item then
        return false
    end

    local zone_placements = state.placements[zone_id]
    if not zone_placements then
        zone_placements = {}
        state.placements[zone_id] = zone_placements
    end

    local instance_attrs = copy_attrs(item.base_attrs)
    if attrs then
        for key, value in pairs(attrs) do
            instance_attrs[key] = value
        end
    end

    zone_placements[booth_index] = {
        item_id = item_id,
        attrs = instance_attrs,
    }
    return true
end

---Remove whatever is placed on a booth (no-op if empty).
---@param state BoothState
---@param zone_id integer
---@param booth_index integer
---@return boolean removed
function BoothState.remove_item(state, zone_id, booth_index)
    local zone_placements = state.placements[zone_id]
    if not zone_placements or not zone_placements[booth_index] then
        return false
    end
    zone_placements[booth_index] = nil
    return true
end

---Set one attribute value on a placed item instance (per-instance mutation).
---@param state BoothState
---@param zone_id integer
---@param booth_index integer
---@param attr string
---@param value BoothAttrValue
---@return boolean success
function BoothState.set_item_attr(state, zone_id, booth_index, attr, value)
    local placement = BoothState.get_placement(state, zone_id, booth_index)
    if not placement then
        return false
    end
    placement.attrs[attr] = value
    return true
end

return BoothState
