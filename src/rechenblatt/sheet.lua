-- Core API: turns sheet settings into a fully determined sheet.
--
-- This is the one entry point every frontend uses (CLI today, GUI later).
-- It does no I/O and never exits the program: errors are returned as
-- `nil, message`, with messages that do not mention any CLI flags.
-- Presentation (title, solution page, output format) is not its business.

local tasks = require("rechenblatt.tasks")
local rng = require("rechenblatt.rng")
local sheet_code = require("rechenblatt.sheet_code")

local M = {}

-- Domain defaults: addition and subtraction up to 100, enough for 5 minutes.
M.DEFAULTS = {
	min = 1,
	max = 100,
	operations = { "add", "sub" },
	minutes = 5,
}

local function copy_list(list)
	local result = {}
	for i, v in ipairs(list) do
		result[i] = v
	end
	return result
end

local KNOWN_OPERATIONS = {}
for _, op in ipairs(tasks.OPERATIONS) do
	KNOWN_OPERATIONS[op] = true
end

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

local function resolve(settings)
	settings = settings or {}
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
-- @param settings {operations?, min?, max?, count?, minutes?, seed?, code?}
--        count takes precedence over minutes; code overrides everything.
-- @return {operations, min, max, count, minutes?, seed} or nil, message
function M.resolve(settings)
	local ok, result = pcall(resolve, settings)
	if not ok then
		return nil, tostring(result)
	end
	return result
end

--- Generates a sheet.
-- @param settings see M.resolve
-- @return sheet {tasks, operations, min, max, count, minutes?, seed, code}
--         or nil, message
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
