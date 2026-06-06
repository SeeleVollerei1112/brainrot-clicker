--[[
Booth/BoothZoneView.lua

展台区场景表现层。
锁定展区隐藏展台模型并关闭物理；解锁展区显示展台模型并恢复碰撞。
公告板展示当前展区状态（每秒总收益 + 随时间累计的总收益）。
每个已放置展台在展示台上方绑定一个 3D 场景界面(E3DLayer)，显示该实例的
等级与每秒收益。展台和公告板都是编辑器中已摆放的场景单位，运行时按
BoothConfig 的命名规则通过 LuaAPI.query_unit 查询并缓存。

头顶 3D 文字依赖编辑器导出的界面预设/节点（见 BoothConfig.HEAD_UI）：
预设或节点尚未导出时，运行时安全跳过头顶文字并打日志，其余逻辑不受影响。
头顶界面句柄与公告板一样按场景维度（zone|booth）维护，符合本玩法单活跃
玩家的前提；玩家离开时统一销毁(clear_labels)。
]]

local BoothConfig = require("Booth.BoothConfig")
local BoothController = require("Booth.BoothController")
local BoothState = require("Booth.BoothState")
local PrefabData = require("Data.Prefab")
local UINodes = require("Data.UINodes")

local BoothZoneView = {}

local COLOR_LOCKED = 0xFFFF3030
local COLOR_UNLOCKED = 0xFFFFFFFF

-- 展示台模型：stands_cache[zone_id][booth_index] = Unit
---@type table<integer, table<integer, Unit>>
local stands_cache = {}

---@type table<integer, Unit>
local board_cache = {}

---@type table<integer, boolean>
local resolved_zone = {}

-- 头顶 3D 界面句柄：head_layer["zone|booth"] = E3DLayer
---@type table<string, any>
local head_layer = {}

-- 头顶界面预设/节点缺失时只告警一次，避免每次刷新刷屏。
local head_missing_logged = false

---@param zone_id integer
---@param booth_index integer
---@return string
local function slot_key(zone_id, booth_index)
    return tostring(zone_id) .. "|" .. tostring(booth_index)
end

---@param node any
---@return boolean
local function is_node(node)
    return node ~= nil and node ~= false and node ~= 0 and node ~= ""
end

---读取头顶 3D 界面预设编号；未导出(Data/Prefab.lua 无 scene_eui 表或缺键)时返回 nil。
---@return any|nil layer_key
local function head_layer_key()
    local scene_eui = PrefabData.scene_eui
    return scene_eui and scene_eui[BoothConfig.HEAD_UI.layer_name] or nil
end

---@param layer any
---@param node_name string|nil
---@return any|nil node
local function get_scene_ui_node(layer, node_name)
    local node_id = node_name and UINodes[node_name]
    if not is_node(node_id) then
        return nil
    end
    return GameAPI.get_eui_node_at_scene_ui(layer, node_id)
end

---@param zone_id integer
local function resolve_zone_units(zone_id)
    if resolved_zone[zone_id] then
        return
    end

    resolved_zone[zone_id] = true

    local stands = {}
    local zone = BoothConfig.find_zone(zone_id)
    if zone then
        for booth_index = 0, zone.booth_count - 1 do
            local name = BoothConfig.booth_stand_name(zone_id, booth_index)
            local unit = LuaAPI.query_unit(name)
            if unit then
                stands[booth_index] = unit
            else
                LuaAPI.log("[BoothZoneView] 找不到展台模型: " .. tostring(name), 1)
            end
        end
    end
    stands_cache[zone_id] = stands

    local board_name = BoothConfig.zone_board_name(zone_id)
    local board = LuaAPI.query_unit(board_name)
    if not board then
        LuaAPI.log("[BoothZoneView] 找不到公告板: " .. tostring(board_name), 1)
    end
    board_cache[zone_id] = board
end

---@param unit Unit
local function unlock_stand(unit)
    unit.set_model_visible(true)
    unit.set_physics_active(true)
    unit.set_model_physic_visible(true)

    LuaAPI.call_delay_frame(1, function()
        unit.set_model_visible(true)
        unit.set_physics_active(true)
        unit.set_model_physic_visible(true)
    end)
end

---@param unit Unit
local function lock_stand(unit)
    unit.set_physics_active(false)
    unit.set_model_physic_visible(false)
    unit.set_model_visible(false)
end

function BoothZoneView.initialize()
    -- 重新初始化前销毁残留的头顶界面句柄，避免泄漏。
    for _, layer in pairs(head_layer) do
        GameAPI.destroy_scene_ui(layer)
    end
    stands_cache = {}
    board_cache = {}
    resolved_zone = {}
    head_layer = {}
    head_missing_logged = false
end

-- ---------- 收益 ----------

---某展区当前「每秒总收益」与「随时间累计总收益」。
---@param role Role
---@param zone_id integer
---@return integer income_per_second, integer income_total
function BoothZoneView.compute_zone_income(role, zone_id)
    local state = BoothController.get_state(role)
    if not state then
        return 0, 0
    end
    return BoothState.zone_income_per_second(state, zone_id),
        BoothState.zone_income_total(state, zone_id)
end

-- ---------- 头顶 3D 文字 ----------

---销毁某展台位的头顶界面（若有）。
---@param key string
local function destroy_head_layer(key)
    local layer = head_layer[key]
    if layer then
        GameAPI.destroy_scene_ui(layer)
        head_layer[key] = nil
    end
end

---把等级/每秒收益写进头顶界面的文本节点（对所有可见玩家生效）。
---@param layer any
---@param level integer
---@param income_per_second integer
local function set_head_text(layer, level, income_per_second)
    local style = BoothConfig.HEAD_UI.style or {}
    local level_node = get_scene_ui_node(layer, BoothConfig.HEAD_UI.level_node)
    local income_node = get_scene_ui_node(layer, BoothConfig.HEAD_UI.income_node)
    if not level_node and not income_node then
        return
    end

    local background_nodes = {}
    for _, node_name in ipairs(BoothConfig.HEAD_UI.background_nodes or {}) do
        local node = get_scene_ui_node(layer, node_name)
        if node then
            background_nodes[#background_nodes + 1] = node
        end
    end

    for _, role in ipairs(GameAPI.get_all_valid_roles()) do
        local to_fixed = math.tofixed
        if level_node then
            role.set_label_text(level_node, (style.level_prefix or "Lv.") .. tostring(level))
            role.set_label_color(level_node, style.level_color or 0xFFD14D2B, to_fixed(0))
            role.set_label_font_size(level_node, style.level_font_size or 32, to_fixed(0))
            role.set_label_background_opacity(level_node, to_fixed(style.label_background_opacity or 0.0), to_fixed(0))
            role.set_label_outline_enabled(level_node, true)
            role.set_label_outline_color(level_node, style.outline_color or 0xFF000000)
            role.set_label_outline_width(level_node, to_fixed(style.outline_width or 2))
        end
        if income_node then
            role.set_label_text(income_node,
                (style.income_prefix or "+") .. tostring(income_per_second) .. (style.income_suffix or "/s"))
            role.set_label_color(income_node, style.income_color or 0xFF2BAFD1, to_fixed(0))
            role.set_label_font_size(income_node, style.income_font_size or 28, to_fixed(0))
            role.set_label_background_opacity(income_node, to_fixed(style.label_background_opacity or 0.0), to_fixed(0))
            role.set_label_outline_enabled(income_node, true)
            role.set_label_outline_color(income_node, style.outline_color or 0xFF000000)
            role.set_label_outline_width(income_node, to_fixed(style.outline_width or 2))
        end
        for _, background_node in ipairs(background_nodes) do
            role.set_node_visible(background_node, style.background_visible == true)
            role.set_ui_opacity(background_node, to_fixed(style.background_opacity or 0.0))
        end
    end
end

---刷新某展台位的头顶 3D 文字：占用则创建/更新，空置则销毁。
---@param role Role
---@param zone_id integer
---@param booth_index integer
function BoothZoneView.refresh_booth_label(role, zone_id, booth_index)
    local key = slot_key(zone_id, booth_index)

    local state = BoothController.get_state(role)
    local placement = state and BoothState.get_placement(state, zone_id, booth_index)
    local unlocked = state and BoothState.is_zone_unlocked(state, zone_id)
    if not placement or not unlocked then
        destroy_head_layer(key)
        return
    end

    local layer_key = head_layer_key()
    if not layer_key then
        if not head_missing_logged then
            head_missing_logged = true
            LuaAPI.log("[BoothZoneView] 头顶界面预设未导出(待编辑器): "
                .. tostring(BoothConfig.HEAD_UI.layer_name) .. "，跳过头顶文字", 1)
        end
        return
    end

    local stands = stands_cache[zone_id]
    local stand = stands and stands[booth_index]
    if not stand then
        return
    end

    local layer = head_layer[key]
    if not layer then
        local off = BoothConfig.HEAD_UI.offset
        layer = stand.create_scene_ui_bind_unit(
            layer_key,
            BoothConfig.HEAD_UI.socket,
            math.Vector3(off.x, off.y, off.z),
            -1.0,  -- 持续时间：-1 = 常驻（沙盒不接受 nil）
            false, -- 事件不指向绑定者
            true   -- 跟随展示台显隐（展区锁定隐藏模型时一并隐藏）
        )
        head_layer[key] = layer
    end
    if not layer then
        return
    end

    local attrs = placement.attrs or {}
    local level = math.tointeger(attrs.level or 1) or 1
    local income = math.tointeger(attrs.income_per_second or 0) or 0
    set_head_text(layer, level, income)
end

-- ---------- 刷新入口 ----------

---只刷新某展区公告板的收益文本/颜色（供每秒收益结算高频调用，不动模型与头顶界面）。
---@param role Role
---@param zone_id integer
function BoothZoneView.refresh_board(role, zone_id)
    resolve_zone_units(zone_id)
    local board = board_cache[zone_id]
    if not board then
        return
    end

    local state = BoothController.get_state(role)
    local unlocked = state and BoothState.is_zone_unlocked(state, zone_id)
    if unlocked then
        local per_second, total = BoothZoneView.compute_zone_income(role, zone_id)
        board.set_billboard_text("每秒总收益: " .. tostring(per_second) .. "\n总收益: " .. tostring(total))
        board.set_billboard_text_color(COLOR_UNLOCKED)
    else
        board.set_billboard_text("未解锁")
        board.set_billboard_text_color(COLOR_LOCKED)
    end
end

---整刷某展区：展示台显隐/物理 + 公告板收益 + 各展台位头顶文字。
---@param role Role
---@param zone_id integer
function BoothZoneView.refresh_zone(role, zone_id)
    local state = BoothController.get_state(role)
    local unlocked = BoothState.is_zone_unlocked(state, zone_id)

    resolve_zone_units(zone_id)

    local zone = BoothConfig.find_zone(zone_id)
    local stands = stands_cache[zone_id] or {}
    if zone then
        for booth_index = 0, zone.booth_count - 1 do
            local stand = stands[booth_index]
            if stand then
                if unlocked then
                    unlock_stand(stand)
                else
                    lock_stand(stand)
                end
            end
            BoothZoneView.refresh_booth_label(role, zone_id, booth_index)
        end
    end

    BoothZoneView.refresh_board(role, zone_id)
end

---@param role Role
function BoothZoneView.refresh_all(role)
    for _, zone in ipairs(BoothConfig.ZONES) do
        BoothZoneView.refresh_zone(role, zone.id)
    end
end

---玩家离开时销毁其所有头顶 3D 文字句柄（公告板是场景共享单位，无需按玩家清理）。
---@param _role Role
function BoothZoneView.clear_labels(_role)
    for key in pairs(head_layer) do
        destroy_head_layer(key)
    end
end

return BoothZoneView
