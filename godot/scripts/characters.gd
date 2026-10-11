extends RefCounted
## Everything you need for character design and department content lives here.
## Change looks, add hair styles or colours, write new quiz questions or Moodle tasks.

# ------------------------------------------------------------------ design options
# hair styles understood by character_art.gd
const HAIR_STYLES := ["kurz", "lang", "zopf", "dutt", "locken", "cap", "glatze"]
const HAIR_COLORS := ["2b2018", "5a3a22", "8a3b22", "c9a46a", "e8d9b0", "1a1a1a", "b8b8b8", "6b2d8f"]
const SKIN_TONES := ["f5d6bd", "f1c9a5", "e0ac85", "c68863", "9c6644", "6f4a33"]
const TOP_COLORS := ["2f4f8f", "e07a2f", "3e7d4f", "3b3f46", "a33b5c", "d9a441", "e9ece8", "5d3f7a"]
const PANTS_COLORS := ["2d3a52", "3b3f46", "6b5440", "1f1f24", "4f6b8a", "7a6450"]
# top styles: tshirt, hoodie, overall, labcoat, jacket, sweater
# what the players can choose in the character design (skin_menu.gd), with the names shown there
const PLAYER_TOPS := ["tshirt", "hoodie", "sweater", "jacket"]
const TOP_NAMES := {"tshirt": "T-Shirt", "hoodie": "Hoodie", "sweater": "Pulli", "jacket": "Jacke", "overall": "Overall", "labcoat": "Labormantel"}
const HAIR_NAMES := {"kurz": "Kurz", "lang": "Lang", "zopf": "Zopf", "dutt": "Dutt", "locken": "Locken", "cap": "Cap", "glatze": "Glatze"}
const EXTRAS := ["", "glasses", "headphones", "beard", "goggles"]      # one accessory to pick; "" = none
const EXTRA_NAMES := {"": "nichts", "glasses": "Brille", "headphones": "Kopfhörer", "beard": "Bart", "goggles": "Schutzbrille"}
const SHOE_COLORS := ["1f1f24", "e9ece8", "3b2a1e", "6b5440", "a33b5c", "2f4f8f", "3e7d4f"]
# accessories: goggles, headphones, glasses, backpack, toolbelt, laptop, flashlight, beard, lanyard, erstibag, tray, loot


# ------------------------------------------------------------------ departments
const DEPTS := {
	"MAVT": {
		"full": "Maschinenbau und Verfahrenstechnik",
		"char": "Lena",
		"tag": "Baut alles, was sich dreht.",
		"accent": "e07a2f",
		"look": {"skin": "f1c9a5", "hair": "8a3b22", "hair_style": "zopf", "top": "2f4f8f", "top_style": "overall",
			"accent": "e07a2f", "pants": "2f4f8f", "shoes": "3b2a1e", "acc": ["goggles", "toolbelt"]},
		"ability": {"id": "wrench", "name": "Schraubenschlüssel werfen", "cooldown": 12.0,
			"desc": "Wirft einen Schlüssel ein Stück nach vorne. Der Lärm lockt Professoren an genau diese Stelle."},
		"night_text": "Hol dir das Dietrich-Set aus der Werkzeugkiste im Seminarraum, knack die Labortür (Timing-Minigame) und schnapp dir den Prototyp.",
		"day_text": "Getriebe schweissen, Statik-Quiz, Mechanik-Aufgaben im Moodle und Kaffee für den Prof.",
		"prof": "Prof. Dr. Brunner",
	},
	"ITET": {
		"full": "Informationstechnologie und Elektrotechnik",
		"char": "Noah",
		"tag": "Wo Strom fliesst, ist Noah nicht weit.",
		"accent": "3fae6a",
		"look": {"skin": "9c6644", "hair": "1a1a1a", "hair_style": "locken", "top": "3e7d4f", "top_style": "hoodie",
			"accent": "d9a441", "pants": "4f6b8a", "shoes": "e9ece8", "acc": ["headphones", "backpack"]},
		"ability": {"id": "blackout", "name": "Stromausfall", "cooldown": 25.0,
			"desc": "Legt für 7 Sekunden das Licht lahm. Die Taschenlampen der Professoren reichen nur noch halb so weit."},
		"night_text": "Hol den Schaltplan an der Ausleihe, verdrahte den Sicherungskasten neben dem Labor (Kabel-Minigame) und hol die Festplatte mit den Messdaten.",
		"day_text": "Sicherung flicken, Elektrotechnik-Quiz, Schaltungsrechnung im Moodle und eine Platine verdrahten.",
		"prof": "Prof. Dr. Keller",
	},
	"D-INFK": {
		"full": "Informatik",
		"char": "Mia",
		"tag": "Löst Probleme, die es ohne Computer nicht gäbe.",
		"accent": "6a9be0",
		"look": {"skin": "e0ac85", "hair": "2b2018", "hair_style": "lang", "top": "3b3f46", "top_style": "hoodie",
			"accent": "6a9be0", "pants": "1f1f24", "shoes": "a33b5c", "acc": ["glasses", "laptop"]},
		"ability": {"id": "ping", "name": "Netzwerk-Ping", "cooldown": 15.0,
			"desc": "Zeigt 6 Sekunden lang, wo alle Professoren sind und wohin sie schauen, auch ausserhalb des Bildschirms."},
		"night_text": "Lös am Moodle-PC in der Bibliothek zwei Code-Aufgaben, um das Wartungspasswort zu finden, hack den Kartenleser (Code-Minigame) und hol den USB-Stick.",
		"day_text": "Server neustarten, Algorithmen-Quiz und zwei Code-Aufgaben im Moodle.",
		"prof": "Prof. Dr. Huber",
	},
}
const DEPT_ORDER := ["MAVT", "ITET", "D-INFK"]


# ------------------------------------------------------------------ professors (fictional)
const PROF_LOOKS := {
	"Prof. Dr. Brunner": {"skin": "e6b894", "hair": "d8d4cc", "hair_style": "kurz", "top": "6b4f3a", "top_style": "jacket",
		"accent": "e9ece8", "pants": "3b3f46", "shoes": "2b2018", "acc": ["glasses", "beard", "flashlight"]},
	"Prof. Dr. Keller": {"skin": "c68863", "hair": "3b2a1e", "hair_style": "kurz", "top": "39465a", "top_style": "sweater",
		"accent": "e9ece8", "pants": "2d3a52", "shoes": "2b2018", "acc": ["flashlight", "lanyard"]},
	"Prof. Dr. Meier": {"skin": "f1c9a5", "hair": "c9c4ba", "hair_style": "dutt", "top": "5d6b4a", "top_style": "jacket",
		"accent": "d9a441", "pants": "6b5440", "shoes": "3b2a1e", "acc": ["glasses", "flashlight"]},
	"Prof. Dr. Huber": {"skin": "f5d6bd", "hair": "e8e4dc", "hair_style": "glatze", "top": "eef1f3", "top_style": "labcoat",
		"accent": "6a9be0", "pants": "3b3f46", "shoes": "1f1f24", "acc": ["glasses", "beard", "flashlight"]},
	"Prof. Dr. Widmer": {"skin": "e0ac85", "hair": "6b5040", "hair_style": "kurz", "top": "2f4f6f", "top_style": "jacket",
		"accent": "c0392b", "pants": "1f1f24", "shoes": "1f1f24", "acc": ["flashlight"]},
}


static func random_student(rng: RandomNumberGenerator) -> Dictionary:
	var styles := ["tshirt", "hoodie", "sweater", "jacket", "tshirt"]
	var accs: Array = []
	if rng.randf() < 0.5: accs.append("backpack")
	if rng.randf() < 0.25: accs.append("glasses")
	if rng.randf() < 0.15: accs.append("headphones")
	if rng.randf() < 0.1: accs.append("laptop")
	return {"skin": SKIN_TONES[rng.randi() % SKIN_TONES.size()], "hair": HAIR_COLORS[rng.randi() % 6],
		"hair_style": HAIR_STYLES[rng.randi() % 6], "top": TOP_COLORS[rng.randi() % TOP_COLORS.size()],
		"top_style": styles[rng.randi() % styles.size()], "accent": TOP_COLORS[rng.randi() % TOP_COLORS.size()],
		"pants": PANTS_COLORS[rng.randi() % PANTS_COLORS.size()], "shoes": ["1f1f24", "e9ece8", "6b5440", "a33b5c"][rng.randi() % 4],
		"acc": accs}


# ------------------------------------------------------------------ quiz questions [question, [answers], index of correct]
const QUIZ := {
	"MAVT": [
		["Einheit der Kraft?", ["Newton", "Joule", "Pascal"], 0],
		["Spannung sigma = ?", ["F / A", "F · A", "A / F"], 0],
		["Hookesches Gesetz: sigma = ?", ["E · epsilon", "E / epsilon", "epsilon / E"], 0],
		["Welches Getriebe lenkt um 90 Grad um?", ["Kegelradgetriebe", "Stirnradgetriebe", "Riemengetriebe"], 0],
		["1 bar entspricht …", ["100'000 Pa", "1'000 Pa", "1'000'000 Pa"], 0],
		["Was speichert ein Schwungrad?", ["Rotationsenergie", "Wärme", "Elektrische Ladung"], 0],
	],
	"ITET": [
		["Ohmsches Gesetz: U = ?", ["R · I", "R / I", "I / R"], 0],
		["Einheit der Kapazität?", ["Farad", "Henry", "Ohm"], 0],
		["Zwei 100-Ohm-Widerstände parallel ergeben …", ["50 Ohm", "200 Ohm", "100 Ohm"], 0],
		["Elektrische Leistung P = ?", ["U · I", "U / I", "R / I"], 0],
		["Netzfrequenz in der Schweiz?", ["50 Hz", "60 Hz", "230 Hz"], 0],
		["Was lässt Strom nur in eine Richtung durch?", ["Diode", "Spule", "Kondensator"], 0],
	],
	"D-INFK": [
		["Laufzeit der binären Suche?", ["O(log n)", "O(n)", "O(n log n)"], 0],
		["Welche Datenstruktur arbeitet nach LIFO?", ["Stack", "Queue", "Heap"], 0],
		["Wie viele Bit hat ein Byte?", ["8", "16", "4"], 0],
		["Was ist 2 hoch 10?", ["1024", "1000", "2048"], 0],
		["Welche Sprache entwickelte Niklaus Wirth an der ETH?", ["Pascal", "C", "Java"], 0],
		["Was ist ein Deadlock?", ["Prozesse warten gegenseitig ewig", "Ein abgestürzter Server", "Ein voller Speicher"], 0],
	],
}


# ------------------------------------------------------------------ Moodle tasks
# "num": type a number. "expr": write the return expression of a tiny function; it is run against the tests.
const MOODLE := {
	"MAVT": {"course": "Mechanik I – Übungsserie 4", "tasks": [
		{"type": "num", "q": "Ein Körper mit m = 4 kg wird mit a = 3 m/s^2 beschleunigt. Wie gross ist die Kraft F in N?", "a": 12.0},
		{"type": "num", "q": "Ableitung von f(x) = x^3 an der Stelle x = 2?", "a": 12.0},
		{"type": "num", "q": "Hebel: 20 N wirken bei 0.5 m. Welche Kraft (in N) hält bei 2 m das Gleichgewicht?", "a": 5.0},
		{"type": "num", "q": "Integral von 0 bis 2 über 2x dx?", "a": 4.0},
		{"type": "num", "q": "Druck p = F / A mit F = 500 N und A = 0.25 m^2. Wie viel Pa?", "a": 2000.0},
	]},
	"ITET": {"course": "Netzwerke und Schaltungen – Serie 2", "tasks": [
		{"type": "num", "q": "U = 12 V, R = 4 Ohm. Wie gross ist der Strom I in A?", "a": 3.0},
		{"type": "num", "q": "P = U · I mit U = 230 V und I = 2 A. Leistung in W?", "a": 460.0},
		{"type": "num", "q": "6 Ohm und 3 Ohm parallel geschaltet. Gesamtwiderstand in Ohm?", "a": 2.0},
		{"type": "num", "q": "Die Binärzahl 1011 als Dezimalzahl?", "a": 11.0},
		{"type": "num", "q": "Frequenz f = 50 Hz. Periodendauer T in ms?", "a": 20.0},
	]},
	"D-INFK": {"course": "Einführung in die Programmierung – Serie 5", "tasks": [
		{"type": "expr", "q": "Gib true zurück, wenn n gerade ist.", "sig": "func ist_gerade(n):", "vars": ["n"],
			"tests": [[0], [3], [8], [-5], [14]], "ref": "n % 2 == 0", "hint": "Der Rest beim Teilen durch 2 ist bei geraden Zahlen 0. Operator: %"},
		{"type": "expr", "q": "Berechne 1 + 2 + … + n ohne Schleife.", "sig": "func summe(n):", "vars": ["n"],
			"tests": [[1], [4], [10], [100]], "ref": "n * (n + 1) / 2", "hint": "Der junge Gauss: n mal (n + 1), geteilt durch 2."},
		{"type": "expr", "q": "Gib die grösste der drei Zahlen zurück.", "sig": "func maximum(a, b, c):", "vars": ["a", "b", "c"],
			"tests": [[1, 5, 3], [9, 2, 4], [-1, -7, -3], [2, 2, 8]], "ref": "max(a, max(b, c))", "hint": "Es gibt die Funktion max(x, y)."},
		{"type": "expr", "q": "Gib die letzte Ziffer von n zurück (n >= 0).", "sig": "func letzte_ziffer(n):", "vars": ["n"],
			"tests": [[7], [123], [90], [4056]], "ref": "n % 10", "hint": "Der Rest beim Teilen durch 10."},
		{"type": "expr", "q": "Ist y ein Schaltjahr? Durch 4 teilbar, aber nicht durch 100 – ausser durch 400.", "sig": "func schaltjahr(y):", "vars": ["y"],
			"tests": [[2024], [1900], [2000], [2023], [2100]], "ref": "(y % 4 == 0 and y % 100 != 0) or y % 400 == 0", "hint": "Verknüpfe Bedingungen mit and / or."},
		{"type": "expr", "q": "Wie viele Sekunden haben h Stunden?", "sig": "func sekunden(h):", "vars": ["h"],
			"tests": [[1], [2], [24]], "ref": "h * 3600", "hint": "Eine Stunde hat 60 · 60 Sekunden."},
	]},
}


# ------------------------------------------------------------------ day tasks (station rects in tiles)
const DAY_TASKS := {
	"MAVT": [
		{"id": "weld", "name": "Getriebe schweissen", "where": "Labor", "label": "Schweissnaht setzen", "game": "timing",
			"params": {"title": "Getriebe schweissen", "hits": 4, "verb": "Schweisspunkt"}, "rect": Rect2(71, 51, 6, 1.1)},
		{"id": "quiz", "name": "Statik-Quiz", "where": "Bibliothek", "label": "Quiz lösen", "game": "quiz",
			"params": {"title": "Statik-Quiz", "count": 3}, "rect": Rect2(75, 34.2, 3.6, 1.2)},
		{"id": "moodle", "name": "Mechanik im Moodle", "where": "Seminarraum-PC", "label": "Moodle öffnen", "game": "moodle",
			"params": {"count": 3}, "rect": Rect2(39.6, 23.6, 3.6, 0.7)},
		{"id": "coffee", "name": "Kaffee für den Prof", "where": "Mensa", "label": "Kaffee holen", "game": "timing",
			"params": {"title": "Café Crème zapfen", "hits": 3, "verb": "Zapfen", "speed": 340.0}, "rect": Rect2(14, 75.1, 18, 0.95)},
	],
	"ITET": [
		{"id": "fuse", "name": "Sicherung flicken", "where": "Gang beim Labor", "label": "Sicherungskasten öffnen", "game": "wiring",
			"params": {"title": "Sicherungskasten", "wires": 4}, "rect": Rect2(67.5, 48.3, 0.45, 1.3)},
		{"id": "quiz", "name": "Elektrotechnik-Quiz", "where": "Bibliothek", "label": "Quiz lösen", "game": "quiz",
			"params": {"title": "Elektrotechnik-Quiz", "count": 3}, "rect": Rect2(80.8, 38.4, 3.6, 1.2)},
		{"id": "moodle", "name": "Schaltungsrechnung im Moodle", "where": "Bibliothek, Katalog-PC", "label": "Moodle öffnen", "game": "moodle",
			"params": {"count": 3}, "rect": Rect2(69.3, 29.8, 3.9, 1.0)},
		{"id": "board", "name": "Platine verdrahten", "where": "Labor", "label": "Platine verdrahten", "game": "wiring",
			"params": {"title": "Platine", "wires": 5}, "rect": Rect2(79, 57.6, 6, 1.1)},
	],
	"D-INFK": [
		{"id": "server", "name": "Server neustarten", "where": "Labor, Serverschrank", "label": "Server-Konsole", "game": "sequence",
			"params": {"title": "Server-Neustart", "length": 5}, "rect": Rect2(85.6, 48.2, 1.2, 3.0)},
		{"id": "quiz", "name": "Algorithmen-Quiz", "where": "Seminarraum", "label": "Quiz lösen", "game": "quiz",
			"params": {"title": "Algorithmen-Quiz", "count": 3}, "rect": Rect2(39.6, 25.9, 3.6, 0.7)},
		{"id": "moodle", "name": "Code-Aufgaben im Moodle", "where": "Bibliothek, Katalog-PC", "label": "Moodle öffnen", "game": "moodle",
			"params": {"count": 2}, "rect": Rect2(69.3, 29.8, 3.9, 1.0)},
		{"id": "moodle2", "name": "Bonus-Code im Labor", "where": "Labor, Messplatz-PC", "label": "Moodle öffnen", "game": "moodle",
			"params": {"count": 2, "offset": 2}, "rect": Rect2(79, 51, 6, 1.1)},
	],
}
