local rng = require("rechenblatt.rng")

describe("rng.new", function()
	it("liefert für Seed 1 die festgelegte Folge (plattform- und versionsunabhängig)", function()
		-- Reference values of mulberry32, cross-checked against an independent
		-- implementation. If this fails, every existing sheet code is broken.
		local rnd = rng.new(1)
		local values = {}
		for i = 1, 5 do
			values[i] = rnd(0, 0xFFFFFFFF)
		end
		assert.are.same({ 2693262067, 11749833, 2265367787, 4213581821, 4159151403 }, values)

		rnd = rng.new(1)
		values = {}
		for i = 1, 8 do
			values[i] = rnd(1, 100)
		end
		assert.are.same({ 68, 34, 88, 22, 4, 53, 65, 21 }, values)
	end)

	it("ist mit gleichem Seed reproduzierbar, mit anderem nicht", function()
		local a, b, c = rng.new(4711), rng.new(4711), rng.new(4712)
		local same, different = true, false
		for _ = 1, 50 do
			local x, y, z = a(1, 1000), b(1, 1000), c(1, 1000)
			same = same and x == y
			different = different or x ~= z
		end
		assert.is_true(same)
		assert.is_true(different)
	end)

	it("bleibt im Bereich und trifft alle Werte", function()
		local rnd = rng.new(42)
		local hits = {}
		for _ = 1, 2000 do
			local x = rnd(3, 7)
			assert.is_true(x >= 3 and x <= 7)
			assert.are.equal("integer", math.type(x))
			hits[x] = true
		end
		for x = 3, 7 do
			assert.is_true(hits[x])
		end
		assert.are.equal(5, rnd(5, 5))
	end)

	it("versteht rnd(n) wie math.random(n)", function()
		local rnd = rng.new(7)
		for _ = 1, 200 do
			local x = rnd(6)
			assert.is_true(x >= 1 and x <= 6)
		end
	end)

	it("lehnt ungültige Seeds und Bereiche ab", function()
		assert.has_error(function()
			rng.new(-1)
		end)
		assert.has_error(function()
			rng.new(1.5)
		end)
		assert.has_error(function()
			rng.new(1)(5, 4)
		end)
	end)
end)
