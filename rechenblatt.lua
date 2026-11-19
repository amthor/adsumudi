#!/usr/bin/env lua
-- Rechenblatt: generates math practice worksheets (primary school) as LaTeX/PDF.

-- Module path relative to the script, so it can be run from any directory
local script_dir = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
package.path = script_dir .. "/src/?.lua;" .. package.path

-- Find modules installed with luarocks (etlua), including ~/.luarocks.
pcall(require, "luarocks.loader")
if not pcall(require, "etlua") then
	io.stderr:write("Fehler: Lua-Modul 'etlua' fehlt. Installieren mit:\n", "  luarocks install --local etlua\n")
	os.exit(1)
end

local config = require("rechenblatt.config")
local tasks = require("rechenblatt.tasks")
local rng = require("rechenblatt.rng")
local sheet_code = require("rechenblatt.sheet_code")
local latex = require("rechenblatt.latex")

local function fail(text)
	io.stderr:write("Fehler: ", text, "\n", "Hilfe mit: lua rechenblatt.lua --hilfe\n")
	os.exit(1)
end

local function build_pdf(tex_file, keep_log)
	local dir = tex_file:match("^(.*)[/\\]") or "."
	local file = tex_file:match("([^/\\]+)$")
	local cmd = ("cd %q && lualatex -interaction=nonstopmode -halt-on-error %q > /dev/null"):format(dir, file)
	local base = tex_file:gsub("%.tex$", "")

	-- The total page count (lastpage) is only known after another run:
	-- repeat as long as the log asks for a "Rerun" (at most 3 runs).
	for _ = 1, 3 do
		if not os.execute(cmd) then
			fail("lualatex ist fehlgeschlagen (Details in der .log-Datei)")
		end
		local log = io.open(base .. ".log", "r")
		local content = log and log:read("a") or ""
		if log then
			log:close()
		end
		if not content:find("Rerun", 1, true) then
			break
		end
	end

	-- Remove auxiliary files
	os.remove(base .. ".aux")
	if not keep_log then
		os.remove(base .. ".log")
	end
	return base .. ".pdf"
end

local function main(args)
	local ok, opts = pcall(config.parse, args)
	if not ok then
		fail(opts)
	end
	if opts.help then
		io.write(config.HELP)
		return
	end

	-- At most five digits keep the sheet code short; collisions are harmless.
	opts.seed = opts.seed or os.time() % 100000

	local ok2, list = pcall(tasks.generate_list, opts, rng.new(opts.seed))
	if not ok2 then
		fail(tostring(list):gsub("^.-:%d+: ", ""))
	end

	opts.sheet_code = sheet_code.encode(opts)

	local f, err = io.open(opts.output, "w")
	if not f then
		fail(err)
	end
	f:write(latex.render(list, opts))
	f:close()
	print(("%d Aufgaben geschrieben: %s"):format(#list, opts.output))
	print("Blattcode: " .. opts.sheet_code)

	if opts.pdf then
		print("PDF erzeugt: " .. build_pdf(opts.output, opts.debug))
	end
end

main(arg)
