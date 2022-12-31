-- mod-version:3
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
local command = require 'core.command'
local Doc = require 'core.doc'
local Highlight = require 'core.doc.highlighter'

local languages = require 'plugins.evergreen.languages'
require 'plugins.evergreen.style'
require 'plugins.evergreen.installer'

local function localPath()
   local str = debug.getinfo(2, 'S').source:sub(2)
   return str:match '(.*[/\\])'
end

local parsers = {}

-- get parser based on ext
-- todo: pass doc and make it get based on either ext or actual file type
local function getParser(ext)
	if parsers[ext] then return parsers[ext] end

	local ok, result = pcall(ltreesitter.require, ext)

	if not ok then
		core.error(string.format('Could not load parser for %s\n%s', ext, result))
		return nil
	else
		core.log(string.format('Loaded parser for %s', ext))
		parsers[ext] = result
	end

	return result
end

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

		if languages.exts[ext:sub(2)] then
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

local function incrementalHighlight(doc)
	local old = doc.ts.tree
	doc.ts.tree = doc.ts.parser:parse_with(tsInput(doc.lines), doc.ts.tree)

	for _, p in ipairs(old:get_changed_ranges(doc.ts.tree)) do
		for i = p.start_point.row + 1, p.end_point.row + 1 do
			doc.highlighter.lines[i] = false
		end
		doc.highlighter:invalidate(p.start_point.row + 1)
	end
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
		incrementalHighlight(self)
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
		incrementalHighlight(self)
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
	for n, nName in self.doc.ts.query:capture(self.doc.ts.tree:root(), {
		row = i,
		column = 0
	}, {
		row = i,
		column = #currentLine - 1
	}) do
		local startPoint = n:start_point()
		local endPoint = n:end_point()

		if i > endPoint.row then goto continue end
		if i < startPoint.row then break end

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

command.add('core.docview!', {
	['evergreen:toggle-highlighting'] = function(dv)
		-- check for doc.ts to not toggle on docviews that are in unsupported languages
		if dv.doc.ts then
			dv.doc.treesit = not dv.doc.treesit
			dv.doc.highlighter:reset()
		end
	end
})
