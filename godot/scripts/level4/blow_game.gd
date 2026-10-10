extends CanvasLayer
## Level 4, challenge 2: the fondue alarm. Prof. Dr. Siedler's fondue in fume hood 1 is boiling
## over. The two players cool it by blowing into the microphone (autoload Track: Track.use_mic,
## Track.blow) until the thermometer is back in the green. If it reaches the top, it boils over
## and a jet of flame shoots out: the level sets the players on fire (see level.gd).
##
## Without a microphone, and at any other time as well, they fan it with their lab journals: both
## hammer on their interact key. Fanning only works together: a press counts while the other
## player has pressed within TOGETHER seconds, too.
##
##   var mg = BlowGame.new();  mg.temp = 55.0;  main.add_child(mg);  mg.open()
## Emits finished(true) when it is saved, finished(false) when somebody left with Esc or
## Backspace (read `temp` then, the fondue keeps heating in the lab), and burnt() when it boiled over.

signal finished(success: bool)
signal burnt

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")

# ---- tuning. Temperatures are on the scale of the thermometer, 0..100.
const HEAT := 6.5          # per second: how fast the fondue heats up by itself while the game is open
const COOL_BLOW := 30.0    # per second at a full blow (Track.blow = 1)
const BLOW_MIN := 0.1      # blowing weaker than this does nothing (noise in the room)
const COOL_KEY := 2.3      # per key press while both are fanning
const TOGETHER := 0.45     # seconds: a press counts if the other one pressed within this time, too
const SAFE := 22.0         # at or below this the fondue is saved
const MIC_WAIT := 2.5      # seconds to wait for the microphone before it counts as missing

const CANVAS := Vector2(760, 320)
const SCENE_W := 560.0
const CHEESE := Color("ffd23f")
const CHARRED := Color("6b3d14")
const POT := Color("c0392b")

var temp := 50.0
var sfx = null             # lab_sfx.gd node of the level, for the alarm
var mic := "wait"          # wait, on, off
var mic_t := 0.0
var t := 0.0
var closing := -1.0        # > 0: saved, closing
var burning := -1.0        # > 0: boiled over, closing
var last_press: Array = [-9.0, -9.0]
var flap: Array = [0.0, 0.0]   # the lab journals: 1 right after a press that counted
var fanned := 0.0          # cooling from the keys during the last moment, per second, for the drawing
var wind := 0.0            # 0..1: how hard it is being cooled right now
var beep_t := 0.0

var root: Control
var panel: PanelContainer
var title_l: Label
var info_l: Label
var canvas: Control


func open() -> void:
	layer = 20
	Track.use_mic(self)   # the microphone is let go again when this node leaves the tree
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
	title_l = UI.label("Blubber-Alarm: Das Fondue kocht über!", 30, UI.YELLOW, 7)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)
	head.add_child(UI.label("%s / %s · abbrechen" % [KEYS.LABELS[0]["abort"], KEYS.LABELS[1]["abort"]], 13, UI.MUTED))
	canvas = Control.new()
	canvas.custom_minimum_size = CANVAS
	canvas.clip_contents = true
	canvas.draw.connect(_draw_all)
	body.add_child(canvas)
	info_l = UI.label("", 15, UI.WHITE, 0, true)
	info_l.custom_minimum_size = Vector2(CANVAS.x, 44)
	body.add_child(info_l)
	if Track.mic_ok:
		mic = "on"
	_show_info()
	UI.pop_in(panel, 0.0, 0.6)
	UI.sfx("whoosh", -10.0)


func _show_info() -> void:
	var k0: String = KEYS.LABELS[0]["ok"]
	var k1: String = KEYS.LABELS[1]["ok"]
	match mic:
		"on":
			info_l.text = "Pustet ins Mikrofon, bis das Thermometer im Grünen ist! Fächeln hilft auch: beide gleichzeitig auf %s und %s hämmern." % [k0, k1]
		"off":
			info_l.text = "Kein Mikrofon gefunden. Dann wird gefächelt: beide gleichzeitig auf ihre Taste hämmern (%s und %s), bis das Thermometer im Grünen ist. Allein bringt es nichts." % [k0, k1]
		_:
			info_l.text = "Mikrofon startet … Fächeln geht schon: beide gleichzeitig auf %s und %s hämmern." % [k0, k1]


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	t += delta
	for i in 2:
		flap[i] = maxf(0.0, flap[i] - delta * 5.0)
	fanned = maxf(0.0, fanned - fanned * delta * 4.0)
	if closing >= 0.0:
		closing -= delta
		if closing < 0.0:
			finished.emit(true)
			queue_free()
			return
	elif burning >= 0.0:
		burning -= delta
		if burning < 0.0:
			burnt.emit()
			queue_free()
			return
	else:
		_update_mic(delta)
		_cool(delta)
	canvas.queue_redraw()


func _update_mic(delta: float) -> void:
	var before := mic
	if Track.mic_ok:
		mic = "on"
	elif mic == "wait":
		mic_t += delta
		if mic_t >= MIC_WAIT:
			mic = "off"
	if mic != before:
		_show_info()


func _cool(delta: float) -> void:
	var blow := 0.0
	if mic == "on" and Track.blow > BLOW_MIN:
		blow = Track.blow * COOL_BLOW
	for pid in 2:
		if Input.is_action_just_pressed(KEYS.action(pid, "interact")):
			last_press[pid] = t
			if t - float(last_press[1 - pid]) <= TOGETHER:   # only together
				temp -= COOL_KEY
				fanned += COOL_KEY * 4.0
				flap[pid] = 1.0
	temp = clampf(temp + (HEAT - blow) * delta, 0.0, 100.0)
	wind = lerpf(wind, clampf((blow + fanned) / COOL_BLOW, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	beep_t -= delta
	if beep_t <= 0.0:
		beep_t = lerpf(1.2, 0.45, temp / 100.0)
		if sfx:
			sfx.play("alarm", -14.0)
	if temp <= SAFE:
		closing = 1.3
		title_l.text = "Gerettet! Das Fondue lebt."
		title_l.label_settings.font_color = UI.GREEN
		panel.add_theme_stylebox_override("panel", UI.box(UI.NAVY, UI.GREEN, 24, 5, 18))
		UI.sfx("grant", -6.0)
	elif temp >= 100.0:
		burning = 0.9
		title_l.text = "STICHFLAMME!"
		title_l.label_settings.font_color = UI.RED
		panel.add_theme_stylebox_override("panel", UI.box(UI.NAVY, UI.RED, 24, 5, 18))
		UI.sfx("fail", -4.0)
		UI.shake(panel, 12.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k in (KEYS.PLAYER_KEYS[0]["abort"] as Array) or k in (KEYS.PLAYER_KEYS[1]["abort"] as Array):
		get_viewport().set_input_as_handled()
		if closing < 0.0 and burning < 0.0:
			finished.emit(false)
			queue_free()


# ------------------------------------------------------------------ drawing
func _text(pos: Vector2, s: String, size: int, col: Color, outline: int = 0) -> void:
	var font := ThemeDB.fallback_font
	if outline > 0:
		canvas.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, UI.DARK)
	canvas.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	canvas.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	canvas.draw_circle(Vector2.ZERO, rx, col)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A number that stays the same for the same i: where bubble or puff i sits.
func _rnd(i: int) -> float:
	return fmod(absf(sin(i * 12.9898) * 43758.5453), 1.0)


func _draw_all() -> void:
	_draw_scene()
	_draw_thermo()


## Inside fume hood 1: the caquelon on its burner, bubbling harder the hotter it gets.
func _draw_scene() -> void:
	var c := canvas
	var hot := clampf(temp / 100.0, 0.0, 1.0)
	c.draw_rect(Rect2(0, 0, SCENE_W, CANVAS.y), Color("2f363d"))
	c.draw_rect(Rect2(10, 10, SCENE_W - 20.0, 232.0), Color("3d464f"))
	for i in 6:   # the slots in the back wall
		c.draw_rect(Rect2(40.0 + i * 86.0, 26.0, 46.0, 5.0), Color("23292f"))
	c.draw_rect(Rect2(0, 242, SCENE_W, CANVAS.y - 242.0), Color("cfd6da"))
	c.draw_rect(Rect2(0, 242, SCENE_W, 5.0), Color("9aa6ae"))
	c.draw_rect(Rect2(0, 0, SCENE_W, CANVAS.y), Color(1.0, 0.35, 0.1, 0.22 * clampf((hot - 0.5) * 2.0, 0.0, 1.0) * (0.75 + 0.25 * sin(t * 9.0))))
	# the note on the glass
	c.draw_rect(Rect2(404, 44, 132, 46), Color("fff3a0"))
	_text(Vector2(412, 62), "NICHT anfassen.", 13, Color("3a3320"))
	_text(Vector2(412, 80), "Nicht probieren. S.", 13, Color("3a3320"))
	# smoke detector
	c.draw_circle(Vector2(36, 50), 12.0, Color("e9ece8"))
	c.draw_circle(Vector2(36, 50), 5.0, UI.RED if (hot > 0.55 and fmod(t * (2.0 + hot * 4.0), 1.0) < 0.5) else Color("7a2a2a"))
	var mid := 280.0
	# burner under the pot
	c.draw_rect(Rect2(mid - 62.0, 232.0, 124.0, 10.0), Color("1f2429"))
	for sx in [-1.0, 1.0]:
		c.draw_line(Vector2(mid + sx * 54.0, 234.0), Vector2(mid + sx * 44.0, 204.0), Color("1f2429"), 5.0)
	c.draw_rect(Rect2(mid - 12.0, 216.0, 24.0, 18.0), Color("7f8a94"))
	var fl := 1.0 + 0.2 * sin(t * 19.0) + 0.12 * sin(t * 31.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(mid - 15.0, 216.0), Vector2(mid, 216.0 - 26.0 * fl), Vector2(mid + 15.0, 216.0)]), Color(1.0, 0.55, 0.15, 0.95))
	c.draw_colored_polygon(PackedVector2Array([Vector2(mid - 8.0, 216.0), Vector2(mid, 216.0 - 15.0 * fl), Vector2(mid + 8.0, 216.0)]), Color(0.45, 0.7, 1.0, 0.95))
	# the caquelon
	var top := 128.0
	var pot := PackedVector2Array([Vector2(mid - 96.0, top), Vector2(mid + 96.0, top), Vector2(mid + 78.0, 204.0), Vector2(mid - 78.0, 204.0)])
	c.draw_colored_polygon(pot, POT)
	c.draw_colored_polygon(PackedVector2Array([Vector2(mid - 96.0, top), Vector2(mid - 60.0, top), Vector2(mid - 50.0, 204.0), Vector2(mid - 78.0, 204.0)]), POT.lightened(0.14))
	c.draw_rect(Rect2(mid + 92.0, top + 14.0, 78.0, 15.0), POT.darkened(0.2))   # handle
	c.draw_circle(Vector2(mid + 170.0, top + 21.5), 9.0, POT.darkened(0.2))
	for i in 5:   # white crosses, it is a Swiss pot
		var cx := mid - 44.0 + i * 30.0
		c.draw_rect(Rect2(cx - 2.0, 160.0, 4.0, 14.0), Color.WHITE)
		c.draw_rect(Rect2(cx - 7.0, 165.0, 14.0, 4.0), Color.WHITE)
	# cheese: yellow, darker and browner towards burnt
	var cheese := CHEESE.lerp(CHARRED, clampf((hot - 0.55) / 0.45, 0.0, 1.0) * 0.85)
	_ell(Vector2(mid, top), 96.0, 15.0, POT.darkened(0.25))
	_ell(Vector2(mid, top), 89.0, 11.5, cheese)
	if hot > 0.7:   # running over the rim
		var over := (hot - 0.7) / 0.3
		for i in 5:
			var dx := mid - 84.0 + i * 42.0 + sin(i * 2.3) * 8.0
			c.draw_rect(Rect2(dx - 5.0, top, 10.0, 12.0 + over * (30.0 + _rnd(i) * 30.0)), cheese)
			c.draw_circle(Vector2(dx, top + 12.0 + over * (30.0 + _rnd(i) * 30.0)), 5.0, cheese)
	var bubbles := 3 + int(hot * 9.0)
	for i in bubbles:
		var u := fmod(t * (0.5 + hot * 1.6) + _rnd(i) * 3.0, 1.0)
		var bx := mid - 74.0 + _rnd(i + 7) * 148.0
		var br := (3.0 + 9.0 * hot) * sin(u * PI)
		c.draw_circle(Vector2(bx, top - br * 0.5), br, cheese.lightened(0.18))
		c.draw_arc(Vector2(bx, top - br * 0.5), br, 0.0, TAU, 14, cheese.darkened(0.25), 1.2)
	# a fork with a piece of bread that somebody left in it
	c.draw_line(Vector2(mid - 30.0, top - 4.0), Vector2(mid - 92.0, top - 78.0), Color("9aa6ae"), 3.0)
	c.draw_rect(Rect2(mid - 40.0, top - 14.0, 16.0, 14.0), Color("d9b77a"))
	# steam, turning into smoke; the wind blows it away
	var puffs := 4 + int(hot * 8.0)
	var smoke := Color(1, 1, 1).lerp(Color(0.25, 0.22, 0.2), clampf((hot - 0.6) / 0.4, 0.0, 1.0))
	for i in puffs:
		var u2 := fmod(t * (0.35 + hot * 0.5) + _rnd(i + 20), 1.0)
		var px := mid - 70.0 + _rnd(i + 31) * 140.0 + sin(u2 * 5.0 + i) * 9.0 + wind * u2 * 170.0
		c.draw_circle(Vector2(px, top - 12.0 - u2 * (70.0 + hot * 50.0)), 7.0 + u2 * (10.0 + hot * 12.0), Color(smoke, (0.2 + 0.35 * hot) * (1.0 - u2)))
	# boiled over: the jet of flame
	if burning >= 0.0:
		var g := clampf(1.0 - burning / 0.9, 0.0, 1.0)
		for i in 7:
			var fx := mid - 90.0 + i * 30.0 + sin(t * 23.0 + i) * 6.0
			var fh := (120.0 + _rnd(i + 60) * 110.0) * g * (0.8 + 0.2 * sin(t * 31.0 + i * 2.0))
			c.draw_colored_polygon(PackedVector2Array([Vector2(fx - 26.0, top + 6.0), Vector2(fx, top - fh), Vector2(fx + 26.0, top + 6.0)]), Color(1.0, 0.45, 0.1, 0.92))
			c.draw_colored_polygon(PackedVector2Array([Vector2(fx - 13.0, top + 6.0), Vector2(fx, top - fh * 0.6), Vector2(fx + 13.0, top + 6.0)]), Color(1.0, 0.85, 0.3, 0.95))
		c.draw_rect(Rect2(0, 0, SCENE_W, CANVAS.y), Color(1.0, 0.9, 0.6, 0.35 * (1.0 - g)))
	# the wind: blown or fanned
	if wind > 0.04:
		for i in 7:
			var u3 := fmod(t * (1.2 + wind * 1.6) + _rnd(i + 40), 1.0)
			var y := 60.0 + _rnd(i + 50) * 110.0
			var x := 70.0 + u3 * 420.0
			c.draw_line(Vector2(x, y), Vector2(x + 34.0 + wind * 40.0, y + sin(u3 * 6.0) * 4.0), Color(1, 1, 1, wind * (1.0 - u3) * 0.85), 2.5)
	# the two lab journals for fanning
	for pid in 2:
		var pc := Color(KEYS.TAG_COLORS[pid])
		var at := Vector2(74.0 if pid == 0 else SCENE_W - 74.0, 196.0)
		var swing: float = float(flap[pid]) * (0.7 if pid == 0 else -0.7)
		c.draw_set_transform(at, swing, Vector2.ONE)
		c.draw_rect(Rect2(-24.0, -70.0, 48.0, 64.0), UI.DARK)
		c.draw_rect(Rect2(-21.0, -67.0, 42.0, 58.0), pc)
		c.draw_rect(Rect2(-14.0, -58.0, 28.0, 4.0), Color(1, 1, 1, 0.7))
		c.draw_rect(Rect2(-14.0, -48.0, 20.0, 4.0), Color(1, 1, 1, 0.7))
		c.draw_circle(Vector2(0, 0), 9.0, Color("e0ac85"))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var lit: bool = t - float(last_press[pid]) < 0.15
		var kc := Vector2(at.x, 286.0)
		c.draw_circle(kc, 19.0, pc if lit else Color(0.2, 0.25, 0.3))
		c.draw_arc(kc, 19.0, 0.0, TAU, 28, pc, 3.0)
		var key: String = KEYS.LABELS[pid]["ok"]
		var kw := ThemeDB.fallback_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_text(kc + Vector2(-kw / 2.0, 5.0), key, 13, UI.DARK if lit else UI.WHITE)
	# the microphone: how hard the blowing arrives
	var bar := Rect2(170.0, 276.0, 220.0, 18.0)
	_text(Vector2(bar.position.x, bar.position.y - 6.0), "Mikrofon", 13, Color("3a4150"))
	c.draw_rect(bar, UI.DARK)
	if mic == "on":
		c.draw_rect(Rect2(bar.position.x + 2.0, bar.position.y + 2.0, (bar.size.x - 4.0) * clampf(Track.blow, 0.0, 1.0), bar.size.y - 4.0), UI.BLUE.lerp(Color.WHITE, clampf(Track.blow, 0.0, 1.0) * 0.6))
		c.draw_line(Vector2(bar.position.x + bar.size.x * BLOW_MIN, bar.position.y), Vector2(bar.position.x + bar.size.x * BLOW_MIN, bar.end.y), UI.YELLOW, 2.0)
	else:
		_text(bar.position + Vector2(8.0, 14.0), "startet …" if mic == "wait" else "keines gefunden", 13, UI.MUTED)


## The thermometer: green at the bottom, red at the top. Saved below the green line, burnt at the top.
func _draw_thermo() -> void:
	var c := canvas
	var tube := Rect2(626.0, 30.0, 44.0, 236.0)
	c.draw_rect(tube.grow(4.0), UI.DARK)
	var n := 48
	for i in n:
		var v := (i + 0.5) / n * 100.0
		var col := UI.GREEN
		if v > SAFE:
			col = UI.GREEN.lerp(UI.YELLOW, clampf((v - SAFE) / 28.0, 0.0, 1.0)) if v < 50.0 else UI.YELLOW.lerp(UI.RED, clampf((v - 50.0) / 35.0, 0.0, 1.0))
		var y := tube.end.y - tube.size.y * (i + 1) / n
		c.draw_rect(Rect2(tube.position.x, y, tube.size.x, tube.size.y / n + 0.6), col)
	var safe_y := tube.end.y - tube.size.y * SAFE / 100.0
	c.draw_line(Vector2(tube.position.x - 8.0, safe_y), Vector2(tube.end.x + 8.0, safe_y), UI.WHITE, 2.0)
	_text(Vector2(tube.end.x + 12.0, safe_y + 5.0), "gerettet", 14, UI.GREEN, 4)
	_text(Vector2(tube.end.x + 12.0, tube.position.y + 12.0), "verbrannt", 14, UI.RED, 4)
	# the pointer
	var y2 := tube.end.y - tube.size.y * clampf(temp, 0.0, 100.0) / 100.0
	c.draw_rect(Rect2(tube.position.x - 6.0, y2 - 3.5, tube.size.x + 12.0, 7.0), UI.DARK)
	c.draw_rect(Rect2(tube.position.x - 4.0, y2 - 1.5, tube.size.x + 8.0, 3.0), UI.WHITE)
	c.draw_colored_polygon(PackedVector2Array([Vector2(tube.position.x - 18.0, y2 - 8.0), Vector2(tube.position.x - 18.0, y2 + 8.0), Vector2(tube.position.x - 5.0, y2)]), UI.WHITE)
	var txt := "%d °C" % int(round(temp))
	var w := ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var tc := UI.GREEN if temp <= SAFE else (UI.YELLOW if temp < 60.0 else UI.RED)
	_text(Vector2(tube.get_center().x - w / 2.0, tube.end.y + 38.0), txt, 30, tc, 7)
