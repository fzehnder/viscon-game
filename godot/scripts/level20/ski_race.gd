extends Control
## The ski race: both players ride the same giant slalom at the same time, P1 on the left half,
## P2 on the right. Two runs one after the other, the times are added up. Each player sees the
## other one on the course too, plus the gap at every gate.
## Steering with the body in front of the camera (step left and right, duck for the tuck),
## or with the keys (left / right, down = tuck) when there is no camera or somebody presses a key.
## Emits `finished(results)` when the players leave the final screen.

signal finished(results: Array)

const KEYS = preload("res://scripts/controls.gd")
const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")
const BOARD = preload("res://scripts/level20/ski_board.gd")

# ---- course (world pixels, y goes downhill)
const SEEDS := [5051, 7303]       # one fixed course per run, the same every time (fair leaderboard)
const GATES := 26                  # gates per run
const GATE_GAP := 350.0            # downhill distance between two gates
const GATE_W := 96.0               # space between the two poles of a gate
const GATE_MIN_X := 40.0           # how far a gate sits beside the middle of the slope
const GATE_MAX_X := 125.0
const SLOPE_W := 250.0             # half width of the groomed slope, outside is deep snow
const POLE_HIT := 9.0              # closer than this to a pole = hit it
# ---- skier
const GRAVITY := 300.0             # acceleration downhill, px/s²
const BRAKE := 500.0               # slowing down to a lower top speed
const V_MAX := 500.0               # top speed standing up
const V_TUCK := 620.0              # top speed in the tuck
const V_DEEP := 210.0              # top speed in deep snow
const V_HIT := 230.0               # speed right after hitting a pole
const V_MIN := 140.0               # never slower (so everybody reaches the finish)
const LAT_MAX := 420.0             # sideways speed standing up
const LAT_TUCK := 240.0            # sideways speed in the tuck (hard to turn)
const LAT_ACC := 1500.0            # how quickly the sideways speed follows
const TURN_LOSS := 230.0           # speed lost per second at full sideways speed
const CAM_GAIN := 5.0              # camera steering: sideways speed per pixel off the target
const MISS_PENALTY := 2.0          # seconds for a missed gate
const WOBBLE := 0.6                # seconds of slow wobbling after a pole hit
# ---- camera control
const CAM_RANGE := 0.16            # moving this share of the picture width = from the middle to the edge of the slope
const TUCK_DROP := 0.08            # head this much lower than at the start (share of picture height) = tuck
# ---- screen
const CAM_AHEAD := 0.28            # the skier sits this far down the half screen
const PX_TO_KMH := 0.15
const GRADE_SLOPE := 8.0           # grade points lost per 100 % slower than par
const BETWEEN_TIME := 7.0          # seconds the result of run 1 stays before run 2 starts by itself

const SNOW := Color("f4f7fb")
const SNOW_LINE := Color("e6ecf4")
const SNOW_DEEP := Color("dfe7f2")
const SNOW_DOT := Color("cdd8e8")
const SHADOW := Color(0.45, 0.55, 0.7, 0.28)
const RED := Color("e0393e")
const BLUE := Color("2f6fd6")
const PINE := Color("2b5530")
const PINE_LIT := Color("3e7343")
const TRUNK := Color("5a3d2a")
const INK := Color("23264a")

var main                         # main.gd, for names and looks
var font: Font
var run := 0                     # 0 or 1
var phase := "count"             # count, race, between, final
var phase_t := 0.0
var course: Dictionary
var pars: Array = [0.0, 0.0]     # par time per run (an ideal line, see _par)
var sk: Array = []               # the two skiers
var results: Array = []          # per player: {"name", "runs": [t1, t2], "misses", "total", "grade"}
var base_y: Array = [-1.0, -1.0] # head height at the start (for the tuck), per player
var base_n: Array = [0, 0]
var views: Array = []
var overlay: Control
var panel_root: Control
var fresh: Array = []            # saved entries of this race (highlighted on the board)


## A half of the screen that clips what is drawn in it.
class HalfView:
	extends Control
	var race
	var pid := 0

	func _draw() -> void:
		race._draw_half(self, pid)


class Overlay:
	extends Control
	var race

	func _draw() -> void:
		race._draw_overlay(self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	for pid in 2:
		var v := HalfView.new()
		v.race = self
		v.pid = pid
		v.clip_contents = true
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		views.append(v)
	overlay = Overlay.new()
	overlay.race = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root = Control.new()
	panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_root)
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()
	for r in 2:
		pars[r] = _par(_make_course(r))
	Track.use(self, ["pose", "face"])
	_new_race()


func _layout() -> void:
	for pid in views.size():
		views[pid].position = Vector2(size.x / 2.0 * pid, 0)
		views[pid].size = Vector2(size.x / 2.0, size.y)


func _new_race() -> void:
	results = []
	for pid in 2:
		results.append({"name": Game.name_of(pid), "runs": [0.0, 0.0], "misses": 0, "total": 0.0, "grade": 0.0})
	fresh = []
	_start_run(0)


func _start_run(r: int) -> void:
	run = r
	course = _make_course(r)
	sk = [_new_skier(-40.0), _new_skier(40.0)]
	phase = "count"
	phase_t = 0.0
	base_y = [-1.0, -1.0]
	base_n = [0, 0]
	for c in panel_root.get_children():
		c.queue_free()


func _new_skier(x: float) -> Dictionary:
	return {"x": x, "y": 0.0, "vx": 0.0, "speed": 0.0, "t": 0.0, "penalty": 0.0, "gate": 0, "misses": 0,
		"hits": 0, "finished": false, "time": 0.0, "wobble": 0.0, "tuck": false, "cam": false,
		"splits": [], "msg": "", "msg_t": 0.0, "msg_col": Color.WHITE, "trail": [], "cam_x": x, "flash": 0.0}


# ------------------------------------------------------------------ course
func _make_course(r: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEEDS[r]
	var c := {"phase": rng.randf() * TAU, "gates": [], "trees": [], "bumps": []}
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	for i in GATES:
		var gy := 420.0 + i * GATE_GAP + rng.randf_range(-40.0, 40.0)
		var gx := _center(c, gy) + side * rng.randf_range(GATE_MIN_X, GATE_MAX_X)
		(c["gates"] as Array).append({"y": gy, "x": gx, "red": i % 2 == 0, "i": i})
		if rng.randf() > 0.15:   # now and then two gates on the same side
			side = -side
	c["length"] = float(c["gates"].back()["y"]) + 460.0
	var y := -400.0
	while y < float(c["length"]) + 900.0:
		for s: float in [-1.0, 1.0]:
			if rng.randf() < 0.85:
				var tx := _center(c, y) + s * (SLOPE_W + 26.0 + rng.randf() * 170.0)
				(c["trees"] as Array).append({"x": tx, "y": y + rng.randf_range(-15.0, 15.0), "k": rng.randf_range(0.75, 1.35)})
		y += 44.0
	for i in 160:
		var by := rng.randf_range(0.0, float(c["length"]))
		(c["bumps"] as Array).append({"x": _center(c, by) + rng.randf_range(-SLOPE_W, SLOPE_W), "y": by})
	return c


## Middle of the slope at height y: the slope bends gently left and right.
func _center(c: Dictionary, y: float) -> float:
	var p: float = c["phase"]
	return sin(y * 0.00055 + p) * 90.0 + sin(y * 0.0013 + p * 2.0) * 30.0


## Time of a clean, safe line through every gate centre without the tuck.
func _par(c: Dictionary) -> float:
	var s := _new_skier(0.0)
	var dt := 1.0 / 60.0
	var guard := 0
	while not s["finished"] and guard < 60 * 300:
		guard += 1
		var gates: Array = c["gates"]
		var tx: float = gates[s["gate"]]["x"] if s["gate"] < gates.size() else _center(c, s["y"])
		var u := (tx - _center(c, s["y"])) / (SLOPE_W - 10.0)
		_step(s, c, dt, {"cam": true, "u": u, "dir": 0.0, "tuck": false}, -1)
	return s["time"]


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	phase_t += delta
	match phase:
		"count":
			for pid in 2:
				_calibrate(pid)
			if phase_t >= 3.0:
				phase = "race"
				phase_t = 0.0
				UI.sfx("whoosh")
			elif int(phase_t - delta) != int(phase_t):
				UI.sfx("tick")
		"race":
			for pid in 2:
				_step(sk[pid], course, delta, _steer(pid), pid)
			if sk[0]["finished"] and sk[1]["finished"]:
				_end_run()
		"between":
			for pid in 2:
				_step(sk[pid], course, delta, _steer(pid), pid)
			if phase_t > 1.0 and (phase_t >= BETWEEN_TIME or _pressed_go()):
				_start_run(1)
		"final":
			for pid in 2:
				_step(sk[pid], course, delta, _steer(pid), pid)
			if phase_t > 0.8 and _pressed_go():
				finished.emit(results)
			elif phase_t > 0.8 and Input.is_action_just_pressed("restart"):
				UI.sfx("pop")
				_new_race()
	for pid in 2:
		var s: Dictionary = sk[pid]
		s["msg_t"] = maxf(0.0, s["msg_t"] - delta)
		s["flash"] = maxf(0.0, s["flash"] - delta)
	for v in views:
		v.queue_redraw()
	overlay.queue_redraw()


func _pressed_go() -> bool:
	for pid in 2:
		if Input.is_action_just_pressed(KEYS.action(pid, "interact")):
			return true
	return Input.is_action_just_pressed("start")


## What a player wants: from the keys if any is held, else from the camera.
func _steer(pid: int) -> Dictionary:
	var dir := 0.0
	if Input.is_action_pressed(KEYS.action(pid, "left")):
		dir -= 1.0
	if Input.is_action_pressed(KEYS.action(pid, "right")):
		dir += 1.0
	var key_tuck := Input.is_action_pressed(KEYS.action(pid, "down"))
	var cam := _cam(pid)
	if dir != 0.0 or key_tuck or cam.is_empty():
		return {"cam": false, "u": 0.0, "dir": dir, "tuck": key_tuck}
	return {"cam": true, "u": cam["u"], "dir": 0.0, "tuck": cam["tuck"]}


## Body position in the player's half of the camera picture: {"u": -1..1, "tuck": bool, "y"}, or {}.
func _cam(pid: int) -> Dictionary:
	if not Track.alive:
		return {}
	var p: Dictionary = Track.pose(pid)
	var f: Dictionary = Track.face(pid)
	if p.is_empty() and f.is_empty():
		return {}
	var x: float = p["x"] if not p.is_empty() else f["x"]
	var y: float = f["y"] if not f.is_empty() else p["y"]
	var mid := 0.25 if pid == 0 else 0.75
	var tuck: bool = base_y[pid] >= 0.0 and y - float(base_y[pid]) > TUCK_DROP
	return {"u": clampf((x - mid) / CAM_RANGE, -1.0, 1.0), "tuck": tuck, "y": y}


## During the countdown: remember how high the head is when standing.
func _calibrate(pid: int) -> void:
	var c := _cam(pid)
	if c.is_empty():
		return
	base_n[pid] += 1
	var y: float = c["y"]
	base_y[pid] = y if base_y[pid] < 0.0 else lerpf(base_y[pid], y, 1.0 / base_n[pid])


## One frame of a skier. pid -1: the par line, no sounds and messages.
func _step(s: Dictionary, c: Dictionary, delta: float, steer: Dictionary, pid: int) -> void:
	var live := pid >= 0
	var cx := _center(c, s["y"])
	if s["finished"]:
		s["speed"] = maxf(0.0, s["speed"] - 700.0 * delta)
		s["vx"] = move_toward(s["vx"], 0.0, 900.0 * delta)
		s["y"] += s["speed"] * delta
		s["x"] += s["vx"] * delta
		return
	s["t"] += delta
	s["cam"] = steer["cam"]
	var deep := absf(s["x"] - cx) > SLOPE_W
	var tuck: bool = steer["tuck"] and not deep
	s["tuck"] = tuck
	var lat := LAT_TUCK if tuck else LAT_MAX
	var want: float
	if steer["cam"]:
		want = clampf((cx + float(steer["u"]) * (SLOPE_W - 10.0) - s["x"]) * CAM_GAIN, -lat, lat)
	else:
		want = float(steer["dir"]) * lat
	s["vx"] = move_toward(s["vx"], want, LAT_ACC * delta)
	var vmax := V_DEEP if deep else (V_TUCK if tuck else V_MAX)
	s["speed"] = move_toward(s["speed"], vmax, (GRAVITY if s["speed"] < vmax else BRAKE) * delta)
	s["speed"] -= absf(s["vx"]) / LAT_MAX * TURN_LOSS * delta
	if s["wobble"] > 0.0:
		s["wobble"] -= delta
		s["speed"] = minf(s["speed"], V_HIT)
	s["speed"] = maxf(s["speed"], V_MIN)
	s["y"] += s["speed"] * delta
	s["x"] = clampf(s["x"] + s["vx"] * delta, cx - SLOPE_W - 150.0, cx + SLOPE_W + 150.0)
	var gates: Array = c["gates"]
	while s["gate"] < gates.size() and float(gates[s["gate"]]["y"]) <= s["y"]:
		_pass_gate(s, gates[s["gate"]], pid)
		s["gate"] += 1
	if live:
		var tr: Array = s["trail"]
		if tr.is_empty() or s["y"] - (tr.back() as Vector2).y > 10.0:
			tr.append(Vector2(s["x"], s["y"]))
			if tr.size() > 90:
				tr.remove_at(0)
	if s["y"] >= float(c["length"]):
		s["finished"] = true
		s["time"] = s["t"] + s["penalty"]
		if live:
			UI.sfx("success")


func _pass_gate(s: Dictionary, g: Dictionary, pid: int) -> void:
	var live := pid >= 0
	var gx: float = g["x"]
	var off := absf(s["x"] - gx)
	var edge := GATE_W / 2.0
	if absf(off - edge) < POLE_HIT:
		s["hits"] += 1
		s["wobble"] = WOBBLE
		if live:
			_msg(s, "Stange!", UI.ORANGE)
			UI.sfx("buzz", -8.0)
	if off > edge:
		s["misses"] += 1
		s["penalty"] += MISS_PENALTY
		s["flash"] = 0.5
		if live:
			_msg(s, "Tor verpasst  +%d s" % int(MISS_PENALTY), UI.RED)
			UI.sfx("fail", -8.0)
	elif live:
		UI.sfx("tick", -10.0)
	(s["splits"] as Array).append(s["t"] + s["penalty"])
	if live:
		var other: Dictionary = sk[1 - pid]
		var gi: int = (s["splits"] as Array).size() - 1
		if (other["splits"] as Array).size() > gi:
			var gap: float = float(s["splits"][gi]) - float(other["splits"][gi])
			if s["msg_t"] <= 0.0:
				_msg(s, "%+.2f" % gap, UI.GREEN if gap <= 0.0 else UI.RED)


func _msg(s: Dictionary, text: String, col: Color) -> void:
	s["msg"] = text
	s["msg_t"] = 1.6
	s["msg_col"] = col


func _end_run() -> void:
	for pid in 2:
		var s: Dictionary = sk[pid]
		results[pid]["runs"][run] = s["time"]
		results[pid]["misses"] += s["misses"]
	phase_t = 0.0
	if run == 0:
		phase = "between"
		UI.sfx("pop")
		_show_between()
		return
	phase = "final"
	var par_total: float = pars[0] + pars[1]
	for r in results:
		r["total"] = float(r["runs"][0]) + float(r["runs"][1])
		r["grade"] = grade_for(r["total"], par_total)
	var winner := 0 if results[0]["total"] < results[1]["total"] else 1
	if is_equal_approx(results[0]["total"], results[1]["total"]):
		winner = -1
	fresh = BOARD.save_race(results, winner, Game.persist)
	UI.sfx("fanfare")
	_show_final(winner)


## Swiss grade from the total time: 6 at par or better, a quarter less for every 3 % slower
## (25 % slower = 4, just passed).
static func grade_for(total: float, par_total: float) -> float:
	var g := 6.0 - (total / par_total - 1.0) * GRADE_SLOPE
	return clampf(snappedf(g, 0.25), 1.0, 6.0)


# ------------------------------------------------------------------ panels
func _show_between() -> void:
	var p := UI.panel(UI.NAVY, UI.YELLOW)
	panel_root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_c(UI.label("1. Lauf", 34, UI.YELLOW, 6)))
	var lead := 0 if sk[0]["time"] <= sk[1]["time"] else 1
	for pid in [lead, 1 - lead]:
		var s: Dictionary = sk[pid]
		var line := "%s   %s" % [Game.name_of(pid), BOARD.fmt(s["time"])]
		if s["misses"] > 0:
			line += "   (%d Tor%s verpasst)" % [s["misses"], "" if s["misses"] == 1 else "e"]
		v.add_child(_c(UI.label(line, 24, Color(KEYS.TAG_COLORS[pid]), 4)))
	var gap: float = absf(sk[0]["time"] - sk[1]["time"])
	v.add_child(_c(UI.label("%s führt mit %.2f s Vorsprung." % [Game.name_of(lead), gap], 18, UI.WHITE)))
	v.add_child(_c(UI.label("2. Lauf auf einer neuen Piste. Enter / E: los", 15, UI.MUTED)))
	_center_panel(p)
	UI.pop_in(p)


func _show_final(winner: int) -> void:
	var p := UI.panel(UI.NAVY, UI.YELLOW)
	panel_root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	if winner >= 0:
		var gap: float = absf(results[0]["total"] - results[1]["total"])
		v.add_child(_c(UI.label("%s gewinnt!" % results[winner]["name"], 38, Color(KEYS.TAG_COLORS[winner]), 7)))
		v.add_child(_c(UI.label("Vorsprung %.2f s nach zwei Läufen" % gap, 17, UI.WHITE)))
	else:
		v.add_child(_c(UI.label("Unentschieden!", 38, UI.YELLOW, 7)))
	var rec := BOARD.duel_record(results[0]["name"], results[1]["name"])
	v.add_child(_c(UI.label("Duell-Bilanz  %s %d : %d %s" % [results[0]["name"], rec[0], rec[1], results[1]["name"]], 16, UI.MUTED)))
	for pid in 2:
		var r: Dictionary = results[pid]
		var best := BOARD.best_of(r["name"])
		var pb := "  · neuer Rekord!" if is_equal_approx(best, snappedf(r["total"], 0.01)) else ""
		v.add_child(_c(UI.label("%s: %s + %s = %s · Note %s%s" % [r["name"], BOARD.fmt(r["runs"][0]), BOARD.fmt(r["runs"][1]),
			BOARD.fmt(r["total"]), String.num(r["grade"], 2), pb], 16, Color(KEYS.TAG_COLORS[pid]))))
	v.add_child(_board_table())
	v.add_child(_c(UI.label("Enter / E: weiter · R: Revanche", 15, UI.MUTED)))
	_center_panel(p)
	UI.pop_in(p)
	UI.confetti(panel_root, Vector2(size.x / 2.0, size.y * 0.25), 120)


## Top 10 of all saved races, NPCs and Opps. Rows of this race are highlighted; if a player is
## further down, their row is added at the end with the real rank.
func _board_table() -> Control:
	var all: Array = BOARD.load_times().duplicate()
	if not Game.persist:
		all.append_array(fresh)
	all.append_array(BOARD.npc_times(pars, Game.opps))
	all.sort_custom(func(a, b): return float(a["total"]) < float(b["total"]))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.add_child(_c(UI.label("Bestenliste", 22, UI.YELLOW, 4)))
	var shown := 0
	var extra: Array = []
	for i in all.size():
		var e: Dictionary = all[i]
		var mine := _is_fresh(e)
		if shown < 10:
			box.add_child(_board_row(i + 1, e, mine))
			shown += 1
		elif mine:
			extra.append([i + 1, e])
	for x in extra:
		box.add_child(_board_row(x[0], x[1], true))
	return box


func _is_fresh(e: Dictionary) -> bool:
	for f in fresh:
		if f["name"] == e["name"] and is_equal_approx(float(f["total"]), float(e["total"])) and f.get("date", "") == e.get("date", "-"):
			return true
	return false


func _board_row(rank: int, e: Dictionary, mine: bool) -> Control:
	var kind: String = e.get("kind", "")
	var col := UI.WHITE
	var tag := ""
	if kind == "opp":
		col = UI.RED
		tag = "  OPP"
	elif kind == "npc":
		col = UI.MUTED
	if mine:
		col = UI.YELLOW
		tag = "  NEU"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var cells := [["%d." % rank, 40], [String(e["name"]) + tag, 330], [BOARD.fmt(float(e["r1"])), 80],
		[BOARD.fmt(float(e["r2"])), 80], [BOARD.fmt(float(e["total"])), 90]]
	for c in cells:
		var l := UI.label(String(c[0]), 16, col, 3 if mine else 0)
		l.custom_minimum_size.x = c[1]
		if c[1] != 330:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	return h


func _c(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _center_panel(p: Control) -> void:
	p.reset_size()
	p.position = (size - p.get_combined_minimum_size()) / 2.0
	p.resized.connect(func(): p.position = (size - p.size) / 2.0)


# ------------------------------------------------------------------ drawing
func _draw_half(ci: Control, pid: int) -> void:
	var s: Dictionary = sk[pid]
	var w := ci.size.x
	var h := ci.size.y
	var want_x := lerpf(_center(course, s["y"]), s["x"], 0.45)
	s["cam_x"] = lerpf(s["cam_x"], want_x, 0.12)
	var cam := Vector2(s["cam_x"] - w / 2.0, s["y"] - h * CAM_AHEAD)
	# snow: groomed slope with corduroy stripes, deep snow beside it
	var row := 6.0
	var y0 := floorf(cam.y / row) * row
	var y := y0
	while y < cam.y + h + row:
		var cx := _center(course, y) - cam.x
		var sy := y - cam.y
		ci.draw_rect(Rect2(0, sy, w, row), SNOW_DEEP)
		var stripe := int(y / row) % 3 == 0
		ci.draw_rect(Rect2(cx - SLOPE_W, sy, SLOPE_W * 2.0, row), SNOW_LINE if stripe else SNOW)
		if int(y / row) % 20 == 0:
			for k: float in [-1.0, 1.0]:
				ci.draw_rect(Rect2(cx + k * (SLOPE_W + 3.0) - 2.0, sy - 12.0, 4, 16), RED if k < 0.0 else BLUE)
		y += row
	for b: Dictionary in course["bumps"]:
		var p := Vector2(b["x"], b["y"]) - cam
		if p.y > -20.0 and p.y < h + 20.0:
			ci.draw_rect(Rect2(p.x - 9.0, p.y, 18, 3), SNOW_DOT)
			ci.draw_rect(Rect2(p.x - 6.0, p.y - 3.0, 12, 3), Color.WHITE)
	_draw_lines(ci, cam, w, h)
	for o in 2:
		_draw_trail(ci, sk[o], cam)
	# everything that stands up, sorted by its foot
	var items: Array = []
	for g: Dictionary in course["gates"]:
		if g["y"] - cam.y > -60.0 and g["y"] - cam.y < h + 60.0:
			items.append([g["y"], "gate", g])
	for t: Dictionary in course["trees"]:
		if t["y"] - cam.y > -10.0 and t["y"] - cam.y < h + 110.0:
			items.append([t["y"], "tree", t])
	for o in 2:
		items.append([sk[o]["y"], "skier", o])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		match it[1]:
			"gate": _draw_gate(ci, it[2], cam, pid)
			"tree": _draw_tree(ci, it[2], cam)
			"skier": _draw_skier(ci, it[2], cam, it[2] == pid)
	if s["flash"] > 0.0:
		ci.draw_rect(Rect2(0, 0, w, h), Color(1, 0.2, 0.25, s["flash"] * 0.35))
	_draw_hud(ci, pid)


## Start gate and finish line across the slope.
func _draw_lines(ci: Control, cam: Vector2, w: float, h: float) -> void:
	for which in 2:
		var ly: float = 0.0 if which == 0 else float(course["length"])
		var sy := ly - cam.y
		if sy < -60.0 or sy > h + 60.0:
			continue
		var cx := _center(course, ly) - cam.x
		var x0 := cx - SLOPE_W
		if which == 1:
			for i in int(SLOPE_W * 2.0 / 10.0):
				for j in 2:
					ci.draw_rect(Rect2(x0 + i * 10.0, sy + j * 10.0, 10, 10), INK if (i + j) % 2 == 0 else Color.WHITE)
		else:
			ci.draw_rect(Rect2(x0, sy, SLOPE_W * 2.0, 4), RED)
		# banner on two posts
		ci.draw_rect(Rect2(x0 - 6.0, sy - 70.0, 8, 72), INK)
		ci.draw_rect(Rect2(x0 + SLOPE_W * 2.0 - 2.0, sy - 70.0, 8, 72), INK)
		ci.draw_rect(Rect2(x0, sy - 70.0, SLOPE_W * 2.0, 26), RED if which == 1 else BLUE)
		var txt := "ZIEL" if which == 1 else "START"
		ci.draw_string(font, Vector2(x0, sy - 50.0), txt, HORIZONTAL_ALIGNMENT_CENTER, SLOPE_W * 2.0, 20, Color.WHITE)


func _draw_trail(ci: Control, s: Dictionary, cam: Vector2) -> void:
	var tr: Array = s["trail"]
	for i in range(1, tr.size()):
		var a: Vector2 = tr[i - 1] - cam
		var b: Vector2 = tr[i] - cam
		for k: float in [-4.0, 4.0]:
			ci.draw_line(a + Vector2(k, 0), b + Vector2(k, 0), Color(0.62, 0.7, 0.82, 0.55), 2.0)


func _draw_gate(ci: Control, g: Dictionary, cam: Vector2, pid: int) -> void:
	var c: Color = RED if g["red"] else BLUE
	var gi: int = g["i"]
	var passed: bool = sk[pid]["gate"] > gi
	for k: float in [-1.0, 1.0]:
		var p := Vector2(g["x"] + k * GATE_W / 2.0, g["y"]) - cam
		ci.draw_rect(Rect2(p.x - 6.0, p.y - 2.0, 12, 4), SHADOW)
		ci.draw_rect(Rect2(p.x - 2.0, p.y - 34.0, 4, 34), c.darkened(0.2))
		ci.draw_rect(Rect2(p.x - 2.0, p.y - 34.0, 2, 34), c.lightened(0.25))
		# the flag hangs on the outside of the gate
		var fx := p.x + (2.0 if k > 0.0 else -18.0)
		ci.draw_rect(Rect2(fx, p.y - 32.0, 16, 13), c if not passed else c.lerp(Color.WHITE, 0.4))
		ci.draw_rect(Rect2(fx, p.y - 32.0, 16, 2), c.lightened(0.3))
	if not passed and gi == sk[pid]["gate"]:
		var m := Vector2(g["x"], g["y"]) - cam
		ci.draw_rect(Rect2(m.x - 3.0, m.y - 2.0, 6, 4), Color(c, 0.5))


func _draw_tree(ci: Control, t: Dictionary, cam: Vector2) -> void:
	var p := Vector2(t["x"], t["y"]) - cam
	var k: float = t["k"]
	ci.draw_rect(Rect2(p.x - 14.0 * k, p.y - 3.0, 28.0 * k, 6), SHADOW)
	ci.draw_rect(Rect2(p.x - 3.0 * k, p.y - 14.0 * k, 6.0 * k, 14.0 * k), TRUNK)
	for i in 4:
		var wy := p.y - (14.0 + i * 15.0) * k
		var hw := (26.0 - i * 5.5) * k
		ci.draw_colored_polygon(PackedVector2Array([Vector2(p.x - hw, wy), Vector2(p.x + hw, wy), Vector2(p.x, wy - 24.0 * k)]), PINE)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(p.x - hw * 0.5, wy - 4.0 * k), Vector2(p.x, wy - 4.0 * k), Vector2(p.x - 2.0 * k, wy - 20.0 * k)]), PINE_LIT)
		# snow on the branches
		ci.draw_rect(Rect2(p.x - hw * 0.6, wy - 3.0 * k, hw * 0.5, 2.0 * k), Color.WHITE)


func _draw_skier(ci: Control, pid: int, cam: Vector2, mine: bool) -> void:
	var s: Dictionary = sk[pid]
	var p := Vector2(s["x"], s["y"]) - cam
	var col := Color(KEYS.TAG_COLORS[pid])
	var sc := 1.55 if mine else 1.3
	var dirv := Vector2(s["vx"], maxf(s["speed"], 1.0)).normalized()
	var wob := sin(s["t"] * 40.0) * 3.0 if s["wobble"] > 0.0 else 0.0
	# skis (pointing where the skier goes) and the shadow
	ci.draw_rect(Rect2(p.x - 13.0, p.y - 2.0, 26, 5), SHADOW)
	for k: float in [-5.0, 5.0]:
		var side := Vector2(-dirv.y, dirv.x) * k
		ci.draw_line(p + side - dirv * 20.0, p + side + dirv * 22.0, col.darkened(0.3), 4.0)
		ci.draw_line(p + side - dirv * 20.0, p + side + dirv * 22.0, col, 2.0)
	var crouch := 4.0 if s["tuck"] else 0.0
	ART.draw_character(ci, main.players[pid].look, ART.FRONT, 0.0, false, p + Vector2(wob, crouch), sc)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# poles
	var top := p + Vector2(0, -30.0 * sc + crouch)
	for k: float in [-1.0, 1.0]:
		var hand := top + Vector2(k * 12.0, 10.0)
		var tip := hand + Vector2(k * 6.0, 0) + (Vector2(0, -16.0) if s["tuck"] else Vector2(0, 26.0))
		ci.draw_line(hand, tip, INK, 2.0)
	# name tag over the head of the other player
	if not mine:
		var tag := Game.name_of(pid)
		var tp := p + Vector2(-60, -46.0 * sc - 10.0)
		ci.draw_string_outline(font, tp, tag, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 4, INK)
		ci.draw_string(font, tp, tag, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, col)


func _text(ci: CanvasItem, pos: Vector2, text: String, fs: int, col: Color, width: float = -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string_outline(font, pos, text, align, width, fs, 6, INK)
	ci.draw_string(font, pos, text, align, width, fs, col)


func _draw_hud(ci: Control, pid: int) -> void:
	var s: Dictionary = sk[pid]
	var w := ci.size.x
	var col := Color(KEYS.TAG_COLORS[pid])
	ci.draw_rect(Rect2(14, 14, 250, 92), Color(UI.NAVY, 0.82))
	ci.draw_rect(Rect2(14, 14, 6, 92), col)
	_text(ci, Vector2(30, 40), Game.name_of(pid), 20, col)
	var shown: float = s["time"] if s["finished"] else s["t"] + s["penalty"]
	if phase == "count":
		shown = 0.0
	_text(ci, Vector2(30, 76), BOARD.fmt(shown), 30, UI.WHITE)
	var gates: Array = course["gates"]
	_text(ci, Vector2(30, 98), "Tor %d/%d · %d km/h" % [mini(s["gate"], gates.size()), gates.size(), int(s["speed"] * PX_TO_KMH)], 13, UI.MUTED)
	# run and control mode, top right of the half
	_text(ci, Vector2(w - 230, 36), "%d. Lauf" % (run + 1), 18, UI.YELLOW, 216, HORIZONTAL_ALIGNMENT_RIGHT)
	var how := "Kamera" if s["cam"] else "Tasten"
	if phase == "count":
		how = "Kamera bereit" if not _cam(pid).is_empty() else ("Tasten" if not Track.alive else "Kamera: niemand im Bild")
	_text(ci, Vector2(w - 230, 58), how, 14, UI.MUTED, 216, HORIZONTAL_ALIGNMENT_RIGHT)
	if s["tuck"]:
		_text(ci, Vector2(w - 230, 80), "HOCKE", 16, UI.GREEN, 216, HORIZONTAL_ALIGNMENT_RIGHT)
	if s["msg_t"] > 0.0:
		var a := minf(1.0, s["msg_t"] * 3.0)
		_text(ci, Vector2(0, ci.size.y * 0.62), s["msg"], 30, Color(s["msg_col"], a), w, HORIZONTAL_ALIGNMENT_CENTER)
	if s["finished"] and phase == "race":
		_text(ci, Vector2(0, ci.size.y * 0.5), "Im Ziel! %s" % BOARD.fmt(s["time"]), 30, UI.YELLOW, w, HORIZONTAL_ALIGNMENT_CENTER)
		_text(ci, Vector2(0, ci.size.y * 0.5 + 30.0), "Warte auf %s ..." % Game.name_of(1 - pid), 16, UI.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)


## Divider with both progress dots, countdown, camera picture during the countdown.
func _draw_overlay(ci: Control) -> void:
	var w := ci.size.x
	var h := ci.size.y
	ci.draw_rect(Rect2(w / 2.0 - 3.0, 0, 6, h), INK)
	var top := 120.0
	var bot := h - 120.0
	ci.draw_rect(Rect2(w / 2.0 - 1.0, top, 2, bot - top), Color(1, 1, 1, 0.5))
	var length: float = course["length"]
	for pid in 2:
		var k := clampf(sk[pid]["y"] / length, 0.0, 1.0)
		var py := lerpf(top, bot, k)
		ci.draw_circle(Vector2(w / 2.0, py), 8.0, INK)
		ci.draw_circle(Vector2(w / 2.0, py), 6.0, Color(KEYS.TAG_COLORS[pid]))
	if phase == "count":
		var n := 3 - int(phase_t)
		var txt := str(n) if n > 0 else "LOS!"
		var fs := 120 + int(fmod(phase_t, 1.0) * 30.0)
		_text(ci, Vector2(0, h * 0.42), txt, fs, UI.YELLOW, w, HORIZONTAL_ALIGNMENT_CENTER)
		var hint := "Steht gerade hin. Zum Lenken nach links und rechts gehen, zum Beschleunigen in die Hocke."
		if not Track.alive:
			hint = "Lenken: A / D und Pfeile links / rechts · Hocke (schneller, lenkt schlechter): S und Pfeil runter"
		_text(ci, Vector2(0, h * 0.42 + 50.0), hint, 18, UI.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
		if Track.alive and Track.preview != null:
			var pw := 240.0
			var ph := pw / Track.aspect
			var r := Rect2(w / 2.0 - pw / 2.0, h - ph - 20.0, pw, ph)
			ci.draw_rect(r.grow(4.0), INK)
			ci.draw_texture_rect(Track.preview, r, false)
			ci.draw_line(Vector2(w / 2.0, r.position.y), Vector2(w / 2.0, r.end.y), UI.YELLOW, 2.0)
