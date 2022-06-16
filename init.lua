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

		if self.ts and self.ts.parser then
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
	res.init_state = state
	res.text = self.doc.lines[idx]
	res.state = 0
	res.tokens = {}

	print(idx)


	local i = idx - 1
	local tokens = res.tokens
	local currentLine = self.doc.lines[idx]
	local lastNode, lastStartPoint, lastEndPoint
	for n, nName in self.doc.ts.query:capture(self.doc.ts.tree:root()) do
		local startPoint = n:start_point()
		local endPoint = n:end_point()

		if i > startPoint.row and i > endPoint.row then goto continue end
		if startPoint.row > i then break end

		if not lastNode and startPoint.column > 0 and i == startPoint.row then
			-- first node
				tokens[#tokens+1] = 'normal'
				tokens[#tokens+1] = currentLine:sub(1, startPoint.column)
		elseif lastNode and lastEndPoint.row == startPoint.row and startPoint.column - lastEndPoint.column > 0 then
			tokens[#tokens+1] = 'normal'
			tokens[#tokens+1] = currentLine:sub(lastEndPoint.column + 1, startPoint.column)
		end

		-- single line token
		if startPoint.row == endPoint.row then
			local append_idx =
				(lastNode and lastStartPoint.column == startPoint.column and lastEndPoint.column == endPoint.column) -- if the nodes overlap
					and (#tokens - 1) -- replace the old one
					or (#tokens + 1)  -- create a new token
			tokens[append_idx] = nName
			tokens[append_idx+1] = n:source()

		elseif i >= startPoint.row and i <= endPoint.row then
			tokens[#tokens+1] = nName
			if i == startPoint.row then
				tokens[#tokens+1] = currentLine:sub(startPoint.column + 1, -2) -- from node start to EOL
			elseif i == endPoint.row then
				tokens[#tokens+1] = currentLine:sub(1, endPoint.column) -- from line start to end of node
			else
				tokens[#tokens+1] = currentLine
			end
		end

		lastNode = n
		lastStartPoint = startPoint
		lastEndPoint = endPoint
		::continue::
	end

	if lastNode and i == lastEndPoint.row then
		tokens[#tokens+1] = 'normal'
		tokens[#tokens+1] = currentLine:sub(lastEndPoint.column + 1)
	end

	if not lastNode then
		tokens[#tokens+1] = 'normal'
		tokens[#tokens+1] = currentLine
	end

	print(common.serialize(tokens))
	return res
end
