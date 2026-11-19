-- Command line frontend: argv -> core API -> .tex file (-> PDF).
--
-- Contains no domain logic of its own; it only connects args, sheet, latex
-- and pdf, and turns errors into German messages and an exit code.

local args = require("rechenblatt.args")
local sheet = require("rechenblatt.sheet")
local latex = require("rechenblatt.latex")
local pdf = require("rechenblatt.pdf")

local M = {}

--- Runs the CLI.
-- @param argv   list of arguments
-- @param out    stream for normal output (default io.stdout)
-- @param errout stream for error messages (default io.stderr)
-- @return exit code (0 = success, 1 = error)
function M.main(argv, out, errout)
	out = out or io.stdout
	errout = errout or io.stderr

	local function fail(message)
		errout:write("Fehler: ", tostring(message), "\n", "Hilfe mit: lua rechenblatt.lua --hilfe\n")
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

	local result, err = sheet.generate(opts.settings)
	if not result then
		return fail(err)
	end

	local tex = latex.render(result, { title = opts.title, solutions = opts.solutions, debug = opts.debug })
	local f, open_err = io.open(opts.output, "w")
	if not f then
		return fail(open_err)
	end
	f:write(tex)
	f:close()
	out:write(("%d Aufgaben geschrieben: %s\n"):format(#result.tasks, opts.output))
	out:write("Blattcode: ", result.code, "\n")

	if opts.pdf then
		local pdf_path, pdf_err = pdf.build(opts.output, { keep_log = opts.debug })
		if not pdf_path then
			return fail(pdf_err)
		end
		out:write("PDF erzeugt: ", pdf_path, "\n")
	end
	return 0
end

return M
