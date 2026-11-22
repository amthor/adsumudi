-- cli.lua
-- Command line frontend.
--
-- Connects args, sheet and the selected backend, and turns errors into (German)
-- messages and an exit code. Contains no domain logic of its own.

local args = require("adsumudi.args")
local sheet = require("adsumudi.sheet")

local M = {}

--- Backends interfaces.
--- @type { [string]: string }
local BACKENDS = {
	typst = "adsumudi.typst",
	latex = "adsumudi.latex",
}

--- Runs the CLI.
--- @param argv   string[] list of CL arguments
--- @param out    file*?   stream for normal output (default io.stdout)
--- @param errout file*?   stream for error messages (default io.stderr)
--- @return integer exit code (0 = success, 1 = error)
function M.main(argv, out, errout)
	out = out or io.stdout
	errout = errout or io.stderr

	--- Bubble up any error message.
	--- @param message any
	--- @return integer
	local function fail(message)
		errout:write("Fehler: ", tostring(message), "\n", "Hilfe mit: lua adsumudi.lua --hilfe\n")
		return 1
	end

	local ok, opts = pcall(args.parse, argv)
	if not ok then
		return fail(opts)
	end
	if opts.help then
		out:write(args.HELP)
		return 0
	end

	--- @type Backend
	local backend = require(BACKENDS[opts.backend])
	local output = opts.output or (opts.source_only and "rechenblatt." .. backend.SOURCE_EXT or "rechenblatt.pdf")
	if not opts.source_only and not output:match("%.pdf$") then
		return fail("die Ausgabedatei muss auf .pdf enden (für die Quelle: --quelle)")
	end

	local result, err = sheet.generate(opts.settings)
	if not result then
		return fail(err)
	end

	local rendered, source =
		pcall(backend.render, result, { title = opts.title, solutions = opts.solutions, debug = opts.debug })
	if not rendered then
		return fail(source)
	end

	if opts.source_only then
		local f, open_err = io.open(output, "w")
		if not f then
			return fail(open_err)
		end
		f:write(source)
		f:close()
		out:write(("Quelle geschrieben (%d Aufgaben): %s\n"):format(#result.tasks, output))
	else
		local pdf_path, build_err = backend.build(source, output, { keep_files = opts.debug })
		if not pdf_path then
			return fail(build_err)
		end
		out:write(("PDF erzeugt (%d Aufgaben): %s\n"):format(#result.tasks, pdf_path))
	end
	out:write("Blattcode: ", result.code, "\n")
	return 0
end

return M
