--[[
Booth/BoothController.lua

展台存档控制层：负责玩家展台状态的生命周期和角色维度状态表。

每个玩家持有一份 BoothState（以 role_id 为键），进入时读取，离开时保存。
接入方式与 Lottery / Inventory 控制器一致。这里也暴露 DebugTools 使用的
粗粒度操作，每次状态变更都会立即保存，方便阶段测试。

这里只处理存档和数据，不放 EUI 与世界放置逻辑。
]]

local BoothConfig = require("Booth.BoothConfig")
local BoothState = require("Booth.BoothState")
local BoothPersistence = require("Booth.BoothPersistence")

local BoothController = {}

-- 收益结算节奏 / 自动存档节奏（秒），供 GameApp 注册定时器使用。
BoothController.INCOME_TICK_INTERVAL = BoothConfig.INCOME_TICK_INTERVAL
BoothController.AUTOSAVE_INTERVAL = BoothConfig.AUTOSAVE_INTERVAL

-- 编排的子模块（场景表现层 / 交互层 / 放置层）。这些子模块反过来 require 本控制器，
-- 为避免加载期循环依赖拿到半初始化的模块表，这里延迟到首次使用时再 require 并缓存。
local BoothZoneView, BoothInteraction, BoothPlacement

local function submodules()
    BoothZoneView = BoothZoneView or require("Booth.BoothZoneView")
    BoothInteraction = BoothInteraction or require("Booth.BoothInteraction")
    BoothPlacement = BoothPlacement or require("Booth.BoothPlacement")
    return BoothZoneView, BoothInteraction, BoothPlacement
end

---@type table<RoleID, BoothState>
local state_by_role_id = {}

---@param role Role
---@return RoleID|nil role_id
local function get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

---初始化入口；作为展台系统的统一门面，在此编排子模块的全局初始化
---（场景表现层 + 交互层），并自注册收益结算 / 自动存档定时器。
---@param application Application
function BoothController.initialize(application)
    local register_trigger = application.register_trigger
    local zone_view, interaction = submodules()
    zone_view.initialize()
    interaction.initialize(register_trigger)

    -- 收益结算定时器：仅内存累加 + 刷新公告板
    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(BoothController.INCOME_TICK_INTERVAL) },
        function()
            application.sessions.for_each(function(session)
                BoothController.tick_income(session.role)
            end)
        end
    )

    -- 自动存档定时器
    register_trigger(
        { EVENT.REPEAT_TIMEOUT, math.tofixed(BoothController.AUTOSAVE_INTERVAL) },
        function()
            application.sessions.for_each(function(session)
                BoothController.save_now(session.role)
            end)
        end
    )
end

---玩家进入时读取或创建展台状态，并编排子模块的角色级初始化：
---初始隐藏交互按钮、按存档重建世界放置物、刷新所有展区场景表现。
---@param session PlayerSession
function BoothController.setup_session(session)
    local role = session and session.role
    local role_id = get_role_id(role)
    if not role_id then
        return
    end
    local state = BoothPersistence.load(role)
    state_by_role_id[role_id] = state

    -- 离线收益结算放在刷新展现之前，让公告板直接显示结算后的总收益。
    local offline_gain, offline_sec = BoothController.settle_offline(role, state)

    local zone_view, interaction, placement = submodules()
    interaction.initialize_role(role)
    placement.spawn_saved(role)
    zone_view.refresh_all(role)

    if offline_gain > 0 and offline_sec >= (BoothConfig.OFFLINE.min_notify_seconds or 0) then
        role.show_tips("欢迎回来，离线收益 +" .. tostring(offline_gain))
    end
end

---@param role Role
function BoothController.initialize_role(role)
    BoothController.setup_session({ role = role })
end

---玩家离开时编排子模块清理（销毁世界放置物、清交互记录），再保存并移除展台状态。
---@param session PlayerSession
function BoothController.cleanup_session(session)
    local role = session and session.role
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    local zone_view, interaction, placement = submodules()
    placement.clear_role(role)
    interaction.cleanup_role(role)
    zone_view.clear_labels(role)

    local state = state_by_role_id[role_id]
    if state then
        BoothPersistence.save(role, state)
    end
    state_by_role_id[role_id] = nil
end

---@param role Role
function BoothController.cleanup_role(role)
    BoothController.cleanup_session({ role = role })
end

---获取玩家当前展台状态；不存在时现场读取。
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

---只读查询某个展台位上的放置物。
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

---立即保存玩家当前展台状态。
---@param role Role
function BoothController.save_now(role)
    local state = BoothController.get_state(role)
    if state then
        BoothPersistence.save(role, state)
    end
end

---离线收益结算：玩家回归时按「存档游标 last_ts -> 现在」的真实时长结算一笔
---（离线倍率 + 离线封顶），并入各展区总收益。游标随存档 blob 原子推进，所以即使
---退出事件没触发、或上次会话异常结束，也只会结算未结算过的那段时间，不会重复。
---结算后立即落盘（把推进后的游标 + 收益写下，作为本次会话与下次离线的新基准）。
---@param role Role
---@param state BoothState
---@return integer gained 离线收益总额
---@return integer elapsed 离线秒数
function BoothController.settle_offline(role, state)
    if not state then
        return 0, 0
    end
    local gained, elapsed = BoothState.accrue_to(state, GameAPI.get_timestamp(),
        BoothConfig.OFFLINE.rate or 1.0, BoothConfig.OFFLINE.max_seconds or 0)
    -- 即使本次无收益（首次登录立基准 / 无放置物）也要落盘，写下新游标基准。
    BoothPersistence.save(role, state)
    if gained > 0 then
        LuaAPI.log("[BoothController] 离线收益结算 sec=" .. tostring(elapsed)
            .. " total=" .. tostring(gained), 0)
    end
    return gained, elapsed
end

---在线收益结算节拍：与离线共用 accrue_to（在线倍率 1.0、不封顶），按真实时间戳差
---把收益累加进总收益并推进游标。仅内存累加 + 刷新公告板，不每秒落盘（落盘走放置/
---回收等操作与 GameApp 的定时自动存档；即使中途崩溃，未落盘的时间下次登录会作为
---离线收益补回，不会丢失）。
---@param role Role
function BoothController.tick_income(role)
    local state = BoothController.get_state(role)
    if not state then
        return
    end
    local gained = BoothState.accrue_to(state, GameAPI.get_timestamp(), 1.0, 0)
    if gained <= 0 then
        return
    end

    local zone_view = submodules()
    for _, zone in ipairs(BoothConfig.ZONES) do
        if BoothState.is_zone_unlocked(state, zone.id) then
            zone_view.refresh_board(role, zone.id)
            for booth_index = 0, zone.booth_count - 1 do
                zone_view.refresh_booth_label(role, zone.id, booth_index)
            end
        end
    end
end

---把玩家当前展台状态序列化为 JSON，供调试查看。
---@param role Role
---@return string json
function BoothController.dump_json(role)
    local state = BoothController.get_state(role)
    if not state then
        return ""
    end
    return BoothPersistence.to_json(state)
end

-- ---------- 粗粒度状态变更（自动保存，供 DebugTools 使用） ----------

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
    local zone_view = submodules()
    zone_view.refresh_zone(role, zone_id)
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
    local zone_view = submodules()
    zone_view.refresh_zone(role, zone_id)
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
    local zone_view = submodules()
    zone_view.refresh_zone(role, zone_id)
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
