local languages = require 'plugins.evergreen.languages'
local util = require 'plugins.evergreen.util'
local ts = require 'libraries.tree_sitter'

local M = {}

local function localPath()
	local str = debug.getinfo(2, 'S').source:sub(2)
	return str:match '(.*[/\\])'
end

local function predicatesFor(doc)
	local function getSource(n)
		local startPt = n:start_point()
		local endPt   = n:end_point()
		local startRow, startCol = startPt:row() + 1, startPt:column() + 1
		local endRow, endCol     = endPt:row() + 1, endPt:column() + 1

		return doc:get_text(startRow, startCol, endRow, endCol)
	end

	local function coerceToStr(n)
		if type(n) ~= 'string' then
			return getSource(n:one_node())
		else
			return n
		end
	end

	local predicates = {
		['eq?'] = function(ns, m)
			local str = coerceToStr(m)

			for _, n in ipairs(ns:nodes()) do
				if getSource(n) ~= str then return false end
			end
			return true
		end,

		['any-eq?'] = function(ns, m)
			local str = coerceToStr(m)

			for _, n in ipairs(ns:nodes()) do
				if getSource(n) == str then return true end
			end

			return false
		end,

		['match?'] = function(ns, s)
			local r = regex.compile(s)

			for _, n in ipairs(ns:nodes()) do
				if not r:cmatch(getSource(n), 0, 0) then return false end
			end

			return true
		end,

		['any-match?'] = function(ns, s)
			local r = regex.compile(s)

			for _, n in ipairs(ns:nodes()) do
				if r:cmatch(getSource(n), 0, 0) then return true end
			end

			return false
		end,

		['lua-match?'] = function(ns, p)
			for _, n in ipairs(ns:nodes()) do
				if not getSource(n):match(p) then return false end
			end

			return true
		end,

		['any-lua-match?'] = function(ns, p)
			for _, n in ipairs(ns:nodes()) do
				if getSource(n):match(p) then return true end
			end

			return false
		end,

		['contains?'] = function(ns, ...)
			local ts = {...}

			for _, n in ipairs(ns:nodes()) do
				local s = getSource(n)

				for _, t in ipairs(ts) do
					if not s:find(t, 1, true) then return false end
				end
			end

			return true
		end,

		['any-contains?'] = function(ns, ...)
			local ts = {...}

			for _, n in ipairs(ns:nodes()) do
				local s = getSource(n)

				for _, t in ipairs(ts) do
					if s:find(t, 1, true) then return true end
				end
			end

			return false
		end,

		['any-of?'] = function(ns, ...)
			local ts = {}
			for _, t in ipairs {...} do
				ts[t] = true
			end

			for _, n in ipairs(ns:nodes()) do
				if not ts[getSource(n)] then return false end
			end

			return true
		end,

		['has-ancestor?'] = function(n, ...)
			local ts = {}
			for _, t in ipairs {...} do
				ts[t] = true
			end

			local a = n:one_node():parent()
			while a do
				if ts[a:type()] then return true end
				a = a:parent()
			end

			return false
		end,

		['has-parent?'] = function(n, ...)
			local p = n:one_node():parent():type()

			for _, t in ipairs {...} do
				if p == t then return true end
			end

			return false
		end,

		['set!'] = function()
			-- dummy
		end,
	}

	local ret = {}

	for name, fn in pairs(predicates) do
		ret[name] = fn

		if name:sub(-1) == '?' then
			ret['not-' .. name] = function(...)
				return not fn(...)
			end
		end
	end

	return ret
end

local disabledCaptures = {
	'spell',
	'nospell',
}

--- @param doc core.doc
function M.init(doc)
	if not doc.filename then return end

	local langDef = languages.findDef(doc.abs_filename)
	if not langDef then return end

	local lang = languages.getLang(langDef)
	if not lang then return end

	local queryStr = languages.getQuery(langDef, 'highlights')
	if not queryStr then return end

	local query = ts.Query.new(lang, queryStr)
	for _, name in ipairs(disabledCaptures) do
		query:disable_capture(name)
	end

	local parser = ts.Parser.new()
	parser:set_language(lang)

	doc.treesit = true
	doc.ts = {
		parser = parser,
		tree = parser:parse(nil, util.input(doc.lines)),
		query = query,
		runner = ts.Query.Runner.new(predicatesFor(doc)),
	}
end


return M
