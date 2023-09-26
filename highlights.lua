local parser = require 'plugins.evergreen.parser'
local languages = require 'plugins.evergreen.languages'

local M = {
	predicates = {}
}

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

function M.addPredicate(name, func)
	M.predicates[name] = func
	M.predicates['not-' .. name] = function(t, ...) return not func(t, ...) end
end

M.addPredicate('any-of?', function(t, ...)
	local src = t:source()
	for _, match in ipairs {...} do
		if src == match then return true end
	end
	return false
end)
M.addPredicate('lua-match?', function(t, pattern)
	local src = t:source()
	local res = string.match(src, pattern)
	return res ~= nil
end)
M.addPredicate('contains?', function(t, search)
	local n = t
	local res = string.find(n:source(), search)
	if res then return true end

	while not done do
		n = n:prev_named_sibling()
		if not n then break end

		local res = string.find(n:source(), search)
		if res then
			return true
		end
	end
	return false
end)
M.addPredicate('has-ancestor?', function(t, ...)
	local c = t:create_cursor()
	local went = c:goto_parent()
	local n = c:current_node()

	while went do
		for _, typ in ipairs {...} do
			if n:type() == typ then return true end
		end

		went = c:goto_parent()
		n = c:current_node()
	end

	return false
end)
M.addPredicate('has-parent?', function(t, ...)
	local c = t:create_cursor()
	c:goto_parent()

	local n = c:current_node()
	for _, typ in ipairs {...} do
		if n:type() == typ then return true end
	end

	return false
end)

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
			query = p:query(M.query(languages.fromDoc(doc))):with(M.predicates),
			mlNodes = {}
		}
	end
end

return M
