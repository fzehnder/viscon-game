extends CanvasLayer
## Level 18 (Ersti-Fest): the DJ battle, the two players against each other at the DJ table.
## Notes fall down four lanes per player, the same notes for both. Whoever taps the right key of
## their side of the keyboard while a note is on the line scores: the closer, the more, and a
## streak multiplies. P1 plays A S W D, P2 the arrow keys (left, down, up, right).
## The beat comes from fest_sfx.gd, all notes sit on its quarter beats.
##
##   var mg = DjGame.new();  mg.sfx = <fest_sfx node>;  main.add_child(mg);  mg.open()
## Emits finished([score P1, score P2]) after the result screen, or finished([]) if somebody
## left with Esc / Backspace.

signal finished(scores: Array)

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const ART = preload("res://scripts/character_art.gd")

# ---- tuning
const BPM := 120.0             # has to match fest_sfx.gd
const LEAD_IN := 3.0           # seconds before the first note is due
const SONG := 30.0             # seconds of notes
const FALL := 1.5              # seconds a note is on its way down
const HITS := [[0.06, 100, "PERFEKT!"], [0.12, 60, "GUT"], [0.19, 30, "OK"]]   # [seconds off, points, word]
const COMBO_STEP := 5          # every so many hits in a row ...
const COMBO_GAIN := 0.1        # ... are worth this much more
const COMBO_MAX := 2.0
const ON_BEAT := 0.85          # chance of a note on a beat
const OFF_BEAT := 0.3          # ... and between two beats
const RESULT_TIME := 5.0

const LANES := ["left", "down", "up", "right"]
const LANE_COLORS := ["9b6bff", "4d8dff", "3ddc97", "ff8c42"]
const LANE_DIRS := [Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 0)]
const P1_LETTERS := ["A", "S", "W", "D"]

var sfx = null
var clock := 0.0
var notes: Array = []                    # {"t": seconds, "lane": 0..3}
var state: Array = [[], []]              # per player and note: 0 = coming, 1 = hit, 2 = missed
var score: Array = [0, 0]
var combo: Array = [0, 0]
var best: Array = [0, 0]
var word: Array = ["", ""]               # last judgement per player
var word_t: Array = [0.0, 0.0]
var word_col: Array = [Color.WHITE, Color.WHITE]
var tapped: Array = [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]   # key caps light up
var bursts: Array = []                   # [position, age, colour]
var phase := "play"                      # play, result
var result_t := 0.0
var looks: Array = []
var canvas: Control


func open() -> void:
	layer = 20
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_all)
	for pid in 2:
		var lk: Dictionary = (Game.player_looks[pid] as Dictionary).duplicate(true)
		var acc: Array = lk.get("acc", [])
		acc.erase("backpack")
		if not acc.has("headphones"):
			acc.append("headphones")
		lk["acc"] = acc
		looks.append(lk)
	_make_notes()
	if sfx:
		sfx.beat_on()
		sfx.play("scratch", -6.0)


## The same notes for both: on the quarter beats, more of them on the beat and towards the end.
func _make_notes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var step := 60.0 / BPM / 2.0
	var k := 0
	var last := -1
	var run := 0
	while LEAD_IN + k * step < LEAD_IN + SONG:
		var p := ON_BEAT if k % 2 == 0 else OFF_BEAT
		p *= lerpf(0.75, 1.15, k * step / SONG)
		if rng.randf() < p:
			var lane := rng.randi() % 4
			if lane == last:
				run += 1
				if run >= 2:
					lane = (lane + 1 + rng.randi() % 3) % 4
					run = 0
			else:
				run = 0
			last = lane
			notes.append({"t": LEAD_IN + k * step, "lane": lane})
		k += 1
	for pid in 2:
		var st: Array = []
		st.resize(notes.size())
		st.fill(0)
		state[pid] = st


func _mult(pid: int) -> float:
	@warning_ignore("integer_division")
	return minf(COMBO_MAX, 1.0 + COMBO_GAIN * (int(combo[pid]) / COMBO_STEP))


## Player pid taps lane `lane` (0..3) right now.
func tap(pid: int, lane: int) -> void:
	if phase != "play":
		return
	tapped[pid][lane] = 0.15
	var best_i := -1
	var best_d := 99.0
	for i in notes.size():
		if state[pid][i] != 0 or int(notes[i]["lane"]) != lane:
			continue
		var d := absf(float(notes[i]["t"]) - clock)
		if d < best_d:
			best_d = d
			best_i = i
	var limit: float = HITS[HITS.size() - 1][0]
	if best_i < 0 or best_d > limit:
		combo[pid] = 0
		_say(pid, "DANEBEN", UI.MUTED)
		return
	state[pid][best_i] = 1
	for h in HITS:
		if best_d <= float(h[0]):
			score[pid] += int(round(float(h[1]) * _mult(pid)))
			combo[pid] += 1
			best[pid] = maxi(best[pid], combo[pid])
			_say(pid, String(h[2]), UI.GREEN if int(h[1]) >= 100 else (UI.YELLOW if int(h[1]) >= 60 else UI.ORANGE))
			bursts.append([_lane_x(pid, lane), 0.0, Color(LANE_COLORS[lane])])
			if sfx:
				sfx.play("hit", -13.0, 1.0 + lane * 0.12)
			return


func _say(pid: int, w: String, col: Color) -> void:
	word[pid] = w
	word_t[pid] = 0.5
	word_col[pid] = col


func _process(delta: float) -> void:
	clock += delta
	for pid in 2:
		word_t[pid] = maxf(0.0, word_t[pid] - delta)
		for l in 4:
			tapped[pid][l] = maxf(0.0, tapped[pid][l] - delta)
	for b in bursts:
		b[1] += delta
	bursts = bursts.filter(func(b): return b[1] < 0.3)
	if phase == "play":
		var limit: float = HITS[HITS.size() - 1][0]
		for pid in 2:
			for i in notes.size():
				if state[pid][i] == 0 and clock - float(notes[i]["t"]) > limit:
					state[pid][i] = 2
					combo[pid] = 0
					_say(pid, "VERPASST", UI.RED)
		if clock > LEAD_IN + SONG + 1.2:
			phase = "result"
			result_t = 0.0
			if sfx:
				sfx.beat_off()
				sfx.play("cheer", -4.0)
			UI.sfx("fanfare")
	else:
		result_t += delta
		if result_t >= RESULT_TIME:
			_end()
	canvas.queue_redraw()


func _end() -> void:
	if sfx:
		sfx.beat_off()
	finished.emit([score[0], score[1]])
	queue_free()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	for pid in 2:
		var keys: Dictionary = KEYS.PLAYER_KEYS[pid]
		if k in (keys["abort"] as Array) and phase == "play":
			get_viewport().set_input_as_handled()
			if sfx:
				sfx.beat_off()
			finished.emit([])
			queue_free()
			return
		if phase == "result" and result_t > 1.5 and k in (keys["interact"] as Array):
			get_viewport().set_input_as_handled()
			_end()
			return
		for l in 4:
			if k in (keys[LANES[l]] as Array):
				get_viewport().set_input_as_handled()
				tap(pid, l)
				return


# ------------------------------------------------------------------ drawing
func _size() -> Vector2:
	return canvas.size


func _block(pid: int) -> Rect2:
	var s := _size()
	var w := s.x * 0.24
	return Rect2(s.x * 0.035 if pid == 0 else s.x * 0.965 - w, s.y * 0.1, w, s.y * 0.7)


## Where the hit line of a lane is.
func _lane_x(pid: int, lane: int) -> Vector2:
	var b := _block(pid)
	return Vector2(b.position.x + b.size.x * (lane + 0.5) / 4.0, b.end.y)


func _text(pos: Vector2, s: String, size: int, col: Color, centered: bool = false, outline: int = 6) -> void:
	var font := ThemeDB.fallback_font
	var p := pos
	if centered:
		p.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	if outline > 0:
		canvas.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, UI.DARK)
	canvas.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _arrow(c: Vector2, dir: Vector2, r: float, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	canvas.draw_colored_polygon(PackedVector2Array([c + dir * r, c - dir * r * 0.6 + side * r * 0.85, c - dir * r * 0.6 - side * r * 0.85]), col)


func _draw_all() -> void:
	var s := _size()
	var beat := 60.0 / BPM
	var pump := pow(1.0 - fmod(clock, beat) / beat, 2.0)   # 1 on the beat, falls off
	# the club: dark, with light beams from the ceiling
	canvas.draw_rect(Rect2(Vector2.ZERO, s), Color("120b24"))
	canvas.draw_rect(Rect2(0, s.y * 0.55, s.x, s.y * 0.45), Color("1b1136"))
	var beams := ["ff5d8f", "4d8dff", "3ddc97", "ffc93c", "9b6bff", "ff8c42"]
	for i in beams.size():
		var bx := s.x * (0.1 + 0.16 * i)
		var sway := sin(clock * 0.7 + i * 1.3) * s.x * 0.12
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(bx - 8.0, 0), Vector2(bx + 8.0, 0), Vector2(bx + sway + s.x * 0.07, s.y * 0.9), Vector2(bx + sway - s.x * 0.07, s.y * 0.9)]),
			Color(Color(beams[i]), 0.06 + 0.07 * pump))
	_draw_table(pump)
	for pid in 2:
		_draw_lanes(pid)
	_draw_scores()
	_draw_crowd(pump)
	# what is on top
	var left := LEAD_IN - clock
	if phase == "play" and left > -0.6:
		var n := int(ceil(left))
		_text(Vector2(s.x / 2.0, s.y * 0.42), UI.T("LOS!") if left <= 0.0 else str(n), 120, UI.YELLOW, true, 18)
	if phase == "result":
		_draw_result()


## The DJ table with the two players behind it: the background the user asked for.
func _draw_table(pump: float) -> void:
	var s := _size()
	var t := Rect2(s.x * 0.32, s.y * 0.6, s.x * 0.36, s.y * 0.27)
	# speakers left and right of the table, the cones pump
	for sx in [-1.0, 1.0]:
		var sp := Rect2(t.get_center().x + sx * (t.size.x / 2.0 + 44.0) - 34.0, t.position.y - 70.0, 68.0, t.size.y + 70.0)
		canvas.draw_rect(sp, Color("0b0716"))
		canvas.draw_rect(sp, Color("3a2d5c"), false, 3.0)
		for j in 2:
			var cc := Vector2(sp.get_center().x, sp.position.y + 48.0 + j * 86.0)
			canvas.draw_circle(cc, 26.0 + pump * 4.0, Color("241a3d"))
			canvas.draw_circle(cc, 15.0 + pump * 6.0, Color("5a4a8a"))
			canvas.draw_circle(cc, 6.0, Color("0b0716"))
	# the two DJs
	for pid in 2:
		var at := Vector2(t.position.x + t.size.x * (0.27 + 0.46 * pid), t.position.y + 16.0 - absf(sin(clock * PI / (60.0 / BPM))) * 6.0)
		ART.draw_character(canvas, looks[pid], ART.FRONT, clock * 8.0, true, at, 3.6)
	canvas.draw_rect(t, Color("0b0716"))
	canvas.draw_rect(Rect2(t.position, Vector2(t.size.x, 10.0)), Color("3a2d5c"))
	canvas.draw_rect(t, Color("3a2d5c"), false, 3.0)
	# turntables: one per player, the record carries their colour
	for pid in 2:
		var c := Vector2(t.position.x + t.size.x * (0.2 + 0.6 * pid), t.position.y + t.size.y * 0.52)
		var r := minf(t.size.y * 0.36, t.size.x * 0.15)
		canvas.draw_rect(Rect2(c - Vector2(r + 12.0, r + 12.0), Vector2(r * 2.0 + 24.0, r * 2.0 + 24.0)), Color("241a3d"))
		canvas.draw_circle(c, r, Color("08060f"))
		for g in 3:
			canvas.draw_arc(c, r * (0.5 + g * 0.16), 0.0, TAU, 40, Color(1, 1, 1, 0.07), 1.0)
		canvas.draw_circle(c, r * 0.34, Color(KEYS.TAG_COLORS[pid]))
		var a := clock * 4.0 * (1.0 if pid == 0 else -1.0)
		canvas.draw_line(c, c + Vector2.from_angle(a) * r * 0.9, Color(1, 1, 1, 0.25), 2.0)
		canvas.draw_circle(c, 3.0, Color.WHITE)
		canvas.draw_line(c + Vector2(r + 6.0, -r - 4.0), c + Vector2(r * 0.55, -r * 0.2), Color("c9d1d6"), 4.0)   # tone arm
	# the mixer in the middle: the crossfader leans to whoever is ahead
	var m := Rect2(t.get_center().x - t.size.x * 0.12, t.position.y + 22.0, t.size.x * 0.24, t.size.y - 34.0)
	canvas.draw_rect(m, Color("241a3d"))
	canvas.draw_rect(m, Color("5a4a8a"), false, 2.0)
	for j in 6:   # level meters
		var hgt := (0.25 + 0.7 * absf(sin(clock * 9.0 + j * 1.7))) * (0.5 + 0.5 * pump) * m.size.y * 0.42
		canvas.draw_rect(Rect2(m.position.x + 10.0 + j * (m.size.x - 20.0) / 6.0, m.position.y + m.size.y * 0.5 - hgt, (m.size.x - 20.0) / 6.0 - 3.0, hgt),
			UI.GREEN if hgt < m.size.y * 0.28 else UI.ORANGE)
	var total: float = maxf(1.0, float(score[0] + score[1]))
	var lean := 0.5 if (score[0] + score[1]) == 0 else float(score[1]) / total
	var fy := m.end.y - 22.0
	canvas.draw_rect(Rect2(m.position.x + 12.0, fy, m.size.x - 24.0, 6.0), Color("08060f"))
	canvas.draw_rect(Rect2(m.position.x + 12.0 + (m.size.x - 24.0) * lean - 8.0, fy - 8.0, 16.0, 22.0), Color.WHITE)


func _draw_lanes(pid: int) -> void:
	var b := _block(pid)
	var pc := Color(KEYS.TAG_COLORS[pid])
	var lw := b.size.x / 4.0
	canvas.draw_rect(Rect2(b.position.x - 6.0, b.position.y - 6.0, b.size.x + 12.0, b.size.y + 70.0), Color(0.03, 0.02, 0.08, 0.72))
	canvas.draw_rect(Rect2(b.position.x - 6.0, b.position.y - 6.0, b.size.x + 12.0, b.size.y + 70.0), pc, false, 4.0)
	for l in 4:
		var lc := Color(LANE_COLORS[l])
		canvas.draw_rect(Rect2(b.position.x + l * lw + 2.0, b.position.y, lw - 4.0, b.size.y), Color(lc, 0.07 + 0.25 * float(tapped[pid][l]) / 0.15))
	# the notes
	var r := minf(lw * 0.36, 30.0)
	for i in notes.size():
		var st: int = state[pid][i]
		if st == 1:
			continue
		var dt := float(notes[i]["t"]) - clock
		if dt > FALL or dt < -0.35:
			continue
		var l2: int = notes[i]["lane"]
		var c := Vector2(b.position.x + (l2 + 0.5) * lw, b.end.y - dt / FALL * b.size.y)
		var col := Color(LANE_COLORS[l2]) if st == 0 else Color(0.4, 0.4, 0.45, 0.6)
		canvas.draw_rect(Rect2(c - Vector2(r, r) - Vector2(3, 3), Vector2(r * 2.0 + 6.0, r * 2.0 + 6.0)), UI.DARK)
		canvas.draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), col)
		_arrow(c, LANE_DIRS[l2], r * 0.55, Color.WHITE)
	# the line, and under it the key for each lane
	canvas.draw_rect(Rect2(b.position.x, b.end.y - 3.0, b.size.x, 6.0), Color.WHITE)
	for l in 4:
		var kc := _lane_x(pid, l) + Vector2(0, 34.0)
		var lit: bool = float(tapped[pid][l]) > 0.0
		canvas.draw_rect(Rect2(kc - Vector2(r, 22.0), Vector2(r * 2.0, 44.0)), Color(LANE_COLORS[l]) if lit else Color("241a3d"))
		canvas.draw_rect(Rect2(kc - Vector2(r, 22.0), Vector2(r * 2.0, 44.0)), Color(LANE_COLORS[l]), false, 3.0)
		if pid == 0:
			_text(kc + Vector2(0, 9.0), P1_LETTERS[l], 24, Color.WHITE, true, 0)
		else:
			_arrow(kc, LANE_DIRS[l], 11.0, Color.WHITE)
	for bu in bursts:
		var u: float = float(bu[1]) / 0.3
		canvas.draw_arc(bu[0], r * (1.0 + u * 1.6), 0.0, TAU, 24, Color(bu[2] as Color, 1.0 - u), 5.0)
	if float(word_t[pid]) > 0.0:
		var up: float = (0.5 - float(word_t[pid])) * 50.0
		_text(Vector2(b.get_center().x, b.end.y - 60.0 - up), UI.T(String(word[pid])), 34, word_col[pid], true, 8)


func _draw_scores() -> void:
	var s := _size()
	_text(Vector2(s.x / 2.0, s.y * 0.085), UI.T("DJ-BATTLE"), 44, UI.YELLOW, true, 10)
	# how much of the song is left
	var bar := Rect2(s.x * 0.36, s.y * 0.105, s.x * 0.28, 8.0)
	canvas.draw_rect(bar, UI.DARK)
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf((clock - LEAD_IN) / SONG, 0.0, 1.0), bar.size.y)), UI.YELLOW)
	for pid in 2:
		var pc := Color(KEYS.TAG_COLORS[pid])
		var cx := s.x * (0.41 if pid == 0 else 0.59)
		_text(Vector2(cx, s.y * 0.2), Game.name_of(pid), 24, pc, true)
		_text(Vector2(cx, s.y * 0.29), str(score[pid]), 56, UI.WHITE, true, 10)
		if int(combo[pid]) >= 2:
			_text(Vector2(cx, s.y * 0.35), UI.T("Kombo %d") % int(combo[pid]) + ("  x%.1f" % _mult(pid) if _mult(pid) > 1.0 else ""), 22, UI.YELLOW, true)


func _draw_crowd(pump: float) -> void:
	var s := _size()
	var n := 26
	for i in n:
		var x := s.x * (i + 0.5) / n + sin(i * 7.3) * 9.0
		var hop := absf(sin(clock * PI / (60.0 / BPM) + i * 0.9)) * 12.0 + pump * 5.0
		var y := s.y + 26.0 - hop - fmod(i * 13.0, 22.0)
		canvas.draw_circle(Vector2(x, y - 44.0), 17.0, Color("07050d"))
		canvas.draw_rect(Rect2(x - 20.0, y - 30.0, 40.0, 70.0), Color("07050d"))
		if i % 3 == 0:   # hands in the air
			canvas.draw_line(Vector2(x - 16.0, y - 26.0), Vector2(x - 26.0, y - 74.0 - hop), Color("07050d"), 8.0)
			canvas.draw_line(Vector2(x + 16.0, y - 26.0), Vector2(x + 26.0, y - 74.0 - hop), Color("07050d"), 8.0)


func _draw_result() -> void:
	var s := _size()
	canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.02, 0.08, 0.9))
	var win := -1
	if score[0] != score[1]:
		win = 0 if score[0] > score[1] else 1
	var col := UI.YELLOW if win < 0 else Color(KEYS.TAG_COLORS[win])
	var head := UI.T("Unentschieden!") if win < 0 else UI.T("DJ %s gewinnt!") % Game.name_of(win)
	var pop := minf(1.0, result_t / 0.25)
	_text(Vector2(s.x / 2.0, s.y * 0.36), head, int(76 * (0.6 + 0.4 * pop)), col, true, 14)
	for pid in 2:
		var cx := s.x * (0.36 if pid == 0 else 0.64)
		_text(Vector2(cx, s.y * 0.52), Game.name_of(pid), 30, Color(KEYS.TAG_COLORS[pid]), true)
		_text(Vector2(cx, s.y * 0.63), str(score[pid]), 70, UI.WHITE, true, 12)
		_text(Vector2(cx, s.y * 0.7), UI.T("längste Kombo: %d") % int(best[pid]), 22, UI.MUTED, true)
	if result_t > 1.5:
		_text(Vector2(s.x / 2.0, s.y * 0.84), UI.T("%s oder %s: weiter") % [KEYS.LABELS[0]["ok"], KEYS.LABELS[1]["ok"]], 20, UI.MUTED, true)
