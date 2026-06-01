-- ============================================================
-- UI/CharacterView.lua
-- Bind the click target and play character-only visual feedback.
-- ============================================================

local CharacterView = {}
local UIConfig = require("Data.UIConfig")
local configuration = UIConfig.CHARACTER
local nodes = {}
local squeeze_generations_by_role_id = {}
local lifecycle_generation = 0

---@param role Role
---@return RoleID|nil role_id
local function get_role_id(role)
    local control_unit = role and role.get_ctrl_unit()
    return control_unit and control_unit.get_role_id() or nil
end

---@param role Role
local function play_burst(role)
    if not role or not nodes.burst then
        return
    end

    role.set_image_color(nodes.burst, configuration.burst.flash_color, math.tofixed(0))
    role.set_image_color(
        nodes.burst,
        configuration.burst.rest_color,
        math.tofixed(configuration.burst.rest_transition)
    )
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

---Bind the editor-authored character nodes once.
---@param canvas ECanvas
function CharacterView.initialize(canvas)
    lifecycle_generation = lifecycle_generation + 1
    squeeze_generations_by_role_id = {}
    nodes = {
        full_background       = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.full_background),
        right_background      = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.right_background),
        burst                 = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.burst),
        animation_ring        = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.animation_ring),
        character_image       = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.character_image),
        character_image_small = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.character_image_small),
        click_button          = GameAPI.get_eui_child_by_name(canvas, configuration.nodes.click_button),
    }
end

---Initialize role-local visual state.
---@param role Role
function CharacterView.initialize_role(role)
    if not role then
        return
    end
    if nodes.animation_ring then
        role.play_ui_effect(nodes.animation_ring)
    end
    if nodes.character_image_small then
        role.set_node_visible(nodes.character_image_small, false)
    end
end

---Bind click interaction through the controller-owned registrar.
---@param on_click fun(role: Role)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function CharacterView.bind_click_handler(on_click, register_trigger)
    if not nodes.click_button then
        return
    end

    register_trigger(
        { EVENT.EUI_NODE_TOUCH_EVENT, nodes.click_button, UIConfig.TOUCH.CLICK },
        function(event_name, actor, data)
            local role = data and data.role
            if role then
                on_click(role)
            end
        end
    )
end

---Play feedback for a successful click.
---@param role Role
function CharacterView.play_click_feedback(role)
    play_burst(role)
    play_squeeze(role)
end

---Invalidate delayed callbacks during game shutdown.
function CharacterView.shutdown()
    lifecycle_generation = lifecycle_generation + 1
    squeeze_generations_by_role_id = {}
end

return CharacterView
