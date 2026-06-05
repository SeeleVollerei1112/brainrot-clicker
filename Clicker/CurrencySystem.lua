--[[
Clicker/CurrencySystem.lua

点击收益与被动收益计算。
]]

local CurrencySystem = {}
local ClickerConfig = require("Clicker.ClickerConfig")
local PlayerState = require("Clicker.PlayerState")

---结算一次角色点击获得的收益。
---@param state PlayerGameState
---@return number income
function CurrencySystem.add_click_income(state)
    local income = state.currency.click_power * state.combo.multiplier
    if income < 1 then
        income = 1
    end

    PlayerState.add_brainrot(state, income)
    return income
end

---结算一次被动收益。
---@param state PlayerGameState
---@return number income
function CurrencySystem.add_passive_income(state)
    local income = state.currency.brainrot_per_second
    if income <= 0 then
        return 0
    end

    if state.easter_egg.brainrot_per_second_bonus_active then
        income = income * ClickerConfig.PASSIVE_INCOME.easter_bonus_multiplier
    end

    PlayerState.add_brainrot(state, income)
    return income
end

return CurrencySystem
