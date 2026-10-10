extends Control
## The Basisprüfung in the ONA exam hall (computer exam), full screen and first person: the Streber
## is on P1's left and on P2's right (P1 turns the head to the left, P2 to the right), each half of
## the screen is what that player sees. Turning the
## head towards the Streber (camera, Track.face yaw) pans the view over the partition onto his
## screen: reading fills the memory, turning back to the own screen types it in.
## Two watchers: the Streber writes, gets restless (a short tell), then glances left or right;
## the supervisor at the front stands up now and then and looks over the hall. Whoever is seen
## with the head turned is caught, and the exam is over for both (red light, green light).
## Both get more alert with time and after every close call. The camera is required; the user
## argument --exam-keys (tests only) lets P1 hold D and P2 the left arrow instead.
## Emits `finished(won, info)`; info: {"near": close calls, "time": seconds, "who": pid, -2 = time up}.

signal finished(won: bool, info: Dictionary)

const KEYS = preload("res://scripts/controls.gd")
const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")

# ---- exam
const ANSWERS := 8              # answers each player has to copy
const READ_RATE := 0.3          # memory per second while fully turned to the Streber's screen
const WRITE_RATE := 0.6         # answer per second while looking at the own screen (from memory)
const EXAM_TIME := 240.0        # seconds; time up = failed
# ---- head
const CALIB_DEG := 12.0         # head turn (degrees) needed during the calibration ...
const CALIB_NOSE := 0.08        # ... while the nose is this far off the face centre towards the Streber
const LOOK_DEG := 26.0          # head turned this far = fully looking over
const FORWARD_DEG := 8.0        # less than this = looking at the own screen
const KEY_TURN := 3.2           # --exam-keys: how fast the view turns (per second)
const READ_FROM := 0.8          # view this far over: reading
const WRITE_BELOW := 0.2        # view less than this: typing
const SEEN_FROM := 0.35         # a watcher catches you from this far over
const LOST_WARN := 1.0          # seconds without a face before the warning
# ---- Streber
const WRITE_TIME := Vector2(3.5, 6.0)    # seconds he writes before getting restless (shrinks with alert)
const TELL_TIME := Vector2(0.8, 0.3)     # warning time at alert 0 and 1
const GLANCE_TIME := Vector2(1.5, 2.6)
const ALERT_TIME := 90.0                 # alert grows from 0 to 1 over this many seconds
const NEAR_ALERT := 0.15                 # extra alert per close call
const FAKE_FROM := 0.3                   # from this alert on he sometimes only pretends
const DOUBLE_FROM := 0.45                # ... and sometimes glances to both sides
# ---- supervisor
const SUP_FIRST := 20.0                  # first time she looks up
const SUP_EVERY := Vector2(11.0, 19.0)   # seconds between two looks (shrinks with alert)
const SUP_TELL := Vector2(1.0, 0.5)      # standing up before looking
const SUP_LOOK := Vector2(1.6, 2.8)
const SIDE := [-1.0, 1.0]                # where the Streber is: P1 turns left, P2 turns right
const PAN := 280.0                       # how far the view pans, px (fully turned: his screen is in the middle)

const CEIL := Color("e9ebee")
const DUCT := Color("c9ced6")
const WIN := Color("dbe8f3")
const WIN_BAR := Color("aebccb")
const PILLAR := Color("4f7f3a")
const FLOOR := Color("cfcfcc")
const DESK := Color("e4e2dc")
const PART := Color("f3f2ef")
const PART_EDGE := Color("c8c6c0")
const SCREEN := Color("2e3440")
const SCREEN_ON := Color("f4f7fb")
const INK := Color("1c1d33")

var main
var font: Font
var keys_ok := false           # --exam-keys
var phase := "calib"           # calib, exam, caught, done
var t := 0.0
var phase_t := 0.0
var exam_t := 0.0
var view: Array = [0.0, 0.0]   # 0 = own screen, 1 = fully turned to the Streber
var yaw_sign: Array = [0, 0]   # which yaw direction means "towards the Streber", from the calibration
var calib_t: Array = [0.0, 0.0]
var wrong_t: Array = [0.0, 0.0]     # calibration: turning the wrong way (for the hint)
var lost_t: Array = [0.0, 0.0]
var memory: Array = [0.0, 0.0]
var answers: Array = [0.0, 0.0]
var look_time: Array = [0.0, 0.0]   # how long each one looked recently (he glances there more often)
var near := 0
var alert := 0.0
var bonus_alert := 0.0
# Streber: write -> tell -> glance (side) -> write
var s_state := "write"
var s_t := 0.0
var s_dur := 5.0
var s_side := 0                # 0 = towards P1, 1 = towards P2
var s_fake := false
var s_double := false
# supervisor: sit -> stand (tell) -> look -> sit
var a_state := "sit"
var a_t := 0.0
var a_dur := SUP_FIRST
var caught_pid := -1
var caught_by := ""            # "streber" or "aufsicht"
var flash := 0.0
var shout := ""
var halves: Array = []
var overlay: Control


class Half:
	extends Control
	var ex
	var pid := 0

	func _draw() -> void:
		ex._draw_half(self, pid)


class Over:
	extends Control
	var ex

	func _draw() -> void:
		ex._draw_over(self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	keys_ok = OS.get_cmdline_user_args().has("--exam-keys")
	for pid in 2:
		var h := Half.new()
		h.ex = self
		h.pid = pid
		h.clip_contents = true
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		halves.append(h)
	overlay = Over.new()
	overlay.ex = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()
	Track.use(self, ["face"])


func _layout() -> void:
	for pid in halves.size():
		halves[pid].position = Vector2(size.x / 2.0 * pid, 0)
		halves[pid].size = Vector2(size.x / 2.0, size.y)


# ------------------------------------------------------------------ input
## Head turn of a player in degrees towards the Streber (positive = towards him), or NAN.
func _head(pid: int) -> float:
	if not Track.alive:
		return NAN
	var f: Dictionary = Track.face(pid)
	if f.is_empty():
		return NAN
	var yaw: float = f["yaw"]
	return yaw if yaw_sign[pid] == 0 else yaw * yaw_sign[pid]


## How far the nose is off the middle of the face, towards the Streber (positive), or NAN.
## This is plain geometry in the mirrored picture (turning to your own left moves the nose to the
## left), so unlike the sign of yaw it cannot be the wrong way round. Used to set the direction.
func _nose_turn(pid: int) -> float:
	if not Track.alive:
		return NAN
	var f: Dictionary = Track.face(pid)
	if f.is_empty() or not f.has("box"):
		return NAN
	var box: Array = f["box"]
	if float(box[2]) <= 0.0:
		return NAN
	var off: float = (float(f["x"]) - (float(box[0]) + float(box[2]) / 2.0)) / float(box[2])
	return off * SIDE[pid]


func _key_over(pid: int) -> bool:
	return keys_ok and Input.is_action_pressed(KEYS.action(pid, "left" if pid == 0 else "right"))


func _update_view(pid: int, delta: float) -> void:
	if _key_over(pid) or (keys_ok and yaw_sign[pid] == 2):
		view[pid] = move_toward(view[pid], 1.0 if _key_over(pid) else 0.0, KEY_TURN * delta)
		return
	var h := _head(pid)
	if is_nan(h) or yaw_sign[pid] == 0:
		lost_t[pid] += delta
		view[pid] = move_toward(view[pid], 0.0, 2.0 * delta)   # not in the picture: no reading either
		return
	lost_t[pid] = 0.0
	var want := clampf(inverse_lerp(FORWARD_DEG, LOOK_DEG, h), 0.0, 1.0)
	view[pid] = lerpf(view[pid], want, 1.0 - exp(-14.0 * delta))


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	flash = maxf(0.0, flash - delta * 1.5)
	match phase:
		"calib":
			_process_calib(delta)
		"exam":
			_process_exam(delta)
		"caught":
			if phase_t > 3.2:
				phase = "done"
				finished.emit(false, {"near": near, "time": exam_t, "who": caught_pid})
	for hv in halves:
		hv.queue_redraw()
	overlay.queue_redraw()


## Before the exam: both have to be in the picture and turn their head towards the Streber once;
## that sets the direction (the camera picture may be mirrored). No camera, no exam.
func _process_calib(delta: float) -> void:
	var ready_n := 0
	for pid in 2:
		_update_view(pid, delta)
		if keys_ok and _key_over(pid) and yaw_sign[pid] == 0:
			yaw_sign[pid] = 2
		if yaw_sign[pid] != 0:
			ready_n += 1
			continue
		# the nose says which way is towards the Streber; the yaw that goes with it gives its sign
		var h := _head(pid)
		var n := _nose_turn(pid)
		if not is_nan(h) and not is_nan(n) and absf(h) > CALIB_DEG and n > CALIB_NOSE:
			calib_t[pid] += delta
			wrong_t[pid] = 0.0
			if calib_t[pid] > 0.4:
				yaw_sign[pid] = 1 if h > 0.0 else -1
				UI.sfx("pop")
		else:
			calib_t[pid] = 0.0
			if not is_nan(n) and n < -CALIB_NOSE:
				wrong_t[pid] += delta
			else:
				wrong_t[pid] = maxf(0.0, wrong_t[pid] - delta)
	if ready_n >= 2 and view[0] < WRITE_BELOW and view[1] < WRITE_BELOW:
		phase = "exam"
		phase_t = 0.0
		_streber_write()
		UI.sfx("whoosh")


func _process_exam(delta: float) -> void:
	exam_t += delta
	alert = clampf(exam_t / ALERT_TIME + bonus_alert, 0.0, 1.0)
	for pid in 2:
		_update_view(pid, delta)
		var v: float = view[pid]
		look_time[pid] = maxf(0.0, look_time[pid] - delta * 0.15)
		if v > SEEN_FROM:
			look_time[pid] += delta
		if v >= READ_FROM and s_state != "glance":
			memory[pid] = minf(1.0, memory[pid] + READ_RATE * delta)
		elif v <= WRITE_BELOW and memory[pid] > 0.0 and answers[pid] < ANSWERS:
			var w := minf(memory[pid], WRITE_RATE * delta)
			memory[pid] -= w
			answers[pid] = minf(float(ANSWERS), answers[pid] + w)
			if int(answers[pid] - w) != int(answers[pid]):
				UI.sfx("tick", -6.0)
	_process_streber(delta)
	if phase == "exam":
		_process_supervisor(delta)
	if phase != "exam":
		return
	if answers[0] >= ANSWERS and answers[1] >= ANSWERS:
		phase = "done"
		UI.sfx("fanfare")
		finished.emit(true, {"near": near, "time": exam_t, "who": -1})
	elif exam_t >= EXAM_TIME:
		phase = "done"
		UI.sfx("doom")
		finished.emit(false, {"near": near, "time": exam_t, "who": -2})


func _streber_write() -> void:
	s_state = "write"
	s_t = 0.0
	s_dur = randf_range(WRITE_TIME.x, WRITE_TIME.y) * (1.0 - 0.55 * alert)


func _process_streber(delta: float) -> void:
	s_t += delta
	match s_state:
		"write":
			if s_t >= s_dur:
				s_state = "tell"
				s_t = 0.0
				s_dur = lerpf(TELL_TIME.x, TELL_TIME.y, alert)
				# he looks more often to the one who looked over more
				var w0: float = 1.0 + look_time[0]
				var w1: float = 1.0 + look_time[1]
				s_side = 0 if randf() * (w0 + w1) < w0 else 1
				s_fake = alert >= FAKE_FROM and randf() < 0.3
				s_double = alert >= DOUBLE_FROM and randf() < 0.35
				UI.sfx("click", -4.0)
		"tell":
			if s_t >= s_dur:
				if s_fake:
					_streber_write()
					return
				# looking over when he turns to the other side: he noticed something
				for pid in 2:
					if view[pid] > SEEN_FROM and pid != s_side:
						_close_call("Hm?!")
				s_state = "glance"
				s_t = 0.0
				s_dur = randf_range(GLANCE_TIME.x, GLANCE_TIME.y)
				UI.sfx("whoosh", -6.0)
		"glance":
			if view[s_side] > SEEN_FROM:
				_caught(s_side, "streber")
				return
			if s_t >= s_dur:
				if s_double:
					s_double = false
					s_side = 1 - s_side
					s_t = 0.0
					s_dur = randf_range(GLANCE_TIME.x, GLANCE_TIME.y) * 0.7
					UI.sfx("whoosh", -6.0)
				else:
					_streber_write()


## The supervisor at the front: sits and reads, stands up (the tell), looks over the hall.
func _process_supervisor(delta: float) -> void:
	a_t += delta
	match a_state:
		"sit":
			if a_t >= a_dur:
				a_state = "stand"
				a_t = 0.0
				a_dur = lerpf(SUP_TELL.x, SUP_TELL.y, alert)
				UI.sfx("buzz", -14.0)
		"stand":
			if a_t >= a_dur:
				a_state = "look"
				a_t = 0.0
				a_dur = randf_range(SUP_LOOK.x, SUP_LOOK.y)
		"look":
			for pid in 2:
				if view[pid] > SEEN_FROM:
					_caught(pid, "aufsicht")
					return
			if a_t >= a_dur:
				a_state = "sit"
				a_t = 0.0
				a_dur = randf_range(SUP_EVERY.x, SUP_EVERY.y) * (1.0 - 0.4 * alert)


func _close_call(text: String) -> void:
	near += 1
	bonus_alert += NEAR_ALERT
	shout = text
	UI.sfx("buzz", -8.0)


func _caught(pid: int, by: String) -> void:
	phase = "caught"
	phase_t = 0.0
	caught_pid = pid
	caught_by = by
	flash = 1.0
	if by == "streber":
		shout = "AUFSICHT! %s SCHREIBT AB!" % Game.name_of(pid).to_upper()
	else:
		shout = "%s, KOMMEN SIE BITTE NACH VORNE." % Game.name_of(pid).to_upper()
	UI.sfx("fail")
	UI.sfx("doom", -4.0)


# ------------------------------------------------------------------ drawing
func _draw_half(ci: Control, pid: int) -> void:
	var w := ci.size.x
	var h := ci.size.y
	var v: float = view[pid]
	var dir: float = SIDE[pid]                   # P1 turns left, P2 turns right
	var off := -dir * v * PAN                   # the room moves the other way
	var bob := sin(t * 1.3 + pid) * 2.0
	_draw_hall(ci, w, h, off, bob)
	# the Streber right next to you, behind the partition: at the edge while you look ahead,
	# his screen in the middle when you are fully turned
	_draw_streber(ci, pid, Vector2(w / 2.0 + dir * (20.0 + PAN) + off, h * 0.8 + bob))
	_draw_own_screen(ci, pid, w, h, off * 1.4)   # right in front of you: moves out of the picture when you turn
	# memory: what you have in your head right now
	if memory[pid] > 0.0:
		var mc := Vector2(w / 2.0 - dir * 170.0, 300)
		ci.draw_circle(mc, 42, Color(1, 1, 1, 0.94))
		ci.draw_circle(mc + Vector2(dir * 52, 44), 10, Color(1, 1, 1, 0.94))
		ci.draw_arc(mc, 36, -PI / 2.0, -PI / 2.0 + TAU * memory[pid], 32, Color(KEYS.TAG_COLORS[pid]), 7.0)
		ci.draw_string(font, mc + Vector2(-40, 7), "f'(x)=", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, INK)
	for i in 6:
		var k := float(i) / 6.0
		ci.draw_rect(Rect2(-i * 6, -i * 6, w + i * 12, h + i * 12), Color(0, 0, 0, 0.05 * (1.0 - k)), false, 40.0)
	if caught_pid == pid and phase in ["caught", "done"]:
		ci.draw_rect(Rect2(0, 0, w, h), Color(1, 0.1, 0.15, 0.25 + flash * 0.3))
	_draw_cam(ci, pid)
	_draw_hud(ci, pid)


## The ONA exam hall: window wall with bars, green steel pillars with braces, ducts under the
## ceiling, rows of desks with white partitions and screens, the supervisor at the front.
func _draw_hall(ci: Control, w: float, h: float, off: float, bob: float) -> void:
	var hor := h * 0.44 + bob
	var o1 := off * 0.25          # far: window wall
	ci.draw_rect(Rect2(0, 0, w, h), FLOOR)
	ci.draw_rect(Rect2(0, 0, w, hor), CEIL)
	# window wall
	var wy := 70.0 + bob
	ci.draw_rect(Rect2(-200 + o1, wy, w + 400, hor - wy), WIN)
	var x := -200.0 + fmod(o1, 26.0)
	while x < w + 200:
		ci.draw_line(Vector2(x, wy), Vector2(x, hor), WIN_BAR, 2.0)
		x += 26.0
	var y := wy
	while y < hor:
		ci.draw_line(Vector2(0, y), Vector2(w, y), WIN_BAR, 2.0)
		y += 22.0
	# pillars with diagonal braces
	for k in 5:
		var px := -260.0 + k * 260.0 + o1 * 1.6
		ci.draw_line(Vector2(px, wy + 10), Vector2(px + 120, hor), PILLAR.lightened(0.3), 4.0)
		ci.draw_rect(Rect2(px - 8, 20, 16, hor - 20), PILLAR)
	# ducts and lamps under the ceiling
	for k in 3:
		var dy := 18.0 + k * 16.0 + bob * 0.5
		ci.draw_rect(Rect2(0, dy, w, 9), DUCT)
		ci.draw_line(Vector2(0, dy + 9), Vector2(w, dy + 9), DUCT.darkened(0.15), 1.0)
	for k in 6:
		ci.draw_rect(Rect2(40 + k * 110 + fmod(o1, 110.0), 8, 70, 4), Color.WHITE)
	# supervisor at the front, raised desk
	var sup := Vector2(w / 2.0 + off * 0.3, hor + 18)
	ci.draw_rect(Rect2(sup.x - 70, sup.y - 18, 140, 26), DESK.darkened(0.2))
	var standing := a_state != "sit" and phase != "calib"
	var watching := a_state == "look" or (caught_by == "aufsicht" and phase != "exam")
	ART.draw_character(ci, {"skin": "e8b894", "hair": "8a8a8a", "top": "3b4a6b", "hair_style": "kurz", "acc": ["glasses"]},
		ART.FRONT, 0.0, false, sup + Vector2(0, -6 if not standing else -24), 1.8)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if watching:
		ci.draw_circle(sup + Vector2(0, -122), 13, UI.RED)
		ci.draw_string(font, sup + Vector2(-10, -114), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 20, Color.WHITE)
		# her look sweeps over the hall
		var a := sin(a_t * 2.2) * 0.9
		ci.draw_colored_polygon(PackedVector2Array([sup + Vector2(0, -60), sup + Vector2(-200 + a * 120, 320), sup + Vector2(200 + a * 120, 320)]), Color(1.0, 0.93, 0.6, 0.12))
	elif standing:
		ci.draw_circle(sup + Vector2(0, -122), 13, UI.YELLOW)
		ci.draw_string(font, sup + Vector2(-10, -114), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 20, INK)
	# rows of desks with partitions and screens, students from behind; nearer rows are larger
	for row in 3:
		var ry := hor + 40 + row * 62 + bob
		var sc := 1.2 + row * 0.45
		var gap := 90.0 + row * 40.0
		var par := 0.45 + row * 0.2
		for k in range(-5, 6):
			var cx := w / 2.0 + k * gap + off * par + (gap / 2.0 if row % 2 else 0.0)
			if cx < -80 or cx > w + 80:
				continue
			var look := {"skin": "e0ac85", "hair": ["2b2018", "8a3b22", "1a1a1a", "c9a36b"][absi(k + row) % 4],
				"top": ["4d6a8f", "8f4d5e", "3e7d4f", "33383d"][absi(k * 3 + row) % 4], "hair_style": ["kurz", "lang", "locken", "zopf"][absi(k + row * 2) % 4], "acc": []}
			ART.draw_character(ci, look, ART.BACK, 0.0, false, Vector2(cx, ry + 6), sc)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var dw := gap - 12.0
			ci.draw_rect(Rect2(cx - dw / 2.0, ry - 16 * sc, dw, 16 * sc), DESK)
			ci.draw_rect(Rect2(cx - 14 * sc, ry - 30 * sc, 28 * sc, 16 * sc), SCREEN)
			ci.draw_rect(Rect2(cx - 12 * sc, ry - 28 * sc, 24 * sc, 12 * sc), Color("7fa3c7"))
			ci.draw_rect(Rect2(cx + dw / 2.0 - 3, ry - 40 * sc, 6, 40 * sc), PART)
			ci.draw_line(Vector2(cx + dw / 2.0 - 3, ry - 40 * sc), Vector2(cx + dw / 2.0 + 3, ry - 40 * sc), PART_EDGE, 2.0)


func _draw_streber(ci: Control, pid: int, foot: Vector2) -> void:
	var look := {"skin": "f1c9a5", "hair": "6b4a2b", "top": "ffffff", "pants": "2d3a52", "hair_style": "kurz", "acc": ["glasses"]}
	var facing := ART.BACK
	var at_me := false
	var bob := 0.0
	match s_state:
		"write":
			bob = sin(t * 8.0) * 2.0
		"tell":
			bob = -6.0
		"glance":
			at_me = s_side == pid
			facing = ART.FRONT if at_me else (ART.LEFT if pid == 0 else ART.RIGHT)
	if phase in ["caught", "done"] and caught_by == "streber":
		at_me = caught_pid == pid
		facing = ART.FRONT if at_me else (ART.LEFT if pid == 0 else ART.RIGHT)
	var dir: float = SIDE[pid]
	ART.draw_character(ci, look, facing, 0.0, false, foot + Vector2(0, bob), 5.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# his desk and his screen, the partition between you and him
	var desk := Rect2(foot.x - 190, foot.y - 70, 380, 34)
	ci.draw_rect(desk, DESK)
	ci.draw_rect(Rect2(desk.position.x, desk.end.y, desk.size.x, 10), DESK.darkened(0.2))
	var scr := Rect2(foot.x - dir * 20.0 - 110, foot.y - 168, 220, 104)
	ci.draw_rect(scr.grow(6), SCREEN)
	ci.draw_rect(scr, SCREEN_ON)
	ci.draw_rect(Rect2(scr.position.x, scr.position.y, scr.size.x, 14), Color("1f407a"))
	ci.draw_string(font, scr.position + Vector2(6, 11), "Safe Exam · Aufgabe 3", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	ci.draw_rect(Rect2(foot.x - dir * 20.0 - 8, scr.end.y + 6, 16, 10), SCREEN)
	var reading: bool = view[pid] >= READ_FROM and s_state != "glance" and phase == "exam"
	for i in 6:
		var lw := 170.0 - (i * 37) % 70
		var lc := Color(KEYS.TAG_COLORS[pid]) if reading and i == int(t * 2.0) % 6 else Color("6b7385")
		ci.draw_line(scr.position + Vector2(10, 24 + i * 12), scr.position + Vector2(10 + lw, 24 + i * 12), lc, 2.0)
	var part_x := foot.x - dir * 200.0
	ci.draw_rect(Rect2(part_x - 5, foot.y - 210, 10, 210), PART)
	ci.draw_rect(Rect2(part_x - 5, foot.y - 210, 10, 4), PART_EDGE)
	# bubble over his head: "?" when restless, "!" when looking at you
	var hc := foot + Vector2(0, -5.0 * 58.0)
	if s_state == "tell" and phase == "exam":
		ci.draw_circle(hc, 26, UI.YELLOW)
		ci.draw_string(font, hc + Vector2(-20, 12), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 34, INK)
	elif (s_state == "glance" and at_me and phase == "exam") or (at_me and phase != "exam" and caught_by == "streber"):
		ci.draw_circle(hc, 28, UI.RED)
		ci.draw_string(font, hc + Vector2(-20, 12), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 36, Color.WHITE)


func _draw_own_screen(ci: Control, pid: int, w: float, h: float, off: float) -> void:
	var desk := Rect2(-20 + off, h - 150, w + 40, 180)
	ci.draw_rect(desk, DESK)
	ci.draw_rect(Rect2(desk.position.x, desk.position.y, desk.size.x, 6), DESK.darkened(0.2))
	var scr := Rect2(w / 2.0 - 200 + off, h - 300, 400, 226)
	ci.draw_rect(scr.grow(8), SCREEN)
	ci.draw_rect(scr, SCREEN_ON)
	ci.draw_rect(Rect2(scr.position.x, scr.position.y, scr.size.x, 22), Color("1f407a"))
	ci.draw_string(font, scr.position + Vector2(8, 16), "Safe Exam Browser · Basisprüfung · %s" % Game.name_of(pid), HORIZONTAL_ALIGNMENT_LEFT, scr.size.x - 16, 13, Color.WHITE)
	var col := Color(KEYS.TAG_COLORS[pid]).darkened(0.25)
	for i in ANSWERS:
		var yy := scr.position.y + 36 + i * 23
		ci.draw_string(font, Vector2(scr.position.x + 10, yy + 12), "%d)" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		ci.draw_rect(Rect2(scr.position.x + 36, yy, scr.size.x - 50, 17), Color("eef1f6"))
		var fill := clampf(answers[pid] - i, 0.0, 1.0)
		if fill > 0.0:
			ci.draw_rect(Rect2(scr.position.x + 38, yy + 2, (scr.size.x - 54) * fill, 13), Color(col, 0.25))
			var chars := int(28 * fill)
			ci.draw_string(font, Vector2(scr.position.x + 42, yy + 13), "x = 2 · e^(-t) + C ..........".substr(0, chars), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	ci.draw_rect(Rect2(w / 2.0 - 20 + off, scr.end.y + 8, 40, 14), SCREEN)
	# keyboard
	ci.draw_rect(Rect2(w / 2.0 - 150 + off, h - 52, 300, 40), Color("3a3f4c"))
	for k in 3:
		ci.draw_line(Vector2(w / 2.0 - 140 + off, h - 40 + k * 10), Vector2(w / 2.0 + 140 + off, h - 40 + k * 10), Color("50566a"), 2.0)


## The player's own camera picture, small, bottom corner of the half.
func _draw_cam(ci: Control, pid: int) -> void:
	var r := Rect2(14 if pid == 0 else ci.size.x - 174, ci.size.y - 134, 160, 120)
	ci.draw_rect(r.grow(3), INK)
	if Track.alive and Track.preview != null and Track.preview.get_width() > 0:
		var tw := float(Track.preview.get_width())
		var th := float(Track.preview.get_height())
		ci.draw_texture_rect_region(Track.preview, r, Rect2(tw / 2.0 * pid, 0, tw / 2.0, th))
	else:
		ci.draw_rect(r, Color("2a2e38"))
		ci.draw_string(font, r.position + Vector2(0, 64), "keine Kamera", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, UI.MUTED)
	if lost_t[pid] > LOST_WARN and phase != "calib":
		ci.draw_rect(r, Color(1, 0.2, 0.25, 0.35))
		ci.draw_string(font, r.position + Vector2(0, 112), "Nicht im Bild!", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color.WHITE)


func _text(ci: CanvasItem, pos: Vector2, s: String, fs: int, col: Color, width: float = -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string_outline(font, pos, s, al, width, fs, 6, INK)
	ci.draw_string(font, pos, s, al, width, fs, col)


func _draw_hud(ci: Control, pid: int) -> void:
	var w := ci.size.x
	var col := Color(KEYS.TAG_COLORS[pid])
	var bx := 14.0 if pid == 0 else w - 244.0
	ci.draw_rect(Rect2(bx, 14, 230, 78), Color(UI.NAVY, 0.88))
	ci.draw_rect(Rect2(bx, 14, 6, 78), col)
	_text(ci, Vector2(bx + 16, 40), Game.name_of(pid), 18, col)
	_text(ci, Vector2(bx + 16, 66), "Antworten %d / %d" % [int(answers[pid]), ANSWERS], 17, UI.WHITE)
	ci.draw_rect(Rect2(bx + 16, 76, 200, 8), Color("3a3f4c"))
	ci.draw_rect(Rect2(bx + 16, 76, 200 * memory[pid], 8), col)
	# how far the head is turned
	var gx0 := w - 214.0 if pid == 0 else 24.0
	var g := Rect2(gx0, 104, 190, 12)
	ci.draw_rect(g, Color(UI.NAVY, 0.85))
	ci.draw_rect(Rect2(g.position.x, g.position.y, g.size.x * SEEN_FROM, g.size.y), Color(UI.GREEN, 0.5))
	ci.draw_rect(Rect2(g.position.x + g.size.x * SEEN_FROM, g.position.y, g.size.x * (1.0 - SEEN_FROM), g.size.y), Color(UI.RED, 0.45))
	var mx: float = g.position.x + g.size.x * float(view[pid])
	ci.draw_rect(Rect2(mx - 3, g.position.y - 4, 6, g.size.y + 8), UI.WHITE)
	_text(ci, Vector2(gx0, 134), "Kopfdrehung", 13, UI.MUTED, 190, HORIZONTAL_ALIGNMENT_CENTER)
	var hint := ""
	if phase == "calib":
		if not Track.alive and not keys_ok:
			hint = ""
		elif yaw_sign[pid] == 0:
			var way := "links" if pid == 0 else "rechts"
			hint = "Dreh den Kopf nach %s zum Streber!" % way if not is_nan(_head(pid)) else "Setz dich vor die Kamera"
			if wrong_t[pid] > 0.3:
				hint = "Andere Richtung! Nach %s!" % way
		elif view[pid] >= WRITE_BELOW:
			hint = "Gut! Jetzt wieder nach vorne"
		else:
			hint = "Bereit"
	elif phase == "exam":
		if view[pid] >= READ_FROM and s_state != "glance":
			hint = "Lesen …"
		elif view[pid] <= WRITE_BELOW and memory[pid] > 0.0 and answers[pid] < ANSWERS:
			hint = "Tippen …"
		elif answers[pid] >= ANSWERS:
			hint = "Fertig! Nur noch brav nach vorne schauen."
	if hint != "":
		_text(ci, Vector2(0, ci.size.y * 0.5), hint, 24, UI.YELLOW if phase == "calib" else UI.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)


## Middle: alert of the two watchers, the exam clock, the calibration text, the shout.
func _draw_over(ci: Control) -> void:
	var w := ci.size.x
	var h := ci.size.y
	ci.draw_rect(Rect2(w / 2.0 - 3.0, 0, 6, h), INK)
	var r := Rect2(w / 2.0 - 110, 14, 220, 64)
	ci.draw_rect(r, Color(UI.NAVY, 0.92))
	_text(ci, r.position + Vector2(0, 22), "Alarm", 14, UI.MUTED, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_rect(Rect2(r.position.x + 14, r.position.y + 30, r.size.x - 28, 12), Color("3a3f4c"))
	ci.draw_rect(Rect2(r.position.x + 14, r.position.y + 30, (r.size.x - 28) * alert, 12), UI.GREEN.lerp(UI.RED, alert))
	var left := maxf(0.0, EXAM_TIME - exam_t)
	_text(ci, r.position + Vector2(0, 58), "Ende in %d:%02d" % [int(left) / 60, int(left) % 60], 14, UI.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if phase == "calib":
		ci.draw_rect(Rect2(0, h * 0.2 - 64, w, 170), Color(UI.NAVY, 0.9))
		_text(ci, Vector2(0, h * 0.2), "BASISPRÜFUNG · ONA", 52, UI.YELLOW, w, HORIZONTAL_ALIGNMENT_CENTER)
		if not Track.alive and not keys_ok:
			_text(ci, Vector2(0, h * 0.2 + 42), "Für diese Prüfung braucht es die Kamera. %s" % Track.status, 20, UI.RED, w, HORIZONTAL_ALIGNMENT_CENTER)
			_text(ci, Vector2(0, h * 0.2 + 70), "Einrichtung: tracker/README.md (uv installieren, einmal uv run tracker/tracker.py --selftest)", 16, UI.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_text(ci, Vector2(0, h * 0.2 + 40), "Kopf zum Streber: spicken · Kopf zum eigenen Bildschirm: eintippen", 18, UI.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
			_text(ci, Vector2(0, h * 0.2 + 66), "Der Streber zuckt, bevor er sich umdreht. Die Aufsicht steht auf, bevor sie in die Halle schaut.", 17, UI.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
			_text(ci, Vector2(0, h * 0.2 + 92), "Wer mit gedrehtem Kopf erwischt wird, fliegt, und ihr beide mit.", 17, UI.ORANGE, w, HORIZONTAL_ALIGNMENT_CENTER)
	if shout != "" and phase != "calib":
		var big := phase != "exam"
		_text(ci, Vector2(0, h * 0.34), shout, 38 if big else 28, UI.RED if big else UI.YELLOW, w, HORIZONTAL_ALIGNMENT_CENTER)
	if phase == "exam" and s_state == "write" and s_t > 1.0:
		shout = ""
