-- mod-version:3
local core = require 'core'
local config = require 'plugins.evergreen.config'
local util = require 'plugins.evergreen.util'
local home = HOME or os.getenv 'HOME'
local function appendPaths(paths)
	for _, path in ipairs(paths) do
		package.cpath = package.cpath .. ';' .. path:gsub('~', home)
	end
end

system.mkdir(config.dataDir)
system.mkdir(config.parserLocation)

appendPaths {
	util.join {config.dataDir, '?' .. util.soname},
	util.join {config.parserLocation, '?', 'libtree-sitter-?' .. util.soname},
	util.join {config.parserLocation, '?', 'parser' .. util.soname},
}

if PLATFORM ~= 'Windows' then
	appendPaths {
		'~/.luarocks/lib/lua/5.4/?' .. util.soname,
		'~/.luarocks/lib64/lua/5.4/?' .. util.soname,
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

local ok = package.searchpath('ltreesitter', package.cpath)
core.log('%s', ok)
if not ok then
	core.add_thread(function()
		core.log 'Could not require ltreesitter, attempting to install...'
		local url = string.format('https://github.com/TorchedSammy/evergreen-builds/releases/download/ltreesitter/ltreesitter%s', util.soname)

		local out, exitCode
		if PLATFORM == 'Windows' then
			out, exitCode = exec({'powershell', '-Command', string.format('Invoke-WebRequest -OutFile ( New-Item -Path "%s" -Force ) -Uri %s', util.join {config.dataDir, 'ltreesitter' .. util.soname}, url)})
		else
			out, exitCode = exec({'curl', '-L', '--create-dirs', '--output-dir', config.dataDir, '--fail', url, '-o', 'ltreesitter' .. util.soname})
		end
		if exitCode ~= 0 then
			core.error('An error occured while attempting to download ltreesitter\n%s', out)
			return
		else
			core.log('Finished installing ltreesitter!')
		end
		core.reload_module 'plugins.evergreen'
	end)
	return
end

local common = require 'core.common'
local command = require 'core.command'
local Doc = require 'core.doc'
local Highlight = require 'core.doc.highlighter'

local parser = require 'plugins.evergreen.parser'
local highlights = require 'plugins.evergreen.highlights'
require 'plugins.evergreen.style'
require 'plugins.evergreen.installer'

--- @class core.doc
--- @field treesit boolean
--- @field ts table

local oldDocNew = Doc.new
function Doc:new(filename, abs_filename, new_file)
	oldDocNew(self, filename, abs_filename, new_file)
	highlights.init(self)
end

local function accumulateLen(tbl, s, e)
	local len = 0

	for i=s,e do
		len = len + tbl[i]:len()
	end

	return len
end

local function incrementalHighlight(doc, row)
	local old = doc.ts.tree
	doc.ts.tree = doc.ts.parser:parse_with(parser.input(doc.lines), doc.ts.tree)

	for _, p in ipairs(old:get_changed_ranges(doc.ts.tree)) do
		for i = p.start_point.row + 1, p.end_point.row + 1 do
			doc.highlighter.lines[i] = false
		end
		doc.highlighter:invalidate(p.start_point.row + 1)
	end

	for n, _ in doc.ts.query:capture(doc.ts.tree:root(), {
		row    = row - 1,
		column = 0
	}, {
		row    = row - 1,
		column = #doc.lines[row] - 1
	}) do
		for i = n:start_point().row + 1, n:end_point().row + 1 do
			doc.highlighter.lines[i] = false
		end
		doc.highlighter:invalidate(n:start_point().row + 1)
	end
end

local oldDocInsert = Doc.raw_insert
function Doc:raw_insert(line, col, text, undo, time)
	oldDocInsert(self, line, col, text, undo, time)

	if self.treesit then
		line, col = self:sanitize_position(line, col)

		local tsByte = accumulateLen(self.lines, 1, line - 1) + col - 1
		local tsLine, tsCol = line - 1, col - 1

		self.ts.tree:edit_s {
			start_byte    = tsByte,
			old_end_byte  = tsByte,
			new_end_byte  = tsByte + text:len(),
			start_point   = { row = tsLine, column = tsCol },
			old_end_point = { row = tsLine, column = tsCol },
			new_end_point = { row = tsLine, column = tsCol + text:len() },
		}
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
		local text = self:get_text(line1, col1, line2, col2)

		oldDocRemove(self, line1, col1, line2, col2, undo, time)

		local tsByte = accumulateLen(self.lines, 1, line1 - 1) + col1 - 1

		self.ts.tree:edit_s {
			start_byte    = tsByte,
			old_end_byte  = tsByte + text:len(),
			new_end_byte  = tsByte,
			start_point   = { row = line1 - 1, column = col1 - 1 },
			old_end_point = { row = line2 - 1, column = col2 - 1 },
			new_end_point = { row = line1 - 1, column = col1 - 1 },
		}
		incrementalHighlight(self, line1)
	else
		oldDocRemove(self, line1, col1, line2, col2, undo, time)
	end
end

local oldDocReload = Doc.reload
function Doc:reload()
	oldDocReload(self)
	if self.treesit then
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

	for node, name in self.doc.ts.query:capture(self.doc.ts.tree:root(), {
		row    = row,
		column = 0
	}, {
		row    = row,
		column = #txt - 1
	}) do
		local startPt = node:start_point()
		local endPt   = node:end_point()

		if row > endPt.row then goto continue end
		if row < startPt.row then break end

		local startPos = startPt.row < row and 1 or startPt.column + 1
		local endPos   = endPt.row > row and #txt or endPt.column

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
		end
	end
})
