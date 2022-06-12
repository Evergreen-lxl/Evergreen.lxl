-- mod-version:2 -- lite-xl 2.0
HOME = (HOME or os.getenv 'HOME') .. '/'
package.cpath = package.cpath .. ';' .. HOME .. '.luarocks/lib64/lua/5.4/?.so;'
.. HOME .. '.local/share/tree-sitter/parsers/tree-sitter-?/libtree-sitter-?.so'

local ltreesitter = require 'ltreesitter'
local core = require 'core'
local common = require 'core.common'
local Doc = require 'core.doc'
local Highlight = require 'core.doc.highlighter'

local function localPath()
   local str = debug.getinfo(2, 'S').source:sub(2)
   return str:match '(.*[/\\])'
end


local ff = io.open(string.format('%s/highlights.scm', localPath()))
local highlights = ff:read '*a'
ff:close()

local go = ltreesitter.require 'go'
--local tree = go:parse_string(source)

local my_query = go:query(highlights)

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

local oldDocNew = Doc.new
function Doc:new(filename, abs_filename, new_file)
	oldDocNew(self, filename, abs_filename, new_file)
	if filename then
		local ext = filename:match '^.+(%..+)$'
		if ext and ext:sub(2) == 'go' then
			self.treesit = true
			self.tstree = go:parse_string(table.concat(self.lines, ''))
		end
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
	for n, nName in my_query:capture(self.doc.tstree:root()) do
		--local replace = false
		local lastNode = (#linenodes ~= 0 and linenodes[#linenodes] or {})['node']
		local startPoint = n:start_point()
		local endPoint = n:end_point()

		if startPoint.row == i and endPoint.row == i then
			print(idx, string.format('"%s"', self.doc.lines[idx]:sub(0, startPoint.column)))
			print(gotline == false)
			-- indentation pass
			if (startPoint.column > 1 or self.doc.lines[idx]:sub(0, startPoint.column):find('\t')) and gotline == false then
				print('adding indents')
				table.insert(res.tokens, 'normal')
				table.insert(res.tokens, self.doc.lines[idx]:sub(0, startPoint.column))
			end

			if lastNode then
				local lnStartPoint = lastNode:start_point()
				local lnEndPoint = lastNode:end_point()

				if lnStartPoint.column == startPoint.column and lnEndPoint.column == endPoint.column then goto continue end
				-- whitespace between cur and last node
				if startPoint.column - lnEndPoint.column >= 1 then
					table.insert(res.tokens, 'normal')
					-- todo: use whitespace from line
					table.insert(res.tokens, (" "):rep(startPoint.column - lnEndPoint.column))
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
	print(common.serialize(res.tokens))

	return res
end
