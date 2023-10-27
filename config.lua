local util = require 'plugins.evergreen.util'
local installer = require 'plugins.evergreen.installer'

local home = HOME or os.getenv 'HOME'

local M = {
	dataDir = PLATFORM ~= 'Windows'
			and ('~/.local/share/evergreen'):gsub('~', home)
			or string.format('%s\\evergreen', os.getenv 'APPDATA')
}

M.parserLocation = util.join { M.dataDir, 'parsers' }
M.queryLocation = util.join { M.dataDir, 'queries' }

-- add grammar
function M.addGrammar(options)
	installer.addGrammar(options, M)
end

return M
