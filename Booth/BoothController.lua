-- ============================================================
-- Booth/BoothController.lua
-- Booth save-layer lifecycle + per-player state registry.
--
-- Holds each player's BoothState (keyed by role_id), loads it on join
-- and saves it on leave — wired from GameController exactly like the
-- Lottery/Inventory controllers. Also exposes coarse operations used by
-- the DebugTools plugin buttons (each mutation auto-saves for testing).
--
-- This is the SAVE/data layer only; no booth EUI or placement gameplay.
-- ============================================================

local BoothState = require("Systems.BoothState")
local BoothPersistence = require("Systems.BoothPersistence")

local BoothController = {}

---@type table<RoleID, BoothState>
local state_by_role_id = {}

---@param role Role
---@return RoleID|nil role_id
local function get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

---Shared init hook (kept for parity with other controllers). No-op for now.
---@param register_trigger fun(event_arguments: table, callback: function): integer
function BoothController.initialize(register_trigger)
    -- 存档层暂无需注册引擎事件；保留签名与其它控制器一致。
end

---Load (or freshly create) a joining player's booth state.
---@param role Role
function BoothController.initialize_role(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end
    state_by_role_id[role_id] = BoothPersistence.load(role)
end

---Persist and drop a leaving player's booth state.
---@param role Role
function BoothController.cleanup_role(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end
    local state = state_by_role_id[role_id]
    if state then
        BoothPersistence.save(role, state)
    end
    state_by_role_id[role_id] = nil
end

---Get a player's live booth state (lazily creating one if absent).
---@param role Role
---@return BoothState|nil state
function BoothController.get_state(role)
    local role_id = get_role_id(role)
    if not role_id then
        return nil
    end
    local state = state_by_role_id[role_id]
    if not state then
        state = BoothPersistence.load(role)
        state_by_role_id[role_id] = state
    end
    return state
end

---Persist a player's current state immediately.
---@param role Role
function BoothController.save_now(role)
    local state = BoothController.get_state(role)
    if state then
        BoothPersistence.save(role, state)
    end
end

---Serialize a player's current state to JSON (for debug inspection).
---@param role Role
---@return string json
function BoothController.dump_json(role)
    local state = BoothController.get_state(role)
    if not state then
        return ""
    end
    return BoothPersistence.to_json(state)
end

-- ---------- coarse mutations (auto-save; used by DebugTools) ----------

---@param role Role
---@param zone_id integer
---@return boolean success
function BoothController.unlock_zone(role, zone_id)
    local state = BoothController.get_state(role)
    if not state or not BoothState.unlock_zone(state, zone_id) then
        return false
    end
    BoothPersistence.save(role, state)
    return true
end

---@param role Role
---@param zone_id integer
---@param booth_index integer
---@param item_id integer
---@param attrs table<string, integer|string>|nil
---@return boolean success
function BoothController.place_item(role, zone_id, booth_index, item_id, attrs)
    local state = BoothController.get_state(role)
    if not state or not BoothState.place_item(state, zone_id, booth_index, item_id, attrs) then
        return false
    end
    BoothPersistence.save(role, state)
    return true
end

---@param role Role
---@param zone_id integer
---@param booth_index integer
---@return boolean removed
function BoothController.remove_item(role, zone_id, booth_index)
    local state = BoothController.get_state(role)
    if not state or not BoothState.remove_item(state, zone_id, booth_index) then
        return false
    end
    BoothPersistence.save(role, state)
    return true
end

---@param role Role
---@param zone_id integer
---@param booth_index integer
---@param attr string
---@param value integer|string
---@return boolean success
function BoothController.set_item_attr(role, zone_id, booth_index, attr, value)
    local state = BoothController.get_state(role)
    if not state or not BoothState.set_item_attr(state, zone_id, booth_index, attr, value) then
        return false
    end
    BoothPersistence.save(role, state)
    return true
end

return BoothController
