# VIScon Hackathon Game

2-Spieler-Koop-Schleichspiel an der ETH (lokal, eine Tastatur). Team aus 5 Leuten, Hackathon-Ende **So 11.10.2026 12:55**, Feature Freeze So 06:00 (siehe `docs/TEAM.md`).

## Wo der Code liegt (wichtig)

- **Das echte Spiel ist das Godot-Projekt in `godot/`** (Godot 4.3+, `project.godot` meldet Feature 4.7, GDScript, alles im Code gezeichnet, keine Asset-Dateien, Sounds werden in `sfx.gd` erzeugt).
- Seit dem 10.10.2026 liegt es auch auf `main`: Das Team führt die Branches dort per Pull Request zusammen. Daneben liegt auf `main` noch das ursprüngliche Phaser/TypeScript/Vite-Gerüst mit dem Platzhalter "ETH Exam Run" (`src/`, `package.json`). Das ist **nicht** das Spiel und wird nicht weiterentwickelt; der Pages-Workflow baut weiterhin nur diesen Platzhalter.
- Remote: `git@github.com:fzehnder/viscon-game.git`.
- Starten: Godot öffnen, `godot/project.godot` importieren, F5. Startszene ist `menu.tscn`. Direkt in ein Level: auf der Startseite «Leistungsüberblick · Level wählen» und dort ein Fach anklicken, oder `godot --path godot res://main.tscn -- --level=2`.

## Arbeitsweise (Wunsch des Teams, 10.10.2026)

- **Nicht nach jeder Änderung alles testen.** Getestet wird am Schluss oder wenn etwas nicht funktioniert. Nach einer Änderung reicht ein kurzer Startlauf, der Skriptfehler zeigt (siehe "Prüfen ohne Editor"); Bot-Durchläufe und Screenshots nur auf Wunsch, bei der Fehlersuche oder vor der Abgabe.
- Änderungen committen und pushen, wenn das Team es sagt ("push bitte"). Allgemeines kommt auf `level-base` und wird danach in die Level-Branches gemergt.
- "Merge und push" heisst: `level-base` in die eigenen Level-Branches mergen, diese nach `main` mergen und alles pushen. Branches von anderen Teammitgliedern (`tracking`, `level4-labor`) mergt, wer sie gebaut hat, oder das Team per Pull Request, nicht nebenbei.
- Vor der Arbeit `git fetch`: Die anderen pushen laufend, auch nach `main`.
- Diese Datei nach jeder grösseren Änderung nachführen, damit neue Sessions den Stand kennen.
- Wünsche zur Platzierung und zum Aussehen gelten so, wie das Team sie sagt. Bedenken kurz nennen und technisch absichern, nicht eigenmächtig anders platzieren.

## Branches: Levels gleichzeitig bauen

Jedes Level bekommt einen eigenen Branch. Kein Level-Branch hängt von einem anderen ab: alle zweigen vom gemeinsamen Stand `level-base` ab. Fertiges kommt per Pull Request nach `main`.

| Branch | Wer | Inhalt |
|---|---|---|
| `main` | alle | der zusammengeführte Stand: `level-base`, `level2-mensa`, `level3-polyball` und `level4-labor` (Stand 10.10.2026), dazu das alte Phaser-Gerüst |
| `level-base` | Leo | gemeinsamer Stand ohne Level-Ordner: Level 1, Level-Gerüst, Opp-System, HUD mit Minimap, fliessender Split Screen, Aufgabenwahl mit Pfeilen, Hauptgebäude nach echtem Grundriss. Hier zweigen neue Branches ab |
| `level2-mensa` | Leo | `level-base` (regelmässig hineingemergt) plus Ordner `godot/scripts/level2/` |
| `level4-labor` | Knuusper | `level-base` (hineingemergt) plus Ordner `godot/scripts/level4/` (Level 4 "Chemiepraktikum": Kamera-Pipettieren, Blubber-Alarm mit dem Mikrofon, Testat). Seit dem 10.10.2026 auf `main` |
| `tracking` | Deniz Acar | Kamera- und Mikrofon-Tracking für Minigames (siehe unten). Seit dem 10.10.2026 in `level-base` und damit auf `main` |
| `level3-polyball` | Deniz Acar | `level-base` plus Ordner `godot/scripts/level3/` (Level 3 "Polyball"). Seit dem 10.10.2026 auf `main` |
| `level5-ski` | Tim | Wahlfach Skifahren in `godot/scripts/level20/` (freiwillig, nicht in der Story, Start über den Leistungsüberblick), dazu Wahlfächer in `levels.gd`/`transcript.gd`, Leistungsüberblick im Spiel (`L`), Ladebildschirm und Startseite mit dem ETH-Hauptgebäude (`eth_front.gd`, `tools/make_splash.gd`) |
| `level19-freelancing` | Tim | Wahlfach Freelancing (D-MAVT) in `godot/scripts/level19/`: eine Bewerbung pro Spiel, Jobbörse (AMZ, ARIS, Swissloop Tunneling, MedTech-Startup), Bewerbungsgespräch als Video-Call, Antworten laut ins Mikrofon. Dazu Spracherkennung für alle: `scripts/speech.gd` und `tracker/speech.py` (Whisper offline, siehe `tracker/README.md`) |
| `level1-coop`, `godot-eth-tag-nacht` | Finn | alte Stände vor dem Level-Gerüst, nicht mehr weiterführen |

Auf `main` spielt das Spiel 1 → 2 → 3 → 4. Fehlt auf einem Branch eine Nummer, wird sie übersprungen.

Wahlfächer (`"block": "W"` in `DEF`, `LV.is_elective`) gehören nicht zur Reihenfolge: Sie stehen im Leistungsüberblick unter «Wahlfächer», werden nur von dort gestartet, sind nie das nächste Level und setzen in `Game.begin_level` nichts zurück. Sie bekommen hohe Nummern (Skifahren ist 20), damit die Story-Levels von 2 an frei bleiben. Der Leistungsüberblick geht auch im Spiel auf (`L` oder Button unten rechts, pausiert das Spiel). Was in einem Wahlfach pro Spiel gilt (zum Beispiel die eine Bewerbung im Freelancing), steht in `Game.electives` (`Game.elective(key)`, `Game.set_elective(key, value)`, im Spielstand, nur `Game.new_game()` löscht es).

Regeln:
- Neues Level: `git fetch`, dann `git switch -c level3-name origin/level-base`. Nie von einem anderen Level-Branch abzweigen.
- Einem Level gehört genau **ein Ordner** `godot/scripts/level<N>/` (Code, eigene README). Gemeinsame Dateien fasst ein Level-Branch nicht an. So gibt es beim Zusammenführen keine Konflikte, egal in welcher Reihenfolge.
- Braucht ein Level etwas Allgemeines (Hook in `main.gd`, Accessoire, Sound), dann als eigenen kleinen Commit, der früh nach `level-base` geht.
- Fertige Levels kommen per Pull Request nach `main`. Allgemeines (alles ausserhalb eines Level-Ordners) geht zuerst nach `level-base`; die Level-Branches holen es mit `git merge origin/level-base`.
- Der Stand eines Levels wird in dessen `README.md` nachgeführt, nicht in dieser Datei (sonst kollidieren die Branches hier).
- Vor der Arbeit an einem Level dessen `godot/scripts/level<N>/README.md` lesen.

## Level-Gerüst

- `scripts/levels.gd` findet Levels selbst: Es prüft `res://scripts/level<N>/level.gd` für N = 2 bis 20 (`LV.numbers()`), Level 1 steht direkt in `levels.gd` (`LEVEL1`). Nichts muss registriert werden. Fehlt eine Nummer (Branch mit Level 1 und 3), wird sie übersprungen: `LV.next_after(n)`.
- `LV.current` ist das laufende Level, gesetzt vom Autoload `Game` (`Game.set_level(n)`). `LV.level()` liefert die Beschreibung, `LV.tasks()` / `LV.task(id)` die Aufgaben.
- `level.gd` eines Levels: `extends Node2D`, `const DEF` (Felder wie `LEVEL1`: `name`, `tag`, `mode`, `time`, `start`, `intro`, `tasks`; optionale Texte `hint`, `start_toast`, `timer_title`, `win_title`, `win_text` mit zweimal `%s`, `lose_title`, `lose_text`), optional `static func build_map(md)`. Die Datei ist zugleich der Logik-Node, den `main.gd` als `main.logic` in die Welt hängt (`main` ist vor `_ready` gesetzt).
- Aufgaben mit `"type": "level"` gehören dem Level. Hooks, die `main.gd` aufruft, alle optional: `update_near(pid)` (setzt `main.nears[pid] = {"use": "level", "label", "rect", ...}`), `interact(pid, o)`, `goal_positions(id, n0, n1)`, `task_targets(id, pid)`, `on_noise(at, radius)`, `finale(done)`. Aufgabe erledigt: `main._task_done(pid, id)`.
- Aufgaben mit `"spots"` (wie in Level 1) werden ohne eigene Logik zu Stationen mit Minigame.
- Nach dem Sieg zeigt `main.gd` "Weiter zu Level N", solange es ein nächstes gibt.
- Leistungsüberblick (`scripts/transcript.gd`, Wunsch des Teams vom 10.10.2026: Level-Übersicht wie der Leistungsüberblick auf myStudies): Jedes Level ist ein Fach mit Nummer, Session, Note und Gewicht, einsortiert in «Basisprüfungsblock A/B»; die späteren Studienjahre stehen als leere Kategorien darunter (`LATER`). Ein Klick auf ein Fach startet das Level. Optionale Felder in `DEF`: `course` (Fachnummer, sonst `252-000N-00 L`), `ects` (Kreditpunkte und Gewicht, sonst 6), `block` (`"A"` oder `"B"`, sonst A für Level 1 und 2, B ab Level 3). Kein Level muss etwas eintragen. Die Note schreibt `main._win_day` über `Game.add_grade` (beste Note pro Level, in `user://save.cfg`); Kreditpunkte gibt es ab Note 4.
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
- Bag zurück (Wunsch des Teams): Sobald ein Opp seine Bag wieder hat (`bag_is_back()`), lohnt sich die Jagd für ihn nicht mehr: `TIRED_SPEED` 100 statt 152 (langsamer als ein gehender Spieler mit 135), Aufgeben nach `TIRED_CHASE` 3 s oder sobald er die Figur aus den Augen verliert, danach `TIRED_CALM` 7 s Ruhe. Nach erneutem Diebstahl wieder volles Tempo. Opps ohne Bag (Drängler aus Level 2, Wiederkehrer) jagen immer voll.
- Erwischt (`main.opp_catch`): mit dessen Bag = Beute weg, Aufgabe wieder offen, Fehler; sonst `main.caught(opp)` = Level verloren. Level können das mit `on_opp_catch` übersteuern.
- Klaubare Bag: `"bag"` am NPC, Interaktion `"use": "bag"` in `main.gd`, Aufgabentyp `"bag"`. `"bag_acc"` bestimmt, wie der Dieb sie trägt (`erstibag` auf dem Rücken oder `loot` in der Hand), `"bag_name"` den Namen in Texten. Gesehen = sofort Opp und Jagd, ungesehen = Timer `NOTICE` (6 bis 9 s), dann Suche in Richtung des Diebs.
- Bag rausbringen (Wunsch des Teams): Klauen allein erledigt die Aufgabe nicht mehr. Erst wenn der Dieb den Raum des Besitzers verlassen hat (`op.home_zone`, Zonenname am Platz des Besitzers; `main._check_escapes`), gilt sie. Vorher erwischt = Bag weg, nochmals von vorn. Solange jemand die Bag trägt, steht auf der Aufgabenkarte «raus!» (vierter Eintrag in `main.objectives()`), und die gestrichelten Pfeile führen zum nächsten Ausgang (`main._way_out`). Grund: Sonst endet das Level sofort beim Klauen, wenn die Bag die letzte Aufgabe ist.
- Speicher: `Game.opps` (`id -> {name, look, level, by, why}`), `ConfigFile` unter `user://save.cfg`. `Game.begin_level()` löscht beim (Neu-)Start eines Levels alle Opps, die in diesem oder einem späteren Level entstanden sind; `Game.new_game()` löscht alle. `--nosave` hält alles nur im Speicher (für Tests).
- Mitgenommenes: `Game.items` (`id -> Level`), `Game.add_item(id)` und `Game.has_item(id)` für Dinge, die die Figuren in spätere Levels mitnehmen (zum Beispiel `prof_badge` aus Level 3). Liegt in derselben Datei im Abschnitt `items` und folgt denselben Regeln wie die Opps: Beim (Neu-)Start eines Levels verschwindet, was in diesem oder einem späteren Level dazukam.
- Wiederkehr: `main._spawn_npcs` setzt Opps aus früheren Levels an die `opp_spots` des Levels (`"lauert"` oder `"jagd"`). Level 1 und 2 haben keine `opp_spots`; ab Level 3 muss das Level welche angeben.
- Level 1: Der "Rucksack" aus der Vorgabe **ist die Ersti-Bag**, es gibt dafür keine eigene Aufgabe. Deniz (`rucksack_a`) und Livia (`rucksack_b`) sitzen am Lesetisch in der Bibliothek, ihre Ersti-Bags stehen neben dem Stuhl; die Aufgabe "Ersti-Bag klauen" (jetzt Typ `"bag"`) wird dort erledigt. Die Ersti-Menge auf der Polyterrasse trägt keine Bags mehr (`"bags": 0`); der alte Weg (Bag einem Ersti aus der Menge per Timing-Minigame vom Rücken klauen, Typ `"steal"`) steckt noch in `main.gd` und `student.gd`, ist aber abgeschaltet.
- Level 2 (auf `level2-mensa`): siehe dessen README.

## Kamera- und Mikrofon-Tracking (gebaut; benutzt in Level 3 und in Level 4: Pipettieren mit der Kamera, Blubber-Alarm mit dem Mikrofon)

Vorgabe des Teams: Minigames mit Kamera-Erkennung (Pose nachstellen, in die Luft greifen, Pinch, nicht blinzeln, stillhalten, nicken oder Kopf schütteln) und Pusten ins Mikrofon. Die Minigames entstehen beim Bau der Levels, hier liegt nur das Fundament. Anleitung, Datenfelder und ein Rezept pro geplantem Minigame: `tracker/README.md`.

- `tracker/tracker.py` (Repo-Wurzel): zweiter Prozess in Python mit MediaPipe 1.1.0, erkennt Gesichter, Hände und Körperhaltung und schickt sie per UDP ans Spiel (nur localhost, Ports 47800 und 47801). Das Spiel startet ihn selbst über `uv` und beendet ihn wieder. Erster Start braucht Internet (Pakete und Modelle), deshalb auf jedem Rechner einmal `uv run tracker/tracker.py --selftest`.
- Welche Kamera: Auf dem Mac nimmt der Tracker von selbst die eingebaute, nicht ein iPhone in der Nähe (OpenCV zählt die Kameras nach ihrer Kennung, das iPhone kann dabei Nummer 0 sein). `uv run tracker/tracker.py --list-cameras` zeigt die Wahl, `VISCON_CAMERA` (Nummer oder Teil des Namens) ändert sie, `Track.camera` nennt sie im Spiel.
- Autoload `Track` (`scripts/tracking.gd`): `Track.use(self, ["face"])` (auch `"hand"`, `"pose"`) gilt, solange der Node im Baum ist. `Track.face(pid)`, `Track.hand(pid)`, `Track.pose(pid)` liefern, was in der Bildhälfte der Person ist (P1 sitzt links, P2 rechts), sonst `{}`. `Track.preview` ist das Kamerabild. `Track.use_mic(self)`, danach `Track.blow` (0 bis 1) und `Track.blowing`. Vor dem ersten `use` läuft nichts und kostet nichts.
- `scripts/track_math.gd`: fertige Auswertungen (`eyes_closed`, `looking_away`, `moved_cm`, `pinch01`, `is_fist`, `pose_match`, Klassen `NodShake` und `Jitter`). Schwellen als Konstanten oben in der Datei.
- Mehrere Leute im Bild: Der Tracker meldet bis zu vier Personen, Gesichter und Hände, in keiner festen Reihenfolge und nicht in jedem Bild dieselben. `Track.face(pid)` und `Track.pose(pid)` nehmen deshalb nur die beiden grössten (die vordersten). Wer sonst mitspielt, entscheidet das Minigame: `TM.front(liste, n)` (die n grössten, also die vordersten), `TM.mine(liste, pid)`, `TM.pair(liste)`. Rohdaten nie direkt anzeigen: glätten, kurze Aussetzer überbrücken, Personen von Bild zu Bild verfolgen. Fertiges Vorbild: Klasse `Followed` und `_follow_bodies` in `godot/scripts/level3/kamera_spiel.gd`.
- Deckt ein Kamera-Minigame den Bildschirm (oder eine Hälfte) deckend ab, die Karte dahinter solange nicht zeichnen lassen, sonst stottert das Kamerabild im Takt der Karte (siehe «Offen», Bildrate). Vorbild: `_cover` in `godot/scripts/level3/level.gd`.
- **Jedes Kamera-Minigame braucht eine Tasten-Variante:** Ohne Kamera oder Tracker bleibt `Track.alive` auf `false`.
- Pipettieren zu zweit in Level 4 (`scripts/level4/pipette_game.gd`): Eine Person drückt Daumen und Zeigefinger genau richtig zusammen (`TM.pinch01`, Balken von Rot über Grün nach Rot), die andere hält die Hand waagrecht und ruhig (Neigung aus den Handpunkten 0 und 9, Zittern über `TM.Jitter`). Welche Hand wem gehört, sagt `TM.pair(Track.hands)`. Nach der ersten Runde vor der echten Kamera («buggy») umgebaut, so wie es oben unter «Mehrere Leute im Bild» steht: Werte über `SMOOTH` geglättet, Aussetzer `HOLD` lang überbrückt, Zittern zählt erst nach `SHAKE_TIME`, und Pipette und Glas stehen **fest** am Bildrand statt an den erkannten Händen zu hängen; die Pipette hat die Farbe davon, wie gut der Druck stimmt. Das Kamerabild wird in seiner eigenen Form gezeichnet (`Track.aspect`), nicht auf 4:3 gezogen. Die Karte dahinter hält `_freeze_views` in `level4/level.gd` an (einfachere Fassung von `_cover` aus Level 3, für Spiele über den ganzen Bildschirm). Tasten-Variante nach 6 s ohne Bild oder sofort, wenn `Track.status` mit «kein» beginnt; kommt das Bild später doch, wechselt das Spiel von selbst zur Kamera zurück, ausser jemand hat die Tasten mit `K` gewählt. Das Level ruft `Track.use(self, ["hand"], false)` schon in `_ready`, damit die Kamera bereit ist, wenn die Figuren am Tisch ankommen, und gibt sie danach mit `Track.release(self)` zurück.
- Blubber-Alarm in Level 4 (`scripts/level4/blow_game.gd`), das erste Minigame mit dem Mikrofon: `Track.use_mic(self)`, dann kühlt `Track.blow` das überkochende Fondue; schwächer als `BLOW_MIN` zählt nicht. Liefert das Mikrofon nach `MIC_WAIT` Sekunden nichts (`Track.mic_ok` bleibt `false`), gilt die Tasten-Variante: Beide hämmern gleichzeitig auf ihre Taste. Die Tasten gehen immer, auch mit Mikrofon, als Absicherung, falls das Pusten schlecht erkannt wird. Per Bot prüfen: `Track.set_process(false)`, dann `Track.mic_ok = true` und `Track.blow` von Hand setzen. Headless und mit `--audio-driver Dummy` liefert das Mikrofon nichts, das Spiel landet dann von selbst bei den Tasten, und macOS fragt nicht nach der Freigabe.
- Falle beim Einrichten (macOS): Nimmt `uv` das Python von python.org, scheitert der erste Download der Modelle an `CERTIFICATE_VERIFY_FAILED`. `tracker/models/` bleibt dann leer, und das Spiel zeigt nur die Tasten-Variante. Abhilfe: `SSL_CERT_FILE=/etc/ssl/cert.pem uv run tracker/tracker.py --selftest`.
- Die Kamera-Freigabe hängt am Programm, das startet. Aus der Claude-App heraus (und aus manchen Terminals) verweigert macOS die Kamera («not authorized to capture video»), auch wenn Tracker und Modelle in Ordnung sind: Der Selbsttest meldet dann `camera FAILED`. Die echte Kamera muss deshalb ein Mensch prüfen, der Godot selbst startet; nicht versuchen, das zu umgehen.
- Testszene: `godot --path godot res://track_debug.tscn`. Ohne Kamera testen: den Tracker vorher von Hand mit `--fake bild.jpg` starten, das Spiel benutzt dann diesen.
- `Track` rechnet seine Wartezeiten in Echtzeit, nicht in Spielzeit. In Bot-Läufen mit `--fixed-fps` startet der Tracker deshalb meist gar nicht; Kamera-Minigames dort über die Tasten-Variante prüfen.
- Kamera-Minigames ohne Kamera und ohne Hände prüfen, zwei Wege: (a) Die Kette Spiel und Tracker mit `--fake` und irgendeinem Bild, auch einem grauen: `Track.alive` wird wahr, die Vorschau kommt an, Hände gibt es keine. Dazu das Spiel **ohne** `--fixed-fps` laufen lassen und den Tracker danach wieder beenden. (b) Die Auswertung mit künstlichen Händen im Bot, auch mit `--fixed-fps`: jeden Frame `Track._last_data = 1.0e12` setzen (hält `Track.alive` auf wahr) und `Track.hands` mit Einträgen im Format des Trackers füllen (`x`, `y`, `palm`, `pinch`, `open`, `side` und 21 `pts`; `x` unter 0.5 gehört P1).
- Kamera-Minigames per Bot prüfen, ohne Kamera: nach jedem `Track.use` im Test `Track.set_process(false)` aufrufen (dann startet kein Tracker, und `Track` überschreibt nichts), danach `Track.alive = true` und `Track.poses` / `Track.hands` / `Track.faces` selbst setzen. So sind die drei Kamera-Aufgaben von Level 3 geprüft (`godot/scripts/level3/`, Vorbild für weitere: `kamera_spiel.gd` und `_open_cam` in `level.gd`).
- Offen: Die Schwellen sind Startwerte und noch nicht im Spieltest eingestellt, auch die des Pipettierens (`PINCH_TARGET`, `LEVEL_TOL`, `SHAKE_LIMIT` in `pipette_game.gd`). Pusten ist nur mit Raumgeräusch geprüft. Vorzeichen von `pitch` und die Angabe linke/rechte Hand sind nicht von einem Menschen bestätigt. Mit echter Kamera gelaufen sind bisher Badge und Tanzen (eine Person) aus Level 3 und das Pipettieren aus Level 4 (vom Erbauer ausprobiert, nach dem Umbau «sieht super aus», danach noch leicht verschärft). Mit einem echten Mikrofon ist noch kein Minigame gelaufen, auch der Blubber-Alarm nicht.

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
- Koop-Steuerung (`controls.gd`, physische Tastenpositionen): P1 WASD / E / Shift Sprint / C Schleichen / Esc / 1 2 3; P2 Pfeile / Enter / `.` Sprint / `-` Schleichen / Backspace / 8 9 0 Schleichen lag bis zum 10.10.2026 auf Ctrl: Ctrl + Pfeiltasten der anderen Person ist ein System-Kürzel (macOS wechselt den Schreibtisch). Deshalb keine Modifier-Taste (Ctrl, Alt, Cmd) als Halte-Taste vergeben. Tastennamen für Texte stehen in `KEYS.LABELS` (`sneak`, `sprint`, `select`), nicht fest in die Texte schreiben
- Dynamischer Zoom und Split Screen (`main.gd`): Das gemeinsame Bild zoomt beim Auseinanderlaufen bis 2.2x heraus (`OUT_MAX`), Grundzoom 2.5 / 1.3 (etwa 1.92), danach teilt es sich und zoomt langsam zurück (`ZOOM_BACK`); zusammen wieder unter `MERGE_OUT`. Die Trennlinie steht immer senkrecht zur Linie zwischen den Figuren (jede Figur auf ihrer echten Seite) und dreht mit. Bei einem Minigame für eine Person stellt sie sich in `SPLIT_TIME` (1.2 s) senkrecht, und jede Person behält ihre Seite (`force_flip`); das Minigame öffnet auf `main.minigame_side(pid)`. Level-Code, der `screen_side` selbst setzt, bestimmt damit die Seite. HUD bleibt fest. Nicht gespielt, nur geschrieben (10.10.2026, Finn)
- HUD: Aufgaben pro Person auf ihrer Seite (P1 links, P2 rechts), Level und Zeit oben Mitte, Minimap unten Mitte
- Karte: Hauptgebäude nach dem echten Grundriss des E-Geschosses (siehe "Karte")
- Aufgabe wählen (Tab für P1, Komma für P2, oder Klick auf die Aufgabe): ein Band mit fliessenden Winkeln in der Farbe der Person zeigt den kürzesten Weg zum nächsten Ort, an dem die Aufgabe lösbar ist, auch auf der Minimap. `main.picked` / `main.routes`, Ziele aus `main.task_targets(id, pid)` (Stationen, Bags, bei Koop-Aufgaben die andere Person, bei Level-Aufgaben der Hook `task_targets` oder ersatzweise `goal_positions`), gezeichnet in `fx.gd` (`_draw_route`). Nur auf Skriptfehler und einen kurzen Lauf geprüft, nicht gespielt Der Weg wird geglättet (`world.smooth_path`: gerade, wo die Gerade im A*-Raster frei ist, Ecken gerundet, alle 8 px ein Punkt), alle 0.2 s neu gesucht und dazwischen nur an den Füssen gekürzt; gezeichnet wird vom Ziel her gemessen (`fx._draw_route`), damit das Muster am Boden stehen bleibt, während man läuft.
- Schleichen / Gehen / Sprinten, Stamina (2 s Sprint, ca. 3 s Regeneration), Geräuschkreise pro Schritt (`player.gd`, `fx.gd`)
- Story-Intro im Menü: Startseite, Hack der Bewerbungsseite, Namen (Nachname optional, nur für die Legi), Legi-Foto von P1, dann P2, Charakter-Editor mit Studiengang, am Schluss beide Legis nebeneinander im Layout der echten ETH-Legi (`legi_card.gd`, Daten aus `Game`: `legi_ids`, `birthdays`, `surnames`, `programme_of`); Level-Auswahl als «Leistungsüberblick» im Aussehen von myStudies (ersetzt die Zeile «Direkt zu»), mit den besten Noten pro Level. START beginnt ein neues Studium und löscht Opps und Noten. Nur per Startlauf und einem Screenshot geprüft, nicht gespielt
- Level 1 "Ersti-Tag" (Tag, 7 min): Ersti-Bag klauen (bei Deniz und Livia am Lesetisch, macht sie zu Opps), Legi validieren, Moodle & Code Expert einrichten, Koop-High-Five, Note 1 bis 6
- Minigames (`minigame.gd`): Timing, Kabel, Sequenz, Quiz, Moodle, Setup, High Five
- Karte ETH Zentrum mit Tag/Nacht, Kollision, A*-Wegfindung, HUD, Popups
- Level-Gerüst, Cutscene-Abspieler, Übergang zum nächsten Level
- Opp-System samt Ersti-Bag-Diebstahl in Level 1 (siehe oben). Per Bot geprüft, von Menschen noch nicht gespielt

Auf `level2-mensa`: Level 2 "Mensa-Stau" komplett spielbar (Schlange als Stau, Kassiererin, Menü, Tische, Basisprüfungs-Cutscene, Opps durch Vordrängeln). Details, Stellschrauben und Offenes in `godot/scripts/level2/README.md`.

Auf `level3-polyball`: Level 3 "Polyball" im Hauptgebäude (Verkleidung als Faktor auf das Opp-System, Frack, Armband zu zweit, Prof-Badge im Spielstand, Buffet, wiederkehrende Opps über `opp_spots`). Drei Aufgaben lassen sich vor der Kamera spielen: Tanzfläche (Körperhaltung), Badge (Hand), Buffet (Mund auf), jede auch mit Tasten. Details, Stellschrauben und Offenes in `godot/scripts/level3/README.md`.

Auf `level4-labor`: Level 4 "Chemiepraktikum" (Tag, 6 min) im Labor im Südflügel, per `build_map` zum Chemielabor umgebaut, mit Prof. Dr. Siedler und fünf Studierenden. Drei Aufgaben in fester Reihenfolge (`phase`): (1) Kamera-Pipettieren zu zweit. (2) Blubber-Alarm: Das Fondue des Professors kocht in Kapelle 1 über, beide pusten es über das Mikrofon kühl oder fächeln mit den Tasten. Zu wenig gepustet gibt eine Stichflamme, beide Figuren brennen und müssen unter die Notdusche, bevor sie es nochmals versuchen; wer 20 s brennt, ohne zu duschen, löst den Wutanfall aus. (3) Testat in zwei Serien mit Fragen, die alle beantworten können (eigenes Quiz `chem_quiz.gd`, ein Fehler erlaubt). Wer trotzdem durchfällt, löst einen Wutanfall des Professors aus (Vollbild-Szene `prof_rage.gd`), und das Level beginnt für beide neu. Keine `opp_spots`. Laborplätze, Pulte, Kapelle und Notdusche lassen sich von jeder Seite benutzen (`REACH`). Per Bot geprüft, jeweils zu Fuss mit echten Tastendrücken von der Tür an: Pipettieren (künstliche Handdaten und Tasten), Alarm mit künstlichem Pusten und mit Fächeln, Stichflamme, Notdusche, zweiter Versuch, zu lange brennen, Testat bis Sieg und bis Wutanfall. Details, Stellschrauben und Offenes in `godot/scripts/level4/README.md`.

Geprüft (per Bot, nach dem Kartenumbau): Level 1 mit Ersti-Bags und Opps bis zum Sieg, Kamera und HUD, Level 2 von der Schlange bis zum Siegbildschirm, Erreichbarkeit aller Räume bei Tag und Nacht. Von Menschen ist noch nichts davon gespielt worden: Schwierigkeit, Zeiten und das Gefühl des Split-Screen-Übergangs sind offen. Die Nacht ist nach dem Kartenumbau nur auf Erreichbarkeit geprüft, nicht gespielt.

Altes Prototyp-Verhalten (Nacht), noch nicht nach Plan:
- Professoren als Guards (`professor.gd`): Patrouille, sichtbarer Kegel, hören Geräuschkreise. Volle Anzeige oder Berührung ruft `main.caught()` auf und **beendet das Level sofort für beide**
- Nacht-Mission und Q-Fähigkeit hängen am alten Departement-System (`characters.gd`, `Game.dept` fest auf D-INFK)

Offen:
- Nacht laut Plan: Guard-Sprint bei Alarm, Rauswurf statt Game Over, Teammate holt den Spieler zurück, verloren erst wenn beide draussen sind
- Opps: Kein Level hat bisher `opp_spots`, die Wiederkehr ist nur mit einem Testlevel geprüft. Offen ist auch, ob "erwischt ohne Beute = Level verloren" am Tag zu hart ist
- Level 3: Die Zielposen der Tanzfläche sind Platzhalter. Vor der echten Kamera sind Badge und Tanzen (eine Person) gespielt, Tanzen zu zweit oder in einer Gruppe und das Buffet mit dem Mund noch nicht; die Schwellen sind geschätzt (siehe `godot/scripts/level3/README.md`)
- **Bildrate:** Die Karte (`scripts/world.gd`) ist ein einziges Bild aus rund 63 000 Zeichenbefehlen, und Godot zeichnet es jedes Bild für beide Ansichten ganz, auch was nicht zu sehen ist. Gemessen am 10.10.2026 auf einem MacBook Pro (120 Hz, Fenster 1280 × 720): Level 1 mit 31, Level 3 mit 37 Bildern pro Sekunde, ohne Karte 170 bis 185; die Scripts brauchen 0.3 ms pro Bild. Auf schwächeren Laptops dürfte es weniger sein. Abhilfe wäre, die Karte in Stücke aufzuteilen (eigene Nodes pro Kartenausschnitt, dann zeichnet Godot nur, was im Bild ist). Mit dem drehenden Split-Screen (zwei Ansichten über den ganzen Bildschirm) ist es gleich: 36 in Level 3. Noch nicht gemacht, weil es `world.gd` für alle Levels umbaut
- Level 4: Der Blubber-Alarm ist noch nie mit einem echten Mikrofon gelaufen (`Track.blow` war im Bot von Hand gesetzt). Das Pipettieren ist vor der echten Kamera ausprobiert, die zuletzt leicht verschärften Schwellen aber nicht mehr. Notdusche, Stichflamme und Testat sind nur per Bot und auf Screenshots geprüft; das Level ist noch nie von zwei Menschen am Stück durchgespielt worden
- Level 3 ist gegen den drehenden Split-Screen mit Startlauf und Bot geprüft (Tanzen allein und zu zweit, Badge, Buffet, Abschalten der verdeckten Ansichten), von Menschen nicht neu durchgespielt
- Die Möblierung der neuen Büros und Hörsäle ist schlicht (Pult, Stuhl, Bankreihen); die Hörsäle sind rechteckig mit Bühnennische statt fächerförmig, die Höfe neben den Hörsälen fehlen
- Der Pages-Deploy-Workflow auf `main` baut weiterhin nur den Phaser-Platzhalter, das Godot-Spiel wird nirgends automatisch gebaut oder veröffentlicht

## Code-Orientierung (`godot/scripts/`)

| Datei | Inhalt |
|---|---|
| `game_state.gd` | Autoload `Game`: Level, Modus, Namen, Fotos, Looks der beiden Spieler, Liste der Opps, Noten pro Level und Spielstand (`user://save.cfg`) |
| `levels.gd` | findet die Levels, enthält Level 1 (Positionen in Tiles, 1 Tile = 32 px) |
| `level<N>/` | je ein weiteres Level: `level.gd`, eigene Figuren, `README.md` |
| `cutscene.gd` | Cutscene-Abspieler |
| `skin_menu.gd` | Figuren gestalten im Intro (Stufe `custom` in `menu.gd`): zwei Karten, beide wählen gleichzeitig mit ihren Tasten (P1 W/S Zeile, A/D ändern, Q Zufall, E bereit; P2 Pfeile, `-` Zufall, Enter bereit), Maus geht auch. Was wählbar ist, steht in `characters.gd` (`PLAYER_TOPS`, `EXTRAS`, `SHOE_COLORS`, die Farblisten). Auf der Startseite gibt es dazu «Figuren ändern» |
| `loading_screen.gd`, `loading.tscn` | Ladebildschirm vor jedem Level: Die Polybahn fährt vom Central zur Polyterrasse und ist der Ladebalken, dazu Level-Nummer, Name, Zeitvorgabe, ein gezeichnetes Motiv pro Level (`_motif`, nach Level-Nummer) und ein Tipp. Aus dem Menü (Stufe `loading`), zwischen zwei Levels (`main._next_level`) und beim Start aus dem Leistungsüberblick. Ein Level kann in seiner `DEF` `"tips": [...]` (eigene Tipps) und `"sky": "abend"` (Dämmerung) angeben |
| `level_done.gd` | Szene am Ende jedes gewonnenen Levels, vor dem Sieg-Dialog (`main._win_day`): Blatt «Leistungsnachweis», Note zählt hoch, Stempel. Eine eigene Schlussszene eines Levels (`finale`) kommt davor |
| `main.gd` | Spielablauf, Split Screen, Interaktion, Aufgaben, Sieg/Niederlage, Level-Hooks |
| `player.gd`, `student.gd`, `professor.gd` | Spieler, Studierende/Erstis, Guards |
| `opp.gd` | Leute, die zu Opps werden (Zustände, Kegel, Verdachtsbalken, klaubare Bag) |
| `minigame.gd` | alle Minigames |
| `map_data.gd`, `world.gd` | Kartendaten (Hauptgebäude in `_hauptgebaeude`), Zeichnen, Kollision, Wegfindung, Sichtlinien |
| `menu.gd`, `legi_card.gd` | Story-Intro, Charakter-Erstellung |
| `transcript.gd` | Level-Auswahl als Leistungsüberblick (myStudies-Look): Tabelle von Hand gezeichnet, Systemschrift Arial |
| `hud.gd`, `ui.gd`, `fx.gd`, `sfx.gd` | Anzeigen (Aufgabenkarten, Zeit, Minimap, Stempel «ERLEDIGT» bei einer erledigten Aufgabe: `hud.celebrate`), Popup-Stil, Effekte (auch der Weg zur Aufgabe), Sounds |
| `tracking.gd`, `track_math.gd` | Autoload `Track`: Webcam (Gesicht, Hand, Körper) und Pusten ins Mikrofon für Minigames; Auswertungen dazu. Anleitung und Rezepte in `tracker/README.md`, Testszene `track_debug.tscn` |
| `characters.gd`, `character_art.gd` | Looks, Quiz-/Moodle-Inhalte, Figuren-Zeichnung. Der dunkle Umriss ist eine eigene kleine Funktion (`_outline`): die Hauptformen der Figur noch einmal, dunkel und etwas grösser, vor der Figur gezeichnet. Wer eine Form ändert oder ergänzt, die übersteht (Frisur, grosses Accessoire), führt `_outline` nach. Figuren werden jedes Bild neu gezeichnet, eine ganze Menge davon, deshalb zählt dort jeder Aufruf: Ein `draw_circle` kostet 64 Dreiecke, also in Weltgrösse (`_fine` falsch) Kästchen oder `_oval` / `_cap` (Einheitsform, verschoben und gestreckt) nehmen. Ein zweiter Durchgang über alle Teile für den Umriss hat Level 1 von 30 auf 14 Bilder pro Sekunde gedrückt; so wie jetzt sind es wieder 30. Kopfmitte (y = -35), Augenkasten und Mundlage nicht verschieben: `level4/prof_rage.gd` und andere zeichnen darüber |

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
- **Look (seit 10.10.2026):** cremeweisses Papier mit dunkler Schrift, ETH-Blau als Akzent statt Gelb, keine dunkelvioletten Panels mehr. Farben in `ui.gd`: `UI.PAPER`, `UI.PAPER2`, `UI.INK`, `UI.INK2`, `UI.LINE`, `UI.ETH_BLUE`, `UI.OK`, `UI.WARN`. `UI.panel()` ist ohne Argumente schon Papier mit blauem Rand, `UI.label()` ohne Farbe ist dunkle Schrift; `outline` wirkt nur bei heller Schrift (Text direkt auf der Spielwelt). Halbseitige Minigames dunkeln nicht mehr ab, nur bildschirmfüllende. Der Hacker-Teil im Menü bleibt bewusst dunkel. Levels, die selbst `UI.NAVY` übergeben, behalten ihre dunklen Panels, bis sie umgestellt werden.
- **Kamera und Split Screen:** Es gibt immer zwei Viewports über den ganzen Bildschirm; der von P2 liegt oben und wird per Shader an der Trennlinie abgeschnitten (`SPLIT_SHADER`, Normale `split_n` zeigt von P1 zu P2). Sind die Figuren zusammen, stehen beide Kameras auf der Mitte, die Bilder sind gleich und der Schnitt unsichtbar. Passen sie auch bei `OUT_MAX` nicht mehr ins Bild, rückt jede Kamera um den Überschuss zu ihrer Figur (Voronoi-Split, `split_k` = wie sichtbar die Teilung ist, `split` ist der Zustand). Der effektive Zoom ist `main.zoom / main.out`. Deshalb: Kamerapositionen setzt ausschliesslich `main._update_cameras`, Zoom nur über `main.zoom` (auch in Tweens: `tween_property(main, "zoom", 3.5, 0.9)`), nie an einer einzelnen Kamera, sonst passen die Hälften nicht mehr zusammen. Die eingebaute Kameraglättung ist aus, geglättet wird in `_update_cameras` (`CAM_FOLLOW`).
- **HUD-Plätze** (so vom Team gewünscht): oben links und rechts die Aufgabenkarten, oben Mitte Level und Zeit, unten Mitte die Minimap, unten links die Nacht-Fähigkeit, Eingabehinweise unten bei 25 % und 75 % der Breite, Popups (`hud.toast(Titel, Text, Dauer, pid)`) erscheinen direkt unter der Aufgabenkarte der Person, die sie ausgelöst hat, gleich breit; ohne `pid` bei `main.last_actor` (wer zuletzt interagiert oder ein Minigame geöffnet hat). Damit im gemeinsamen Bild niemand hinter Zeit-Karte oder Minimap gerät, bleiben die Figuren vertikal näher an der Mitte (`FIT_Y` 0.42 statt `FIT_X` 0.5). Wer eine dieser Anzeigen grösser macht, muss `FIT_Y` nachrechnen: Füsse der oberen Figur bei `360 - FIT_Y * 360` px, eine Figur ist bei Zoom 2.5 etwa 115 px hoch.
- **Minimap:** Klasse `MiniMap` in `hud.gd`, Kacheln einmal als Textur, Markierungen aus `main.goal_positions()`. Was ein Level dort zeigen will, liefert es über `goal_positions`.
- **Aufgabe wieder öffnen:** `main.done[pid].erase(id)`; das HUD zieht den Chip von selbst zurück.
- **Eigenes Minigame eines Levels** (wenn `minigame.gd` nicht passt, zum Beispiel eigene Fragen oder die Kamera): ein `CanvasLayer` mit `layer = 20` im Level-Ordner, der sich so anmeldet, wie es `main.open_minigame` tut: `main.minis[pid] = node`, `main.nears[pid] = null`, `main.players[pid].enabled = false`, `main.add_child(node)`; am Ende `main.minis[pid] = null` und `enabled = true`. Für eine Person auf ihrer Bildhälfte (`screen_side` und `_place_half` wie in `minigame.gd`), für beide dasselbe Objekt an beiden Plätzen von `main.minis`, dann bleibt das Bild ungeteilt. `main._close_minis` räumt solche Nodes mit auf. Beispiele: `level4/chem_quiz.gd` (eine Person) und `level4/pipette_game.gd` (beide).
- **Über den Figuren zeichnen und Figuren einfärben, ohne `player.gd` anzufassen:** ein kleiner `Node2D` im Level mit `z_as_relative = false` und `z_index = 4` (über `main.actors`, unter den Namensschildern von `fx.gd` auf 5) zeichnet an `main.players[pid].global_position`; `main.players[pid].modulate` färbt die Figur. So brennen und tropfen die Figuren in Level 4 (`_paint_top`, `_flare`).
- **Koop-Aufgabe aus einem Level:** `main._coop_done(id)` erledigt eine Aufgabe für beide und feiert in Gelb, auch bei Aufgaben vom Typ `"level"`.
- **Ein Level von sich aus verlieren lassen:** `main.state = "cutscene"` (die Uhr steht), eigene Szene abspielen, dann `main.state = "lost"` und `main.hud.show_overlay(Titel, Text, Hinweis, "Nochmals versuchen", true, "lose", "LEVEL %d" % Game.level)`. R, M und der Button laufen danach über `main.gd`. Was den Neustart überleben soll (zum Beispiel ein Zähler der Versuche), kommt in eine `static var` des Level-Skripts: `levels.gd` behält die Skripte im Speicher.
- **Spielstand:** Alles, was `Game.save_game()` schreibt, landet im echten `user://`-Ordner des Rechners. Tests mit `--nosave` starten oder `Game.save_path` auf eine Testdatei umbiegen und diese am Ende löschen.

GDScript-Fallen, in die ich getreten bin oder die ich umgangen habe:
- `levels.gd` darf den Autoload `Game` nicht benutzen (`game_state.gd` lädt `levels.gd` per `preload`, das wäre ein Zirkel). Deshalb die statische Variable `LV.current`.
- Level-Skripte werden mit `load()` geholt, nicht mit `preload`. Auf dem geladenen Skript funktionieren `sc.DEF`, `sc.new()` und statische Funktionen (`sc.build_map(md)`); ob eine statische Funktion existiert, prüft `sc.get_script_method_list()`.
- Lambdas an `get_tree().create_timer(...)`, die einen Node einfangen, werfen "Lambda capture was freed", wenn der Node vorher gelöscht wird. Stattdessen `node.create_tween()` mit `tween_interval` und `tween_callback`: Der Tween stirbt mit dem Node.
- Text, der sich selbst tippt: `label.visible_characters` hochzählen, nicht `text` ändern, sonst springt das Layout.
- Konstanten mit Funktionsaufruf (`const X := deg_to_rad(...)`) vermeiden, Zahl direkt hinschreiben.
- In einer Schleife über `members.size()` die Liste nicht verändern; Abgänge merken und nach der Schleife entfernen.
- Der Standard-Font kann «•», «·» und Guillemets, aber keine Emojis oder Pfeil-Symbole: Symbole zeichnen statt schreiben.
- `preload` mit relativem Pfad (`preload("lab_person.gd")`) funktioniert innerhalb eines Level-Ordners. So lässt sich ein Level umnummerieren, ohne Pfade anzufassen.

Damit ein Level zum Rest passt:
- Farben und Bausteine aus `ui.gd`: Panels `UI.panel(UI.NAVY, Rahmenfarbe)`, Texte `UI.label`, Buttons `UI.button`, Einblenden `UI.pop_in`, Wackeln `UI.shake`, Konfetti `UI.confetti`. P1 ist Pink, P2 Blau (`KEYS.TAG_COLORS`), Gelb heisst "beide".
- Blasen über Köpfen: dunkler Kreis, Radius 10, bei y -58. Gelbes «!» = passt auf (wie die Erstis), Grün = Chance. Sichtkegel wie bei den Professoren: `Color(1.0, 0.93, 0.6, 0.2)`, bei Alarm Richtung Rot.
- Hinweise als `main.hud.toast(Titel, Text, Dauer)`, Erklär-Toasts nur einmal zeigen. Erledigtes feiert `main._task_done` selbst. Fehler: `main.mistakes_total += 1`, roter Geräuschkreis `main.fx.sound(...)`, `UI.sfx("fail")`.
- Ziele als Rauten über `goal_positions` in der Farbe derer, die sie noch brauchen (`main._need_color`).
- Neue Sounds als Notenliste in `sfx.gd`, neue Accessoires in `character_art.gd` (dort auf die Kosten achten und den Umriss nachführen, siehe Dateitabelle).

Leveldesign:
- Das Zeitfenster, um das sich ein Level dreht, sichtbar machen (ablaufender Ring, Markierung am Boden), sonst wirkt Erwischtwerden willkürlich.
- Den "ehrlichen" Weg nachrechnen: In Level 2 muss Anstehen länger dauern als das Zeitlimit, sonst drängelt niemand.
- Lösbarkeit garantieren statt hoffen (Gäste lassen immer zwei Plätze an einem Tisch frei; ein lauernder Opp lässt sich durch Lärm von seiner Bag weglocken).
- Wer direkt neben einem NPC etwas tut und gesehen wird, wäre ohne Schrecksekunde sofort gefangen. Verfolger brauchen eine kurze Verzögerung, sonst gibt es keine Flucht.
- Alle Stellschrauben als Konstanten oben in `level.gd` und in der Level-README erklären; das Team stellt sie im Spieltest ein.
- Scheitern muss nicht Neustart heissen. In Level 4 führte ein übergekochtes Fondue zuerst direkt zum Wutanfall; gewünscht war eine Folge im Spiel: Die Figuren brennen, müssen unter die Notdusche und dürfen es nochmals versuchen (kostet Zeit und einen Fehler). Der Neustart bleibt für das, was das Team dafür vorgesehen hat.
- Jeden Ort von jeder Seite benutzbar machen, von der eine Figur ankommen kann: Abstand zum Rechteck des Möbels messen (wie `main._update_near` es tut), nicht zu einem einzelnen Standpunkt. In Level 4 lag der Standpunkt hinter dem Labortisch; vom Gang her, aus dem alle kommen, erschien kein Hinweis.

Zusammenarbeit:
- Begriffe aus einer Vorgabe erst gegen das abgleichen, was es im Spiel schon gibt, bevor etwas Neues daneben entsteht. Der "Rucksack" in der Opp-Vorgabe war die vorhandene Ersti-Bag; ich hatte zuerst eine zweite Aufgabe gebaut.
- Die Zeit-Karte hatte ich aus Sorge um verdeckte Figuren nach unten gelegt; das Team wollte sie oben und die Minimap unten in der Mitte. Richtig war: so platzieren wie gewünscht und das Verdecken über `SPLIT_AT_Y` lösen (heute `FIT_Y`).
- Ausführliches Testen nach jedem Schritt kostet dem Team zu viel Zeit (siehe "Arbeitsweise").
- `level-base` ändert sich laufend: Während Level 4 entstand, wurde das Hauptgebäude umgebaut und das Labor lag danach woanders. Vor dem Zusammenführen `git fetch`, `level-base` hineinmergen und alle Positionen des Levels gegen die Tabelle unter "Karte" prüfen.

Rechner und Werkzeuge:
- Liegt das Repo in einem Ordner, den macOS mit iCloud abgleicht («Schreibtisch & Dokumente»), entstehen bei Git-Operationen Kopien wie `CLAUDE 2.md`, `project 2.godot` oder ein leerer Ordner `level4 2`. Das sind alte Fassungen (mit `git log --all --find-object=$(git hash-object "DATEI")` nachprüfbar), sie gehören nicht ins Repo. Am besten liegt das Repo ausserhalb von iCloud; sonst hält ein Muster wie `* [2-9].*` in `.git/info/exclude` sie aus `git status` heraus.

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
- **Teleport-Tests übersehen, was Menschen als Erstes tun.** Level 4 war per Bot durchgespielt und auf `main`, liess sich aber nicht spielen: Der Bot stellte die Figuren genau auf den Standpunkt und rief `main._interact(pid)` auf, ein Mensch kommt von der Tür und steht auf der anderen Seite des Tisches. Bevor etwas als spielbar gilt, mindestens einen Lauf vom Startpunkt aus mit echten Tasten machen: `Input.action_press("p1_right")` halten, bis die Figur ansteht, prüfen, dass `main.nears[pid]` gesetzt ist, dann die echte Taste drücken (`"p1_interact"`, `"p2_interact"`) statt `_interact` aufzurufen. Die Startkarte schliesst die Aktion `"start"` oder `"interact"`, nicht `"p1_interact"`.
- Tasten im Bot zum richtigen Zeitpunkt drücken: `is_action_just_pressed` gilt nur im Frame des Drückens. Wer nach `await RenderingServer.frame_post_draw` (Screenshot) sofort `Input.action_press` aufruft, drückt am Ende des Frames, und `main._process` sieht es im nächsten nicht mehr. Nach einem Screenshot erst `await get_tree().physics_frame`.
- Screenshots brauchen ein echtes Fenster (headless rendert nicht): ohne `--headless`, mit `--audio-driver Dummy --disable-vsync` und einer temporären `override.cfg` mit `display/window/size/no_focus=true`; speichern mit `get_viewport().get_texture().get_image().save_png(...)`.
- Level 4 wurde mit so einem Bot geprüft: zu Fuss mit echten Tasten von der Tür an den Labortisch, Hinweis da, Interaktionstaste öffnet das Pipettieren (künstliche Handdaten: kurzer Aussetzer, einzelner Sprung, anhaltendes Zittern, zu fest, schief, beide Hände auf einer Bildseite), weiter zu Fuss zur Kapelle 1 in den Blubber-Alarm (künstliches Pusten, Raumgeräusch kühlt nicht, Fächeln allein und zu zweit, Verlassen und Wiederkommen), Stichflamme, zu Fuss unter die Notdusche, zweiter Versuch, dann ans Pult und ins Testat; dazu zu lange brennen, niemand kommt zum Alarm, Testat bis zum Sieg und bis zum Wutanfall. Das Testat beantwortet der Bot über `main.minis[pid].opts` und `_pick(i)`.
- Ein Fehler im Test-Skript (zum Beispiel Zugriff auf ein Minigame, das schon geschlossen ist) beendet nur die Coroutine des Bots: Godot läuft dann ewig weiter, und der Befehl hängt. In jeden Bot einen Wachhund einbauen (in `_process` Frames zählen und nach einer Obergrenze `get_tree().quit(2)`). macOS hat kein `timeout`-Kommando.
- Temporäre Testdateien (`zz_*`, `override.cfg`, deren `.uid`) vor dem Commit wieder löschen.
- Der Bot beweist, dass der Ablauf funktioniert, nicht dass er Spass macht oder die Schwierigkeit stimmt.
