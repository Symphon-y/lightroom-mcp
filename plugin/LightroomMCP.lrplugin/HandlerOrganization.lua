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

    -- 0 clears the rating (Lightroom's setRawMetadata rejects a literal 0
    -- rating -- "Invalid rating: 0" -- clearing requires passing nil).
    -- NOTE: `(rating == 0) and nil or rating` looks like it should do this
    -- but doesn't: Lua's and/or ternary idiom falls through to the `or`
    -- side whenever the `and` branch's value is itself nil/false, so that
    -- expression always evaluated to `rating` regardless of the condition.
    -- Found live: it silently passed 0 through and Lightroom rejected it.
    local ratingToSet = rating
    if rating == 0 then
        ratingToSet = nil
    end

    catalog:withWriteAccessDo('Set Rating', function()
        photo:setRawMetadata('rating', ratingToSet)
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

-- Valid colorNameForLabel values (confirmed via SDK research): red, yellow,
-- green, blue, purple, none. NOTE: reading an unlabeled photo returns
-- 'grey', but writing 'grey' is rejected -- clearing a label must use
-- 'none', not the value you'd get back from a read.
local VALID_COLOR_LABELS = { red = true, yellow = true, green = true, blue = true, purple = true, none = true }

function HandlerOrganization.setColorLabel(params)
    local catalog = LrApplication.activeCatalog()
    local photo = PhotoLookup.byId(params.photoId)
    if not photo then error('Photo not found: ' .. tostring(params.photoId)) end

    local label = params.label
    if not VALID_COLOR_LABELS[label] then
        error("label must be one of red, yellow, green, blue, purple, none")
    end

    catalog:withWriteAccessDo('Set Color Label', function()
        photo:setRawMetadata('colorNameForLabel', label)
    end)

    return { id = photo.localIdentifier, label = label }
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
