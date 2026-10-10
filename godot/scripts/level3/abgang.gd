extends CanvasLayer
## Level 3: the way out. Played when every task is done, before the win screen. The two dance
## across the ballroom to the exit with the badge, and at the back the professor goes through his
## pockets. Then the title of the evening comes down.
##
##   var a = Abgang.new()
##   a.looks = [look of P1, look of P2]
##   main.add_child(a)
##   a.play(done)
##
## E / Enter / Space or a click: on. Esc: skip everything.

const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")
const ART = preload("res://scripts/character_art.gd")
const Fund = preload("res://scripts/level3/fund.gd")

const LINE := "Dann tanzen wir uns jetzt ganz unauffällig zum Ausgang."
const DANCE_TIME := 5.4           # seconds of dancing before the title comes by itself
const TITLE_TIME := 2.8           # seconds the title stays
const BEAT := 0.42                # seconds per dance step
const BAR_H := 62.0               # cinema bars, as in cutscene.gd
const TYPE_SPEED := 44.0
const NIGHT := Color("1a1433")
const WALL := Color("2a2150")
const FLOOR := Color("3a2a4d")
const SHADE := Color("110d22")
# the owner of the coat: his loden hangs in the cloakroom, he is in a dinner jacket
const PROF_LOOK := {"skin": "e6b894", "hair": "d8d4cc", "hair_style": "kurz", "top": "20222c", "top_style": "jacket",
	"accent": "f4f1ea", "pants": "20222c", "shoes": "0e0e12", "acc": ["glasses", "beard"]}

var looks: Array = [{}, {}]
var on_done: Callable = Callable()
var t := 0.0
var phase := "dance"              # dance, title
var phase_t := 0.0
var shown := 0.0
var ending := false
var root: Control
var canvas: Control
var caption: Control
var cap_l: Label
var title_box: Control


func _ready() -> void:
	layer = 30
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_advance())
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_scene)
	root.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# what player 1 says to it, typed, as a subtitle in the lower bar (the hall stays free)
	var col := Color(String(KEYS.TAG_COLORS[0]))
	caption = HBoxContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_constant_override("separation", 12)
	root.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	caption.offset_left = 28.0
	caption.offset_right = 960.0
	caption.offset_top = -BAR_H + 12.0
	caption.offset_bottom = -12.0
	caption.add_child(UI.label(Game.name_of(0) + ":", 22, col, 5))
	cap_l = UI.label(LINE, 22, UI.WHITE, 4)
	cap_l.visible_characters = 0
	caption.add_child(cap_l)
	var hint := UI.label("E / Enter weiter · Esc überspringen", 13, UI.MUTED)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -300.0
	hint.offset_top = -40.0
	hint.offset_right = -22.0
	hint.offset_bottom = -18.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.35)
	UI.sfx("whoosh", -8.0)


func play(done: Callable = Callable()) -> void:
	on_done = done


func _process(delta: float) -> void:
	if ending:
		return
	t += delta
	phase_t += delta
	canvas.queue_redraw()
	if phase == "dance":
		if t > 0.6 and cap_l.visible_characters >= 0:
			var before := int(shown)
			shown += delta * TYPE_SPEED
			if int(shown) >= cap_l.text.length():
				cap_l.visible_characters = -1
			elif int(shown) != before:
				cap_l.visible_characters = int(shown)
				if int(shown) % 3 == 0:
					UI.sfx("type", -18.0)
		if phase_t >= DANCE_TIME:
			_show_title()
	elif phase_t >= TITLE_TIME:
		_finish()


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


## First the rest of the line, then the title, then out.
func _advance() -> void:
	if ending:
		return
	if phase == "dance":
		if cap_l.visible_characters >= 0:
			cap_l.visible_characters = -1
		else:
			_show_title()
	elif phase_t > 0.5:
		_finish()


func _show_title() -> void:
	phase = "title"
	phase_t = 0.0
	caption.visible = false
	title_box = Control.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_box)
	title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.12, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.create_tween().tween_property(dim, "color:a", 0.55, 0.3)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(v)
	var big := UI.label("POLYBALL", 118, UI.YELLOW, 20)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var sub := UI.label("ein Badge wechselt den Besitzer", 28, UI.WHITE, 7)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	UI.pop_in(big, 0.0, 2.6)
	UI.pop_in(sub, 0.45, 0.6)
	UI.sfx("success", -4.0)
	var vs: Vector2 = root.size
	var tw := title_box.create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		UI.shake(v, 14.0)
		UI.confetti(title_box, Vector2(vs.x * 0.2, vs.y + 10), 90, true, 35.0, 1.25)
		UI.confetti(title_box, Vector2(vs.x * 0.8, vs.y + 10), 90, true, 35.0, 1.25))


func _finish() -> void:
	if ending:
		return
	ending = true
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if on_done.is_valid():
			on_done.call()
		queue_free())


# ------------------------------------------------------------------ drawing
func _hash(i: int) -> float:
	return fposmod(sin(i * 127.1 + 31.7) * 43758.5453, 1.0)


func _draw_scene() -> void:
	var vs: Vector2 = canvas.size
	var floor_y := vs.y * 0.66
	var beat := t / BEAT
	# hall: wall with tall arched windows, columns between them, parquet floor
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), NIGHT)
	canvas.draw_rect(Rect2(0, 0, vs.x, floor_y), WALL)
	var n_arch := 6
	var aw := vs.x / n_arch
	for i in n_arch:
		var ax := aw * (i + 0.5)
		var top := vs.y * 0.2
		var w := aw * 0.46
		canvas.draw_rect(Rect2(ax - w / 2.0, top, w, floor_y - top), Color("171233"))
		canvas.draw_circle(Vector2(ax, top), w / 2.0, Color("171233"))
		canvas.draw_line(Vector2(ax, top - w / 2.0), Vector2(ax, floor_y), Color(1, 1, 1, 0.05), 2.0)
		canvas.draw_rect(Rect2(aw * i - 9.0, vs.y * 0.12, 18.0, floor_y - vs.y * 0.12), Color("3b3068"))
	canvas.draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), FLOOR)
	for i in 14:
		var fx := vs.x * (i / 13.0)
		canvas.draw_line(Vector2(vs.x / 2.0 + (fx - vs.x / 2.0) * 0.55, floor_y), Vector2(vs.x / 2.0 + (fx - vs.x / 2.0) * 1.5, vs.y), Color(0, 0, 0, 0.16), 2.0)
	canvas.draw_rect(Rect2(0, floor_y - 3.0, vs.x, 6.0), Color("1c1538"))
	# the mirror ball and what it throws around the hall
	var ball := Vector2(vs.x / 2.0, vs.y * 0.2)
	canvas.draw_line(Vector2(ball.x, 0), ball, Color("0c0a18"), 3.0)
	for i in 7:
		var a := PI / 2.0 + sin(t * 0.7 + i * 1.3) * 0.95 + (i - 3) * 0.12
		var dirv := Vector2.from_angle(a)
		var sidev := Vector2(-dirv.y, dirv.x)
		var far := vs.y * 1.1
		var col := Color(String(UI.PARTY[i % 6]))
		canvas.draw_colored_polygon(PackedVector2Array([ball, ball + dirv * far + sidev * 70.0, ball + dirv * far - sidev * 70.0]), Color(col, 0.11))
	for i in 26:
		var a2 := t * (0.35 + _hash(i) * 0.3) + _hash(i + 50) * TAU
		var r := vs.x * (0.12 + _hash(i + 9) * 0.42)
		var p := ball + Vector2(cos(a2) * r, absf(sin(a2 * 0.7 + i)) * vs.y * 0.72)
		var colp := Color(String(UI.PARTY[i % 6]))
		canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.55 if p.y > floor_y else 1.0))
		canvas.draw_circle(Vector2.ZERO, 7.0 + _hash(i + 3) * 9.0, Color(colp, 0.2))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var br := 44.0
	canvas.draw_circle(ball, br, Color("8d93b8"))
	for row in 7:
		var ry := -br + (row + 0.5) * br * 2.0 / 7.0
		var half := sqrt(maxf(0.0, br * br - ry * ry))
		for cidx in 8:
			var u := fposmod(cidx / 8.0 + t * 0.11 + row * 0.07, 1.0)
			var x := -half + u * half * 2.0
			var lit := 0.35 + 0.65 * maxf(0.0, sin(t * 3.0 + row * 2.1 + cidx * 1.7))
			var s := 5.0 * (0.5 + 0.5 * sin(u * PI))
			canvas.draw_rect(Rect2(ball + Vector2(x - s / 2.0, ry - 3.5), Vector2(s, 7.0)), Color(1, 1, 1, 0.25 + 0.6 * lit))
	canvas.draw_arc(ball, br, 0.0, TAU, 40, Color("0c0a18"), 2.0, true)
	# the cloakroom at the back on the left, and somebody who misses something
	var gx := vs.x * 0.16
	canvas.draw_rect(Rect2(gx - 86.0, floor_y - 150.0, 172.0, 150.0), Color("120e26"))
	canvas.draw_rect(Rect2(gx - 86.0, floor_y - 176.0, 172.0, 26.0), Color("7a2f45"))
	_text(Vector2(gx, floor_y - 157.0), "GARDEROBE", 16, Color("f4f1ea"))
	canvas.draw_rect(Rect2(gx - 96.0, floor_y - 44.0, 192.0, 44.0), Color("4a3a2a"))
	canvas.draw_rect(Rect2(gx - 96.0, floor_y - 48.0, 192.0, 6.0), Color("6b5440"))
	var pat := sin(t * 9.0)
	ART.draw_character(canvas, PROF_LOOK, ART.FRONT, t * 9.0, true, Vector2(gx + pat * 3.0, floor_y - 40.0), 2.5)
	if fposmod(t, 1.7) < 1.25:
		var q := Vector2(gx + 44.0, floor_y - 150.0 - absf(sin(t * 3.7)) * 4.0)
		canvas.draw_circle(q, 17.0, Color("f4f1ea"))
		canvas.draw_colored_polygon(PackedVector2Array([q + Vector2(-12, 10), q + Vector2(-24, 26), q + Vector2(-2, 15)]), Color("f4f1ea"))
		_text(q + Vector2(0, 9), "?", 26, Color("23264a"))
	# the exit on the right
	var ex := Vector2(vs.x * 0.88, floor_y)
	canvas.draw_rect(Rect2(ex.x - 62.0, ex.y - 190.0, 124.0, 190.0), Color("0c0a18"))
	canvas.draw_rect(Rect2(ex.x - 54.0, ex.y - 182.0, 108.0, 182.0), Color("20305c"))
	var sign := Rect2(ex.x - 58.0, ex.y - 226.0, 116.0, 28.0)
	canvas.draw_rect(sign, Color("1f9d55").lerp(Color("5ee08f"), 0.5 + 0.5 * sin(t * 4.0)))
	_text(sign.get_center() + Vector2(0, 6), "AUSGANG →", 15, Color.WHITE)
	# the other guests: dark figures along the wall, moving with the music
	for i in 18:
		var cxp := vs.x * (0.27 + 0.53 * i / 17.0) + sin(i * 2.3) * 14.0
		var bob := absf(sin(beat * PI + i * 0.9)) * 7.0
		var hgt := 78.0 + _hash(i + 20) * 26.0
		var foot := floor_y + 6.0 + _hash(i + 30) * 16.0
		canvas.draw_rect(Rect2(cxp - 17.0, foot - hgt * 0.72 - bob, 34.0, hgt * 0.72 + bob), SHADE)
		canvas.draw_circle(Vector2(cxp, foot - hgt * 0.72 - bob - 13.0), 14.0, SHADE)
	# the two, dancing towards the exit: a step to the front, a step to the side, in turns
	var prog := clampf(t / (DANCE_TIME + TITLE_TIME), 0.0, 1.0)
	var along := lerpf(vs.x * 0.26, vs.x * 0.7, smoothstep(0.0, 1.0, prog))
	var step := int(beat)
	for j in 2:
		var order := 1 - j                                      # the one in front is drawn last
		var who := order
		var px := along - 150.0 * who + sin(beat * PI + who * 1.4) * 16.0
		var hop := absf(sin((beat + who * 0.5) * PI)) * 20.0
		var pos := Vector2(px, vs.y * 0.9 - hop)
		var face := ART.FRONT if (step + who) % 2 == 0 else ART.RIGHT
		canvas.draw_set_transform(Vector2(px, vs.y * 0.9), 0.0, Vector2(1.0, 0.3))
		canvas.draw_circle(Vector2.ZERO, 52.0 - hop * 0.8, Color(0, 0, 0, 0.32))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ART.draw_character(canvas, looks[who], face, beat * PI, true, pos, 6.0)
		if who == 0:
			# the badge on its strap, swinging from the hand in front
			var hand := pos + Vector2(52.0, -96.0)
			var swing := sin(beat * PI * 2.0) * 0.5
			canvas.draw_line(hand, hand + Vector2(sin(swing) * 26.0, 26.0), UI.ETH_BLUE, 4.0, true)
			canvas.draw_set_transform(hand + Vector2(sin(swing) * 26.0, 26.0), swing * 0.8, Vector2.ONE)
			Fund.draw_card(canvas, Rect2(-17, 0, 34, 48))
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var tw := maxf(0.0, sin(t * 5.0))
			if tw > 0.08:
				canvas.draw_colored_polygon(UI.star_points(hand + Vector2(30, 14), 12.0 * tw, 3.5 * tw, t), Color(1, 1, 1, 0.9))
	# cinema bars
	canvas.draw_rect(Rect2(0, 0, vs.x, BAR_H), Color.BLACK)
	canvas.draw_rect(Rect2(0, vs.y - BAR_H, vs.x, BAR_H), Color.BLACK)


func _text(center: Vector2, s: String, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, center - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
