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

Zwei Spieler*innen an einer Tastatur. Sind beide nah beieinander, gibt es eine gemeinsame Kamera. Laufen sie auseinander oder ist jemand in einem Minigame, teilt sich der Bildschirm (P1 links, P2 rechts). Das Minigame öffnet sich auf der Hälfte von dem, der es gestartet hat.

| | P1 | P2 |
|---|---|---|
| Gehen | WASD | Pfeiltasten |
| Interagieren / Minigame | E | Enter |
| Sprinten (2 s, lädt in ca. 3 s auf) | Shift | . |
| Schleichen | Ctrl | - (US-Layout: /) |
| Minigame abbrechen | Esc | Backspace |
| Antworten | 1 2 3 | 8 9 0 |

Jeder Schritt sendet einen Geräusch-Kreis aus: schleichen fast lautlos, gehen normal, sprinten laut. Fehler in Minigames machen ebenfalls einen Kreis.

**Level 1 (Tag):** Ersti-Bag klauen (anschleichen, sonst schauen die Helfer*innen her), Legi validieren, Moodle & Code Expert einrichten, High Five zu zweit. Inhalte und Positionen in `scripts/levels.gd`, Tasten in `scripts/controls.gd`.

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
- Accessoires: `goggles`, `headphones`, `glasses`, `backpack`, `toolbelt`, `laptop`, `flashlight`, `beard`, `lanyard`

Eine neue Frisur oder ein neues Accessoire fügst du in `character_art.gd` hinzu (Funktionen `_draw_hair_fb` und `_draw_hair_side` für Haare, `draw_character` für Kleidung).

## Dateien

| Datei | Inhalt |
|---|---|
| `menu.tscn`, `scripts/menu.gd` | Auswahlmenü mit Vorschau |
| `main.tscn`, `scripts/main.gd` | Spielablauf, Missionen, Fähigkeiten, Noten |
| `scripts/map_data.gd` | Karte, Möbel, Türen, Stationen, Patrouillen |
| `scripts/world.gd` | Zeichnen der Karte (Tag/Nacht), Kollision, A*-Wege |
| `scripts/minigame.gd` | Alle Minigames inklusive Moodle |
| `scripts/player.gd`, `professor.gd`, `student.gd` | Figuren |
| `scripts/hud.gd`, `scripts/fx.gd` | Anzeigen und Effekte |
| `scripts/game_state.gd` | Autoload «Game»: gewählte Optionen |

Die Karte ist an die ETH Zentrum angelehnt, aber vereinfacht. Professoren und Figuren sind erfunden. Die Datei `scripts/person_draw.gd` aus der ersten Version wird nicht mehr gebraucht und kann gelöscht werden.
