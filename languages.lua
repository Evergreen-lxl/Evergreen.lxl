local core = require "core"

local util = require 'plugins.evergreen.util'
local config = require 'plugins.evergreen.config'

local M = {}

-- map grammars to file extensions
M.extensionMappings = {}
-- map grammars to specific file names
M.filenameMappings = {}

-- check if file exists
local function exists(path)
	local f = system.get_file_info(path)
	if f ~= nil then return f.type == "file" else return false end
end

-- check if path is a directory or not
local function isDir(path)
	local f = system.get_file_info(path)
	if f ~= nil then return f.type == "dir" else return false end
end

-- execute proecess
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

-- remove directory
local function rmDir(path)
	exec(PLATFORM == 'Windows' and
		{ 'cmd', '/c', 'rmdir ' .. path } or
		{ 'sh', '-c', 'rm -rf ' .. path })
end

local function copyQueries(source, dest)
	local out, exitCode = exec(PLATFORM == 'Windows' and
		{ 'cmd', '/c', 'cp ' .. util.join { source, '*.scm' } .. ' ' .. dest } or
		{ 'sh', '-c', 'cp ' .. util.join { source, '*.scm' } .. ' ' .. dest })
	if exitCode ~= 0 then
		core.error('[Evergreen] An error occured while copying queries from ' .. source .. ' to ' .. dest .. ' \n' .. out)
	end
	return exitCode == 0
end

local function compileParser(lang, path, dest)
	do
		local out, exitCode = exec(PLATFORM == 'Windows' and
			{ 'cmd', '/c', 'gcc -o ' .. util.join { dest, 'parser.so' } .. ' -shared src\\*.c -Os -I.\\src -fPIC' } or
			{ 'sh', '-c', 'gcc -o ' .. util.join { dest, 'parser.so' } .. ' -shared src/*.c -Os -I./src -fPIC' },
			{ cwd = path })
		if exitCode ~= 0 then
			core.error('[Evergreen] An error occured while attempting to compile the parser at ' .. path .. ' \n' .. out)
			return false
		else
			core.log('[Evergreen] Finished installing parser for ' .. lang)
			return true
		end
	end
end

local function mapGrammar(options)
	if options.extensions ~= nil then
		for ext in options.extensions:gmatch('[^,]+') do
			M.extensionMappings[ext] = options.lang
		end
	end
	if options.filename ~= nil then
		for name in options.filename:gmatch('[^,]+') do
			M.filenameMappings[name] = options.lang
		end
	end
end

local function installGrammar(options)
	local path = util.join { config.parserLocation, options.lang }
	if isDir(options.path) then
		system.mkdir(path) -- ignore output
		if compileParser(options.lang, options.path, path) then
			local queryPath = util.join { config.queryLocation, options.lang }
			system.mkdir(queryPath)
			local queries = "queries"
			if options.queries ~= nil then
				queries = options.queries
			end
			if copyQueries(util.join { options.path, queries }, queryPath) then
				core.log('[Evergreen] Finished installing queries for ' .. options.lang)
				mapGrammar(options)
			end
			return true;
		end
	else
		core.error(
			"[Evergreen] impossible to install '%s' grammar as '%s' path does not exists.",
			options.lang,
			options.path
		)
	end
	return false
end


local function installGrammarFromGit(options)
	local tmp_path = util.join { config.dataDir, "temp" }
	system.mkdir(tmp_path)
	local repo_path = util.join { tmp_path, options.lang }
	if isDir(repo_path) then
		core.log("[Evergreen] " .. repo_path .. " exists")
		return true
	end
	core.log('[Evergreen] cloning ' .. options.git .. ' in ' .. repo_path)
	exec({ "git", "clone", options.git, options.lang }, { cwd = tmp_path })
	if options.rev ~= nil then
		core.log('[Evergreen] checkout revision ' .. options.rev)
		exec({ "git", "checkout", options.rev }, { cwd = repo_path })
	end

	local path = util.join { config.parserLocation, options.lang }
	if isDir(repo_path) then
		system.mkdir(path) -- ignore output
		if options.subpath ~= nil then
			repo_path = util.join { repo_path, options.subpath }
		end
		if compileParser(options.lang, repo_path, path) then
			local queryPath = util.join { config.queryLocation, options.lang }
			system.mkdir(queryPath)
			local queries = "queries"
			if options.queries ~= nil then
				queries = options.queries
			end
			if copyQueries(util.join { repo_path, queries }, queryPath) then
				core.log('[Evergreen] Finished installing queries for ' .. options.lang)
				mapGrammar(options)
			end
			rmDir(repo_path)
			return true
		else
			rmDir(repo_path)
			return false
		end
	else
		core.error(
			"[Evergreen] impossible to install '%s' grammar as '%s' path does not exists.",
			options.lang,
			options.git
		)
	end
	return false
end


function M.addGrammar(options)
	local required_fields = {
		"lang",
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
	local lib = util.join { config.parserLocation, options.lang, "parser.so" }

	if not exists(lib) then
		if options.git ~= nil then
			core.add_thread(function()
				installGrammarFromGit(options)
			end)
		elseif options.path ~= nil then
			core.add_thread(function()
				installGrammar(options)
			end)
		else
			core.error("[Evergreen] nor path or git defined for " .. options.lang)
		end
	else
		mapGrammar(options)
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
