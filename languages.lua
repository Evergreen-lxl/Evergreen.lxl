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
			core.error('[Evergreen] An error occured while attempting to compile the parser at ' .. path .. ' \n' .. out)
			return false
		else
			core.log('[Evergreen] Finished installing parser for ' .. lang)
			return true
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
			local out, exitCode = exec(PLATFORM == 'Windows' and
				{ 'cmd', '/c', 'cp ' .. util.join { queries, '*.scm' } .. ' ' .. queryPath } or
				{ 'sh', '-c', 'cp ' .. util.join { queries, '*.scm' } .. ' ' .. queryPath }, { cwd = options.path })
			if exitCode ~= 0 then
				core.error('[Evergreen] An error occured while copying ' .. options.lang .. 'queries \n' .. out)
				return false
			else
				core.log('[Evergreen] Finished installing queries for ' .. options.lang)
				if options.extensions ~= nil then
					for ext in options.extensions:gmatch('[^,]+') do
						M.extensionMappings[ext] = options.lang
					end
				end
				if options.filename ~= nil then
					M.filenameMappings[options.filename] = options.lang
				end
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

local function rmDir(path)
	exec(PLATFORM == 'Windows' and
		{ 'cmd', '/c', 'rmdir ' .. path } or
		{ 'sh', '-c', 'rm -rf ' .. path })
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
	-- local gitOut, gitCode =
	exec({ "git", "clone", options.git, options.lang }, { cwd = tmp_path })
	-- if gitCode ~= 0 then
	-- core.error('[Evergreen] impossible to clone ' .. options.git .. ': '.. gitOut)
	-- return false
	-- end
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
			local out, exitCode = exec(PLATFORM == 'Windows' and
				{ 'cmd', '/c', 'cp ' .. util.join { queries, '*.scm' } .. ' ' .. queryPath } or
				{ 'sh', '-c', 'cp ' .. util.join { queries, '*.scm' } .. ' ' .. queryPath }, { cwd = repo_path })
			if exitCode ~= 0 then
				core.error('[Evergreen] An error occured while copying ' .. options.lang .. 'queries \n' .. out)
			else
				core.log('[Evergreen] Finished installing queries for ' .. options.lang)
				if options.extensions ~= nil then
					for ext in options.extensions:gmatch('[^,]+') do
						M.extensionMappings[ext] = options.lang
					end
				end
				if options.filename ~= nil then
					M.filenameMappings[options.filename] = options.lang
				end
			end
		end
		-- rmDir(repo_path)
	else
		core.error(
			"[Evergreen] impossible to install '%s' grammar as '%s' path does not exists.",
			options.lang,
			options.git
		)
		return false
	end
	return false
end

function M.add_grammar(options)
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
		if options.extensions ~= nil then
			for ext in options.extensions:gmatch('[^,]+') do
				M.extensionMappings[ext] = options.lang
			end
		end
		if options.filename ~= nil then
			M.filenameMappings[options.filename] = options.lang
		end
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
