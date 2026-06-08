--[[
Inventory/ItemSynthesisSystem.lua

背包物品合成系统。
负责扫描玩家持有物品、按 ItemSynthesisConfig.RECIPES 匹配材料、消耗材料并生成结果物品。
合成结果的等级/收益属性会写入物品描述中的轻量标记，并缓存在本局内；展台放置时可读取
这些属性写入 BoothState，从而让公告板和头顶收益展示使用合成后的数值。
]]

local BoothConfig = require("Booth.BoothConfig")
local ItemSynthesisConfig = require("Inventory.ItemSynthesisConfig")

local ItemSynthesisSystem = {}

local ATTR_DESC_PREFIX = "BR_SYNTH|"
local BACKPACK = Enums.EquipmentSlotType.BACKPACK

---@type table<any, table<string, integer|string>>
local attrs_by_equipment_key = {}

---@param value any
---@return integer
local function to_int(value)
    return math.tointeger(value) or 0
end

---@param attrs table<string, integer|string>|nil
---@return table<string, integer|string>
local function copy_attrs(attrs)
    local result = {}
    if attrs then
        for key, value in pairs(attrs) do
            result[key] = value
        end
    end
    return result
end

---@param text string
---@param index integer
---@return integer value
---@return integer next_index
---@return boolean ok
local function read_int_field(text, index)
    local value = 0
    local saw_digit = false
    while index <= #text do
        local ch = text:byte(index)
        if ch < 48 or ch > 57 then
            break
        end
        value = value * 10 + (ch - 48)
        saw_digit = true
        index = index + 1
    end
    return value, index, saw_digit
end

---@param item_id integer
---@param attrs table<string, integer|string>
---@return string
local function encode_attrs_desc(item_id, attrs)
    return ATTR_DESC_PREFIX
        .. tostring(item_id) .. "|"
        .. tostring(to_int(attrs.level or 1)) .. "|"
        .. tostring(to_int(attrs.income_per_second or 0))
end

---@param desc string|nil
---@return integer|nil item_id
---@return table<string, integer|string>|nil attrs
local function decode_attrs_desc(desc)
    if type(desc) ~= "string" or desc:sub(1, #ATTR_DESC_PREFIX) ~= ATTR_DESC_PREFIX then
        return nil, nil
    end

    local index = #ATTR_DESC_PREFIX + 1
    local item_id
    local level
    local income
    local ok

    item_id, index, ok = read_int_field(desc, index)
    if not ok or desc:sub(index, index) ~= "|" then
        return nil, nil
    end
    index = index + 1

    level, index, ok = read_int_field(desc, index)
    if not ok or desc:sub(index, index) ~= "|" then
        return nil, nil
    end
    index = index + 1

    income, _, ok = read_int_field(desc, index)
    if not ok then
        return nil, nil
    end

    local item = BoothConfig.find_item(item_id)
    if not item then
        return nil, nil
    end

    local attrs = copy_attrs(item.base_attrs)
    attrs.level = level
    attrs.income_per_second = income
    return item_id, attrs
end

---@param equipment Equipment|nil
---@return any key
local function equipment_cache_key(equipment)
    if not equipment then
        return nil
    end
    local unit = equipment.get_unit()
    if unit then
        return LuaAPI.get_unit_id(unit)
    end
    return equipment
end

---@param slot_type_name string|nil
---@return any slot_type
local function get_slot_type(slot_type_name)
    if slot_type_name and Enums.EquipmentSlotType[slot_type_name] ~= nil then
        return Enums.EquipmentSlotType[slot_type_name]
    end
    return BACKPACK
end

---@param equipment Equipment
---@param item_id integer
---@param attrs table<string, integer|string>
local function apply_equipment_display(equipment, item_id, attrs)
    if not equipment then
        return
    end
    local item = BoothConfig.find_item(item_id)
    local name = (attrs and attrs.name) or (item and item.base_attrs and item.base_attrs.name) or "脑红"
    local level = to_int(attrs and attrs.level or 1)
    local income = to_int(attrs and attrs.income_per_second or 0)
    equipment.set_name(tostring(name) .. " Lv." .. tostring(level))
    equipment.set_desc(encode_attrs_desc(item_id, attrs))
    LuaAPI.log("[ItemSynthesisSystem] 标记物品 item=" .. tostring(item_id)
        .. " level=" .. tostring(level) .. " income=" .. tostring(income), 0)
end

---@param equipment Equipment|nil
---@param attrs table<string, integer|string>|nil
local function cache_attrs(equipment, attrs)
    local key = equipment_cache_key(equipment)
    if key then
        attrs_by_equipment_key[key] = attrs and copy_attrs(attrs) or nil
    end
end

function ItemSynthesisSystem.initialize()
    attrs_by_equipment_key = {}
end

---@param equipment Equipment
---@param item_id integer
---@param attrs table<string, integer|string>|nil
function ItemSynthesisSystem.attach_attrs(equipment, item_id, attrs)
    local item = BoothConfig.find_item(item_id)
    if not equipment or not item then
        return
    end
    local output_attrs = copy_attrs(item.base_attrs)
    if attrs then
        for key, value in pairs(attrs) do
            output_attrs[key] = value
        end
    end
    cache_attrs(equipment, output_attrs)
    apply_equipment_display(equipment, item_id, output_attrs)
end

---@param equipment Equipment|nil
---@return integer|nil item_id
---@return table<string, integer|string>|nil attrs
function ItemSynthesisSystem.get_equipment_item(equipment)
    if not equipment then
        return nil, nil
    end

    local item_id, desc_attrs = decode_attrs_desc(equipment.get_desc())
    if item_id and desc_attrs then
        cache_attrs(equipment, desc_attrs)
        return item_id, desc_attrs
    end

    local key = equipment_cache_key(equipment)
    local cached = key and attrs_by_equipment_key[key] or nil
    local item = BoothConfig.find_item_by_prefab(equipment.get_key())
    if cached and item then
        return item.id, copy_attrs(cached)
    end
    if item then
        return item.id, copy_attrs(item.base_attrs)
    end
    return nil, nil
end

---@param equipment Equipment|nil
---@return table<string, integer|string>|nil attrs
function ItemSynthesisSystem.get_equipment_attrs(equipment)
    return select(2, ItemSynthesisSystem.get_equipment_item(equipment))
end

---@param equipment Equipment|nil
function ItemSynthesisSystem.forget_equipment(equipment)
    local key = equipment_cache_key(equipment)
    if key then
        attrs_by_equipment_key[key] = nil
    end
end

---@param character Character
---@return table materials
local function collect_materials(character)
    local materials = {}
    local seen = {}
    if not character then
        return materials
    end

    for _, slot_type_name in ipairs(ItemSynthesisConfig.SOURCE_SLOT_TYPE_NAMES or {}) do
        local list = character.get_equipment_list_by_slot_type(get_slot_type(slot_type_name))
        if type(list) == "table" then
            for _, equipment in ipairs(list) do
                local cache_key = equipment_cache_key(equipment) or equipment
                local item_id, attrs = nil, nil
                if cache_key and not seen[cache_key] then
                    seen[cache_key] = true
                    item_id, attrs = ItemSynthesisSystem.get_equipment_item(equipment)
                end
                if item_id and attrs then
                    materials[#materials + 1] = {
                        equipment = equipment,
                        item_id = item_id,
                        attrs = attrs,
                        level = to_int(attrs.level or 1),
                        income_per_second = to_int(attrs.income_per_second or 0),
                    }
                end
            end
        end
    end
    return materials
end

---@param materials table
---@param requested_item_id integer|nil
---@param requested_level integer|nil
---@return table|nil recipe
---@return table|nil picked
local function find_match(materials, requested_item_id, requested_level)
    for _, first in ipairs(materials) do
        if (not requested_item_id or first.item_id == requested_item_id)
            and (not requested_level or requested_level <= 0 or first.level == requested_level) then
            local recipe = ItemSynthesisConfig.find_recipe(first.item_id, first.level)
            if recipe then
                local picked = { first }
                for _, other in ipairs(materials) do
                    if other ~= first and other.item_id == first.item_id and other.level == first.level then
                        picked[#picked + 1] = other
                        if #picked >= (recipe.ingredient_count or 2) then
                            return recipe, picked
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

---@param recipe table
---@param materials table
---@return integer|nil result_item_id
---@return table<string, integer|string>|nil result_attrs
local function build_result(recipe, materials)
    local first = materials and materials[1]
    if not first then
        return nil, nil
    end

    local result_item = ItemSynthesisConfig.resolve_result_item(recipe, first.item_id)
    if not result_item or not result_item.prefab_id then
        return nil, nil
    end

    local result = recipe.result or {}
    local result_attrs = copy_attrs(result_item.base_attrs)
    result_attrs.level = first.level + (result.level_add or 1)
    result_attrs.income_per_second = to_int(
        math.floor(first.income_per_second * (result.income_multiplier or 1) + (result.income_add or 0))
    )
    return result_item.id, result_attrs
end

---@param role Role
---@param item_id integer|nil 指定物品类型；nil/0 自动匹配第一组可合成材料
---@param level integer|nil 指定等级；nil/0 自动匹配
---@return table result
function ItemSynthesisSystem.synthesize(role, item_id, level)
    local character = role and role.get_ctrl_unit()
    if not character then
        return { success = false, reason = "no_role" }
    end

    local requested_item_id = item_id and item_id > 0 and item_id or nil
    local requested_level = level and level > 0 and level or nil
    local materials = collect_materials(character)
    local recipe, picked = find_match(materials, requested_item_id, requested_level)
    if not recipe or not picked then
        return { success = false, reason = "materials_missing" }
    end

    local result_item_id, result_attrs = build_result(recipe, picked)
    local result_item = result_item_id and BoothConfig.find_item(result_item_id) or nil
    if not result_item or not result_item.prefab_id or not result_attrs then
        return { success = false, reason = "result_missing" }
    end

    for _, material in ipairs(picked) do
        ItemSynthesisSystem.forget_equipment(material.equipment)
        material.equipment.destroy_equipment()
    end

    local output = character.create_equipment_to_slot(result_item.prefab_id,
        get_slot_type(ItemSynthesisConfig.OUTPUT_SLOT_TYPE_NAME))
    ItemSynthesisSystem.attach_attrs(output, result_item_id, result_attrs)

    return {
        success = true,
        reason = "ok",
        recipe_id = recipe.id,
        item_id = result_item_id,
        level = to_int(result_attrs.level or 1),
        income_per_second = to_int(result_attrs.income_per_second or 0),
        equipment = output,
    }
end

---@param role Role
---@param item_id integer
---@param attrs table<string, integer|string>|nil
---@param slot_type_name string|nil
---@return Equipment|nil equipment
function ItemSynthesisSystem.give_item(role, item_id, attrs, slot_type_name)
    local character = role and role.get_ctrl_unit()
    local item = BoothConfig.find_item(item_id)
    if not character or not item or not item.prefab_id then
        return nil
    end

    local equipment = character.create_equipment_to_slot(item.prefab_id,
        get_slot_type(slot_type_name or ItemSynthesisConfig.OUTPUT_SLOT_TYPE_NAME))
    ItemSynthesisSystem.attach_attrs(equipment, item_id, attrs or item.base_attrs)
    return equipment
end

---@param role Role
---@param item_id integer|nil
---@param level integer|nil
---@return boolean can
---@return string reason
function ItemSynthesisSystem.can_synthesize(role, item_id, level)
    local character = role and role.get_ctrl_unit()
    if not character then
        return false, "no_role"
    end
    local materials = collect_materials(character)
    local recipe = find_match(materials, item_id and item_id > 0 and item_id or nil,
        level and level > 0 and level or nil)
    if recipe then
        return true, "ok"
    end
    return false, "materials_missing"
end

return ItemSynthesisSystem
