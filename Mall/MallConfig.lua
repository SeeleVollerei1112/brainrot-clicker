-- ============================================================
-- Mall/MallConfig.lua
-- 内购商城（商城画布）配置：独立于点击升级商店（ShopConfig）。
-- 这是一套面向内购（IAP）的商城，含两个侧边栏标签页：
--   暴击道具(crit) -> 列表视图 shop_tab_1
--   时间道具(time) -> 列表视图 shop_tab_1_1
-- 商品数据为【占位配置】，价格/货币/效果均为 TODO，待接入真实内购与游戏逻辑。
-- 道具实际发放待接入（见 MallSystem.purchase 的占位日志路径）。
-- ============================================================

---@class MallItemConfig
---@field id integer            商品唯一ID（暴击 1001+，时间 2001+）
---@field index integer         所在标签页内的槽位序号(1..6)，对应 shop_item_<index>
---@field name string           商品名（占位）
---@field description string    商品描述（占位）
---@field icon_preset integer|nil 图标贴图编号；nil 表示沿用编辑器原贴图
---@field price integer         占位价格
---@field currency string       结算货币占位："premium"(内购货币) | "coin"(乐园币)
---@field grant_type string     发放效果类型占位："crit_buff" | "time_buff"
---@field grant_value integer   发放效果数值占位

---@class MallTabConfig
---@field key string            标签页键："crit" | "time"
---@field title string          标签标题
---@field tab_node string       列表视图节点名（UINodes 键）
---@field button string         侧边栏标签按钮节点名（UINodes 键）
---@field label string          侧边栏标签文字节点名（UINodes 键）
---@field select_default boolean 是否为打开商城时默认选中页
---@field item_suffix_fmt string 子节点后缀格式（string.format 用）
---@field buy_fmt string         购买按钮名格式（string.format 用）
---@field items MallItemConfig[]

---@class MallConfig
local MallConfig = {
    -- 商城画布与开关
    CANVAS_NAME = "商城画布",

    -- 商城画布开关的自定义事件（画布在编辑器绑定了 show/hide_event）
    EVENTS = {
        open = "OPEN_MALL_CANVAS",
        close = "CLOSE_MALL_CANVAS",
    },

    -- 入口按钮（世界画布 btn_shop）/ 关闭按钮（商城画布内）节点名
    BUTTONS = {
        open = "btn_shop",
        close = "mall_btn_close",
    },

    UI = {
        sidebar = "侧边栏",

        -- 商品项内的子节点基础名（最终名 = base .. string.format(item_suffix_fmt, index)）
        item_base = "shop_item",
        child_base = {
            slot = "shop_slot",
            icon = "shop_icon",
            name = "shop_name",
            price = "shop_price",
            description = "shop_desc",
            coin = "shop_coin",
        },

        -- 购买按钮文案（不改字号/颜色，沿用按钮预设原样式）
        -- 侧边栏标签选中视觉常量统一在 Util/SidebarTabs.lua
        buy = {
            text = "购买",
        },
    },

    -- 两个标签页（顺序即侧边栏从上到下）
    ---@type MallTabConfig[]
    TABS = {
        {
            key = "crit",
            title = "暴击道具",
            tab_node = "shop_tab_1",
            button = "mall_tab_btn_crit",
            label = "mall_tab_lbl_crit",
            select_default = true,
            item_suffix_fmt = "_%d",       -- crit: shop_item_1 / shop_slot_1 ...
            buy_fmt = "mall_buy_crit_%d",
            items = {
                -- TODO(策划): 填入真实暴击道具名称/图标/价格/货币/效果
                { id = 1001, index = 1, name = "暴击道具1", description = "占位描述", icon_preset = nil, price = 6,  currency = "premium", grant_type = "crit_buff", grant_value = 0 },
                { id = 1002, index = 2, name = "暴击道具2", description = "占位描述", icon_preset = nil, price = 12, currency = "premium", grant_type = "crit_buff", grant_value = 0 },
                { id = 1003, index = 3, name = "暴击道具3", description = "占位描述", icon_preset = nil, price = 30, currency = "premium", grant_type = "crit_buff", grant_value = 0 },
                { id = 1004, index = 4, name = "暴击道具4", description = "占位描述", icon_preset = nil, price = 68, currency = "premium", grant_type = "crit_buff", grant_value = 0 },
                { id = 1005, index = 5, name = "暴击道具5", description = "占位描述", icon_preset = nil, price = 128, currency = "premium", grant_type = "crit_buff", grant_value = 0 },
                { id = 1006, index = 6, name = "暴击道具6", description = "占位描述", icon_preset = nil, price = 268, currency = "premium", grant_type = "crit_buff", grant_value = 0 },
            },
        },
        {
            key = "time",
            title = "时间道具",
            tab_node = "shop_tab_1_1",
            button = "mall_tab_btn_time",
            label = "mall_tab_lbl_time",
            select_default = false,
            item_suffix_fmt = "_%d_1",     -- time: shop_item_1_1 / shop_slot_1_1 ...
            buy_fmt = "mall_buy_time_%d_1",
            items = {
                -- TODO(策划): 填入真实时间道具名称/图标/价格/货币/效果
                { id = 2001, index = 1, name = "时间道具1", description = "占位描述", icon_preset = nil, price = 6,  currency = "premium", grant_type = "time_buff", grant_value = 0 },
                { id = 2002, index = 2, name = "时间道具2", description = "占位描述", icon_preset = nil, price = 12, currency = "premium", grant_type = "time_buff", grant_value = 0 },
                { id = 2003, index = 3, name = "时间道具3", description = "占位描述", icon_preset = nil, price = 30, currency = "premium", grant_type = "time_buff", grant_value = 0 },
                { id = 2004, index = 4, name = "时间道具4", description = "占位描述", icon_preset = nil, price = 68, currency = "premium", grant_type = "time_buff", grant_value = 0 },
                { id = 2005, index = 5, name = "时间道具5", description = "占位描述", icon_preset = nil, price = 128, currency = "premium", grant_type = "time_buff", grant_value = 0 },
                { id = 2006, index = 6, name = "时间道具6", description = "占位描述", icon_preset = nil, price = 268, currency = "premium", grant_type = "time_buff", grant_value = 0 },
            },
        },
    },
}

---按标签页配置生成第 index 个商品项的子节点全名。
---@param tab MallTabConfig
---@param base string
---@param index integer
---@return string node_name
function MallConfig.child_name(tab, base, index)
    return base .. string.format(tab.item_suffix_fmt, index)
end

---返回商品项容器节点名（如 shop_item_3 / shop_item_3_1）。
---@param tab MallTabConfig
---@param index integer
---@return string node_name
function MallConfig.item_name(tab, index)
    return MallConfig.UI.item_base .. string.format(tab.item_suffix_fmt, index)
end

---返回购买按钮节点名（如 mall_buy_crit_3）。
---@param tab MallTabConfig
---@param index integer
---@return string node_name
function MallConfig.buy_name(tab, index)
    return string.format(tab.buy_fmt, index)
end

---按商品ID查找配置（含所属标签）。
---@param item_id integer
---@return MallItemConfig|nil item, MallTabConfig|nil tab
function MallConfig.find_item(item_id)
    for _, tab in ipairs(MallConfig.TABS) do
        for _, item in ipairs(tab.items) do
            if item.id == item_id then
                return item, tab
            end
        end
    end
    return nil, nil
end

return MallConfig
