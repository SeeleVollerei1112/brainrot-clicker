-- ============================================================
-- UI/FloatText.lua
-- Role-isolated waypoint animation for click-income labels.
--
-- Runtime EUI cannot move nodes, so each column is a sequence of
-- editor-independent labels shown one waypoint at a time.
-- ============================================================

local FloatText = {}
local UIConfig = require("Data.UIConfig")
local configuration = UIConfig.FLOAT_TEXT
local columns = {}
local animation_generations_by_role_id = {}
local lifecycle_generation = 0

---@param role Role
---@return RoleID|nil role_id
local function get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

---@param waypoint_index integer
---@return number progress
local function get_progress(waypoint_index)
    if configuration.waypoint_count <= 1 then
        return 0
    end
    return (waypoint_index - 1) / (configuration.waypoint_count - 1)
end

---@param waypoint_index integer
---@return integer font_size
local function get_font_size(waypoint_index)
    local progress = get_progress(waypoint_index)
    return math.tointeger(
        math.floor(configuration.size_bottom + (configuration.size_top - configuration.size_bottom) * progress + 0.5)
    )
end

---@param waypoint_index integer
---@return number opacity
local function get_opacity(waypoint_index)
    local progress = get_progress(waypoint_index)
    if progress <= configuration.fade_start then
        return 1.0
    end

    local opacity = 1.0 - (progress - configuration.fade_start) / (1.0 - configuration.fade_start)
    return math.max(0.0, opacity)
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

---Create all waypoint labels once during game initialization.
---@param canvas ECanvas
function FloatText.initialize(canvas)
    lifecycle_generation = lifecycle_generation + 1
    animation_generations_by_role_id = {}
    columns = {}

    local to_fixed = math.tofixed
    for channel_index = 1, configuration.channel_count do
        columns[channel_index] = {}
        local horizontal_offset = get_channel_offset(channel_index)
        for waypoint_index = 1, configuration.waypoint_count do
            columns[channel_index][waypoint_index] = GameAPI.create_eui_label_at_position(
                configuration.label_style,
                canvas,
                to_fixed(configuration.base_x + horizontal_offset),
                to_fixed(configuration.base_y + get_progress(waypoint_index) * configuration.rise_dist),
                to_fixed(configuration.width),
                to_fixed(configuration.height),
                configuration.name_prefix .. channel_index .. "_" .. waypoint_index,
                "+0"
            )
        end
    end
end

---Initialize role-local styling and visibility.
---@param role Role
function FloatText.initialize_role(role)
    if not role then
        return
    end

    local to_fixed = math.tofixed
    for channel_index = 1, configuration.channel_count do
        for waypoint_index = 1, configuration.waypoint_count do
            local label = columns[channel_index][waypoint_index]
            if label then
                role.set_node_visible(label, false)
                role.set_label_color(label, configuration.color, to_fixed(0))
                role.set_label_font_size(label, get_font_size(waypoint_index), to_fixed(0))
                role.set_label_outline_enabled(label, true)
                role.set_label_outline_color(label, configuration.outline_color)
                role.set_label_outline_width(label, to_fixed(configuration.outline_width))
            end
        end
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

    local channel_index = GameAPI.random_int(1, configuration.channel_count)
    local column = columns[channel_index]
    if not column then
        return
    end

    local role_animation_generations = get_animation_generations(role_id)
    role_animation_generations[channel_index] = (role_animation_generations[channel_index] or 0) + 1
    local animation_generation = role_animation_generations[channel_index]
    local current_lifecycle_generation = lifecycle_generation
    local text = "+" .. tostring(math.tointeger(amount))
    local to_fixed = math.tofixed

    for waypoint_index = 1, configuration.waypoint_count do
        role.set_node_visible(column[waypoint_index], false)
    end

    local function show_waypoint(waypoint_index)
        if lifecycle_generation ~= current_lifecycle_generation then
            return
        end
        if get_animation_generations(role_id)[channel_index] ~= animation_generation then
            return
        end
        if waypoint_index > 1 then
            role.set_node_visible(column[waypoint_index - 1], false)
        end
        if waypoint_index > configuration.waypoint_count then
            return
        end

        local label = column[waypoint_index]
        role.set_label_text(label, text)
        role.set_ui_opacity(label, to_fixed(get_opacity(waypoint_index)))
        role.set_node_visible(label, true)
        LuaAPI.call_delay_frame(configuration.step_frames, function()
            show_waypoint(waypoint_index + 1)
        end)
    end

    show_waypoint(1)
end

---Invalidate delayed callbacks during game shutdown.
function FloatText.shutdown()
    lifecycle_generation = lifecycle_generation + 1
    animation_generations_by_role_id = {}
end

return FloatText
