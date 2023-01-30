local M = {
	soname = PLATFORM == 'Windows' and '.dll' or '.so'
}

function M.join(parts)
	local str = ''
	local sepPattern = string.format('%s$', '%' .. PATHSEP)
	for i, part in ipairs(parts) do
		local sepMatch = part:match(sepPattern)
		str = str .. part .. (sepMatch or i == #parts and '' or PATHSEP)
	end
	str = str:gsub(string.format('%s$', '%' .. PATHSEP), '')

	return str
end

return M
