# Level 6 · Bib in der Lernphase

Tag-Level für zwei. Juli, Lernphase, mitten am Tag: Die ETH-Bibliothek ist rappelvoll, und die beiden sind die Einzigen, die nicht lernen, weil sie die Prüfung schon haben (Level 5). Story-Level nach der Nacht im HIL (5) und vor der Basisprüfung (7).

## So spielt es sich

- **In der Bib wird geschlichen.** Gehen und Rennen hört man. Wer lernt, schaut auf und zischt «Psst!»; wer in `DEF.npcs` mit `"hears": true` steht, dreht sich zum Geräusch um (Opp-System).
- **Wegnehmen läuft über das Bag-System aus Level 1** (`opp.gd`, `"bag"` in `DEF.npcs`): Sieht es die Besitzerin oder der Besitzer, ist das sofort ein Opp. Sonst fällt es nach 6 bis 9 Sekunden auf (`NOTICE` in `opp.gd`), und dann wird in eure Richtung gesucht.
- **Erwischt** von jemandem aus diesem Level heisst: vor die Tür gestellt (Korridor vor dem Westeingang der Bib), ein Fehler, das Level geht weiter. Opps aus früheren Levels bleiben beim Standard: Level verloren.

## Aufgaben

| Aufgabe | Was passiert | Für wen |
|---|---|---|
| **Platz besetzen** | Alle Plätze sind «reserviert»: eine Jacke über dem Stuhl, ein leeres Mäppli, ein Laptop von jemandem, der seit Stunden weg ist. Reservation wegräumen (interagieren), hinsetzen, zehn Sekunden sitzen bleiben. Wer vorher aufsteht, fängt bei null an. Die drei, denen die Sachen gehören, stehen zwischen den Regalen im Pavillon; wer seine Reservation vermisst, kommt nachsehen und findet am ehesten, wer gerade auf seinem Platz sitzt. | jede Person für sich |
| **Fehler finden** | An den PCs der Bib läuft Code Expert. Drei Runden: je ein kurzes Python-Programm (4 bis 6 Zeilen) mit genau einer falschen Zeile, die man auswählt (hoch, runter, bestätigen, oder anklicken). Eine falsche Zeile ist ein Fehler mit Lärmkreis wie in den anderen Minigames. Wer abbricht, macht bei der Runde weiter, bei der er war. Keine Kamera. | jede Person für sich |
| **Zusammenfassung klauen** | Hans Muster steht am Ende des ersten Tisches und schaut auf seine Zusammenfassung, die vor ihm auf dem Tisch liegt. Nehmen geht mit dem «klauen» aus Level 1. Von jeder Stelle, von der man sie erreicht, sieht er einen, solange er hinschaut: also warten, bis er sich umdreht (alle 5 bis 9 Sekunden kurz), oder die andere Person lenkt ihn mit Lärm ab. Erledigt ist es erst, wenn man die Bib mit ihr verlassen hat, ohne erwischt zu werden; sonst liegt sie wieder am Platz. | eine Person holt sie, gilt für beide |
| **Starrwettbewerb** | Der Demo-Moment vor der Kamera: «Wer zuerst blinzelt, verliert die Runde», best of 3. Beide müssen am Fensterplatz stehen, dann interagieren. Details unter «Starrwettbewerb». | zu zweit gegeneinander, gilt für beide |
| **Code abschreiben** | Relay an der Theke: Eine Person liest einen kurzen Code vor, die andere tippt ihn. Der Code steht nur auf der Bildhälfte der Person, die liest (dort sieht sie auch, wie weit getippt ist); die Hälfte der Person, die tippt, zeigt nur das Getippte. Drei Codes mit Zeichen, die sich umständlich ansagen lassen (Klammern, Anführungszeichen, Unterstrich, eckige und geschweifte Klammern); nach jedem Code tauschen die Rollen. Wer das Minigame öffnet, liest zuerst. Leerzeichen tippt man nicht, sie kommen von selbst. Ein falsches Zeichen leert die Zeile und gibt einen Lärmkreis. Nur Esc bricht ab (Backspace nicht: Danach greift man beim Tippen von selbst); wer abbricht, macht beim selben Code weiter. Keine Kamera. | zu zweit, gilt für beide |
| **Steckdosenturm klauen** | Im Ostende der Bib steht ein Steckdosenturm zwischen zwei Lerntischen. Vier Geräte hängen dran: Laptop (Selina), Handy-Ladegerät (Beat), Tischlampe (Fabienne), Kaffeemaschine (Marco). Alle vier sitzen mit dem Rücken zum Turm und lesen. **1.** Geräte in fester Reihenfolge ausstecken: das bestehende Sequenz-Minigame, jedes Gerät ist ein Pfeil (oben, unten, links, rechts), die Reihenfolge leuchtet zuerst auf, im Minigame und an den Geräten. Ein falscher Stecker gibt Funken und einen Lärmkreis; **was draussen ist, bleibt draussen**, auch nach einem Abbruch. **2.** Wem ein Gerät ausgesteckt wurde, der merkt es nach 6 bis 9 Sekunden («Akku leer!») und wird zum Opp; sieht er einen dabei oder dreht er sich vorher um, sofort. **3.** Sind alle draussen, den Turm nehmen («klauen» aus Level 1) und aus der Bib tragen. Erledigt ist es erst draussen, ohne erwischt zu werden; sonst steht der Turm wieder an seinem Platz (die Stecker bleiben draussen). | eine Person trägt ihn hinaus, gilt für beide |
| **Mate klauen** | Neben dem Stuhl von Dario (Tisch 1) und von Nina (Tisch 4) steht je ein Rucksack, aus dem der Hals einer Mate-Flasche schaut. In der Bib ist Essen und Trinken verboten, die Mate ist also Schmuggelware. **1.** Leise von hinten heran: Schritte hören die beiden und drehen sich um, und wer gerade hergeschaut wird, kommt nicht an den Rucksack. **2.** Reissverschluss öffnen: das bestehende Timing-Minigame, drei Durchgänge im gleichmässigen Takt. Ein Fehlgriff gibt einen Lärmkreis; dreht sich die Person um und sieht die Hand im Rucksack, muss die Hand wieder raus (der Reissverschluss bleibt so weit offen). **3.** Die Mate gehört dir (die Figur trägt die Flasche), der Rucksack bleibt am Platz. Der Besitzer merkt es nach 6 bis 9 Sekunden oder sofort, wenn er sich umdreht und einen mit der Flasche sieht, und wird dann zum Opp. In jedem Rucksack ist eine Flasche, also braucht jede Person ihren eigenen Rucksack. | jede Person für sich |

**Die Zusammenfassung landet im Spielstand** als `hans_summary`: `Game.has_item("hans_summary")`. Level 7 (Basisprüfung) kann das so abfragen, um in der Prüfung Hinweise zu geben. Gesetzt wird es in dem Moment, in dem die Person mit der Zusammenfassung aus der Bib ist. Wird Level 6 neu gestartet, ist es wieder weg (`Game.begin_level`). Der Name steht als `SUMMARY_ITEM` oben in `level.gd`. Dasselbe Muster wie `prof_badge` aus Level 3.

## Starrwettbewerb

**Einbettung in die Platz-Geschichte:** Ein einziger Platz hat keine Reservation, der Fensterplatz an der Südwand (Tisch 3, Südseite links, mit Fenster und Sonnenfleck). Beide wollen ihn, keiner gibt nach, also starren sie sich an. Wer das Duell gewinnt, darf sich dort hinsetzen, und das zählt für «Platz besetzen»; die andere Person muss eine Reservation wegräumen. Bei Unentschieden gehört er, wer zuerst sitzt. Vor dem Duell kann sich dort niemand hinsetzen. Die Aufgabe selbst ist für beide erledigt, egal wie es ausgeht: Niemand bleibt hängen.

Ablauf einer Runde (`starr_spiel.gd`):

1. Beide sitzen nebeneinander vor der Kamera, **P1 links, P2 rechts**. Sobald die Kamera beide Gesichter `READY_HOLD` lang hat, zählt es «3, 2, 1, Augen auf!».
2. Danach gilt `BLINK_GRACE_S` Schonfrist, in der nichts zählt.
3. Ab dann zählt **jedes Kamerabild mit geschlossenen Augen sofort** als Blinzeln, ohne Mindestdauer: `TM.eyes_closed(Track.face(pid))`. Wer zuerst blinzelt, verliert die Runde.
4. Blinzeln beide im selben Bild: unentschieden, die Runde wird wiederholt. Nach `MAX_DRAWS` Unentschieden hintereinander geht die Runde an beide, damit das Spiel nicht hängen bleibt (zum Beispiel wenn niemand mehr vor der Kamera sitzt).
5. Kein Gesicht im Bild zählt erst nach `FACE_LOST_S` als Verlust. Kurz aus dem Bild zu geraten, entscheidet nie eine Runde.
6. Nach `ROUND_MAX_S` gewinnen beide die Runde.
7. Wer zuerst `WINS` Runden hat, gewinnt das Duell. Haben beide gleich viele (durch Runden, die an beide gingen), ist es unentschieden. **Wer verliert, bekommt einen Fehlerpunkt** wie bei jedem Minigame-Fehler, samt Lärmkreis.

- **Der Bildschirm ist hell, solange das Minigame offen ist.** Das ist Pflicht und keine Deko: Der Demo-Raum ist abgedunkelt, und ohne Licht findet MediaPipe kein Gesicht. Nicht dunkler machen.
- **Tasten-Variante:** Ist `Track.alive` nach `CAM_WAIT_S` noch falsch (oder meldet der Tracker «keine Kamera»), halten beide ihre Interaktionstaste gedrückt (P1 E, P2 Enter); wer loslässt, hat «geblinzelt». Gleiche Regeln. Wer vor oder zwischen den Runden seine Taste drückt, schaltet selbst auf Tasten um. Läuft die Kamera, aber nicht beide Gesichter sind im Bild, wartet das Spiel dreimal so lang (`CAM_PATIENCE`) und nimmt dann die Tasten. Umgeschaltet wird nur zwischen den Runden, nie mittendrin.
- Die Anzeige zeigt pro Person zwei Augen, die so weit zugehen, wie die Kamera es misst, darunter «im Bild» oder «nicht im Bild». So sieht man, was die Kamera glaubt.
- Es ist das einzige Kamera-Minigame des Levels, `tracking.gd` ist nicht angefasst, und es läuft nur das Gesichts-Modell. Kein Mikrofon.
- Die Karte dahinter wird solange nicht gezeichnet (`_freeze_views` in `level.gd`, wie in Level 4), sonst stottert das Kamerabild.

## Wo was ist

Es gibt keine neue Karte. Die Bib ist der Nordflügel des Hauptgebäudes, wie er in `map_data.gd` steht: Lesesaal 69..86, 27..34, Pavillon 78..86, 21..25, Tür vom Korridor bei (68, 27..28), Ausgang Rämistrasse bei (87, 30..31). `build_map` stellt nur zwei weitere Lerntische mit Stühlen ins Ostende des Lesesaals.

| Was | Tiles |
|---|---|
| Start | (66, 27.7), im Korridor vor der Westtür |
| Lesetische der Karte | (74.2, 29.4), (79.4, 29.4), (74.2, 32.6), (79.4, 32.6), je 3.6 × 1.2 |
| Lerntische des Levels | (83.2, 29.3) und (83.2, 32.7), je 2.9 × 1.0 |
| PCs mit Code Expert | (69.4, 33.7), 3.9 × 1.0: der «catalog» der Karte, zwei Bildschirme |
| Hans Muster, seine Zusammenfassung | er steht bei (73.7, 30), sie liegt bei (75.55, 30) auf Tisch 1 |
| Theke (Code abschreiben) | (69.4, 31.2), 3.5 × 0.95: der «counter» der Karte |
| Steckdosenturm | (84.65, 31.5), zwischen den beiden Lerntischen des Levels. Der Ausgang Rämistrasse liegt gleich daneben |
| Selina, Marco, Fabienne, Beat | (83.9, 30.85), (85.4, 30.85), (83.9, 33.1), (85.4, 33.1) |
| Dario und Nina, ihre Rucksäcke | Dario (76.83, 31.15), Rucksack (77.55, 31.25). Nina (80.13, 34.35), Rucksack (80.85, 34.45) |
| Fensterplatz | Tisch 3 Südseite links, bei (74.93, 34.35) |
| Reservierte Plätze | Jacke: Tisch 2 Südseite links. Mäppli: Tisch 3 Nordseite rechts. Laptop: Tisch 2 Nordseite rechts |
| Noah, Lara, Yannick (denen die Sachen gehören) | (79.5, 22.45), (84.5, 22.45), (85.3, 25.4), im Pavillon |
| Plätze für Opps aus früheren Levels | (82.5, 22.45), (78.6, 25.4), (80.9, 22.45), älteste zuerst, alle lauernd, alle drei im Pavillon (der dritte stand zuerst am Ostende des Gangs neben dem Steckdosenturm und beendete dort das Level) |

Wer wo sitzt, steht als Liste `SEATS` oben in `level.gd`: pro Stuhl Tisch, Stuhl am Tisch, Seite und wer dort ist (jemand, der lernt, eine Person aus `DEF.npcs`, oder die id der Person, die den Platz reserviert hat).

## Stellschrauben

Oben in `level.gd`:

| Konstante | Wert | Wirkung |
|---|---|---|
| `DEF.time` | 900 s | Zeitlimit, grosszügig: Das Level hat noch niemand gespielt |
| `SIT_TIME` | 10 s | so lange muss man sitzen bleiben |
| `REACH` | 1.15 Tiles | so nah an einer Sache oder einem Stuhl kann man sie benutzen |
| `STUN` | 1.4 s | so lange kann man sich nicht bewegen, nachdem man vor die Tür gestellt wurde |
| `OPP_CALM` | 6 s | so lange lässt einen danach in Ruhe, wer einen erwischt hat |
| `PSST_TIME` | 1.6 s | so lange schaut jemand auf, der etwas gehört hat |
| `PAIR_DIST` | 2.5 Tiles | so nah muss die andere Person stehen, wenn etwas zu zweit geht |
| `EJECT` | (66.2, 27.9) | wohin man gestellt wird |
| `SPARK_TIME` | 0.6 s | so lange sprüht der Turm nach einem falschen Stecker Funken |
| `DEVICES` | 4 Geräte | was am Turm hängt: Name, wem es gehört, auf welchem Tisch es steht. Die Reihenfolge der Liste ist die der Pfeile (oben, unten, links, rechts) |
| `SEATS`, `RESERVATIONS` | | wer wo sitzt, welche Plätze reserviert sind und womit |
| `HANS_ID` | `hans_muster` | dieselbe id wie in Level 3: Wer ihn dort oder hier zum Opp macht, den kennt er überall wieder |
| `SUMMARY_ITEM` | `hans_summary` | Name der Zusammenfassung im Spielstand |
| `DEF.npcs`, `DEF.opp_spots` | | Standort und Blickrichtung der Leute und der Opps aus früheren Levels |

Wie lange es dauert, bis ein Diebstahl auffällt, steht in `opp.gd` (`NOTICE`, 6 bis 9 s) und gilt für alle Levels.

In `rucksack.gd` (alles zur Mate, eigene Datei, damit sich die Verzögerung leicht ändern lässt):

| Konstante | Wert | Wirkung |
|---|---|---|
| `NOTICE` | 6 bis 9 s | so lange dauert es, bis die Besitzerin oder der Besitzer die fehlende Mate bemerkt, wenn niemand den Diebstahl gesehen hat |
| `MATES` | 1 | Flaschen pro Rucksack |
| `ZIP_HITS` | 3 | Durchgänge des Timing-Minigames, bis der Reissverschluss offen ist |
| `ZIP_SPEED` | 250 px/s | Tempo des Zeigers |
| `ZIP_EVEN` | an | der Zeiger behält sein Tempo (gleichmässiger Takt). Aus: nach jedem Treffer 15 % schneller, wie sonst im Timing-Minigame |
| `ZIP_KEPT` | an | der Reissverschluss bleibt nach einer Unterbrechung so weit offen, wie man war |
| `BACKPACKS` | 2 | wem ein Rucksack gehört, wo er steht, welche Farbe er hat |

Oben in `starr_spiel.gd`:

| Konstante | Wert | Wirkung |
|---|---|---|
| `BLINK_GRACE_S` | 0.5 s | Schonfrist nach «Augen auf», in der nichts zählt |
| `FACE_LOST_S` | 1.5 s | so lange darf ein Gesicht fehlen, bevor das als Verlust zählt |
| `ROUND_MAX_S` | 15 s | danach gewinnen beide die Runde |
| `CAM_WAIT_S` | 5 s | so lange ohne Kamerabild, dann übernehmen die Tasten |
| `CAM_PATIENCE` | 3 | mal so lange, wenn die Kamera läuft, aber nicht beide im Bild sind |
| `WINS` | 2 | so viele Runden braucht man (best of 3) |
| `COUNT_STEP` | 0.8 s | Dauer pro Zahl des Countdowns |
| `READY_HOLD` | 0.6 s | so lange müssen beide im Bild sein (oder ihre Taste halten), bevor der Countdown startet |
| `RESULT_TIME`, `END_TIME` | 2.4 s, 2.6 s | so lange steht das Ergebnis einer Runde bzw. des Duells da |
| `MAX_DRAWS` | 3 | nach so vielen Unentschieden hintereinander geht die Runde an beide |
| `LIGHT` | fast weiss, deckend | wie hell der Bildschirm wird |

Ab wann ein Auge als zu gilt, steht in `track_math.gd` (`BLINK_AT`, 0.5) und gilt für alle Levels.

Oben in `abschreib_spiel.gd`:

| Konstante | Wert | Wirkung |
|---|---|---|
| `TYPO_COUNTS` | an | ein falsches Zeichen zählt als Fehler für die Note. Aus: nur Lärmkreis und leere Zeile |
| `SWAP_PAUSE` | 1.6 s | Pause zwischen zwei Codes, in der die Rollen tauschen |
| `WRONG_FLASH` | 0.5 s | so lange bleibt die Hälfte der tippenden Person nach einem falschen Zeichen rot |
| `CODE_SIZE` | 26 | Schriftgrösse des Codes |

Die Codes stehen in `abschreib_codes.gd` (`CODES`, eine bis zwei Zeilen pro Code). Sie werden auf Deutsch und Englisch gleich gezeigt, deshalb neutrale Namen nehmen.

Oben in `fehler_spiel.gd`:

| Konstante | Wert | Wirkung |
|---|---|---|
| `ROUND_PAUSE` | 2 s | so lange steht die Erklärung da, bevor die nächste Runde kommt |
| `WRONG_FLASH` | 0.6 s | so lange bleibt eine falsch gewählte Zeile rot |
| `CODE_SIZE` | 19 | Schriftgrösse des Programms |

Die Programme stehen in `fehler_codes.gd` (`RUNDEN`: Zeilen, Nummer der falschen Zeile, Erklärung). Bis auf die eine Zeile muss alles echtes, korrektes Python sein, und jede Runde hat eine andere Fehlerart: fehlende Klammer, `=` statt `==`, Text plus Zahl. Das Englisch der Zeilen steht in `en.gd`.

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | Beschreibung (`DEF`), Tische (`build_map`), Plätze und Reservationen, Erwischt-Regel, Schluss, Zeichnung |
| `starr_spiel.gd` | der Starrwettbewerb vor der Kamera, mit Tasten-Variante |
| `abschreib_spiel.gd` | das Relay «Code abschreiben» für zwei: links die Hälfte von P1, rechts die von P2 |
| `abschreib_codes.gd` | die drei Codes dafür, zum Austauschen |
| `fehler_spiel.gd` | das Minigame «Fehler finden» für eine Person auf ihrer Bildhälfte |
| `fehler_codes.gd` | die drei Programme dafür, zum Austauschen |
| `schluss.gd` | das Schlussbild: Die beiden gehen hinaus, alle anderen lernen weiter |
| `rucksack.gd` | die Rucksäcke mit der Mate: wo sie stehen, wie lange es dauert, bis es auffällt |
| `en.gd` | Englisch für alle Texte dieses Ordners, auch für die Programme |

Gemeinsame Dateien sind nicht angefasst.

## Wie es gebaut ist

- **Reservation = Bag von jemandem, der nicht da ist.** Noah, Lara und Yannick stehen als `npcs` im Pavillon, ihr `"bag"` liegt am Platz. `opp.gd` zeichnet dafür einen Rucksack; `_swap_bag` hängt an dieselbe Stelle eine eigene Zeichnung (Jacke, Mäppli, Laptop), `opp.gd` blendet sie nur ein und aus. Wegräumen ruft `op.bag_taken(pid)` auf, alles Weitere macht das Opp-System. Sobald die Person es gemerkt hat, ist die Sache endgültig weg (`bag_state` «none»): Man trägt nichts herum, und der Platz bleibt frei.
- **`main.gd` kennt pro Level nur eine Aufgabe vom Typ `"bag"`** (`_bag_task` nimmt die erste). Hier gibt es mehrere Dinge zum Wegnehmen, deshalb sind alle Aufgaben vom Typ `"level"`, und `level.gd` entscheidet, wann eine erledigt ist. Das eigene «wegräumen» ersetzt beim Platz das «klauen» von `main.gd` (`update_near`), weil eine Reservation nicht aus dem Raum getragen wird.
- **Hinaustragen** (`loot`, `_update_loot`): Die Zusammenfassung ist die Bag von Hans Muster; nehmen, tragen und «Hände voll» macht `main.gd` wie in Level 1. `level.gd` hakt ab, sobald die Person, die sie hat, nicht mehr in der Zone «ETH-Bibliothek» ist, und trägt dann `SUMMARY_ITEM` ein. Danach ist sie verstaut: Die Hände sind wieder frei, sobald Hans es gemerkt hat. Wird die Person vorher erwischt, liegt die Zusammenfassung wieder am Platz (`_drop_loot`).
- **Steckdosenturm, Ausstecken** (`_open_turm`, `_watch_turm`): `main.open_minigame("sequence", …)`, die Reihenfolge der Stecker wird als Sequenz eingesetzt (`mg.seq`), sie ist bei jedem Start des Levels eine andere. Nach einem Fehler würde das Minigame wieder beim ersten Pfeil anfangen; `_watch_turm` setzt es auf den Stand zurück, der schon draussen ist (`unplugged`), und schreibt den Text unter die Tasten (welcher Pfeil welches Gerät ist).
- **Steckdosenturm, Mitnehmen:** Der Turm ist eine Bag ohne Besitzer. Das Bag-System braucht aber jemanden, der sie hält; dafür steht in `DEF.npcs` ein Eintrag ohne id, den `_ready` unsichtbar macht und abschaltet (sieht nichts, hört nichts, wird nie ein Opp). Nehmen, tragen und hinausbringen laufen dann genau wie bei der Zusammenfassung. Solange ein Gerät eingesteckt ist, bietet `update_near` «Geräte ausstecken» an statt «klauen».
- **Wer merkt es wann** (`_start_notice`, `_update_notices`): dieselbe Logik wie bei einer Bag in `opp.gd` (`bag_taken`, `_bag_clock`), für Dinge, die keine Bag sind: sofort, wenn die Person einen sieht; sonst nach der Wartezeit, oder früher, wenn sie sich umdreht und einen sieht. Danach `op.become_opp`, und sie jagt oder sucht wie nach einem Bag-Diebstahl. Die Wartezeit für die Geräte ist `NOTICE` aus `opp.gd`.
- **Mate** (`_open_mate`, `_watch_mate`, `_got_mate`): Der Rucksack ist keine Bag (er bleibt stehen), sondern ein Ort, an dem `main.open_minigame("timing", …)` aufgeht. `_watch_mate` hält den Zeiger auf seinem Tempo, merkt sich, wie weit der Reissverschluss ist, und bricht ab, sobald die Person, der er gehört, die Figur sieht. Nach dem Griff läuft `_start_notice` mit `NOTICE` aus `rucksack.gd`.
- **Hans Muster** hat in `DEF.npcs` kein eigenes `look`: `opp.gd` leitet das Aussehen aus der id ab, er sieht also aus wie in Level 3. Ist er schon ein Opp, lauert er von Anfang an bei seiner Zusammenfassung; mit Lärm lässt er sich weglocken.
- **«Relay-Prinzip aus Level 1»:** Im Code ist «Legi validieren» ein Timing-Minigame für eine Person, ein Relay gibt es dort nicht (das steht auch in der README von Level 3). «Code abschreiben» ist deshalb ein eigenes Minigame für beide, das wie ein Koop-Minigame von `main.gd` angemeldet wird (`_duo`): dasselbe Objekt an beiden Plätzen von `main.minis`, das Bild bleibt ungeteilt, links die Hälfte von P1, rechts die von P2.
- **Tippen braucht die ganze Tastatur.** `main.gd` öffnet mit L den Leistungsüberblick, auch während eines Minigames. Solange «Code abschreiben» offen ist, setzt es jedes Bild `main.tr_closed_frame` auf das laufende Bild; `main.open_transcript` hält den Überblick dann für gerade geschlossen und öffnet ihn nicht. Alle anderen Tasten nimmt das Minigame selbst entgegen (`_input`).
- **Tischplatten** liegen als eigene Nodes bei den Figuren (`_build_tables`), damit die Beine derer, die auf der Nordseite sitzen, unter dem Tisch verschwinden. Sie sehen aus wie die Lesetische in `world.gd`. Was auf einem Tisch liegt, wird mit der Platte gezeichnet.
- **Wer lernt**, ist eine einmal gezeichnete Figur ohne eigene Logik (`readers`), kein `opp.gd`: Das kostet nichts.
- **Erwischt** (`on_opp_catch`): Leute aus `DEF.npcs` stellen die Person vor die Tür. Für Opps aus früheren Levels gibt die Funktion `false` zurück, dann gilt der Standard von `main.gd`.

## Stand

- Gebaut sind alle sieben Aufgaben. Geprüft per Startlauf und je einem kurzen automatischen Lauf ohne Fenster.
- Mate: Reissverschluss im gleichmässigen Takt, ein Fehlgriff (Lärm, er dreht sich um, Hand raus, Reissverschluss bleibt ein Drittel offen), weitermachen, Flasche, der Besitzer wird zum Opp und stellt die Figur vor die Tür, die stehen bleibt; zweiter Rucksack für die zweite Person.
- Steckdosenturm: Reihenfolge wird gezeigt, ein Stecker raus, ein falscher (Funken, Lärm, wer schon ausgesteckt ist, dreht sich um, sieht die Figur und stellt sie vor die Tür), die andere Person macht bei Stecker zwei weiter, nimmt den Turm und trägt ihn zum Ausgang Rämistrasse hinaus; die übrigen drei merken es nach ihrer Wartezeit.
- Code abschreiben: alle drei Codes getippt (mit einem falschen Zeichen, Abbrechen und Weitermachen), die Rollen tauschen, ein L öffnet den Leistungsüberblick nicht.
- Starrwettbewerb, Tasten: Umschalten nach 5 Sekunden ohne Kamera, loslassen verliert die Runde, beide im selben Bild wird wiederholt, Zeit um geht an beide, Fehlerpunkt für die Verliererin, Fensterplatz nur für den Gewinner. Kamera mit von Hand eingespeisten Gesichtern: ein einzelnes Bild mit geschlossenen Augen entscheidet, 0.8 Sekunden ohne Gesicht entscheiden nichts, 1.8 Sekunden schon. **Vor einer echten Kamera ist er noch nie gelaufen** (aus der Claude-App gibt macOS die Kamera nicht frei): ob `BLINK_AT` für echte Augen passt, muss ein Mensch ausprobieren.
- Platz besetzen: Reservation wegräumen, hinsetzen, der Besitzer merkt es nach gut 6 Sekunden, kommt aus dem Pavillon und erwischt die Figur, die nach Ablauf der zehn Sekunden am Stuhl stehen bleibt; früh aufstehen setzt die Zeit zurück.
- Zusammenfassung: vor seinen Augen genommen (sofort Opp, erwischt, vor die Tür gestellt, Zusammenfassung wieder am Platz), danach von der anderen Person genommen und hinausgetragen (gilt für beide, `hans_summary` im Spielstand).
- Fehler finden: falsche und richtige Zeile, Tasten beider Personen, abbrechen und bei derselben Runde weitermachen, Deutsch und Englisch.
- Ein Lauf durch alle sieben Aufgaben bis zum Siegbildschirm («Weiter zu Level 7») ist ohne Skriptfehler durch; das Aussehen ist an Screenshots angesehen. Während des Starrwettbewerbs kann niemand die beiden sehen oder erwischen (`hidden_mode`), damit das Duell nicht unterbrochen wird.
- **Bekannt und offen (Aussehen):** Am Tisch nördlich des Steckdosenturms verdecken die Köpfe von Selina und Marco ihre Geräte (Laptop, Kaffeemaschine); die Sachen vor allen, die auf der Südseite eines Tisches sitzen, sind aus demselben Grund kaum zu sehen, und Mäppli und Laptop der Reservationen liegen etwas zu weit hinten auf dem Tisch. Abhilfe: in `_device_local` und `_paint_table` seitlich neben den Kopf rücken, die beiden `bag`-Positionen in `DEF.npcs` näher an die Nordkante.
- **Gespielt hat das Level noch niemand**, und das Aussehen (Tischplatten, Jacke, Mäppli, Laptop, Lesende) hat noch niemand am Bildschirm gesehen.
