extends Node2D
## Level 6 · Bib in der Lernphase (day, two players). Definition (DEF), furniture (build_map), logic.
## July, the Lernphase, the middle of the day: the ETH library is packed, and the two players are
## the only ones who are not studying. Everything of this level lives in this folder (found by
## levels.gd through the folder name).
##
## The room is the library that is on the map anyway (north wing of the Hauptgebäude, map_data.gd).
## build_map only adds two study tables with chairs, the socket tower and backpacks.
##
## Whatever can be taken away uses the bag system of level 1 (opp.gd, "bag" in "npcs"): a
## reservation on a chair is the bag of somebody who is not there right now. The Opp system does
## the rest: seen = Opp at once, otherwise the owner notices after opp.NOTICE seconds and comes
## looking. main.gd knows a single "bag" task per level, so the tasks here are of type "level" and
## this file decides when one is done.
##
## People of this level who catch a player put that player in front of the library door (a
## mistake, the level goes on). Opps from earlier levels stay at the standard: the level is lost.
##
## All positions are in tiles (1 tile = 32 px) unless a name ends in _px.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const CH = preload("res://scripts/characters.gd")
const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const OPP = preload("res://scripts/opp.gd")
const Cutscene = preload("res://scripts/cutscene.gd")
const FehlerSpiel = preload("fehler_spiel.gd")
const FehlerCodes = preload("fehler_codes.gd")
const StarrSpiel = preload("starr_spiel.gd")
const AbschreibSpiel = preload("abschreib_spiel.gd")
const AbschreibCodes = preload("abschreib_codes.gd")
const Rucksack = preload("rucksack.gd")
const Schluss = preload("schluss.gd")

# ---- tuning (see README.md)
const SIT_TIME := 10.0                  # seconds a player has to stay seated for the seat to count
const REACH := 1.15                     # tiles: this close to a thing or a chair it can be used
const STUN := 1.4                       # seconds until you can move again after being put in front of the door
const OPP_CALM := 6.0                   # seconds somebody leaves you alone after putting you in front of the door
const PSST_TIME := 1.6                  # seconds a reader looks up and hisses after hearing something
const PAIR_DIST := 2.5                  # tiles: for what takes two, the other player has to be this close
const SPARK_TIME := 0.6                 # seconds the socket tower throws sparks after a wrong plug
const READER_SEED := 2026               # the readers look the same every time

# ---- places
const LIB := "ETH-Bibliothek"           # zone name of the library in map_data.gd
const EJECT := Vector2(66.2, 27.9)      # in the corridor, in front of the west door of the library
const PCS := Rect2(69.4, 33.7, 3.9, 1.0)   # the two PCs of the library (the "catalog" of the map): Code Expert
const THEKE := Rect2(69.4, 31.2, 3.5, 0.95)   # the counter of the library, with its screen: where the code is typed in
const TURM := Vector2(84.65, 31.5)      # the socket tower, between the two tables that build_map adds
const TURM_NAME := "Steckdosenturm"
# What hangs on the tower, one thing per arrow of the sequence minigame (0 up, 1 down, 2 left,
# 3 right): its name, whose it is (id in DEF.npcs) and where it stands (table, chair along it).
const DEVICES := [
	{"name": "Laptop", "owner": "l6_selina", "table": 4, "seat": 0},
	{"name": "Handy-Ladegerät", "owner": "l6_beat", "table": 5, "seat": 1},
	{"name": "Tischlampe", "owner": "l6_fabienne", "table": 5, "seat": 0},
	{"name": "Kaffeemaschine", "owner": "l6_marco", "table": 4, "seat": 1},
]

# ---- things that go on into later levels
const HANS_ID := "hans_muster"          # the same id as in level 3: whoever makes him an Opp, he remembers it everywhere
const SUMMARY_ITEM := "hans_summary"    # in the save game once his summary is out of the library: Game.has_item("hans_summary")
# the four reading tables of the map, then the two that build_map adds in the east end of the room
const TABLES := [Rect2(74.2, 29.4, 3.6, 1.2), Rect2(79.4, 29.4, 3.6, 1.2), Rect2(74.2, 32.6, 3.6, 1.2), Rect2(79.4, 32.6, 3.6, 1.2),
	Rect2(83.2, 29.3, 2.9, 1.0), Rect2(83.2, 32.7, 2.9, 1.0)]
const NEW_TABLES := 4                   # index of the first table that build_map adds
const SEAT_DX := [[0.73, 2.63], [0.73, 2.63], [0.73, 2.63], [0.73, 2.63], [0.7, 2.2], [0.7, 2.2]]   # chairs along each table
# Every chair: [table, chair along the table, north side of the table, who is there].
#   "leser"   somebody who studies (drawn once, never moves)
#   "npc"     one of the people from DEF.npcs sits here
#   "hans"    the place of Hans Muster, who stands next to the table
#   "fenster" the window seat, the only one without a reservation: both want it (staring contest)
#   an id     reserved by that person from DEF.npcs: their thing has to go before a player can sit
const SEATS := [
	[0, 0, true, "hans"], [0, 1, true, "leser"], [0, 0, false, "leser"], [0, 1, false, "npc"],
	[1, 0, true, "leser"], [1, 1, true, "l6_yannick"], [1, 0, false, "l6_noah"], [1, 1, false, "leser"],
	[2, 0, true, "leser"], [2, 1, true, "l6_lara"], [2, 0, false, "fenster"], [2, 1, false, "leser"],
	[3, 0, true, "leser"], [3, 1, true, "leser"], [3, 0, false, "npc"], [3, 1, false, "leser"],
	[4, 0, false, "npc"], [4, 1, false, "npc"], [5, 0, true, "npc"], [5, 1, true, "npc"],
]
# How a reservation looks ("art") and on which table it lies (-1 = on the chair).
const RESERVATIONS := {
	"l6_noah": {"art": "jacke", "table": -1},
	"l6_lara": {"art": "maeppli", "table": 2},
	"l6_yannick": {"art": "laptop", "table": 1},
}

const DEF := {
	"name": "Bib in der Lernphase",
	"tag": "LEVEL 6",
	"mode": "day",
	"time": 900.0,                      # generous: nobody has played this level yet
	"start": Vector2(66.0, 27.7),       # in the corridor, in front of the west door of the library
	"timer_title": "BIB SCHLIESST IN",
	"tips": [
		"In der Bib wird geschlichen. Wer geht, wird gehört, und wer hinschaut, merkt sich euer Gesicht.",
		"Eine Jacke über der Stuhllehne ist keine Person. Weg damit, hinsetzen, sitzen bleiben.",
		"Wem ihr etwas wegnehmt, der merkt es nach ein paar Sekunden und kommt nachsehen.",
		"Starrwettbewerb: nebeneinander vor die Kamera setzen und nicht blinzeln. Mit Tasten geht es auch.",
		"Essen und Trinken sind in der Bib verboten. Die Mate im Rucksack ist also Schmuggelware.",
	],
	"intro": "Juli, Lernphase, mitten am Tag. Die Bib ist rappelvoll, und ihr seid die Einzigen, die nicht lernen: Die Prüfung habt ihr ja schon. Beide müssen alles erledigen:",
	"hint": "In der Bib wird geschlichen: Wer geht oder rennt, wird gehört.",
	"start_toast": ["Psst!", "Alle Plätze sind reserviert: eine Jacke, ein Mäppli, ein Laptop. Räumt die Reservation weg und setzt euch hin, bevor jemand zurückkommt."],
	"win_title": "Lernphase überstanden",
	"win_text": "%s & %s gehen aus der Bib, ohne eine Sekunde gelernt zu haben. Alle anderen lernen weiter.",
	"lose_title": "Die Bib schliesst",
	"lose_text": "Die Aufsicht macht das Licht aus. Alle anderen haben heute etwas gelernt, ihr nicht einmal das.",
	# People who can turn into Opps (opp.gd). The three whose "bag" is a reservation are away
	# from their place: they stand between the shelves in the pavilion.
	"npcs": [
		{"id": "l6_noah", "name": "Noah", "pos": Vector2(79.5, 22.45), "face": -PI / 2.0,
			"bag": Vector2(80.13, 31.15), "bag_name": "Jacke", "bag_col": "3f6b4f"},
		{"id": "l6_lara", "name": "Lara", "pos": Vector2(84.5, 22.45), "face": -PI / 2.0,
			"bag": Vector2(76.83, 32.95), "bag_name": "Mäppli", "bag_col": "c8463c"},
		{"id": "l6_yannick", "name": "Yannick", "pos": Vector2(85.3, 25.4), "face": -PI / 2.0,
			"bag": Vector2(82.03, 29.8), "bag_name": "Laptop", "bag_col": "9aa4ad"},
		# Hans Muster stands at the end of the first table and looks at his summary, which lies on it.
		# No "look": he looks the same as in level 3. Already an Opp from an earlier level: he lurks.
		{"id": HANS_ID, "name": "Hans Muster", "pos": Vector2(73.7, 30.0), "face": 0.0, "hears": true, "if_opp": "lauert",
			"bag": Vector2(75.55, 30.0), "bag_name": "Zusammenfassung", "bag_acc": "l6_zf", "bag_col": "f3efe2"},
		# Four people at the two tables in the east end, each with something plugged into the socket
		# tower between them. All of them sit with their back to it.
		{"id": "l6_selina", "name": "Selina", "pos": Vector2(83.9, 30.85), "face": -PI / 2.0, "mode": "sitzt", "hears": true},
		{"id": "l6_marco", "name": "Marco", "pos": Vector2(85.4, 30.85), "face": -PI / 2.0, "mode": "sitzt", "hears": true},
		{"id": "l6_fabienne", "name": "Fabienne", "pos": Vector2(83.9, 33.1), "face": PI / 2.0, "mode": "sitzt", "hears": true},
		{"id": "l6_beat", "name": "Beat", "pos": Vector2(85.4, 33.1), "face": PI / 2.0, "mode": "sitzt", "hears": true},
		# Two people with a backpack next to their chair, and a Mate in it (rucksack.gd).
		{"id": "l6_dario", "name": "Dario", "pos": Vector2(76.83, 31.15), "face": -PI / 2.0, "mode": "sitzt", "hears": true},
		{"id": "l6_nina", "name": "Nina", "pos": Vector2(80.13, 34.35), "face": -PI / 2.0, "mode": "sitzt", "hears": true},
		# The socket tower itself: a "bag" that belongs to nobody. This entry is only there to hold
		# it; _ready makes it invisible and switches it off (no id: it can never become an Opp).
		{"id": "", "name": "Steckdosenturm", "pos": Vector2(84.65, 31.5), "bag": Vector2(84.65, 31.5),
			"bag_name": "Steckdosenturm", "bag_acc": "l6_turm", "bag_col": "e9ece8"},
	],
	# Opps from earlier levels come back here, oldest first: two between the shelves of the
	# pavilion, the third next to them.
	"opp_spots": [
		{"pos": Vector2(82.5, 22.45), "face": PI / 2.0, "mode": "lauert"},
		{"pos": Vector2(78.6, 25.4), "face": 0.0, "mode": "lauert"},
		# (the third one stood at the east end of the aisle, 3 tiles from the socket tower and the exit:
		# whoever worked at the tower was caught within seconds, and that ends the level)
		{"pos": Vector2(80.9, 22.45), "face": 0.0, "mode": "lauert"},
	],
	"tasks": [
		{"id": "platz", "name": "Platz besetzen", "where": "Reservation wegräumen, hinsetzen, 10 Sekunden sitzen bleiben", "type": "level"},
		{"id": "fehler", "name": "Fehler finden", "where": "Code Expert an den PCs der Bib", "type": "level"},
		{"id": "zf", "name": "Zusammenfassung klauen", "where": "bei Hans Muster am ersten Tisch, dann raus aus der Bib", "type": "level"},
		{"id": "starren", "name": "Starrwettbewerb", "where": "zu zweit am Fensterplatz, vor der Kamera", "type": "level"},
		{"id": "code", "name": "Code abschreiben", "where": "zu zweit an der Theke: eine Person liest vor, die andere tippt", "type": "level"},
		{"id": "turm", "name": "Steckdosenturm klauen", "where": "Ostende der Bib: Geräte in der richtigen Reihenfolge ausstecken, dann raus damit", "type": "level"},
		{"id": "mate", "name": "Mate klauen", "where": "Rucksack neben einem Stuhl: leise von hinten, dann den Reissverschluss auf", "type": "level"},
	],
}

var main
var t := 0.0
var rng := RandomNumberGenerator.new()
var people := {}                      # id -> the person from DEF.npcs (opp.gd)
var table_props: Array = []           # one per table: the table top, drawn over the legs of whoever sits behind it
var seats: Array = []                 # chairs a player can use: {"pos", "stand", "north", "table", "res", "fenster", "who", "back"}
var fenster_k := -1                   # index of the window seat in `seats`
var fenster_for: Array = []           # who may sit on the window seat (decided by the staring contest)
var readers: Array = []               # everybody who studies: {"pos", "look", "north", "psst", "node"}
var oben: Node2D                      # what is drawn above the characters
var told := {}                        # hints that have been shown
# players
var p_seat: Array = [-1, -1]          # index into `seats` while sitting
var p_sit: Array = [0.0, 0.0]         # seconds seated so far
var p_col: Array = [[0, 0], [0, 0]]   # collision layer and mask before sitting down
var p_tween: Array = [null, null]     # the slide onto or off a chair
var stun: Array = [0.0, 0.0]          # seconds left in front of the door
var fehler_round: Array = [0, 0]      # «Fehler finden»: the round each player goes on with
var code_n := 0                       # «Code abschreiben»: how many codes are through
var code_reader := -1                 # ... and who read the first one out (the two swap after every code)
# the socket tower
var turm_op = null                    # the entry of DEF.npcs that holds the tower (switched off, see _ready)
var plug_order: Array = []            # in which order the devices have to come out: indices into DEVICES
var unplugged := 0                    # how many of them are out (it stays that way)
var turm_pid := -1                    # who is at the sequence minigame of the tower right now
var spark_t := 0.0
# the Mate
var backpacks: Array = []             # {"op", "pos" (px), "col", "left", "zip", "busy", "node"}, see rucksack.gd
var mate: Array = [false, false]      # who has a bottle
var mate_at: Array = [-1, -1]         # the backpack each player has a hand in right now
# Somebody will notice in a moment that something of theirs is gone (devices, Mate):
# {"op", "pid", "t", "kind", "what"}. The same delay logic as for a bag in opp.gd.
var pending: Array = []
# What is carried out of the library: the owner of the bag (opp.gd) -> {"task", "art", "safe"}.
# "safe" = it is out of the library, the task is done and nobody can take it back.
var loot := {}


## Furniture and things that sort with the characters. What it looks like is drawn by `paint`.
class Prop:
	extends Node2D
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


# ================================================================== map
## Called by map_data.gd: two more study tables with chairs. Everything else is the library as it is.
static func build_map(md) -> void:
	for k in range(NEW_TABLES, TABLES.size()):
		var r: Rect2 = TABLES[k]
		md.R("rtable", r.position.x, r.position.y, r.size.x, r.size.y)
		var north: bool = k == TABLES.size() - 1   # chairs on the side that faces the other new table
		for dx in SEAT_DX[k]:
			md.R("chair", r.position.x + dx - 0.33, (r.position.y - 0.78) if north else (r.end.y + 0.08), 0.66, 0.55, {"solid": false})
	# the socket tower stands between them (not solid: once it is carried away nothing is in the way)
	md.R("l6_turm", TURM.x - 0.25, TURM.y - 0.5, 0.5, 0.6, {"solid": false})
	# the backpacks next to two chairs (drawn by this level, like the tower)
	for b in Rucksack.BACKPACKS:
		var bp: Vector2 = b["pos"]
		md.R("l6_rucksack", bp.x - 0.25, bp.y - 0.5, 0.5, 0.55, {"solid": false})


# ================================================================== setup
func _ready() -> void:
	z_index = -5                       # floor decoration: above the map, below the characters
	process_physics_priority = 10      # after the Opps: what they did in this step is known
	rng.seed = READER_SEED
	for op in main.opps:
		if op.opp_id != "" and _is_mine(op.opp_id):
			people[op.opp_id] = op
	_build_tables()
	_build_seats()
	for id in RESERVATIONS:
		if people.has(id):
			_swap_bag(people[id], String(RESERVATIONS[id]["art"]), int(RESERVATIONS[id]["table"]))
	if people.has(HANS_ID):
		_swap_bag(people[HANS_ID], "zf", 0)
		loot[people[HANS_ID]] = {"task": "zf", "art": "zf", "safe": false}
	for op in main.opps:
		if op.opp_id == "" and op.bag_name == TURM_NAME:
			# nobody owns the tower: whoever holds it for the bag system sees nothing, hears nothing
			# and does nothing
			turm_op = op
			op.visible = false
			op.set_physics_process(false)
			op.range_px = 0.0
			op.hears = false
			_swap_bag(op, "turm", -1)
			loot[op] = {"task": "turm", "art": "turm", "safe": false}
	plug_order = range(DEVICES.size())
	plug_order.shuffle()
	for b in Rucksack.BACKPACKS:
		var k := backpacks.size()
		var bn := Prop.new()
		bn.position = (b["pos"] as Vector2) * TS
		bn.paint = func(ci): _paint_rucksack(ci, k)
		main.actors.add_child(bn)
		backpacks.append({"op": people.get(String(b["owner"])), "pos": bn.position, "col": Color(String(b["col"])),
			"left": Rucksack.MATES, "zip": 0, "busy": -1, "node": bn})
	oben = Oben.new()
	oben.level = self
	oben.z_index = 11                  # relative to this node: above the characters and fx
	add_child(oben)


## What floats above heads and what a player carries, drawn above everything in the world.
class Oben:
	extends Node2D
	var level

	func _draw() -> void:
		level._draw_oben(self)


func _is_mine(id: String) -> bool:
	for d in DEF["npcs"]:
		if String(d.get("id", "")) == id:
			return true
	return false


## The table tops once more, as nodes that sort with the characters: whoever sits on the far side
## has the legs under the table. What lies on a table is drawn with it.
func _build_tables() -> void:
	for k in TABLES.size():
		var r: Rect2 = TABLES[k]
		var tp := Prop.new()
		tp.position = Vector2(r.position.x, r.end.y) * TS
		tp.paint = func(ci): _paint_table(ci, k)
		main.actors.add_child(tp)
		table_props.append(tp)


## Where somebody sits on chair `c` of table `k`, in tiles.
func _seat_pos(k: int, c: int, north: bool) -> Vector2:
	var r: Rect2 = TABLES[k]
	var x: float = r.position.x + float(SEAT_DX[k][c])
	return Vector2(x, r.position.y + 0.4) if north else Vector2(x, r.end.y + 0.55)


## Where a player stands before sitting down there and after getting up.
func _stand_pos(k: int, c: int, north: bool) -> Vector2:
	var r: Rect2 = TABLES[k]
	var x: float = r.position.x + float(SEAT_DX[k][c])
	return Vector2(x, r.position.y - 0.5) if north else Vector2(x, r.end.y + 0.55)


func _build_seats() -> void:
	for s in SEATS:
		var k: int = s[0]
		var north: bool = s[2]
		var who: String = s[3]
		var pos := _seat_pos(k, int(s[1]), north) * TS
		if who == "leser":
			var look: Dictionary = CH.random_student(rng)
			ART.set_acc(look, "backpack", false)   # the backpacks stand next to the chairs
			ART.set_acc(look, "laptop", false)
			var rd := {"pos": pos, "look": look, "north": north, "psst": 0.0, "node": null}
			var rp := Prop.new()
			rp.position = pos
			rp.paint = func(ci): _paint_reader(ci, rd)
			main.actors.add_child(rp)
			rd["node"] = rp
			readers.append(rd)
		elif who == "fenster" or people.has(who):
			var st := {"pos": pos, "stand": _stand_pos(k, int(s[1]), north) * TS, "north": north, "table": k,
				"res": people.get(who), "fenster": who == "fenster", "who": -1, "back": null}
			if who == "fenster":
				fenster_k = seats.size()
			if not north:
				# near side: the back of the chair hides the legs of a player who sits there
				var bp := Prop.new()
				bp.position = pos + Vector2(0, 2)
				bp.paint = _paint_chair_back
				bp.visible = false
				main.actors.add_child(bp)
				st["back"] = bp
			seats.append(st)


## The thing of opp.gd is a backpack. Here it is a jacket, a pencil case, a laptop: its own node
## in the same place (opp.gd only shows and hides `bag_node`).
func _swap_bag(op, art: String, table: int) -> void:
	if op.bag_node != null:
		op.bag_node.queue_free()
	var p := Prop.new()
	p.paint = func(ci): _paint_ding(ci, art, op.bag_col)
	if table >= 0:
		var tp: Node2D = table_props[table]
		tp.add_child(p)
		p.position = op.bag_pos - tp.position
	else:
		main.actors.add_child(p)
		p.position = op.bag_pos
	p.visible = op.bag_state == "there"
	op.bag_node = p


# ================================================================== loop
func _process(delta: float) -> void:
	t += delta
	spark_t = maxf(0.0, spark_t - delta)
	for rd in readers:
		if rd["psst"] > 0.0:
			rd["psst"] = maxf(0.0, rd["psst"] - delta)
	queue_redraw()
	oben.queue_redraw()


func _physics_process(delta: float) -> void:
	if main.state != "play":
		return
	for pid in 2:
		var pl = main.players[pid]
		stun[pid] = maxf(0.0, stun[pid] - delta)
		if not main.busy(pid):
			pl.enabled = stun[pid] <= 0.0 and p_seat[pid] < 0
		if p_seat[pid] >= 0 and not main.done[pid].has("platz"):
			p_sit[pid] += delta
			if p_sit[pid] >= SIT_TIME:
				main._task_done(pid, "platz")
				_get_up(pid)
				if not main.done[1 - pid].has("platz"):
					main.hud.toast("Platz besetzt", "Zehn Sekunden gesessen, das reicht für heute. Jetzt braucht noch %s einen Platz." % Game.name_of(1 - pid), 4.0, pid)
	# A reservation whose owner has noticed is gone for good: nothing is carried, the hands are free.
	for id in RESERVATIONS:
		var op = people.get(id)
		if op != null and op.bag_state == "stolen" and op.angry:
			op.bag_state = "none"
			op.bag_thief = -1
	_update_loot()
	_update_notices(delta)
	_watch_turm()
	_watch_mate()


# ------------------------------------------------------------------ things that are carried out of the library
## The thing this player is carrying out right now (the owner of the bag, opp.gd), or null.
func _carried(pid: int):
	for op in loot:
		if op.bag_state == "stolen" and op.bag_thief == pid and not loot[op]["safe"]:
			return op
	return null


## Taking is the "klauen" of main.gd (bag system of level 1). What counts as done is decided
## here: the thief has left the library with it, without being caught.
func _update_loot() -> void:
	for op in loot:
		if op.bag_state != "stolen" or op.bag_thief < 0:
			continue
		var info: Dictionary = loot[op]
		var pid: int = op.bag_thief
		var pl = main.players[pid]
		if not info["safe"] and main.world.zone_at(pl.global_position) != LIB:
			info["safe"] = true
			ART.set_acc(pl.look, op.bag_acc, false)   # stowed away: nothing in the hands any more
			pl.queue_redraw()
			_got_out(String(info["task"]), pid)
		# Out of the library it still counts as stolen until the owner has noticed (opp.gd turns
		# them into an Opp then). After that the player's hands are free for the next thing.
		if info["safe"] and (op.angry or op.opp_id == ""):
			op.bag_state = "none"
			op.bag_thief = -1


func _got_out(task: String, pid: int) -> void:
	match task:
		"zf":
			Game.add_item(SUMMARY_ITEM)
			main._coop_done("zf")
			main.hud.toast("Zusammenfassung gesichert", "Vierzig Seiten von Hans Muster, in vier Farben markiert. In der Prüfung hilft das.", 5.0, pid)
		"turm":
			main._coop_done("turm")
			main.hud.toast("Steckdosenturm gesichert", "Acht Steckdosen, vier USB-Anschlüsse. Ab jetzt habt ihr überall Strom, und in der Bib niemand mehr.", 5.0, pid)


## Whatever this player is carrying goes back to where it was.
func _drop_loot(pid: int) -> String:
	var op = _carried(pid)
	if op == null:
		return ""
	var pl = main.players[pid]
	ART.set_acc(pl.look, op.bag_acc, false)
	pl.queue_redraw()
	op.bag_state = "there"
	op.bag_thief = -1
	op.notice_t = -1.0
	if op.bag_node != null:
		op.bag_node.visible = true
	return String(op.bag_name)


# ================================================================== people of this level catch somebody
## Whoever of this level catches a player puts that player in front of the door: a mistake, the
## level goes on. Opps from earlier levels are not handled here (level lost, as everywhere).
func on_opp_catch(op, pid: int) -> bool:
	if not people.values().has(op):
		return false
	var pl = main.players[pid]
	main.mistakes_total += 1
	if main.minis[pid] != null:
		main._abort_mini(pid)
	if p_seat[pid] >= 0:
		_leave_seat(pid)
	elif p_tween[pid] != null and (p_tween[pid] as Tween).is_valid():
		# just getting up: the slide must not pull the player back to the chair
		(p_tween[pid] as Tween).kill()
		pl.collision_layer = p_col[pid][0]
		pl.collision_mask = p_col[pid][1]
	var lost := _drop_loot(pid)
	stun[pid] = STUN
	pl.enabled = false
	pl.global_position = (EJECT + Vector2(0.0, 0.45 * pid)) * TS
	op.meter = 0.0
	op.calm_t = OPP_CALM
	op._go_home()
	UI.sfx("fail")
	main.fx.sound(pl.global_position, 3.0 * TS, Color(1.0, 0.4, 0.4, 0.7), 0.8)
	if lost != "":
		main.hud.toast("Raus aus der Bib!", "%s stellt dich vor die Tür, und die Beute ist wieder an ihrem Platz: %s. Hol sie nochmals, wenn niemand hinschaut." % [op.pname, lost], 5.0, pid)
	else:
		main.hud.toast("Raus aus der Bib!", "%s stellt dich vor die Tür. Drinnen wartet ihr besser, bis niemand mehr hinschaut." % op.pname, 4.5, pid)
	return true


# ================================================================== interaction
func _near(act: String, label: String, rect: Rect2, extra: Dictionary = {}) -> Dictionary:
	var o := {"use": "level", "act": act, "label": label, "rect": rect}
	o.merge(extra)
	return o


## Everything this player could use right now.
func _spots(pid: int) -> Array:
	var out: Array = []
	var d: Dictionary = main.done[pid]
	for id in RESERVATIONS:
		var op = people.get(id)
		if op != null and op.bag_state == "there":
			var p: Vector2 = op.bag_pos / TS
			out.append(_near("res", "%s wegräumen" % op.bag_name, Rect2(p - Vector2(0.35, 0.6), Vector2(0.7, 0.75)), {"op": op}))
	if not d.has("platz"):
		for k in seats.size():
			if _can_sit(pid, k):
				out.append(_near("sit", "Hinsetzen", _seat_rect(k), {"seat": k}))
	if not d.has("starren") and fenster_k >= 0:
		out.append(_near("starren", "Um den Fensterplatz starren (zu zweit)", _seat_rect(fenster_k)))
	if not d.has("code"):
		out.append(_near("code", "Code abschreiben (zu zweit)", THEKE))
	if not d.has("mate"):
		for k in backpacks.size():
			if int(backpacks[k]["left"]) > 0:
				var bp: Vector2 = (backpacks[k]["pos"] as Vector2) / TS
				out.append(_near("mate", "Reissverschluss öffnen", Rect2(bp - Vector2(0.3, 0.55), Vector2(0.6, 0.65)), {"bp": k}))
	if turm_op != null and unplugged < DEVICES.size():
		# as long as something is plugged in, the tower cannot be taken: this replaces the "klauen" of main.gd
		out.append(_near("stecker", "Geräte ausstecken", Rect2(TURM - Vector2(0.3, 0.6), Vector2(0.6, 0.8))))
	if not d.has("fehler"):
		out.append(_near("pc", "Code Expert öffnen", PCS))
	return out


func update_near(pid: int) -> void:
	if stun[pid] > 0.0:
		main.nears[pid] = null
		return
	if p_seat[pid] >= 0:
		main.nears[pid] = _near("up", "Aufstehen", _seat_rect(p_seat[pid]))
		return
	# a reservation is taken away here, not with the "klauen" of main.gd (it is not carried out)
	var cur = main.nears[pid]
	if cur != null and String(cur.get("use", "")) == "bag" and RESERVATIONS.has(cur["opp"].opp_id):
		main.nears[pid] = null
	var p: Vector2 = main.players[pid].global_position / TS
	var best := REACH
	for o in _spots(pid):
		var r: Rect2 = o["rect"]
		var c := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var dd := p.distance_to(c)
		if dd < best:
			best = dd
			main.nears[pid] = o


func interact(pid: int, o: Dictionary) -> void:
	match o["act"]:
		"res":
			_clear_reservation(pid, o["op"])
		"sit":
			_sit(pid, int(o["seat"]))
		"up":
			_get_up(pid)
		"pc":
			_open_fehler(pid)
		"starren":
			if _partner_ready(pid, "%s muss auch am Fensterplatz stehen. Ihr wollt ihn schliesslich beide."):
				_open_starren()
		"code":
			if _partner_ready(pid, "%s muss auch an der Theke stehen: Eine Person liest vor, die andere tippt."):
				_open_abschreiben(pid)
		"stecker":
			_open_turm(pid)
		"mate":
			_open_mate(pid, int(o["bp"]))


## Registers a minigame of this folder for one player the way main.open_minigame does with its
## own: it sits in main.minis, so the player is busy and the screen splits for it.
func _solo(mg: Node, pid: int) -> void:
	mg.screen_side = main.minigame_side(pid)
	mg.keys = KEYS.keys_for(pid)
	mg.labels = KEYS.labels_for(pid)
	mg.accent = Color(String(KEYS.TAG_COLORS[pid]))
	main.last_actor = pid
	main.minis[pid] = mg
	main.nears[pid] = null
	main.players[pid].enabled = false
	main.add_child(mg)


## For what takes two: is the other player close enough and free? If not, `why` says so (%s = their name).
func _partner_ready(pid: int, why: String) -> bool:
	var other = main.players[1 - pid]
	var far: bool = other.global_position.distance_to(main.players[pid].global_position) > PAIR_DIST * TS
	if far or main.busy(1 - pid) or p_seat[1 - pid] >= 0 or stun[1 - pid] > 0.0:
		main.hud.toast("Zu zweit", why % Game.name_of(1 - pid), 3.5, pid)
		return false
	return true


## Registers a minigame of this folder for both players, the way main.open_coop_minigame does:
## the same object in both places of main.minis, so the screen stays in one piece.
func _duo(mg: Node) -> void:
	mg.keys = KEYS.keys_for(0)
	mg.labels = KEYS.labels_for(0)
	mg.keys2 = KEYS.keys_for(1)
	mg.labels2 = KEYS.labels_for(1)
	for j in 2:
		main.minis[j] = mg
		main.nears[j] = null
		main.players[j].enabled = false
	main.add_child(mg)


## True if `mg` was still the open minigame of both and the level is still running. Clears it.
func _duo_closed(mg: Node) -> bool:
	var mine := false
	for j in 2:
		if main.minis[j] == mg:
			main.minis[j] = null
			mine = true
	return mine and main.state == "play"


## The map is one huge drawing and takes most of the time of every frame. While a game covers the
## whole screen, the two views are not drawn again (they keep their last picture), so the camera
## picture runs smoothly. They are switched back on when the game leaves the tree. As in level 4.
func _freeze_views(mg: Node) -> void:
	var modes: Array = []
	for vp in main.vps:
		modes.append(vp.render_target_update_mode)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mg.tree_exited.connect(func():
		if not is_instance_valid(main):
			return
		for i in main.vps.size():
			if is_instance_valid(main.vps[i]):
				main.vps[i].render_target_update_mode = modes[i])


# ------------------------------------------------------------------ task 4: the staring contest
## The window seat is the only one without a reservation, and both want it. Nobody gives way, so
## they stare at each other in front of the camera (starr_spiel.gd). The task is done for both
## whatever comes out; the loser gets a mistake, the winner may sit on the window seat.
func _open_starren() -> void:
	var mg = StarrSpiel.new()
	_duo(mg)
	mg.open()
	_freeze_views(mg)
	# While the two sit in front of the camera nobody sees or catches them (the screen is covered,
	# they could not even see it coming): the duel is never cut short.
	for pl in main.players:
		pl.hidden_mode = true
	mg.tree_exited.connect(func():
		if is_instance_valid(main):
			for pl in main.players:
				if is_instance_valid(pl):
					pl.hidden_mode = false)
	mg.finished.connect(func(ok: bool, _m: int):
		if not _duo_closed(mg):
			return
		if not ok:
			main.hud.toast("Abgebrochen", "Ihr könnt es jederzeit nochmals versuchen.", 2.5)
			return
		_duel_over(int(mg.winner), int(mg.loser)))


func _duel_over(winner: int, loser: int) -> void:
	fenster_for = [0, 1] if winner < 0 else [winner]
	if loser >= 0:
		main._on_mini_mistake(loser)   # a mistake like any minigame mistake, with its ring of noise
	main._coop_done("starren")
	if winner < 0:
		main.hud.toast("Keiner gibt nach", "Unentschieden. Der Fensterplatz gehört, wer zuerst sitzt.", 5.0)
	elif main.done[winner].has("platz"):
		main.hud.toast("%s gewinnt" % Game.name_of(winner), "Der Fensterplatz gehört %s. %s hat nachgegeben, das gibt einen Fehler." % [Game.name_of(winner), Game.name_of(loser)], 5.0, winner)
	else:
		main.hud.toast("%s gewinnt" % Game.name_of(winner), "Der Fensterplatz gehört %s: hinsetzen, das zählt als Platz. %s muss eine Reservation wegräumen." % [Game.name_of(winner), Game.name_of(loser)], 6.0, winner)


# ------------------------------------------------------------------ somebody notices a little later
## The same delay logic as for a stolen bag (opp.gd, bag_taken and _bag_clock), for things that
## are not a bag: the owner notices at once if they see the player, otherwise after `delay`
## seconds, or earlier if they turn around and see the player in between.
func _start_notice(op, pid: int, delay: float, kind: String, what: String) -> void:
	if op == null:
		return
	var e := {"op": op, "pid": pid, "t": delay, "kind": kind, "what": what}
	if op.can_see(main.players[pid]):
		_noticed(e, true)
	else:
		pending.append(e)


func _update_notices(delta: float) -> void:
	for e in pending.duplicate():
		e["t"] -= delta
		var seen: bool = e["op"].can_see(main.players[int(e["pid"])])
		if seen or float(e["t"]) <= 0.0:
			pending.erase(e)
			_noticed(e, seen)


func _noticed(e: Dictionary, seen: bool) -> void:
	var op = e["op"]
	var pid: int = e["pid"]
	var pl = main.players[pid]
	op.become_opp(pid, seen, "%s weg" % String(e["what"]))   # opp.gd remembers it (and says "Neuer Opp" the first time)
	if op.state != OPP.JAGD:
		if seen:
			op._chase(pl)
		else:
			# gets up and looks for the player, a few steps in the direction they went
			var to: Vector2 = pl.global_position - op.global_position
			op.last_seen = op.global_position + to.limit_length(6.0 * TS)
			op._search(op.last_seen)
	if main.state != "play":
		return
	match String(e["kind"]):
		"akku":
			if seen:
				main.hud.toast("Akku leer!", "%s sieht dich am Steckdosenturm und ist jetzt hinter dir her. Lauf!" % op.pname, 4.5, pid)
			else:
				main.hud.toast("Akku leer!", "%s merkt, dass der Stecker draussen ist, und sucht dich. Bleib ausser Sicht." % op.pname, 4.5, pid)
		"mate":
			if seen:
				main.hud.toast("«Meine Mate!»", "%s sieht dich mit der Flasche und ist jetzt hinter dir her. Lauf!" % op.pname, 4.5, pid)
			else:
				main.hud.toast("«Wo ist meine Mate?»", "%s merkt, dass die Flasche fehlt, und sucht dich. Bleib ausser Sicht." % op.pname, 4.5, pid)


# ------------------------------------------------------------------ task 7: the Mate in the backpack
## A backpack stands next to the chair of somebody who reads. Quietly from behind, then the zip:
## the timing minigame of minigame.gd, several goes in a row. The backpack stays where it is.
func _open_mate(pid: int, k: int) -> void:
	var bp: Dictionary = backpacks[k]
	var op = bp["op"]
	if int(bp["busy"]) >= 0:
		main.hud.toast("Besetzt", "%s hat die Hand schon in diesem Rucksack." % Game.name_of(int(bp["busy"])), 2.5, pid)
		return
	if op != null and op.can_see(main.players[pid]):
		UI.sfx("fail")
		main.hud.toast("Bemerkt!", "%s schaut gerade her. Warte, bis wieder gelesen wird, und komm leise von hinten." % op.pname, 3.5, pid)
		return
	bp["busy"] = pid
	var on_ok := func(): _got_mate(pid, k)
	var on_close := func():
		bp["busy"] = -1
		mate_at[pid] = -1
		(bp["node"] as Node2D).queue_redraw()
	main.open_minigame("timing", {"title": "Reissverschluss öffnen", "hits": Rucksack.ZIP_HITS, "verb": "Zahn", "speed": Rucksack.ZIP_SPEED}, on_ok, pid, Callable(), on_close)
	mate_at[pid] = k
	var mg = main.minis[pid]
	if Rucksack.ZIP_KEPT and int(bp["zip"]) > 0:
		# the zip is open as far as somebody got last time
		mg.hits = mini(int(bp["zip"]), Rucksack.ZIP_HITS - 1)
		mg._new_zone()
		mg._update_info()


## While a hand is in a backpack: the pointer keeps its pace, the zip remembers how far it is,
## and if the owner turns around and sees the player, the hand has to come out again.
func _watch_mate() -> void:
	for pid in 2:
		var k: int = mate_at[pid]
		if k < 0:
			continue
		var mg = main.minis[pid]
		if mg == null or not is_instance_valid(mg) or not ("zone" in mg):
			mate_at[pid] = -1
			continue
		var bp: Dictionary = backpacks[k]
		if Rucksack.ZIP_EVEN:
			mg.vel = signf(mg.vel) * Rucksack.ZIP_SPEED
		if int(mg.hits) != int(bp["zip"]):
			bp["zip"] = int(mg.hits)
			(bp["node"] as Node2D).queue_redraw()
		var op = bp["op"]
		if op != null and mg.closing < 0.0 and op.can_see(main.players[pid]):
			main._abort_mini(pid)
			UI.sfx("fail")
			main.hud.toast("Ups, gemerkt!", "%s hat sich umgedreht. Hand raus und kurz warten: Der Reissverschluss bleibt so weit offen." % op.pname, 4.0, pid)


## The bottle is out. The backpack stays; its owner will miss the Mate a little later, or at
## once if they see the player with it (rucksack.gd, NOTICE).
func _got_mate(pid: int, k: int) -> void:
	var bp: Dictionary = backpacks[k]
	bp["left"] = int(bp["left"]) - 1
	bp["zip"] = Rucksack.ZIP_HITS
	(bp["node"] as Node2D).queue_redraw()
	mate[pid] = true
	UI.sfx("steal")
	UI.confetti(main.fx, main.players[pid].global_position + Vector2(0, -30), 40, true, 70.0, 0.3)
	main._task_done(pid, "mate")
	main.hud.toast("Mate gesichert", "Lauwarm und durchgeschüttelt, aber deine. Jetzt weg hier, bevor jemand Durst bekommt.", 4.5, pid)
	_start_notice(bp["op"], pid, randf_range(Rucksack.NOTICE.x, Rucksack.NOTICE.y), "mate", "Mate")


# ------------------------------------------------------------------ task 6: the socket tower
## Step 1: the devices have to come out in a fixed order. This is the sequence minigame of
## minigame.gd, with the order of the plugs as its sequence: every device is an arrow.
func _open_turm(pid: int) -> void:
	var on_ok := func():
		main.hud.toast("Alles ausgesteckt", "Jetzt den Turm nehmen und raus aus der Bib, bevor jemand den leeren Akku bemerkt.", 4.5, pid)
	var on_wrong := func():
		spark_t = SPARK_TIME   # sparks; the ring of noise comes from main.gd
	var on_close := func(): turm_pid = -1
	main.open_minigame("sequence", {"title": "Steckdosenturm", "length": DEVICES.size()}, on_ok, pid, on_wrong, on_close)
	turm_pid = pid
	var mg = main.minis[pid]
	mg.seq = plug_order.duplicate()
	mg._restart_show()   # the order lights up, also on the tower (see _draw_oben)
	_turm_info(mg)


## Keeps the sequence minigame and the tower in step. A plug that is out stays out: after a
## wrong one the minigame would start again from the first arrow.
func _watch_turm() -> void:
	if turm_pid < 0:
		return
	var mg = main.minis[turm_pid]
	if mg == null or not is_instance_valid(mg) or not ("seq_phase" in mg):
		turm_pid = -1
		return
	if int(mg.input_i) > unplugged:
		for k in range(unplugged, int(mg.input_i)):
			_unplug(int(plug_order[k]), turm_pid)
		unplugged = int(mg.input_i)
	elif String(mg.seq_phase) == "input" and int(mg.input_i) < unplugged:
		mg.input_i = unplugged
	_turm_info(mg)


## Out of the tower: the device goes dark, and its owner will notice (like a bag in level 1).
func _unplug(dev: int, pid: int) -> void:
	var d: Dictionary = DEVICES[dev]
	UI.sfx("click", -4.0)
	(table_props[int(d["table"])] as Node2D).queue_redraw()
	_start_notice(people.get(String(d["owner"])), pid, randf_range(OPP.NOTICE.x, OPP.NOTICE.y), "akku", String(d["name"]))


## Is device `dev` still plugged in?
func _plugged(dev: int) -> bool:
	return plug_order.find(dev) >= unplugged


## The text under the pads: which arrow is which device, and how far it is.
func _turm_info(mg) -> void:
	var s := ""
	var col := UI.ON_GLASS2
	if mg.closing >= 0.0:
		s = "Alles ausgesteckt. Jetzt den Turm nehmen und raus hier."
		col = UI.GREEN
	elif String(mg.seq_phase) == "wait":
		s = "Funken! Das war der falsche Stecker. Was draussen ist, bleibt draussen."
		col = UI.RED
	elif String(mg.seq_phase) == "show":
		s = "Merk dir die Reihenfolge. Oben: %s · unten: %s · links: %s · rechts: %s." % [DEVICES[0]["name"], DEVICES[1]["name"], DEVICES[2]["name"], DEVICES[3]["name"]]
	else:
		s = "Jetzt ausstecken, mit %s. Oben: %s · unten: %s · links: %s · rechts: %s. Draussen: %d von %d." % [mg.labels["dirs"],
			DEVICES[0]["name"], DEVICES[1]["name"], DEVICES[2]["name"], DEVICES[3]["name"], unplugged, DEVICES.size()]
	if mg.mistakes > 0 and mg.closing < 0.0:
		s += "   Fehler: %d" % mg.mistakes
	if mg.info_l.text != s:
		mg.info_l.text = s
	mg.info_l.label_settings.font_color = col


# ------------------------------------------------------------------ task 5: copy the code
## A relay at the counter (abschreib_spiel.gd): one reads the code out, the other one types it,
## and after every code they swap. Whoever starts it reads the first one.
func _open_abschreiben(pid: int) -> void:
	if code_reader < 0:
		code_reader = pid
	var mg = AbschreibSpiel.new()
	mg.host = main
	_duo(mg)
	mg.open(AbschreibCodes.CODES, code_n, code_reader)
	mg.mistake.connect(func(): _typo(int(mg.typist())))
	mg.code_done.connect(func(n: int): code_n = n)
	mg.finished.connect(func(ok: bool, _m: int):
		if not _duo_closed(mg):
			return
		if ok:
			main._coop_done("code")
			main.hud.toast("Abgegeben", "Die Übung ist eingereicht, zwei Minuten vor der Frist. Von wem der Code war, fragt besser niemand.", 4.5)
		else:
			main.hud.toast("Abgebrochen", "Ihr könnt es jederzeit nochmals versuchen.", 2.5))


## A wrong key: a ring of noise where the typist stands, as after any minigame mistake. Whether
## it also counts for the grade says AbschreibSpiel.TYPO_COUNTS.
func _typo(pid: int) -> void:
	if AbschreibSpiel.TYPO_COUNTS:
		main._on_mini_mistake(pid)
		return
	var at: Vector2 = main.players[pid].global_position
	main.fx.sound(at, 4.0 * TS, Color(1.0, 0.45, 0.35, 0.7), 1.0)
	for op in main.opps:
		op.hear(at, 4.0 * TS)
	on_noise(at, 3.0 * TS)


# ------------------------------------------------------------------ task 2: find the mistake
## Code Expert on one of the PCs: three programs, one wrong line each (fehler_spiel.gd).
func _open_fehler(pid: int) -> void:
	var mg = FehlerSpiel.new()
	_solo(mg, pid)
	mg.open(FehlerCodes.RUNDEN, int(fehler_round[pid]))
	mg.mistake.connect(func(): main._on_mini_mistake(pid))
	mg.round_done.connect(func(n: int): fehler_round[pid] = n)
	mg.finished.connect(func(ok: bool, _m: int):
		if main.minis[pid] != mg:
			return
		main.minis[pid] = null
		if main.state != "play":
			return
		if ok:
			main._task_done(pid, "fehler")
		else:
			main.hud.toast("Abgebrochen", "Du kannst es jederzeit nochmals versuchen.", 2.5, pid))


# ------------------------------------------------------------------ task 1: a place to sit
## A chair is free once the thing that reserved it is gone and nobody sits there. The window
## seat is free once the staring contest is over.
func _seat_free(k: int) -> bool:
	var st: Dictionary = seats[k]
	if int(st["who"]) >= 0:
		return false
	if st["fenster"]:
		return main.done[0].has("starren")
	return st["res"].bag_state != "there" and st["res"].bag_state != "carried"


## May this player sit down there? The window seat belongs to whoever won it.
func _can_sit(pid: int, k: int) -> bool:
	return _seat_free(k) and (not seats[k]["fenster"] or fenster_for.has(pid))


func _seat_rect(k: int) -> Rect2:
	return Rect2((seats[k]["stand"] as Vector2) / TS - Vector2(0.4, 0.5), Vector2(0.8, 0.9))


## The reservation goes: for opp.gd the player has taken the bag of somebody who is away. Seen
## = Opp at once; otherwise the owner notices a little later and comes to look for the player.
func _clear_reservation(pid: int, op) -> void:
	if op.bag_state != "there":
		return
	UI.sfx("steal")
	UI.confetti(main.fx, op.bag_pos + Vector2(0, -16), 30, true, 60.0, 0.25)
	op.bag_taken(pid)
	if main.state == "play" and not op.angry:
		main.hud.toast("Weg damit", "%s ist verschwunden, der Platz ist frei. Hinsetzen und sitzen bleiben, bevor %s zurückkommt." % [_the(op.bag_name), op.pname], 4.5, pid)


## "Die Jacke", "Das Mäppli", "Der Laptop": the name of a thing with its article, for the texts.
func _the(thing: String) -> String:
	match thing:
		"Jacke":
			return "Die Jacke"
		"Mäppli":
			return "Das Mäppli"
		"Laptop":
			return "Der Laptop"
	return thing


func _sit(pid: int, k: int) -> void:
	if not _can_sit(pid, k):
		return
	var st: Dictionary = seats[k]
	var pl = main.players[pid]
	st["who"] = pid
	p_seat[pid] = k
	p_sit[pid] = 0.0
	p_col[pid] = [pl.collision_layer, pl.collision_mask]
	pl.collision_layer = 0   # the far seats are inside the collision box of the table
	pl.collision_mask = 0
	pl.enabled = false
	pl.dir = PI / 2.0 if st["north"] else -PI / 2.0
	pl.facing = ART.FRONT if st["north"] else ART.BACK
	_slide(pid, st["pos"])
	if st["back"] != null:
		st["back"].visible = true
	UI.sfx("pop")
	if not told.has("sit"):
		told["sit"] = true
		main.hud.toast("Sitzen bleiben", "Zehn Sekunden, dann gehört der Platz dir. Wer vorher aufsteht, fängt wieder bei null an.", 4.5, pid)


func _slide(pid: int, to: Vector2) -> Tween:
	if p_tween[pid] != null and (p_tween[pid] as Tween).is_valid():
		(p_tween[pid] as Tween).kill()
	var tw := create_tween()
	tw.tween_property(main.players[pid], "global_position", to, 0.18)
	p_tween[pid] = tw
	return tw


## Off the chair at once, without the slide: the player is about to be put somewhere else.
func _leave_seat(pid: int) -> void:
	var st: Dictionary = seats[p_seat[pid]]
	var pl = main.players[pid]
	if p_tween[pid] != null and (p_tween[pid] as Tween).is_valid():
		(p_tween[pid] as Tween).kill()
	st["who"] = -1
	if st["back"] != null:
		st["back"].visible = false
	p_seat[pid] = -1
	p_sit[pid] = 0.0
	pl.collision_layer = p_col[pid][0]
	pl.collision_mask = p_col[pid][1]


func _get_up(pid: int) -> void:
	var st: Dictionary = seats[p_seat[pid]]
	var pl = main.players[pid]
	st["who"] = -1
	if st["back"] != null:
		st["back"].visible = false
	p_seat[pid] = -1
	p_sit[pid] = 0.0
	stun[pid] = maxf(stun[pid], 0.2)   # no steps until the player stands next to the chair again
	var tw := _slide(pid, st["stand"])
	tw.tween_callback(func():
		pl.collision_layer = p_col[pid][0]
		pl.collision_mask = p_col[pid][1])


# ================================================================== hooks called by main.gd
## Footsteps and minigame mistakes: whoever studies nearby looks up and hisses.
func on_noise(at: Vector2, radius: float) -> void:
	var any := false
	for rd in readers:
		if (rd["pos"] as Vector2).distance_to(at) < radius:
			rd["psst"] = PSST_TIME
			any = true
	if any and not told.has("psst") and main.state == "play" and main.time_played > 4.0:
		told["psst"] = true
		main.hud.toast("Psst!", "In der Bib hört man jeden Schritt. Schleichen: %s %s, %s %s" % [Game.name_of(0), KEYS.labels_for(0)["sneak"], Game.name_of(1), KEYS.labels_for(1)["sneak"]], 5.0)


## Where task `id` can be done by player `pid` right now, in px (for the arrow that shows the way).
func task_targets(id: String, pid: int) -> Array:
	var out: Array = []
	match id:
		"platz":
			if p_seat[pid] >= 0:
				return out
			for k in seats.size():
				if _can_sit(pid, k):
					out.append(seats[k]["stand"])
			if out.is_empty():
				for st in seats:
					if st["res"] != null and st["res"].bag_state == "there":
						out.append(st["res"].bag_pos)
		"fehler":
			out.append(_c(PCS))
		"zf":
			out.append_array(_loot_targets("zf", pid))
		"starren":
			if fenster_k >= 0:
				out.append(seats[fenster_k]["stand"])
		"code":
			out.append(_c(THEKE))
		"turm":
			out.append_array(_loot_targets("turm", pid))
		"mate":
			for bp in backpacks:
				if int(bp["left"]) > 0:
					out.append(bp["pos"])
	return out


## Where to go for a thing that has to be carried out: to it, or out of the library with it.
func _loot_targets(task: String, pid: int) -> Array:
	var out: Array = []
	for op in loot:
		if String(loot[op]["task"]) != task:
			continue
		if _carried(pid) == op:
			out.append(main._way_out(pid, LIB))
		elif op.bag_state == "there":
			out.append(op.bag_pos)
	return out


func _c(r: Rect2) -> Vector2:
	return r.get_center() * TS


## Goal markers for the HUD: [position in px, colour of whoever still needs it].
func goal_positions(id: String, n0: bool, n1: bool) -> Array:
	var out: Array = []
	match id:
		"platz":
			var w0: bool = n0 and p_seat[0] < 0
			var w1: bool = n1 and p_seat[1] < 0
			if not (w0 or w1):
				return out
			for k in seats.size():
				var st: Dictionary = seats[k]
				var s0: bool = w0 and _can_sit(0, k)
				var s1: bool = w1 and _can_sit(1, k)
				if s0 or s1:
					out.append([st["stand"], main._need_color(s0, s1)])
				elif st["res"] != null and st["res"].bag_state == "there":
					out.append([st["res"].bag_pos + Vector2(0, -14), main._need_color(w0, w1)])
		"fehler":
			out.append([_c(PCS), main._need_color(n0, n1)])
		"zf", "turm":
			for op in loot:
				if String(loot[op]["task"]) == id and op.bag_state == "there":
					out.append([op.bag_pos + Vector2(0, -12 if id == "zf" else -30), main._need_color(n0, n1)])
		"starren":
			if fenster_k >= 0:
				out.append([seats[fenster_k]["stand"] + Vector2(0, -10), main._need_color(n0, n1)])
		"code":
			out.append([_c(THEKE), main._need_color(n0, n1)])
		"mate":
			for bp in backpacks:
				if int(bp["left"]) > 0:
					out.append([(bp["pos"] as Vector2) + Vector2(0, -22), main._need_color(n0, n1)])
	return out


## Called by main.gd when every task is done: a few lines, then the last picture (schluss.gd):
## the two walk out, everybody else goes on studying.
func finale(done: Callable) -> void:
	main.state = "cutscene"
	main.hud.visible = false
	for pid in 2:
		if p_seat[pid] >= 0:
			_leave_seat(pid)
		main.players[pid].enabled = false
	create_tween().tween_property(main, "zoom", 3.2, 0.9).set_trans(Tween.TRANS_SINE)   # main.zoom moves both cameras
	var steps := [
		{"say": 0, "text": "Ein Platz, eine Zusammenfassung, ein Steckdosenturm und zwei Mate."},
		{"say": 1, "text": "Und keine einzige Seite gelesen."},
		{"say": 0, "text": "Brauchen wir auch nicht. Die Prüfung haben wir ja schon."},
	]
	var cs = Cutscene.new()
	main.add_child(cs)
	cs.play(steps, func():
		var sch = Schluss.new()
		sch.looks = [main.players[0].look, main.players[1].look]
		for rd in readers:
			sch.readers.append(rd["look"])
		_freeze_views(sch)
		main.add_child(sch)
		sch.done.connect(func():
			main.hud.visible = true
			done.call()))


# ================================================================== drawing
func _draw() -> void:
	_draw_window()
	_draw_cables()
	if main.state != "play":
		return
	# a free chair that still counts for somebody: a green ring on the floor
	var pulse := 0.55 + 0.45 * sin(t * 6.0)
	for k in seats.size():
		for pid in 2:
			if not main.done[pid].has("platz") and p_seat[pid] < 0 and _can_sit(pid, k):
				_ell(seats[k]["stand"] + Vector2(0, -4), 13.0, 6.0, Color(UI.GREEN, pulse), 2.0)
				break


## The window seat: a window in the south wall behind it, and the sun on the floor.
func _draw_window() -> void:
	if fenster_k < 0:
		return
	var c: Vector2 = seats[fenster_k]["pos"]
	var wy := 35.0 * TS   # the south wall of the reading room
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - 26.0, wy), Vector2(c.x + 26.0, wy), Vector2(c.x + 46.0, wy - 52.0), Vector2(c.x - 14.0, wy - 52.0)]),
		Color(1.0, 0.95, 0.62, 0.2))
	draw_rect(Rect2(c.x - 27.0, wy + 6.0, 54.0, 18.0), Color("3b2a1e"))
	draw_rect(Rect2(c.x - 24.0, wy + 8.0, 48.0, 14.0), Color("bfe3ff"))
	draw_line(Vector2(c.x, wy + 8.0), Vector2(c.x, wy + 22.0), Color("3b2a1e"), 2.0)


func _ell(c: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	draw_arc(Vector2.ZERO, rx, 0.0, TAU, 28, col, width)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where device `dev` stands on its table, seen from the node of that table top (px).
func _device_local(dev: int) -> Vector2:
	var d: Dictionary = DEVICES[dev]
	var k: int = d["table"]
	var north: bool = k == TABLES.size() - 1   # at the last table people sit on the north side
	return Vector2(float(SEAT_DX[k][int(d["seat"])]) * TS, (-(TABLES[k] as Rect2).size.y * TS + 11.0) if north else -11.0)


func _device_pos(dev: int) -> Vector2:
	return (table_props[int(DEVICES[dev]["table"])] as Node2D).position + _device_local(dev)


## The cables from the socket tower to what hangs on it. One that is out lies on the floor.
func _draw_cables() -> void:
	if turm_op == null or table_props.is_empty():
		return
	var base := TURM * TS
	var socket := [Vector2(0, -22), Vector2(0, -2), Vector2(-6, -12), Vector2(6, -12)]   # up, down, left, right
	var cable := Color("23262e")
	for dev in DEVICES.size():
		var dp := _device_pos(dev)
		if _plugged(dev) and turm_op.bag_state == "there":
			var end: Vector2 = base + socket[dev]
			draw_polyline(PackedVector2Array([dp, Vector2(dp.x, (dp.y + end.y) / 2.0), Vector2(end.x, (dp.y + end.y) / 2.0), end]), cable, 2.0)
			draw_rect(Rect2(end - Vector2(2.5, 2.5), Vector2(5, 5)), Color("f3efe2"))
		else:
			var end2 := dp.lerp(base, 0.55) + Vector2(4.0 if dev % 2 == 0 else -4.0, 0.0)
			draw_polyline(PackedVector2Array([dp, Vector2(dp.x, end2.y), end2]), Color(cable, 0.7), 2.0)
			draw_rect(Rect2(end2 - Vector2(2.5, 2.5), Vector2(5, 5)), Color("b9b2a0"))


## What hangs on the socket tower, drawn on its table: bright while it has power.
func _paint_device(ci: CanvasItem, c: Vector2, dev: int, on: bool) -> void:
	match dev:
		0:   # a laptop
			ci.draw_rect(Rect2(c.x - 10.0, c.y - 6.0, 20.0, 12.0), Color("5f6b74"))
			ci.draw_rect(Rect2(c.x - 8.5, c.y - 4.5, 17.0, 9.0), Color("bfe3ff") if on else Color("1b1d26"))
		1:   # a phone on its charger
			ci.draw_rect(Rect2(c.x - 4.0, c.y - 7.0, 8.0, 14.0), Color("23262e"))
			ci.draw_rect(Rect2(c.x - 3.0, c.y - 5.5, 6.0, 11.0), Color("7dffb0") if on else Color("0d0f14"))
		2:   # a desk lamp
			if on:
				ci.draw_circle(c, 13.0, Color(1.0, 0.92, 0.55, 0.35))
			ci.draw_circle(c + Vector2(-3, 3), 4.0, Color("3a3f46"))
			ci.draw_line(c + Vector2(-3, 3), c + Vector2(4, -4), Color("3a3f46"), 2.0)
			ci.draw_circle(c + Vector2(4, -4), 4.5, Color("ffe38a") if on else Color("8a8f98"))
		3:   # a coffee machine (eating and drinking are not allowed in here, of course)
			ci.draw_rect(Rect2(c.x - 8.0, c.y - 8.0, 16.0, 15.0), Color("2b2f35"))
			ci.draw_rect(Rect2(c.x - 5.0, c.y - 1.0, 10.0, 6.0), Color("14161a"))
			ci.draw_rect(Rect2(c.x - 2.5, c.y + 1.0, 5.0, 4.0), Color("f3efe2"))
			ci.draw_circle(c + Vector2(5, -5), 1.6, Color("ff5d5d") if on else Color("4a2a2a"))


## The top of table `k`, drawn like world.gd draws a reading table, with what lies on it.
func _paint_table(ci: CanvasItem, k: int) -> void:
	var r: Rect2 = TABLES[k]
	var w := r.size.x * TS
	var h := r.size.y * TS
	ci.draw_rect(Rect2(0, -h, w, h), Color("8a6a48"))
	ci.draw_rect(Rect2(3, -h + 3, w - 6, h - 6), Color("9d7b55"))
	for dx in [0.9, 2.7]:
		ci.draw_circle(Vector2(dx * TS, -h / 2.0), TS * 0.17, Color(0.95, 0.85, 0.45))
	if k >= NEW_TABLES:
		# the two tables at the socket tower: what is plugged into it
		for dev in DEVICES.size():
			if int(DEVICES[dev]["table"]) == k:
				_paint_device(ci, _device_local(dev), dev, _plugged(dev) and turm_op != null and turm_op.bag_state == "there")
		return
	# in front of everybody who studies: an open book, a pad or a laptop
	for s in SEATS:
		if int(s[0]) != k or String(s[3]) in ["hans", "fenster"] or RESERVATIONS.has(String(s[3])):
			continue
		var north: bool = s[2]
		var c := Vector2(float(SEAT_DX[k][int(s[1])]) * TS, (-h + 11.0) if north else -11.0)
		var what: int = (k * 7 + int(s[1]) * 3 + (1 if north else 0)) % 3
		match what:
			0:   # an open book
				ci.draw_rect(Rect2(c.x - 9.0, c.y - 5.0, 18.0, 10.0), Color("f3efe2"))
				ci.draw_line(c + Vector2(0, -5), c + Vector2(0, 5), Color("b9b2a0"), 1.0)
				for i in 3:
					ci.draw_line(c + Vector2(-7, -3 + i * 3), c + Vector2(-2, -3 + i * 3), Color("9aa0aa"), 1.0)
					ci.draw_line(c + Vector2(2, -3 + i * 3), c + Vector2(7, -3 + i * 3), Color("9aa0aa"), 1.0)
			1:   # a pad with notes and a marker
				ci.draw_rect(Rect2(c.x - 7.0, c.y - 5.0, 12.0, 10.0), Color("fff3b0"))
				for i in 3:
					ci.draw_line(c + Vector2(-5, -3 + i * 3), c + Vector2(3, -3 + i * 3), Color("8f8660"), 1.0)
				ci.draw_rect(Rect2(c.x + 7.0, c.y - 4.0, 2.5, 8.0), Color("ff5d8f"))
			_:   # a laptop
				ci.draw_rect(Rect2(c.x - 9.0, c.y - 5.0, 18.0, 10.0), Color("5f6b74"))
				ci.draw_rect(Rect2(c.x - 7.5, c.y - 3.5, 15.0, 7.0), Color("bfe3ff") if north else Color("2b3644"))


func _paint_chair_back(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-7.0, -2.0, 2.5, 4.0), Color("2b3644"))
	ci.draw_rect(Rect2(4.5, -2.0, 2.5, 4.0), Color("2b3644"))
	ci.draw_rect(Rect2(-8.0, -19.0, 16.0, 17.0), Color("3d4e63"))
	ci.draw_rect(Rect2(-6.0, -17.0, 12.0, 12.0), Color("4f6380"))


## Somebody who studies. Drawn once: they never move.
func _paint_reader(ci: CanvasItem, rd: Dictionary) -> void:
	var north: bool = rd["north"]
	ART.draw_character(ci, rd["look"], ART.FRONT if north else ART.BACK, 0.0, false)
	if not north:
		ci.draw_set_transform(Vector2(0, 2), 0.0, Vector2.ONE)
		_paint_chair_back(ci)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A backpack next to a chair: the zip is open as far as somebody got, and as long as the Mate
## is in it the neck of the bottle sticks out.
func _paint_rucksack(ci: CanvasItem, k: int) -> void:
	var bp: Dictionary = backpacks[k]
	var col: Color = bp["col"]
	ci.draw_rect(Rect2(-9.0, -3.0, 18.0, 5.0), Color(0, 0, 0, 0.25))
	if int(bp["left"]) > 0:
		_paint_bottle(ci, Vector2(3.0, -21.0))
	ci.draw_rect(Rect2(-7.5, -16.0, 15.0, 16.0), col)
	ci.draw_rect(Rect2(-7.5, -16.0, 15.0, 4.5), col.darkened(0.25))
	ci.draw_rect(Rect2(-4.5, -8.5, 9.0, 6.0), col.lightened(0.25))
	ci.draw_line(Vector2(-6.0, -11.5), Vector2(6.0, -11.5), col.darkened(0.45), 1.5)
	var open := clampf(float(bp["zip"]) / float(Rucksack.ZIP_HITS), 0.0, 1.0)
	if open > 0.0:
		ci.draw_line(Vector2(-6.0, -11.5), Vector2(-6.0 + 12.0 * open, -11.5), Color("101218"), 2.5)


## A bottle of Mate, `at` = the middle of its cap.
func _paint_bottle(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_rect(Rect2(at.x - 1.5, at.y - 1.0, 3.0, 2.0), Color("d9b44a"))
	ci.draw_rect(Rect2(at.x - 1.5, at.y + 1.0, 3.0, 4.0), Color("6b3f1d"))
	ci.draw_rect(Rect2(at.x - 3.0, at.y + 5.0, 6.0, 10.0), Color("6b3f1d"))
	ci.draw_rect(Rect2(at.x - 3.0, at.y + 7.5, 6.0, 4.0), Color("f1c40f"))


## A thing that lies around: `art` says what it is, the origin is where it lies.
func _paint_ding(ci: CanvasItem, art: String, col: Color) -> void:
	match art:
		"jacke":   # over the seat of the chair, the sleeves hang down at the sides
			ci.draw_rect(Rect2(-10.0, -18.0, 20.0, 14.0), col)
			ci.draw_rect(Rect2(-13.0, -16.0, 4.0, 13.0), col.darkened(0.18))
			ci.draw_rect(Rect2(9.0, -16.0, 4.0, 13.0), col.darkened(0.18))
			ci.draw_rect(Rect2(-4.0, -18.0, 8.0, 3.0), col.darkened(0.35))
			ci.draw_line(Vector2(0, -15), Vector2(0, -5), col.darkened(0.35), 1.0)
		"maeppli":   # an empty pencil case, and the one pen that was in it
			ci.draw_rect(Rect2(-9.0, -4.0, 18.0, 8.0), col)
			ci.draw_rect(Rect2(-9.0, -4.0, 18.0, 2.0), col.darkened(0.25))
			ci.draw_line(Vector2(-7, 0), Vector2(7, 0), Color("f3efe2"), 1.0)
			ci.draw_rect(Rect2(11.0, -3.0, 2.0, 7.0), Color("2f5d8c"))
		"laptop":   # shut for hours: the screen is dark
			ci.draw_rect(Rect2(-10.0, -2.0, 20.0, 8.0), col)
			ci.draw_rect(Rect2(-10.0, -13.0, 20.0, 11.0), col.darkened(0.3))
			ci.draw_rect(Rect2(-8.5, -11.5, 17.0, 8.0), Color("1b1d26"))
			ci.draw_circle(Vector2(0, -7.5), 1.5, Color("5f6b74"))
		"zf":   # a thick summary: a stack of sheets, marked in four colours, held by a clip
			ci.draw_rect(Rect2(-7.0, -8.0, 16.0, 13.0), col.darkened(0.2))
			ci.draw_rect(Rect2(-9.0, -10.0, 16.0, 13.0), col)
			var marks := ["ffc93c", "3ddc97", "ff5d8f", "4d8dff"]
			for i in 4:
				ci.draw_line(Vector2(-7, -7 + i * 2.8), Vector2(4.0 - (i % 2) * 3.0, -7 + i * 2.8), Color(String(marks[i]), 0.9), 1.6)
			ci.draw_rect(Rect2(3.0, -11.0, 2.0, 5.0), Color("6b7385"))
		"turm":   # a tower of sockets on a foot, with a little red light on top
			ci.draw_rect(Rect2(-9.0, -3.0, 18.0, 5.0), Color(0, 0, 0, 0.25))
			ci.draw_rect(Rect2(-8.0, -5.0, 16.0, 5.0), col.darkened(0.4))
			ci.draw_rect(Rect2(-5.5, -30.0, 11.0, 26.0), col)
			ci.draw_rect(Rect2(-5.5, -30.0, 3.0, 26.0), col.darkened(0.12))
			for i in 4:
				ci.draw_rect(Rect2(-2.5, -26.5 + i * 5.6, 6.0, 3.6), Color("3a3f46"))
			ci.draw_rect(Rect2(-1.5, -33.0, 3.0, 3.0), Color("ff5d5d"))


## Above the characters: how long a player has been sitting.
func _draw_oben(ci: CanvasItem) -> void:
	if main.state != "play":
		return
	var font := ThemeDB.fallback_font
	for pid in 2:
		if p_seat[pid] < 0 or main.done[pid].has("platz"):
			continue
		var c: Vector2 = main.players[pid].global_position + Vector2(0, -64)
		var col := Color(String(KEYS.TAG_COLORS[pid]))
		ci.draw_circle(c, 11.0, Color(0.08, 0.09, 0.17, 0.9))
		ci.draw_arc(c, 8.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(p_sit[pid] / SIT_TIME, 0.0, 1.0), 24, col, 3.0)
		var left := str(int(ceil(SIT_TIME - p_sit[pid])))
		var w := font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		ci.draw_string(font, c + Vector2(-w / 2.0, 3.5), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.WHITE)
	# the socket tower: while the minigame shows the order, the device in turn lights up; sparks
	# after a wrong plug
	if turm_pid >= 0 and not table_props.is_empty():
		var mg = main.minis[turm_pid]
		if mg != null and is_instance_valid(mg) and "seq_phase" in mg and String(mg.seq_phase) == "show" and int(mg.lit) >= 0 and float(mg.lit_t) > 0.0:
			var dp := _device_pos(int(mg.lit))
			ci.draw_arc(dp, 15.0 + 2.0 * sin(t * 14.0), 0.0, TAU, 24, UI.YELLOW, 3.0)
			ci.draw_line(dp, TURM * TS + Vector2(0, -14), Color(UI.YELLOW, 0.6), 2.0)
	if spark_t > 0.0:
		var sc := TURM * TS + Vector2(0, -18)
		var a := spark_t / SPARK_TIME
		for i in 8:
			var d := Vector2.from_angle(i * 0.785 + t * 9.0)
			ci.draw_line(sc + d * 5.0, sc + d * (12.0 + 10.0 * (1.0 - a)), Color(1.0, 0.9, 0.3, a), 2.0)
		ci.draw_circle(sc, 5.0 * a, Color(1.0, 1.0, 0.8, a))
	# whoever has a Mate carries the bottle around
	for pid in 2:
		if mate[pid]:
			_paint_bottle(ci, main.players[pid].global_position + Vector2(-11.0, -30.0))
	# what a player is carrying out of the library, held in front of the chest
	for pid in 2:
		var op = _carried(pid)
		if op == null:
			continue
		ci.draw_set_transform(main.players[pid].global_position + Vector2(9, -20), 0.0, Vector2(0.8, 0.8))
		_paint_ding(ci, String(loot[op]["art"]), op.bag_col)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for rd in readers:
		if rd["psst"] <= 0.0:
			continue
		var a := clampf(float(rd["psst"]) / 0.4, 0.0, 1.0)
		var bc: Vector2 = (rd["pos"] as Vector2) + Vector2(0, -58)
		var txt := tr("Psst!")
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		ci.draw_rect(Rect2(bc.x - tw / 2.0 - 4.0, bc.y - 9.0, tw + 8.0, 13.0), Color(0.08, 0.09, 0.17, 0.85 * a))
		ci.draw_string(font, bc + Vector2(-tw / 2.0, 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, a))
