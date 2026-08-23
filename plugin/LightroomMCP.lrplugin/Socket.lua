-- Binds two localhost-only LrSocket servers: one the MCP server connects to
-- for sending requests (mode "receive"), one it connects to for reading
-- responses (mode "send"). LrSocket is unidirectional per bind, hence two
-- ports rather than one. Never binds to anything other than localhost.
--
-- IMPORTANT (learned by testing against real Lightroom): an LrSocket bound
-- with LrSocket.bind{} does NOT automatically keep listening after a client
-- disconnects or after onClosed/onError fires -- it just sits idle. It has
-- to be explicitly told to start listening again via socket:reconnect(), or
-- rebound from scratch. A first version of this file that skipped that
-- (assuming a persistent listener plus an occasional heartbeat check) bound
-- successfully but then silently went idle within ~10 seconds. This version
-- runs a single polling loop, inside the same async task the sockets were
-- bound in, that reacts to connection-state flags set by the socket
-- callbacks -- mirroring the control flow that Automaat/lightroom-mcp
-- (referenced during design) actually needed to keep a Windows LrSocket
-- alive.

local LrSocket = import 'LrSocket'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'

local Log = require 'Log'
local Json = require 'Json'
local State = require 'State'
local Token = require 'Token'
local Dispatch = require 'Dispatch'

local REQUEST_PORT = 58763
local RESPONSE_PORT = 58764
local POLL_INTERVAL = 0.2        -- seconds between loop iterations
local STALE_RECONNECT_SECONDS = 90   -- restart if idle this long with no in-flight request
local STALE_RESTART_HARD_CAP_SECONDS = 120  -- restart regardless of in-flight requests

local Socket = {}

local function sendResponse(response)
    if State.responseSocket then
        pcall(function() State.responseSocket:send(Json.encode(response) .. '\n') end)
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

    State.inFlightRequests = State.inFlightRequests + 1
    LrTasks.startAsyncTask(function()
        local ok2, err = pcall(Dispatch.handle, message, sendResponse)
        if not ok2 then
            Log.error('Socket: dispatch error: %s', tostring(err))
        end
        State.inFlightRequests = math.max(0, State.inFlightRequests - 1)
    end, 'LightroomMCP dispatch')
end

local function bindRequest(context)
    return LrSocket.bind {
        functionContext = context,
        plugin = _PLUGIN,
        port = REQUEST_PORT,
        mode = 'receive',
        onConnected = function()
            State.receiveConnected = true
            State.lastConnectedTime = os.time()
            State.lastRequestTime = nil
            if State.freshRestart then
                State.freshRestart = false
                Log.info('Request socket connected (post-restart)')
            else
                State.sendConnected = false
                State.responseNeedsRebind = true
                Log.info('Request socket connected')
            end
        end,
        onMessage = function(_, message)
            State.lastRequestTime = os.time()
            -- LrSocket delivers one already-delimited message per callback
            -- in receive mode (the newline is the framing marker, consumed
            -- by the socket itself), so `message` is one full JSON line.
            handleLine(message)
        end,
        onClosed = function()
            State.receiveConnected = false
            State.requestNeedsReconnect = true
            Log.warn('Request socket closed')
        end,
        onError = function(_, err)
            State.receiveConnected = false
            State.requestNeedsReconnect = true
            Log.warn('Request socket error: %s', tostring(err))
        end,
    }
end

-- The response socket is guarded by a generation counter: every rebind
-- increments State.responseGen, and each bound socket's callbacks check
-- isLive() before touching shared state, so a stale closure from a socket
-- that's already been superseded by a newer rebind can't clobber it.
local function bindResponse(context, myGen)
    local function isLive() return State.responseGen == myGen end
    return LrSocket.bind {
        functionContext = context,
        plugin = _PLUGIN,
        port = RESPONSE_PORT,
        mode = 'send',
        onConnected = function()
            if not isLive() then return end
            State.sendConnected = true
            Log.info('Response socket connected')
        end,
        onClosed = function()
            if not isLive() then return end
            State.sendConnected = false
            State.responseNeedsRebind = true
            Log.warn('Response socket closed (gen=%s)', tostring(myGen))
        end,
        onError = function(_, err)
            if not isLive() then return end
            State.sendConnected = false
            State.responseNeedsRebind = true
            Log.warn('Response socket error (gen=%s): %s', tostring(myGen), tostring(err))
        end,
    }
end

local function shouldRestartForStale(idleSeconds, inFlightRequests)
    if idleSeconds > STALE_RESTART_HARD_CAP_SECONDS then
        return true
    end
    return idleSeconds > STALE_RECONNECT_SECONDS and inFlightRequests == 0
end

-- Creates its own async task context internally, so callers don't need to
-- wrap this in their own postAsyncTaskWithContext -- just call Socket.start().
function Socket.start()
    if State.running then
        Log.info('Socket.start: already running')
        return
    end
    State.running = true
    State.token = Token.generate()

    State.instanceId = (State.instanceId or 0) + 1
    local instanceId = State.instanceId

    LrFunctionContext.postAsyncTaskWithContext('LightroomMCPServer', function(taskContext)
        taskContext:addCleanupHandler(function()
            if State.instanceId ~= instanceId then
                return -- superseded by a newer start; not our sockets to clean up
            end
            if State.requestSocket then
                pcall(function() State.requestSocket:close() end)
            end
            if State.responseSocket then
                pcall(function() State.responseSocket:close() end)
            end
            State.requestSocket = nil
            State.responseSocket = nil
            State.receiveConnected = false
            State.sendConnected = false
            State.token = nil
            Log.info('LightroomMCP server stopped')
        end)

        State.responseGen = State.responseGen + 1
        State.requestNeedsReconnect = false
        State.responseNeedsRebind = false

        State.requestSocket = bindRequest(taskContext)
        State.responseSocket = bindResponse(taskContext, State.responseGen)
        Log.info('LightroomMCP server started (ports %d/%d)', REQUEST_PORT, RESPONSE_PORT)

        while State.running and State.instanceId == instanceId do
            if State.requestNeedsReconnect and State.requestSocket then
                State.requestNeedsReconnect = false
                pcall(function() State.requestSocket:reconnect() end)
            end

            if State.responseNeedsRebind then
                State.responseGen = State.responseGen + 1
                local newGen = State.responseGen
                if State.responseSocket then
                    pcall(function() State.responseSocket:close() end)
                end
                State.sendConnected = false
                LrTasks.sleep(0.1)
                State.responseSocket = bindResponse(taskContext, newGen)
                State.responseNeedsRebind = false
                Log.info('Response socket rebound (gen=%d)', newGen)
            end

            if State.needsFullRestart then
                State.needsFullRestart = false
                State.running = false -- exits this loop; cleanup handler tears down sockets
                LrTasks.startAsyncTask(function()
                    Log.warn('Restarting server (stale connection recovery)')
                    LrTasks.sleep(0.5)
                    Socket.start()
                end, 'LightroomMCP restart')
            elseif State.receiveConnected then
                local ref = State.lastRequestTime or State.lastConnectedTime
                if ref then
                    local idle = os.time() - ref
                    if shouldRestartForStale(idle, State.inFlightRequests) then
                        Log.warn('Connection looks stale (%ds idle), scheduling restart', idle)
                        State.lastRequestTime = nil
                        State.lastConnectedTime = nil
                        State.needsFullRestart = true
                        State.freshRestart = true
                    end
                end
            end

            LrTasks.sleep(POLL_INTERVAL)
        end
    end)
end

function Socket.stop()
    State.running = false -- the running loop notices and its cleanup handler closes the sockets
end

return Socket
