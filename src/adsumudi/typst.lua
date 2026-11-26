-- typst.lua
-- Typst backend: serializes the template view (view.lua) to JSON, which
-- templates/adsumudi.typ reads via `sys.inputs`.

--- Options for building the PDF.
--- @class BuildOptions
--- @field keep_files boolean? keep intermediate files (debug mode)

--- Interface of a rendering backend.
--- @class Backend
--- @field SOURCE_EXT string source file extension
--- @field render     fun(sheet: SheetData, presentation: Presentation?): string
--- @field build      fun(source: string, pdf_path: string, options: BuildOptions?): string|nil, string?

local json = require("dkjson.dkjson")
local view = require("adsumudi.view")
local shell = require("adsumudi.shell")

--- Template view as JSON data.
--- @class TypstData : View
--- @field blattcode string|table sheet code (or `json.null`)
--- @field minuten   string|table display string (or `json.null`)

--- @class TypstBackend : Backend
local M = {}

--- Extension of the source (JSON template data).
--- @type string
M.SOURCE_EXT = "json"

--- Project root relative to this module.
--- @type string
local ROOT = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or ".") .. "/../.."

--- Path of the Typst template.
--- @type string
M.TEMPLATE_PATH = ROOT .. "/templates/adsumudi.typ"

--- Directory of the bundled fonts (the only ones Typst may use).
--- @type string
M.FONT_DIR = ROOT .. "/fonts"

--- Stable, readable key order in the JSON output.
--- @type string[]
local KEY_ORDER = {
    "titel",
    "beschreibung",
    "minuten",
    "blattcode",
    "stellen",
    "debug",
    "seiten",
    "aufgaben",
    "loesung",
    "art",
    "a",
    "b",
    "ergebnis",
    "metadaten",
    -- from here metadata fields
    "name",
    "version",
    "betreff",
    "autor",
    "ersteller",
    "entwicklerwebseite",
    "benutzerwebseite",
    "nutzungsbedingungen",
    "url",
    "text",
}

--- Builds the JSON data for the Typst template.
--- @param sheet        SheetData
--- @param presentation Presentation?
--- @return string JSON
function M.render(sheet, presentation)
    local data = view.build(sheet, presentation) --[[@as TypstData]]
    -- explicit null instead of a missing key
    -- (template can make sure that every field is present)
    data.blattcode = data.blattcode or json.null
    data.minuten = data.minuten or json.null
    return json.encode(data, { indent = true, keyorder = KEY_ORDER }) .. "\n"
end

--- Compiles PDF with the typst CLI.
--  **Throws error:** the shell cannot be started.
--- @param source   string JSON from M.render
--- @param pdf_path string path of the PDF to create
--- @return string|nil, string? pdf_path on success; nil and typst output otherwise
function M.build(source, pdf_path)
    local cmd = table.concat({
        "typst compile --ignore-system-fonts", -- make sure our bundled fonts are used
        "--font-path " .. shell.quote(M.FONT_DIR),
        "--input " .. shell.quote("daten=" .. source),
        shell.quote(M.TEMPLATE_PATH),
        shell.quote(pdf_path),
        "2>&1",
    }, " ")
    local proc = assert(io.popen(cmd, "r"))
    local output = proc:read("a")
    local ok, _, code = proc:close()
    if ok then
        return pdf_path
    end
    if code == 127 then
        return nil, "typst nicht gefunden (installieren mit `cargo install --locked typst-cli`)"
    end
    return nil, "typst ist fehlgeschlagen:\n" .. output
end

return M
