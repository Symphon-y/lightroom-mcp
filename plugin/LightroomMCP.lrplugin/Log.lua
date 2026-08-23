-- Thin wrapper around LrLogger so call sites don't repeat the import.
local LrLogger = import 'LrLogger'

local logger = LrLogger('LightroomMCP')
logger:enable('logfile')

local Log = {}

function Log.info(msg, ...)
    logger:infof(msg, ...)
end

function Log.warn(msg, ...)
    logger:warnf(msg, ...)
end

function Log.error(msg, ...)
    logger:errorf(msg, ...)
end

return Log
