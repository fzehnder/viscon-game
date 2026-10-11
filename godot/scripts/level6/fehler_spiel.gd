extends CanvasLayer
## Level 6: «Fehler finden». Code Expert shows a short Python program in which exactly one line is
## wrong (fehler_codes.gd), and the player picks that line, the way a compiler would point at it.
## For one player, on that player's half of the screen and with that player's keys, in the look of
## minigame.gd. No camera.
## Emits `mistake` on every wrong pick, `round_done(n)` after every round (so the level can let a
## player go on where they left) and `finished(done, mistakes)` at the end; done = false means the
## player left with the abort key.
## Set `screen_side`, `keys`, `labels` and `accent` before open(), like main.open_minigame does.

signal finished(success: bool, mistakes: int)
signal mistake
signal round_done(n: int)

const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")

# ---- tuning
const ROUND_PAUSE := 2.0          # seconds the explanation stays on the screen before the next round
const WRONG_FLASH := 0.6          # seconds a wrong pick stays red
const CODE_SIZE := 19             # font size of the program

const PANEL_BG := Color(0.05, 0.11, 0.25, 0.9)   # dark blue glass, as in minigame.gd
const TEXT := Color("f2f6ff")
const TEXT2 := Color("a9b7d3")
const EDITOR := Color("0d1424")
const OKC := Color("3ddc97")
const BAD := Color("ff4d5e")
const MONO := ["Menlo", "Consolas", "DejaVu Sans Mono", "Courier New", "monospace"]

var screen_side := -1
var keys: Dictionary = {}
var labels: Dictionary = {}
var accent := Color("8fb4f0")
var mistakes := 0
var runden: Array = []
var round_i := 0
var cur := 0
var lock := 0.0               # > 0: the wrong line has been found, then the next round
var closing := -1.0
var wrong := -1               # the line that was picked wrongly a moment ago
var wrong_t := 0.0

var root: Control
var panel: PanelContainer
var title_l: Label
var progress_l: Label
var rows: VBoxContainer
var buttons: Array = []
var info_l: Label
var count_l: Label
var mono: SystemFont


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
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


## `p_runden`: see fehler_codes.gd. `start`: the round to begin with (0 = the first).
func open(p_runden: Array, start: int = 0) -> void:
	runden = p_runden
	round_i = clampi(start, 0, maxi(0, runden.size() - 1))
	layer = 20
	if keys.is_empty():
		keys = KEYS.SOLO_KEYS
	if labels.is_empty():
		labels = KEYS.SOLO_LABELS
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(MONO)
	root = Control.new()
	add_child(root)
	if screen_side < 0:
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_place_half()
	var cc := CenterContainer.new()
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(PANEL_BG, accent, 18, 2, 18))
	cc.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	title_l = UI.label("Fehler finden", 30, accent, 7)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)
	head.add_child(_label("%s · abbrechen" % labels["abort"], 13, TEXT2))
	var sub := HBoxContainer.new()
	body.add_child(sub)
	var what := _label("Code Expert  ·  Welche Zeile ist falsch?", 15, TEXT)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_child(what)
	progress_l = _label("", 13, TEXT2)
	sub.add_child(progress_l)
	# the editor with the program, one row per line
	var editor := PanelContainer.new()
	editor.add_theme_stylebox_override("panel", _style(EDITOR, Color(1, 1, 1, 0.18)))
	body.add_child(editor)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.custom_minimum_size = Vector2(640, 6 * (CODE_SIZE + 14))   # room for six lines: the panel keeps its size
	editor.add_child(rows)
	var foot := HBoxContainer.new()
	body.add_child(foot)
	info_l = _label("", 15, TEXT2, true)
	info_l.custom_minimum_size = Vector2(520, 44)
	info_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(info_l)
	count_l = _label("", 15, TEXT2)
	foot.add_child(count_l)
	_show_round()
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


func _show_round() -> void:
	for b in buttons:
		rows.remove_child(b)
		b.queue_free()
	buttons.clear()
	var lines: Array = runden[round_i]["zeilen"]
	for i in lines.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # translated here, as a whole line
		b.text = "%d   %s" % [i + 1, _code(String(lines[i]))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", mono)
		b.add_theme_font_size_override("font_size", CODE_SIZE)
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", TEXT)
		b.add_theme_color_override("font_pressed_color", TEXT)
		b.custom_minimum_size = Vector2(640, CODE_SIZE + 12)
		var idx := i
		b.pressed.connect(func(): _pick(idx))
		rows.add_child(b)
		buttons.append(b)
	cur = 0
	wrong = -1
	progress_l.text = "Runde %d von %d" % [round_i + 1, runden.size()]
	info_l.label_settings.font_color = TEXT2
	_update_info()
	_paint()


## A line of the program as it is shown: in the language of the game if en.gd has it, and with
## the indent as spaces that no label swallows.
func _code(line: String) -> String:
	var s := tr(line)
	var n := 0
	while n < s.length() and s[n] == " ":
		n += 1
	return " ".repeat(n) + s.substr(n)


func _update_info() -> void:
	if lock <= 0.0 and closing < 0.0:
		info_l.text = "Auswählen mit %s, bestätigen mit %s (oder die Zeile anklicken)." % [labels["dirs"], labels["ok"]]
	count_l.text = "Fehler: %d" % mistakes
	count_l.label_settings.font_color = TEXT2 if mistakes == 0 else UI.YELLOW


func _paint() -> void:
	var right: int = int(runden[round_i]["falsch"]) if lock > 0.0 or closing >= 0.0 else -1
	for i in buttons.size():
		var bg := Color(1, 1, 1, 0.0)
		var br := Color(1, 1, 1, 0.0)
		if i == cur and right < 0:
			bg = Color(0.56, 0.7, 0.95, 0.22)
			br = UI.SKY
		if i == wrong and wrong_t > 0.0:
			bg = Color(1.0, 0.3, 0.37, 0.25)
			br = BAD
		if i == right:
			bg = Color(0.24, 0.86, 0.59, 0.25)
			br = OKC
		for st in ["normal", "hover", "pressed"]:
			(buttons[i] as Button).add_theme_stylebox_override(st, _style(bg, br))


func _pick(i: int) -> void:
	if lock > 0.0 or closing >= 0.0 or i < 0 or i >= buttons.size():
		return
	cur = i
	var rd: Dictionary = runden[round_i]
	if i == int(rd["falsch"]):
		lock = ROUND_PAUSE
		info_l.text = String(rd["warum"])
		info_l.label_settings.font_color = OKC
		UI.sfx("pop", -9.0)
		round_done.emit(round_i + 1)
	else:
		mistakes += 1
		wrong = i
		wrong_t = WRONG_FLASH
		UI.sfx("fail", -8.0)
		UI.shake(panel)
		mistake.emit()
		_update_info()
	_paint()


func _process(delta: float) -> void:
	if screen_side >= 0 and root:
		_place_half()
	if closing >= 0.0:
		closing -= delta
		if closing < 0.0:
			finished.emit(true, mistakes)
			queue_free()
		return
	if wrong_t > 0.0:
		wrong_t -= delta
		if wrong_t <= 0.0:
			_paint()
	if lock > 0.0:
		lock -= delta
		if lock <= 0.0:
			if round_i + 1 >= runden.size():
				_end()
			else:
				round_i += 1
				_show_round()


func _end() -> void:
	closing = 0.9
	panel.add_theme_stylebox_override("panel", UI.box(PANEL_BG, UI.GREEN, 18, 2, 18))
	title_l.label_settings.font_color = UI.GREEN
	info_l.text = "Alle Fehler gefunden. Code Expert ist zufrieden."
	info_l.label_settings.font_color = UI.GREEN
	UI.sfx("grant", -6.0)


func _has(what: String, k: int) -> bool:
	return k in (keys.get(what, []) as Array)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if _has("abort", k):
		get_viewport().set_input_as_handled()
		finished.emit(false, mistakes)
		queue_free()
		return
	if closing >= 0.0:
		return
	var used := true
	if _has("up", k):
		if lock <= 0.0:
			cur = (cur + buttons.size() - 1) % buttons.size()
			_paint()
	elif _has("down", k):
		if lock <= 0.0:
			cur = (cur + 1) % buttons.size()
			_paint()
	elif _has("interact", k):
		_pick(cur)
	else:
		used = false
	if used:
		get_viewport().set_input_as_handled()
