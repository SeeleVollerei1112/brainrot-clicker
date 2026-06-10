--[[
Clicker/UpgradeShop/UpgradeShopConfig.lua

点击升级商店配置：道具名、描述、兑换额度、等级与收益效果。
]]

---@class ShopItemConfig
---@field id integer
---@field name string
---@field locked_name string
---@field description string
---@field locked_description string
---@field effect_type string "click" | "passive" --缺少字面量类型
---@field effect_value integer
---@field base_price integer
---@field price_growth_percent integer
---@field initial_level integer
---@field max_level integer|nil
---@field unlock_total_brainrot integer
---@field icon_preset integer|nil
---@field locked_icon_preset integer|nil

---@class UpgradeShopConfig
local UpgradeShopConfig = {
    PRICE_GROWTH_PERCENT = 115,

    UI = {
        max_static_slot_scan = 64,
        title_prefix = "+",
        locked_price_prefix = "累计 ",
        colors = {
            card_ready = 0xFFFFFFFF,
            card_locked = 0xFF9A9A9A,
            text_dark = 0xFF000000,
            text_blue = 0xFF5FA6FF,
            text_grey = 0xFF303036,
            coin = 0xFFFFD84A,
            title = 0xFFFFFFFF,
            outline = 0xFF000000,
        },
        label = {
            name_size = 42,
            desc_size = 31,
            price_size = 31,
            level_size = 60,
            title_size = 46,
            title_outline_width = 3,
        },
        opacity = {
            visible = 1.0,
            hidden = 0.0,
            locked_icon = 0.35,
        },
        nodes = {
            panel = "shop_panel",
            title = "label_shop_title",
            number = "lable_shop_title_number",
            listview = "shop_listview",
            -- 升级商店专属前缀（与商城画布的 shop_* 节点区分，避免全局重名）
            item_prefix = "up_item_",
            card_prefix = "up_card",
            slot_prefix = "up_slot",
            icon_prefix = "up_icon",
            name_prefix = "up_name",
            desc_prefix = "up_desc",
            coin_prefix = "up_coin",
            price_prefix = "up_price",
            level_prefix = "up_level",
        },
    },

    ITEMS = {
        {
            id = 1,
            name = "Cursor",
            locked_name = "Cursor",
            description = "+1 Brainrot per click",
            locked_description = "+1 Brainrot per click",
            effect_type = "click",
            effect_value = 1,
            base_price = 50,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 0,
            icon_preset = nil,
            locked_icon_preset = nil,
        },
        {
            id = 2,
            name = "Auto Click",
            locked_name = "Auto Click",
            description = "+1 Brainrot per second",
            locked_description = "+1 Brainrot per second",
            effect_type = "passive",
            effect_value = 1,
            base_price = 200,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 0,
            icon_preset = nil,
            locked_icon_preset = nil,
        },
        {
            id = 3,
            name = "Mr Clicker",
            locked_name = "Mr Clicker",
            description = "+5 Brainrot per click",
            locked_description = "+5 Brainrot per click",
            effect_type = "click",
            effect_value = 5,
            base_price = 800,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 0,
            icon_preset = nil,
            locked_icon_preset = nil,
        },
        {
            id = 4,
            name = "Trallere Trallala Farm",
            locked_name = "???",
            description = "+6 Brainrot per second",
            locked_description = "???",
            effect_type = "passive",
            effect_value = 6,
            base_price = 3200,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 1000,
            icon_preset = nil,
            locked_icon_preset = nil,
        },
        {
            id = 5,
            name = "Presidnet Clicker",
            locked_name = "???",
            description = "+25 Brainrot per click",
            locked_description = "???",
            effect_type = "click",
            effect_value = 25,
            base_price = 12500,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 10000,
            icon_preset = nil,
            locked_icon_preset = nil,
        },
        {
            id = 6,
            name = "Bombardlro Crocodlllo Pump",
            locked_name = "???",
            description = "+100 Brainrot per second",
            locked_description = "???",
            effect_type = "passive",
            effect_value = 100,
            base_price = 50000,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 50000,
            icon_preset = nil,
            locked_icon_preset = nil,
        },
        {
            id = 7,
            name = "King Clicker",
            locked_name = "???",
            description = "+100 Brainrot per click",
            locked_description = "???",
            effect_type = "click",
            effect_value = 100,
            base_price = 200000,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 100000,
            icon_preset = nil,
            locked_icon_preset = nil,
        },
        {
            id = 8,
            name = "Trallere Trallala Factory",
            locked_name = "???",
            description = "+5000 Brainrot per second",
            locked_description = "???",
            effect_type = "passive",
            effect_value = 5000,
            base_price = 800000,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 250000,
            icon_preset = nil,
            locked_icon_preset = nil,
        },
    },
}

function UpgradeShopConfig.get_price_growth(item)
    return item.price_growth_percent or UpgradeShopConfig.PRICE_GROWTH_PERCENT
end

return UpgradeShopConfig
