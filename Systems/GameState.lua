-- ============================================================
-- Systems/GameState.lua
-- Per-player business state and atomic currency operations.
-- ============================================================

local GameConfig = require("Data.GameConfig")

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

local GameState = {}

---Create a new independent state tree for one player.
---@return PlayerGameState state
function GameState.new()
    return {
        currency = {
            brainrot = GameConfig.INITIAL_BRAINROT,
            total_brainrot = GameConfig.INITIAL_BRAINROT,
            click_power = GameConfig.INITIAL_CLICK_POWER,
            brainrot_per_second = GameConfig.INITIAL_BRAINROT_PER_SECOND,
        },
        shop = {
            items = {},
        },
        combo = {
            count = GameConfig.INITIAL_COMBO_COUNT,
            multiplier = GameConfig.INITIAL_COMBO_MULTIPLIER,
            tick_counter = GameConfig.INITIAL_TICK_COUNTER,
            last_click_tick = GameConfig.INITIAL_TICK_COUNTER,
        },
        easter_egg = {
            active = false,
            brainrot_per_second_bonus_active = false,
        },
    }
end

---Add spendable and lifetime brainrot together.
---@param state PlayerGameState
---@param amount number
function GameState.add_brainrot(state, amount)
    state.currency.brainrot = state.currency.brainrot + amount
    state.currency.total_brainrot = state.currency.total_brainrot + amount
end

---Spend brainrot if the player can afford the amount.
---@param state PlayerGameState
---@param amount number
---@return boolean success
function GameState.spend_brainrot(state, amount)
    if state.currency.brainrot < amount then
        return false
    end

    state.currency.brainrot = state.currency.brainrot - amount
    return true
end

return GameState
