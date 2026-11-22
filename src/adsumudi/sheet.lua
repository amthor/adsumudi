-- sheet.lua
-- Core API: turns sheet settings into a fully determined sheet.
--
-- This is the single entry point both frontends (CLI and web app) use. Does no
-- I/O and never exits the program. Errors are returned as `nil, string`, with
-- frontend-neutral messages (i.e., not relating to CLI flags). Logic here is
-- oblivious to presentation details (title, solution page, output format).

local tasks = require("adsumudi.tasks")
local rng = require("adsumudi.rng")
local sheet_code = require("adsumudi.sheet_code")

--- Sheet data generated.
--- @class SheetData
--- @field tasks      Task[]
--- @field operations Operation[]
--- @field min        integer
--- @field max        integer
--- @field count      integer
--- @field minutes    number?
--- @field seed       integer
--- @field code       string

local M = {}

--- Domain defaults: addition and subtraction up to 100, enough for 5 minutes.
--- @type table
M.DEFAULTS = {
	min = 1,
	max = 100,
	operations = { "add", "sub" },
	minutes = 5,
}

--- Makes a shallow copy of table `list`.
--- @param list table
--- @return table
local function copy_list(list)
	local result = {}
	for i, v in ipairs(list) do
		result[i] = v
	end
	return result
end

--- List of all operations declared in `tasks.lua`.
--- @type { [string]: boolean }
local KNOWN_OPERATIONS = {}
for _, op in ipairs(tasks.OPERATIONS) do
	KNOWN_OPERATIONS[op] = true
end

--- Validates settings.
--  **Throws error:** validation fails.
--- @param s Settings
local function validate(s)
	if #s.operations == 0 then
		error("mindestens eine Rechenart muss gewählt sein", 0)
	end
	for _, op in ipairs(s.operations) do
		if not KNOWN_OPERATIONS[op] then
			error("unbekannte Rechenart: " .. tostring(op), 0)
		end
	end
	if s.min < 0 then
		error("Min darf nicht negativ sein", 0)
	end
	if s.max <= s.min then
		error("Max muss größer als Min sein", 0)
	end
	if s.count and s.count < 1 then
		error("die Anzahl muss mindestens 1 sein", 0)
	end
	if s.minutes and s.minutes <= 0 then
		error("die Minuten müssen größer als 0 sein", 0)
	end
	if s.seed and (s.seed < 0 or s.seed > 0xFFFFFFFF) then
		error("der Seed muss zwischen 0 und 4294967295 liegen", 0)
	end
end

--- Resolves settings: apply defaults for options not given, validate resulting
--- settings.
--  **Throws error:** validation fails.
--- @param settings Settings?
--- @return Settings
local function resolve(settings)
	settings = settings or {}
	--- @type Settings
	local s = {
		operations = copy_list(settings.operations or M.DEFAULTS.operations),
		min = settings.min or M.DEFAULTS.min,
		max = settings.max or M.DEFAULTS.max,
		count = settings.count,
		minutes = settings.minutes,
		seed = settings.seed,
	}

	if settings.code then
		-- A sheet code fully determines the tasks and overrides everything else.
		for key, v in pairs(sheet_code.decode(settings.code)) do
			s[key] = v
		end
		s.minutes = nil -- presentation only, not part of the code
	elseif not s.count then
		s.minutes = s.minutes or M.DEFAULTS.minutes
	end

	validate(s)

	if s.count then
		s.minutes = nil
	else
		s.count = tasks.count_for_minutes(s.minutes, s.operations)
	end
	-- At most five digits keep the sheet code short; collisions are harmless.
	s.seed = s.seed or os.time() % 100000
	return s
end

--- Applies defaults, a sheet code, validation, count and seed.
--  `count` takes precedence over `minutes`; `code` overrides everything.
--- @param settings Settings
--- @return Settings|nil, string? if `nil`: append a German error message
function M.resolve(settings)
	local ok, result = pcall(resolve, settings)
	if not ok then
		return nil, tostring(result)
	end
	return result
end

--- Generates a sheet.
--- @param settings Settings
--- @return SheetData|nil, string? sheet data or `nil` and a message on error
function M.generate(settings)
	local s, err = M.resolve(settings)
	if not s then
		return nil, err
	end
	local ok, list = pcall(tasks.generate_list, s, rng.new(s.seed))
	if not ok then
		return nil, tostring(list)
	end
	s.tasks = list
	s.code = sheet_code.encode(s)
	return s
end

return M
