local core = require 'core'
local style = require 'core.style'

local config = require 'plugins.evergreen.config'

local fallbackMap = {
	['normal'] = {
		'punctuation.delimiter',
		['punctuation.bracket'] = {
			'tag.delimiter',
		},
		'markup.strong',
		'markup.italic',
		'markup.strikethrough',
		'markup.underline',
		['markup.heading'] = {
			'markup.heading.1',
			'markup.heading.2',
			'markup.heading.3',
			'markup.heading.4',
			'markup.heading.5',
			'markup.heading.6',
		},
		'markup.quote',
		'markup.math',
		['markup.raw'] = {
			'markup.raw.block',
		},
	},
	['symbol'] = {
		['variable'] = {
			'variable.builtin',
			['variable.parameter'] = {
				'variable.parameter.builtin',
			},
			['variable.member'] = {
				'property',
				'tag.attribute',
			},
		},
		'label',
	},
	['comment'] = {
		'string.documentation',
		'comment.documentation',
		'comment.error',
		'comment.warning',
		'comment.todo',
		'comment.note',
	},
	['keyword'] = {
		'string.escape',
		'keyword.coroutine',
		'keyword.function',
		'keyword.import',
		'keyword.type',
		'keyword.modifier',
		'keyword.repeat',
		'keyword.return',
		'keyword.debug',
		'keyword.exception',
		'keyword.conditional',
		['keyword.directive'] = {
			'keyword.directive.define',
		},
		'punctuation.special',
		'tag.builtin',
	},
	['keyword2'] = {
		['module'] = {
			'module.builtin',
		},
		['type'] = {
			'type.builtin',
			'type.definition',
		},
		'constructor',
	},
	['number'] = {
		'number.float',
	},
	['literal'] = {
		['constant'] = {
			'constant.builtin',
			'constant.macro',
		},
		['character'] = {
			'character.constant',
		},
		'boolean',
		['markup.list'] = {
			'markup.list.checked',
			'markup.list.unchecked',
		},
	},
	['string'] = {
		'string.regexp',
		['string.special'] = {
			'string.special.symbol',
			'string.special.path',
			'string.special.url',
			['markup.link'] = {
				'markup.link.label',
				'markup.link.url',
			},
		},
	},
	['operator'] = {
		'keyword.operator',
		'keyword.conditional.ternary',
	},
	['function'] = {
		['attribute'] = {
			'attribute.builtin',
		},
		'function.builtin',
		'function.call',
		'function.macro',
		['function.method'] = {
			'function.method.call',
		},
		'tag',
	},
}

local function setFallbacks(fallbackMap, colour, missing)
	if not config.useFallbackColors then return 0 end

	missing = missing or {}

	for k, v in pairs(fallbackMap) do
		if type(k) == 'string' then
			if not style.syntax[k] then
				style.syntax[k] = colour
				missing[#missing + 1] = k
			end

			setFallbacks(v, style.syntax[k], missing)
		else
			if not style.syntax[v] then
				style.syntax[v] = colour
				missing[#missing + 1] = v
			end
		end
	end

	return missing
end

local function refreshSyntaxColors()
	local missing = setFallbacks(fallbackMap)

	if config.warnFallbackColors and #missing > 0 then
		table.sort(missing)

		core.warn(string.format(
			'Fallbacks were used for %d colors for Evergreen highlighting.\n\z
			Disable this message by setting the warnFallbackColors option \z
			in the module plugins.evergreen.config to false, \z
			or by specifying all the following syntax colors: \n\t%s',
			#missing, table.concat(missing, '\n\t')
		))
	end
end

local oldReloadModule = core.reload_module
function core.reload_module(name)
	if name:find('colors.', 1, true) then
		style.syntax = {}
		oldReloadModule(name)
		refreshSyntaxColors(fallbackMap)
	else
		oldReloadModule(name)
	end
end

core.add_thread(refreshSyntaxColors)
