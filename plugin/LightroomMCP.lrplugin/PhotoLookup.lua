-- Photos are addressed on the wire by their Lightroom localIdentifier.
-- There's no documented direct lookup-by-id API, so we scan the catalog.
-- Fine for MVP catalog sizes; revisit with a cached index if this proves
-- slow on large catalogs.

local LrApplication = import 'LrApplication'

local PhotoLookup = {}

function PhotoLookup.byId(photoId)
    local catalog = LrApplication.activeCatalog()
    local target = tostring(photoId)
    for _, photo in ipairs(catalog:getAllPhotos()) do
        if tostring(photo.localIdentifier) == target then
            return photo
        end
    end
    return nil
end

function PhotoLookup.summary(photo)
    return {
        id = photo.localIdentifier,
        path = photo:getRawMetadata('path'),
        fileName = photo:getFormattedMetadata('fileName'),
    }
end

return PhotoLookup
