local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrUUID = import 'LrUUID'

local PhotoLookup = require 'PhotoLookup'

local HandlerPreview = {}

local function tempExportDir(requestId)
    local base = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'lightroom-mcp-previews')
    return LrPathUtils.child(base, requestId)
end

-- Renders a small JPEG of one photo to a unique temp folder and hands back
-- its path (not the image bytes -- Lua has no base64 encoder, and the file
-- already sits on the same local machine as the Node server, so the server
-- reads and encodes it directly). The caller is responsible for deleting
-- exportDir once it's done reading the file.
function HandlerPreview.getPhotoPreview(params)
    local photo = PhotoLookup.byId(params.photoId)
    if not photo then error('Photo not found: ' .. tostring(params.photoId)) end

    local maxDimension = params.maxDimension or 1024
    local quality = params.quality or 0.75

    local exportDir = tempExportDir(LrUUID.generateUUID())
    LrFileUtils.createAllDirectories(exportDir)

    local exportSession = LrExportSession({
        photosToExport = { photo },
        exportSettings = {
            LR_export_destinationType = 'specificFolder',
            LR_export_destinationPathPrefix = exportDir,
            LR_export_useSubfolder = false,
            LR_format = 'JPEG',
            LR_jpeg_quality = quality,
            LR_size_doConstrain = true,
            LR_size_maxWidth = maxDimension,
            LR_size_maxHeight = maxDimension,
            LR_size_resizeType = 'wh',
            LR_size_units = 'pixels',
        },
    })

    exportSession:doExportOnCurrentTask()

    local exportedPath = nil
    for _, rendition in exportSession:renditions() do
        local success, pathOrMessage = rendition:waitForRender()
        if not success then
            error('Export failed: ' .. tostring(pathOrMessage))
        end
        exportedPath = pathOrMessage
        break -- exactly one photo was requested
    end

    if not exportedPath then
        error('Export produced no output file')
    end

    return {
        path = exportedPath,
        exportDir = exportDir,
        fileName = photo:getFormattedMetadata('fileName'),
        rating = photo:getRawMetadata('rating'),
        pickStatus = photo:getRawMetadata('pickStatus'),
    }
end

return HandlerPreview
