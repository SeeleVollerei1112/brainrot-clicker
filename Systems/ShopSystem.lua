-- ============================================================
-- Systems/ShopSystem.lua
-- Pure shop initialization, display-data projection and purchases.
-- ============================================================

local GameState = require("Systems.GameState")
local ShopConfig = require("Data.ShopConfig")

---@class ShopItemDisplayData
---@field id integer
---@field name string
---@field description string
---@field price number
---@field level integer
---@field count integer
---@field icon_preset integer|nil
---@field unlocked boolean
---@field can_buy boolean
---@field max_level integer|nil
---@field unlock_total_brainrot number

---@class ShopDisplayData
---@field click_power number
---@field items table<integer, ShopItemDisplayData>

---@class ShopPurchaseResult
---@field success boolean
---@field reason string

local ShopSystem = {}

---@param current_price number
---@param growth_percent number
---@return number next_price
local function get_next_price(current_price, growth_percent)
    local to_fixed = math.tofixed
    return math.tointeger(to_fixed(current_price) * to_fixed(growth_percent) / to_fixed(100)) + 1
end

---@param state PlayerGameState
---@param item_id integer
---@return ShopItemState item_state
local function get_item_state(state, item_id)
    state.shop.items[item_id] = state.shop.items[item_id] or {
        count = 0,
        level = 0,
        current_price = 0,
    }
    return state.shop.items[item_id]
end

---Initialize item prices for a newly created player state.
---@param state PlayerGameState
function ShopSystem.initialize(state)
    for _, item_configuration in ipairs(ShopConfig.ITEMS) do
        local item_state = get_item_state(state, item_configuration.id)
        item_state.count = item_configuration.initial_level or 0
        item_state.level = item_configuration.initial_level or 0
        item_state.current_price = item_configuration.base_price
    end
end

---Return whether lifetime brainrot has unlocked an item.
---@param state PlayerGameState
---@param item_id integer
---@return boolean unlocked
function ShopSystem.is_unlocked(state, item_id)
    local item_configuration = ShopConfig.ITEMS[item_id]
    if not item_configuration then
        return false
    end

    return state.currency.total_brainrot >= item_configuration.unlock_total_brainrot
end

---Return whether the player can buy an item now.
---@param state PlayerGameState
---@param item_id integer
---@return boolean can_buy
function ShopSystem.can_buy(state, item_id)
    local item_configuration = ShopConfig.ITEMS[item_id]
    if not item_configuration or not ShopSystem.is_unlocked(state, item_id) then
        return false
    end

    local item_state = get_item_state(state, item_id)
    if item_configuration.max_level and item_state.level >= item_configuration.max_level then
        return false
    end

    return state.currency.brainrot >= item_state.current_price
end

---@param state PlayerGameState
---@param item_id integer
---@return ShopItemDisplayData|nil display_data
local function get_item_display_data(state, item_id)
    local item_configuration = ShopConfig.ITEMS[item_id]
    if not item_configuration then
        return nil
    end

    local item_state = get_item_state(state, item_id)
    local unlocked = ShopSystem.is_unlocked(state, item_id)
    local icon_preset = item_configuration.locked_icon_preset
    if unlocked then
        icon_preset = item_configuration.icon_preset
    end

    return {
        id = item_configuration.id,
        name = unlocked and item_configuration.name or item_configuration.locked_name,
        description = unlocked and item_configuration.description or item_configuration.locked_description,
        price = item_state.current_price,
        level = item_state.level,
        count = item_state.count,
        icon_preset = icon_preset,
        unlocked = unlocked,
        can_buy = ShopSystem.can_buy(state, item_id),
        max_level = item_configuration.max_level,
        unlock_total_brainrot = item_configuration.unlock_total_brainrot,
    }
end

---Project all shop data needed by the view.
---@param state PlayerGameState
---@return ShopDisplayData display_data
function ShopSystem.get_display_data(state)
    local item_display_data = {}
    for _, item_configuration in ipairs(ShopConfig.ITEMS) do
        item_display_data[item_configuration.id] = get_item_display_data(state, item_configuration.id)
    end

    return {
        click_power = state.currency.click_power,
        items = item_display_data,
    }
end

---Buy an item and apply its stat increase.
---@param state PlayerGameState
---@param item_id integer
---@return ShopPurchaseResult result
function ShopSystem.purchase(state, item_id)
    local item_configuration = ShopConfig.ITEMS[item_id]
    if not item_configuration then
        return { success = false, reason = "invalid_item" }
    end
    if not ShopSystem.is_unlocked(state, item_id) then
        return { success = false, reason = "locked" }
    end

    local item_state = get_item_state(state, item_id)
    if item_configuration.max_level and item_state.level >= item_configuration.max_level then
        return { success = false, reason = "max_level" }
    end
    if not GameState.spend_brainrot(state, item_state.current_price) then
        return { success = false, reason = "not_enough_brainrot" }
    end

    item_state.count = item_state.count + 1
    item_state.level = item_state.level + 1

    if item_configuration.effect_type == "click" then
        state.currency.click_power = state.currency.click_power + item_configuration.effect_value
    elseif item_configuration.effect_type == "passive" then
        state.currency.brainrot_per_second =
            state.currency.brainrot_per_second + item_configuration.effect_value
    end

    item_state.current_price = get_next_price(
        item_state.current_price,
        ShopConfig.get_price_growth(item_configuration)
    )

    return { success = true, reason = "ok" }
end

return ShopSystem
