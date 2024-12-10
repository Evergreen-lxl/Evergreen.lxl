local M = {}

function M.joinPath(parts)
	local str = ''
	local sepPattern = string.format('%s$', '%' .. PATHSEP)
	for i, part in ipairs(parts) do
		local sepMatch = part:match(sepPattern)
		str = str .. part .. (sepMatch or i == #parts and '' or PATHSEP)
	end
	str = str:gsub(string.format('%s$', '%' .. PATHSEP), '')

	return str
end

function M.flatten(parts, dest)
	dest = dest or {}

	for _, part in ipairs(parts) do
		if type(part) == 'table' then
			M.flatten(part, dest)
		else
			dest[#dest + 1] = part
		end
	end

	return dest
end

function M.input(lines)
	return function(_, point)
		if point:row() < #lines then
			return lines[point:row() + 1], point:column() + 1
		else
			return nil
		end
	end
end

return M
