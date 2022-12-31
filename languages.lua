local M = {}

local function makeTbl(tbl)
	local t = {}
	for exts, ftype in pairs(tbl) do
		if type(exts) == 'number' then
			t[ftype] = ftype
		else
			for ext in exts:gmatch('[^,]+') do
				t[ext] = ftype
			end
		end
	end
	return t
end

M.extensionMappings = makeTbl {
	['c,h'] = 'c',
	['cc,cpp,hpp'] = 'cpp',
	'diff',
	'go',
	'lua',
}

-- lists of valid/supported language extensions
-- with their intended parser
M.exts = {
	c = 'https://github.com/tree-sitter/tree-sitter-c',
	cpp = 'https://github.com/tree-sitter/tree-sitter-cpp',
	diff = 'https://github.com/the-mikedavis/tree-sitter-diff',
	lua = 'https://github.com/MunifTanjim/tree-sitter-lua',
	go = 'https://github.com/tree-sitter/tree-sitter-go'
}

M.installed = {}

return M
