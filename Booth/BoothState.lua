--[[
Booth/BoothState.lua

单个玩家的展台运行时状态，以及只修改传入 state 的纯状态操作。

状态结构（详见下方 ---@class）：
  unlocked[zone_id]                = true                  已解锁区（只存标记）
  placements[zone_id][booth_index] = { item_id, attrs }    放置的物品实例
  booth_income[zone_id][booth]     = total                 单个展台位累计收益

这些函数不持有全局玩家状态；存档和序列化放在 Booth/BoothPersistence.lua。
]]

local BoothConfig = require("Booth.BoothConfig")

---@alias BoothAttrValue integer|string

---@class BoothItemInstance
---@field item_id integer
---@field attrs table<string, BoothAttrValue>

---@class BoothState
---@field unlocked table<integer, boolean>
---@field placements table<integer, table<integer, BoothItemInstance>>
---@field zone_income table<integer, integer>  各展区随时间累计的总收益（整数，入档）
---@field booth_income table<integer, table<integer, integer>>  各展台位随时间累计的总收益（整数，入档）
---@field last_ts integer  收益已结算到的真实时间戳（游标，入档；0=尚无基准）

local BoothState = {}

---复制一层扁平属性表。
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

---创建新状态：只解锁默认展区，所有展台位为空。
---@return BoothState state
function BoothState.new()
    return {
        unlocked = { [BoothConfig.DEFAULT_UNLOCKED_ZONE_ID] = true },
        placements = {},
        zone_income = {},
        booth_income = {},
        last_ts = 0,
    }
end

---@param state BoothState
---@param zone_id integer
---@return boolean
function BoothState.is_zone_unlocked(state, zone_id)
    return state.unlocked[zone_id] == true
end

---标记展区已解锁。展区未配置时返回 false。
---这是无条件解锁路径，供 DebugTools / 后台强制解锁使用。
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

---在展台位上放置物品。
---要求展区已解锁、展台位合法、物品已配置。先复制配置里的 base_attrs，
---再用传入 attrs 覆盖。
---@param state BoothState
---@param zone_id integer
---@param booth_index integer
---@param item_id integer
---@param attrs table<string, BoothAttrValue>|nil
---@param preserve_booth_income boolean|nil
---@return boolean success
function BoothState.place_item(state, zone_id, booth_index, item_id, attrs, preserve_booth_income)
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

    local zone_booth_income = state.booth_income[zone_id]
    if not zone_booth_income then
        zone_booth_income = {}
        state.booth_income[zone_id] = zone_booth_income
    end
    if not preserve_booth_income then
        zone_booth_income[booth_index] = 0
    else
        zone_booth_income[booth_index] = zone_booth_income[booth_index] or 0
    end
    return true
end

---移除展台位上的物品；空位返回 false。
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
    local zone_booth_income = state.booth_income[zone_id]
    if zone_booth_income then
        zone_booth_income[booth_index] = nil
    end
    return true
end

-- ---------- 收益 ----------

---某展区当前「每秒收益」= 该区所有已放置实例 income_per_second 之和（整数）。
---@param state BoothState
---@param zone_id integer
---@return integer income_per_second
function BoothState.zone_income_per_second(state, zone_id)
    local sum = 0
    local zone_placements = state.placements[zone_id]
    if zone_placements then
        for _, instance in pairs(zone_placements) do
            local per_second = instance.attrs and instance.attrs.income_per_second
            if type(per_second) == "number" then
                sum = sum + math.tointeger(per_second)
            end
        end
    end
    return sum
end

---某展区随时间累计的总收益（整数）。
---@param state BoothState
---@param zone_id integer
---@return integer income_total
function BoothState.zone_income_total(state, zone_id)
    return state.zone_income[zone_id] or 0
end

---某展台位随时间累计的总收益（整数）。
---@param state BoothState
---@param zone_id integer
---@param booth_index integer
---@return integer income_total
function BoothState.booth_income_total(state, zone_id, booth_index)
    local zone_booth_income = state.booth_income[zone_id]
    return zone_booth_income and zone_booth_income[booth_index] or 0
end

---把「上次结算游标 last_ts -> now」这段真实时间的收益累加进各展区总收益，并把
---游标推进到 now。在线 tick 与离线结算共用本函数（区别仅在传入的 rate / max_seconds）：
---  - 在线：now 与 last_ts 仅差一个 tick，elapsed≈1，rate=1.0；
---  - 离线：玩家回归时 last_ts 是上次落盘的游标，elapsed=整段离线时长。
---游标随 state 一起入档，保证 zone_income 与 last_ts 原子推进，天然防重复结算，
---且不依赖退出事件。倍率在「每秒收益」小数量级上先折算再乘以秒数（整数×整数），
---规避无上限离线时大数 × Fixed 的精度/溢出问题。
---@param state BoothState
---@param now integer 当前真实时间戳（GameAPI.get_timestamp()）
---@param rate Fixed 收益倍率（在线传 1.0，离线传 BoothConfig.OFFLINE.rate）
---@param max_seconds integer 本次结算封顶秒数；<=0 表示不封顶
---@return integer gained 本次累加的总额
---@return integer elapsed 实际结算的秒数
function BoothState.accrue_to(state, now, rate, max_seconds)
    local last = state.last_ts
    state.last_ts = now

    -- 首次（无基准）只立基准、不结算。
    if last <= 0 then
        return 0, 0
    end

    local elapsed = GameAPI.get_timestamp_diff(now, last)
    if type(elapsed) ~= "number" or elapsed <= 0 then
        return 0, 0
    end
    if max_seconds and max_seconds > 0 and elapsed > max_seconds then
        elapsed = max_seconds
    end

    local total = 0
    for zone_id in pairs(state.unlocked) do
        local zone_placements = state.placements[zone_id]
        if zone_placements then
            local zone_booth_income = state.booth_income[zone_id]
            if not zone_booth_income then
                zone_booth_income = {}
                state.booth_income[zone_id] = zone_booth_income
            end

            for booth_index, instance in pairs(zone_placements) do
                local per_second = instance.attrs and instance.attrs.income_per_second
                if type(per_second) == "number" then
                    local effective = math.tointeger(math.floor(per_second * rate)) or 0
                    if effective > 0 then
                        local gain = effective * elapsed
                        zone_booth_income[booth_index] = (zone_booth_income[booth_index] or 0) + gain
                        state.zone_income[zone_id] = (state.zone_income[zone_id] or 0) + gain
                        total = total + gain
                    end
                end
            end
        end
    end
    return total, elapsed
end

return BoothState
