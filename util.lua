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

function M.localPath()
	local str = debug.getinfo(2, 'S').source:sub(2)
	return str:match '(.*[/\\])'
end

-- check if file exists
function M.exists(path)
	local f = system.get_file_info(path)
	if f ~= nil then return f.type == "file" else return false end
end

-- check if path is a directory or not
function M.isDir(path)
	local f = system.get_file_info(path)
	if f ~= nil then return f.type == "dir" else return false end
end

return M
