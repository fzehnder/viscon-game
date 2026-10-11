extends CanvasLayer
## Level 18 (Ersti-Fest): getting past the bouncer. The party is sold out, so the two players
## stack up under one long coat and pretend to be one tall guest. One of them is the legs and
## walks (holds "right"), the other one sits on top and leans against the swaying (left / right).
## If the tower leans too far, both tumble out of the coat, the bouncer has a good laugh, and they
## start again a bit further back. Only together they get to the door.
##
##   var mg = SneakGame.new();  mg.legs = pid;  main.add_child(mg);  mg.open()
## Emits mistake on every fall and finished(true) at the door, finished(false) on Esc / Backspace.

signal finished(success: bool)
signal mistake

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const ART = preload("res://scripts/character_art.gd")

# ---- tuning
const WALK := 0.11         # share of the way per second while the legs walk
const TIP := 34.0          # degrees at which the two fall apart
const WOBBLE := 30.0       # degrees per second squared of swaying while standing
const STEP_PUSH := 62.0    # ... and on top of that from every step
const GRAVITY := 2.4       # the further it leans, the faster it tips
const STEER := 150.0       # degrees per second squared the upper player can lean against it
const DAMP := 1.5
const BACK := 0.3          # how far back they start again after a fall

const COAT := Color("c8a878")
const BOUNCER := {"skin": "c68863", "hair": "1a1a1a", "hair_style": "glatze", "top": "15161c", "top_style": "jacket",
	"accent": "15161c", "pants": "15161c", "shoes": "0c0c10", "acc": ["glasses"]}

var legs := 0              # pid of the player who walks; the other one is on top
var sfx = null
var x := 0.0               # 0 = start, 1 = at the door
var tilt := 0.0            # degrees, + = leaning towards the door
var tilt_v := 0.0
var step := 0.0
var walking := false
var fall_t := -1.0
var fall_dir := 1.0
var closing := -1.0
var t := 0.0
var canvas: Control
var tower: Control


func head() -> int:
	return 1 - legs


func open() -> void:
	layer = 20
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_all)
	tower = Control.new()
	tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tower.draw.connect(_draw_tower)
	canvas.add_child(tower)
	UI.sfx("whoosh", -10.0)


func _process(delta: float) -> void:
	t += delta
	if closing >= 0.0:
		closing -= delta
		tilt = lerpf(tilt, 0.0, 1.0 - exp(-6.0 * delta))
		if closing < 0.0:
			finished.emit(true)
			queue_free()
			return
	elif fall_t >= 0.0:
		fall_t -= delta
		if fall_t < 0.0:
			x = maxf(0.0, x - BACK)
			tilt = 0.0
			tilt_v = 0.0
	else:
		walking = Input.is_action_pressed(KEYS.action(legs, "right"))
		var steer := Input.get_axis(KEYS.action(head(), "left"), KEYS.action(head(), "right"))
		var push := WOBBLE * (sin(t * 1.7 + 0.5) + 0.7 * sin(t * 3.1))
		if walking:
			x += WALK * delta
			step += delta * 8.0
			push += STEP_PUSH * sin(step * 0.5)
		tilt_v += (push + tilt * GRAVITY + steer * STEER) * delta
		tilt_v -= tilt_v * DAMP * delta
		tilt += tilt_v * delta
		if absf(tilt) >= TIP:
			fall_t = 1.6
			fall_dir = signf(tilt)
			walking = false
			mistake.emit()
			if sfx:
				sfx.play("thud", -4.0)
			UI.sfx("fail", -8.0)
		elif x >= 1.0:
			x = 1.0
			walking = false
			closing = 1.8
			UI.sfx("grant", -6.0)
	_place()
	canvas.queue_redraw()
	tower.queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k in (KEYS.PLAYER_KEYS[0]["abort"] as Array) or k in (KEYS.PLAYER_KEYS[1]["abort"] as Array):
		get_viewport().set_input_as_handled()
		if closing < 0.0:
			finished.emit(false)
			queue_free()


# ------------------------------------------------------------------ drawing
func _size() -> Vector2:
	return canvas.size


func _ground() -> float:
	return _size().y * 0.8


func _k() -> float:
	return _size().y / 720.0 * 4.6   # px per figure unit


func _place() -> void:
	var s := _size()
	tower.position = Vector2(lerpf(s.x * 0.12, s.x * 0.74, x), _ground())
	var deg := tilt
	if fall_t >= 0.0:
		deg = fall_dir * lerpf(TIP, 92.0, clampf((1.6 - fall_t) / 0.45, 0.0, 1.0))
	tower.rotation = deg_to_rad(deg)


func _text(pos: Vector2, s: String, size: int, col: Color, centered: bool = false, outline: int = 6) -> void:
	var font := ThemeDB.fallback_font
	var p := pos
	if centered:
		p.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	if outline > 0:
		canvas.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, UI.DARK)
	canvas.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Two players in one coat: the legs below, the head with hat and moustache on top.
func _draw_tower() -> void:
	var k := _k()
	ART.draw_character(tower, Game.player_looks[legs], ART.RIGHT, step, walking, Vector2.ZERO, k)
	ART.draw_character(tower, Game.player_looks[head()], ART.RIGHT, 0.0, false, Vector2(0, -27.0 * k), k)
	# the coat hides everything between the upper one's chin and the lower one's knees
	var coat := PackedVector2Array([Vector2(-6.5, -54.0) * k, Vector2(6.5, -54.0) * k, Vector2(10.0, -9.0) * k, Vector2(-10.0, -9.0) * k])
	tower.draw_colored_polygon(coat, COAT)
	tower.draw_colored_polygon(PackedVector2Array([Vector2(1.5, -54.0) * k, Vector2(6.5, -54.0) * k, Vector2(10.0, -9.0) * k, Vector2(3.0, -9.0) * k]), COAT.darkened(0.12))
	tower.draw_rect(Rect2(Vector2(-8.5, -34.0) * k, Vector2(17.0, 2.6) * k), COAT.darkened(0.3))   # belt
	for i in 4:
		tower.draw_circle(Vector2(1.5, -49.0 + i * 9.5) * k, 0.9 * k, COAT.darkened(0.45))
	tower.draw_rect(Rect2(Vector2(-10.5, -50.0) * k, Vector2(3.6, 15.0) * k), COAT.darkened(0.08))   # the sleeves hang empty
	tower.draw_rect(Rect2(Vector2(7.0, -50.0) * k, Vector2(3.6, 15.0) * k), COAT.darkened(0.2))
	# hat and moustache
	tower.draw_rect(Rect2(Vector2(-9.5, -68.5) * k, Vector2(20.0, 1.8) * k), Color("3b2a1e"))
	tower.draw_rect(Rect2(Vector2(-6.0, -74.0) * k, Vector2(12.5, 6.0) * k), Color("3b2a1e"))
	tower.draw_rect(Rect2(Vector2(-6.0, -70.2) * k, Vector2(12.5, 1.4) * k), Color("8a6340"))
	tower.draw_rect(Rect2(Vector2(3.2, -58.6) * k, Vector2(5.0, 1.6) * k), Color("1a1a1a"))


func _draw_all() -> void:
	var s := _size()
	var g := _ground()
	var k := _k()
	var beat := 0.5
	var pump := pow(1.0 - fmod(t, beat) / beat, 2.0)
	# night, the wall of the Mensa with party light behind the windows
	canvas.draw_rect(Rect2(Vector2.ZERO, s), Color("0d1026"))
	for i in 40:
		var sx := fmod(i * 197.3, s.x)
		var sy := fmod(i * 91.7, s.y * 0.3)
		canvas.draw_circle(Vector2(sx, sy), 1.2 + fmod(i * 0.37, 1.2), Color(1, 1, 1, 0.5 + 0.4 * sin(t * 2.0 + i)))
	canvas.draw_rect(Rect2(0, s.y * 0.26, s.x, g - s.y * 0.26), Color("2a2c3d"))
	canvas.draw_rect(Rect2(0, s.y * 0.26, s.x, 10.0), Color("3d4056"))
	var lights := ["ff5d8f", "4d8dff", "3ddc97", "ffc93c", "9b6bff"]
	for i in 5:
		var w := Rect2(s.x * (0.06 + i * 0.145), s.y * 0.36, s.x * 0.1, s.y * 0.2)
		canvas.draw_rect(w, Color("0b0716"))
		canvas.draw_rect(w.grow(-4.0), Color(Color(lights[(i + int(t / beat)) % lights.size()]), 0.35 + 0.35 * pump))
		for j in 3:   # dancers behind the glass
			var hx := w.position.x + w.size.x * (0.22 + j * 0.28)
			var hop := absf(sin(t * PI / beat + i + j * 1.3)) * 8.0
			canvas.draw_circle(Vector2(hx, w.end.y - 34.0 - hop), 9.0, Color(0.03, 0.02, 0.08, 0.85))
			canvas.draw_rect(Rect2(hx - 10.0, w.end.y - 26.0 - hop, 20.0, 26.0 + hop - 4.0), Color(0.03, 0.02, 0.08, 0.85))
	# the door with the sign, the rope and the bouncer
	var door := Rect2(s.x * 0.8, g - s.y * 0.36, s.x * 0.1, s.y * 0.36)
	canvas.draw_rect(door.grow(8.0), Color("15161c"))
	canvas.draw_rect(door, Color(Color("ff5d8f"), 0.25 + 0.25 * pump))
	var sign := Rect2(door.get_center().x - s.x * 0.1, door.position.y - s.y * 0.11, s.x * 0.2, s.y * 0.075)
	canvas.draw_rect(sign, Color("15161c"))
	canvas.draw_rect(sign, Color(UI.PINK, 0.6 + 0.4 * sin(t * 6.0)), false, 4.0)
	_text(Vector2(sign.get_center().x, sign.get_center().y + 13.0), UI.T("ERSTI-FEST"), 34, UI.YELLOW, true, 6)
	canvas.draw_rect(Rect2(0, g, s.x, s.y - g), Color("1b1c28"))
	canvas.draw_rect(Rect2(s.x * 0.08, g, s.x * 0.84, 16.0), Color("8e2a3a"))   # red carpet
	var bx := s.x * 0.93
	ART.draw_character(canvas, BOUNCER, ART.LEFT, 0.0, false, Vector2(bx, g), k * 1.12)
	for px in [s.x * 0.775, s.x * 0.915]:
		canvas.draw_rect(Rect2(px - 5.0, g - 70.0, 10.0, 70.0), Color("c9a23c"))
		canvas.draw_circle(Vector2(px, g - 72.0), 9.0, Color("c9a23c"))
	if closing < 0.0:
		canvas.draw_line(Vector2(s.x * 0.775, g - 62.0), Vector2(s.x * 0.915, g - 62.0), Color("b7352d"), 7.0)
	# what the bouncer says
	var says := ""
	if closing >= 0.0:
		says = UI.T("N'Abend, der Herr. Viel Spass.")
	elif fall_t >= 0.0:
		says = UI.T("Haha! Zwei Erstis im Mantel. Netter Versuch.")
	elif x > 0.55:
		says = UI.T("Hmm. Grosser Typ.")
	if says != "":
		var w2 := ThemeDB.fallback_font.get_string_size(says, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var bub := Rect2(bx - w2 - 70.0, g - k * 60.0, w2 + 36.0, 46.0)
		canvas.draw_rect(bub.grow(4.0), UI.DARK)
		canvas.draw_rect(bub, UI.CREAM)
		_text(bub.position + Vector2(18.0, 31.0), says, 22, Color("1c1d33"), false, 0)
	# on top: what to do, the level, the way
	_text(Vector2(s.x / 2.0, s.y * 0.09), UI.T("Zu zweit in einem Mantel"), 44, UI.YELLOW, true, 10)
	_text(Vector2(s.x / 2.0, s.y * 0.135), UI.T("Ausverkauft. Aber ein grosser Gast kommt immer rein."), 20, UI.MUTED, true, 4)
	var tube := Rect2(s.x * 0.35, s.y * 0.17, s.x * 0.3, 24.0)
	canvas.draw_rect(tube.grow(3.0), UI.DARK)
	canvas.draw_rect(tube, Color("c9e8b5"))
	var safe := tube.size.x * 0.5 * 0.55
	canvas.draw_rect(Rect2(tube.get_center().x - safe, tube.position.y, safe * 2.0, tube.size.y), Color(UI.GREEN, 0.55))
	var bubx := tube.get_center().x + clampf(tilt / TIP, -1.0, 1.0) * (tube.size.x / 2.0 - 12.0)
	canvas.draw_circle(Vector2(bubx, tube.get_center().y), 11.0, UI.DARK)
	canvas.draw_circle(Vector2(bubx, tube.get_center().y), 9.0, UI.WHITE if absf(tilt) < TIP * 0.55 else UI.RED)
	var way := Rect2(s.x * 0.35, s.y * 0.215, s.x * 0.3, 8.0)
	canvas.draw_rect(way, UI.DARK)
	canvas.draw_rect(Rect2(way.position, Vector2(way.size.x * clampf(x, 0.0, 1.0), way.size.y)), UI.YELLOW)
	for pid in 2:
		var pc := Color(KEYS.TAG_COLORS[pid])
		var is_legs := pid == legs
		var cx := s.x * (0.21 if pid == 0 else 0.79)
		var role := UI.T("%s: die Beine") if is_legs else UI.T("%s: oben im Mantel")
		_text(Vector2(cx, s.y * 0.9), role % Game.name_of(pid), 24, pc, true)
		var how := ""
		if is_legs:
			how = UI.T("%s halten: gehen") % ("D" if pid == 0 else UI.T("Pfeil rechts"))
		else:
			how = UI.T("%s: gegen das Schwanken lehnen") % ("A / D" if pid == 0 else UI.T("Pfeil links / rechts"))
		_text(Vector2(cx, s.y * 0.945), how, 18, UI.WHITE, true, 4)
	_text(Vector2(s.x / 2.0, s.y * 0.975), "%s / %s · %s" % [KEYS.LABELS[0]["abort"], KEYS.LABELS[1]["abort"], UI.T("abbrechen")], 14, UI.MUTED, true, 0)
