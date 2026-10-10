extends CanvasLayer
## Small cutscene player in the style of the HUD: cinema bars, speech lines that type themselves,
## buzzing phones with a notification, an e-mail and a big title card. Reusable for every level.
##
##   var cs := Cutscene.new()
##   main.add_child(cs)
##   cs.play(steps, done)
##
## `steps` is an Array with one Dictionary per beat:
##   {"say": pid, "text": "..."}                      line of player pid (-1 = narrator)
##   {"phones": "sender", "text": "subject"}          both phones buzz and show a notification
##   {"mail": {"from": "", "to": "", "subject": "", "body": "", "footer": ""}}
##   {"title": "BIG", "sub": "small"}                 title card, optional "color" and "sfx"
## E / Enter / Space or a click: next beat. Esc: skip everything.

const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")
const BAR_H := 62.0
const INK := Color("1c1d33")
const INK2 := Color("3a4150")
const INK3 := Color("6b7385")

var steps: Array = []
var on_done: Callable = Callable()
var idx := -1
var root: Control
var stage: Control
var typed: Label = null   # label that is typing itself right now
var shown := 0.0
var type_speed := 46.0
var auto_t := -1.0        # > 0: next beat by itself after this many seconds
var ending := false


## Head and shoulders of a player, for speech lines.
class Portrait:
	extends Control
	const ART2 = preload("res://scripts/character_art.gd")
	var look: Dictionary = {}
	var col := Color.WHITE

	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, Color(col, 0.22))
		ART2.draw_character(self, look, ART2.FRONT, 0.0, false, Vector2(size.x / 2.0, size.y + 62.0), 3.4)


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
	# cinema bars slide in from the top and the bottom
	for i in 2:
		var bar := ColorRect.new()
		bar.color = UI.DARK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bar)
		bar.anchor_right = 1.0
		bar.anchor_top = float(i)
		bar.anchor_bottom = float(i)
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		var tw := bar.create_tween()
		if i == 0:
			tw.tween_property(bar, "offset_bottom", BAR_H, 0.4).set_trans(Tween.TRANS_SINE)
		else:
			tw.tween_property(bar, "offset_top", -BAR_H, 0.4).set_trans(Tween.TRANS_SINE)
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


func play(p_steps: Array, done: Callable = Callable()) -> void:
	steps = p_steps
	on_done = done
	idx = -1
	_next()


func _next() -> void:
	if ending:
		return
	idx += 1
	for c in stage.get_children():
		c.queue_free()
	typed = null
	auto_t = -1.0
	type_speed = 46.0
	if idx >= steps.size():
		_finish()
		return
	var st: Dictionary = steps[idx]
	if st.has("say"):
		_show_say(st)
	elif st.has("phones"):
		_show_phones(st)
	elif st.has("mail"):
		_show_mail(st)
	elif st.has("title"):
		_show_title(st)
	else:
		_next()


func _advance() -> void:
	if ending:
		return
	if typed != null and typed.visible_characters >= 0:
		typed.visible_characters = -1   # first press: show the whole text
		return
	_next()


func _finish() -> void:
	if ending:
		return
	ending = true
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		if on_done.is_valid():
			on_done.call()
		queue_free())


func _type(l: Label, speed: float = 46.0) -> void:
	typed = l
	shown = 0.0
	type_speed = speed
	l.visible_characters = 0


func _process(delta: float) -> void:
	if ending:
		return
	if typed != null and typed.visible_characters >= 0:
		var before := int(shown)
		shown += delta * type_speed
		if int(shown) >= typed.text.length():
			typed.visible_characters = -1
		elif int(shown) != before:
			typed.visible_characters = int(shown)
			if int(shown) % 3 == 0:
				UI.sfx("type", -18.0)
	elif auto_t > 0.0:
		auto_t -= delta
		if auto_t <= 0.0:
			_next()


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


func _center() -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = BAR_H
	cc.offset_bottom = -BAR_H
	return cc


# ------------------------------------------------------------------ speech line
func _show_say(st: Dictionary) -> void:
	var pid: int = st["say"]
	var col := UI.YELLOW if pid < 0 else Color(KEYS.TAG_COLORS[pid])
	var card := UI.panel(UI.NAVY, col, 22, 14)
	stage.add_child(card)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -410.0
	card.offset_right = 410.0
	card.offset_bottom = -(BAR_H + 24.0)
	card.offset_top = card.offset_bottom - 132.0
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	card.add_child(h)
	if pid >= 0:
		var por := Portrait.new()
		por.look = Game.player_looks[pid]
		por.col = col
		por.custom_minimum_size = Vector2(96, 96)
		por.clip_contents = true
		por.mouse_filter = Control.MOUSE_FILTER_IGNORE
		por.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(por)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(String(st.get("name", "")) if pid < 0 else Game.name_of(pid), 20, col, 5))
	var l := UI.label(String(st["text"]), 22, UI.WHITE, 0, true)
	l.custom_minimum_size = Vector2(620, 66)
	v.add_child(l)
	_type(l)
	UI.pop_in(card, 0.0, 0.8)
	UI.sfx("pop", -10.0)


# ------------------------------------------------------------------ buzzing phones
func _show_phones(st: Dictionary) -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	for i in 2:
		var col := Color(KEYS.TAG_COLORS[i])
		var ph := PanelContainer.new()
		ph.add_theme_stylebox_override("panel", UI.box(UI.DARK, col, 30, 5, 16))
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.custom_minimum_size = Vector2(330, 250)
		stage.add_child(ph)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		ph.add_child(v)
		var top := HBoxContainer.new()
		v.add_child(top)
		var clock := UI.label("12:47", 16, UI.WHITE)
		clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(clock)
		top.add_child(UI.label("Handy von %s" % Game.name_of(i), 13, col))
		var big := UI.label("12:47", 54, UI.WHITE)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(big)
		var note := PanelContainer.new()
		note.add_theme_stylebox_override("panel", UI.box(Color("f4f6fa"), Color("dfe3ec"), 14, 2, 10, false))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(note)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 2)
		note.add_child(nv)
		nv.add_child(UI.label("E-MAIL   ·   jetzt", 12, INK3))
		nv.add_child(UI.label(String(st["phones"]), 16, INK))
		var body := UI.label(String(st["text"]), 15, INK2, 0, true)
		body.custom_minimum_size = Vector2(270, 0)
		nv.add_child(body)
		# slide up from below the screen, then buzz twice
		var home := Vector2(vs.x * (0.28 + 0.44 * i) - 165.0, vs.y * 0.5 - 150.0)
		ph.position = Vector2(home.x, vs.y + 30.0)
		ph.rotation = -0.05 + 0.1 * i
		var tw := ph.create_tween()
		tw.tween_property(ph, "position", home, 0.35).set_delay(0.12 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for k in 2:
			tw.tween_callback(func(): UI.shake(ph, 11.0))
			tw.tween_interval(0.32)
	UI.sfx("buzz", -3.0)
	get_tree().create_timer(0.95).timeout.connect(func(): UI.sfx("mail"))
	auto_t = float(st.get("time", 3.6))


# ------------------------------------------------------------------ e-mail
func _show_mail(st: Dictionary) -> void:
	var m: Dictionary = st["mail"]
	var win := PanelContainer.new()
	win.add_theme_stylebox_override("panel", UI.box(Color("f4f6fa"), UI.DARK, 16, 4, 0))
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center().add_child(win)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	win.add_child(outer)
	# ETH-style header band, like the application portal in the intro
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = UI.ETH_BLUE
	hsb.corner_radius_top_left = 12
	hsb.corner_radius_top_right = 12
	hsb.content_margin_left = 28
	hsb.content_margin_right = 28
	hsb.content_margin_top = 12
	hsb.content_margin_bottom = 12
	head.add_theme_stylebox_override("panel", hsb)
	outer.add_child(head)
	var hh := HBoxContainer.new()
	head.add_child(hh)
	var logo := UI.label("ETH zürich", 28, UI.WHITE)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(logo)
	hh.add_child(UI.label("Posteingang · 1 neue Nachricht", 15, Color(1, 1, 1, 0.85)))
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 30)
	mc.add_theme_constant_override("margin_right", 30)
	mc.add_theme_constant_override("margin_top", 18)
	mc.add_theme_constant_override("margin_bottom", 20)
	outer.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	mc.add_child(v)
	var subject := UI.label(String(m.get("subject", "")), 25, INK, 0, true)
	subject.custom_minimum_size = Vector2(700, 0)
	v.add_child(subject)
	v.add_child(UI.label("Von:  %s" % m.get("from", ""), 15, INK3))
	v.add_child(UI.label("An:  %s" % m.get("to", ""), 15, INK3))
	var line := ColorRect.new()
	line.color = Color("dfe3ec")
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	var body := UI.label(String(m.get("body", "")), 17, INK2, 0, true)
	body.custom_minimum_size = Vector2(700, 0)
	v.add_child(body)
	if m.has("footer"):
		var foot := PanelContainer.new()
		foot.add_theme_stylebox_override("panel", UI.box(Color("e3e6ee"), Color("c9cedb"), 10, 2, 6, false))
		foot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		foot.add_child(UI.label(String(m["footer"]), 15, Color("9aa3b5")))
		v.add_child(foot)
	_type(body, 150.0)
	UI.pop_in(win, 0.0, 0.85)
	UI.sfx("whoosh", -8.0)


# ------------------------------------------------------------------ title card
func _show_title(st: Dictionary) -> void:
	var col: Color = st.get("color", UI.RED)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.12, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_top = BAR_H
	dim.offset_bottom = -BAR_H
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center().add_child(v)
	var big := UI.label(String(st["title"]), 112, col, 20)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var sub := UI.label(String(st.get("sub", "")), 26, UI.WHITE, 7)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	UI.pop_in(big, 0.0, 2.4)
	UI.pop_in(sub, 0.5, 0.6)
	UI.sfx(String(st.get("sfx", "doom")), -3.0)
	var tw := v.create_tween()   # bound to the card, so it stops when the beat is skipped
	tw.tween_interval(0.45)
	tw.tween_callback(func(): UI.shake(v, 16.0))
	auto_t = float(st.get("time", 4.5))
