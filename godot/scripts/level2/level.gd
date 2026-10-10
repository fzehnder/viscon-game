extends Node2D
## Level 2 · Mensa-Stau (day, two players). Definition (DEF), Mensa furniture (build_map) and logic.
## Everything of this level lives in this folder (found by levels.gd through the folder name).
##
## The queue works like a traffic jam: everybody follows the person in front. When that person
## moves up, the one behind needs a moment to notice (green bubble with a ring that runs down).
## During that moment there is a gap, and a player who sneaks into it is in the line.
## Whoever steps in front of somebody who is paying attention gets caught, and the first places
## are watched by the cashier (light cone). Noise makes people attentive (yellow "!"), then they
## close gaps at once. At the head of the line you get your menu (timing minigame), then both
## sit down at the same table and the cutscene with the Basisprüfung e-mail plays.
## Whoever you push in front of becomes an Opp (see opp.gd and Game.opps): they stay in the line
## here, but they remember your face and come back in later levels.
##
## All positions are in tiles (1 tile = 32 px) unless a name ends in _px.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const CH = preload("res://scripts/characters.gd")
const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const Guest = preload("res://scripts/level2/mensa_guest.gd")
const Cutscene = preload("res://scripts/cutscene.gd")

const DEF := {
	"name": "Mensa-Stau",
	"tag": "LEVEL 2",
	"mode": "day",
	"time": 180.0,
	"start": Vector2(22.4, 61.3),   # on the Polyterrasse, in front of the Mensa door
	"timer_title": "MENSA SCHLIESST IN",
	"intro": "Mittag! Die Schlange in der Mensa ist endlos, und die Ausgabe macht gleich zu. Hinten anstellen reicht nie. Beide müssen alles erledigen:",
	"hint": "Wie im Stau: Rückt jemand auf, braucht die Person dahinter einen Moment (grüne Blase). Genau dann leise in die Lücke schleichen.",
	"start_toast": ["Ab in die Mensa!", "Stellt euch neben die Schlange, wartet auf eine Lücke und schleicht hinein. Vorne an der Kasse passt die Kassiererin auf."],
	"win_title": "Satt und angemeldet",
	"win_text": "%s & %s haben sich ein Menü erdrängelt. Die Basisprüfung gibt es gratis dazu.",
	"lose_title": "Mensa geschlossen",
	"lose_text": "Die Ausgabe ist zu, und ihr steht mit leerem Magen da. Hinten anstellen dauert zu lange: Drängelt euch weiter vorne in eine Lücke.",
	"tasks": [
		{"id": "queue", "name": "Vordrängeln", "where": "in eine Lücke der Schlange schleichen", "type": "level"},
		{"id": "food", "name": "Menü holen", "where": "ganz vorne an der Kasse", "type": "level"},
		{"id": "sit", "name": "Zusammen hinsetzen", "where": "zu zweit an denselben Tisch", "type": "level"},
	],
}

# ---- queue (tuning)
const PATH := [Vector2(15.4, 74.5), Vector2(32.3, 74.5), Vector2(32.3, 65.7), Vector2(24.4, 65.7), Vector2(24.4, 50.0)]   # head first
const INSIDE := 3                       # the first three legs of PATH are inside the Mensa
const SP := 0.95                        # distance between two people in the line
const N_QUEUE := 34                     # people in the line: too many to wait at the end, it reaches out of the door
const SERVICE := Vector2(3.0, 4.0)      # seconds at the till
const REACT := Vector2(0.9, 1.5)        # seconds until somebody notices the gap in front
const HEADPHONES := 1.45                # people with headphones need this much longer
const Q_SPEED := 1.7                    # tiles per second when moving up
const NOTICE := 0.3                     # a gap this much wider than normal means "the line has moved"
const ALERT := 2.5                      # seconds of attention after hearing a noise
const ENTER_D := 0.22 * TS              # this close to the middle of the lane = stepped into the line
const LEAVE_D := 0.62 * TS              # further away than this = left the line
const EAT := Vector2(30.0, 48.0)
const N_SIT := 14                       # guests who already sit when the level starts
const GRUDGE := 5.0                     # seconds until somebody realises that you slipped in in front of them
const MAX_OPPS := 3                     # at most this many Opps come out of this level
const OPP_NAMES := ["Jonas", "Mia", "Luca", "Sara", "Nico", "Elin", "Tim", "Lea"]

# ---- cashier
const TILL := Vector2(15.4, 75.6)
const CONE_APEX := Vector2(14.6, 75.5)
const CONE_DIR := -0.873                 # rad: up and to the right, along the line
const CONE_HALF := 0.785
const CONE_RANGE := 4.1                 # covers the first four places of the line

# ---- furniture
const COUNTER := Rect2(14.0, 75.15, 18.7, 0.9)
const RACK := Rect2(13.15, 73.2, 1.75, 1.9)
const TABLE_X := [14.6, 20.0, 25.4]
const TABLE_Y := [67.5, 70.55]
const TABLE_SIZE := Vector2(3.4, 1.15)
const SEAT_DX := [0.6, 1.7, 2.8]
const STAFF := [Vector2(14.6, 76.55), Vector2(21.5, 76.55), Vector2(27.5, 76.55)]   # the first one is the cashier
const STAFF_LOOK := {"skin": "e0ac85", "hair": "3b2a1e", "hair_style": "cap", "top": "f3f3f0", "top_style": "labcoat",
	"accent": "e9ece8", "pants": "3b3f46", "shoes": "1f1f24", "acc": []}
const FOODS := ["a5612a", "e3b23c", "6fae4f", "e8dcc0", "c0392b", "e8c98a", "8fbf6a", "b5651d"]

var main
var t := 0.0
var rng := RandomNumberGenerator.new()
# queue path
var pts := PackedVector2Array()       # corner points in px
var cum := PackedFloat32Array()       # distance from the head to each corner, in tiles
var total := 0.0
var members: Array = []               # the line, head first: guests and players
var joiners: Array = []               # guests on their way to the end of the line
var guests: Array = []                # all guests (not the staff)
var spawn_t := 3.0
# players
var p_member: Array = [false, false]
var p_qs: Array = [0.0, 0.0]
var p_out: Array = [0.0, 0.0]         # time spent beside the lane while still counted as in line
var p_cool: Array = [0.0, 0.0]        # after being caught: no new attempt for a moment
var p_stun: Array = [0.0, 0.0]
var p_food: Array = [false, false]
var p_seat: Array = [-1, -1]
var p_col: Array = [[0, 0], [0, 0]]   # collision layer and mask before sitting down
var hint_noise := false
var hint_tail := false
var opp_count := 0
var opp_names: Array = []
# tables and seats
var tables: Array = []                # Rect2
var table_props: Array = []
var seats: Array = []                 # {"pos": px, "stand": px, "table": int, "north": bool, "who": node or null, "tray": bool}
var cone: Polygon2D
var cone_flash := 0.0


## Furniture that sorts with the characters (tables hide the legs of whoever sits behind them).
class Prop:
	extends Node2D
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


# ================================================================== map
## Called by map_data.gd: replaces the simple Mensa furniture with counter, tables and chairs.
static func build_map(md) -> void:
	md.objs = md.objs.filter(func(o): return not (o["kind"] in ["mcounter", "mtable"]))
	md.R("l2_counter", COUNTER.position.x, COUNTER.position.y, COUNTER.size.x, COUNTER.size.y)
	md.R("l2_rack", RACK.position.x, RACK.position.y, RACK.size.x, RACK.size.y)
	for ty in TABLE_Y:
		for tx in TABLE_X:
			md.R("l2_table", tx, ty, TABLE_SIZE.x, TABLE_SIZE.y)
			for dx in SEAT_DX:
				md.R("chair", tx + dx - 0.33, ty - 0.6, 0.66, 0.55, {"solid": false})
	for l in md.labels:
		if l["t"] == "MENSA POLYTERRASSE":
			l["p"] = Vector2(23.5, 72.8)
			l["sz"] = 0.5
	# no students strolling through the queue
	md.student_zones = md.student_zones.filter(func(z): return not (z[0] == 13 and z[1] == 65))


# ================================================================== setup
func _ready() -> void:
	z_index = -5   # floor decoration: above the map, below the characters
	rng.randomize()
	_build_path()
	_build_tables()
	_spawn_staff()
	_spawn_queue()
	for k in N_SIT:
		_spawn_sitter()
	cone = Polygon2D.new()
	var poly := PackedVector2Array([CONE_APEX * TS])
	for i in 17:
		var a := CONE_DIR - CONE_HALF + 2.0 * CONE_HALF * i / 16.0
		poly.append((CONE_APEX + Vector2.from_angle(a) * CONE_RANGE) * TS)
	cone.polygon = poly
	cone.color = Color(1.0, 0.93, 0.6, 0.2)
	add_child(cone)
	for pl in main.players:
		pl.collision_mask |= 32   # people in the line are solid for the players


func _build_path() -> void:
	var d := 0.0
	for i in PATH.size():
		if i > 0:
			d += (PATH[i] as Vector2).distance_to(PATH[i - 1])
		pts.append((PATH[i] as Vector2) * TS)
		cum.append(d)
	total = d
	# guests on their way to a seat should not walk along the queue
	var astar: AStarGrid2D = main.world.astar
	var s := 0.0
	while s < total:
		var tile := Vector2i((_pos_at(s) / TS).floor())
		if astar.is_in_boundsv(tile) and not astar.is_point_solid(tile):
			astar.set_point_weight_scale(tile, 6.0)
		s += 0.5


func _build_tables() -> void:
	for ty in TABLE_Y:
		for tx in TABLE_X:
			var k := tables.size()
			var r := Rect2(tx, ty, TABLE_SIZE.x, TABLE_SIZE.y)
			tables.append(r)
			var tp := Prop.new()
			tp.position = Vector2(r.get_center().x, r.end.y) * TS
			tp.paint = func(ci): _paint_table(ci, k)
			main.actors.add_child(tp)
			table_props.append(tp)
			for dx in SEAT_DX:
				# far side: sits behind the table and looks at us, the table hides the legs
				seats.append({"pos": Vector2(tx + dx, ty + 0.42) * TS, "stand": Vector2(tx + dx, ty - 0.7) * TS,
					"table": k, "north": true, "who": null, "tray": false})
			for dx in SEAT_DX:
				# near side: we see the back, a chair back hides the legs
				var sp := Vector2(tx + dx, r.end.y + 0.5) * TS
				seats.append({"pos": sp, "stand": sp, "table": k, "north": false, "who": null, "tray": false})
				var cp := Prop.new()
				cp.position = sp + Vector2(0, 2)
				cp.paint = _paint_chair_back
				main.actors.add_child(cp)


func _new_guest():
	var g = Guest.new()
	g.main = main
	g.look = CH.random_student(rng)
	g.look["acc"] = (g.look["acc"] as Array).filter(func(a): return a != "laptop")
	g.slow = HEADPHONES if (g.look["acc"] as Array).has("headphones") else 1.0
	g.speed = rng.randf_range(58.0, 74.0)
	main.actors.add_child(g)
	guests.append(g)
	return g


func _spawn_staff() -> void:
	for p in STAFF:
		var g = Guest.new()
		g.main = main
		g.mode = "still"
		g.look = STAFF_LOOK.duplicate(true)
		g.facing = ART.BACK
		g.position = (p as Vector2) * TS
		main.actors.add_child(g)


func _spawn_queue() -> void:
	for k in N_QUEUE:
		var g = _new_guest()
		g.qs = k * SP
		_enqueue(g)
		_place(g)
	members[0].q_state = "served"
	members[0].q_total = SERVICE.y
	members[0].q_timer = rng.randf_range(1.0, SERVICE.y)


func _spawn_sitter() -> void:
	var k := _pick_seat()
	if k < 0:
		return
	var g = _new_guest()
	seats[k]["who"] = g
	g.seat = k
	g.global_position = seats[k]["pos"]
	_sit_guest(g)
	g.eat_t = rng.randf_range(8.0, 110.0)


func _enqueue(g) -> void:
	g.mode = "queue"
	g.q_state = "wait"
	g.collision_layer = 32
	members.append(g)


# ================================================================== queue path
func _seg(s: float) -> int:
	for i in range(1, cum.size()):
		if s <= cum[i]:
			return i - 1
	return cum.size() - 2


func _pos_at(s: float) -> Vector2:
	s = clampf(s, 0.0, total)
	var i := _seg(s)
	return pts[i].lerp(pts[i + 1], (s - cum[i]) / maxf(0.001, cum[i + 1] - cum[i]))


## Unit vector along the lane, pointing away from the head.
func _dir_at(s: float) -> Vector2:
	var i := _seg(clampf(s, 0.0, total))
	return (pts[i + 1] - pts[i]).normalized()


## Unit vector from the lane into the room (the other side is the counter or a wall).
func _open_side(s: float) -> Vector2:
	var d := _dir_at(s)
	return Vector2(d.y, -d.x)


## Closest point of the lane to `p_px`: [distance from the head in tiles, distance to the lane in px].
func _project(p_px: Vector2) -> Array:
	var best_d := INF
	var best_s := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var ab := pts[i + 1] - a
		var u := clampf((p_px - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p_px.distance_to(a + ab * u)
		if d < best_d:
			best_d = d
			best_s = cum[i] + u * (cum[i + 1] - cum[i])
	return [best_s, best_d]


func _is_player(m) -> bool:
	return main.players.has(m)


func _qs(m) -> float:
	var pid: int = main.players.find(m)
	return p_qs[pid] if pid >= 0 else m.qs


func _tail_s() -> float:
	return -SP if members.is_empty() else _qs(members[members.size() - 1])


func _in_cone(p_px: Vector2) -> bool:
	var v := p_px / TS - CONE_APEX
	return v.length() <= CONE_RANGE and absf(wrapf(v.angle() - CONE_DIR, -PI, PI)) <= CONE_HALF


func _place(g) -> void:
	g.global_position = _pos_at(g.qs)
	match g.q_state:
		"react":
			g.face(-_open_side(g.qs))   # looks at the food or the wall, not at the line
		"served":
			g.face(Vector2.DOWN)
		_:
			g.face(-_dir_at(g.qs))


# ================================================================== loop
func _process(delta: float) -> void:
	t += delta
	cone_flash = maxf(0.0, cone_flash - delta * 1.6)
	cone.color = Color(1.0, 0.93 - cone_flash * 0.6, 0.6 - cone_flash * 0.45, 0.2 + cone_flash * 0.25)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not (main.state in ["play", "cutscene"]):
		return
	if main.state == "play":
		_update_players(delta)
	_update_queue(delta)
	for g in guests.duplicate():
		if g.grudge_t > 0.0:
			g.grudge_t -= delta
			if g.grudge_t <= 0.0:
				var who := _make_opp(g, g.grudge_by, "vorgedrängelt")
				if who != "" and main.state == "play":
					main.hud.toast("Neuer Opp: %s" % who, "%s hat gemerkt, dass du dich vorgedrängelt hast, und merkt sich dein Gesicht. Ihr seht euch wieder." % who, 4.5)
		if g.mode == "sit":
			g.eat_t -= delta
			if g.eat_t <= 0.0:
				_guest_done(g)
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = 2.5
		var n := joiners.size()
		for m in members:
			if not _is_player(m):
				n += 1
		if n < N_QUEUE:
			_spawn_joiner()


## Follow-the-leader with a reaction time: this is what makes the queue behave like a traffic jam.
func _update_queue(delta: float) -> void:
	var leaving = null
	for i in members.size():
		var g = members[i]
		if _is_player(g):
			continue
		var target: float = 0.0 if i == 0 else _qs(members[i - 1]) + SP
		var gap: float = g.qs - target
		g.moving = false
		match g.q_state:
			"wait":
				if gap > NOTICE:
					g.q_state = "react"
					g.q_total = rng.randf_range(REACT.x, REACT.y) * g.slow
					g.q_timer = g.q_total
				elif i == 0 and g.qs <= 0.05:
					g.q_state = "served"
					g.q_total = rng.randf_range(SERVICE.x, SERVICE.y)
					g.q_timer = g.q_total
			"react":
				if g.alert_t > 0.0:
					g.q_timer = minf(g.q_timer, 0.12)
				g.q_timer -= delta
				if gap <= NOTICE * 0.5:
					g.q_state = "wait"   # somebody took the gap
				elif g.q_timer <= 0.0:
					g.q_state = "move"
			"move":
				if gap > 0.0:
					g.qs = maxf(target, g.qs - Q_SPEED * delta)
					g.moving = true
				if g.qs - target <= 0.01:
					g.q_state = "wait"
			"served":
				g.q_timer -= delta
				if g.q_timer <= 0.0:
					leaving = g
		_place(g)
	if leaving != null:
		members.erase(leaving)
		_send_to_seat(leaving)


func _update_players(delta: float) -> void:
	for pid in main.players.size():
		var pl = main.players[pid]
		p_cool[pid] = maxf(0.0, p_cool[pid] - delta)
		if p_stun[pid] > 0.0:
			p_stun[pid] -= delta
			if p_stun[pid] <= 0.0 and not main.busy(pid) and p_seat[pid] < 0:
				pl.enabled = true
			continue
		if p_seat[pid] >= 0:
			continue
		var pr := _project(pl.global_position)
		var s: float = pr[0]
		var d: float = pr[1]
		if p_member[pid]:
			# keep the order of the line: never in front of the one ahead or behind the one after
			var idx := members.find(pl)
			if idx > 0:
				s = maxf(s, _qs(members[idx - 1]) + 0.3)
			if idx < members.size() - 1:
				s = minf(s, _qs(members[idx + 1]) - 0.3)
			p_qs[pid] = s
			if d > LEAVE_D:
				p_out[pid] += delta
				if p_out[pid] > 0.2:
					_leave(pid, true)
			else:
				p_out[pid] = 0.0
		elif d < ENTER_D and p_cool[pid] <= 0.0 and s <= _tail_s() + 1.3 * SP:
			if p_food[pid]:
				_eject(pid)
				main.hud.toast("Du hast schon ein Menü", "Raus aus der Schlange und ab an einen Tisch.", 2.5)
			else:
				_try_insert(pid, s)


# ================================================================== players in the line
func _try_insert(pid: int, s: float) -> void:
	var pl = main.players[pid]
	var idx := members.size()
	for k in members.size():
		if _qs(members[k]) > s:
			idx = k
			break
	var behind = members[idx] if idx < members.size() else null
	if behind != null and not _is_player(behind):
		if _in_cone(pl.global_position):
			_caught(pid, behind, true)
			return
		if behind.q_state != "react" or behind.alert_t > 0.0:
			_caught(pid, behind, false)
			return
	members.insert(idx, pl)
	p_member[pid] = true
	p_qs[pid] = s
	p_out[pid] = 0.0
	if behind != null and not _is_player(behind) and behind.grudge_t <= 0.0:
		behind.grudge_t = GRUDGE   # distracted now, but not for ever
		behind.grudge_by = pid
	if behind != null:
		# somebody is behind us now: that is jumping the queue (a teammate may also keep a gap open)
		if main.done[pid].has("queue"):
			UI.sfx("pop")
		else:
			main._task_done(pid, "queue")
			main.hud.toast("Drin!", "Rück selber mit auf, bis du an der Kasse bist. Tipp: Lass vor dir eine Lücke, dann kann %s dort hinein." % Game.name_of(1 - pid), 5.0)
	elif not hint_tail:
		hint_tail = true
		main.hud.toast("Brav hinten angestellt", "Von hier dauert es zu lange. Weiter vorne geht immer wieder eine Lücke auf.", 5.0)


func _leave(pid: int, lost: bool) -> void:
	members.erase(main.players[pid])
	p_member[pid] = false
	p_out[pid] = 0.0
	if lost and not p_food[pid] and main.state == "play":
		main.hud.toast("Platz verloren", "Wer aus der Schlange tritt, ist raus. Die nächste Lücke kommt bestimmt.", 2.5)


func _caught(pid: int, by, cashier: bool) -> void:
	main.mistakes_total += 1
	p_cool[pid] = 1.5
	for m in members:
		if not _is_player(m) and absf(m.qs - by.qs) < 4.5 * SP:
			m.alert_t = maxf(m.alert_t, 4.0)
	var pl = main.players[pid]
	main.fx.sound(pl.global_position, 2.6 * TS, Color(1.0, 0.4, 0.4, 0.7), 0.6)
	UI.sfx("fail")
	var who := _make_opp(by, pid, "beim Vordrängeln erwischt")
	var extra := "" if who == "" else " Neuer Opp: %s merkt sich dein Gesicht." % who
	if cashier:
		cone_flash = 1.0
		main.hud.toast("Erwischt!", "Kassiererin: «Hallo? Hinten anstellen, gell!» Die vordersten Plätze hat sie im Blick.%s" % extra, 4.5)
	else:
		main.hud.toast("Erwischt!", "«Hey, nicht drängeln!» Nur wer gerade abgelenkt ist (grüne Blase), merkt nichts.%s" % extra, 4.5)
	_eject(pid)


## The guest `g` now has it in for player `pid`: an Opp, also in later levels. Returns the name
## if this is a new Opp, "" otherwise (already one, or the level has made enough).
func _make_opp(g, pid: int, why: String) -> String:
	g.grudge_t = -1.0
	if g.opp_id != "":
		var by: Array = Game.opps[g.opp_id]["by"]
		if not by.has(pid):
			by.append(pid)
			Game.add_opp(g.opp_id, g.pname, g.look, by, why)
		g.angry_t = 3.0
		return ""
	if opp_count >= MAX_OPPS:
		return ""
	if opp_names.is_empty():
		opp_names = OPP_NAMES.duplicate()
		opp_names.shuffle()
	g.pname = opp_names[opp_count % opp_names.size()]
	opp_count += 1
	g.opp_id = "draengler_%d" % opp_count
	g.angry_t = 3.0
	var look: Dictionary = g.look.duplicate(true)
	_set_acc(look, "tray", false)
	Game.add_opp(g.opp_id, g.pname, look, [pid], why)
	UI.sfx("doom", -9.0)
	main.fx.sound(g.global_position, 2.6 * TS, Color(1.0, 0.4, 0.4, 0.7), 0.8)
	return g.pname


## Pushes a player out of the lane, into the room.
func _eject(pid: int) -> void:
	var pl = main.players[pid]
	var pr := _project(pl.global_position)
	var out: Vector2 = _pos_at(pr[0]) + _open_side(pr[0]) * 1.3 * TS
	pl.enabled = false
	p_stun[pid] = 0.5
	create_tween().tween_property(pl, "global_position", out, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _at_till(pid: int) -> bool:
	return p_member[pid] and members[0] == main.players[pid] and p_qs[pid] < 0.55 * SP


func _order(pid: int) -> void:
	var on_ok := func(): _got_food(pid)
	main.open_minigame("timing", {"title": "Menü schöpfen", "hits": 3, "verb": "Kelle", "speed": 300.0}, on_ok, pid)


func _got_food(pid: int) -> void:
	var pl = main.players[pid]
	p_food[pid] = true
	_set_acc(pl.look, "tray", true)
	pl.queue_redraw()
	UI.sfx("steal")
	main.done[pid]["queue"] = true   # whoever waited at the end is through as well
	main._task_done(pid, "food")
	_leave(pid, false)
	_eject(pid)   # steps out of the line with the tray, the next one can move up


# ================================================================== guests
func _set_acc(look: Dictionary, what: String, on: bool) -> void:
	var acc: Array = look.get("acc", [])
	acc.erase(what)
	if on:
		acc.append(what)
	look["acc"] = acc


func _free_at(table: int) -> int:
	var n := 0
	for st in seats:
		if st["table"] == table and st["who"] == null:
			n += 1
	return n


## A free seat for a guest, or -1. Guests keep away from a table where a player sits, and they
## always leave one table with two free seats for the players.
func _pick_seat() -> int:
	var taken := -1   # table with a player
	for pid in 2:
		if p_seat[pid] >= 0:
			taken = seats[p_seat[pid]]["table"]
	var cand: Array = []
	for k in seats.size():
		if seats[k]["who"] == null and seats[k]["table"] != taken:
			cand.append(k)
	while not cand.is_empty():
		var k: int = cand.pop_at(rng.randi() % cand.size())
		if taken >= 0:
			return k
		for t2 in tables.size():
			if _free_at(t2) - (1 if t2 == seats[k]["table"] else 0) >= 2:
				return k
	return -1


func _send_to_seat(g) -> void:
	g.collision_layer = 0
	g.q_state = "wait"
	g.alert_t = 0.0
	_set_acc(g.look, "tray", true)
	var step_out: Vector2 = g.global_position + _open_side(0.0) * 1.1 * TS
	var k := _pick_seat()
	if k < 0:
		_walk_out(g, step_out)   # no seat: takes the menu outside
		return
	var st: Dictionary = seats[k]
	st["who"] = g
	g.seat = k
	var p: Array = [step_out]
	p.append_array(main.world.find_path(step_out, st["stand"]))
	p.append(st["stand"])
	p.append(st["pos"])
	g.walk(p, func(): _sit_guest(g))


func _sit_guest(g) -> void:
	var st: Dictionary = seats[g.seat]
	g.mode = "sit"
	g.facing = ART.FRONT if st["north"] else ART.BACK
	g.eat_t = rng.randf_range(EAT.x, EAT.y)
	_set_acc(g.look, "tray", false)
	st["tray"] = true
	table_props[st["table"]].queue_redraw()


func _guest_done(g) -> void:
	var st: Dictionary = seats[g.seat]
	st["who"] = null
	st["tray"] = false
	table_props[st["table"]].queue_redraw()
	g.seat = -1
	_walk_out(g, st["stand"])


## Out of the door and away over the Polyterrasse.
func _walk_out(g, first: Vector2) -> void:
	var goal := Vector2(rng.randf_range(13.0, 35.0), 49.5) * TS
	var p: Array = [first]
	p.append_array(main.world.find_path(first, goal))
	g.walk(p, func():
		guests.erase(g)
		g.queue_free())


func _spawn_joiner() -> void:
	var g = _new_guest()
	g.global_position = Vector2(rng.randf_range(19.0, 30.0), 49.5) * TS
	joiners.append(g)
	_route_joiner(g)


func _route_joiner(g) -> void:
	var goal := _pos_at(minf(total - 0.2, _tail_s() + SP * (1.5 + joiners.find(g))))
	var p: Array = main.world.find_path(g.global_position, goal)
	p.append(goal)
	g.walk(p, func(): _joiner_arrived(g))


func _joiner_arrived(g) -> void:
	var pr := _project(g.global_position)
	if pr[0] < _tail_s() + SP * 0.9 or pr[1] > TS:
		_route_joiner(g)   # the end of the line is somewhere else by now
		return
	joiners.erase(g)
	g.qs = pr[0]
	_enqueue(g)


# ================================================================== hooks called by main.gd
## Footsteps and minigame mistakes: whoever hears them pays attention for a while.
func on_noise(at: Vector2, radius: float) -> void:
	var any := false
	for m in members:
		if _is_player(m) or m.global_position.distance_to(at) >= radius:
			continue
		if m.alert_t <= 0.0:
			any = true
		m.alert_t = maxf(m.alert_t, ALERT)
	if any and not hint_noise and main.time_played > 8.0:
		hint_noise = true
		main.hud.toast("Psst! Zu laut!", "Wer euch hört, passt auf und rückt sofort nach. Schleichen: %s Ctrl, %s -" % [Game.name_of(0), Game.name_of(1)], 5.0)


func update_near(pid: int) -> void:
	var pl = main.players[pid]
	if p_seat[pid] >= 0:
		if not main.done[pid].has("sit"):
			main.nears[pid] = {"use": "level", "act": "stand", "label": "Aufstehen", "rect": _seat_rect(p_seat[pid])}
		return
	if _at_till(pid) and not p_food[pid]:
		main.nears[pid] = {"use": "level", "act": "food", "label": "Menü schöpfen",
			"rect": Rect2(TILL - Vector2(0.55, 0.5), Vector2(1.1, 0.95))}
		return
	if not p_food[pid]:
		return
	var best := 0.9 * TS
	for k in seats.size():
		var st: Dictionary = seats[k]
		if st["who"] != null:
			continue
		var dd: float = pl.global_position.distance_to(st["stand"])
		if dd < best:
			best = dd
			main.nears[pid] = {"use": "level", "act": "sit", "seat": k, "label": "Hinsetzen", "rect": _seat_rect(k)}


func interact(pid: int, o: Dictionary) -> void:
	match o["act"]:
		"food":
			_order(pid)
		"sit":
			_sit(pid, o["seat"])
		"stand":
			_stand(pid)


func _seat_rect(k: int) -> Rect2:
	return Rect2((seats[k]["pos"] as Vector2) / TS - Vector2(0.42, 1.4), Vector2(0.84, 1.55))


func _sit(pid: int, k: int) -> void:
	var st: Dictionary = seats[k]
	if st["who"] != null:
		return
	var pl = main.players[pid]
	st["who"] = pl
	st["tray"] = true
	p_seat[pid] = k
	p_col[pid] = [pl.collision_layer, pl.collision_mask]
	pl.collision_layer = 0   # the far seats are inside the table's collision box
	pl.collision_mask = 0
	pl.enabled = false
	pl.dir = PI / 2.0 if st["north"] else -PI / 2.0
	pl.facing = ART.FRONT if st["north"] else ART.BACK
	_set_acc(pl.look, "tray", false)
	create_tween().tween_property(pl, "global_position", st["pos"], 0.18)
	table_props[st["table"]].queue_redraw()
	UI.sfx("pop")
	var other: int = p_seat[1 - pid]
	if other < 0:
		main.hud.toast("Platz gesichert", "Jetzt fehlt noch %s am selben Tisch." % Game.name_of(1 - pid), 3.0)
	elif seats[other]["table"] != st["table"]:
		main.hud.toast("Falscher Tisch", "Ihr sitzt an verschiedenen Tischen. Setzt euch zusammen!", 3.0)
	else:
		for i in 2:
			main._task_done(i, "sit")


func _stand(pid: int) -> void:
	var st: Dictionary = seats[p_seat[pid]]
	var pl = main.players[pid]
	st["who"] = null
	st["tray"] = false
	p_seat[pid] = -1
	_set_acc(pl.look, "tray", true)
	table_props[st["table"]].queue_redraw()
	var tw := create_tween()
	tw.tween_property(pl, "global_position", st["stand"], 0.18)
	tw.tween_callback(func():
		pl.collision_layer = p_col[pid][0]
		pl.collision_mask = p_col[pid][1]
		if main.state == "play":
			pl.enabled = true)


## Goal markers for the HUD: [position in px, colour of whoever still needs it].
func goal_positions(id: String, n0: bool, n1: bool) -> Array:
	var out: Array = []
	match id:
		"queue":
			var w0: bool = n0 and not p_member[0]
			var w1: bool = n1 and not p_member[1]
			if not (w0 or w1):
				return out
			for i in range(1, members.size()):
				var g = members[i]
				if _is_player(g) or g.q_state != "react" or g.alert_t > 0.0:
					continue
				var p := _pos_at(g.qs - SP)
				if not _in_cone(p):
					out.append([p + Vector2(0, -8), main._need_color(w0, w1)])
		"food":
			out.append([(TILL + Vector2(0, 0.55)) * TS, main._need_color(n0, n1)])
		"sit":
			var w0: bool = n0 and p_food[0] and p_seat[0] < 0
			var w1: bool = n1 and p_food[1] and p_seat[1] < 0
			if not (w0 or w1):
				return out
			var only := -1   # the table where the other one already sits
			for pid in 2:
				if p_seat[pid] >= 0:
					only = seats[p_seat[pid]]["table"]
			for k in tables.size():
				if (only < 0 and _free_at(k) >= 2) or k == only:
					out.append([(tables[k] as Rect2).get_center() * TS, main._need_color(w0, w1)])
	return out


## Called by main.gd when every task is done: the Basisprüfung cutscene, then the win screen.
func finale(done: Callable) -> void:
	main.state = "cutscene"
	main.hud.visible = false
	for pl in main.players:
		pl.enabled = false
	var cam: Camera2D = main.cams[0]
	create_tween().tween_property(cam, "zoom", Vector2(3.5, 3.5), 0.9).set_trans(Tween.TRANS_SINE)
	var a: String = Game.name_of(0)
	var b: String = Game.name_of(1)
	var steps := [
		{"say": 0, "text": "Geschafft. Erster Tag an der ETH, erstes Mensa-Menü."},
		{"say": 1, "text": "Und niemand hat gemerkt, dass wir uns einfach reingehackt haben."},
		{"phones": "ETH Zürich · Prüfungsplanstelle", "text": "Bestätigung: Ihre Anmeldung zur Basisprüfung"},
		{"say": 0, "text": "Hat dein Handy auch gerade vibriert?"},
		{"mail": {"from": "Prüfungsplanstelle ETH Zürich", "to": "%s, %s" % [a, b],
			"subject": "Bestätigung: Ihre Anmeldung zur Basisprüfung",
			"body": "Guten Tag\n\nSie sind verbindlich für die Basisprüfung angemeldet:\n\n      •  Analysis I\n      •  Lineare Algebra\n      •  Diskrete Mathematik\n      •  Einführung in die Programmierung\n\nDie Prüfungen finden in drei Wochen statt. Eine Abmeldung ist nicht mehr möglich.\n\nFreundliche Grüsse\nIhre Prüfungsplanstelle",
			"footer": "Abmelden  (Frist abgelaufen)"}},
		{"say": 1, "text": "Basisprüfung?! Wir haben uns doch nirgends angemeldet!"},
		{"say": 0, "text": "Doch. Unser Hack hat überall «zugelassen» eingetragen. Auch bei den Prüfungen."},
		{"title": "BASISPRÜFUNG", "sub": "in 3 Wochen  ·  Abmeldung nicht möglich"},
	]
	var cs = Cutscene.new()
	main.add_child(cs)
	cs.play(steps, func():
		main.hud.visible = true
		done.call())


# ================================================================== drawing
func _ell(c: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	draw_arc(Vector2.ZERO, rx, 0.0, TAU, 28, col, width)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	# lane on the floor: a blue band with arrows towards the till
	var blue := UI.ETH_BLUE
	for i in INSIDE:
		var a := pts[i]
		var b := pts[i + 1]
		var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()).grow(0.4 * TS)
		draw_rect(r, Color(blue, 0.1))
	var s := 1.4
	while s < cum[INSIDE]:
		var c := _pos_at(s)
		var d := -_dir_at(s)
		var n := Vector2(-d.y, d.x)
		draw_polyline(PackedVector2Array([c - d * 5.0 + n * 6.0, c + d * 3.0, c - d * 5.0 - n * 6.0]), Color(blue, 0.38), 2.0)
		s += 1.9
	# open gaps that can be taken right now
	if main.state == "play":
		var pulse := 0.55 + 0.45 * sin(t * 9.0)
		for i in range(1, members.size()):
			var g = members[i]
			if _is_player(g) or g.q_state != "react" or g.alert_t > 0.0:
				continue
			var gp := _pos_at(g.qs - SP)
			if not _in_cone(gp):
				_ell(gp, 11.0, 5.0, Color(UI.GREEN, pulse), 2.0)
	_draw_rack()
	_draw_counter()


func _draw_rack() -> void:
	var r := Rect2(RACK.position * TS, RACK.size * TS)
	draw_rect(Rect2(r.position + Vector2(2.5, 3.5), r.size), Color(0, 0, 0, 0.32))
	draw_rect(r, Color("7f8a94"))
	draw_rect(r.grow(-3.0), Color("aab4bd"))
	for i in 4:   # stacks of trays
		var y := r.position.y + 6.0 + i * 13.5
		draw_rect(Rect2(r.position.x + 7.0, y, r.size.x - 14.0, 9.5), Color("9a6431"))
		draw_rect(Rect2(r.position.x + 7.0, y, r.size.x - 14.0, 7.0), Color("c98a4b"))


func _draw_counter() -> void:
	var r := Rect2(COUNTER.position * TS, COUNTER.size * TS)
	draw_rect(Rect2(r.position + Vector2(2.5, 3.5), r.size), Color(0, 0, 0, 0.32))
	draw_rect(r, Color("9aa4ad"))
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, r.size.y * 0.45), Color("c6ced5"))
	# food containers
	var x := r.position.x + 2.6 * TS
	var i := 0
	while x + 1.5 * TS < r.end.x - 0.3 * TS:
		var pan := Rect2(x, r.position.y + 5.0, 1.5 * TS, r.size.y - 10.0)
		draw_rect(pan, Color("5f6b74"))
		draw_rect(pan.grow(-2.5), Color(FOODS[i % FOODS.size()]))
		draw_rect(Rect2(pan.position.x + 2.5, pan.position.y + 2.5, pan.size.x - 5.0, 3.0), Color(1, 1, 1, 0.18))
		x += 1.95 * TS
		i += 1
	# glass in front of the food
	draw_rect(Rect2(r.position.x + 2.4 * TS, r.position.y - 2.0, r.size.x - 2.6 * TS, 4.0), Color(0.75, 0.9, 1.0, 0.55))
	# till
	var till := Rect2((TILL.x - 0.5) * TS, r.position.y + 4.0, 1.0 * TS, r.size.y - 8.0)
	draw_rect(till, Color("2b2f35"))
	draw_rect(Rect2(till.position + Vector2(4, 3), Vector2(till.size.x - 8, 8)), Color(0.3, 0.9, 0.6, 0.9))
	# how far the one at the till is
	if not members.is_empty() and not _is_player(members[0]) and members[0].q_state == "served":
		var g = members[0]
		var c := Vector2(TILL.x * TS, r.position.y - 8.0)
		draw_circle(c, 7.0, Color(0.08, 0.09, 0.17, 0.85))
		draw_arc(c, 5.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - g.q_timer / maxf(0.01, g.q_total)), 20, UI.GREEN, 2.5)


func _paint_table(ci: CanvasItem, k: int) -> void:
	var w := TABLE_SIZE.x * TS
	var h := TABLE_SIZE.y * TS
	var r := Rect2(-w / 2.0, -h, w, h)
	ci.draw_rect(Rect2(r.position + Vector2(2.5, 3.5), r.size), Color(0, 0, 0, 0.3))
	ci.draw_rect(r, Color("c9c0ae"))
	ci.draw_rect(r.grow(-2.0), Color("efe9dc"))
	ci.draw_rect(Rect2(r.position.x + 2.0, r.end.y - 5.0, w - 4.0, 3.0), Color("ddd5c4"))
	var x0: float = (tables[k] as Rect2).get_center().x * TS
	for st in seats:
		if st["table"] == k and st["tray"]:
			var dx: float = (st["pos"] as Vector2).x - x0
			ART._tray(ci, Vector2(dx, -h + 10.0 if st["north"] else -9.0), 17.0)


func _paint_chair_back(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(-7.0, -2.0, 2.5, 4.0), Color("2b3644"))
	ci.draw_rect(Rect2(4.5, -2.0, 2.5, 4.0), Color("2b3644"))
	ci.draw_rect(Rect2(-8.0, -19.0, 16.0, 17.0), Color("3d4e63"))
	ci.draw_rect(Rect2(-6.0, -17.0, 12.0, 12.0), Color("4f6380"))
