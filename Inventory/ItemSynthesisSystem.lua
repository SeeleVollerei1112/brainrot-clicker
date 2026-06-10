--[[
Inventory/ItemSynthesisSystem.lua

背包物品合成系统。
物品实例属性只写入/读取 Equipment 自定义 KV，不再写入物品描述。
]]

-- 与展台共用同一存档槽位（read-merge-write 各管各的字段），槽位以 ArchivesData 为唯一真相
local BOOTH_ARCHIVE = require("Data.ArchivesData")["展台状态"]
local BoothConfig = require("Booth.BoothConfig")
local ItemSynthesisConfig = require("Inventory.ItemSynthesisConfig")
local Json = require("Util.Json")

local ItemSynthesisSystem = {}

local KV_ITEM_ID = "booth_item_id"
local KV_LEVEL = "booth_level"
local KV_INCOME_PER_SECOND = "booth_income_per_second"
local KV_NAME = "booth_name"
local KV_INT = Enums.ValueType.Int
local KV_STR = Enums.ValueType.Str
local BACKPACK = Enums.EquipmentSlotType.BACKPACK

---@param attrs table<string, integer|string>|nil
---@return table<string, integer|string>
local function copy_attrs(attrs)
    local result = {}
    for key, value in pairs(attrs or {}) do
        result[key] = value
    end
    return result
end

---@param item table
---@param attrs table<string, integer|string>|nil
---@return table<string, integer|string>
local function merge_item_attrs(item, attrs)
    local result = copy_attrs(item.base_attrs)
    for key, value in pairs(attrs or {}) do
        result[key] = value
    end
    return result
end

local get_role_id = require("Util.RoleUtil").get_role_id

---@param equipment Equipment|nil
---@return Role|nil
local function get_equipment_role(equipment)
    local character = equipment and equipment.get_owner_character()
    local role_id = character and character.get_role_id() or nil
    return role_id and GameAPI.get_role(role_id) or nil
end

---@param slot_type_name string|nil
---@return any
local function get_slot_type(slot_type_name)
    if slot_type_name and Enums.EquipmentSlotType[slot_type_name] ~= nil then
        return Enums.EquipmentSlotType[slot_type_name]
    end
    return BACKPACK
end

---@param equipment Equipment|nil
---@return integer
local function stack_count(equipment)
    if not equipment then
        return 1
    end
    local count = math.tointeger(equipment.get_current_stack_num()) or 0
    if count <= 0 then
        return 1
    end
    return count
end

---@param equipment Equipment|nil
---@param count integer
local function set_stack_count(equipment, count)
    if not equipment then
        return
    end
    local target = math.tointeger(count) or 0
    if target <= 0 then
        target = 1
    end

    local max_stack = math.tointeger(equipment.get_max_stack_num()) or 0
    if max_stack > 0 and max_stack < target then
        equipment.change_max_stack_size(target - max_stack)
    end

    local current = stack_count(equipment)
    if current ~= target then
        equipment.change_current_stack_size(target - current)
    end
end

---@param equipment Equipment|nil
---@param key string
---@return integer
local function get_int_kv(equipment, key)
    if not equipment then
        return 0
    end
    return math.tointeger(equipment.get_kv_by_type(KV_INT, key)) or 0
end

---@param equipment Equipment|nil
---@param key string
---@return string|nil
local function get_str_kv(equipment, key)
    if not equipment then
        return nil
    end
    local value = equipment.get_kv_by_type(KV_STR, key)
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

---@param equipment Equipment
---@param item_id integer
---@param attrs table<string, integer|string>
local function write_attrs_kv(equipment, item_id, attrs)
    equipment.set_kv_by_type(KV_INT, KV_ITEM_ID, math.tointeger(item_id))
    equipment.set_kv_by_type(KV_INT, KV_LEVEL, math.tointeger(attrs.level or 1))
    equipment.set_kv_by_type(KV_INT, KV_INCOME_PER_SECOND, math.tointeger(attrs.income_per_second or 0))
    if attrs.name then
        equipment.set_kv_by_type(KV_STR, KV_NAME, tostring(attrs.name))
    end
end

---@param equipment Equipment
---@param item_id integer
---@param attrs table<string, integer|string>
local function apply_equipment_display(equipment, item_id, attrs)
    local item = BoothConfig.find_item(item_id)
    local name = attrs.name or (item and item.base_attrs and item.base_attrs.name) or "脑红"
    equipment.set_name(tostring(name) .. " Lv." .. tostring(math.tointeger(attrs.level or 1)))
    write_attrs_kv(equipment, item_id, attrs)
    LuaAPI.log("[ItemSynthesisSystem] 标记物品 item=" .. tostring(item_id)
        .. " level=" .. tostring(math.tointeger(attrs.level or 1))
        .. " income=" .. tostring(math.tointeger(attrs.income_per_second or 0)), 0)
end

function ItemSynthesisSystem.initialize()
end

---@param equipment Equipment|nil
---@param item_id integer
---@param attrs table<string, integer|string>|nil
function ItemSynthesisSystem.attach_attrs(equipment, item_id, attrs)
    local item = BoothConfig.find_item(item_id)
    if not equipment or not item then
        return
    end
    apply_equipment_display(equipment, item_id, merge_item_attrs(item, attrs))
end

---@param equipment Equipment|nil
---@return integer|nil item_id
---@return table<string, integer|string>|nil attrs
function ItemSynthesisSystem.get_equipment_item(equipment)
    if not equipment then
        return nil, nil
    end

    local item_id = get_int_kv(equipment, KV_ITEM_ID)
    local item = item_id > 0 and BoothConfig.find_item(item_id) or nil
    if not item then
        item = BoothConfig.find_item_by_prefab(equipment.get_key())
        item_id = item and item.id or 0
    end
    if not item then
        return nil, nil
    end

    local attrs = copy_attrs(item.base_attrs)
    local level = get_int_kv(equipment, KV_LEVEL)
    local income = get_int_kv(equipment, KV_INCOME_PER_SECOND)
    local name = get_str_kv(equipment, KV_NAME)
    if level > 0 then
        attrs.level = level
    end
    if income > 0 then
        attrs.income_per_second = income
    end
    if name then
        attrs.name = name
    end
    return item_id, attrs
end

---@param equipment Equipment|nil
---@return table<string, integer|string>|nil
function ItemSynthesisSystem.get_equipment_attrs(equipment)
    return select(2, ItemSynthesisSystem.get_equipment_item(equipment))
end

---@param left table<string, integer|string>|nil
---@param right table<string, integer|string>|nil
---@return boolean
local function same_stack_attrs(left, right)
    return left ~= nil
        and right ~= nil
        and math.tointeger(left.level or 1) == math.tointeger(right.level or 1)
        and math.tointeger(left.income_per_second or 0) == math.tointeger(right.income_per_second or 0)
end

---@param role Role
---@return table
local function load_archive_root(role)
    if not role or not role.has_saved_archive() then
        return {}
    end
    local blob = role.get_archive_by_type(BOOTH_ARCHIVE.vType, BOOTH_ARCHIVE.id)
    if type(blob) ~= "string" or blob == "" then
        return {}
    end
    local data = Json.decode(blob)
    if type(data) == "table" then
        return data
    end
    return {}
end

---@return boolean
local function archives_ready()
    if not GameAPI.is_archives_enabled() then
        LuaAPI.log("[ItemSynthesisSystem] 存档功能未开启，跳过物品栏存/读档", 1)
        return false
    end
    return true
end

---@param stacks table[]
---@param slot_type_name string
---@param item_id integer
---@param attrs table<string, integer|string>
---@param count integer
local function append_saved_stack(stacks, slot_type_name, item_id, attrs, count)
    local safe_count = math.tointeger(count) or 0
    if safe_count <= 0 then
        safe_count = 1
    end
    for _, stack in ipairs(stacks) do
        if stack.slot == slot_type_name
            and stack.item_id == item_id
            and same_stack_attrs(stack.attrs, attrs) then
            stack.count = (math.tointeger(stack.count) or 0) + safe_count
            return
        end
    end
    stacks[#stacks + 1] = {
        slot = slot_type_name,
        item_id = item_id,
        attrs = copy_attrs(attrs),
        count = safe_count,
    }
end

---@param role Role
---@return table[]
local function collect_saved_stacks(role)
    local stacks = {}
    local character = role and role.get_ctrl_unit()
    if not character then
        return stacks
    end

    for _, slot_type_name in ipairs(ItemSynthesisConfig.SOURCE_SLOT_TYPE_NAMES or {}) do
        local list = character.get_equipment_list_by_slot_type(get_slot_type(slot_type_name))
        if type(list) == "table" then
            for _, equipment in ipairs(list) do
                local item_id, attrs = ItemSynthesisSystem.get_equipment_item(equipment)
                if item_id and attrs then
                    append_saved_stack(stacks, slot_type_name, item_id, attrs, stack_count(equipment))
                end
            end
        end
    end
    return stacks
end

---@param role Role
function ItemSynthesisSystem.save_role_inventory(role)
    if not role or not archives_ready() then
        return
    end
    local data = load_archive_root(role)
    data.inventory = {
        version = 1,
        stacks = collect_saved_stacks(role),
    }
    local blob = Json.encode(data)
    role.set_archive_by_type(BOOTH_ARCHIVE.vType, BOOTH_ARCHIVE.id, blob)
    LuaAPI.log("[ItemSynthesisSystem] 已保存合成物品栏: " .. blob, 0)
end

---@param role Role
---@return table[]|nil
local function load_saved_stacks(role)
    if not role or not archives_ready() or not role.has_saved_archive() then
        return nil
    end
    local inventory = load_archive_root(role).inventory
    if type(inventory) == "table" and type(inventory.stacks) == "table" then
        return inventory.stacks
    end
    return nil
end

---@param role Role
local function destroy_current_booth_items(role)
    local character = role and role.get_ctrl_unit()
    if not character then
        return
    end

    local targets = {}
    for _, slot_type_name in ipairs(ItemSynthesisConfig.SOURCE_SLOT_TYPE_NAMES or {}) do
        local list = character.get_equipment_list_by_slot_type(get_slot_type(slot_type_name))
        if type(list) == "table" then
            for _, equipment in ipairs(list) do
                if BoothConfig.find_item_by_prefab(equipment.get_key()) then
                    targets[#targets + 1] = equipment
                end
            end
        end
    end

    for _, equipment in ipairs(targets) do
        equipment.destroy_equipment()
    end
end

---@param role Role
---@param stack table
local function restore_saved_stack(role, stack)
    local character = role and role.get_ctrl_unit()
    local item_id = math.tointeger(stack and stack.item_id) or 0
    local item = BoothConfig.find_item(item_id)
    if not character or not item or not item.prefab_id then
        return
    end

    local slot_type_name = type(stack.slot) == "string" and stack.slot or ItemSynthesisConfig.OUTPUT_SLOT_TYPE_NAME
    local equipment = character.create_equipment_to_slot(item.prefab_id, get_slot_type(slot_type_name))
    ItemSynthesisSystem.attach_attrs(equipment, item_id, stack.attrs)
    set_stack_count(equipment, stack.count or 1)
end

---@param role Role
local function normalize_current_booth_items(role)
    local character = role and role.get_ctrl_unit()
    if not character then
        return
    end

    for _, slot_type_name in ipairs(ItemSynthesisConfig.SOURCE_SLOT_TYPE_NAMES or {}) do
        local list = character.get_equipment_list_by_slot_type(get_slot_type(slot_type_name))
        if type(list) == "table" then
            for _, equipment in ipairs(list) do
                local item_id, attrs = ItemSynthesisSystem.get_equipment_item(equipment)
                if item_id and attrs then
                    ItemSynthesisSystem.attach_attrs(equipment, item_id, attrs)
                end
            end
        end
    end
end

---@param role Role
function ItemSynthesisSystem.restore_role_inventory(role)
    if not get_role_id(role) then
        return
    end

    local stacks = load_saved_stacks(role)
    if not stacks then
        normalize_current_booth_items(role)
        ItemSynthesisSystem.save_role_inventory(role)
        return
    end

    destroy_current_booth_items(role)
    for _, stack in ipairs(stacks) do
        restore_saved_stack(role, stack)
    end
    ItemSynthesisSystem.save_role_inventory(role)
end

---@param character Character
---@param item_id integer
---@param attrs table<string, integer|string>
---@param slot_type_name string
---@return Equipment|nil
local function find_matching_stack_in_slot(character, item_id, attrs, slot_type_name)
    local list = character.get_equipment_list_by_slot_type(get_slot_type(slot_type_name))
    if type(list) ~= "table" then
        return nil
    end
    for _, equipment in ipairs(list) do
        local existing_item_id, existing_attrs = ItemSynthesisSystem.get_equipment_item(equipment)
        if existing_item_id == item_id and same_stack_attrs(existing_attrs, attrs) then
            return equipment
        end
    end
    return nil
end

---@param equipment Equipment
---@param item_id integer
---@param attrs table<string, integer|string>
---@param count integer|nil
---@return Equipment
local function add_to_stack(equipment, item_id, attrs, count)
    ItemSynthesisSystem.attach_attrs(equipment, item_id, attrs)
    set_stack_count(equipment, stack_count(equipment) + math.tointeger(count or 1))
    ItemSynthesisSystem.save_role_inventory(get_equipment_role(equipment))
    return equipment
end

---@param equipment Equipment|nil
---@param count integer|nil
---@return boolean
function ItemSynthesisSystem.consume_equipment(equipment, count)
    if not equipment then
        return false
    end

    local role = get_equipment_role(equipment)
    local consume_count = math.tointeger(count or 1)
    if consume_count <= 0 then
        consume_count = 1
    end

    if stack_count(equipment) > consume_count then
        equipment.change_current_stack_size(-consume_count)
    else
        equipment.destroy_equipment()
    end
    ItemSynthesisSystem.save_role_inventory(role)
    return true
end

---@param character Character
---@return table[]
local function collect_materials(character)
    local materials = {}
    if not character then
        return materials
    end

    for _, slot_type_name in ipairs(ItemSynthesisConfig.SOURCE_SLOT_TYPE_NAMES or {}) do
        local list = character.get_equipment_list_by_slot_type(get_slot_type(slot_type_name))
        if type(list) == "table" then
            for _, equipment in ipairs(list) do
                local item_id, attrs = ItemSynthesisSystem.get_equipment_item(equipment)
                if item_id and attrs then
                    materials[#materials + 1] = {
                        equipment = equipment,
                        item_id = item_id,
                        attrs = attrs,
                        level = math.tointeger(attrs.level or 1),
                        income_per_second = math.tointeger(attrs.income_per_second or 0),
                        count = stack_count(equipment),
                    }
                end
            end
        end
    end
    return materials
end

---@param materials table[]
---@param requested_item_id integer|nil
---@param requested_level integer|nil
---@return table|nil recipe
---@return table[]|nil picked
local function find_match(materials, requested_item_id, requested_level)
    for _, first in ipairs(materials) do
        if (not requested_item_id or first.item_id == requested_item_id)
            and (not requested_level or requested_level <= 0 or first.level == requested_level) then
            local recipe = ItemSynthesisConfig.find_recipe(first.item_id, first.level)
            local remaining = recipe and recipe.ingredient_count or 0
            local picked = {}
            for _, other in ipairs(materials) do
                if recipe and other.item_id == first.item_id and other.level == first.level then
                    local take = other.count
                    if take > remaining then
                        take = remaining
                    end
                    picked[#picked + 1] = {
                        equipment = other.equipment,
                        item_id = other.item_id,
                        attrs = other.attrs,
                        level = other.level,
                        income_per_second = other.income_per_second,
                        consume_count = take,
                    }
                    remaining = remaining - take
                    if remaining <= 0 then
                        return recipe, picked
                    end
                end
            end
        end
    end
    return nil, nil
end

---@param recipe table
---@param materials table[]
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
    result_attrs.income_per_second = math.tointeger(
        math.floor(first.income_per_second * (result.income_multiplier or 1) + (result.income_add or 0))
    )
    return result_item.id, result_attrs
end

---@param material table
local function consume_material(material)
    ItemSynthesisSystem.consume_equipment(material.equipment, material.consume_count or 1)
end

---@param role Role
---@param item_id integer|nil
---@param level integer|nil
---@return table
function ItemSynthesisSystem.synthesize(role, item_id, level)
    local character = role and role.get_ctrl_unit()
    if not character then
        return { success = false, reason = "no_role" }
    end

    local requested_item_id = item_id and item_id > 0 and item_id or nil
    local requested_level = level and level > 0 and level or nil
    local recipe, picked = find_match(collect_materials(character), requested_item_id, requested_level)
    if not recipe or not picked then
        return { success = false, reason = "materials_missing" }
    end

    local result_item_id, result_attrs = build_result(recipe, picked)
    if not result_item_id or not result_attrs then
        return { success = false, reason = "result_missing" }
    end

    for _, material in ipairs(picked) do
        consume_material(material)
    end

    local output = ItemSynthesisSystem.give_item_preferred_slots(
        role,
        result_item_id,
        result_attrs,
        1,
        { ItemSynthesisConfig.OUTPUT_SLOT_TYPE_NAME, "BACKPACK" }
    )

    return {
        success = true,
        reason = "ok",
        recipe_id = recipe.id,
        item_id = result_item_id,
        level = math.tointeger(result_attrs.level or 1),
        income_per_second = math.tointeger(result_attrs.income_per_second or 0),
        equipment = output,
    }
end

---@param role Role
---@param item_id integer
---@param attrs table<string, integer|string>|nil
---@param slot_type_name string|nil
---@param count integer|nil
---@return Equipment|nil
function ItemSynthesisSystem.give_item(role, item_id, attrs, slot_type_name, count)
    local character = role and role.get_ctrl_unit()
    local item = BoothConfig.find_item(item_id)
    if not character or not item or not item.prefab_id then
        return nil
    end

    local output_attrs = merge_item_attrs(item, attrs)
    local target_slot_type_name = slot_type_name or ItemSynthesisConfig.OUTPUT_SLOT_TYPE_NAME
    local stack = find_matching_stack_in_slot(character, item_id, output_attrs, target_slot_type_name)
    if stack then
        return add_to_stack(stack, item_id, output_attrs, count)
    end

    local equipment = character.create_equipment_to_slot(item.prefab_id, get_slot_type(target_slot_type_name))
    ItemSynthesisSystem.attach_attrs(equipment, item_id, output_attrs)
    set_stack_count(equipment, count or 1)
    ItemSynthesisSystem.save_role_inventory(role)
    return equipment
end

---@param role Role
---@param item_id integer
---@param attrs table<string, integer|string>|nil
---@param count integer|nil
---@param slot_type_names string[]|nil
---@return Equipment|nil
function ItemSynthesisSystem.give_item_preferred_slots(role, item_id, attrs, count, slot_type_names)
    local character = role and role.get_ctrl_unit()
    local item = BoothConfig.find_item(item_id)
    if not character or not item then
        return nil
    end

    local output_attrs = merge_item_attrs(item, attrs)
    local preferred_slots = slot_type_names or { ItemSynthesisConfig.OUTPUT_SLOT_TYPE_NAME, "BACKPACK" }
    for _, slot_type_name in ipairs(preferred_slots) do
        local stack = find_matching_stack_in_slot(character, item_id, output_attrs, slot_type_name)
        if stack then
            return add_to_stack(stack, item_id, output_attrs, count)
        end
    end

    for _, slot_type_name in ipairs(preferred_slots) do
        local equipment = ItemSynthesisSystem.give_item(role, item_id, output_attrs, slot_type_name, count)
        if equipment then
            return equipment
        end
    end
    return ItemSynthesisSystem.give_item(role, item_id, output_attrs, nil, count)
end

---按合成成长曲线推算某物品在指定等级的属性，与逐级合成的产物数值一致
---（每级套用对应配方的 income_multiplier/income_add）。
---超出合成上限（max_level）时停在可达的最高级。
---@param item_id integer
---@param level integer|nil 缺省或小于 1 时按 1 级
---@return table<string, integer|string>|nil attrs 物品未配置时返回 nil
function ItemSynthesisSystem.attrs_at_level(item_id, level)
    local item = BoothConfig.find_item(item_id)
    if not item then
        return nil
    end

    local attrs = copy_attrs(item.base_attrs)
    local target_level = math.tointeger(level) or 1
    local current_level = math.tointeger(attrs.level) or 1
    local income = math.tointeger(attrs.income_per_second) or 0
    while current_level < target_level do
        local recipe = ItemSynthesisConfig.find_recipe(item_id, current_level)
        if not recipe then
            break
        end
        local result = recipe.result or {}
        income = math.tointeger(
            math.floor(income * (result.income_multiplier or 1) + (result.income_add or 0))
        ) or income
        current_level = current_level + (math.tointeger(result.level_add) or 1)
    end

    attrs.level = current_level
    attrs.income_per_second = income
    return attrs
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
    local recipe = find_match(
        collect_materials(character),
        item_id and item_id > 0 and item_id or nil,
        level and level > 0 and level or nil
    )
    return recipe ~= nil, recipe and "ok" or "materials_missing"
end

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

---@param recipe table
---@param booth_material table
---@param held_material table
---@return boolean
local function recipe_matches_pair(recipe, booth_material, held_material)
    if math.tointeger(recipe.ingredient_count or 2) ~= 2 then
        return false
    end
    if recipe.same_item_id ~= false and booth_material.item_id ~= held_material.item_id then
        return false
    end
    if recipe.same_level ~= false and booth_material.level ~= held_material.level then
        return false
    end
    if math.tointeger(recipe.max_level or 0) > 0 and booth_material.level >= math.tointeger(recipe.max_level or 0) then
        return false
    end

    local ingredients = recipe.ingredients
    if type(ingredients) ~= "table" or #ingredients <= 0 then
        return contains_item_id(recipe.item_ids, booth_material.item_id)
            and contains_item_id(recipe.item_ids, held_material.item_id)
    end
    if #ingredients ~= 2 then
        return false
    end

    local first = ingredients[1]
    local second = ingredients[2]
    return (contains_item_id(first.item_ids, booth_material.item_id)
            and contains_item_id(second.item_ids, held_material.item_id))
        or (contains_item_id(first.item_ids, held_material.item_id)
            and contains_item_id(second.item_ids, booth_material.item_id))
end

---@param item_id integer
---@param attrs table<string, integer|string>|nil
---@param equipment Equipment|nil
---@return table|nil
local function preview_pair_result(item_id, attrs, equipment)
    local booth_item = BoothConfig.find_item(item_id)
    local held_item_id, held_attrs = ItemSynthesisSystem.get_equipment_item(equipment)
    if not booth_item or not held_item_id or not held_attrs then
        return nil
    end

    local booth_attrs = merge_item_attrs(booth_item, attrs)
    local booth_material = {
        item_id = item_id,
        attrs = booth_attrs,
        level = math.tointeger(booth_attrs.level or 1),
        income_per_second = math.tointeger(booth_attrs.income_per_second or 0),
        count = 1,
    }
    local held_material = {
        equipment = equipment,
        item_id = held_item_id,
        attrs = held_attrs,
        level = math.tointeger(held_attrs.level or 1),
        income_per_second = math.tointeger(held_attrs.income_per_second or 0),
        count = 1,
    }

    for _, recipe in ipairs(ItemSynthesisConfig.RECIPES or {}) do
        if recipe_matches_pair(recipe, booth_material, held_material) then
            local result_item_id, result_attrs = build_result(recipe, { booth_material, held_material })
            if result_item_id and result_attrs then
                return {
                    success = true,
                    reason = "ok",
                    recipe_id = recipe.id,
                    item_id = result_item_id,
                    attrs = result_attrs,
                    level = math.tointeger(result_attrs.level or 1),
                    income_per_second = math.tointeger(result_attrs.income_per_second or 0),
                    held_equipment = equipment,
                }
            end
            return { success = false, reason = "result_missing" }
        end
    end
    return nil
end

---@param item_id integer
---@param attrs table<string, integer|string>|nil
---@param equipment Equipment|nil
---@return table
function ItemSynthesisSystem.preview_pair(item_id, attrs, equipment)
    local preview = equipment and preview_pair_result(item_id, attrs, equipment) or nil
    return preview or { success = false, reason = equipment and "materials_missing" or "no_held_item" }
end

---@param item_id integer
---@param attrs table<string, integer|string>|nil
---@param equipment Equipment|nil
---@return boolean can
---@return string reason
function ItemSynthesisSystem.can_synthesize_pair(item_id, attrs, equipment)
    local result = ItemSynthesisSystem.preview_pair(item_id, attrs, equipment)
    return result.success == true, result.reason
end

return ItemSynthesisSystem
