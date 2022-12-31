local core = require 'core'
local style = require 'core.style'
local missingCount = 0
local totalCount = 0

local function addAlias(to, from)
	if not style.syntax[to] then
		missingCount = missingCount + 1
		style.syntax[to] = style.syntax[from]
	end
end

local altMap = {
	literal = {
		'boolean',
		'constant',
		'float',
		'number',
		'label'
	},
	constant = {'constant.builtin'},
	keyword = {
		'attribute',
		'conditional',
		'define',
		'exception',
		'include',
		'keyword.function',
		'keyword.return',
		'namespace',
		'preproc',
		'repeat',
		'type.qualifier'
	},
	keyword2 = {
		'type', -- this is suitable i think?
		'type.builtin',
		'variable.builtin',
		'type.definition',
	},
	operator = {
		'conditional.ternary',
		'keyword.operator'
	},
	['function'] = {
		'function.call',
		'method',
	},
	method = {'method.call'},
	normal = {
		'field',
		'punctuation.delimiter',
		'punctuation.brackets',
		'variable'
	}
}

for from, tos in pairs(altMap) do
	for _, to in ipairs(tos) do
		addAlias(to, from)
	end

	totalCount = totalCount + #tos
end

core.add_thread(function()
	if missingCount > 0 then
		core.warn(string.format('Missing %d/%d style variables for Evergreen syntax highlighting. To get the full experience, you can set these separately.', missingCount, totalCount))
	end
end)
