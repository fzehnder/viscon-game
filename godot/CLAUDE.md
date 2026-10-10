# ETH Zentrum – Tag & Nacht (Godot)

2D-Spiel in **Godot 4** (getestet mit 4.3 und 4.7, Renderer `gl_compatibility`) für den VISCON-Hackathon.
Liegt im Ordner `godot/` des Repos `fzehnder/viscon-game`. Der Rest des Repos (`src/`, `index.html`, Vite) ist ein
separates Phaser-3-Webspiel mit GitHub-Pages-Deployment auf `main`. Dateien ausserhalb von `godot/` nicht anfassen.

## Branches

- `main`: Phaser-Webspiel (CI deployt auf GitHub Pages).
- `godot-eth-tag-nacht`: erste Godot-Version (Departemente MAVT/ITET/D-INFK, Tag/Nacht, Minigames, Moodle).
- `level1-coop`: aktueller Stand. Story-Modus, 2 Spieler*innen an einer Tastatur, Level 1 «Ersti-Tag».

## Grundprinzipien

- **Alles wird im Code erzeugt**: Karte, Figuren, UI, Sounds. Keine Bild- oder Audiodateien. Szenen (`main.tscn`, `menu.tscn`) sind leere Startknoten.
- Texte im Spiel auf **Deutsch** (Schweizer Schreibweise, «ss» statt «ß», Guillemets «…»). Schweizer Noten: 6 ist die Bestnote, ab 4 bestanden.
- Professoren und Figuren sind erfunden. Die Karte ist an die ETH Zentrum angelehnt (HG, Polyterrasse, Polybahn, Bibliothek, Mensa, Rämistrasse), aber vereinfacht. 1 Kachel = 32 px, Karte 112 × 84 Kacheln.
- Die Standardschrift von Godot hat nicht alle Unicode-Zeichen: keine Pfeile, kein ≥, kein Ω usw. in Labels verwenden, stattdessen Formen zeichnen oder ASCII.
- GDScript: bei `for x in [..]` mit `:=`-Inferenz aufpassen (Variant-Typ) und `for x: float in [...]` schreiben. `_rrect`-Polygone dürfen nicht entarten, sonst «triangulation failed».

## Wichtige Dateien

| Datei | Inhalt |
|---|---|
| `scripts/map_data.gd` | Kacheln, Möbel, Türen, Stationen, Zonen, Patrouillen (Kachelkoordinaten) |
| `scripts/world.gd` | Zeichnet die Karte (Tag/Nacht), Kollisionen, A*-Raster (`AStarGrid2D`), Raycasts für Sichtkegel |
| `scripts/main.gd` | Spielablauf, Interaktionen, Ziele, Sieg/Niederlage |
| `scripts/levels.gd` | Story-Level (Level 1: Aufgaben, Orte, Menge der Erstis) |
| `scripts/controls.gd` | Tasten für P1/P2 (physische Tasten, funktioniert auf Schweizer Tastatur) |
| `scripts/minigame.gd` | Timing, Kabel, Sequenz, Quiz, Moodle (Zahlen- und Code-Aufgaben via `Expression`), Setup, High Five |
| `scripts/character_art.gd` | Figuren aus Körperteilen, 4 Blickrichtungen, Laufanimation |
| `scripts/characters.gd` | Looks, Farbpaletten, Quizfragen, Moodle-Aufgaben |
| `scripts/professor.gd` | Patrouille, Sichtkegel, Hören, Untersuchen |
| `scripts/hud.gd`, `ui.gd`, `fx.gd`, `sfx.gd` | Anzeigen, Popup-Stil, Effekte, synthetische Sounds |
| `scripts/game_state.gd` | Autoload `Game`: Spieler, Looks, Level |

Moodle-Code-Aufgaben: Spieler*innen tippen den Ausdruck nach `return`. Er wird mit `Expression` gegen Testfälle
ausgeführt und mit einem Referenzausdruck verglichen. Unterstützt: `+ - * / % **`, Vergleiche, `and/or/not`,
`max/min/abs/pow/sqrt`. Der Ternär-Operator `a if c else b` funktioniert in `Expression` **nicht** zuverlässig.

## Testen ohne Editor

```bash
godot --headless --editor --quit --path godot            # importieren, Parse-Fehler anzeigen
godot --headless --path godot --quit-after 300           # Spiel kurz laufen lassen
godot --headless --path godot -s res://_test.gd          # eigenes SceneTree-Testskript (danach löschen)
```

Bewährt hat sich ein Testskript, das `main.tscn` instanziiert, die Spielfigur an Zielpunkte teleportiert, `_interact()`
aufruft und Minigames programmatisch löst. Screenshots gehen mit
`xvfb-run godot --rendering-driver opengl3 ...` und `get_viewport().get_texture().get_image().save_png(...)`.

## Bekannte offene Punkte (Stand 10.10.)

- Level 1: In der Aufgabenliste oben links sind die Spieler-Chips abgeschnitten («Spiele.» statt «Spieler*in 1/2»).
- Level 1: Die Namensschilder von P1 und P2 überlappen, wenn beide nah beieinander stehen.
