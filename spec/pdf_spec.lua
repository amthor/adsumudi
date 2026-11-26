-- Checks the finished PDFs of both backends: metadata, link and footer.
-- Needs pdfinfo and pdftotext (poppler). A backend's tests are pending
-- without typst, or without lualatex and etlua.

local cli = require("adsumudi.cli")
local shell = require("adsumudi.shell")
local about = require("adsumudi.about")

local CODE = "1-AS-1-100-22-48213"
local TITLE = "Übung: 3 & 4 (50%) a_b"
-- Same text as in spec/view_spec.lua.
local SUBJECT = "Erstellt mit Adsumudi "
	.. about.version
	.. " (https://github.com/amthor/adsumudi/). "
	.. "Dieses Blatt ist gemeinfrei (CC0 1.0) und darf ohne Einschränkung verwendet werden."
-- Same tolerance as the layout comparison of the task area (CLAUDE.md).
local TOLERANCE = 0.7
-- Everything below this y coordinate (pt from the top) belongs to the footer.
local FOOTER_TOP = 760

local function command_exists(name)
	return os.execute("command -v " .. name .. " > /dev/null 2>&1") == true
end

local function read_command(cmd)
	local p = assert(io.popen(cmd, "r"))
	local text = p:read("a")
	p:close()
	return text
end

-- Stream that discards everything.
local function silent()
	local s = {}
	function s:write()
		return self
	end
	return s
end

local poppler = command_exists("pdfinfo") and command_exists("pdftotext")
local available = {
	typst = poppler and command_exists("typst"),
	latex = poppler and command_exists("lualatex") and (pcall(require, "etlua")),
}

-- One PDF per backend, built on first use (LaTeX needs a few seconds).
local built = {}
local function pdf(backend)
	if not built[backend] then
		local path = os.tmpname() .. ".pdf"
		local code = cli.main({ "-c", CODE, "-l", "--titel", TITLE, "--satz", backend, "-o", path }, silent(), silent())
		assert.are.equal(0, code)
		built[backend] = path
	end
	return built[backend]
end

-- pdfinfo fields such as Title, Author, Subject.
local function info(path)
	local fields = {}
	for line in read_command("pdfinfo " .. shell.quote(path)):gmatch("[^\n]+") do
		local key, value = line:match("^(%w+):%s*(.-)%s*$")
		if key then
			fields[key] = value
		end
	end
	return fields
end

-- Text of one page with whitespace collapsed.
local function page_text(path, page)
	local text = read_command(("pdftotext -f %d -l %d %s -"):format(page, page, shell.quote(path)))
	return (text:gsub("%s+", " "))
end

-- Part of the footer a word belongs to, by the middle of the word.
local function region(w)
	local width = 595.28 -- A4
	local middle = (w.x0 + w.x1) / 2
	if middle < width / 3 then
		return "left"
	elseif middle > 2 * width / 3 then
		return "right"
	end
	return "centre"
end

-- Words of the footer on page 1: {text, x0, y0, x1}, sorted by y, then x.
local function footer_words(path)
	local words = {}
	local xml = read_command("pdftotext -f 1 -l 1 -bbox " .. shell.quote(path) .. " -")
	for x0, y0, x1, text in
		xml:gmatch('<word xMin="([%d.]+)" yMin="([%d.]+)" xMax="([%d.]+)" yMax="[%d.]+">([^<]*)</word>')
	do
		if tonumber(y0) > FOOTER_TOP then
			words[#words + 1] = { text = text, x0 = tonumber(x0), y0 = tonumber(y0), x1 = tonumber(x1) }
		end
	end
	table.sort(words, function(a, b)
		if a.y0 ~= b.y0 then
			return a.y0 < b.y0
		end
		return a.x0 < b.x0
	end)
	-- The page number "1 / 2" is three words in Typst but one in LaTeX, whose
	-- spaces are below pdftotext's word gap. Merge the centre into one word.
	local merged, centre = {}, nil
	for _, w in ipairs(words) do
		if region(w) == "centre" then
			if centre then
				centre.text = centre.text .. w.text
				centre.x0, centre.x1 = math.min(centre.x0, w.x0), math.max(centre.x1, w.x1)
				centre.y0 = math.min(centre.y0, w.y0)
			else
				centre = { text = w.text, x0 = w.x0, y0 = w.y0, x1 = w.x1 }
				merged[#merged + 1] = centre
			end
		else
			merged[#merged + 1] = w
		end
	end
	return merged
end

-- Horizontal anchors of the footer, in line order: the start of each line
-- in the left third, the end of each line in the right third, and the middle
-- of the centre part (page number).
local function anchors(words)
	local result = { left = {}, right = {} }
	local left_line, right_line -- y of the current line on each side
	local centre_min, centre_max = math.huge, -math.huge
	for _, w in ipairs(words) do
		local where = region(w)
		if where == "left" then
			if not left_line or math.abs(w.y0 - left_line) > 1 then
				left_line = w.y0
				result.left[#result.left + 1] = w.x0
			else
				result.left[#result.left] = math.min(result.left[#result.left], w.x0)
			end
		elseif where == "right" then
			if not right_line or math.abs(w.y0 - right_line) > 1 then
				right_line = w.y0
				result.right[#result.right + 1] = w.x1
			else
				result.right[#result.right] = math.max(result.right[#result.right], w.x1)
			end
		else
			centre_min, centre_max = math.min(centre_min, w.x0), math.max(centre_max, w.x1)
		end
	end
	result.centre = (centre_min + centre_max) / 2
	return result
end

describe("PDF", function()
	teardown(function()
		for _, path in pairs(built) do
			os.remove(path)
		end
	end)

	for _, backend in ipairs({ "typst", "latex" }) do
		local test = available[backend] and it or pending

		describe(backend, function()
			test("trägt Titel, Autor und Betreff in die Metadaten ein", function()
				local fields = info(pdf(backend))
				assert.are.equal(TITLE, fields.Title)
				assert.are.equal("Adsumudi Rechenblattgenerator", fields.Author)
				assert.are.equal(SUBJECT, fields.Subject)
			end)

			test("enthält einen klickbaren Link auf die Webseite", function()
				local urls = read_command("pdfinfo -url " .. shell.quote(pdf(backend)))
				assert.matches("https://amthor.github.io/adsumudi/", urls, 1, true)
			end)

			test("zeigt „Erstellt mit Adsumudi“ und die Webseite nur auf der ersten Seite", function()
				local first, second = page_text(pdf(backend), 1), page_text(pdf(backend), 2)
				assert.matches("Erstellt mit Adsumudi", first, 1, true)
				assert.matches("amthor.github.io/adsumudi", first, 1, true)
				assert.is_nil(second:find("Erstellt mit", 1, true))
			end)
		end)
	end

	local both = (available.typst and available.latex) and it or pending
	both("Fußzeile: Typst und LaTeX stimmen überein (≤ 0,7 pt)", function()
		local t, l = footer_words(pdf("typst")), footer_words(pdf("latex"))

		-- Same words; each word is paired with its counterpart of the same text
		-- (several occurrences in order of x).
		local function by_text(words)
			local map = {}
			for _, w in ipairs(words) do
				map[w.text] = map[w.text] or {}
				table.insert(map[w.text], w)
			end
			for _, list in pairs(map) do
				table.sort(list, function(a, b)
					return a.x0 < b.x0
				end)
			end
			return map
		end
		local function texts(words)
			local list = {}
			for i, w in ipairs(words) do
				list[i] = w.text
			end
			table.sort(list)
			return list
		end
		assert.are.same(texts(t), texts(l))
		local lt = by_text(l)

		-- Collected instead of asserted one by one, so a failure lists all of them.
		local deviations = {}
		local function compare(what, a, b)
			if math.abs(a - b) > TOLERANCE then
				deviations[#deviations + 1] = ("%s: Typst %.2f, LaTeX %.2f"):format(what, a, b)
			end
		end
		for text, list in pairs(by_text(t)) do
			for i, w in ipairs(list) do
				compare(("Höhe von „%s“"):format(text), w.y0, lt[text][i].y0)
			end
		end
		local at, al = anchors(t), anchors(l)
		for side, label in pairs({ left = "Zeilenanfang links", right = "Zeilenende rechts" }) do
			local a, b = at[side], al[side]
			for i = 1, math.max(#a, #b) do
				compare(label, a[i] or 0, b[i] or 0)
			end
		end
		compare("Mitte der Seitenzahl", at.centre, al.centre)
		assert.are.same({}, deviations)
	end)
end)
