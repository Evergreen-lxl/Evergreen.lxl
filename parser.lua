local core = require 'core'
local ts = require 'libraries.tree_sitter'
local M = {
	_parsers = {}
}

function M.get(ftype)
	if not ftype then return end
	if M._parsers[ftype] then return M._parsers[ftype] end

	local ok, lang = pcall(ts.Language.require, ftype)
	local parser

	if not ok then
		core.error(string.format('Could not load parser for %s\n%s', ftype, result))
		return nil
	else
		core.log(string.format('Loaded parser for %s', ftype))
		parser = ts.Parser.new()
		parser:set_language(lang)
		M._parsers[ftype] = parser
	end

	return parser
end

function M.input(lines)
	return function(_, point)
		if point:row() < #lines then
			return lines[point:row() + 1], point:column() + 1
		else
			return nil
		end
	end
end

return M
