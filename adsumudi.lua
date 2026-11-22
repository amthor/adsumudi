#!/usr/bin/env lua
-- Adsumudi: generates math practice worksheets (primary school) as PDF
-- (typeset with Typst, alternatively LaTeX).

-- Module paths relative to the script (src/ for our modules, the root for
-- vendored libraries such as dkjson/), so it can be run from any directory
local script_dir = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
package.path = script_dir .. "/src/?.lua;" .. script_dir .. "/?.lua;" .. package.path

-- Find modules installed with luarocks (etlua for --satz latex), including
-- ~/.luarocks. The LaTeX backend reports a missing etlua itself.
pcall(require, "luarocks.loader")

os.exit(require("adsumudi.cli").main(arg))
