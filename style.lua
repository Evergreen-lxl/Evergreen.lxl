local style = require 'core.style'

local function addAlias(to, from)
	if not style.syntax[to] then
		style.syntax[to] = style.syntax[from]
	end
end

addAlias('boolean', 'literal')

addAlias('constant', 'literal')
addAlias('constant.builtin', 'literal')
addAlias('conditional', 'keyword')
addAlias('conditional.ternary', 'operator')

addAlias('define', 'keyword')

addAlias('exception', 'keyword')

addAlias('field', 'normal')
addAlias('function.call', 'function')
addAlias('float', 'literal')

addAlias('number', 'literal')

addAlias('keyword.function', 'keyword')
addAlias('keyword.operator', 'operator')

addAlias('method', 'function')
addAlias('method.call', 'method') -- if user doesnt have custom method highlight it will fallback to function
