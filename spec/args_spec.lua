local args = require("adsumudi.args")

describe("args.parse", function()
	it("liefert ohne Argumente leere Einstellungen und die Ausgabe-Voreinstellungen", function()
		local o = args.parse({})
		assert.are.same({}, o.settings)
		assert.is_nil(o.output) -- the CLI picks the file name
		assert.are.equal("typst", o.backend)
		assert.is_false(o.source_only)
		assert.are.equal("Rechenblatt", o.title)
		assert.is_false(o.solutions)
		assert.is_false(o.debug)
		assert.is_nil(o.help)
	end)

	it("--version fordert die Versionsausgabe an", function()
		assert.is_true(args.parse({ "--version" }).version)
		assert.is_nil(args.parse({}).version)
	end)

	it("--satz wählt das Satzsystem, --quelle nur die Quelle", function()
		assert.are.equal("latex", args.parse({ "--satz", "latex" }).backend)
		assert.are.equal("typst", args.parse({ "--satz", "Typst" }).backend)
		assert.is_true(args.parse({ "--quelle" }).source_only)
		assert.has_error(function()
			args.parse({ "--satz", "word" })
		end)
		assert.has_error(function()
			args.parse({ "-p" }) -- removed: PDF is the default now
		end)
	end)

	it("trennt Blatt-Einstellungen von Ausgabe-Optionen", function()
		local o = args.parse({
			"-n",
			"8",
			"-t",
			"10",
			"--min",
			"2",
			"--max",
			"50",
			"-s",
			"7",
			"-l",
			"-o",
			"x.pdf",
			"--titel",
			"T",
		})
		assert.are.same({ count = 8, minutes = 10, min = 2, max = 50, seed = 7 }, o.settings)
		assert.is_true(o.solutions)
		assert.are.equal("x.pdf", o.output)
		assert.are.equal("T", o.title)
	end)

	it("--debug und --hilfe", function()
		assert.is_true(args.parse({ "--debug" }).debug)
		assert.is_true(args.parse({ "-d" }).debug)
		assert.is_true(args.parse({ "--hilfe" }).help)
		assert.is_true(args.parse({ "-h" }).help)
	end)

	it("versteht Rechenzeichen und Namen", function()
		local o = args.parse({ "-r", "+,*,:,minus" })
		assert.are.same({ "add", "mul", "div", "sub" }, o.settings.operations)
	end)

	it("meldet ungültige Argumente", function()
		for _, argv in ipairs({ { "-r", "wurzel" }, { "--max", "abc" }, { "--foo" }, { "-n" }, { "-n", "2.5" } }) do
			assert.has_error(function()
				args.parse(argv)
			end)
		end
	end)

	it("liefert ganze Zahlen als Lua-Integer", function()
		assert.are.equal("integer", math.type(args.parse({ "-s", "5.0" }).settings.seed))
	end)

	it("--blattcode landet unverändert in den Einstellungen", function()
		local o = args.parse({ "--blattcode", "1-MD-2-50-12-48213", "-l", "--titel", "Nachdruck" })
		assert.are.same({ code = "1-MD-2-50-12-48213" }, o.settings)
		assert.is_true(o.solutions)
		assert.are.equal("Nachdruck", o.title)
		assert.are.equal("1-AS-1-100-22-1", args.parse({ "-c", "1-AS-1-100-22-1" }).settings.code)
	end)

	it("--blattcode lässt sich nicht mit festlegenden Optionen kombinieren", function()
		for _, extra in ipairs({
			{ "-r", "add" },
			{ "--min", "2" },
			{ "--max", "50" },
			{ "-n", "4" },
			{ "-t", "3" },
			{ "-s", "1" },
		}) do
			local argv = { "--blattcode", "1-AS-1-100-22-1", extra[1], extra[2] }
			assert.error_matches(function()
				args.parse(argv)
			end, "--blattcode kann nicht mit", 1, true)
		end
	end)
end)
