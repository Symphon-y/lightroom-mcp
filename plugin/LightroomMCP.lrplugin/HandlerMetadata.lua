local LrApplication = import 'LrApplication'

local PhotoLookup = require 'PhotoLookup'

local HandlerMetadata = {}

local RAW_FIELDS = {
    'rating', 'pickStatus', 'colorNameForLabel', 'dateCreated',
    'fileFormat', 'dimensions', 'gps', 'keywords', 'path',
}

function HandlerMetadata.getPhotoMetadata(params)
    local catalog = LrApplication.activeCatalog()
    local photo = PhotoLookup.byId(params.photoId)
    if not photo then
        error('Photo not found: ' .. tostring(params.photoId))
    end

    local raw = {}
    catalog:withReadAccessDo(function()
        for _, field in ipairs(RAW_FIELDS) do
            local ok, value = pcall(function() return photo:getRawMetadata(field) end)
            if ok and value ~= nil then
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
