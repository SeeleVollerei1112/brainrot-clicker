--[[
Booth/BoothPersistence.lua

展台状态持久化：BoothState <-> JSON，并读写到玩家存档。

整份展台状态写入一个 Str 类型存档位，内容是 JSON 字符串。引擎没有内置 JSON，
也没有适合这种可变嵌套结构的逐字段表存档，所以这里统一编码为字符串。
存档读写以 Role 为单位立即生效，不需要额外 commit / flush。

序列化结构：
  {
    "zones": [1, 2],
    "placements": {
      "<zone>": { "<booth>": { "item_id": id, "attrs": {..} } }
    }
  }

对象键统一转成字符串，避免编码器把整数键表误判成数组；只有 zones 是 JSON 数组。
]]

local ArchiveKeys = require("Data.ArchiveKeys")
local BoothConfig = require("Booth.BoothConfig")
local BoothState = require("Booth.BoothState")
local Json = require("Util.Json")

local BoothPersistence = {}

---@param value any
---@return integer
local function to_int(value)
    return math.tointeger(value) or 0
end

---@param attr string
---@param value any
---@param attrs table<string, integer|string>
local function set_decoded_attr(attr, value, attrs)
    if attr == "attack" then
        if attrs.income_per_second == nil then
            attrs.income_per_second = to_int(value)
        end
        return
    end

    if type(value) == "string" then
        attrs[attr] = value
    elseif type(value) == "number" then
        attrs[attr] = to_int(value)
    end
end

--[[
JSON 对象键解码后是字符串。
沙盒里没有全局 tonumber，所以这里手写一个只解析整数字符串的转换函数。
]]
---@param key string
---@return integer
local function key_to_int(key)
    if type(key) == "number" then
        return math.tointeger(key) or 0
    end
    if type(key) ~= "string" or key == "" then
        return 0
    end

    local sign = 1
    local index = 1
    local first = key:sub(1, 1)
    if first == "-" then
        sign = -1
        index = 2
    elseif first == "+" then
        index = 2
    end

    local value = 0
    local saw_digit = false
    while index <= #key do
        local ch = key:byte(index)
        if ch < 48 or ch > 57 then
            return 0
        end
        value = value * 10 + (ch - 48)
        saw_digit = true
        index = index + 1
    end

    if not saw_digit then
        return 0
    end
    return sign * value
end

-- ---------- 序列化 ----------

---把运行时状态转为 JSON 字符串。
---展区 / 展台位的键会转成字符串，保证它们保持 JSON 对象；只有 zones 是数组。
---Json.encode 会排序对象键，所以输出天然稳定。
---@param state BoothState
---@return string json
function BoothPersistence.to_json(state)
    local zones = {}
    for zone_id in pairs(state.unlocked) do
        zones[#zones + 1] = zone_id
    end
    table.sort(zones)

    local placements = {}
    for zone_id, zone_placements in pairs(state.placements) do
        local zone_out = {}
        for booth_index, instance in pairs(zone_placements) do
            zone_out[tostring(booth_index)] = {
                item_id = instance.item_id,
                attrs = instance.attrs or {},
            }
        end
        placements[tostring(zone_id)] = zone_out
    end

    return Json.encode({
        zones = zones,
        placements = placements,
    })
end

-- ---------- 反序列化 ----------

---从 JSON 字符串重建运行时状态，并按当前配置校验。
---未知展区、展台位和物品会被丢弃，格式错误时退回新状态。
---@param str string
---@return BoothState state
function BoothPersistence.from_json(str)
    local data = Json.decode(str)
    if type(data) ~= "table" then
        return BoothState.new()
    end

    local state = { unlocked = {}, placements = {} }

    -- 已解锁展区：只保留当前配置里仍存在的 id。
    if type(data.zones) == "table" then
        for _, zone_id in ipairs(data.zones) do
            local id = to_int(zone_id)
            if BoothConfig.find_zone(id) then
                state.unlocked[id] = true
            end
        end
    end
    -- 默认展区始终解锁，即使旧存档里漏了它。
    state.unlocked[BoothConfig.DEFAULT_UNLOCKED_ZONE_ID] = true

    -- 放置物：校验展区已解锁、展台位合法、物品已配置。
    if type(data.placements) == "table" then
        for zone_key, zone_placements in pairs(data.placements) do
            local zone_id = key_to_int(zone_key)
            if state.unlocked[zone_id] and type(zone_placements) == "table" then
                for booth_key, instance in pairs(zone_placements) do
                    local booth_index = key_to_int(booth_key)
                    local item_id = type(instance) == "table" and to_int(instance.item_id) or 0
                    if BoothConfig.is_valid_booth(zone_id, booth_index)
                        and BoothConfig.find_item(item_id) then
                        local attrs = {}
                        if type(instance.attrs) == "table" then
                            for attr, attr_value in pairs(instance.attrs) do
                                set_decoded_attr(attr, attr_value, attrs)
                            end
                        end
                        BoothState.place_item(state, zone_id, booth_index, item_id, attrs)
                    end
                end
            end
        end
    end

    return state
end

-- ---------- 存档读写 ----------

---@return boolean
local function archives_ready()
    if not GameAPI.is_archives_enabled() then
        LuaAPI.log("[BoothPersistence] 存档功能未开启，跳过存/读档", 1)
        return false
    end
    return true
end

---@param role Role
---@param state BoothState
function BoothPersistence.save(role, state)
    if not role or not archives_ready() then
        return
    end
    local blob = BoothPersistence.to_json(state)
    role.set_archive_by_type(ArchiveKeys.BOOTH_BLOB.type, ArchiveKeys.BOOTH_BLOB.id, blob)
    LuaAPI.log("[BoothPersistence] 已保存展台存档: " .. blob, 0)
end

---@param role Role
---@return BoothState state
function BoothPersistence.load(role)
    if not role or not archives_ready() or not role.has_saved_archive() then
        return BoothState.new()
    end
    local blob = role.get_archive_by_type(ArchiveKeys.BOOTH_BLOB.type, ArchiveKeys.BOOTH_BLOB.id)
    if type(blob) ~= "string" or blob == "" then
        return BoothState.new()
    end
    return BoothPersistence.from_json(blob)
end

return BoothPersistence
