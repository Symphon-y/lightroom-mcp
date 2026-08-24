import { getSelectedPhotos } from "./getSelectedPhotos.js";
import { getPhotoMetadata } from "./getPhotoMetadata.js";
import { setRating } from "./setRating.js";
import { setFlag } from "./setFlag.js";
import { setColorLabel } from "./setColorLabel.js";
import { setKeywords } from "./setKeywords.js";
import { searchPhotos } from "./searchPhotos.js";
import { listCollections } from "./listCollections.js";
import { createCollection } from "./createCollection.js";
import { addToCollection } from "./addToCollection.js";
import { listFolders } from "./listFolders.js";
import { getFolderPhotos } from "./getFolderPhotos.js";

// Phase 1: culling + organization. Phase 2 (develop presets/settings) is
// deliberately not added here yet.
export const tools = [
  getSelectedPhotos,
  getPhotoMetadata,
  setRating,
  setFlag,
  setColorLabel,
  setKeywords,
  searchPhotos,
  listCollections,
  createCollection,
  addToCollection,
  listFolders,
  getFolderPhotos,
];
