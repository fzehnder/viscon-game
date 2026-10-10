extends RefCounted
## Level content. Level 1 is the day level: two players, no guards, students walking around.
## Station rects are in tiles (1 tile = 32 px) on the current ETH Zentrum map.

const LEVEL1 := {
	"name": "Level 1 · Erster Tag",
	"time": 300.0,
	"intro": "Euer erster Tag an der ETH. Ihr habt %d Minuten:\n\n· Am Ersti-Stand auf der Polyterrasse eine Ersti-Bag klauen. Schleicht euch an, sonst schauen die Helfer*innen her.\n· Die Legi am Terminal in der Haupthalle validieren.\n· Moodle und Code Expert am PC in der Bibliothek einrichten.\n· Zum Schluss: High Five in der Mitte der Haupthalle, beide gleichzeitig.\n\nDie gelben Markierungen zeigen, wo es etwas zu tun gibt. Fehler kosten Note.",
	"tasks": [
		{"id": "ersti", "name": "Ersti-Bag klauen", "where": "Polyterrasse", "label": "Ersti-Bag schnappen", "game": "timing",
			"params": {"title": "Ersti-Bag klauen", "hits": 3, "verb": "Griff", "speed": 340.0},
			"rect": Rect2(25.6, 43.0, 1.0, 0.8), "sneak": true},
		{"id": "legi", "name": "Legi validieren", "where": "Haupthalle, Eingang", "label": "Legi validieren", "game": "timing",
			"params": {"title": "Legi validieren", "hits": 3, "verb": "Scan", "speed": 260.0},
			"rect": Rect2(47.3, 39.6, 0.7, 0.9)},
		{"id": "setup", "name": "Moodle & Code Expert einrichten", "where": "Bibliothek, Katalog-PC", "label": "PC benutzen", "game": "setup",
			"params": {"title": "Moodle & Code Expert einrichten"},
			"rect": Rect2(69.3, 29.8, 3.9, 1.0)},
		{"id": "highfive", "name": "High Five", "where": "Haupthalle, Mitte", "label": "High Five (zu zweit)", "game": "highfive",
			"params": {"title": "High Five!", "hits": 3}, "coop": true,
			"rect": Rect2(54.9, 42.0, 1.2, 1.2)},
	],
}

# Setup minigame: [question, [answers], index of correct answer]. "%COURSE%" is replaced by the player's Moodle course.
const SETUP_STEPS := [
	["Moodle: Wie meldest du dich an?", ["Mit dem ETH-Login", "Mit deinem Instagram-Account", "Gar nicht, Moodle braucht kein Login"], 0],
	["Moodle: In welchen Kurs schreibst du dich ein?", ["%COURSE%", "Kochen für Anfänger", "Einführung ins Jodeln"], 0],
	["Code Expert: Wie kommst du rein?", ["Auch mit dem ETH-Login", "Mit einem neuen Passwort pro Aufgabe", "Per Fax an den Prof"], 0],
	["Code Expert: Was machst du in der ersten Übung zuerst?", ["Projekt öffnen und den Code ausführen", "Den Server neu starten", "Dem Prof eine Mail schreiben"], 0],
]


static func level(_n: int = 1) -> Dictionary:
	return LEVEL1


static func task(id: String) -> Dictionary:
	for tk in LEVEL1["tasks"]:
		if tk["id"] == id:
			return tk
	return {}
