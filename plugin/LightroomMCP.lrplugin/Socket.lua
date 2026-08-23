-- Binds two localhost-only LrSocket servers: one the MCP server connects to
-- for sending requests (mode "receive"), one it connects to for reading
-- responses (mode "send"). LrSocket is unidirectional per bind, hence two
-- ports rather than one. Never binds to anything other than localhost.

local LrSocket = import 'LrSocket'
local LrTasks = import 'LrTasks'

local Log = require 'Log'
local Json = require 'Json'
local State = require 'State'
local Token = require 'Token'
local Dispatch = require 'Dispatch'

local REQUEST_PORT = 58763
local RESPONSE_PORT = 58764
local HEARTBEAT_INTERVAL = 30  -- seconds
local STALE_THRESHOLD = 90     -- seconds without traffic before we force a rebind

local Socket = {}

local function sendResponse(response)
    if State.responseSocket then
        State.responseSocket:send(Json.encode(response) .. '\n')
    end
end

local function handleLine(line)
    if line == '' then return end
    local ok, message = pcall(Json.decode, line)
    if not ok or type(message) ~= 'table' then
        Log.error('Socket: failed to decode message: %s', tostring(message))
        return
    end
    if message.hello ~= State.token then
        Log.warn('Socket: rejected message with invalid token')
        return
    end
    LrTasks.startAsyncTask(function()
        Dispatch.handle(message, sendResponse)
    end, 'LightroomMCP dispatch')
end

local function bindRequestSocket(context)
    State.requestSocket = LrSocket.bind {
        functionContext = context,
        plugin = _PLUGIN,
        port = REQUEST_PORT,
        mode = 'receive',
        onConnected = function()
            Log.info('Request socket connected on port %d', REQUEST_PORT)
            State.lastHeartbeat = os.time()
        end,
        onMessage = function(_, message)
            State.lastHeartbeat = os.time()
            -- LrSocket delivers one already-delimited message per callback
            -- in receive mode (the newline is the framing marker, consumed
            -- by the socket itself), so `message` is one full JSON line.
            handleLine(message)
        end,
        onClosed = function()
            Log.warn('Request socket closed')
        end,
        onError = function(_, err)
            Log.error('Request socket error: %s', tostring(err))
        end,
    }
end

local function bindResponseSocket(context)
    State.responseSocket = LrSocket.bind {
        functionContext = context,
        plugin = _PLUGIN,
        port = RESPONSE_PORT,
        mode = 'send',
        onConnected = function()
            Log.info('Response socket connected on port %d', RESPONSE_PORT)
            State.lastHeartbeat = os.time()
        end,
        onClosed = function()
            Log.warn('Response socket closed')
        end,
        onError = function(_, err)
            Log.error('Response socket error: %s', tostring(err))
        end,
    }
end

-- Windows does not reliably fire onClosed when a peer disconnects, so we
-- track our own heartbeat and force a rebind if things go stale rather than
-- trusting socket callbacks alone.
local function startHeartbeat(context)
    LrTasks.startAsyncTask(function()
        while State.running do
            LrTasks.sleep(HEARTBEAT_INTERVAL)
            if State.running and State.lastHeartbeat and (os.time() - State.lastHeartbeat) > STALE_THRESHOLD then
                Log.warn('Socket: connection looks stale, rebinding')
                Socket.stop()
                LrTasks.sleep(1)
                Socket.start(context)
                return
            end
        end
    end, 'LightroomMCP heartbeat')
end

function Socket.start(context)
    if State.running then
        Log.info('Socket.start: already running')
        return
    end
    State.token = Token.generate()
    State.lastHeartbeat = os.time()
    bindRequestSocket(context)
    bindResponseSocket(context)
    State.running = true
    startHeartbeat(context)
    Log.info('LightroomMCP server started (ports %d/%d)', REQUEST_PORT, RESPONSE_PORT)
end

function Socket.stop()
    if State.requestSocket then
        State.requestSocket:close()
        State.requestSocket = nil
    end
    if State.responseSocket then
        State.responseSocket:close()
        State.responseSocket = nil
    end
    State.running = false
    Log.info('LightroomMCP server stopped')
end

return Socket
