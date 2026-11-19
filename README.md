# Rechenblatt

Erzeugt Mathe-Übungsblätter (3. Klasse) zum selbständigen Üben als LaTeX-Datei bzw. PDF.

## Voraussetzungen

- Lua 5.3 oder neuer
- Template-Engine [etlua](https://github.com/leafo/etlua): `luarocks install --local etlua`
  (oder alle Abhängigkeiten: `luarocks install --local --only-deps rechenblatt-dev-1.rockspec`)
- lualatex mit den Paketen `extsizes`, `babel` (ngerman), `geometry`, `multicol`, `enumitem`, `fontspec`, `unicode-math` und den Schriften Fira Sans und Fira Math (alle in TeX Live enthalten)
- optional zum Testen: [busted](https://lunarmodules.github.io/busted/)

## Benutzung

```sh
lua rechenblatt.lua --pdf          # Voreinstellung: Plus/Minus, 1–100, für 5 Minuten
lua rechenblatt.lua -r mul,div -n 30 -l --pdf   # 30 Mal-/Geteilt-Aufgaben mit Lösungsblatt
lua rechenblatt.lua -r +,-,*,: -t 10 --max 50 --pdf
lua rechenblatt.lua --hilfe        # alle Optionen
```

| Option | Bedeutung | Standard |
|---|---|---|
| `-n`, `--anzahl N` | Anzahl der Aufgaben (hat Vorrang vor `--minuten`) | – |
| `-t`, `--minuten M` | Bearbeitungsdauer; daraus wird die Anzahl berechnet | 5 |
| `--min N` / `--max N` | Zahlenbereich | 1 / 100 |
| `-r`, `--rechenarten` | `add,sub,mul,div` oder `+,-,*,:` | `add,sub` |
| `-l`, `--loesungen` | Lösungsblatt als zweite Seite | aus |
| `-o`, `--ausgabe` | Ausgabedatei | `rechenblatt.tex` |
| `-p`, `--pdf` | PDF mit lualatex erzeugen | aus |
| `-c`, `--blattcode CODE` | Blatt aus dem Blattcode exakt nachbauen (siehe unten) | – |
| `-s`, `--seed N` | Zufallsstartwert, v. a. für Tests | Uhrzeit |
| `-d`, `--debug` | Boxen sichtbar machen (lua-visual-debug), `.log` behalten | aus |

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
lua rechenblatt.lua --blattcode 1-AS-1-100-22-48213 -l --pdf
```

Aufbau: `Version-Rechenarten-Min-Max-Anzahl-Seed`. Die Rechenarten sind A (Plus), S (Minus),
M (Mal) und D (Geteilt), und zwar in der Reihenfolge, in der sie angegeben wurden. Der Code legt die
Aufgaben fest, nicht die Aufmachung: `--titel`, `-l`, `-o` und `-p` dürfen frei kombiniert werden,
`-r`, `--min`, `--max`, `-n`, `-t` und `-s` dagegen nicht.

Die Version am Anfang ist die des Aufgabengenerators. Erzeugt eine neuere Programmversion bei gleichen
Eingaben andere Aufgaben, lehnt sie alte Codes mit einer Meldung ab, statt still ein anderes Blatt
zu liefern.

## Layout anpassen

Das Aussehen des Blatts steht vollständig in `templates/rechenblatt.tex.etlua`, einer normalen
LaTeX-Datei mit etlua-Platzhaltern: `<% lua-code %>` für Schleifen/Bedingungen, `<%- wert %>`
für Werte. (Nicht `<%= %>` verwenden – das maskiert für HTML, nicht für LaTeX.)

Die Breite der Zahlenboxen ist `\ziffernbreite` (0.75em) mal der maximalen Stellenzahl
des Zahlenbereichs; der Wert pro Ziffer steht im Template.

## Tests

```sh
busted
```
