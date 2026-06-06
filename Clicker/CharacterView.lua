--[[
Clicker/CharacterView.lua

角色点击表现层。
负责绑定点击目标、播放角色点击反馈，并按玩家累计脑腐值切换皮肤。

皮肤配置在 ClickerConfig.CHARACTER.skins 中。人物图片和 burst 颜色走玩家维度
渲染调用；特效节点是共享 UI 节点，但每个玩家单独显隐和播放，避免互相串状态。
]]

local CharacterView = {}
local AppConfig = require("App.AppConfig")
local ClickerConfig = require("Clicker.ClickerConfig")
local SkinSystem = require("Clicker.SkinSystem")
local configuration = ClickerConfig.CHARACTER
local nodes = {}
local effect_nodes = {}
local squeeze_generations_by_role_id = {}
local applied_tier_by_role_id = {}
local active_burst_by_role_id = {}
local lifecycle_generation = 0

---@param role Role
---@return RoleID|nil role_id
local function get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

---把 AARRGGBB 颜色强制转成不透明，保留 RGB。
---@param color integer
---@return integer opaque_color
local function to_opaque(color)
    return 0xFF000000 + (color % 0x1000000)
end

---@param role Role
local function play_burst(role)
    if not role or not nodes.burst then
        return
    end

    local role_id = get_role_id(role)
    local burst = (role_id and active_burst_by_role_id[role_id]) or configuration.burst

    role.set_image_color(nodes.burst, burst.flash_color, math.tofixed(0))
    role.set_image_color(nodes.burst, burst.rest_color, math.tofixed(burst.rest_transition))
end

---@param role Role
local function play_squeeze(role)
    local role_id = get_role_id(role)
    if not role_id or not nodes.character_image or not nodes.character_image_small then
        return
    end

    squeeze_generations_by_role_id[role_id] = (squeeze_generations_by_role_id[role_id] or 0) + 1
    local animation_generation = squeeze_generations_by_role_id[role_id]
    local current_lifecycle_generation = lifecycle_generation

    role.set_node_visible(nodes.character_image, false)
    role.set_node_visible(nodes.character_image_small, true)
    LuaAPI.call_delay_frame(configuration.squeeze.delay_frames, function()
        if lifecycle_generation ~= current_lifecycle_generation then
            return
        end
        if squeeze_generations_by_role_id[role_id] ~= animation_generation then
            return
        end

        role.set_node_visible(nodes.character_image_small, false)
        role.set_image_color(nodes.character_image, configuration.squeeze.flash_color, math.tofixed(0))
        role.set_node_visible(nodes.character_image, true)
        role.set_image_color(
            nodes.character_image,
            configuration.squeeze.rest_color,
            math.tofixed(configuration.squeeze.rest_transition)
        )
    end)
end

---绑定编辑器内的角色节点，并一次性创建皮肤特效节点。
---@param canvas ENode
function CharacterView.initialize(canvas)
    lifecycle_generation = lifecycle_generation + 1
    squeeze_generations_by_role_id = {}
    applied_tier_by_role_id = {}
    active_burst_by_role_id = {}
    effect_nodes = {}
    nodes = {
        full_background       = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.full_background),
        right_background      = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.right_background),
        burst                 = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.burst),
        animation_ring        = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.animation_ring),
        character_image       = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.character_image),
        character_image_small = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.character_image_small),
        click_button          = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.click_button),
    }

    local to_fixed = math.tofixed
    local area = configuration.effect_area
    for tier_index, skin in ipairs(configuration.skins or {}) do
        if skin.effect_style and area then
            effect_nodes[tier_index] = GameAPI.create_eui_effect_at_position(
                skin.effect_style,
                canvas,
                to_fixed(area.x),
                to_fixed(area.y),
                to_fixed(area.w),
                to_fixed(area.h),
                configuration.effect_loop and true or false,
                "char_skin_fx_" .. tier_index
            )
        end
    end
end

---初始化玩家自己的表现状态，皮肤应用前先隐藏特效。
---@param role Role
function CharacterView.initialize_role(role)
    if not role then
        return
    end
    if nodes.character_image_small then
        role.set_node_visible(nodes.character_image_small, false)
    end
    for _, effect_node in pairs(effect_nodes) do
        role.stop_ui_effect(effect_node)
        role.set_node_visible(effect_node, false)
    end
    -- 默认播放编辑器内的圆环；update_skin 会再切到当前皮肤效果。
    if nodes.animation_ring then
        role.play_ui_effect(nodes.animation_ring)
    end
end

---解析并应用玩家当前已解锁的最高皮肤。
---@param role Role
---@param total_brainrot number
---@return boolean changed
function CharacterView.update_skin(role, total_brainrot)
    local role_id = get_role_id(role)
    if not role_id then
        return false
    end

    local skins = configuration.skins
    if not skins or #skins == 0 then
        return false
    end

    local tier_index = SkinSystem.resolve_tier_index(skins, total_brainrot or 0)
    if applied_tier_by_role_id[role_id] == tier_index then
        return false
    end
    applied_tier_by_role_id[role_id] = tier_index

    local skin = skins[tier_index]

    if nodes.character_image and skin.image then
        role.set_image_texture_by_key_with_auto_resize(nodes.character_image, skin.image, configuration.reset_image_size)
    end
    -- 小图 image_small 留空时沿用 image；两者都为 nil 时保持编辑器原贴图，不调用 API。
    local small_image = skin.image_small or skin.image
    if nodes.character_image_small and small_image then
        role.set_image_texture_by_key_with_auto_resize(
            nodes.character_image_small,
            small_image,
            configuration.reset_image_size
        )
    end

    for index, effect_node in pairs(effect_nodes) do
        if index == tier_index then
            role.set_node_visible(effect_node, true)
            role.play_ui_effect(effect_node)
        else
            role.stop_ui_effect(effect_node)
            role.set_node_visible(effect_node, false)
        end
    end

    --[[
    编辑器内圆环是没有 effect_style 时的兜底效果；
    配了皮肤特效时，由皮肤特效替代它。
    ]]
    if nodes.animation_ring then
        if effect_nodes[tier_index] then
            role.stop_ui_effect(nodes.animation_ring)
            role.set_node_visible(nodes.animation_ring, false)
        else
            role.set_node_visible(nodes.animation_ring, true)
            role.play_ui_effect(nodes.animation_ring)
        end
    end

    active_burst_by_role_id[role_id] = skin.burst or configuration.burst
    return true
end

---取飘字颜色，跟当前皮肤的 burst 常态颜色保持一致。
---@param role Role
---@return integer color
function CharacterView.get_active_float_color(role)
    local role_id = get_role_id(role)
    local burst = (role_id and active_burst_by_role_id[role_id]) or configuration.burst
    return to_opaque(burst.rest_color)
end

---通过主控制器传入的注册函数绑定点击事件。
---@param on_click fun(role: Role)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function CharacterView.bind_click_handler(on_click, register_trigger)
    if not nodes.click_button then
        return
    end

    register_trigger(
        { EVENT.EUI_NODE_TOUCH_EVENT, nodes.click_button, AppConfig.TOUCH.CLICK },
        function(event_name, actor, data)
            local role = data and data.role
            if role then
                on_click(role)
            end
        end
    )
end

---播放一次成功点击反馈。
---@param role Role
function CharacterView.play_click_feedback(role)
    play_burst(role)
    play_squeeze(role)
end

---玩家离开时清理对应的皮肤状态。
---@param role Role
function CharacterView.cleanup_role(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end
    squeeze_generations_by_role_id[role_id] = nil
    applied_tier_by_role_id[role_id] = nil
    active_burst_by_role_id[role_id] = nil
end

---关闭玩法时让延迟回调失效。
function CharacterView.shutdown()
    lifecycle_generation = lifecycle_generation + 1
    squeeze_generations_by_role_id = {}
    applied_tier_by_role_id = {}
    active_burst_by_role_id = {}
end

return CharacterView
