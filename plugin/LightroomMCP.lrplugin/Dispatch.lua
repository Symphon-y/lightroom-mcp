local Log = require 'Log'

local HandlerSelection = require 'HandlerSelection'
local HandlerMetadata = require 'HandlerMetadata'
local HandlerOrganization = require 'HandlerOrganization'
local HandlerSearch = require 'HandlerSearch'
local HandlerCollections = require 'HandlerCollections'

local Dispatch = {}

-- Phase 1: culling + organization. Phase 2 (develop presets/settings) is
-- deliberately not wired up yet.
local ACTIONS = {
    ping = function() return { ok = true } end,
    get_selected_photos = HandlerSelection.getSelectedPhotos,
    get_photo_metadata = HandlerMetadata.getPhotoMetadata,
    set_rating = HandlerOrganization.setRating,
    set_flag = HandlerOrganization.setFlag,
    set_keywords = HandlerOrganization.setKeywords,
    search_photos = HandlerSearch.searchPhotos,
    list_collections = HandlerCollections.listCollections,
    create_collection = HandlerCollections.createCollection,
    add_to_collection = HandlerCollections.addToCollection,
}

-- request: { hello, id, action, params }. reply(response) sends the result
-- back over the response socket; response is { id, ok, result } or
-- { id, ok = false, error }.
function Dispatch.handle(request, reply)
    local action = ACTIONS[request.action]
    if not action then
        reply { id = request.id, ok = false, error = 'Unknown action: ' .. tostring(request.action) }
        return
    end

    local ok, result = pcall(action, request.params or {})
    if ok then
        reply { id = request.id, ok = true, result = result }
    else
        Log.error('Dispatch: action %s failed: %s', tostring(request.action), tostring(result))
        reply { id = request.id, ok = false, error = tostring(result) }
    end
end

return Dispatch
