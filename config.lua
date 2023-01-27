local util = require 'plugins.evergreen.util'
local home = HOME or os.getenv 'HOME'

local M = {
	dataDir = PLATFORM ~= 'Windows'
	and ('~/.local/share/evergreen'):gsub('~', home)
	or string.format('%s\\evergreen', os.getenv 'APPDATA')
}

M.parserLocation = util.join {M.dataDir, 'parsers'}

return M
