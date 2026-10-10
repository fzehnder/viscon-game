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

Anzeigen: Die Aufgaben stehen auf der Seite der jeweiligen Person, links für P1 (WASD), rechts für P2 (Pfeiltasten), mit Häkchen und Zähler. Unten in der Mitte Level und Zeit, unten rechts die Minimap: der ganze Campus, beide Figuren in ihrer Farbe, offene Aufgaben als Rauten (in der Farbe derer, die sie noch brauchen, Gelb heisst beide) und rot blinkend ein Opp, der gerade jemanden jagt.

| | P1 | P2 |
|---|---|---|
| Gehen | WASD | Pfeiltasten |
| Interagieren / Minigame | E | Enter |
| Sprinten (2 s, lädt in ca. 3 s auf) | Shift | . |
| Schleichen | Ctrl | - (US-Layout: /) |
| Minigame abbrechen | Esc | Backspace |
| Antworten | 1 2 3 | 8 9 0 |

Jeder Schritt sendet einen Geräusch-Kreis aus: schleichen fast lautlos, gehen normal, sprinten laut. Fehler in Minigames machen ebenfalls einen Kreis.

**Ablauf (Story-Modus, keine Departemente mehr):** Startseite → Hack der Bewerbungsseite → Namen → Legi-Foto pro Person (Kamera des Geräts, sonst gezeichnete Figur) → Figuren gestalten → Level 1.

**Level 1 · Ersti-Tag (Tag):** Ihr startet in der Ersti-Menge auf der Polyterrasse. Beide müssen alles erledigen:
- Ersti-Bag klauen: Am Lesetisch in der Bibliothek sitzen Deniz und Livia, neben jedem Stuhl steht eine Ersti-Bag. Leise von hinten heran und mit der Interaktionstaste nehmen, die Bag erscheint danach auf eurer Figur. Wer laut ist, wird gehört, und wer beim Klauen gesehen wird, hat sofort einen Opp am Hals (siehe unten).
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

Ersti-Bag in Level 1: Sieht Deniz oder Livia den Diebstahl, wird er oder sie sofort zum Opp. Sonst fällt es erst nach 6 bis 9 Sekunden auf (oder früher, wenn sich jemand umdreht und euch mit der Bag sieht), und dann wird in eure Richtung gesucht.

Der Code steht in `scripts/opp.gd` (Zustände und Stellschrauben oben in der Datei), die Liste der Opps im Autoload `Game` (`game_state.gd`).

**Weitere Levels** liegen je in einem eigenen Ordner `scripts/level<N>/` und beschreiben sich dort in einer `README.md`. Welche Levels es gibt, hängt vom Branch ab: Das Spiel findet die Ordner selbst und spielt sie in der Reihenfolge ihrer Nummern.

## Ein neues Level bauen

Levels entstehen gleichzeitig auf eigenen Branches. Damit sich niemand in die Quere kommt, gehört einem Level genau ein Ordner, und gemeinsame Dateien bleiben unangetastet.

1. Branch vom gemeinsamen Stand abzweigen: `git fetch`, dann `git switch -c level3-name origin/level-base`. Nicht von einem anderen Level-Branch abzweigen und nicht auf dessen Push warten.
2. Ordner `scripts/level3/` anlegen, darin `level.gd`. Mehr braucht es nicht: `scripts/levels.gd` findet den Ordner über den Namen, das Level erscheint auf der Startseite unter «Direkt zu» und nach dem Level davor als «Weiter zu Level 3». Fehlt auf einem Branch ein Level dazwischen, wird es übersprungen.
3. Alles, was nur dieses Level braucht (Figuren, Möbel, Texte, eine `README.md`), kommt in diesen Ordner.
4. Testen: auf der Startseite «Direkt zu», oder `godot --path godot res://main.tscn -- --level=3`.
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
| `scripts/game_state.gd` | Autoload «Game»: gewählte Optionen |

Die Karte ist an die ETH Zentrum angelehnt, aber vereinfacht. Professoren und Figuren sind erfunden. Die Datei `scripts/person_draw.gd` aus der ersten Version wird nicht mehr gebraucht und kann gelöscht werden.
