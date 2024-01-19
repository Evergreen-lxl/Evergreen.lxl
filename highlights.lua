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
	local function getSource(n)
		local startPt = n:start_point()
		local endPt   = n:end_point()
		local startRow, startCol = startPt.row + 1, startPt.column + 1
		local endRow, endCol     = endPt.row + 1, endPt.column

		if startRow == endRow then
			return doc.lines[startRow]:sub(startCol, endCol)
		end

		local lns = {}
		lns[1] = doc.lines[startRow]:sub(startCol)
		for i = startRow + 1, endRow - 1 do
			lns[#lns + 1] = doc.lines[i]
		end
		lns[#lns + 1] = doc.lines[endRow]:sub(1, endCol)

		return table.concat(lns)
	end

	if not doc.filename then return end

	local p = parser.get(languages.fromDoc(doc))
	if p then
		doc.treesit = true
		doc.ts = {
			parser = p,
			tree = p:parse_with(parser.input(doc.lines)),
			query = p:query(M.query(languages.fromDoc(doc))):with {
				['any-of?'] = function(t, ...)
					local src = getSource(t)
					for _, match in ipairs {...} do
						if src == match then return true end
					end
					return false
				end,
				['lua-match?'] = function(t, pattern)
					local src = getSource(t)
					local res = string.match(src, pattern)
					return res ~= nil
				end,
				['contains?'] = function(t, search)
					local n = t
					local res = string.find(getSource(n), search)
					if res then return true end

					while true do
						n = n:prev_named_sibling()
						if not n then break end

						local res = string.find(getSource(n), search)
						if res then
							return true
						end
					end
					return false
				end
			},
			mlNodes = {}
		}
	end
end

return M
