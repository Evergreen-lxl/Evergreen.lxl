local M = {}

-- lists of valid/supported language extensions
-- with their intended parser
M.exts = {
	lua = 'https://github.com/MunifTanjim/tree-sitter-lua',
	go = 'https://github.com/tree-sitter/tree-sitter-go',
	zig = 'https://github.com/maxxnino/tree-sitter-zig'
}

M.installed = {}

return M
