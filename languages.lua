local core = require "core"

local util = require 'plugins.evergreen.util'
local config = require 'plugins.evergreen.config'

local M = {}

M.grammars = {}
M.extensionMappings = {}
M.filenameMappings = {}


local function exists(path)
	local f = system.get_file_info(path)
	if f ~= nil then return f.type == "file" else return false end
end

local function isDir(path)
	local f = system.get_file_info(path)
	if f ~= nil then return f.type == "dir" else return false end
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

local function compileParser(lang, path, dest)
	do
		local out, exitCode = exec(PLATFORM == 'Windows' and
			{ 'cmd', '/c', 'gcc -o ' .. util.join { dest, 'parser.so' } .. ' -shared src\\*.c -Os -I.\\src -fPIC' } or
			{ 'sh', '-c', 'gcc -o ' .. util.join { dest, 'parser.so' } .. ' -shared src/*.c -Os -I./src -fPIC' },
			{ cwd = path })
		if exitCode ~= 0 then
			core.error('[Evergreen] An error occured while attempting to compile the parser\n' .. out)
			return false
		else
			core.log('[Evergreen] Finished installing parser for ' .. lang)
			return true
		end
	end
end

local function installGrammar(options)
	local path = util.join {  config.parserLocation, options.lang }
	if isDir(options.path) then
		system.mkdir(path) -- ignore output
		if compileParser(options.lang, options.path, path) then
			local queryPath = util.join { config.queryLocation, options.lang }
			system.mkdir(queryPath)
			local out, exitCode = exec(PLATFORM == 'Windows' and
				{ 'cmd', '/c', 'cp ' .. util.join { options.query, '*.scm' } .. ' ' .. queryPath } or
				{ 'sh', '-c', 'cp ' .. util.join { options.query, '*.scm' } .. ' ' .. queryPath }, { cwd = options.path })
			if exitCode ~= 0 then
				core.error('[Evergreen] An error occured while copying ' .. options.lang .. 'queries \n' .. out)
				return false
			else
				core.log('[Evergreen] Finished installing queries for ' .. options.lang)
				return true
			end
		else
			return false
		end
	else
		core.error(
			"[Evergreen] impossible to install '%s' grammar as '%s' path does not exists.",
			options.lang,
			options.path
		)
		return false
	end
end

function M.add_grammar(options)
	local required_fields = {
		"path",
		"lang",
		"extensions",
		"query",
	}
	for _, field in pairs(required_fields) do
		if not options[field] then
			core.error(
				"[Evergreen] You need to provide a '%s' field for the grammar.",
				field
			)
			return false
		end
	end
	for ext in options.extensions:gmatch('[^,]+') do
		M.extensionMappings[ext] = options.lang
	end
	local lib = util.join {config.parserLocation, options.lang, "parser.so" }

	if not exists(lib) then
		core.add_thread(function()
			installGrammar(options)
		end)
	end
	return true
end

function M.add_filespec_grammar(options)
	local required_fields = {
		"path",
		"lang",
		"filename",
		"query",
	}
	for _, field in pairs(required_fields) do
    if not options[field] then
      core.error(
        "[Evergreen] You need to provide a '%s' field for the grammar.",
        field
      )
      return false
    end
  end
  M.filenameMappings[options.filename] = options.lang
	local lib = util.join {config.parserLocation, options.lang , "parser.so"}

	if not exists(lib) then
		core.add_thread(function()
			installGrammar(options)
		end)
	end
	return true
end

--- @param doc core.doc
function M.fromDoc(doc)
	-- TODO: hashbang detection
	if not doc.filename then return end

	local ext = doc.filename:match('%.([^.]+)$')
	if ext then
		local extMapping = M.extensionMappings[ext]
		if extMapping then return extMapping end
	end

	-- match explicitly on filename
	return M.filenameMappings[doc.filename]
end

return M
