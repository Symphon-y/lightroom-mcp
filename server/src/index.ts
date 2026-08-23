#!/usr/bin/env node
import { readFileSync, rmSync } from "node:fs";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { Dispatcher } from "./dispatcher.js";
import { tools } from "./tools/index.js";
import { getPhotoPreview } from "./tools/getPhotoPreview.js";

interface PhotoPreviewResult {
  path: string;
  exportDir: string;
  fileName: string;
  rating: number | null;
  pickStatus: number | null;
}

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

  // Special-cased, not part of the generic loop above: this is the only
  // tool that returns an image rather than JSON-as-text, and it needs to
  // read + clean up a temp file the Lua side exported.
  server.tool(
    getPhotoPreview.name,
    getPhotoPreview.description,
    getPhotoPreview.inputShape,
    async (args: Record<string, unknown>) => {
      const result = (await dispatcher.call(getPhotoPreview.action, args)) as PhotoPreviewResult;
      const imageBuffer = readFileSync(result.path);
      const base64 = imageBuffer.toString("base64");

      try {
        rmSync(result.exportDir, { recursive: true, force: true });
      } catch (err) {
        console.error("[lightroom-mcp] failed to clean up preview temp dir:", (err as Error).message);
      }

      return {
        content: [
          { type: "image" as const, data: base64, mimeType: "image/jpeg" },
          {
            type: "text" as const,
            text: JSON.stringify({
              fileName: result.fileName,
              rating: result.rating,
              pickStatus: result.pickStatus,
              approxBytes: imageBuffer.length,
            }),
          },
        ],
      };
    }
  );

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
