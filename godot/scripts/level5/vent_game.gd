extends CanvasLayer
## Level 5: the vent of the camera room, played as a pantomime in front of the camera (autoload
## Track, like the pipetting in level 4). Four screws: pinch thumb and index finger (the
## screwdriver) and turn circles with the hand, two turns per screw. Then three cables: make a
## fist (grab) and yank the hand down, twice per cable (the first loosens it). A yank is measured
## from the highest point of the fist in the last half second; a fist lost for a moment (motion
## blur) still holds, and a hand yanked out of the picture counts. When the last cable is out, the cameras are broken.
## Without a camera or tracker the same with keys (the team's rule for every camera minigame):
## left and right in turn unscrew, interact grabs a cable and down rips it. K switches by hand.
##
## It takes only the half of the screen of whoever works at the vent (main.screen_side), like the
## other minigames; the other player keeps playing on the other half.
##
##   var mg = VentGame.new();  mg.pid = pid;  mg.main = main;  main.add_child(mg);  mg.open()
## Emits finished(success). Esc or Backspace leaves it.

signal finished(success: bool)

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const TM = preload("res://scripts/track_math.gd")

# ---- tuning (camera values are starting points, check them with res://track_debug.tscn)
const SCREWS := 4
const TURNS := 2.0             # turns per screw
const PINCH_GRIP := 0.35       # TM.pinch01 below this holds the screwdriver
const MIN_R := 0.025           # circles smaller than this (share of the picture) do not count
const TRAIL := 0.9             # seconds of finger positions for the middle of the circle
const CABLES := 3
const PULL := 0.16             # a yank: the fist moves down this far (share of the picture) ...
const PULL_TIME := 0.5         # ... within this many seconds (a slow pull does not count)
const YANKS := 2               # yanks per cable: the first loosens it, the second rips it out
const GRIP_HOLD := 0.6         # a fist the camera loses for a moment (motion blur when yanking) still holds this long
const LOST_RIP := 0.6          # the hand vanishes after a yank got this far: it was yanked out of the picture
const CAM_WAIT := 6.0          # seconds to wait for the camera before the keys take over
const KEY_TURN := 0.25         # turns per left/right in the keys variant
const KEY_PULL_TIME := 0.35    # keys: hold interact, then down within this long

const CAM_SIZE := Vector2(300, 225)
const BONES := [[0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [5, 6], [6, 7], [7, 8], [5, 9], [9, 10], [10, 11], [11, 12],
	[9, 13], [13, 14], [14, 15], [15, 16], [13, 17], [17, 18], [18, 19], [19, 20], [0, 17]]
const CABLE_COLS := ["e74c3c", "f1c40f", "3498db"]

var pid := 0
var main
var mode := "wait"             # wait (for the camera), cam, keys
var chose_keys := false
var wait_t := 0.0
var t := 0.0
var phase := "screws"          # screws, cables, done
var screw := 0                 # the screw being worked on
var turns: Array = [0.0, 0.0, 0.0, 0.0]
var cable := 0
var ripped: Array = [false, false, false]
var gripping := false          # pinch (screws) or fist (cables) right now
var trail: Array = []          # [time, Vector2] of the fingertip, for the middle of the circle
var last_ang := NAN
var grab_y := 0.0             # highest point of the fist within the last PULL_TIME
var pull_trail: Array = []    # [time, palm y] while gripping
var yanks := 0                # yanks on the current cable
var grab_t := 0.0
var fist_t := -9.0            # last time the camera saw a fist
var last_palm := 0.0
var pull_k := 0.0             # how far the cable is pulled, 0..1 (for the drawing)
var key_side := 0              # keys variant: which of left/right comes next
var sparks: Array = []         # [pos, vel, life]
var hand_pts: Array = []
var hand_age := 99.0
var done_t := -1.0
var abort_held := true
var root: Control
var view: Control


func open() -> void:
	layer = 20
	Track.use(self, ["hand"])
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	view = Control.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	root.add_child(view)
	_place()
	if Track.alive:
		mode = "cam"
	UI.sfx("whoosh", -10.0)


## On the half of the screen of this player (the split can still be moving).
func _place() -> void:
	var vs := root.get_viewport_rect().size
	var side: int = main.screen_side(pid) if main != null else pid
	if side < 0:
		side = pid
	root.position = Vector2(side * vs.x / 2.0, 0)
	root.size = Vector2(vs.x / 2.0, vs.y)
	view.position = Vector2.ZERO
	view.size = root.size


func _process(delta: float) -> void:
	t += delta
	_place()
	view.queue_redraw()
	for s in sparks:
		s[0] += s[1] * delta
		s[1] += Vector2(0, 600) * delta
		s[2] -= delta
	sparks = sparks.filter(func(s): return s[2] > 0.0)
	if done_t >= 0.0:
		done_t += delta
		if done_t > 1.6:
			finished.emit(true)
			queue_free()
		return
	var abort_now := false
	for k in KEYS.keys_for(pid)["abort"]:
		abort_now = abort_now or Input.is_physical_key_pressed(k)
	if abort_now and not abort_held:
		finished.emit(false)
		queue_free()
		return
	abort_held = abort_now
	_update_mode(delta)
	if mode == "cam":
		_read_camera(delta)
	elif mode == "keys":
		_read_keys(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_K:
		chose_keys = mode != "keys"
		mode = "keys" if chose_keys else ("cam" if Track.alive else "wait")
		get_viewport().set_input_as_handled()


func _update_mode(delta: float) -> void:
	match mode:
		"wait":
			if Track.alive:
				mode = "cam"
			else:
				wait_t += delta
				if wait_t >= CAM_WAIT or Track.status.begins_with("kein"):
					mode = "keys"
		"keys":
			if Track.alive and not chose_keys:
				mode = "cam"


# ------------------------------------------------------------------ camera
func _hand() -> Dictionary:
	var h: Dictionary = TM.mine(Track.hands, pid)
	if h.is_empty():
		h = Track.hand(-1)
	return h


func _read_camera(delta: float) -> void:
	var h := _hand()
	if h.is_empty():
		hand_age += delta
		last_ang = NAN
		if phase == "cables" and gripping:
			# pulled down hard enough that the hand left the picture: that was the yank
			if last_palm - grab_y > PULL * LOST_RIP:
				_yank()
			elif t - fist_t > GRIP_HOLD:
				gripping = false
				pull_k = 0.0
		else:
			gripping = false
		return
	hand_age = 0.0
	hand_pts = []
	for p in h["pts"]:
		hand_pts.append(Vector2(p[0], p[1]))
	var tip := Vector2(float(h["x"]) * Track.aspect, float(h["y"]))
	match phase:
		"screws":
			gripping = TM.pinch01(h) < PINCH_GRIP
			trail.append([t, tip])
			while trail.size() > 0 and t - float(trail[0][0]) > TRAIL:
				trail.pop_front()
			if not gripping or trail.size() < 6:
				last_ang = NAN
				return
			var mid := Vector2.ZERO
			for e in trail:
				mid += e[1]
			mid /= trail.size()
			var off: Vector2 = tip - mid
			if off.length() < MIN_R:
				return
			var a := off.angle()
			if not is_nan(last_ang):
				_turn(absf(wrapf(a - last_ang, -PI, PI)) / TAU)
			last_ang = a
		"cables":
			var palm := float(h["palm"][1])
			if TM.is_fist(h):
				if not gripping:
					gripping = true
					grab_y = palm
					grab_t = t
					UI.sfx("click", -10.0)
				fist_t = t
			elif gripping and t - fist_t > GRIP_HOLD:
				gripping = false   # the hand opened for good: let go
			if gripping:
				# measured from the highest point of the last PULL_TIME: only a quick yank gets far enough
				pull_trail.append([t, palm])
				while pull_trail.size() > 0 and t - float(pull_trail[0][0]) > PULL_TIME:
					pull_trail.pop_front()
				grab_y = palm
				for e in pull_trail:
					grab_y = minf(grab_y, float(e[1]))
				pull_k = clampf((palm - grab_y) / PULL, 0.0, 1.0)
				if palm - grab_y >= PULL:
					_yank()
			else:
				pull_k = 0.0
				pull_trail.clear()
			last_palm = palm


# ------------------------------------------------------------------ keys
func _read_keys(_delta: float) -> void:
	var left := Input.is_action_just_pressed(KEYS.action(pid, "left"))
	var right := Input.is_action_just_pressed(KEYS.action(pid, "right"))
	match phase:
		"screws":
			gripping = Input.is_action_pressed(KEYS.action(pid, "left")) or Input.is_action_pressed(KEYS.action(pid, "right"))
			if (left and key_side == 0) or (right and key_side == 1):
				key_side = 1 - key_side
				_turn(KEY_TURN)
		"cables":
			if Input.is_action_just_pressed(KEYS.action(pid, "interact")):
				gripping = true
				grab_t = t
				UI.sfx("click", -10.0)
			if not Input.is_action_pressed(KEYS.action(pid, "interact")):
				gripping = false
			pull_k = 0.5 if gripping else 0.0
			if gripping and Input.is_action_just_pressed(KEYS.action(pid, "down")):
				if t - grab_t < KEY_PULL_TIME:
					_yank()
				else:
					grab_t = t


# ------------------------------------------------------------------ progress
func _turn(amount: float) -> void:
	if phase != "screws":
		return
	var before: float = floorf(float(turns[screw]) * 4.0)
	turns[screw] = minf(TURNS, turns[screw] + amount)
	if floorf(turns[screw] * 4.0) != before:
		UI.sfx("tick", -14.0)
	if turns[screw] >= TURNS:
		UI.sfx("pop", -6.0)
		screw += 1
		last_ang = NAN
		trail.clear()
		if screw >= SCREWS:
			phase = "cables"
			gripping = false
			UI.sfx("whoosh", -6.0)


## One yank on the current cable: the first loosens it, the last rips it out.
func _yank() -> void:
	pull_trail.clear()
	pull_k = 0.0
	yanks += 1
	if yanks < YANKS:
		UI.sfx("buzz", -10.0)
		var at := _cable_end(cable) + Vector2(0, 10)
		for i in 8:
			sparks.append([at, Vector2(randf_range(-120, 120), randf_range(-200, -40)), randf_range(0.2, 0.5)])
		return
	yanks = 0
	_rip()


func _rip() -> void:
	ripped[cable] = true
	var at := _cable_end(cable)
	for i in 26:
		sparks.append([at, Vector2(randf_range(-260, 260), randf_range(-380, -60)), randf_range(0.3, 0.9)])
	UI.sfx("buzz", -2.0)
	UI.sfx("fail", -12.0)
	cable += 1
	gripping = false
	pull_k = 0.0
	fist_t = -9.0
	if cable >= CABLES:
		phase = "done"
		done_t = 0.0
		UI.sfx("success")


# ------------------------------------------------------------------ drawing
func _panel() -> Rect2:
	return Rect2(Vector2(14, 24), view.size - Vector2(28, 48))


func _vent_rect() -> Rect2:
	var p := _panel()
	return Rect2(p.position.x + 22.0, p.position.y + 70.0, p.size.x - 44.0, minf(250.0, p.size.y * 0.4))


func _cam_rect() -> Rect2:
	var v := _vent_rect()
	return Rect2(Vector2(v.position.x + (v.size.x - CAM_SIZE.x) / 2.0, v.end.y + 22.0), CAM_SIZE)


func _screw_pos(i: int) -> Vector2:
	var r := _vent_rect().grow(-34.0)
	return [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end][i]


func _cable_end(i: int) -> Vector2:
	var r := _vent_rect()
	return Vector2(r.position.x + r.size.x * (0.3 + i * 0.2), r.position.y + r.size.y * 0.45)


func _text(pos: Vector2, s: String, fs: int, col: Color, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := ThemeDB.fallback_font
	view.draw_string_outline(font, pos, tr(s), align, width, fs, 6, Color("15162b"))
	view.draw_string(font, pos, tr(s), align, width, fs, col)


func _draw_view() -> void:
	var panel := _panel()
	var w := panel.size.x
	view.draw_rect(Rect2(Vector2.ZERO, view.size), Color(0.03, 0.03, 0.08, 0.55))
	view.draw_style_box(UI.box(UI.NAVY, Color(KEYS.TAG_COLORS[pid]), 20, 5, 0), panel)
	var title := "Lüftungsschacht" if phase == "screws" else ("Kabel rausreissen!" if phase == "cables" else "Kameras kaputt!")
	_text(panel.position + Vector2(22, 46), title, 28, UI.YELLOW)
	var prog := "Schraube %d / %d" % [mini(screw + 1, SCREWS), SCREWS] if phase == "screws" else "Kabel %d / %d" % [mini(cable + 1, CABLES), CABLES]
	if phase != "done":
		_text(panel.position + Vector2(w - 190, 44), prog, 18, UI.WHITE, 168.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_vent()
	_draw_cam(_cam_rect())
	var hint := ""
	match phase:
		"screws":
			hint = "Daumen und Zeigefinger zusammen und mit der Hand Kreise drehen." if mode != "keys" else "Links und rechts im Wechsel: die Schraube dreht sich."
		"cables":
			if yanks > 0:
				hint = "Locker! Noch einmal kräftig reissen!"
			else:
				hint = "Faust machen und ruckartig nach unten reissen, zweimal pro Kabel!" if mode != "keys" else "%s halten (packen), dann schnell runter (reissen), zweimal pro Kabel." % ("E" if pid == 0 else "Enter")
		"done":
			hint = "Die Kameras im Kameraraum sind tot."
	_text(Vector2(panel.position.x + 22, panel.end.y - 44), hint, 16, UI.WHITE, w - 44.0)
	_text(Vector2(panel.position.x + 22, panel.end.y - 18), "%s: abbrechen · K: Tasten" % KEYS.LABELS[pid]["abort"], 13, UI.MUTED)


func _draw_vent() -> void:
	var r := _vent_rect()
	view.draw_rect(r.grow(8), Color("2b2f35"))
	# behind the cover: the cable board
	view.draw_rect(r, Color("16181d"))
	var board := Rect2(r.position.x + r.size.x * 0.18, r.position.y + r.size.y * 0.2, r.size.x * 0.64, r.size.y * 0.5)
	view.draw_rect(board, Color("2f3a2f"))
	for i in CABLES:
		var end := _cable_end(i)
		var col := Color(CABLE_COLS[i])
		if ripped[i]:
			# torn off: a stump in the board, the rest hangs down
			view.draw_line(end, end + Vector2(0, 14), col.darkened(0.3), 6.0)
			view.draw_line(end + Vector2(6, 40), end + Vector2(-10, r.size.y * 0.5), col.darkened(0.4), 6.0)
			if fmod(t * 7.0 + i, 1.0) < 0.3:
				view.draw_circle(end + Vector2(0, 16), 4.0, UI.YELLOW)
		else:
			var loose := 18.0 * yanks if i == cable else 0.0   # half out after the first yank
			var tug := Vector2(0, (40.0 * pull_k + loose) if (i == cable and phase == "cables") else 0.0)
			view.draw_line(end + tug * 0.5, end + Vector2(0, r.size.y * 0.5) + tug, col, 7.0)
			view.draw_rect(Rect2(end - Vector2(9, 9) + tug * 0.5, Vector2(18, 18)), Color("c9ced8"))
			if i == cable and phase == "cables":
				view.draw_arc(end, 22.0 + sin(t * 6.0) * 3.0, 0, TAU, 24, UI.GREEN if gripping else UI.YELLOW, 3.0)
				if gripping:
					# how far it is pulled: a bar next to the cable, full = out
					var bar := Rect2(end + Vector2(30, -10), Vector2(12, 90))
					view.draw_rect(bar, Color("2b2f35"))
					view.draw_rect(Rect2(bar.position, Vector2(bar.size.x, bar.size.y * pull_k)), UI.GREEN.lerp(UI.RED, pull_k))
					view.draw_rect(bar, Color.WHITE, false, 1.5)
	# the cover with its slats while screws are still in
	if phase == "screws":
		view.draw_rect(r, Color("7d8794"))
		for i in 9:
			var y := r.position.y + 26.0 + i * (r.size.y - 52.0) / 9.0
			view.draw_rect(Rect2(r.position.x + 30, y, r.size.x - 60, 14), Color("4a5560"))
		for i in SCREWS:
			var p := _screw_pos(i)
			var out: float = float(turns[i]) / TURNS
			view.draw_circle(p + Vector2(3, 4), 14.0, Color(0, 0, 0, 0.35))
			view.draw_circle(p, 14.0 + out * 4.0, Color("c9ced8") if i < screw or i == screw else Color("9aa1ad"))
			var a: float = float(turns[i]) * TAU
			view.draw_line(p + Vector2.from_angle(a) * 10.0, p - Vector2.from_angle(a) * 10.0, Color("2b2f35"), 3.0)
			if i < screw:
				view.draw_circle(p, 16.0, Color("2b2f35"))   # out: just the hole
			elif i == screw:
				view.draw_arc(p, 24.0, -PI / 2.0, -PI / 2.0 + TAU * out, 32, UI.GREEN if gripping else UI.YELLOW, 5.0)
				if gripping:
					# the screwdriver
					view.draw_line(p, p + Vector2(40, -40), Color("e0a83a"), 7.0)
					view.draw_line(p + Vector2(40, -40), p + Vector2(62, -62), Color("d5202a"), 12.0)
	for s in sparks:
		view.draw_line(s[0], s[0] - (s[1] as Vector2) * 0.02, Color(1.0, 0.85, 0.3, clampf(s[2] * 2.0, 0.0, 1.0)), 2.5)


func _draw_cam(r: Rect2) -> void:
	view.draw_rect(r, UI.DARK)
	if mode == "cam" and Track.preview.get_width() > 0:
		var a: float = maxf(Track.aspect, 0.2)
		var size := Vector2(r.size.x, r.size.x / a)
		if size.y > r.size.y:
			size = Vector2(r.size.y * a, r.size.y)
		var pic := Rect2(r.position + (r.size - size) / 2.0, size)
		view.draw_texture_rect(Track.preview, pic, false)
		if hand_pts.size() >= 21 and hand_age < 0.4:
			var col := UI.GREEN if gripping else Color(KEYS.TAG_COLORS[pid])
			for b in BONES:
				view.draw_line(pic.position + (hand_pts[b[0]] as Vector2) * pic.size, pic.position + (hand_pts[b[1]] as Vector2) * pic.size, Color(col, 0.85), 2.5)
			for p in hand_pts:
				view.draw_circle(pic.position + (p as Vector2) * pic.size, 3.0, col)
		var state := ""
		if phase == "screws":
			state = "Schraubenzieher gepackt" if gripping else "Finger zusammen!"
		elif phase == "cables":
			state = "Gepackt, reiss!" if gripping else "Faust machen!"
		_text(r.position + Vector2(10, r.size.y - 12), state, 16, UI.GREEN if gripping else UI.YELLOW)
	else:
		var msg := "Kamera startet …" if mode == "wait" else "Tasten-Variante"
		if mode == "wait" and Track.status != "aus":
			msg = Track.status
		_text(r.position + Vector2(0, r.size.y / 2.0), msg, 18, UI.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	view.draw_rect(r, Color(KEYS.TAG_COLORS[pid]), false, 3.0)
