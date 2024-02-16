local M = {}
local core = require 'core'
-- map of grammar configured
M.grammars = {}

--- @param doc core.doc
function M.fromDoc(doc)
	-- TODO: hashbang detection
	if not doc.filename then return end
	for lang, options in pairs(M.grammars) do
		if options.filePatterns ~= nil then
			for _, ext in pairs(options.filePatterns) do
				if doc.filename:match(ext .. "$") ~= nil then 
					return lang
				end
			end
		end
	end
end

return M
