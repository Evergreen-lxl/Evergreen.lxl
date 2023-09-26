local core = require 'core'
local style = require 'core.style'
local missingStyles = {}
local missingCount = 0
local totalCount = 0

local function addAlias(to, from, notSyntax)
	totalCount = totalCount + 1
	if not style.syntax[to] then
		missingCount = missingCount + 1
		table.insert(missingStyles, to)

		local source = style.syntax
		if notSyntax then source = style end
		style.syntax[to] = source[from]
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
	comment = {
		'comment.documentation'
	},
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
		'type.qualifier',
		'constructor'
	},
	keyword2 = {
		'type', -- this is suitable i think?
		'type.builtin',
		'variable.builtin',
		'type.definition',
	},
	operator = {
		'conditional.ternary',
		'keyword.operator',
		'punctuation.special',
		'storageclass'
	},
	storageclass = {
		'storageclass.lifetime'
	},
	['function'] = {
		'function.call',
		'function.macro',
		'method',
		'tag'
	},
	method = {'method.call'},
	normal = {
		'field',
		'punctuation.brackets',
		'punctuation.delimiter',
		'variable'
	},
	attribute = {
		'tag.attribute',
	},
	tag = {
		'tag.delimiter'
	}
}

addAlias('error', 'error', true)
addAlias('text.diff.add', 'good', true)
addAlias('text.diff.delete', 'error', true)

for from, tos in pairs(altMap) do
	for _, to in ipairs(tos) do
		addAlias(to, from)
	end
end

core.add_thread(function()
	if missingCount > 0 then
		core.warn(string.format('Missing %d/%d style variables for Evergreen syntax highlighting. To get the full experience, you can set these separately:\n%s', missingCount, totalCount, table.concat(missingStyles, '\n')))
	end
end)
