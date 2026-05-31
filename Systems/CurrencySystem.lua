-- ============================================================
-- Systems/CurrencySystem.lua
-- Pure click and passive-income calculations.
-- ============================================================

local CurrencySystem = {}
local GameConfig = require("Data.GameConfig")
local GameState = require("Systems.GameState")

---Add the income earned by one character click.
---@param state PlayerGameState
---@return number income
function CurrencySystem.add_click_income(state)
    local income = state.currency.click_power * state.combo.multiplier
    if income < 1 then
        income = 1
    end

    GameState.add_brainrot(state, income)
    return income
end

---Add one passive-income tick.
---@param state PlayerGameState
---@return number income
function CurrencySystem.add_passive_income(state)
    local income = state.currency.brainrot_per_second
    if income <= 0 then
        return 0
    end

    if state.easter_egg.brainrot_per_second_bonus_active then
        income = income * GameConfig.BRAINROT_PER_SECOND_EASTER_BONUS_MULTIPLIER
    end

    GameState.add_brainrot(state, income)
    return income
end

return CurrencySystem
