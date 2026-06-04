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

-- ---------- serialize ----------

---Convert runtime state to a JSON string. Zone / booth keys are stringified
---so they stay JSON objects (only `zones` is a JSON array); Json.encode sorts
---object keys itself, so the output is already deterministic.
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

-- ---------- deserialize ----------

---Rebuild runtime state from a JSON string, validating against current
---config. Unknown zones/booths/items are dropped (forward compatible);
---malformed input falls back to a fresh state.
---@param str string
---@return BoothState state
function BoothPersistence.from_json(str)
    local data = Json.decode(str)
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
