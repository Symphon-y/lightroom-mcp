local LrApplication = import 'LrApplication'

local PhotoLookup = require 'PhotoLookup'

local HandlerFolders = {}

-- Recursively collects every LrFolder in the catalog (top-level via
-- catalog:getFolders(), then descending through folder:getChildren()).
-- Shared by both handlers below so the tree is only walked once per call.
local function collectFolders(folders, out)
    for _, folder in ipairs(folders) do
        table.insert(out, folder)
        collectFolders(folder:getChildren(), out)
    end
end

local function allFolders(catalog)
    local out = {}
    collectFolders(catalog:getFolders(), out)
    return out
end

-- Case-insensitive path comparison: Windows paths are case-insensitive,
-- and getPath()'s trailing-separator behavior isn't documented, so trim
-- any trailing slash/backslash from both sides before comparing.
local function normalizePath(path)
    return (path or ''):gsub('[\\/]+$', ''):lower()
end

function HandlerFolders.listFolders(params)
    local catalog = LrApplication.activeCatalog()
    local folders = allFolders(catalog)

    local out = {}
    for i, folder in ipairs(folders) do
        local parent = folder:getParent()
        out[i] = {
            path = folder:getPath(),
            name = folder:getName(),
            parentPath = parent and parent:getPath() or nil,
        }
    end
    return { folders = out }
end

function HandlerFolders.getFolderPhotos(params)
    local catalog = LrApplication.activeCatalog()
    local folders = allFolders(catalog)

    local targetPath = normalizePath(params.path)
    local target
    for _, folder in ipairs(folders) do
        if normalizePath(folder:getPath()) == targetPath then
            target = folder
            break
        end
    end
    if not target then error('Folder not found: ' .. tostring(params.path)) end

    local includeSubfolders = params.includeSubfolders
    if includeSubfolders == nil then includeSubfolders = true end

    local photos = target:getPhotos(includeSubfolders)

    local out = {}
    for i, photo in ipairs(photos) do
        out[i] = PhotoLookup.summary(photo)
    end
    return { photos = out, count = #out }
end

return HandlerFolders
