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
	'd',
	'diff',
	'go',
	'lua',
	['jsx,js'] = 'javascript',
	['jl'] = 'julia',
	['rs'] = 'rust',
	'zig'
}

M.filenameMappings = {
	['go.mod'] = 'gomod'
}

-- lists of valid/supported language extensions
-- with their intended parser
M.exts = {
	c = 'https://github.com/tree-sitter/tree-sitter-c',
	cpp = 'https://github.com/tree-sitter/tree-sitter-cpp',
	d = 'https://github.com/CyberShadow/tree-sitter-d',
	diff = 'https://github.com/the-mikedavis/tree-sitter-diff',
	go = 'https://github.com/tree-sitter/tree-sitter-go',
	gomod = 'https://github.com/camdencheek/tree-sitter-go-mod',
	javascript = 'https://github.com/tree-sitter/tree-sitter-javascript',
	julia = 'https://github.com/tree-sitter/tree-sitter-julia',
	lua = 'https://github.com/MunifTanjim/tree-sitter-lua',
	rust = 'https://github.com/tree-sitter/tree-sitter-rust',
	zig = 'https://github.com/maxxnino/tree-sitter-zig'
}

M.installed = {}

--- @param doc core.doc
function M.fromDoc(doc)
	-- TODO: hashbang detection
	if not doc.filename then return end

	local ext = doc.filename:match('%.([^.]+)$')
	if ext then
		local extMapping = M.extensionMappings[ext]
		if extMapping then return extMapping end
	end

	-- match explicitly on filename
	return M.filenameMappings[doc.filename]
end

return M
