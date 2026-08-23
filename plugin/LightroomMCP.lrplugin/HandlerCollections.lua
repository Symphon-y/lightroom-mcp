local LrApplication = import 'LrApplication'

local PhotoLookup = require 'PhotoLookup'

local HandlerCollections = {}

local function collectionSummary(collection)
    return {
        id = collection.localIdentifier,
        name = collection:getName(),
    }
end

function HandlerCollections.listCollections(params)
    local catalog = LrApplication.activeCatalog()

    local out = {}
    for i, collection in ipairs(catalog:getChildCollections()) do
        out[i] = collectionSummary(collection)
    end

    local sets = {}
    for i, set in ipairs(catalog:getChildCollectionSets()) do
        sets[i] = { id = set.localIdentifier, name = set:getName() }
    end

    return { collections = out, collectionSets = sets }
end

function HandlerCollections.createCollection(params)
    local catalog = LrApplication.activeCatalog()
    local collection
    catalog:withWriteAccessDo('Create Collection', function()
        collection = catalog:createCollection(params.name, nil, true)
    end)
    return collectionSummary(collection)
end

function HandlerCollections.addToCollection(params)
    local catalog = LrApplication.activeCatalog()

    local target
    for _, c in ipairs(catalog:getChildCollections()) do
        if tostring(c.localIdentifier) == tostring(params.collectionId) then
            target = c
            break
        end
    end
    if not target then error('Collection not found: ' .. tostring(params.collectionId)) end

    local photos = {}
    for i, photoId in ipairs(params.photoIds or {}) do
        local photo = PhotoLookup.byId(photoId)
        if not photo then error('Photo not found: ' .. tostring(photoId)) end
        photos[i] = photo
    end

    catalog:withWriteAccessDo('Add to Collection', function()
        target:addPhotos(photos)
    end)

    return { id = target.localIdentifier, added = #photos }
end

return HandlerCollections
