-- shell.lua
-- Helpers for running shell commands.

local M = {}

--- Quotes a string as a single POSIX shell word (wraps in '...', turns ' into
--  '\''). Inside single quotes nothing is interpreted.
--- @param text any
--- @return string
function M.quote(text)
	return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end

return M
