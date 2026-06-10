--[[
Clicker/ClickerState.lua

点击玩法的玩家状态树 + 纯逻辑（货币收益、连击、皮肤档位）。
合并自原 PlayerState / CurrencySystem / ComboSystem / SkinSystem——它们本就全部
操作同一棵 PlayerGameState、无引擎 I/O，拆成四个文件反而割裂。这里集中状态定义与
所有对状态的纯运算；表现层在 ClickerView，编排在 ClickerController。
]]

local ClickerConfig = require("Clicker.ClickerConfig")

---@class CurrencyState
---@field brainrot number
---@field total_brainrot number
---@field click_power number
---@field brainrot_per_second number

---@class ShopItemState
---@field level integer
---@field current_price number

---@class ShopState
---@field items table<integer, ShopItemState>

---@class ComboState
---@field count number
---@field multiplier number

---@class ClickerUiState
---@field canvas_open boolean 点击画布是否打开

---@class PlayerGameState
---@field currency CurrencyState
---@field shop ShopState
---@field combo ComboState
---@field ui ClickerUiState

---@class ComboUpdateResult
---@field state_changed boolean
---@field tier_changed boolean
---@field old_tier integer
---@field new_tier integer
---@field should_pop boolean

local ClickerState = {}

-- ---------- 状态树 ----------

---创建单个玩家独立的状态树。
---@return PlayerGameState state
function ClickerState.new()
    local initial = ClickerConfig.INITIAL
    return {
        currency = {
            brainrot = initial.brainrot,
            total_brainrot = initial.brainrot,
            click_power = initial.click_power,
            brainrot_per_second = initial.brainrot_per_second,
        },
        shop = {
            items = {},
        },
        combo = {
            count = 0,
            multiplier = 1,
        },
        ui = {
            canvas_open = false,
        },
    }
end

---同时增加当前可消费脑腐值和累计脑腐值。
---@param state PlayerGameState
---@param amount number
function ClickerState.add_brainrot(state, amount)
    state.currency.brainrot = state.currency.brainrot + amount
    state.currency.total_brainrot = state.currency.total_brainrot + amount
end

---玩家脑腐值足够时扣除指定数量。
---@param state PlayerGameState
---@param amount number
---@return boolean success
function ClickerState.spend_brainrot(state, amount)
    if state.currency.brainrot < amount then
        return false
    end

    state.currency.brainrot = state.currency.brainrot - amount
    return true
end

-- ---------- 货币收益 ----------

---结算一次角色点击获得的收益。
---@param state PlayerGameState
---@return number income
function ClickerState.add_click_income(state)
    local income = state.currency.click_power * state.combo.multiplier
    ClickerState.add_brainrot(state, income)
    return income
end

---结算一次被动收益。
---@param state PlayerGameState
---@return number income
function ClickerState.add_passive_income(state)
    local income = state.currency.brainrot_per_second
    if income <= 0 then
        return 0
    end

    ClickerState.add_brainrot(state, income)
    return income
end

-- ---------- 连击 ----------

---@param combo_count number
---@return integer tier
local function get_tier(combo_count)
    local tier = 0
    for tier_index, tier_configuration in ipairs(ClickerConfig.COMBO.TIERS) do
        if combo_count >= tier_configuration.threshold then
            tier = tier_index
        end
    end
    return tier
end

---@param state PlayerGameState
---@param tier integer
local function set_multiplier(state, tier)
    state.combo.multiplier = tier > 0 and ClickerConfig.COMBO.TIERS[tier].multiplier or 1
end

---处理一次点击带来的连击增长。
---@param state PlayerGameState
---@return ComboUpdateResult result
function ClickerState.add_combo_click(state)
    local combo = ClickerConfig.COMBO
    local old_tier = get_tier(state.combo.count)
    state.combo.count = math.min(state.combo.count + combo.CLICK_GAIN, combo.MAX)
    local new_tier = get_tier(state.combo.count)
    set_multiplier(state, new_tier)
    return {
        state_changed = true,
        tier_changed = new_tier ~= old_tier,
        old_tier = old_tier,
        new_tier = new_tier,
        should_pop = new_tier > 0 and new_tier == old_tier,
    }
end

---处理一次连击衰减。
---@param state PlayerGameState
---@return ComboUpdateResult result
function ClickerState.decay_combo(state)
    if state.combo.count <= 0 then
        return {
            state_changed = false,
            tier_changed = false,
            old_tier = 0,
            new_tier = 0,
            should_pop = false,
        }
    end

    local old_tier = get_tier(state.combo.count)
    state.combo.count = math.max(0, state.combo.count - ClickerConfig.COMBO.DECAY_RATE)
    local new_tier = get_tier(state.combo.count)
    set_multiplier(state, new_tier)
    return {
        state_changed = true,
        tier_changed = new_tier ~= old_tier,
        old_tier = old_tier,
        new_tier = new_tier,
        should_pop = false,
    }
end

-- ---------- 皮肤档位 ----------

---返回已达到门槛的最高皮肤索引。
---skins 需要按 threshold 升序排列；索引 1 是基础皮肤。
---@param skins table[] ordered skin tiers, each with a numeric `threshold`
---@param value number lifetime brainrot
---@return integer tier_index
function ClickerState.resolve_tier_index(skins, value)
    local tier_index = 1
    for index = 1, #skins do
        if value >= skins[index].threshold then
            tier_index = index
        else
            break
        end
    end

    return tier_index
end

return ClickerState
