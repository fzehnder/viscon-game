extends CanvasLayer
## Level 3: the two minigames that are played in front of the webcam (autoload Track).
##   "tanz"   strike the dance pose that is shown, on the beat (body pose). Two people in the
##            picture: both have to hit it. One person in the picture: that one dances for both.
##   "badge"  one player pulls the badge out of the coat with two fingers and a steady hand
## Same contract as minigame.gd, so that main.gd treats it like any minigame: the signals
## `finished(success, mistakes)` and `mistake`, the counter `mistakes`, and it sits in main.minis
## while it is open (see _open_cam in level.gd).
## While it runs, the screen (or the player's half) is bright: in the story that is the spotlight,
## in a dark room it is the lamp without which the camera finds nobody.
## No camera, no tracker or nobody in the picture for CAM_WAIT seconds: "tanz" goes on with the
## keys, "badge" emits `fallback` and the level opens the sequence minigame instead. The interact
## key does the same at any time.
##
## The camera of a laptop is close: sitting at the keyboard only head and shoulders are in the
## picture. So the dance starts with "hands up": whoever can strike that has moved back far
## enough for the arms to be seen, and all poses keep the arms up.

signal finished(success: bool, mistakes: int)
signal mistake
signal fallback

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const TM = preload("res://scripts/track_math.gd")
const Posen = preload("res://scripts/level3/posen.gd")

# ---- tuning
const CAM_WAIT := 5.0            # seconds without a result from the camera until the keys take over
const CAM_PATIENCE := 3.0        # ... times this if the camera works but nobody is in the picture
const LIGHT := Color(1.0, 0.98, 0.93, 0.95)   # the spotlight: how bright the screen gets
# tanz
const POSE_OK := 50.0            # percent the arms have to match the pose (see _arms). Measured in front of a
                                 # laptop camera: a pose struck well gives 50 to 65, another pose under 40
const READY_OK := 42.0           # percent for the "hands up" that starts the dance
const ARM_TOLERANCE := 70.0      # degrees an upper arm or forearm may be off before it scores 0
const READY_HOLD := 0.5          # seconds the hands have to stay up
const PAIR_ON := 1.0             # seconds two people have to be in the picture before both have to dance (a passer-by does not count)
const PAIR_MEMORY := 6.0         # seconds a second dancer who left the picture is still expected back (costs a beat), then the other one dances for both
const BEAT := 3.4                # seconds per pose
const BEAT_WINDOW := 1.4         # the last seconds of a beat, in which the pose has to sit
const DANCE_HITS := 4            # poses that have to be hit to get across the floor
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
const BOTH := Color("d99a00")    # one dancer for both players
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
var state := "warm"              # warm (waiting for the camera), ready ("hands up"), play, done
var no_cam := 0.0                # seconds without a result from the camera
var use_keys := false
var flash := 0.0
var flash_ok := true
var root: Control
var canvas: Control
var info: Label
# tanz
var poses: Array = []
var ready_pose: Dictionary = {}
var round_i := 0
var beat_t := 0.0
var hits := 0
var hit_now := false
var pressed: Array = [false, false]
var match_pc: Array = [0.0, 0.0]
var dancers: Array = [{}, {}]    # the poses of P1 and P2 this frame ({} = not in the picture)
var solo := true                 # one person dances for both (false: two dancers, both have to hit)
var pair_level := 0.0            # 0..1: rises while two people are in the picture, falls while there are fewer
var ready_t := 0.0
# badge
var holding := false
var armed := true                # false after the coat rustled: open the fingers before grabbing again
var hand: Dictionary = {}        # the hand that is playing ({} = none in the picture)
var palm := Vector2.ZERO
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
	canvas.custom_minimum_size = Vector2(900, 500) if kind == "tanz" else Vector2(640, 380)
	canvas.draw.connect(_on_draw)
	v.add_child(canvas)
	info = UI.label("", 17, INK, 0, true)
	info.custom_minimum_size = Vector2(canvas.custom_minimum_size.x, 48)
	v.add_child(info)
	if kind == "tanz":
		poses = Posen.alle()
		ready_pose = Posen.bereit()
		round_i = Posen.erste()
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
		var k0 := clampf(minf(vs.x / 980.0, vs.y / 690.0), 0.5, 1.2)
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
		if state != "play":
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
## Who is dancing. Two people who stay in the picture are P1 (left) and P2 (right), wherever
## exactly they sit, and both have to hit the pose. Otherwise the person closest to the middle
## dances for both: sitting at a laptop the second player is often half out of the picture, and
## somebody walking past must not stop the dance.
func _find_dancers(delta: float) -> int:
	var list: Array = Track.poses if Track.alive else []
	var n := list.size()
	if n >= 2:
		pair_level = minf(1.0, pair_level + delta / PAIR_ON)
	else:
		pair_level = maxf(0.0, pair_level - delta / PAIR_MEMORY)
	if pair_level >= 1.0:
		solo = false
	elif pair_level <= 0.0:
		solo = true
	if n == 0:
		dancers = [{}, {}]
	elif not solo:
		dancers = TM.pair(list)
	else:
		var mid: Dictionary = list[0]
		for e in list:
			if absf(e["x"] - 0.5) < absf(mid["x"] - 0.5):
				mid = e
		dancers = [mid, mid]
	return mini(n, 2)


## How well somebody's arms match the target pose, 0..100. Per arm: upper arm and forearm are
## compared by direction (so distance and body size do not matter); half the score of an arm is
## the average of the two, half is the worse one. The worse arm counts. So one arm in the wrong
## place cannot be made up for by the other one, and the shoulders, which always match, do not
## help. Arms that are not in the picture score 0.
func _arms(pose: Dictionary, target: Dictionary) -> float:
	if pose.is_empty() or target.is_empty():
		return 0.0
	var a: Array = pose["pts"]
	var b: Array = target["pts"]
	var asp: float = Track.aspect
	var worst := 1.0
	for arm in [[11, 13, 15], [12, 14, 16]]:
		var sum := 0.0
		var low := 1.0
		for k in 2:
			var i: int = arm[k]
			var j: int = arm[k + 1]
			var sc := 0.0
			if minf(a[i][2], a[j][2]) >= TM.POSE_MIN_VIS:
				var da := Vector2((a[j][0] - a[i][0]) * asp, a[j][1] - a[i][1])
				var db := Vector2((b[j][0] - b[i][0]) * asp, b[j][1] - b[i][1])
				sc = clampf(1.0 - absf(rad_to_deg(da.angle_to(db))) / ARM_TOLERANCE, 0.0, 1.0)
			sum += sc
			low = minf(low, sc)
		worst = minf(worst, (sum / 2.0 + low) / 2.0)
	return worst * 100.0


func _tanz(delta: float) -> void:
	var n := 0
	if not use_keys:
		n = _find_dancers(delta)
		no_cam = 0.0 if n > 0 else no_cam + delta
		var target: Dictionary = poses[round_i % poses.size()] if state == "play" else ready_pose
		for j in 2:
			match_pc[j] = _arms(dancers[j], target)
		if no_cam > CAM_WAIT * (CAM_PATIENCE if Track.alive else 1.0):
			_to_keys()
	var both: float = minf(match_pc[0], match_pc[1])
	if state == "warm":
		if n > 0:
			state = "ready"
		return
	if state == "ready":
		# hands up: that starts the dance, and it shows that the arms are in the picture
		# (the camera loses people for a frame now and then: that must not start the count again)
		ready_t = ready_t + delta if (n > 0 and both >= READY_OK) else maxf(0.0, ready_t - 2.0 * delta)
		if ready_t >= READY_HOLD:
			state = "play"
			beat_t = BEAT + 0.6
			flash = 0.4
			flash_ok = true
			UI.sfx("pop", -6.0)
		return
	beat_t -= delta
	if beat_t <= BEAT_WINDOW and not hit_now:
		var ok: bool = (pressed[0] and pressed[1]) if use_keys else (n > 0 and both >= POSE_OK)
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
## The hand that plays. Any hand in the picture will do (only one player steals at a time): the
## one that is pinching hardest, and once it holds the badge, the one closest to where it was.
func _find_hand() -> void:
	hand = {}
	if not Track.alive:
		return
	var best := INF
	for h in Track.hands:
		var p := Vector2(h["palm"][0], h["palm"][1])
		var score: float = p.distance_to(palm) if holding else float(h["pinch"])
		if score < best:
			best = score
			hand = h
	if not hand.is_empty():
		palm = Vector2(hand["palm"][0], hand["palm"][1])


func _badge(delta: float) -> void:
	_find_hand()
	var seen := not hand.is_empty()
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
	var p := TM.pinch01(hand)
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
	var with_keys := "   (%s oder %s: mit Tasten tanzen)" % [labels.get("ok", "E"), labels2.get("ok", "Enter")]
	if kind == "tanz":
		if state == "done":
			s = "Ihr tanzt, als hättet ihr nie etwas anderes gemacht."
		elif use_keys:
			s = "Ohne Kamera: Drückt beide die gezeigte Richtung, sobald der Balken grün ist (%s, %s)." % [labels.get("dirs", "WASD"), labels2.get("dirs", "Pfeiltasten")]
		elif state == "warm":
			s = ("Niemand im Bild. Rückt vom Bildschirm weg, bis Kopf, Schultern und erhobene Arme zu sehen sind." if Track.alive else "Kamera startet …") + with_keys
		elif state == "ready":
			if solo:
				s = "Wer in der Mitte sitzt, tanzt für beide. Rück so weit zurück, dass deine erhobenen Hände im Bild sind. Dann: Hände hoch! Sind zwei ganz im Bild, tanzen beide." + with_keys
			else:
				s = "Zwei im Bild: Ihr tanzt beide. Rückt so weit zurück, dass eure erhobenen Hände im Bild sind. Dann beide: Hände hoch!" + with_keys
		else:
			s = "Macht die Pose nach, solange der Balken grün ist. Getroffen: %d von %d." % [hits, DANCE_HITS]
			if not solo:
				for j in 2:
					if (dancers[j] as Dictionary).is_empty():
						s += "   %s ist nicht im Bild!" % Game.name_of(j)
	else:
		if state == "done":
			s = "Der Badge ist draussen."
		elif state == "warm":
			if not Track.alive:
				s = "Kamera startet … (%s: mit Tasten)" % labels.get("ok", "E")
			else:
				s = "Halte eine Hand vor die Kamera. (%s: mit Tasten)" % labels.get("ok", "E")
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


## The biggest rectangle with the shape of the camera picture inside `r`.
func _fit(r: Rect2) -> Rect2:
	var asp: float = Track.aspect
	var size := Vector2(r.size.x, r.size.x / asp)
	if size.y > r.size.y:
		size = Vector2(r.size.y * asp, r.size.y)
	return Rect2(r.position + (r.size - size) / 2.0, size)


## A pose as a stick figure with head and torso, fitted into `r` around the shoulders.
func _figure(pose: Dictionary, r: Rect2, col: Color, width: float) -> void:
	if pose.is_empty():
		return
	var pts: Array = pose["pts"]
	var asp: float = Track.aspect
	var ls := Vector2(pts[11][0] * asp, pts[11][1])
	var rs := Vector2(pts[12][0] * asp, pts[12][1])
	var mid := (ls + rs) / 2.0
	var sw := r.size.x * 0.22                          # shoulder width on screen
	var k := sw / maxf(ls.distance_to(rs), 0.01)
	var o := Vector2(r.get_center().x, r.position.y + r.size.y * 0.66)
	var at := func(i: int) -> Vector2: return o + (Vector2(pts[i][0] * asp, pts[i][1]) - mid) * k
	canvas.draw_colored_polygon(PackedVector2Array([o + Vector2(-sw / 2.0, 0), o + Vector2(sw / 2.0, 0),
		o + Vector2(sw * 0.4, r.size.y * 0.3), o + Vector2(-sw * 0.4, r.size.y * 0.3)]), Color(col, 0.3))
	canvas.draw_circle(o + Vector2(0, -sw * 0.62), sw * 0.36, Color(col, 0.55))
	for limb in [[11, 13], [13, 15], [12, 14], [14, 16]]:
		if minf(pts[limb[0]][2], pts[limb[1]][2]) < TM.POSE_MIN_VIS:
			continue
		var a: Vector2 = at.call(limb[0])
		var b: Vector2 = at.call(limb[1])
		canvas.draw_line(a, b, col, width)
		canvas.draw_circle(a, width * 0.62, col)
		canvas.draw_circle(b, width * 0.62, col)


## What the camera recognises of somebody, drawn onto the camera picture in `view`.
func _skeleton(pose: Dictionary, view: Rect2, col: Color) -> void:
	var pts: Array = pose["pts"]
	for limb in [[11, 13], [13, 15], [12, 14], [14, 16], [11, 12]]:
		var a: Array = pts[limb[0]]
		var b: Array = pts[limb[1]]
		if minf(a[2], b[2]) < TM.POSE_MIN_VIS:
			continue
		var pa := view.position + Vector2(a[0], a[1]) * view.size
		var pb := view.position + Vector2(b[0], b[1]) * view.size
		canvas.draw_line(pa, pb, Color(1, 1, 1, 0.9), 7.0)
		canvas.draw_line(pa, pb, col, 4.0)
	for i in [11, 12, 13, 14, 15, 16]:
		if pts[i][2] >= TM.POSE_MIN_VIS:
			canvas.draw_circle(view.position + Vector2(pts[i][0], pts[i][1]) * view.size, 5.0, col)


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
	var playing := state == "play" or state == "done"
	var limit := POSE_OK if playing else READY_OK
	# left: the camera picture as a mirror with what is recognised, or the direction to press
	var pic := Rect2(10, 10, 500, 375)
	canvas.draw_rect(pic, Color(0.14, 0.15, 0.29, 0.1))
	if use_keys:
		var pad := Rect2(pic.get_center() - Vector2(70, 70), Vector2(140, 140))
		canvas.draw_rect(pad, Color(1, 1, 1, 0.85))
		canvas.draw_rect(pad, INK, false, 4.0)
		_arrow(pad.get_center(), round_i % 4, 40.0, INK)
		_txt(Vector2(pic.get_center().x, pic.position.y + 60), "Diese Richtung, wenn der Balken grün ist", 18, MUTED, true)
	else:
		var view := _fit(pic)
		if Track.preview.get_width() > 0:
			canvas.draw_texture_rect(Track.preview, view, false)
		else:
			_txt(pic.get_center(), "Kamera startet …" if not Track.alive else "kein Bild", 20, MUTED, true)
		var drawn: Array = []
		for j in 2:
			var pose: Dictionary = dancers[j]
			if pose.is_empty() or drawn.has(pose):
				continue
			drawn.append(pose)
			_skeleton(pose, view, BOTH if solo else Color(String(KEYS.TAG_COLORS[j])))
	canvas.draw_rect(pic, INK, false, 3.0)
	# under it: how well each of the two matches
	for j in 2:
		var col := Color(String(KEYS.TAG_COLORS[j]))
		var x := 10.0 + j * 256.0
		var v: float = match_pc[j]
		var there: bool = not (dancers[j] as Dictionary).is_empty()
		_txt(Vector2(x, 414), Game.name_of(j), 18, col.darkened(0.15))
		if use_keys:
			var done: bool = pressed[j] or hit_now
			_txt(Vector2(x, 446), "gedrückt" if done else "…", 24, UI.GREEN.darkened(0.25) if done else SOFT)
		elif not there:
			_txt(Vector2(x, 446), "nicht im Bild", 20, UI.RED if state != "warm" else MUTED)
		else:
			_bar(Rect2(x, 426, 244, 18), v / 100.0, UI.GREEN if v >= limit else col)
			canvas.draw_line(Vector2(x + 244.0 * limit / 100.0, 421), Vector2(x + 244.0 * limit / 100.0, 449), INK, 2.0)
			_txt(Vector2(x, 474), ("%d %%" % int(v)) + ("   (tanzt für beide)" if solo else ""), 18, UI.GREEN.darkened(0.25) if v >= limit else INK)
	# right: the pose to strike, and the beat
	var box := Rect2(570, 10, 320, 300)
	canvas.draw_rect(box, Color(1, 1, 1, 0.7))
	canvas.draw_rect(box, INK, false, 3.0)
	if state == "warm":
		_txt(Vector2(box.get_center().x, box.get_center().y), "Gleich geht's los", 22, MUTED, true)
	elif not playing:
		_figure(ready_pose, box, INK, 11.0)
		_txt(Vector2(box.get_center().x, 342), "Zum Start: Hände hoch!", 24, INK, true)
		_bar(Rect2(570, 356, 320, 18), ready_t / READY_HOLD, UI.GREEN)
	else:
		var target: Dictionary = poses[round_i % poses.size()]
		_figure(target, box, INK, 11.0)
		_txt(Vector2(box.get_center().x, 342), String(target.get("name", "Pose %d" % (round_i % poses.size() + 1))), 24, INK, true)
		var now := beat_t <= BEAT_WINDOW
		_bar(Rect2(570, 356, 320, 18), beat_t / BEAT, UI.GREEN if now else INK)
		if hit_now:
			_txt(Vector2(box.get_center().x, 408), "Sitzt!", 28, UI.GREEN.darkened(0.25), true)
		elif now:
			_txt(Vector2(box.get_center().x, 408), "JETZT!", 28, UI.GREEN.darkened(0.25), true)
	for i in DANCE_HITS:
		var c := Vector2(box.get_center().x - (DANCE_HITS - 1) * 19.0 + i * 38.0, 452.0)
		canvas.draw_circle(c, 13.0, Color(0.14, 0.15, 0.29, 0.18))
		if i < hits:
			canvas.draw_circle(c, 10.0, UI.GREEN)


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
	if not hand.is_empty():
		var pts: Array = hand["pts"]
		var to := func(q: Array) -> Vector2: return coat.position + Vector2(float(q[0]), float(q[1])) * coat.size
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
	# what the camera sees
	var mine := Color(String(KEYS.TAG_COLORS[pid])) if pid >= 0 else INK
	var pr := Rect2(330, 20, 290, 218)
	canvas.draw_rect(pr, Color(0.14, 0.15, 0.29, 0.12))
	var view := _fit(pr)
	if Track.preview.get_width() > 0:
		canvas.draw_texture_rect(Track.preview, view, false)
		if not hand.is_empty():
			var hp: Array = hand["pts"]
			for i in [4, 8]:
				canvas.draw_circle(view.position + Vector2(hp[i][0], hp[i][1]) * view.size, 5.0, UI.GREEN if holding else mine)
	canvas.draw_rect(pr, INK, false, 2.0)
	_txt(Vector2(330, 270), "Ruhige Hand", 15, INK)
	_bar(Rect2(330, 280, 290, 12), shake / JITTER_MAX, UI.RED if shake > JITTER_MAX else mine)
