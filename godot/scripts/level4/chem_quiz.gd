extends CanvasLayer
## Level 4: the Testat. A short multiple-choice test for one player, on that player's half of the
## screen and with that player's keys, in the look of minigame.gd.
## Unlike the minigames it cannot be left, and it can be failed: more than `allowed` wrong answers
## end it at once. Emits `mistake` on every wrong answer and `finished(passed, mistakes)` at the end.
## Set `screen_side`, `keys`, `labels` and `accent` before open(), like main.open_minigame does.

signal finished(passed: bool, mistakes: int)
signal mistake

const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")
const MUTED := Color("b9bde6")
const OKC := Color("3ddc97")
const BAD := Color("ff4d5e")
const INK := Color("1d2125")
const INK3 := Color("6b7785")

var screen_side := -1
var keys: Dictionary = {}
var labels: Dictionary = {}
var accent := Color("ffc93c")
var mistakes := 0
var correct := 0
var allowed := 1
var questions: Array = []   # [question, [answers], index of the correct answer]
var q_i := 0
var opts: Array = []        # answers of the running question, shuffled: [text, is right]
var cur := 0
var lock := 0.0             # > 0: showing right or wrong, then the next question
var ending := -1.0
var passed := false

var root: Control
var panel: PanelContainer
var title_l: Label
var progress_l: Label
var q_label: Label
var buttons: Array = []
var info_l: Label
var lives_l: Label


func _style(bg: Color, border: Color, pad: float = 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
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


## `title`: "Testat · Serie A". `who`: name on the sheet. `p_questions`: see `questions`.
func open(title: String, who: String, p_questions: Array, p_allowed: int = 1) -> void:
	questions = p_questions
	allowed = p_allowed
	layer = 20
	if keys.is_empty():
		keys = KEYS.SOLO_KEYS
	if labels.is_empty():
		labels = KEYS.SOLO_LABELS
	root = Control.new()
	add_child(root)
	if screen_side < 0:
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_place_half()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.12, 0.5)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.NAVY, accent, 24, 5, 18))
	cc.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	title_l = UI.label(title, 30, accent, 7)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)
	head.add_child(_label("Abbrechen gibt es im Testat nicht", 13, MUTED))
	# the exam sheet
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", _style(Color("fbf7ea"), Color("d9cfae"), 14))
	body.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sheet.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var course := _label("ETH Zürich  ·  Praktikum Allgemeine Chemie  ·  Name: %s" % who, 13, INK3)
	course.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(course)
	progress_l = _label("", 13, INK3)
	top.add_child(progress_l)
	q_label = _label("", 21, INK, true)
	q_label.custom_minimum_size = Vector2(640, 62)
	v.add_child(q_label)
	for i in 3:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", UI.WHITE)
		b.add_theme_color_override("font_hover_color", UI.WHITE)
		b.custom_minimum_size = Vector2(640, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func(): _pick(idx))
		body.add_child(b)
		buttons.append(b)
	var foot := HBoxContainer.new()
	body.add_child(foot)
	info_l = _label("Auswählen mit %s, bestätigen mit %s (oder Tasten %s)." % [labels["dirs"], labels["ok"], labels["nums"]], 15, MUTED, true)
	info_l.custom_minimum_size = Vector2(440, 0)
	info_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(info_l)
	lives_l = _label("", 15, MUTED)
	foot.add_child(lives_l)
	_show_question()
	UI.pop_in(panel, 0.0, 0.6)
	UI.sfx("whoosh", -10.0)


## Fit the panel into the left or right half of the screen (split screen), scaled down if needed.
func _place_half() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var half := vs.x / 2.0
	var k := clampf((half - 24.0) / 740.0, 0.5, 1.0)
	scale = Vector2(k, k)
	offset = Vector2(screen_side * half, 0.0)
	root.position = Vector2.ZERO
	root.size = Vector2(half, vs.y) / k


func _num_name(i: int) -> String:
	var names: PackedStringArray = String(labels.get("nums", "1 2 3")).split(" ")
	return names[i] if i < names.size() else str(i + 1)


func _show_question() -> void:
	var q: Array = questions[q_i]
	progress_l.text = "Frage %d von %d" % [q_i + 1, questions.size()]
	q_label.text = q[0]
	opts = []
	var answers: Array = q[1]
	for i in answers.size():
		opts.append([answers[i], i == int(q[2])])
	opts.shuffle()
	cur = 0
	_paint(-1, false)
	_update_lives()


func _update_lives() -> void:
	lives_l.text = "Fehler: %d  ·  erlaubt: %d" % [mistakes, allowed]
	lives_l.label_settings.font_color = MUTED if mistakes == 0 else (UI.YELLOW if mistakes <= allowed else BAD)


## `wrong`: index of a wrong pick (-1 = none). `reveal`: show which answer was right.
func _paint(wrong: int, reveal: bool) -> void:
	for i in buttons.size():
		var b: Button = buttons[i]
		b.text = "%s   %s" % [_num_name(i), opts[i][0]]
		var bg := Color(0.15, 0.2, 0.26)
		var br := Color(0.3, 0.38, 0.46)
		if i == cur and not reveal:
			bg = Color(0.2, 0.26, 0.34)
			br = UI.YELLOW
		if reveal and opts[i][1]:
			bg = Color(0.2, 0.45, 0.25)
			br = OKC
		if i == wrong:
			bg = Color(0.5, 0.18, 0.15)
			br = BAD
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, _style(bg, br))


func _pick(i: int) -> void:
	if lock > 0.0 or ending >= 0.0:
		return
	cur = i
	if opts[i][1]:
		correct += 1
		_paint(-1, true)
		UI.sfx("pop", -9.0)
		lock = 0.65
		return
	mistakes += 1
	_paint(i, true)
	_update_lives()
	UI.sfx("fail", -8.0)
	UI.shake(panel)
	mistake.emit()
	if mistakes > allowed:
		_end(false)
	else:
		lock = 1.2


func _end(ok: bool) -> void:
	if ending >= 0.0:
		return
	passed = ok
	var col := OKC if ok else BAD
	panel.add_theme_stylebox_override("panel", UI.box(UI.NAVY, col, 24, 5, 18))
	title_l.label_settings.font_color = col
	info_l.label_settings.font_color = col
	if ok:
		ending = 1.0
		info_l.text = "Bestanden: %d von %d richtig." % [correct, questions.size()]
		UI.sfx("grant", -6.0)
	else:
		ending = 1.1
		info_l.text = "Durchgefallen: %d von %d richtig. Der Professor hat es gesehen ..." % [correct, questions.size()]


func _process(delta: float) -> void:
	if screen_side >= 0 and root:
		_place_half()
	if ending >= 0.0:
		ending -= delta
		if ending < 0.0:
			finished.emit(passed, mistakes)
			queue_free()
		return
	if lock > 0.0:
		lock -= delta
		if lock <= 0.0:
			q_i += 1
			if q_i >= questions.size():
				_end(true)
			else:
				_show_question()


func _has(what: String, k: int) -> bool:
	return k in (keys.get(what, []) as Array)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	var used := true
	var num: int = (keys.get("nums", []) as Array).find(k)
	if _has("abort", k):
		if ending < 0.0:
			info_l.text = "Im Testat gibt es kein Zurück. Der Professor schaut schon."
			UI.shake(panel, 5.0)
	elif num >= 0 and num < buttons.size():
		_pick(num)
	elif _has("up", k):
		if lock <= 0.0 and ending < 0.0:
			cur = (cur + buttons.size() - 1) % buttons.size()
			_paint(-1, false)
	elif _has("down", k):
		if lock <= 0.0 and ending < 0.0:
			cur = (cur + 1) % buttons.size()
			_paint(-1, false)
	elif _has("interact", k):
		_pick(cur)
	else:
		used = false
	if used:
		get_viewport().set_input_as_handled()
