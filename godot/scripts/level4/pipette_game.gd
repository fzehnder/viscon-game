extends CanvasLayer
## Level 4, challenge 1: pipetting for two, with the camera (autoload Track, see tracker/README.md).
## One player works the pipette: thumb and index finger pressed together just the right amount.
## A bar runs from red over green to red, the pointer has to stand in the green part.
## The other one holds the glass: a flat hand held level into the camera, without shaking.
## The liquid only runs while both are right at the same time. When the glass is full, it is done.
##
## Player 1 sits on the left of the camera picture, player 2 on the right (Track.hand(pid)).
## Without a camera or tracker the same game is played with keys (the team's rule for every camera
## minigame): the pipette player holds and lets go of the interact key, the glass player steers the
## bubble of the spirit level with left and right. K switches by hand.
##
##   var mg = PipetteGame.new();  mg.pipetter = pid;  main.add_child(mg);  mg.open()
## Emits finished(success). Esc or Backspace leaves it.

signal finished(success: bool)

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const TM = preload("res://scripts/track_math.gd")

# ---- tuning. The camera values are starting points: check them with res://track_debug.tscn
const PINCH_TARGET := 0.45     # TM.pinch01 the pipette wants: 0 = fingers together, 1 = spread wide
const PINCH_OK := 0.13         # this far off is still green
const LEVEL_TOL := 18.0        # degrees the hand may tilt
const SHAKE_LIMIT := 5.0       # TM.Jitter of the palm; a calm hand measures about 1 to 2
const HOLD_TIME := 3.0         # seconds both have to be right, in total
const DRAIN := 0.35            # the glass loses this share of the fill speed while somebody is off
const SPILL_AT := 2.2          # shaking this many times over the limit spills
const STICKY := 1.15           # once in the green, the limits are this much wider (no flicker at the edge)
const CAM_WAIT := 6.0          # seconds to wait for the camera before the keys take over
const SMOOTH := 12.0           # smoothing of the camera values
const GOAL_ML := 10.0
# keys variant
const KEY_SQUEEZE := 0.95      # pinch per second while the key is held
const KEY_RELAX := 0.6         # ... and back when it is let go
const KEY_TILT := 46.0         # degrees per second with left / right
const KEY_DRIFT := 15.0        # how hard the hand drifts by itself, degrees per second

const SIDE_W := 250.0
const CAM_SIZE := Vector2(380, 285)
const LIQUID := Color("4d8dff")
const BONES := [[0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [5, 6], [6, 7], [7, 8], [5, 9], [9, 10], [10, 11], [11, 12],
	[9, 13], [13, 14], [14, 15], [15, 16], [13, 17], [17, 18], [18, 19], [19, 20], [0, 17]]

var pipetter := 0              # pid with the pipette; the other one holds the glass
var sfx = null                 # lab_sfx.gd node of the level, for the drops
var mode := "wait"             # wait (for the camera), cam, keys
var wait_t := 0.0
var lost_t := 0.0
var t := 0.0
var closing := -1.0
var fill := 0.0                # 0..1
var seen: Array = [false, false]   # per player: hand in the picture
var ok: Array = [false, false]     # per player: in the green
var pinch := 1.0               # 0 = pressed together, 1 = open
var tilt := 0.0                # degrees, + = the right side hangs down
var shake := 0.0
var jitter := TM.Jitter.new()
var spill_t := 0.0
var drip_t := 0.0
var drops: Array = []          # [position in the camera panel, age]

var root: Control
var panel: PanelContainer
var title_l: Label
var info_l: Label
var cam_c: Control
var fill_c: Control
var gauges: Array = [null, null]
var how_l: Array = [null, null]
var state_l: Array = [null, null]


func holder() -> int:
	return 1 - pipetter


func open() -> void:
	layer = 20
	Track.use(self, ["hand"])   # the camera goes off again when this node leaves the tree
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.12, 0.5)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.NAVY, UI.YELLOW, 24, 5, 18))
	cc.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	title_l = UI.label("Pipettieren zu zweit: %.1f mL" % GOAL_ML, 30, UI.YELLOW, 7)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)
	head.add_child(UI.label("%s / %s · abbrechen" % [KEYS.LABELS[0]["abort"], KEYS.LABELS[1]["abort"]], 13, UI.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	row.add_child(_side(0))
	cam_c = Control.new()
	cam_c.custom_minimum_size = CAM_SIZE
	cam_c.clip_contents = true
	cam_c.draw.connect(_draw_cam)
	row.add_child(cam_c)
	row.add_child(_side(1))
	fill_c = Control.new()
	fill_c.custom_minimum_size = Vector2(0, 62)
	fill_c.draw.connect(_draw_fill)
	body.add_child(fill_c)
	info_l = UI.label("", 14, UI.MUTED, 0, true)
	info_l.custom_minimum_size = Vector2(SIDE_W * 2.0 + CAM_SIZE.x + 36.0, 38)
	body.add_child(info_l)
	if Track.alive:
		mode = "cam"
	_set_texts()
	UI.pop_in(panel, 0.0, 0.6)
	UI.sfx("whoosh", -10.0)


## Column of one player: role, name, what to do, the gauge and how it is going.
func _side(pid: int) -> VBoxContainer:
	var pc := Color(KEYS.TAG_COLORS[pid])
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(SIDE_W, 0)
	v.add_theme_constant_override("separation", 6)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = pc
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", sb)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_child(UI.label("PIPETTE" if pid == pipetter else "GLAS HALTEN", 15, UI.WHITE))
	v.add_child(pill)
	v.add_child(UI.label(Game.name_of(pid), 22, pc, 5))
	var how := UI.label("", 15, UI.WHITE, 0, true)
	how.custom_minimum_size = Vector2(SIDE_W, 88)
	v.add_child(how)
	how_l[pid] = how
	var g := Control.new()
	g.custom_minimum_size = Vector2(SIDE_W, 104)
	g.draw.connect(_draw_gauge.bind(pid))
	v.add_child(g)
	gauges[pid] = g
	var st := UI.label("", 17, UI.MUTED, 4)
	v.add_child(st)
	state_l[pid] = st
	return v


func _set_texts() -> void:
	var p := pipetter
	var h := holder()
	if mode == "keys":
		how_l[p].text = "%s gedrückt halten drückt die Pipette zusammen, loslassen lässt sie auf. Halte den Zeiger im grünen Bereich." % KEYS.LABELS[p]["ok"]
		how_l[h].text = "Die Hand kippt von selbst. Steuere die Blase mit %s zurück in die Mitte." % ("A und D" if h == 0 else "Pfeil links und rechts")
		var why := "Tasten-Variante gewählt." if Track.alive else "Keine Kamera, deshalb mit Tasten. Tracker: %s." % Track.status
		info_l.text = "%s Beide gleichzeitig im grünen Bereich halten, bis das Glas voll ist.   K = Kamera versuchen" % why
	else:
		how_l[p].text = "Drück Daumen und Zeigefinger vor der Kamera zusammen wie an einer Pipette. Nicht zu fest, nicht zu locker: Der Zeiger muss im grünen Bereich stehen."
		how_l[h].text = "Halte die Hand flach und waagrecht in die Kamera, als stünde das Glas darauf. Nicht zittern!"
		if mode == "cam":
			info_l.text = "Kamera läuft: %s sitzt links im Bild, %s rechts. Beide gleichzeitig im grünen Bereich halten, bis das Glas voll ist.   K = mit Tasten spielen" % [Game.name_of(0), Game.name_of(1)]
		else:
			info_l.text = "Kamera startet … %s sitzt links im Bild, %s rechts.   K = gleich mit Tasten spielen" % [Game.name_of(0), Game.name_of(1)]


func _set_mode(m: String) -> void:
	if mode == m:
		return
	mode = m
	wait_t = 0.0
	lost_t = 0.0
	if m == "keys":
		pinch = 1.0
		tilt = 0.0
		shake = 1.0
	_set_texts()


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	t += delta
	if closing >= 0.0:
		closing -= delta
		if closing < 0.0:
			finished.emit(true)
			queue_free()
			return
	else:
		_update_mode(delta)
		match mode:
			"cam":
				_read_camera(delta)
			"keys":
				_read_keys(delta)
			_:
				seen = [false, false]
		_judge()
		_update_fill(delta)
	for d in drops:
		d[0] += Vector2(0, 170.0) * delta
		d[1] += delta
	drops = drops.filter(func(d): return d[1] < 0.45)
	spill_t = maxf(0.0, spill_t - delta)
	_show_state()
	cam_c.queue_redraw()
	fill_c.queue_redraw()
	for g in gauges:
		g.queue_redraw()


## Camera as soon as the tracker delivers, keys when it does not come or went away.
func _update_mode(delta: float) -> void:
	match mode:
		"wait":
			if Track.alive:
				_set_mode("cam")
			else:
				wait_t += delta
				if wait_t >= CAM_WAIT or Track.status.begins_with("kein"):
					_set_mode("keys")
		"cam":
			lost_t = 0.0 if Track.alive else lost_t + delta
			if lost_t > 2.5:
				_set_mode("keys")


func _read_camera(delta: float) -> void:
	var k := 1.0 - exp(-SMOOTH * delta)
	var hp := Track.hand(pipetter)
	var hh := Track.hand(holder())
	seen[pipetter] = not hp.is_empty()
	seen[holder()] = not hh.is_empty()
	if not hp.is_empty():
		pinch = lerpf(pinch, TM.pinch01(hp), k)
	if not hh.is_empty():
		tilt = lerpf(tilt, hand_tilt(hh), k)
		shake = lerpf(shake, jitter.push(Vector2(hh["palm"][0], hh["palm"][1]), delta), k)


## How far the hand is from level, in degrees: 0 = wrist and knuckles side by side,
## + = the right side hangs down, 90 = fingers straight up or down.
func hand_tilt(hand: Dictionary) -> float:
	var pts: Array = hand["pts"]
	var v := Vector2((float(pts[9][0]) - float(pts[0][0])) * Track.aspect, float(pts[9][1]) - float(pts[0][1]))
	var deg := rad_to_deg(v.angle())
	if deg > 90.0:
		deg -= 180.0
	elif deg < -90.0:
		deg += 180.0
	return deg


func _read_keys(delta: float) -> void:
	seen = [true, true]
	var squeeze := Input.is_action_pressed(KEYS.action(pipetter, "interact"))
	pinch = clampf(pinch + (-KEY_SQUEEZE if squeeze else KEY_RELAX) * delta, 0.0, 1.0)
	var h := holder()
	var steer := Input.get_axis(KEYS.action(h, "left"), KEYS.action(h, "right"))
	var drift := KEY_DRIFT * (sin(t * 0.9 + 1.3) + 0.6 * sin(t * 2.3))
	tilt = clampf(tilt + (drift - steer * KEY_TILT) * delta, -45.0, 45.0)   # right key: bubble to the right
	shake = 1.0


func _judge() -> void:
	var p := pipetter
	var h := holder()
	var mp := STICKY if ok[p] else 1.0
	ok[p] = seen[p] and absf(pinch - PINCH_TARGET) <= PINCH_OK * mp
	var mh := STICKY if ok[h] else 1.0
	ok[h] = seen[h] and absf(tilt) <= LEVEL_TOL * mh and shake <= SHAKE_LIMIT * mh


func _update_fill(delta: float) -> void:
	if ok[0] and ok[1]:
		fill += delta / HOLD_TIME
		drip_t -= delta
		if drip_t <= 0.0:
			drip_t = 0.16
			drops.append([_pipette_tip(), 0.0])
			if sfx:
				sfx.play("drip", -12.0, 0.9 + fill * 0.5)
	else:
		var loss := DRAIN
		if seen[holder()] and shake > SHAKE_LIMIT * SPILL_AT and fill > 0.0:
			loss = 2.0   # shaken out of the glass
			if spill_t <= 0.0:
				UI.shake(panel, 5.0)
			spill_t = 0.5
		fill -= delta * loss / HOLD_TIME
	fill = clampf(fill, 0.0, 1.0)
	if fill >= 1.0:
		closing = 1.1
		title_l.text = "%.1f mL, sauber pipettiert!" % GOAL_ML
		title_l.label_settings.font_color = UI.GREEN
		panel.add_theme_stylebox_override("panel", UI.box(UI.NAVY, UI.GREEN, 24, 5, 18))
		UI.sfx("grant", -6.0)


func _show_state() -> void:
	var p := pipetter
	var h := holder()
	var texts: Array = ["", ""]
	if mode == "wait":
		texts = ["Kamera startet …", "Kamera startet …"]
	else:
		if not seen[p]:
			texts[p] = "Hand ins Bild halten"
		elif ok[p]:
			texts[p] = "Genau richtig!"
		else:
			texts[p] = "Zu fest gedrückt" if pinch < PINCH_TARGET else "Zu locker"
		if not seen[h]:
			texts[h] = "Hand ins Bild halten"
		elif ok[h]:
			texts[h] = "Ruhig und waagrecht!"
		elif absf(tilt) > LEVEL_TOL:
			texts[h] = "Schief! Waagrecht halten"
		else:
			texts[h] = "Zittert! Ruhig halten"
	for pid in 2:
		var l: Label = state_l[pid]
		l.text = texts[pid]
		l.label_settings.font_color = UI.GREEN if ok[pid] else (UI.MUTED if (mode == "wait" or not seen[pid]) else UI.ORANGE)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k in (KEYS.PLAYER_KEYS[0]["abort"] as Array) or k in (KEYS.PLAYER_KEYS[1]["abort"] as Array):
		get_viewport().set_input_as_handled()
		if closing < 0.0:
			finished.emit(false)
			queue_free()
	elif k == KEY_K and closing < 0.0:
		get_viewport().set_input_as_handled()
		_set_mode("wait" if mode == "keys" else "keys")


# ------------------------------------------------------------------ drawing
## Red far from the target, yellow close to it, green on it. `k` = distance in units of "still fine".
func _zone_col(k: float) -> Color:
	if k <= 1.0:
		return UI.GREEN
	if k <= 1.9:
		return UI.GREEN.lerp(UI.YELLOW, (k - 1.0) / 0.9)
	return UI.YELLOW.lerp(UI.RED, clampf((k - 1.9) / 1.3, 0.0, 1.0))


func _text(c: Control, pos: Vector2, s: String, size: int, col: Color) -> void:
	c.draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _needle(c: Control, x: float, top: float, bottom: float) -> void:
	c.draw_rect(Rect2(x - 3.0, top, 6.0, bottom - top), UI.DARK)
	c.draw_rect(Rect2(x - 1.5, top + 1.0, 3.0, bottom - top - 2.0), UI.WHITE)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - 7, top - 7), Vector2(x + 7, top - 7), Vector2(x, top + 2)]), UI.WHITE)


func _draw_gauge(pid: int) -> void:
	var c: Control = gauges[pid]
	var w := SIDE_W
	var live: bool = mode != "wait" and seen[pid]
	if pid == pipetter:
		# the bar from red over green to red: how hard the pipette is pressed
		_text(c, Vector2(0, 14), "Druck auf die Pipette", 13, UI.MUTED)
		var bar := Rect2(0, 30, w, 28)
		var n := 50
		for i in n:
			var v := (i + 0.5) / n
			c.draw_rect(Rect2(bar.position.x + bar.size.x * i / n, bar.position.y, bar.size.x / n + 0.6, bar.size.y),
				_zone_col(absf(v - PINCH_TARGET) / PINCH_OK))
		c.draw_rect(bar, UI.DARK, false, 2.0)
		if live:
			_needle(c, clampf(pinch, 0.0, 1.0) * w, bar.position.y - 3.0, bar.end.y + 4.0)
		_text(c, Vector2(0, 78), "fest", 12, UI.MUTED)
		_text(c, Vector2(w - 40.0, 78), "locker", 12, UI.MUTED)
		return
	# the glass holder: spirit level on top, shaking below
	_text(c, Vector2(0, 14), "Wasserwaage", 13, UI.MUTED)
	var tube := Rect2(0, 22, w, 26)
	c.draw_rect(tube, UI.DARK)
	c.draw_rect(tube.grow(-2.0), Color("c9e8b5"))
	var half := LEVEL_TOL / 45.0 * (w / 2.0 - 12.0) + 11.0
	c.draw_rect(Rect2(w / 2.0 - half, tube.position.y + 2.0, half * 2.0, tube.size.y - 4.0), Color(UI.GREEN, 0.55))
	c.draw_line(Vector2(w / 2.0 - half, tube.position.y), Vector2(w / 2.0 - half, tube.end.y), UI.DARK, 2.0)
	c.draw_line(Vector2(w / 2.0 + half, tube.position.y), Vector2(w / 2.0 + half, tube.end.y), UI.DARK, 2.0)
	if live:
		var bx := w / 2.0 - clampf(tilt / 45.0, -1.0, 1.0) * (w / 2.0 - 12.0)   # the bubble climbs to the high side
		var level: bool = absf(tilt) <= LEVEL_TOL
		c.draw_circle(Vector2(bx, tube.get_center().y), 10.0, UI.DARK)
		c.draw_circle(Vector2(bx, tube.get_center().y), 8.0, UI.WHITE if level else UI.RED)
		c.draw_circle(Vector2(bx - 2.5, tube.get_center().y - 2.5), 2.2, Color(1, 1, 1, 0.8))
	_text(c, Vector2(0, 66), "Zittern", 13, UI.MUTED)
	var sb := Rect2(0, 82, w, 14)
	var m := 40
	for i in m:
		var v2 := (i + 0.5) / m * 2.0   # in units of the limit: the limit is in the middle
		var col := UI.GREEN
		if v2 > 0.75:
			col = UI.GREEN.lerp(UI.YELLOW, clampf((v2 - 0.75) / 0.25, 0.0, 1.0)) if v2 <= 1.0 else UI.YELLOW.lerp(UI.RED, clampf((v2 - 1.0) / 0.5, 0.0, 1.0))
		c.draw_rect(Rect2(sb.position.x + sb.size.x * i / m, sb.position.y, sb.size.x / m + 0.6, sb.size.y), col)
	c.draw_rect(sb, UI.DARK, false, 2.0)
	if live:
		_needle(c, clampf(shake / (SHAKE_LIMIT * 2.0), 0.0, 1.0) * w, sb.position.y - 2.0, sb.end.y + 3.0)


## Where the drops leave the pipette, in the camera panel.
func _pipette_tip() -> Vector2:
	if mode == "cam":
		var h := Track.hand(pipetter)
		if not h.is_empty():
			var pts: Array = h["pts"]
			return Vector2((float(pts[4][0]) + float(pts[8][0])) / 2.0, (float(pts[4][1]) + float(pts[8][1])) / 2.0) * CAM_SIZE + Vector2(0, 46)
	return Vector2(CAM_SIZE.x * (0.25 + 0.5 * pipetter), CAM_SIZE.y * 0.42 + 50.0)


## A pipette at `at`: the bulb between the fingers (flatter the harder it is pressed), the tube below.
func _draw_pipette(at: Vector2, gap: float, good: bool) -> void:
	var col := UI.GREEN if good else UI.ORANGE
	cam_c.draw_rect(Rect2(at.x - 3.0, at.y, 6.0, 40.0), Color(0.86, 0.95, 1.0, 0.9))
	cam_c.draw_rect(Rect2(at.x - 1.6, at.y + 14.0, 3.2, 26.0), LIQUID)
	cam_c.draw_line(Vector2(at.x, at.y + 40.0), Vector2(at.x, at.y + 46.0), Color(0.86, 0.95, 1.0, 0.9), 2.0)
	cam_c.draw_set_transform(at, 0.0, Vector2(clampf(gap / 26.0, 0.35, 1.3), 1.0))
	cam_c.draw_circle(Vector2.ZERO, 13.0, UI.DARK)
	cam_c.draw_circle(Vector2.ZERO, 11.0, col)
	cam_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The glass standing on the hand at `at`, tilted with it, sloshing when the hand shakes.
func _draw_glass(at: Vector2, deg: float, good: bool) -> void:
	var slosh := sin(t * 31.0) * clampf(shake / SHAKE_LIMIT - 0.6, 0.0, 2.0) * 3.0
	cam_c.draw_set_transform(at + Vector2(slosh, 0), deg_to_rad(deg), Vector2.ONE)
	var g := Rect2(-17.0, -52.0, 34.0, 44.0)
	cam_c.draw_rect(g, Color(0.86, 0.95, 1.0, 0.55))
	var lh := (g.size.y - 3.0) * fill
	if lh > 0.5:
		cam_c.draw_rect(Rect2(g.position.x + 2.0, g.end.y - 1.5 - lh, g.size.x - 4.0, lh), LIQUID)
	cam_c.draw_rect(g, UI.GREEN if good else UI.ORANGE, false, 2.5)
	cam_c.draw_line(Vector2(g.position.x - 3.0, g.position.y + 5.0), Vector2(g.end.x + 3.0, g.position.y + 5.0), UI.RED, 1.2)   # the 10 mL mark
	cam_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cam() -> void:
	var size := CAM_SIZE
	cam_c.draw_rect(Rect2(Vector2.ZERO, size), UI.DARK)
	var picture: bool = mode == "cam" and Track.preview.get_width() > 0
	if picture:
		cam_c.draw_texture_rect(Track.preview, Rect2(Vector2.ZERO, size), false)
	cam_c.draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, size.y), Color(1, 1, 1, 0.3), 1.0)
	for pid in 2:
		var pc := Color(KEYS.TAG_COLORS[pid])
		var x0 := size.x / 2.0 * pid
		cam_c.draw_rect(Rect2(x0, 0, size.x / 2.0, size.y), Color(pc, 0.9), false, 3.0)
		var tag := "%s: %s" % [KEYS.TAGS[pid], "Pipette" if pid == pipetter else "Glas"]
		cam_c.draw_rect(Rect2(x0 + 6.0, size.y - 26.0, 104.0, 20.0), Color(UI.DARK, 0.8))
		_text(cam_c, Vector2(x0 + 11.0, size.y - 11.0), tag, 14, pc)
	if mode == "cam":
		# what the camera sees: the hands with their joints, pipette and glass painted onto them
		for pid in 2:
			var h := Track.hand(pid)
			if h.is_empty():
				continue
			var pc2 := Color(KEYS.TAG_COLORS[pid])
			var pts: Array = h["pts"]
			for b in BONES:
				cam_c.draw_line(Vector2(pts[b[0]][0], pts[b[0]][1]) * size, Vector2(pts[b[1]][0], pts[b[1]][1]) * size, Color(pc2, 0.75), 2.0)
			for p in pts:
				cam_c.draw_circle(Vector2(p[0], p[1]) * size, 2.5, pc2)
			if pid == pipetter:
				var a := Vector2(pts[4][0], pts[4][1]) * size
				var b2 := Vector2(pts[8][0], pts[8][1]) * size
				cam_c.draw_line(a, b2, UI.GREEN if ok[pid] else UI.YELLOW, 3.0)
				_draw_pipette((a + b2) / 2.0, a.distance_to(b2), ok[pid])
			else:
				_draw_glass(Vector2(h["palm"][0], h["palm"][1]) * size, tilt, ok[pid])
	else:
		# no picture: the same thing as a drawing
		var dim := 0.35 if mode == "wait" else 1.0
		var pc3 := Vector2(size.x * (0.25 + 0.5 * pipetter), size.y * 0.42)
		var gap := lerpf(8.0, 46.0, pinch)
		for sx in [-1.0, 1.0]:
			cam_c.draw_rect(Rect2(pc3.x + sx * (gap / 2.0 + 4.0) - 26.0 + sx * 26.0, pc3.y - 9.0, 52.0, 18.0), Color("e0ac85"))
			cam_c.draw_circle(pc3 + Vector2(sx * (gap / 2.0 + 4.0), 0), 9.0, Color("e0ac85"))
		_draw_pipette(pc3, gap, ok[pipetter])
		var hc := Vector2(size.x * (0.25 + 0.5 * holder()), size.y * 0.66)
		cam_c.draw_set_transform(hc, deg_to_rad(tilt), Vector2.ONE)
		cam_c.draw_rect(Rect2(-62.0, -8.0, 124.0, 16.0), Color("e0ac85"))
		cam_c.draw_circle(Vector2(-62.0, 0), 8.0, Color("e0ac85"))
		cam_c.draw_circle(Vector2(62.0, 0), 8.0, Color("e0ac85"))
		cam_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_glass(hc, tilt, ok[holder()])
		if dim < 1.0:
			cam_c.draw_rect(Rect2(Vector2.ZERO, size), Color(UI.DARK, 0.6))
			var msg := Track.status if Track.status != "aus" else "Kamera startet …"
			var mw := ThemeDB.fallback_font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			_text(cam_c, Vector2((size.x - mw) / 2.0, size.y / 2.0 - 10.0), msg, 20, UI.WHITE)
			for i in 3:
				cam_c.draw_circle(Vector2(size.x / 2.0 - 16.0 + i * 16.0, size.y / 2.0 + 18.0), 4.0,
					Color(UI.YELLOW, 0.3 + 0.7 * maxf(0.0, sin(t * 4.0 - i * 0.9))))
	for d in drops:
		cam_c.draw_circle(d[0], 3.2, LIQUID)
		cam_c.draw_circle((d[0] as Vector2) + Vector2(-0.8, -0.8), 1.0, Color(1, 1, 1, 0.8))


## The glass filling up, with one lamp per player that is on while that player is in the green.
func _draw_fill() -> void:
	var w := fill_c.size.x
	var bar := Rect2(64.0, 14.0, w - 128.0, 34.0)
	fill_c.draw_rect(bar, UI.DARK)
	fill_c.draw_rect(bar.grow(-3.0), Color(0.15, 0.19, 0.3))
	var fw := (bar.size.x - 6.0) * fill
	if fw > 0.5:
		fill_c.draw_rect(Rect2(bar.position.x + 3.0, bar.position.y + 3.0, fw, bar.size.y - 6.0), LIQUID)
		fill_c.draw_rect(Rect2(bar.position.x + 3.0, bar.position.y + 3.0, fw, 5.0), Color(1, 1, 1, 0.25))
	if ok[0] and ok[1] and closing < 0.0:
		fill_c.draw_rect(bar, Color(UI.GREEN, 0.6 + 0.4 * sin(t * 10.0)), false, 3.0)
	elif spill_t > 0.0:
		fill_c.draw_rect(bar, Color(UI.RED, spill_t * 2.0), false, 3.0)
	var txt := "%.1f von %.1f mL" % [fill * GOAL_ML, GOAL_ML]
	if spill_t > 0.0:
		txt += "   verschüttet!"
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var tp := Vector2(bar.get_center().x - tw / 2.0, bar.get_center().y + 6.0)
	fill_c.draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, UI.DARK)
	fill_c.draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.WHITE)
	for pid in 2:
		var pc := Color(KEYS.TAG_COLORS[pid])
		var lc := Vector2(30.0 if pid == 0 else w - 30.0, bar.get_center().y)
		fill_c.draw_circle(lc, 20.0, UI.GREEN if ok[pid] else Color(0.2, 0.25, 0.3))
		fill_c.draw_arc(lc, 20.0, 0.0, TAU, 28, pc, 3.0)
		var tag: String = KEYS.TAGS[pid]
		var sw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		fill_c.draw_string(font, lc + Vector2(-sw / 2.0, 5.5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.DARK if ok[pid] else UI.WHITE)
