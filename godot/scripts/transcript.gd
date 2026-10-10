extends Control
## Level overview in the look of the myStudies page "Leistungsüberblick" (transcript of records).
## Every level is a course: number, name, session, grade, weight. The courses sit in the blocks of
## the Basisprüfung, the later study years are listed but stay empty. A click on a course starts
## that level (without the story intro).
##
## A level can set "course" (course number), "ects" (credit points, also the weight of its grade)
## and "block" ("A" or "B") in its DEF. Without them the values follow from the level number.
## Grades come from Game.grades: the best grade per level, written by main.gd when a level is won.

signal start_level(n: int)
signal back

const UI = preload("res://scripts/ui.gd")
const LV = preload("res://scripts/levels.gd")

const PASS := 4.0                 # credits from this grade on
const SESSION := "W27"            # the game plays in autumn 2026, that counts for the winter session
const DEFAULT_ECTS := 6
const PROGRAMME := "Bachelor-Studiengang Tag & Nacht"
const URL := "lehrbetrieb.ethz.ch"
# study years the game does not reach: [category, required credits]
const LATER := [
	["Obligatorische Fächer des 2. und 3. Studienjahres", 52],
	["Projekt", 3],
	["Wahlfächer", 24],
	["Fokus und Bachelor-Arbeit", 36],
	["Wissenschaft im Kontext", 6],
]

const INK := Color("1a1a1a")
const TITLE_BLUE := Color("1f407a")
const LINK := Color("0d67bd")
const CRUMB_GREEN := Color("6fa800")
const BAR := Color("33383d")
const GREY := Color("eeeeee")
const LINE := Color("d2d2d2")
const DIFF_RED := Color("d40000")
const HILITE := Color("e2edfa")
const FONTS := ["Arial", "Helvetica Neue", "Helvetica", "Liberation Sans", "sans-serif"]
const DAYS := ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
const MONTHS := ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sept.", "Okt.", "Nov.", "Dez."]

var reg: SystemFont
var bold: SystemFont
var table: Table
var scroll: ScrollContainer
var inner: Control
var start_btn: Button
var order: Array = []     # level numbers from top to bottom
var sel := 1


## Hand-drawn parts of the page: text on whole pixels, hairlines, the little triangles.
class Sheet:
	extends Control
	var reg: Font
	var bold: Font

	func width(f: Font, s: String, fs: int) -> float:
		return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

	## Text in a line of height `h` that starts at `y`; with `right` the text ends at `x`.
	func put(f: Font, s: String, x: float, y: float, h: float, fs: int, col: Color, right: bool = false) -> void:
		if s == "":
			return
		if right:
			x -= width(f, s, fs)
		var base := y + (h + f.get_ascent(fs) - f.get_descent(fs)) / 2.0
		draw_string(f, Vector2(roundf(x), roundf(base)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func hline(y: float, col: Color) -> void:
		draw_rect(Rect2(0.0, y, size.x, 1.0), col)

	func tri(x: float, cy: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(x, cy - 4.5), Vector2(x + 5.5, cy), Vector2(x, cy + 4.5)]), col)


## Browser bar and the green breadcrumb below it.
class Head:
	extends Sheet
	const BAR_H := 30.0
	const CRUMB_H := 26.0
	const CRUMBS := ["Willkommen", "Studium", "Leistungsüberblick"]
	var clock := ""
	var who := ""

	func _init() -> void:
		custom_minimum_size = Vector2(0, BAR_H + CRUMB_H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, BAR_H), BAR)
		put(bold, clock, 16.0, 0.0, BAR_H, 14, Color.WHITE)
		put(reg, URL, (size.x - width(reg, URL, 14)) / 2.0, 0.0, BAR_H, 14, Color.WHITE)
		put(reg, who, size.x - 16.0, 0.0, BAR_H, 14, Color.WHITE, true)
		var w := 2.0
		for c in CRUMBS:
			w += width(bold, c, 13) + 26.0
		draw_rect(Rect2(0, BAR_H, w, CRUMB_H), CRUMB_GREEN)
		var x := 14.0
		for i in CRUMBS.size():
			var last := i == CRUMBS.size() - 1
			put(bold, CRUMBS[i], x, BAR_H, CRUMB_H, 13, Color.WHITE if last else INK)
			x += width(bold, CRUMBS[i], 13) + 10.0
			if not last:
				tri(x, BAR_H + CRUMB_H / 2.0, Color.WHITE)
				x += 16.0


## The table. Rows are dictionaries: "text", optional "code" (course number, then "text" is the
## course name), "x" (indent), "tri" (triangles in front), "bold", the cells "sess", "grade", "wgt",
## "obt", "req", "diff", and "level" on rows that start a level.
class Table:
	extends Sheet
	signal chosen(level: int)
	const ROW_H := 25.0
	const HEAD_H := 46.0
	const FS := 15
	const X_NAME := 250.0
	# columns, measured from the right edge: the first three start there, the credits end there
	const C_SESS := -400.0
	const C_GRADE := -330.0
	const C_WGT := -262.0
	const C_OBT := -150.0
	const C_REQ := -78.0
	const C_DIFF := -10.0
	var rows: Array = []
	var sel := 0
	var hover := -1

	func _init() -> void:
		mouse_exited.connect(func(): _set_hover(-1))

	func set_rows(r: Array) -> void:
		rows = r
		custom_minimum_size = Vector2(0, HEAD_H + rows.size() * ROW_H + 1.0)
		queue_redraw()

	func row_y(level: int) -> float:
		for i in rows.size():
			if int(rows[i].get("level", 0)) == level:
				return HEAD_H + i * ROW_H
		return 0.0

	func _row_at(y: float) -> int:
		var i := int(floor((y - HEAD_H) / ROW_H))
		return i if y >= HEAD_H and i < rows.size() else -1

	func _level_at(i: int) -> int:
		return int(rows[i].get("level", 0)) if i >= 0 else 0

	func _set_hover(i: int) -> void:
		if i == hover:
			return
		hover = i
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _level_at(i) > 0 else Control.CURSOR_ARROW
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_set_hover(_row_at(event.position.y))
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var n := _level_at(_row_at(event.position.y))
			if n > 0:
				chosen.emit(n)

	func _draw() -> void:
		var w := size.x
		var half := HEAD_H / 2.0
		draw_rect(Rect2(0, 0, w, HEAD_H), GREY)
		hline(0.0, LINE)
		hline(half, LINE)
		put(bold, "Sess.", w + C_SESS, 0.0, half, 13, INK)
		put(bold, "Note", w + C_GRADE, 0.0, half, 13, INK)
		put(bold, "Gew.", w + C_WGT, 0.0, half, 13, INK)
		put(bold, "ECTS-Kreditpunkte", w + C_OBT - 62.0, 0.0, half, 13, INK)
		put(bold, "Erw.", w + C_OBT, half, half, 13, INK, true)
		put(bold, "Erf.", w + C_REQ, half, half, 13, INK, true)
		put(bold, "Diff.", w + C_DIFF, half, half, 13, INK, true)
		hline(HEAD_H, INK)
		for i in rows.size():
			var r: Dictionary = rows[i]
			var y := HEAD_H + i * ROW_H
			var n := int(r.get("level", 0))
			var strong: bool = r.get("bold", false)
			var f: Font = bold if strong else reg
			if n > 0 and (n == sel or i == hover):
				draw_rect(Rect2(0, y + 1.0, w, ROW_H - 1.0), HILITE)
			if n > 0 and n == sel:
				draw_rect(Rect2(0, y + 1.0, 4.0, ROW_H - 1.0), LINK)
			for k in int(r.get("tri", 0)):
				tri(8.0 + k * 12.0, y + ROW_H / 2.0 + 0.5, INK)
			var x := float(r.get("x", 8.0))
			if r.has("code"):
				put(reg, String(r["code"]), x, y, ROW_H, FS, INK)
				put(reg, String(r["text"]), X_NAME, y, ROW_H, FS, LINK if n == sel else INK)
			else:
				put(f, String(r["text"]), x, y, ROW_H, FS, INK)
			put(reg, String(r.get("sess", "")), w + C_SESS, y, ROW_H, FS, INK)
			put(reg, String(r.get("grade", "")), w + C_GRADE, y, ROW_H, FS, INK)
			put(reg, String(r.get("wgt", "")), w + C_WGT, y, ROW_H, FS, INK)
			put(f, String(r.get("obt", "")), w + C_OBT, y, ROW_H, FS, INK, true)
			put(f, String(r.get("req", "")), w + C_REQ, y, ROW_H, FS, INK, true)
			put(f, String(r.get("diff", "")), w + C_DIFF, y, ROW_H, FS, DIFF_RED, true)
			# categories are framed by dark lines, courses are separated by light ones
			var heavy := strong or i == rows.size() - 1 or bool(rows[i + 1].get("bold", false))
			hline(y + ROW_H, INK if heavy else LINE)


## Course data of level `n`: course number, credit points (also the weight) and exam block.
static func course(n: int) -> Dictionary:
	var d: Dictionary = LV.level(n)
	return {"code": String(d.get("course", "252-%04d-00 L" % n)), "ects": int(d.get("ects", DEFAULT_ECTS)),
		"block": String(d.get("block", "A" if n <= 2 else "B"))}


## Grades the way the ETH writes them: 5, 4.5, 4.25.
static func grade_text(g: float) -> String:
	return ("%.2f" % g).trim_suffix("0").trim_suffix("0").trim_suffix(".")


func _ready() -> void:
	reg = SystemFont.new()
	reg.font_names = PackedStringArray(FONTS)
	bold = SystemFont.new()
	bold.font_names = PackedStringArray(FONTS)
	bold.font_weight = 700
	var page := ColorRect.new()
	page.color = Color.WHITE
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var head := Head.new()
	head.reg = reg
	head.bold = bold
	var now := Time.get_datetime_dict_from_system()
	head.clock = "%02d:%02d   %s %d. %s" % [now["hour"], now["minute"], DAYS[now["weekday"]], now["day"], MONTHS[int(now["month"]) - 1]]
	head.who = "%s & %s" % [Game.name_of(0), Game.name_of(1)]
	col.add_child(head)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	inner = _margin(14, 10, 14, 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	inner.add_child(v)

	v.add_child(_text("Leistungsüberblick", 30, TITLE_BLUE, true))
	var info := _frame(Color.WHITE, LINE)
	info.add_child(_text("Die Spalte Diff. zeigt, wie viele Kreditpunkte in welcher Kategorie noch fehlen. Jedes Level ist ein Fach: Ab Note 4 gibt es die Kreditpunkte, die beste Note zählt. Ein Klick auf ein Fach startet das Level.", 14, INK, false, true))
	v.add_child(info)

	var key := _frame(GREY, LINE)
	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", 3)
	key.add_child(kv)
	kv.add_child(_text("Studierende:  %s (%s), %s (%s)" % [Game.name_of(0), Game.legi_ids[0], Game.name_of(1), Game.legi_ids[1]], 14, INK, true))
	kv.add_child(_text("Reglement:  %s vom 10.10.2026" % PROGRAMME, 14, INK, true))
	var legend := RichTextLabel.new()
	legend.bbcode_enabled = true
	legend.fit_content = true
	legend.scroll_active = false
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_font_override("normal_font", reg)
	legend.add_theme_font_override("bold_font", bold)
	legend.add_theme_font_size_override("normal_font_size", 13)
	legend.add_theme_font_size_override("bold_font_size", 13)
	legend.add_theme_color_override("default_color", INK)
	legend.text = "[b]Legende: Sess.:[/b] Prüfungssession (W27: Winter 2026/27); [b]Note:[/b] 6 ist die Bestnote, ab 4 ist bestanden; [b]Gew.:[/b] Gewicht der Note im Prüfungsblock; [b]Erw.:[/b] erworbene Kreditpunkte; [b]Erf.:[/b] gemäss Reglement minimal erforderliche Kreditpunkte; [b]Diff.:[/b] noch zu erwerbende Kreditpunkte"
	kv.add_child(legend)
	v.add_child(key)

	table = Table.new()
	table.reg = reg
	table.bold = bold
	table.set_rows(_rows())
	table.chosen.connect(_start)
	v.add_child(table)

	var foot_m := _margin(14, 0, 14, 10)
	col.add_child(foot_m)
	var foot := _frame(GREY, LINE, 6.0)
	foot_m.add_child(foot)
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 14)
	foot.add_child(fh)
	var back_btn := _button("Zurück")
	back_btn.pressed.connect(func(): back.emit())
	fh.add_child(back_btn)
	var hint := _text("W/S oder Pfeiltasten: Fach wählen  ·  Enter: Level starten  ·  Esc: zurück", 14)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fh.add_child(hint)
	start_btn = _button("")
	start_btn.pressed.connect(func(): _start(sel))
	fh.add_child(start_btn)

	# start on the first course that is not passed yet
	var first: int = order[order.size() - 1]
	for n in order:
		if Game.grade_of(n) < PASS:
			first = n
			break
	_select(first)


func _margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


func _text(s: String, fs: int, col: Color = INK, strong: bool = false, wrap: bool = false) -> Label:
	var l := UI.label(s, fs, col, 0, wrap)
	l.label_settings.font = bold if strong else reg
	return l


func _frame(bg: Color, border: Color, pad: float = 8.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Flat blue button like the ones on the real page.
func _button(s: String) -> Button:
	var b := Button.new()
	b.text = s
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 15)
	for st in [["normal", LINK], ["hover", LINK.lightened(0.15)], ["pressed", LINK.darkened(0.15)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = st[1]
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(st[0], sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.button_down.connect(func(): UI.sfx("click"))
	return b


func _cat(text: String, depth: int, got: int, need: int) -> Dictionary:
	return {"x": 8.0 + depth * 14.0, "tri": depth, "text": text, "bold": true, "obt": str(got), "req": str(need),
		"diff": str(need - got) if got < need else ""}


## Rows of the table, and `order` (the levels from top to bottom).
func _rows() -> Array:
	var blocks := {}
	for n in LV.numbers():
		var b: String = course(n)["block"]
		if not blocks.has(b):
			blocks[b] = []
		(blocks[b] as Array).append(n)
	var names: Array = blocks.keys()
	names.sort()
	order = []
	var body: Array = []
	var got := 0
	var need := 0
	for b in names:
		var lines: Array = []
		var wsum := 0.0
		var gsum := 0.0
		var obt := 0
		for n in blocks[b]:
			var c: Dictionary = course(n)
			var e: int = c["ects"]
			var g: float = Game.grade_of(n)
			need += e
			if g > 0.0:
				wsum += e
				gsum += g * e
			if g >= PASS:
				obt += e
			order.append(n)
			lines.append({"x": 58.0, "code": c["code"], "text": "Level %d · %s" % [n, LV.level(n)["name"]],
				"sess": SESSION if g > 0.0 else "", "grade": grade_text(g) if g > 0.0 else "", "wgt": str(e), "level": n})
		got += obt
		# like the real block: the average of its grades, weighted
		body.append({"x": 44.0, "text": "Basisprüfungsblock %s" % b, "sess": SESSION if wsum > 0.0 else "",
			"grade": grade_text(gsum / wsum) if wsum > 0.0 else "", "obt": str(obt)})
		body.append_array(lines)
	var rest := 0
	for c in LATER:
		rest += int(c[1])
	var rows: Array = [_cat(PROGRAMME, 0, got, need + rest), _cat("Obligatorische Fächer des Basisjahres", 1, got, need),
		_cat("Basisprüfung (bestanden)" if got == need else "Basisprüfung", 2, got, need)]
	rows.append_array(body)
	for c in LATER:
		rows.append(_cat(String(c[0]), 1, 0, int(c[1])))
	return rows


func _select(n: int) -> void:
	sel = n
	table.sel = n
	table.queue_redraw()
	start_btn.text = "Level %d starten" % n
	# keep the chosen course in view when the list is longer than the screen
	var y := table.global_position.y - inner.global_position.y + table.row_y(n)
	if y < scroll.scroll_vertical:
		scroll.scroll_vertical = int(y) - 8
	elif y + Table.ROW_H > scroll.scroll_vertical + scroll.size.y and scroll.size.y > 0.0:
		scroll.scroll_vertical = int(y + Table.ROW_H - scroll.size.y) + 8


func _start(n: int) -> void:
	start_level.emit(n)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
		var i := order.find(sel) + (-1 if k in [KEY_UP, KEY_W] else 1)
		if i >= 0 and i < order.size():
			UI.sfx("pop", -12.0)
			_select(int(order[i]))
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		get_viewport().set_input_as_handled()
		_start(sel)
		return
	elif k in [KEY_ESCAPE, KEY_BACKSPACE]:
		get_viewport().set_input_as_handled()
		back.emit()
		return
	else:
		return
	get_viewport().set_input_as_handled()
