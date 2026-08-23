#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { Dispatcher } from "./dispatcher.js";
import { tools } from "./tools/index.js";

async function main() {
  const dispatcher = new Dispatcher();
  await dispatcher.connect();

  const server = new McpServer({
    name: "lightroom-mcp",
    version: "0.1.0",
  });

  for (const tool of tools) {
    server.tool(tool.name, tool.description, tool.inputShape, async (args: Record<string, unknown>) => {
      const result = await dispatcher.call(tool.action, args);
      return {
        content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }],
      };
    });
  }

  const transport = new StdioServerTransport();
  await server.connect(transport);

  process.on("SIGINT", () => {
    dispatcher.close();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error("[lightroom-mcp] fatal error:", err);
  process.exit(1);
});
