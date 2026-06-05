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


local BoothController = nil
local BoothState = nil
local BoothPersistence = nil
local BoothZoneView = nil

local function load_booth_modules()
	if BoothController and BoothState and BoothPersistence and BoothZoneView then
		return true
	end

	local ok, module = pcall(require, "Booth.BoothController")
	if not ok then
		LuaAPI.log("[Debug] 加载 BoothController 失败: " .. tostring(module), 1)
		return false
	end
	BoothController = module

	ok, module = pcall(require, "Booth.BoothState")
	if not ok then
		LuaAPI.log("[Debug] 加载 BoothState 失败: " .. tostring(module), 1)
		return false
	end
	BoothState = module

	ok, module = pcall(require, "Booth.BoothPersistence")
	if not ok then
		LuaAPI.log("[Debug] 加载 BoothPersistence 失败: " .. tostring(module), 1)
		return false
	end
	BoothPersistence = module

	ok, module = pcall(require, "Booth.BoothZoneView")
	if not ok then
		LuaAPI.log("[Debug] 加载 BoothZoneView 失败: " .. tostring(module), 1)
		return false
	end
	BoothZoneView = module

	return true
end

local function get_debug_role(action, role_id)
	LuaAPI.log("[Debug] " .. action .. " 点击 role_id=" .. tostring(role_id), 0)
	local role = GameAPI.get_role(role_id)
	if not role then
		LuaAPI.log("[Debug] " .. action .. " 未找到玩家 role_id=" .. tostring(role_id), 1)
	end
	return role
end

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
	if (result) then
		role.win()
	else
		role.lose()
	end
end

-- ============================================================
-- 展台存档调试按钮（Booth save-layer）
-- 结果统一用 LuaAPI.log 打到 log.txt（game_execute 无返回值）。
-- ============================================================

---@export_plugin
---@style button
---@desc 展台-填充测试数据并存档
---@param role_id RoleID 玩家ID
function BoothSeedTestData(role_id)
	if not load_booth_modules() then
		return
	end
	local role = get_debug_role("BoothSeedTestData", role_id)
	if not BoothController or not role then
		return
	end
	BoothController.unlock_zone(role, 2)
	BoothController.place_item(role, 1, 0, 101)
	BoothController.place_item(role, 1, 2, 103)
	BoothController.place_item(role, 2, 0, 105)
	-- 体现「实例属性可变」：给区2-台0的物品改属性
	BoothController.set_item_attr(role, 2, 0, "level", 7)
	BoothController.set_item_attr(role, 2, 0, "income_per_second", 999)
	BoothController.set_item_attr(role, 2, 0, "name", "满级古董钟")
	BoothController.save_now(role)
	LuaAPI.log("[Debug] 展台测试数据已写入: " .. BoothController.dump_json(role), 0)
end

---@export_plugin
---@style button
---@desc 展台-打印当前状态JSON
---@param role_id RoleID 玩家ID
function BoothDump(role_id)
	if not load_booth_modules() then
		return
	end
	local role = get_debug_role("BoothDump", role_id)
	if not role or not BoothController then
		return
	end
	LuaAPI.log("[Debug] 展台当前状态: " .. BoothController.dump_json(role), 0)
end

---@export_plugin
---@style button
---@desc 展台-立即存档
---@param role_id RoleID 玩家ID
function BoothSaveNow(role_id)
	if not load_booth_modules() then
		return
	end
	local role = get_debug_role("BoothSaveNow", role_id)
	if not role or not BoothController then
		return
	end
	BoothController.save_now(role)
	LuaAPI.log("[Debug] 展台立即存档已触发: " .. BoothController.dump_json(role), 0)
end

---@export_plugin
---@style button
---@desc 展台-从存档重新读取并打印
---@param role_id RoleID 玩家ID
function BoothLoadNow(role_id)
	if not load_booth_modules() then
		return
	end
	local role = get_debug_role("BoothLoadNow", role_id)
	if not role or not BoothPersistence then
		return
	end
	local loaded = BoothPersistence.load(role)
	LuaAPI.log("[Debug] 从存档读取的展台状态: " .. BoothPersistence.to_json(loaded), 0)
end

---@export_plugin
---@style button
---@desc 展台-序列化往返自测(不依赖存档开关)
function BoothRoundTripTest()
	LuaAPI.log("[Debug] BoothRoundTripTest 点击", 0)
	if not load_booth_modules() or not BoothState or not BoothPersistence then
		return
	end

	local state = BoothState.new()
	BoothState.unlock_zone(state, 2)
	BoothState.place_item(state, 1, 0, 101)
	BoothState.place_item(state, 2, 0, 105)
	BoothState.set_item_attr(state, 2, 0, "level", 7)
	BoothState.set_item_attr(state, 2, 0, "income_per_second", 999)
	BoothState.set_item_attr(state, 2, 0, "name", "满级古董钟")

	local json1 = BoothPersistence.to_json(state)
	local restored = BoothPersistence.from_json(json1)
	local json2 = BoothPersistence.to_json(restored)

	if json1 == json2 then
		LuaAPI.log("[Debug] 展台序列化往返自测 PASS: " .. json1, 0)
	else
		LuaAPI.log("[Debug] 展台序列化往返自测 FAIL\n  json1=" .. json1 .. "\n  json2=" .. json2, 1)
	end
end

---@export_plugin
---@style button
---@desc 展台-解锁指定展台区
---@param role_id RoleID 玩家ID
---@param zone_id integer 展台区ID
function BoothUnlockZone(role_id, zone_id)
	if not load_booth_modules() then
		return
	end
	local role = get_debug_role("BoothUnlockZone", role_id)
	if not role or not BoothController then
		return
	end
	local ok = BoothController.unlock_zone(role, zone_id)
	if ok and BoothZoneView then
		BoothZoneView.refresh_zone(role, zone_id)
	end
	LuaAPI.log("[Debug] 解锁展台区 " .. tostring(zone_id) .. " 结果=" .. tostring(ok)
		.. " 状态: " .. BoothController.dump_json(role), 0)
end

---@export_plugin
---@style button
---@desc 展台-重新锁定展台区(撤销解锁,默认区1不可锁,用于测试未解锁视觉)
---@param role_id RoleID 玩家ID
---@param zone_id integer 展台区ID
function BoothLockZone(role_id, zone_id)
	if not load_booth_modules() then
		return
	end
	local role = get_debug_role("BoothLockZone", role_id)
	if not role or not BoothController then
		return
	end
	local ok = BoothController.lock_zone(role, zone_id)
	if ok and BoothZoneView then
		BoothZoneView.refresh_zone(role, zone_id)
	end
	LuaAPI.log("[Debug] 重新锁定展台区 " .. tostring(zone_id) .. " 结果=" .. tostring(ok)
		.. " 状态: " .. BoothController.dump_json(role), 0)
end

---@export_plugin
---@style button
---@desc 展台-放置物品
---@param role_id RoleID 玩家ID
---@param zone_id integer 展台区ID
---@param booth_index integer 展台位索引(从0起)
---@param item_id integer 物品ID
function BoothPlaceItem(role_id, zone_id, booth_index, item_id)
	if not load_booth_modules() then
		return
	end
	local role = get_debug_role("BoothPlaceItem", role_id)
	if not role or not BoothController then
		return
	end
	local ok = BoothController.place_item(role, zone_id, booth_index, item_id)
	LuaAPI.log("[Debug] 放置物品 z=" .. tostring(zone_id) .. " b=" .. tostring(booth_index)
		.. " item=" .. tostring(item_id) .. " 结果=" .. tostring(ok)
		.. " 状态: " .. BoothController.dump_json(role), 0)
end

---@export_plugin
---@style button
---@desc 展台-按条件尝试解锁展台区(走 unlock_condition/unlock_cost 字段)
---@param role_id RoleID 玩家ID
---@param zone_id integer 展台区ID
function BoothTryUnlockZone(role_id, zone_id)
	if not load_booth_modules() then
		return
	end
	local role = get_debug_role("BoothTryUnlockZone", role_id)
	if not role or not BoothController then
		return
	end
	local ok, reason = BoothController.try_unlock_zone(role, zone_id)
	if ok and BoothZoneView then
		BoothZoneView.refresh_zone(role, zone_id)
	end
	LuaAPI.log("[Debug] 尝试解锁展台区 " .. tostring(zone_id) .. " 结果=" .. tostring(ok)
		.. " 原因=" .. tostring(reason) .. " 状态: " .. BoothController.dump_json(role), 0)
end

---@export_plugin
---@style button
---@desc 展台-给背包发一件测试物品(脑红1,用于试玩放置)
---@param role_id RoleID 玩家ID
function BoothGiveTestItem(role_id)
	local role = get_debug_role("BoothGiveTestItem", role_id)
	if not role then
		return
	end
	local ch = role.get_ctrl_unit()
	if not ch then
		LuaAPI.log("[Debug] BoothGiveTestItem 未找到控制单位", 1)
		return
	end
	local ok = pcall(function()
		ch.create_equipment_to_slot(1073741848, Enums.EquipmentSlotType.BACKPACK)
	end)
	LuaAPI.log("[Debug] 给背包发测试物品 脑红1 结果=" .. tostring(ok), 0)
end
