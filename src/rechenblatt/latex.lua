-- LaTeX backend (alternative to Typst, --satz latex): fills
-- templates/rechenblatt.tex.etlua with the template view (view.lua) and adds
-- what is LaTeX-specific: escaping and TeX operator symbols. The layout lives
-- entirely in the template. Same backend interface as typst.lua.
--
-- etlua is loaded only when this backend is actually used, so the default
-- Typst backend works without it.

local view = require("rechenblatt.view")
local shell = require("rechenblatt.shell")

local M = {}

M.SOURCE_EXT = "tex"

local OPERATOR = {
	add = "+",
	sub = "-",
	mul = "\\cdot",
	div = ":",
}

-- The template is located relative to this module: src/rechenblatt/ -> ../../templates/
local MODULE_DIR = debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or "."
M.TEMPLATE_PATH = MODULE_DIR .. "/../../templates/rechenblatt.tex.etlua"

local TEX_SPECIAL_CHARS = {
	["\\"] = "\\textbackslash{}",
	["{"] = "\\{",
	["}"] = "\\}",
	["#"] = "\\#",
	["$"] = "\\$",
	["%"] = "\\%",
	["&"] = "\\&",
	["_"] = "\\_",
	["^"] = "\\^{}",
	["~"] = "\\~{}",
}

--- Escapes LaTeX special characters in free text (e.g. --titel).
function M.escape(text)
	return (tostring(text):gsub("[\\{}#$%%&_^~]", TEX_SPECIAL_CHARS))
end

local compiled
local function template()
	if not compiled then
		local found, etlua = pcall(require, "etlua")
		if not found then
			error(
				"Lua-Modul 'etlua' fehlt (nur für --satz latex nötig). Installieren mit: luarocks install --local etlua",
				0
			)
		end
		local f = assert(io.open(M.TEMPLATE_PATH, "r"))
		local source = f:read("a")
		f:close()
		compiled = assert(etlua.compile(source))
	end
	return compiled
end

--- Builds the complete .tex document (raises an error if etlua is missing).
-- @param sheet        result of sheet.generate
-- @param presentation {title?, solutions?, debug?}
function M.render(sheet, presentation)
	local data = view.build(sheet, presentation)
	data.titel = M.escape(data.titel)
	data.blattcode = data.blattcode and M.escape(data.blattcode)
	data.operator = OPERATOR
	return template()(data)
end

--- Compiles the PDF with lualatex.
-- The .tex file is written next to the PDF (same name, .tex) and removed
-- afterwards together with .aux/.log, unless options.keep_files (debug mode).
-- @param source   .tex document from M.render
-- @param pdf_path path of the PDF to create; must end in .pdf
-- @param options  {keep_files?}
-- @return pdf_path, or nil, message
function M.build(source, pdf_path, options)
	options = options or {}
	local base = pdf_path:gsub("%.pdf$", "")
	local tex_path = base .. ".tex"
	local f, err = io.open(tex_path, "w")
	if not f then
		return nil, err
	end
	f:write(source)
	f:close()

	local dir = tex_path:match("^(.*)[/\\]") or "."
	local file = tex_path:match("([^/\\]+)$")
	local cmd = ("cd %s && lualatex -interaction=nonstopmode -halt-on-error %s > /dev/null"):format(
		shell.quote(dir),
		shell.quote(file)
	)

	-- The total page count (lastpage) is only known after another run:
	-- repeat as long as the log asks for a "Rerun" (at most 3 runs).
	for _ = 1, 3 do
		if not os.execute(cmd) then
			return nil, "lualatex ist fehlgeschlagen (Details in " .. base .. ".log)"
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
	if not options.keep_files then
		os.remove(base .. ".log")
		os.remove(tex_path)
	end
	return pdf_path
end

return M
