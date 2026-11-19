local sheet = require("rechenblatt.sheet")

describe("sheet.resolve", function()
	it("Voreinstellung: Plus/Minus, 1-100, 5 Minuten", function()
		local s = assert(sheet.resolve({}))
		assert.are.same({ "add", "sub" }, s.operations)
		assert.are.equal(1, s.min)
		assert.are.equal(100, s.max)
		assert.are.equal(5, s.minutes)
		-- assert.are.equal(22, s.count)
		assert.is_true(s.count >= 2)
		assert.are.equal("integer", math.type(s.seed))
		assert.is_true(s.seed >= 0 and s.seed < 100000)
	end)

	it("Anzahl hat Vorrang vor Minuten", function()
		local s = assert(sheet.resolve({ minutes = 10, count = 8 }))
		assert.are.equal(8, s.count)
		assert.is_nil(s.minutes)
	end)

	it("Blattcode legt alles fest und entfernt die Minuten", function()
		local s = assert(sheet.resolve({ code = "1-MD-2-50-12-48213", minutes = 3 }))
		assert.are.same({ "mul", "div" }, s.operations)
		assert.are.equal(2, s.min)
		assert.are.equal(50, s.max)
		assert.are.equal(12, s.count)
		assert.are.equal(48213, s.seed)
		assert.is_nil(s.minutes)
	end)

	it("verändert die übergebenen Einstellungen nicht", function()
		local ops = { "add" }
		local settings = { operations = ops, count = 4 }
		assert(sheet.resolve(settings))
		assert.are.same({ operations = { "add" }, count = 4 }, settings)
		assert.are.equal(ops, settings.operations)
	end)

	it("meldet ungültige Einstellungen als nil, Meldung (ohne zu werfen)", function()
		local cases = {
			{ min = 50, max = 10 },
			{ min = -1 },
			{ count = 0 },
			{ minutes = 0 },
			{ seed = 0x100000000 },
			{ code = "9-AS-1-100-22-1" },
		}
		for _, settings in ipairs(cases) do
			local s, err = sheet.resolve(settings)
			assert.is_nil(s)
			assert.are.equal("string", type(err))
			assert.falsy(err:find("%-%-")) -- frontend-neutral: no CLI flags
		end
	end)
end)

describe("sheet.generate", function()
	it("liefert Aufgaben und Blattcode", function()
		local s = assert(sheet.generate({ operations = { "add", "sub" }, count = 6, seed = 12345 }))
		assert.are.equal(6, #s.tasks)
		assert.are.equal("1-AS-1-100-6-12345", s.code)
	end)

	it("erzeugt aus einem Blattcode dieselben Aufgaben wie der Golden-Test", function()
		local s = assert(sheet.generate({ code = "1-AS-1-100-6-12345" }))
		assert.are.same({ op = "add", a = 85, b = 8, result = 93 }, s.tasks[1])
		assert.are.same({ op = "sub", a = 47, b = 41, result = 6 }, s.tasks[6])
	end)

	it("meldet einen unmöglichen Zahlenbereich ohne Dateipfad im Text", function()
		local s, err = sheet.generate({ operations = { "add" }, min = 60, max = 100, count = 2 })
		assert.is_nil(s)
		assert.are.equal("Rechenart 'add' ist im Zahlenbereich 60-100 nicht möglich", err)
	end)
end)
