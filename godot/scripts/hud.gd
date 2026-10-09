extends CanvasLayer
## Screen overlay: place + mission, detection meter or day timer, ability, prompts, messages,
## ping arrows, blackout tint and the start/end screens.

const CH = preload("res://scripts/characters.gd")
const INK := Color("eef1ea")
const MUTED := Color("a6b5c0")
const SIGNAL := Color("f2c14e")
const OKC := Color("86c97f")
const ALERT := Color("ff5a4e")

var main
var zone_l: Label
var clock_l: Label
var obj_box: VBoxContainer
var obj_l: Array = []
var meter_title: Label
var meter_fill: ColorRect
var meter_l: Label
var status_l: Label
var ab_name: Label
var ab_fill: ColorRect
var prompt_p: PanelContainer
var prompt_l: Label
var toast_p: PanelContainer
var toast_h: Label
var toast_b: Label
var toast_t := 0.0
var overlay: Control
var ov_title: Label
var ov_body: Label
var ov_hint: Label
var ov_btn: Button
var ov_menu: Button
var blackout: ColorRect
var arrows: Control


func _style(bg: Color, border: Color, pad: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad + 1
	return sb


func _panel(pad: float = 8.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.09, 0.12, 0.16, 0.9), Color(0.23, 0.3, 0.36), pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(190, 42)
	b.add_theme_font_size_override("font_size", 17)
	var bg := Color("215caf") if primary else Color(0.15, 0.2, 0.26)
	var br := Color("6a9be0") if primary else Color(0.3, 0.38, 0.46)
	b.add_theme_stylebox_override("normal", _style(bg, br, 8))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.1), br.lightened(0.2), 8))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.1), br, 8))
	return b


func _bar(w: float, fill_col: Color) -> Array:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(w, 8)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.12)
	bg.size = Vector2(w, 8)
	bar.add_child(bg)
	var f := ColorRect.new()
	f.color = fill_col
	f.size = Vector2(0, 8)
	bar.add_child(f)
	return [bar, f]


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	blackout = ColorRect.new()
	blackout.color = Color(0.01, 0.02, 0.06, 0.5)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(blackout)
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout.visible = false

	arrows = Control.new()
	arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arrows)
	arrows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arrows.draw.connect(_draw_arrows)

	var d: Dictionary = CH.DEPTS[main.dept]
	var accent := Color(d["accent"])

	# top-left
	var tl := _panel()
	root.add_child(tl)
	tl.position = Vector2(16, 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	tl.add_child(v)
	clock_l = _label("", 12, MUTED)
	v.add_child(clock_l)
	zone_l = _label("", 24, INK)
	v.add_child(zone_l)
	var who := _label("%s · %s · %s" % [d["char"], main.dept, "Nacht" if main.night else "Tag"], 13, accent)
	v.add_child(who)
	v.add_child(HSeparator.new())
	v.add_child(_label("AUFTRAG", 12, MUTED))
	obj_box = VBoxContainer.new()
	obj_box.add_theme_constant_override("separation", 2)
	v.add_child(obj_box)

	# top-right
	var trp := _panel()
	root.add_child(trp)
	trp.anchor_left = 1.0
	trp.anchor_right = 1.0
	trp.offset_left = -240
	trp.offset_right = -16
	trp.offset_top = 14
	trp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 5)
	trp.add_child(v2)
	meter_title = _label("SICHTBARKEIT" if main.night else "VERBLEIBENDE ZEIT", 12, MUTED)
	v2.add_child(meter_title)
	meter_l = _label("", 22, OKC)
	v2.add_child(meter_l)
	var mb := _bar(200, OKC)
	v2.add_child(mb[0])
	meter_fill = mb[1]
	status_l = _label("", 13, MUTED)
	v2.add_child(status_l)

	# bottom-left: ability
	var ab := _panel()
	root.add_child(ab)
	ab.anchor_top = 1.0
	ab.anchor_bottom = 1.0
	ab.offset_left = 16
	ab.offset_top = -78
	ab.offset_bottom = -16
	ab.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 4)
	ab.add_child(av)
	var ah := HBoxContainer.new()
	ah.add_theme_constant_override("separation", 8)
	av.add_child(ah)
	var key := PanelContainer.new()
	key.add_theme_stylebox_override("panel", _style(accent, accent.lightened(0.3), 2))
	key.add_child(_label("Q", 14, Color("1a1a1a")))
	ah.add_child(key)
	ab_name = _label(d["ability"]["name"], 15, INK)
	ah.add_child(ab_name)
	var abb := _bar(210, accent)
	av.add_child(abb[0])
	ab_fill = abb[1]

	# bottom-centre: prompt
	prompt_p = _panel(6)
	root.add_child(prompt_p)
	prompt_p.anchor_left = 0.5
	prompt_p.anchor_right = 0.5
	prompt_p.anchor_top = 1.0
	prompt_p.anchor_bottom = 1.0
	prompt_p.offset_top = -60
	prompt_p.offset_bottom = -22
	prompt_p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	prompt_p.add_child(hb)
	var ek := PanelContainer.new()
	ek.add_theme_stylebox_override("panel", _style(SIGNAL, Color("b38b2c"), 2))
	ek.add_child(_label("E", 15, Color("2a2410")))
	hb.add_child(ek)
	prompt_l = _label("", 17, INK)
	hb.add_child(prompt_l)
	prompt_p.visible = false

	# toast
	toast_p = _panel(10)
	root.add_child(toast_p)
	toast_p.anchor_left = 0.5
	toast_p.anchor_right = 0.5
	toast_p.anchor_top = 1.0
	toast_p.anchor_bottom = 1.0
	toast_p.offset_left = -250
	toast_p.offset_right = 250
	toast_p.offset_bottom = -74
	toast_p.offset_top = -160
	toast_p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var tv := VBoxContainer.new()
	toast_p.add_child(tv)
	toast_h = _label("", 17, SIGNAL)
	tv.add_child(toast_h)
	toast_b = _label("", 15, INK)
	toast_b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_b.custom_minimum_size = Vector2(470, 0)
	tv.add_child(toast_b)
	toast_p.visible = false

	# overlay
	overlay = Control.new()
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.72)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	overlay.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var op := _panel(22)
	op.mouse_filter = Control.MOUSE_FILTER_STOP
	cc.add_child(op)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 12)
	op.add_child(ov)
	ov.add_child(_label("ETH ZENTRUM · TAG & NACHT", 13, Color("6a9be0")))
	ov_title = _label("", 42, INK)
	ov.add_child(ov_title)
	ov_body = _label("", 16, Color("d7dee3"))
	ov_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov_body.custom_minimum_size = Vector2(580, 0)
	ov.add_child(ov_body)
	ov_hint = _label("", 15, SIGNAL)
	ov_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov_hint.custom_minimum_size = Vector2(580, 0)
	ov.add_child(ov_hint)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	ov.add_child(brow)
	ov_btn = _btn("", true)
	ov_btn.pressed.connect(func(): main.on_overlay_button())
	brow.add_child(ov_btn)
	ov_menu = _btn("Zum Menü", false)
	ov_menu.pressed.connect(func(): main.on_overlay_menu())
	brow.add_child(ov_menu)


func show_overlay(title: String, body: String, hint: String, button: String, with_menu: bool = false) -> void:
	ov_title.text = title
	ov_body.text = body
	ov_hint.text = hint
	ov_btn.text = button
	ov_menu.visible = with_menu
	overlay.visible = true


func hide_overlay() -> void:
	overlay.visible = false


func toast(head: String, body: String, dur: float = 5.0) -> void:
	toast_h.text = head
	toast_b.text = body
	toast_p.visible = true
	toast_t = dur


func refresh(delta: float) -> void:
	var tp: float = main.time_played
	if main.night:
		var mins := 30 + int(tp / 4.0)
		clock_l.text = "ETH ZENTRUM · %02d:%02d UHR" % [mins / 60, mins % 60]
	else:
		var mins2 := 10 * 60 + 15 + int(tp / 2.0)
		clock_l.text = "ETH ZENTRUM · %02d:%02d UHR" % [mins2 / 60, mins2 % 60]
	zone_l.text = main.zone
	var objs: Array = main.objectives()
	while obj_l.size() < objs.size():
		var l := _label("", 15, INK)
		obj_box.add_child(l)
		obj_l.append(l)
	for i in obj_l.size():
		var l: Label = obj_l[i]
		if i >= objs.size():
			l.visible = false
			continue
		var o: Array = objs[i]
		l.visible = true
		l.text = ("[x] " if o[1] else "[ ] ") + o[0]
		l.label_settings.font_color = MUTED if o[1] else (INK if o[2] else Color(0.65, 0.7, 0.75, 0.45))

	var pl = main.player
	if main.night:
		var m: float = main.max_meter()
		meter_fill.size = Vector2(200.0 * m, 8)
		var c := OKC
		var txt := "UNENTDECKT"
		if m >= 0.6:
			c = ALERT
			txt = "ENTDECKT!"
		elif m > 0.05:
			c = SIGNAL
			txt = "VERDÄCHTIG"
		meter_l.text = txt
		meter_l.label_settings.font_color = c
		meter_fill.color = c
		if pl.hidden_mode:
			status_l.text = "Versteckt · E zum Verlassen"
		elif pl.sneaking:
			status_l.text = "Schleichen · lautlos"
		elif pl.moving:
			status_l.text = "Gehen · man hört dich"
		else:
			status_l.text = "Shift halten zum Schleichen"
	else:
		var left: float = main.time_left()
		var frac: float = left / main.day_total()
		meter_l.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
		var c2 := OKC if frac > 0.4 else (SIGNAL if frac > 0.15 else ALERT)
		meter_l.label_settings.font_color = c2
		meter_fill.color = c2
		meter_fill.size = Vector2(200.0 * frac, 8)
		status_l.text = "Fehler bisher: %d" % main.mistakes_total

	var cd: float = main.cooldown
	var total: float = main.ability["cooldown"]
	ab_fill.size = Vector2(210.0 * (1.0 - cd / total), 8)
	if not main.night:
		ab_name.text = main.ability["name"] + " (nur nachts)"
	elif cd > 0.0:
		ab_name.text = "%s · %ds" % [main.ability["name"], ceili(cd)]
	else:
		ab_name.text = main.ability["name"] + " · bereit"

	if main.state == "play" and pl.hidden_mode:
		prompt_p.visible = true
		prompt_l.text = "Versteck verlassen"
	elif main.state == "play" and main.near != null:
		prompt_p.visible = true
		prompt_l.text = main.near["label"]
	else:
		prompt_p.visible = false
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			toast_p.visible = false
	blackout.visible = main.blackout_t > 0.0
	arrows.queue_redraw()


func _draw_arrows() -> void:
	if main.ping_t <= 0.0:
		return
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var vs: Vector2 = arrows.size
	var font := ThemeDB.fallback_font
	var centre := vs / 2.0
	for p in main.profs:
		var sp: Vector2 = xf * (p.global_position as Vector2)
		var on_screen := Rect2(Vector2(40, 40), vs - Vector2(80, 80)).has_point(sp)
		var d_tiles := int((p.global_position as Vector2).distance_to(main.player.global_position) / 32.0)
		var label: String = "%s · %d m" % [String(p.pname).replace("Prof. Dr. ", ""), d_tiles * 2]
		if on_screen:
			arrows.draw_arc(sp + Vector2(0, -26), 28.0, 0.0, TAU, 32, Color("6a9be0"), 2.0)
			arrows.draw_string(font, sp + Vector2(-40, -62), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("cfe0f7"))
			continue
		var dirv := (sp - centre).normalized()
		var edge := centre + dirv * minf(absf((vs.x / 2.0 - 46) / dirv.x) if absf(dirv.x) > 0.001 else 1e9,
			absf((vs.y / 2.0 - 46) / dirv.y) if absf(dirv.y) > 0.001 else 1e9)
		var pv := Vector2(-dirv.y, dirv.x)
		arrows.draw_colored_polygon(PackedVector2Array([edge + dirv * 16, edge - dirv * 8 + pv * 11, edge - dirv * 8 - pv * 11]), Color("6a9be0"))
		arrows.draw_string(font, edge - dirv * 30 + Vector2(-36, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("cfe0f7"))
