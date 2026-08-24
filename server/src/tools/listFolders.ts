import { z } from "zod";
import { defineTool } from "./types.js";

export const listFolders = defineTool({
  name: "list_folders",
  description: "List every folder in the catalog (mirrors Lightroom's Library folder panel), with each folder's path, name, parent path, and recursive photo count (including subfolders).",
  inputShape: {
    includeEmpty: z.boolean().optional().describe("Include folders with zero photos (recursively). Default false."),
  },
  action: "list_folders",
});
