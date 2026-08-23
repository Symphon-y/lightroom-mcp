local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs = import 'LrPrefs'

local Log = require 'Log'
local State = require 'State'
local Socket = require 'Socket'

local prefs = LrPrefs.prefsForPlugin()
if prefs.autoStartServer == nil then
    prefs.autoStartServer = true
end

if prefs.autoStartServer and not State.running then
    -- A task started with the init script's own function context gets
    -- cancelled mid-sleep once LrInitPlugin returns, so it needs its own
    -- context via postAsyncTaskWithContext rather than a bare async task.
    LrFunctionContext.postAsyncTaskWithContext('LightroomMCP init', function(context)
        Socket.start(context)
    end)
end

Log.info('LightroomMCP plugin initialized')
