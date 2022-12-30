local core = require 'core'
local command = require 'core.command'
local languages = require 'plugins.evergreen.languages'
local home = HOME or os.getenv 'HOME'
local installDir = ('~/.local/share/tree-sitter/parsers'):gsub('~', home)
local exts = {}

for k, _ in pairs(languages.exts) do
	table.insert(exts, k)
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

command.add(nil, {
	['evergreen:install'] = function()
		core.command_view:enter('Install a Treesitter parser for', {
			submit = function(lang)
				if not languages.exts[lang] then
					core.error('Unknown parser for language ' .. lang)
					return
				end
				core.log('Installing parser for ' .. lang)

				core.add_thread(function()
					local parserDir = string.format('%s/%s', installDir, 'tree-sitter-' .. lang)
					exec {'git', 'clone', languages.exts[lang], parserDir}

					local out, exitCode = exec({'sh', '-c', 'gcc -o parser.so -shared src/*.c -Os -I./src -fPIC'}, {cwd = parserDir})
					if exitCode ~= 0 then
						core.error('An error occured while attempting to compile the parser\n' .. out)
					else
						core.log('Finished installing parser for ' .. lang)
					end
				end)
			end,
			suggest = function()
				return exts
			end
		})
	end
})
