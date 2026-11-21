-- Web frontend adapter: JSON request -> sheet -> Typst data, JSON response.
--
-- Counterpart of cli.lua for the browser GUI in web/. The page talks to Lua
-- through exactly one JSON string in each direction. That keeps Wasmoon's
-- automatic JS <-> Lua type conversion out of the picture, and it makes this
-- module testable with plain Lua (spec/web_spec.lua).
--
-- Like the CLI, it only builds `settings` and calls sheet.generate; domain
-- validation stays in sheet.lua. This module only checks that the request
-- has the right shape and types (the browser form cannot guarantee that).

local json = require("dkjson.dkjson")
local sheet = require("rechenblatt.sheet")
local typst = require("rechenblatt.typst")
local view = require("rechenblatt.view")

local M = {}

M.DEFAULT_TITLE = "Rechenblatt"

-- Stable key order for responses (dkjson otherwise follows pairs()).
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

local function encode(value)
	return json.encode(value, { keyorder = KEY_ORDER })
end

-- Input checks. Names in messages are the German field labels of the form.

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

local function number(value, label)
	if value ~= nil and type(value) ~= "number" then
		error(label .. " muss eine Zahl sein", 0)
	end
	return value
end

local function text(value, label)
	if value ~= nil and type(value) ~= "string" then
		error(label .. " muss ein Text sein", 0)
	end
	return value
end

local function operations(value)
	if value == nil then
		return nil
	end
	if type(value) ~= "table" then
		error("die Rechenarten müssen eine Liste sein", 0)
	end
	local list = {}
	for i, op in ipairs(value) do
		list[i] = text(op, "eine Rechenart")
	end
	return list
end

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
-- @return JSON {operations, min, max, minutes, title}
function M.defaults()
	local d = sheet.DEFAULTS
	return encode({
		operations = d.operations,
		min = d.min,
		max = d.max,
		minutes = d.minutes,
		title = M.DEFAULT_TITLE,
	})
end

local function generate(request_json)
	local request, _, err = json.decode(request_json)
	-- dkjson marks decoded arrays with __jsontype = "array"; only objects are valid.
	if type(request) ~= "table" or (getmetatable(request) or {}).__jsontype == "array" then
		error("ungültige Anfrage: " .. tostring(err or "kein JSON-Objekt"), 0)
	end
	local s = object(request.settings, "settings")
	local p = object(request.presentation, "presentation")

	-- A sheet code overrides everything else (sheet.resolve), so the form may
	-- send its other fields along unchanged.
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
-- @param request_json JSON {settings = {operations?, min?, max?, count?,
--        minutes?, code?}, presentation = {title?, solutions?}}
-- @return JSON {ok = true, code, count, description, title, source} where
--         source is the data for templates/rechenblatt.typ (sys.inputs.daten),
--         or {ok = false, error = message}
function M.generate(request_json)
	local ok, result = pcall(generate, request_json)
	if not ok then
		return encode({ ok = false, error = tostring(result) })
	end
	return encode(result)
end

return M
