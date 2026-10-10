extends Control
## Freelancing elective, full screen: a job board with four freelance jobs, then a job interview
## as a video call. The interviewer asks six questions, each one to P1, to P2 or to both; the
## player holds their interact key (E / Enter), answers out loud, and the speech recognition
## (speech.gd) turns it into text that is checked against the expected words (jobs.gd).
## Without speech recognition (or while the model is still loading) the answers are picked
## from three options with the number keys. Four right answers get the job: both players sign
## the contract by holding their key. Emits `finished(best_grade)` when the players are done.

signal finished(best_grade: float)

const KEYS = preload("res://scripts/controls.gd")
const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")
const JOBS = preload("res://scripts/level19/jobs.gd")
const SpeechScript = preload("res://scripts/speech.gd")

const TYPE_SPEED := 42.0       # letters per second while the interviewer talks
const MIN_TALK := 0.6          # shorter recordings count as "nothing said"
const MAX_TALK := 15.0         # recordings stop by themselves after this
const SIGN_TIME := 1.4         # seconds both have to hold their key to sign
const GOOD_POINTS := 17.0      # impression for a right answer
const BAD_POINTS := -6.0
const TALK_BONUS := 3.0        # spoke for at least BONUS_SECS: sounds confident
const ANSWER_TIME := 12.0      # seconds to start answering; silence counts as a wrong answer
const BONUS_SECS := 2.0

const BG := Color("15171c")
const TILE := Color("23262e")
const TILE_EDGE := Color("343844")
const INK := Color("1c1d33")
const PAPER := Color("fbf8f1")

var main
var speech
var font: Font
var stage := "board"           # board, call, offer, reject
var t := 0.0
var sel := 0
var best := 0.0
var done_any := false
var applied := ""              # the one job the players applied for (one application per visit)
var outcome := ""              # "hired", "rejected" or "" while nothing is decided
# call
var job: Dictionary
var qs: Array = []
var qi := -1
var turn := 0                  # who answers right now (0 / 1)
var both_left: Array = []      # for questions to both: who still has to answer
var phase := "hello"           # hello, ask, answer, wait, react, bye
var phase_t := 0.0
var line := ""                 # what the interviewer says right now (typed)
var typed := 0.0
var impression := 50.0
var shown_imp := 50.0
var marks: Array = []          # per question: "ok", "bad" or ""
var q_ok := false
var retried := false
var answer_text := ""
var answer_hits: Array = []
var wave: Array = []           # recent microphone levels, for the bars
var nod := 0.0
var shake := 0.0
var talk_t := 0.0
var wait_id := -1
var used_keys := false
var options: Array = []        # keyboard variant: [text, right?]
var sign: Array = [0.0, 0.0]
var feedback: Array = []       # [question, tip] of the wrong answers
# nodes
var board_root: Control
var call_view: Control
var q_label: RichTextLabel
var a_label: RichTextLabel
var hint_label: Label
var paper_root: Control


class CallView:
	extends Control
	var iv

	func _draw() -> void:
		iv._draw_call(self)


## One video tile ("boss", or 0 / 1 for the players); clips what is drawn in it.
class TileView:
	extends Control
	var iv
	var who = "boss"

	func _draw() -> void:
		if who is String:
			iv._draw_boss_tile(self, Rect2(Vector2.ZERO, size))
		else:
			iv._draw_player_tile(self, int(who), Rect2(Vector2.ZERO, size))


class Card:
	extends Control
	var iv
	var i := 0
	var k := 0.0   # 0 = resting, 1 = selected; eases, so lifting and framing glide

	func _process(delta: float) -> void:
		var goal := 1.0 if iv.sel == i else 0.0
		if absf(goal - k) > 0.001:
			k += (goal - k) * (1.0 - exp(-12.0 * delta))
			queue_redraw()

	func _draw() -> void:
		iv._draw_card(self, i)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			iv._card_clicked(i)
		elif ev is InputEventMouseMotion and iv.sel != i:
			iv.sel = i


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	speech = SpeechScript.new()
	add_child(speech)
	speech.heard.connect(_on_heard)
	Track.use(self, ["face"])      # live camera picture in the player tiles, if there is a tracker
	# one application per game: if there was one already, only its result is shown
	var a := JOBS.application()
	if not a.is_empty():
		applied = String(a["id"])
		outcome = String(a["outcome"])
		best = float(a["grade"])
		done_any = true
	resized.connect(func():
		_layout_cards()
		_layout_call())
	_show_board()


# ------------------------------------------------------------------ board
func _clear() -> void:
	for c in get_children():
		if c != speech:
			c.queue_free()
	board_root = null
	call_view = null
	paper_root = null


func _show_board() -> void:
	_clear()
	stage = "board"
	for i in JOBS.JOBS.size():
		if JOBS.JOBS[i]["id"] == applied:
			sel = i
	board_root = Control.new()
	add_child(board_root)
	board_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("eef1f6")
	board_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := ColorRect.new()
	top.color = Color("1f407a")
	top.size = Vector2(4000, 74)
	board_root.add_child(top)
	var title := UI.label("ETH Freelance-Börse", 30, UI.WHITE)
	title.position = Vector2(28, 14)
	board_root.add_child(title)
	var sub := UI.label("Wahlfach Freelancing · Bewerbt euch zu zweit, das Interview läuft per Video-Call", 15, Color("c8d3ea"))
	sub.position = Vector2(30, 52)
	board_root.add_child(sub)
	hint_label = UI.label("", 15, Color("33383d"))
	hint_label.position = Vector2(30, 92)
	board_root.add_child(hint_label)
	var job_now := "Eine Bewerbung pro Spiel"
	if outcome == "hired":
		job_now = "Euer Job: %s" % JOBS.job(applied).get("name", applied)
	elif outcome == "rejected":
		job_now = "Bewerbung bei %s: Absage" % JOBS.job(applied).get("name", applied)
	var mine := UI.label(job_now, 14, Color("c8d3ea"))
	mine.anchor_left = 1.0
	mine.anchor_right = 1.0
	mine.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mine.offset_right = -24
	mine.offset_top = 26
	board_root.add_child(mine)
	for i in JOBS.JOBS.size():
		var c := Card.new()
		c.iv = self
		c.i = i
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		board_root.add_child(c)
	var fin := UI.button("Fertig für heute", UI.GREEN if done_any else Color("8a93a6"), 18)
	fin.anchor_left = 1.0
	fin.anchor_right = 1.0
	fin.anchor_top = 1.0
	fin.anchor_bottom = 1.0
	fin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fin.offset_right = -24
	fin.offset_bottom = -72   # above the transcript button of main.gd
	fin.disabled = not done_any
	fin.pressed.connect(func(): finished.emit(best))
	board_root.add_child(fin)
	var keys := UI.label("A / D oder Pfeile: Firma wählen · E / Enter: bewerben · Ihr habt nur eine Bewerbung, wählt gut!" if applied == "" else "Eure Bewerbung ist durch. «Fertig für heute» oder E / Enter beendet das Wahlfach.", 14, Color("5b6170"))
	keys.anchor_top = 1.0
	keys.anchor_bottom = 1.0
	keys.offset_left = 30
	keys.offset_top = -40
	board_root.add_child(keys)
	_layout_cards()


func _layout_cards() -> void:
	if board_root == null:
		return
	var n := JOBS.JOBS.size()
	var gap := 22.0
	var w := minf(290.0, (size.x - 60.0 - gap * (n - 1)) / n)
	var h := 400.0
	var x0 := (size.x - (w * n + gap * (n - 1))) / 2.0
	var k := 0
	for c in board_root.get_children():
		if c is Card:
			c.position = Vector2(x0 + k * (w + gap), 130)
			c.size = Vector2(w, h)
			k += 1


func _card_clicked(i: int) -> void:
	if sel == i:
		_apply(i)
	sel = i


func _locked(i: int) -> bool:
	return applied != "" and JOBS.JOBS[i]["id"] != applied


func _draw_card(ci: Control, i: int) -> void:
	var j: Dictionary = JOBS.JOBS[i]
	var w := ci.size.x
	var h := ci.size.y
	var c1 := Color(j["color"])
	var k: float = ci.k
	var lift := -10.0 * k
	var r := Rect2(0, lift, w, h)
	ci.draw_rect(Rect2(4, lift + 8 + 6.0 * k, w, h), Color(0, 0, 0, 0.1 + 0.08 * k))
	ci.draw_rect(r, Color.WHITE)
	ci.draw_rect(Rect2(0, lift, w, 118), c1)
	_draw_logo(ci, j["id"], Vector2(w / 2.0, lift + 60), c1, Color(j["color2"]))
	if k > 0.01:
		ci.draw_rect(r, Color(UI.ETH_BLUE, k), false, 4.0)
	var y := lift + 148
	ci.draw_string(font, Vector2(16, y), j["name"], HORIZONTAL_ALIGNMENT_LEFT, w - 32, 22, Color("1a1a1a"))
	ci.draw_string(font, Vector2(16, y + 22), j["tagline"], HORIZONTAL_ALIGNMENT_LEFT, w - 32, 13, Color("5b6170"))
	ci.draw_line(Vector2(16, y + 36), Vector2(w - 16, y + 36), Color("e3e6ec"), 2.0)
	_wrap(ci, j["role"], Vector2(16, y + 62), w - 32, 16, Color("1f407a"))
	ci.draw_string(font, Vector2(16, y + 122), "CHF %d / Stunde" % j["rate"], HORIZONTAL_ALIGNMENT_LEFT, w - 32, 18, Color("1a1a1a"))
	ci.draw_string(font, Vector2(16, y + 148), "Interview: 6 Fragen · %s" % j["boss"], HORIZONTAL_ALIGNMENT_LEFT, w - 32, 13, Color("5b6170"))
	ci.draw_string(font, Vector2(16, y + 174), "Schwierigkeit", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("5b6170"))
	for s in 3:
		var sc := Vector2(120 + s * 22, y + 169)
		ci.draw_colored_polygon(UI.star_points(sc, 9, 4, 0.0), UI.ETH_BLUE if s < int(j["stars"]) else Color("dde1e8"))
	if applied == j["id"] and outcome != "":
		var ok := outcome == "hired"
		var b0 := Rect2(w - 128, lift + 128, 116, 28)
		ci.draw_rect(b0, UI.GREEN.darkened(0.15) if ok else UI.RED.darkened(0.1))
		ci.draw_string(font, b0.position + Vector2(0, 20), "ANGESTELLT" if ok else "ABGESAGT", HORIZONTAL_ALIGNMENT_CENTER, b0.size.x, 14, Color.WHITE)
	if applied != "" and applied != j["id"]:
		# one application only: the other jobs are greyed out
		ci.draw_rect(r, Color(0.93, 0.94, 0.96, 0.72))
		ci.draw_string(font, Vector2(0, lift + h / 2.0), "Keine weitere Bewerbung", HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color("5b6170"))
	elif k > 0.01 and applied == "":
		var b2 := Rect2(16, h + lift - 52 + 8.0 * (1.0 - k), w - 32, 38)
		ci.draw_rect(b2, Color(c1, k))
		ci.draw_string(font, b2.position + Vector2(0, 26), "Jetzt bewerben", HORIZONTAL_ALIGNMENT_CENTER, b2.size.x, 17, Color(1, 1, 1, k))


## Simple emblem per team, drawn (no real logos).
func _draw_logo(ci: CanvasItem, id: String, c: Vector2, col: Color, col2: Color) -> void:
	var white := Color.WHITE
	match id:
		"amz":
			# race car from the side with speed lines
			for k in 3:
				ci.draw_rect(Rect2(c.x - 92, c.y - 14 + k * 10, 34 - k * 8, 4), Color(1, 1, 1, 0.6))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-52, 8), c + Vector2(-40, -10), c + Vector2(-6, -12),
				c + Vector2(8, -24), c + Vector2(22, -24), c + Vector2(30, -10), c + Vector2(62, -4), c + Vector2(64, 8)]), white)
			for wx: float in [-34.0, 44.0]:
				ci.draw_circle(c + Vector2(wx, 10), 11, col2)
				ci.draw_circle(c + Vector2(wx, 10), 4, white)
		"aris":
			# rocket with a flame
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -44), c + Vector2(12, -24), c + Vector2(12, 18), c + Vector2(-12, 18), c + Vector2(-12, -24)]), white)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 4), c + Vector2(-24, 22), c + Vector2(-12, 18)]), col2)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(12, 4), c + Vector2(24, 22), c + Vector2(12, 18)]), col2)
			ci.draw_circle(c + Vector2(0, -16), 5, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 20), c + Vector2(8, 20), c + Vector2(0, 40 + sin(t * 20.0) * 4.0)]), UI.ORANGE)
			for k in 6:
				var a := TAU * k / 6.0 + 0.3
				ci.draw_circle(c + Vector2(cos(a) * 64, sin(a) * 34), 2, Color(1, 1, 1, 0.7))
		"swissloop":
			# drill head: a turning disc with teeth
			var spin := t * 1.5
			ci.draw_circle(c, 38, white)
			ci.draw_circle(c, 30, col2)
			for k in 8:
				var a := spin + TAU * k / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 10, c + Vector2(cos(a), sin(a)) * 30, col, 4.0)
				ci.draw_rect(Rect2(c + Vector2(cos(a), sin(a)) * 38 - Vector2(4, 4), Vector2(8, 8)), white)
			ci.draw_circle(c, 8, col)
		"medtech":
			# T-shirt with an ECG line
			var s := PackedVector2Array([c + Vector2(-30, -30), c + Vector2(-12, -38), c + Vector2(12, -38), c + Vector2(30, -30),
				c + Vector2(46, -12), c + Vector2(34, -2), c + Vector2(26, -10), c + Vector2(26, 34), c + Vector2(-26, 34),
				c + Vector2(-26, -10), c + Vector2(-34, -2), c + Vector2(-46, -12)])
			ci.draw_colored_polygon(s, white)
			var pts := PackedVector2Array()
			for k in 30:
				var x := -24.0 + k * 1.65
				var ph := fmod(k * 0.11 + t * 0.8, 1.0)
				var y := 0.0
				if ph > 0.4 and ph < 0.46:
					y = -18.0
				elif ph >= 0.46 and ph < 0.5:
					y = 10.0
				pts.append(c + Vector2(x, 6 + y))
			ci.draw_polyline(pts, col, 3.0)


## How many lines _wrap needs for `text`.
func _wrap_lines(text: String, width: float, fs: int) -> int:
	var n := 1
	var cur := ""
	for wd in text.split(" "):
		var tryl := wd if cur == "" else cur + " " + wd
		if font.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and cur != "":
			n += 1
			cur = wd
		else:
			cur = tryl
	return n


func _wrap(ci: CanvasItem, text: String, pos: Vector2, width: float, fs: int, col: Color) -> void:
	var words := text.split(" ")
	var cur := ""
	var y := pos.y
	for wd in words:
		var tryl := wd if cur == "" else cur + " " + wd
		if font.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and cur != "":
			ci.draw_string(font, Vector2(pos.x, y), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			y += fs + 4
			cur = wd
		else:
			cur = tryl
	ci.draw_string(font, Vector2(pos.x, y), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _apply(i: int) -> void:
	if applied != "":
		if outcome != "" and JOBS.JOBS[i]["id"] == applied:
			finished.emit(best)
		else:
			UI.sfx("fail", -10.0)   # one application only
		return
	applied = JOBS.JOBS[i]["id"]
	# counts from the first second: leaving the interview (Esc, closing the game) is a rejection
	JOBS.set_application(applied, "rejected", 1.0)
	UI.sfx("pop")
	_start_call(JOBS.JOBS[i])


# ------------------------------------------------------------------ call
func _start_call(j: Dictionary) -> void:
	_clear()
	stage = "call"
	job = j
	qs = j["questions"]
	qi = -1
	impression = 50.0
	shown_imp = 50.0
	marks = []
	for q in qs:
		marks.append("")
	feedback = []
	used_keys = false
	call_view = CallView.new()
	call_view.iv = self
	call_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(call_view)
	call_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for who in ["boss", 0, 1]:
		var tv := TileView.new()
		tv.iv = self
		tv.who = who
		tv.clip_contents = true
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tv)
		call_view.set_meta("tile_%s" % str(who), tv)
	q_label = _rich(20)
	add_child(q_label)
	a_label = _rich(18)
	add_child(a_label)
	hint_label = UI.label("", 15, Color("aeb4c6"))
	add_child(hint_label)
	_layout_call()
	_say(j["hello"], "hello")
	UI.sfx("mail")


func _rich(fs: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.add_theme_color_override("default_color", Color("e9ecf3"))
	return r


func _layout_call() -> void:
	if call_view == null:
		return
	for who in ["boss", 0, 1]:
		var tv: Control = call_view.get_meta("tile_%s" % str(who))
		var r := _main_rect() if who is String else _side_rect(int(who))
		tv.position = r.position
		tv.size = r.size
	var b := _bottom_rect()
	q_label.position = b.position + Vector2(92, 40)
	q_label.size = Vector2(b.size.x - 112, 60)
	a_label.position = b.position + Vector2(92, 104)
	a_label.size = Vector2(b.size.x - 112, 60)
	hint_label.position = b.position + Vector2(92, b.size.y - 30)


## Big tile of the interviewer, the two player tiles and the panel at the bottom.
func _main_rect() -> Rect2:
	return Rect2(20, 64, size.x * 0.62 - 30, size.y * 0.6 - 64)


func _side_rect(pid: int) -> Rect2:
	var m := _main_rect()
	var x := m.end.x + 16
	var h := (m.size.y - 16) / 2.0
	return Rect2(x, m.position.y + pid * (h + 16), size.x - x - 20, h)


func _bottom_rect() -> Rect2:
	var m := _main_rect()
	return Rect2(20, m.end.y + 16, size.x - 40, size.y - m.end.y - 36)


func _say(text: String, ph: String) -> void:
	line = text
	typed = 0.0
	phase = ph
	phase_t = 0.0
	q_label.text = ""


func _next_question() -> void:
	qi += 1
	retried = false
	answer_text = ""
	a_label.text = ""
	if qi >= qs.size():
		_finish_call()
		return
	var q: Dictionary = qs[qi]
	var who: int = q["who"]
	both_left = [0, 1] if who < 0 else [who]
	q_ok = true   # questions to both: both answers have to be good
	var lead := ""
	if who < 0:
		lead = "Frage an euch beide: "
	else:
		lead = "%s, " % Game.name_of(who)
	_say(lead + String(q["q"]), "ask")


func _begin_answer() -> void:
	turn = both_left.pop_front()
	answer_text = ""
	a_label.text = ""   # the last answer would otherwise sit on top of the answer cards
	phase = "answer"
	phase_t = 0.0
	talk_t = 0.0
	options = []
	if not speech.is_ready:
		used_keys = true
		var opts: Array = qs[qi]["opts"]
		for k in opts.size():
			options.append([opts[k], k == 0])
		options.shuffle()


func _finish_call() -> void:
	var right := 0
	for m in marks:
		if m == "ok":
			right += 1
	var grade := clampf(snappedf(1.0 + 5.0 * right / float(qs.size()), 0.25), 1.0, 6.0)
	done_any = true
	JOBS.set_application(job["id"], "hired" if right >= JOBS.PASS else "rejected", grade)
	if right >= JOBS.PASS:
		best = maxf(best, grade)
		outcome = "hired"
		_say("Das war stark. Ich mache euch gleich ein Angebot. Bis bald!", "bye")
		_after_bye(func(): _show_offer(grade, right))
	else:
		best = maxf(best, grade)
		outcome = "rejected"
		_say("Danke euch beiden. Wir melden uns per Mail.", "bye")
		_after_bye(func(): _show_reject(right))


func _after_bye(then: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_callback(then)


func _on_heard(id: int, text: String) -> void:
	if stage != "call" or id != wait_id:
		return
	wait_id = -1
	_judge(text)


## Checks one answer of `turn` and lets the interviewer react. picked: keyboard variant,
## 1 = the right option was chosen, 0 = a wrong one, -1 = spoken (check the words).
func _judge(text: String, picked: int = -1) -> void:
	var q: Dictionary = qs[qi]
	answer_text = text.strip_edges()
	if picked < 0 and answer_text.length() < 3 and talk_t > 0.0:
		if not retried:
			retried = true
			both_left.push_front(turn)
			a_label.text = "[color=#aeb4c6]«…»[/color]"
			_say("Sorry, die Verbindung hat kurz gehackt. Kannst du das nochmals sagen?", "react")
			return
	var res := JOBS.check(q, answer_text)
	answer_hits = res["hits"] if picked < 0 else []
	a_label.text = "[b][color=#%s]%s:[/color][/b] «%s»" % [KEYS.TAG_COLORS[turn], Game.name_of(turn), _highlight(answer_text, answer_hits)]
	var ok: bool = res["ok"] if picked < 0 else picked == 1
	var short := picked < 0 and answer_text.split(" ", false).size() < JOBS.MIN_WORDS
	var silent := answer_text == ""
	if short:
		ok = false
	if ok:
		impression += GOOD_POINTS
		if talk_t >= BONUS_SECS:
			impression += TALK_BONUS
		nod = 1.0
		UI.sfx("success", -8.0)
		_say(String(q["good"]), "react")
	else:
		q_ok = false
		impression += BAD_POINTS
		shake = 1.0
		UI.sfx("fail", -10.0)
		var why := "Hm, nicht ganz."
		if silent:
			why = "Schweigen ist leider keine Antwort."
			a_label.text = "[color=#aeb4c6]%s: (keine Antwort)[/color]" % Game.name_of(turn)
		elif short:
			why = "Das war mir zu knapp, da will ich mehr hören."
		_say("%s Gut wäre zum Beispiel: %s" % [why, q["tip"]], "react")
	impression = clampf(impression, 0.0, 100.0)
	if both_left.is_empty():
		marks[qi] = "ok" if q_ok else "bad"
		if not q_ok:
			feedback.append([q["q"], q["tip"]])


## The answer with the matching words in green.
func _highlight(text: String, hits: Array) -> String:
	var out := ""
	for wd in text.split(" "):
		var norm := JOBS.normalize(wd)
		var green := false
		for h in hits:
			if h != "" and JOBS.has_word(norm, h):
				green = true
		var safe := wd.replace("[", "(").replace("]", ")")
		out += ("[color=#3ddc97]%s[/color] " % safe) if green else safe + " "
	return out.strip_edges()


# ------------------------------------------------------------------ offer / rejection
func _paper(head: String, accent: Color) -> VBoxContainer:
	_clear()
	paper_root = Control.new()
	add_child(paper_root)
	paper_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("2a2e38")
	paper_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(PAPER, accent, 6, 6, 28))
	paper_root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(720, 0)
	p.add_child(v)
	var h := UI.label(head, 30, accent.darkened(0.2))
	v.add_child(h)
	p.resized.connect(func(): p.position = (size - p.size) / 2.0)
	return v


func _show_offer(grade: float, right: int) -> void:
	stage = "offer"
	sign = [0.0, 0.0]
	var c := Color(job["color"])
	var v := _paper("Freelance-Vertrag", c)
	v.add_child(UI.label("%s  ·  %s" % [job["name"], job["role"]], 20, Color("1a1a1a")))
	v.add_child(UI.label("Auftragnehmende: %s und %s\nHonorar: CHF %d pro Stunde · Start: sofort · Arbeitsort: remote und ETH Zentrum\nInterview: %d von %d Fragen richtig · Note %s" % [
		Game.name_of(0), Game.name_of(1), job["rate"], right, qs.size(), String.num(grade, 2)], 16, Color("33383d")))
	var sig := Control.new()
	sig.custom_minimum_size = Vector2(0, 120)
	sig.draw.connect(func(): _draw_signatures(sig))
	sig.set_process(true)
	v.add_child(sig)
	paper_root.set_meta("sig", sig)
	v.add_child(UI.label("Unterschreiben: %s hält E, %s hält Enter, beide gleichzeitig" % [Game.name_of(0), Game.name_of(1)], 15, Color("5b6170")))
	UI.sfx("grant")
	set_meta("grade", grade)


func _draw_signatures(ci: Control) -> void:
	var w := ci.size.x
	for pid in 2:
		var x0 := 20.0 + pid * (w / 2.0)
		var lw := w / 2.0 - 60.0
		ci.draw_line(Vector2(x0, 92), Vector2(x0 + lw, 92), Color("33383d"), 2.0)
		ci.draw_string(font, Vector2(x0, 112), Game.name_of(pid), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("5b6170"))
		var k: float = clampf(sign[pid] / SIGN_TIME, 0.0, 1.0)
		var pts := PackedVector2Array()
		var n := int(60 * k)
		for i in n:
			var u := i / 60.0
			var seed := float(pid * 7 + 3)
			pts.append(Vector2(x0 + 10 + u * (lw - 20), 74 - sin(u * 19.0 + seed) * 16.0 * (1.0 - u * 0.5) - cos(u * 41.0 + seed) * 6.0))
		if pts.size() > 1:
			ci.draw_polyline(pts, Color(KEYS.TAG_COLORS[pid]).darkened(0.35), 3.0, true)
	if sign[0] >= SIGN_TIME and sign[1] >= SIGN_TIME:
		var c := Vector2(w - 110, 40)
		ci.draw_set_transform(c, -0.25, Vector2.ONE)
		ci.draw_rect(Rect2(-100, -26, 200, 52), Color(UI.GREEN.darkened(0.2), 0.85), false, 5.0)
		ci.draw_string(font, Vector2(-100, 12), "ANGESTELLT", HORIZONTAL_ALIGNMENT_CENTER, 200, 30, Color(UI.GREEN.darkened(0.2), 0.9))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _show_reject(right: int) -> void:
	stage = "reject"
	var v := _paper("Ihre Bewerbung bei %s" % job["name"], Color("8a93a6"))
	v.add_child(UI.label("Von: %s <jobs@%s.example>" % [job["boss"], job["id"]], 14, Color("5b6170")))
	v.add_child(UI.label("Liebe %s, lieber %s\n\nvielen Dank für das Gespräch. Leider haben wir uns für jemand anderen entschieden. Sie hatten %d von %d Fragen richtig, wir brauchen %d.\nDamit es beim nächsten Mal klappt:" % [
		Game.name_of(0), Game.name_of(1), right, qs.size(), JOBS.PASS], 16, Color("33383d"), 0, true))
	for f in feedback:
		var l := UI.label("•  %s\n    %s" % [f[0], f[1]], 14, Color("1f407a"), 0, true)
		v.add_child(l)
	v.add_child(UI.label("Freundliche Grüsse, %s" % job["boss"], 15, Color("33383d")))
	v.add_child(UI.label("E / Enter: zum Abschluss", 15, Color("5b6170")))
	UI.sfx("doom", -10.0)


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	t += delta
	match stage:
		"board":
			_process_board()
		"call":
			_process_call(delta)
		"offer":
			_process_offer(delta)
		"reject":
			if _just(0, "interact") or _just(1, "interact"):
				_end()


func _just(pid: int, what: String) -> bool:
	return Input.is_action_just_pressed(KEYS.action(pid, what))


func _held(pid: int) -> bool:
	return Input.is_action_pressed(KEYS.action(pid, "interact"))


func _process_board() -> void:
	var n := JOBS.JOBS.size()
	for pid in 2:
		if _just(pid, "left"):
			sel = (sel - 1 + n) % n
			UI.sfx("tick")
		if _just(pid, "right"):
			sel = (sel + 1) % n
			UI.sfx("tick")
		if _just(pid, "interact"):
			_apply(sel)
			return
	if board_root != null:
		var st: String = speech.state
		if speech.failed:
			hint_label.text = "Mikrofon: keine Spracherkennung gefunden (siehe tracker/README.md). Ihr antwortet mit den Zahlentasten."
		elif speech.is_ready:
			hint_label.text = "Mikrofon bereit: Im Interview haltet ihr E bzw. Enter gedrückt und antwortet laut."
		else:
			hint_label.text = "Spracherkennung: %s Bis dahin antwortet ihr mit den Zahlentasten." % st


func _process_call(delta: float) -> void:
	phase_t += delta
	shown_imp = lerpf(shown_imp, impression, 1.0 - exp(-4.0 * delta))
	nod = maxf(0.0, nod - delta * 1.4)
	shake = maxf(0.0, shake - delta * 1.6)
	wave.append(speech.level)
	if wave.size() > 64:
		wave.remove_at(0)
	# the interviewer talks: type the line, a tick now and then
	if typed < line.length():
		var before := int(typed)
		typed += delta * TYPE_SPEED
		if int(typed) != before and int(typed) % 3 == 0:
			UI.sfx("type", -18.0)
		q_label.text = "[b]%s:[/b] %s" % [job["boss"], line.substr(0, int(typed))]
		if _just(0, "interact") or _just(1, "interact") or Input.is_action_just_pressed("start"):
			typed = line.length()
			q_label.text = "[b]%s:[/b] %s" % [job["boss"], line]
		hint_label.text = ""
		call_view.queue_redraw()
		return
	match phase:
		"hello":
			hint_label.text = "E / Enter: weiter"
			if _just(0, "interact") or _just(1, "interact") or phase_t > 6.0:
				_next_question()
		"ask":
			_begin_answer()
		"answer":
			_process_answer(delta)
		"wait":
			hint_label.text = "Wird verstanden …"
		"react":
			hint_label.text = "E / Enter: weiter"
			if _just(0, "interact") or _just(1, "interact") or phase_t > 7.0:
				if not both_left.is_empty():
					var nxt: int = both_left[0]
					_say("Und du, %s?" % Game.name_of(nxt), "ask")
				else:
					_next_question()
		"bye":
			hint_label.text = ""
	call_view.queue_redraw()


func _process_answer(delta: float) -> void:
	var pid := turn
	var key := "E" if pid == 0 else "Enter"
	if not speech.recording and phase_t > ANSWER_TIME:
		talk_t = 0.0
		_judge("", 0)   # too long silent
		return
	if not options.is_empty():
		var nums := ["1 2 3", "8 9 0"]
		hint_label.text = "%s: wähle mit %s" % [Game.name_of(pid), nums[pid]]
		var keys: Array = KEYS.keys_for(pid)["nums"]
		for k in options.size():
			if Input.is_physical_key_pressed(keys[k]) and phase_t > 0.3:
				_judge(String(options[k][0]), 1 if options[k][1] else 0)
				return
		return
	if speech.recording:
		talk_t += delta
		hint_label.text = "%s spricht … (loslassen, wenn fertig)" % Game.name_of(pid)
		if not _held(pid) or talk_t >= MAX_TALK:
			var id: int = speech.finish(String(job["prompt"]))
			if talk_t < MIN_TALK:
				wait_id = -1
				hint_label.text = "Zu kurz. Nochmals: halte %s gedrückt und sprich." % key
				return
			wait_id = id
			phase = "wait"
			phase_t = 0.0
			UI.sfx("click")
		return
	hint_label.text = "%s: halte %s gedrückt und antworte laut" % [Game.name_of(pid), key]
	if _held(pid) and phase_t > 0.25:
		speech.begin()
		talk_t = 0.0
		UI.sfx("pop", -12.0)


func _process_offer(delta: float) -> void:
	var sig: Control = paper_root.get_meta("sig") if paper_root != null else null
	var was_done: bool = sign[0] >= SIGN_TIME and sign[1] >= SIGN_TIME
	for pid in 2:
		if _held(pid) and not was_done:
			sign[pid] = minf(SIGN_TIME, sign[pid] + delta)
	if sig != null:
		sig.queue_redraw()
	var now_done: bool = sign[0] >= SIGN_TIME and sign[1] >= SIGN_TIME
	if now_done and not was_done:
		UI.sfx("fanfare")
		UI.confetti(self, Vector2(size.x / 2.0, size.y * 0.3), 140)
		var tw := create_tween()
		tw.tween_interval(2.6)
		tw.tween_callback(_end)


# ------------------------------------------------------------------ drawing the call
func _draw_call(ci: Control) -> void:
	var w := ci.size.x
	ci.draw_rect(Rect2(Vector2.ZERO, ci.size), BG)
	# top bar
	ci.draw_circle(Vector2(30, 32), 7, UI.RED if fmod(t, 1.2) < 0.8 else UI.RED.darkened(0.5))
	ci.draw_string(font, Vector2(46, 39), "Interview · %s · %s" % [job["name"], job["role"]], HORIZONTAL_ALIGNMENT_LEFT, w * 0.6, 18, Color("e9ecf3"))
	var secs := int(t)
	ci.draw_string(font, Vector2(w - 380, 39), "%02d:%02d" % [secs / 60 % 60, secs % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("aeb4c6"))
	# progress dots
	for i in marks.size():
		var c := Color("3a3f4c")
		if marks[i] == "ok":
			c = UI.GREEN
		elif marks[i] == "bad":
			c = UI.RED
		elif i == qi:
			c = UI.YELLOW
		ci.draw_circle(Vector2(w - 300 + i * 22, 32), 7, c)
	# impression bar
	var bx := w - 160.0
	ci.draw_string(font, Vector2(bx, 22), "Eindruck", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("aeb4c6"))
	ci.draw_rect(Rect2(bx, 28, 136, 12), Color("3a3f4c"))
	var ic := Color("ff4d5e").lerp(UI.GREEN, shown_imp / 100.0)
	ci.draw_rect(Rect2(bx, 28, 136 * shown_imp / 100.0, 12), ic)
	for who in ["boss", 0, 1]:
		(call_view.get_meta("tile_%s" % str(who)) as Control).queue_redraw()
	_draw_bottom(ci, _bottom_rect())


func _tile_edge(ci: CanvasItem, r: Rect2, talking: bool, col: Color) -> void:
	ci.draw_rect(r.grow(-1.0), col if talking else TILE_EDGE, false, 4.0 if talking else 2.0)


func _draw_boss_tile(ci: Control, r: Rect2) -> void:
	var c1 := Color(job["color"])
	var talking := typed < line.length()
	# office behind the interviewer: wall in the team colour, a shelf, the emblem as a poster
	ci.draw_rect(r, c1.darkened(0.55))
	ci.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * 0.28, r.size.x, r.size.y * 0.28), c1.darkened(0.7))
	var poster := Rect2(r.position.x + 30, r.position.y + 30, 170, 120)
	ci.draw_rect(poster, c1)
	_draw_logo(ci, job["id"], poster.get_center(), c1, Color(job["color2"]))
	var shelf := Rect2(r.end.x - 230, r.position.y + 70, 190, 8)
	ci.draw_rect(shelf, Color("6b4a33"))
	for k in 6:
		ci.draw_rect(Rect2(shelf.position.x + 10 + k * 28, shelf.position.y - 34 + (k % 2) * 6, 18, 34 - (k % 2) * 6), [UI.YELLOW, UI.BLUE, UI.PINK, UI.GREEN][k % 4].darkened(0.3))
	ci.draw_circle(Vector2(r.end.x - 70, r.end.y - r.size.y * 0.28 - 30), 26, Color("2f7a4a"))
	ci.draw_rect(Rect2(r.end.x - 84, r.end.y - r.size.y * 0.28 - 8, 28, 30), Color("8a5a3c"))
	# the interviewer: nods to a good answer, shakes the head to a bad one
	var look := {"skin": "e8b894", "hair": "3b2a1e", "top": job["color"], "pants": "2d3a52", "hair_style": "lang" if job["id"] in ["amz", "swissloop", "medtech"] else "kurz", "acc": []}
	var dy := sin(nod * TAU * 1.5) * 6.0 * nod
	var dx := sin(shake * TAU * 2.5) * 8.0 * shake
	var bob := sin(t * 9.0) * 1.5 if talking else 0.0
	ART.draw_character(ci, look, ART.FRONT, 0.0, false, Vector2(r.get_center().x + dx, r.end.y + 120 + dy + bob), 6.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_tile_edge(ci, r, talking, UI.GREEN)
	# name plate and speaking bars
	var plate := Rect2(r.position.x + 12, r.end.y - 40, 330, 30)
	ci.draw_rect(plate, Color(0, 0, 0, 0.55))
	ci.draw_string(font, plate.position + Vector2(10, 21), "%s · %s" % [job["boss"], job["boss_role"]], HORIZONTAL_ALIGNMENT_LEFT, 310, 14, Color.WHITE)
	if talking:
		for k in 4:
			var hgt := 6.0 + absf(sin(t * 14.0 + k * 1.3)) * 14.0
			ci.draw_rect(Rect2(r.end.x - 44 + k * 7, r.end.y - 22 - hgt / 2.0, 4, hgt), UI.GREEN)
	# reaction bubble
	if nod > 0.0 or shake > 0.0:
		var good := nod > shake
		var bc := Vector2(r.get_center().x + 120, r.position.y + 90)
		ci.draw_circle(bc, 30, UI.GREEN if good else UI.RED)
		if good:
			ci.draw_polyline(PackedVector2Array([bc + Vector2(-13, 0), bc + Vector2(-3, 11), bc + Vector2(15, -11)]), Color.WHITE, 6.0)
		else:
			ci.draw_line(bc + Vector2(-11, -11), bc + Vector2(11, 11), Color.WHITE, 6.0)
			ci.draw_line(bc + Vector2(11, -11), bc + Vector2(-11, 11), Color.WHITE, 6.0)


func _draw_player_tile(ci: Control, pid: int, r: Rect2) -> void:
	var col := Color(KEYS.TAG_COLORS[pid])
	var my_turn := stage == "call" and phase in ["answer", "wait"] and turn == pid
	var talking: bool = my_turn and speech.recording
	ci.draw_rect(r, TILE)
	if Track.alive and Track.preview != null and Track.preview.get_width() > 0:
		# the real camera picture: P1 sits in the left half, P2 in the right
		var tw := float(Track.preview.get_width())
		var th := float(Track.preview.get_height())
		var half := Rect2(tw / 2.0 * pid, 0, tw / 2.0, th)
		var k := minf(r.size.x / half.size.x, r.size.y / half.size.y)
		var ds := half.size * k
		var src := half
		if ds.x < r.size.x:   # crop top and bottom so the tile is filled
			var kk := r.size.x / half.size.x
			var vis_h := r.size.y / kk
			src = Rect2(half.position.x, (th - vis_h) / 2.0, half.size.x, vis_h)
		ci.draw_texture_rect_region(Track.preview, r, src)
	else:
		ci.draw_rect(r, col.darkened(0.7))
		var look: Dictionary = main.players[pid].look if main != null else {}
		ART.draw_character(ci, look, ART.FRONT, 0.0, false, Vector2(r.get_center().x, r.end.y + 70), 4.2)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var edge := col if my_turn else TILE_EDGE
	var wgt: float = 3.0 + (float(speech.level) * 6.0 if talking else 0.0)
	ci.draw_rect(r.grow(-wgt / 2.0), edge, false, wgt if my_turn else 2.0)
	var plate := Rect2(r.position.x + 10, r.end.y - 36, 220, 26)
	ci.draw_rect(plate, Color(0, 0, 0, 0.55))
	ci.draw_string(font, plate.position + Vector2(10, 19), Game.name_of(pid), HORIZONTAL_ALIGNMENT_LEFT, 150, 14, col)
	_draw_mic(ci, Vector2(plate.end.x - 18, plate.get_center().y), talking, col)
	if my_turn and phase == "answer" and not speech.recording and options.is_empty():
		var b := Rect2(r.position.x + r.size.x / 2.0 - 110, r.position.y + 14, 220, 30)
		ci.draw_rect(b, Color(0, 0, 0, 0.6))
		ci.draw_string(font, b.position + Vector2(0, 21), "Du bist dran: halte %s" % ("E" if pid == 0 else "Enter"), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 14, UI.YELLOW)


func _draw_mic(ci: CanvasItem, c: Vector2, on: bool, col: Color) -> void:
	var mc := col if on else Color("8a93a6")
	ci.draw_rect(Rect2(c.x - 4, c.y - 9, 8, 12), mc)
	ci.draw_circle(c + Vector2(0, -9), 4, mc)
	ci.draw_circle(c + Vector2(0, 3), 4, mc)
	ci.draw_arc(c + Vector2(0, 1), 8, 0.1, PI - 0.1, 10, mc, 2.0)
	ci.draw_line(c + Vector2(0, 9), c + Vector2(0, 13), mc, 2.0)
	if not on and stage == "call" and phase != "answer":
		ci.draw_line(c + Vector2(-9, -12), c + Vector2(9, 12), UI.RED, 2.0)


func _draw_bottom(ci: Control, r: Rect2) -> void:
	ci.draw_rect(r, Color("1d2027"))
	ci.draw_rect(r, TILE_EDGE, false, 2.0)
	# the big microphone on the left with the live level
	var mc := r.position + Vector2(46, r.size.y / 2.0)
	var rec: bool = speech.recording
	var col := Color(KEYS.TAG_COLORS[turn]) if phase in ["answer", "wait"] else Color("8a93a6")
	ci.draw_circle(mc, 30 + (speech.level * 14.0 if rec else 0.0), Color(col, 0.25))
	ci.draw_circle(mc, 28, col if rec else Color("2c303a"))
	ci.draw_set_transform(mc, 0.0, Vector2(1.6, 1.6))
	_draw_mic(ci, Vector2.ZERO, true, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if phase == "wait":
		for k in 8:
			var a := t * 6.0 + TAU * k / 8.0
			ci.draw_circle(mc + Vector2(cos(a), sin(a)) * 40.0, 3.0, Color(UI.YELLOW, float(k) / 8.0))
	# wave of the microphone level while answering
	if phase == "answer" and options.is_empty():
		var x0 := r.end.x - 20 - wave.size() * 5.0
		for i in wave.size():
			var hgt := 3.0 + float(wave[i]) * 46.0
			ci.draw_rect(Rect2(x0 + i * 5.0, r.position.y + 30 - hgt / 2.0 + 10, 3, hgt), Color(col, 0.35 + float(wave[i]) * 0.65))
		if rec:
			ci.draw_string(font, Vector2(r.end.x - 120, r.end.y - 14), "%.1f s" % talk_t, HORIZONTAL_ALIGNMENT_RIGHT, 100, 14, col)
	# time left to start answering
	if phase == "answer" and not rec:
		var left := clampf(1.0 - phase_t / ANSWER_TIME, 0.0, 1.0)
		var tcol := UI.GREEN.lerp(UI.RED, 1.0 - left)
		ci.draw_rect(Rect2(r.position.x + 2, r.position.y + 2, (r.size.x - 4) * left, 5), tcol)
		ci.draw_string(font, Vector2(r.end.x - 120, r.position.y + 24), "%d s" % int(ceilf(ANSWER_TIME - phase_t)), HORIZONTAL_ALIGNMENT_RIGHT, 100, 15, tcol)
	# keyboard variant: three answer cards
	if phase == "answer" and not options.is_empty():
		# long answers go onto a second line; all three cards get the same height
		var nums: Array = ["1", "2", "3"] if turn == 0 else ["8", "9", "0"]
		var cw := (r.size.x - 140) / 3.0
		var tw := cw - 16.0 - 54.0
		var lines := 1
		for k in options.size():
			lines = maxi(lines, _wrap_lines(String(options[k][0]), tw, 16))
		var bh := 26.0 + lines * 20.0
		for k in options.size():
			var b := Rect2(r.position.x + 100 + k * cw, r.position.y + 104, cw - 16, bh)
			ci.draw_rect(b, Color("2c303a"))
			ci.draw_rect(b, Color(KEYS.TAG_COLORS[turn]), false, 2.0)
			ci.draw_string(font, b.position + Vector2(14, 29), nums[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(KEYS.TAG_COLORS[turn]))
			_wrap(ci, String(options[k][0]), b.position + Vector2(40, 29), tw, 16, Color.WHITE)
	# speech state, small, bottom left
	ci.draw_string(font, Vector2(r.position.x + 92, r.position.y + 22), "Mikrofon: %s" % speech.state, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("6b7385"))


func _input(event: InputEvent) -> void:
	if stage == "call" and phase != "bye" and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_abort_call()


## One application per game: after the contract or the rejection mail comes the end screen
## (level.gd finale), not the board again. Only once.
func _end() -> void:
	if stage == "done":
		return
	stage = "done"
	finished.emit(best)


## Esc in the interview: walking out of it counts as an application, every open question is lost.
func _abort_call() -> void:
	speech.cancel()
	for i in marks.size():
		if marks[i] == "":
			marks[i] = "bad"
			feedback.append([qs[i]["q"], "Nicht beantwortet, das Gespräch wurde abgebrochen."])
	both_left = []
	_finish_call()
