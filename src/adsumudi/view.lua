-- Template view: the data every template (Typst, LaTeX) receives.
--
-- This is the boundary between the English internals and the German
-- template variables. It contains no format-specific details (no escaping,
-- no operator symbols); each backend adds those itself.
--
-- View:
--   titel        page title, raw text
--   seiten       list of pages: { {loesung = false}, {loesung = true}? }
--   aufgaben     list of { art = "add"|"sub"|"mul"|"div", a, b, ergebnis }
--   blattcode    sheet code (string) or nil
--   beschreibung e.g. "Plus, Minus im Zahlenraum 1 bis 100"
--   minuten      display string such as "5" or "7.5", or nil
--   stellen      max. number of digits, sizes the number boxes
--   debug        layout debugging requested

local M = {}

local OPERATION_NAMES = {
	add = "Plus",
	sub = "Minus",
	mul = "Mal",
	div = "Geteilt",
}

--- Maximum number of digits in the number range; determines the width of the number boxes.
-- Operands and results never exceed max (see tasks.lua).
function M.digit_count(min, max)
	return math.max(#tostring(math.floor(min)), #tostring(math.floor(max)))
end

--- Short German description of a sheet, e.g. "Plus, Minus im Zahlenraum 1 bis 100".
-- Shown under the title and in the web frontend's history.
function M.describe(operations, min, max)
	local names = {}
	for _, op in ipairs(operations) do
		names[#names + 1] = OPERATION_NAMES[op]
	end
	return ("%s im Zahlenraum %d bis %d"):format(table.concat(names, ", "), min, max)
end

--- Builds the template view.
-- @param sheet        result of sheet.generate:
--                     {tasks, operations, min, max, minutes?, code?}
-- @param presentation {title?, solutions?, debug?}
function M.build(sheet, presentation)
	presentation = presentation or {}
	local pages = { { loesung = false } }
	if presentation.solutions then
		pages[2] = { loesung = true }
	end
	local tasks = {}
	for i, task in ipairs(sheet.tasks) do
		tasks[i] = { art = task.op, a = task.a, b = task.b, ergebnis = task.result }
	end
	return {
		titel = presentation.title or "Rechenblatt",
		seiten = pages,
		aufgaben = tasks,
		blattcode = sheet.code,
		beschreibung = M.describe(sheet.operations, sheet.min, sheet.max),
		minuten = sheet.minutes and (tostring(sheet.minutes):gsub("%.0$", "")),
		stellen = M.digit_count(sheet.min, sheet.max),
		debug = presentation.debug or false,
	}
end

return M
