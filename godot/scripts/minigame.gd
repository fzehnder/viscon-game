extends CanvasLayer
## Minigame overlay. Kinds: timing, wiring, sequence, quiz, moodle, setup, highfive.
## Emits `mistake` on every error (at night that makes noise) and `finished(success, mistakes)` at the end.
## Co-op: set `screen_side` (0 = left half, 1 = right half, -1 = full screen) and `keys` / `labels` for the
## player who opened it before calling open(). "highfive" also uses `keys2` / `labels2` for the second player.

signal finished(success: bool, mistakes: int)
signal mistake

const CH = preload("res://scripts/characters.gd")
const KEYS = preload("res://scripts/controls.gd")
const LV = preload("res://scripts/levels.gd")
const INK := Color("eef1ea")
const MUTED := Color("a6b5c0")
const SIGNAL := Color("f2c14e")
const OKC := Color("86c97f")
const BAD := Color("ff5a4e")
const WIRE_COLORS := ["e74c3c", "3498db", "f1c40f", "2ecc71", "ecf0f1", "e67e22"]

var kind := ""
var params := {}
var dept := "MAVT"
var mistakes := 0
var closing := -1.0
var t := 0.0
var screen_side := -1
var keys: Dictionary = {}
var labels: Dictionary = {}
var keys2: Dictionary = {}
var labels2: Dictionary = {}

var root: Control
var panel: PanelContainer
var canvas: Control
var title_l: Label
var info_l: Label
var body: VBoxContainer

# timing
var hits := 0
var need := 4
var pos := 0.0
var vel := 260.0
var zone := Vector2(200, 300)
var flash := 0.0
var flash_ok := true
const BAR_X := 50.0
const BAR_W := 540.0

# wiring
var n_wires := 4
var right_order: Array = []
var links := {}
var side := 0
var cur := 0
var sel_left := -1
var wrong_t := 0.0
var wrong_pair := Vector2i(-1, -1)

# sequence
var seq: Array = []
var seq_phase := "show"
var show_i := 0
var show_t := 0.0
var input_i := 0
var lit := -1
var lit_t := 0.0
var lit_bad := false

# quiz
var questions: Array = []
var q_i := 0
var q_correct := 0
var q_buttons: Array = []
var q_label: Label
var q_lock := 0.0

# moodle
var tasks: Array = []
var task_i := 0
var task_wrong := 0
var m_progress: Label
var m_question: Label
var m_sig: Label
var m_edit: LineEdit
var m_feedback: Label
var m_hint: Label
var m_skip: Button

# setup (Moodle + Code Expert): pick the right option per step, no typing
var s_steps: Array = []
var s_i := 0
var s_cur := 0
var s_opts: Array = []
var s_lock := 0.0
var s_label: Label
var s_progress: Label
var s_buttons: Array = []

# highfive (co-op): both players press inside the green zone within HF_WINDOW of each other
const HF_WINDOW := 0.3
var hf_press: Array = [-1.0, -1.0]
var hf_in: Array = [false, false]
var hf_msg := ""


func _style(bg: Color, border: Color, pad: float = 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
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
	b.add_theme_stylebox_override("normal", _style(Color(0.15, 0.2, 0.26), Color(0.3, 0.38, 0.46)))
	b.add_theme_stylebox_override("hover", _style(Color(0.2, 0.26, 0.34), Color(0.45, 0.55, 0.65)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.24, 0.3, 0.38), SIGNAL))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	return b


func open(k: String, p: Dictionary, d: String) -> void:
	kind = k
	params = p
	dept = d
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
	dim.color = Color(0.02, 0.04, 0.07, 0.55)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.11, 0.15, 0.97), Color(0.3, 0.38, 0.46), 16))
	cc.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	title_l = _label(p.get("title", "Minigame"), 24, INK)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)
	var abort_txt: String = labels["abort"]
	if kind == "highfive" and not labels2.is_empty():
		abort_txt = "%s / %s" % [labels["abort"], labels2["abort"]]
	head.add_child(_label("%s · abbrechen" % abort_txt, 13, MUTED))
	match kind:
		"timing": _setup_timing()
		"wiring": _setup_wiring()
		"sequence": _setup_sequence()
		"quiz": _setup_quiz()
		"moodle": _setup_moodle()
		"setup": _setup_setup()
		"highfive": _setup_highfive()
	info_l = _label("", 15, MUTED, true)
	info_l.custom_minimum_size = Vector2(640, 0)
	body.add_child(info_l)
	_update_info()


## Fit the panel into the left or right half of the screen (split screen), scaled down if needed.
func _place_half() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var half := vs.x / 2.0
	var k := clampf((half - 24.0) / 740.0, 0.5, 1.0)
	scale = Vector2(k, k)
	offset = Vector2(screen_side * half, 0.0)
	root.position = Vector2.ZERO
	root.size = Vector2(half, vs.y) / k


func _add_canvas(h: float) -> void:
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(640, h)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_on_draw)
	canvas.gui_input.connect(_on_canvas_input)
	body.add_child(canvas)


func _update_info() -> void:
	if info_l == null:
		return
	match kind:
		"timing":
			info_l.text = "%s drücken, wenn der Zeiger im grünen Bereich ist. %s %d von %d." % [labels["ok"], params.get("verb", "Treffer"), hits, need]
		"wiring":
			info_l.text = "Verbinde jedes Kabel mit der Buchse in derselben Farbe. Links ein Kabel wählen, dann rechts die Buchse (Maus, oder %s + %s)." % [labels["dirs"], labels["ok"]]
		"sequence":
			info_l.text = "Merk dir die Reihenfolge …" if seq_phase == "show" else "Jetzt du: %s. %d / %d" % [labels["dirs"], input_i, seq.size()]
		"quiz":
			info_l.text = "Frage %d von %d · Tasten %s oder klicken" % [mini(q_i + 1, questions.size()), questions.size(), labels["nums"]]
		"moodle":
			info_l.text = "Enter oder «Prüfen» zum Abgeben."
		"setup":
			info_l.text = "Auswählen mit %s, bestätigen mit %s (oder Tasten %s)." % [labels["dirs"], labels["ok"], labels["nums"]]
		"highfive":
			var l2: String = labels2.get("ok", "?")
			info_l.text = "Beide gleichzeitig drücken, wenn der Zeiger im grünen Bereich ist: P1 %s, P2 %s. High Fives %d von %d." % [labels["ok"], l2, hits, need]
			if hf_msg != "":
				info_l.text += "   " + hf_msg
	if mistakes > 0:
		info_l.text += "   Fehler: %d" % mistakes


func _err() -> void:
	mistakes += 1
	mistake.emit()
	_update_info()


func _succeed(msg: String) -> void:
	if closing >= 0.0:
		return
	closing = 0.9
	info_l.text = msg
	info_l.label_settings.font_color = OKC


# ------------------------------------------------------------------ timing
func _setup_timing() -> void:
	need = int(params.get("hits", 4))
	vel = float(params.get("speed", 260.0))
	_add_canvas(170)
	_new_zone()


func _new_zone() -> void:
	var w := maxf(40.0, 120.0 - hits * 18.0)
	var x := randf_range(40.0, BAR_W - w - 20.0)
	zone = Vector2(x, x + w)


func _timing_press() -> void:
	if pos >= zone.x and pos <= zone.y:
		hits += 1
		flash_ok = true
		flash = 0.35
		vel *= 1.15
		if hits >= need:
			_succeed("Geschafft!")
		else:
			_new_zone()
	else:
		flash_ok = false
		flash = 0.35
		_err()
	_update_info()


# ------------------------------------------------------------------ wiring
func _setup_wiring() -> void:
	n_wires = int(params.get("wires", 4))
	right_order = range(n_wires)
	right_order.shuffle()
	_add_canvas(60 + n_wires * 48)


func _node_pos(s: int, i: int) -> Vector2:
	return Vector2(120.0 if s == 0 else 520.0, 40.0 + i * 48.0)


func _wire_select() -> void:
	if side == 0:
		if links.has(cur):
			return
		sel_left = cur
		side = 1
		cur = 0
		for j in n_wires:
			if not links.values().has(j):
				cur = j
				break
	else:
		if sel_left < 0:
			side = 0
			return
		_try_link(sel_left, cur)


func _try_link(li: int, rj: int) -> void:
	if links.values().has(rj):
		return
	if right_order[rj] == li:
		links[li] = rj
		sel_left = -1
		side = 0
		cur = 0
		for i in n_wires:
			if not links.has(i):
				cur = i
				break
		if links.size() == n_wires:
			_succeed("Alles verbunden – es läuft Strom!")
	else:
		wrong_pair = Vector2i(li, rj)
		wrong_t = 0.5
		_err()


# ------------------------------------------------------------------ sequence
func _setup_sequence() -> void:
	var length := int(params.get("length", 5))
	for i in length:
		seq.append(randi() % 4)
	_add_canvas(260)
	_restart_show()


func _restart_show() -> void:
	seq_phase = "show"
	show_i = 0
	show_t = -0.6
	input_i = 0
	_update_info()


func _pad_center(i: int) -> Vector2:
	var c := Vector2(320, 130)
	return c + [Vector2(0, -72), Vector2(0, 72), Vector2(-72, 0), Vector2(72, 0)][i]


func _seq_press(i: int) -> void:
	if seq_phase != "input":
		return
	lit = i
	lit_t = 0.25
	if seq[input_i] == i:
		lit_bad = false
		input_i += 1
		if input_i >= seq.size():
			seq_phase = "done"
			_succeed("Zugriff gewährt.")
	else:
		lit_bad = true
		_err()
		seq_phase = "wait"
		show_t = 0.0
	_update_info()


# ------------------------------------------------------------------ quiz
func _setup_quiz() -> void:
	var bank: Array = (CH.QUIZ[dept] as Array).duplicate()
	bank.shuffle()
	questions = bank.slice(0, int(params.get("count", 3)))
	q_label = _label("", 20, INK, true)
	q_label.custom_minimum_size = Vector2(640, 60)
	body.add_child(q_label)
	for i in 3:
		var b := _button("", 17)
		b.custom_minimum_size = Vector2(640, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func(): _quiz_answer(idx))
		body.add_child(b)
		q_buttons.append(b)
	_show_question()


var q_options: Array = []
var q_right := 0


func _show_question() -> void:
	var q: Array = questions[q_i]
	q_label.text = q[0]
	var opts: Array = []
	for i in (q[1] as Array).size():
		opts.append([q[1][i], i == q[2]])
	opts.shuffle()
	q_options = opts
	for i in 3:
		q_buttons[i].text = "%s   %s" % [_num_name(i), opts[i][0]]
		q_buttons[i].add_theme_stylebox_override("normal", _style(Color(0.15, 0.2, 0.26), Color(0.3, 0.38, 0.46)))
		if opts[i][1]:
			q_right = i
	if info_l:
		_update_info()


func _quiz_answer(i: int) -> void:
	if q_lock > 0.0 or closing >= 0.0:
		return
	q_buttons[q_right].add_theme_stylebox_override("normal", _style(Color(0.2, 0.45, 0.25), OKC))
	if i == q_right:
		q_correct += 1
	else:
		q_buttons[i].add_theme_stylebox_override("normal", _style(Color(0.5, 0.18, 0.15), BAD))
		_err()
	q_lock = 0.9


# ------------------------------------------------------------------ moodle
func _setup_moodle() -> void:
	var m: Dictionary = CH.MOODLE[dept]
	var all: Array = m["tasks"]
	var count := int(params.get("count", 3))
	var offset := int(params.get("offset", -1))
	if offset >= 0:
		for i in count:
			tasks.append(all[(offset + i) % all.size()])
	else:
		var pool := all.duplicate()
		pool.shuffle()
		tasks = pool.slice(0, count)
	title_l.text = "moodle"
	title_l.label_settings.font_color = Color("f98012")
	title_l.label_settings.font_size = 28
	var crumb := _label("ETH Zürich  ›  Meine Kurse  ›  " + m["course"], 14, MUTED)
	body.add_child(crumb)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(Color("f4f5f7"), Color("d7dbe0"), 14))
	body.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	m_progress = _label("", 13, Color("6b7785"))
	v.add_child(m_progress)
	m_question = _label("", 18, Color("1d2125"), true)
	m_question.custom_minimum_size = Vector2(640, 0)
	v.add_child(m_question)
	m_sig = _label("", 16, Color("1d2125"))
	v.add_child(m_sig)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	m_edit = LineEdit.new()
	m_edit.custom_minimum_size = Vector2(470, 40)
	m_edit.add_theme_font_size_override("font_size", 17)
	m_edit.add_theme_stylebox_override("normal", _style(Color.WHITE, Color("8f99a3"), 6))
	m_edit.add_theme_stylebox_override("focus", _style(Color.WHITE, Color("0f6cbf"), 6))
	m_edit.add_theme_color_override("font_color", Color("1d2125"))
	m_edit.add_theme_color_override("caret_color", Color("1d2125"))
	m_edit.text_submitted.connect(func(_s): _moodle_check())
	row.add_child(m_edit)
	var check := _button("Prüfen", 16)
	check.add_theme_stylebox_override("normal", _style(Color("0f6cbf"), Color("0f6cbf")))
	check.pressed.connect(_moodle_check)
	row.add_child(check)
	m_feedback = _label("", 15, Color("1d2125"), true)
	m_feedback.custom_minimum_size = Vector2(640, 0)
	v.add_child(m_feedback)
	m_hint = _label("", 14, Color("6b4a00"), true)
	m_hint.custom_minimum_size = Vector2(640, 0)
	v.add_child(m_hint)
	m_skip = _button("Überspringen (zählt als Fehler)", 13)
	m_skip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	m_skip.pressed.connect(func():
		_err()
		_next_task())
	v.add_child(m_skip)
	_show_task()


func _show_task() -> void:
	var tk: Dictionary = tasks[task_i]
	task_wrong = 0
	m_progress.text = "Aufgabe %d von %d" % [task_i + 1, tasks.size()]
	m_question.text = tk["q"]
	if tk["type"] == "expr":
		m_sig.text = tk["sig"] + "\n    return …"
		m_edit.placeholder_text = "Ausdruck, z. B. a + b"
	else:
		m_sig.text = "Antwort:"
		m_edit.placeholder_text = "Zahl eingeben"
	m_edit.text = ""
	m_feedback.text = ""
	m_hint.text = ""
	m_skip.visible = false
	m_edit.call_deferred("grab_focus")


func _next_task() -> void:
	task_i += 1
	if task_i >= tasks.size():
		m_feedback.text = "Alle Aufgaben abgegeben. Bewertung: bestanden."
		m_feedback.label_settings.font_color = Color("357a38")
		_succeed("Moodle-Abgabe erledigt.")
	else:
		_show_task()


func _moodle_check() -> void:
	if closing >= 0.0:
		return
	var tk: Dictionary = tasks[task_i]
	var src := m_edit.text.strip_edges()
	if src.is_empty():
		return
	var ok := false
	if tk["type"] == "num":
		var s := src.replace(",", ".").replace("'", "").replace(" ", "")
		if s.is_valid_float():
			ok = absf(s.to_float() - float(tk["a"])) < 0.01
			m_feedback.text = "Richtig!" if ok else "Leider falsch."
		else:
			m_feedback.text = "Bitte eine Zahl eingeben."
			return
	else:
		var r := _check_expr(tk, src)
		ok = r[0] == r[1]
		m_feedback.text = ("Alle %d Tests bestanden!" % r[1]) if ok else ("%d von %d Tests bestanden. %s" % [r[0], r[1], r[2]])
	m_feedback.label_settings.font_color = Color("357a38") if ok else Color("b3261e")
	if ok:
		get_tree().create_timer(0.7).timeout.connect(_next_task)
	else:
		task_wrong += 1
		_err()
		if task_wrong >= 2:
			m_hint.text = "Tipp: " + tk.get("hint", "Lies die Aufgabe nochmals genau.")
		if task_wrong >= 3:
			m_skip.visible = true


func _check_expr(tk: Dictionary, src: String) -> Array:
	if src.begins_with("return "):
		src = src.substr(7)
	src = src.trim_suffix(";")
	var vars := PackedStringArray(tk["vars"])
	var tests: Array = tk["tests"]
	var e := Expression.new()
	if e.parse(src, vars) != OK:
		return [0, tests.size(), "Syntaxfehler: " + e.get_error_text()]
	var ref := Expression.new()
	ref.parse(tk["ref"], vars)
	var passed := 0
	var first_fail := ""
	for args in tests:
		var got = e.execute(args, null, false)
		if e.has_execute_failed():
			var msg := e.get_error_text()
			if "instance is null" in msg or "not found" in msg.to_lower():
				msg = "Unbekannter Name. Du kannst nur %s verwenden." % ", ".join(vars)
			return [passed, tests.size(), "Fehler: " + msg]
		var want = ref.execute(args, null, false)
		if _same(got, want):
			passed += 1
		elif first_fail == "":
			first_fail = "Für %s erwartet: %s, erhalten: %s." % [str(args), str(want), str(got)]
	return [passed, tests.size(), first_fail]


func _same(a, b) -> bool:
	var na := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var nb := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if na and nb:
		return absf(float(a) - float(b)) < 0.000001
	if typeof(a) != typeof(b):
		return false
	return a == b


# ------------------------------------------------------------------ setup (Moodle + Code Expert)
func _num_name(i: int) -> String:
	var names: PackedStringArray = String(labels.get("nums", "1 2 3")).split(" ")
	return names[i] if i < names.size() else str(i + 1)


func _setup_setup() -> void:
	var course: String = CH.MOODLE[dept]["course"]
	for st in LV.SETUP_STEPS:
		var answers: Array = []
		for a in (st[1] as Array):
			answers.append(String(a).replace("%COURSE%", course))
		s_steps.append([String(st[0]), answers, int(st[2])])
	s_progress = _label("", 13, MUTED)
	body.add_child(s_progress)
	s_label = _label("", 20, INK, true)
	s_label.custom_minimum_size = Vector2(640, 60)
	body.add_child(s_label)
	for i in 3:
		var b := _button("", 17)
		b.custom_minimum_size = Vector2(640, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func(): _setup_pick(idx))
		body.add_child(b)
		s_buttons.append(b)
	_setup_show()


func _setup_show() -> void:
	var st: Array = s_steps[s_i]
	s_progress.text = "Schritt %d von %d" % [s_i + 1, s_steps.size()]
	s_label.text = st[0]
	var opts: Array = []
	var answers: Array = st[1]
	for i in answers.size():
		opts.append([answers[i], i == int(st[2])])
	opts.shuffle()
	s_opts = opts
	s_cur = 0
	_setup_paint(-1)


func _setup_paint(wrong: int) -> void:
	for i in s_buttons.size():
		var b: Button = s_buttons[i]
		b.text = "%s   %s" % [_num_name(i), s_opts[i][0]]
		var bg := Color(0.15, 0.2, 0.26)
		var br := Color(0.3, 0.38, 0.46)
		if i == s_cur:
			bg = Color(0.2, 0.26, 0.34)
			br = SIGNAL
		if i == wrong:
			bg = Color(0.5, 0.18, 0.15)
			br = BAD
		b.add_theme_stylebox_override("normal", _style(bg, br))


func _setup_pick(i: int) -> void:
	if s_lock > 0.0 or closing >= 0.0:
		return
	s_cur = i
	if s_opts[i][1]:
		s_buttons[i].add_theme_stylebox_override("normal", _style(Color(0.2, 0.45, 0.25), OKC))
		s_lock = 0.6
	else:
		_setup_paint(i)
		_err()


# ------------------------------------------------------------------ highfive (co-op timing)
func _setup_highfive() -> void:
	need = int(params.get("hits", 3))
	vel = float(params.get("speed", 230.0))
	_add_canvas(190)
	_hf_zone()


func _hf_zone() -> void:
	var w := maxf(70.0, 150.0 - hits * 25.0)
	var x := randf_range(40.0, BAR_W - w - 20.0)
	zone = Vector2(x, x + w)


func _hf_press(j: int) -> void:
	if hf_press[j] >= 0.0:
		return
	hf_press[j] = t
	hf_in[j] = pos >= zone.x and pos <= zone.y
	if hf_press[1 - j] >= 0.0:
		_hf_resolve("")


func _hf_resolve(late: String) -> void:
	var ok: bool = late == "" and hf_in[0] and hf_in[1]
	if ok:
		hits += 1
		flash_ok = true
		hf_msg = "Klatsch!"
		vel *= 1.12
		if hits >= need:
			_succeed("Up top! Perfekter High Five.")
		else:
			_hf_zone()
	else:
		flash_ok = false
		if late != "":
			hf_msg = "%s war zu spät." % late
		elif not hf_in[0] and not hf_in[1]:
			hf_msg = "Beide daneben."
		else:
			hf_msg = "%s daneben." % ("P1" if not hf_in[0] else "P2")
		_err()
	flash = 0.35
	hf_press = [-1.0, -1.0]
	hf_in = [false, false]
	if closing < 0.0:
		_update_info()


# ------------------------------------------------------------------ loop + input
func _process(delta: float) -> void:
	t += delta
	if screen_side >= 0 and root:
		_place_half()
	if closing >= 0.0:
		closing -= delta
		if closing < 0.0:
			finished.emit(true, mistakes)
			queue_free()
			return
	match kind:
		"timing", "highfive":
			if closing < 0.0:
				pos += vel * delta
				if pos > BAR_W:
					pos = BAR_W
					vel = -absf(vel)
				elif pos < 0.0:
					pos = 0.0
					vel = absf(vel)
			flash = maxf(0.0, flash - delta)
			if kind == "highfive" and closing < 0.0:
				for j in 2:
					if hf_press[j] >= 0.0 and hf_press[1 - j] < 0.0 and t - hf_press[j] > HF_WINDOW:
						_hf_resolve("P2" if j == 0 else "P1")
						break
		"setup":
			if s_lock > 0.0:
				s_lock -= delta
				if s_lock <= 0.0:
					s_i += 1
					if s_i >= s_steps.size():
						s_label.text = "Moodle und Code Expert sind bereit."
						_succeed("Alles eingerichtet!")
					else:
						_setup_show()
		"wiring":
			wrong_t = maxf(0.0, wrong_t - delta)
		"sequence":
			lit_t = maxf(0.0, lit_t - delta)
			if seq_phase == "show":
				show_t += delta
				if show_t >= 0.0:
					var step := int(show_t / 0.65)
					if step >= seq.size():
						seq_phase = "input"
						lit = -1
						_update_info()
					elif fmod(show_t, 0.65) < 0.5:
						lit = seq[step]
						lit_t = 0.05
						lit_bad = false
			elif seq_phase == "wait":
				show_t += delta
				if show_t > 0.9:
					_restart_show()
		"quiz":
			if q_lock > 0.0:
				q_lock -= delta
				if q_lock <= 0.0:
					q_i += 1
					if q_i >= questions.size():
						q_label.text = "%d von %d richtig." % [q_correct, questions.size()]
						_succeed("Quiz abgeschlossen.")
					else:
						_show_question()
	if canvas:
		canvas.queue_redraw()


func _has(d: Dictionary, what: String, k: int) -> bool:
	return k in (d.get(what, []) as Array)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if _has(keys, "abort", k) or (kind == "highfive" and _has(keys2, "abort", k)):
		get_viewport().set_input_as_handled()
		finished.emit(false, mistakes)
		queue_free()
		return
	if closing >= 0.0 or kind == "moodle":
		return
	var used := true
	match kind:
		"timing":
			if _has(keys, "interact", k):
				_timing_press()
			else:
				used = false
		"wiring":
			if _has(keys, "up", k):
				cur = (cur - 1 + n_wires) % n_wires
			elif _has(keys, "down", k):
				cur = (cur + 1) % n_wires
			elif _has(keys, "left", k):
				side = 0
			elif _has(keys, "right", k):
				side = 1
			elif _has(keys, "interact", k):
				_wire_select()
			else:
				used = false
		"sequence":
			var dirs := ["up", "down", "left", "right"]
			used = false
			for i in 4:
				if _has(keys, dirs[i], k):
					_seq_press(i)
					used = true
					break
		"quiz":
			var qi: int = (keys.get("nums", []) as Array).find(k)
			if qi >= 0:
				_quiz_answer(qi)
			else:
				used = false
		"setup":
			var si: int = (keys.get("nums", []) as Array).find(k)
			if si >= 0:
				_setup_pick(si)
			elif _has(keys, "up", k):
				if s_lock <= 0.0:
					s_cur = (s_cur + 2) % 3
					_setup_paint(-1)
			elif _has(keys, "down", k):
				if s_lock <= 0.0:
					s_cur = (s_cur + 1) % 3
					_setup_paint(-1)
			elif _has(keys, "interact", k):
				_setup_pick(s_cur)
			else:
				used = false
		"highfive":
			if _has(keys, "interact", k):
				_hf_press(0)
			elif _has(keys2, "interact", k):
				_hf_press(1)
			else:
				used = false
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()


func _on_canvas_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var p: Vector2 = event.position
	match kind:
		"timing":
			_timing_press()
		"wiring":
			for s in 2:
				for i in n_wires:
					if p.distance_to(_node_pos(s, i)) < 20.0:
						side = s
						cur = i
						if s == 0:
							if not links.has(i):
								sel_left = i
								side = 1
						elif sel_left >= 0:
							_try_link(sel_left, i)
						return
		"sequence":
			for i in 4:
				if p.distance_to(_pad_center(i)) < 30.0:
					_seq_press(i)


func _on_draw() -> void:
	var c := canvas
	var font := ThemeDB.fallback_font
	match kind:
		"timing":
			for i in need:
				var pc := Vector2(BAR_X + 20 + i * 34, 30)
				c.draw_circle(pc, 11, Color(0.2, 0.25, 0.3))
				if i < hits:
					c.draw_circle(pc, 8, SIGNAL)
			c.draw_rect(Rect2(BAR_X, 80, BAR_W, 36), Color(0.15, 0.19, 0.24))
			c.draw_rect(Rect2(BAR_X + zone.x, 80, zone.y - zone.x, 36), Color(0.3, 0.75, 0.4, 0.85))
			c.draw_rect(Rect2(BAR_X, 80, BAR_W, 36), Color(0.4, 0.48, 0.56), false, 1.5)
			var mx := BAR_X + pos
			c.draw_rect(Rect2(mx - 3, 70, 6, 56), INK)
			c.draw_colored_polygon(PackedVector2Array([Vector2(mx - 8, 62), Vector2(mx + 8, 62), Vector2(mx, 72)]), SIGNAL)
			if flash > 0.0:
				var fc := OKC if flash_ok else BAD
				c.draw_rect(Rect2(BAR_X - 4, 76, BAR_W + 8, 44), Color(fc.r, fc.g, fc.b, flash * 1.6), false, 3.0)
		"highfive":
			for i in need:
				var hc := Vector2(BAR_X + 20 + i * 34, 30)
				c.draw_circle(hc, 11, Color(0.2, 0.25, 0.3))
				if i < hits:
					c.draw_circle(hc, 8, SIGNAL)
			c.draw_rect(Rect2(BAR_X, 80, BAR_W, 36), Color(0.15, 0.19, 0.24))
			c.draw_rect(Rect2(BAR_X + zone.x, 80, zone.y - zone.x, 36), Color(0.3, 0.75, 0.4, 0.85))
			c.draw_rect(Rect2(BAR_X, 80, BAR_W, 36), Color(0.4, 0.48, 0.56), false, 1.5)
			var hx := BAR_X + pos
			c.draw_rect(Rect2(hx - 3, 70, 6, 56), INK)
			c.draw_colored_polygon(PackedVector2Array([Vector2(hx - 8, 62), Vector2(hx + 8, 62), Vector2(hx, 72)]), SIGNAL)
			if flash > 0.0:
				var hfc := OKC if flash_ok else BAD
				c.draw_rect(Rect2(BAR_X - 4, 76, BAR_W + 8, 44), Color(hfc.r, hfc.g, hfc.b, flash * 1.6), false, 3.0)
			# one hand per player, lights up when that player pressed in this round
			for j in 2:
				var hp := Vector2(BAR_X + 60 + j * (BAR_W - 120), 160)
				var col := Color(KEYS.TAG_COLORS[j])
				var pressed: bool = hf_press[j] >= 0.0
				c.draw_circle(hp, 18, col if pressed else Color(0.2, 0.25, 0.3))
				c.draw_arc(hp, 18, 0, TAU, 28, col, 2.0)
				var tag: String = KEYS.TAGS[j]
				var tsz := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
				c.draw_string(font, hp + Vector2(-tsz.x / 2.0, 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("1a1a1a") if pressed else INK)
		"wiring":
			for i in n_wires:
				var lp := _node_pos(0, i)
				var col := Color(WIRE_COLORS[i])
				c.draw_rect(Rect2(20, lp.y - 5, lp.x - 20, 10), col)
				c.draw_circle(lp, 12, col)
				var rp := _node_pos(1, i)
				var rc := Color(WIRE_COLORS[right_order[i]])
				c.draw_circle(rp, 14, Color(0.12, 0.15, 0.2))
				c.draw_arc(rp, 14, 0, TAU, 28, rc, 4.0)
				c.draw_rect(Rect2(rp.x + 14, rp.y - 3, 90, 6), Color(0.3, 0.35, 0.4))
			for li in links:
				var a := _node_pos(0, li)
				var bpos := _node_pos(1, links[li])
				var pts := PackedVector2Array()
				for s in 21:
					var u := s / 20.0
					pts.append(a.lerp(bpos, u) + Vector2(0, sin(u * PI) * 18.0))
				c.draw_polyline(pts, Color(WIRE_COLORS[li]), 6.0)
			if sel_left >= 0:
				var a2 := _node_pos(0, sel_left)
				var m := c.get_local_mouse_position()
				c.draw_line(a2, m if side == 1 and m.x > 140 else _node_pos(1, cur), Color(WIRE_COLORS[sel_left], 0.6), 4.0)
				c.draw_arc(a2, 17, 0, TAU, 28, INK, 2.0)
			if wrong_t > 0.0:
				c.draw_line(_node_pos(0, wrong_pair.x), _node_pos(1, wrong_pair.y), Color(1, 0.3, 0.25, wrong_t * 2.0), 4.0)
			var cp := _node_pos(side, cur)
			c.draw_arc(cp, 20 + sin(t * 6.0) * 2.0, 0, TAU, 28, SIGNAL, 2.0)
		"sequence":
			for i in 4:
				var pc := _pad_center(i)
				var on := lit == i and lit_t > 0.0
				var bgc := Color(0.15, 0.2, 0.26)
				if on:
					bgc = BAD if lit_bad else Color("6a9be0")
				c.draw_rect(Rect2(pc - Vector2(30, 30), Vector2(60, 60)), bgc)
				c.draw_rect(Rect2(pc - Vector2(30, 30), Vector2(60, 60)), Color(0.4, 0.48, 0.56), false, 1.5)
				var dirs := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
				var dv: Vector2 = dirs[i]
				var pv := Vector2(-dv.y, dv.x)
				c.draw_colored_polygon(PackedVector2Array([pc + dv * 16, pc - dv * 10 + pv * 13, pc - dv * 10 - pv * 13]), INK)
			for i in seq.size():
				var dc := Vector2(470 + (i % 6) * 22, 40 + (i / 6) * 22)
				c.draw_circle(dc, 7, OKC if i < input_i else Color(0.25, 0.3, 0.36))
			c.draw_string(font, Vector2(470, 20), "Fortschritt", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
