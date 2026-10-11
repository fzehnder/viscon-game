extends CanvasLayer
## Level 6: caught copying at the Basisprüfung. A full-screen scene before the lose card, in the
## spirit of the professor's fit of rage in level 4 (level4/prof_rage.gd), but colder: the exam
## supervisor has seen everything, gets angrier with every line, opens disciplinary proceedings,
## takes both Legis away (the real ones from the start of the game, legi_card.gd) and cuts them in two, and the stamp at the end leaves no doubt that this
## is about being thrown out of ETH.
##
##   var sc = Erwischt.new();  sc.who = <pid of who was seen>;  main.add_child(sc);  sc.play(done)
## E / Enter / Space or a click: on (a line that is still being typed is finished first).
## Esc / Backspace: skip everything. `done` is called once at the end.

const UI = preload("res://scripts/ui.gd")
const ART = preload("res://scripts/character_art.gd")
const KEYS = preload("res://scripts/controls.gd")
const LegiCard = preload("res://scripts/legi_card.gd")

const LOOK := {"skin": "e8b894", "hair": "8d929c", "hair_style": "dutt", "top": "23263a", "top_style": "jacket",
	"accent": "8c1c2b", "pants": "23263a", "shoes": "111118", "acc": ["glasses"]}
const TYPE_SPEED := 38.0      # letters per second
const HOLD := 1.7             # seconds a finished line stays before the next one comes by itself
const STAMP_RED := Color("d6202f")
const LEGI := Vector2(300.0, 187.0)   # the size of a Legi in this scene (same shape as legi_card.gd CARD)
# what happens, one after the other. "anger" 0..1: how red she is by then
const BEATS := [
	{"kind": "halt"},
	{"kind": "say", "text": "%s! Kopf zum Nachbarn. Ich habe alles gesehen.", "anger": 0.3},
	{"kind": "say", "text": "Abschreiben. An der Basisprüfung. In MEINER Halle.", "anger": 0.6},
	{"kind": "form", "text": "Hände weg von der Tastatur. Beide. Das geht heute noch ans Rektorat.", "anger": 0.8},
	{"kind": "legi", "text": "Und Ihre Legis. Die brauchen Sie nicht mehr.", "anger": 1.0},
	{"kind": "stamp"},
]

var who := 0                  # pid of the player who was seen
var on_done: Callable = Callable()
var idx := -1
var bt := 0.0                 # seconds in this beat
var t := 0.0
var anger := 0.0
var shake := 0.0
var flash := 0.0
var hit := false              # the stamp or the scissors of this beat have come down
var finished := false
var canvas: Control           # the hall, the supervisor, the form, the speech bubble
var over: Control             # everything that lies above the Legis: marks, the last stamp, the flash
var pen: Control              # where _text and the helpers draw right now (canvas or over)
var cards: Array = []         # per player: {"holder", "left", "right"}, the real Legi (legi_card.gd) in two halves
var cut := 0.0                # 0 whole .. 1 cut in two and apart


func play(done: Callable = Callable()) -> void:
	on_done = done
	layer = 30
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_all)
	canvas.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_next())
	over = Control.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(over)
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.draw.connect(_draw_over)
	pen = canvas
	_go(0)


## The Legis of both players, the real ones from the start of the game (legi_card.gd), each as two
## halves behind a clipping frame, so that it can be cut in two.
func _make_cards() -> void:
	for pid in 2:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(holder)
		var halves: Array = []
		for half in 2:
			var frame := Control.new()
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.clip_contents = true
			frame.size = Vector2(LEGI.x / 2.0, LEGI.y)
			frame.pivot_offset = Vector2(LEGI.x / 2.0 if half == 0 else 0.0, LEGI.y / 2.0)   # turns around the cut
			holder.add_child(frame)
			var card = LegiCard.new()
			card.set_player(pid)
			card.accent = Color(String(KEYS.TAG_COLORS[pid]))
			card.validated = true
			card.custom_minimum_size = LEGI
			card.size = LEGI
			card.position = Vector2(0.0 if half == 0 else -LEGI.x / 2.0, 0.0)
			frame.add_child(card)
			halves.append(frame)
		cards.append({"holder": holder, "left": halves[0], "right": halves[1]})
	canvas.move_child(over, -1)      # the marks and the stamp stay above the Legis


func _place_cards(s: Vector2, kind: String) -> void:
	var appear := clampf(bt / 0.4, 0.0, 1.0) if kind == "legi" else 1.0
	cut = 1.0
	if kind == "legi":
		cut = clampf((bt - 1.5) / 0.9, 0.0, 1.0) if hit else 0.0
	var slide := 1.0 - pow(1.0 - appear, 3.0)
	for pid in cards.size():
		var c: Dictionary = cards[pid]
		var holder: Control = c["holder"]
		holder.position = Vector2(lerpf(s.x * 1.2, s.x * 0.865, slide), s.y * (0.47 + pid * 0.27))
		holder.rotation = 0.05 - pid * 0.11
		var left: Control = c["left"]
		var right: Control = c["right"]
		left.position = Vector2(-LEGI.x / 2.0 - cut * 20.0, -LEGI.y / 2.0 + cut * 5.0)
		left.rotation = -0.17 * cut
		right.position = Vector2(cut * 20.0, -LEGI.y / 2.0 + cut * 14.0)
		right.rotation = 0.15 * cut


func _beat() -> Dictionary:
	return BEATS[clampi(idx, 0, BEATS.size() - 1)]


func _line() -> String:
	var b := _beat()
	if not b.has("text"):
		return ""
	var s := UI.T(String(b["text"]))
	return s % Game.name_of(who) if s.contains("%s") else s


func _typed() -> bool:
	return bt * TYPE_SPEED >= _line().length()


func _go(i: int) -> void:
	if i >= BEATS.size():
		_finish()
		return
	idx = i
	bt = 0.0
	hit = false
	match String(_beat()["kind"]):
		"halt":
			flash = 1.0
			shake = 1.0
			UI.sfx("fail")
			UI.sfx("buzz", -4.0)
		"stamp":
			pass
		"legi":
			_make_cards()
			UI.sfx("pop", -10.0)
		_:
			UI.sfx("pop", -10.0)


func _next() -> void:
	if finished:
		return
	var kind := String(_beat()["kind"])
	if kind == "stamp":
		if bt > 1.6:
			_finish()
	elif kind != "halt" and not _typed():
		bt = _line().length() / TYPE_SPEED + 0.01     # finish the line first
	else:
		_go(idx + 1)


func _finish() -> void:
	if finished:
		return
	finished = true
	if on_done.is_valid():
		on_done.call()
	queue_free()


func _process(delta: float) -> void:
	if finished or canvas == null:
		return
	t += delta
	bt += delta
	shake = maxf(0.0, shake - delta * 2.2)
	flash = maxf(0.0, flash - delta * 1.8)
	anger = move_toward(anger, float(_beat().get("anger", anger)), delta * 0.5)
	var kind := String(_beat()["kind"])
	match kind:
		"halt":
			if bt >= 1.5:
				_go(idx + 1)
		"form":
			if not hit and bt >= 1.7:
				hit = true
				shake = 0.6
				UI.sfx("stamp")
		"legi":
			if not hit and bt >= 1.5:
				hit = true
				shake = 0.5
				UI.sfx("click")
				UI.sfx("fail", -8.0)
		"stamp":
			if not hit and bt >= 0.45:
				hit = true
				shake = 1.0
				flash = 0.6
				UI.sfx("stamp")
				UI.sfx("doom", -3.0)
			if bt >= 6.0:
				_finish()
	if kind in ["say", "form", "legi"] and _typed() and bt >= _line().length() / TYPE_SPEED + HOLD + (1.6 if kind != "say" else 0.0):
		_go(idx + 1)
	if not cards.is_empty():
		_place_cards(canvas.size, kind)
	canvas.queue_redraw()
	over.queue_redraw()


func _input(event: InputEvent) -> void:
	if finished or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	get_viewport().set_input_as_handled()
	if k in [KEY_ESCAPE, KEY_BACKSPACE]:
		_finish()
	elif k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_next()


# ------------------------------------------------------------------ drawing
func _text(pos: Vector2, s: String, size: int, col: Color, centered: bool = false, outline: int = 0) -> void:
	var font := ThemeDB.fallback_font
	var p := pos
	if centered:
		p.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	if outline > 0:
		pen.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, UI.DARK)
	pen.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## The supervisor, big, in front of the hall: the usual figure, with a face that leaves no
## questions open. Drawn straight onto the canvas (draw_character takes a place and a scale).
func _draw_supervisor(s: Vector2) -> void:
	var k := s.y / 120.0 * 1.3
	var at := Vector2(s.x * 0.2, s.y * 1.02) + Vector2(sin(t * 47.0), cos(t * 53.0)) * (shake * 10.0 + anger * 1.5)
	ART.draw_character(pen, LOOK, ART.FRONT, 0.0, false, at, k)
	pen.draw_set_transform(at, 0.0, Vector2(k, k))
	var ink := Color("15162b")
	pen.draw_circle(Vector2(0, -34.6), 8.0, Color(0.9, 0.08, 0.08, 0.3 * anger))           # she turns red
	pen.draw_line(Vector2(-6.5, -41.2), Vector2(-1.4, -41.2 + 2.6 * anger), ink, 1.3)      # eyebrows, down in the middle
	pen.draw_line(Vector2(6.5, -41.2), Vector2(1.4, -41.2 + 2.6 * anger), ink, 1.3)
	var talking := String(_beat()["kind"]) != "stamp" and not _typed()
	pen.draw_rect(Rect2(-2.6, -30.6, 5.2, 1.2 + (2.6 * absf(sin(t * 17.0)) if talking else 0.0)), ink)   # the mouth
	if anger > 0.5:      # a vein on the forehead
		var v := Vector2(6.2, -44.5)
		var vc := Color(0.75, 0.05, 0.1, clampf((anger - 0.5) * 2.0, 0.0, 1.0))
		pen.draw_line(v + Vector2(-1.6, -1.6), v + Vector2(1.6, 1.6), vc, 1.0)
		pen.draw_line(v + Vector2(1.6, -1.6), v + Vector2(-1.6, 1.6), vc, 1.0)
	pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_all() -> void:
	pen = canvas
	var s := canvas.size
	var kind := String(_beat()["kind"])
	# the exam hall, dark; rows of desks; the alarm light turns
	pen.draw_rect(Rect2(Vector2.ZERO, s), Color("14141f"))
	for row in 4:
		var y := s.y * (0.42 + row * 0.11)
		pen.draw_rect(Rect2(0.0, y, s.x, 5.0), Color(1, 1, 1, 0.03))
		for d in 9:
			pen.draw_rect(Rect2(s.x * (0.04 + d * 0.11) + row * 14.0, y - 26.0, s.x * 0.075, 24.0), Color("23263a"))
			pen.draw_rect(Rect2(s.x * (0.055 + d * 0.11) + row * 14.0, y - 46.0, s.x * 0.045, 18.0), Color(0.4, 0.55, 0.9, 0.12))
	var siren := 0.5 + 0.5 * sin(t * 5.0)
	pen.draw_rect(Rect2(Vector2.ZERO, s), Color(0.85, 0.05, 0.08, (0.05 + 0.12 * siren) * maxf(anger, 0.25)))
	if kind == "halt":
		var pop := minf(1.0, bt / 0.12)
		_text(Vector2(s.x / 2.0, s.y * 0.56) + Vector2(sin(t * 60.0), cos(t * 71.0)) * shake * 14.0, UI.T("HALT!"), int(210 * (0.6 + 0.4 * pop)), STAMP_RED, true, 26)
	else:
		_draw_supervisor(s)
		_draw_form(s, kind)
		if kind != "stamp":
			_draw_bubble(s)


## Above the Legis: what is printed across them, the last stamp, the flash.
func _draw_over() -> void:
	pen = over
	var s := over.size
	var kind := String(_beat()["kind"])
	_draw_marks()
	if kind == "stamp":
		_draw_stamp(s)
	if flash > 0.0:
		pen.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, flash * 0.7))
	_text(Vector2(s.x - 24.0 - 330.0, s.y - 16.0), UI.T("E / Enter: weiter  ·  Esc: überspringen"), 15, Color(1, 1, 1, 0.5))
	pen = canvas


func _draw_bubble(s: Vector2) -> void:
	var r := Rect2(s.x * 0.4, s.y * 0.07, s.x * 0.55, s.y * 0.2)
	pen.draw_rect(r.grow(5.0), UI.DARK)
	pen.draw_rect(r, UI.PAPER)
	pen.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 30.0, r.end.y), Vector2(r.position.x + 78.0, r.end.y), Vector2(r.position.x - 16.0, r.end.y + 46.0)]), UI.PAPER)
	_text(r.position + Vector2(22.0, 34.0), UI.T("Prüfungsaufsicht"), 18, STAMP_RED)
	var line := _line()
	var shown := line.substr(0, int(bt * TYPE_SPEED))
	pen.draw_multiline_string(ThemeDB.fallback_font, r.position + Vector2(22.0, 74.0), shown, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 44.0, 28, -1, UI.INK)


## The form of the disciplinary proceedings slides in; the stamp makes the exam void.
func _draw_form(s: Vector2, kind: String) -> void:
	var beat_i := BEATS.find(_beat())
	if beat_i < 3:
		return
	var slide := 1.0 if kind != "form" else clampf(bt / 0.45, 0.0, 1.0)
	var at := Vector2(lerpf(s.x * 1.1, s.x * 0.44, 1.0 - pow(1.0 - slide, 3.0)), s.y * 0.36)
	var w := s.x * 0.3
	var h := s.y * 0.5
	pen.draw_set_transform(at, -0.035, Vector2.ONE)
	pen.draw_rect(Rect2(8.0, 10.0, w, h), Color(0, 0, 0, 0.35))
	pen.draw_rect(Rect2(0.0, 0.0, w, h), UI.PAPER)
	pen.draw_rect(Rect2(0.0, 0.0, w, 10.0), UI.ETH_BLUE)
	var font := ThemeDB.fallback_font
	pen.draw_string(font, Vector2(20.0, 44.0), UI.T("ETH Zürich · Rektorat"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.ETH_BLUE)
	pen.draw_string(font, Vector2(20.0, 80.0), UI.T("DISZIPLINARVERFAHREN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 25, UI.INK)
	pen.draw_string(font, Vector2(20.0, 104.0), "Nr. 2026-0042", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.INK)
	pen.draw_line(Vector2(20.0, 116.0), Vector2(w - 20.0, 116.0), UI.INK, 1.5)
	var rows := [
		[UI.T("Betrifft"), "%s, %s" % [Game.name_of(0), Game.name_of(1)]],
		[UI.T("Vergehen"), UI.T("Abschreiben an der Basisprüfung")],
		[UI.T("Antrag"), UI.T("Ausschluss vom Studium")],
	]
	for i in rows.size():
		pen.draw_string(font, Vector2(20.0, 148.0 + i * 54.0), String(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("6b7088"))
		pen.draw_string(font, Vector2(20.0, 170.0 + i * 54.0), String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, w - 40.0, 19, UI.INK if i < 2 else STAMP_RED)
	if kind != "form" or hit:
		var punch := 1.0 if kind != "form" else 1.0 + 1.2 * maxf(0.0, 1.0 - (bt - 1.7) / 0.14)
		pen.draw_set_transform(at + Vector2(w * 0.5, h * 0.9).rotated(-0.035), -0.2, Vector2(punch, punch))
		var word := UI.T("PRÜFUNG UNGÜLTIG")
		var tw := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		pen.draw_rect(Rect2(-tw / 2.0 - 12.0, -30.0, tw + 24.0, 44.0), Color(STAMP_RED, 0.9), false, 4.0)
		pen.draw_string(font, Vector2(-tw / 2.0, 2.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(STAMP_RED, 0.9))
	pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Across each Legi that has been cut: taken away.
func _draw_marks() -> void:
	if cards.is_empty() or cut < 0.3:
		return
	var font := ThemeDB.fallback_font
	var word := UI.T("EINGEZOGEN")
	var tw := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var pop := 1.0 + 0.8 * maxf(0.0, 1.0 - (cut - 0.3) / 0.15)
	for c in cards:
		var holder: Control = c["holder"]
		pen.draw_set_transform(holder.position + Vector2(0.0, 14.0), -0.14, Vector2(pop, pop))
		pen.draw_rect(Rect2(-tw / 2.0 - 12.0, -34.0, tw + 24.0, 48.0), Color(UI.PAPER, 0.9))
		pen.draw_rect(Rect2(-tw / 2.0 - 12.0, -34.0, tw + 24.0, 48.0), STAMP_RED, false, 4.0)
		pen.draw_string(font, Vector2(-tw / 2.0, 2.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, STAMP_RED)
	pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The last word: the stamp over everything.
func _draw_stamp(s: Vector2) -> void:
	pen.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.02, 0.05, clampf(bt / 0.4, 0.0, 1.0) * 0.72))
	if not hit:
		return
	var font := ThemeDB.fallback_font
	var punch := 1.0 + 1.6 * maxf(0.0, 1.0 - (bt - 0.45) / 0.16)
	var jitter := Vector2(sin(t * 60.0), cos(t * 71.0)) * shake * 12.0
	pen.draw_set_transform(s / 2.0 + Vector2(0.0, -s.y * 0.04) + jitter, -0.1, Vector2(punch, punch))
	var lines := [UI.T("EXMATRIKULATION"), UI.T("BEANTRAGT")]
	var size := int(s.y * 0.125)
	var widest := 0.0
	for l in lines:
		widest = maxf(widest, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var box := Rect2(-widest / 2.0 - 36.0, -size * 1.25, widest + 72.0, size * 2.55)
	pen.draw_rect(box, Color(STAMP_RED, 0.12))
	pen.draw_rect(box, STAMP_RED, false, 10.0)
	pen.draw_rect(box.grow(-14.0), STAMP_RED, false, 3.0)
	for i in lines.size():
		var tw := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pen.draw_string(font, Vector2(-tw / 2.0, -size * 0.12 + i * size * 1.08), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, STAMP_RED)
	pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if bt > 1.2:
		_text(Vector2(s.x / 2.0, s.y * 0.84), UI.T("Disziplinarausschuss der ETH  ·  Der Entscheid folgt per Einschreiben"), 22, Color(1, 1, 1, 0.85), true, 6)
	if bt > 1.6:
		_text(Vector2(s.x / 2.0, s.y * 0.9), UI.T("%s und %s: Bitte verlassen Sie die Halle.") % [Game.name_of(0), Game.name_of(1)], 20, UI.MUTED, true, 6)
