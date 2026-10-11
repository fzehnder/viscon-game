extends CanvasLayer
## Level 6: «Code abschreiben», a relay for two. One player reads a short piece of code out loud,
## the other one types it. The code is only on the reader's half of the screen; the typist's half
## shows nothing but what has been typed so far. After every code the two swap. No camera.
##   - Spaces are not typed, they appear by themselves. Everything else has to match exactly.
##   - A wrong key empties the line that is being typed and makes a ring of noise (`mistake`).
##   - Only Esc leaves: Backspace is what a typist reaches for after a wrong key.
## The typist needs the whole keyboard, so the key that opens the transcript in main.gd (L) is
## held off while this is open (see _process).
## Same contract as minigame.gd: the signals `finished(success, mistakes)` and `mistake`, the
## counter `mistakes`. `code_done(n)` tells the level how many codes are through, so that the
## two go on where they left.

signal finished(success: bool, mistakes: int)
signal mistake
signal code_done(n: int)

const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")

# ---- tuning
const CODE_SIZE := 26             # font size of the code
const SWAP_PAUSE := 1.6           # seconds between two codes, while the roles swap
const WRONG_FLASH := 0.5          # seconds the typist's half stays red after a wrong key
const TYPO_COUNTS := true         # a wrong key counts as a mistake for the grade (false: only the noise and the empty line)

const PANEL_BG := Color(0.05, 0.11, 0.25, 0.92)   # dark blue glass, as in minigame.gd
const TEXT := Color("f2f6ff")
const TEXT2 := Color("a9b7d3")
const EDITOR := Color("0d1424")
const OKC := Color("3ddc97")
const BAD := Color("ff4d5e")
const MONO := ["Menlo", "Consolas", "DejaVu Sans Mono", "Courier New", "monospace"]
const CARD := Vector2(560.0, 250.0)   # size of one half

var keys: Dictionary = {}         # of P1 (the contract; only "abort" is used)
var keys2: Dictionary = {}
var labels: Dictionary = {}
var labels2: Dictionary = {}
var host = null                   # main.gd, set by the level: see _process
var first_reader := 0             # who reads the first code out
var mistakes := 0
var codes: Array = []             # see abschreib_codes.gd
var code_i := 0
var line_i := 0
var pos := 0                      # how far the line that is being typed has got (index into it, spaces included)
var lock := 0.0                   # > 0: a code is through, the roles are about to swap
var closing := -1.0
var wrong_t := 0.0
var t := 0.0

var root: Control
var panel: PanelContainer
var title_l: Label
var progress_l: Label
var heads: Array = []             # the line above each half: who reads, who types
var cards: Array = []             # the two halves, P1 left and P2 right
var info_l: Label
var count_l: Label
var mono: SystemFont


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8.0)
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


## `p_codes`: see abschreib_codes.gd. `start`: the code to begin with. `who_reads`: who reads the first one out.
func open(p_codes: Array, start: int = 0, who_reads: int = 0) -> void:
	codes = p_codes
	code_i = clampi(start, 0, maxi(0, codes.size() - 1))
	first_reader = who_reads
	layer = 20
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(MONO)
	root = Control.new()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.12, 0.45)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(PANEL_BG, UI.SKY, 18, 2, 18))
	cc.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	title_l = UI.label("Code abschreiben", 30, UI.SKY, 7)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)
	progress_l = _label("", 15, TEXT)
	head.add_child(progress_l)
	head.add_child(_label("     %s · abbrechen" % labels.get("abort", "Esc"), 13, TEXT2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	for pid in 2:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		row.add_child(col)
		var hl := _label("", 17, Color(String(KEYS.TAG_COLORS[pid])))
		col.add_child(hl)
		heads.append(hl)
		var card := Control.new()
		card.custom_minimum_size = CARD
		card.draw.connect(_draw_card.bind(pid))
		col.add_child(card)
		cards.append(card)
	var foot := HBoxContainer.new()
	body.add_child(foot)
	info_l = _label("", 15, TEXT2, true)
	info_l.custom_minimum_size = Vector2(900, 44)
	info_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(info_l)
	count_l = _label("", 15, TEXT2)
	foot.add_child(count_l)
	_place()
	_start_code()
	UI.pop_in(panel, 0.0, 0.6)
	UI.sfx("whoosh", -10.0)


## The whole screen, scaled down if the two halves do not fit next to each other.
func _place() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var k := clampf(minf(vs.x / 1240.0, vs.y / 520.0), 0.5, 1.2)
	scale = Vector2(k, k)
	offset = Vector2.ZERO
	root.position = Vector2.ZERO
	root.size = vs / k


## Who reads the code that is on right now: the two swap after every code.
func reader() -> int:
	return (first_reader + code_i) % 2


func typist() -> int:
	return 1 - reader()


func _start_code() -> void:
	line_i = 0
	pos = 0
	_skip_spaces()
	progress_l.text = "Code %d von %d" % [code_i + 1, codes.size()]
	heads[reader()].text = "%s liest vor" % Game.name_of(reader())
	heads[typist()].text = "%s tippt" % Game.name_of(typist())
	_update_info()


func _line() -> String:
	return String(codes[code_i][line_i])


## Spaces are never typed: the place in the line moves on over them.
func _skip_spaces() -> void:
	var s := _line()
	while pos < s.length() and s[pos] == " ":
		pos += 1


func _update_info() -> void:
	if closing < 0.0 and lock <= 0.0:
		info_l.text = "%s sagt Zeichen für Zeichen an, %s tippt. Leerzeichen kommen von selbst. Ein falsches Zeichen, und die Zeile ist wieder leer." % [Game.name_of(reader()), Game.name_of(typist())]
		info_l.label_settings.font_color = TEXT2
	count_l.text = "Fehler: %d" % mistakes
	count_l.label_settings.font_color = TEXT2 if mistakes == 0 else UI.YELLOW


# ------------------------------------------------------------------ typing
func _type(ch: String) -> void:
	if lock > 0.0 or closing >= 0.0 or ch == " " or ch == "":
		return
	var s := _line()
	if pos < s.length() and ch == s[pos]:
		pos += 1
		_skip_spaces()
		UI.sfx("type", -10.0)
		if pos >= s.length():
			_line_done()
		return
	# a wrong key: the line is empty again
	pos = 0
	_skip_spaces()
	mistakes += 1
	wrong_t = WRONG_FLASH
	UI.sfx("fail", -8.0)
	UI.shake(panel, 6.0)
	mistake.emit()
	_update_info()


func _line_done() -> void:
	UI.sfx("pop", -9.0)
	if line_i + 1 < (codes[code_i] as Array).size():
		line_i += 1
		pos = 0
		_skip_spaces()
		return
	# the code is through
	code_done.emit(code_i + 1)
	if code_i + 1 >= codes.size():
		closing = 1.1
		panel.add_theme_stylebox_override("panel", UI.box(PANEL_BG, UI.GREEN, 18, 2, 18))
		title_l.label_settings.font_color = UI.GREEN
		info_l.text = "Abgegeben. Drei Codes, und keiner davon war eurer."
		info_l.label_settings.font_color = UI.GREEN
		UI.sfx("grant", -6.0)
		return
	lock = SWAP_PAUSE
	info_l.text = "Stimmt. Jetzt wird getauscht: %s liest vor, %s tippt." % [Game.name_of(typist()), Game.name_of(reader())]
	info_l.label_settings.font_color = OKC


func _process(delta: float) -> void:
	t += delta
	_place()
	# The typist needs every letter. main.gd opens the transcript on L whenever it likes; it does
	# not if it believes the transcript was closed a moment ago.
	if host != null and "tr_closed_frame" in host:
		host.tr_closed_frame = Engine.get_process_frames()
	wrong_t = maxf(0.0, wrong_t - delta)
	if closing >= 0.0:
		closing -= delta
		if closing < 0.0:
			finished.emit(true, mistakes)
			queue_free()
			return
	elif lock > 0.0:
		lock -= delta
		if lock <= 0.0:
			code_i += 1
			_start_code()
	for c in cards:
		c.queue_redraw()


func _has(d: Dictionary, what: String, k: int) -> bool:
	return k in (d.get(what, []) as Array)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()   # every key belongs to the typist while this is open
	if event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		if closing < 0.0:
			finished.emit(false, mistakes)
			queue_free()
		return
	if event.unicode >= 32:
		_type(String.chr(event.unicode))


# ------------------------------------------------------------------ drawing
## One half: the reader's shows the code and how far the typist is, the typist's only what has
## been typed.
func _draw_card(pid: int) -> void:
	var c: Control = cards[pid]
	var reads := pid == reader()
	var col := Color(String(KEYS.TAG_COLORS[pid]))
	var bg := EDITOR
	if not reads and wrong_t > 0.0:
		bg = EDITOR.lerp(BAD, 0.35 * wrong_t / WRONG_FLASH)
	c.draw_style_box(_style(bg, col), Rect2(Vector2.ZERO, CARD))
	var cw := mono.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_SIZE).x
	var lines: Array = codes[code_i]
	var y0 := CARD.y / 2.0 - (lines.size() - 1) * (CODE_SIZE + 12.0) / 2.0 + CODE_SIZE * 0.35
	for li in lines.size():
		var s := String(lines[li])
		var done := s.length() if (li < line_i or lock > 0.0 or closing >= 0.0) else (pos if li == line_i else 0)
		var x0 := (CARD.x - s.length() * cw) / 2.0
		var y := y0 + li * (CODE_SIZE + 12.0)
		for i in s.length():
			var at := Vector2(x0 + i * cw, y)
			if i < done:
				c.draw_string(mono, at, s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_SIZE, OKC)
			elif reads:
				c.draw_string(mono, at, s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_SIZE, TEXT)
		if li == line_i and lock <= 0.0 and closing < 0.0:
			# where the next character goes: a line under it on the reader's half, a cursor on the typist's
			var cx := x0 + done * cw
			if reads:
				c.draw_rect(Rect2(cx, y + 5.0, cw, 3.0), UI.YELLOW)
			elif fmod(t, 0.9) < 0.55:
				c.draw_rect(Rect2(cx, y - CODE_SIZE * 0.8, 3.0, CODE_SIZE), TEXT)
