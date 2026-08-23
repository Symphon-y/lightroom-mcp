local State = require 'State'
local Socket = require 'Socket'
local Token = require 'Token'

local PluginInfoProvider = {}

function PluginInfoProvider.sectionsForTopOfDialog(viewFactory, propertyTable)
    local statusText = State.running and 'Running (ports 58763/58764)' or 'Stopped'

    return {
        {
            title = 'Lightroom MCP',
            viewFactory:column {
                spacing = viewFactory:control_spacing(),
                viewFactory:static_text { title = 'Status: ' .. statusText },
                viewFactory:static_text { title = 'Token file: ' .. Token.path() },
                viewFactory:row {
                    spacing = viewFactory:control_spacing(),
                    viewFactory:push_button {
                        title = 'Start Server',
                        action = function()
                            Socket.start()
                        end,
                    },
                    viewFactory:push_button {
                        title = 'Stop Server',
                        action = function()
                            Socket.stop()
                        end,
                    },
                },
                viewFactory:static_text { title = 'Reopen Plug-in Manager to refresh status.' },
            },
        },
    }
end

return PluginInfoProvider
