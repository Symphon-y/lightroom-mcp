-- Minimal JSON encode/decode for LightroomMCP's fixed message shapes.
-- The Lightroom Lua sandbox does not provide a JSON library or the standard
-- `io`/`os` string libraries needed by most third-party ones, so this is
-- self-contained rather than vendored.

local Json = {}

-- ===== Encode =====

local escapeMap = {
    ['\\'] = '\\\\',
    ['"'] = '\\"',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
}

local function escapeString(s)
    return (s:gsub('[%c\\"]', function(c)
        return escapeMap[c] or string.format('\\u%04x', c:byte())
    end))
end

local encodeValue

local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= 'number' then return false end
        n = n + 1
    end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return true, n
end

local function encodeTable(t)
    local ok, n = isArray(t)
    local parts = {}
    if ok then
        for i = 1, n do
            parts[#parts + 1] = encodeValue(t[i])
        end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    for k, v in pairs(t) do
        parts[#parts + 1] = '"' .. escapeString(tostring(k)) .. '":' .. encodeValue(v)
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

encodeValue = function(v)
    local t = type(v)
    if v == nil then
        return 'null'
    elseif t == 'boolean' then
        return v and 'true' or 'false'
    elseif t == 'number' then
        return tostring(v)
    elseif t == 'string' then
        return '"' .. escapeString(v) .. '"'
    elseif t == 'table' then
        if next(v) == nil then
            -- Ambiguous empty table -- Lua can't distinguish {} from [].
            -- Every value we actually send is a list (photos, collections,
            -- keywords, ...), never a freeform dict that happens to be
            -- empty, so default to an empty array. (Found live: an empty
            -- top-level collections list came back as {} and would have
            -- broken any consumer calling .map()/.length on it.)
            return '[]'
        end
        return encodeTable(v)
    else
        error('Json.encode: unsupported type ' .. t)
    end
end

function Json.encode(value)
    return encodeValue(value)
end

-- ===== Decode =====

local decodeValue

local function skipWhitespace(s, i)
    local _, e = s:find('^[ \t\r\n]*', i)
    return e + 1
end

local function decodeString(s, i)
    -- i points just after the opening quote.
    local out = {}
    while true do
        local c = s:sub(i, i)
        if c == '' then error('Json.decode: unterminated string') end
        if c == '"' then
            return table.concat(out), i + 1
        elseif c == '\\' then
            local n = s:sub(i + 1, i + 1)
            local map = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
            if map[n] then
                out[#out + 1] = map[n]
                i = i + 2
            elseif n == 'u' then
                local hex = s:sub(i + 2, i + 5)
                out[#out + 1] = utf8 and utf8.char(tonumber(hex, 16)) or ('\\u' .. hex)
                i = i + 6
            else
                error('Json.decode: bad escape \\' .. n)
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
end

local function decodeNumber(s, i)
    local numStr, e = s:match('^(-?%d+%.?%d*[eE]?[+-]?%d*)()', i)
    if not numStr then error('Json.decode: invalid number at ' .. i) end
    return tonumber(numStr), e
end

local function decodeArray(s, i)
    local out = {}
    i = skipWhitespace(s, i)
    if s:sub(i, i) == ']' then return out, i + 1 end
    while true do
        local v
        v, i = decodeValue(s, i)
        out[#out + 1] = v
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == ',' then
            i = skipWhitespace(s, i + 1)
        elseif c == ']' then
            return out, i + 1
        else
            error('Json.decode: expected , or ] at ' .. i)
        end
    end
end

local function decodeObject(s, i)
    local out = {}
    i = skipWhitespace(s, i)
    if s:sub(i, i) == '}' then return out, i + 1 end
    while true do
        i = skipWhitespace(s, i)
        if s:sub(i, i) ~= '"' then error('Json.decode: expected string key at ' .. i) end
        local key
        key, i = decodeString(s, i + 1)
        i = skipWhitespace(s, i)
        if s:sub(i, i) ~= ':' then error('Json.decode: expected : at ' .. i) end
        i = skipWhitespace(s, i + 1)
        local v
        v, i = decodeValue(s, i)
        out[key] = v
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == ',' then
            i = skipWhitespace(s, i + 1)
        elseif c == '}' then
            return out, i + 1
        else
            error('Json.decode: expected , or } at ' .. i)
        end
    end
end

decodeValue = function(s, i)
    i = skipWhitespace(s, i)
    local c = s:sub(i, i)
    if c == '"' then
        return decodeString(s, i + 1)
    elseif c == '{' then
        return decodeObject(s, i + 1)
    elseif c == '[' then
        return decodeArray(s, i + 1)
    elseif c == 't' and s:sub(i, i + 3) == 'true' then
        return true, i + 4
    elseif c == 'f' and s:sub(i, i + 4) == 'false' then
        return false, i + 5
    elseif c == 'n' and s:sub(i, i + 3) == 'null' then
        return nil, i + 4
    elseif c:match('[%-%d]') then
        return decodeNumber(s, i)
    else
        error('Json.decode: unexpected character at ' .. i .. ': ' .. tostring(c))
    end
end

function Json.decode(s)
    local value = decodeValue(s, 1)
    return value
end

return Json
