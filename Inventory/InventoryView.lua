-- ============================================================
-- Inventory/InventoryView.lua
-- 背包侧边栏视图：解析 装备栏/储物栏 两个标签(按钮+文字+列表)的节点，
-- 标签切换/选中视觉/默认选中/点击绑定统一交由 Util/SidebarTabs 处理。
--
-- 层级（编辑器命名，均为 UINodes 顶层键）：
--   装备栏按钮(EButton) / 装备栏文本(ELabel) / 装备栏(EList)
--   储物栏按钮(EButton) / 储物栏文本(ELabel) / 储物栏(EList)
-- ============================================================

local UINodes = require("Data.UINodes")
local SidebarTabs = require("Util.SidebarTabs")

local InventoryView = {}

-- 两个标签（顺序即从前到后；第一个为默认选中）
local TABS = {
    { key = "equip",   button = "装备栏按钮", label = "装备栏文本", listview = "装备栏" },
    { key = "storage", button = "储物栏按钮", label = "储物栏文本", listview = "储物栏" },
}

---@type SidebarTabEntry[]
local tabs = {}

---一次性绑定背包标签静态节点。GAME_INIT 时调用。
function InventoryView.initialize()
    tabs = {}
    for _, tcfg in ipairs(TABS) do
        local entry = {
            key = tcfg.key,
            button = UINodes[tcfg.button],
            label = UINodes[tcfg.label],
            listview = UINodes[tcfg.listview],
        }
        if not entry.listview then
            LuaAPI.log("[InventoryView] 缺少标签列表节点: " .. tcfg.listview, 1)
        end
        tabs[#tabs + 1] = entry
    end
    LuaAPI.log("[InventoryView] 背包标签静态节点绑定完成", 0)
end

---切换到某标签页。
---@param role Role
---@param tab_key string
function InventoryView.select_tab(role, tab_key)
    SidebarTabs.select_tab(role, tabs, tab_key)
end

---玩家会话创建时：关闭标签文字触摸 + 应用默认选中视觉。
---@param role Role
function InventoryView.initialize_role(role)
    SidebarTabs.initialize_role(role, tabs)
end

---绑定两个标签按钮点击。
---@param on_select fun(role: Role, tab_key: string)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function InventoryView.bind_tab_handler(on_select, register_trigger)
    SidebarTabs.bind(tabs, on_select, register_trigger)
end

return InventoryView
