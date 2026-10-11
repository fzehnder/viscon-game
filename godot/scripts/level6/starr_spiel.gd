extends CanvasLayer
## Level 6: the staring contest («Starrwettbewerb»), the one camera minigame of this level.
## Both players sit in front of the webcam, P1 on the left and P2 on the right (autoload Track).
## Whoever blinks first loses the round, best of three.
##   - Countdown "3, 2, 1, Augen auf", then BLINK_GRACE_S in which nothing counts.
##   - After that every camera picture with the eyes shut counts as a blink at once, without a
##     minimum length (a real blink only lasts 100 to 150 ms).
##   - Both blink in the same picture: a draw, the round is played again.
##   - No face in the picture only counts after FACE_LOST_S. Losing the face for a moment never
##     decides a round.
##   - After ROUND_MAX_S both get the round.
## Without a camera (Track.alive still false after CAM_WAIT_S) the keys take over: both hold
## their interact key, whoever lets go has blinked. Same rules. So the level can be played through
## without a webcam.
## The whole screen is bright while this is open. That is not decoration: the room of the demo is
## dark, and without light MediaPipe finds no face.
## Same contract as minigame.gd, so that main.gd treats it like any minigame: the signals
## `finished(success, mistakes)` and `mistake`, the counter `mistakes`. What came out of it is in
## `winner` and `loser` (-1 = a draw). Nobody can fail: the level goes on in any case.

signal finished(success: bool, mistakes: int)
signal mistake

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const TM = preload("res://scripts/track_math.gd")

# ---- tuning
const BLINK_GRACE_S := 0.5       # seconds after the countdown (eyes open) in which nothing counts
const FACE_LOST_S := 1.5         # seconds without a face until that counts as losing the round
const ROUND_MAX_S := 15.0        # seconds after which both get the round
const CAM_WAIT_S := 5.0          # seconds without a picture from the camera until the keys take over
const CAM_PATIENCE := 3.0        # ... times this if the camera works but not both faces are in the picture
const WINS := 2                  # rounds somebody has to win: best of three
const COUNT_STEP := 0.8          # seconds per number of the countdown
const READY_HOLD := 0.6          # seconds both have to be in the picture (or hold their key) before the countdown
const RESULT_TIME := 2.4         # seconds the result of a round stays on the screen
const END_TIME := 2.6            # seconds the result of the duel stays on the screen
const MAX_DRAWS := 3             # this many draws in a row and both get the round: nobody is stuck in here
const LIGHT := Color(1.0, 0.98, 0.93)   # the lamp: the whole screen, nothing shines through

const INK := Color("23264a")
const MUTED := Color(0.14, 0.15, 0.29, 0.62)
const SOFT := Color(0.14, 0.15, 0.29, 0.14)
const W := 940.0                 # size of the drawing
const H := 470.0
const VIEW := Rect2(170.0, 10.0, 600.0, 450.0)   # where the camera picture goes

var keys: Dictionary = {}        # of P1
var keys2: Dictionary = {}       # of P2
var labels: Dictionary = {}
var labels2: Dictionary = {}
var mistakes := 0
var winner := -1                 # who won the duel, -1 = a draw
var loser := -1
var t := 0.0
var phase := "cam"               # cam (waiting for the camera), ready, count, grace, stare, result, end
var use_keys := false
var keys_chosen := false         # somebody asked for the keys: the camera does not take over again
var no_cam := 0.0                # seconds without a picture from the camera
var no_pair := 0.0               # seconds with a picture, but without both faces
var ready_t := 0.0
var count_t := 0.0
var grace_t := 0.0
var stare_t := 0.0
var result_t := 0.0
var closing := -1.0
var round_n := 1
var draws := 0                   # draws in a row in this round
var score: Array = [0, 0]
var lost: Array = [0.0, 0.0]     # seconds each face has been gone
var there: Array = [false, false]   # in the picture (or holding the key) right now
var shut: Array = [0.0, 0.0]     # how far each player's eyes are shut, 0..1, for the display
var out: Array = [false, false]  # who went out in the round that just ended
var result := ""                 # what happened, as a sentence under the picture
var result_head := ""            # ... and as a word across it
var last_count := 0
var root: Control
var canvas: Control
var info: Label


func open() -> void:
	layer = 20
	root = Control.new()
	add_child(root)
	var light := ColorRect.new()
	light.color = LIGHT
	root.add_child(light)
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	cc.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UI.label("Starrwettbewerb", 30, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.label("%s / %s · abbrechen" % [labels.get("abort", "Esc"), labels2.get("abort", "Backspace")], 13, MUTED))
	v.add_child(UI.label("Wer zuerst blinzelt, verliert die Runde. Wer zuerst zwei Runden hat, bekommt den Fensterplatz.", 16, INK))
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(W, H)
	canvas.draw.connect(_on_draw)
	v.add_child(canvas)
	info = UI.label("", 17, INK, 0, true)
	info.custom_minimum_size = Vector2(W, 52)   # two lines: the layout does not jump when the text changes
	info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(info)
	Track.use(self, ["face"])
	_place()
	_update_info()
	UI.sfx("whoosh", -10.0)


## The whole screen, scaled so that the drawing fits.
func _place() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var k := clampf(minf(vs.x / 1000.0, vs.y / 690.0), 0.5, 1.3)
	scale = Vector2(k, k)
	offset = Vector2.ZERO
	root.position = Vector2.ZERO
	root.size = vs / k


func _name(pid: int) -> String:
	return Game.name_of(pid)


func _key_name(pid: int) -> String:
	return String((labels if pid == 0 else labels2).get("ok", "E" if pid == 0 else "Enter"))


func _holds(pid: int) -> bool:
	return Input.is_action_pressed(KEYS.action(pid, "interact"))


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	t += delta
	_place()
	if closing >= 0.0:
		closing -= delta
		if closing < 0.0:
			finished.emit(true, mistakes)
			queue_free()
			return
	else:
		_sense(delta)
		_step(delta)
	_update_info()
	canvas.queue_redraw()


## What the camera (or the keys) say about both players right now.
func _sense(delta: float) -> void:
	if not use_keys:
		if Track.alive:
			no_cam = 0.0
		else:
			no_cam += delta
	elif not keys_chosen and Track.alive and phase == "ready":
		use_keys = false   # the camera has come after all
		no_cam = 0.0
		no_pair = 0.0
	for pid in 2:
		if use_keys:
			there[pid] = _holds(pid)
			shut[pid] = 0.0 if there[pid] else 1.0
			lost[pid] = 0.0
			continue
		var f: Dictionary = Track.face(pid)   # P1 sits on the left, P2 on the right
		there[pid] = not f.is_empty()
		if there[pid]:
			lost[pid] = 0.0
			shut[pid] = clampf(minf(float(f.get("blink_l", 0.0)), float(f.get("blink_r", 0.0))), 0.0, 1.0)
		else:
			lost[pid] += delta
	# no camera, no tracker, no permission: go on with the keys (between rounds, never in one)
	if not use_keys and phase in ["cam", "ready"]:
		if no_cam >= CAM_WAIT_S or String(Track.status).begins_with("kein"):
			_to_keys(false)
		elif Track.alive and not (there[0] and there[1]):
			no_pair += delta
			if no_pair >= CAM_WAIT_S * CAM_PATIENCE:
				_to_keys(false)
		else:
			no_pair = 0.0


func _to_keys(chosen: bool) -> void:
	use_keys = true
	keys_chosen = keys_chosen or chosen
	ready_t = 0.0
	if phase == "cam":
		phase = "ready"


## Has this player blinked (or let go of the key) in this picture?
func _blinked(pid: int) -> bool:
	if use_keys:
		return not _holds(pid)
	return TM.eyes_closed(Track.face(pid))


func _step(delta: float) -> void:
	match phase:
		"cam":
			if Track.alive:
				phase = "ready"
				ready_t = 0.0
		"ready":
			if there[0] and there[1]:
				ready_t += delta
				if ready_t >= READY_HOLD:
					phase = "count"
					count_t = 3.0 * COUNT_STEP
					last_count = 0
			else:
				ready_t = 0.0
		"count":
			if use_keys and not (there[0] and there[1]):
				phase = "ready"   # somebody let go before it started: that is not a blink yet
				ready_t = 0.0
				return
			count_t -= delta
			var n := int(ceil(count_t / COUNT_STEP))
			if n != last_count and n > 0:
				last_count = n
				UI.sfx("tick", -6.0)
			if count_t <= 0.0:
				phase = "grace"
				grace_t = BLINK_GRACE_S
				UI.sfx("pop", -4.0)
		"grace":
			grace_t -= delta
			if grace_t <= 0.0:
				phase = "stare"
				stare_t = 0.0
				lost = [0.0, 0.0]
		"stare":
			stare_t += delta
			var o0: bool = _blinked(0) or lost[0] >= FACE_LOST_S
			var o1: bool = _blinked(1) or lost[1] >= FACE_LOST_S
			if o0 or o1:
				_round_over(o0, o1)
			elif stare_t >= ROUND_MAX_S:
				_round_over(false, false)
		"result":
			result_t -= delta
			if result_t <= 0.0:
				_next()


## `o0`, `o1`: who went out. Both = a draw, the round is played again. Nobody = the time is up.
func _round_over(o0: bool, o1: bool) -> void:
	out = [o0, o1]
	phase = "result"
	result_t = RESULT_TIME
	if o0 and o1:
		draws += 1
		result_head = "Unentschieden"
		if draws < MAX_DRAWS:
			result = "Beide im selben Moment: unentschieden. Die Runde wird wiederholt."
			UI.sfx("click", -4.0)
			return
		result = "Schon wieder beide gleichzeitig. Die Runde geht an beide."
		score[0] += 1
		score[1] += 1
	elif not o0 and not o1:
		result_head = "Zeit um"
		result = "Zeit um, keiner hat nachgegeben. Die Runde geht an beide."
		score[0] += 1
		score[1] += 1
	else:
		var bad := 0 if o0 else 1
		score[1 - bad] += 1
		if use_keys:
			result_head = "%s lässt los!" % _name(bad)
			result = "%s hat losgelassen. Runde %d geht an %s." % [_name(bad), round_n, _name(1 - bad)]
		elif lost[bad] >= FACE_LOST_S:
			result_head = "%s ist weg!" % _name(bad)
			result = "%s war nicht mehr im Bild. Runde %d geht an %s." % [_name(bad), round_n, _name(1 - bad)]
		else:
			result_head = "%s blinzelt!" % _name(bad)
			result = "%s hat geblinzelt. Runde %d geht an %s." % [_name(bad), round_n, _name(1 - bad)]
	draws = 0
	round_n += 1
	UI.sfx("stamp", -4.0)


func _next() -> void:
	if score[0] >= WINS or score[1] >= WINS:
		phase = "end"
		closing = END_TIME
		out = [false, false]
		if score[0] == score[1]:
			winner = -1
			loser = -1
			result_head = "Unentschieden"
			result = "Unentschieden, %d : %d. Keiner gibt nach, also gehört der Fensterplatz, wer zuerst sitzt." % [score[0], score[1]]
		else:
			winner = 0 if score[0] > score[1] else 1
			loser = 1 - winner
			result_head = "%s gewinnt" % _name(winner)
			result = "%s gewinnt das Duell %d : %d und bekommt den Fensterplatz." % [_name(winner), score[winner], score[loser]]
		UI.sfx("grant", -6.0)
		return
	phase = "ready"
	ready_t = 0.0
	no_pair = 0.0


func _update_info() -> void:
	var s := ""
	match phase:
		"cam":
			s = "Kamera startet … Setzt euch nebeneinander davor: %s links, %s rechts. Ohne Kamera geht es mit den Tasten (%s / %s)." % [_name(0), _name(1), _key_name(0), _key_name(1)]
		"ready":
			if use_keys:
				s = "Ohne Kamera: Beide halten ihre Taste gedrückt, %s die Taste %s und %s die Taste %s. Wer loslässt, hat geblinzelt." % [_name(0), _key_name(0), _name(1), _key_name(1)]
			else:
				s = "Beide ins Bild: %s links, %s rechts. Sobald die Kamera beide Gesichter hat, geht es los. Mit Tasten spielen: %s oder %s drücken." % [_name(0), _name(1), _key_name(0), _key_name(1)]
		"count":
			s = "Gleich gilt es. Augen auf!" if not use_keys else "Gleich gilt es. Taste halten!"
		"grace", "stare":
			s = "Nicht blinzeln! Wer zuerst blinzelt, verliert die Runde." if not use_keys else "Taste halten! Wer zuerst loslässt, verliert die Runde."
		"result", "end":
			s = result
	if info.text != s:
		info.text = s


func _has(d: Dictionary, what: String, k: int) -> bool:
	return k in (d.get(what, []) as Array)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if closing >= 0.0:
		return   # the duel is decided: it cannot be left any more
	if _has(keys, "abort", k) or _has(keys2, "abort", k):
		get_viewport().set_input_as_handled()
		finished.emit(false, mistakes)
		queue_free()
		return
	if _has(keys, "interact", k) or _has(keys2, "interact", k):
		get_viewport().set_input_as_handled()
		if not use_keys and phase in ["cam", "ready"]:
			_to_keys(true)   # whoever presses the key wants to play with the keys


# ------------------------------------------------------------------ drawing
func _text(at: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, width := 0.0) -> void:
	var font := ThemeDB.fallback_font
	var s := tr(text)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	canvas.draw_string(font, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, width if width > 0.0 else -1.0, size, col)


## One eye, `r` wide, shut by `lid` (0 = wide open, 1 = shut).
func _eye(c: Vector2, r: float, lid: float, col: Color) -> void:
	var open := clampf(1.0 - lid, 0.0, 1.0)
	if open < 0.12:
		canvas.draw_arc(c + Vector2(0, -r * 0.2), r, 0.25, PI - 0.25, 20, INK, maxf(3.0, r * 0.12))
		return
	canvas.draw_set_transform(c, 0.0, Vector2(1.0, 0.62 * open))
	canvas.draw_circle(Vector2.ZERO, r, Color.WHITE)
	canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, INK, maxf(3.0, r * 0.1) / maxf(0.3, open))
	canvas.draw_set_transform(c, 0.0, Vector2.ONE)
	var pr := minf(r * 0.42, r * 0.6 * open)
	canvas.draw_circle(Vector2.ZERO, pr, col)
	canvas.draw_circle(Vector2.ZERO, pr * 0.5, INK)
	canvas.draw_circle(Vector2(-pr * 0.3, -pr * 0.3), pr * 0.18, Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Name, rounds won and the eyes of one player, around `c`.
func _player(pid: int, c: Vector2, eye_r: float) -> void:
	var col := Color(String(KEYS.TAG_COLORS[pid]))
	_text(c + Vector2(0, -eye_r * 2.2 - 34.0), _name(pid), 22, col.darkened(0.25))
	for i in WINS:
		var pc := c + Vector2((i - (WINS - 1) / 2.0) * 30.0, -eye_r * 2.2 - 8.0)
		canvas.draw_circle(pc, 10.0, SOFT)
		if i < int(score[pid]):
			canvas.draw_circle(pc, 8.0, col)
		canvas.draw_arc(pc, 10.0, 0.0, TAU, 24, INK, 1.5)
	var went_out: bool = phase in ["result", "end"] and bool(out[pid])
	var lid: float = 1.0 if went_out else float(shut[pid])
	_eye(c + Vector2(-eye_r * 1.25, 0), eye_r, lid, col)
	_eye(c + Vector2(eye_r * 1.25, 0), eye_r, lid, col)
	var note := ""
	var note_col := MUTED
	if use_keys:
		note = "%s halten" % _key_name(pid)
		if phase in ["ready", "count"] and not there[pid]:
			note_col = UI.RED.darkened(0.15)
	elif not there[pid]:
		note = "nicht im Bild"
		note_col = UI.RED.darkened(0.15)
	else:
		note = "im Bild"
		note_col = UI.OK
	_text(c + Vector2(0, eye_r * 1.6 + 26.0), note, 16, note_col)


func _on_draw() -> void:
	if use_keys:
		# no camera: the two stare at each other across the middle
		_player(0, Vector2(W * 0.27, H * 0.52), 44.0)
		_player(1, Vector2(W * 0.73, H * 0.52), 44.0)
		canvas.draw_line(Vector2(W / 2.0, 60.0), Vector2(W / 2.0, H - 40.0), SOFT, 3.0)
	else:
		_player(0, Vector2(82.0, H * 0.5), 24.0)
		_player(1, Vector2(W - 82.0, H * 0.5), 24.0)
		_camera()
	var mid := Vector2(W / 2.0, H / 2.0)
	match phase:
		"count":
			_banner(mid, str(maxi(1, int(ceil(count_t / COUNT_STEP)))), 150)
		"grace":
			_banner(mid, "Augen auf!" if not use_keys else "Halten!", 76)
		"stare":
			# how much of the round is left
			var k := clampf(1.0 - stare_t / ROUND_MAX_S, 0.0, 1.0)
			canvas.draw_rect(Rect2(VIEW.position.x, H - 8.0, VIEW.size.x, 6.0), SOFT)
			canvas.draw_rect(Rect2(VIEW.position.x, H - 8.0, VIEW.size.x * k, 6.0), INK)
		"result", "end":
			_banner(mid, result_head, 54)


## A word across the middle, on a strip so that it reads on the camera picture too.
func _banner(c: Vector2, text: String, size: int) -> void:
	var font := ThemeDB.fallback_font
	var s := tr(text)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r := Rect2(c.x - w / 2.0 - 26.0, c.y - size * 0.62, w + 52.0, size * 1.1)
	canvas.draw_rect(r, Color(1.0, 0.98, 0.93, 0.92))
	canvas.draw_rect(r, INK, false, 3.0)
	canvas.draw_string(font, Vector2(c.x - w / 2.0, c.y + size * 0.3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)


## The mirrored camera picture in its own shape, the line between the two halves and a frame
## around each player's face.
func _camera() -> void:
	var r := VIEW
	var a: float = maxf(0.5, float(Track.aspect))
	if a > r.size.x / r.size.y:
		var h2 := r.size.x / a
		r = Rect2(r.position.x, r.position.y + (r.size.y - h2) / 2.0, r.size.x, h2)
	else:
		var w2 := r.size.y * a
		r = Rect2(r.position.x + (r.size.x - w2) / 2.0, r.position.y, w2, r.size.y)
	canvas.draw_rect(r, Color(0.14, 0.15, 0.29, 0.1))
	if Track.alive and Track.preview != null and Track.preview.get_width() > 0:
		canvas.draw_texture_rect(Track.preview, r, false)
	else:
		_text(r.get_center() + Vector2(0, 6), "Kamera startet …", 22, MUTED)
	canvas.draw_rect(r, INK, false, 3.0)
	canvas.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(1, 1, 1, 0.7), 2.0)
	for pid in 2:
		var f: Dictionary = Track.face(pid)
		if f.is_empty() or not f.has("box"):
			continue
		var b: Array = f["box"]
		var col := Color(String(KEYS.TAG_COLORS[pid]))
		var fr := Rect2(r.position + Vector2(float(b[0]), float(b[1])) * r.size, Vector2(float(b[2]), float(b[3])) * r.size)
		canvas.draw_rect(fr, col, false, 3.0)
