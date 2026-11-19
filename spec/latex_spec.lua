local latex = require("rechenblatt.latex")

describe("latex.render", function()
  local list = {
    { op = "add", a = 12, b = 7, result = 19 },
    { op = "mul", a = 3, b = 4, result = 12 },
  }
  local opts = { min = 1, max = 100, operations = { "add", "mul" }, minutes = 5 }

  it("enthält Aufgaben mit Lücken, aber keine Lösungen", function()
    local tex = latex.render(list, opts)
    assert.truthy(tex:find("\\aufgabe{12}{+}{7}{\\luecke}", 1, true))
    assert.truthy(tex:find("\\aufgabe{3}{\\cdot}{4}{\\luecke}", 1, true))
    assert.falsy(tex:find("\\textbf{19}", 1, true))
    assert.truthy(tex:find("etwa 5 Minuten", 1, true))
  end)

  it("hängt optional ein Lösungsblatt an", function()
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    o.solutions = true
    local tex = latex.render(list, o)
    assert.truthy(tex:find("\\newpage", 1, true))
    assert.truthy(tex:find("\\aufgabe{12}{+}{7}{\\textbf{19}}", 1, true))
  end)

  it("maskiert LaTeX-Sonderzeichen im Titel", function()
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    o.title = "3 & 4 (50%) a_b"
    local tex = latex.render(list, o)
    assert.truthy(tex:find("3 \\& 4 (50\\%) a\\_b", 1, true))
  end)

  it("berechnet die Zahlenbreite aus der maximalen Stellenzahl", function()
    assert.are.equal(1, latex.digit_count(1, 9))
    assert.are.equal(2, latex.digit_count(1, 99))
    assert.are.equal(3, latex.digit_count(1, 100))
    assert.are.equal(4, latex.digit_count(10, 1000))
    local tex = latex.render(list, opts)
    assert.truthy(tex:find("\\setlength{\\zahlbreite}{3\\ziffernbreite}", 1, true))
  end)

  it("bindet lua-visual-debug nur im Debug-Modus ein", function()
    assert.falsy(latex.render(list, opts):find("lua-visual-debug", 1, true))
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    o.debug = true
    assert.truthy(latex.render(list, o):find("\\usepackage{lua-visual-debug}", 1, true))
  end)

  it("zeigt den Blattcode einmal in der Fußzeile der ersten Seite", function()
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    o.solutions = true
    o.sheet_code = "1-AS-1-100-22-4711"
    local tex = latex.render(list, o)
    local _, n = tex:gsub("Blattcode: 1%-AS%-1%-100%-22%-4711", "")
    assert.are.equal(1, n)
    assert.truthy(tex:find("\\rfoot{\\footnotesize Blattcode: 1-AS-1-100-22-4711}", 1, true))
    assert.truthy(tex:find("\\thispagestyle{ersteseite}", 1, true))
  end)

  it("lässt den Blattcode ohne Code weg", function()
    local tex = latex.render(list, opts)
    assert.falsy(tex:find("Blattcode:", 1, true))
    assert.falsy(tex:find("\\rfoot", 1, true))
  end)
end)
