--[[
Inventory/ItemSynthesisConfig.lua

物品合成配置。
配置 DSL 使用 + 表示材料组合，表构造中的 = 表示产出：

    [Item({ 101, 102 }) + Item({ 101, 102 })] = SameItem({ ... })

Lua 不能重载独立赋值语句的 =，这里使用的是 table constructor 的键值语法。
]]

local BoothConfig = require("Booth.BoothConfig")

local IngredientExprMeta = {}
IngredientExprMeta.__index = IngredientExprMeta

---@param value any
---@return integer[] item_ids
local function normalize_item_ids(value)
    if type(value) == "table" then
        local item_ids = {}
        for _, item_id in ipairs(value) do
            item_ids[#item_ids + 1] = math.tointeger(item_id)
        end
        return item_ids
    end
    return { math.tointeger(value) }
end

---@param item_ids integer[]
---@return integer[] copied
local function copy_item_ids(item_ids)
    local copied = {}
    for _, item_id in ipairs(item_ids or {}) do
        copied[#copied + 1] = item_id
    end
    return copied
end

---@param term table
---@return table copied
local function copy_ingredient_term(term)
    return {
        item_ids = copy_item_ids(term.item_ids),
        count = math.tointeger(term.count or 1),
    }
end

---@param expr table
---@param terms table[]
local function append_terms(expr, terms)
    if type(expr) ~= "table" or expr.kind ~= "ingredient_expr" then
        error("[ItemSynthesisConfig] + 两侧必须是 Item(...) 材料表达式")
    end
    for _, term in ipairs(expr.terms or {}) do
        terms[#terms + 1] = copy_ingredient_term(term)
    end
end

---@param left table
---@param right table
---@return table expr
function IngredientExprMeta.__add(left, right)
    local terms = {}
    append_terms(left, terms)
    append_terms(right, terms)
    return setmetatable({
        kind = "ingredient_expr",
        terms = terms,
    }, IngredientExprMeta)
end

---@param item_ids integer|integer[]
---@return table expr
local function Item(item_ids)
    return setmetatable({
        kind = "ingredient_expr",
        terms = {
            {
                item_ids = normalize_item_ids(item_ids),
                count = 1,
            },
        },
    }, IngredientExprMeta)
end

---@param options table|nil
---@return table result
local function SameItem(options)
    local result = options or {}
    result.kind = "synthesis_result"
    result.item_id = "same"
    return result
end

---@param item_id integer
---@param options table|nil
---@return table result
local function OutputItem(item_id, options)
    local result = options or {}
    result.kind = "synthesis_result"
    result.item_id = math.tointeger(item_id)
    return result
end

---@param left integer[]
---@param right integer[]
---@return boolean same
local function same_item_id_set(left, right)
    if #left ~= #right then
        return false
    end
    for index, item_id in ipairs(left) do
        if right[index] ~= item_id then
            return false
        end
    end
    return true
end

---@param recipe table
---@param item_ids integer[]
local function append_unique_item_ids(recipe, item_ids)
    for _, item_id in ipairs(item_ids or {}) do
        if not recipe.item_id_lookup[item_id] then
            recipe.item_id_lookup[item_id] = true
            recipe.item_ids[#recipe.item_ids + 1] = item_id
        end
    end
end

---@param ingredients table
---@param result table
---@param index integer
---@return table recipe
local function build_recipe(ingredients, result, index)
    if type(ingredients) ~= "table" or ingredients.kind ~= "ingredient_expr" then
        error("[ItemSynthesisConfig] 合成规则左侧必须是 Item(...) + Item(...)")
    end
    if type(result) ~= "table" or result.kind ~= "synthesis_result" then
        error("[ItemSynthesisConfig] 合成规则右侧必须是 SameItem(...) 或 OutputItem(...)")
    end

    local recipe = {
        id = result.id or ("synthesis_" .. tostring(index)),
        item_ids = {},
        item_id_lookup = {},
        ingredient_count = 0,
        same_level = result.same_level ~= false,
        same_item_id = true,
        max_level = math.tointeger(result.max_level or 0),
        priority = math.tointeger(result.priority or 0),
        result = {
            item_id = result.item_id,
            level_add = math.tointeger(result.level_add or 1),
            income_multiplier = result.income_multiplier or 1,
            income_add = math.tointeger(result.income_add or 0),
        },
    }

    local first_item_ids = nil
    recipe.ingredients = {}
    for _, term in ipairs(ingredients.terms or {}) do
        local copied = copy_ingredient_term(term)
        recipe.ingredients[#recipe.ingredients + 1] = copied
        recipe.ingredient_count = recipe.ingredient_count + math.tointeger(copied.count or 1)
        append_unique_item_ids(recipe, copied.item_ids)

        if not first_item_ids then
            first_item_ids = copied.item_ids
        elseif not same_item_id_set(first_item_ids, copied.item_ids) then
            recipe.same_item_id = false
        end
    end

    recipe.item_id_lookup = nil
    return recipe
end

---@param rules table
---@return table[] recipes
local function Recipes(rules)
    local recipes = {}
    for ingredients, result in pairs(rules or {}) do
        recipes[#recipes + 1] = build_recipe(ingredients, result, #recipes + 1)
    end
    table.sort(recipes, function(left, right)
        local left_priority = math.tointeger(left.priority or 0)
        local right_priority = math.tointeger(right.priority or 0)
        if left_priority ~= right_priority then
            return left_priority > right_priority
        end
        return tostring(left.id) < tostring(right.id)
    end)
    return recipes
end

local ItemSynthesisConfig = {
    SOURCE_SLOT_TYPE_NAMES = { "EQUIPPED", "BACKPACK" },
    OUTPUT_SLOT_TYPE_NAME = "EQUIPPED",

    Item = Item,
    SameItem = SameItem,
    OutputItem = OutputItem,
    Recipes = Recipes,

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

---@param item_ids integer[]
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
