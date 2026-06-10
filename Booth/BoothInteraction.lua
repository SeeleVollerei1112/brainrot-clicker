--[[
Booth/BoothInteraction.lua

展台交互层：玩家进出每个展台位的「事件触发区域」时，按当前状态显隐
「放置 / 回收 / 合成」按钮；点击按钮则对玩家所在展台位执行对应操作。

触发区域按命名(BoothConfig.booth_trigger_name)用 LuaAPI.query_unit 反查，
逐个注册 ANY_LIFEENTITY_TRIGGER_SPACE 的 ENTER / LEAVE，建立
trigger_zone_id -> (zone_id, booth_index) 注册表。

「放置/回收/合成」按钮节点由编辑器导出到 Data/UINodes.lua（名字见 BoothConfig.UI）；
若尚未导出，运行时安全跳过显隐并打日志。按钮显隐用 set_node_visible（与背包/
商城一致：同时摘除隐藏页触摸响应）。
]]
local BoothConfig = require("Booth.BoothConfig")
local UINodes = require("Data.UINodes")
local AppConfig = require("App.AppConfig")
local get_role_id = require("Util.RoleUtil").get_role_id

local BoothInteraction = {}
local BoothPlacement = nil
local BoothZoneView = nil

local TOUCH_CLICK = AppConfig.TOUCH.CLICK
local ENTER = Enums.TriggerSpaceEventType.ENTER
local LEAVE = Enums.TriggerSpaceEventType.LEAVE

-- 触发区域 ID -> { 展区 ID, 展台位索引 }
---@type table<CustomTriggerSpaceID, { zone_id: integer, booth_index: integer }>
local booth_by_zone_id = {}

-- 当前展台位：current_booth[role_id] = { zone_id, booth_index }
---@type table<RoleID, { zone_id: integer, booth_index: integer }>
local current_booth = {}

-- 交互按钮表驱动配置：config_key 对应 BoothConfig.UI 的键，action 为点击后执行的
-- 放置层操作名，label 用于节点缺失日志；node 在 initialize 时解析填入。
---@type { config_key: string, action: string, label: string, node: any }[]
local buttons = {
    { config_key = "place_button", action = "place", label = "放置" },
    { config_key = "recycle_button", action = "recycle", label = "回收" },
    { config_key = "synthesis_button", action = "synthesize_with_selected", label = "合成" },
}

local function get_placement()
    if not BoothPlacement then
        BoothPlacement = require("Booth.BoothPlacement")
    end
    return BoothPlacement
end

local function get_zone_view()
    if not BoothZoneView then
        BoothZoneView = require("Booth.BoothZoneView")
    end
    return BoothZoneView
end

---按某展台位的占用/背包情况，显隐放置/回收/合成按钮。
---@param role Role
---@param zone_id integer
---@param booth_index integer
local function update_buttons(role, zone_id, booth_index)
    local placement = get_placement()
    local occupied = placement.is_occupied(role, zone_id, booth_index)
    local visible = {
        place_button = (not occupied) and placement.has_placeable_item(role),
        recycle_button = occupied,
        synthesis_button = occupied
            and placement.can_synthesize_with_selected(role, zone_id, booth_index),
    }
    for _, button in ipairs(buttons) do
        if button.node then
            role.set_node_visible(button.node, visible[button.config_key] == true)
        end
    end
end

---隐藏所有交互按钮。
---@param role Role
local function hide_buttons(role)
    for _, button in ipairs(buttons) do
        if button.node then
            role.set_node_visible(button.node, false)
        end
    end
end

---进入某展台位触发区域。
---@param role Role
---@param zone_id integer
---@param booth_index integer
local function on_enter(role, zone_id, booth_index)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end
    current_booth[role_id] = { zone_id = zone_id, booth_index = booth_index }
    update_buttons(role, zone_id, booth_index)
end

---离开某展台位触发区域。
---@param role Role
---@param zone_id integer
---@param booth_index integer
local function on_leave(role, zone_id, booth_index)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end
    -- 仅当离开的是「当前记录的展台位」才清除（避免先进后离的乱序覆盖）。
    local cur = current_booth[role_id]
    if cur and cur.zone_id == zone_id and cur.booth_index == booth_index then
        current_booth[role_id] = nil
    end
    hide_buttons(role)
end

---点击放置/回收后，对玩家当前展台位执行操作并刷新按钮。
---@param role Role
---@param action fun(role: Role, zone_id: integer, booth_index: integer): boolean, string
local function run_action_on_current(role, action)
    local role_id = get_role_id(role)
    local cur = role_id and current_booth[role_id]
    if not cur then
        return
    end
    action(role, cur.zone_id, cur.booth_index)
    -- 操作后状态变化（占用/背包），重新评估按钮。
    update_buttons(role, cur.zone_id, cur.booth_index)
    -- 放置/回收改变了该区物品，刷新公告板收益展示。
    get_zone_view().refresh_zone(role, cur.zone_id)
end

---注册每个展台位触发区域的进出事件。
---@param register_trigger fun(event_arguments: table, callback: function): integer
local function bind_zone_triggers(register_trigger)
    local bound, missing = 0, 0
    BoothConfig.for_each_booth(function(zone_id, booth_index, trigger_name)
        local unit = LuaAPI.query_unit(trigger_name)
        if not unit then
            missing = missing + 1
            LuaAPI.log("[BoothInteraction] 找不到展台触发区域: " .. tostring(trigger_name), 1)
            return
        end
        local zone_unit_id = LuaAPI.get_unit_id(unit)
        booth_by_zone_id[zone_unit_id] = { zone_id = zone_id, booth_index = booth_index }

        -- 触发单位来自引擎事件，非玩家角色 get_ctrl_role 返回 nil，逐层守卫。
        register_trigger(
            { EVENT.ANY_LIFEENTITY_TRIGGER_SPACE, ENTER, zone_unit_id },
            function(event_name, actor, data)
                local entity = data and data.event_unit
                local role = entity and entity.get_ctrl_role()
                if role then
                    on_enter(role, zone_id, booth_index)
                end
            end
        )
        register_trigger(
            { EVENT.ANY_LIFEENTITY_TRIGGER_SPACE, LEAVE, zone_unit_id },
            function(event_name, actor, data)
                local entity = data and data.event_unit
                local role = entity and entity.get_ctrl_role()
                if role then
                    on_leave(role, zone_id, booth_index)
                end
            end
        )
        bound = bound + 1
    end)
    LuaAPI.log("[BoothInteraction] 展台触发区域绑定完成 bound=" .. bound .. " missing=" .. missing, 0)
end

---注册放置/回收/合成按钮点击。
---@param register_trigger fun(event_arguments: table, callback: function): integer
local function bind_buttons(register_trigger)
    for _, button in ipairs(buttons) do
        if button.node then
            local action_name = button.action
            register_trigger(
                { EVENT.EUI_NODE_TOUCH_EVENT, button.node, TOUCH_CLICK },
                function(event_name, actor, data)
                    if data and data.role then
                        run_action_on_current(data.role, get_placement()[action_name])
                    end
                end
            )
        else
            LuaAPI.log("[BoothInteraction] 缺少" .. button.label .. "按钮节点(待导出): "
                .. tostring(BoothConfig.UI[button.config_key]), 1)
        end
    end
end

local function hide_buttons_for_all_roles()
    for _, role in ipairs(GameAPI.get_all_valid_roles()) do
        hide_buttons(role)
    end
end

---GAME_INIT 时由 GameApp 调用：解析按钮节点 + 绑定触发区域与按钮。
---@param register_trigger fun(event_arguments: table, callback: function): integer
function BoothInteraction.initialize(register_trigger)
    booth_by_zone_id = {}
    current_booth = {}
    for _, button in ipairs(buttons) do
        button.node = UINodes[BoothConfig.UI[button.config_key]]
    end

    hide_buttons_for_all_roles()
    bind_zone_triggers(register_trigger)
    bind_buttons(register_trigger)
    LuaAPI.log("[BoothInteraction] 展台交互初始化完成", 0)
end

---玩家会话创建时：初始隐藏交互按钮。
---@param role Role
function BoothInteraction.initialize_role(role)
    hide_buttons(role)
end

---玩家离开：清除其当前展台位记录。
---@param role Role
function BoothInteraction.cleanup_role(role)
    local role_id = get_role_id(role)
    if role_id then
        current_booth[role_id] = nil
    end
end

return BoothInteraction
