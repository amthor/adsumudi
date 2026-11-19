-- Typst backend: serializes the template view (view.lua) to JSON, which
-- templates/rechenblatt.typ reads via sys.inputs. Unlike LaTeX, no escaping
-- is needed: Typst inserts JSON strings literally, never as markup.

local json = require("dkjson.dkjson")
local view = require("rechenblatt.view")

local M = {}

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

return M
