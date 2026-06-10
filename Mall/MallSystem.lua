-- ============================================================
-- Mall/MallSystem.lua
-- 内购商城纯逻辑层：商品展示数据投影 + 购买入口。
-- 商城为内购产品，默认无玩家状态依赖（不消耗脑腐值）。
-- 购买目前仅记录占位日志，真实下单/发放待接入。
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

---购买一个内购商品。当前仅记录占位日志。
---@param role Role
---@param item_id integer
---@return MallPurchaseResult result
function MallSystem.purchase(role, item_id)
    local item, tab = MallConfig.find_item(item_id)
    if not item or not tab then
        return { success = false, reason = "invalid_item" }
    end

    -- TODO(策划/后端): 在此接入真实内购下单流程（货币校验、订单、发放、防刷等）。
    LuaAPI.log(
        "[MallSystem] 购买占位触发（未接真实内购） tab=" .. tab.key
            .. " item=" .. tostring(item_id) .. " name=" .. item.name,
        0
    )
    return { success = true, reason = "ok_placeholder" }
end

return MallSystem
