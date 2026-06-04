-- ============================================================
-- Data/ShopConfig.lua
-- 商城道具配置：道具名、描述、兑换额度、等级与收益效果
-- ============================================================

---@class ShopItemConfig
---@field id integer
---@field name string
---@field locked_name string
---@field description string
---@field locked_description string
---@field effect_type string "click" | "passive"
---@field effect_value integer
---@field base_price integer
---@field price_growth_percent integer
---@field initial_level integer
---@field max_level integer|nil
---@field unlock_total_brainrot integer
---@field icon_preset integer|nil
---@field locked_icon_preset integer|nil

---@class ShopConfig
local ShopConfig = {
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
            item_prefix = "shop_item_",
            card_prefix = "shop_card",
            slot_prefix = "shop_slot",
            icon_prefix = "shop_icon",
            name_prefix = "shop_name",
            desc_prefix = "shop_desc",
            coin_prefix = "shop_coin",
            price_prefix = "shop_price",
            level_prefix = "shop_level",
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
            base_price = 125,
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
            base_price = 500,
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
            base_price = 1100,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 1100,
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
            effect_value = 100,
            base_price = 12000,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 15000,
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
            effect_value = 200,
            base_price = 12000,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 18000,
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
            effect_value = 1000,
            base_price = 90000,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 90000,
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
            base_price = 315000,
            price_growth_percent = 115,
            initial_level = 0,
            max_level = nil,
            unlock_total_brainrot = 315000,
            icon_preset = nil,
            locked_icon_preset = nil,
        },
    },
}

function ShopConfig.get_price_growth(item)
    return item.price_growth_percent or ShopConfig.PRICE_GROWTH_PERCENT
end

return ShopConfig
