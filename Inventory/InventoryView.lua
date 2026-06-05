-- ============================================================
-- Inventory/InventoryView.lua
-- 背包侧边栏视图：绑定 装备栏/储物栏 两个标签(按钮+文字+列表)，
-- 点击标签时显隐对应 listview 并设置选中视觉。
--
-- 选中视觉沿用商城标签方案（见 MallView）：
--   未选中 -> 标签按钮 opacity=0 + 文字白；选中 -> 标签按钮 opacity=1 + 文字黑。
-- 文字节点关闭触摸，让点击穿透命中背后的标签按钮（按钮 opacity=0 仍可点击）。
--
-- 层级（编辑器命名，均为 UINodes 顶层键）：
--   装备栏按钮(EButton) / 装备栏文本(ELabel) / 装备栏(EList)
--   储物栏按钮(EButton) / 储物栏文本(ELabel) / 储物栏(EList)
-- ============================================================

local UINodes = require("Data.UINodes")
local AppConfig = require("App.AppConfig")

local InventoryView = {}

local tf = math.tofixed
local TOUCH_CLICK = AppConfig.TOUCH.CLICK

-- 选中视觉常量（与商城标签 MallConfig.UI.tab 保持一致）
local TEXT_SELECTED = 0xFF000000    -- 选中文字：黑
local TEXT_UNSELECTED = 0xFFFFFFFF  -- 未选中文字：白
local OPACITY_SELECTED = 1.0        -- 选中：标签按钮不透明
local OPACITY_UNSELECTED = 0.0      -- 未选中：标签按钮透明

-- 两个标签（顺序即从前到后；TABS[1] 为默认选中）
local TABS = {
    { key = "equip",   button = "装备栏按钮", label = "装备栏文本", listview = "装备栏" },
    { key = "storage", button = "储物栏按钮", label = "储物栏文本", listview = "储物栏" },
}

---@type table<string, { button:ENode, label:ENode, listview:ENode }>
local tabs = {}

---@param node any
---@return boolean
local function is_node(node)
    return node ~= nil and node ~= false and node ~= 0 and node ~= ""
end

---一次性绑定背包标签静态节点。GAME_INIT 时调用。
function InventoryView.initialize()
    tabs = {}
    for _, tcfg in ipairs(TABS) do
        local entry = {
            button = UINodes[tcfg.button],
            label = UINodes[tcfg.label],
            listview = UINodes[tcfg.listview],
        }
        if not is_node(entry.button) then
            LuaAPI.log("[InventoryView] 缺少标签按钮: " .. tcfg.button, 1)
        end
        if not is_node(entry.listview) then
            LuaAPI.log("[InventoryView] 缺少标签列表节点: " .. tcfg.listview, 1)
        end
        tabs[tcfg.key] = entry
    end
    LuaAPI.log("[InventoryView] 背包标签静态节点绑定完成", 0)
end

---返回默认选中标签键（第一个标签）。
---@return string
function InventoryView.get_default_tab_key()
    return TABS[1].key
end

---切换到某标签：显示其 listview、隐藏另一页；
---选中标签按钮 opacity=1 + 文字黑，未选中按钮 opacity=0 + 文字白。
---@param role Role
---@param tab_key string
function InventoryView.select_tab(role, tab_key)
    if not role then
        return
    end

    for _, tcfg in ipairs(TABS) do
        local entry = tabs[tcfg.key]
        if entry then
            local selected = tcfg.key == tab_key

            -- set_node_visible 同时移除隐藏页的触摸/滚动响应，避免遮挡选中页。
            if is_node(entry.listview) then
                role.set_node_visible(entry.listview, selected)
            end

            if is_node(entry.label) then
                -- 文字变色：选中黑 / 未选中白（label 触摸已在 initialize_role 关闭，点击穿透到按钮）
                role.set_label_color(entry.label, selected and TEXT_SELECTED or TEXT_UNSELECTED, tf(0))
            end

            if is_node(entry.button) then
                -- 选中底框：用按钮自身不透明度显隐（opacity=0 仍可点击，保证未选中页可被切回）
                role.set_ui_opacity(entry.button, tf(selected and OPACITY_SELECTED or OPACITY_UNSELECTED))
            end
        end
    end
end

---玩家会话创建时：关闭标签文字触摸 + 应用默认选中视觉。
---@param role Role
function InventoryView.initialize_role(role)
    if not role then
        return
    end

    for _, tcfg in ipairs(TABS) do
        local entry = tabs[tcfg.key]
        -- 关闭标签文字触摸，让点击穿透 label 命中背后的标签按钮。
        if entry and is_node(entry.label) then
            role.set_node_touch_enabled(entry.label, false)
        end
    end

    InventoryView.select_tab(role, InventoryView.get_default_tab_key())
end

---绑定两个标签按钮点击。
---@param on_select fun(role: Role, tab_key: string)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function InventoryView.bind_tab_handler(on_select, register_trigger)
    for _, tcfg in ipairs(TABS) do
        local entry = tabs[tcfg.key]
        local button = entry and entry.button
        if is_node(button) then
            local tab_key = tcfg.key
            register_trigger(
                { EVENT.EUI_NODE_TOUCH_EVENT, button, TOUCH_CLICK },
                function(event_name, actor, data)
                    local role = data and data.role
                    if role then
                        on_select(role, tab_key)
                    end
                end
            )
        else
            LuaAPI.log("[InventoryView] 缺少标签按钮: " .. tostring(tcfg.button), 1)
        end
    end
end

return InventoryView
