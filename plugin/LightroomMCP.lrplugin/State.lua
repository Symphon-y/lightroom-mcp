-- Shared state kept on a namespaced global so it survives a plugin reload
-- (File > Plug-in Manager can re-execute this module). Without this, a
-- reload can lose track of an already-bound socket and block a rebind.

if not _G.LightroomMCP_State then
    _G.LightroomMCP_State = {
        running = false,
        requestSocket = nil,
        responseSocket = nil,
        token = nil,
        lastHeartbeat = nil,
    }
end

return _G.LightroomMCP_State
