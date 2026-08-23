import { z } from "zod";
import { defineTool } from "./types.js";

export const setKeywords = defineTool({
  name: "set_keywords",
  description: "Add and/or remove keywords on a photo.",
  inputShape: {
    photoId: z.union([z.string(), z.number()]),
    add: z.array(z.string()).optional(),
    remove: z.array(z.string()).optional(),
  },
  action: "set_keywords",
});
