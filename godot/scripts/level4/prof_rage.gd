extends CanvasLayer
## Level 4: the professor boils over. Full-screen fail animation after a failed Testat.
## He tries to stay calm, the Siedler-Meter climbs with every line, his face turns red, steam comes
## out of his ears, and at 100 °C the thermometer bursts, his glasses fly off and the stamp comes down.
## Afterwards the level shows the usual lose screen.
##
##   var rage = Rage.new()
##   rage.look = <look of the professor>;  rage.pname = "Prof. Dr. Siedler";  rage.sfx = <lab_sfx.gd node>
##   main.add_child(rage)
##   rage.play(beats, done)
##
## `beats` is an Array with one Dictionary per beat:
##   {"text": "...", "heat": 0.5}       a line; the meter climbs to `heat` (0..1 = 20..100 °C).
##                                      Optional: "size" (font), "speed" (letters per second),
##                                      "calm": true (eyes closed, breathing)
##   {"text": "...", "burst": true}     he swells up, the thermometer bursts, then the line
##   {"stamp": "BIG", "sub": "small"}   the stamp, ends the animation
## E / Enter / Space or a click: next beat. Esc: skip everything.

signal burst

const UI = preload("res://scripts/ui.gd")
const ART = preload("res://scripts/character_art.gd")
const BAR_H := 62.0
const SWELL_TIME := 1.1   # seconds he swells up before the thermometer bursts
const HOT := Color("e5372c")
const INK := Color("1c1d33")
const MARKS := [[20, "entspannt"], [40, "kalter Kaffee"], [60, "Folien vergessen"], [80, "falsche Einheit"], [100, "IHR TESTAT"]]

var look: Dictionary = {}
var pname := ""
var sfx = null
var beats: Array = []
var on_done: Callable = Callable()
var idx := -1
var t := 0.0
var heat := 0.0
var heat_target := 0.0
var heat_rate := 0.4
var calm := false
var swell := 0.0          # 0..1 while he swells up before the burst
var burst_wait := false
var burst_from := 0.0
var bursted := false
var ending := false
var typing := false
var shown := 0.0
var type_speed := 40.0
var hold := -1.0
var mouth := 0.0
var shake := 0.0
var flash := 0.0
var stamp_hit := false
var steam: Array = []     # [position, velocity, age] in figure units
var steam_t := 0.0
var drops: Array = []     # [position, velocity, age, radius] in screen px
var specs: Array = []     # flying glasses: [position, velocity, rotation]

var root: Control
var stage: Control
var back: Control
var fig: Control
var over: Control
var bubble: PanelContainer
var text_l: Label
var stamp_root: Control = null


func _ready() -> void:
	layer = 30
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_advance())
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back = _canvas(_draw_back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fig = _canvas(_draw_fig)
	# speech bubble
	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.box(UI.CREAM, UI.DARK, 22, 4, 16))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	bubble.add_child(v)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = HOT
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", sb)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_child(UI.label(pname, 14, UI.WHITE))
	v.add_child(pill)
	text_l = UI.label("", 26, INK, 0, true)
	v.add_child(text_l)
	bubble.visible = false
	over = _canvas(_draw_over)
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# cinema bars, like cutscene.gd
	for i in 2:
		var bar := ColorRect.new()
		bar.color = UI.DARK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bar)
		bar.anchor_right = 1.0
		bar.anchor_top = float(i)
		bar.anchor_bottom = float(i)
		var tw := bar.create_tween()
		if i == 0:
			tw.tween_property(bar, "offset_bottom", BAR_H, 0.3).set_trans(Tween.TRANS_SINE)
		else:
			tw.tween_property(bar, "offset_top", -BAR_H, 0.3).set_trans(Tween.TRANS_SINE)
	var hint := UI.label("E / Enter = weiter   ·   Esc = überspringen", 13, UI.MUTED)
	root.add_child(hint)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -330.0
	hint.offset_right = -18.0
	hint.offset_top = -BAR_H + 20.0
	hint.offset_bottom = -18.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.25)


func _canvas(painter: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(painter)
	stage.add_child(c)
	return c


func play(p_beats: Array, done: Callable = Callable()) -> void:
	beats = p_beats
	on_done = done
	idx = -1
	_next()


# ------------------------------------------------------------------ layout (all relative to the screen)
func _vs() -> Vector2:
	return get_viewport().get_visible_rect().size


func _k() -> float:
	return _vs().y / 720.0 * 8.6   # px per figure unit: the professor is about half the screen tall


func _feet() -> Vector2:
	var vs := _vs()
	return Vector2(vs.x * 0.23, vs.y - BAR_H - vs.y * 0.05)


func _head() -> Vector2:
	return _feet() + Vector2(0, -35.0 * _k())


func _thermo_x() -> float:
	return _vs().x * 0.885


func _thermo_top() -> float:
	return BAR_H + _vs().y * 0.13


func _thermo_bulb() -> float:
	return _vs().y - BAR_H - _vs().y * 0.17


## Screen y of temperature `deg` on the scale.
func _thermo_y(deg: float) -> float:
	return lerpf(_thermo_bulb() - 40.0, _thermo_top() + 16.0, (deg - 20.0) / 80.0)


# ------------------------------------------------------------------ beats
func _next() -> void:
	if ending:
		return
	idx += 1
	if idx >= beats.size():
		_finish()
		return
	var b: Dictionary = beats[idx]
	if b.has("stamp"):
		_show_stamp(b)
		return
	calm = b.get("calm", false)
	if b.get("burst", false) and not bursted:
		# no words yet: he swells up first, the line comes with the bang
		burst_wait = true
		burst_from = heat
		heat_target = 1.0
		swell = 0.0
		bubble.visible = false
		typing = false
		hold = -1.0
		return
	heat_target = float(b.get("heat", heat_target))
	heat_rate = 0.4
	_say(b)


func _say(b: Dictionary) -> void:
	text_l.text = String(b["text"])
	text_l.label_settings.font_size = int(b.get("size", 26))
	text_l.visible_characters = 0
	shown = 0.0
	type_speed = float(b.get("speed", 40.0))
	typing = true
	hold = -1.0
	var w := _vs().x * 0.325   # ends left of the labels of the Siedler-Meter
	text_l.custom_minimum_size = Vector2(w, 0)
	bubble.visible = true
	bubble.reset_size()
	UI.pop_in(bubble, 0.0, 0.8)


func _burst() -> void:
	burst_wait = false
	bursted = true
	swell = 0.0
	flash = 1.0
	shake = 30.0
	if sfx:
		sfx.kettle_off()
		sfx.play("boom", -2.0)
		sfx.play("glass", -4.0)
	var k := _k()
	specs = [_head() + Vector2(0, -0.5 * k), Vector2(310.0, -640.0) * (_vs().y / 720.0), 0.0]
	var top := Vector2(_thermo_x(), _thermo_top())
	for i in 70:
		var a := -PI / 2.0 + randf_range(-1.15, 1.15)
		drops.append([top + Vector2(randf_range(-8, 8), randf_range(-6, 30)), Vector2.from_angle(a) * randf_range(180.0, 720.0), 0.0, randf_range(2.5, 7.0)])
	burst.emit()
	_say(beats[idx])


func _show_stamp(b: Dictionary) -> void:
	bubble.visible = false
	typing = false
	hold = -1.0
	stamp_root = Control.new()
	stamp_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stamp_root)
	stamp_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.05, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var turn := Control.new()   # the part that rotates and slams down
	turn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_root.add_child(turn)
	turn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(HOT, 0.16)
	sb.border_color = HOT
	sb.set_border_width_all(10)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 8
	sb.content_margin_bottom = 14
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	frame.add_child(v)
	var big := UI.label(String(b["stamp"]), 104, HOT, 16)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var sub := UI.label(String(b.get("sub", "")), 24, UI.WHITE, 7)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	turn.pivot_offset = _vs() / 2.0
	turn.rotation = -0.13
	turn.scale = Vector2(3.6, 3.6)
	turn.modulate.a = 0.0
	var tw := stamp_root.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(turn, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(turn, "modulate:a", 1.0, 0.08)
	tw.tween_callback(func():
		stamp_hit = true
		shake = 22.0
		dim.color.a = 0.4
		if sfx:
			sfx.play("stamp", -1.0)
		UI.sfx("doom", -4.0))
	tw.tween_interval(float(b.get("time", 2.4)))
	tw.tween_callback(_finish)


func _advance() -> void:
	if ending or t < 0.7:
		return
	if stamp_root != null:
		if stamp_hit:
			_finish()
		return
	if burst_wait:
		swell = 1.0
		return
	if typing:
		typing = false
		text_l.visible_characters = -1
		hold = 1.4
		return
	_next()


func _finish() -> void:
	if ending:
		return
	ending = true
	if sfx:
		sfx.kettle_off()
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if on_done.is_valid():
			on_done.call()
		queue_free())


func _input(event: InputEvent) -> void:
	if ending or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish()
	elif k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		_advance()


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	t += delta
	if ending:
		return
	heat = move_toward(heat, heat_target, delta * heat_rate)
	if burst_wait:
		# a long second of puffed cheeks, then the bang
		swell = minf(1.0, swell + delta / SWELL_TIME)
		heat = lerpf(burst_from, 1.0, swell)
		if swell >= 1.0:
			_burst()
	if sfx and not bursted:
		sfx.kettle(heat)
	# typing and talking
	mouth = maxf(0.0, mouth - delta * 7.0)
	if typing:
		var before := int(shown)
		shown += delta * type_speed
		if int(shown) >= text_l.text.length():
			typing = false
			text_l.visible_characters = -1
			hold = 0.9 + text_l.text.length() * 0.03
		elif int(shown) != before:
			text_l.visible_characters = int(shown)
			if int(shown) % 2 == 0:
				mouth = 1.0
				if sfx:
					sfx.play("blah", lerpf(-17.0, -6.0, heat), randf_range(0.8, 1.25) * lerpf(0.75, 1.5, heat))
	elif hold > 0.0:
		hold -= delta
		if hold <= 0.0:
			_next()
	# steam from the ears
	for s in steam:
		s[0] += (s[1] as Vector2) * delta
		s[2] += delta
	steam = steam.filter(func(s): return s[2] < 0.9)
	if heat > 0.4 and not calm:
		steam_t -= delta
		if steam_t <= 0.0:
			steam_t = lerpf(0.14, 0.03, heat)
			for side in [-1.0, 1.0]:
				steam.append([Vector2(side * 8.4, -34.5), Vector2(side * randf_range(12.0, 30.0), -randf_range(5.0, 17.0)), 0.0])
	# what flies through the air after the burst
	var g := 1500.0 * _vs().y / 720.0
	for d in drops:
		d[1] += Vector2(0, g) * delta
		d[0] += (d[1] as Vector2) * delta
		d[2] += delta
	drops = drops.filter(func(d): return d[2] < 1.6)
	if not specs.is_empty():
		specs[1] += Vector2(0, g) * delta
		specs[0] += (specs[1] as Vector2) * delta
		specs[2] += delta * 11.0
	flash = maxf(0.0, flash - delta * 2.6)
	shake = move_toward(shake, 0.0, delta * 55.0)
	_place()
	back.queue_redraw()
	fig.queue_redraw()
	over.queue_redraw()


## Shake, hop, squash and stretch.
func _place() -> void:
	var vs := _vs()
	var k := _k()
	var s := vs.y / 720.0
	var rumble := shake + (heat - 0.6) * 5.0 if heat > 0.6 else shake
	stage.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * rumble
	var fury := 0.0 if (calm or burst_wait) else clampf((heat - 0.5) / 0.5, 0.0, 1.0)   # hopping mad
	var up := absf(sin(t * 10.0))
	var stretch := lerpf(-0.09, 0.09, up) * fury
	var breath := sin(t * 2.4) * 0.02 if calm else 0.0
	var big := 1.0 + 0.16 * swell
	fig.scale = Vector2(k * big * (1.0 - stretch + swell * 0.05 * sin(t * 40.0)), k * big * (1.0 + stretch + breath))
	fig.position = _feet() + Vector2(sin(t * 53.0) * 4.0 * heat * heat * s, -up * 46.0 * fury * s)
	fig.rotation = sin(t * 23.0) * 0.035 * fury
	if bubble.visible:
		var jitter := Vector2(sin(t * 61.0), cos(t * 47.0)) * 3.0 * clampf((heat - 0.5) * 2.0, 0.0, 1.0)
		bubble.position = Vector2(vs.x * 0.385, BAR_H + vs.y * 0.085) + jitter


# ------------------------------------------------------------------ drawing
func _text(c: Control, pos: Vector2, text: String, size: int, col: Color, align_right: bool = false, outline: int = 4) -> void:
	var font := ThemeDB.fallback_font
	var p := pos
	if align_right:
		p.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if outline > 0:
		c.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, UI.DARK)
	c.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_back() -> void:
	var vs := _vs()
	var full := Rect2(Vector2(-60, -60), vs + Vector2(120, 120))   # wider than the screen: the stage shakes
	back.draw_rect(full, Color(0.07, 0.03, 0.07, 0.66))
	back.draw_rect(full, Color(HOT, (0.04 + 0.13 * heat) * (0.65 + 0.35 * sin(t * 9.0))))
	# rays behind his head, faster and redder with the heat
	var hc := _head()
	var rl := vs.y * (0.45 + 0.4 * heat)
	for i in 14:
		var a := t * (0.25 + heat) + i * TAU / 14.0
		back.draw_colored_polygon(PackedVector2Array([hc + Vector2.from_angle(a - 0.1) * 50.0, hc + Vector2.from_angle(a) * rl,
			hc + Vector2.from_angle(a + 0.1) * 50.0]), Color(1.0, 0.45, 0.25, 0.03 + 0.13 * heat))
	_draw_thermo()


func _draw_thermo() -> void:
	var x := _thermo_x()
	var top := _thermo_top()
	var bulb := _thermo_bulb()
	var deg := 20.0 + 80.0 * heat
	var wob := Vector2(sin(t * 70.0), 0) * (3.0 * clampf((heat - 0.8) * 5.0, 0.0, 1.0) if not bursted else 0.0)
	var c := Vector2(x, 0) + wob
	_text(back, Vector2(x - 78.0, top - 22.0), "SIEDLER-METER", 19, UI.YELLOW)
	# glass
	back.draw_rect(Rect2(c.x - 15, top, 30, bulb - top), UI.DARK)
	back.draw_circle(Vector2(c.x, bulb), 33.0, UI.DARK)
	if not bursted:
		back.draw_circle(Vector2(c.x, top), 15.0, UI.DARK)
		back.draw_circle(Vector2(c.x, top), 11.0, Color("eef4f8"))
	back.draw_rect(Rect2(c.x - 11, top, 22, bulb - top), Color("eef4f8"))
	back.draw_circle(Vector2(c.x, bulb), 29.0, Color("eef4f8"))
	# mercury
	var level := _thermo_y(minf(deg, 106.0)) if not bursted else top
	back.draw_circle(Vector2(c.x, bulb), 23.0, HOT)
	back.draw_rect(Rect2(c.x - 6, level, 12, bulb - level), HOT)
	back.draw_circle(Vector2(c.x - 8, bulb - 8), 5.0, Color(1, 1, 1, 0.45))
	if bursted:
		# what is left of the top
		back.draw_colored_polygon(PackedVector2Array([Vector2(c.x - 15, top), Vector2(c.x - 9, top - 13), Vector2(c.x - 3, top + 2),
			Vector2(c.x + 4, top - 9), Vector2(c.x + 9, top + 3), Vector2(c.x + 15, top - 6), Vector2(c.x + 15, top + 8), Vector2(c.x - 15, top + 8)]), UI.DARK)
		back.draw_polyline(PackedVector2Array([Vector2(c.x - 9, top + 20), Vector2(c.x + 2, top + 44), Vector2(c.x - 5, top + 70), Vector2(c.x + 7, top + 104)]), UI.DARK, 2.0)
	# scale
	for d in range(20, 101, 10):
		var y := _thermo_y(float(d))
		back.draw_line(Vector2(c.x + 15, y), Vector2(c.x + (27 if d % 20 == 0 else 21), y), UI.WHITE, 2.0)
	for m in MARKS:
		var y2 := _thermo_y(float(m[0]))
		var reached: bool = deg >= float(m[0]) - 0.5
		var col := UI.MUTED
		if reached:
			col = HOT.lightened(0.25) if int(m[0]) >= 100 else UI.WHITE
		_text(back, Vector2(c.x - 24.0, y2 + 5.0), "%s  %d°" % [m[1], m[0]], 17 if int(m[0]) >= 100 else 15, col, true)
	# read-out
	var read := "%d °C" % int(deg)
	if bursted:
		read = "ÜBER 100 °C"
	var rs := 28 if not bursted else 24
	var rw := ThemeDB.fallback_font.get_string_size(read, HORIZONTAL_ALIGNMENT_LEFT, -1, rs).x
	_text(back, Vector2(x - rw / 2.0, bulb + 68.0), read, rs, UI.WHITE.lerp(HOT.lightened(0.2), heat), false, 6)


func _draw_fig() -> void:
	var lk := look.duplicate()
	lk["skin"] = ART.col(look, "skin").lerp(HOT, clampf(heat * 1.05, 0.0, 1.0))
	if bursted:
		lk["skin"] = (lk["skin"] as Color).lerp(Color("9c1f4d"), 0.35 + 0.2 * sin(t * 6.0))
		lk["acc"] = (look.get("acc", []) as Array).filter(func(a): return a != "glasses")
	# hair and beard start to glow like hot metal
	var hair := ART.col(look, "hair").lerp(Color("ff6a3d"), heat * heat * 0.75)
	lk["hair"] = hair
	ART.draw_character(fig, lk, ART.FRONT, 0.0, false)
	var hy := -35.0
	var skin: Color = lk["skin"]
	var fury := clampf((heat - 0.3) / 0.7, 0.0, 1.0)
	# hair standing on end
	if heat > 0.55:
		var hk := clampf((heat - 0.55) / 0.45, 0.0, 1.0)
		for i in 9:
			var a := deg_to_rad(198.0 + i * 18.0)
			var dir := Vector2.from_angle(a)
			var side := Vector2(-dir.y, dir.x)
			var tip := Vector2(0, hy) + dir * (9.5 + 5.5 * hk + sin(t * 30.0 + i * 2.0) * 0.8 * hk)
			fig.draw_colored_polygon(PackedVector2Array([Vector2(0, hy) + dir * 7.0 + side * 1.5, tip, Vector2(0, hy) + dir * 7.0 - side * 1.5]), hair)
	# eyes
	if calm:
		for sx in [-1.0, 1.0]:
			if sx > 0.0 and fmod(t, 1.1) < 0.12:
				continue   # one eye twitches open
			fig.draw_rect(Rect2(sx * 2.45 - 1.05, hy - 1.0, 2.1, 2.8), skin)
			fig.draw_line(Vector2(sx * 2.45 - 1.2, hy + 0.7), Vector2(sx * 2.45 + 1.2, hy + 0.7), Color("1f1a17"), 0.5)
	elif heat > 0.82:
		for sx in [-1.0, 1.0]:
			var ec := Vector2(sx * 2.5, hy + 0.3)
			fig.draw_circle(ec, 2.3, Color.WHITE)
			fig.draw_arc(ec, 2.3, 0.0, TAU, 16, Color("1f1a17"), 0.3)
			fig.draw_circle(ec + Vector2(sin(t * 31.0 + sx), cos(t * 27.0)) * 0.5, 0.65, Color("1f1a17"))
	# eyebrows
	if not calm:
		var brow := Color("3a3a3a")
		for sx in [-1.0, 1.0]:
			fig.draw_line(Vector2(sx * 5.4, hy - 3.6 - fury * 2.2), Vector2(sx * 0.9, hy - 2.4 + fury * 0.5), brow, 0.9 + fury * 0.5)
	# mouth
	if calm or swell > 0.0:
		fig.draw_line(Vector2(-1.6, hy + 4.0), Vector2(1.6, hy + 4.0), Color("3a1410"), 0.5)
	else:
		var open := 0.45 + mouth * (1.2 + fury * 1.6)
		fig.draw_set_transform(Vector2(0, hy + 4.2), 0.0, Vector2(1.0, open / 2.6))
		fig.draw_circle(Vector2.ZERO, 2.6 + fury * 0.4, Color("3a1410"))
		fig.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if mouth > 0.3:
			fig.draw_rect(Rect2(-1.6, hy + 4.2 - open * 0.85, 3.2, 0.7), Color.WHITE)
	# cheeks puffed up before the burst
	if swell > 0.0:
		for sx in [-1.0, 1.0]:
			fig.draw_circle(Vector2(sx * 6.0, hy + 3.0), 1.5 + swell * 2.0, skin.lightened(0.08))
	# veins
	if heat > 0.5:
		_anger(Vector2(9.8, hy - 8.5), 0.9 + 0.25 * sin(t * 9.0))
	if heat > 0.8:
		_anger(Vector2(-10.6, hy - 4.5), 0.7 + 0.2 * sin(t * 11.0 + 1.0))
	# steam
	for s in steam:
		var a2: float = float(s[2]) / 0.9
		fig.draw_circle(s[0], 1.6 + a2 * 4.2, Color(1, 1, 1, 0.8 * (1.0 - a2)))


func _anger(c: Vector2, s: float) -> void:
	for q in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		fig.draw_polyline(PackedVector2Array([c + Vector2(q.x * 1.0, q.y * 3.6) * s, c + Vector2(q.x * 1.0, q.y * 1.0) * s,
			c + Vector2(q.x * 3.6, q.y * 1.0) * s]), Color("ff2a2a"), 0.7)


func _draw_over() -> void:
	var vs := _vs()
	# tail of the speech bubble, pointing at his mouth
	if bubble.visible:
		var bp := bubble.position
		var tip := _head() + Vector2(10.5, 3.0) * _k() * 0.95
		var a := bp + Vector2(5.0, 40.0)
		var b := bp + Vector2(5.0, 78.0)
		over.draw_colored_polygon(PackedVector2Array([a, tip, b]), UI.CREAM)
		over.draw_line(a, tip, UI.DARK, 4.0)
		over.draw_line(tip, b, UI.DARK, 4.0)
	# mercury drops
	for d in drops:
		var u: float = float(d[2]) / 1.6
		over.draw_circle(d[0], float(d[3]) * (1.0 - u * 0.5), Color(HOT, 1.0 - u * u))
	# his glasses
	if not specs.is_empty():
		var k := _k() * 0.95
		over.draw_set_transform(specs[0], specs[2], Vector2(k, k))
		var gc := Color("22262b")
		over.draw_rect(Rect2(-4.6, -1.8, 4.0, 3.6), gc, false, 0.8)
		over.draw_rect(Rect2(0.6, -1.8, 4.0, 3.6), gc, false, 0.8)
		over.draw_line(Vector2(-0.6, -0.4), Vector2(0.6, -0.4), gc, 0.8)
		over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		over.draw_rect(Rect2(Vector2(-40, -40), vs + Vector2(80, 80)), Color(1, 1, 1, flash))
