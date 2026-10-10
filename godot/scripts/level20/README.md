# Wahlfach · Skifahren (Riesenslalom)

Freiwilliges Wahlfach am D-HEST, nicht Teil der Story. Man startet es jederzeit über den Leistungsüberblick (Kategorie «Wahlfächer»), im Menü oder im Spiel mit `L` bzw. dem Button unten rechts. Es ist nie das «nächste Level», und es löscht keine Opps oder Gegenstände der Story.

Die Nummer 20 hält das Wahlfach aus dem Weg der Story-Levels, die von 2 an aufwärts zählen. Dass es ein Wahlfach ist, steht in `DEF` als `"block": "W"` (`LV.is_elective`).

## So spielt es sich

1. **Cutscene:** Die beiden erfahren per myStudies und Mail, dass ihr Wahlfach am D-HEST Skifahren ist und die Prüfung zwei Läufe Riesenslalom sind.
2. **Countdown:** 3, 2, 1. Währenddessen merkt sich das Spiel, wie hoch der Kopf im Stehen ist (für die Hocke), und zeigt das Kamerabild.
3. **Zwei Läufe gleichzeitig:** Links fährt P1 (Pink), rechts P2 (Blau), auf derselben Piste. Man sieht die andere Person auf der eigenen Hälfte, in der Mitte zeigen zwei Punkte, wer wie weit ist. An jedem Tor erscheint der Abstand zur anderen Person (grün voraus, rot hinten).
4. **Nach dem 1. Lauf:** Zwischenstand, dann der 2. Lauf auf einer anderen Piste (Enter / E oder nach 7 s von selbst).
5. **Schluss:** Wer gewinnt, Duell-Bilanz der beiden Namen, Noten, Bestenliste. Enter / E: weiter zum Siegbildschirm. R: Revanche (zwei neue Läufe).

**Steuerung mit Kamera** (beide nebeneinander vor der Kamera): nach links und rechts gehen lenkt, in die Hocke gehen macht schneller, lenkt aber schlechter. **Ohne Kamera** oder sobald jemand eine Taste drückt: A / D bzw. Pfeile links / rechts, Hocke mit S bzw. Pfeil runter. Oben rechts auf jeder Hälfte steht, ob gerade Kamera oder Tasten lenken.

**Fehler:** Ein verpasstes Tor kostet 2 Sekunden. Wer eine Stange streift, wird kurz langsam. Neben der Piste ist Tiefschnee, dort geht es nur langsam voran.

## Bestenliste und Speichern (`ski_board.gd`)

- Jedes fertige Rennen wird mit Namen, beiden Laufzeiten, Gesamtzeit, verpassten Toren und Datum in `user://ski.cfg` gespeichert. Das ist eine eigene Datei: Ein neues Studium im Menü löscht die Rekorde nicht.
- Pro Namenspaar wird die Duell-Bilanz mitgezählt (wer wie oft gewonnen hat).
- In der Bestenliste stehen ausserdem feste Gegner (Skilehrer, Skiclub, Hilfsassistentin, Prof. Siedler) und **alle Opps** aus dem Spielstand (rot markiert). Ihre Zeiten sind Faktoren auf die Ideallinie, für denselben Namen immer gleich.
- Die Note gibt es nach Zeit: 6 auf der Ideallinie oder schneller, 4 bei 25 % langsamer. Die Note des Fachs ist der Schnitt der beiden.
- `--nosave` speichert nichts.

## Stellschrauben (oben in `ski_race.gd` und `ski_board.gd`)

| Konstante | Wert | Wirkung |
|---|---|---|
| `GATES`, `GATE_GAP`, `GATE_W` | 26, 350 px, 96 px | Anzahl Tore, Abstand, Breite eines Tors |
| `GATE_MIN_X`, `GATE_MAX_X` | 40, 125 px | wie weit die Tore seitlich versetzt sind (mehr = schwerer) |
| `SEEDS` | 5051, 7303 | die beiden Pisten; ändern macht alte Bestzeiten unvergleichbar |
| `V_MAX`, `V_TUCK`, `V_DEEP` | 500, 620, 210 px/s | Höchsttempo stehend, in der Hocke, im Tiefschnee |
| `LAT_MAX`, `LAT_TUCK` | 420, 240 px/s | wie schnell man seitwärts kommt |
| `MISS_PENALTY` | 2 s | Strafe für ein verpasstes Tor |
| `CAM_RANGE` | 0.16 | so weit (Anteil der Bildbreite) muss man gehen, um vom Pistenrand zum anderen zu kommen |
| `TUCK_DROP` | 0.08 | so viel tiefer (Anteil der Bildhöhe) muss der Kopf für die Hocke |
| `GRADE_SLOPE` | 8 | Notenpunkte pro 100 % langsamer als die Ideallinie |
| `RIVALS`, `OPP_FAST`, `OPP_SLOW` | | Zeiten der festen Gegner und der Opps als Faktor auf die Ideallinie |

Die Ideallinie (`_par`) wird beim Start ausgerechnet: ein Bot fährt jede Torstange mittig an, ohne Hocke. Ein vorausschauender Tasten-Bot schafft ungefähr diese Zeit (etwa 40 s für beide Läufe), ein unsauberer etwa 7 % mehr.

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | `DEF`, Cutscene, öffnet das Rennen im Vollbild, eigener Siegbildschirm mit der Note aus den Zeiten |
| `ski_race.gd` | das Rennen: Pisten, Physik, Kamera- und Tastensteuerung, Zeichnung, Zwischenstand und Schlussbild |
| `ski_board.gd` | Bestenliste, Duell-Bilanz, Speichern, Zeiten der NPCs und Opps |

Ausserhalb des Ordners angefasst: `levels.gd` (`is_elective`, `next_after` überspringt Wahlfächer), `game_state.gd` (`begin_level` tut bei Wahlfächern nichts, `story_level` für «Weiterspielen»), `transcript.gd` (Wahlfächer in der eigenen Kategorie), `main.gd` (Leistungsüberblick im Spiel mit `L` und Button), `menu.gd` («Weiterspielen» nimmt das letzte Story-Level).

## Stand

- Per Bot geprüft: Cutscene, beide Läufe, Zwischenstand, Schlussbild mit Bestenliste, Siegbildschirm und Note; Leistungsüberblick im Spiel öffnen und schliessen.
- Nicht geprüft: die Kamerasteuerung mit echten Menschen (Schwellen `CAM_RANGE`, `TUCK_DROP` sind Startwerte), wie schwer es sich anfühlt.
