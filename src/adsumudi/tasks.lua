-- tasks.lua
-- Generation of arithmetic tasks for primary school.
--
-- Rules (suitable for 3rd grade):
--
-- - All operands lie in the number range [min, max].
-- - All results lie in [0, max] – no negative numbers.
-- - Division always works out without remainder.
-- - Multiplication/division avoid the trivial factors 0 and 1 whenever
--   the number range allows it.

--- Arithmetic operation identifier.
--- @alias Operation "add"|"sub"|"mul"|"div"

--- Task description.
--- @class Task
--- @field op     Operation
--- @field a      number
--- @field b      number
--- @field result number

--- What a task list is generated from.
--  ResolvedSettings (sheet.lua) extends this with minutes and seed.
--- @class TaskListOptions
--- @field operations Operation[]
--- @field min        integer
--- @field max        integer
--- @field count      integer

--- Operand generator for one operation.
--  Returns nil when the operation is impossible within [min, max].
--- @alias Generator fun(rnd: Rnd, min: integer, max: integer): integer|nil, integer?

local M = {}

--- Version of the task generation, part of every sheet code.
--  MUST be incremented whenever the same inputs (operations, range, count,
--  seed) would produce different tasks, e.g. after changing a generator, the
--  distribution or the shuffle. Old codes are then rejected with a clear
--  message instead of silently yielding another sheet. The golden test in
--  spec/tasks_spec.lua fails when this is forgotten.
--- @type integer
M.GENERATOR_VERSION = 1

--- All operations, in canonical order.
--- @type Operation[]
M.OPERATIONS = { "add", "sub", "mul", "div" }

--- Plain-text operator symbols.
--- @type { [Operation]: string }
M.SYMBOLS = { add = "+", sub = "-", mul = "*", div = ":" }

--- Estimated time per task in seconds (3rd grade, numbers up to 100).
--  Basis for deriving the task count from a duration.
--- @type { [Operation]: number }
M.SECONDS_PER_TASK = { add = 17, sub = 20, mul = 15, div = 20 }

--- Attempts before giving up on a random draw (operands, duplicates).
--- @type integer
local MAX_ATTEMPTS = 1000

--- Computes the result of a task.
--  **Throws error:** unknown operation.
--- @param op Operation
--- @param a  integer
--- @param b  integer
--- @return integer
local function compute(op, a, b)
	if op == "add" then
		return a + b
	elseif op == "sub" then
		return a - b
	elseif op == "mul" then
		return a * b
	elseif op == "div" then
		return a // b
	end
	error("unbekannte Rechenart: " .. tostring(op))
end
M.compute = compute

--- Smallest sensible factor for multiplication/division.
--- @param min integer
--- @param max integer
--- @return integer
local function min_factor(min, max)
	local f = math.max(min, 2)
	if f * f > max then
		f = math.max(min, 1)
	end
	return f
end

--- Operands for an addition whose sum stays within max.
--- @param rnd Rnd
--- @param min integer
--- @param max integer
--- @return integer|nil, integer? both operands; nil if impossible
local function generate_add(rnd, min, max)
	if min + min > max then
		return nil
	end
	local a = rnd(min, max - min)
	local b = rnd(min, max - a)
	return a, b
end

--- Operands for a subtraction without a negative result.
--- @param rnd Rnd
--- @param min integer
--- @param max integer
--- @return integer, integer
local function generate_sub(rnd, min, max)
	local a = rnd(min, max)
	local b = rnd(min, max)
	if b > a then
		a, b = b, a
	end
	return a, b
end

--- Largest factor for multiplication/division.
--  Up to 100 the small multiplication table (up to 10), for larger ranges up
--  to sqrt(max). Without this cap, tasks like 48 · 2 dominate, because a large
--  first factor forces the second one to be small.
--- @param max integer
--- @return integer
local function max_factor(max)
	return math.max(10, math.floor(math.sqrt(max)))
end

--- Factors for a multiplication whose product stays within max.
--- @param rnd Rnd
--- @param min integer
--- @param max integer
--- @return integer|nil, integer? both factors; nil if impossible
local function generate_mul(rnd, min, max)
	local fmin = min_factor(min, max)
	if fmin * fmin > max then
		return nil
	end
	local fmax = math.min(max_factor(max), max // fmin)

	-- Both factors uniformly distributed; products that are too large are rejected.
	for _ = 1, MAX_ATTEMPTS do
		local a, b = rnd(fmin, fmax), rnd(fmin, fmax)
		if a * b <= max then
			return a, b
		end
	end
	return fmin, fmin
end

--- Dividend and divisor for a division without remainder.
--- @param rnd Rnd
--- @param min integer
--- @param max integer
--- @return integer|nil, integer? dividend and divisor; nil if impossible
local function generate_div(rnd, min, max)
	-- Dividend = divisor * quotient, all three within the range.
	local a, b = generate_mul(rnd, min, max)
	if not a then
		return nil
	end
	--- @cast b integer generate_mul returns both factors or none
	local dividend = a * b
	if dividend < min then
		return nil
	end
	return dividend, b
end

--- Operand generator per operation.
--- @type { [Operation]: Generator }
local GENERATORS = {
	add = generate_add,
	sub = generate_sub,
	mul = generate_mul,
	div = generate_div,
}

--- Generates a single task.
--  **Throws error:** unknown operation.
--- @param op  Operation
--- @param min integer
--- @param max integer
--- @param rnd Rnd?     random function (default math.random)
--- @return Task|nil task; nil if the operation is impossible within the range
function M.generate(op, min, max, rnd)
	rnd = rnd or math.random
	local generator = GENERATORS[op]
	if not generator then
		error("unbekannte Rechenart: " .. tostring(op))
	end
	local a, b = generator(rnd, min, max)
	if not a then
		return nil
	end
	--- @cast b integer generators return both operands or none
	return { op = op, a = a, b = b, result = compute(op, a, b) }
end

--- Identity of a task, for detecting duplicates.
--- @param task Task
--- @return string
local function key(task)
	return task.op .. ":" .. task.a .. ":" .. task.b
end

--- Generates a list of tasks.
--  Operations are distributed as evenly as possible and shuffled; duplicates
--  are avoided as long as the number range offers enough variety.
--  **Throws error:** an operation is impossible within the range.
--- @param opts TaskListOptions
--- @param rnd  Rnd?            random function (default math.random)
--- @return Task[]
function M.generate_list(opts, rnd)
	rnd = rnd or math.random
	local operations = opts.operations
	--- @type Task[]
	local list = {}
	--- @type { [string]: boolean }
	local seen = {}

	for i = 1, opts.count do
		local op = operations[(i - 1) % #operations + 1]
		--- @type Task
		local task
		for _ = 1, MAX_ATTEMPTS do
			local candidate = M.generate(op, opts.min, opts.max, rnd)
			if not candidate then
				error(("Rechenart '%s' ist im Zahlenbereich %d-%d nicht möglich"):format(op, opts.min, opts.max), 0)
			end
			task = candidate
			if not seen[key(candidate)] then
				break
			end
		end
		seen[key(task)] = true
		list[#list + 1] = task
	end

	-- Fisher-Yates: shuffle the operations.
	for i = #list, 2, -1 do
		local j = rnd(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

--- Computes the number of tasks for a given duration.
--  The result is rounded to an even number (two-column layout).
--- @param minutes    number
--- @param operations Operation[]
--- @return integer
function M.count_for_minutes(minutes, operations)
	local sum = 0
	for _, op in ipairs(operations) do
		sum = sum + M.SECONDS_PER_TASK[op]
	end
	local average = sum / #operations
	local n = math.floor(minutes * 60 / average + 0.5)
	n = n + (n % 2)
	return math.max(n, 2)
end

return M
