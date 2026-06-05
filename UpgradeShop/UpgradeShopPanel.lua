--[[
UpgradeShop/UpgradeShopPanel.lua

升级商店表现层。
静态节点由编辑器搭好，业务层只传入展示数据，本文件负责绑定节点、渲染文本与触摸状态。
]]

local UpgradeShopPanel = {}
local UpgradeShopConfig = require("UpgradeShop.UpgradeShopConfig")
local AppConfig = require("App.AppConfig")
local configuration = UpgradeShopConfig.UI
local node_names = configuration.nodes
local colors = configuration.colors
local label_configuration = configuration.label
local opacity_configuration = configuration.opacity
local panel = nil
local listview = nil
local cards_by_item_id = {}
local static_slots = {}
local title_label = nil
local click_power_label = nil

---@param node any
---@return boolean valid
local function is_node(node)
    return node ~= nil and node ~= false and node ~= 0 and node ~= ""
end

---@param value number
---@return string formatted_value
local function format_integer(value)
    return tostring(math.tointeger(value) or 0)
end

---@param parent ENode
---@param name string
---@param required boolean
---@return ENode|nil node
local function fetch_child(parent, name, required)
    if not is_node(parent) then
        if required then
            LuaAPI.log("[UpgradeShopPanel] 缺少父节点，无法获取: " .. name, 1)
        end
        return nil
    end

    local node = GameAPI.get_eui_child_by_name(parent, name)
    if not is_node(node) then
        if required then
            LuaAPI.log("[UpgradeShopPanel] 缺少静态节点: " .. name, 1)
        end
        return nil
    end
    return node
end

---@param target_nodes ENode[]
---@param node ENode|nil
local function append_node(target_nodes, node)
    if is_node(node) then
        table.insert(target_nodes, node)
    end
end

---@param role Role
---@param card table
local function set_card_text_style(role, card)
    local to_fixed = math.tofixed
    role.set_label_color(card.name, colors.text_dark, to_fixed(0))
    role.set_label_color(card.description, colors.text_dark, to_fixed(0))
    role.set_label_color(card.price, colors.text_dark, to_fixed(0))
    role.set_label_color(card.level, colors.text_blue, to_fixed(0))
    role.set_label_font_size(card.name, label_configuration.name_size, to_fixed(0))
    role.set_label_font_size(card.description, label_configuration.desc_size, to_fixed(0))
    role.set_label_font_size(card.price, label_configuration.price_size, to_fixed(0))
    role.set_label_font_size(card.level, label_configuration.level_size, to_fixed(0))
    role.set_label_outline_enabled(card.name, false)
    role.set_label_outline_enabled(card.description, false)
    role.set_label_outline_enabled(card.price, false)
    role.set_label_outline_enabled(card.level, false)
    role.set_label_shadow_enabled(card.name, false)
    role.set_label_shadow_enabled(card.description, false)
    role.set_label_shadow_enabled(card.price, false)
    role.set_label_shadow_enabled(card.level, false)
end

---@param role Role
---@param card table
---@param color integer
local function set_card_background_color(role, card, color)
    role.set_image_color(card.background, color, math.tofixed(0))
end

---@param role Role
---@param card table
local function disable_card_child_touch(role, card)
    local child_nodes = {
        card.background,
        card.slot,
        card.icon,
        card.coin,
        card.name,
        card.description,
        card.price,
        card.level,
    }
    for _, node in ipairs(child_nodes) do
        if is_node(node) then
            role.set_node_touch_enabled(node, false)
        end
    end
end

---@param role Role
---@param label ENode|nil
local function set_title_style(role, label)
    if not is_node(label) then
        return
    end

    local to_fixed = math.tofixed
    role.set_label_color(label, colors.title, to_fixed(0))
    role.set_label_font_size(label, label_configuration.title_size, to_fixed(0))
    role.set_label_outline_enabled(label, true)
    role.set_label_outline_color(label, colors.outline)
    role.set_label_outline_width(label, to_fixed(label_configuration.title_outline_width))
end

---@param slot_index integer
---@return table|nil card
local function bind_static_slot(slot_index)
    local root = fetch_child(listview, node_names.item_prefix .. slot_index, false)
    if not is_node(root) then
        return nil
    end

    local suffix = "_" .. slot_index
    local card = {
        slot_index = slot_index,
        container = root,
        background = fetch_child(root, node_names.card_prefix .. suffix, true),
        slot = fetch_child(root, node_names.slot_prefix .. suffix, true),
        icon = fetch_child(root, node_names.icon_prefix .. suffix, true),
        name = fetch_child(root, node_names.name_prefix .. suffix, true),
        description = fetch_child(root, node_names.desc_prefix .. suffix, true),
        coin = fetch_child(root, node_names.coin_prefix .. suffix, true),
        price = fetch_child(root, node_names.price_prefix .. suffix, true),
        level = fetch_child(root, node_names.level_prefix .. suffix, true),
        nodes = {},
    }

    append_node(card.nodes, card.container)
    append_node(card.nodes, card.background)
    append_node(card.nodes, card.slot)
    append_node(card.nodes, card.icon)
    append_node(card.nodes, card.name)
    append_node(card.nodes, card.description)
    append_node(card.nodes, card.coin)
    append_node(card.nodes, card.price)
    append_node(card.nodes, card.level)
    return card
end

---@param role Role
---@param card table
---@param visible boolean
local function set_slot_visible(role, card, visible)
    if not role or not card then
        return
    end

    for _, node in ipairs(card.nodes) do
        role.set_node_visible(node, visible)
    end
end

---@param role Role
local function hide_unused_slots(role)
    for slot_index = #UpgradeShopConfig.ITEMS + 1, #static_slots do
        set_slot_visible(role, static_slots[slot_index], false)
    end
end

---绑定编辑器内已搭好的商店节点。
---@param canvas ECanvas
function UpgradeShopPanel.initialize(canvas)
    panel = fetch_child(canvas, node_names.panel, true)
    listview = nil
    cards_by_item_id = {}
    static_slots = {}
    title_label = nil
    click_power_label = nil

    if not is_node(panel) then
        LuaAPI.log("[UpgradeShopPanel] 静态商城根节点不存在，跳过商城绑定", 1)
        return
    end

    title_label = fetch_child(panel, node_names.title, true)
    click_power_label = fetch_child(panel, node_names.number, true)
    listview = fetch_child(panel, node_names.listview, true)
    if not is_node(listview) then
        LuaAPI.log("[UpgradeShopPanel] 静态商城列表节点不存在，跳过商城绑定", 1)
        return
    end

    for slot_index = 1, configuration.max_static_slot_scan do
        local card = bind_static_slot(slot_index)
        if not card then
            break
        end
        static_slots[slot_index] = card
    end

    for slot_index, item_configuration in ipairs(UpgradeShopConfig.ITEMS) do
        local card = static_slots[slot_index]
        if card then
            card.item_id = item_configuration.id
            cards_by_item_id[item_configuration.id] = card
        else
            LuaAPI.log("[UpgradeShopPanel] 商品缺少静态槽位: index=" .. tostring(slot_index), 1)
        end
    end

    LuaAPI.log(
        "[UpgradeShopPanel] static slots bound items=" .. tostring(#UpgradeShopConfig.ITEMS)
            .. " slots=" .. tostring(#static_slots),
        0
    )
end

---初始化单个玩家看到的商店样式和触摸状态。
---@param role Role
function UpgradeShopPanel.initialize_role(role)
    if not role then
        return
    end

    local to_fixed = math.tofixed
    set_title_style(role, title_label)
    set_title_style(role, click_power_label)
    hide_unused_slots(role)

    for _, item_configuration in ipairs(UpgradeShopConfig.ITEMS) do
        local card = cards_by_item_id[item_configuration.id]
        if card then
            set_slot_visible(role, card, true)
            set_card_background_color(role, card, colors.card_ready)
            role.set_image_color(card.slot, colors.coin, to_fixed(0))
            role.set_node_touch_enabled(card.container, false)
            set_card_text_style(role, card)
            disable_card_child_touch(role, card)
        end
    end
end

---通过主控制器传入的注册函数绑定购买事件。
---@param on_purchase fun(role: Role, item_id: integer)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function UpgradeShopPanel.bind_purchase_handler(on_purchase, register_trigger)
    for _, item_configuration in ipairs(UpgradeShopConfig.ITEMS) do
        local item_id = item_configuration.id
        local card = cards_by_item_id[item_id]
        if card then
            register_trigger(
                { EVENT.EUI_NODE_TOUCH_EVENT, card.container, AppConfig.TOUCH.CLICK },
                function(event_name, actor, data)
                    local role = data and data.role
                    if role then
                        on_purchase(role, item_id)
                    end
                end
            )
        end
    end
end

---设置单个玩家的商店面板显隐。
---@param role Role
---@param visible boolean
function UpgradeShopPanel.set_visible(role, visible)
    if not role then
        return
    end

    local to_fixed = math.tofixed
    if is_node(panel) then role.set_node_visible(panel, visible) end
    if is_node(listview) then role.set_node_visible(listview, visible) end
    if is_node(title_label) then role.set_node_visible(title_label, visible) end
    if is_node(click_power_label) then role.set_node_visible(click_power_label, visible) end

    for slot_index, card in ipairs(static_slots) do
        local slot_visible = visible and slot_index <= #UpgradeShopConfig.ITEMS
        set_slot_visible(role, card, slot_visible)
        if card.slot and card.icon then
            role.set_ui_opacity(card.slot, to_fixed(slot_visible and opacity_configuration.visible or opacity_configuration.hidden))
            if not slot_visible then
                role.set_ui_opacity(card.icon, to_fixed(opacity_configuration.hidden))
            end
        end
    end
end

---渲染 UpgradeShopSystem 生成的商店展示数据。
---@param role Role
---@param display_data ShopDisplayData
function UpgradeShopPanel.render(role, display_data)
    if not role or not display_data then
        return
    end

    local to_fixed = math.tofixed
    hide_unused_slots(role)
    if is_node(click_power_label) then
        role.set_label_text(click_power_label, configuration.title_prefix .. format_integer(display_data.click_power))
    end

    for _, item_configuration in ipairs(UpgradeShopConfig.ITEMS) do
        local card = cards_by_item_id[item_configuration.id]
        local item_display_data = display_data.items[item_configuration.id]
        if card and item_display_data then
            role.set_label_text(card.name, item_display_data.name)
            role.set_label_text(card.description, item_display_data.description)
            role.set_label_text(card.level, tostring(item_display_data.level))

            -- 图标预设 icon_preset 为 nil 时沿用编辑器内的原贴图。
            if item_display_data.icon_preset then
                role.set_image_texture_by_key_with_auto_resize(card.icon, item_display_data.icon_preset, false)
            end

            if item_display_data.unlocked then
                role.set_label_text(card.price, format_integer(item_display_data.price))
                role.set_node_visible(card.coin, true)
            else
                role.set_label_text(
                    card.price,
                    configuration.locked_price_prefix .. format_integer(item_display_data.unlock_total_brainrot)
                )
                role.set_node_visible(card.coin, false)
            end

            local at_max_level =
                item_display_data.max_level and item_display_data.level >= item_display_data.max_level
            local enabled = item_display_data.can_buy and not at_max_level
            role.set_node_touch_enabled(card.container, enabled)
            if enabled then
                set_card_background_color(role, card, colors.card_ready)
                role.set_ui_opacity(card.icon, to_fixed(opacity_configuration.visible))
                role.set_label_color(card.name, colors.text_dark, to_fixed(0))
                role.set_label_color(card.description, colors.text_dark, to_fixed(0))
                role.set_label_color(card.price, colors.text_dark, to_fixed(0))
                role.set_label_color(card.level, colors.text_blue, to_fixed(0))
            else
                set_card_background_color(role, card, colors.card_locked)
                role.set_ui_opacity(card.icon, to_fixed(opacity_configuration.locked_icon))
                role.set_label_color(card.name, colors.text_dark, to_fixed(0))
                role.set_label_color(card.description, colors.text_dark, to_fixed(0))
                role.set_label_color(card.price, colors.text_grey, to_fixed(0))
                role.set_label_color(card.level, colors.text_grey, to_fixed(0))
            end
        end
    end
end

return UpgradeShopPanel
