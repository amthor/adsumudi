-- latex.lua
-- LaTeX backend: fills templates/adsumudi.tex.etlua with the template view
-- (view.lua), does LaTeX escaping and TeX operator symbols.
-- Same backend interface as typst.lua.

--- Template view plus what only the LaTeX template needs.
--- @class LatexView : View
--- @field operator { [Operation]: string } TeX operator symbols

local view = require("adsumudi.view")
local shell = require("adsumudi.shell")

--- @class LatexBackend : Backend
local M = {}

--- Complete .tex filename.
--- @type string
M.SOURCE_EXT = "tex"

--- TeX operator symbol per operation.
--- @type { [Operation]: string }
local OPERATOR = {
	add = "+",
	sub = "-",
	mul = "\\cdot",
	div = ":",
}

--- Directory of this module (template relative to it).
--- @type string
local MODULE_DIR = debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or "."

--- Path of etlua template: src/adsumudi/ -> ../../templates/
--- @type string
M.TEMPLATE_PATH = MODULE_DIR .. "/../../templates/adsumudi.tex.etlua"

--- Replacement of LaTeX special characters.
--- @type { [string]: string }
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
--- @param text any converted with tostring
--- @return string
function M.escape(text)
	return (tostring(text):gsub("[\\{}#$%%&_^~]", TEX_SPECIAL_CHARS))
end

--- Compiled template, cached after the first use.
--- @type (fun(data: LatexView): string)?
local compiled

--- Loads etlua and compiles the template (once).
--  etlua is loaded only when this backend is actually used (the default
--  Typst backend works without it).
--  **Throws error:** etlua is not installed; template missing or invalid.
--- @return fun(data: LatexView): string
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

--- Builds the complete .tex document.
--  **Throws error:** etlua is not installed.
--- @param sheet        SheetData
--- @param presentation Presentation?
--- @return string
function M.render(sheet, presentation)
	local data = view.build(sheet, presentation) --[[@as LatexView]]
	data.titel = M.escape(data.titel)
	data.metadaten.betreff = M.escape(data.metadaten.betreff)
	data.blattcode = data.blattcode and M.escape(data.blattcode)
	data.operator = OPERATOR
	return template()(data)
end

--- Compiles the PDF with lualatex.
--- @param source   string        .tex document from M.render
--- @param pdf_path string        path of the PDF to create; must end in .pdf
--- @param options  BuildOptions?
--- @return string|nil, string? pdf_path on success; else nil and a message
function M.build(source, pdf_path, options)
	options = options or {}
	-- .tex file is written next to the PDF (same name)
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

	-- Remove .aux file
	os.remove(base .. ".aux")
	-- remove tex and log file, unless `options.keep_files`
	if not options.keep_files then
		os.remove(base .. ".log")
		os.remove(tex_path)
	end
	return pdf_path
end

return M
