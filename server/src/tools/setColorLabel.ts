import { z } from "zod";
import { defineTool } from "./types.js";

export const setColorLabel = defineTool({
  name: "set_color_label",
  description: "Set a photo's color label (used here to mark duplicate/near-duplicate groups that need a manual keep-one decision).",
  inputShape: {
    photoId: z.union([z.string(), z.number()]),
    label: z.enum(["red", "yellow", "green", "blue", "purple", "none"]),
  },
  action: "set_color_label",
});
