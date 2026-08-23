import { z } from "zod";
import { defineTool } from "./types.js";

export const setFlag = defineTool({
  name: "set_flag",
  description: "Set a photo's pick/reject flag for culling.",
  inputShape: {
    photoId: z.union([z.string(), z.number()]),
    flag: z.enum(["pick", "reject", "none"]),
  },
  action: "set_flag",
});
