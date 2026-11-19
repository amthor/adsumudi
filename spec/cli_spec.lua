local cli = require("rechenblatt.cli")

-- In-memory stream that collects everything written to it.
local function stream()
	local s = { text = "" }
	function s:write(...)
		self.text = self.text .. table.concat({ ... })
		return self
	end
	return s
end

describe("cli.main", function()
	it("--hilfe gibt die Hilfe aus und liefert 0", function()
		local out, err = stream(), stream()
		assert.are.equal(0, cli.main({ "--hilfe" }, out, err))
		assert.truthy(out.text:find("Aufruf:", 1, true))
		assert.are.equal("", err.text)
	end)

	it("ungültige Option und unmöglicher Bereich liefern 1 mit Fehlermeldung", function()
		local out, err = stream(), stream()
		assert.are.equal(1, cli.main({ "--foo" }, out, err))
		assert.truthy(err.text:find("Fehler: unbekannte Option: --foo", 1, true))

		err = stream()
		assert.are.equal(1, cli.main({ "--min", "60", "-r", "add" }, out, err))
		assert.truthy(err.text:find("Fehler: Rechenart 'add' ist im Zahlenbereich 60-100 nicht möglich", 1, true))
	end)

	it("schreibt die .tex-Datei und meldet den Blattcode", function()
		local path = os.tmpname()
		local out, err = stream(), stream()
		assert.are.equal(0, cli.main({ "-c", "1-AS-1-100-6-12345", "-o", path }, out, err))
		local f = assert(io.open(path, "r"))
		local tex = f:read("a")
		f:close()
		os.remove(path)
		assert.truthy(tex:find("\\begin{document}", 1, true))
		assert.truthy(tex:find("\\aufgabe{85}{+}{8}{\\luecke}", 1, true))
		assert.truthy(out.text:find("6 Aufgaben geschrieben: " .. path, 1, true))
		assert.truthy(out.text:find("Blattcode: 1-AS-1-100-6-12345", 1, true))
		assert.are.equal("", err.text)
	end)
end)
