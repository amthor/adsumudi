-- view.lua
-- Template view: the data every template receives.
--
-- This module is at the boundary of English internals and the user-facing, i.e. German,
-- template variables. It contains no format-specific details (escaping,
-- operator symbols), since these are added by the backend.

--- Presentation options.
--- @class Presentation
--- @field title     string?  page title
--- @field solutions boolean? solution page requested
--- @field debug     boolean? layout debugging

--- Individual metadata of a single sheet page.
--- @class ViewPage
--- @field loesung boolean true for the solution page

--- Single task as the templates see it.
--- @class ViewTask
--- @field art      Operation
--- @field a        number
--- @field b        number
--- @field ergebnis number

--- Template view (German variable names).
--- @class View
--- @field titel        string       page title
--- @field seiten       ViewPage[]   sheet plus solution if requested
--- @field aufgaben     ViewTask[]
--- @field blattcode    string?      sheet code
--- @field beschreibung string
--- @field minuten      string?      display string such as "5" or "7.5"
--- @field stellen      integer      max. number of digits in number range
--- @field debug        boolean      layout debugging requested
--- @field metadaten    ViewMeta     metadata

--- Metadata field of template view (German variable names).
--- @class ViewMeta
--- @field name                string program name
--- @field version             string program version
--- @field betreff             string PDF "subject" field
--- @field autor               string PDF "author" field
--- @field ersteller           string PDF "creator" field
--- @field entwicklerwebseite  url    repository URL
--- @field benutzerwebseite    url    web app URL
--- @field nutzungsbedingungen string usage terms of a generated sheet

local about = require("adsumudi.about")

local M = {}

--- German operation names.
--- @type { [Operation]: string }
local OPERATION_NAMES = {
    add = "Plus",
    sub = "Minus",
    mul = "Mal",
    div = "Geteilt",
}

--- Maximum number of digits in the number range.
--  Determines the width of the number boxes such that operands and results never
--  exceed `max`.
--- @param min number
--- @param max number
--- @return integer
function M.digit_count(min, max)
    return math.max(#tostring(math.floor(min)), #tostring(math.floor(max)))
end

--- Short German description of a sheet.
--  Shown under the title and in the web frontend's history (e.g., "Plus, Minus im
--  Zahlenraum 1 bis 100").
--- @param operations Operation[]
--- @param min        integer
--- @param max        integer
--- @return string
function M.describe(operations, min, max)
    --- @type string[]
    local names = {}
    for _, op in ipairs(operations) do
        names[#names + 1] = OPERATION_NAMES[op]
    end
    return ("%s im Zahlenraum %d bis %d"):format(table.concat(names, ", "), min, max)
end

--- Builds the template view.
--- @param sheet        SheetData
--- @param presentation Presentation?
--- @return View
function M.build(sheet, presentation)
    presentation = presentation or {}
    --- @type ViewPage[]
    local pages = { { loesung = false } }
    if presentation.solutions then
        pages[2] = { loesung = true }
    end
    --- @type ViewTask[]
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
        metadaten = {
            name = about.name,
            version = about.version,
            betreff = about.description,
            autor = about.pdfauthor,
            ersteller = about.pdfcreator,
            entwicklerwebseite = { url = about.urlproject.full, text = about.urlproject.display },
            benutzerwebseite = { url = about.urlweb.full, text = about.urlweb.display },
            nutzungsbedingungen = about.usageterms,
        }
    }
end

return M
