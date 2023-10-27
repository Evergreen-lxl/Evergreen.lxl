local M = {}

-- map grammars to file extensions
M.extensionMappings = {}
-- map grammars to specific file names
M.filenameMappings = {}
-- map of grammar configured
M.grammars = {}

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
