local core = require 'core'
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

M.defOptions = {
	-- Name of the language
	name = '',
	-- Filenames to match
	files = {},
	-- Path to the directory to install from
	path = '~',
	-- Relative path to the shared library
	-- {SOEXT} will be replaced with the configured shared library extension (e.g. .so / .dll)
	-- Optional if files is empty or nil
	soFile = 'parser{SOEXT}',
	-- Relative path to queries
	queryFiles = {
		highlights = 'queries/highlights.scm',
	},
}

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
				defOptions.soFile:gsub('{SOEXT}', config.soExt) or
				'parser' .. config.soExt
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

		for _, pattern in ipairs(def.files) do
			local s, e = filename:find(pattern)
			if s then
				local score = e - s
				if score > bestScore then
					bestScore = score
					bestDef = def
				end
			end
		end
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

	local builder = {}

	local head = f:read '*l'
	if head:sub(1, 12) == '; inherits: ' then
		for name in head:sub(13):gmatch '[%l_]+' do
			builder[#builder + 1] = M.getQuery(M.defs[name], queryType)
		end
	end

	f:seek('set', 0)
	builder[#builder + 1] = f:read '*a'
	f:close()

	query = table.concat(builder)
	M.queryCache[queryType][def.name] = query
	core.log('Loaded ' .. def.name .. ' ' .. queryType .. ' query')

	return query
end

return M
