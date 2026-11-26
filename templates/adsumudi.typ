// Adsumudi – Typst-Template
//
// Die Daten kommen als JSON von Lua (src/adsumudi/typst.lua) über
// `typst compile --input daten='<json>' adsumudi.typ blatt.pdf`.
//
// ## Layout bearbeiten
//
// Damit sich das Layout direkt bearbeiten und live ansehen lässt, `--input`
// weglassen:
//
// ```bash
//   typst watch --font-path fonts templates/adsumudi.typ
// ```
//
// Danach beispiel.json neu erzeugen:
//
// ```bash
// lua adsumudi.lua -t 5 -s 4711 -l --quelle -o templates/beispiel.json
// ```
//
// Felder:
// - `titel`
// - `version`
// - `beschreibung`
// - `minuten` (Text oder none)
// - `blattcode` (Text oder none)
// - `stellen`
// - `debug`
// - `seiten` -> `((loesung: bool), …)`,
// - `aufgaben` -> `((art: "add"|"sub"|"mul"|"div", a, b, ergebnis), …)`

//
// === Daten ===
//
#let daten = if "daten" in sys.inputs {
  json(bytes(sys.inputs.daten))
} else {
  json("beispiel.json")
}

//
// === Grundeinstellungen ===
// (Schrift, Seite, Fußzeile)
//
#set document(
  title: daten.titel,
  author: daten.metadaten.autor,
  description: daten.metadaten.betreff,
)

// Seitenrand unten und Spaltenabstand
#let rand-unten = 2cm
#let spaltenabstand = 1.5cm

// Gleich breite Ziffern ("tabular") -> Zahlen bündig untereinander
#set text(font: "Fira Sans", size: 14pt, lang: "de", number-width: "tabular")

#set page(
  paper: "a4",
  // Oben + 4.4pt: Einheitlichkeit zwischen Typst und LaTeX
  // (LaTeX setzt erste Grundlinie \topskip (14pt) unter den Satzspiegel
  // -> in Typst Versalhöhe ≈ 9.6pt)
  margin: (top: 2cm + 4.4pt, bottom: rand-unten, rest: 2cm),
  // Fußzeile:
  // - links (erste Seite): Adsumudi-Hinweis
  // - Mitte: "Seite / Seitenzahl"
  // - rechts (erste Seite): Blattcode
  // Wie bei LaTeX/fancyhdr stehen alle drei Teile auf einer gemeinsamen
  // Grundlinie, eine zweite Zeile hängt darunter. Dafür ist es erforderlich, dass die
  // Zeilenboxen an der Grundlinie beginnen und enden -> Zellen, die am oberen Rand bündig gesetzt sind, haben so dieselbe erste
  // Grundlinie bzw. `leading` ist genau der Grundlinienabstand (= LaTeX
  // \scriptsize: 9.5pt). Die Grundlinie liegt dann direkt am unteren
  // Satzspiegelrand. `footer-descent` senkt sie um LaTeX' \footskip (30pt).
  footer-descent: 30pt,
  footer: context {
    set text(top-edge: "baseline", bottom-edge: "baseline")
    set par(leading: 9.5pt)
    grid(
      columns: (1fr, auto, 1fr),
      if here().page() == 1 {
        text(size: 8pt)[
          Erstellt mit #emph(daten.metadaten.name) #daten.metadaten.version \
          #underline(link(daten.metadaten.benutzerwebseite.url, daten.metadaten.benutzerwebseite.text))
        ]
      },
      counter(page).display("1 / 1", both: true),
      align(right, if here().page() == 1 and daten.blattcode != none {
        text(size: 10pt)[Blattcode: #daten.blattcode]
      }),
    )
  },
)

// Debug-Modus (eine "Show-Regel" auf das ganze Dokument)
#show: body => if daten.debug {
  set box(stroke: 0.3pt + red)
  set block(stroke: 0.3pt + green)
  set grid(stroke: 0.3pt + blue)
  body
} else {
  body
}

//
// === Bausteine ===
//

// == Rechenzeichen ==
#let zeichen = (add: "+", sub: "−", mul: "·", div: ":")

// == Formularfelder ==
// (Antwortlücke, Name, Datum)
#let linie(breite) = box(width: breite, stroke: (bottom: 0.5pt), outset: (bottom: 3pt))

// == Zahlenbox ==
// (Annahme: Ziffernbreite mal maximale Stellenzahl für alle Aufgaben gleich)
#let ziffernbreite = 0.7em
#let zahlbreite = daten.stellen * ziffernbreite
#let zahl(n) = box(width: zahlbreite, align(center, str(n)))

// == Breiten ==
// (übrige Bausteine einer Aufgabe)
#let einzug = 1em
#let zeichenbreite = 0.6cm
#let gleichbreite = 0.8cm
#let lueckenbreite = 2.2cm
#let aufgabenbreite = einzug + 2 * zahlbreite + zeichenbreite + gleichbreite + lueckenbreite

// == Aufgabe ==
// Die feste Gesamtbreite verhindert einen Umbruch innerhalb der Aufgabe:
// eine Box ohne Breite wäre höchstens spaltenbreit und bräche intern um.
#let aufgabe(a, loesung) = box(width: aufgabenbreite, {
  h(einzug)
  zahl(a.a)
  // Operatorenzeichen gut sichtbar -> semibold
  box(width: zeichenbreite, align(center, text(weight: "semibold", zeichen.at(a.art))))
  zahl(a.b)
  box(width: gleichbreite, align(center)[=])
  if loesung { strong(str(a.ergebnis)) } else { linie(lueckenbreite) }
})

// == Seitenkopf ==
// (Name/Datum, Titel, Beschreibung)
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

// == Textkörper ==
//
// Aufgaben in zwei Spalten. Spaltenausgleich am Ende:
//
// - Linke Hälfte passt in den freien Platz der Seite -> Liste halbieren und
//   nebeneinander setzen (rechte Liste zählt weiter)
// - Sonst: Aufgaben fließen spaltenweise über mehrere Seiten
//   (Seite 1 links, Seite 1 rechts, Seite 2 links, ...)
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
        links, enum(start: haelfte + 1, ..items.slice(haelfte)),
      )
    } else {
      columns(2, gutter: spaltenabstand, enum(..items))
    }
  })
}

//
// === Dokument ===
//
#for (i, seite) in daten.seiten.enumerate() {
  if i > 0 { pagebreak() }
  kopf(if seite.loesung { daten.titel + " – Lösungen" } else { daten.titel })
  aufgabenblock(seite.loesung)
}
