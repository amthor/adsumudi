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

os.exit(require("rechenblatt.cli").main(arg))
