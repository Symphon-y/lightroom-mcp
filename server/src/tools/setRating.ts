import { z } from "zod";
import { defineTool } from "./types.js";

export const setRating = defineTool({
  name: "set_rating",
  description: "Set a photo's star rating (0-5). 0 clears the rating.",
  inputShape: {
    photoId: z.union([z.string(), z.number()]),
    rating: z.number().int().min(0).max(5),
  },
  action: "set_rating",
});
