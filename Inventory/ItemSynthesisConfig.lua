--[[
Inventory/ItemSynthesisConfig.lua

物品合成配置。
当前规则用于展台脑红物品：两个相同类型、相同等级的脑红合成同类型更高等级脑红，
并按配置公式提升每秒收益。
]]

local BoothConfig = require("Booth.BoothConfig")

local ItemSynthesisConfig = {
    SOURCE_SLOT_TYPE_NAMES = { "EQUIPPED", "BACKPACK" },
    OUTPUT_SLOT_TYPE_NAME = "EQUIPPED",

    RECIPES = {
        {
            id = "brainrot_same_type_level",
            item_ids = { 101, 102, 103, 104, 105 },
            ingredient_count = 2,
            same_item_id = true,
            same_level = true,
            max_level = 10,
            result = {
                item_id = "same",
                level_add = 1,
                income_multiplier = 2,
                income_add = 0,
            },
        },
    },
}

---@param item_id integer
---@return boolean
local function contains_item_id(item_ids, item_id)
    for _, candidate in ipairs(item_ids or {}) do
        if candidate == item_id then
            return true
        end
    end
    return false
end

---@param item_id integer
---@param level integer
---@return table|nil recipe
function ItemSynthesisConfig.find_recipe(item_id, level)
    for _, recipe in ipairs(ItemSynthesisConfig.RECIPES) do
        if contains_item_id(recipe.item_ids, item_id) then
            local max_level = recipe.max_level or 0
            if max_level <= 0 or level < max_level then
                return recipe
            end
        end
    end
    return nil
end

---@param recipe table
---@param item_id integer
---@return BoothItemConfig|nil item
function ItemSynthesisConfig.resolve_result_item(recipe, item_id)
    local result = recipe and recipe.result
    local result_item_id = result and result.item_id
    if result_item_id == "same" or result_item_id == nil then
        result_item_id = item_id
    end
    return BoothConfig.find_item(result_item_id)
end

return ItemSynthesisConfig
