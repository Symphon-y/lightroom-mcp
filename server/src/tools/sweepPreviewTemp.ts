import { z } from "zod";
import { defineTool } from "./types.js";

// Not part of the generic `tools` array in tools/index.ts -- this tool
// never touches the Lightroom catalog (pure local temp-directory
// housekeeping under os.tmpdir()/lightroom-mcp-previews), so it doesn't go
// through the Lua round-trip at all. Registered directly in index.ts,
// same as get_photo_preview's special-casing but even simpler: no
// dispatcher.call() involved.
export const sweepPreviewTemp = defineTool({
  name: "sweep_preview_temp",
  description:
    "Delete orphaned preview temp directories under the OS temp dir left behind when a connection drops mid-export (get_photo_preview normally cleans up its own exports). Only removes directories older than the age threshold, so anything still in flight is left alone.",
  inputShape: {
    olderThanMinutes: z.number().min(0).optional().describe("Age threshold in minutes. Default 10."),
  },
  action: "sweep_preview_temp",
});
