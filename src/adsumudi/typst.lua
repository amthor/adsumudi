-- Typst backend (default): serializes the template view (view.lua) to JSON,
-- which templates/adsumudi.typ reads via sys.inputs. Unlike LaTeX, no
-- escaping is needed: Typst inserts JSON strings literally, never as markup.
--
-- Backend interface (shared with latex.lua):
--   SOURCE_EXT                         extension of the source (--quelle)
--   render(sheet, presentation)        -> source text
--   build(source, pdf_path, options)   -> pdf_path, or nil, message

local json = require("dkjson.dkjson")
local view = require("adsumudi.view")
local shell = require("adsumudi.shell")

local M = {}

M.SOURCE_EXT = "json"

-- Project root relative to this module: src/adsumudi/ -> ../../
local ROOT = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]") or ".") .. "/../.."
M.TEMPLATE_PATH = ROOT .. "/templates/adsumudi.typ"
M.FONT_DIR = ROOT .. "/fonts"

-- Stable, readable key order in the JSON output.
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
}

--- Builds the JSON data for the Typst template.
-- @param sheet        result of sheet.generate
-- @param presentation {title?, solutions?, debug?}
-- @return JSON string
function M.render(sheet, presentation)
	local data = view.build(sheet, presentation)
	-- Explicit null instead of a missing key, so the template can rely on
	-- every field being present.
	data.blattcode = data.blattcode or json.null
	data.minuten = data.minuten or json.null
	return json.encode(data, { indent = true, keyorder = KEY_ORDER }) .. "\n"
end

--- Compiles the PDF with the typst CLI.
-- Only the bundled fonts are used (--ignore-system-fonts), so the result is
-- the same on every machine.
-- @param source   JSON from M.render
-- @param pdf_path path of the PDF to create
-- @return pdf_path, or nil, message (including typst's own error output)
function M.build(source, pdf_path)
	local cmd = table.concat({
		"typst compile --ignore-system-fonts",
		"--font-path " .. shell.quote(M.FONT_DIR),
		"--input " .. shell.quote("daten=" .. source),
		shell.quote(M.TEMPLATE_PATH),
		shell.quote(pdf_path),
		"2>&1",
	}, " ")
	local proc = io.popen(cmd, "r")
	local output = proc:read("a")
	local ok, _, code = proc:close()
	if ok then
		return pdf_path
	end
	if code == 127 then
		return nil,
			"typst wurde nicht gefunden. Installation z.B. mit: cargo install --locked typst-cli "
				.. "(oder --satz latex verwenden)"
	end
	return nil, "typst ist fehlgeschlagen:\n" .. output
end

return M
