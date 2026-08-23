import { z } from "zod";
import { defineTool } from "./types.js";

export const getSelectedPhotos = defineTool({
  name: "get_selected_photos",
  description: "Get the currently selected photo(s) in Lightroom Classic's filmstrip/grid.",
  inputShape: {},
  action: "get_selected_photos",
});
