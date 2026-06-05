--[[
Combo/ComboSystem.lua

连击纯业务计算：点击累积、自然衰减和倍率档位变更。
]]

local ComboSystem = {}
local ComboConfig = require("Combo.ComboConfig")

---@class ComboUpdateResult
---@field state_changed boolean
---@field tier_changed boolean
---@field old_tier integer
---@field new_tier integer
---@field should_pop boolean

---@param combo_count number
---@return integer tier
local function get_tier(combo_count)
    local tier = 0
    for tier_index, tier_configuration in ipairs(ComboConfig.TIERS) do
        if combo_count >= tier_configuration.threshold then
            tier = tier_index
        end
    end
    return tier
end

---@param state PlayerGameState
---@param tier integer
local function set_multiplier(state, tier)
    state.combo.multiplier = tier > 0 and ComboConfig.TIERS[tier].multiplier or 1
end

---处理一次点击带来的连击增长。
---@param state PlayerGameState
---@return ComboUpdateResult result
function ComboSystem.add_click(state)
    local old_tier = get_tier(state.combo.count)
    state.combo.count = math.min(state.combo.count + ComboConfig.CLICK_GAIN, ComboConfig.MAX)
    state.combo.last_click_tick = state.combo.tick_counter

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
function ComboSystem.decay(state)
    state.combo.tick_counter = state.combo.tick_counter + 1
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
    state.combo.count = math.max(0, state.combo.count - ComboConfig.DECAY_RATE)
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

return ComboSystem
