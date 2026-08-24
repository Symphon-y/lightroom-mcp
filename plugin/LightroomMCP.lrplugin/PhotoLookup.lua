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

-- Verified against the SDK's LrPhoto API reference (getRawMetadata throws
-- on an unknown key, so every entry here has to be a real one) -- same
-- defensive whitelist pattern as HandlerMetadata.lua's RAW_FIELDS.
-- Used by get_folder_photos so duplicate/burst clustering can run off this
-- one call without a separate get_photo_metadata round-trip per photo.
local FOLDER_SUMMARY_FIELDS = {
    'dateTimeOriginal', 'focalLength', 'shutterSpeed', 'aperture', 'isoSpeedRating',
    'croppedDimensions', 'rating', 'pickStatus', 'colorNameForLabel', 'keywords',
}

function PhotoLookup.folderSummary(catalog, photo)
    local out = {
        id = photo.localIdentifier,
        path = photo:getRawMetadata('path'),
        fileName = photo:getFormattedMetadata('fileName'),
    }

    catalog:withReadAccessDo(function()
        for _, field in ipairs(FOLDER_SUMMARY_FIELDS) do
            local value = photo:getRawMetadata(field)
            if value ~= nil then
                if field == 'keywords' and type(value) == 'table' then
                    local names = {}
                    for i, kw in ipairs(value) do
                        names[i] = kw:getName()
                    end
                    out.keywords = names
                else
                    out[field] = value
                end
            end
        end
    end)

    return out
end

return PhotoLookup
