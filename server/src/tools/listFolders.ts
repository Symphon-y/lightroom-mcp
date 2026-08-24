import { defineTool } from "./types.js";

export const listFolders = defineTool({
  name: "list_folders",
  description: "List every folder in the catalog (mirrors Lightroom's Library folder panel), with each folder's path, name, and parent path.",
  inputShape: {},
  action: "list_folders",
});
