-- ============================================================
-- Util/Json.lua
-- Minimal pure-Lua JSON encode/decode for archive blobs.
--
-- Scope-limited on purpose: only this project's save data passes
-- through here — plain tables of numbers/strings, ascii string keys,
-- and booleans. So it:
--   * encodes integral numbers without decimals (Fix32-safe),
--   * escapes only " \ and whitespace (blob keys are ascii),
--   * decodes WITHOUT pcall/error (sandbox lacks pcall) — a malformed
--     string yields nil instead of raising, so callers can fall back.
-- Not a general-purpose JSON library.
-- ============================================================

local Json = {}

-- ---------- encode ----------

local ESCAPE_MAP = {
    ['"'] = '\\"',
    ['\\'] = '\\\\',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
}

local function encode_string(value, out)
    out[#out + 1] = '"'
    out[#out + 1] = (value:gsub('[\\"\n\r\t]', ESCAPE_MAP))
    out[#out + 1] = '"'
end

local function encode_number(value, out)
    local integer = math.tointeger(value)
    if integer ~= nil then
        out[#out + 1] = tostring(integer)
    else
        out[#out + 1] = tostring(value)
    end
end

-- A table is treated as a JSON array only when its keys are exactly
-- 1..n contiguous integers (n > 0). Empty tables encode as objects {}.
---@param t table
---@return boolean is_array, integer length
local function detect_array(t)
    local count = 0
    for key in pairs(t) do
        if type(key) ~= "number" then
            return false, 0
        end
        count = count + 1
    end
    for index = 1, count do
        if t[index] == nil then
            return false, 0
        end
    end
    return count > 0, count
end

local encode_value -- forward declaration

local function encode_table(t, out)
    local is_array, length = detect_array(t)
    if is_array then
        out[#out + 1] = "["
        for index = 1, length do
            if index > 1 then
                out[#out + 1] = ","
            end
            encode_value(t[index], out)
        end
        out[#out + 1] = "]"
    else
        -- Sort keys so output is deterministic regardless of pairs() order;
        -- this makes encode(decode(encode(x))) stable for round-trip checks.
        local entries = {}
        for key, value in pairs(t) do
            entries[#entries + 1] = { k = tostring(key), v = value }
        end
        table.sort(entries, function(a, b)
            return a.k < b.k
        end)
        out[#out + 1] = "{"
        for index = 1, #entries do
            if index > 1 then
                out[#out + 1] = ","
            end
            encode_string(entries[index].k, out)
            out[#out + 1] = ":"
            encode_value(entries[index].v, out)
        end
        out[#out + 1] = "}"
    end
end

encode_value = function(value, out)
    local value_type = type(value)
    if value == nil then
        out[#out + 1] = "null"
    elseif value_type == "boolean" then
        out[#out + 1] = value and "true" or "false"
    elseif value_type == "number" then
        encode_number(value, out)
    elseif value_type == "string" then
        encode_string(value, out)
    elseif value_type == "table" then
        encode_table(value, out)
    else
        out[#out + 1] = "null"
    end
end

---Encode a Lua value (table/string/number/boolean/nil) to a JSON string.
---@param value any
---@return string json
function Json.encode(value)
    local out = {}
    encode_value(value, out)
    return table.concat(out)
end

-- ---------- decode (no pcall/error; sets a flag on malformed input) ----------

local UNESCAPE_MAP = {
    ['"'] = '"',
    ['\\'] = '\\',
    ['/'] = '/',
    ['n'] = '\n',
    ['r'] = '\r',
    ['t'] = '\t',
    ['b'] = '\b',
    ['f'] = '\f',
}

local DIGIT_VALUE = {
    ['0'] = 0, ['1'] = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4,
    ['5'] = 5, ['6'] = 6, ['7'] = 7, ['8'] = 8, ['9'] = 9,
}

---Parse a numeric string WITHOUT the global `tonumber` (sandboxed out of
---the Eggy VM). Handles optional sign + integer + fractional parts;
---integer inputs return a Lua integer. Returns nil on malformed input.
---@param str string
---@return number|nil
local function parse_number(str)
    if str == nil or str == "" then
        return nil
    end
    local index = 1
    local sign = 1
    local first = str:sub(1, 1)
    if first == "-" then
        sign = -1
        index = 2
    elseif first == "+" then
        index = 2
    end

    local integer_part = 0
    local saw_digit = false
    while index <= #str do
        local digit = DIGIT_VALUE[str:sub(index, index)]
        if digit == nil then
            break
        end
        integer_part = integer_part * 10 + digit
        saw_digit = true
        index = index + 1
    end

    local result = integer_part
    if str:sub(index, index) == "." then
        index = index + 1
        local fraction = 0
        local scale = 1
        while index <= #str do
            local digit = DIGIT_VALUE[str:sub(index, index)]
            if digit == nil then
                break
            end
            fraction = fraction * 10 + digit
            scale = scale * 10
            saw_digit = true
            index = index + 1
        end
        result = integer_part + fraction / scale
    end

    if not saw_digit then
        return nil
    end
    return sign * result
end

-- Parser state lives module-local during a single Json.decode call.
local source = ""
local had_error = false

local function fail()
    had_error = true
    return nil, #source + 1
end

local function skip_ws(i)
    while i <= #source do
        local c = source:sub(i, i)
        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            i = i + 1
        else
            break
        end
    end
    return i
end

local function decode_string(i)
    i = i + 1 -- skip opening quote
    local buffer = {}
    while i <= #source do
        local c = source:sub(i, i)
        if c == '"' then
            return table.concat(buffer), i + 1
        elseif c == '\\' then
            local nc = source:sub(i + 1, i + 1)
            buffer[#buffer + 1] = UNESCAPE_MAP[nc] or nc
            i = i + 2
        else
            buffer[#buffer + 1] = c
            i = i + 1
        end
    end
    return fail()
end

local function decode_number(i)
    local j = i
    while j <= #source do
        local c = source:sub(j, j)
        if c:match("[%d%+%-%.eE]") then
            j = j + 1
        else
            break
        end
    end
    local number = parse_number(source:sub(i, j - 1))
    if number == nil then
        return fail()
    end
    return (math.tointeger(number) or number), j
end

local decode_value -- forward declaration

local function decode_array(i)
    i = skip_ws(i + 1) -- skip [
    local array = {}
    if source:sub(i, i) == "]" then
        return array, i + 1
    end
    while true do
        local value
        value, i = decode_value(i)
        if had_error then
            return nil, i
        end
        array[#array + 1] = value
        i = skip_ws(i)
        local c = source:sub(i, i)
        if c == "," then
            i = skip_ws(i + 1)
        elseif c == "]" then
            return array, i + 1
        else
            return fail()
        end
    end
end

local function decode_object(i)
    i = skip_ws(i + 1) -- skip {
    local object = {}
    if source:sub(i, i) == "}" then
        return object, i + 1
    end
    while true do
        if source:sub(i, i) ~= '"' then
            return fail()
        end
        local key
        key, i = decode_string(i)
        if had_error then
            return nil, i
        end
        i = skip_ws(i)
        if source:sub(i, i) ~= ":" then
            return fail()
        end
        i = skip_ws(i + 1)
        local value
        value, i = decode_value(i)
        if had_error then
            return nil, i
        end
        object[key] = value
        i = skip_ws(i)
        local c = source:sub(i, i)
        if c == "," then
            i = skip_ws(i + 1)
        elseif c == "}" then
            return object, i + 1
        else
            return fail()
        end
    end
end

decode_value = function(i)
    i = skip_ws(i)
    local c = source:sub(i, i)
    if c == "{" then
        return decode_object(i)
    elseif c == "[" then
        return decode_array(i)
    elseif c == '"' then
        return decode_string(i)
    elseif c == "t" then
        if source:sub(i, i + 3) == "true" then
            return true, i + 4
        end
        return fail()
    elseif c == "f" then
        if source:sub(i, i + 4) == "false" then
            return false, i + 5
        end
        return fail()
    elseif c == "n" then
        if source:sub(i, i + 3) == "null" then
            return nil, i + 4
        end
        return fail()
    else
        return decode_number(i)
    end
end

---Decode a JSON string to a Lua value. Returns nil on empty/malformed input.
---@param str string
---@return any|nil value
function Json.decode(str)
    if type(str) ~= "string" or str == "" then
        return nil
    end
    source = str
    had_error = false
    local value = decode_value(1)
    source = ""
    if had_error then
        return nil
    end
    return value
end

-- Exposed so callers can parse numeric strings (e.g. JSON object keys that
-- are really integers) without the sandboxed global `tonumber`.
Json.parse_number = parse_number

return Json
