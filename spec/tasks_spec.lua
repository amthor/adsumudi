local tasks = require("adsumudi.tasks")
local rng = require("adsumudi.rng")
local sheet_code = require("adsumudi.sheet_code")

describe("tasks.generate", function()
	local function check_many(op, min, max, check)
		math.randomseed(42)
		for _ = 1, 2000 do
			local t = tasks.generate(op, min, max)
			assert.is_not_nil(t)
			check(t)
		end
	end

	it("Addition bleibt im Zahlenbereich", function()
		check_many("add", 1, 100, function(t)
			assert.is_true(t.a >= 1 and t.b >= 1)
			assert.is_true(t.result <= 100)
			assert.are.equal(t.a + t.b, t.result)
		end)
	end)

	it("Subtraktion ergibt nie negative Zahlen", function()
		check_many("sub", 1, 100, function(t)
			assert.is_true(t.a <= 100 and t.b >= 1)
			assert.is_true(t.result >= 0)
		end)
	end)

	it("Multiplikation ohne Faktor 0/1 und Produkt <= max", function()
		check_many("mul", 1, 100, function(t)
			assert.is_true(t.a >= 2 and t.b >= 2)
			assert.is_true(t.result <= 100)
		end)
	end)

	it("Multiplikation im Zahlenraum 100 nutzt das kleine Einmaleins", function()
		local zweier = 0
		check_many("mul", 1, 100, function(t)
			assert.is_true(t.a <= 10 and t.b <= 10)
			if t.a == 2 or t.b == 2 then
				zweier = zweier + 1
			end
		end)
		assert.is_true(zweier < 2000 * 0.4)
	end)

	it("Division geht ohne Rest auf", function()
		check_many("div", 1, 100, function(t)
			assert.are.equal(0, t.a % t.b)
			assert.is_true(t.a <= 100 and t.b >= 2 and t.result >= 2)
		end)
	end)

	it("liefert nil, wenn der Bereich zu klein ist", function()
		assert.is_nil(tasks.generate("add", 60, 100))
		assert.is_nil(tasks.generate("mul", 11, 100))
	end)
end)

describe("tasks.generate_list", function()
	it("erzeugt die gewünschte Anzahl, gemischt und ohne Duplikate", function()
		math.randomseed(1)
		local list = tasks.generate_list({ count = 40, min = 1, max = 100, operations = { "add", "sub" } })
		assert.are.equal(40, #list)
		local per_op, seen = {}, {}
		for _, t in ipairs(list) do
			per_op[t.op] = (per_op[t.op] or 0) + 1
			local k = t.op .. t.a .. "," .. t.b
			assert.is_nil(seen[k])
			seen[k] = true
		end
		assert.are.equal(20, per_op.add)
		assert.are.equal(20, per_op.sub)
	end)

	it("ist mit gleichem Seed reproduzierbar", function()
		local opts = { count = 10, min = 1, max = 100, operations = { "mul", "div" } }
		math.randomseed(7)
		local a = tasks.generate_list(opts)
		math.randomseed(7)
		local b = tasks.generate_list(opts)
		assert.are.same(a, b)
	end)

	it("meldet unmögliche Rechenarten", function()
		assert.has_error(function()
			tasks.generate_list({ count = 2, min = 60, max = 100, operations = { "add" } })
		end)
	end)
end)

describe("tasks.count_for_minutes", function()
	-- it("Voreinstellung: 5 Minuten Plus/Minus ergibt 22 Aufgaben", function()
	--   assert.are.equal(22, tasks.count_for_minutes(5, { "add", "sub" }))
	-- end)
	--
	it("liefert immer eine gerade Zahl >= 2", function()
		for _, m in ipairs({ 0.1, 1, 3, 7, 13 }) do
			local n = tasks.count_for_minutes(m, { "div" })
			assert.are.equal(0, n % 2)
			assert.is_true(n >= 2)
		end
	end)
end)

describe("Golden-Test: Blattcodes erzeugen immer dieselben Aufgaben", function()
	-- If this test fails, the generator now produces different tasks for the
	-- same sheet code. Then: increment tasks.GENERATOR_VERSION, update the codes
	-- and expected lists below (old codes are rejected from then on).
	local function generate(code)
		local opts = sheet_code.decode(code)
		return tasks.generate_list(opts, rng.new(opts.seed))
	end

	it("Plus/Minus", function()
		assert.are.same({
			{ op = "add", a = 85, b = 8, result = 93 },
			{ op = "add", a = 19, b = 25, result = 44 },
			{ op = "add", a = 76, b = 14, result = 90 },
			{ op = "sub", a = 53, b = 51, result = 2 },
			{ op = "sub", a = 64, b = 31, result = 33 },
			{ op = "sub", a = 47, b = 41, result = 6 },
		}, generate("1-AS-1-100-6-12345"))
	end)

	it("Mal/Geteilt", function()
		assert.are.same({
			{ op = "div", a = 70, b = 10, result = 7 },
			{ op = "mul", a = 6, b = 9, result = 54 },
			{ op = "div", a = 40, b = 4, result = 10 },
			{ op = "mul", a = 10, b = 4, result = 40 },
		}, generate("1-MD-1-100-4-777"))
	end)
end)
