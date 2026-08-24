import { z } from "zod";
import { defineTool } from "./types.js";

export const getFolderPhotos = defineTool({
  name: "get_folder_photos",
  description: "Get all photos in a folder (by path, from list_folders). Includes subfolders by default.",
  inputShape: {
    path: z.string(),
    includeSubfolders: z.boolean().optional(),
  },
  action: "get_folder_photos",
});
