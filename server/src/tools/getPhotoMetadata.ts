import { z } from "zod";
import { defineTool } from "./types.js";

export const getPhotoMetadata = defineTool({
  name: "get_photo_metadata",
  description: "Get metadata (rating, flag, keywords, and other fields) for a specific photo by id.",
  inputShape: {
    photoId: z.union([z.string(), z.number()]).describe("Lightroom localIdentifier of the photo"),
  },
  action: "get_photo_metadata",
});
