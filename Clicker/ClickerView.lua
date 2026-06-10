--[[
Clicker/ClickerView.lua

点击玩法的「点击展示」表现层：角色点击反馈 + 收益飘字 + HUD 数值 + 连击条。
合并自原 CharacterView / FloatTextView / HeadsUpDisplay / ComboBar——它们都是「点击时
玩家看到的反馈」、且彼此联动（飘字颜色跟随皮肤、连击/HUD 随点击一起刷），拆成四个
文件反而割裂。本文件按 角色/飘字/HUD/连击 分段，段内状态各自命名空间，生命周期入口
（initialize / initialize_role / cleanup_role / shutdown）统一编排。
纯状态与逻辑在 ClickerState，编排在 ClickerController。
]]

local AppConfig = require("App.AppConfig")
local ClickerConfig = require("Clicker.ClickerConfig")
local ClickerState = require("Clicker.ClickerState")

local ClickerView = {}

-- 延迟回调的世代号：每次 initialize / shutdown 自增，过期回调据此失效（四段共用一个）。
local lifecycle_generation = 0

-- ---------- 共享小工具 ----------

local get_role_id = require("Util.RoleUtil").get_role_id

---@param parent ENode
---@param name string
---@return ENode|nil node
local function fetch_child(parent, name)
    local node = GameAPI.get_eui_child_by_name(parent, name)
    if not node then
        LuaAPI.log("[ClickerView] 缺少静态节点: " .. name, 1)
        return nil
    end
    return node
end

-- ============================================================
-- 角色点击表现（原 CharacterView）
-- ============================================================

local character_cfg = ClickerConfig.CHARACTER
local character_nodes = {}
local effect_nodes = {}
local squeeze_generations_by_role_id = {}
local applied_tier_by_role_id = {}
local active_burst_by_role_id = {}

---把 AARRGGBB 颜色强制转成不透明，保留 RGB。
---@param color integer
---@return integer opaque_color
local function to_opaque(color)
    return 0xFF000000 + (color % 0x1000000)
end

---@param role Role
local function play_burst(role)
    if not role or not character_nodes.burst then
        return
    end

    local role_id = get_role_id(role)
    local burst = (role_id and active_burst_by_role_id[role_id]) or character_cfg.burst

    role.set_image_color(character_nodes.burst, burst.flash_color, math.tofixed(0))
    role.set_image_color(character_nodes.burst, burst.rest_color, math.tofixed(burst.rest_transition))
end

---@param role Role
local function play_squeeze(role)
    local role_id = get_role_id(role)
    if not role_id or not character_nodes.character_image or not character_nodes.character_image_small then
        return
    end

    squeeze_generations_by_role_id[role_id] = (squeeze_generations_by_role_id[role_id] or 0) + 1
    local animation_generation = squeeze_generations_by_role_id[role_id]
    local current_lifecycle_generation = lifecycle_generation

    role.set_node_visible(character_nodes.character_image, false)
    role.set_node_visible(character_nodes.character_image_small, true)
    LuaAPI.call_delay_frame(character_cfg.squeeze.delay_frames, function()
        if lifecycle_generation ~= current_lifecycle_generation then
            return
        end
        if squeeze_generations_by_role_id[role_id] ~= animation_generation then
            return
        end

        role.set_node_visible(character_nodes.character_image_small, false)
        role.set_image_color(character_nodes.character_image, character_cfg.squeeze.flash_color, math.tofixed(0))
        role.set_node_visible(character_nodes.character_image, true)
        role.set_image_color(
            character_nodes.character_image,
            character_cfg.squeeze.rest_color,
            math.tofixed(character_cfg.squeeze.rest_transition)
        )
    end)
end

---@param role Role
local function play_click_animation_event(role)
    if not role then
        return
    end

    local events = character_cfg.animation_events
    if not events then
        return
    end

    if events.reset then
        role.send_ui_custom_event(events.reset, {})
    end

    if events.start then
        local delay_frames = character_cfg.click_animation_start_delay_frames or 0
        if delay_frames > 0 then
            LuaAPI.call_delay_frame(delay_frames, function()
                role.send_ui_custom_event(events.start, {})
            end)
        else
            role.send_ui_custom_event(events.start, {})
        end
    end
end

---绑定编辑器内的角色节点，并一次性创建皮肤特效节点。
---@param canvas ENode
local function character_initialize(canvas)
    squeeze_generations_by_role_id = {}
    applied_tier_by_role_id = {}
    active_burst_by_role_id = {}
    effect_nodes = {}
    character_nodes = {
        full_background       = GameAPI.get_eui_child_by_name(canvas, character_cfg.nodes.full_background),
        right_background      = GameAPI.get_eui_child_by_name(canvas, character_cfg.nodes.right_background),
        burst                 = GameAPI.get_eui_child_by_name(canvas, character_cfg.nodes.burst),
        animation_ring        = GameAPI.get_eui_child_by_name(canvas, character_cfg.nodes.animation_ring),
        character_image       = GameAPI.get_eui_child_by_name(canvas, character_cfg.nodes.character_image),
        character_image_small = GameAPI.get_eui_child_by_name(canvas, character_cfg.nodes.character_image_small),
        click_button          = GameAPI.get_eui_child_by_name(canvas, character_cfg.nodes.click_button),
    }

    local to_fixed = math.tofixed
    local area = character_cfg.effect_area
    for tier_index, skin in ipairs(character_cfg.skins or {}) do
        if skin.effect_style and area then
            effect_nodes[tier_index] = GameAPI.create_eui_effect_at_position(
                skin.effect_style,
                canvas,
                to_fixed(area.x),
                to_fixed(area.y),
                to_fixed(area.w),
                to_fixed(area.h),
                character_cfg.effect_loop and true or false,
                "char_skin_fx_" .. tier_index
            )
        end
    end
end

---初始化玩家自己的表现状态，皮肤应用前先隐藏特效。
---@param role Role
local function character_initialize_role(role)
    if not role then
        return
    end
    if character_nodes.character_image_small then
        role.set_node_visible(character_nodes.character_image_small, false)
    end
    for _, effect_node in pairs(effect_nodes) do
        role.stop_ui_effect(effect_node)
        role.set_node_visible(effect_node, false)
    end
    -- 默认播放编辑器内的圆环；update_skin 会再切到当前皮肤效果。
    if character_nodes.animation_ring then
        role.play_ui_effect(character_nodes.animation_ring)
    end
end

---解析并应用玩家当前已解锁的最高皮肤。
---@param role Role
---@param total_brainrot number
---@return boolean changed
function ClickerView.update_skin(role, total_brainrot)
    local role_id = get_role_id(role)
    if not role_id then
        return false
    end

    local skins = character_cfg.skins
    if not skins or #skins == 0 then
        return false
    end

    local tier_index = ClickerState.resolve_tier_index(skins, total_brainrot or 0)
    if applied_tier_by_role_id[role_id] == tier_index then
        return false
    end
    applied_tier_by_role_id[role_id] = tier_index

    local skin = skins[tier_index]

    if character_nodes.character_image and skin.image then
        role.set_image_texture_by_key_with_auto_resize(character_nodes.character_image, skin.image, character_cfg.reset_image_size)
    end
    -- 小图 image_small 留空时沿用 image；两者都为 nil 时保持编辑器原贴图，不调用 API。
    local small_image = skin.image_small or skin.image
    if character_nodes.character_image_small and small_image then
        role.set_image_texture_by_key_with_auto_resize(
            character_nodes.character_image_small,
            small_image,
            character_cfg.reset_image_size
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
    if character_nodes.animation_ring then
        if effect_nodes[tier_index] then
            role.stop_ui_effect(character_nodes.animation_ring)
            role.set_node_visible(character_nodes.animation_ring, false)
        else
            role.set_node_visible(character_nodes.animation_ring, true)
            role.play_ui_effect(character_nodes.animation_ring)
        end
    end

    active_burst_by_role_id[role_id] = skin.burst or character_cfg.burst
    return true
end

---取飘字颜色，跟当前皮肤的 burst 常态颜色保持一致。
---@param role Role
---@return integer color
function ClickerView.get_active_float_color(role)
    local role_id = get_role_id(role)
    local burst = (role_id and active_burst_by_role_id[role_id]) or character_cfg.burst
    return to_opaque(burst.rest_color)
end

---通过主控制器传入的注册函数绑定点击事件。
---@param on_click fun(role: Role)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function ClickerView.bind_click_handler(on_click, register_trigger)
    if not character_nodes.click_button then
        return
    end

    register_trigger(
        { EVENT.EUI_NODE_TOUCH_EVENT, character_nodes.click_button, AppConfig.TOUCH.CLICK },
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
function ClickerView.play_click_feedback(role)
    play_burst(role)
    play_click_animation_event(role)
    if character_cfg.use_legacy_squeeze then
        play_squeeze(role)
    end
end

---玩家离开时清理对应的皮肤状态。
---@param role Role
local function character_cleanup_role(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end
    squeeze_generations_by_role_id[role_id] = nil
    applied_tier_by_role_id[role_id] = nil
    active_burst_by_role_id[role_id] = nil
end

-- ============================================================
-- 收益飘字（原 FloatTextView）
-- ============================================================

local float_cfg = ClickerConfig.FLOAT_TEXT
local float_canvas = nil
local float_nodes_by_role_id = {}
local float_anim_generations_by_role_id = {}

---@param frame_index integer
---@return number progress
local function float_get_progress(frame_index)
    if float_cfg.frame_steps <= 1 then
        return 0
    end
    return (frame_index - 1) / (float_cfg.frame_steps - 1)
end

---@param frame_index integer
---@return integer? font_size
local function float_get_font_size(frame_index)
    local progress = float_get_progress(frame_index)
    return math.tointeger(
        math.floor(float_cfg.size_bottom + (float_cfg.size_top - float_cfg.size_bottom) * progress + 0.5)
    )
end

---@param frame_index integer
---@return number opacity
local function float_get_opacity(frame_index)
    local progress = float_get_progress(frame_index)
    if progress <= float_cfg.fade_start then
        return 1.0
    end

    local opacity = 1.0 - (progress - float_cfg.fade_start) / (1.0 - float_cfg.fade_start)
    return math.max(0.0, opacity)
end

---@param frame_index integer
---@return number bottom_offset
local function float_get_bottom_offset(frame_index)
    return float_cfg.base_y + float_get_progress(frame_index) * float_cfg.rise_dist
end

---@param channel_index integer
---@return number offset
local function float_get_channel_offset(channel_index)
    return (channel_index - (float_cfg.channel_count + 1) / 2) * float_cfg.channel_gap
end

---@param role_id RoleID
---@return table<integer, integer> animation_generations
local function float_get_animation_generations(role_id)
    float_anim_generations_by_role_id[role_id] = float_anim_generations_by_role_id[role_id] or {}
    return float_anim_generations_by_role_id[role_id]
end

---创建并设置当前玩家自己的飘字通道节点。
---@param role Role
local function float_initialize_role(role)
    local role_id = get_role_id(role)
    if not role_id or not float_canvas then
        return
    end

    local to_fixed = math.tofixed
    local channels = {}
    for channel_index = 1, float_cfg.channel_count do
        local horizontal_offset = float_get_channel_offset(channel_index)
        local label = GameAPI.create_eui_label_at_position(
            float_cfg.label_style,
            float_canvas,
            to_fixed(float_cfg.base_x + horizontal_offset),
            to_fixed(float_cfg.base_y),
            to_fixed(float_cfg.width),
            to_fixed(float_cfg.height),
            float_cfg.name_prefix .. role_id .. "_" .. channel_index,
            "+0"
        )
        role.set_node_visible(label, false)
        role.set_label_color(label, float_cfg.color, to_fixed(0))
        role.set_label_font_size(label, float_get_font_size(1), to_fixed(0))
        role.set_label_outline_enabled(label, true)
        role.set_label_outline_color(label, float_cfg.outline_color)
        role.set_label_outline_width(label, to_fixed(float_cfg.outline_width))
        channels[channel_index] = label
    end

    float_nodes_by_role_id[role_id] = channels
end

---修改玩家飘字颜色，描边保持不变。
---@param role Role
---@param color integer
function ClickerView.set_color(role, color)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    local channels = float_nodes_by_role_id[role_id]
    if not channels then
        return
    end

    local to_fixed = math.tofixed
    for _, label in pairs(channels) do
        role.set_label_color(label, color, to_fixed(0))
    end
end

---播放一次收益飘字。
---@param role Role
---@param amount number
function ClickerView.show(role, amount)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    local channels = float_nodes_by_role_id[role_id]
    if not channels then
        return
    end

    local channel_index = GameAPI.random_int(1, float_cfg.channel_count)
    local label = channels[channel_index]
    if not label then
        return
    end

    local role_animation_generations = float_get_animation_generations(role_id)
    role_animation_generations[channel_index] = (role_animation_generations[channel_index] or 0) + 1
    local animation_generation = role_animation_generations[channel_index]
    local current_lifecycle_generation = lifecycle_generation
    local text = "+" .. tostring(math.tointeger(amount))
    local to_fixed = math.tofixed

    local function show_frame(frame_index)
        if lifecycle_generation ~= current_lifecycle_generation then
            return
        end
        if float_get_animation_generations(role_id)[channel_index] ~= animation_generation then
            return
        end
        if frame_index > float_cfg.frame_steps then
            role.set_node_visible(label, false)
            return
        end

        GameAPI.set_eui_node_bottom_auto_adaption(label, true, false, to_fixed(float_get_bottom_offset(frame_index)))
        role.set_label_text(label, text)
        role.set_label_font_size(label, float_get_font_size(frame_index), to_fixed(0))
        role.set_ui_opacity(label, to_fixed(float_get_opacity(frame_index)))
        role.set_node_visible(label, true)
        LuaAPI.call_delay_frame(float_cfg.step_frames, function()
            show_frame(frame_index + 1)
        end)
    end

    show_frame(1)
end

---玩家离开时隐藏并移除他的飘字节点。
---@param role Role
local function float_cleanup_role(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    local channels = float_nodes_by_role_id[role_id]
    if channels then
        for _, label in pairs(channels) do
            role.set_node_visible(label, false)
        end
    end
    float_nodes_by_role_id[role_id] = nil
    float_anim_generations_by_role_id[role_id] = nil
end

-- ============================================================
-- HUD 数值（原 HeadsUpDisplay）
-- ============================================================

local hud_cfg = ClickerConfig.HUD
local hud_nodes = {}

---@param value number
---@return string formatted_value
local function hud_format_integer(value)
    return tostring(math.tointeger(value) or 0)
end

---游戏初始化时绑定编辑器内已搭好的 HUD 节点。
---@param canvas ENode
local function hud_initialize(canvas)
    hud_nodes.coin = fetch_child(canvas, hud_cfg.nodes.coin)
    hud_nodes.brainrot = fetch_child(canvas, hud_cfg.nodes.brainrot)
    hud_nodes.brainrot_per_second = fetch_child(canvas, hud_cfg.nodes.brainrot_per_second)
end

---渲染单个玩家的 HUD 数值。
---@param role Role
---@param state PlayerGameState
function ClickerView.render(role, state)
    if not role or not state then
        return
    end
    if not hud_nodes.brainrot or not hud_nodes.brainrot_per_second then
        return
    end

    role.set_label_text(hud_nodes.brainrot, hud_format_integer(state.currency.brainrot))
    role.set_label_text(
        hud_nodes.brainrot_per_second,
        hud_cfg.brainrot_per_second_prefix .. hud_format_integer(state.currency.brainrot_per_second)
    )
end

-- ============================================================
-- 连击条（原 ComboBar）
-- ============================================================

local combo_cfg = ClickerConfig.COMBO.BAR
local combo_max = ClickerConfig.COMBO.MAX
local combo_nodes = {}
local combo_anim_generations_by_role_id = {}

---@param role Role
local function play_pop_animation(role)
    local role_id = get_role_id(role)
    if not role_id or not combo_nodes.label then
        return
    end

    combo_anim_generations_by_role_id[role_id] = (combo_anim_generations_by_role_id[role_id] or 0) + 1
    local animation_generation = combo_anim_generations_by_role_id[role_id]
    local current_lifecycle_generation = lifecycle_generation
    local to_fixed = math.tofixed

    role.set_label_shadow_x_offset(combo_nodes.label, to_fixed(combo_cfg.shadow_reset_x))
    role.set_label_font_size(combo_nodes.label, combo_cfg.pop_start_size, to_fixed(0))

    LuaAPI.call_delay_frame(combo_cfg.pop_start_delay_frames, function()
        if lifecycle_generation ~= current_lifecycle_generation then
            return
        end
        if combo_anim_generations_by_role_id[role_id] ~= animation_generation then
            return
        end

        role.set_label_font_size(
            combo_nodes.label,
            combo_cfg.pop_peak_size,
            to_fixed(combo_cfg.pop_grow_duration)
        )

        local shadow_sweep_index = 0
        local function sweep_shadow()
            if lifecycle_generation ~= current_lifecycle_generation then
                return
            end
            if combo_anim_generations_by_role_id[role_id] ~= animation_generation then
                return
            end

            shadow_sweep_index = shadow_sweep_index + 1
            if shadow_sweep_index > #combo_cfg.shadow_sweep then
                return
            end

            role.set_label_shadow_x_offset(
                combo_nodes.label,
                to_fixed(combo_cfg.shadow_sweep[shadow_sweep_index])
            )
            LuaAPI.call_delay_frame(combo_cfg.shadow_sweep_frames, sweep_shadow)
        end
        sweep_shadow()

        LuaAPI.call_delay_frame(combo_cfg.pop_settle_delay_frames, function()
            if lifecycle_generation ~= current_lifecycle_generation then
                return
            end
            if combo_anim_generations_by_role_id[role_id] ~= animation_generation then
                return
            end

            role.set_label_font_size(
                combo_nodes.label,
                combo_cfg.settle_size,
                to_fixed(combo_cfg.pop_settle_duration)
            )
        end)
    end)
end

---绑定编辑器内已搭好的连击节点。
---@param canvas ENode
local function combo_initialize(canvas)
    combo_anim_generations_by_role_id = {}
    combo_nodes.bar = fetch_child(canvas, combo_cfg.nodes.bar)
    combo_nodes.label = fetch_child(combo_nodes.bar or canvas, combo_cfg.nodes.label)
end

---初始化单个玩家看到的连击表现。
---@param role Role
local function combo_initialize_role(role)
    if not role or not combo_nodes.bar then
        return
    end

    role.set_progressbar_min(combo_nodes.bar, 0)
    role.set_progressbar_max(combo_nodes.bar, combo_max)
    role.set_progressbar_current(combo_nodes.bar, 0)
    if combo_nodes.label then
        role.set_node_visible(combo_nodes.label, false)
    end
end

---渲染当前连击能量。
---@param role Role
---@param state PlayerGameState
function ClickerView.render_progress(role, state)
    if not role or not combo_nodes.bar then
        return
    end

    local current_value = math.tointeger(math.min(state.combo.count, combo_max))
    role.set_progressbar_transition(combo_nodes.bar, current_value, math.tofixed(combo_cfg.progress_transition))
end

---渲染倍率档位变化并播放反馈。
---@param role Role
---@param old_tier integer
---@param new_tier integer
function ClickerView.handle_tier_change(role, old_tier, new_tier)
    if not role or not combo_nodes.label then
        return
    end

    if new_tier == 0 then
        local role_id = get_role_id(role)
        if role_id then
            combo_anim_generations_by_role_id[role_id] = (combo_anim_generations_by_role_id[role_id] or 0) + 1
        end
        role.set_node_visible(combo_nodes.label, false)
        role.set_label_shadow_x_offset(combo_nodes.label, math.tofixed(combo_cfg.shadow_reset_x))
        role.set_label_shadow_y_offset(combo_nodes.label, math.tofixed(combo_cfg.shadow_reset_y))
        return
    end

    role.set_label_text(combo_nodes.label, combo_cfg.tier_texts[new_tier])
    role.set_label_color(combo_nodes.label, combo_cfg.tier_colors[new_tier], math.tofixed(0))
    role.set_node_visible(combo_nodes.label, true)
    play_pop_animation(role)
end

---同一倍率档内再次点击时重播反馈。
---@param role Role
function ClickerView.pop(role)
    play_pop_animation(role)
end

-- ============================================================
-- 统一生命周期入口
-- ============================================================

---绑定四段所需的画布节点，并创建皮肤特效。GAME_INIT 时由 ClickerController 调用。
---@param canvas ENode
function ClickerView.initialize(canvas)
    lifecycle_generation = lifecycle_generation + 1
    character_initialize(canvas)
    hud_initialize(canvas)
    float_canvas = canvas
    float_nodes_by_role_id = {}
    float_anim_generations_by_role_id = {}
    combo_initialize(canvas)
end

---玩家会话创建时初始化各段的角色级表现。
---@param role Role
function ClickerView.initialize_role(role)
    character_initialize_role(role)
    float_initialize_role(role)
    combo_initialize_role(role)
end

---玩家离开时清理各段的角色级状态。
---@param role Role
function ClickerView.cleanup_role(role)
    character_cleanup_role(role)
    float_cleanup_role(role)
end

---关闭玩法时让所有延迟回调失效并清理段内状态。
function ClickerView.shutdown()
    lifecycle_generation = lifecycle_generation + 1
    squeeze_generations_by_role_id = {}
    applied_tier_by_role_id = {}
    active_burst_by_role_id = {}
    float_anim_generations_by_role_id = {}
    float_nodes_by_role_id = {}
    combo_anim_generations_by_role_id = {}
end

return ClickerView
