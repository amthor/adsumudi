-- Command line parsing: turns argv into sheet settings and output options.
--
-- Only knows about flags. Domain defaults, validation and the resolution of
-- minutes and sheet codes live in the core API (sheet.lua).

local M = {}

-- Output/presentation defaults of the CLI (domain defaults: sheet.DEFAULTS).
M.DEFAULTS = {
	output = "rechenblatt.tex",
	title = "Rechenblatt",
	solutions = false,
	pdf = false,
	debug = false,
}

M.HELP = [[
Aufruf: lua rechenblatt.lua [Optionen]

Erzeugt ein Mathe-Übungsblatt als LaTeX-Datei (optional als PDF).

Optionen:
  -n, --anzahl N        Anzahl der Aufgaben (hat Vorrang vor --minuten)
  -t, --minuten M       Bearbeitungsdauer in Minuten (Standard: 5)
      --min N           kleinste Zahl (Standard: 1)
      --max N           größte Zahl (Standard: 100)
  -r, --rechenarten L   Kommaliste aus add,sub,mul,div bzw. + - * :
                        (Standard: add,sub)
  -l, --loesungen       Lösungsblatt als zweite Seite anhängen
  -o, --ausgabe DATEI   Ausgabedatei (Standard: rechenblatt.tex)
  -p, --pdf             PDF mit lualatex erzeugen
  -c, --blattcode CODE  Blatt aus dem Blattcode (Fußzeile) exakt nachbauen;
                        legt Rechenarten, Zahlenbereich, Anzahl und Seed fest
  -s, --seed N          Zufallsstartwert (für Tests; zum Nachbauen --blattcode)
      --titel TEXT      Überschrift (Standard: Rechenblatt)
  -d, --debug           Layout-Debugging: Boxen sichtbar machen
                        (lua-visual-debug), .log-Datei behalten
  -h, --hilfe           diese Hilfe anzeigen

Beispiele:
  lua rechenblatt.lua --pdf
  lua rechenblatt.lua -r mul,div --max 100 -n 30 -l --pdf
  lua rechenblatt.lua -r +,-,*,: -t 10 -o test.tex
  lua rechenblatt.lua --blattcode 1-AS-1-100-22-48213 -l --pdf
]]

local ALIASES = {
	add = "add",
	["+"] = "add",
	plus = "add",
	sub = "sub",
	["-"] = "sub",
	minus = "sub",
	mul = "mul",
	["*"] = "mul",
	x = "mul",
	mal = "mul",
	div = "div",
	[":"] = "div",
	["/"] = "div",
	geteilt = "div",
}

local function parse_operations(text)
	local operations, seen = {}, {}
	for part in text:gmatch("[^,%s]+") do
		local op = ALIASES[part:lower()]
		if not op then
			error("unbekannte Rechenart: " .. part, 0)
		end
		if not seen[op] then
			seen[op] = true
			operations[#operations + 1] = op
		end
	end
	if #operations == 0 then
		error("keine Rechenart angegeben", 0)
	end
	return operations
end

local function number(name, value, integer)
	local n = tonumber(value)
	if not n then
		error(("%s erwartet eine Zahl, nicht '%s'"):format(name, tostring(value)), 0)
	end
	if integer then
		n = math.tointeger(n)
		if not n then
			error(name .. " erwartet eine ganze Zahl", 0)
		end
	end
	return n
end

--- Parses the arguments.
-- @return {settings, output, title, solutions, pdf, debug, help?}
--         settings holds only what was given: {operations?, min?, max?,
--         count?, minutes?, seed?, code?} (input for sheet.generate).
-- Errors are raised via error(msg, 0).
function M.parse(args)
	local o = {}
	for key, v in pairs(M.DEFAULTS) do
		o[key] = v
	end
	local settings = {}
	o.settings = settings
	-- Options that a sheet code determines; remembered for the conflict check.
	local explicit = {}
	local i = 1
	local function value(name)
		i = i + 1
		local v = args[i]
		if v == nil then
			error("Option " .. name .. " braucht einen Wert", 0)
		end
		return v
	end

	while i <= #args do
		local a = args[i]
		if a == "-h" or a == "--hilfe" or a == "--help" then
			o.help = true
		elseif a == "-c" or a == "--blattcode" then
			settings.code = value(a)
		elseif a == "-n" or a == "--anzahl" then
			explicit[#explicit + 1] = "--anzahl"
			settings.count = number(a, value(a), true)
		elseif a == "-t" or a == "--minuten" then
			explicit[#explicit + 1] = "--minuten"
			settings.minutes = number(a, value(a))
		elseif a == "--min" then
			explicit[#explicit + 1] = "--min"
			settings.min = number(a, value(a), true)
		elseif a == "--max" then
			explicit[#explicit + 1] = "--max"
			settings.max = number(a, value(a), true)
		elseif a == "-r" or a == "--rechenarten" then
			explicit[#explicit + 1] = "--rechenarten"
			settings.operations = parse_operations(value(a))
		elseif a == "-l" or a == "--loesungen" then
			o.solutions = true
		elseif a == "-o" or a == "--ausgabe" then
			o.output = value(a)
		elseif a == "-p" or a == "--pdf" then
			o.pdf = true
		elseif a == "-s" or a == "--seed" then
			explicit[#explicit + 1] = "--seed"
			settings.seed = number(a, value(a), true)
		elseif a == "--titel" then
			o.title = value(a)
		elseif a == "-d" or a == "--debug" then
			o.debug = true
		else
			error("unbekannte Option: " .. a, 0)
		end
		i = i + 1
	end

	if settings.code and #explicit > 0 then
		error(
			("--blattcode kann nicht mit %s kombiniert werden: "):format(table.concat(explicit, ", "))
				.. "der Blattcode legt Rechenarten, Zahlenbereich, Anzahl und Seed bereits fest",
			0
		)
	end
	return o
end

return M
