extends CanvasLayer
## Level 18 (Ersti-Fest): the dance battle. The two players dance one after the other, alone in
## front of the camera (autoload Track, body pose), ROUNDS rounds of DANCE_TIME seconds each, and
## get a score from 0 to 10 for every dance: the crazier, the higher.
##
## "Crazy" is measured, not judged: how fast arms, legs and head move (in shoulder widths per
## second, so the distance to the camera does not matter), how much room each hand sweeps, and how
## far the body itself travels. Time in which the camera sees nobody counts as standing still.
## A 10 needs all three at once, for the whole dance: only really crazy dancing gets there.
## What the camera reports is restless: the skeleton that is drawn is smoothed and kept for a
## moment when it is lost, and single jumps are capped (SPEED_CAP).
##
## Without a camera the same battle is danced on the keys: the dancer hammers the keys of their
## side, and changing keys counts more than repeating one. K switches by hand.
##
##   var mg = DanceGame.new();  mg.first = pid;  mg.sfx = <fest_sfx node>;  main.add_child(mg);  mg.open()
## Emits finished([total P1, total P2]), or finished([]) if somebody left with Esc / Backspace.

signal finished(totals: Array)

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const ART = preload("res://scripts/character_art.gd")
const TM = preload("res://scripts/track_math.gd")

# ---- tuning. Played in front of the real camera on 11.10.2026 and made stricter twice since:
# "only really crazy movements" are to get a 10. Start: E_FULL 2.4, REACH_FULL 9 and TRAVEL_FULL
# 1.6 (both as the box around everything seen), KEY_FULL 40, no CURVE. Second: 3.4, 12, 2.2, 50,
# CURVE 1.2. Now: see below; room and way no longer count single wrong pictures (TRIM), and the
# speed is that of the TOP fastest joints, so legs the camera sees do not thin out the arms.
const ROUNDS := 3
const DANCE_TIME := 5.0        # seconds per dance
const READY_TIME := 3.0        # countdown before each dance
const SHOW_TIME := 2.8         # the score stays this long
const END_TIME := 6.0
const CAM_WAIT := 6.0          # seconds to wait for the camera before the keys take over
const BPM := 120.0
const JOINTS := [0, 13, 14, 15, 16, 25, 26, 27, 28]   # nose, elbows, wrists, knees, ankles
const MIN_VIS := 0.5           # body points the camera is less sure of are left out
const SPEED_CAP := 10.0        # shoulder widths per second: anything faster is a jump of the camera
const TOP := 5                 # the speed is the mean of this many fastest joints (fewer in the picture: the rest counts 0)
const E_FULL := 5.5            # ... and this much, as the mean over the whole dance, is completely crazy:
                               # both arms whirling in full circles about once a second, and the rest of the body with them
const REACH_FULL := 6.0        # room each hand sweeps (mean of both), in shoulder widths squared: from above the head to the hips, and as wide
const TRAVEL_FULL := 1.8       # how far the body itself moves, in shoulder widths: jumping from side to side
const TRIM := 0.1              # room and way: this share of the pictures is cut off at either end
const MIN_SAMPLES := 10        # ... and with fewer pictures than this there is no room and no way
const CURVE := 1.4             # above 1: the middle scores lower, a 10 stays a 10 (1 = straight line)
const W_ENERGY := 0.65         # what the three are worth, together 1
const W_REACH := 0.2
const W_TRAVEL := 0.15
const SMOOTH := 0.08           # seconds over which the drawn skeleton is smoothed
const HOLD := 0.5              # seconds it stays when the camera loses the dancer
const KEY_FULL := 60.0         # keys variant: this many points are a 10 (a new key 1, the same again 0.35)
const KEY_SAME := 0.35

var first := 0                 # who dances first
var sfx = null
var mode := "wait"             # wait (for the camera), cam, keys
var wait_t := 0.0
var chose_keys := false
var phase := "ready"           # ready, dance, show, end
var phase_t := 0.0
var turn := 0                  # 0 .. ROUNDS * 2 - 1
var scores: Array = [[], []]   # per player: one score per round
var last_score := 0.0
var t := 0.0
# measuring (camera)
var raw_prev: Array = []
var since_new := 0.0
var sum_e := 0.0
var e_now := 0.0
var meter := 0.0               # 0..1, what the bar shows
var hand_xy: Array = [[[], []], [[], []]]   # per hand: all x and all y, relative to the shoulders
var mid_xy: Array = [[], []]                # the middle of the shoulders: all x and all y
var show_pts: Array = []       # the skeleton that is drawn: Vector3(x, y, visibility)
var seen_age := 99.0
# keys variant
var key_points := 0.0
var last_key := -1
var lean := 0.0
var hop := 0.0
var squat := 0.0
var face_i := 0

var canvas: Control
var avatar: Control


func dancer() -> int:
	return first if turn % 2 == 0 else 1 - first


func round_no() -> int:
	@warning_ignore("integer_division")
	return turn / 2


func open() -> void:
	layer = 20
	Track.use(self, ["pose"])   # the camera goes off again when this node leaves the tree
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_all)
	avatar = Control.new()
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.draw.connect(_draw_avatar)
	canvas.add_child(avatar)
	if Track.alive:
		mode = "cam"
	if sfx:
		sfx.beat_on(-12.0)
	_start_ready()


func _start_ready() -> void:
	phase = "ready"
	phase_t = 0.0


func _start_dance() -> void:
	phase = "dance"
	phase_t = 0.0
	raw_prev = []
	since_new = 0.0
	sum_e = 0.0
	e_now = 0.0
	hand_xy = [[[], []], [[], []]]
	mid_xy = [[], []]
	key_points = 0.0
	last_key = -1
	UI.sfx("pop")


func _end_dance() -> void:
	var crazy := 0.0
	if mode == "keys":
		crazy = clampf(key_points / KEY_FULL, 0.0, 1.0)
	else:
		var e := sum_e / DANCE_TIME   # time without a dancer in the picture counts as standing still
		var room := (_span(hand_xy[0][0]) * _span(hand_xy[0][1]) + _span(hand_xy[1][0]) * _span(hand_xy[1][1])) / 2.0
		var way := Vector2(_span(mid_xy[0]), _span(mid_xy[1])).length()
		crazy = clampf(e / E_FULL, 0.0, 1.0) * W_ENERGY + clampf(room / REACH_FULL, 0.0, 1.0) * W_REACH + clampf(way / TRAVEL_FULL, 0.0, 1.0) * W_TRAVEL
	crazy = pow(crazy, CURVE)
	last_score = snappedf(10.0 * crazy, 0.1)
	(scores[dancer()] as Array).append(last_score)
	phase = "show"
	phase_t = 0.0
	if sfx:
		sfx.play("cheer", lerpf(-16.0, -3.0, crazy))
	UI.sfx("success" if last_score >= 5.0 else "pop")


func total(pid: int) -> float:
	var sum := 0.0
	for v in scores[pid]:
		sum += float(v)
	return snappedf(sum, 0.1)


func _process(delta: float) -> void:
	t += delta
	phase_t += delta
	_update_mode(delta)
	var p := {}
	if mode == "cam":
		var front: Array = TM.front(Track.poses, 1)   # whoever is closest to the camera dances
		if not front.is_empty():
			p = front[0]
	_follow(p, delta)
	match phase:
		"ready":
			if mode != "wait" and phase_t >= READY_TIME:
				_start_dance()
			elif mode == "wait":
				phase_t = 0.0   # the countdown starts when it is clear how the dance is measured
		"dance":
			if mode == "cam":
				_measure(p, delta)
			meter = lerpf(meter, clampf(e_now / E_FULL, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
			e_now = maxf(0.0, e_now - e_now * delta * 3.0)
			if phase_t >= DANCE_TIME:
				_end_dance()
		"show":
			meter = lerpf(meter, 0.0, 1.0 - exp(-5.0 * delta))
			if phase_t >= SHOW_TIME:
				turn += 1
				if turn >= ROUNDS * 2:
					phase = "end"
					phase_t = 0.0
					if sfx:
						sfx.beat_off()
						sfx.play("cheer", -3.0)
					UI.sfx("fanfare")
				else:
					_start_ready()
		"end":
			if phase_t >= END_TIME:
				_finish()
	lean = lerpf(lean, 0.0, 1.0 - exp(-5.0 * delta))
	hop = maxf(0.0, hop - delta * 3.2)
	squat = maxf(0.0, squat - delta * 3.5)
	_place_avatar()
	canvas.queue_redraw()
	avatar.queue_redraw()


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
			if Track.alive and not chose_keys and phase == "ready":
				mode = "cam"   # the camera was only slow to start
		"cam":
			if not Track.alive and phase == "ready":
				mode = "keys"


## Smooths the points for drawing and keeps them for a moment when the dancer is lost.
func _follow(p: Dictionary, delta: float) -> void:
	if p.is_empty():
		seen_age += delta
		return
	var src: Array = p["pts"]
	if show_pts.size() != src.size() or seen_age > HOLD:
		show_pts = []
		for q in src:
			show_pts.append(Vector3(q[0], q[1], q[2]))
	else:
		var k := 1.0 - exp(-(delta + seen_age) / SMOOTH)
		for i in src.size():
			show_pts[i] = (show_pts[i] as Vector3).lerp(Vector3(src[i][0], src[i][1], src[i][2]), k)
	seen_age = 0.0


## Adds what happened since the last picture of the camera to the score of this dance.
func _measure(p: Dictionary, delta: float) -> void:
	since_new += delta
	if p.is_empty():
		return
	var pts: Array = p["pts"]
	if pts == raw_prev:
		return   # the camera is slower than the game: the same picture again
	var dt := since_new
	since_new = 0.0
	var a: float = Track.aspect
	var sw := Vector2((float(pts[11][0]) - float(pts[12][0])) * a, float(pts[11][1]) - float(pts[12][1])).length()
	if sw > 0.02:
		if raw_prev.size() == pts.size() and dt > 0.0 and dt < 0.5:
			var speeds: Array = []
			for j in JOINTS:
				if minf(pts[j][2], raw_prev[j][2]) < MIN_VIS:
					continue
				var d := Vector2((float(pts[j][0]) - float(raw_prev[j][0])) * a, float(pts[j][1]) - float(raw_prev[j][1])).length() / sw / dt
				speeds.append(minf(d, SPEED_CAP))
			if speeds.size() >= 2:
				speeds.sort()
				var sum := 0.0
				for i in mini(TOP, speeds.size()):
					sum += float(speeds[speeds.size() - 1 - i])   # the fastest ones
				e_now = sum / TOP
				sum_e += e_now * dt
		var mid := Vector2((float(pts[11][0]) + float(pts[12][0])) / 2.0 * a, (float(pts[11][1]) + float(pts[12][1])) / 2.0) / sw
		(mid_xy[0] as Array).append(mid.x)
		(mid_xy[1] as Array).append(mid.y)
		for h in 2:
			var j: int = 15 + h
			if float(pts[j][2]) >= MIN_VIS:
				var hand := Vector2(float(pts[j][0]) * a, float(pts[j][1])) / sw - mid
				(hand_xy[h][0] as Array).append(hand.x)
				(hand_xy[h][1] as Array).append(hand.y)
	raw_prev = pts


## How far the values reach, without the TRIM outermost at either end: a single picture in which
## the camera puts a hand in the wrong corner does not count as a big move.
func _span(values: Array) -> float:
	var n := values.size()
	if n < MIN_SAMPLES:
		return 0.0
	var v := values.duplicate()
	v.sort()
	return float(v[int((n - 1) * (1.0 - TRIM))]) - float(v[int((n - 1) * TRIM)])


func _key_move(dir: int) -> void:
	var fresh := dir != last_key
	key_points += 1.0 if fresh else KEY_SAME
	last_key = dir
	e_now = minf(E_FULL * 1.2, e_now + E_FULL * (0.4 if fresh else 0.15))
	match dir:
		0:
			hop = 1.0
		1:
			squat = 1.0
		2:
			lean = -0.5
		3:
			lean = 0.5
		_:
			face_i = (face_i + 1) % 4


func _finish() -> void:
	if sfx:
		sfx.beat_off()
	finished.emit([total(0), total(1)])
	queue_free()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	for pid in 2:
		var keys: Dictionary = KEYS.PLAYER_KEYS[pid]
		if k in (keys["abort"] as Array) and phase != "end":
			get_viewport().set_input_as_handled()
			if sfx:
				sfx.beat_off()
			finished.emit([])
			queue_free()
			return
		if phase == "end" and phase_t > 1.5 and k in (keys["interact"] as Array):
			get_viewport().set_input_as_handled()
			_finish()
			return
	if k == KEY_K and phase == "ready":
		get_viewport().set_input_as_handled()
		chose_keys = mode != "keys"
		mode = "keys" if chose_keys else "wait"
		wait_t = 0.0
		return
	if mode == "keys" and phase == "dance":
		var mine: Dictionary = KEYS.PLAYER_KEYS[dancer()]
		var names := ["up", "down", "left", "right", "interact"]
		for i in names.size():
			if k in (mine[names[i]] as Array):
				get_viewport().set_input_as_handled()
				_key_move(i)
				return


# ------------------------------------------------------------------ drawing
func _size() -> Vector2:
	return canvas.size


func _stage() -> Rect2:
	var s := _size()
	return Rect2(s.x * 0.05, s.y * 0.15, s.x * 0.58, s.y * 0.66)


## Where the camera picture lies on the stage: as big as it fits, in its own shape.
func _picture() -> Rect2:
	var st := _stage()
	var a: float = maxf(Track.aspect, 0.2)
	var size := Vector2(st.size.x, st.size.x / a)
	if size.y > st.size.y:
		size = Vector2(st.size.y * a, st.size.y)
	return Rect2(st.position + (st.size - size) / 2.0, size)


func _text(pos: Vector2, s: String, size: int, col: Color, centered: bool = false, outline: int = 6) -> void:
	var font := ThemeDB.fallback_font
	var p := pos
	if centered:
		p.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	if outline > 0:
		canvas.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, UI.DARK)
	canvas.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _verdict(v: float) -> String:
	if v >= 8.5:
		return "Völlig durchgedreht!"
	if v >= 6.5:
		return "Wild!"
	if v >= 4.0:
		return "Solide."
	if v >= 2.0:
		return "Etwas schüchtern."
	return "War das schon der Tanz?"


func _place_avatar() -> void:
	var st := _stage()
	var k := st.size.y / 120.0
	avatar.visible = mode != "cam"
	avatar.position = Vector2(st.get_center().x, st.end.y - st.size.y * 0.16 - hop * (2.0 - hop) * st.size.y * 0.16)
	avatar.rotation = lean
	avatar.scale = Vector2(k * (1.0 + squat * 0.18), k * (1.0 - squat * 0.3))


func _draw_avatar() -> void:
	var facings := [ART.FRONT, ART.LEFT, ART.BACK, ART.RIGHT]
	ART.draw_character(avatar, Game.player_looks[dancer()], facings[face_i], t * 9.0, phase == "dance")


func _draw_all() -> void:
	var s := _size()
	var beat := 60.0 / BPM
	var pump := pow(1.0 - fmod(t, beat) / beat, 2.0)
	var d := dancer() if phase != "end" else -1
	var dc := UI.YELLOW if d < 0 else Color(KEYS.TAG_COLORS[d])
	canvas.draw_rect(Rect2(Vector2.ZERO, s), Color("120b24"))
	var beams := ["ff5d8f", "4d8dff", "3ddc97", "ffc93c", "9b6bff"]
	for i in beams.size():
		var bx := s.x * (0.12 + 0.19 * i)
		var sway := sin(t * 0.8 + i * 1.4) * s.x * 0.1
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(bx - 8.0, 0), Vector2(bx + 8.0, 0), Vector2(bx + sway + s.x * 0.06, s.y), Vector2(bx + sway - s.x * 0.06, s.y)]),
			Color(Color(beams[i]), 0.05 + 0.06 * pump))
	_text(Vector2(s.x / 2.0, s.y * 0.09), UI.T("DANCE-BATTLE"), 44, UI.YELLOW, true, 10)
	if phase != "end":
		_text(Vector2(s.x / 2.0, s.y * 0.13), UI.T("Runde %d von %d") % [round_no() + 1, ROUNDS], 20, UI.MUTED, true, 4)
	# the stage: the camera picture with the dancer's skeleton, or the dance floor with the figure
	var st := _stage()
	canvas.draw_rect(st.grow(6.0), dc)
	canvas.draw_rect(st, Color("08060f"))
	if mode == "cam":
		var pic := _picture()
		if Track.preview.get_width() > 0:
			canvas.draw_texture_rect(Track.preview, pic, false)
		_draw_skeleton(pic, dc)
	else:
		# a lit dance floor
		var cols := 8
		var rows := 3
		var fl := Rect2(st.position.x, st.end.y - st.size.y * 0.3, st.size.x, st.size.y * 0.3)
		for r in rows:
			for cx in cols:
				var on := fmod(float(cx * 3 + r * 5) + floor(t / beat), 4.0) < 1.0
				canvas.draw_rect(Rect2(fl.position.x + fl.size.x * cx / cols + 2.0, fl.position.y + fl.size.y * r / rows + 2.0, fl.size.x / cols - 4.0, fl.size.y / rows - 4.0),
					Color(Color(beams[(cx + r) % beams.size()]), 0.75 if on else 0.18))
		canvas.draw_circle(Vector2(st.get_center().x, fl.position.y + fl.size.y * 0.45), st.size.y * 0.2, Color(1, 1, 1, 0.06 + 0.05 * pump))
		if mode == "wait":
			_text(st.get_center() + Vector2(0, -st.size.y * 0.3), UI.T("Kamera startet …"), 26, UI.WHITE, true)
	# how crazy it is right now, and how much time is left
	var bar := Rect2(st.position.x, st.end.y + 22.0, st.size.x, 22.0)
	canvas.draw_rect(bar.grow(3.0), UI.DARK)
	var n := 40
	for i in n:
		if (i + 0.5) / n > meter:
			break
		canvas.draw_rect(Rect2(bar.position.x + bar.size.x * i / n, bar.position.y, bar.size.x / n + 0.6, bar.size.y), UI.BLUE.lerp(UI.PINK, float(i) / n).lerp(UI.YELLOW, maxf(0.0, float(i) / n - 0.7) / 0.3))
	_text(Vector2(bar.position.x, bar.end.y + 24.0), UI.T("Verrücktheit"), 16, UI.MUTED, false, 0)
	if phase == "dance":
		var left := clampf(1.0 - phase_t / DANCE_TIME, 0.0, 1.0)
		canvas.draw_rect(Rect2(st.position.x, st.position.y - 14.0, st.size.x * left, 8.0), dc)
		_text(Vector2(st.end.x - 58.0, st.position.y + 50.0), "%.1f" % maxf(0.0, DANCE_TIME - phase_t), 40, UI.WHITE, true, 8)
		if phase_t < 0.7:
			_text(st.get_center() + Vector2(0, 30.0), UI.T("TANZ!"), 130, dc, true, 18)
	elif phase == "ready":
		var who: String = Game.name_of(dancer())
		_text(st.get_center() + Vector2(0, -st.size.y * 0.12), UI.T("%s ist dran!") % who, 56, dc, true, 12)
		if mode != "wait":
			_text(st.get_center() + Vector2(0, st.size.y * 0.16), str(int(ceil(maxf(0.0, READY_TIME - phase_t)))), 120, UI.WHITE, true, 16)
		var hint := UI.T("Allein vor die Kamera, einen Schritt zurück. Je verrückter, desto mehr Punkte!")
		if mode == "keys":
			hint = UI.T("Tanz auf den Tasten: %s und %s. Abwechseln zählt mehr als hämmern!") % [UI.T(String(KEYS.LABELS[dancer()]["dirs"])), KEYS.LABELS[dancer()]["ok"]]
		_text(Vector2(st.get_center().x, st.end.y - 18.0), hint, 18, UI.WHITE, true, 5)
	elif phase == "show":
		var pop := minf(1.0, phase_t / 0.2)
		_text(st.get_center() + Vector2(0, 30.0), "%.1f" % last_score, int(170 * (0.5 + 0.5 * pop)), dc, true, 20)
		_text(st.get_center() + Vector2(0, st.size.y * 0.3), UI.T(_verdict(last_score)), 34, UI.WHITE, true, 8)
	_draw_board()
	# how it is measured
	var line := ""
	match mode:
		"cam":
			line = UI.T("Kamera läuft. Es tanzt, wer der Kamera am nächsten ist.   K = mit Tasten tanzen")
		"keys":
			line = UI.T("Ohne Kamera: getanzt wird auf den Tasten.   K = Kamera versuchen")
		_:
			line = UI.T("Kamera startet …   K = gleich mit Tasten tanzen")
	_text(Vector2(s.x * 0.05, s.y - 18.0), line, 15, UI.MUTED, false, 0)
	_text(Vector2(s.x * 0.95 - 210.0, s.y - 18.0), "%s / %s · %s" % [KEYS.LABELS[0]["abort"], KEYS.LABELS[1]["abort"], UI.T("abbrechen")], 15, UI.MUTED, false, 0)
	if phase == "end":
		_draw_end()


func _draw_skeleton(pic: Rect2, col: Color) -> void:
	if show_pts.size() < 33 or seen_age > HOLD:
		if phase == "dance" or phase == "ready":
			_text(pic.get_center() + Vector2(0, pic.size.y * 0.38), UI.T("Niemand im Bild: einen Schritt zurück!"), 22, UI.YELLOW, true)
		return
	var fade := 1.0 - clampf(seen_age / HOLD, 0.0, 1.0) * 0.7
	for limb in TM.LIMBS:
		var a: Vector3 = show_pts[limb[0]]
		var b: Vector3 = show_pts[limb[1]]
		if minf(a.z, b.z) < 0.3:
			continue
		canvas.draw_line(pic.position + Vector2(a.x, a.y) * pic.size, pic.position + Vector2(b.x, b.y) * pic.size, Color(col, 0.9 * fade), 7.0)
	for j in [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]:
		var q: Vector3 = show_pts[j]
		if q.z >= 0.3:
			canvas.draw_circle(pic.position + Vector2(q.x, q.y) * pic.size, 14.0 if j == 0 else 7.0, Color(Color.WHITE if j != 0 else col, fade))


## The score sheet on the right: one row per round, the sums below.
func _draw_board() -> void:
	var s := _size()
	var r := Rect2(s.x * 0.67, s.y * 0.15, s.x * 0.28, s.y * 0.66)
	canvas.draw_rect(r, Color(0.03, 0.02, 0.08, 0.8))
	canvas.draw_rect(r, UI.YELLOW, false, 4.0)
	var cx := [r.position.x + r.size.x * 0.5, r.position.x + r.size.x * 0.82]
	for pid in 2:
		_text(Vector2(cx[pid], r.position.y + 44.0), Game.name_of(pid).left(9), 22, Color(KEYS.TAG_COLORS[pid]), true)
	var row_h := r.size.y * 0.15
	for i in ROUNDS:
		var y := r.position.y + 100.0 + i * row_h
		_text(Vector2(r.position.x + 18.0, y), UI.T("Runde %d") % (i + 1), 20, UI.MUTED, false, 0)
		for pid in 2:
			var sc: Array = scores[pid]
			var now: bool = phase != "end" and i == round_no() and pid == dancer() and phase != "show"
			if i < sc.size():
				_text(Vector2(cx[pid], y), "%.1f" % float(sc[i]), 28, UI.WHITE, true)
			else:
				_text(Vector2(cx[pid], y), "?" if now else "-", 28, UI.YELLOW if now else UI.MUTED, true)
	var ty := r.position.y + 100.0 + ROUNDS * row_h + 26.0
	canvas.draw_line(Vector2(r.position.x + 14.0, ty - 40.0), Vector2(r.end.x - 14.0, ty - 40.0), UI.MUTED, 2.0)
	_text(Vector2(r.position.x + 18.0, ty), UI.T("Total"), 22, UI.WHITE, false, 0)
	for pid in 2:
		_text(Vector2(cx[pid], ty + 6.0), "%.1f" % total(pid), 38, Color(KEYS.TAG_COLORS[pid]), true)


func _draw_end() -> void:
	var s := _size()
	canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.02, 0.08, 0.92))
	var a := total(0)
	var b := total(1)
	var win := -1 if is_equal_approx(a, b) else (0 if a > b else 1)
	var col := UI.YELLOW if win < 0 else Color(KEYS.TAG_COLORS[win])
	var head := UI.T("Unentschieden!") if win < 0 else UI.T("%s gewinnt das Dance-Battle!") % Game.name_of(win)
	_text(Vector2(s.x / 2.0, s.y * 0.36), head, 64, col, true, 14)
	for pid in 2:
		var cx := s.x * (0.36 if pid == 0 else 0.64)
		_text(Vector2(cx, s.y * 0.52), Game.name_of(pid), 30, Color(KEYS.TAG_COLORS[pid]), true)
		_text(Vector2(cx, s.y * 0.64), "%.1f" % total(pid), 80, UI.WHITE, true, 12)
	if phase_t > 1.5:
		_text(Vector2(s.x / 2.0, s.y * 0.84), UI.T("%s oder %s: weiter") % [KEYS.LABELS[0]["ok"], KEYS.LABELS[1]["ok"]], 20, UI.MUTED, true)
