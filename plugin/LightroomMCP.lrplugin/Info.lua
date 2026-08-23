return {
    LrSdkVersion = 13.0,
    LrSdkMinimumVersion = 10.0,
    LrToolkitIdentifier = 'com.symphony.lightroommcp',
    LrPluginName = "Lightroom MCP",

    LrPluginInfoProvider = 'PluginInfoProvider.lua',
    LrInitPlugin = 'PluginInit.lua',
    LrShutdownPlugin = 'PluginShutdown.lua',
    LrShutdownApp = 'PluginShutdown.lua',

    -- Eager-load the plugin at Lightroom startup instead of lazily on first
    -- use, so the MCP server is available as soon as Lightroom is.
    LrForceInitPlugin = true,

    LrLibraryMenuItems = {
        {
            title = "Lightroom MCP: Show Status",
            file = "MenuShowStatus.lua",
        },
    },

    VERSION = { major = 0, minor = 1, revision = 0, build = 0 },
}
