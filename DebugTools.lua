-- Lua调试插件
-- ---example
-- --@export_plugin
-- --@style style_type[插件样式]
-- --@desc func_desc[方法描述]
-- --@param var_name[变量名] var_type[变量类型] var_desc[变量描述]
-- --@param.var_name param_extra_data_key[变量额外数据key] param_extra_data_value[变量额外数据value]
-- --@return return_type[返回值类型]
-- function func_name(var_name)
-- 	func_body
-- end
-- 说明：
-- 1、插件样式
-- 当前支持样式: button
-- button 按钮 点击后执行方法
-- e.g.
-- ---@style button
-- 2、变量类型
-- 当前支持类型: integer, number, boolean, string, Vector3, RoleID, Color
-- 3、变量额外数据key
-- 当前支持key: style, enum
-- 3.1 style
-- ui_type value 支持 textField, dropDown, multiDropDown
-- e.g. 设置参数样式为文本框
-- ---@param unit_desc string 组件说明
-- ---@param.unit_desc style textField
-- e.g. 设置参数样式为下拉枚举
-- ---@param role_id RoleID 玩家ID
-- ---@param.role_id style dropDown
-- ---@param.role_id enum [(1, "玩家1"), (2, "玩家2")]
-- e.g. 设置参数样式为多选下拉枚举
-- ---@param number[] 生效状态
-- ---@param.effect_state style multiDropDown
-- ---@param.effect_state enum [(1, "状态1"), (2, "状态2")]
-- 3.2 enum
-- 配合 dropDown 使用, 设置枚举选项


---@export_plugin
---@style button
---@desc 设置蛋仔位置
---@param role_id RoleID 玩家ID
---@param position Vector3 位置
function SetPosition(role_id, position)
	local role = GameAPI.get_role(role_id)
	if not role then
		return
	end
	local unit = role.get_ctrl_unit()
	if not unit then
		return
	end
	unit.set_position(position)
end

---@export_plugin
---@style button
---@desc 一键结束
---@param role_id RoleID 玩家ID
---@param result boolean 是否胜利
function SetRoleGameResult(role_id, result)
	local role = GameAPI.get_role(role_id)
	if not role then
		return
	end
	if (result)	then
		role.win()
	else
		role.lose()
	end
end

---@export_plugin
---@style button
---@desc 解锁展台区域
---@param role_id RoleID 玩家ID
---@param zone_id integer 展区ID
function UnlockBoothZone(role_id, zone_id)
	local role = GameAPI.get_role(role_id)
	if not role then
		return
	end

	local BoothController = require("Booth.BoothController")
	local success = BoothController.unlock_zone(role, zone_id)
	if success then
		role.show_tips("展区已解锁: " .. tostring(zone_id))
	else
		role.show_tips("展区解锁失败: " .. tostring(zone_id))
	end
end

---@export_plugin
---@style button
---@desc 调试发放脑红合成材料
---@param role_id RoleID 玩家ID
---@param item_id integer 物品ID
---@param level integer 等级(<=0默认1)
---@param count integer 数量(<=0默认1)
function GiveBoothSynthesisItem(role_id, item_id, level, count)
	local role = GameAPI.get_role(role_id)
	if not role then
		return
	end

	local ItemSynthesisSystem = require("Inventory.ItemSynthesisSystem")
	local attrs = ItemSynthesisSystem.attrs_at_level(item_id, math.tointeger(level))
	if not attrs then
		role.show_tips("发放失败: 未配置物品 " .. tostring(item_id))
		return
	end

	local output_count = math.tointeger(count) or 1
	if output_count <= 0 then
		output_count = 1
	end
	ItemSynthesisSystem.give_item_preferred_slots(role, item_id, attrs, output_count)
	role.show_tips("已发放合成材料 item=" .. tostring(item_id)
		.. " Lv." .. tostring(attrs.level)
		.. " x" .. tostring(output_count))
end

---@export_plugin
---@style button
---@desc 执行脑红物品合成
---@param role_id RoleID 玩家ID
---@param item_id integer 物品ID(<=0自动匹配)
---@param level integer 等级(<=0自动匹配)
function SynthesizeBoothItem(role_id, item_id, level)
	local role = GameAPI.get_role(role_id)
	if not role then
		return
	end

	local ItemSynthesisSystem = require("Inventory.ItemSynthesisSystem")
	local result = ItemSynthesisSystem.synthesize(role, item_id, level)
	if result.success then
		role.show_tips("合成成功: item=" .. tostring(result.item_id)
			.. " Lv." .. tostring(result.level)
			.. " 收益=" .. tostring(result.income_per_second) .. "/s")
	else
		role.show_tips("合成失败: " .. tostring(result.reason))
	end
end

---@export_plugin
---@style button
---@desc 检测脑红合成功能
---@param role_id RoleID 玩家ID
---@param item_id integer 物品ID
function TestBoothItemSynthesis(role_id, item_id)
	local role = GameAPI.get_role(role_id)
	if not role then
		return
	end

	local ItemSynthesisSystem = require("Inventory.ItemSynthesisSystem")
	local attrs = ItemSynthesisSystem.attrs_at_level(item_id, 1)
	if not attrs then
		role.show_tips("合成检测失败: 未配置物品 " .. tostring(item_id))
		return
	end

	ItemSynthesisSystem.give_item_preferred_slots(role, item_id, attrs, 2)

	local result = ItemSynthesisSystem.synthesize(role, item_id, attrs.level)
	local expected = ItemSynthesisSystem.attrs_at_level(item_id, attrs.level + 1)
	if result.success
		and result.level == expected.level
		and result.income_per_second == expected.income_per_second then
		role.show_tips("合成检测通过: Lv." .. tostring(result.level)
			.. " 收益=" .. tostring(result.income_per_second) .. "/s")
	else
		role.show_tips("合成检测失败: reason=" .. tostring(result.reason)
			.. " level=" .. tostring(result.level)
			.. " income=" .. tostring(result.income_per_second))
	end
end

---@export_plugin
---@style button
---@desc 检测脑红实例KV读写
---@param role_id RoleID 玩家ID
---@param item_id integer 物品ID
---@param level integer 等级(<=0默认3)
function TestBoothItemInstanceKV(role_id, item_id, level)
	local role = GameAPI.get_role(role_id)
	if not role then
		return
	end

	local ItemSynthesisSystem = require("Inventory.ItemSynthesisSystem")
	local target_level = math.tointeger(level) or 3
	if target_level <= 0 then
		target_level = 3
	end
	local attrs = ItemSynthesisSystem.attrs_at_level(item_id, target_level)
	if not attrs then
		role.show_tips("实例KV检测失败: 未配置物品 " .. tostring(item_id))
		return
	end
	target_level = attrs.level

	local equipment = ItemSynthesisSystem.give_item_preferred_slots(role, item_id, attrs, 1)
	if not equipment then
		role.show_tips("实例KV检测失败: 发放物品失败")
		return
	end

	local kv_item_id = math.tointeger(equipment.get_kv_by_type(Enums.ValueType.Int, "booth_item_id")) or 0
	local kv_level = math.tointeger(equipment.get_kv_by_type(Enums.ValueType.Int, "booth_level")) or 0
	local kv_income = math.tointeger(equipment.get_kv_by_type(Enums.ValueType.Int, "booth_income_per_second")) or 0
	local read_item_id, read_attrs = ItemSynthesisSystem.get_equipment_item(equipment)
	local read_level = read_attrs and math.tointeger(read_attrs.level or 0) or 0
	local read_income = read_attrs and math.tointeger(read_attrs.income_per_second or 0) or 0

	if kv_item_id == item_id
		and kv_level == target_level
		and kv_income == attrs.income_per_second
		and read_item_id == item_id
		and read_level == target_level
		and read_income == attrs.income_per_second then
		role.show_tips("实例KV检测通过: item=" .. tostring(item_id)
			.. " Lv." .. tostring(target_level)
			.. " 收益=" .. tostring(kv_income) .. "/s")
	else
		role.show_tips("实例KV检测失败: kv="
			.. tostring(kv_item_id) .. "/"
			.. tostring(kv_level) .. "/"
			.. tostring(kv_income)
			.. " read=" .. tostring(read_item_id) .. "/"
			.. tostring(read_level) .. "/"
			.. tostring(read_income))
	end
end

---@export_plugin
---@style button
---@desc 检测合成后展台收益同步
---@param role_id RoleID 玩家ID
---@param zone_id integer 展区ID
---@param booth_index integer 展台索引(从0开始)
---@param item_id integer 物品ID
function TestBoothSynthesisBoardSync(role_id, zone_id, booth_index, item_id)
	local role = GameAPI.get_role(role_id)
	if not role then
		return
	end

	local BoothConfig = require("Booth.BoothConfig")
	local BoothController = require("Booth.BoothController")
	local BoothPlacement = require("Booth.BoothPlacement")
	local BoothState = require("Booth.BoothState")
	local BoothZoneView = require("Booth.BoothZoneView")
	local ItemSynthesisSystem = require("Inventory.ItemSynthesisSystem")

	local attrs = ItemSynthesisSystem.attrs_at_level(item_id, 1)
	if not attrs then
		role.show_tips("展台合成检测失败: 未配置物品 " .. tostring(item_id))
		return
	end
	if not BoothConfig.is_valid_booth(zone_id, booth_index) then
		role.show_tips("展台合成检测失败: 展台位非法")
		return
	end
	if BoothController.get_placement(role, zone_id, booth_index) then
		role.show_tips("展台合成检测失败: 目标展台已占用")
		return
	end

	BoothController.unlock_zone(role, zone_id)

	ItemSynthesisSystem.give_item_preferred_slots(role, item_id, attrs, 2)

	local result = ItemSynthesisSystem.synthesize(role, item_id, attrs.level)
	if not result.success then
		role.show_tips("展台合成检测失败: 合成失败 " .. tostring(result.reason))
		return
	end

	local placed, reason = BoothPlacement.place(role, zone_id, booth_index)
	if not placed then
		role.show_tips("展台合成检测失败: 放置失败 " .. tostring(reason))
		return
	end

	BoothZoneView.refresh_zone(role, zone_id)
	local state = BoothController.get_state(role)
	local per_second = state and BoothState.zone_income_per_second(state, zone_id) or 0
	if per_second >= result.income_per_second then
		role.show_tips("展台合成检测通过: 展区每秒总收益=" .. tostring(per_second))
	else
		role.show_tips("展台合成检测失败: 展区收益=" .. tostring(per_second)
			.. " 期望>=" .. tostring(result.income_per_second))
	end
end
