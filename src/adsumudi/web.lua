-- web.lua
-- Web GUI frontend (JSON request -> sheet -> Typst data, JSON response).
--
-- Counterpart of cli.lua for the browser GUI in web/. The page talks to Lua
-- through exactly one JSON string in each direction. That keeps Wasmoon's
-- automatic JS <-> Lua type conversion out of the picture, and it makes this
-- module testable with plain Lua (spec/web_spec.lua).
--
-- Like the CLI, it only builds `settings` and calls sheet.generate; domain
-- validation stays in sheet.lua. This module only checks that the request
-- has the right shape and types (the browser form cannot guarantee that).

--- Settings part of a request, as decoded from JSON (unchecked).
--- @class WebSettings
--- @field operations any expected: string[]
--- @field min        any expected: integer
--- @field max        any expected: integer
--- @field count      any expected: integer
--- @field minutes    any expected: number
--- @field code       any expected: string

--- Presentation part of a request, as decoded from JSON (unchecked).
--- @class WebPresentation
--- @field title     any expected: string
--- @field solutions any expected: boolean

--- Successful response before JSON encoding.
--- @class WebResult
--- @field ok          true
--- @field code        string
--- @field count       integer
--- @field description string
--- @field title       string
--- @field source      string data for templates/adsumudi.typ (`sys.inputs.daten`)

local json = require("dkjson.dkjson")
local sheet = require("adsumudi.sheet")
local typst = require("adsumudi.typst")
local view = require("adsumudi.view")
local about = require("adsumudi.about")

local M = {}

--- Title used when the request has none.
--- @type string
M.DEFAULT_TITLE = "Rechenblatt"

--- Stable key order for responses (dkjson should not use an arbitrary order
--  following from `pairs()`).
--- @type string[]
local KEY_ORDER = {
	"ok",
	"error",
	"code",
	"count",
	"description",
	"operations",
	"min",
	"max",
	"minutes",
	"title",
	"source",
}

--- Encodes a response.
--- @param value table
--- @return string JSON
local function encode(value)
	return json.encode(value, { keyorder = KEY_ORDER }) --[[@as string]]
end

-- === Input checks ===
--
-- Names in messages are (German) field labels in the form

--- Checks an optional integer.
--  **Throws error:** not an integer.
--- @param value any
--- @param label string German field label
--- @return integer?
local function integer(value, label)
	if value == nil then
		return nil
	end
	local n = type(value) == "number" and math.tointeger(value)
	if not n then
		error(label .. " muss eine ganze Zahl sein", 0)
	end
	return n
end

--- Checks an optional number.
--  **Throws error:** not a number.
--- @param value any
--- @param label string German field label
--- @return number?
local function number(value, label)
	if value ~= nil and type(value) ~= "number" then
		error(label .. " muss eine Zahl sein", 0)
	end
	return value
end

--- Checks an optional string.
--  **Throws error:** not a string.
--- @param value any
--- @param label string German field label
--- @return string?
local function text(value, label)
	if value ~= nil and type(value) ~= "string" then
		error(label .. " muss ein Text sein", 0)
	end
	return value
end

--- Checks an optional list of operation names.
--  The names themselves are validated by sheet.lua.
--  **Throws error:** not a list, or an element is not a string.
--- @param value any
--- @return string[]?
local function operations(value)
	if value == nil then
		return nil
	end
	if type(value) ~= "table" then
		error("die Rechenarten müssen eine Liste sein", 0)
	end
	--- @type string[]
	local list = {}
	for i, op in ipairs(value) do
		list[i] = text(op, "eine Rechenart")
	end
	return list
end

--- Checks an optional object of the request.
--  **Throws error:** not a table.
--- @param value any
--- @param label string name of the request part, for the message
--- @return table
local function object(value, label)
	if value == nil then
		return {}
	end
	if type(value) ~= "table" then
		error("ungültige Anfrage: " .. label .. " fehlt", 0)
	end
	return value
end

--- Settings the form starts with: the domain defaults plus the default title.
--  Response: JSON {operations, min, max, minutes, title, version}.
--- @return string JSON
function M.defaults()
	local d = sheet.DEFAULTS
	return encode({
		operations = d.operations,
		min = d.min,
		max = d.max,
		minutes = d.minutes,
		title = M.DEFAULT_TITLE,
		version = about.version,
	})
end

--- Checks the request and generates the sheet.
--  **Throws error:** invalid request, or the sheet cannot be generated.
--- @param request_json string
--- @return WebResult
local function do_generate(request_json)
	local request, _, err = json.decode(request_json)
	-- dkjson marks decoded arrays with __jsontype = "array"; only objects are valid.
	if type(request) ~= "table" or (getmetatable(request) or {}).__jsontype == "array" then
		error("ungültige Anfrage: " .. tostring(err or "kein JSON-Objekt"), 0)
	end
	--- @type WebSettings
	local s = object(request.settings, "settings")
	--- @type WebPresentation
	local p = object(request.presentation, "presentation")

	-- A sheet code overrides everything else (sheet.resolve), so the form may
	-- send its other fields along unchanged.
	--- @type Settings
	local settings = {
		operations = operations(s.operations),
		min = integer(s.min, "Min"),
		max = integer(s.max, "Max"),
		count = integer(s.count, "die Anzahl"),
		minutes = number(s.minutes, "die Minutenzahl"),
		code = text(s.code, "der Blattcode"),
	}
	if settings.code and settings.code:match("^%s*$") then
		settings.code = nil
	end

	local title = text(p.title, "der Titel")
	if not title or title:match("^%s*$") then
		title = M.DEFAULT_TITLE
	end

	local result, generate_err = sheet.generate(settings)
	if not result then
		error(generate_err, 0)
	end
	return {
		ok = true,
		code = result.code,
		count = result.count,
		description = view.describe(result.operations, result.min, result.max),
		title = title,
		source = typst.render(result, { title = title, solutions = p.solutions == true }),
	}
end

--- Generates a sheet for the web frontend.
--  Request: JSON {settings = {operations?, min?, max?, count?, minutes?, code?},
--  presentation = {title?, solutions?}} (see WebSettings, WebPresentation).
--  Response: JSON of a WebResult, or {ok = false, error = message}.
--- @param request_json string JSON
--- @return string JSON
function M.generate(request_json)
	local ok, result = pcall(do_generate, request_json)
	if not ok then
		return encode({ ok = false, error = tostring(result) })
	end
	return encode(result)
end

return M
