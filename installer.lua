local core = require 'core'

local util = require 'plugins.evergreen.util'
local languages = require 'plugins.evergreen.languages'

-- defualts grammar configuration
local defaults = {
  c = {
    filePatterns = {'%.c', '%.h'},
    precompiled = true,
    git = 'https://github.com/tree-sitter/tree-sitter-c'
  },
  cpp = {
    filePatterns = {'%.cpp', '%.cc','%.hpp'},
    precompiled = true,
    git = 'https://github.com/tree-sitter/tree-sitter-cpp'
  },
  diff = {
    precompiled = true,
    git = 'https://github.com/the-mikedavis/tree-sitter-diff'
  },
  go = {
    precompiled = true,
    git = 'https://github.com/tree-sitter/tree-sitter-go'
  },
  gomod = {
    filePatterns = {'go.mod'},
    precompiled = true,
    git = 'https://github.com/camdencheek/tree-sitter-go-mod'
  },
  lua = {
    precompiled = true,
    git = 'https://github.com/MunifTanjim/tree-sitter-lua'
  },
  javascript = {
    filePatterns = {'%.jsx','%.js'},
    precompiled = true,
    git = 'https://github.com/tree-sitter/tree-sitter-javascript'
  },
  julia = {
    filePatterns = {'%.jl'},
    precompiled = true,
    git = 'https://github.com/tree-sitter/tree-sitter-julia'
  },
  rust = {
    filePatterns = {'%.rs'},
    precompiled = true,
    git = 'https://github.com/tree-sitter/tree-sitter-rust'
  },
  zig = {
    precompiled = true,
    git = 'https://github.com/maxxnino/tree-sitter-zig'
  }
}

local function copyQueries(source, dest)
  local out, exitCode = util.exec(PLATFORM == 'Windows' and
    { 'cmd', '/c', 'cp ' .. util.join { source, '*.scm' } .. ' ' .. dest } or
    { 'sh', '-c', 'cp ' .. util.join { source, '*.scm' } .. ' ' .. dest })
  if exitCode ~= 0 then
    core.error('[Evergreen] An error occured while copying queries from ' .. source .. ' to ' .. dest .. ' \n' .. out)
  end
  return exitCode == 0
end

local function compileParser(lang, path, dest)
  do
    local out, exitCode = util.exec(PLATFORM == 'Windows' and
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

local function installQueries(path, options, config)
  local queryPath = util.join { config.queryLocation, options.lang }
  system.mkdir(queryPath)
  local queries = 'queries'
  if options.queries == nil then
    local defQueries = util.join { util.localPath(), 'queries', options.lang }
    if util.isDir(defQueries) then
      queries = defQueries
    else
      queries = util.join { path, queries }
    end
  else
    queries = util.join { path, options.queries }
  end
  core.log('[Evergreen] installing queries for language %s from %s to %s', options.lang, queries, queryPath)
  if copyQueries(queries, queryPath) then
    core.log('[Evergreen] Finished installing queries for ' .. options.lang)
    return true
  end
  util.rmDir(queryPath)
  return false
end

local function installGrammarFromPath(options, config)
  core.log('[Evergreen] installing parser for languange %s from local path: %s.', options.lang, options.path)
  local path = util.join { config.parserLocation, options.lang }
  local src_path = util.fixHomePath(options.path)
  if util.isDir(src_path) then
    system.mkdir(path)
    if compileParser(options.lang, src_path, path) then
      return installQueries(src_path, options, config)
    end
  else
    core.error(
      '[Evergreen] impossible to install "%s" grammar as path "%s" does not exists.',
      options.lang,
      src_path
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
    core.log_quiet('[Evergreen] repository path "%s" exists', repo_path)
    return true
  end
  core.log_quiet('[Evergreen] cloning ' .. options.git .. ' in ' .. repo_path)
  util.exec({ 'git', 'clone', options.git, options.lang }, { cwd = tmp_path })
  if options.rev ~= nil then
    core.log_quiet('[Evergreen] checkout revision ' .. options.rev)
    util.exec({ 'git', 'checkout', options.rev }, { cwd = repo_path })
  end

  local path = util.join { config.parserLocation, options.lang }
  if util.isDir(repo_path) then
    system.mkdir(path)
    if options.subpath ~= nil then
      repo_path = util.join { repo_path, options.subpath }
    end
    if compileParser(options.lang, repo_path, path) then
      local ok = installQueries(repo_path, options, config)
      util.rmDir(repo_path)
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
    out, exitCode = util.exec({ 'powershell', '-Command',
      string.format('Invoke-WebRequest -OutFile ( New-Item -Path "%s" -Force ) -Uri %s', path, options.url) })
  else
    out, exitCode = util.exec({ 'curl', '-L', '--create-dirs', '--output-dir', path, '--fail', options.url, '-o',
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

function M.installGrammar(options, config)
  if options.git ~= nil then
    core.add_thread(function()
      installGrammarFromGit(options, config)
    end)
  elseif options.path ~= nil or options.url ~= nil then
    installGrammar(options, config)
  elseif defaults[options.lang] ~= nil then
    local default = defaults[options.lang]
    if options.precompiled == nil or options.precompiled then
      options.url =
          string.format('https://github.com/TorchedSammy/evergreen-builds/releases/download/parsers/tree-sitter-%s%s',
            options.lang, util.soname)
    else
      options.git = default.git
    end
    installGrammar(options, config)
  else
    core.error('[Evergreen] nor installation mode defined for language %s.', options.lang)
  end
end

local function fillPatterns(options)
  if options.filePatterns == nil then
    local def = defaults[options.lang]
    if def ~= nil and def.filePatterns ~= nil then
      options.filePatterns = def.filePatterns
    else
      options.filePatterns = { "%."..options.lang}
    end
  end
  return options
end

function M.addGrammar(options, config)
  local required_fields = {
    'lang',
  }
  for _, field in pairs(required_fields) do
    if not options[field] then
      core.error(
        '[Evergreen] You need to provide a "%s" field for the grammar.',
        field
      )
      return false
    end
  end

  languages.grammars[options.lang] = fillPatterns(options)
  local lib = util.join { config.parserLocation, options.lang, 'parser.so' }
  local queries = util.join { config.queryLocation, options.lang, 'highlights.scm' }
  if not util.exists(lib) or not util.exists(queries) then
    M.installGrammar(options, config)
  end
  return true
end

return M
