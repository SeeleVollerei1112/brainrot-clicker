-- ============================================================
-- Mall/MallSystem.lua
-- 内购商城纯逻辑层：商品展示数据投影 + 购买入口。
-- 商城为内购产品，默认无玩家状态依赖（不消耗脑腐值）。
-- 真实下单与道具发放通过 set_grant_handler() 注册的钩子接入（预留接口）。
-- ============================================================

local MallConfig = require("Mall.MallConfig")

---@class MallItemDisplayData
---@field id integer
---@field index integer
---@field name string
---@field description string
---@field icon_preset integer|nil
---@field price integer
---@field currency string

---@class MallTabDisplayData
---@field key string
---@field title string
---@field items MallItemDisplayData[]

---@class MallDisplayData
---@field tabs MallTabDisplayData[]

---@class MallPurchaseResult
---@field success boolean
---@field reason string

local MallSystem = {}

---@type fun(role: Role, item: MallItemConfig, tab: MallTabConfig): boolean
local grant_handler = nil

---注册真实发放/下单钩子（预留给游戏逻辑/后端接入）。
---钩子返回 true 表示发放成功。未注册时购买仅记录日志。
---@param handler fun(role: Role, item: MallItemConfig, tab: MallTabConfig): boolean
function MallSystem.set_grant_handler(handler)
    grant_handler = handler
end

---@param item MallItemConfig
---@return MallItemDisplayData
local function project_item(item)
    return {
        id = item.id,
        index = item.index,
        name = item.name,
        description = item.description,
        icon_preset = item.icon_preset,
        price = item.price,
        currency = item.currency,
    }
end

---投影两个标签页的商品展示数据。
---@return MallDisplayData display_data
function MallSystem.get_display_data()
    local tabs = {}
    for _, tab in ipairs(MallConfig.TABS) do
        local items = {}
        for _, item in ipairs(tab.items) do
            items[item.index] = project_item(item)
        end
        table.insert(tabs, { key = tab.key, title = tab.title, items = items })
    end
    return { tabs = tabs }
end

---购买一个内购商品。当前仅走预留钩子；真实下单/发放由 grant_handler 实现。
---@param role Role
---@param item_id integer
---@return MallPurchaseResult result
function MallSystem.purchase(role, item_id)
    local item, tab = MallConfig.find_item(item_id)
    if not item or not tab then
        return { success = false, reason = "invalid_item" }
    end

    -- TODO(策划/后端): 在此接入真实内购下单流程（货币校验、订单、防刷等）。
    -- 目前直接调用发放钩子作为占位。
    if grant_handler then
        local ok = grant_handler(role, item, tab)
        if not ok then
            return { success = false, reason = "grant_failed" }
        end
        return { success = true, reason = "ok" }
    end

    LuaAPI.log(
        "[MallSystem] 购买占位触发（未接发放钩子） tab=" .. tab.key
            .. " item=" .. tostring(item_id) .. " name=" .. item.name,
        0
    )
    return { success = true, reason = "ok_placeholder" }
end

return MallSystem
