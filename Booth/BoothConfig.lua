--[[
Booth/BoothConfig.lua

展台玩法静态配置：展台区(zone) / 展台位(booth) / 物品类型(item)。

三层结构：展台区 -> 展台位(0..booth_count-1) -> 放置的物品。
物品类型带 base_attrs 作为「实例属性」的初值参考；放置后每个实例
的属性可独立变化并随存档保存（见 Booth/BoothState.lua）。

数值属性统一用整数，规避 Fix32 在 JSON 序列化中的小数串问题；
name 作为实例展示名保存，支持后续单实例改名或配置改名后的存档稳定展示。
这里同时充当本阶段的测试数据来源（3 个区 + 5 个物品）。

场景对接（运行时实测，2026-06-05）：
  每个展台位在编辑器中各有一个独立的「事件触发区域」(CustomTriggerSpace,
  prefab key = BOOTH_TRIGGER_KEY)，命名规则为
      <展区名>_展示台_<序号>_触发区   （序号从 1 起）
  例如「新手展区_展示台_1_触发区」。代码据此用 LuaAPI.query_unit(name)
  反查触发区域并绑定进出事件，无需在区域上额外配置自定义值。
  见 BoothConfig.booth_trigger_name / Booth/BoothInteraction.lua。
]]

---@class BoothZoneConfig
---@field id integer
---@field name string
---@field booth_count integer
---@field unlock_condition table   解锁条件占位（留空待策划填充；空表=无条件）
---@field unlock_cost integer      解锁成本占位（0=免费/暂不消耗）

---@class BoothItemConfig
---@field id integer
---@field prefab_id integer|nil    放置到场景时创建的物品预设编号(EquipmentKey)；nil=尚未导出
---@field base_attrs table<string, integer|string>

---@class BoothConfig
local BoothConfig = {
    -- 开局默认解锁的展台区
    DEFAULT_UNLOCKED_ZONE_ID = 1,

    -- 展台位事件触发区域的 prefab 编号（场景内所有展台触发区共用此 key）。
    BOOTH_TRIGGER_KEY = 31010112,

    -- 触发区域命名规则的固定中缀/后缀（拼出 <展区名>_展示台_<序号>_触发区）。
    TRIGGER_NAME_INFIX = "_展示台_",
    TRIGGER_NAME_SUFFIX = "_触发区",

    -- 放置物品时相对触发区域中心的高度偏移（让物品落在展台台面上，按需微调）。
    PLACEMENT_Y_OFFSET = 0.0,

    -- 展台收益累计的结算节奏（秒）。每个节拍按真实时间戳差把收益累加进总收益。
    INCOME_TICK_INTERVAL = 1.0,

    -- 展台状态定时自动存档（秒）。退出事件在本环境不一定触发，故定时落盘收益游标，
    -- 让在线累计的总收益与 last_ts 保持持久（崩溃/异常退出时也只丢失最多一个间隔）。
    AUTOSAVE_INTERVAL = 60.0,

    -- 离线收益：收益统一按「真实时间戳差」累计——在线 tick 与离线结算是同一套逻辑，
    -- 游标 last_ts 存进存档 blob（与 zone_income 原子落盘），因此不依赖退出事件、
    -- 也不会重复结算。回归时第一笔结算即为离线收益，弹窗提示并入各展区总收益
    -- （沿用纯展示、不进货币）。
    OFFLINE = {
        -- 离线收益倍率（相对在线速率）。1.0 = 全额；0.5 = 半额；按需调整。
        rate = 1.0,
        -- 离线结算的封顶秒数；0 = 无上限（按真实离线时长全额结算）。
        -- 如需封顶改成秒数，例如 8 小时 = 28800。
        max_seconds = 0,
        -- 离线时长达到该秒数才弹「欢迎回来」提示，避免短暂重连刷屏。
        min_notify_seconds = 60,
    },

    -- 进入展台后显示的交互按钮节点名（由编辑器导出到 Data/UINodes.lua 后即被引用；
    -- 若尚未导出，运行时会安全跳过并打日志）。
    UI = {
        place_button = "展台放置按钮",
        recycle_button = "展台回收按钮",
    },

    -- 展台「头顶」3D 文字界面：放置物品后在展示台上方绑定一个场景界面(E3DLayer)，
    -- 显示该实例的等级、每秒收益与累计收益。对应编辑器导出的预设/节点：
    --   layer_name  -> Data/Prefab.lua 的 scene_eui 表键（场景界面预设）
    --   level_node / income_node / total_node -> Data/UINodes.lua 的文本节点键
    --   background_nodes -> 需要透明化的背景图片节点键（按需在编辑器导出后填入）
    -- 预设未导出时，运行时会安全跳过头顶文字并打日志（其余展台逻辑不受影响）。
    HEAD_UI = {
        layer_name = "物品详细",
        level_node = "物品等级",
        income_node = "物品每秒收益",
        total_node = "物品收益",
        background_nodes = {},
        -- 绑定到展示台「底面中心点」，再沿 Y 轴上移到模型头顶（按模型高度微调）。
        socket = "socket_origin",
        offset = { x = 0.0, y = 6.0, z = 0.0 },
        style = {
            level_color = 0xFFD14D2B,
            income_color = 0xFF2BAFD1,
            total_color = 0xFF799e35,
            outline_color = 0xFF000000,
            outline_width = 2,
            level_font_size = 65,
            income_font_size = 50,
            total_font_size = 50,
            label_background_opacity = 0.0,
            background_opacity = 0.0,
            background_visible = false,
            level_prefix = "Lv.",
            income_prefix = "+",
            income_suffix = "/s",
            total_prefix = "",
        },
    },

    -- 展台回收目标槽位。默认回到「装备栏」而不是储物栏(BACKPACK)。
    -- 若编辑器枚举名不同，调整 slot_type_names 的顺序即可；都不可用时才回退 BACKPACK 并打日志。
    RECYCLE = {
        slot_type_names = { "EQUIPPED" },
    },

    ---@type BoothZoneConfig[]
    ZONES = {
        { id = 1, name = "新手展区", booth_count = 4, unlock_condition = {}, unlock_cost = 0 },
        { id = 2, name = "进阶展区", booth_count = 6, unlock_condition = {}, unlock_cost = 0 },
        { id = 3, name = "大师展区", booth_count = 6, unlock_condition = {}, unlock_cost = 0 },
    },

    ---@type BoothItemConfig[]
    ITEMS = {
        { id = 101, prefab_id = 1073741848, base_attrs = { name = "脑红1", income_per_second = 5, level = 1 } },
        { id = 102, prefab_id = 1073774688, base_attrs = { name = "脑红2", income_per_second = 12, level = 1 } },
        { id = 103, prefab_id = 1073786911, base_attrs = { name = "脑红3", income_per_second = 30, level = 1 } },
        { id = 104, prefab_id = 1073795119, base_attrs = { name = "脑红4", income_per_second = 18, level = 1 } },
        { id = 105, prefab_id = 1073807366, base_attrs = { name = "脑红5", income_per_second = 45, level = 1 } },
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

---按物品预设编号反查物品类型（放置/回收时把背包装备映射回 item_id）。
---@param prefab_id integer|nil
---@return BoothItemConfig|nil
function BoothConfig.find_item_by_prefab(prefab_id)
    if prefab_id == nil then
        return nil
    end
    for _, item in ipairs(BoothConfig.ITEMS) do
        if item.prefab_id == prefab_id then
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

---拼出某展台位事件触发区域的场景命名（序号从 1 起 = booth_index + 1）。
---@param zone_id integer
---@param booth_index integer
---@return string|nil name
function BoothConfig.booth_trigger_name(zone_id, booth_index)
    local zone = BoothConfig.find_zone(zone_id)
    if not zone or not BoothConfig.is_valid_booth(zone_id, booth_index) then
        return nil
    end
    return zone.name
        .. BoothConfig.TRIGGER_NAME_INFIX
        .. tostring(booth_index + 1)
        .. BoothConfig.TRIGGER_NAME_SUFFIX
end

---拼出某展台位「展台模型(展示台)」的场景命名 = <展区名>_展示台_<序号>。
---即触发区域名去掉「_触发区」后缀（序号从 1 起 = booth_index + 1）。
---⚠ 名称约定与触发区一致，但展台模型节点名未经运行时实测，编辑器恢复后需核对。
---@param zone_id integer
---@param booth_index integer
---@return string|nil name
function BoothConfig.booth_stand_name(zone_id, booth_index)
    local zone = BoothConfig.find_zone(zone_id)
    if not zone or not BoothConfig.is_valid_booth(zone_id, booth_index) then
        return nil
    end
    return zone.name .. BoothConfig.TRIGGER_NAME_INFIX .. tostring(booth_index + 1)
end

---拼出某展台区「公告板」的场景命名。优先用 zone.board_name 覆盖，
---否则默认 <展区名>_公告板。
---⚠ 默认后缀「_公告板」未经运行时实测，编辑器恢复后需核对/在 ZONES.board_name 修正。
---@param zone_id integer
---@return string|nil name
function BoothConfig.zone_board_name(zone_id)
    local zone = BoothConfig.find_zone(zone_id)
    if not zone then
        return nil
    end
    return zone.board_name or (zone.name .. "_公告板")
end

---遍历所有 (zone_id, booth_index, trigger_name)。供交互层批量绑定触发区域。
---@param callback fun(zone_id: integer, booth_index: integer, trigger_name: string)
function BoothConfig.for_each_booth(callback)
    for _, zone in ipairs(BoothConfig.ZONES) do
        for booth_index = 0, zone.booth_count - 1 do
            callback(zone.id, booth_index, BoothConfig.booth_trigger_name(zone.id, booth_index))
        end
    end
end

---获取某展台区的解锁字段（条件占位 + 成本）。
---@param zone_id integer
---@return table|nil unlock_condition, integer|nil unlock_cost
function BoothConfig.get_unlock(zone_id)
    local zone = BoothConfig.find_zone(zone_id)
    if not zone then
        return nil, nil
    end
    return zone.unlock_condition or {}, zone.unlock_cost or 0
end

return BoothConfig
