local LrApplication = import 'LrApplication'

local PhotoLookup = require 'PhotoLookup'

local HandlerSearch = {}

local FLAG_VALUES = { pick = 1, none = 0, reject = -1 }

-- NOTE: the exact `criteria`/`operation` names accepted by
-- catalog:findPhotos{searchDesc=...} are the least-documented part of the
-- SDK we could confirm from research (Adobe's API reference isn't published
-- on the open web). The shape below follows what's commonly referenced in
-- community plugin code; verify field names against the local SDK's
-- "API Reference/modules/LrCatalog.html" once installed, and adjust if
-- findPhotos rejects a criterion.
function HandlerSearch.searchPhotos(params)
    local catalog = LrApplication.activeCatalog()

    local criteria = {}
    if params.rating then
        table.insert(criteria, {
            criteria = 'rating',
            operation = 'in',
            value = params.rating.min,
            value2 = params.rating.max,
        })
    end
    if params.flag then
        table.insert(criteria, { criteria = 'pickStatus', operation = '==', value = FLAG_VALUES[params.flag] })
    end
    if params.keyword then
        table.insert(criteria, { criteria = 'keywords', operation = 'any', value = params.keyword })
    end
    if params.dateFrom or params.dateTo then
        table.insert(criteria, {
            criteria = 'captureTime',
            operation = 'in',
            value = params.dateFrom,
            value2 = params.dateTo,
        })
    end

    local photos
    if #criteria == 0 then
        photos = catalog:getAllPhotos()
    else
        local searchDesc = #criteria == 1 and criteria[1] or { combine = 'intersect', unpack(criteria) }
        photos = catalog:findPhotos { searchDesc = searchDesc }
    end

    local out = {}
    for i, photo in ipairs(photos) do
        out[i] = PhotoLookup.summary(photo)
    end
    return { photos = out, count = #out }
end

return HandlerSearch
