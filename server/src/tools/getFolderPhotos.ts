import { z } from "zod";
import { defineTool } from "./types.js";

export const getFolderPhotos = defineTool({
  name: "get_folder_photos",
  description:
    "Get photos in a folder (by path, from list_folders), including subfolders by default. Each photo includes clustering-relevant fields (capture time, focal length, shutter speed, aperture, ISO, cropped dimensions, rating, flag, color label, keywords) so burst/duplicate clustering doesn't need a separate get_photo_metadata call per photo. Paginated: default 40 per page, hard cap 100 -- the per-photo payload is large enough that bigger pages can exceed the MCP response size limit, so a large folder needs several calls with offset/limit rather than one big one.",
  inputShape: {
    path: z.string(),
    includeSubfolders: z.boolean().optional(),
    offset: z.number().int().min(0).optional(),
    limit: z.number().int().min(1).max(100).optional(),
  },
  action: "get_folder_photos",
});
