-- ============================================================
-- UI/FloatText.lua
-- Role-isolated rising animation for click-income labels.
--
-- Each role owns one moving label per channel. Vertical motion is
-- driven at runtime by GameAPI.set_eui_node_bottom_auto_adaption,
-- while font size and opacity are animated through per-role render
-- overrides. Because position is a global node property, every role
-- keeps a private node set so other clients never see the movement.
-- ============================================================

local FloatText = {}
local UIConfig = require("Data.UIConfig")
local configuration = UIConfig.FLOAT_TEXT
local canvas = nil
local nodes_by_role_id = {}
local animation_generations_by_role_id = {}
local lifecycle_generation = 0

---@param role Role
---@return RoleID|nil role_id
local function get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

---@param frame_index integer
---@return number progress
local function get_progress(frame_index)
    if configuration.frame_steps <= 1 then
        return 0
    end
    return (frame_index - 1) / (configuration.frame_steps - 1)
end

---@param frame_index integer
---@return integer font_size
local function get_font_size(frame_index)
    local progress = get_progress(frame_index)
    return math.tointeger(
        math.floor(configuration.size_bottom + (configuration.size_top - configuration.size_bottom) * progress + 0.5)
    )
end

---@param frame_index integer
---@return number opacity
local function get_opacity(frame_index)
    local progress = get_progress(frame_index)
    if progress <= configuration.fade_start then
        return 1.0
    end

    local opacity = 1.0 - (progress - configuration.fade_start) / (1.0 - configuration.fade_start)
    return math.max(0.0, opacity)
end

---@param frame_index integer
---@return number bottom_offset
local function get_bottom_offset(frame_index)
    return configuration.base_y + get_progress(frame_index) * configuration.rise_dist
end

---@param channel_index integer
---@return number offset
local function get_channel_offset(channel_index)
    return (channel_index - (configuration.channel_count + 1) / 2) * configuration.channel_gap
end

---@param role_id RoleID
---@return table<integer, integer> animation_generations
local function get_animation_generations(role_id)
    animation_generations_by_role_id[role_id] = animation_generations_by_role_id[role_id] or {}
    return animation_generations_by_role_id[role_id]
end

---Capture the canvas; per-role nodes are created lazily in initialize_role.
---@param target_canvas ECanvas
function FloatText.initialize(target_canvas)
    lifecycle_generation = lifecycle_generation + 1
    animation_generations_by_role_id = {}
    nodes_by_role_id = {}
    canvas = target_canvas
end

---Create and style this role's private channel labels.
---@param role Role
function FloatText.initialize_role(role)
    local role_id = get_role_id(role)
    if not role_id or not canvas then
        return
    end

    local to_fixed = math.tofixed
    local channels = {}
    for channel_index = 1, configuration.channel_count do
        local horizontal_offset = get_channel_offset(channel_index)
        local label = GameAPI.create_eui_label_at_position(
            configuration.label_style,
            canvas,
            to_fixed(configuration.base_x + horizontal_offset),
            to_fixed(configuration.base_y),
            to_fixed(configuration.width),
            to_fixed(configuration.height),
            configuration.name_prefix .. role_id .. "_" .. channel_index,
            "+0"
        )
        role.set_node_visible(label, false)
        role.set_label_color(label, configuration.color, to_fixed(0))
        role.set_label_font_size(label, get_font_size(1), to_fixed(0))
        role.set_label_outline_enabled(label, true)
        role.set_label_outline_color(label, configuration.outline_color)
        role.set_label_outline_width(label, to_fixed(configuration.outline_width))
        channels[channel_index] = label
    end

    nodes_by_role_id[role_id] = channels
end

---Recolor a role's float labels (outline is left unchanged).
---@param role Role
---@param color integer
function FloatText.set_color(role, color)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    local channels = nodes_by_role_id[role_id]
    if not channels then
        return
    end

    local to_fixed = math.tofixed
    for _, label in pairs(channels) do
        role.set_label_color(label, color, to_fixed(0))
    end
end

---Play one floating income label for a role.
---@param role Role
---@param amount number
function FloatText.show(role, amount)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    local channels = nodes_by_role_id[role_id]
    if not channels then
        return
    end

    local channel_index = GameAPI.random_int(1, configuration.channel_count)
    local label = channels[channel_index]
    if not label then
        return
    end

    local role_animation_generations = get_animation_generations(role_id)
    role_animation_generations[channel_index] = (role_animation_generations[channel_index] or 0) + 1
    local animation_generation = role_animation_generations[channel_index]
    local current_lifecycle_generation = lifecycle_generation
    local text = "+" .. tostring(math.tointeger(amount))
    local to_fixed = math.tofixed

    local function show_frame(frame_index)
        if lifecycle_generation ~= current_lifecycle_generation then
            return
        end
        if get_animation_generations(role_id)[channel_index] ~= animation_generation then
            return
        end
        if frame_index > configuration.frame_steps then
            role.set_node_visible(label, false)
            return
        end

        GameAPI.set_eui_node_bottom_auto_adaption(label, true, false, to_fixed(get_bottom_offset(frame_index)))
        role.set_label_text(label, text)
        role.set_label_font_size(label, get_font_size(frame_index), to_fixed(0))
        role.set_ui_opacity(label, to_fixed(get_opacity(frame_index)))
        role.set_node_visible(label, true)
        LuaAPI.call_delay_frame(configuration.step_frames, function()
            show_frame(frame_index + 1)
        end)
    end

    show_frame(1)
end

---Hide and drop one role's nodes when they leave the game.
---@param role Role
function FloatText.cleanup_role(role)
    local role_id = get_role_id(role)
    if not role_id then
        return
    end

    local channels = nodes_by_role_id[role_id]
    if channels then
        for _, label in pairs(channels) do
            role.set_node_visible(label, false)
        end
    end
    nodes_by_role_id[role_id] = nil
    animation_generations_by_role_id[role_id] = nil
end

---Invalidate delayed callbacks during game shutdown.
function FloatText.shutdown()
    lifecycle_generation = lifecycle_generation + 1
    animation_generations_by_role_id = {}
    nodes_by_role_id = {}
end

return FloatText
