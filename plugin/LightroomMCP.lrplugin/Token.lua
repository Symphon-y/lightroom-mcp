-- Local auth token: generated fresh each time the server is started, written
-- to a file only the local user can read, and checked per-message (not
-- per-connection) so a socket reconnect can't desync from the current token.

local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrUUID = import 'LrUUID'

local Log = require 'Log'

local Token = {}

local function tokenDir()
    return LrPathUtils.child(LrPathUtils.getStandardFilePath('home'), '.config/lightroom-mcp')
end

local function tokenPath()
    return LrPathUtils.child(tokenDir(), 'token')
end

function Token.generate()
    local raw = (LrUUID.generateUUID() .. LrUUID.generateUUID()):gsub('%-', ''):lower()
    local dir = tokenDir()
    if not LrFileUtils.exists(dir) then
        LrFileUtils.createAllDirectories(dir)
    end
    local path = tokenPath()
    local f = io.open(path, 'w')
    if not f then
        Log.error('Token.generate: could not open %s for writing', path)
        error('LightroomMCP: could not write token file at ' .. path)
    end
    f:write(raw)
    f:close()
    return raw
end

function Token.path()
    return tokenPath()
end

return Token
