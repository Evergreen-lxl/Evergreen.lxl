local home = HOME or os.getenv 'HOME'

local M = {
	parserLocation = PLATFORM ~= 'Windows'
	and ('~/.local/share/evergreen/parsers'):gsub('~', home)
	or string.format('%s\\evergreen\\parsers', os.getenv 'APPDATA')
}

return M
