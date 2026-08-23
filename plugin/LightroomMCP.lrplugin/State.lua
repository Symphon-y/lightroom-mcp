-- Shared state kept on a namespaced global so it survives a plugin reload
-- (File > Plug-in Manager can re-execute this module). Without this, a
-- reload can lose track of an already-bound socket and block a rebind.

if not _G.LightroomMCP_State then
    _G.LightroomMCP_State = {
        running = false,
        requestSocket = nil,
        responseSocket = nil,
        token = nil,

        -- Connection tracking. LrSocket connections are not self-healing on
        -- their own -- onClosed/onError fire and then the socket just sits
        -- idle until something explicitly calls :reconnect() or rebinds it.
        receiveConnected = false,
        sendConnected = false,
        requestNeedsReconnect = false,
        responseNeedsRebind = false,
        responseNeedsReconnect = false,
        responseGen = 0,
        instanceId = 0,

        lastConnectedTime = nil,
        lastRequestTime = nil,
        inFlightRequests = 0,
        needsFullRestart = false,
        freshRestart = false,
    }
end

return _G.LightroomMCP_State
