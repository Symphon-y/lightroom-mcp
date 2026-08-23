// The Lightroom plugin binds two localhost LrSocket servers: one it
// receives requests on, one it sends responses on. We only ever connect to
// 127.0.0.1 — never 0.0.0.0 or a remote host — by design.
export const REQUEST_PORT = Number(process.env.LIGHTROOM_MCP_REQUEST_PORT ?? 58763);
export const RESPONSE_PORT = Number(process.env.LIGHTROOM_MCP_RESPONSE_PORT ?? 58764);
export const HOST = "127.0.0.1";
