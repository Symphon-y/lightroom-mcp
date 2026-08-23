import { defineTool } from "./types.js";

export const listCollections = defineTool({
  name: "list_collections",
  description: "List all collections and collection sets in the catalog.",
  inputShape: {},
  action: "list_collections",
});
