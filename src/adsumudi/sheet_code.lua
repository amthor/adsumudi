-- sheet_code.lua
-- Sheet code ("Blattcode"): everything needed to regenerate a sheet's tasks.
--
-- Format: <version>-<operations>-<min>-<max>-<count>-<seed>, e.g. 1-AS-1-100-22-48213
--   version     tasks.GENERATOR_VERSION at the time the sheet was generated
--   operations  one letter per operation, in the given order (the order
--               affects the round-robin distribution): A=add, S=sub, M=mul, D=div
--   count       the resolved number of tasks (not the minutes), so tuning
--               tasks.SECONDS_PER_TASK does not invalidate old codes
-- Title and the "Zeit: etwa N Minuten" hint are presentation, not part of the code.

local tasks = require("adsumudi.tasks")

local M = {}

--- Code letter per operation.
--- @type { [Operation]: string }
local LETTER = { add = "A", sub = "S", mul = "M", div = "D" }

--- Operation per code letter.
--- @type { [string]: Operation }
local OPERATION = { A = "add", S = "sub", M = "mul", D = "div" }

--- Builds the sheet code from fully resolved settings.
--  **Throws error:** unknown operation.
--- @param opts ResolvedSettings
--- @return string
function M.encode(opts)
	local letters = {}
	for i, op in ipairs(opts.operations) do
		letters[i] = assert(LETTER[op], "unknown operation: " .. tostring(op))
	end
	return ("%d-%s-%d-%d-%d-%d"):format(
		tasks.GENERATOR_VERSION,
		table.concat(letters),
		opts.min,
		opts.max,
		opts.count,
		opts.seed
	)
end

--- Rejects a sheet code.
--  **Throws error:** always, with a German message naming the code.
--- @param code   string
--- @param reason string
local function fail(code, reason)
	error(("ungültiger Blattcode '%s': %s"):format(code, reason), 0)
end

--- Parses one numeric part of a sheet code.
--  **Throws error:** not a non-negative integer.
--- @param code  string whole code, for the message
--- @param field string German field name, for the message
--- @param text  string
--- @return integer
local function parse_number(code, field, text)
	if not text:match("^%d+$") then
		fail(code, ("%s muss eine nicht-negative ganze Zahl sein, nicht '%s'"):format(field, text))
	end
	return math.tointeger(tonumber(text)) --[[@as integer]]
end

--- Parses a sheet code.
--  Case-insensitive, surrounding whitespace is ignored.
--  **Throws error:** malformed code or other generator version.
--- @param input string
--- @return ResolvedSettings without minutes
function M.decode(input)
	local code = tostring(input):match("^%s*(.-)%s*$"):upper()
	--- @type string[]
	local parts = {}
	for part in (code .. "-"):gmatch("([^-]*)-") do
		parts[#parts + 1] = part
	end
	if #parts ~= 6 then
		fail(code, "erwartet 6 durch '-' getrennte Teile (Version-Rechenarten-Min-Max-Anzahl-Seed)")
	end

	local version = parse_number(code, "Version", parts[1])
	if version ~= tasks.GENERATOR_VERSION then
		fail(
			code,
			("stammt von Generator-Version %d, dieses Programm hat Version %d"):format(version, tasks.GENERATOR_VERSION)
		)
	end

	--- @type Operation[]
	local operations = {}
	--- @type { [Operation]: boolean }
	local seen = {}
	if parts[2] == "" then
		fail(code, "keine Rechenarten angegeben")
	end
	for letter in parts[2]:gmatch(".") do
		local op = OPERATION[letter]
		if not op then
			fail(code, ("unbekannte Rechenart '%s' (erlaubt: A, S, M, D)"):format(letter))
		end
		if seen[op] then
			fail(code, ("Rechenart '%s' doppelt"):format(letter))
		end
		seen[op] = true
		operations[#operations + 1] = op
	end

	return {
		operations = operations,
		min = parse_number(code, "Min", parts[3]),
		max = parse_number(code, "Max", parts[4]),
		count = parse_number(code, "Anzahl", parts[5]),
		seed = parse_number(code, "Seed", parts[6]),
	}
end

return M
