--[[
Clicker/UpgradeShop/UpgradeShopView.lua

升级商店表现层。
静态节点由编辑器搭好，业务层只传入展示数据，本文件负责绑定节点、渲染文本与触摸状态。
]]

local UpgradeShopView = {}
local UpgradeShopConfig = require("Clicker.UpgradeShop.UpgradeShopConfig")
local AppConfig = require("App.AppConfig")
local UINodes = require("Data.UINodes")
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

---节点查找：up_* 重命名后所有商店节点均有全局唯一导出，直查 UINodes；
---兜底再按父节点找一次（导出物落后于场景时仍可工作），都找不到则记日志。
---不做 "_1" 后缀回退——那是上次静默错绑到商城隐藏节点的根源。
---@param parent ENode|nil
---@param name string
---@return ENode|nil node
local function find_node(parent, name)
    local node = UINodes[name] or (parent and GameAPI.get_eui_child_by_name(parent, name))
    if not node then
        LuaAPI.log("[UpgradeShopView] 缺少静态节点: " .. name, 1)
    end
    return node
end

---@param role Role
---@param label ENode|nil 导出缺失时为 nil，就地跳过
---@param color integer
---@param size integer
local function style_card_label(role, label, color, size)
    if not label then
        return
    end
    local to_fixed = math.tofixed
    role.set_label_color(label, color, to_fixed(0))
    role.set_label_font_size(label, size, to_fixed(0))
    role.set_label_outline_enabled(label, false)
    role.set_label_shadow_enabled(label, false)
end

---@param role Role
---@param card table
local function set_card_text_style(role, card)
    style_card_label(role, card.name, colors.text_dark, label_configuration.name_size)
    style_card_label(role, card.description, colors.text_dark, label_configuration.desc_size)
    style_card_label(role, card.price, colors.text_dark, label_configuration.price_size)
    style_card_label(role, card.level, colors.text_blue, label_configuration.level_size)
end

-- 卡片子节点字段名：遍历设置可见性/触摸状态时共用
local CARD_CHILD_KEYS = { "background", "slot", "icon", "coin", "name", "description", "price", "level" }

---@param role Role
---@param card table
local function disable_card_child_touch(role, card)
    for _, key in ipairs(CARD_CHILD_KEYS) do
        local node = card[key]
        if node then
            role.set_node_touch_enabled(node, false)
        end
    end
end

---@param role Role
---@param label ENode|nil
local function set_title_style(role, label)
    if not label then
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
    local root = UINodes[node_names.item_prefix .. slot_index]
    if not root then
        return nil
    end

    local suffix = "_" .. slot_index
    return {
        slot_index = slot_index,
        container = root,
        background = find_node(root, node_names.card_prefix .. suffix),
        slot = find_node(root, node_names.slot_prefix .. suffix),
        icon = find_node(root, node_names.icon_prefix .. suffix),
        name = find_node(root, node_names.name_prefix .. suffix),
        description = find_node(root, node_names.desc_prefix .. suffix),
        coin = find_node(root, node_names.coin_prefix .. suffix),
        price = find_node(root, node_names.price_prefix .. suffix),
        level = find_node(root, node_names.level_prefix .. suffix),
    }
end

---@param role Role
---@param card table
---@param visible boolean
local function set_slot_visible(role, card, visible)
    role.set_node_visible(card.container, visible)
    for _, key in ipairs(CARD_CHILD_KEYS) do
        local node = card[key]
        if node then
            role.set_node_visible(node, visible)
        end
    end
end

---@param role Role
local function hide_unused_slots(role)
    for slot_index = #UpgradeShopConfig.ITEMS + 1, #static_slots do
        set_slot_visible(role, static_slots[slot_index], false)
    end
end

---绑定编辑器内已搭好的商店节点。
---@param canvas ENode
function UpgradeShopView.initialize(canvas)
    panel = find_node(canvas, node_names.panel)
    listview = nil
    cards_by_item_id = {}
    static_slots = {}
    title_label = nil
    click_power_label = nil

    if not panel then
        LuaAPI.log("[UpgradeShopView] 静态商城根节点不存在，跳过商城绑定", 1)
        return
    end

    title_label = find_node(panel, node_names.title)
    click_power_label = find_node(panel, node_names.number)
    listview = find_node(panel, node_names.listview)
    if not listview then
        LuaAPI.log("[UpgradeShopView] 静态商城列表节点不存在，跳过商城绑定", 1)
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
            LuaAPI.log("[UpgradeShopView] 商品缺少静态槽位: index=" .. tostring(slot_index), 1)
        end
    end

    LuaAPI.log(
        "[UpgradeShopView] static slots bound items=" .. tostring(#UpgradeShopConfig.ITEMS)
        .. " slots=" .. tostring(#static_slots),
        0
    )
end

---初始化单个玩家看到的商店样式和触摸状态。
---@param role Role
function UpgradeShopView.initialize_role(role)
    local to_fixed = math.tofixed
    set_title_style(role, title_label)
    set_title_style(role, click_power_label)
    hide_unused_slots(role)

    for _, item_configuration in ipairs(UpgradeShopConfig.ITEMS) do
        local card = cards_by_item_id[item_configuration.id]
        if card then
            set_slot_visible(role, card, true)
            if card.background then
                role.set_image_color(card.background, colors.card_ready, to_fixed(0))
            end
            if card.slot then
                role.set_image_color(card.slot, colors.coin, to_fixed(0))
            end
            role.set_node_touch_enabled(card.container, false)
            set_card_text_style(role, card)
            disable_card_child_touch(role, card)
        end
    end
end

---通过主控制器传入的注册函数绑定购买事件。
---@param on_purchase fun(role: Role, item_id: integer)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function UpgradeShopView.bind_purchase_handler(on_purchase, register_trigger)
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

---渲染 UpgradeShopSystem 生成的商店展示数据。
---@param role Role
---@param display_data ShopDisplayData
function UpgradeShopView.render(role, display_data)
    local to_fixed = math.tofixed
    if click_power_label then
        role.set_label_text(click_power_label, configuration.title_prefix .. tostring(display_data.click_power))
    end

    for _, item_configuration in ipairs(UpgradeShopConfig.ITEMS) do
        local card = cards_by_item_id[item_configuration.id]
        local item_display_data = display_data.items[item_configuration.id]
        if card and item_display_data then
            if card.name then role.set_label_text(card.name, item_display_data.name) end
            if card.description then role.set_label_text(card.description, item_display_data.description) end
            if card.level then role.set_label_text(card.level, tostring(item_display_data.level)) end

            -- 图标预设 icon_preset 为 nil 时沿用编辑器内的原贴图。
            if item_display_data.icon_preset and card.icon then
                role.set_image_texture_by_key_with_auto_resize(card.icon, item_display_data.icon_preset, false)
            end

            if item_display_data.unlocked then
                if card.price then role.set_label_text(card.price, tostring(item_display_data.price)) end
                if card.coin then role.set_node_visible(card.coin, true) end
            else
                if card.price then
                    role.set_label_text(
                        card.price,
                        configuration.locked_price_prefix .. tostring(item_display_data.unlock_total_brainrot)
                    )
                end
                if card.coin then role.set_node_visible(card.coin, false) end
            end

            local enabled = item_display_data.can_buy
            role.set_node_touch_enabled(card.container, enabled)
            if card.background then
                role.set_image_color(card.background, enabled and colors.card_ready or colors.card_locked, to_fixed(0))
            end
            if card.icon then
                role.set_ui_opacity(card.icon,
                    to_fixed(enabled and opacity_configuration.visible or opacity_configuration.locked_icon))
            end
            local detail_color = enabled and colors.text_dark or colors.text_grey
            if card.price then role.set_label_color(card.price, detail_color, to_fixed(0)) end
            if card.level then
                role.set_label_color(card.level, enabled and colors.text_blue or colors.text_grey, to_fixed(0))
            end
        end
    end
end

return UpgradeShopView
