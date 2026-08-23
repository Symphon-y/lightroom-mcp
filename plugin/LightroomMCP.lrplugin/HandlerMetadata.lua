local LrApplication = import 'LrApplication'

local PhotoLookup = require 'PhotoLookup'

local HandlerMetadata = {}

-- Verified against the SDK's LrPhoto API reference (getRawMetadata throws
-- on an unknown key, so every entry here has to be a real one).
local RAW_FIELDS = {
    'rating', 'pickStatus', 'colorNameForLabel', 'dateTimeOriginal',
    'fileFormat', 'dimensions', 'gps', 'keywords', 'path',
}

function HandlerMetadata.getPhotoMetadata(params)
    local catalog = LrApplication.activeCatalog()
    local photo = PhotoLookup.byId(params.photoId)
    if not photo then
        error('Photo not found: ' .. tostring(params.photoId))
    end

    -- No pcall around the per-field reads: getRawMetadata can yield for
    -- some fields, and Lua can't yield across pcall's C-call boundary in
    -- Lightroom's embedded Lua 5.1. A genuinely invalid field name is a
    -- programmer error in RAW_FIELDS above, not something to swallow here.
    local raw = {}
    catalog:withReadAccessDo(function()
        for _, field in ipairs(RAW_FIELDS) do
            local value = photo:getRawMetadata(field)
            if value ~= nil then
                if field == 'keywords' and type(value) == 'table' then
                    local names = {}
                    for i, kw in ipairs(value) do
                        names[i] = kw:getName()
                    end
                    raw[field] = names
                else
                    raw[field] = value
                end
            end
        end
    end)

    return {
        id = photo.localIdentifier,
        fileName = photo:getFormattedMetadata('fileName'),
        metadata = raw,
    }
end

return HandlerMetadata
