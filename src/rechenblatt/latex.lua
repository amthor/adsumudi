-- Fills the LaTeX template (templates/rechenblatt.tex.etlua) with a task list.
-- The layout lives entirely in the template; this module only prepares the data.
-- The variables visible to the template deliberately have German names
-- (seiten, aufgaben, blattcode, ...); everything internal is named in English.

local etlua = require("etlua")

local M = {}

local OPERATOR = {
	add = "+",
	sub = "-",
	mul = "\\cdot",
	div = ":",
}

local OPERATION_NAMES = {
	add = "Plus",
	sub = "Minus",
	mul = "Mal",
	div = "Geteilt",
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

local function describe_sheet(operations, min, max)
	local names = {}
	for _, op in ipairs(operations) do
		names[#names + 1] = OPERATION_NAMES[op]
	end
	return ("%s im Zahlenraum %d bis %d"):format(table.concat(names, ", "), min, max)
end

--- Maximum number of digits in the number range; determines the width of the number boxes.
-- Operands and results never exceed max (see tasks.lua).
function M.digit_count(min, max)
	return math.max(#tostring(math.floor(min)), #tostring(math.floor(max)))
end

-- Translate tasks into the template's view: {art, a, b, ergebnis}.
local function template_tasks(list)
	local result = {}
	for i, task in ipairs(list) do
		result[i] = { art = task.op, a = task.a, b = task.b, ergebnis = task.result }
	end
	return result
end

--- Builds the complete .tex document.
-- @param sheet        result of sheet.generate:
--                     {tasks, operations, min, max, minutes?, code}
-- @param presentation {title?, solutions?, debug?}
function M.render(sheet, presentation)
	presentation = presentation or {}
	local title = M.escape(presentation.title or "Rechenblatt")
	local pages = { { titel = title, loesung = false } }
	if presentation.solutions then
		pages[2] = { titel = title .. " -- Lösungen", loesung = true }
	end
	return template()({
		seiten = pages,
		aufgaben = template_tasks(sheet.tasks),
		blattcode = sheet.code and M.escape(sheet.code),
		operator = OPERATOR,
		beschreibung = describe_sheet(sheet.operations, sheet.min, sheet.max),
		minuten = sheet.minutes and (tostring(sheet.minutes):gsub("%.0$", "")),
		stellen = M.digit_count(sheet.min, sheet.max),
		debug = presentation.debug or false,
	})
end

return M
