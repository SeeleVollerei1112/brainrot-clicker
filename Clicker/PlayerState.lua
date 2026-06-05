--[[
Clicker/PlayerState.lua

单个玩家的点击玩法状态树，以及最基础的脑腐值增减操作。
]]

local ClickerConfig = require("Clicker.ClickerConfig")

---@class CurrencyState
---@field brainrot number
---@field total_brainrot number
---@field click_power number
---@field brainrot_per_second number

---@class ShopItemState
---@field count integer
---@field level integer
---@field current_price number

---@class ShopState
---@field items table<integer, ShopItemState>

---@class ComboState
---@field count number
---@field multiplier number
---@field tick_counter integer
---@field last_click_tick integer

---@class EasterEggState
---@field active boolean
---@field brainrot_per_second_bonus_active boolean

---@class PlayerGameState
---@field currency CurrencyState
---@field shop ShopState
---@field combo ComboState
---@field easter_egg EasterEggState

local PlayerState = {}

---创建单个玩家独立的状态树。
---@return PlayerGameState state
function PlayerState.new()
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
            count = initial.combo_count,
            multiplier = initial.combo_multiplier,
            tick_counter = initial.tick_counter,
            last_click_tick = initial.tick_counter,
        },
        easter_egg = {
            active = false,
            brainrot_per_second_bonus_active = false,
        },
    }
end

---同时增加当前可消费脑腐值和累计脑腐值。
---@param state PlayerGameState
---@param amount number
function PlayerState.add_brainrot(state, amount)
    state.currency.brainrot = state.currency.brainrot + amount
    state.currency.total_brainrot = state.currency.total_brainrot + amount
end

---玩家脑腐值足够时扣除指定数量。
---@param state PlayerGameState
---@param amount number
---@return boolean success
function PlayerState.spend_brainrot(state, amount)
    if state.currency.brainrot < amount then
        return false
    end

    state.currency.brainrot = state.currency.brainrot - amount
    return true
end

return PlayerState
