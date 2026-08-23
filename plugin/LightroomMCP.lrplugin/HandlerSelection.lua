local LrApplication = import 'LrApplication'

local PhotoLookup = require 'PhotoLookup'

local HandlerSelection = {}

function HandlerSelection.getSelectedPhotos(params)
    local catalog = LrApplication.activeCatalog()
    -- getTargetPhotos() must be called outside withReadAccessDo: doing it
    -- inside deadlocks on Windows.
    local photos = catalog:getTargetPhotos()
    local out = {}
    for i, photo in ipairs(photos) do
        out[i] = PhotoLookup.summary(photo)
    end
    return { photos = out }
end

return HandlerSelection
