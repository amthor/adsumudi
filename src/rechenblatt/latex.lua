-- LaTeX backend: fills templates/rechenblatt.tex.etlua with the template view
-- (view.lua) and adds what is LaTeX-specific: escaping and TeX operator symbols.
-- The layout lives entirely in the template.

local etlua = require("etlua")
local view = require("rechenblatt.view")

local M = {}

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
		local f = assert(io.open(M.TEMPLATE_PATH, "r"))
		local source = f:read("a")
		f:close()
		compiled = assert(etlua.compile(source))
	end
	return compiled
end

--- Builds the complete .tex document.
-- @param sheet        result of sheet.generate
-- @param presentation {title?, solutions?, debug?}
function M.render(sheet, presentation)
	local data = view.build(sheet, presentation)
	data.titel = M.escape(data.titel)
	data.blattcode = data.blattcode and M.escape(data.blattcode)
	data.operator = OPERATOR
	return template()(data)
end

return M
