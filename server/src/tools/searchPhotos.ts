import { z } from "zod";
import { defineTool } from "./types.js";

export const searchPhotos = defineTool({
  name: "search_photos",
  description: "Search/filter the catalog by rating range, flag, keyword, or capture date range.",
  inputShape: {
    rating: z.object({ min: z.number().min(0).max(5), max: z.number().min(0).max(5) }).optional(),
    flag: z.enum(["pick", "reject", "none"]).optional(),
    keyword: z.string().optional(),
    dateFrom: z.string().optional().describe("ISO date, e.g. 2026-01-01"),
    dateTo: z.string().optional().describe("ISO date, e.g. 2026-01-31"),
  },
  action: "search_photos",
});
