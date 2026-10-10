# Level 5 · Nacht im HIL (Hönggerberg)

Story-Level nach dem Chemiepraktikum (4) und vor der Basisprüfung (6). Nachts ins HIL (Architektur) am Hönggerberg: Im Büro des Profs liegen die bewerteten Abgaben, auf seinem Computer die Notenliste. Jede*r ändert den Namen auf einer Abgabe mit der 6 in den eigenen. Dann raus und in den letzten ETH-Link.

## So spielt es sich

1. **Start** an der Haltestelle des ETH-Link vor dem HIL, Mitternacht. Der Ladebildschirm zeigt den ETH-Link, der nachts den Hönggerberg hochfährt (`"sky": "night"`, `"ride": "ethlink"`).
2. **Zugang:** Die Karte, die ihr dem Prof am Polyball abgenommen habt (Level 3, `Game.has_item("prof_badge")`), öffnet die Tür mit Kartenleser neben dem Haupteingang und die Bürotür; die Aufgabe ist dann gleich erledigt. Ohne Karte (Level 3 in diesem Spiel nicht gespielt) liegt eine Ersatzkarte in der Campus Info neben der Haltestelle.
3. **Durchs HIL**, eng und nach dem echten Grundriss: Foyer, daneben Alumni-Lounge und gta-Ausstellung (hohe Ausstellungswände verdecken die Sicht), das geschlossene Atrium in der Mitte mit je einem schmalen Gang links und rechts, oben der lange **Nordflügel**: ein Gang von zwei Feldern Breite zwischen zwei Reihen kleiner Büros, ganz im Westen das **Büro des Profs**. Im Osten der Ostblock mit Büros und dem Zeichensaal (dort sitzen Opps aus früheren Levels in der Nachtschicht).
4. **Der Sicherheitsdienst:** neun Wachen mit Taschenlampe: zwei vor dem Gebäude, Foyer und Gang am Atrium (West), gta-Ausstellung, Gang am Atrium (Ost), Ostblock und Zeichensaal, und **drei im Nordgang**: zwei laufen ihn gegenläufig ab, einer steht lange vor dem Büro des Profs. Wer im Lichtkegel steht, füllt ihren Verdacht, bei voll: erwischt, Level verloren. Sie hören Schritte und gehen nachschauen.
5. **Kameras** (`watch.gd`, `CAMS`): sechs Stück, sie schwenken hin und her, ihr Kegel ist rot. Wer 0,8 s darin steht, löst **Alarm** aus: Die drei nächsten Wachen rennen hin, alle sind 18 s lang schneller, der Bildschirm pulsiert rot. Danach ist die Kamera 7 s still. Kameras fangen niemanden selbst.
6. **Verstecken:** Büro-, Akten-, Garderoben- und Putzschränke, Transport- und Modellkisten: E bzw. Enter rein und wieder raus. Um die versteckte Figur liegt eine **Schranktür mit Lamellen**; kommt eine Wache näher, schlägt das Herz schneller und der Rand wird rot. **Wachen kontrollieren Schränke:** Ist eine Wache misstrauisch (sie sucht, schaut sich um oder hat Verdacht) und steht 1,2 s neben dem Schrank, reisst sie ihn auf: erwischt. Wer sich versteckt, während eine Wache ihn schon halb gesehen hat, wird direkt dort gesucht. Eine Wache, die nur vorbeiläuft, macht nichts.
7. **Am Computer des Profs** (`grade_pc.gd`, auf der eigenen Bildschirmhälfte): Notenliste mit acht Abgaben in zufälliger Reihenfolge, zwei davon mit einer 6. Hoch/runter wählen, E/Enter öffnet; dann den eigenen Namen eintippen, indem man E/Enter hämmert. Eine falsche Abgabe öffnen piept laut: Die Wachen in der Nähe hören es und kommen. Esc bzw. Rücktaste: weg vom PC. Beide müssen ran, nacheinander.
8. Sind beide Namen drin, knallt irgendwo eine Tür: Die Wachen werden schneller und sehen weiter.
9. **In den ETH-Link:** an der Bustür E/Enter, sobald der eigene Name bei der 6 steht. Sind beide drin: Cutscene, Sieg.

Zeit: 7 Minuten bis zum letzten ETH-Link.

## Die Karte

`build_map` räumt die Karte des Zentrums leer und baut den Campus Hönggerberg (Tiles): Strasse (y 76..79) mit Haltestelle (x 34..58), Platz vor dem HIL, Campus Info (62..72 / 60..68); das HIL: Nordflügel (8..100 / 8..24, Gang y 16..17, Büro des Profs 9..14), Mittelteil (28..64 / 24..56: gta-Ausstellung, Atrium 45..59 / 25..42, Gänge x 42..44 und 60..62, Alumni-Lounge, Foyer), Ostblock (64..100 / 30..50, Gang y 39..40, Zeichensaal 92..99). `md.mode = "night"` lässt `world.gd` die Karte nachts zeichnen (Laternen, Lichtinseln), das Spiel selbst läuft als Tag-Level mit Aufgaben. Die Wachen sind `professor.gd`, vom Level selbst in `main.profs` gesetzt (am Tag spawnt `main.gd` keine).

## Stellschrauben (oben in `level.gd`, `grade_pc.gd`)

| Konstante | Wert | Wirkung |
|---|---|---|
| `DEF.time` | 420 s | bis zum letzten ETH-Link |
| `GUARDS` | 9 | Name, Tempo, Sichtweite (Tiles), Pausen, Patrouillenpunkte |
| `GUARD_SPEED_UP`, `GUARD_RANGE_UP` | 1.25, 1 Tile | Wachen, sobald beide Namen drin sind |
| `CAMS` | 6 | Kameras: Ort, Blickrichtung, Schwenk, Reichweite |
| `ALARM_TIME`, `ALARM_SPEED`, `ALARM_GUARDS` | 18 s, 1.3, 3 | Alarm einer Kamera |
| `Cam.SEE_TIME`, `Cam.COOL` (`watch.gd`) | 0.8 s, 7 s | so lange im Kegel bis zum Alarm, Pause danach |
| `CHECK_TIME`, `CHECK_NEAR` | 1.2 s, 1.7 Tiles | misstrauische Wache macht den Schrank auf |
| `SAW_YOU` | 0.35 | ab diesem Verdacht hat die Wache das Verstecken gesehen |
| `CHARS_PER_PRESS` | 2 | Buchstaben pro Tastendruck beim Eintippen |
| Lärm beim Piepen | 7 Tiles | `_open_pc` in `level.gd` |

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | `DEF`, Karte (`build_map`), Wachen, Türen mit Kartenleser, Computer, ETH-Link, Cutscene, Zeichnung der eigenen Möbel und des Busses |
| `grade_pc.gd` | die Notenverwaltung am Computer des Profs |
| `watch.gd` | Überwachungskameras und die Schranktür um versteckte Figuren, roter Alarm |

Gemeinsame Dateien sind nicht angefasst.

## Stand

- Per Bot geprüft: jedes Bodenfeld im Gebäude und jedes Objekt ist von der Haltestelle aus erreichbar, alle Patrouillenpunkte auch; mit Karte vom Polyball und ohne (Ersatzkarte aus der Campus Info): Türen, beide Namen bei einer 6, beide in den ETH-Link, Sieg.
- Per Bot geprüft: Kamera löst nach 0,8 s Alarm aus; eine misstrauische Wache öffnet den Schrank, eine vorbeilaufende nicht; alle Patrouillenpunkte der neun Wachen erreichbar.
- Nicht gespielt: ob es zu schwer ist (neun Wachen, sechs Kameras, 7 Minuten). Erste Stellschrauben: `CAMS`, Anzahl `GUARDS`, `DEF.time`.

Ausserhalb des Ordners: `scripts/loading_screen.gd` zeichnet für Levels mit `"ride": "ethlink"` (nur dieses) den ETH-Link, der nachts auf den Hönggerberg fährt, statt der Polybahn, und hat Motive für Level 5 und 6. `level3/level.gd`: der Polyball hat im Ladebildschirm jetzt Nacht (`"sky": "night"`).
