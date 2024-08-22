-- mod-version:3
local core = require 'core'
local config = require 'plugins.evergreen.config'
local util = require 'plugins.evergreen.util'
local home = HOME or os.getenv 'HOME'
local languages = require 'plugins.evergreen.languages'
local installer = require 'plugins.evergreen.installer'

local function appendPaths(paths)
	for _, path in ipairs(paths) do
		package.cpath = package.cpath .. ';' .. path:gsub('~', home)
	end
end

system.mkdir(config.dataDir)
system.mkdir(config.parserLocation)
system.mkdir(config.queryLocation)

appendPaths {
	util.join { config.dataDir, '?' .. util.soname },
	util.join { config.parserLocation, '?', 'libtree-sitter-?' .. util.soname },
	util.join { config.parserLocation, '?', 'parser' .. util.soname },
}

if PLATFORM ~= 'Windows' then
	appendPaths {
		'~/.local/share/tree-sitter/parsers/tree-sitter-?/libtree-sitter-?' .. util.soname,
		'~/.local/share/tree-sitter/parsers/tree-sitter-?/parser' .. util.soname
	}
end

local function exec(cmd, opts)
	local proc = process.start(cmd, opts or {})
	if proc then
		while proc:running() do
			coroutine.yield(0.1)
		end
		return (proc:read_stdout() or '<no stdout>\n') .. (proc:read_stderr() or '<no stderr>'), proc:returncode()
	end

	return nil
end
local common = require 'core.common'
local command = require 'core.command'
local Doc = require 'core.doc'
local Highlight = require 'core.doc.highlighter'

local parser = require 'plugins.evergreen.parser'
local highlights = require 'plugins.evergreen.highlights'
require 'plugins.evergreen.style'

local ts = require 'libraries.tree_sitter'

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

local function incrementalHighlight(doc, row)
	local old = doc.ts.tree
	doc.ts.tree = doc.ts.parser:parse(doc.ts.tree, parser.input(doc.lines))

	for _, r in ipairs(ts.Tree.get_changed_ranges(old, doc.ts.tree):to_table()) do
		local startRow = r:start_point():row() + 1
		local endRow   = r:end_point():row() + 1

		for i = startRow, endRow do
			doc.highlighter.lines[i] = false
		end
		doc.highlighter:invalidate(startRow)
	end

	local cursor = ts.Query.Cursor.new(doc.ts.query, doc.ts.tree:root_node())
	cursor:set_point_range(
		ts.Point.new(row - 1, 0),
		ts.Point.new(row - 1, #doc.lines[row] - 1)
	)

	for capture in doc.ts.runner:iter_captures(cursor) do
		local node     = capture:node()
		local startRow = node:start_point():row() + 1
		local endRow   = node:end_point():row() + 1

		for i = startRow, endRow do
			doc.highlighter.lines[i] = false
		end
		doc.highlighter:invalidate(startRow)
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
		incrementalHighlight(self, line)
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
		incrementalHighlight(self, line1)
	else
		oldDocRemove(self, line1, col1, line2, col2, undo, time)
	end
end

local oldDocReload = Doc.reload
function Doc:reload()
	oldDocReload(self)

	if self.treesit then
		self:invalidateLen()
		self.ts.tree = self.ts.parser:parse_with(parser.input(self.lines))
	end
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

		local i        = #buf - 1
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

command.add(nil, {
	['evergreen:status'] = function()
		local notInstalled = {}
		local installed = {}
		local errorCounter = 0
		for lang, options in pairs(languages.grammars) do
			local lib = util.join { config.parserLocation, lang, 'parser.so' }
			local queries = util.join { config.queryLocation, lang, 'highlights.scm' }
			if not util.exists(lib) or not util.exists(queries) then
				errorCounter = errorCounter + 1
				table.insert(notInstalled, lang)
			else
				local str = ' - ' .. lang .. ': '
				if options.filePatterns ~= nil then
					for _, ext in pairs(options.filePatterns) do
						str = str .. ext .. ' '
					end
				end
				str = str .. ' '
				table.insert(installed, str)
			end
		end
		core.log('[Evergreen] Installed grammars:\n%s', table.concat(installed, '\n'))
		if errorCounter > 0 then
			core.warn('[Evergreen] grammars not operational:\n%s', table.concat(notInstalled, '\n'))
		end
	end
})


local exts = {}

for k, _ in pairs(languages.grammars) do
	table.insert(exts, k)
end


command.add(nil, {
	['evergreen:update-all'] = function()
		for lang, options in pairs(languages.grammars) do
			core.log('[Evergreen] updating grammar for language "%s"', lang)
			installer.installGrammar(options, config)
		end
	end
})

command.add(nil, {
	['evergreen:update'] = function()
		core.command_view:enter('Update Treesitter parser for', {
			submit = function(lang)
				if not languages.grammars[lang] then
					core.error('Unknown parser for language ' .. lang)
					return
				end
				core.log('Installing parser for ' .. lang)
				installer.installGrammar(languages.grammars[lang], config)
			end,
			suggest = function()
				return exts
			end
		})
	end
})

command.add(nil, {
	['evergreen:clean'] = function()
		core.add_thread(function()
			for _, parser_dir in pairs(system.list_dir(config.parserLocation)) do
				local path = util.join { config.parserLocation, parser_dir }
				if util.isDir(path) and languages.grammars[parser_dir] == nil then
					core.log('[Evergreen] removing unused parser "%s"', parser_dir)
					util.rmDir(path)
				end
			end
			for _, query_dir in pairs(system.list_dir(config.queryLocation)) do
				local path = util.join { config.queryLocation, query_dir }
				if util.isDir(path) and languages.grammars[query_dir] == nil then
					core.log('[Evergreen] removing unused queries "%s"', query_dir)
					util.rmDir(path)
				end
			end
		end)
	end
})
