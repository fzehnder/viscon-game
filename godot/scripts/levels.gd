extends RefCounted
## Story levels, in order. `current` is the level that is running (set by the Game autoload).
## Level 1 is the Ersti-Tag (day): two players, no guards, a crowd of Erstis.
## Every player has to do every task. Tasks with "spots" can be done at any of those places
## (rects in tiles, 1 tile = 32 px). "coop" tasks have no fixed place, a "bag" task is done by
## stealing the bag of one of the "npcs" (opp.gd).
##
## Every further level lives in its own folder: scripts/level<N>/level.gd (plus whatever else it
## needs). The folders are found by themselves, nothing has to be registered here. That way levels
## can be built in parallel on separate branches without touching shared files, and a branch that
## only has level 1 and level 3 simply plays 1 -> 3.
## level.gd has the definition `DEF` (like LEVEL1 below), optionally `static func build_map(md)`
## for its furniture, and is itself the logic node that main.gd adds to the world: tasks of type
## "level" are handled there (see the hooks in main.gd and godot/README.md).

const MAX_LEVEL := 20
const LEVEL_PATH := "res://scripts/level%d/level.gd"

static var current := 1
static var _scripts := {}       # level number -> script of that level (not for level 1)
static var _numbers: Array = []   # level numbers that exist, ascending

const LEVEL1 := {
	"name": "Ersti-Tag",
	"tag": "LEVEL 1",
	"mode": "day",
	"time": 420.0,
	# how the level shows up in the transcript (transcript.gd); all three are optional
	"course": "252-0001-00 L", "ects": 6, "block": "A",
	"start": Vector2(26.0, 42.0),        # crowd centre on the Polyterrasse
	"speaker": Vector2(36.5, 45.5),      # the crowd faces the entrance of the main building
	"crowd": 26,                          # Erstis in the welcome crowd
	"bags": 0,                            # Erstis in the crowd who carry a bag to steal ("steal" task, not used any more)
	"gather": 7.0,                        # seconds the crowd stays together after the start
	"intro": "Willkommen an der ETH! Ihr steht mitten in der Ersti-Menge auf der Polyterrasse. Beide müssen alles erledigen:",
	"start_toast": ["Willkommen, Erstis!", "Deniz und Livia sitzen am Lesetisch in der Bibliothek, ihre Ersti-Bags stehen neben dem Stuhl. Leise von hinten heran, nicht rennen!"],
	# People who can turn into Opps (opp.gd). Two Erstis at a reading table, each with an Ersti bag
	# next to the chair: steal it unseen and they notice a little later, get seen and they are
	# after you at once.
	"npcs": [
		{"id": "rucksack_a", "name": "Deniz", "pos": Vector2(74.93, 31.15), "face": -PI / 2.0, "mode": "sitzt",
			"bag": Vector2(75.65, 31.3), "bag_acc": "erstibag", "bag_name": "Ersti-Bag", "hears": true},
		{"id": "rucksack_b", "name": "Livia", "pos": Vector2(76.83, 31.15), "face": -PI / 2.0, "mode": "sitzt",
			"bag": Vector2(77.55, 31.3), "bag_acc": "erstibag", "bag_name": "Ersti-Bag", "hears": true},
	],
	"tasks": [
		{"id": "ersti", "name": "Ersti-Bag klauen", "where": "bei Deniz und Livia am Lesetisch (Bibliothek)", "type": "bag"},
		{"id": "legi", "name": "Legi validieren", "where": "Terminals in der Haupthalle", "label": "Legi validieren",
			"game": "timing", "params": {"title": "Legi validieren", "hits": 3, "verb": "Scan", "speed": 260.0},
			"kind": "legi_terminal",
			"spots": [Rect2(50.6, 43.05, 0.8, 1.0), Rect2(62.1, 43.05, 0.8, 1.0), Rect2(51.0, 47.95, 0.8, 1.0)]},
		{"id": "setup", "name": "Moodle & Code Expert", "where": "PCs in Bibliothek und Seminarraum", "label": "PC benutzen",
			"game": "setup", "params": {"title": "Moodle & Code Expert einrichten"},
			"kind": "station",
			"spots": [Rect2(69.4, 33.7, 3.9, 1.0), Rect2(39.3, 23.3, 2.6, 0.7), Rect2(79.4, 32.6, 3.6, 1.2)]},
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


## Level numbers that exist in this checkout, ascending. Level 1 is always there.
static func numbers() -> Array:
	if _numbers.is_empty():
		_numbers = [1]
		for n in range(2, MAX_LEVEL + 1):
			if ResourceLoader.exists(LEVEL_PATH % n):
				_scripts[n] = load(LEVEL_PATH % n)
				_numbers.append(n)
	return _numbers


static func has_level(n: int) -> bool:
	return numbers().has(n)


## The story level that follows `n`, or -1 if `n` is the last one. Electives are never next,
## and after an elective there is no next level either.
static func next_after(n: int) -> int:
	if is_elective(n):
		return -1
	for k in numbers():
		if k > n and not is_elective(k):
			return k
	return -1


## Electives ("block": "W" in DEF) are optional levels outside the story: started from the
## transcript at any time, they do not reset Opps or items of the story (Game.begin_level).
static func is_elective(n: int) -> bool:
	return has_level(n) and String(level(n).get("block", "")) == "W"


static func _script_of(n: int) -> GDScript:
	numbers()
	return _scripts.get(n)


## Definition of level `n` (default: the running level).
static func level(n: int = -1) -> Dictionary:
	var sc := _script_of(current if n < 0 else n)
	return LEVEL1 if sc == null else sc.DEF


## The logic node of the running level, or null if the level needs none (level 1).
static func new_logic() -> Node:
	var sc := _script_of(current)
	return null if sc == null else sc.new()


## Lets the running level change the map (md = map_data.gd, called at the end of build()).
static func build_map(md) -> void:
	var sc := _script_of(current)
	if sc == null:
		return
	for m in sc.get_script_method_list():
		if m["name"] == "build_map":
			sc.build_map(md)
			return


static func tasks() -> Array:
	return level()["tasks"]


static func task(id: String) -> Dictionary:
	for tk in tasks():
		if tk["id"] == id:
			return tk
	return {}
