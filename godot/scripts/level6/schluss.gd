extends CanvasLayer
## Level 6: the last picture. The two walk out of the library, everybody else goes on studying.
## A drawn scene over the whole screen: the reading room from the side, rows of desks with heads
## bent over books, the door on the right. The two players cross it with what they took, then
## the title. E / Enter / Space or a click goes on, Esc skips it; it ends by itself.
## Set `looks` (the two players) and `readers` (looks of people who study) before it enters the
## tree; `done` is emitted once when it is over.

signal done

const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")

# ---- tuning
const WALK_TIME := 4.6            # seconds the two need to cross the room
const TITLE_TIME := 4.2           # seconds the title stays, then it ends by itself
const FADE := 0.5

const W := 1280.0                 # size of the stage the picture is drawn for
const H := 720.0
const WALL := Color("efe6d2")
const FLOOR := Color("b98b5e")
const WOOD := Color("7a5032")
const INK := Color("23264a")
const BOOKS := ["8c2f39", "2f5d8c", "3e7d4f", "b5893a", "5d3f7a", "2b6e6e", "c4643a", "394150"]

var looks: Array = [{}, {}]
var readers: Array = []
var t := 0.0
var over := false
var stage: Control


func _ready() -> void:
	layer = 30
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.draw.connect(_on_draw)
	stage.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_advance())
	UI.sfx("whoosh", -10.0)


func _process(delta: float) -> void:
	t += delta
	if t >= WALK_TIME + TITLE_TIME:
		_end()
	stage.queue_redraw()


func _input(event: InputEvent) -> void:
	if over or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_end()
	elif k in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_advance()


## To the title, or on from the title.
func _advance() -> void:
	if t < WALK_TIME:
		t = WALK_TIME
	else:
		_end()


func _end() -> void:
	if over:
		return
	over = true
	done.emit()
	queue_free()


func _text(at: Vector2, text: String, size: int, col: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	var font := ThemeDB.fallback_font
	var s := tr(text)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(at.x - w / 2.0, at.y)
	if outline.a > 0.0:
		stage.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, outline)
	stage.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _on_draw() -> void:
	var vs := stage.size
	var k := maxf(vs.x / W, vs.y / H)   # fills the screen, cut at the edges if the shape differs
	var o := (vs - Vector2(W, H) * k) / 2.0
	stage.draw_set_transform(o, 0.0, Vector2(k, k))
	_room()
	# three rows of desks, the far one first
	var n := 0
	for row in 3:
		var y := 330.0 + row * 105.0
		var sc := 2.0 + row * 0.35
		var x0 := 70.0 + row * 46.0
		var seats := 6 - row
		var step := 150.0 + row * 14.0
		for i in seats:
			var x := x0 + i * step
			if readers.size() > 0:
				# draw_character sets its own transform (and clears it): give it screen coordinates, then set ours again
				ART.draw_character(stage, readers[n % readers.size()], ART.FRONT, 0.0, false, o + Vector2(x, y + 6.0) * k, sc * k)
				stage.draw_set_transform(o, 0.0, Vector2(k, k))
			n += 1
		# the desk in front of them, with a book for everybody
		stage.draw_rect(Rect2(x0 - 70.0, y - 6.0, step * (seats - 1) + 140.0, 34.0 + row * 6.0), WOOD)
		stage.draw_rect(Rect2(x0 - 70.0, y - 6.0, step * (seats - 1) + 140.0, 7.0), WOOD.lightened(0.18))
		for i in seats:
			var bx := x0 + i * step
			stage.draw_rect(Rect2(bx - 22.0, y - 14.0, 44.0, 12.0), Color("f3efe2"))
			stage.draw_line(Vector2(bx, y - 14.0), Vector2(bx, y - 2.0), Color("b9b2a0"), 1.5)
	# the two on their way out, along the front, towards the door
	var u := clampf(t / WALK_TIME, 0.0, 1.0)
	for pid in 2:
		var x := lerpf(380.0, 1330.0, u) - pid * 110.0
		var feet := Vector2(x, 690.0)
		if (looks[pid] as Dictionary).is_empty():
			continue
		ART.draw_character(stage, looks[pid], ART.RIGHT, t * 11.0, u < 1.0, o + feet * k, 4.4 * k)
		stage.draw_set_transform(o, 0.0, Vector2(k, k))
		if pid == 0:
			_tower(feet + Vector2(64.0, -96.0))
		else:
			_bottle(feet + Vector2(58.0, -118.0))
	# somebody looks up after all
	if t > 1.2 and t < 3.0:
		var bc := Vector2(70.0 + 46.0 * 2.0 + 178.0, 440.0)
		stage.draw_rect(Rect2(bc.x - 46.0, bc.y - 26.0, 92.0, 34.0), Color(0.08, 0.09, 0.17, 0.9))
		_text(bc + Vector2(0, 0), "Psst!", 24, Color.WHITE)
	# the title
	var a := clampf((t - WALK_TIME) / FADE, 0.0, 1.0)
	if a > 0.0:
		stage.draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.14, 0.55 * a))
		_text(Vector2(W / 2.0, 330.0), "LERNPHASE", 110, Color(1, 1, 1, a), Color(0.08, 0.09, 0.17, a))
		_text(Vector2(W / 2.0, 400.0), "Ihr geht raus  ·  alle anderen lernen weiter", 30, Color(UI.SKY, a), Color(0.08, 0.09, 0.17, a))
	stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Walls, shelves full of books, a window and the open door on the right.
func _room() -> void:
	stage.draw_rect(Rect2(-200, -200, W + 400, H + 400), WALL)
	stage.draw_rect(Rect2(-200, 590, W + 400, 400), FLOOR)
	stage.draw_rect(Rect2(-200, 590, W + 400, 8), FLOOR.darkened(0.25))
	# shelves along the back wall
	for s in 4:
		var sx := 30.0 + s * 250.0
		stage.draw_rect(Rect2(sx, 60.0, 210.0, 230.0), WOOD.darkened(0.2))
		for row in 4:
			var by := 72.0 + row * 54.0
			stage.draw_rect(Rect2(sx + 8.0, by, 194.0, 44.0), WOOD.darkened(0.45))
			for i in 14:
				var hgt := 30.0 + float((i * 7 + row * 5 + s * 3) % 5) * 3.0
				stage.draw_rect(Rect2(sx + 12.0 + i * 13.5, by + 44.0 - hgt, 11.0, hgt), Color(String(BOOKS[(i * 3 + row + s * 5) % BOOKS.size()])))
	# the door: open, the summer outside
	stage.draw_rect(Rect2(1090.0, 250.0, 150.0, 345.0), WOOD.darkened(0.3))
	stage.draw_rect(Rect2(1102.0, 262.0, 126.0, 333.0), Color("fff6cf"))
	stage.draw_colored_polygon(PackedVector2Array([Vector2(1102, 595), Vector2(1228, 595), Vector2(1330, 720), Vector2(930, 720)]), Color(1.0, 0.96, 0.7, 0.35))
	stage.draw_rect(Rect2(1112.0, 214.0, 106.0, 28.0), Color("2f9e5b"))
	_text(Vector2(1165.0, 235.0), "AUSGANG", 18, Color.WHITE)


## The socket tower under the arm.
func _tower(c: Vector2) -> void:
	stage.draw_rect(Rect2(c.x - 13.0, c.y - 74.0, 26.0, 74.0), Color("e9ece8"))
	stage.draw_rect(Rect2(c.x - 13.0, c.y - 74.0, 7.0, 74.0), Color("cfd3cd"))
	for i in 4:
		stage.draw_rect(Rect2(c.x - 5.0, c.y - 64.0 + i * 16.0, 13.0, 9.0), Color("3a3f46"))
	stage.draw_rect(Rect2(c.x - 18.0, c.y, 36.0, 9.0), Color("8f948d"))
	stage.draw_polyline(PackedVector2Array([c + Vector2(0, 9), c + Vector2(-14, 40), c + Vector2(6, 66)]), Color("23262e"), 4.0)


## A bottle of Mate in the hand.
func _bottle(c: Vector2) -> void:
	stage.draw_rect(Rect2(c.x - 4.0, c.y - 2.0, 8.0, 5.0), Color("d9b44a"))
	stage.draw_rect(Rect2(c.x - 4.0, c.y + 3.0, 8.0, 12.0), Color("6b3f1d"))
	stage.draw_rect(Rect2(c.x - 9.0, c.y + 15.0, 18.0, 34.0), Color("6b3f1d"))
	stage.draw_rect(Rect2(c.x - 9.0, c.y + 23.0, 18.0, 14.0), Color("f1c40f"))
