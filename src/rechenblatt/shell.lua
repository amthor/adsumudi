-- Helpers for running shell commands (platform layer).

local M = {}

--- Quotes a string as a single POSIX shell word: wrap it in '...' and
-- turn every ' into '\''. Nothing inside single quotes is interpreted.
function M.quote(text)
	return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end

return M
