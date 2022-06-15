-- mod-version:2 -- lite-xl 2.0
HOME = (HOME or os.getenv 'HOME') .. '/'
package.cpath = package.cpath .. ';' .. HOME .. '.luarocks/lib64/lua/5.4/?.so;'
.. HOME .. '.local/share/tree-sitter/parsers/tree-sitter-?/libtree-sitter-?.so;'
.. HOME .. '.local/share/tree-sitter/parsers/tree-sitter-?/parser.so'

local ltreesitter = require 'ltreesitter'
local core = require 'core'
local common = require 'core.common'
local Doc = require 'core.doc'
local Highlight = require 'core.doc.highlighter'

local function localPath()
   local str = debug.getinfo(2, 'S').source:sub(2)
   return str:match '(.*[/\\])'
end

local parsers = {}

-- get parser based on ext
-- todo: pass doc and make it get based on either ext or actual file type
local function getParser(ext)
	if parsers[ext] then return parsers[ext] end

	local ok, parser = pcall(ltreesitter.require, ext)

	if not ok then
		core.log(string.format('Could not load parser for %s', ext))
		print(ok, parser)
		return nil
	else
		core.log(string.format('Loaded parser for %s', ext))
		parsers[ext] = parser
	end

	return parser
end

--[[
for capture, capture_name in my_query:capture(tree:root()) do
	print(capture:source(), capture_name)
end

local function nodes(t)
	local treenode = t:root()
	local directChild = true
	local function yieldnode(node, nested)
		for n in node:named_children() do
			coroutine.yield(n, directChild)
			if n:named_child_count() ~= 0 then
				directChild = false
				yieldnode(n, true)
			end
			if not nested then
				directChild = true
			end
		end
	end

	return coroutine.wrap(function() yieldnode(treenode) end)
end
]]--

local function highlightQuery(ext)
	local ff = io.open(string.format('%s/queries/%s/highlights.scm', localPath(), ext))
	if not ff then
		return ""
	end

	local highlights = ff:read '*a'
	print(highlights)
	ff:close()

	return highlights
end

local oldDocNew = Doc.new
function Doc:new(filename, abs_filename, new_file)
	oldDocNew(self, filename, abs_filename, new_file)
	if filename then
		local ext = filename:match '^.+(%..+)$'
		if not ext then return end

		if ext:sub(2) == 'go' then
			self.ts = {parser = getParser 'go'}
		elseif ext:sub(2) == 'lua' then
			self.ts = {parser = getParser 'lua'}
		end

		if self.ts.parser then
			self.wholeDoc = table.concat(self.lines, '')
			self.treesit = true
			self.ts.tree = self.ts.parser:parse_string(self.wholeDoc)
			self.ts.query = self.ts.parser:query(highlightQuery(ext:sub(2)))
			self.ts.mlNodes = {}
		end
	end
end

local oldDocChange = Doc.on_text_change
function Doc:on_text_change(type)
	oldDocChange(self, type)
	if self.treesit then
		-- todo: use tree edit instead of reparsing
		print('change', type)
		self.wholeDoc = table.concat(self.lines, '')
		self.ts.tree = self.ts.parser:parse_string(self.wholeDoc)
	end
end

local oldTokenize = Highlight.tokenize_line
function Highlight:tokenize_line(idx, state)
	if not self.doc.treesit then return oldTokenize(self, idx, state) end

	local res = {}
	local i = idx - 1
	res.init_state = state
	res.text = self.doc.lines[idx]
	res.state = 0
	res.tokens = {}

	local linenodes = {}
	local gotline = false
	print(idx)
	local lastNode
	for n, nName in self.doc.ts.query:capture(self.doc.ts.tree:root()) do
		lastNode = (#linenodes ~= 0 and linenodes[#linenodes] or {})['node']
		local startPoint = n:start_point()
		local endPoint = n:end_point()

		if startPoint.row == i and endPoint.row == i then
			-- indentation pass
			if (startPoint.column > 1 or self.doc.lines[idx]:sub(0, startPoint.column):find('\t')) and gotline == false then
				table.insert(res.tokens, 'normal')
				table.insert(res.tokens, self.doc.lines[idx]:sub(0, startPoint.column))
			end

			if lastNode then
				local lnStartPoint = lastNode:start_point()
				local lnEndPoint = lastNode:end_point()

				if lnStartPoint.column == startPoint.column and lnEndPoint.column == endPoint.column then
					linenodes[#linenodes] = {node = n, name = nName}
					res.tokens[#res.tokens - 1] = nName
					res.tokens[#res.tokens] = n:source()
					goto continue
				end
				-- whitespace between cur and last node
				if startPoint.column - lnEndPoint.column >= 1 then
					table.insert(res.tokens, 'normal')
					-- todo: use whitespace from line
					table.insert(res.tokens, (' '):rep(startPoint.column - lnEndPoint.column))
				end
			end
			gotline = true
			table.insert(linenodes, {node = n, name = nName})
			table.insert(res.tokens, nName)
			table.insert(res.tokens, n:source())
		elseif gotline then
			break
		end

		::continue::
	end
	if lastNode then
		local lnEndPoint = lastNode:end_point()
		local endCol = lnEndPoint.column + 1
		if endCol < string.len(self.doc.lines[idx]) then
			print(endCol)
			table.insert(res.tokens, 'normal')
			table.insert(res.tokens, self.doc.lines[idx]:sub(endCol))
		end
	end

	print(common.serialize(res.tokens))

	return res
end
