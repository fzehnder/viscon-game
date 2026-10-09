extends Control
## Start screen: pick a department, design the character, choose day or night.

const CH = preload("res://scripts/characters.gd")
const ART = preload("res://scripts/character_art.gd")

const INK := Color("eef1ea")
const MUTED := Color("a6b5c0")
const SIGNAL := Color("f2c14e")
const PANEL := Color(0.09, 0.12, 0.16, 0.94)
const LINE := Color(0.23, 0.3, 0.36)

var preview: Control
var dept_btns := {}
var mode_btns := {}
var name_l: Label
var full_l: Label
var tag_l: Label
var ability_l: Label
var mission_l: Label
var swatches := {}
var t := 0.0


class Preview:
	extends Control
	const ART2 = preload("res://scripts/character_art.gd")
	var look: Dictionary = {}
	var accent := Color.WHITE
	var t := 0.0
	var facing := 0
	var manual := false

	func _process(delta: float) -> void:
		t += delta
		if not manual and int(t / 1.6) % 4 != facing:
			facing = int(t / 1.6) % 4
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y * 0.82)
		var sc := minf(size.y / 60.0, 6.5)
		# podium
		var pts := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			pts.append(c + Vector2(cos(a) * 26 * sc, sin(a) * 8 * sc))
		draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.18))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(accent.r, accent.g, accent.b, 0.6), 2.0)
		var order := [0, 3, 1, 2]
		ART2.draw_character(self, look, order[facing], t * 7.0, true, c, sc)


func _style(bg: Color, border: Color, pad: float = 8.0, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


func _label(text: String, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _style(Color(0.13, 0.17, 0.22), LINE))
	b.add_theme_stylebox_override("hover", _style(Color(0.17, 0.22, 0.29), Color(0.4, 0.5, 0.6)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.2, 0.26, 0.34), SIGNAL))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	return b


func _section(text: String) -> Label:
	var l := _label(text, 12, MUTED)
	return l


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("121a22")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.draw.connect(func():
		var s := 32.0
		var x := 0.0
		while x < bg.size.x:
			bg.draw_line(Vector2(x, 0), Vector2(x, bg.size.y), Color(0.42, 0.6, 0.88, 0.06), 1.0)
			x += s
		var y := 0.0
		while y < bg.size.y:
			bg.draw_line(Vector2(0, y), Vector2(bg.size.x, y), Color(0.42, 0.6, 0.88, 0.06), 1.0)
			y += s)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	# ---- left: preview
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.85
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	left.add_child(_label("ETH ZENTRUM", 14, Color("6a9be0")))
	left.add_child(_label("Tag & Nacht", 44, INK))
	preview = Preview.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(300, 300)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(preview)
	name_l = _label("", 30, INK)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(name_l)
	tag_l = _label("", 15, MUTED)
	tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(tag_l)
	var turn := HBoxContainer.new()
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(turn)
	var tl := _button("< drehen", 13)
	tl.pressed.connect(func(): _turn(-1))
	turn.add_child(tl)
	var tr2 := _button("drehen >", 13)
	tr2.pressed.connect(func(): _turn(1))
	turn.add_child(tr2)

	# ---- right: choices
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	scroll.add_child(right)

	right.add_child(_section("1 · DEPARTEMENT"))
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 8)
	right.add_child(dr)
	for d in CH.DEPT_ORDER:
		var b := _button(d, 20)
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _pick_dept(d))
		dr.add_child(b)
		dept_btns[d] = b
	full_l = _label("", 15, INK)
	right.add_child(full_l)

	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", _style(PANEL, LINE, 10))
	right.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	info.add_child(iv)
	ability_l = _label("", 14, INK, true)
	ability_l.custom_minimum_size = Vector2(380, 0)
	iv.add_child(ability_l)
	mission_l = _label("", 14, Color("d7dee3"), true)
	mission_l.custom_minimum_size = Vector2(380, 0)
	iv.add_child(mission_l)

	right.add_child(_section("2 · AUSSEHEN"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	right.add_child(grid)
	var rows := [["hair_style", "Frisur", CH.HAIR_STYLES], ["hair", "Haarfarbe", CH.HAIR_COLORS], ["skin", "Hautton", CH.SKIN_TONES],
		["top", "Oberteil", CH.TOP_COLORS], ["pants", "Hose", CH.PANTS_COLORS]]
	for r in rows:
		var key: String = r[0]
		var opts: Array = r[2]
		var nl := _label(r[1], 14, MUTED)
		nl.custom_minimum_size = Vector2(90, 0)
		grid.add_child(nl)
		var prev := _button("<", 14)
		prev.pressed.connect(func(): _cycle(key, opts, -1))
		grid.add_child(prev)
		var sw := PanelContainer.new()
		sw.custom_minimum_size = Vector2(150, 30)
		var swl := _label("", 14, INK)
		swl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sw.add_child(swl)
		grid.add_child(sw)
		swatches[key] = [sw, swl]
		var nxt := _button(">", 14)
		nxt.pressed.connect(func(): _cycle(key, opts, 1))
		grid.add_child(nxt)
	var reset := _button("Original-Look", 13)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func():
		Game.reset_look(Game.dept)
		_refresh())
	right.add_child(reset)

	right.add_child(_section("3 · TAGESZEIT"))
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 8)
	right.add_child(mr)
	for m in [["day", "TAG · Aufgaben unter Zeitdruck"], ["night", "NACHT · Einbruch ins Labor"]]:
		var mb := _button(m[1], 15)
		mb.custom_minimum_size = Vector2(0, 42)
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mid: String = m[0]
		mb.pressed.connect(func():
			Game.mode = mid
			_refresh())
		mr.add_child(mb)
		mode_btns[mid] = mb

	var play := _button("SPIELEN", 22)
	play.custom_minimum_size = Vector2(0, 54)
	play.add_theme_stylebox_override("normal", _style(Color("215caf"), Color("6a9be0")))
	play.add_theme_stylebox_override("hover", _style(Color("2a6cc8"), Color("8db4ea")))
	play.pressed.connect(_start)
	right.add_child(play)
	right.add_child(_label("Tasten: 1 2 3 Departement · T / N Tageszeit · Enter spielen", 12, MUTED))
	_refresh()


func _turn(dir: int) -> void:
	preview.manual = true
	preview.facing = (preview.facing + dir + 4) % 4


func _pick_dept(d: String) -> void:
	Game.dept = d
	_refresh()


func _cycle(key: String, opts: Array, dir: int) -> void:
	var lk: Dictionary = Game.look()
	var i := opts.find(lk.get(key, opts[0]))
	i = (i + dir + opts.size()) % opts.size()
	lk[key] = opts[i]
	if key == "top" and lk.get("top_style", "") == "overall":
		lk["pants"] = opts[i]
	_refresh()


func _refresh() -> void:
	var d: Dictionary = CH.DEPTS[Game.dept]
	var accent := Color(d["accent"])
	preview.look = Game.look()
	preview.accent = accent
	name_l.text = "%s · %s" % [d["char"], Game.dept]
	tag_l.text = d["tag"]
	full_l.text = "Departement %s" % d["full"]
	var ab: Dictionary = d["ability"]
	ability_l.text = "Fähigkeit (Nacht, Taste Q): %s – %s" % [ab["name"], ab["desc"]]
	mission_l.text = ("Nacht-Mission: " + d["night_text"]) if Game.mode == "night" else ("Tagesaufgaben: " + d["day_text"])
	for k in dept_btns:
		var on: bool = k == Game.dept
		dept_btns[k].add_theme_stylebox_override("normal", _style(Color(accent.r, accent.g, accent.b, 0.35) if on else Color(0.13, 0.17, 0.22), accent if on else LINE))
	for k in mode_btns:
		var on2: bool = k == Game.mode
		mode_btns[k].add_theme_stylebox_override("normal", _style(Color(0.95, 0.76, 0.3, 0.28) if on2 else Color(0.13, 0.17, 0.22), SIGNAL if on2 else LINE))
	var lk: Dictionary = Game.look()
	for key in swatches:
		var sw: PanelContainer = swatches[key][0]
		var swl: Label = swatches[key][1]
		if key == "hair_style":
			sw.add_theme_stylebox_override("panel", _style(Color(0.13, 0.17, 0.22), LINE, 4))
			swl.text = String(lk.get(key, "kurz")).capitalize()
		else:
			var c := Color(String(lk.get(key, "888888")))
			sw.add_theme_stylebox_override("panel", _style(c, LINE, 4))
			swl.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _pick_dept("MAVT")
			KEY_2: _pick_dept("ITET")
			KEY_3: _pick_dept("D-INFK")
			KEY_T:
				Game.mode = "day"
				_refresh()
			KEY_N:
				Game.mode = "night"
				_refresh()
			KEY_LEFT: _turn(-1)
			KEY_RIGHT: _turn(1)
			KEY_ENTER, KEY_KP_ENTER: _start()


func _start() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
