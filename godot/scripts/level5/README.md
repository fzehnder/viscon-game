# Level 5 · Nacht im HIL (Hönggerberg)

Story-Level nach dem Chemiepraktikum (4) und vor der Basisprüfung (6). Nachts ins HIL (Architektur) am Hönggerberg: Im Büro des Profs liegen die bewerteten Abgaben, auf seinem Computer die Notenliste. Jede*r ändert den Namen auf einer Abgabe mit der 6 in den eigenen. Dann raus und in den letzten ETH-Link.

## So spielt es sich

1. **Start** an der Haltestelle des ETH-Link vor dem HIL, Mitternacht. Der Ladebildschirm zeigt den ETH-Link, der nachts den Hönggerberg hochfährt (`"sky": "night"`).
2. **Zugang:** Die Karte, die ihr dem Prof am Polyball abgenommen habt (Level 3, `Game.has_item("prof_badge")`), öffnet die Tür mit Kartenleser neben dem Haupteingang und die Bürotür; die Aufgabe ist dann gleich erledigt. Ohne Karte (Level 3 in diesem Spiel nicht gespielt) liegt eine Ersatzkarte in der Campus Info neben der Haltestelle.
3. **Durchs HIL**, eng und nach dem echten Grundriss: Foyer, daneben Alumni-Lounge und gta-Ausstellung (hohe Ausstellungswände verdecken die Sicht), das geschlossene Atrium in der Mitte mit je einem schmalen Gang links und rechts, oben der lange **Nordflügel**: ein Gang von zwei Feldern Breite zwischen zwei Reihen kleiner Büros, ganz im Westen das **Büro des Profs**. Im Osten der Ostblock mit Büros und dem Zeichensaal (dort sitzen Opps aus früheren Levels in der Nachtschicht).
4. **Der Sicherheitsdienst:** fünf Wachen mit Taschenlampe: vor dem Gebäude, Foyer und die Gänge am Atrium, Ostblock und Zeichensaal, und **zwei im Nordgang**, gegenläufig. Wer im Lichtkegel steht, füllt ihren Verdacht, bei voll: erwischt, Level verloren. Sie hören Schritte und gehen nachschauen. Im Nordgang heisst das: sich rechtzeitig in ein Büro ducken.
5. **Verstecken:** Büro-, Akten-, Garderoben- und Putzschränke, Transport- und Modellkisten: E bzw. Enter rein und wieder raus. Versteckt sieht euch niemand.
6. **Am Computer des Profs** (`grade_pc.gd`, auf der eigenen Bildschirmhälfte): Notenliste mit acht Abgaben in zufälliger Reihenfolge, zwei davon mit einer 6. Hoch/runter wählen, E/Enter öffnet; dann den eigenen Namen eintippen, indem man E/Enter hämmert. Eine falsche Abgabe öffnen piept laut: Die Wachen in der Nähe hören es und kommen. Esc bzw. Rücktaste: weg vom PC. Beide müssen ran, nacheinander.
7. Sind beide Namen drin, knallt irgendwo eine Tür: Die Wachen werden schneller und sehen weiter.
8. **In den ETH-Link:** an der Bustür E/Enter, sobald der eigene Name bei der 6 steht. Sind beide drin: Cutscene, Sieg.

Zeit: 8 Minuten bis zum letzten ETH-Link.

## Die Karte

`build_map` räumt die Karte des Zentrums leer und baut den Campus Hönggerberg (Tiles): Strasse (y 76..79) mit Haltestelle (x 34..58), Platz vor dem HIL, Campus Info (62..72 / 60..68); das HIL: Nordflügel (8..100 / 8..24, Gang y 16..17, Büro des Profs 9..14), Mittelteil (28..64 / 24..56: gta-Ausstellung, Atrium 45..59 / 25..42, Gänge x 42..44 und 60..62, Alumni-Lounge, Foyer), Ostblock (64..100 / 30..50, Gang y 39..40, Zeichensaal 92..99). `md.mode = "night"` lässt `world.gd` die Karte nachts zeichnen (Laternen, Lichtinseln), das Spiel selbst läuft als Tag-Level mit Aufgaben. Die Wachen sind `professor.gd`, vom Level selbst in `main.profs` gesetzt (am Tag spawnt `main.gd` keine).

## Stellschrauben (oben in `level.gd`, `grade_pc.gd`)

| Konstante | Wert | Wirkung |
|---|---|---|
| `DEF.time` | 480 s | bis zum letzten ETH-Link |
| `GUARDS` | 5 | Name, Tempo, Sichtweite (Tiles), Pausen, Patrouillenpunkte |
| `GUARD_SPEED_UP`, `GUARD_RANGE_UP` | 1.25, 1 Tile | Wachen, sobald beide Namen drin sind |
| `CHARS_PER_PRESS` | 2 | Buchstaben pro Tastendruck beim Eintippen |
| Lärm beim Piepen | 7 Tiles | `_open_pc` in `level.gd` |

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | `DEF`, Karte (`build_map`), Wachen, Türen mit Kartenleser, Computer, ETH-Link, Cutscene, Zeichnung der eigenen Möbel und des Busses |
| `grade_pc.gd` | die Notenverwaltung am Computer des Profs |

Gemeinsame Dateien sind nicht angefasst.

## Stand

- Per Bot geprüft: jedes Bodenfeld im Gebäude und jedes Objekt ist von der Haltestelle aus erreichbar, alle Patrouillenpunkte auch; mit Karte vom Polyball und ohne (Ersatzkarte aus der Campus Info): Türen, beide Namen bei einer 6, beide in den ETH-Link, Sieg.
- Nicht gespielt: wie schwer die Wachen zu umgehen sind, ob 8 Minuten passen.

Ausserhalb des Ordners: `scripts/loading_screen.gd` zeigt statt der Polybahn den ETH-Link, der den Hönggerberg hochfährt, und hat Motive für Level 5 und 6.
