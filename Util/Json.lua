-- ============================================================
-- Util/Json.lua
-- Minimal JSON encode/decode for the booth save blob.
--
-- Sandbox notes: the Eggy VM has no global `tonumber`, so numbers are
-- parsed by hand; integers encode without a decimal point (Fix32-safe).
-- Object keys are sorted so encode output is deterministic (round-trip
-- equality). Json.decode returns nil on malformed input.
-- ============================================================

local Json = {}

-- ---------- encode ----------

local ESCAPE_MAP = {
    ['"'] = '\\"', ['\\'] = '\\\\',
    ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function quote(str)
    return '"' .. str:gsub('[\\"\n\r\t]', ESCAPE_MAP) .. '"'
end

local encode_value -- forward declaration

local function encode_table(t, out)
    -- A table is a JSON array only when its keys are exactly 1..n (n > 0).
    local count = 0
    local is_array = true
    for key in pairs(t) do
        if type(key) ~= "number" then
            is_array = false
        end
        count = count + 1
    end
    for index = 1, count do
        if t[index] == nil then
            is_array = false
        end
    end

    if is_array and count > 0 then
        out[#out + 1] = "["
        for index = 1, count do
            if index > 1 then out[#out + 1] = "," end
            encode_value(t[index], out)
        end
        out[#out + 1] = "]"
    else
        -- Sort keys so the output is stable regardless of pairs() order.
        local entries = {}
        for key, value in pairs(t) do
            entries[#entries + 1] = { tostring(key), value }
        end
        table.sort(entries, function(a, b) return a[1] < b[1] end)
        out[#out + 1] = "{"
        for index = 1, #entries do
            if index > 1 then out[#out + 1] = "," end
            out[#out + 1] = quote(entries[index][1]) .. ":"
            encode_value(entries[index][2], out)
        end
        out[#out + 1] = "}"
    end
end

encode_value = function(value, out)
    local value_type = type(value)
    if value_type == "number" then
        out[#out + 1] = tostring(math.tointeger(value) or value)
    elseif value_type == "string" then
        out[#out + 1] = quote(value)
    elseif value_type == "boolean" then
        out[#out + 1] = value and "true" or "false"
    elseif value_type == "table" then
        encode_table(value, out)
    else
        out[#out + 1] = "null"
    end
end

---@param value any
---@return string json
function Json.encode(value)
    local out = {}
    encode_value(value, out)
    return table.concat(out)
end

-- ---------- decode (errors on bad input; Json.decode catches with pcall) ----------

local UNESCAPE_MAP = {
    ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
    ['n'] = '\n', ['r'] = '\r', ['t'] = '\t', ['b'] = '\b', ['f'] = '\f',
}

local DIGITS = {
    ['0'] = 0, ['1'] = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4,
    ['5'] = 5, ['6'] = 6, ['7'] = 7, ['8'] = 8, ['9'] = 9,
}

-- Parse a numeric string without the (sandboxed-out) global `tonumber`.
-- Handles an optional '-' sign plus integer and fractional parts.
local function parse_number(str)
    local index, sign = 1, 1
    if str:sub(1, 1) == "-" then
        sign, index = -1, 2
    end

    local result, saw_digit = 0, false
    while DIGITS[str:sub(index, index)] do
        result = result * 10 + DIGITS[str:sub(index, index)]
        saw_digit, index = true, index + 1
    end

    if str:sub(index, index) == "." then
        index = index + 1
        local fraction, scale = 0, 1
        while DIGITS[str:sub(index, index)] do
            fraction = fraction * 10 + DIGITS[str:sub(index, index)]
            scale, saw_digit, index = scale * 10, true, index + 1
        end
        result = result + fraction / scale
    end

    if not saw_digit then
        error("invalid number")
    end
    return sign * result
end

local source = ""

local function skip_ws(i)
    while true do
        local c = source:sub(i, i)
        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            i = i + 1
        else
            return i
        end
    end
end

local decode_value -- forward declaration

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
    error("unterminated string")
end

local function decode_number(i)
    local j = i
    while source:sub(j, j):match("[%d%+%-%.eE]") do
        j = j + 1
    end
    local number = parse_number(source:sub(i, j - 1))
    return (math.tointeger(number) or number), j
end

local function decode_array(i)
    i = skip_ws(i + 1) -- skip [
    local array = {}
    if source:sub(i, i) == "]" then
        return array, i + 1
    end
    while true do
        local value
        value, i = decode_value(i)
        array[#array + 1] = value
        i = skip_ws(i)
        local c = source:sub(i, i)
        if c == "," then
            i = skip_ws(i + 1)
        elseif c == "]" then
            return array, i + 1
        else
            error("expected , or ]")
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
            error("expected object key")
        end
        local key
        key, i = decode_string(i)
        i = skip_ws(i)
        if source:sub(i, i) ~= ":" then
            error("expected colon")
        end
        local value
        value, i = decode_value(skip_ws(i + 1))
        object[key] = value
        i = skip_ws(i)
        local c = source:sub(i, i)
        if c == "," then
            i = skip_ws(i + 1)
        elseif c == "}" then
            return object, i + 1
        else
            error("expected , or }")
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
        if source:sub(i, i + 3) == "true" then return true, i + 4 end
        error("invalid literal")
    elseif c == "f" then
        if source:sub(i, i + 4) == "false" then return false, i + 5 end
        error("invalid literal")
    elseif c == "n" then
        if source:sub(i, i + 3) == "null" then return nil, i + 4 end
        error("invalid literal")
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
    local ok, value = pcall(decode_value, 1)
    source = ""
    if ok then
        return value
    end
    return nil
end

return Json
