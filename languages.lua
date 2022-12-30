local M = {}

-- lists of valid/supported language extensions
-- with their intended parser
M.exts = {
	c = 'https://github.com/tree-sitter/tree-sitter-c',
	cpp = 'https://github.com/tree-sitter/tree-sitter-cpp',
	lua = 'https://github.com/MunifTanjim/tree-sitter-lua',
	go = 'https://github.com/tree-sitter/tree-sitter-go'
}

M.installed = {}

return M
