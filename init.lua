-- mod-version:2 -- lite-xl 2.0
local home = HOME or os.getenv 'HOME'
local function appendPaths(paths)
	for _, path in ipairs(paths) do
		package.cpath = package.cpath .. ';' .. path:gsub('~', home)
	end
end

appendPaths {
	'~/.luarocks/lib/lua/5.4/?.so',
	'~/.luarocks/lib64/lua/5.4/?.so',
	'~/.local/share/tree-sitter/parsers/tree-sitter-?/libtree-sitter-?.so',
	'~/.local/share/tree-sitter/parsers/tree-sitter-?/parser.so'
}

local ltreesitter = require 'ltreesitter'
local core = require 'core'
local common = require 'core.common'
local Doc = require 'core.doc'
local Highlight = require 'core.doc.highlighter'

local function localPath()
   local str = debug.getinfo(2, 'S').source:sub(2)
   return str:match '(.*[/\\])'
end

local function tru(tbl)
	local t = {}

	for _, k in ipairs(tbl) do
		t[k] = true
	end

	return t
end

local validExts = tru {
	'lua',
	'go'
}
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
	ff:close()

	return highlights
end

local function tsInput(lines)
	return function(_, point)
		return (point.row < #lines)
			and (lines[point.row + 1]:sub(point.column + 1)) or nil
	end
end

local oldDocNew = Doc.new
function Doc:new(filename, abs_filename, new_file)
	oldDocNew(self, filename, abs_filename, new_file)
	if filename then
		local ext = filename:match '^.+(%..+)$'
		if not ext then return end

		if validExts[ext:sub(2)] then
			self.ts = {parser = getParser(ext:sub(2))}
		end

		if self.ts and self.ts.parser then
			self.treesit = true
			self.ts.tree = self.ts.parser:parse_with(tsInput(self.lines))
			self.ts.query = self.ts.parser:query(highlightQuery(ext:sub(2)))
			self.ts.mlNodes = {}
		end
	end
end

function table.slice(tbl, first, last, step)
	local sliced = {}

	for i = first or 1, last or #tbl, step or 1 do
		sliced[#sliced+1] = tbl[i]
	end

	return sliced
end

local function accumulateLen(tbl)
	local len = 0

	for _, entry in ipairs(tbl) do
		len = len + entry:len()
	end

	return len
end

local oldDocInsert = Doc.raw_insert
function Doc:raw_insert(line, col, text, undo, time)
	oldDocInsert(self, line, col, text, undo, time)

	if self.treesit then
		line, col = self:sanitize_position(line, col)

		local lns = table.slice(self.lines, 1, line - 1)
		local start = accumulateLen(lns)

		local tsByte = start + col - 1
		local tsLine, tsCol = line - 1, col - 1

		self.ts.tree:edit_s {
			start_byte    = tsByte,
			old_end_byte  = tsByte,
			new_end_byte  = tsByte + text:len(),
			start_point   = { row = tsLine, column = tsCol },
			old_end_point = { row = tsLine, column = tsCol },
			new_end_point = { row = tsLine, column = tsCol + text:len() },
		}
		self.ts.tree = self.ts.parser:parse_with(tsInput(self.lines), self.ts.tree)

		self.highlighter:soft_reset()
	end
end

local function sortPositions(line1, col1, line2, col2)
	if line1 > line2 or line1 == line2 and col1 > col2 then
		return line2, col2, line1, col1
	end
	return line1, col1, line2, col2
end

-- TODO: appropriate this for delete
local oldDocRemove = Doc.raw_remove
function Doc:raw_remove(line1, col1, line2, col2, undo, time)
	if self.treesit then
		line1, col1 = self:sanitize_position(line1, col1)
		line2, col2 = self:sanitize_position(line2, col2)
		line1, col1, line2, col2 = sortPositions(line1, col1, line2, col2)
		local text = self:get_text(line1, col1, line2, col2)

		oldDocRemove(self, line1, col1, line2, col2, undo, time)

		local lns = table.slice(self.lines, 1, line1 - 1)
		local start = accumulateLen(lns)

		local tsByte = start + col1 - 1

		self.ts.tree:edit_s {
			start_byte    = tsByte,
			old_end_byte  = tsByte + text:len(),
			new_end_byte  = tsByte,
			start_point   = { row = line1 - 1, column = col1 - 1 },
			old_end_point = { row = line2 - 1, column = col2 - 1 },
			new_end_point = { row = line1 - 1, column = col1 - 1 },
		}
		self.ts.tree = self.ts.parser:parse_with(tsInput(self.lines), self.ts.tree)

		self.highlighter:soft_reset()
	else
		oldDocRemove(self, line1, col1, line2, col2, undo, time)
	end
end

local oldTokenize = Highlight.tokenize_line
function Highlight:tokenize_line(idx, state)
	if not self.doc.treesit then return oldTokenize(self, idx, state) end

	local function isBefore(curStart, prevEnd)
		return
			prevEnd.row > curStart.row or
			(prevEnd.row == curStart.row and prevEnd.column > curStart.column)
	end

	local res = {}
	res.init_state = state
	res.text = self.doc.lines[idx]
	res.state = 0
	res.tokens = {}

	local i = idx - 1
	local tokens = res.tokens
	local currentLine = self.doc.lines[idx]
	local lastNode, lastName, lastStartPoint, lastEndPoint
	for n, nName in self.doc.ts.query:capture(self.doc.ts.tree:root()) do
		local startPoint = n:start_point()
		local endPoint = n:end_point()

		if i > startPoint.row and i > endPoint.row then goto continue end
		if startPoint.row > i then break end

		if not lastNode and startPoint.column > 0 and i == startPoint.row then
			-- first node
				tokens[#tokens + 1] = 'normal'
				tokens[#tokens + 1] = currentLine:sub(1, startPoint.column)
		elseif lastNode and lastEndPoint.row == startPoint.row and startPoint.column - lastEndPoint.column > 0 then
			tokens[#tokens + 1] = 'normal'
			tokens[#tokens + 1] = currentLine:sub(lastEndPoint.column + 1, startPoint.column)
		end

		-- single line token
		if startPoint.row == endPoint.row then
			if lastNode and isBefore(startPoint, lastEndPoint) then
				if lastName ~= "error" then
					local append_idx = #tokens - 1
					tokens[append_idx] = nName
					tokens[append_idx + 1] = currentLine:sub(startPoint.column + 1, endPoint.column)
				else
					goto continue
				end
			else
				local append_idx = #tokens + 1
				tokens[append_idx] = nName
				tokens[append_idx + 1] = currentLine:sub(startPoint.column + 1, endPoint.column)
			end
		elseif i >= startPoint.row and i <= endPoint.row then
			if lastNode and lastName == "error" and isBefore(startPoint, lastEndPoint) then
				goto continue
			end

			if self.lines[idx] then
				self:invalidate(idx + 1)
				common.splice(self.lines, idx + 1, #self.lines - 1)
			end

			tokens[#tokens + 1] = nName
			if i == startPoint.row then
				tokens[#tokens + 1] = currentLine:sub(startPoint.column + 1, -2) -- from node start to EOL
			elseif i == endPoint.row then
				tokens[#tokens + 1] = currentLine:sub(1, endPoint.column) -- from line start to end of node
			else
				tokens[#tokens + 1] = currentLine
			end
		end

		lastNode = n
		lastName = nName
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

	return res
end
