-- ============================================================
-- Data/BoothConfig.lua
-- 展台玩法静态配置：展台区(zone) / 展台位(booth) / 物品类型(item)。
--
-- 三层结构：展台区 -> 展台位(0..booth_count-1) -> 放置的物品。
-- 物品类型带 base_attrs 作为「实例属性」的初值参考；放置后每个实例
-- 的属性可独立变化并随存档保存（见 Systems/BoothState.lua）。
--
-- 数值属性统一用整数，规避 Fix32 在 JSON 序列化中的小数串问题；
-- name 作为实例展示名保存，支持后续单实例改名或配置改名后的存档稳定展示。
-- 这里同时充当本阶段的测试数据来源（3 个区 + 5 个物品）。
-- ============================================================

---@class BoothZoneConfig
---@field id integer
---@field name string
---@field booth_count integer

---@class BoothItemConfig
---@field id integer
---@field name string
---@field base_attrs table<string, integer|string>

---@class BoothConfig
local BoothConfig = {
    -- 开局默认解锁的展台区
    DEFAULT_UNLOCKED_ZONE_ID = 1,

    ---@type BoothZoneConfig[]
    ZONES = {
        { id = 1, name = "新手展区", booth_count = 4 },
        { id = 2, name = "进阶展区", booth_count = 6 },
        { id = 3, name = "大师展区", booth_count = 6 },
    },

    ---@type BoothItemConfig[]
    ITEMS = {
        { id = 101, name = "脑红1", base_attrs = { name = "脑红1", income_per_second = 5, level = 1 } },
        { id = 102, name = "脑红2", base_attrs = { name = "脑红2", income_per_second = 12, level = 1 } },
        { id = 103, name = "脑红3", base_attrs = { name = "脑红3", income_per_second = 30, level = 1 } },
        { id = 104, name = "脑红4", base_attrs = { name = "脑红4", income_per_second = 18, level = 1 } },
        { id = 105, name = "脑红5", base_attrs = { name = "脑红5", income_per_second = 45, level = 1 } },
    },
}

---按 id 查找展台区配置。
---@param zone_id integer
---@return BoothZoneConfig|nil
function BoothConfig.find_zone(zone_id)
    for _, zone in ipairs(BoothConfig.ZONES) do
        if zone.id == zone_id then
            return zone
        end
    end
    return nil
end

---按 id 查找物品类型配置。
---@param item_id integer
---@return BoothItemConfig|nil
function BoothConfig.find_item(item_id)
    for _, item in ipairs(BoothConfig.ITEMS) do
        if item.id == item_id then
            return item
        end
    end
    return nil
end

---校验 (区, 展台位) 是否合法（区存在且位索引在范围内）。
---@param zone_id integer
---@param booth_index integer
---@return boolean
function BoothConfig.is_valid_booth(zone_id, booth_index)
    local zone = BoothConfig.find_zone(zone_id)
    if not zone then
        return false
    end
    if type(booth_index) ~= "number" then
        return false
    end
    return booth_index >= 0 and booth_index < zone.booth_count
end

return BoothConfig
