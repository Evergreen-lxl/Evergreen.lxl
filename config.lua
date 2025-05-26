local common = require 'core.common'

local M = {
	useFallbackColors = true,
	warnFallbackColors = true,
	maxParseTime = 2000,
}

if PLATFORM ~= 'Windows' then
	M.soExt = '.so'
else
	M.soExt = '.dll'
end

return M
