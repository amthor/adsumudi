-- PDF build via lualatex (platform layer: shells out, touches the file system).
-- Will be replaced when switching to Typst.

local M = {}

--- Compiles a .tex file into a PDF next to it.
-- @param tex_path path of the .tex file
-- @param options  {keep_log?}: keep the .log file (debug mode)
-- @return path of the PDF, or nil, message
function M.build(tex_path, options)
	options = options or {}
	local dir = tex_path:match("^(.*)[/\\]") or "."
	local file = tex_path:match("([^/\\]+)$")
	local cmd = ("cd %q && lualatex -interaction=nonstopmode -halt-on-error %q > /dev/null"):format(dir, file)
	local base = tex_path:gsub("%.tex$", "")

	-- The total page count (lastpage) is only known after another run:
	-- repeat as long as the log asks for a "Rerun" (at most 3 runs).
	for _ = 1, 3 do
		if not os.execute(cmd) then
			return nil, "lualatex ist fehlgeschlagen (Details in der .log-Datei)"
		end
		local log = io.open(base .. ".log", "r")
		local content = log and log:read("a") or ""
		if log then
			log:close()
		end
		if not content:find("Rerun", 1, true) then
			break
		end
	end

	-- Remove auxiliary files
	os.remove(base .. ".aux")
	if not options.keep_log then
		os.remove(base .. ".log")
	end
	return base .. ".pdf"
end

return M
