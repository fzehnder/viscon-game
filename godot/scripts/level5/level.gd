extends Node2D
## Level 5 · Nacht im HIL (Hönggerberg). With the professor's badge from the Polyball (Game item
## "prof_badge", level 3) the players break into the HIL (architecture) at night. The graded
## submissions of the design studio are in the professor's office, and on his computer each of them
## changes the name on a submission with a 6 to their own (grade_pc.gd). Then they get away on the ETH-Link bus.
## The building is guarded: the security staff patrol with flashlights (professor.gd: cone,
## suspicion bar, they hear footsteps), whoever they see is caught and the level is lost. Lockers,
## model crates and cabinets hide you ("use": "hide", handled by main.gd).
## Without the badge (level 3 not played in this game) a spare card waits in the caretaker's lodge.
##
## The level brings its own map (build_map clears the Zentrum and builds the campus) and draws it
## at night (md.mode = "night"), while the game itself runs as a day level with tasks.

const TS := 32.0
const MD = preload("res://scripts/map_data.gd")
const ProfScript = preload("res://scripts/professor.gd")
const PcScript = preload("res://scripts/level5/grade_pc.gd")
const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")
const Cutscene = preload("res://scripts/cutscene.gd")

const BADGE_ITEM := "prof_badge"
const GUARD_SPEED_UP := 1.25        # guards once both grades are changed: this much faster ...
const GUARD_RANGE_UP := 1.0         # ... and they see this many tiles further
const BUS := Rect2(38.0, 76.3, 16.0, 2.5)        # where the ETH-Link stands (tiles)
const BUS_DOOR := Rect2(44.5, 73.4, 3.0, 1.4)    # step in here

const DEF := {
	"name": "Nacht im HIL",
	"sky": "night",      # the loading screen: the ETH-Link drives up at night
	"tag": "LEVEL 5 · NACHT",
	"mode": "day",       # tasks and hooks like a day level; the map is drawn at night (build_map)
	"time": 480.0,
	"course": "052-0005-00 L", "ects": 6, "block": "B",
	"start": Vector2(46.0, 72.4),
	"intro": "Mitternacht am Hönggerberg. Mit der Karte, die ihr dem Prof am Polyball abgenommen habt, kommt ihr ins HIL. Im Büro des Profs ganz im Westen des Nordflügels liegen die bewerteten Abgaben, und auf seinem Computer die Notenliste. Jede*r von euch ändert den Namen auf einer Abgabe mit der 6 in den eigenen. Dann verschwindet ihr und steigt in den letzten ETH-Link.\n\nDer Sicherheitsdienst patrouilliert mit Taschenlampen, im schmalen Gang des Nordflügels gleich zu zweit. Wer gesehen wird, fliegt. Duckt euch in die Büros. Schleichen ist leise, Rennen hört man weit. In Schränken und Modellkisten sieht euch niemand.",
	"hint": "Schleichen: C bzw. -. Verstecken und wieder raus: E bzw. Enter.",
	"start_toast": ["Hönggerberg, 00:12", "Neben dem Haupteingang ist eine Tür mit Kartenleser. Haltet euch vom Licht der Taschenlampen fern."],
	"timer_title": "BIS ZUM LETZTEN ETH-LINK",
	"win_title": "Zwei Sechser!",
	"win_text": "%s & %s sitzen im letzten ETH-Link. Auf der Notenliste stehen jetzt ihre Namen neben der 6.",
	"lose_title": "Letzten ETH-Link verpasst",
	"lose_text": "Der letzte ETH-Link ist weg, und der Sicherheitsdienst macht die Morgenrunde.",
	"tasks": [
		{"id": "badge", "name": "Zugang mit Karte", "where": "Prof-Karte vom Polyball, sonst Campus Info", "type": "level"},
		{"id": "grades", "name": "Namen bei der 6 ändern", "where": "Computer im Büro des Profs (Ostflügel)", "type": "level"},
		{"id": "bus", "name": "In den ETH-Link einsteigen", "where": "Haltestelle vor dem HIL", "type": "level"},
	],
	# Opps from earlier levels pull an all-nighter in the drawing studio
	# Opps from earlier levels pull an all-nighter in the drawing studio of the east block
	"opp_spots": [
		{"pos": Vector2(94.5, 34.4), "face": PI / 2.0, "mode": "lauert"},
		{"pos": Vector2(97.0, 44.4), "face": -PI / 2.0, "mode": "lauert"},
		{"pos": Vector2(93.6, 46.8), "face": -PI / 2.0, "mode": "lauert"},
	],
}

# Security staff (made up): patrol points in tiles. Uniform look, flashlight.
const GUARDS := [
	{"name": "Wachmann Gerber", "speed": 48.0, "range": 6.5, "pmin": 1.0, "pmax": 2.5,
		"quote": "Halt! Der Campus ist um diese Zeit geschlossen.",
		"pts": [Vector2(32.5, 65.5), Vector2(60.5, 65.5), Vector2(60.5, 58.5), Vector2(32.5, 58.5)]},
	{"name": "Wachfrau Brühlmann", "speed": 50.0, "range": 6.0,
		"quote": "Was machen Sie im HIL? Ausweis, bitte!",
		"pts": [Vector2(42.5, 53.5), Vector2(42.5, 26.5), Vector2(42.5, 53.5), Vector2(52.5, 50.5), Vector2(61.5, 50.5), Vector2(61.5, 27.0), Vector2(61.5, 50.5), Vector2(52.5, 50.5)]},
	{"name": "Wachmann Lüthi", "speed": 52.0, "range": 6.0, "pmin": 1.2, "pmax": 3.0,
		"quote": "Hier ist nachts niemand. Ausser Ihnen, offenbar.",
		"pts": [Vector2(18.5, 16.5), Vector2(97.5, 16.5)]},
	{"name": "Wachfrau Keller", "speed": 46.0, "range": 6.0, "pmin": 2.0, "pmax": 4.0,
		"quote": "Finger weg von den Unterlagen der Professur!",
		"pts": [Vector2(60.5, 16.5), Vector2(20.5, 16.5), Vector2(60.5, 16.5), Vector2(96.5, 16.5)]},
	{"name": "Nachtwächter Ammann", "speed": 48.0, "range": 6.0,
		"quote": "Auch Architekturstudis müssen irgendwann schlafen. Raus hier!",
		"pts": [Vector2(66.5, 39.5), Vector2(89.5, 39.5), Vector2(95.9, 44.9), Vector2(95.9, 34.9), Vector2(89.5, 39.5)]},
]
const GUARD_LOOK := {"skin": "d9a37e", "hair": "2b2018", "hair_style": "cap", "top": "1f2a3a", "top_style": "jacket",
	"accent": "f2c14e", "pants": "1f2a3a", "shoes": "111111", "acc": ["flashlight"]}

var main            # main.gd, set before _ready
var started := false
var rows: Array = PcScript.make_rows()   # the grade list on the professor's computer
var restless := false
var boarded: Array = [false, false]
var guards: Array = []
var t := 0.0


## The campus Hönggerberg instead of the Zentrum, the HIL after its real ground floor, simplified
## and tight: a long north wing with a narrow corridor between rows of small offices, the
## professor's office at the far west end, the atrium in the middle with the gta exhibition,
## the alumni lounge and the foyer, the east block with offices and the drawing studio, the
## campus info and the bus stop in the south. Positions in tiles.
static func build_map(md) -> void:
	md.map.fill(MD.GRASS)
	md.objs.clear()
	md.doors.clear()
	md.labels.clear()
	md.lamps.clear()
	md.profs.clear()
	md.student_zones.clear()
	md.mode = "night"
	# --- road, bus stop, the square in front of the building ---
	md.fill(0, 76, 111, 79, MD.ROAD)
	md.fill(0, 74, 111, 75, MD.WALK)
	md.fill(0, 80, 111, 81, MD.WALK)
	md.fill(34, 72, 58, 73, MD.PAVE)               # bus stop
	md.fill(28, 57, 74, 71, MD.PAVE)               # square
	md.fill(44, 56, 49, 56, MD.PAVE)
	# --- campus info, its side door is open ---
	md.box(62, 60, 72, 68, MD.STONE)
	md.fill(62, 63, 62, 64, MD.STONE)
	# --- north wing: offices | corridor (16..17) | rooms ---
	md.box(8, 8, 100, 24, MD.TILE)
	md.fill(9, 15, 99, 15, MD.WALL)
	md.fill(9, 18, 99, 18, MD.WALL)
	for x in range(20, 100, 5):                    # small offices along the north
		md.fill(x, 9, x, 14, MD.WALL)
		md.fill(x - 3, 15, x - 3, 15, MD.TILE)      # their doors
	md.fill(97, 15, 97, 15, MD.TILE)
	for x in range(22, 100, 6):                    # rooms along the south
		md.fill(x, 19, x, 23, MD.WALL)
		md.fill(x - 3, 18, x - 3, 18, MD.TILE)
	md.fill(19, 18, 19, 18, MD.TILE)
	md.fill(97, 18, 97, 18, MD.TILE)                # the last room has a door too
	md.fill(9, 9, 14, 23, MD.CARPET)               # the professor's office, west end
	md.fill(15, 9, 15, 23, MD.WALL)
	md.fill(15, 16, 15, 17, MD.CARPET)             # its door (locked, see below)
	md.fill(41, 18, 45, 24, MD.TILE)               # passage down to the atrium (west)
	md.fill(41, 18, 41, 23, MD.WALL)
	md.fill(45, 19, 45, 24, MD.WALL)
	md.fill(42, 18, 44, 18, MD.TILE)
	md.fill(59, 18, 63, 24, MD.TILE)               # passage down (east)
	md.fill(59, 19, 59, 24, MD.WALL)
	md.fill(64, 19, 64, 23, MD.WALL)
	md.fill(60, 18, 63, 18, MD.TILE)
	# --- middle: gta exhibition, atrium, alumni lounge, foyer ---
	md.box(28, 24, 64, 56, MD.TILE)
	md.fill(42, 24, 44, 24, MD.TILE)
	md.fill(60, 24, 63, 24, MD.TILE)
	md.fill(29, 25, 40, 44, MD.MARBLE)             # gta exhibition
	md.fill(41, 25, 41, 45, MD.WALL)
	md.fill(41, 33, 41, 34, MD.MARBLE)
	md.fill(29, 45, 41, 45, MD.WALL)
	md.fill(29, 46, 40, 55, MD.CARPET)             # alumni lounge
	md.fill(41, 46, 41, 55, MD.WALL)
	md.fill(41, 50, 41, 51, MD.CARPET)
	md.box(45, 25, 59, 42, MD.GRASS)               # the atrium: a closed courtyard
	md.fill(42, 43, 63, 55, MD.MARBLE)             # foyer
	md.fill(60, 25, 63, 42, MD.TILE)
	md.fill(63, 25, 63, 42, MD.WALL)
	# --- east block: offices | corridor (39..40) | rooms, drawing studio at the end ---
	md.box(64, 30, 100, 50, MD.TILE)
	md.fill(65, 38, 90, 38, MD.WALL)
	md.fill(65, 41, 90, 41, MD.WALL)
	for x in range(70, 91, 5):
		md.fill(x, 31, x, 37, MD.WALL)
		md.fill(x - 3, 38, x - 3, 38, MD.TILE)
	for x in range(71, 91, 6):
		md.fill(x, 42, x, 49, MD.WALL)
		md.fill(x - 3, 41, x - 3, 41, MD.TILE)
	md.fill(90, 42, 91, 49, MD.WALL)
	md.fill(91, 31, 91, 41, MD.WALL)
	md.fill(91, 39, 91, 40, MD.WOOD)
	md.fill(92, 31, 99, 49, MD.WOOD)              # drawing studio
	md.fill(63, 39, 64, 40, MD.TILE)               # from the east corridor of the middle part
	# --- doors: main entrance locked, side door with the card reader, office with the card ---
	md.R("locked_door", 50, 56, 4, 1, {"door": "main", "use": "info", "label": "Haupteingang prüfen",
		"info": ["Haupteingang", "Nachts zu. Daneben ist eine Tür mit Kartenleser."]})
	md.fill(44, 56, 45, 56, MD.MARBLE)
	md.R("l5_door", 44, 56, 2, 1, {"door": "entry", "use": "level", "act": "door", "label": "Karte an den Leser halten", "side": "h"})
	md.R("l5_door", 15, 16, 1, 2, {"door": "office", "use": "level", "act": "door", "label": "Karte an den Leser halten", "side": "v"})
	# --- the professor's office ---
	md.R("l5_abgaben", 9.2, 9.05, 5.4, 0.9, {"use": "info", "label": "Abgaben ansehen",
		"info": ["Die Abgaben", "Modelle und Pläne, jede mit einem Zettel: Name und Note. Die Noten stehen auch im Computer."]})
	md.R("l5_desk", 9.2, 18.4, 3.4, 1.4, {"use": "level", "act": "pc", "label": "Computer des Profs benutzen"})
	md.R("locker", 13.6, 22.05, 1.2, 0.95, {"use": "hide", "label": "In den Garderobenschrank"})
	md.R("shelf", 9.1, 12.0, 0.9, 4.0)
	# --- small offices: desks, and in some of them a cupboard to hide in ---
	var k := 0
	for x in range(20, 100, 5):
		if x + 1 < 99:
			md.R("labdesk", x + 1.2, 9.1, 2.6, 1.0)
		if k % 2 == 0 and x + 4 < 100:
			md.R("locker", x + 3.6, 13.05, 1.2, 0.9, {"use": "hide", "label": "In den Büroschrank"})
		k += 1
	for x in range(22, 100, 6):
		if x in [40, 58, 64]:
			continue
		if x + 5 < 100:
			md.R("labdesk", x + 1.4, 22.1, 3.2, 0.9)
		if (x / 6) % 2 == 1 and x + 5 < 100:
			md.R("cabinet", x + 4.4, 19.05, 1.4, 0.9, {"use": "hide", "label": "In den Aktenschrank"})
	md.R("l5_closet", 17.2, 19.1, 1.4, 0.9, {"use": "hide", "label": "In den Putzschrank"})
	# --- gta exhibition: tall display walls, a crate ---
	for y: float in [27.0, 32.0, 37.0]:
		md.R("l5_panel", 31.0, y, 6.0, 0.6, {"tall": true})
	md.R("l5_crate", 38.6, 42.6, 1.8, 1.2, {"use": "hide", "label": "In die Transportkiste kriechen"})
	# --- alumni lounge ---
	md.R("sofa", 30.0, 47.5, 3.0, 1.0)
	md.R("sofa", 30.0, 52.5, 3.0, 1.0)
	md.R("l5_closet", 38.8, 53.9, 1.4, 1.0, {"use": "hide", "label": "In den Garderobenschrank"})
	# --- foyer ---
	md.R("infodesk", 50.0, 47.5, 4.0, 1.2)
	md.R("l5_model", 55.0, 51.0, 3.0, 2.0)
	for x: float in [47.0, 57.0]:
		md.C("pillar", x, 45.0, 0.45)
	# --- east block: offices, drawing studio ---
	var j := 0
	for x in range(70, 91, 5):
		md.R("labdesk", x - 3.8, 31.1, 2.6, 1.0)
		if j % 2 == 1:
			md.R("locker", x - 1.6, 36.05, 1.2, 0.9, {"use": "hide", "label": "In den Büroschrank"})
		j += 1
	for x: float in [93.0, 96.4]:
		for y: float in [32.4, 36.4, 42.4, 46.4]:
			md.R("l5_drafting", x, y, 2.8, 1.3)
	md.R("l5_crate", 97.8, 39.0, 1.6, 1.2, {"use": "hide", "label": "In die Modellkiste kriechen"})
	# --- campus info: the spare card ---
	md.R("l5_keybox", 70.2, 61.1, 1.6, 0.8, {"use": "level", "act": "keybox", "label": "Ersatzkarte nehmen"})
	md.R("counter", 64.5, 65.5, 4.0, 1.2)
	# --- bus stop ---
	md.R("l5_shelter", 36.0, 71.2, 5.0, 0.8)
	md.R("l5_busdoor", BUS_DOOR.position.x, BUS_DOOR.position.y, BUS_DOOR.size.x, BUS_DOOR.size.y,
		{"use": "level", "act": "bus", "label": "In den ETH-Link einsteigen", "solid": false})
	# --- outside ---
	for x: float in [30.0, 37.0, 66.0, 74.0, 82.0, 90.0, 98.0]:
		md.C("tree", x, 69.5, 0.9, {"hitr": 0.3})
	for y: float in [28.0, 36.0, 44.0, 52.0, 60.0]:
		md.C("tree", 104.0, y, 0.8, {"hitr": 0.3})
		md.C("tree", 4.0, y, 0.8, {"hitr": 0.3})
	md.R("bench", 52.0, 66.0, 2.0, 0.6)
	for x in range(4, 110, 9):
		md.lamp(x + 0.5, 74.6, 3.0, Color(1.0, 0.8, 0.45))
	for x: float in [32.0, 44.0, 58.0, 70.0]:
		md.lamp(x, 59.0, 3.0, Color(1.0, 0.85, 0.55))
	md.lamp(44.8, 57.4, 2.0, Color(1.0, 0.85, 0.55))       # over the side door
	md.lamp(67.0, 63.0, 2.6, Color(1.0, 0.9, 0.6))         # campus info
	md.lamp(52.0, 49.0, 3.2, Color(0.75, 0.85, 1.0))       # foyer night light
	md.lamp(11.0, 18.0, 2.4, Color(0.75, 0.85, 1.0))       # the professor's screen
	md.lamp(95.5, 40.0, 3.4, Color(1.0, 0.9, 0.7))         # drawing studio: somebody is still working
	# --- labels and zones ---
	md.L("HIL · ARCHITEKTUR", 51.0, 61.5, 0.6, "floor")
	md.L("ATRIUM", 52.0, 33.5, 0.5, "floor")
	md.L("GTA AUSSTELLUNG", 35.0, 41.0, 0.32, "floor")
	md.L("ALUMNI LOUNGE", 35.0, 50.5, 0.32, "floor")
	md.L("FOYER", 52.0, 53.5, 0.45, "floor")
	md.L("BÜRO PROF", 11.8, 15.6, 0.28, "floor")
	md.L("ZEICHENSAAL", 95.6, 40.6, 0.3, "floor")
	md.L("CAMPUS INFO", 67.0, 66.8, 0.3, "floor")
	md.L("ETH-LINK", 46.0, 72.5, 0.34, "floor")
	md.zones = [
		[Rect2(9, 9, 6, 15), "Büro der Professur"], [Rect2(9, 16, 91, 2), "Gang Nordflügel"],
		[Rect2(9, 9, 91, 15), "Nordflügel"], [Rect2(29, 25, 12, 20), "gta Ausstellung"],
		[Rect2(29, 46, 12, 10), "Alumni Lounge"], [Rect2(42, 43, 22, 13), "Foyer HIL"],
		[Rect2(42, 25, 3, 18), "Gang am Atrium"], [Rect2(60, 25, 3, 18), "Gang am Atrium"],
		[Rect2(92, 31, 8, 19), "Zeichensaal"], [Rect2(65, 31, 26, 19), "Ostblock"],
		[Rect2(62, 60, 11, 9), "Campus Info"], [Rect2(30, 70, 30, 12), "Haltestelle ETH-Link"],
		[Rect2(0, 0, 112, 84), "Campus Hönggerberg"],
	]


func _ready() -> void:
	z_index = -5   # own drawing above the map, below the figures
	for g in GUARDS:
		var pr = ProfScript.new()
		pr.setup(g, main.world, main)
		pr.look = GUARD_LOOK.duplicate(true)
		main.actors.add_child(pr)
		main.profs.append(pr)
		guards.append(pr)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if main.state != "play":
		return
	if not started:
		started = true
		if Game.has_item(BADGE_ITEM):
			main._coop_done("badge")
			main.hud.toast("Die Prof-Karte vom Polyball", "Sie öffnet die Tür neben dem Haupteingang und das Büro des Profs.", 5.0)
		else:
			main.hud.toast("Keine Prof-Karte", "Ohne die Karte vom Polyball bleibt nur die Ersatzkarte in der Campus Info neben der Haltestelle.", 6.0)


# ------------------------------------------------------------------ interaction
func interact(pid: int, o: Dictionary) -> void:
	match String(o.get("act", "")):
		"door":
			if not main.done[pid].has("badge"):
				UI.sfx("buzz")
				main.hud.toast("Rotes Licht", "Der Leser will eine Karte. Die Ersatzkarte liegt in der Campus Info.", 3.5, pid)
				return
			main.world.open_door(String(o["door"]))
			UI.sfx("grant")
			main.hud.toast("Grünes Licht", "Die Tür summt und springt auf.", 2.5, pid)
		"keybox":
			o["taken"] = true
			main._coop_done("badge")
			UI.sfx("steal")
		"pc":
			if main.done[pid].has("grades"):
				main.hud.toast("Erledigt", "Deine 6 ist schon gespeichert.", 2.0, pid)
				return
			if main.busy(1 - pid) and main.minis[1 - pid] is PcScript:
				main.hud.toast("Besetzt", "%s sitzt schon am Computer." % Game.name_of(1 - pid), 2.0, pid)
				return
			_open_pc(pid)
		"bus":
			if not main.done[pid].has("grades"):
				main.hud.toast("Noch nicht", "Erst steht dein Name bei der 6, dann fahren wir heim.", 2.5, pid)
				return
			_board(pid)


## The grade list on this player's half of the screen, like a minigame (main.minis).
func _open_pc(pid: int) -> void:
	var pc = PcScript.new()
	pc.pid = pid
	pc.main = main
	main.minis[pid] = pc
	main.nears[pid] = null
	main.players[pid].enabled = false
	main.add_child(pc)
	pc.open(rows)
	pc.mistake.connect(func():
		# the computer beeps: the guards hear it
		main.mistakes_total += 1
		main.make_noise(main.players[pid].global_position, 7.0 * TS)
		main.fx.sound(main.players[pid].global_position, 7.0 * TS, Color(1.0, 0.4, 0.4, 0.7), 0.8))
	pc.finished.connect(func(ok: bool, _m: int):
		if main.minis[pid] == pc:
			main.minis[pid] = null
		if main.state != "play":
			return
		main.players[pid].enabled = true
		if ok:
			main._task_done(pid, "grades")
			_check_restless())


## Both names are in: the guards get restless, faster and further.
func _check_restless() -> void:
	if restless or not (main.done[0].has("grades") and main.done[1].has("grades")):
		return
	restless = true
	for g in guards:
		g.speed *= GUARD_SPEED_UP
		g.range_px += GUARD_RANGE_UP * TS
	main.hud.toast("Beide Sechser gespeichert", "Irgendwo knallt eine Tür. Der Sicherheitsdienst ist jetzt wacher. Raus und ab in den ETH-Link!", 5.0)


func _board(pid: int) -> void:
	if boarded[pid]:
		return
	boarded[pid] = true
	var pl = main.players[pid]
	pl.hidden_mode = true
	pl.enabled = false
	pl.visible = false
	UI.sfx("pop")
	main._task_done(pid, "bus")
	if not (boarded[0] and boarded[1]):
		main.hud.toast("Im ETH-Link", "%s wartet drin. Fehlt nur noch %s." % [Game.name_of(pid), Game.name_of(1 - pid)], 3.5)


## Diamonds on the map for the tasks, in the colour of who still needs them.
func goal_positions(id: String, n0: bool, n1: bool) -> Array:
	var col: Color = main._need_color(n0, n1)
	var out: Array = []
	for p in task_targets(id, -1):
		out.append([p, col])
	return out


func task_targets(id: String, _pid: int) -> Array:
	match id:
		"badge":
			return [Vector2(71.0, 62.4) * TS]
		"grades":
			return [Vector2(10.9, 20.4) * TS]
		"bus":
			return [BUS_DOOR.get_center() * TS]
	return []


## The bus leaves with both of them on board.
func finale(done: Callable) -> void:
	main.state = "cutscene"
	main.hud.visible = false
	var steps := [
		{"say": 0, "text": "Zwei Sechser im Entwurf. Und niemand hat uns gesehen."},
		{"say": 1, "text": "Fast niemand. Der Wachmann am Eingang hat sehr komisch geschaut."},
		{"phones": "ETH-Link", "text": "Letzte Fahrt ab ETH Hönggerberg: 00:41"},
		{"phones": "myStudies", "text": "Neue Note verfügbar: Entwurf HS26"},
		{"say": 0, "text": "Lea und Noah wundern sich morgen sicher ein bisschen."},
		{"title": "NOTE 6", "sub": "Hönggerberg  ·  00:41  ·  letzter ETH-Link"},
	]
	var cs = Cutscene.new()
	main.add_child(cs)
	cs.play(steps, func():
		main.state = "play"
		main.hud.visible = true
		done.call())


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if main == null or main.data.is_empty():
		return
	_draw_tracks()
	for o in main.data["objs"]:
		var k: String = o["kind"]
		if k.begins_with("l5_"):
			_draw_obj(o)
	_draw_bus()


func _draw_tracks() -> void:
	var x := 0.0
	while x < 112.0:   # dashed middle line of the road
		draw_rect(Rect2(x * TS, 77.9 * TS, 0.9 * TS, 3), Color(0.9, 0.88, 0.78, 0.6))
		x += 1.8
	draw_rect(Rect2(BUS.position.x * TS - 20, 76.1 * TS, BUS.size.x * TS + 40, 2), Color(1.0, 0.85, 0.3, 0.7))   # bus bay


## The ETH-Link at the stop: dark blue, white band, doors open, windows lit; who boarded sits inside.
func _draw_bus() -> void:
	var r := Rect2(BUS.position * TS, BUS.size * TS)
	draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, Color("1f407a"))
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 14, r.size.x, 8), Color("f4f6fa"))
	var n := int(BUS.size.x / 1.6)
	for i in n:
		var wx := r.position.x + 10 + i * 1.6 * TS
		draw_rect(Rect2(wx, r.position.y + 10, 1.1 * TS, 0.9 * TS), Color(1.0, 0.92, 0.65, 0.9))
	var d := Rect2(BUS_DOOR.position.x * TS, r.position.y - 2, BUS_DOOR.size.x * TS, 10)
	draw_rect(d, Color(1.0, 0.95, 0.7))
	for pid in 2:
		if boarded[pid]:
			var p := r.position + Vector2((5.5 + pid * 3.5) * TS, 1.3 * TS)
			ART.draw_character(self, main.players[pid].look, ART.FRONT, 0.0, false, p, 0.7)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(12, r.size.y - 18), "ETH-Link  ·  Zentrum", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("1f407a"))
	draw_circle(r.position + Vector2(r.size.x - 6, 10), 6.0, Color(1.0, 0.95, 0.7, 0.9))


func _draw_obj(o: Dictionary) -> void:
	var r: Rect2 = o["rect"]
	var R2 := Rect2(r.position * TS, r.size * TS)
	var x := R2.position.x
	var y := R2.position.y
	var w := R2.size.x
	var h := R2.size.y
	match String(o["kind"]):
		"l5_drafting":
			draw_rect(Rect2(x + 3, y + 4, w, h), Color(0, 0, 0, 0.3))
			draw_rect(R2, Color("d9d4c7"))
			draw_rect(Rect2(x + 4, y + 4, w * 0.45, h - 8), Color("f6f4ee"))
			for i in 3:
				draw_line(Vector2(x + 7, y + 8 + i * 8), Vector2(x + w * 0.4, y + 8 + i * 8), Color("8a93a6"), 1.0)
			# a white model of a building
			var mx := x + w * 0.6
			draw_rect(Rect2(mx, y + 6, 16, 18), Color("fbfaf5"))
			draw_rect(Rect2(mx + 18, y + 12, 12, 12), Color("ece8de"))
			draw_rect(Rect2(mx, y + 6, 16, 3), Color("c8c2b4"))
		"l5_crate":
			draw_rect(Rect2(x + 3, y + 4, w, h), Color(0, 0, 0, 0.35))
			draw_rect(R2, Color("b08a55"))
			draw_rect(R2, Color("7a5a32"), false, 2.0)
			draw_line(Vector2(x, y), Vector2(x + w, y + h), Color("7a5a32"), 2.0)
			draw_line(Vector2(x + w, y), Vector2(x, y + h), Color("7a5a32"), 2.0)
		"l5_closet":
			draw_rect(Rect2(x + 3, y + 4, w, h), Color(0, 0, 0, 0.35))
			draw_rect(R2, Color("7d8794"))
			draw_rect(Rect2(x + w / 2 - 1, y, 2, h), Color("4a5560"))
			draw_circle(Vector2(x + w / 2 - 5, y + h / 2), 2.0, Color("e8ecf0"))
		"l5_abgaben":
			# the submissions: rolled plans and small white models on a sideboard
			draw_rect(Rect2(x + 3, y + 4, w, h), Color(0, 0, 0, 0.35))
			draw_rect(R2, Color("6b4a33"))
			for i in 4:
				draw_rect(Rect2(x + 4 + i * w / 4.0, y + 3, w / 4.0 - 8, h - 6), Color("fbfaf5") if i % 2 == 0 else Color("dfe8f3"))
				draw_rect(Rect2(x + 4 + i * w / 4.0, y + h - 7, 8, 4), Color("f2c14e"))   # grade note
		"l5_desk":
			draw_rect(Rect2(x + 3, y + 4, w, h), Color(0, 0, 0, 0.3))
			draw_rect(R2, Color("6b4a33"))
			# the professor's computer, the screen glows
			var sc := Rect2(x + w * 0.3, y + 4, w * 0.4, h * 0.55)
			draw_rect(sc.grow(2), Color("1c1d22"))
			draw_rect(sc, Color(0.55, 0.75, 1.0, 0.75 + sin(t * 2.0) * 0.1))
			draw_rect(Rect2(x + w * 0.32, y + h * 0.7, w * 0.36, 5), Color("2b2f35"))     # keyboard
			draw_circle(Vector2(x + w - 12, y + 12), 7.0, Color(1.0, 0.9, 0.6, 0.9))   # desk lamp
		"l5_model":
			draw_rect(Rect2(x + 4, y + 5, w, h), Color(0, 0, 0, 0.3))
			draw_rect(R2, Color("e8e4da"))
			for i in 4:
				var bx := x + 6 + (i % 2) * w * 0.45
				var by := y + 6 + (i / 2) * h * 0.45
				draw_rect(Rect2(bx, by, w * 0.38, h * 0.36), Color("fbfaf5"))
				draw_rect(Rect2(bx, by, w * 0.38, 3), Color("c8c2b4"))
		"l5_pinboard":
			draw_rect(R2, Color("a7835a"))
			var px := x + 4
			var i := 0
			while px < x + w - 20:
				draw_rect(Rect2(px, y + 2, 22, h - 4), Color("f4f1e8") if i % 3 else Color("dfe8f3"))
				px += 28
				i += 1
		"l5_panel":
			draw_rect(Rect2(x + 3, y + 4, w, h), Color(0, 0, 0, 0.35))
			draw_rect(R2, Color("f3f2ef"))
			var px2 := x + 6
			while px2 < x + w - 30:
				draw_rect(Rect2(px2, y + 3, 26, h - 6), Color("c9d6e6"))
				px2 += 40
		"l5_keybox":
			draw_rect(R2, Color("5a3d2a"))
			if not o.get("taken", false):
				draw_rect(Rect2(x + w / 2 - 6, y + 4, 12, 8), Color("f2c14e"))
		"l5_shelter":
			draw_rect(Rect2(x, y - 10, w, h + 10), Color(0.6, 0.75, 0.9, 0.35))
			draw_rect(Rect2(x, y - 10, w, 4), Color("3b4a6b"))
			draw_rect(Rect2(x + w - 22, y - 30, 20, 20), Color("2f6fd6"))
			draw_string(ThemeDB.fallback_font, Vector2(x + w - 19, y - 14), "10", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		"l5_door":
			if o.get("opened", false):
				draw_rect(R2, Color(0.4, 0.8, 0.5, 0.25))
			else:
				draw_rect(R2, Color("5b6170"))
				draw_rect(R2, Color("2b2f35"), false, 2.0)
			# card reader next to the door, red or green
			var rc := R2.get_center() + (Vector2(-20, 0) if o.get("side", "h") == "v" else Vector2(0, 20))
			draw_rect(Rect2(rc - Vector2(5, 7), Vector2(10, 14)), Color("2b2f35"))
			draw_circle(rc + Vector2(0, -2), 2.5, UI.GREEN if o.get("opened", false) else UI.RED)
		"l5_busdoor":
			pass
