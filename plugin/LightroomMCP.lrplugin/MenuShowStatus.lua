local LrDialogs = import 'LrDialogs'

local State = require 'State'
local Token = require 'Token'

local message
if State.running then
    message = string.format('Running on ports 58763/58764.\nToken file: %s', Token.path())
else
    message = 'Not running. Open File > Plug-in Manager > Lightroom MCP to start it.'
end

LrDialogs.message('Lightroom MCP Status', message, 'info')
