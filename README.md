# lightroom-mcp

An MCP server for Adobe Lightroom Classic, built from scratch (not a fork),
for AI-assisted photo culling and catalog organization — with batch develop
editing planned as a later phase.

Built with [Automaat/lightroom-mcp](https://github.com/Automaat/lightroom-mcp)
(MIT) as an architectural reference only — no code copied from it. We wanted
a fully self-authored, auditable implementation with a guaranteed
local-only network story rather than trusting a third party's claims.

## Architecture

```
Claude (MCP client, stdio) <--stdio--> MCP server (Node/TypeScript)
                                           |  net.Socket (client) x2, 127.0.0.1 only
                                           v
                              Lightroom Classic Lua plugin
                              (LrSocket.bind, ports 58763/58764)
                                           |
                                           v
                              Lightroom Classic Catalog API
```

- `plugin/LightroomMCP.lrplugin` — the Lua plugin. Binds two localhost
  `LrSocket` servers: port `58763` (receives requests), port `58764` (sends
  responses). Never binds or connects anywhere other than `127.0.0.1`.
- `server/` — the MCP server (TypeScript/Node, `@modelcontextprotocol/sdk`).
  Connects to the plugin as a TCP client on both ports, correlates
  request/response by an `id` field, and exposes MCP tools over stdio to
  Claude.
- Protocol: newline-delimited JSON. Every message includes `hello: <token>`
  — a token generated locally when the server is started from Lightroom's
  Plug-in Manager and written to `~/.config/lightroom-mcp/token`, checked
  per-message on the plugin side.

## Status: Phase 1 (culling + organization)

Implemented tools: `get_selected_photos`, `get_photo_metadata`,
`set_rating`, `set_flag`, `set_keywords`, `search_photos`,
`list_collections`, `create_collection`, `add_to_collection`.

**Phase 2 (batch develop editing — presets, copying develop settings) is
not implemented yet.** It's the next milestone once Phase 1 is verified
working.

## Important: this has not been run against real Lightroom Classic yet

This scaffold was written from SDK documentation and research, not tested
against a live Lightroom Classic install (no Lightroom available in the
environment it was built in). Before trusting it with a real catalog:

1. Read through `plugin/LightroomMCP.lrplugin` and `server/src` yourself —
   confirm there is no outbound networking beyond `127.0.0.1:58763` /
   `127.0.0.1:58764`.
2. Expect to debug the Lua side against Lightroom's actual behavior,
   especially:
   - `HandlerSearch.lua`'s `catalog:findPhotos{searchDesc=...}` criteria
     names/operations — the least-documented part of the SDK; verify
     against the local SDK's API Reference once installed.
   - `Token.lua`'s use of `LrPathUtils.getStandardFilePath('home')`.
   - `Socket.lua`'s assumption that `LrSocket` delivers one fully-delimited
     message per `onMessage` callback in receive mode.
3. Confirm only localhost traffic ever appears (`netstat`) during a live
   session.

## Setup

1. Install Node.js 18+.
2. `cd server && npm install && npm run build`
3. Install the plugin into Lightroom:
   - Either run `node scripts/install-plugin.mjs`, or
   - Open Lightroom Classic > File > Plug-in Manager > Add, and select
     `plugin/LightroomMCP.lrplugin` directly (more reliable).
4. In Plug-in Manager, select "Lightroom MCP" and click "Start Server".
5. Register the MCP server with your client (e.g. Claude Code) pointing at
   `server/dist/index.js` (stdio transport).

## Environment variables (server)

- `LIGHTROOM_MCP_REQUEST_PORT` (default `58763`)
- `LIGHTROOM_MCP_RESPONSE_PORT` (default `58764`)
- `LIGHTROOM_MCP_TOKEN_PATH` (default `~/.config/lightroom-mcp/token`)
