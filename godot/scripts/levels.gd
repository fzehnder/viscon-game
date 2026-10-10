extends RefCounted
## Story levels. Level 1 is the Ersti-Tag (day): two players, no guards, a crowd of Erstis.
## Every player has to do every task. Tasks with "spots" can be done at any of those places
## (rects in tiles, 1 tile = 32 px). "steal" and "coop" tasks have no fixed place.

const LEVEL1 := {
	"name": "Ersti-Tag",
	"tag": "LEVEL 1",
	"mode": "day",
	"time": 420.0,
	"start": Vector2(26.0, 42.0),        # crowd centre on the Polyterrasse
	"speaker": Vector2(36.5, 42.0),      # the crowd faces the main building
	"crowd": 26,                          # Erstis in the welcome crowd
	"bags": 9,                            # how many of them carry an Ersti bag
	"gather": 7.0,                        # seconds the crowd stays together after the start
	"intro": "Willkommen an der ETH! Ihr steht mitten in der Ersti-Menge auf der Polyterrasse. Beide müssen alles erledigen:",
	"tasks": [
		{"id": "ersti", "name": "Ersti-Bag klauen", "where": "Erstis mit grüner Bag", "type": "steal"},
		{"id": "legi", "name": "Legi validieren", "where": "Terminals in der Haupthalle", "label": "Legi validieren",
			"game": "timing", "params": {"title": "Legi validieren", "hits": 3, "verb": "Scan", "speed": 260.0},
			"kind": "legi_terminal",
			"spots": [Rect2(47.3, 39.4, 0.8, 1.0), Rect2(62.0, 39.4, 0.8, 1.0), Rect2(51.4, 31.2, 0.8, 1.0)]},
		{"id": "setup", "name": "Moodle & Code Expert", "where": "PCs in Bibliothek und Seminarraum", "label": "PC benutzen",
			"game": "setup", "params": {"title": "Moodle & Code Expert einrichten"},
			"kind": "station",
			"spots": [Rect2(69.3, 29.8, 3.9, 1.0), Rect2(39.6, 23.6, 3.6, 0.7), Rect2(80.8, 38.4, 3.6, 1.2)]},
		{"id": "highfive", "name": "High Five", "where": "zu zweit, überall", "type": "coop",
			"game": "highfive", "params": {"title": "High Five!", "hits": 3}},
	],
}

# Setup minigame: [question, [answers], index of correct answer]. "%COURSE%" is replaced by the Moodle course.
const SETUP_STEPS := [
	["Moodle: Wie meldest du dich an?", ["Mit dem ETH-Login", "Mit deinem Instagram-Account", "Gar nicht, Moodle braucht kein Login"], 0],
	["Moodle: In welchen Kurs schreibst du dich ein?", ["%COURSE%", "Kochen für Anfänger", "Einführung ins Jodeln"], 0],
	["Code Expert: Wie kommst du rein?", ["Auch mit dem ETH-Login", "Mit einem neuen Passwort pro Aufgabe", "Per Fax an den Prof"], 0],
	["Code Expert: Was machst du in der ersten Übung zuerst?", ["Projekt öffnen und den Code ausführen", "Den Server neu starten", "Dem Prof eine Mail schreiben"], 0],
]


static func level(_n: int = 1) -> Dictionary:
	return LEVEL1


static func tasks() -> Array:
	return LEVEL1["tasks"]


static func task(id: String) -> Dictionary:
	for tk in LEVEL1["tasks"]:
		if tk["id"] == id:
			return tk
	return {}
