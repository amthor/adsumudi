-- rng.lua
-- Deterministic pseudo-random number generator usung mulberry32.
--
-- **Rationale:** With Lua's math.random, it's not guaranteed that a randomized
-- number sequence is stable between version transisions. This module's
-- raison-d'être is to reliably produce the same sequence for a given seed on
-- every platform and Lua version >= 5.3.

--- Random function (semantics equal `math.random(m, n)`).
--  Uniformly distributed integer in [m, n]. `rnd(n)` is the same as `rnd(1, n)`.
--- @alias Rnd fun(m: integer, n?: integer): integer

local M = {}

--- Mask for the low 32 bits.
--- @type integer
local MASK = 0xFFFFFFFF

--- Number of distinct 32-bit values (2^32).
--- @type integer
local RANGE = MASK + 1

--- 32-bit multiplication.
--  The low 32 bits of a 64-bit product are exact even when the product wraps
--  around.
--- @param a integer
--- @param b integer
--- @return integer
local function imul(a, b)
	return (a * b) & MASK
end

--- Creates a random function with a fixed seed.
--  **Throws error:** seed is not a non-negative integer.
--- @param seed integer non-negative; uses only low 32 bits
--- @return Rnd
function M.new(seed)
	local state = math.tointeger(seed)
	if not state or state < 0 then
		error("Seed muss eine nicht-negative ganze Zahl sein: " .. tostring(seed))
	end
	state = state & MASK

	--- Advances the state and returns the next 32-bit value.
	--- @return integer
	local function next_u32()
		state = (state + 0x6D2B79F5) & MASK
		local t = state
		t = imul(t ~ (t >> 15), t | 1)
		t = (t ~ (t + imul(t ~ (t >> 7), t | 61))) & MASK
		return (t ~ (t >> 14)) & MASK
	end

	--- Draws a uniformly distributed integer in [m, n] (or [1, m]).
	--  **Throws error:** empty or too large range.
	--- @param m integer
	--- @param n integer?
	--- @return integer
	return function(m, n)
		if n == nil then
			m, n = 1, m
		end
		local span = n - m + 1
		if span < 1 or span > RANGE then
			error(("ungültiger Bereich für Zufallszahl: [%s, %s]"):format(tostring(m), tostring(n)))
		end
		-- Rejection sampling:
		-- discard the top remainder of the 32-bit range so that
		-- every value in [m, n] is equally likely (no modulo bias)
		local limit = RANGE - (RANGE % span)
		local x
		repeat
			x = next_u32()
		until x < limit
		return m + x % span
	end
end

return M
