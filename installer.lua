local core = require 'core'

local util = require 'plugins.evergreen.util'
local languages = require 'plugins.evergreen.languages'

-- defualts grammar configuration
local defaults = {
  c = {
    extensions = 'c,h'
  },
  cpp = {
    extensions = 'cpp,cc,hpp'
  },
  d = {},
  diff = {},
  gomod = {
    filename = 'go.mod'
  },
  lua = {},
  javascript = {
    extensions = 'jsx,js'
  },
  julia = {
    extensions = 'jl'
  },
  rust = {
    extensions = 'rs'
  },
  zig = {}
}


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
      languages.extensionMappings[ext] = options.lang
    end
  end
  if options.filename ~= nil then
    for name in options.filename:gmatch('[^,]+') do
      languages.filenameMappings[name] = options.lang
    end
  end
  if options.filename == nil and options.extensions == nil then
    languages.extensionMappings[options.lang] = options.lang
  end
end

local function installQueries(path, options, config)
  local queryPath = util.join { config.queryLocation, options.lang }
  system.mkdir(queryPath)
  local queries = 'queries'
  if options.queries == nil then
    local defQueries = util.join { util.localPath(), 'queries', options.lang }
    if util.isDir(defQueries) then
      queries = defQueries
    else
      queries = util.join { path, options.queries }
    end
  else
    queries = util.join { path, options.queries }
  end
  core.log('[Evergreen] installing queries for language %s from %s to %s', options.lang, queries, queryPath)
  if copyQueries(queries, queryPath) then
    core.log('[Evergreen] Finished installing queries for ' .. options.lang)
    mapGrammar(options)
    return true
  end
  rmDir(queryPath)
  return false
end

local function installGrammarFromPath(options, config)
  core.log('[Evergreen] installing parser for languange %s from local path: %s.', options.lang, options.path)
  local path = util.join { config.parserLocation, options.lang }
  if util.isDir(options.path) then
    system.mkdir(path)
    if compileParser(options.lang, options.path, path) then
      return installQueries(options.path, options, config)
    end
  else
    core.error(
     '[Evergreen] impossible to install "%s" grammar as path "%s" does not exists.',
      options.lang,
      options.path
    )
  end
  return false
end


local function installGrammarFromGit(options, config)
  core.log('[Evergreen] installing parser for languange %s from git repository: %s.', options.lang, options.git)
  local tmp_path = util.join { config.dataDir, 'temp' }
  system.mkdir(tmp_path)
  local repo_path = util.join { tmp_path, options.lang }
  if util.isDir(repo_path) then
    core.log('[Evergreen] repository path "%s" exists', repo_path)
    return true
  end
  core.log('[Evergreen] cloning ' .. options.git .. ' in ' .. repo_path)
  exec({ 'git', 'clone', options.git, options.lang }, { cwd = tmp_path })
  if options.rev ~= nil then
    core.log('[Evergreen] checkout revision ' .. options.rev)
    exec({ 'git', 'checkout', options.rev }, { cwd = repo_path })
  end

  local path = util.join { config.parserLocation, options.lang }
  if util.isDir(repo_path) then
    system.mkdir(path)
    if options.subpath ~= nil then
      repo_path = util.join { repo_path, options.subpath }
    end
    if compileParser(options.lang, repo_path, path) then
      local ok = installQueries(repo_path, options, config)
      rmDir(repo_path)
      return ok
    end
  else
    core.error(
      '[Evergreen] impossible to install "%s" grammar as "%s" path does not exists.',
      options.lang,
      options.git
    )
  end
  return false
end

local function installGrammarFromURL(options, config)
  local path = util.join { config.parserLocation, options.lang }
  core.log('[Evergreen] installing parser for languange %s from  url: %s.', options.lang, options.url)
  system.mkdir(path)
  local out, exitCode
  if PLATFORM == 'Windows' then
    out, exitCode = exec({ 'powershell', '-Command',
      string.format('Invoke-WebRequest -OutFile ( New-Item -Path "%s" -Force ) -Uri %s', path, options.url) })
  else
    out, exitCode = exec({ 'curl', '-L', '--create-dirs', '--output-dir', path, '--fail', options.url, '-o',
      'parser' .. util.soname })
  end

  if exitCode ~= 0 then
    core.error('[Evergreen] An error occured while attempting to download the parser for language %s\n%s', options.lang,
      out)
  else
    installQueries(path, options, config)
  end
end

local function installGrammar(options, config)
  if options.url ~= nil then
    core.add_thread(function()
      installGrammarFromURL(options, config)
    end)
  elseif options.git ~= nil then
    core.add_thread(function()
      installGrammarFromGit(options, config)
    end)
  elseif options.path ~= nil then
    core.add_thread(function()
      installGrammarFromPath(options, config)
    end)
  else
    core.error('[Evergreen] No installation method defined for lanuage %s.', config.lang)
  end
end

local M = {}

function M.addGrammar(options, config)
  local required_fields = {
    'lang',
  }
  for _, field in pairs(required_fields) do
    if not options[field] then
      core.error(
        '[Evergreen] You need to provide a '%s' field for the grammar.',
        field
      )
      return false
    end
  end
  languages.grammars[options.lang] = options
  local lib = util.join { config.parserLocation, options.lang, 'parser.so'}
  local queries = util.join {config.queryLocation, options.lang, 'highlights.scm'}
  if not util.exists(lib) or not util.exists(queries) then
    if options.git ~= nil then
      core.add_thread(function()
        installGrammarFromGit(options, config)
      end)
    elseif options.path ~= nil or options.url ~= nil then
      installGrammar(options, config)
    elseif defaults[options.lang] ~= nil then
      local default = defaults[options.lang]
      options.url =
          string.format('https://github.com/TorchedSammy/evergreen-builds/releases/download/parsers/tree-sitter-%s%s',
            options.lang, util.soname)
      if options.extensions == nil and default.extensions ~= nil then
        options.extensions = default.extensions
      end
      if options.filename == nil and default.filename ~= nil then
        options.filename = default.filename
      end
      installGrammar(options, config)
    else
      core.error('[Evergreen] nor installation mode defined for language %s.', options.lang)
    end
  else
    mapGrammar(options)
  end
  return true
end

return M
