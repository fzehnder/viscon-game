extends Control
## Character design for both players at once (part of the intro in menu.gd). Each player has a
## card: the figure on a spot in the light, turning, and under it the things to choose. Both
## choose at the same time with their own keys; the mouse works too.
##   P1: W / S line, A / D change, Q something random, E ready
##   P2: arrows up / down line, left / right change, - something random, Enter ready
## When both are ready, `done` is emitted. The looks are changed in place (Game.player_looks),
## the study programme in Game.programmes.

signal done

const CH = preload("res://scripts/characters.gd")
const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")

const W := 1280.0                 # laid out for this size, scaled to the screen
const H := 720.0
const CARD := Vector2(540.0, 598.0)
const CARD_Y := 76.0
const STAGE := Rect2(16.0, 52.0, 508.0, 194.0)    # inside a card: where the figure stands
const ROW_Y := 254.0              # first line
const ROW_H := 30.0
const VALUE_X := 338.0            # middle of what is chosen in a line
const DOT_GAP := 30.0
const RANDOM_KEYS := [KEY_Q, KEY_SLASH]          # P1, P2 (the "-" key on a Swiss keyboard)
const RANDOM_NAMES := ["Q", "-"]
const TURN := [ART.FRONT, ART.RIGHT, ART.BACK, ART.LEFT]

var rows: Array = []              # what can be chosen: {"key", "name", "opts", "names" (kinds) or not (colours)}
var cur: Array = [0, 0]           # the line each player is on
var ready_p: Array = [false, false]
var hop: Array = [0.0, 0.0]       # > 0 for a moment after a change: the figure jumps and looks to the front
var t := 0.0
var leaving := -1.0               # > 0: both are ready, seconds until `done`


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var prog_names := {}
	var prog_ids: Array = []
	for k in Game.PROGRAMMES.size():
		prog_ids.append(k)
		prog_names[k] = String(Game.PROGRAMMES[k][0])
	rows = [
		{"key": "hair_style", "name": "Frisur", "opts": CH.HAIR_STYLES, "names": CH.HAIR_NAMES},
		{"key": "hair", "name": "Haarfarbe", "opts": CH.HAIR_COLORS},
		{"key": "skin", "name": "Hautton", "opts": CH.SKIN_TONES},
		{"key": "top_style", "name": "Oberteil", "opts": CH.PLAYER_TOPS, "names": CH.TOP_NAMES},
		{"key": "top", "name": "Farbe", "opts": CH.TOP_COLORS},
		{"key": "pants", "name": "Hose", "opts": CH.PANTS_COLORS},
		{"key": "shoes", "name": "Schuhe", "opts": CH.SHOE_COLORS},
		{"key": "extra", "name": "Extra", "opts": CH.EXTRAS, "names": CH.EXTRA_NAMES},
		{"key": "studium", "name": "Studium", "opts": prog_ids, "names": prog_names},
	]
	# a colour that is not among the dots (the looks the figures start with have some): the nearest
	# dot takes its place, so that every line shows what is chosen
	for i in 2:
		var lk: Dictionary = Game.player_looks[i]
		for r in rows.size():
			if rows[r].has("names") or _index(i, r) >= 0:
				continue
			var have := ART.col(lk, String(rows[r]["key"]), String(rows[r]["opts"][0]))
			var best := 0
			var best_d := INF
			for n in (rows[r]["opts"] as Array).size():
				var c := Color(String(rows[r]["opts"][n]))
				var d := Vector3(c.r - have.r, c.g - have.g, c.b - have.b).length_squared()
				if d < best_d:
					best_d = d
					best = n
			lk[String(rows[r]["key"])] = rows[r]["opts"][best]


func _process(delta: float) -> void:
	t += delta
	for i in 2:
		hop[i] = maxf(0.0, hop[i] - delta)
	if leaving > 0.0:
		leaving -= delta
		if leaving <= 0.0:
			done.emit()
	queue_redraw()


# ------------------------------------------------------------------ what is chosen
func _value(i: int, r: int):
	var key: String = rows[r]["key"]
	var lk: Dictionary = Game.player_looks[i]
	match key:
		"extra":
			for a in lk.get("acc", []):
				if a in CH.EXTRAS:
					return a
			return ""
		"studium":
			return int(Game.programmes[i])
	return lk.get(key, rows[r]["opts"][0])


func _index(i: int, r: int) -> int:
	return (rows[r]["opts"] as Array).find(_value(i, r))


func _choose(i: int, r: int, k: int) -> void:
	var opts: Array = rows[r]["opts"]
	var v = opts[posmod(k, opts.size())]
	var key: String = rows[r]["key"]
	var lk: Dictionary = Game.player_looks[i]
	match key:
		"extra":
			var acc: Array = (lk.get("acc", []) as Array).filter(func(a): return not (a in CH.EXTRAS))
			if String(v) != "":
				acc.append(v)
			lk["acc"] = acc
		"studium":
			Game.programmes[i] = int(v)
		_:
			lk[key] = v
	hop[i] = 1.3
	_unready(i)


func _change(i: int, r: int, dir: int) -> void:
	var k := _index(i, r)
	_choose(i, r, (0 if dir > 0 else -1) if k < 0 else k + dir)
	UI.sfx("pop", -8.0)


func _random(i: int) -> void:
	for r in rows.size():
		if rows[r]["key"] != "studium":
			_choose(i, r, randi() % (rows[r]["opts"] as Array).size())
	UI.sfx("steal", -10.0)


func _unready(i: int) -> void:
	if ready_p[i]:
		ready_p[i] = false
		leaving = -1.0


func _toggle_ready(i: int) -> void:
	ready_p[i] = not ready_p[i]
	if ready_p[i]:
		hop[i] = 1.3
		UI.sfx("grant", -8.0)
		if ready_p[0] and ready_p[1]:
			leaving = 0.9
			UI.sfx("success", -8.0)
	else:
		leaving = -1.0
		UI.sfx("click")


# ------------------------------------------------------------------ keys and mouse
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or leaving > 0.0 and leaving < 0.3:
		return
	var k: int = event.physical_keycode
	for i in 2:
		var keys: Dictionary = KEYS.PLAYER_KEYS[i]
		var used := true
		if k in keys["up"]:
			cur[i] = posmod(cur[i] - 1, rows.size())
			UI.sfx("click", -10.0)
		elif k in keys["down"]:
			cur[i] = posmod(cur[i] + 1, rows.size())
			UI.sfx("click", -10.0)
		elif k in keys["left"]:
			_change(i, cur[i], -1)
		elif k in keys["right"]:
			_change(i, cur[i], 1)
		elif event.echo:
			used = false
		elif k == RANDOM_KEYS[i]:
			_random(i)
		elif (i == 0 and k == KEY_E) or (i == 1 and k in [KEY_ENTER, KEY_KP_ENTER]):
			_toggle_ready(i)
		else:
			used = false
		if used:
			get_viewport().set_input_as_handled()
			return


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var k := minf(size.x / W, size.y / H)
	var p: Vector2 = (event.position - (size - Vector2(W, H) * k) / 2.0) / k
	for i in 2:
		var q := p - _card(i).position
		if not Rect2(Vector2.ZERO, CARD).has_point(q):
			continue
		for r in rows.size():
			var y := ROW_Y + r * ROW_H
			if q.y < y or q.y >= y + ROW_H:
				continue
			cur[i] = r
			var opts: Array = rows[r]["opts"]
			if rows[r].has("names"):
				_change(i, r, -1 if q.x < VALUE_X else 1)
			else:
				var best := int(round((q.x - VALUE_X) / DOT_GAP + (opts.size() - 1) / 2.0))
				if best >= 0 and best < opts.size():
					_choose(i, r, best)
					UI.sfx("pop", -8.0)
			return
		if _random_rect().has_point(q):
			_random(i)
		elif _ready_rect().has_point(q):
			_toggle_ready(i)
		return


# ------------------------------------------------------------------ drawing
func _card(i: int) -> Rect2:
	return Rect2(Vector2(W / 2.0 - 16.0 - CARD.x if i == 0 else W / 2.0 + 16.0, CARD_Y), CARD)


func _random_rect() -> Rect2:
	return Rect2(22.0, CARD.y - 60.0, 196.0, 40.0)


func _ready_rect() -> Rect2:
	return Rect2(CARD.x - 262.0, CARD.y - 60.0, 240.0, 40.0)


func _text(pos: Vector2, s: String, fsize: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 0) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline, Color("15162b"))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


## A key cap with what it does next to it. Returns the width it took.
func _key(pos: Vector2, cap: String, what: String, col: Color, what_col: Color = UI.INK2) -> float:
	var font := ThemeDB.fallback_font
	var cw := maxf(26.0, font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14.0)
	draw_style_box(UI.box(col, Color(0, 0, 0, 0), 7, 0, 0, false), Rect2(pos.x, pos.y - 17.0, cw, 24.0))
	_text(Vector2(pos.x + cw / 2.0, pos.y), cap, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(pos.x + cw + 7.0, pos.y), what, 14, what_col)
	return cw + 7.0 + font.get_string_size(what, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0


func _draw() -> void:
	var k := minf(size.x / W, size.y / H)
	var o := (size - Vector2(W, H) * k) / 2.0
	draw_set_transform(o, 0.0, Vector2(k, k))
	_text(Vector2(W / 2.0, 54.0), "Gestaltet eure Figuren", 40, UI.ETH_BLUE, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 2:
		var pc := Color(String(KEYS.TAG_COLORS[i]))
		var pd := pc.darkened(0.18)              # the player's colour so that it reads on paper
		var card := _card(i)
		var at := card.position
		var edge: Color = UI.OK if ready_p[i] else pc
		draw_style_box(UI.box(UI.PAPER, edge, 16, 3, 0), card)
		# head line: name, and the keys of this player
		_text(at + Vector2(24.0, 36.0), Game.name_of(i), 28, pd)
		var kx := at.x + CARD.x - 232.0
		kx += _key(Vector2(kx, at.y + 33.0), "W S" if i == 0 else "↑ ↓", "Zeile", pd)
		_key(Vector2(kx, at.y + 33.0), "A D" if i == 0 else "← →", "ändern", pd)
		# the stage: dark, a cone of light from above, a spot in the player's colour
		var st := Rect2(at + STAGE.position, STAGE.size)
		draw_style_box(UI.box(Color("15162b"), Color(0, 0, 0, 0), 14, 0, 0, false), st)
		var feet := Vector2(st.get_center().x, st.end.y - 30.0)
		draw_colored_polygon(PackedVector2Array([Vector2(feet.x - 26.0, st.position.y), Vector2(feet.x + 26.0, st.position.y),
			Vector2(feet.x + 118.0, feet.y + 6.0), Vector2(feet.x - 118.0, feet.y + 6.0)]), Color(1, 1, 1, 0.06))
		draw_set_transform(o + feet * k, 0.0, Vector2(k, k * 0.3))
		draw_circle(Vector2.ZERO, 118.0, Color(pc, 0.3))
		draw_arc(Vector2.ZERO, 118.0, 0.0, TAU, 48, Color(edge, 0.95), 5.0, true)
		draw_set_transform(o, 0.0, Vector2(k, k))
		for sp in 5:                              # dust in the light
			var a := t * 0.5 + sp * 1.3 + i
			draw_circle(Vector2(feet.x + sin(a) * (30.0 + sp * 14.0), st.position.y + 20.0 + fposmod(t * 14.0 + sp * 37.0, 130.0)), 1.6, Color(1, 1, 1, 0.25))
		var jump := absf(sin(hop[i] * PI * 2.0)) * 14.0 * minf(1.0, hop[i])
		if ready_p[i]:
			jump = absf(sin(t * 7.0 + i)) * 9.0
		var face: int = ART.FRONT if (hop[i] > 0.0 or ready_p[i]) else TURN[int(t / 1.5 + i) % 4]
		ART.draw_character(self, Game.player_looks[i], face, t * 7.0, true, o + (feet - Vector2(0, jump)) * k, 3.75 * k)
		draw_set_transform(o, 0.0, Vector2(k, k))
		# the lines
		for r in rows.size():
			var y := at.y + ROW_Y + r * ROW_H
			var on: bool = cur[i] == r and not ready_p[i]
			if on:
				draw_style_box(UI.box(Color(pc, 0.16), pc, 9, 2, 0, false), Rect2(at.x + 14.0, y + 1.0, CARD.x - 28.0, ROW_H - 2.0))
			_text(Vector2(at.x + 28.0, y + 21.0), String(rows[r]["name"]), 15, UI.INK if on else UI.INK2)
			var opts: Array = rows[r]["opts"]
			var sel := _index(i, r)
			var cx := at.x + VALUE_X
			if rows[r].has("names"):
				var label := String((rows[r]["names"] as Dictionary).get(_value(i, r), str(_value(i, r))))
				_text(Vector2(cx, y + 21.0), label, 17, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
				_text(Vector2(cx - 150.0, y + 22.0), "‹", 22, pd if on else UI.INK2, HORIZONTAL_ALIGNMENT_CENTER)
				_text(Vector2(cx + 150.0, y + 22.0), "›", 22, pd if on else UI.INK2, HORIZONTAL_ALIGNMENT_CENTER)
				# where in the list: small ticks under the name
				for n in opts.size():
					var tx := cx + (n - (opts.size() - 1) / 2.0) * 8.0
					draw_rect(Rect2(tx - 2.5, y + ROW_H - 5.0, 5.0, 2.0), UI.INK if n == sel else UI.LINE)
			else:
				for n in opts.size():
					var c := Vector2(cx + (n - (opts.size() - 1) / 2.0) * DOT_GAP, y + ROW_H / 2.0)
					if n == sel:
						draw_circle(c, 13.0, UI.INK)
						draw_circle(c, 11.0, UI.PAPER)
						draw_circle(c, 9.0, Color(String(opts[n])))
					else:
						draw_circle(c, 8.0, UI.LINE)
						draw_circle(c, 7.0, Color(String(opts[n])))
		# below: something random, and ready
		var rr := _random_rect()
		rr.position += at
		draw_style_box(UI.box(UI.PAPER2, UI.LINE, 12, 2, 0, false), rr)
		_key(rr.position + Vector2(14.0, 26.0), RANDOM_NAMES[i], "Zufall", UI.ETH_BLUE, UI.INK)
		var gr := _ready_rect()
		gr.position += at
		if ready_p[i]:
			draw_style_box(UI.box(UI.OK, Color(0, 0, 0, 0), 12, 0, 0, false), gr)
			_text(gr.get_center() + Vector2(0, 7.0), "BEREIT ✓", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var beat := 0.5 + 0.5 * sin(t * 4.0)
			draw_style_box(UI.box(Color(pc, 0.12 + 0.14 * beat), pc, 12, 2, 0, false), gr)
			var cap := "E" if i == 0 else "Enter"
			var tw := ThemeDB.fallback_font.get_string_size("bereit?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			_key(Vector2(gr.get_center().x - (tw + 50.0) / 2.0, gr.position.y + 26.0), cap, "bereit?", pd, UI.INK)
	var both: bool = ready_p[0] and ready_p[1]
	_text(Vector2(W / 2.0, H - 16.0), "Los geht's!" if both else "Sind beide bereit, geht es weiter zur Legi.", 16, UI.OK if both else UI.INK2, HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
