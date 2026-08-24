local LrApplication = import 'LrApplication'

local PhotoLookup = require 'PhotoLookup'

local HandlerFolders = {}

local MAX_LIMIT = 100
local DEFAULT_LIMIT = 40

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

-- Recursive (includeChildren = true) rather than direct-only, deliberately:
-- this catalog nests almost everything under date subfolders (e.g.
-- "Sherwood Forest Faire\2026\2026-03-08"), so a direct-only count on a
-- top-level shoot folder would misleadingly read as near-zero.
local function recursivePhotoCount(folder)
    return #folder:getPhotos(true)
end

function HandlerFolders.listFolders(params)
    local catalog = LrApplication.activeCatalog()
    local folders = allFolders(catalog)

    local includeEmpty = params.includeEmpty
    if includeEmpty == nil then includeEmpty = false end

    local out = {}
    for _, folder in ipairs(folders) do
        local photoCount = recursivePhotoCount(folder)
        if includeEmpty or photoCount > 0 then
            local parent = folder:getParent()
            table.insert(out, {
                path = folder:getPath(),
                name = folder:getName(),
                parentPath = parent and parent:getPath() or nil,
                photoCount = photoCount,
            })
        end
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
    local total = #photos

    local offset = params.offset or 0
    local limit = params.limit or DEFAULT_LIMIT
    if limit > MAX_LIMIT then limit = MAX_LIMIT end

    local out = {}
    for i = offset + 1, math.min(offset + limit, total) do
        table.insert(out, PhotoLookup.folderSummary(catalog, photos[i]))
    end

    return { total = total, offset = offset, photos = out }
end

return HandlerFolders
