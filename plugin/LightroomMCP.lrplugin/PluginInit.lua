local LrPrefs = import 'LrPrefs'

local Log = require 'Log'
local State = require 'State'
local Socket = require 'Socket'

local prefs = LrPrefs.prefsForPlugin()
if prefs.autoStartServer == nil then
    prefs.autoStartServer = true
end

if prefs.autoStartServer and not State.running then
    -- Socket.start() creates its own async task context internally, so it's
    -- safe to call directly here without wrapping it ourselves.
    Socket.start()
end

Log.info('LightroomMCP plugin initialized')
