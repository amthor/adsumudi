-- Deterministic pseudo-random number generator (mulberry32).
--
-- Unlike math.random, the sequence for a given seed is identical on every
-- platform and Lua version >= 5.3: only integer arithmetic, masked to 32 bits.
-- This is what makes a sheet code reproducible.

local M = {}

local MASK = 0xFFFFFFFF
local RANGE = MASK + 1 -- 2^32

-- 32-bit multiplication: the low 32 bits of a 64-bit product are exact even
-- when the product wraps around.
local function imul(a, b)
	return (a * b) & MASK
end

--- Creates a random function with a fixed seed.
-- @param seed non-negative integer (only the low 32 bits are used)
-- @return rnd(m, n) with the semantics of math.random(m, n): uniformly
--         distributed integer in [m, n]; rnd(n) is the same as rnd(1, n).
function M.new(seed)
	local state = math.tointeger(seed)
	if not state or state < 0 then
		error("Seed muss eine nicht-negative ganze Zahl sein: " .. tostring(seed))
	end
	state = state & MASK

	local function next_u32()
		state = (state + 0x6D2B79F5) & MASK
		local t = state
		t = imul(t ~ (t >> 15), t | 1)
		t = (t ~ (t + imul(t ~ (t >> 7), t | 61))) & MASK
		return (t ~ (t >> 14)) & MASK
	end

	return function(m, n)
		if n == nil then
			m, n = 1, m
		end
		local span = n - m + 1
		if span < 1 or span > RANGE then
			error(("ungültiger Bereich für Zufallszahl: [%s, %s]"):format(tostring(m), tostring(n)))
		end
		-- Rejection sampling: discard the top remainder of the 32-bit range so
		-- that every value in [m, n] is equally likely (no modulo bias).
		local limit = RANGE - (RANGE % span)
		local x
		repeat
			x = next_u32()
		until x < limit
		return m + x % span
	end
end

return M
