local core = require 'core'
local command = require 'core.command'
local common = require 'core.common'
local config = require 'plugins.evergreen.config'
local util = require 'plugins.evergreen.util'
local ts = require 'libraries.tree_sitter'

local M = {
	defs = {},
	langCache = {},
	queryCache = {
		highlights = {},
	},
}

local soExt = PLATFORM == 'Windows' and '.dll' or '.so'

function M.addDef(defOptions)
	local def = {}

	assert(defOptions.name, 'Name is required for language definition')
	assert(not M.defs[defOptions.name], 'Duplicate language name')
	assert(defOptions.path, 'Path is required for language definition')

	def.name = defOptions.name
	def.files = defOptions.files

	local path = common.home_expand(defOptions.path)

	if defOptions.files and #defOptions.files > 0 then
		def.soFile = util.joinPath {
			path,
			defOptions.soFile and
				defOptions.soFile:gsub('{SOEXT}', soExt) or
				'parser' .. soExt
		}
	end

	def.queryFiles = {}
	def.queryFiles.highlights = util.joinPath {
		path,
		defOptions.queryFiles.highlights or 'queries/highlights.scm'
	}

	M.defs[#M.defs + 1] = def
	M.defs[def.name] = def
end

function M.findDef(filename)
	local bestScore = 0
	local bestDef

	for i = #M.defs, 1, -1 do
		local def = M.defs[i]
		if not def.files then goto continue end

		for _, pattern in ipairs(def.files) do
			local s, e = filename:find(pattern)
			if not s then goto continue end

			local score = e - s
			if score > bestScore then
				bestScore = score
				bestDef = def
			end

			::continue::
		end

		::continue::
	end

	return bestDef
end

function M.getLang(def)
	local lang = M.langCache[def.name]
	if lang then
		return lang
	end

	local ok, result = pcall(ts.Language.load, def.soFile, def.name)
	if not ok then
		core.error('Error loading language ' .. def.name  .. ':\n' .. result)
		return nil
	end

	M.langCache[def.name] = result
	core.log('Loaded language ' .. def.name)

	return result
end

function M.getQuery(def, queryType)
	local query = M.queryCache[queryType][def.name]
	if query then
		return query
	end

	local f = io.open(def.queryFiles[queryType])
	if not f then
		core.error('Error loading ' .. def.name .. ' ' .. queryType .. ' query')
		return nil
	end

	local builder = { '; EVERGREEN: BEGIN ' .. def.name .. '\n' }

	while true do
		local head = f:read '*l'
		if not head:match '%s*;' then
			break
		end

		local names = head:match '%s*;+%s*inherits%s*:%s*([%l_,]*)'
		if names then
			for name in names:gmatch '[%l_]+' do
				local inheritDef = M.defs[name]
				if not inheritDef then
					core.warn(
						'Could not find language %s to inherit queries from. \z
						Syntax highlighting may be incomplete.',
						name
					)
					goto continue
				end

				builder[#builder + 1] = '; EVERGREEN: INHERIT ' .. name .. '\n'
				builder[#builder + 1] = M.getQuery(M.defs[name], queryType)

				::continue::
			end
		end
	end

	f:seek('set', 0)
	builder[#builder + 1] = f:read '*a'
	f:close()

	builder[#builder + 1] = '; EVERGREEN: END ' .. def.name .. '\n'

	query = table.concat(builder)
	M.queryCache[queryType][def.name] = query
	core.log('Loaded ' .. def.name .. ' ' .. queryType .. ' query')

	return query
end

local queryRecents = {}

command.add(nil, {
	['evergreen:view-highlights-query'] = function()
		core.command_view:enter('View highlights query for language', {
			submit = function(name)
				local def = M.defs[name]
				if not def then
					core.error('No such langauge %s', name)
					return
				end

				local doc = core.open_doc('highlights.scm')
				core.root_view:open_doc(doc)
				doc:insert(1, 1, M.getQuery(def, 'highlights'))
				doc.new_file = false
				doc:clean()
			end,

			suggest = function(name)
				local names = {}
				for _, def in ipairs(M.defs) do
					names[#names + 1] = def.name
				end

				return common.fuzzy_match_with_recents(names, queryRecents, name)
			end,
		})
	end,
})

return M
