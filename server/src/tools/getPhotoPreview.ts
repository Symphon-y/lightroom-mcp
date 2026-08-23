import { z } from "zod";
import { defineTool } from "./types.js";

// Not part of the generic `tools` array in tools/index.ts -- this one
// needs a custom result handler (image content block + temp file cleanup)
// instead of the generic JSON.stringify(result) text response the other
// tools use. Registered directly in index.ts.
export const getPhotoPreview = defineTool({
  name: "get_photo_preview",
  description:
    "Render and view a photo as a downsized JPEG, to visually assess it for culling, spotting duplicates, or judging edits. Returns the image plus compact metadata (filename, rating, flag).",
  inputShape: {
    photoId: z.union([z.string(), z.number()]),
    maxDimension: z.number().int().min(128).max(2048).optional(),
    quality: z.number().min(0.1).max(1).optional(),
  },
  action: "get_photo_preview",
});
