# VIScon Hackathon Game

2-Spieler-Koop-Schleichspiel an der ETH (lokal, eine Tastatur). Team aus 5 Leuten, Hackathon-Ende **So 11.10.2026 12:55**, Feature Freeze So 06:00 (siehe `docs/TEAM.md`).

## Wo der Code liegt (wichtig)

- **Das echte Spiel ist das Godot-Projekt in `godot/`** (Godot 4.3+, `project.godot` meldet Feature 4.7, GDScript, alles im Code gezeichnet, keine Asset-Dateien, Sounds werden in `sfx.gd` erzeugt). Es liegt nur auf den Godot-Branches, nicht auf `main`.
- `main` enthält nur das ursprüngliche Phaser/TypeScript/Vite-Gerüst mit dem Platzhalter "ETH Exam Run" (`src/`). Das ist **nicht** das Spiel und wird nicht weiterentwickelt.
- Remote: `git@github.com:fzehnder/viscon-game.git`.
- Starten: Godot öffnen, `godot/project.godot` importieren, F5. Startszene ist `menu.tscn`. Direkt in ein Level: auf der Startseite unter «Direkt zu», oder `godot --path godot res://main.tscn -- --level=2`.

## Arbeitsweise (Wunsch des Teams, 10.10.2026)

- **Nicht nach jeder Änderung alles testen.** Getestet wird am Schluss oder wenn etwas nicht funktioniert. Nach einer Änderung reicht ein kurzer Startlauf, der Skriptfehler zeigt (siehe "Prüfen ohne Editor"); Bot-Durchläufe und Screenshots nur auf Wunsch, bei der Fehlersuche oder vor der Abgabe.
- Änderungen committen und pushen, wenn das Team es sagt ("push bitte"). Allgemeines kommt auf `level-base` und wird danach in die Level-Branches gemergt.
- Diese Datei nach jeder grösseren Änderung nachführen, damit neue Sessions den Stand kennen.
- Wünsche zur Platzierung und zum Aussehen gelten so, wie das Team sie sagt. Bedenken kurz nennen und technisch absichern, nicht eigenmächtig anders platzieren.

## Branches: Levels gleichzeitig bauen

Jedes Level bekommt einen eigenen Branch. Kein Level-Branch hängt von einem anderen ab: alle zweigen vom gemeinsamen Stand `level-base` ab.

| Branch | Inhalt |
|---|---|
| `main` | nur das alte Phaser-Gerüst |
| `level1-coop` | Godot-Spiel mit Level 1, Stand vor dem Level-Gerüst |
| `level-base` | gemeinsamer Stand: `level1-coop` plus Level-Gerüst, Opp-System, neues HUD mit Minimap, fliessender Split Screen und das Hauptgebäude nach echtem Grundriss; ohne weitere Levels |
| `level2-mensa` | `level-base` (regelmässig hineingemergt) plus Ordner `godot/scripts/level2/` |
| `level3-...` usw. | `level-base` plus Ordner `godot/scripts/level3/` |

Regeln:
- Neues Level: `git fetch`, dann `git switch -c level3-name origin/level-base`. Nie von einem anderen Level-Branch abzweigen.
- Einem Level gehört genau **ein Ordner** `godot/scripts/level<N>/` (Code, eigene README). Gemeinsame Dateien fasst ein Level-Branch nicht an. So gibt es beim Zusammenführen keine Konflikte, egal in welcher Reihenfolge.
- Braucht ein Level etwas Allgemeines (Hook in `main.gd`, Accessoire, Sound), dann als eigenen kleinen Commit, der früh nach `level-base` geht.
- Fertige Levels kommen per Pull Request nach `level-base`; die anderen Level-Branches holen den Stand mit `git merge origin/level-base`.
- Der Stand eines Levels wird in dessen `README.md` nachgeführt, nicht in dieser Datei (sonst kollidieren die Branches hier).
- Vor der Arbeit an einem Level dessen `godot/scripts/level<N>/README.md` lesen.

## Level-Gerüst

- `scripts/levels.gd` findet Levels selbst: Es prüft `res://scripts/level<N>/level.gd` für N = 2 bis 20 (`LV.numbers()`), Level 1 steht direkt in `levels.gd` (`LEVEL1`). Nichts muss registriert werden. Fehlt eine Nummer (Branch mit Level 1 und 3), wird sie übersprungen: `LV.next_after(n)`.
- `LV.current` ist das laufende Level, gesetzt vom Autoload `Game` (`Game.set_level(n)`). `LV.level()` liefert die Beschreibung, `LV.tasks()` / `LV.task(id)` die Aufgaben.
- `level.gd` eines Levels: `extends Node2D`, `const DEF` (Felder wie `LEVEL1`: `name`, `tag`, `mode`, `time`, `start`, `intro`, `tasks`; optionale Texte `hint`, `start_toast`, `timer_title`, `win_title`, `win_text` mit zweimal `%s`, `lose_title`, `lose_text`), optional `static func build_map(md)`. Die Datei ist zugleich der Logik-Node, den `main.gd` als `main.logic` in die Welt hängt (`main` ist vor `_ready` gesetzt).
- Aufgaben mit `"type": "level"` gehören dem Level. Hooks, die `main.gd` aufruft, alle optional: `update_near(pid)` (setzt `main.nears[pid] = {"use": "level", "label", "rect", ...}`), `interact(pid, o)`, `goal_positions(id, n0, n1)`, `task_targets(id, pid)`, `on_noise(at, radius)`, `finale(done)`. Aufgabe erledigt: `main._task_done(pid, id)`.
- Aufgaben mit `"spots"` (wie in Level 1) werden ohne eigene Logik zu Stationen mit Minigame.
- Nach dem Sieg zeigt `main.gd` "Weiter zu Level N", solange es ein nächstes gibt.
- `scripts/cutscene.gd`: Cutscenes aus Schritten (`say`, `phones`, `mail`, `title`), für alle Levels.
- Opps: `"npcs"` und `"opp_spots"` in `DEF`, `Game.add_opp(...)` für eigene Auslöser, optionaler Hook `on_opp_catch(opp, pid) -> bool`. Siehe Abschnitt "Opp-System".
- Ein lauffähiges Gerüst für ein neues Level steht in `godot/README.md` (getestet), die ausführliche Vorlage ist `scripts/level2/level.gd` auf `level2-mensa`.

## Karte

Vorgabe des Teams: Das Hauptgebäude soll sich am echten Grundriss orientieren (`Übersichtsplan_HG_ E-Stock.pdf` im Ordner über dem Repo, Fluchtwegplan E-Geschoss), kleiner und mit weniger Räumen, aber Form und Aufteilung sollen stimmen. Gebaut in `map_data.gd` (`_hauptgebaeude`, Möbel in `_furniture`). Norden oben, Polyterrasse im Westen, Rämistrasse im Osten. Die Südhälfte ist die gespiegelte Nordhälfte (`mfill`, `mdoor`: Zeile y entspricht 91 - y; für Möbel mit Höhe h gilt y' = 92 - y - h).

| Ort | Tiles (x, y) | Zugang |
|---|---|---|
| Polyterrasse | 10..37, 20..62 | Start von Level 1 |
| Westeingang und Eingangshalle | 39..45, 43..48 | Tür bei x 38, y 44..47 |
| Haupthalle | 46..67, 43..48 | von der Eingangshalle, vom Korridor-Ring, aus E Nord und E Süd |
| Rotunde | 69..74, 39..52 | Durchgang bei x 68, y 44..47; Tür zum Vorhof bei x 74, y 45..46 |
| Vorhof Rämistrasse | 69..89, 36..55 | Tor im Zaun bei y 44..47 |
| Korridor-Ring | Nord y 27..28, Süd y 63..64, West x 44..45, Ost x 66..67 | |
| Nordeingang, Südeingang | x 52..54, y 22 und y 69 | Vorraum bis zum Korridor |
| E Nord (Foyer) | 47..59, 30..41 | Durchgänge bei x 47..48 und 58..59 nach Norden (Korridor) und Süden (Haupthalle) |
| Hörsaal E1 | 50..56, 30..34 | Türen bei x 49 und x 57, y 32 |
| Hörsaal E3 | 50..56, 39..41 | Tür vom Foyer (53, 38) und zur Haupthalle (54, 42) |
| E Süd, Hörsaal E5, Hörsaal E7 | gespiegelt: Zeile y entspricht 91 - y | |
| Seminarraum | 39..42, 23..27 | Tür (43, 27) |
| Lounge | 39..42, 64..68 | Tür (43, 64) |
| Büros West | 40..42, 29..33 / 35..41 / 50..56 / 58..62 | Türen bei x 43 |
| Räume Nord und Süd | 44..50, 56..60, 62..67 bei y 23..25 und y 66..68 | Türen zum Korridor |
| Räume am Ostkorridor | 61..64, 30..34 / 36..41 / 50..55 / 57..61 | Türen bei x 65 |
| ETH-Bibliothek | 69..86, 27..34 und Pavillon 78..86, 21..25 | Tür vom Korridor (68, 27..28), Ausgang Rämistrasse (87, 30..31) |
| Labor · Robotik | 69..86, 57..64 und Pavillon 78..86, 66..70 | Tür vom Korridor (68, 63..64) |
| Mensa | 13..32, 65..76 | Tür bei x 21..24, y 64 |

- Massstab: etwa 21 px im Plan pro Tile. Die Ostflügel sind tiefer als im Original (8 statt 6 Tiles innen), damit Bibliothek und Labor Platz haben; im echten Gebäude sind dort Büros, die Bibliothek liegt im H-Stock.
- Wegen des grösseren Gebäudes liegt die Künstlergasse 6 Tiles weiter südlich (y 72..77 statt 66..71), die Uni Zürich ist nur noch ein schmaler Streifen. Mensa und Polyterrasse sind unverändert, Level 2 ist nicht betroffen.
- Strassenmarkierungen (Zebrastreifen vor Nordeingang und Vorhof, Mittellinien) stehen fest in `world.gd` `_draw` und müssen bei Kartenänderungen mitziehen.
- Wer Möbel stellt: Die Wegfindung rechnet in ganzen Tiles. Ein Möbel, das in eine Tile-Zeile hineinragt, sperrt für NPCs die ganze Kachel. Deshalb Möbel an Wände rücken und Türkacheln (die Kachel vor jeder Tür) frei lassen. Der Test unten findet abgeschnittene Bereiche.

## Opp-System (gebaut, auf `level-base`)

Vorgabe des Teams: Die meisten NPCs sind zuerst neutral, ein Ereignis macht sie zum Opp, der Status bleibt über Levels gespeichert. Level 1: zwei Studis am Lesetisch, Rucksack (gemeint ist die Ersti-Bag) geklaut, Opp verfolgt dich. Level 2: Person in der Schlange, vor die man sich drängelt. Ab Level 3: Opps aus früheren Levels tauchen wieder auf, jagen direkt oder lauern.

Umsetzung (an den vorhandenen Code angepasst: Skripte statt `Npc.tscn`, Sicht per Rechnung und Raycast statt `Area2D`, Spawns in `DEF` statt in einer Textdatei):
- `scripts/opp.gd`: `CharacterBody2D` mit Zuständen `NEUTRAL, MISSTRAUISCH, JAGD, SUCHEN, ZURUECK, LAUERN` (`enum` und `match`). Gezeichnet wie alle Figuren, Opps tragen ein rotes Namensschild.
- Sicht: Kegel (38 Grad halber Winkel, 5.5 Tiles), `world.sight_clear` / `sight_end` blocken an Wänden und hohen Möbeln (`TALL_KINDS` in `world.gd`, Kollisionslayer 64; ein Level markiert eigene Möbel mit `"tall": true`).
- Verdachtsbalken `meter`: füllt sich in `_watch`, solange ein Gegner sichtbar ist, bei 1.0 beginnt die Jagd. Vor dem Losrennen 0.7 s Schrecksekunde (`START_DELAY`).
- Lärm: `main.on_step` und Minigame-Fehler rufen `hear` auf. Neutrale reagieren nur mit `"hears": true`, Opps immer (sie gehen nachsehen).
- `foes`: Ein Opp jagt nur die Spieler, die ihm etwas getan haben.
- Erwischt (`main.opp_catch`): mit dessen Bag = Beute weg, Aufgabe wieder offen, Fehler; sonst `main.caught(opp)` = Level verloren. Level können das mit `on_opp_catch` übersteuern.
- Klaubare Bag: `"bag"` am NPC, Interaktion `"use": "bag"` in `main.gd`, Aufgabentyp `"bag"`. `"bag_acc"` bestimmt, wie der Dieb sie trägt (`erstibag` auf dem Rücken oder `loot` in der Hand), `"bag_name"` den Namen in Texten. Gesehen = sofort Opp und Jagd, ungesehen = Timer `NOTICE` (6 bis 9 s), dann Suche in Richtung des Diebs.
- Speicher: `Game.opps` (`id -> {name, look, level, by, why}`), `ConfigFile` unter `user://save.cfg`. `Game.begin_level()` löscht beim (Neu-)Start eines Levels alle Opps, die in diesem oder einem späteren Level entstanden sind; `Game.new_game()` löscht alle. `--nosave` hält alles nur im Speicher (für Tests).
- Wiederkehr: `main._spawn_npcs` setzt Opps aus früheren Levels an die `opp_spots` des Levels (`"lauert"` oder `"jagd"`). Level 1 und 2 haben keine `opp_spots`; ab Level 3 muss das Level welche angeben.
- Level 1: Der "Rucksack" aus der Vorgabe **ist die Ersti-Bag**, es gibt dafür keine eigene Aufgabe. Deniz (`rucksack_a`) und Livia (`rucksack_b`) sitzen am Lesetisch in der Bibliothek, ihre Ersti-Bags stehen neben dem Stuhl; die Aufgabe "Ersti-Bag klauen" (jetzt Typ `"bag"`) wird dort erledigt. Die Ersti-Menge auf der Polyterrasse trägt keine Bags mehr (`"bags": 0`); der alte Weg (Bag einem Ersti aus der Menge per Timing-Minigame vom Rücken klauen, Typ `"steal"`) steckt noch in `main.gd` und `student.gd`, ist aber abgeschaltet.
- Level 2 (auf `level2-mensa`): siehe dessen README.

## Spielkonzept (Plan)

Allgemein:
- 2 Spieler Koop, lokal an einer Tastatur
- Minigames im Split Screen; auch Split Screen, wenn die Spieler zu weit auseinander sind
- Tag- und Nacht-Challenges

Nacht-Challenges:
- Guards patrouillieren, ihr Sichtkegel ist für die Spieler sichtbar
- Spieler im Kegel: Guard ist alarmiert und kann sprinten (etwas schneller als normales Gehen des Spielers, langsamer als Spieler-Sprint)
- Schritte erzeugen Geräuschkreise, die sich ausbreiten; andere Geräusche ebenso
- Erreicht ein Kreis einen Guard, ist er alarmiert und geht zur Quelle
- Schleichen = minimales Geräusch
- Sprinten 2 s mit lauteren Schritten, Stamina leert sich und regeneriert über einige Sekunden
- Gefangen (Guard berührt Spieler): Spieler wird aus dem Gebäude geworfen und kommt nicht mehr allein hinein
- Der Teammate kann ihn wieder hineinholen
- Level verloren, wenn beide draussen sind
- Aufgaben sind über die Karte verteilt, meist mit Minigames
- Gewonnen, wenn alle Aufgaben erledigt sind und beide entkommen

Tag-Challenges:
- Andere Leute der Fakultät (Studierende, Profs, TAs usw.), keine Guards
- Gleiche Spielerbewegung mit Geräuschen

Opp-System (levelübergreifend):
- Wer einem NPC etwas klaut (Mate, Ersti-Bag usw.) oder beim Abschreiben erwischt wird, macht diesen NPC zum "Opp"
- Backend: Opp-Liste führen und Opps je nach Level spawnen

Level 1 (Ersti-Tag):
- Start mit gefälschter Legi: Intro-Cutscene (Hack in den Server), neuen Studenten anlegen, Namen eingeben und Charakter erstellen, ausloggen, Spiel startet
- Ersti-Bag von Deniz klauen, der NPC Deniz ist danach ein Opp
- Legi validieren

Level 2 (Mensa):
- In die Mensa-Schlange drängeln. Die Schlange funktioniert wie ein Stau: Rückt jemand auf, braucht die Person dahinter etwas Zeit zum Loslaufen. Mit gutem Timing schleichen die Spieler in diese Lücke
- Danach an einen Tisch setzen
- Cutscene: Sie erfahren (E-Mail), dass sie für die Basisprüfung angemeldet sind

Level 3:
- Bonusaufgabe von einem NPC abschreiben; erwischt er einen, wird er ebenfalls Opp
- Zusammenfassungen klauen
- Mate klauen
- Snacks klauen
- Zusammenfassungen vom Computer einer anderen Person an sich selbst schicken

## Stand (10.10.2026)

Auf `level-base`:
- Koop-Steuerung (`controls.gd`, physische Tastenpositionen): P1 WASD / E / Shift Sprint / Ctrl Schleichen / Esc / 1 2 3; P2 Pfeile / Enter / `.` Sprint / `-` Schleichen / Backspace / 8 9 0
- Dynamischer Split Screen (`main.gd`, `SPLIT_AT` / `MERGE_AT`), auch wenn jemand im Minigame ist, mit fliessendem Übergang (`split_k`, `SPLIT_TIME`)
- HUD: Aufgaben pro Person auf ihrer Seite (P1 links, P2 rechts), Level und Zeit oben Mitte, Minimap unten Mitte
- Karte: Hauptgebäude nach dem echten Grundriss des E-Geschosses (siehe "Karte")
- Aufgabe wählen (Tab für P1, Komma für P2, oder Klick auf die Aufgabe): gestrichelte Pfeile in der Farbe der Person zeigen den kürzesten Weg zum nächsten Ort, an dem die Aufgabe lösbar ist, auch auf der Minimap. `main.picked` / `main.routes`, Ziele aus `main.task_targets(id, pid)` (Stationen, Bags, bei Koop-Aufgaben die andere Person, bei Level-Aufgaben der Hook `task_targets` oder ersatzweise `goal_positions`), gezeichnet in `fx.gd` (`_draw_route`). Nur auf Skriptfehler und einen kurzen Lauf geprüft, nicht gespielt
- Schleichen / Gehen / Sprinten, Stamina (2 s Sprint, ca. 3 s Regeneration), Geräuschkreise pro Schritt (`player.gd`, `fx.gd`)
- Story-Intro im Menü: Startseite, Hack der Bewerbungsseite, Namen, Legi-Foto, Charakter-Editor; Level-Auswahl «Direkt zu»
- Level 1 "Ersti-Tag" (Tag, 7 min): Ersti-Bag klauen (bei Deniz und Livia am Lesetisch, macht sie zu Opps), Legi validieren, Moodle & Code Expert einrichten, Koop-High-Five, Note 1 bis 6
- Minigames (`minigame.gd`): Timing, Kabel, Sequenz, Quiz, Moodle, Setup, High Five
- Karte ETH Zentrum mit Tag/Nacht, Kollision, A*-Wegfindung, HUD, Popups
- Level-Gerüst, Cutscene-Abspieler, Übergang zum nächsten Level
- Opp-System samt Ersti-Bag-Diebstahl in Level 1 (siehe oben). Per Bot geprüft, von Menschen noch nicht gespielt

Auf `level2-mensa`: Level 2 "Mensa-Stau" komplett spielbar (Schlange als Stau, Kassiererin, Menü, Tische, Basisprüfungs-Cutscene, Opps durch Vordrängeln). Details, Stellschrauben und Offenes in `godot/scripts/level2/README.md`.

Geprüft (per Bot, nach dem Kartenumbau): Level 1 mit Ersti-Bags und Opps bis zum Sieg, Kamera und HUD, Level 2 von der Schlange bis zum Siegbildschirm, Erreichbarkeit aller Räume bei Tag und Nacht. Von Menschen ist noch nichts davon gespielt worden: Schwierigkeit, Zeiten und das Gefühl des Split-Screen-Übergangs sind offen. Die Nacht ist nach dem Kartenumbau nur auf Erreichbarkeit geprüft, nicht gespielt.

Altes Prototyp-Verhalten (Nacht), noch nicht nach Plan:
- Professoren als Guards (`professor.gd`): Patrouille, sichtbarer Kegel, hören Geräuschkreise. Volle Anzeige oder Berührung ruft `main.caught()` auf und **beendet das Level sofort für beide**
- Nacht-Mission und Q-Fähigkeit hängen am alten Departement-System (`characters.gd`, `Game.dept` fest auf D-INFK)

Offen:
- Nacht laut Plan: Guard-Sprint bei Alarm, Rauswurf statt Game Over, Teammate holt den Spieler zurück, verloren erst wenn beide draussen sind
- Opps: Kein Level hat bisher `opp_spots`, die Wiederkehr ist nur mit einem Testlevel geprüft. Offen ist auch, ob "erwischt ohne Beute = Level verloren" am Tag zu hart ist
- Level 3 komplett. Wer schon Positionen im alten Hauptgebäude verwendet hat, muss sie an die neue Karte anpassen (Tabelle unter "Karte")
- Die Möblierung der neuen Büros und Hörsäle ist schlicht (Pult, Stuhl, Bankreihen); die Hörsäle sind rechteckig mit Bühnennische statt fächerförmig, die Höfe neben den Hörsälen fehlen
- Nichts davon ist auf `main` gemergt; der Pages-Deploy-Workflow baut weiterhin nur den Phaser-Platzhalter

## Code-Orientierung (`godot/scripts/`)

| Datei | Inhalt |
|---|---|
| `game_state.gd` | Autoload `Game`: Level, Modus, Namen, Fotos, Looks der beiden Spieler, Liste der Opps und Spielstand (`user://save.cfg`) |
| `levels.gd` | findet die Levels, enthält Level 1 (Positionen in Tiles, 1 Tile = 32 px) |
| `level<N>/` | je ein weiteres Level: `level.gd`, eigene Figuren, `README.md` |
| `cutscene.gd` | Cutscene-Abspieler |
| `main.gd` | Spielablauf, Split Screen, Interaktion, Aufgaben, Sieg/Niederlage, Level-Hooks |
| `player.gd`, `student.gd`, `professor.gd` | Spieler, Studierende/Erstis, Guards |
| `opp.gd` | Leute, die zu Opps werden (Zustände, Kegel, Verdachtsbalken, klaubare Bag) |
| `minigame.gd` | alle Minigames |
| `map_data.gd`, `world.gd` | Kartendaten (Hauptgebäude in `_hauptgebaeude`), Zeichnen, Kollision, Wegfindung, Sichtlinien |
| `menu.gd`, `legi_card.gd` | Story-Intro, Charakter-Erstellung, Level-Auswahl |
| `hud.gd`, `ui.gd`, `fx.gd`, `sfx.gd` | Anzeigen (Aufgabenkarten, Zeit, Minimap), Popup-Stil, Effekte, Sounds |
| `characters.gd`, `character_art.gd` | Looks, Quiz-/Moodle-Inhalte, Figuren-Zeichnung |

Konventionen: Code-Kommentare auf Englisch, Texte im Spiel auf Deutsch (Schweizer Schreibweise, kein ß). Zeilenenden LF (`godot/.gitattributes`). Godot legt neben jedes Skript eine `.uid`-Datei, die gehört mit ins Repo.

## Learnings

So funktioniert die Engine-Seite des Spiels:
- **Zeichenebenen:** `world.gd` zeichnet Karte und Möbel auf `z_index -10`, Figuren liegen in `main.actors` (nach y sortiert), `fx.gd` auf `z 5`, HUD ist ein `CanvasLayer` (10), Minigames 20, Cutscene 30. Ein Level-Node mit `z_index = -5` zeichnet Bodendeko über der Karte und unter den Figuren.
- **Möbel, die Figuren verdecken sollen** (Tisch vor den Beinen), müssen eigene kleine Nodes in `main.actors` sein, positioniert an ihrer Vorderkante. Alles, was `world.gd` zeichnet, liegt immer unter den Figuren.
- **Möbel pro Level:** `md.R(kind, x, y, w, h, extra)` in `build_map`. `world.gd` zeichnet nur Arten, die es kennt (`_draw_obj`); unbekannte Arten bekommen trotzdem Kollision und A*-Sperre und werden vom Level selbst gezeichnet. So muss `world.gd` nicht angefasst werden.
- **Kollisionslayer:** 1 Wände und Türen, 2 Möbel, 4 Spieler, 8 Professoren, 16 Studierende, 32 Mensa-Schlange, 64 hohe Möbel (nur für die Sicht der Opps, zusätzlich zu 2). Spieler haben Maske 1|2, laufen also durch NPCs hindurch. Sollen NPCs im Weg stehen, gibt das Level ihnen einen eigenen Layer und setzt ihn in `_ready` in die Maske der Spieler. NPCs, die man direkt per `global_position` bewegt (ohne `move_and_slide`), sind trotzdem feste Hindernisse.
- **Figur in einem Kollisionsrechteck** (Sitzplatz hinter dem Tisch) wird von `move_and_slide` herausgedrückt, auch im Stand. Solange sie sitzt: `collision_layer` und `collision_mask` auf 0, danach zurücksetzen.
- **`main.state`:** `intro`, `play`, `cutscene`, `caught`, `won`, `lost`. Die Zeit läuft nur in `play`. Studierende und `fx` stehen ausserhalb von `play` still bzw. sind unsichtbar; wer in einer Cutscene weiterlaufen soll, muss `cutscene` selbst zulassen.
- **Spieler sperren:** `pl.enabled = false`. Achtung: `main.open_minigame` setzt beim Schliessen `enabled = true`. Reihenfolge der Callbacks dort: `on_close`, dann `enabled = true`, dann `on_success`.
- **Wegfindung:** `main.world.find_path(von_px, nach_px)` liefert Tile-Mittelpunkte ohne exakten Endpunkt, den selbst anhängen. Mit `astar.set_point_weight_scale(tile, 6.0)` hält man Läufer von Bereichen fern, ohne sie zu sperren.
- **HUD ausblenden:** `main.hud.visible = false`.
- **Kamera und Split Screen:** Es gibt immer zwei halbe Viewports. Sind die Figuren zusammen, stehen die beiden Kameras nebeneinander und die Hälften ergeben ein Bild; zum Teilen gleitet jede Kamera zu ihrer Figur (`split_k` 0 bis 1, `split` ist nur das Ziel). Deshalb: Kamerapositionen setzt ausschliesslich `main._update_cameras`, Zoom nur über `main.zoom` (auch in Tweens: `tween_property(main, "zoom", 3.5, 0.9)`), nie an einer einzelnen Kamera, sonst passen die Hälften nicht mehr zusammen. Die eingebaute Kameraglättung ist aus, geglättet wird in `_update_cameras` (`CAM_FOLLOW`).
- **HUD-Plätze** (so vom Team gewünscht): oben links und rechts die Aufgabenkarten, oben Mitte Level und Zeit, unten Mitte die Minimap, unten links die Nacht-Fähigkeit, Eingabehinweise unten bei 25 % und 75 % der Breite, der Toast erscheint für ein paar Sekunden vor der Minimap. Damit im gemeinsamen Bild niemand hinter Zeit-Karte oder Minimap gerät, teilt sich der Bildschirm vertikal früher (`SPLIT_AT_Y` 0.42 statt 0.7 wie horizontal). Wer eine dieser Anzeigen grösser macht, muss `SPLIT_AT_Y` nachrechnen: Füsse der oberen Figur bei `360 - SPLIT_AT_Y * 360` px, eine Figur ist bei Zoom 2.5 etwa 115 px hoch.
- **Minimap:** Klasse `MiniMap` in `hud.gd`, Kacheln einmal als Textur, Markierungen aus `main.goal_positions()`. Was ein Level dort zeigen will, liefert es über `goal_positions`.
- **Aufgabe wieder öffnen:** `main.done[pid].erase(id)`; das HUD zieht den Chip von selbst zurück.
- **Spielstand:** Alles, was `Game.save_game()` schreibt, landet im echten `user://`-Ordner des Rechners. Tests mit `--nosave` starten oder `Game.save_path` auf eine Testdatei umbiegen und diese am Ende löschen.

GDScript-Fallen, in die ich getreten bin oder die ich umgangen habe:
- `levels.gd` darf den Autoload `Game` nicht benutzen (`game_state.gd` lädt `levels.gd` per `preload`, das wäre ein Zirkel). Deshalb die statische Variable `LV.current`.
- Level-Skripte werden mit `load()` geholt, nicht mit `preload`. Auf dem geladenen Skript funktionieren `sc.DEF`, `sc.new()` und statische Funktionen (`sc.build_map(md)`); ob eine statische Funktion existiert, prüft `sc.get_script_method_list()`.
- Lambdas an `get_tree().create_timer(...)`, die einen Node einfangen, werfen "Lambda capture was freed", wenn der Node vorher gelöscht wird. Stattdessen `node.create_tween()` mit `tween_interval` und `tween_callback`: Der Tween stirbt mit dem Node.
- Text, der sich selbst tippt: `label.visible_characters` hochzählen, nicht `text` ändern, sonst springt das Layout.
- Konstanten mit Funktionsaufruf (`const X := deg_to_rad(...)`) vermeiden, Zahl direkt hinschreiben.
- In einer Schleife über `members.size()` die Liste nicht verändern; Abgänge merken und nach der Schleife entfernen.
- Der Standard-Font kann «•», «·» und Guillemets, aber keine Emojis oder Pfeil-Symbole: Symbole zeichnen statt schreiben.

Damit ein Level zum Rest passt:
- Farben und Bausteine aus `ui.gd`: Panels `UI.panel(UI.NAVY, Rahmenfarbe)`, Texte `UI.label`, Buttons `UI.button`, Einblenden `UI.pop_in`, Wackeln `UI.shake`, Konfetti `UI.confetti`. P1 ist Pink, P2 Blau (`KEYS.TAG_COLORS`), Gelb heisst "beide".
- Blasen über Köpfen: dunkler Kreis, Radius 10, bei y -58. Gelbes «!» = passt auf (wie die Erstis), Grün = Chance. Sichtkegel wie bei den Professoren: `Color(1.0, 0.93, 0.6, 0.2)`, bei Alarm Richtung Rot.
- Hinweise als `main.hud.toast(Titel, Text, Dauer)`, Erklär-Toasts nur einmal zeigen. Erledigtes feiert `main._task_done` selbst. Fehler: `main.mistakes_total += 1`, roter Geräuschkreis `main.fx.sound(...)`, `UI.sfx("fail")`.
- Ziele als Rauten über `goal_positions` in der Farbe derer, die sie noch brauchen (`main._need_color`).
- Neue Sounds als Notenliste in `sfx.gd`, neue Accessoires in `character_art.gd`.

Leveldesign:
- Das Zeitfenster, um das sich ein Level dreht, sichtbar machen (ablaufender Ring, Markierung am Boden), sonst wirkt Erwischtwerden willkürlich.
- Den "ehrlichen" Weg nachrechnen: In Level 2 muss Anstehen länger dauern als das Zeitlimit, sonst drängelt niemand.
- Lösbarkeit garantieren statt hoffen (Gäste lassen immer zwei Plätze an einem Tisch frei; ein lauernder Opp lässt sich durch Lärm von seiner Bag weglocken).
- Wer direkt neben einem NPC etwas tut und gesehen wird, wäre ohne Schrecksekunde sofort gefangen. Verfolger brauchen eine kurze Verzögerung, sonst gibt es keine Flucht.
- Alle Stellschrauben als Konstanten oben in `level.gd` und in der Level-README erklären; das Team stellt sie im Spieltest ein.

Zusammenarbeit:
- Begriffe aus einer Vorgabe erst gegen das abgleichen, was es im Spiel schon gibt, bevor etwas Neues daneben entsteht. Der "Rucksack" in der Opp-Vorgabe war die vorhandene Ersti-Bag; ich hatte zuerst eine zweite Aufgabe gebaut.
- Die Zeit-Karte hatte ich aus Sorge um verdeckte Figuren nach unten gelegt; das Team wollte sie oben und die Minimap unten in der Mitte. Richtig war: so platzieren wie gewünscht und das Verdecken über `SPLIT_AT_Y` lösen.
- Ausführliches Testen nach jedem Schritt kostet dem Team zu viel Zeit (siehe "Arbeitsweise").

## Prüfen ohne Editor

Nur so viel wie nötig (siehe "Arbeitsweise"): normalerweise der kurze Startlauf, alles Weitere auf Wunsch, bei der Fehlersuche oder vor der Abgabe.

- Ein kurzer Headless-Lauf findet nur Parse-Fehler und Fehler beim Aufbau, denn das Spiel bleibt im Intro stehen:

```bash
godot --headless --path godot --fixed-fps 60 --quit-after 600 res://main.tscn -- --level=2
```

- Für echte Abläufe eine temporäre Szene ins Projekt legen (`zz_test.tscn` plus Skript), die `main.tscn` instanziert, `main.start_game()` aufruft und spielt: Tasten über `Input.action_press("p1_left")`, Interaktion über `main._interact(pid)`, Timing-Minigame über `main.minis[pid]._timing_press()`, wenn `pos` in `zone` liegt, Abkürzungen per Teleport. Am Ende `RESULT` ausgeben und `get_tree().quit(code)`. `--fixed-fps 60` lässt das schneller als Echtzeit laufen. Tweens (zum Beispiel das Hinausschieben aus der Schlange) überschreiben einen Teleport kurz, also danach eine Sekunde warten.
- Mit so einem Bot wurden geprüft: Level 1 gewinnen, "Weiter", Level 2 bis zum Siegbildschirm; Lücken in den Level-Nummern; ein Minimal-Level ohne Hooks; das Gerüst aus der README; das Opp-System (ungesehen klauen, gesehen werden, Jagd, Beute verlieren, Balken, weglocken, speichern und laden, Wiederkehr in einem Testlevel 3).
- Karte prüfen: von der Startkachel aus alle begehbaren Kacheln fluten (`world.astar.is_point_solid`) und melden, welche freien Kacheln im Gebäude nicht erreicht werden und ob jedes Objekt mit `use` eine erreichbare Kachel in 1.25 Tiles Abstand hat. Das hat tote Ecken hinter Pulten und einen vom Hörsaal abgeschnittenen Bühnenbereich gefunden. Für die Optik: `main.zoom = 0.43` und HUD aus zeigt das ganze Hauptgebäude in einem Screenshot.
- PDF ohne Zusatzprogramme lesen: Windows kann Seiten selbst rendern (`Windows.Data.Pdf.PdfDocument` per PowerShell, `RenderToStreamAsync` schreibt PNG), danach das Bild ansehen und mit PIL zuschneiden.
- Kamerabewegung nur mit echtem Laufen messen (`Input.action_press`), ein Teleport ist selbst ein Sprung. Nahtprüfung fürs gemeinsame Bild: rechte Kante der linken Kamera gleich linke Kante der rechten.
- Fehler in Teleport-Tests sind oft Fehler des Tests: Abstände genau nachrechnen (eine Interaktion mit "kleiner als 1.1" greift bei genau 1.1 nicht), und Zähler gehen bei `reload_current_scene` verloren, weil die Testszene neu entsteht.
- Screenshots brauchen ein echtes Fenster (headless rendert nicht): ohne `--headless`, mit `--audio-driver Dummy --disable-vsync` und einer temporären `override.cfg` mit `display/window/size/no_focus=true`; speichern mit `get_viewport().get_texture().get_image().save_png(...)`.
- Temporäre Testdateien (`zz_*`, `override.cfg`, deren `.uid`) vor dem Commit wieder löschen.
- Der Bot beweist, dass der Ablauf funktioniert, nicht dass er Spass macht oder die Schwierigkeit stimmt.
