#!/usr/bin/env node
import { readFileSync, rmSync, readdirSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { Dispatcher } from "./dispatcher.js";
import { tools } from "./tools/index.js";
import { getPhotoPreview } from "./tools/getPhotoPreview.js";
import { sweepPreviewTemp } from "./tools/sweepPreviewTemp.js";

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
        // Compact, not pretty-printed: this text is read by the model, not a
        // human, and pretty-printing roughly doubles payload size on
        // list-shaped results (get_folder_photos, list_folders) for no
        // benefit.
        content: [{ type: "text" as const, text: JSON.stringify(result) }],
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

  // Special-cased like getPhotoPreview, but simpler: this never touches
  // the Lightroom catalog at all (pure local temp-directory housekeeping),
  // so it doesn't call dispatcher.call()/go through the Lua plugin.
  server.tool(
    sweepPreviewTemp.name,
    sweepPreviewTemp.description,
    sweepPreviewTemp.inputShape,
    async (args: { olderThanMinutes?: number }) => {
      const olderThanMinutes = args.olderThanMinutes ?? 10;
      const cutoff = Date.now() - olderThanMinutes * 60_000;
      const root = join(tmpdir(), "lightroom-mcp-previews");

      let removed = 0;
      let entries: string[] = [];
      try {
        entries = readdirSync(root);
      } catch {
        // Root doesn't exist yet -- nothing to sweep.
      }

      for (const entry of entries) {
        const entryPath = join(root, entry);
        try {
          const stat = statSync(entryPath);
          if (stat.isDirectory() && stat.mtimeMs < cutoff) {
            rmSync(entryPath, { recursive: true, force: true });
            removed++;
          }
        } catch (err) {
          console.error(`[lightroom-mcp] failed to sweep ${entryPath}:`, (err as Error).message);
        }
      }

      return {
        content: [{ type: "text" as const, text: JSON.stringify({ removed }) }],
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
