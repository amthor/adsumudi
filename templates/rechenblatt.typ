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
#set text(font: "Fira Sans", size: 14pt, lang: "de")

#set page(
  paper: "a4",
  margin: 2cm,
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
#let zahl(n) = box(width: daten.stellen * ziffernbreite, align(center, str(n)))

// Eine Aufgabe: a ∘ b = ___ (bzw. = Ergebnis auf der Lösungsseite)
#let aufgabe(a, loesung) = {
  h(1em)
  zahl(a.a)
  box(width: 0.6cm, align(center, text(weight: "semibold", zeichen.at(a.art))))
  zahl(a.b)
  box(width: 0.8cm, align(center)[=])
  if loesung { strong(str(a.ergebnis)) } else { linie(2.2cm) }
}

// Seitenkopf mit Name/Datum, Titel und Beschreibung
#let kopf(titel) = {
  [Name: #linie(6cm) #h(1fr) Datum: #linie(3.5cm)]
  v(1.1cm)
  align(center)[
    #text(size: 24.88pt, weight: "bold", titel) \
    #daten.beschreibung
    #if daten.minuten != none [ • Zeit: etwa #daten.minuten Minuten]
  ]
  v(0.9cm)
}

// Aufgaben in zwei Spalten. Typst gleicht Spalten nicht automatisch aus,
// darum wird die Liste explizit halbiert; die rechte Liste zählt weiter.
#let aufgabenblock(loesung) = {
  set enum(numbering: n => text(size: 12pt)[(#n.)], spacing: 2em)
  let items = daten.aufgaben.map(a => aufgabe(a, loesung))
  let haelfte = calc.ceil(items.len() / 2)
  grid(
    columns: (1fr, 1fr),
    column-gutter: 1.5cm,
    enum(..items.slice(0, haelfte)),
    enum(start: haelfte + 1, ..items.slice(haelfte)),
  )
}

// ---------------------------------------------------------------------------
// Dokument
// ---------------------------------------------------------------------------
#for (i, seite) in daten.seiten.enumerate() {
  if i > 0 { pagebreak() }
  kopf(if seite.loesung { daten.titel + " – Lösungen" } else { daten.titel })
  aufgabenblock(seite.loesung)
}
