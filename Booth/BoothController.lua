--[[
Booth/BoothController.lua

展台存档控制层：负责玩家展台状态的生命周期。

每个玩家的 BoothState 收归 session 状态片（key="booth"），进入时由
SessionStateRegistry 工厂读档创建，离开时由 save 钩子保存。这里也暴露
DebugTools 使用的 role 维度粗粒度操作（内部经 find_session 走 session），
每次状态变更都会立即保存，方便阶段测试。

这里只处理存档和数据，不放 EUI 与世界放置逻辑。
]]

local BoothConfig = require("Booth.BoothConfig")
local BoothState = require("Booth.BoothState")
local BoothPersistence = require("Booth.BoothPersistence")
local SessionStateRegistry = require("App.SessionStateRegistry")

local BoothController = {}

-- 展台状态片：进场读档创建，离场保存（与 Inventory 共用槽位，串行 save 不破坏合并语义）。
SessionStateRegistry.declare("booth", {
    create = function(session)
        return BoothPersistence.load(session.role)
    end,
    save = function(session)
        BoothPersistence.save(session.role, session:get_or_create_state("booth"))
    end,
})

-- 收益结算节奏 / 自动存档节奏（秒），供 GameApp 注册定时器使用。
BoothController.INCOME_TICK_INTERVAL = BoothConfig.INCOME_TICK_INTERVAL
BoothController.AUTOSAVE_INTERVAL = BoothConfig.AUTOSAVE_INTERVAL

-- 子模块延迟加载。编辑器会把顶层 require 链算进 BoothController 编译成本；
-- BoothPlacement 会继续加载合成系统，放在真正初始化/调用时再加载，避免启动编译超时。
local BoothZoneView = nil
local BoothInteraction = nil
local BoothPlacement = nil
local zone_view_bound = false
local placement_bound = false

---@type fun(role: Role): PlayerSession|nil 由 initialize 注入（application.sessions.find_by_role）
local find_session = nil

local function get_zone_view()
    if not BoothZoneView then
        BoothZoneView = require("Booth.BoothZoneView")
    end
    return BoothZoneView
end

local function get_interaction()
    if not BoothInteraction then
        BoothInteraction = require("Booth.BoothInteraction")
    end
    return BoothInteraction
end

local function get_placement()
    if not BoothPlacement then
        BoothPlacement = require("Booth.BoothPlacement")
    end
    return BoothPlacement
end

local function ensure_zone_view_bound()
    if zone_view_bound then
        return
    end
    get_zone_view().bind(BoothController)
    zone_view_bound = true
end

local function ensure_placement_bound()
    if placement_bound then
        return
    end
    get_placement().bind(BoothController)
    placement_bound = true
end

---初始化入口；作为展台系统的统一门面，在此编排子模块的全局初始化
---（场景表现层 + 交互层），并自注册收益结算 / 自动存档定时器。
---@param application Application
function BoothController.initialize(application)
    local register_trigger = application.register_trigger
    find_session = application.sessions.find_by_role

    ensure_zone_view_bound()
    get_zone_view().initialize()
    get_interaction().initialize(register_trigger)

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
    local role = session.role
    local state = session:get_or_create_state("booth")

    -- 离线收益结算放在刷新展现之前，让公告板直接显示结算后的总收益。
    local offline_gain, offline_sec = BoothController.settle_offline(role, state)

    ensure_zone_view_bound()
    ensure_placement_bound()
    get_interaction().initialize_role(role)
    get_placement().spawn_saved(role)
    get_zone_view().refresh_all(role)

    if offline_gain > 0 and offline_sec >= (BoothConfig.OFFLINE.min_notify_seconds or 0) then
        role.show_tips("欢迎回来，离线收益 +" .. tostring(offline_gain))
    end
end

---@param role Role
function BoothController.initialize_role(role)
    BoothController.setup_session({ role = role })
end

---玩家离开时编排子模块清理（销毁世界放置物、清交互记录）。
---状态保存由 SessionStateRegistry 的 save 钩子在清理后统一执行。
---@param session PlayerSession
function BoothController.cleanup_session(session)
    local role = session.role
    ensure_zone_view_bound()
    ensure_placement_bound()
    get_placement().clear_role(role)
    get_interaction().cleanup_role(role)
    get_zone_view().clear_labels(role)
end

---@param role Role
function BoothController.cleanup_role(role)
    BoothController.cleanup_session({ role = role })
end

---获取玩家当前展台状态（经 session 状态片，未创建时由工厂读档创建）。
---@param role Role
---@return BoothState|nil state
function BoothController.get_state(role)
    local session = find_session and find_session(role)
    if not session then
        return nil
    end
    return session:get_or_create_state("booth")
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

    for _, zone in ipairs(BoothConfig.ZONES) do
        if BoothState.is_zone_unlocked(state, zone.id) then
            get_zone_view().refresh_board(role, zone.id)
            for booth_index = 0, zone.booth_count - 1 do
                get_zone_view().refresh_booth_label(role, zone.id, booth_index)
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
    ensure_zone_view_bound()
    get_zone_view().refresh_zone(role, zone_id)
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
    ensure_zone_view_bound()
    get_zone_view().refresh_zone(role, zone_id)
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
    ensure_zone_view_bound()
    get_zone_view().refresh_zone(role, zone_id)
    return true, "ok"
end

---@param role Role
---@param zone_id integer
---@param booth_index integer
---@param item_id integer
---@param attrs table<string, integer|string>|nil
---@param preserve_booth_income boolean|nil
---@return boolean success
function BoothController.place_item(role, zone_id, booth_index, item_id, attrs, preserve_booth_income)
    local state = BoothController.get_state(role)
    if not state or not BoothState.place_item(state, zone_id, booth_index, item_id, attrs, preserve_booth_income) then
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
