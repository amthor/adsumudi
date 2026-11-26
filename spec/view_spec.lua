local about = require("adsumudi.about")
local view = require("adsumudi.view")

describe("view.build", function()
	local sheet = {
		tasks = { { op = "add", a = 12, b = 7, result = 19 } },
		operations = { "add", "mul" },
		min = 1,
		max = 100,
		count = 1,
		seed = 4711,
		minutes = 5,
		code = "1-AM-1-100-1-4711",
	}

	-- Same text as in spec/pdf_spec.lua.
	local SUBJECT = "Erstellt mit Adsumudi "
		.. about.version
		.. " (https://github.com/amthor/adsumudi/). "
		.. "Dieses Blatt ist gemeinfrei (CC0 1.0) und darf ohne Einschränkung verwendet werden."

	it("enthält die Programmversion", function()
		assert.are.equal(about.version, view.build(sheet).metadaten.version)
	end)

	it("enthält Benutzer- und Entwicklerwebseite (Adresse und angezeigter Text)", function()
		local meta = view.build(sheet).metadaten
		assert.are.same(
			{ url = "https://amthor.github.io/adsumudi/", text = "amthor.github.io/adsumudi" },
			meta.benutzerwebseite
		)
		assert.are.same(
			{ url = "https://github.com/amthor/adsumudi/", text = "github.com/amthor/adsumudi" },
			meta.entwicklerwebseite
		)
	end)

	it("setzt Autor und Betreff der PDF-Metadaten", function()
		local meta = view.build(sheet).metadaten
		assert.are.equal("Adsumudi Rechenblattgenerator", meta.autor)
		assert.are.equal(SUBJECT, meta.betreff)
	end)

	it("baut die Metadaten für jedes Blatt neu (Backends dürfen sie verändern)", function()
		assert.are_not.equal(view.build(sheet).metadaten, view.build(sheet).metadaten)
	end)
end)
