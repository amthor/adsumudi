local cli = require("adsumudi.cli")
local json = require("dkjson.dkjson")

-- In-memory stream that collects everything written to it.
local function stream()
	local s = { text = "" }
	function s:write(...)
		self.text = self.text .. table.concat({ ... })
		return self
	end
	return s
end

local function read_file(path)
	local f = assert(io.open(path, "rb"))
	local content = f:read("a")
	f:close()
	return content
end

local function command_exists(name)
	return os.execute("command -v " .. name .. " > /dev/null 2>&1") == true
end

describe("cli.main", function()
	it("--hilfe gibt die Hilfe aus und liefert 0", function()
		local out, err = stream(), stream()
		assert.are.equal(0, cli.main({ "--hilfe" }, out, err))
		assert.truthy(out.text:find("Aufruf:", 1, true))
		assert.are.equal("", err.text)
	end)

	it("Fehler liefern 1 mit Meldung", function()
		local cases = {
			{ { "--foo" }, "Fehler: unbekannte Option: --foo" },
			{
				{ "--min", "60", "-r", "add", "--quelle" },
				"Fehler: Rechenart 'add' ist im Zahlenbereich 60-100 nicht möglich",
			},
			{ { "-o", "blatt.tex" }, "Fehler: die Ausgabedatei muss auf .pdf enden" },
		}
		for _, case in ipairs(cases) do
			local out, err = stream(), stream()
			assert.are.equal(1, cli.main(case[1], out, err))
			assert.matches(case[2], err.text, 1, true)
		end
	end)

	it("--quelle schreibt bei Typst die JSON-Daten", function()
		local path = os.tmpname()
		local out, err = stream(), stream()
		assert.are.equal(0, cli.main({ "-c", "1-AS-1-100-6-12345", "--quelle", "-o", path }, out, err))
		local data = json.decode(read_file(path))
		os.remove(path)
		assert.are.same({ art = "add", a = 85, b = 8, ergebnis = 93 }, data.aufgaben[1])
		assert.are.equal("1-AS-1-100-6-12345", data.blattcode)
		assert.truthy(out.text:find("Quelle geschrieben (6 Aufgaben): " .. path, 1, true))
		assert.truthy(out.text:find("Blattcode: 1-AS-1-100-6-12345", 1, true))
		assert.are.equal("", err.text)
	end)

	it("--quelle schreibt bei LaTeX das .tex-Dokument", function()
		local path = os.tmpname()
		local out, err = stream(), stream()
		assert.are.equal(
			0,
			cli.main({ "-c", "1-AS-1-100-6-12345", "--satz", "latex", "--quelle", "-o", path }, out, err)
		)
		local tex = read_file(path)
		os.remove(path)
		assert.truthy(tex:find("\\begin{document}", 1, true))
		assert.truthy(tex:find("\\aufgabe{85}{+}{8}{\\luecke}", 1, true))
		assert.are.equal("", err.text)
	end)

	-- Without typst the test is only listed as pending.
	local it_typst = command_exists("typst") and it or pending
	it_typst("erzeugt mit Typst ein PDF (nur wenn typst installiert ist)", function()
		local path = os.tmpname() .. ".pdf"
		local out, err = stream(), stream()
		assert.are.equal(0, cli.main({ "-c", "1-AS-1-100-6-12345", "-l", "-o", path }, out, err))
		local pdf = read_file(path)
		os.remove(path)
		assert.are.equal("%PDF", pdf:sub(1, 4))
		assert.truthy(out.text:find("PDF erzeugt (6 Aufgaben): " .. path, 1, true))
		assert.are.equal("", err.text)
	end)
end)
