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
