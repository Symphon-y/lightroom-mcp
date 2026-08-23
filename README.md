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

## Status: Phase 1 (culling + organization) — verified working

All 9 tools have been run end-to-end against a real Lightroom Classic
catalog (not just built/reviewed): `get_selected_photos`,
`get_photo_metadata`, `set_rating`, `set_flag`, `set_keywords`,
`search_photos` (rating-range filter), `list_collections`,
`create_collection`, `add_to_collection`. Confirmed live:

- Sockets bind and stay up on `127.0.0.1` only (checked with `netstat`).
- `Token.lua`'s `LrPathUtils.getStandardFilePath('home')` correctly
  resolves and the token file is created.
- `Socket.lua`'s assumption that `LrSocket` delivers one fully-delimited
  message per `onMessage` callback in receive mode holds.
- The client survives a transient plugin-side reconnect mid-session
  (fails the in-flight call fast with a clear error, auto-reconnects,
  succeeds on retry).

**Not yet exercised:** `search_photos`'s keyword and date-range criteria
(only the rating-range path has been tested against real `findPhotos`
behavior) — the field/operation names there are still the least-verified
part of the SDK usage. Worth a live check before relying on it.

## Status: `get_photo_preview` — verified working

A 10th tool, added after Phase 1: renders a downsized JPEG of a photo via
`LrExportSession` and returns it as an MCP `image` content block, so
Claude can actually see a photo (most of the library is RAW, which
Claude's file tools can't decode directly) — needed for real culling,
duplicate comparison, and edit assessment. Confirmed live end-to-end: a
real photo exported at 1024px/q0.75 came back as an 86KB JPEG in ~3s, the
`maxDimension` constraint was honored (contrary to some forum reports that
it isn't always, from a plugin script), and the rendered image was visibly
correct when inspected directly.

**Known limitation:** if the plugin connection drops between the export
completing and the response reaching the server (the same transient
reconnect noted above), the exported temp file is orphaned — the server
never received its path, so it can't clean it up. Observed live: a couple
of leftover folders under `%TEMP%\lightroom-mcp-previews\` after a
dropped connection during testing. Not a correctness problem (OS temp
dir, and it's bytes not catalog state), but worth a periodic sweep if this
becomes noticeable at real usage scale — not built yet.

**Phase 2 (batch develop editing — presets, copying develop settings) is
not implemented yet.** It's the next milestone.

## Bugs found and fixed during live verification

Kept here because they're the kind of thing a fresh read of the code
won't catch — all required actually running against real Lightroom:

- `LrSocket.bind{}` connections aren't self-healing; they need an
  explicit `:reconnect()` / rebind loop, not just a persistent bind
  (`Socket.lua`).
- Lightroom's embedded Lua 5.1 can't yield a coroutine across `pcall`'s
  C-call boundary, and several catalog APIs yield internally — replaced
  `pcall`-based error handling with `LrFunctionContext`'s
  `addFailureHandler` (`Dispatch.lua`, `Socket.lua`, `HandlerMetadata.lua`).
- `photo:getRawMetadata()` throws on an unrecognized field name (there is
  no `dateCreated` key; it's `dateTimeOriginal`) (`HandlerMetadata.lua`).
- Lua's `cond and a or b` ternary idiom silently breaks when `a` is
  `nil`/`false` — `(rating == 0) and nil or rating` always evaluated to
  `rating`, so clearing a rating actually sent a literal `0`, which
  Lightroom rejects (`HandlerOrganization.lua`).
- Empty Lua tables are ambiguous between `{}` and `[]` in JSON; every
  value this protocol sends is a list, so empty now encodes as `[]`
  (`Json.lua`).
- The TS client coupled its two TCP connections together (tearing down
  both if either's connection attempt failed), which raced against the
  plugin rebinding its response socket on every fresh request connection
  into a self-sustaining disconnect loop — decoupled them into
  independently-reconnecting sockets (`plugin-socket.ts`).

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
