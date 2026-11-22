-- args.lua
-- Command line parsing. Turns argv into sheet settings and output options.
--
-- Only knows about flags. Domain defaults, validation and the resolution of
-- minutes and sheet codes live in the core API (sheet.lua).

local M = {}

--- Output/presentation defaults of the CLI.
--  output = nil means: the CLI picks rechenblatt.pdf (or .json/.tex with --quelle).
M.DEFAULTS = {
	backend = "typst",
	source_only = false,
	title = "Rechenblatt",
	solutions = false,
	debug = false,
}

--- List of recognized backend strings.
--  Can be explicitly set `false` to disable a backend for a build.
--- @type { [string]: boolean }
M.BACKENDS = { typst = true, latex = true }

--- Help string.
--- @type string
M.HELP = [[
Aufruf: lua adsumudi.lua [Optionen]

Erzeugt ein Mathe-Übungsblatt als PDF (Satz mit Typst, alternativ LaTeX).

Optionen:
  -n, --anzahl N        Anzahl der Aufgaben (hat Vorrang vor --minuten)
  -t, --minuten M       Bearbeitungsdauer in Minuten (Standard: 5)
      --min N           kleinste Zahl (Standard: 1)
      --max N           größte Zahl (Standard: 100)
  -r, --rechenarten L   Kommaliste aus add,sub,mul,div bzw. + - * :
                        (Standard: add,sub)
  -l, --loesungen       Lösungsblatt als zweite Seite anhängen
  -o, --ausgabe DATEI   Ausgabedatei (Standard: rechenblatt.pdf)
      --satz SYSTEM     Satzsystem: typst (Standard) oder latex
      --quelle          statt des PDFs nur die Quelle schreiben: die Daten
                        als .json (typst) bzw. das Dokument als .tex (latex)
  -c, --blattcode CODE  Blatt aus dem Blattcode (Fußzeile) exakt nachbauen;
                        legt Rechenarten, Zahlenbereich, Anzahl und Seed fest
  -s, --seed N          Zufallsstartwert (für Tests; zum Nachbauen --blattcode)
      --titel TEXT      Überschrift (Standard: Rechenblatt)
  -d, --debug           Layout-Debugging: Boxen sichtbar machen
                        (latex: lua-visual-debug, .log-Datei behalten)
  -h, --hilfe           diese Hilfe anzeigen

Beispiele:
  lua adsumudi.lua
  lua adsumudi.lua -r mul,div --max 100 -n 30 -l -o mal.pdf
  lua adsumudi.lua -r +,-,*,: -t 10 --satz latex
  lua adsumudi.lua --blattcode 1-AS-1-100-22-48213 -l
  lua adsumudi.lua -t 5 -s 4711 -l --quelle -o templates/beispiel.json
]]

--- Aliases for option values.
--- @type { [string]: Operation }
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

--- Translates alternative strings to operation identifiers.
--  **Throws error:** unknown operation; no operations given.
--- @param text string
--- @return Operation[]
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

--- Translates a named argument to a number.
--  **Throws error:** `tonumber` fails; `tointeger` fails while `is_integer` is set.
--- @param name string
--- @param value string
--- @param is_integer boolean?
--- @return number
local function number(name, value, is_integer)
	local n = tonumber(value)
	if not n then
		error(("%s erwartet eine Zahl, nicht '%s'"):format(name, tostring(value)), 0)
	end
	if (is_integer ~= nil) and (is_integer == true) then
		n = math.tointeger(n)
		if not n then
			error(name .. " erwartet eine ganze Zahl", 0)
		end
	end
	return n
end

--- Parses the arguments.
--  **Throws error:** unknown or malformed option, or a conflict with --blattcode.
--- @param args string[]
--- @return { settings: Settings, output: string?, backend: string?, source_only: boolean, title: string, solutions: boolean, debug: boolean, help: boolean? }
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
	---  Gets the value of a named option.
	--   **Throws error:** missing value for a mandatory option.
	--- @param name string
	--- @return string
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
		elseif a == "--satz" then
			o.backend = value(a):lower()
			if not M.BACKENDS[o.backend] then
				error("--satz erwartet typst oder latex, nicht '" .. o.backend .. "'", 0)
			end
		elseif a == "--quelle" then
			o.source_only = true
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
