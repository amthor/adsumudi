local json = require("dkjson.dkjson")
local typst = require("rechenblatt.typst")

describe("typst.render", function()
	local sheet = {
		tasks = {
			{ op = "add", a = 12, b = 7, result = 19 },
			{ op = "mul", a = 3, b = 4, result = 12 },
		},
		min = 1,
		max = 100,
		operations = { "add", "mul" },
		minutes = 5,
		code = "1-AM-1-100-2-4711",
	}

	local function decode(text)
		local data, _, err = json.decode(text, 1, json.null)
		assert.is_nil(err)
		return data
	end

	it("liefert die Template-Daten mit deutschen Feldnamen als JSON", function()
		local data = decode(typst.render(sheet))
		assert.are.equal("Rechenblatt", data.titel)
		assert.are.equal("Plus, Mal im Zahlenraum 1 bis 100", data.beschreibung)
		assert.are.equal("5", data.minuten)
		assert.are.equal("1-AM-1-100-2-4711", data.blattcode)
		assert.are.equal(3, data.stellen)
		assert.is_false(data.debug)
		assert.are.same({ { loesung = false } }, data.seiten)
		assert.are.same({ art = "add", a = 12, b = 7, ergebnis = 19 }, data.aufgaben[1])
		assert.are.same({ art = "mul", a = 3, b = 4, ergebnis = 12 }, data.aufgaben[2])
	end)

	it("übernimmt Titel, Lösungsseite und Debug", function()
		local data = decode(typst.render(sheet, { title = "Test", solutions = true, debug = true }))
		assert.are.equal("Test", data.titel)
		assert.are.same({ { loesung = false }, { loesung = true } }, data.seiten)
		assert.is_true(data.debug)
	end)

	it("lässt Sonderzeichen im Titel unverändert (Typst braucht kein Escaping)", function()
		local title = 'Übung: 3 & 4 – "50%" #tolles_Blatt $x$ \\ {}'
		assert.are.equal(title, decode(typst.render(sheet, { title = title })).titel)
	end)

	it("schreibt fehlende Werte als null statt das Feld wegzulassen", function()
		local s = {}
		for k, v in pairs(sheet) do
			s[k] = v
		end
		s.minutes, s.code = nil, nil
		local text = typst.render(s)
		assert.truthy(text:find('"minuten":null', 1, true))
		assert.truthy(text:find('"blattcode":null', 1, true))
	end)
end)
