extends CanvasLayer
## The end of a level that was won, before the win card: the two stand left and right, a sheet
## "Leistungsnachweis" is filled in line by line, the grade counts up along a bar from 1 to 6 and
## a stamp comes down. For every level (main._win_day); a level's own scene (its `finale`) comes
## before this one. Built like cutscene.gd.
##
##   var ld = LevelDone.new()
##   main.add_child(ld)
##   ld.play({"level": 3, "tag": "LEVEL 3", "name": "Polyball", "grade": 5.25, "time": 312,
##            "mistakes": 2, "best": true}, done)
##
## E / Enter / Space or a click: on (what is running is finished at once). Esc: skip everything.

const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")
const ART = preload("res://scripts/character_art.gd")
const Transcript = preload("res://scripts/transcript.gd")

const W := 1280.0                 # the scene is laid out for this size and scaled to the screen
const H := 720.0
const INTRO := 0.55               # seconds until the sheet is there
const TYPE_SPEED := 34.0          # letters per second on the sheet
const ROW_PAUSE := 0.16           # seconds between two lines
const ROLL_STEP := 0.085          # seconds per quarter grade while the grade counts up
const STAY := 7.0                 # seconds after the stamp until it goes on by itself
const PAPER := Color("fff8e7")
const INK := Color("1c1d33")
const INK2 := Color("6b7385")
const PASS := 4.0

var info: Dictionary = {}
var on_done: Callable = Callable()
var t := 0.0
var rows: Array = []              # [label, value]
var row_i := 0                    # the line that is being typed
var row_t := 0.0                  # seconds into that line
var shown_grade := 1.0
var roll_t := 0.0
var beat := "intro"               # intro, rows, roll, stamp
var stamp_t := -1.0               # seconds since the stamp came down (-1: not yet)
var ending := false
var view_modes: Array = []        # how the views of the game were drawn before (they pause while this plays)
var root: Control
var canvas: Control


func _ready() -> void:
	layer = 30
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_advance())
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_scene)
	root.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.3)
	# the scene fills the screen: the game behind it does not have to be drawn
	var m = get_parent()
	if m != null and "vps" in m:
		for vp in m.vps:
			view_modes.append(vp.render_target_update_mode)
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	UI.sfx("whoosh", -8.0)


func play(p_info: Dictionary, done: Callable = Callable()) -> void:
	info = p_info
	on_done = done
	var n: int = int(info.get("level", 1))
	var secs: int = int(info.get("time", 0))
	rows = [
		["Lerneinheit", "%s  %s" % [Transcript.course(n)["code"], String(info.get("name", ""))]],
		["Session", "%s · %d Kreditpunkte" % [Transcript.SESSION, int(Transcript.course(n)["ects"])]],
		["Zeit", "%d:%02d" % [secs / 60, secs % 60]],
		["Fehler", str(int(info.get("mistakes", 0)))],
	]


func _grade() -> float:
	return float(info.get("grade", 4.0))


func _process(delta: float) -> void:
	if ending:
		return
	t += delta
	canvas.queue_redraw()
	match beat:
		"intro":
			if t >= INTRO:
				beat = "rows"
		"rows":
			var before := int(row_t * TYPE_SPEED)
			row_t += delta
			var length := String(rows[row_i][1]).length()
			if int(row_t * TYPE_SPEED) != before and int(row_t * TYPE_SPEED) <= length and int(row_t * TYPE_SPEED) % 3 == 0:
				UI.sfx("type", -19.0)
			if row_t * TYPE_SPEED >= length + ROW_PAUSE * TYPE_SPEED:
				row_i += 1
				row_t = 0.0
				if row_i >= rows.size():
					beat = "roll"
		"roll":
			roll_t += delta
			var want := minf(_grade(), 1.0 + floorf(roll_t / ROLL_STEP) * 0.25)
			if want > shown_grade:
				shown_grade = want
				UI.sfx("tick", -12.0)
			if shown_grade >= _grade() and roll_t >= (_grade() - 1.0) / 0.25 * ROLL_STEP + 0.45:
				_stamp()
		"stamp":
			stamp_t += delta
			if stamp_t >= STAY:
				_finish()


func _stamp() -> void:
	beat = "stamp"
	row_i = rows.size()
	shown_grade = _grade()
	stamp_t = 0.0
	UI.sfx("stamp", -2.0)
	var ok := _grade() >= PASS
	UI.sfx("success" if ok else "pop", -5.0)
	if ok:
		var vs: Vector2 = root.size
		for k in 2:
			get_tree().create_timer(0.1 + k * 0.35).timeout.connect(func():
				if ending or not is_instance_valid(root):
					return
				UI.confetti(root, Vector2(vs.x * 0.14, vs.y + 10), 100, true, 32.0, 1.3)
				UI.confetti(root, Vector2(vs.x * 0.86, vs.y + 10), 100, true, 32.0, 1.3))


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


## Whatever is still running is finished at once; after the stamp it goes on.
func _advance() -> void:
	if ending:
		return
	if beat != "stamp":
		_stamp()
	elif stamp_t > 0.45:
		_finish()


func _finish() -> void:
	if ending:
		return
	ending = true
	var m = get_parent()
	if m != null and "vps" in m:
		for i in mini(view_modes.size(), m.vps.size()):
			m.vps[i].render_target_update_mode = view_modes[i]
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		if on_done.is_valid():
			on_done.call()
		queue_free())


# ------------------------------------------------------------------ drawing
func _verdict() -> Array:        # [word on the stamp, colour]
	var g := _grade()
	if g >= 5.5:
		return ["HERVORRAGEND", UI.GREEN]
	if g >= 4.5:
		return ["GUT GEMACHT", UI.GREEN]
	if g >= PASS:
		return ["BESTANDEN", UI.GREEN]
	return ["KNAPP DANEBEN", UI.ORANGE]


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, out_col := Color("15162b")) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	if outline > 0:
		canvas.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, out_col)
	canvas.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_scene() -> void:
	var vs: Vector2 = canvas.size
	var k := minf(vs.x / W, vs.y / H)
	var o := (vs - Vector2(W, H) * k) / 2.0
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), UI.NAVY)
	canvas.draw_set_transform(o, 0.0, Vector2(k, k))
	var mid := Vector2(W / 2.0, H / 2.0 + 10.0)
	var hit := stamp_t >= 0.0
	var ok := _grade() >= PASS
	# rays that turn slowly behind the sheet, brighter once the stamp is down
	for i in 14:
		var a := t * 0.25 + i * TAU / 14.0
		var far := 900.0
		canvas.draw_colored_polygon(PackedVector2Array([mid, mid + Vector2.from_angle(a - 0.09) * far, mid + Vector2.from_angle(a + 0.09) * far]),
			Color(UI.YELLOW if ok else UI.ORANGE, (0.09 if hit else 0.04) if i % 2 == 0 else 0.02))
	# head line
	var tag := String(info.get("tag", ""))
	if tag != "":
		var tw := ThemeDB.fallback_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		canvas.draw_rect(Rect2(W / 2.0 - tw / 2.0 - 12.0, 26.0, tw + 24.0, 28.0), UI.PINK)
		_text(Vector2(W / 2.0, 46.0), tag, 16, UI.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(W / 2.0, 104.0), String(info.get("name", "")), 46, UI.YELLOW, HORIZONTAL_ALIGNMENT_CENTER, 10)
	# the two, each on a spot in their colour; they jump when the stamp comes down
	for pid in 2:
		var col := Color(String(KEYS.TAG_COLORS[pid]))
		var x := 205.0 if pid == 0 else W - 205.0
		var enter := clampf((t - 0.1 - pid * 0.12) / 0.4, 0.0, 1.0)
		var drop := pow(1.0 - enter, 3.0) * -420.0          # they come down from above
		var hop := 0.0
		if hit and ok:
			hop = absf(sin((stamp_t + pid * 0.17) * 6.5)) * 46.0 * clampf(1.0 - stamp_t / 2.6, 0.0, 1.0)
		elif not hit:
			hop = (sin(t * 2.2 + pid * 1.5) * 0.5 + 0.5) * 5.0
		var feet := Vector2(x, 596.0)
		canvas.draw_set_transform(o + feet * k, 0.0, Vector2(k, k * 0.32))
		canvas.draw_circle(Vector2.ZERO, 96.0, Color(col, 0.28))
		canvas.draw_arc(Vector2.ZERO, 96.0, 0.0, TAU, 48, Color(col, 0.9), 5.0, true)
		canvas.draw_set_transform(o, 0.0, Vector2(k, k))
		if enter > 0.0:
			ART.draw_character(canvas, Game.player_looks[pid], ART.FRONT, t * 8.0, hit and ok, o + (feet + Vector2(0, drop - hop)) * k, 7.4 * k)
			canvas.draw_set_transform(o, 0.0, Vector2(k, k))
		_text(Vector2(x, 668.0), Game.name_of(pid), 24, col, HORIZONTAL_ALIGNMENT_CENTER, 7)
	# the sheet slides up, a little crooked
	var slide := 1.0 - pow(1.0 - clampf(t / INTRO, 0.0, 1.0), 3.0)
	var sheet := Rect2(-250.0, -238.0, 500.0, 476.0)
	var jolt := Vector2.ZERO
	if hit and stamp_t < 0.25:
		jolt = Vector2(sin(stamp_t * 90.0), cos(stamp_t * 70.0)) * 9.0 * (1.0 - stamp_t / 0.25)
	canvas.draw_set_transform(o + (mid + Vector2(0, (1.0 - slide) * 620.0) + jolt) * k, -0.022, Vector2(k, k))
	canvas.draw_rect(Rect2(sheet.position + Vector2(10, 14), sheet.size), Color(0, 0, 0, 0.3))
	canvas.draw_rect(sheet, PAPER)
	canvas.draw_rect(Rect2(sheet.position, Vector2(sheet.size.x, 8.0)), UI.ETH_BLUE)
	var left := sheet.position.x + 34.0
	var right := sheet.end.x - 34.0
	_text(Vector2(left, sheet.position.y + 48.0), "ETH Zürich", 24, UI.ETH_BLUE)
	_text(Vector2(right, sheet.position.y + 46.0), "Leistungsnachweis", 17, INK2, HORIZONTAL_ALIGNMENT_RIGHT)
	canvas.draw_line(Vector2(left, sheet.position.y + 62.0), Vector2(right, sheet.position.y + 62.0), INK, 2.0)
	var y := sheet.position.y + 92.0
	for i in rows.size():
		if i > row_i:
			break
		var value := String(rows[i][1])
		if i == row_i and beat == "rows":
			value = value.substr(0, int(row_t * TYPE_SPEED))
		_text(Vector2(left, y), String(rows[i][0]), 14, INK2)
		_text(Vector2(left + 118.0, y + 2.0), value, 19, INK)
		canvas.draw_line(Vector2(left, y + 12.0), Vector2(right, y + 12.0), Color(INK, 0.12), 1.0)
		y += 36.0
	# the grade: a big number and a bar from 1 to 6 with the mark at 4
	if beat == "roll" or hit:
		var gcol: Color = UI.GREEN.darkened(0.3) if shown_grade >= PASS else UI.ORANGE.darkened(0.15)
		_text(Vector2(left, sheet.position.y + 366.0), "Note", 16, INK2)
		var pulse := 1.0 + 0.06 * maxf(0.0, 1.0 - fposmod(roll_t, ROLL_STEP) / ROLL_STEP) if beat == "roll" else 1.0
		_text(Vector2(left, sheet.position.y + 438.0), Transcript.grade_text(shown_grade), int(76.0 * pulse), gcol)
		var bar := Rect2(left + 186.0, sheet.position.y + 400.0, right - left - 186.0, 20.0)
		canvas.draw_rect(bar, Color(INK, 0.1))
		canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * (shown_grade - 1.0) / 5.0, bar.size.y)), gcol)
		canvas.draw_rect(bar, INK, false, 2.0)
		for g in range(1, 7):
			var gx := bar.position.x + bar.size.x * (g - 1) / 5.0
			canvas.draw_line(Vector2(gx, bar.end.y), Vector2(gx, bar.end.y + 6.0), INK, 1.5)
			_text(Vector2(gx, bar.end.y + 22.0), str(g), 13, INK2, HORIZONTAL_ALIGNMENT_CENTER)
		var px := bar.position.x + bar.size.x * (PASS - 1.0) / 5.0
		canvas.draw_line(Vector2(px, bar.position.y - 8.0), Vector2(px, bar.end.y), INK, 3.0)
		_text(Vector2(px, bar.position.y - 13.0), "bestanden ab 4", 12, INK2, HORIZONTAL_ALIGNMENT_CENTER)
	# the stamp comes down across the sheet
	if hit:
		var v := _verdict()
		var word := String(v[0])
		var scol: Color = (v[1] as Color).darkened(0.18)
		var slam := clampf(stamp_t / 0.13, 0.0, 1.0)
		var sc := lerpf(3.2, 1.0, slam * slam)
		if stamp_t > 0.13:
			sc = 1.0 - 0.06 * maxf(0.0, 1.0 - (stamp_t - 0.13) / 0.12)
		var font := ThemeDB.fallback_font
		var fs := 44
		var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := mid + Vector2(44.0, 40.0) + jolt           # in the gap between the lines and the grade
		canvas.draw_set_transform(o + at * k, -0.13, Vector2(k * sc, k * sc))
		var fr := Rect2(-ww / 2.0 - 22.0, -38.0, ww + 44.0, 74.0)
		canvas.draw_rect(fr, Color(scol, 0.12 * slam))
		canvas.draw_rect(fr, Color(scol, slam), false, 7.0)
		canvas.draw_rect(fr.grow(-8.0), Color(scol, slam), false, 2.0)
		canvas.draw_string(font, Vector2(-ww / 2.0, 15.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(scol, slam))
		if bool(info.get("best", false)):
			canvas.draw_set_transform(o + (at + Vector2(128.0, -66.0)) * k, -0.13, Vector2(k, k))
			var pop := clampf((stamp_t - 0.35) / 0.2, 0.0, 1.0)
			if pop > 0.0:
				_text(Vector2(0, 0), "Neue Bestnote!", int(26.0 * (0.6 + 0.4 * pop)), UI.PINK, HORIZONTAL_ALIGNMENT_CENTER, 6, PAPER)
	canvas.draw_set_transform(o, 0.0, Vector2(k, k))
	if hit and stamp_t > 0.6:
		_text(Vector2(W / 2.0, H - 22.0), "E / Enter weiter", 16, Color(UI.WHITE, 0.75 + 0.25 * sin(t * 4.0)), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_text(Vector2(W / 2.0, H - 22.0), "E / Enter weiter · Esc überspringen", 15, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
