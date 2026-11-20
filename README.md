# Rechenblatt

Erzeugt Mathe-Übungsblätter (3. Klasse) zum selbständigen Üben als PDF. Gesetzt wird mit
[Typst](https://typst.app); LaTeX steht als Alternative zur Verfügung.

## Voraussetzungen

- Lua 5.3 oder neuer
- [Typst](https://github.com/typst/typst), z. B. `cargo install --locked typst-cli`.
  Die Schriften (Fira Sans, SIL Open Font License) liegen in `fonts/` bei.
- [dkjson](http://dkolf.de/dkjson-lua/) liegt in `dkjson/` bei.
- Nur für `--satz latex`:
  - die Template-Engine [etlua](https://github.com/leafo/etlua): `luarocks install --local etlua`
  - lualatex mit den Paketen `extsizes`, `babel` (ngerman), `geometry`, `multicol`, `enumitem`,
    `fancyhdr`, `lastpage`, `fontspec`, `unicode-math` und den Schriften Fira Sans und Fira Math
    (alle in TeX Live enthalten)
- optional zum Testen: [busted](https://lunarmodules.github.io/busted/)

## Benutzung

```sh
lua rechenblatt.lua                    # Voreinstellung: Plus/Minus, 1–100, für 5 Minuten → rechenblatt.pdf
lua rechenblatt.lua -r mul,div -n 30 -l -o mal.pdf   # 30 Mal-/Geteilt-Aufgaben mit Lösungsblatt
lua rechenblatt.lua -r +,-,*,: -t 10 --max 50
lua rechenblatt.lua --satz latex       # dasselbe Blatt mit LaTeX gesetzt
lua rechenblatt.lua --hilfe            # alle Optionen
```

| Option | Bedeutung | Standard |
|---|---|---|
| `-n`, `--anzahl N` | Anzahl der Aufgaben (hat Vorrang vor `--minuten`) | – |
| `-t`, `--minuten M` | Bearbeitungsdauer; daraus wird die Anzahl berechnet | 5 |
| `--min N` / `--max N` | Zahlenbereich | 1 / 100 |
| `-r`, `--rechenarten` | `add,sub,mul,div` oder `+,-,*,:` | `add,sub` |
| `-l`, `--loesungen` | Lösungsblatt als zweite Seite | aus |
| `-o`, `--ausgabe` | Ausgabedatei | `rechenblatt.pdf` |
| `--satz SYSTEM` | `typst` oder `latex` | `typst` |
| `--quelle` | statt des PDFs nur die Quelle schreiben (`.json` bei Typst, `.tex` bei LaTeX) | aus |
| `-c`, `--blattcode CODE` | Blatt aus dem Blattcode exakt nachbauen (siehe unten) | – |
| `-s`, `--seed N` | Zufallsstartwert, v. a. für Tests | Uhrzeit |
| `-d`, `--debug` | Boxen sichtbar machen (LaTeX: lua-visual-debug, `.tex`/`.log` behalten) | aus |

## Regeln für die Aufgaben

- Alle Zahlen in den Aufgaben liegen im Zahlenbereich, Ergebnisse zwischen 0 und `--max`.
- Keine negativen Ergebnisse, Division immer ohne Rest.
- Bei Mal/Geteilt kommen die Faktoren 0 und 1 nicht vor, wenn der Bereich das zulässt.
- Rechenarten werden gleichmäßig verteilt und gemischt, doppelte Aufgaben werden vermieden.

Die Anzahl für eine Dauer ergibt sich aus geschätzten Sekunden pro Aufgabe
(`SECONDS_PER_TASK` in `src/rechenblatt/tasks.lua`: Plus 17 s, Minus 20 s,
Mal 15 s, Geteilt 20 s). Passe die Werte an, wenn das Tempo nicht passt.

## Blatt nachdrucken

Unten rechts auf der ersten Seite steht ein **Blattcode**, z. B. `1-AS-1-100-22-48213`. Er wird auch
nach dem Erzeugen auf der Konsole ausgegeben. Mit ihm lässt sich das Blatt später exakt nachbauen,
etwa um nachträglich die Lösungen zu drucken:

```sh
lua rechenblatt.lua --blattcode 1-AS-1-100-22-48213 -l
```

Aufbau: `Version-Rechenarten-Min-Max-Anzahl-Seed`. Die Rechenarten sind A (Plus), S (Minus),
M (Mal) und D (Geteilt), und zwar in der Reihenfolge, in der sie angegeben wurden. Der Code legt die
Aufgaben fest, nicht die Aufmachung: `--titel`, `-l`, `-o`, `--satz` und `--quelle` dürfen frei
kombiniert werden, `-r`, `--min`, `--max`, `-n`, `-t` und `-s` dagegen nicht.

Die Version am Anfang ist die des Aufgabengenerators. Erzeugt eine neuere Programmversion bei gleichen
Eingaben andere Aufgaben, lehnt sie alte Codes mit einer Meldung ab, statt still ein anderes Blatt
zu liefern.

## Layout anpassen

Das Aussehen des Blatts steht vollständig in `templates/rechenblatt.typ`. Lua liefert nur die Daten
(als JSON). Ohne Daten von Lua zeigt das Template die Beispieldaten aus `templates/beispiel.json`,
sodass sich das Layout live bearbeiten lässt:

```sh
typst watch --font-path fonts templates/rechenblatt.typ
```

Die Breite der Zahlenboxen ist `ziffernbreite` (0.7em) mal der maximalen Stellenzahl des
Zahlenbereichs; die übrigen Breiten einer Aufgabe stehen als benannte Werte im Template.

Das LaTeX-Template `templates/rechenblatt.tex.etlua` ist eine LaTeX-Datei mit etlua-Platzhaltern:
`<% lua-code %>` für Schleifen/Bedingungen, `<%- wert %>` für Werte (nicht `<%= %>` – das maskiert
für HTML, nicht für LaTeX). Layout-Änderungen müssen in beiden Templates nachgezogen werden, wenn beide
Satzsysteme gleich aussehen sollen.

## Tests

```sh
busted
```
