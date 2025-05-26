-- mod-version:3 --priority:200

local core = require 'core'
local command = require 'core.command'
local Doc = require 'core.doc'
local Highlight = require 'core.doc.highlighter'
local highlights = require 'plugins.evergreen.highlights'
local util = require 'plugins.evergreen.util'
local ts = require 'libraries.tree_sitter'
require 'plugins.evergreen.style'


--- @class core.doc
--- @field treesit boolean
--- @field ts table

local oldDocNew = Doc.new
function Doc:new(filename, abs_filename, new_file)
	oldDocNew(self, filename, abs_filename, new_file)
	highlights.init(self)

	self.lenAccul = { #self.lines[1] }
	self.lenAcculIdx = 1
end

function Doc:invalidateLen(idx)
	if not idx or idx == 1 then
		self.lenAccul[1] = #self.lines[1]
		self.lenAcculIdx = 1
		return
	end

	if self.lenAcculIdx <= idx then return end

	self.lenAcculIdx = idx - 1
end

function Doc:lenLines(s, e)
	if e < s then return 0 end

	if self.lenAcculIdx < e then
		for i = self.lenAcculIdx + 1, e do
			self.lenAccul[i] = self.lenAccul[i - 1] + #self.lines[i]
		end

		self.lenAcculIdx = e
	end

	return s == 1 and self.lenAccul[e] or self.lenAccul[e] - self.lenAccul[s - 1]
end

local function reparseStep(doc)
	local newTree = doc.ts.parser:parse(doc.ts.tree, util.input(doc.lines))

	if not newTree then return true end

	if newTree then
		doc.ts.tree = newTree
		doc.ts.reparse = false
		doc.ts.running = false

		doc.highlighter:reset()
	end
end

local oldDocInsert = Doc.raw_insert
function Doc:raw_insert(line, col, text, undo, time)
	oldDocInsert(self, line, col, text, undo, time)

	if self.treesit then
		self:invalidateLen(line)

		line, col = self:sanitize_position(line, col)

		local tsByte = self:lenLines(1, line - 1) + col - 1
		local tsLine, tsCol = line - 1, col - 1

		self.ts.tree:edit(
			--[[start_byte   ]] tsByte,
			--[[old_end_byte ]] tsByte,
			--[[new_end_byte ]] tsByte + #text,
			--[[start_point  ]] ts.Point.new(tsLine, tsCol),
			--[[old_end_point]] ts.Point.new(tsLine, tsCol),
			--[[new_end_point]] ts.Point.new(tsLine, tsCol + #text)
		)

		self.ts.reparse = true
		self.ts.parser:reset()
		-- try parsing once immediately, so if the document is not too large,
		-- the highlighting can updated before the next frame
		reparseStep(self) 
	end
end

local function sortPositions(line1, col1, line2, col2)
	if line1 > line2 or line1 == line2 and col1 > col2 then
		return line2, col2, line1, col1
	end
	return line1, col1, line2, col2
end

local oldDocRemove = Doc.raw_remove
function Doc:raw_remove(line1, col1, line2, col2, undo, time)
	if self.treesit then
		line1, col1 = self:sanitize_position(line1, col1)
		line2, col2 = self:sanitize_position(line2, col2)
		line1, col1, line2, col2 = sortPositions(line1, col1, line2, col2)

		local len = line1 == line2 and
			col2 - col1 or
			#self.lines[line1] - col1 + self:lenLines(line1 + 1, line2 - 1) + col2

		oldDocRemove(self, line1, col1, line2, col2, undo, time)
		self:invalidateLen(line1)

		local tsByte = self:lenLines(1, line1 - 1) + col1 - 1

		self.ts.tree:edit(
			--[[start_byte   ]] tsByte,
			--[[old_end_byte ]] tsByte + len,
			--[[new_end_byte ]] tsByte,
			--[[start_point  ]] ts.Point.new(line1 - 1, col1 - 1),
			--[[old_end_point]] ts.Point.new(line2 - 1, col2 - 1),
			--[[new_end_point]] ts.Point.new(line1 - 1, col1 - 1)
		)

		self.ts.reparse = true
		self.ts.parser:reset()
		reparseStep(self)
	else
		oldDocRemove(self, line1, col1, line2, col2, undo, time)
	end
end

local oldDocReload = Doc.reload
function Doc:reload()
	oldDocReload(self)

	if self.treesit then
		self:invalidateLen()
		self.ts.tree = self.ts.parser:parse_with(util.input(self.lines))
	end
end

local oldStart = Highlight.start
function Highlight:start(...)
	local doc = self.doc

	if not doc.treesit then return oldStart(self, ...) end
	if not doc.ts.reparse then return end

	if not doc.ts.running then
		doc.ts.running = true

		core.add_thread(function()
			while reparseStep(doc) do
				coroutine.yield(0)
			end
		end, doc)
	end

	doc.ts.parser:reset()
end

local oldTokenize = Highlight.tokenize_line
function Highlight:tokenize_line(idx, state)
	if not self.doc.treesit then return oldTokenize(self, idx, state) end
	
	local txt      = self.doc.lines[idx]
	local row      = idx - 1
	local toks     = {}
	local buf      = { 'normal', #txt }
	local startBuf = 0
	state = state or string.char(0)

	local cursor = ts.Query.Cursor.new(self.doc.ts.query, self.doc.ts.tree:root_node())
	cursor:set_point_range(ts.Point.new(row, 0), ts.Point.new(row, #txt - 1))

	for capture in self.doc.ts.runner:iter_captures(cursor) do
		local node = capture:node()
		local name = capture:name()

		if name:find('_', 1, true) then goto continue end

		local startPt = node:start_point()
		local endPt   = node:end_point()

		if row > endPt:row() then goto continue end
		if row < startPt:row() then break end

		local startPos = startPt:row() < row and 1 or startPt:column() + 1
		local endPos   = endPt:row() > row and #txt or endPt:column()

		local i = #buf - 1
		while i >= 1 and buf[i + 1] < startPos do
			local e = buf[i + 1]
			toks[#toks + 1] = buf[i]
			toks[#toks + 1] = txt:sub(startBuf, e)
			startBuf = e + 1

			buf[i], buf[i + 1] = nil, nil
			i = i - 2
		end

		toks[#toks + 1] = buf[i]
		toks[#toks + 1] = txt:sub(startBuf, startPos - 1)
		startBuf = startPos

		buf[#buf + 1] = name
		buf[#buf + 1] = endPos

		::continue::
	end

	local i = #buf - 1
	for i = #buf - 1, 1, -2 do
		local e = buf[i + 1]
		toks[#toks + 1] = buf[i]
		toks[#toks + 1] = txt:sub(startBuf, e)
		startBuf = e + 1

		i = i - 2
	end
	
	return {
		init_state = state,
		state      = state,
		text       = txt,
		tokens     = toks
	}
end

command.add('core.docview!', {
	['evergreen:toggle-highlighting'] = function(dv)
		-- check for doc.ts to not toggle on docviews that are in unsupported languages
		if dv.doc.ts then
			dv.doc.treesit = not dv.doc.treesit
			dv.doc.highlighter:reset()
			dv.doc:invalidateLen()
		end
	end
})
