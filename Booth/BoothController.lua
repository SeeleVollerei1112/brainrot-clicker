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

local BoothConfig = require("Data.BoothConfig")
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

---Read what is placed on a booth (nil if empty / no state). Read-only.
---@param role Role
---@param zone_id integer
---@param booth_index integer
---@return BoothItemInstance|nil
function BoothController.get_placement(role, zone_id, booth_index)
    local state = BoothController.get_state(role)
    if not state then
        return nil
    end
    return BoothState.get_placement(state, zone_id, booth_index)
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

---强制解锁（不校验条件/成本）。供 DebugTools 后台直接解锁使用。
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

---重新锁定展台区（撤销解锁，默认区不可锁）。供调试/重置使用。
---@param role Role
---@param zone_id integer
---@return boolean success
function BoothController.lock_zone(role, zone_id)
    local state = BoothController.get_state(role)
    if not state or not BoothState.lock_zone(state, zone_id) then
        return false
    end
    BoothPersistence.save(role, state)
    return true
end

---按解锁条件 + 成本尝试解锁（正式玩法入口）。
---条件判定走 BoothState.can_unlock（目前条件留空恒通过）；成本走 unlock_cost
---字段：若 cost>0 且提供了 spend_fn，则先扣费（扣费失败则不解锁）。这样把
---unlock_condition / unlock_cost 两个字段完整接入，后续填充条件/接入货币即可。
---@param role Role
---@param zone_id integer
---@param spend_fn fun(cost: integer): boolean|nil   可选扣费回调（返回是否扣费成功）
---@return boolean success, string reason
function BoothController.try_unlock_zone(role, zone_id, spend_fn)
    local state = BoothController.get_state(role)
    if not state then
        return false, "no_state"
    end

    local ok, reason = BoothState.can_unlock(state, zone_id)
    if not ok then
        return false, reason
    end

    local _, cost = BoothConfig.get_unlock(zone_id)
    cost = cost or 0
    if cost > 0 and spend_fn then
        if not spend_fn(cost) then
            return false, "insufficient_cost"
        end
    end

    BoothState.unlock_zone(state, zone_id)
    BoothPersistence.save(role, state)
    return true, "ok"
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
