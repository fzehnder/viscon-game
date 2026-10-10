# ETH Zentrum – Tag & Nacht

Ein 2D-Spiel für **Godot 4.3 oder neuer**. Du wählst dein Departement, gestaltest deine Figur und spielst entweder tagsüber Aufgaben gegen die Uhr oder brichst nachts ins Labor ein, ohne dass dich die Professoren erwischen.

## Starten

1. Godot 4.3+ öffnen → **Importieren** → `project.godot` in diesem Ordner wählen.
2. **F5** (Mac: Cmd+B). Das Spiel startet im Auswahlmenü.

## Departemente

| | Figur | Nacht-Fähigkeit (Q) | Nacht-Mission | Tagesaufgaben |
|---|---|---|---|---|
| **MAVT** | Lena | Schraubenschlüssel werfen: lockt Professoren an die Stelle | Dietrich-Set holen, Labortür knacken (Timing), Prototyp-Getriebe | Schweissen, Statik-Quiz, Mechanik im Moodle, Kaffee holen |
| **ITET** | Noah | Stromausfall: Taschenlampen 7 s nur halbe Reichweite | Schaltplan holen, Sicherungskasten verdrahten (Kabel), Festplatte | Sicherung flicken, E-Technik-Quiz, Schaltungsrechnung im Moodle, Platine verdrahten |
| **D-INFK** | Mia | Netzwerk-Ping: zeigt 6 s alle Professoren | Passwort im Moodle finden (Code), Kartenleser hacken (Sequenz), USB-Stick | Server neustarten, Algorithmen-Quiz, zwei Code-Aufgaben im Moodle |

## Modi

- **Nacht:** Schleichspiel. Lichtkegel, Geräusche, Verstecke. Fehler in Minigames machen Lärm. Am Ende geht es zur Polybahn.
- **Tag:** Campus voller Studierender, 5 Minuten Zeit. Fehler und Zeit bestimmen die Note (6 = Bestnote, ab 4 bestanden). Abgeben in der Haupthalle beim Prof deines Departements.

## Minigames

- **Timing:** Taste drücken, wenn der Zeiger im grünen Bereich ist (Schloss, Schweissen, Kaffee).
- **Kabel:** gleiche Farben verbinden (Maus oder W/S + E).
- **Sequenz:** Pfeilfolge merken und nachtippen.
- **Quiz:** drei Fragen pro Departement, Tasten 1–3.
- **Moodle:** am Computer Rechenaufgaben lösen (Zahl eintippen) oder bei D-INFK Mini-Code schreiben. Du schreibst den Ausdruck nach `return`, zum Beispiel `n % 2 == 0`. Er wird gegen mehrere Testfälle ausgeführt. Erlaubt sind `+ - * / %`, `**`, Vergleiche, `and`/`or`/`not` und Funktionen wie `max`, `min`, `abs`, `pow`, `sqrt`.

## Steuerung

| Taste | Aktion |
|---|---|
| WASD / Pfeile | Gehen |
| Shift | Schleichen (nachts, lautlos) |
| E / Leertaste | Interagieren, verstecken |
| Q | Departement-Fähigkeit (nachts) |
| Mausrad / + / − | Zoom |
| Esc | Minigame abbrechen |
| R / M | Nach Spielende: neue Runde / Menü |

## Zu zweit (Co-op)

Zwei Spieler*innen an einer Tastatur. Sind beide nah beieinander, gibt es eine gemeinsame Kamera. Laufen sie auseinander oder ist jemand in einem Minigame, teilt sich der Bildschirm (P1 links, P2 rechts). Der Übergang ist fliessend: Die beiden Bildhälften gleiten auseinander und wieder zusammen, nichts springt. Das Minigame öffnet sich auf der Hälfte von dem, der es gestartet hat.

Aufgabe wählen: Mit Tab (P1) oder Komma (P2) geht man seine offenen Aufgaben der Reihe nach durch, ein weiterer Druck nach der letzten schaltet wieder aus. Ein Klick auf die Aufgabe geht auch. Die gewählte Aufgabe ist auf der Karte eingerahmt, und gestrichelte Pfeile in der eigenen Farbe zeigen den kürzesten Weg zum nächsten Ort, an dem man sie erledigen kann (auch auf der Minimap). Bei «High Five» führt der Weg zur anderen Person.

Anzeigen: Die Aufgaben stehen auf der Seite der jeweiligen Person, links für P1 (WASD), rechts für P2 (Pfeiltasten), mit Häkchen und Zähler. Oben in der Mitte Level und Zeit, unten in der Mitte die Minimap: der ganze Campus, beide Figuren in ihrer Farbe, offene Aufgaben als Rauten (in der Farbe derer, die sie noch brauchen, Gelb heisst beide) und rot blinkend ein Opp, der gerade jemanden jagt.

| | P1 | P2 |
|---|---|---|
| Gehen | WASD | Pfeiltasten |
| Interagieren / Minigame | E | Enter |
| Sprinten (2 s, lädt in ca. 3 s auf) | Shift | . |
| Aufgabe wählen, Weg anzeigen | Tab | , |
| Schleichen | Ctrl | - (US-Layout: /) |
| Minigame abbrechen | Esc | Backspace |
| Antworten | 1 2 3 | 8 9 0 |

Jeder Schritt sendet einen Geräusch-Kreis aus: schleichen fast lautlos, gehen normal, sprinten laut. Fehler in Minigames machen ebenfalls einen Kreis.

**Ablauf (Story-Modus, keine Departemente mehr):** Startseite → Hack der Bewerbungsseite → Namen → Legi-Foto pro Person (Kamera des Geräts, sonst gezeichnete Figur) → Figuren gestalten → Level 1.

**Level 1 · Ersti-Tag (Tag):** Ihr startet in der Ersti-Menge auf der Polyterrasse. Beide müssen alles erledigen:
- Ersti-Bag klauen: Am Lesetisch in der Bibliothek sitzen Deniz und Livia, neben jedem Stuhl steht eine Ersti-Bag. Leise von hinten heran und mit der Interaktionstaste nehmen, die Bag erscheint danach auf eurer Figur. Erledigt ist die Aufgabe erst, wenn ihr die Bibliothek mit der Bag verlassen habt, ohne erwischt zu werden (auf der Aufgabenkarte steht so lange «raus!»). Wer laut ist, wird gehört, und wer beim Klauen gesehen wird, hat sofort einen Opp am Hals (siehe unten).
- Legi validieren: an einem der Terminals in der Haupthalle.
- Moodle & Code Expert einrichten: an einem der PCs (Bibliothek, Seminarraum).
- High Five: zu zweit, überall, wo ihr nebeneinander steht.

Inhalte und Positionen von Level 1 in `scripts/levels.gd`, Tasten in `scripts/controls.gd`, Popup-Stil in `scripts/ui.gd`, Sounds in `scripts/sfx.gd` (werden im Code erzeugt, keine Audiodateien).

## Opps

Ein Opp ist jemand, dem ihr etwas angetan habt. Die meisten Leute sind zuerst neutral; ein Ereignis macht sie zum Opp, und das bleibt über die Levels hinweg gespeichert (`user://save.cfg`, «START» auf der Startseite beginnt wieder bei null).

- **Zustände:** neutral → misstrauisch (hat etwas gehört, schaut kurz hin, gelbes «?») → Jagd (rotes «!», rennt euch nach) → suchen (rotes «?», geht zur Stelle, an der ihr zuletzt gesehen wurdet) → zurück an den Platz → lauern (bleibt wütend und beobachtet).
- **Sichtkegel:** halbtransparent am Boden, Wände und hohe Möbel wie Regale verdecken die Sicht. Bei neutralen Leuten ist er blass, bei Opps gelb bis rot.
- **Verdachtsbalken:** Sieht euch ein Opp, füllt sich der Balken über seinem Kopf, näher dran geht es schneller. Erst bei 100 % beginnt die Jagd, vorher könnt ihr aus dem Kegel verschwinden.
- **Lärm:** Gehen und Sprinten hört man, Schleichen nicht. Normale Leute stört das nicht. Wer in einem Level darauf achten soll (die beiden am Lesetisch), dreht sich um. Opps gehen nachsehen, das kann die andere Person ausnutzen und sie weglocken.
- **Wer ist gemeint:** Ein Opp ist nur hinter denen her, die ihm etwas getan haben. Die andere Person lässt er in Ruhe.
- **Erwischt:** Berührt euch ein Opp, während ihr seine Bag tragt, ist die Beute weg: Er bringt sie zurück an den Platz, die Aufgabe ist wieder offen und es zählt als Fehler. Ohne Beute heisst erwischt: Level verloren.
- **Tempo:** Ein Opp ist schneller als Gehen und langsamer als Sprinten. Abhängen geht mit einem Sprint und einer Ecke oder einem Regal dazwischen.
- **Bag zurück:** Hat ein Opp seine Bag wieder, ist ihm der Aufwand nicht mehr viel wert. Er trottet euch nur noch hinterher, langsamer als ihr geht, gibt nach drei Sekunden auf und lässt euch danach eine Weile in Ruhe. Klaut ihr die Bag erneut, ist er wieder mit vollem Tempo hinter euch her.

Ersti-Bag in Level 1: Sieht Deniz oder Livia den Diebstahl, wird er oder sie sofort zum Opp. Sonst fällt es erst nach 6 bis 9 Sekunden auf (oder früher, wenn sich jemand umdreht und euch mit der Bag sieht), und dann wird in eure Richtung gesucht.

Der Code steht in `scripts/opp.gd` (Zustände und Stellschrauben oben in der Datei), die Liste der Opps im Autoload `Game` (`game_state.gd`).

**Weitere Levels** liegen je in einem eigenen Ordner `scripts/level<N>/` und beschreiben sich dort in einer `README.md`. Welche Levels es gibt, hängt vom Branch ab: Das Spiel findet die Ordner selbst und spielt sie in der Reihenfolge ihrer Nummern.

## Ein neues Level bauen

Levels entstehen gleichzeitig auf eigenen Branches. Damit sich niemand in die Quere kommt, gehört einem Level genau ein Ordner, und gemeinsame Dateien bleiben unangetastet.

1. Branch vom gemeinsamen Stand abzweigen: `git fetch`, dann `git switch -c level3-name origin/level-base`. Nicht von einem anderen Level-Branch abzweigen und nicht auf dessen Push warten.
2. Ordner `scripts/level3/` anlegen, darin `level.gd`. Mehr braucht es nicht: `scripts/levels.gd` findet den Ordner über den Namen, das Level erscheint als Fach im Leistungsüberblick (Startseite, «Leistungsüberblick · Level wählen») und nach dem Level davor als «Weiter zu Level 3». Fehlt auf einem Branch ein Level dazwischen, wird es übersprungen.
3. Alles, was nur dieses Level braucht (Figuren, Möbel, Texte, eine `README.md`), kommt in diesen Ordner.
4. Testen: auf der Startseite «Leistungsüberblick · Level wählen» und das Fach anklicken, oder `godot --path godot res://main.tscn -- --level=3`.
5. Fertige Levels kommen per Pull Request nach `level-base`. Weil jedes Level nur seinen Ordner hinzufügt, gibt es dabei keine Konflikte. Die anderen Level-Branches holen sich den neuen Stand mit `git merge origin/level-base`.

Braucht ein Level doch etwas Allgemeines (einen neuen Hook in `main.gd`, ein Accessoire in `character_art.gd`, einen Sound), dann als eigenen kleinen Commit, der möglichst früh nach `level-base` geht, damit alle ihn haben.

Gerüst für `scripts/level3/level.gd` (Vorlage mit allem Drum und Dran: `scripts/level2/level.gd` auf dem Branch `level2-mensa`):

```gdscript
extends Node2D

const TS := 32.0
const DEF := {
	"name": "Mein Level", "tag": "LEVEL 3", "mode": "day", "time": 180.0,
	"start": Vector2(26.0, 42.0),          # Startpunkt in Tiles (1 Tile = 32 px)
	"intro": "Worum es geht. Beide müssen alles erledigen:",
	"hint": "Ein Satz Spielhilfe.",        # optional, wie alle Texte ab hier
	"start_toast": ["Titel", "Text"],
	"timer_title": "ZEIT BIS ...",
	"win_title": "Geschafft", "win_text": "%s & %s haben es geschafft.",
	"lose_title": "Zeit abgelaufen", "lose_text": "Schade.",
	"tasks": [
		{"id": "mate", "name": "Mate klauen", "where": "im Kühlschrank", "type": "level"},
	],
}

var main   # main.gd, wird vor _ready gesetzt


## Möbel des Levels: md ist map_data.gd, Positionen in Tiles. Optional.
static func build_map(md) -> void:
	md.R("fridge", 40.0, 30.0, 1.0, 1.0)   # unbekannte Arten zeichnet das Level selbst


func _ready() -> void:
	z_index = -5   # eigene Zeichnung über der Karte, unter den Figuren


## Was kann Figur pid gerade tun? Jeden Frame gefragt. Optional wie alle folgenden.
func update_near(pid: int) -> void:
	if main.players[pid].global_position.distance_to(Vector2(40.5, 31.5) * TS) < 1.2 * TS:
		main.nears[pid] = {"use": "level", "act": "fridge", "label": "Kühlschrank öffnen",
			"rect": Rect2(40.0, 30.0, 1.0, 1.0)}


func interact(pid: int, o: Dictionary) -> void:
	if o["act"] == "fridge":
		main._task_done(pid, "mate")   # oder zuerst main.open_minigame(...)


## Markierungen für eine Aufgabe: [[Position in px, Farbe], ...]
func goal_positions(_id: String, n0: bool, n1: bool) -> Array:
	return [[Vector2(40.5, 30.5) * TS, main._need_color(n0, n1)]]


## Wohin die gestrichelten Pfeile führen, wenn jemand die Aufgabe wählt: Punkte in px.
func task_targets(_id: String, _pid: int) -> Array:
	return [Vector2(40.5, 31.5) * TS]


func on_noise(_at: Vector2, _radius: float) -> void:
	pass   # Schritte und Minigame-Fehler


## Nach der letzten Aufgabe, zum Beispiel eine Cutscene. Muss done aufrufen.
func finale(done: Callable) -> void:
	done.call()
```

Opps im eigenen Level, alles über `DEF`, ohne weiteren Code:

```gdscript
	# Leute, die Opps werden können. "bag" stellt etwas Klaubares daneben (dazu eine Aufgabe
	# mit "type": "bag"), "bag_name" benennt es. Ist die id schon ein Opp, startet die Person wütend.
	"npcs": [
		{"id": "mate_max", "name": "Max", "pos": Vector2(41.0, 31.0), "face": PI / 2.0, "mode": "steht",
			"bag": Vector2(41.7, 31.1), "bag_name": "Rucksack", "hears": true, "if_opp": "lauert"},
	],
	# Plätze für Opps aus früheren Levels: "lauert" wartet dort, "jagd" kommt euch suchen.
	"opp_spots": [{"pos": Vector2(30.0, 45.0), "face": 0.0, "mode": "lauert"}, {"pos": Vector2(60.0, 40.0), "mode": "jagd"}],
```

Eigene Auslöser (jemand wird wegen etwas anderem zum Opp): `Game.add_opp(id, name, look, [pid], "warum")` merkt sich die Person samt Aussehen; in späteren Levels taucht sie an den `opp_spots` wieder auf. Wer selbst entscheiden will, was beim Erwischen passiert, schreibt in der Level-Datei `func on_opp_catch(opp, pid) -> bool` und gibt `true` zurück.

Cutscenes: `scripts/cutscene.gd` spielt eine Liste von Schritten ab (Sprechzeilen, Handy-Meldung, E-Mail, Titelkarte), siehe Kommentar oben in der Datei.

## Karte

Das Hauptgebäude folgt dem echten Grundriss des E-Geschosses (Fluchtwegplan), vereinfacht und mit weniger Räumen. Norden ist oben, die Polyterrasse liegt im Westen, die Rämistrasse im Osten.

- Hauptblock mit Westeingang von der Polyterrasse; Eckpavillons und Mittelteil springen an der Fassade vor.
- Die Haupthalle läuft vom Westeingang quer durchs Gebäude und endet in der Rotunde, die in den Vorhof zur Rämistrasse ragt.
- Nördlich und südlich davon E Nord und E Süd: je ein grosser Hörsaal (E1, E7), ein kleiner mit runden Ecken an der Haupthalle (E3, E5), Foyer und Durchgänge rundherum.
- Ein Ring aus Korridoren mit Räumen an der Aussenseite, Nord- und Südeingang in der Mitte der Seiten.
- Zwei Ostflügel mit Endpavillons: im Norden die ETH-Bibliothek, im Süden das Labor. (Im echten Gebäude liegen dort Büros; Bibliothek und Labor braucht das Spiel.)

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

Alle Positionen in Tiles (1 Tile = 32 px), gebaut in `scripts/map_data.gd` (`_hauptgebaeude`). Die Südhälfte ist die gespiegelte Nordhälfte.

## Charakter-Design

Im Menü änderst du Frisur, Haarfarbe, Hautton, Oberteil und Hose. Tiefer geht es in den Dateien:

- `scripts/characters.gd`: Looks der drei Figuren und der Professoren, Farbpaletten, Frisuren, Quizfragen, Moodle-Aufgaben, Tagesaufgaben.
- `scripts/character_art.gd`: zeichnet die Figur aus Körperteilen (Beine, Schuhe, Torso, Arme, Kopf, Gesicht, Haare, Accessoires) in vier Blickrichtungen mit Laufanimation.

Ein Look ist ein Dictionary, zum Beispiel:

```gdscript
{"skin": "f1c9a5", "hair": "8a3b22", "hair_style": "zopf", "top": "2f4f8f", "top_style": "overall",
 "accent": "e07a2f", "pants": "2f4f8f", "shoes": "3b2a1e", "acc": ["goggles", "toolbelt"]}
```

- Frisuren: `kurz`, `lang`, `zopf`, `dutt`, `locken`, `cap`, `glatze`
- Oberteile: `tshirt`, `hoodie`, `overall`, `labcoat`, `jacket`, `sweater`
- Accessoires: `goggles`, `headphones`, `glasses`, `backpack`, `toolbelt`, `laptop`, `flashlight`, `beard`, `lanyard`, `erstibag`, `tray`, `loot`

Eine neue Frisur oder ein neues Accessoire fügst du in `character_art.gd` hinzu (Funktionen `_draw_hair_fb` und `_draw_hair_side` für Haare, `draw_character` für Kleidung).

## Dateien

| Datei | Inhalt |
|---|---|
| `menu.tscn`, `scripts/menu.gd` | Auswahlmenü mit Vorschau |
| `main.tscn`, `scripts/main.gd` | Spielablauf, Missionen, Fähigkeiten, Noten |
| `scripts/levels.gd` | findet die Levels, Inhalt von Level 1 |
| `scripts/level<N>/level.gd` | je ein weiteres Level mit allem, was dazugehört |
| `scripts/cutscene.gd` | Cutscenes (Sprechzeilen, Handy, E-Mail, Titelkarte) |
| `scripts/map_data.gd` | Karte, Möbel, Türen, Stationen, Patrouillen |
| `scripts/world.gd` | Zeichnen der Karte (Tag/Nacht), Kollision, A*-Wege |
| `scripts/minigame.gd` | Alle Minigames inklusive Moodle |
| `scripts/player.gd`, `professor.gd`, `student.gd` | Figuren |
| `scripts/opp.gd` | Leute, die zu Opps werden: Zustände, Sichtkegel, Verdachtsbalken, klaubare Bag |
| `scripts/hud.gd`, `scripts/fx.gd` | Anzeigen und Effekte |
| `scripts/tracking.gd`, `scripts/track_math.gd` | Autoload «Track»: Webcam und Mikrofon für Minigames, siehe `../tracker/README.md` |
| `track_debug.tscn`, `scripts/track_debug.gd` | Testszene für das Tracking, nicht Teil des Spiels |
| `scripts/game_state.gd` | Autoload «Game»: gewählte Optionen |

Die Karte ist an die ETH Zentrum angelehnt, aber vereinfacht. Professoren und Figuren sind erfunden. Die Datei `scripts/person_draw.gd` aus der ersten Version wird nicht mehr gebraucht und kann gelöscht werden.
