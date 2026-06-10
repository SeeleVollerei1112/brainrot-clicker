--[[
Inventory/ItemSynthesisConfig.lua

物品合成配置：RECIPES 为字面量配方表，每条配方描述参与物件(item_ids)、
材料数量(ingredient_count)、等级约束(same_level/max_level)与产出规则(result)。
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

---@param item_ids integer[]|nil
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

ItemSynthesisConfig.contains_item_id = contains_item_id

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
