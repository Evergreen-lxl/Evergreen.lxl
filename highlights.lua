local parser = require 'plugins.evergreen.parser'
local languages = require 'plugins.evergreen.languages'

local M = {}

local function localPath()
   local str = debug.getinfo(2, 'S').source:sub(2)
   return str:match '(.*[/\\])'
end

function M.query(ftype)
	local ff = io.open(string.format('%s/queries/%s/highlights.scm', localPath(), ftype))
	if not ff then
		return ""
	end

	local highlights = ff:read '*a'
	ff:close()

	return highlights
end

--- @param doc core.doc
function M.init(doc)
	if not doc.filename then return end

	local p = parser.get(languages.fromDoc(doc))
	if p then
		doc.treesit = true
		doc.ts = {
			parser = p,
			tree = p:parse_with(parser.input(doc.lines)),
			query = p:query(M.query(languages.fromDoc(doc))):with {
				['any-of?'] = function(t, ...)
					local src = t:source()
					for _, match in ipairs {...} do
						if src == match then return true end
					end
					return false
				end
			},
			mlNodes = {}
		}
	end
end

return M
