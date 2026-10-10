extends CanvasLayer
## Level 3: the two minigames that are played in front of the webcam (autoload Track).
##   "tanz"   both players strike the dance pose that is shown, on the beat (body pose)
##   "badge"  one player pulls the badge out of the coat with two fingers and a steady hand
## Same contract as minigame.gd, so that main.gd treats it like any minigame: the signals
## `finished(success, mistakes)` and `mistake`, the counter `mistakes`, and it sits in main.minis
## while it is open (see _open_cam in level.gd).
## While it runs, the screen (or the player's half) is bright: in the story that is the spotlight,
## in a dark room it is the lamp without which the camera finds nobody.
## No camera, no tracker or no result for CAM_WAIT seconds: "tanz" goes on with the keys, "badge"
## emits `fallback` and the level opens the sequence minigame instead. The interact key does the
## same at any time.

signal finished(success: bool, mistakes: int)
signal mistake
signal fallback

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const TM = preload("res://scripts/track_math.gd")
const Posen = preload("res://scripts/level3/posen.gd")

# ---- tuning
const CAM_WAIT := 5.0            # seconds without a result from the camera until the keys take over
const CAM_PATIENCE := 3.0        # ... times this if the camera works but somebody is not in the picture
const LIGHT := Color(1.0, 0.98, 0.93, 0.95)   # the spotlight: how bright the screen gets
# tanz
const POSE_OK := 80.0            # percent a pose has to match (TM.pose_match)
const BEAT := 3.2                # seconds per pose
const BEAT_WINDOW := 1.2         # the last seconds of a beat, in which the pose has to sit
const DANCE_HITS := 4            # poses both have to hit to get across the floor
# badge
const PINCH_GRAB := 0.3          # fingers closer than this (TM.pinch01) hold the badge
const PINCH_DROP := 0.6          # fingers further apart than this let go of it
const PULL := 0.16               # how far the hand has to go up, in picture heights
const JITTER_MAX := 12.0         # a hand shakier than this (TM.Jitter) ...
const JITTER_TIME := 0.35        # ... for this long makes the coat rustle: mistake, start again
const HAND_LOST := 0.8           # seconds without a hand in the picture until the badge slips back

const INK := Color("23264a")
const SOFT := Color(0.14, 0.15, 0.29, 0.35)
const MUTED := Color(0.14, 0.15, 0.29, 0.62)
const DIR_NAMES := ["up", "down", "left", "right"]
const DIR_VECS := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]

var kind := ""
var pid := -1                    # the player ("badge"), -1 = both ("tanz")
var mistakes := 0
var keys: Dictionary = {}        # of P1, or of the one player
var keys2: Dictionary = {}       # of P2 ("tanz")
var labels: Dictionary = {}
var labels2: Dictionary = {}
var accent := Color("ffc93c")
var t := 0.0
var closing := -1.0
var state := "warm"              # warm (waiting for the camera), play, done
var no_cam := 0.0                # seconds without a result from the camera
var use_keys := false
var flash := 0.0
var flash_ok := true
var root: Control
var canvas: Control
var info: Label
# tanz
var poses: Array = []
var round_i := 0
var beat_t := 0.0
var hits := 0
var hit_now := false
var pressed: Array = [false, false]
var match_pc: Array = [0.0, 0.0]
# badge
var holding := false
var armed := true                # false after the coat rustled: open the fingers before grabbing again
var y0 := 0.0
var progress := 0.0
var shaky_t := 0.0
var shake := 0.0
var lost_t := 0.0
var jitter = null


func open(k: String) -> void:
	kind = k
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
	var title := UI.label("Im Takt über die Tanzfläche" if kind == "tanz" else "Badge aus der Innentasche ziehen", 30, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var ab: String = labels.get("abort", "Esc")
	if kind == "tanz":
		ab = "%s / %s" % [ab, labels2.get("abort", "Backspace")]
	head.add_child(UI.label("%s · abbrechen" % ab, 13, MUTED))
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(900, 520) if kind == "tanz" else Vector2(640, 380)
	canvas.draw.connect(_on_draw)
	v.add_child(canvas)
	info = UI.label("", 16, INK, 0, true)
	info.custom_minimum_size = Vector2(canvas.custom_minimum_size.x, 44)
	v.add_child(info)
	if kind == "tanz":
		poses = Posen.alle()
		Track.use(self, ["pose"])
	else:
		jitter = TM.Jitter.new()
		Track.use(self, ["hand"])
	_place()
	_update_info()
	UI.sfx("whoosh", -10.0)


## The whole screen for two, the player's half for one (like minigame.gd, _place_half).
func _place() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if pid < 0:
		var k0 := clampf(minf(vs.x / 980.0, vs.y / 700.0), 0.5, 1.2)
		scale = Vector2(k0, k0)
		offset = Vector2.ZERO
		root.position = Vector2.ZERO
		root.size = vs / k0
		return
	var half := vs.x / 2.0
	var k := clampf((half - 24.0) / 700.0, 0.5, 1.0)
	scale = Vector2(k, k)
	offset = Vector2(pid * half, 0.0)
	root.position = Vector2.ZERO
	root.size = Vector2(half, vs.y) / k


func _process(delta: float) -> void:
	t += delta
	_place()
	flash = maxf(0.0, flash - delta)
	if closing >= 0.0:
		closing -= delta
		if closing < 0.0:
			finished.emit(true, mistakes)
			queue_free()
			return
	elif kind == "tanz":
		_tanz(delta)
	else:
		_badge(delta)
	_update_info()
	canvas.queue_redraw()


func _has(d: Dictionary, what: String, k: int) -> bool:
	return k in (d.get(what, []) as Array)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if _has(keys, "abort", k) or _has(keys2, "abort", k):
		get_viewport().set_input_as_handled()
		finished.emit(false, mistakes)
		queue_free()
		return
	if closing >= 0.0:
		return
	if not use_keys and (_has(keys, "interact", k) or _has(keys2, "interact", k)):
		get_viewport().set_input_as_handled()
		_to_keys()
		return
	if kind == "tanz" and use_keys and state == "play" and beat_t <= BEAT_WINDOW:
		var want := round_i % 4
		for j in 2:
			var kk: Dictionary = keys if j == 0 else keys2
			for d in 4:
				if _has(kk, DIR_NAMES[d], k):
					pressed[j] = d == want
					get_viewport().set_input_as_handled()


## The camera is of no use right now: go on with the keys.
func _to_keys() -> void:
	if kind == "tanz":
		use_keys = true
		if state == "warm":
			state = "play"
			beat_t = BEAT + 1.0
	else:
		fallback.emit()
		queue_free()


func _miss() -> void:
	mistakes += 1
	flash = 0.5
	flash_ok = false
	UI.sfx("fail", -8.0)
	mistake.emit()


func _win() -> void:
	state = "done"
	closing = 1.2
	flash = 1.2
	flash_ok = true
	UI.sfx("grant", -6.0)


# ------------------------------------------------------------------ tanz
func _tanz(delta: float) -> void:
	var seen := false
	if not use_keys:
		var a := Track.pose(0)
		var b := Track.pose(1)
		seen = Track.alive and not a.is_empty() and not b.is_empty()
		no_cam = 0.0 if seen else no_cam + delta
		var target: Dictionary = poses[round_i % poses.size()]
		match_pc[0] = TM.pose_match(a, target, Track.aspect)
		match_pc[1] = TM.pose_match(b, target, Track.aspect)
		if no_cam > CAM_WAIT * (CAM_PATIENCE if Track.alive else 1.0):
			_to_keys()
	if state == "warm":
		if seen:
			state = "play"
			beat_t = BEAT + 1.0
		return
	beat_t -= delta
	if beat_t <= BEAT_WINDOW and not hit_now:
		var ok: bool = (pressed[0] and pressed[1]) if use_keys else (seen and minf(match_pc[0], match_pc[1]) >= POSE_OK)
		if ok:
			hit_now = true
			hits += 1
			flash = 0.4
			flash_ok = true
			UI.sfx("pop", -6.0)
			beat_t = minf(beat_t, 0.7)   # a short breath, then the next pose
			if hits >= DANCE_HITS:
				_win()
				return
	if beat_t <= 0.0:
		if not hit_now:
			_miss()   # one of the two was off: both stand out
		round_i += 1
		beat_t = BEAT
		hit_now = false
		pressed = [false, false]


# ------------------------------------------------------------------ badge
func _badge(delta: float) -> void:
	var h := Track.hand(pid)
	var seen := Track.alive and not h.is_empty()
	no_cam = 0.0 if seen else no_cam + delta
	if no_cam > CAM_WAIT * (CAM_PATIENCE if Track.alive else 1.0):
		_to_keys()
		return
	if state == "warm":
		if seen:
			state = "play"
		return
	if not seen:
		lost_t += delta
		if lost_t > HAND_LOST:
			holding = false
			progress = 0.0
		return
	lost_t = 0.0
	var p := TM.pinch01(h)
	var palm := Vector2(h["palm"][0], h["palm"][1])
	if not holding:
		shake = 0.0
		if p > PINCH_DROP:
			armed = true
		if armed and p < PINCH_GRAB:
			holding = true
			y0 = palm.y
			progress = 0.0
			shaky_t = 0.0
			jitter = TM.Jitter.new()
			UI.sfx("tick", -6.0)
		return
	if p > PINCH_DROP:
		holding = false     # let go: the badge slips back, nobody noticed
		progress = 0.0
		return
	progress = maxf(progress, clampf((y0 - palm.y) / PULL, 0.0, 1.0))
	shake = jitter.push(palm, delta)
	shaky_t = shaky_t + delta if shake > JITTER_MAX else 0.0
	if shaky_t > JITTER_TIME:
		holding = false
		armed = false
		progress = 0.0
		_miss()             # the coat rustles
	elif progress >= 1.0:
		_win()


# ------------------------------------------------------------------ texts
func _update_info() -> void:
	var s := ""
	if kind == "tanz":
		if state == "done":
			s = "Ihr tanzt, als hättet ihr nie etwas anderes gemacht."
		elif use_keys:
			s = "Ohne Kamera: Drückt beide die gezeigte Richtung, sobald der Balken grün ist (%s, %s)." % [labels.get("dirs", "WASD"), labels2.get("dirs", "Pfeiltasten")]
		elif state == "warm":
			if not Track.alive:
				s = "Kamera startet … Setzt euch so, dass beide im Bild sind: %s links, %s rechts. (%s oder %s: mit Tasten tanzen)" % [
					Game.name_of(0), Game.name_of(1), labels.get("ok", "E"), labels2.get("ok", "Enter")]
			else:
				var missing: String = Game.name_of(0) if Track.pose(0).is_empty() else Game.name_of(1)
				s = "%s ist nicht im Bild. %s sitzt links, %s rechts. (%s oder %s: mit Tasten tanzen)" % [
					missing, Game.name_of(0), Game.name_of(1), labels.get("ok", "E"), labels2.get("ok", "Enter")]
		else:
			s = "Macht die Pose nach, nur mit Armen und Oberkörper. Sie muss bei beiden sitzen, solange der Balken grün ist. Getroffen: %d von %d." % [hits, DANCE_HITS]
	else:
		if state == "done":
			s = "Der Badge ist draussen."
		elif state == "warm":
			if not Track.alive:
				s = "Kamera startet … (%s: mit Tasten)" % labels.get("ok", "E")
			else:
				s = "Halte eine Hand vor die Kamera, in deine Bildhälfte (%s). (%s: mit Tasten)" % ["links" if pid == 0 else "rechts", labels.get("ok", "E")]
		elif not holding:
			s = "Daumen und Zeigefinger zusammendrücken: So greifst du den Badge." if armed else "Der Mantel hat geraschelt! Finger kurz öffnen, dann nochmals greifen."
		else:
			s = "Zugedrückt lassen und die Hand langsam nach oben ziehen. Ruhige Hand, sonst raschelt der Mantel!"
	if mistakes > 0 and state != "done":
		s += "   Fehler: %d" % mistakes
	info.text = s


# ------------------------------------------------------------------ drawing
func _txt(pos: Vector2, s: String, size: int, col: Color, centered: bool = false) -> void:
	var font := ThemeDB.fallback_font
	if centered:
		pos.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	canvas.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar(r: Rect2, v: float, col: Color) -> void:
	canvas.draw_rect(r, Color(0.14, 0.15, 0.29, 0.14))
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), col)
	canvas.draw_rect(r, SOFT, false, 1.5)


## A pose as a stick figure with head and torso, fitted into `r` around the shoulders.
func _figure(pose: Dictionary, r: Rect2, col: Color, width: float) -> void:
	if pose.is_empty():
		return
	var pts: Array = pose["pts"]
	var asp: float = Track.aspect
	var ls := Vector2(pts[11][0] * asp, pts[11][1])
	var rs := Vector2(pts[12][0] * asp, pts[12][1])
	var mid := (ls + rs) / 2.0
	var sw := r.size.x * 0.24                          # shoulder width on screen
	var k := sw / maxf(ls.distance_to(rs), 0.01)
	var o := Vector2(r.get_center().x, r.position.y + r.size.y * 0.56)
	var at := func(i: int) -> Vector2: return o + (Vector2(pts[i][0] * asp, pts[i][1]) - mid) * k
	canvas.draw_colored_polygon(PackedVector2Array([o + Vector2(-sw / 2.0, 0), o + Vector2(sw / 2.0, 0),
		o + Vector2(sw * 0.4, r.size.y * 0.4), o + Vector2(-sw * 0.4, r.size.y * 0.4)]), Color(col, 0.3))
	canvas.draw_circle(o + Vector2(0, -sw * 0.62), sw * 0.36, Color(col, 0.55))
	for limb in [[11, 13], [13, 15], [12, 14], [14, 16]]:
		if minf(pts[limb[0]][2], pts[limb[1]][2]) < TM.POSE_MIN_VIS:
			continue
		var a: Vector2 = at.call(limb[0])
		var b: Vector2 = at.call(limb[1])
		canvas.draw_line(a, b, col, width)
		canvas.draw_circle(a, width * 0.62, col)
		canvas.draw_circle(b, width * 0.62, col)


func _arrow(c: Vector2, d: int, size: float, col: Color) -> void:
	var dv: Vector2 = DIR_VECS[d]
	var n := Vector2(-dv.y, dv.x)
	canvas.draw_colored_polygon(PackedVector2Array([c + dv * size, c - dv * size * 0.6 + n * size * 0.8, c - dv * size * 0.6 - n * size * 0.8]), col)


func _on_draw() -> void:
	if flash > 0.0:
		var fc := UI.GREEN if flash_ok else UI.RED
		canvas.draw_rect(Rect2(Vector2(-8, -8), canvas.size + Vector2(16, 16)), Color(fc, minf(1.0, flash * 2.0) * 0.8), false, 8.0)
	if kind == "tanz":
		_draw_tanz()
	else:
		_draw_badge()


func _draw_tanz() -> void:
	for i in DANCE_HITS:
		var c := Vector2(450.0 - (DANCE_HITS - 1) * 17.0 + i * 34.0, 14.0)
		canvas.draw_circle(c, 11.0, Color(0.14, 0.15, 0.29, 0.18))
		if i < hits:
			canvas.draw_circle(c, 8.0, UI.GREEN)
	# the pose to strike
	var box := Rect2(330, 36, 240, 250)
	canvas.draw_rect(box, Color(1, 1, 1, 0.7))
	canvas.draw_rect(box, INK, false, 3.0)
	var target: Dictionary = poses[round_i % poses.size()]
	if state != "warm":
		_figure(target, box, INK, 10.0)
		_txt(Vector2(450, 312), String(target.get("name", "Pose %d" % (round_i % poses.size() + 1))), 22, INK, true)
		var now := beat_t <= BEAT_WINDOW
		_bar(Rect2(330, 322, 240, 16), beat_t / BEAT, UI.GREEN if now else INK)
		if now and not hit_now:
			_txt(Vector2(450, 364), "JETZT!", 26, UI.GREEN.darkened(0.25), true)
		elif hit_now:
			_txt(Vector2(450, 364), "Sitzt!", 26, UI.GREEN.darkened(0.25), true)
	else:
		_txt(Vector2(450, 170), "Gleich geht's los", 22, MUTED, true)
	# the two dancers
	for j in 2:
		var col := Color(String(KEYS.TAG_COLORS[j]))
		var x := 40.0 if j == 0 else 610.0
		_txt(Vector2(x, 60), Game.name_of(j), 22, col.darkened(0.15))
		if use_keys:
			var done: bool = pressed[j] or hit_now
			_txt(Vector2(x, 112), "gedrückt" if done else "…", 34, UI.GREEN.darkened(0.25) if done else SOFT)
		else:
			var v: float = match_pc[j]
			_txt(Vector2(x, 112), "%d %%" % int(v), 44, UI.GREEN.darkened(0.25) if v >= POSE_OK else INK)
			_bar(Rect2(x, 126, 250, 16), v / 100.0, UI.GREEN if v >= POSE_OK else col)
			canvas.draw_line(Vector2(x + 250.0 * POSE_OK / 100.0, 122), Vector2(x + 250.0 * POSE_OK / 100.0, 146), INK, 2.0)
			var pose := Track.pose(j)
			if pose.is_empty():
				_txt(Vector2(x, 240), "nicht im Bild", 18, UI.RED)
			else:
				_figure(pose, Rect2(x + 20, 160, 210, 220), col, 8.0)
	# what the camera sees, or the direction to press
	if use_keys:
		if state != "warm":
			var pad := Rect2(405, 392, 90, 90)
			canvas.draw_rect(pad, Color(1, 1, 1, 0.8))
			canvas.draw_rect(pad, INK, false, 3.0)
			_arrow(pad.get_center(), round_i % 4, 25.0, INK)
	elif Track.preview.get_width() > 0:
		var pr := Rect2(360, 380, 180, 135)
		canvas.draw_texture_rect(Track.preview, pr, false)
		canvas.draw_rect(pr, INK, false, 2.0)
		canvas.draw_line(Vector2(pr.get_center().x, pr.position.y), Vector2(pr.get_center().x, pr.end.y), Color(1, 1, 1, 0.6), 1.0)


func _draw_badge() -> void:
	var loden := Color("2f6b45")
	var coat := Rect2(40, 20, 250, 330)
	var slit := 222.0                                  # where the inner pocket opens
	canvas.draw_rect(coat, loden)
	canvas.draw_line(coat.position + Vector2(40, 0), coat.position + Vector2(110, 150), loden.darkened(0.3), 4.0)   # lapel
	canvas.draw_circle(coat.position + Vector2(206, 60), 7.0, Color("d9b24c"))
	# the badge comes up out of the pocket
	var card := Rect2(128, slit - 12.0 - 104.0 * progress, 74, 104)
	canvas.draw_rect(card, Color("f4f1ea"))
	canvas.draw_rect(card, INK, false, 2.0)
	canvas.draw_rect(Rect2(card.position + Vector2(8, 10), Vector2(26, 30)), Color("c9c4ba"))
	canvas.draw_rect(Rect2(card.position + Vector2(40, 12), Vector2(26, 5)), UI.ETH_BLUE)
	canvas.draw_rect(Rect2(card.position + Vector2(40, 24), Vector2(22, 4)), SOFT)
	canvas.draw_rect(Rect2(card.position + Vector2(8, 52), Vector2(58, 6)), SOFT)
	_txt(card.position + Vector2(8, 82), "PROF", 13, INK)
	# front of the pocket hides the part that is still inside
	canvas.draw_rect(Rect2(coat.position.x, slit, coat.size.x, coat.end.y - slit), loden.lightened(0.06))
	canvas.draw_line(Vector2(80, slit), Vector2(250, slit), loden.darkened(0.4), 4.0)
	_bar(Rect2(40, 360, 250, 12), progress, UI.GREEN)
	# the hand: thumb and index finger as the camera sees them, moved into the picture of the coat
	var h := Track.hand(pid)
	if Track.alive and not h.is_empty():
		var pts: Array = h["pts"]
		var to := func(q: Array) -> Vector2: return coat.position + Vector2((float(q[0]) * 2.0 - pid) * coat.size.x, float(q[1]) * coat.size.y)
		var a: Vector2 = to.call(pts[4])
		var b: Vector2 = to.call(pts[8])
		var hc := UI.GREEN if holding else Color(1, 1, 1, 0.9)
		canvas.draw_line(a, b, hc, 3.0)
		canvas.draw_circle(a, 9.0, hc)
		canvas.draw_circle(b, 9.0, hc)
		canvas.draw_arc(a, 9.0, 0.0, TAU, 20, INK, 2.0)
		canvas.draw_arc(b, 9.0, 0.0, TAU, 20, INK, 2.0)
		if holding:
			canvas.draw_line((a + b) / 2.0, card.position + Vector2(card.size.x / 2.0, 0), Color("d9b24c"), 2.0)
	# what the camera sees: this player's half of the picture
	var pr := Rect2(390, 20, 190, 285)
	canvas.draw_rect(pr, Color(0.14, 0.15, 0.29, 0.12))
	var tex := Track.preview
	if tex.get_width() > 0:
		var half := Vector2(tex.get_width() / 2.0, tex.get_height())
		canvas.draw_texture_rect_region(tex, pr, Rect2(Vector2(pid * half.x, 0), half))
	canvas.draw_rect(pr, INK, false, 2.0)
	_txt(Vector2(390, 332), "Ruhige Hand", 15, INK)
	_bar(Rect2(390, 342, 190, 12), shake / JITTER_MAX, UI.RED if shake > JITTER_MAX else Color(String(KEYS.TAG_COLORS[pid])))
