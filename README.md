# Adsumudi

**Ad**dition — **Su**btraktion — **Mu**ltiplikation — **Di**vision

Adsumudi erzeugt Mathe-Übungsblätter (Grundschule) zum selbständigen Üben als
PDF, gesetzt mit [Typst] ([LaTeX] möglich als alternatives Backend). Verfügbar
als Kommandozeilenprogramm oder [Web-Oberfläche](#web-oberfläche) (vollständig
im Browser):

<https://amthor.github.io/adsumudi/>

## Voraussetzungen

- Lua ≥ 5.3
- für Lua-Tests (optional): [busted](https://lunarmodules.github.io/busted/)
- [Typst](https://github.com/typst/typst), via `cargo install --locked
typst-cli`
- Fonts im Repo: Fira Sans, SIL Open Font License (`fonts/`)
- [dkjson](http://dkolf.de/dkjson-lua/) im Repo (`dkjson/`)
- für das LaTeX backend (`--satz latex`):
  - Template-Engine [etlua] via `luarocks install --local etlua`
  - lualatex mit packages `extsizes`, `babel` (ngerman), `geometry`,
    `multicol`, `enumitem`, `fancyhdr`, `lastpage`, `fontspec`, `unicode-math`
    und fonts Fira Sans, Fira Math (z.B. via [TeX Live](https://www.tug.org/texlive))

## Allgemeine Benutzung

Beispielaufrufe des Kommandozeilenprogramms:

```sh
lua adsumudi.lua   # mit Standardeinstellungen: Plus/Minus, Zahlen 1–100, Bearbeitungsdauer 5 Minuten
lua adsumudi.lua -r mul,div -n 30 -l -o mal.pdf  # 30 Mal-/Geteilt-Aufgaben, mit Lösungsblatt
lua adsumudi.lua -r +,-,*,: -t 10 --max 50
lua adsumudi.lua --satz latex  # wie oben, mit LateX backend
lua adsumudi.lua --hilfe  # Hilfe zu Optionen (s.u.)
```

| Option                   | Bedeutung                                                                                       | Standard          |
| ------------------------ | ----------------------------------------------------------------------------------------------- | ----------------- |
| `-n`, `--anzahl N`       | Anzahl Aufgaben (Vorrang vor `--minuten`)                                                       | –                 |
| `-t`, `--minuten M`      | Bearbeitungsdauer (automatische Bestimmund der Anzahl Aufgaben)                                 | 5                 |
| `--min N`, `--max N`     | Zahlenraum                                                                                      | 1, 100            |
| `-r`, `--rechenarten`    | `add,sub,mul,div` oder `+,-,*,:`                                                                | `add,sub`         |
| `-l`, `--loesungen`      | Lösungsblatt als zweite Seite generieren                                                        | aus               |
| `-o`, `--ausgabe`        | Ausgabedatei                                                                                    | `rechenblatt.pdf` |
| `--satz SYSTEM`          | `typst` oder `latex`                                                                            | `typst`           |
| `--quelle`               | kein PDF ausgeben sondern nur dessen Quelldatei schreiben (`.json` bei Typst, `.tex` bei LaTeX) | aus               |
| `-c`, `--blattcode CODE` | vorheriges Blatt aus Blattcode nachbauen (siehe unten)                                          | –                 |
| `-s`, `--seed N`         | Zufallsstartwert des Aufgabengenerators                                                         | Uhrzeit           |
| `-d`, `--debug`          | alle Textboxen im PDF sichtbar machen (bei LaTeX wird `.tex` und `.log` behalten)               | aus               |

### Blatt nachdrucken

Unten rechts auf der ersten Seite steht ein _Blattcode_ (z. B.
`1-AS-1-100-22-48213`), der auch nach dem Erzeugen auf der Konsole bzw.
Webseite angegeben wird. Mit ihm lässt sich das Blatt später exakt nachbauen,
etwa Aufaben zu wiederholen um nachträglich Lösungen zu drucken:

```sh
lua adsumudi.lua --blattcode 1-AS-1-100-22-48213 -l
```

Aufbau des Blattcodes: `(Version)-(Rechenarten)-(Min)-(Max)-(Anzahl)-(Seed)`.

- `(Rechenarten)` ist eine Folge der Buchstaben `A` (Plus), `S` (Minus), `M`
  (Mal) oder `D` (Geteilt) in dieser Reihenfolge.
- Die Elemente `(Min)`, `(Max)`, `(Anzahl)`, `(Seed)` geben die jeweiligen
  Werte für die entsprechenden Optionen wieder (siehe Tabelle oben).
- `(Version)` steht für die Version des Aufgabengenerators. Erzeugt ein neuerer
  Aufgabengenerator bei gleichen Eingaben andere Aufgaben, können alte Codes
  mit ihrer früheren Programmversion nicht mehr verwendet werden und werden
  abgelehnt.

Der Code legt die Aufgaben fest, darüber hinaus können wie gewohnt `--titel`,
`-l`, `-o`, `--satz` und `--quelle` frei kombiniert werden. Die Optionen `-r`,
`--min`, `--max`, `-n`, `-t` und `-s` sind bei Angabe eines Blattcodes nicht
möglich.

## Anpassungsmöglichkeiten im Code

### Aufgabengenerierung

Der Aufgabengenerator folgt folgenden Regeln:

- Alle Zahlen in den Aufgaben müssen im Zahlenbereich liegen, die Ergebnisse
  zwischen 0 und `--max`.
- Keine negativen Ergebnisse, Division immer ohne Rest.
- Bei Mal und Geteilt kommen die Faktoren 0 und 1 nicht vor, wenn der Bereich
  das zulässt.
- Rechenarten werden gleichmäßig verteilt und gemischt, doppelte Aufgaben
  werden vermieden soweit möglich (können aber natürlich vorkommen, Bsp: `-r
mul --min 10 --max 100`).

Die Anzahl für eine Dauer ergibt sich aus geschätzten Sekunden pro Aufgabe
(`SECONDS_PER_TASK` in `src/adsumudi/tasks.lua`). Diese werden als grobe
Durchschnittschätzungen je Rechenart wie folgt angenommen:

- Plus: 17 s
- Minus: 20 s
- Mal: 15 s (Einmaleins muss auswendig sitzen)
- Geteilt: 20 s

Diese Werte können bei Bedarf angepasst werden, je nach individuellem Tempo der
Schüler\*innen.

### Layout

**Typst-Backend:** Das Aussehen des Blatts steht vollständig in
`templates/adsumudi.typ`. Lua liefert nur die generierten Aufgabendaten als
JSON. Ohne Daten zeigt das Template ein Demoblatt mit Daten aus
`templates/beispiel.json`, welches sich gut eignet, um das Layout mit
Live-Vorschau zu modifizieren:

```sh
typst watch --font-path fonts templates/adsumudi.typ
```

Die Breite der Zahlenboxen ist `ziffernbreite` (Standard: 0.7em) mal maximale
Stellenzahl des Zahlenraums (sonstige Breitenangaben sind konkrete Werte im
Template).

**LaTeX-Backend:** Das Template `templates/adsumudi.tex.etlua` ist eine
LaTeX-Datei mit [etlua]-Platzhaltern (`<% lua-code %>` für Schleifen und
Bedingungen, `<%- wert %>` für Werte). Wenn beide Backends genutzt werden,
müssen alle Layout-Änderungen auch in beiden Templates vorgenommen werden.

### Tests

```sh
busted                       # Lua: Kern, CLI, Backends, Web-Adapter
cd web && npm run build && npm test   # Web-Oberfläche im Browser
```

## Web-Oberfläche

`web/` enthält eine statische Webseite als alternative grafische
Benutzeroberfläche, die direkt im Browser läuft. Sie erzeugt dieselben Blätter
wie das Kommandozeilenprogramm. Lua (identischer Code zur Aufgabengenerierung)
läuft dazu in [Wasmoon] (Lua 5.4 als WebAssembly), das Template wird mit
[typst.ts] gesetzt.

Voraussetzung ist [Node.js], mit `npm` zum Bauen und Testen.

```sh
cd web
npm ci         # einmalig (Pakete entsprehcend package-lock.json)
npm run build  # kopiert web/dist/ zusammen (kein Bundler)
npm run serve  # http://localhost:8000
npm test       # e2e-Test in Chromium, vergleicht die PDFs mit dem CLI
```

Funktionen:

- Rechenarten, Zahlenraum, Dauer oder Anzahl, Titel und Lösungsseite
- Blattcode zum Nachdrucken
- Verlauf zuletzt erzeugter Blätter
- Aufklappbare Konsole mit Fehlermeldungen und Angaben zu Datenvolumen, Lade-
  und Erzeugungszeiten

`web/dist/` ist die komplette Website. Sie enthält Kopien von Lua-Code,
Template und Schriften aus diesem Repository (Neubau nach Änderungen per CI).
Der erste Aufruf lädt rund 30 MB (vor allem der Typst-Compiler; komprimiert
ausgeliefert etwa 10 MB), danach kommt alles aus dem Browser-Cache.

### Veröffentlichung

Jeder Push auf `main` baut die Seite neu und veröffentlicht sie auf GitHub
Pages via Github workflow. Den Zustand nach dem Deployment prüft der e2e-Test
gegen die veröffentlichte Seite:

```sh
cd web && E2E_URL=https://amthor.github.io/adsumudi/ npm test
```

## Lizenz

Adsumudi selbst steht unter [MIT-Lizenz](LICENSE). Folgende mitgelieferten
Teile benutzen jeweils eigene Lizenzen:

- Fira Sans (`fonts/`): SIL Open Font License 1.1 (`fonts/OFL.txt`)
- dkjson (`dkjson/`): MIT, Copyright David Heiko Kolf
- [Wasmoon] (MIT) für die Web-Oberfläche und [typst.ts] (Apache-2.0) aus npm
  (Lizenztexte nach dem Build in `web/dist/vendor/`)

## KI-Transparenzhinweis

Adsumudi ist mit Unterstützung durch KI-generierten Code und Tests entstanden. Anforderungen, Entwurf, Prüfung und Anpassungen sowie Commits liegen sämtlich beim Autor.

[Typst]: https://typst.app
[LaTeX]: https://www.latex-project.org/
[etlua]: https://github.com/leafo/etlua
[Wasmoon]: https://github.com/ceifa/wasmoon
[typst.ts]: https://github.com/Myriad-Dreamin/typst.ts
[Node.js]: https://nodejs.org
