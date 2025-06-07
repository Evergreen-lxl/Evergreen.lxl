local common = require 'core.common'
local config = require 'core.config'

local defaults = {
	useFallbackColors = true,
	warnFallbackColors = true,
	maxParseTime = 2000,
}

local spec = {
	name = 'Evergreen',
	{
		label       = 'Use fallback colors',
		description = 'Set fallbacks for missing colors',
		path        = 'useFallbackColors',
		type        = 'toggle',
	},
	{
		label       = 'Warn fallback colors',
		description = 'Warn when fallback colors are used',
		path        = 'warnFallbackColors',
		type        = 'toggle',
	},
	{
		label       = 'The below options are meant for advanced use only.',
		path        = '',
		type        = 'button',
		icon        = '!',
	},
	{
		label       = 'Maximum parse time',
		description = 'Maximum time spent parsing before deferring it (in µs). Set this to 0 to disable deferring',
		path        = 'maxParseTime',
		type        = 'number',
		min         = 0,
		step        = 1,
	},
}

for _, option in ipairs(spec) do
	option.default = defaults[option.path]
end

defaults.config_spec     = spec
config.plugins.evergreen = common.merge(defaults, config.plugins.evergreen)

print(config.plugins.evergreen.soExt)

return config.plugins.evergreen
