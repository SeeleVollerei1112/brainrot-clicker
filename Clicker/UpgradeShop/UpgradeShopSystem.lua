--[[
Clicker/UpgradeShop/UpgradeShopSystem.lua

升级商店业务层：初始化商品状态、生成展示数据、处理购买和数值成长。
]]

local ClickerState = require("Clicker.ClickerState")
local UpgradeShopConfig = require("Clicker.UpgradeShop.UpgradeShopConfig")

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

local UpgradeShopSystem = {}

---@param current_price number
---@param growth_percent number
---@return number next_price
local function get_next_price(current_price, growth_percent)
    return math.tointeger(math.tofixed(current_price) * math.tofixed(growth_percent) / math.tofixed(100)) + 1
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

---初始化新玩家状态里的商品价格和等级。
---@param state PlayerGameState
function UpgradeShopSystem.initialize(state)
    for _, item_configuration in ipairs(UpgradeShopConfig.ITEMS) do
        local item_state = get_item_state(state, item_configuration.id)
        item_state.count = item_configuration.initial_level or 0
        item_state.level = item_configuration.initial_level or 0
        item_state.current_price = item_configuration.base_price
    end
end

---判断累计脑腐值是否已解锁商品。
---@param state PlayerGameState
---@param item_id integer
---@return boolean unlocked
function UpgradeShopSystem.is_unlocked(state, item_id)
    local item_configuration = UpgradeShopConfig.ITEMS[item_id]
    if not item_configuration then
        return false
    end

    return state.currency.total_brainrot >= item_configuration.unlock_total_brainrot
end

---判断玩家当前是否可以买这个商品。
---@param state PlayerGameState
---@param item_id integer
---@return boolean can_buy
function UpgradeShopSystem.can_buy(state, item_id)
    local item_configuration = UpgradeShopConfig.ITEMS[item_id]
    if not item_configuration or not UpgradeShopSystem.is_unlocked(state, item_id) then
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
    local item_configuration = UpgradeShopConfig.ITEMS[item_id]
    if not item_configuration then
        return nil
    end

    local item_state = get_item_state(state, item_id)
    local unlocked = UpgradeShopSystem.is_unlocked(state, item_id)
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
        can_buy = UpgradeShopSystem.can_buy(state, item_id),
        max_level = item_configuration.max_level,
        unlock_total_brainrot = item_configuration.unlock_total_brainrot,
    }
end

---生成商店表现层需要的展示数据。
---@param state PlayerGameState
---@return ShopDisplayData display_data
function UpgradeShopSystem.get_display_data(state)
    local item_display_data = {}
    for _, item_configuration in ipairs(UpgradeShopConfig.ITEMS) do
        item_display_data[item_configuration.id] = get_item_display_data(state, item_configuration.id)
    end

    return {
        click_power = state.currency.click_power,
        items = item_display_data,
    }
end

---购买商品并应用对应数值成长。
---@param state PlayerGameState
---@param item_id integer
---@return ShopPurchaseResult result
function UpgradeShopSystem.purchase(state, item_id)
    local item_configuration = UpgradeShopConfig.ITEMS[item_id]
    if not item_configuration then
        return { success = false, reason = "invalid_item" }
    end
    if not UpgradeShopSystem.is_unlocked(state, item_id) then
        return { success = false, reason = "locked" }
    end

    local item_state = get_item_state(state, item_id)
    if item_configuration.max_level and item_state.level >= item_configuration.max_level then
        return { success = false, reason = "max_level" }
    end
    if not ClickerState.spend_brainrot(state, item_state.current_price) then
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
        UpgradeShopConfig.get_price_growth(item_configuration)
    )

    return { success = true, reason = "ok" }
end

return UpgradeShopSystem
