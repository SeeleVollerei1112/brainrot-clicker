-- ============================================================
-- Mall/MallView.lua
-- 内购商城视图：绑定商城画布的静态商品节点、渲染商品数据、绑定购买按钮。
-- 侧边栏标签切换/选中视觉/默认选中/点击绑定统一交由 Util/SidebarTabs 处理。
--
-- 层级（编辑器勘察确认）：
--   shop_tab_1(EList) -> shop_row_k -> shop_item_i -> {shop_slot_i(->shop_icon_i),
--                                       shop_name_i, shop_price_i, shop_desc_i,
--                                       shop_coin_i, mall_buy_crit_i}
--   时间页同理，子节点后缀为 _i_1，列表为 shop_tab_1_1。
-- 商品文字不改字号/颜色，沿用编辑器原始样式。
-- ============================================================

local MallConfig = require("Mall.MallConfig")
local AppConfig = require("App.AppConfig")
local UINodes = require("Data.UINodes")
local SidebarTabs = require("Util.SidebarTabs")

local MallView = {}

local ui = MallConfig.UI
local TOUCH_CLICK = AppConfig.TOUCH.CLICK

local sidebar = nil
---@type table<string, { cards:table }>
local tabs = {}
---@type SidebarTabEntry[]
local sidebar_tabs = {}

---取直接子节点（父无效则返回 nil）。
---@param parent ENode|nil
---@param name string
---@return ENode|nil
local function child(parent, name)
    return parent and GameAPI.get_eui_child_by_name(parent, name) or nil
end

---绑定单个标签页内第 index 个商品项的全部节点。
---@param tcfg MallTabConfig
---@param listview ENode
---@param item MallItemConfig
---@return table|nil card
local function bind_item(tcfg, listview, item)
    local i = item.index
    local row_name = "shop_row" .. string.format(tcfg.item_suffix_fmt, math.ceil(i / 2))
    local row = child(listview, row_name)
    -- 优先 row->item；若引擎按名递归也可直接 listview->item 兜底。
    local container = child(row, MallConfig.item_name(tcfg, i)) or child(listview, MallConfig.item_name(tcfg, i))
    if not container then
        LuaAPI.log("[MallView] 缺少商品容器: " .. MallConfig.item_name(tcfg, i), 1)
        return nil
    end

    local slot = child(container, MallConfig.child_name(tcfg, ui.child_base.slot, i))
    local card = {
        item_id = item.id,
        index = i,
        container = container,
        slot = slot,
        icon = child(slot, MallConfig.child_name(tcfg, ui.child_base.icon, i)),
        name = child(container, MallConfig.child_name(tcfg, ui.child_base.name, i)),
        price = child(container, MallConfig.child_name(tcfg, ui.child_base.price, i)),
        description = child(container, MallConfig.child_name(tcfg, ui.child_base.description, i)),
        coin = child(container, MallConfig.child_name(tcfg, ui.child_base.coin, i)),
        buy = child(container, MallConfig.buy_name(tcfg, i)),
    }
    if not card.buy then
        LuaAPI.log("[MallView] 缺少购买按钮: " .. MallConfig.buy_name(tcfg, i), 1)
    end
    return card
end

---一次性绑定商城画布的静态节点。GAME_INIT 时调用。
function MallView.initialize()
    sidebar = UINodes[ui.sidebar]
    tabs = {}
    sidebar_tabs = {}

    for _, tcfg in ipairs(MallConfig.TABS) do
        local listview = UINodes[tcfg.tab_node]
        local button = UINodes[tcfg.button] or child(sidebar, tcfg.button)
        local label = UINodes[tcfg.label] or child(button, tcfg.label)
        local entry = { cards = {} }

        if listview then
            for _, item in ipairs(tcfg.items) do
                local card = bind_item(tcfg, listview, item)
                if card then
                    entry.cards[item.index] = card
                end
            end
        else
            LuaAPI.log("[MallView] 缺少标签列表节点: " .. tostring(tcfg.tab_node), 1)
        end

        tabs[tcfg.key] = entry
        sidebar_tabs[#sidebar_tabs + 1] = {
            key = tcfg.key,
            button = button,
            label = label,
            listview = listview,
            default = tcfg.select_default,
        }
    end

    LuaAPI.log("[MallView] 商城静态节点绑定完成", 0)
end

---为单个玩家做一次性设置：标签默认选中/关文字触摸 + 购买按钮文案（不改商品字体）。
---@param role Role
function MallView.initialize_role(role)
    SidebarTabs.initialize_role(role, sidebar_tabs)

    for _, tcfg in ipairs(MallConfig.TABS) do
        local entry = tabs[tcfg.key]
        if entry then
            for _, card in pairs(entry.cards) do
                if card.buy then
                    role.set_button_text(card.buy, ui.buy.text)
                end
            end
        end
    end
end

---渲染商城商品数据（仅文本与图标，沿用编辑器原始字体样式）。
---@param role Role
---@param display_data MallDisplayData
function MallView.render(role, display_data)
    for _, tabdd in ipairs(display_data.tabs) do
        local entry = tabs[tabdd.key]
        if entry then
            for _, idd in ipairs(tabdd.items) do
                local card = entry.cards[idd.index]
                if card then
                    if card.name then role.set_label_text(card.name, idd.name) end
                    if card.description then role.set_label_text(card.description, idd.description) end
                    if card.price then role.set_label_text(card.price, tostring(idd.price)) end
                    -- nil 表示沿用编辑器原贴图。
                    if idd.icon_preset and card.icon then
                        role.set_image_texture_by_key_with_auto_resize(card.icon, idd.icon_preset, false)
                    end
                end
            end
        end
    end
end

---切换到某标签页。
---@param role Role
---@param tab_key string
function MallView.select_tab(role, tab_key)
    SidebarTabs.select_tab(role, sidebar_tabs, tab_key)
end

---绑定每个商品的购买按钮点击。
---@param on_buy fun(role: Role, item_id: integer)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function MallView.bind_buy_handler(on_buy, register_trigger)
    for _, tcfg in ipairs(MallConfig.TABS) do
        local entry = tabs[tcfg.key]
        if entry then
            for _, item in ipairs(tcfg.items) do
                local card = entry.cards[item.index]
                if card and card.buy then
                    local item_id = item.id
                    register_trigger(
                        { EVENT.EUI_NODE_TOUCH_EVENT, card.buy, TOUCH_CLICK },
                        function(event_name, actor, data)
                            local role = data and data.role
                            if role then
                                on_buy(role, item_id)
                            end
                        end
                    )
                end
            end
        end
    end
end

---绑定侧边栏标签按钮点击。
---@param on_select fun(role: Role, tab_key: string)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function MallView.bind_tab_handler(on_select, register_trigger)
    SidebarTabs.bind(sidebar_tabs, on_select, register_trigger)
end

return MallView
