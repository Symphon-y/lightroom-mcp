local HandlerSelection = require 'HandlerSelection'
local HandlerMetadata = require 'HandlerMetadata'
local HandlerOrganization = require 'HandlerOrganization'
local HandlerSearch = require 'HandlerSearch'
local HandlerCollections = require 'HandlerCollections'
local HandlerPreview = require 'HandlerPreview'
local HandlerFolders = require 'HandlerFolders'

local Dispatch = {}

-- Phase 1: culling + organization. Phase 2 (develop presets/settings) is
-- deliberately not wired up yet.
local ACTIONS = {
    ping = function() return { ok = true } end,
    get_selected_photos = HandlerSelection.getSelectedPhotos,
    get_photo_metadata = HandlerMetadata.getPhotoMetadata,
    set_rating = HandlerOrganization.setRating,
    set_flag = HandlerOrganization.setFlag,
    set_color_label = HandlerOrganization.setColorLabel,
    set_keywords = HandlerOrganization.setKeywords,
    search_photos = HandlerSearch.searchPhotos,
    list_collections = HandlerCollections.listCollections,
    create_collection = HandlerCollections.createCollection,
    add_to_collection = HandlerCollections.addToCollection,
    get_photo_preview = HandlerPreview.getPhotoPreview,
    list_folders = HandlerFolders.listFolders,
    get_folder_photos = HandlerFolders.getFolderPhotos,
}

-- request: { hello, id, action, params }. reply(response) sends the result
-- back over the response socket; response is { id, ok, result } or
-- { id, ok = false, error }.
--
-- Deliberately no pcall here: most handlers call catalog APIs that yield
-- (getTargetPhotos, withReadAccessDo/withWriteAccessDo, findPhotos), and
-- Lightroom's embedded Lua 5.1 cannot yield across a pcall's C-call
-- boundary ("Yielding is not allowed within a C or metamethod call").
-- Errors are left to propagate to the caller, which handles them with
-- LrFunctionContext's addFailureHandler instead -- the SDK's actual
-- yield-safe error mechanism.
function Dispatch.handle(request, reply)
    local action = ACTIONS[request.action]
    if not action then
        reply { id = request.id, ok = false, error = 'Unknown action: ' .. tostring(request.action) }
        return
    end

    local result = action(request.params or {})
    reply { id = request.id, ok = true, result = result }
end

return Dispatch
