--[[
Combo/ComboBar.lua

连击条表现层：渲染连击进度，并按玩家隔离倍率弹跳动画。
]]

local ComboBar = {}
local ComboConfig = require("Combo.ComboConfig")
local configuration = ComboConfig.BAR
local nodes = {}
local animation_generations_by_role_id = {}
local lifecycle_generation = 0

---@param node any
---@return boolean valid
local function is_node(node)
    return node ~= nil and node ~= false and node ~= 0 and node ~= ""
end

---@param role Role
---@return RoleID|nil role_id
local function get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

---@param parent ENode
---@param name string
---@return ENode|nil node
local function fetch_child(parent, name)
    local node = GameAPI.get_eui_child_by_name(parent, name)
    if not is_node(node) then
        LuaAPI.log("[ComboBar] 缺少静态节点: " .. name, 1)
        return nil
    end
    return node
end

---@param role Role
local function play_pop_animation(role)
    local role_id = get_role_id(role)
    if not role_id or not nodes.label then
        return
    end

    animation_generations_by_role_id[role_id] = (animation_generations_by_role_id[role_id] or 0) + 1
    local animation_generation = animation_generations_by_role_id[role_id]
    local current_lifecycle_generation = lifecycle_generation
    local to_fixed = math.tofixed

    role.set_label_shadow_x_offset(nodes.label, to_fixed(configuration.shadow_reset_x))
    role.set_label_font_size(nodes.label, configuration.pop_start_size, to_fixed(0))

    LuaAPI.call_delay_frame(configuration.pop_start_delay_frames, function()
        if lifecycle_generation ~= current_lifecycle_generation then
            return
        end
        if animation_generations_by_role_id[role_id] ~= animation_generation then
            return
        end

        role.set_label_font_size(
            nodes.label,
            configuration.pop_peak_size,
            to_fixed(configuration.pop_grow_duration)
        )

        local shadow_sweep_index = 0
        local function sweep_shadow()
            if lifecycle_generation ~= current_lifecycle_generation then
                return
            end
            if animation_generations_by_role_id[role_id] ~= animation_generation then
                return
            end

            shadow_sweep_index = shadow_sweep_index + 1
            if shadow_sweep_index > #configuration.shadow_sweep then
                return
            end

            role.set_label_shadow_x_offset(
                nodes.label,
                to_fixed(configuration.shadow_sweep[shadow_sweep_index])
            )
            LuaAPI.call_delay_frame(configuration.shadow_sweep_frames, sweep_shadow)
        end
        sweep_shadow()

        LuaAPI.call_delay_frame(configuration.pop_settle_delay_frames, function()
            if lifecycle_generation ~= current_lifecycle_generation then
                return
            end
            if animation_generations_by_role_id[role_id] ~= animation_generation then
                return
            end

            role.set_label_font_size(
                nodes.label,
                configuration.settle_size,
                to_fixed(configuration.pop_settle_duration)
            )
        end)
    end)
end

---绑定编辑器内已搭好的连击节点。
---@param canvas ENode
function ComboBar.initialize(canvas)
    lifecycle_generation = lifecycle_generation + 1
    animation_generations_by_role_id = {}
    nodes.bar = fetch_child(canvas, configuration.nodes.bar)
    nodes.label = fetch_child(nodes.bar or canvas, configuration.nodes.label)
end

---初始化单个玩家看到的连击表现。
---@param role Role
function ComboBar.initialize_role(role)
    if not role or not nodes.bar then
        return
    end

    role.set_progressbar_min(nodes.bar, 0)
    role.set_progressbar_max(nodes.bar, ComboConfig.MAX)
    role.set_progressbar_current(nodes.bar, 0)
    if nodes.label then
        role.set_node_visible(nodes.label, false)
    end
end

---渲染当前连击能量。
---@param role Role
---@param state PlayerGameState
function ComboBar.render_progress(role, state)
    if not role or not nodes.bar then
        return
    end

    local current_value = math.tointeger(math.min(state.combo.count, ComboConfig.MAX))
    role.set_progressbar_transition(nodes.bar, current_value, math.tofixed(configuration.progress_transition))
end

---渲染倍率档位变化并播放反馈。
---@param role Role
---@param old_tier integer
---@param new_tier integer
function ComboBar.handle_tier_change(role, old_tier, new_tier)
    if not role or not nodes.label then
        return
    end

    if new_tier == 0 then
        local role_id = get_role_id(role)
        if role_id then
            animation_generations_by_role_id[role_id] = (animation_generations_by_role_id[role_id] or 0) + 1
        end
        role.set_node_visible(nodes.label, false)
        role.set_label_shadow_x_offset(nodes.label, math.tofixed(configuration.shadow_reset_x))
        role.set_label_shadow_y_offset(nodes.label, math.tofixed(configuration.shadow_reset_y))
        return
    end

    role.set_label_text(nodes.label, configuration.tier_texts[new_tier])
    role.set_label_color(nodes.label, configuration.tier_colors[new_tier], math.tofixed(0))
    role.set_node_visible(nodes.label, true)
    play_pop_animation(role)
end

---同一倍率档内再次点击时重播反馈。
---@param role Role
function ComboBar.pop(role)
    play_pop_animation(role)
end

---关闭玩法时让延迟回调失效。
function ComboBar.shutdown()
    lifecycle_generation = lifecycle_generation + 1
    animation_generations_by_role_id = {}
end

return ComboBar
