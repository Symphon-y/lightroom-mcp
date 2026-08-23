import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const DEFAULT_TOKEN_PATH = join(homedir(), ".config", "lightroom-mcp", "token");

export function getToken(): string {
  const path = process.env.LIGHTROOM_MCP_TOKEN_PATH ?? DEFAULT_TOKEN_PATH;
  try {
    return readFileSync(path, "utf8").trim();
  } catch (err) {
    throw new Error(
      `Could not read Lightroom MCP token at ${path}. Start the server from ` +
        `Lightroom's Plug-in Manager first (this generates the token file). (${(err as Error).message})`
    );
  }
}
