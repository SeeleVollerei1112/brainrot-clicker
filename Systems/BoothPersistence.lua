-- ============================================================
-- Systems/BoothPersistence.lua
-- Serialize BoothState <-> JSON and read/write it to the player archive.
--
-- The whole booth state goes into ONE Str archive slot as a JSON blob
-- (the engine has no JSON and no per-field table archive that fits a
-- variable nested shape). Archive I/O is per-Role and immediate
-- (no commit/flush). All access is guarded by is_archives_enabled().
--
-- Serialized shape (string object keys, so the encoder never mistakes
-- an integer-keyed map for an array — only `zones` is a JSON array):
--   { "zones": [1, 2],
--     "placements": { "<zone>": { "<booth>": { "item_id": id, "attrs": {..} } } } }
-- ============================================================

local ArchiveKeys = require("Data.ArchiveKeys")
local BoothConfig = require("Data.BoothConfig")
local BoothState = require("Systems.BoothState")
local dkjson = require("Util.dkjson")

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

-- JSON object keys decode as strings; parse them to ints WITHOUT the
-- sandboxed global `tonumber`.
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

---@param tbl table
---@param order string[]
---@return table
local function ordered_table(tbl, order)
    return setmetatable(tbl, { __jsonorder = order, __jsontype = "object" })
end

---@param tbl table
---@return string[]
local function sorted_string_keys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return keys
end

---@param tbl table
---@return string[]
local function sorted_numeric_string_keys(tbl)
    local keys = sorted_string_keys(tbl)
    table.sort(keys, function(a, b)
        local a_number = key_to_int(a)
        local b_number = key_to_int(b)
        if a_number == b_number then
            return a < b
        end
        return a_number < b_number
    end)
    return keys
end

-- ---------- serialize ----------

---Convert runtime state to a JSON string.
---@param state BoothState
---@return string json
function BoothPersistence.to_json(state)
    -- Unlocked zone ids as a sorted array (deterministic output).
    local zones = {}
    for zone_id in pairs(state.unlocked) do
        zones[#zones + 1] = zone_id
    end
    table.sort(zones)

    -- Placements keyed by stringified zone / booth so they stay JSON objects.
    local placements = {}
    for zone_id, zone_placements in pairs(state.placements) do
        local zone_out = {}
        for booth_index, instance in pairs(zone_placements) do
            local attr_out = {}
            for attr, attr_value in pairs(instance.attrs or {}) do
                attr_out[attr] = attr_value
            end
            zone_out[tostring(booth_index)] = ordered_table({
                item_id = instance.item_id,
                attrs = ordered_table(attr_out, sorted_string_keys(attr_out)),
            }, { "item_id", "attrs" })
        end
        placements[tostring(zone_id)] = ordered_table(zone_out, sorted_numeric_string_keys(zone_out))
    end

    return dkjson.encode(ordered_table({
        zones = zones,
        placements = ordered_table(placements, sorted_numeric_string_keys(placements)),
    }, { "zones", "placements" }))
end

-- ---------- deserialize ----------

---Rebuild runtime state from a JSON string, validating against current
---config. Unknown zones/booths/items are dropped (forward compatible);
---malformed input falls back to a fresh state.
---@param str string
---@return BoothState state
function BoothPersistence.from_json(str)
    local data = dkjson.decode(str)
    if type(data) ~= "table" then
        return BoothState.new()
    end

    local state = { unlocked = {}, placements = {} }

    -- Unlocked zones: keep only ids that still exist in config.
    if type(data.zones) == "table" then
        for _, zone_id in ipairs(data.zones) do
            local id = to_int(zone_id)
            if BoothConfig.find_zone(id) then
                state.unlocked[id] = true
            end
        end
    end
    -- The default zone is always unlocked, even if an old blob omitted it.
    state.unlocked[BoothConfig.DEFAULT_UNLOCKED_ZONE_ID] = true

    -- Placements: validate zone unlocked + booth valid + item configured.
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

-- ---------- archive I/O ----------

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
