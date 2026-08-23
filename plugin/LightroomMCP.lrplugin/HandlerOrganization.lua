local LrApplication = import 'LrApplication'

local PhotoLookup = require 'PhotoLookup'

local HandlerOrganization = {}

function HandlerOrganization.setRating(params)
    local catalog = LrApplication.activeCatalog()
    local photo = PhotoLookup.byId(params.photoId)
    if not photo then error('Photo not found: ' .. tostring(params.photoId)) end

    local rating = params.rating
    if rating ~= nil and (rating < 0 or rating > 5) then
        error('rating must be between 0 and 5')
    end

    catalog:withWriteAccessDo('Set Rating', function()
        photo:setRawMetadata('rating', (rating == 0) and nil or rating)
    end)

    return { id = photo.localIdentifier, rating = rating }
end

-- flag: "pick" | "reject" | "none" maps to Lightroom's pickStatus values.
local FLAG_VALUES = { pick = 1, none = 0, reject = -1 }

function HandlerOrganization.setFlag(params)
    local catalog = LrApplication.activeCatalog()
    local photo = PhotoLookup.byId(params.photoId)
    if not photo then error('Photo not found: ' .. tostring(params.photoId)) end

    local value = FLAG_VALUES[params.flag]
    if value == nil then
        error("flag must be one of 'pick', 'reject', 'none'")
    end

    catalog:withWriteAccessDo('Set Flag', function()
        photo:setRawMetadata('pickStatus', value)
    end)

    return { id = photo.localIdentifier, flag = params.flag }
end

function HandlerOrganization.setKeywords(params)
    local catalog = LrApplication.activeCatalog()
    local photo = PhotoLookup.byId(params.photoId)
    if not photo then error('Photo not found: ' .. tostring(params.photoId)) end

    local add = params.add or {}
    local remove = params.remove or {}

    catalog:withWriteAccessDo('Set Keywords', function()
        for _, name in ipairs(add) do
            local keyword = catalog:createKeyword(name, {}, true, nil, true)
            photo:addKeyword(keyword)
        end
        if #remove > 0 then
            local existing = photo:getRawMetadata('keywords') or {}
            for _, kw in ipairs(existing) do
                for _, name in ipairs(remove) do
                    if kw:getName() == name then
                        photo:removeKeyword(kw)
                    end
                end
            end
        end
    end)

    return { id = photo.localIdentifier }
end

return HandlerOrganization
