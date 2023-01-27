local core = require 'core'
local ltreesitter = require 'ltreesitter'
local M = {
	_parsers = {}
}

function M.get(ftype)
	if not ftype then return end
	if M._parsers[ftype] then return M._parsers[ftype] end

	local ok, result = pcall(ltreesitter.require, ftype)

	if not ok then
		core.error(string.format('Could not load parser for %s\n%s', ftype, result))
		return nil
	else
		core.log(string.format('Loaded parser for %s', ftype))
		M._parsers[ftype] = result
	end

	return result
end

function M.input(lines)
	return function(_, point)
		return (point.row < #lines)
			and (lines[point.row + 1]:sub(point.column + 1)) or nil
	end
end

return M
