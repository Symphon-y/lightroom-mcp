import { z } from "zod";
import { defineTool } from "./types.js";

export const addToCollection = defineTool({
  name: "add_to_collection",
  description: "Add one or more photos (by id) to an existing collection.",
  inputShape: {
    collectionId: z.union([z.string(), z.number()]),
    photoIds: z.array(z.union([z.string(), z.number()])),
  },
  action: "add_to_collection",
});
