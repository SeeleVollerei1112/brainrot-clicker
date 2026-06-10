-- ============================================================
-- Util/SidebarTabs.lua
-- 侧边栏标签组件：背包（InventoryView）与商城（MallView）共用的标签切换逻辑。
-- 调用方负责解析节点并提供标签项数组，本组件负责选中视觉、默认选中与点击绑定。
--
-- 选中视觉：选中 -> 标签按钮 opacity=1 + 文字黑；未选中 -> 按钮 opacity=0 + 文字白。
-- 文字节点关闭触摸，让点击穿透命中背后的标签按钮（按钮 opacity=0 仍可点击）。
-- ============================================================

local AppConfig = require("App.AppConfig")

local SidebarTabs = {}

local tf = math.tofixed
local TOUCH_CLICK = AppConfig.TOUCH.CLICK

-- 选中视觉常量
local TEXT_SELECTED = 0xFF000000    -- 选中文字：黑
local TEXT_UNSELECTED = 0xFFFFFFFF  -- 未选中文字：白
local OPACITY_SELECTED = 1.0        -- 选中：标签按钮不透明
local OPACITY_UNSELECTED = 0.0      -- 未选中：标签按钮透明

---@class SidebarTabEntry
---@field key string          标签键
---@field button ENode|nil    标签按钮（选中底框，常驻可点击）
---@field label ENode|nil     标签文字（关闭触摸，点击穿透到按钮）
---@field listview ENode|nil  标签对应的列表页
---@field default boolean|nil 是否默认选中（无任何标记时取第一项）

---返回默认选中标签键（default 标记项，否则第一项）。
---@param tabs SidebarTabEntry[]
---@return string
function SidebarTabs.default_key(tabs)
    for _, entry in ipairs(tabs) do
        if entry.default then
            return entry.key
        end
    end
    return tabs[1].key
end

---切换到某标签：显示其 listview、隐藏其它页；
---选中标签按钮 opacity=1 + 文字黑，未选中按钮 opacity=0 + 文字白。
---@param role Role
---@param tabs SidebarTabEntry[]
---@param tab_key string
function SidebarTabs.select_tab(role, tabs, tab_key)
    for _, entry in ipairs(tabs) do
        local selected = entry.key == tab_key

        -- 显隐对应页：set_node_visible 会一并移除隐藏页的触摸/滚动响应，
        -- 避免隐藏页遮挡选中页的点击与列表滑动（透明度方案无法做到，故不用 opacity）。
        if entry.listview then
            role.set_node_visible(entry.listview, selected)
        end

        if entry.label then
            -- 文字变色：选中黑 / 未选中白（label 触摸已在 initialize_role 关闭，点击穿透到按钮）
            role.set_label_color(entry.label, selected and TEXT_SELECTED or TEXT_UNSELECTED, tf(0))
        end

        if entry.button then
            -- 选中底框：用按钮自身不透明度显隐（opacity=0 仍可点击，保证未选中页可被切回）
            role.set_ui_opacity(entry.button, tf(selected and OPACITY_SELECTED or OPACITY_UNSELECTED))
        end
    end
end

---玩家会话创建时：关闭标签文字触摸 + 应用默认选中视觉。
---@param role Role
---@param tabs SidebarTabEntry[]
function SidebarTabs.initialize_role(role, tabs)
    for _, entry in ipairs(tabs) do
        -- 关闭标签文字触摸，让点击穿透 label 命中背后的标签按钮。
        if entry.label then
            role.set_node_touch_enabled(entry.label, false)
        end
    end
    SidebarTabs.select_tab(role, tabs, SidebarTabs.default_key(tabs))
end

---绑定各标签按钮点击。
---@param tabs SidebarTabEntry[]
---@param on_select fun(role: Role, tab_key: string)
---@param register_trigger fun(event_arguments: table, callback: function): integer
function SidebarTabs.bind(tabs, on_select, register_trigger)
    for _, entry in ipairs(tabs) do
        if entry.button then
            local tab_key = entry.key
            register_trigger(
                { EVENT.EUI_NODE_TOUCH_EVENT, entry.button, TOUCH_CLICK },
                function(event_name, actor, data)
                    local role = data and data.role
                    if role then
                        on_select(role, tab_key)
                    end
                end
            )
        else
            LuaAPI.log("[SidebarTabs] 缺少标签按钮: " .. tostring(entry.key), 1)
        end
    end
end

return SidebarTabs
