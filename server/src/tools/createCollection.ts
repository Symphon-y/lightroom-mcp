import { z } from "zod";
import { defineTool } from "./types.js";

export const createCollection = defineTool({
  name: "create_collection",
  description: "Create a new top-level collection.",
  inputShape: {
    name: z.string(),
  },
  action: "create_collection",
});
