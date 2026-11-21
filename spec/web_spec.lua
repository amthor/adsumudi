local json = require("dkjson.dkjson")
local sheet = require("rechenblatt.sheet")
local typst = require("rechenblatt.typst")
local web = require("rechenblatt.web")

-- Calls web.generate like the browser does: table -> JSON -> Lua -> JSON -> table.
local function generate(request)
	local response = json.decode(web.generate(json.encode(request)))
	return response
end

describe("web.defaults", function()
	it("liefert die Voreinstellungen des Kerns und den Standardtitel", function()
		assert.are.same({
			operations = { "add", "sub" },
			min = 1,
			max = 100,
			minutes = 5,
			title = "Rechenblatt",
		}, json.decode(web.defaults()))
	end)
end)

describe("web.generate", function()
	it("erzeugt ein Blatt aus den Formularwerten", function()
		local r = generate({
			settings = { operations = { "mul", "div" }, min = 1, max = 100, count = 10 },
			presentation = { solutions = true },
		})
		assert.is_true(r.ok)
		assert.are.equal(10, r.count)
		assert.truthy(r.code:match("^1%-MD%-1%-100%-10%-%d+$"))
		assert.are.equal("Mal, Geteilt im Zahlenraum 1 bis 100", r.description)
		local data = json.decode(r.source)
		assert.are.equal("Rechenblatt", data.titel)
		assert.are.equal(2, #data.seiten)
		assert.are.equal(10, #data.aufgaben)
	end)

	it("liefert für einen Blattcode exakt die Daten, die auch das CLI an Typst gibt", function()
		local r = generate({ settings = { code = "1-AS-1-100-6-12345" }, presentation = { title = "Nachdruck" } })
		assert.is_true(r.ok)
		local expected = typst.render(sheet.generate({ code = "1-AS-1-100-6-12345" }), { title = "Nachdruck" })
		assert.are.equal(expected, r.source)
		assert.are.same({ art = "add", a = 85, b = 8, ergebnis = 93 }, json.decode(r.source).aufgaben[1])
	end)

	it("ein Blattcode hat Vorrang vor den übrigen Formularfeldern", function()
		local r = generate({ settings = { code = " 1-as-1-100-6-12345 ", operations = { "mul" }, max = 20, minutes = 3 } })
		assert.is_true(r.ok)
		assert.are.equal("1-AS-1-100-6-12345", r.code)
		assert.are.equal(json.null, json.decode(r.source, 1, json.null).minuten)
	end)

	it("ein leerer Blattcode oder Titel zählt als nicht angegeben", function()
		local r = generate({ settings = { code = "  ", count = 4 }, presentation = { title = " " } })
		assert.is_true(r.ok)
		assert.are.equal(4, r.count)
		assert.are.equal("Rechenblatt", r.title)
	end)

	it("akzeptiert Minuten mit Komma und ganze Zahlen in Gleitkommaform", function()
		assert.is_true(generate({ settings = { minutes = 2.5 } }).ok)
		local r = json.decode(web.generate('{"settings": {"count": 6.0}}'))
		assert.is_true(r.ok)
		assert.are.equal(6, r.count)
	end)

	it("meldet ungültige Eingaben als ok = false mit deutscher Meldung", function()
		local cases = {
			{ '{"settings": {"operations": ["add", "wurzel"]}}', "unbekannte Rechenart: wurzel" },
			{ '{"settings": {"operations": []}}', "mindestens eine Rechenart muss gewählt sein" },
			{ '{"settings": {"count": 2.5}}', "die Anzahl muss eine ganze Zahl sein" },
			{ '{"settings": {"max": "viel"}}', "Max muss eine ganze Zahl sein" },
			{ '{"settings": {"min": 50, "max": 50}}', "Max muss größer als Min sein" },
			{ '{"settings": {"code": "9-AS-1-100-6-1"}}', "stammt von Generator-Version 9" },
			{ '{"settings": {"operations": "add"}}', "die Rechenarten müssen eine Liste sein" },
			{ "{kaputt", "ungültige Anfrage" },
			{ "[]", "ungültige Anfrage" },
		}
		for _, case in ipairs(cases) do
			local r = json.decode(web.generate(case[1]))
			assert.is_false(r.ok, case[1])
			assert.truthy(r.error:find(case[2], 1, true), r.error)
		end
	end)
end)
