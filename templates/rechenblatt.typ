// Rechenblatt – Typst-Template
//
// Die Daten kommen als JSON von Lua (src/rechenblatt/typst.lua) über
//   typst compile --input daten='<json>' rechenblatt.typ blatt.pdf
// Ohne --input wird beispiel.json verwendet, damit sich das Layout direkt
// bearbeiten und mit `typst watch` live ansehen lässt.
//
// Felder: titel, beschreibung, minuten (Text oder none), blattcode (Text oder
// none), stellen, debug, seiten ((loesung: bool), …),
// aufgaben ((art: "add"|"sub"|"mul"|"div", a, b, ergebnis), …)

// ---------------------------------------------------------------------------
// Daten
// ---------------------------------------------------------------------------
#let daten = if "daten" in sys.inputs {
  json(bytes(sys.inputs.daten))
} else {
  json("beispiel.json")
}

// ---------------------------------------------------------------------------
// Grundeinstellungen: Schrift, Seite, Fußzeile
// ---------------------------------------------------------------------------
#set document(title: daten.titel)

// Seitenrand unten und Spaltenabstand; werden auch für die Platzberechnung
// in aufgabenblock() gebraucht.
#let rand-unten = 2cm
#let spaltenabstand = 1.5cm

// Gleich breite Ziffern ("tabular"), damit Zahlen sauber untereinander stehen
#set text(font: "Fira Sans", size: 14pt, lang: "de", number-width: "tabular")

#set page(
  paper: "a4",
  // Oben + 4.4pt: LaTeX setzt die erste Grundlinie \topskip (14pt) unter den
  // Satzspiegel, Typst die Versalhöhe (≈ 9.6pt) – so steht alles wie im LaTeX-Blatt.
  margin: (top: 2cm + 4.4pt, bottom: rand-unten, rest: 2cm),
  // Fußzeile: mittig "Seite / Seitenzahl", rechts der Blattcode nur auf Seite 1
  footer: context grid(
    columns: (1fr, auto, 1fr),
    [],
    counter(page).display("1 / 1", both: true),
    align(right, if here().page() == 1 and daten.blattcode != none {
      text(size: 10pt)[Blattcode: #daten.blattcode]
    }),
  ),
)

// Debug-Modus (--debug): alle Boxen rot, Blöcke grün, Grid-Zellen blau
// umrahmen. Eine "Show-Regel" auf das ganze Dokument. Ausdrücklich gesetzte
// Rahmenseiten (der Unterstrich von linie()) bleiben, die übrigen Seiten
// ergänzt Typst aus der Set-Regel ("Folding").
#show: body => if daten.debug {
  set box(stroke: 0.3pt + red)
  set block(stroke: 0.3pt + green)
  set grid(stroke: 0.3pt + blue)
  body
} else {
  body
}

// ---------------------------------------------------------------------------
// Bausteine
// ---------------------------------------------------------------------------

// Rechenzeichen: echte Textzeichen aus Fira Sans (U+2212 ist das Minus,
// U+00B7 der Malpunkt) – in SemiBold statt künstlich gefettet.
#let zeichen = (add: "+", sub: "−", mul: "·", div: ":")

// Unterstrichene Leerstelle (Antwortlücke, Name, Datum)
#let linie(breite) = box(width: breite, stroke: (bottom: 0.5pt), outset: (bottom: 3pt))

// Zahlenbox: angenommene Ziffernbreite mal maximale Stellenzahl,
// für alle Aufgaben gleich breit
#let ziffernbreite = 0.7em
#let zahlbreite = daten.stellen * ziffernbreite
#let zahl(n) = box(width: zahlbreite, align(center, str(n)))

// Breiten der übrigen Bausteine einer Aufgabe
#let einzug = 1em
#let zeichenbreite = 0.6cm
#let gleichbreite = 0.8cm
#let lueckenbreite = 2.2cm
#let aufgabenbreite = einzug + 2 * zahlbreite + zeichenbreite + gleichbreite + lueckenbreite

// Eine Aufgabe: a ∘ b = ___ (bzw. = Ergebnis auf der Lösungsseite).
// Die feste Gesamtbreite verhindert einen Umbruch innerhalb der Aufgabe:
// eine Box ohne Breite wäre höchstens spaltenbreit und bräche intern um.
#let aufgabe(a, loesung) = box(width: aufgabenbreite, {
  h(einzug)
  zahl(a.a)
  box(width: zeichenbreite, align(center, text(weight: "semibold", zeichen.at(a.art))))
  zahl(a.b)
  box(width: gleichbreite, align(center)[=])
  if loesung { strong(str(a.ergebnis)) } else { linie(lueckenbreite) }
})

// Seitenkopf mit Name/Datum, Titel und Beschreibung
#let kopf(titel) = {
  [Name: #linie(6cm) #h(1fr) Datum: #linie(3.5cm)]
  v(1cm)
  align(center, stack(
    spacing: 12pt,
    text(size: 24.88pt, weight: "bold", titel),
    [#daten.beschreibung#if daten.minuten != none [ • Zeit: etwa #daten.minuten Minuten]],
  ))
  v(1.15cm)
}

// Aufgaben in zwei Spalten. Typst gleicht Spalten nicht automatisch aus
// (anders als LaTeX' multicols). Darum:
//  - Passt die linke Hälfte in den freien Platz der Seite, wird die Liste
//    halbiert und nebeneinander gesetzt; die rechte Liste zählt weiter.
//  - Sonst fließen die Aufgaben spaltenweise über mehrere Seiten
//    (Seite 1 links, Seite 1 rechts, Seite 2 links, ...).
#let aufgabenblock(loesung) = {
  set enum(numbering: n => text(size: 12pt)[(#n.)], spacing: 2em + 1pt, indent: 6.6pt)
  let items = daten.aufgaben.map(a => aufgabe(a, loesung))
  let haelfte = calc.ceil(items.len() / 2)
  layout(size => {
    // layout() liefert die volle Satzspiegelgröße; den noch freien Platz
    // ergibt erst die aktuelle Position auf der Seite.
    let frei = page.height - rand-unten - here().position().y
    let spalte = (size.width - spaltenabstand) / 2
    let links = enum(..items.slice(0, haelfte))
    if measure(links, width: spalte).height <= frei {
      grid(
        columns: (1fr, 1fr),
        column-gutter: spaltenabstand,
        links,
        enum(start: haelfte + 1, ..items.slice(haelfte)),
      )
    } else {
      columns(2, gutter: spaltenabstand, enum(..items))
    }
  })
}

// ---------------------------------------------------------------------------
// Dokument
// ---------------------------------------------------------------------------
#for (i, seite) in daten.seiten.enumerate() {
  if i > 0 { pagebreak() }
  kopf(if seite.loesung { daten.titel + " – Lösungen" } else { daten.titel })
  aufgabenblock(seite.loesung)
}
