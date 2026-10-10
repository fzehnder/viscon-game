extends Control
## The loading screen before a level: the Polybahn rides up from Central to the Polyterrasse and
## is the loading bar. With it the number and the name of the level, how much time there will
## be, a drawn motif of the level and a tip.
##
## Used in two ways: the menu adds it as a child and waits for `finished`; between two levels it
## is the scene loading.tscn by itself (`standalone`) and goes on into the level.
##
## A level can add to it in its DEF (both optional):
##   "tips": ["...", "..."]     shown instead of the general tips
##   "sky": "abend"             dusk instead of day ("mode" decides between day and night otherwise)

signal finished

const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")
const LV = preload("res://scripts/levels.gd")
const ART = preload("res://scripts/character_art.gd")

const W := 1280.0                 # laid out for this size, scaled to the screen
const H := 720.0
const RIDE := 2.6                 # seconds the ride up takes
const FROM := Vector2(176.0, 603.0)    # the track: lower end at Central ...
const TO := Vector2(1004.0, 356.0)     # ... upper end at the Polyterrasse
const RED := Color("d5202a")
const SKIES := {                  # top, bottom, hill, hill in the light, houses in the distance, stone
	"day": ["6fb6ee", "fde9c9", "3f7d49", "56995a", "c3cfe0", "e2d6b8"],
	"abend": ["2a2356", "f2a65a", "25374a", "33495c", "5a4f7c", "b9a98c"],
	"night": ["0b1030", "27356a", "15222e", "1e3040", "1a2348", "6f7c94"],
}
const TIPS := [
	"Schleichen macht fast keinen Lärm. Sprinten hört man weit.",
	"Die Aufgabentaste zeigt den Weg zur nächsten Aufgabe.",
	"Wer euch erwischt, merkt sich das: Opps trefft ihr in späteren Levels wieder.",
	"Die Note sinkt mit jedem Fehler und mit der Zeit. 6 ist die Bestnote, ab 4 ist bestanden.",
	"Mit L öffnet ihr jederzeit den Leistungsüberblick.",
	"Im Lichtkegel füllt sich der Balken über dem Kopf. Raus aus der Sicht, dann sinkt er wieder.",
]

@export var standalone := false
var lv: Dictionary = {}
var n := 1
var sky := "day"
var tip := ""
var t := 0.0
var done := false
var clack := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if standalone:
		Game._apply_level()
	lv = LV.level()
	n = LV.current
	sky = String(lv.get("sky", "night" if String(lv.get("mode", "day")) == "night" else "day"))
	if not SKIES.has(sky):
		sky = "day"
	var tips: Array = lv.get("tips", TIPS)
	if tips.is_empty():
		tips = TIPS
	tip = String(tips[randi() % tips.size()])
	UI.sfx("whoosh", -8.0)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if done:
		return
	clack -= delta
	if clack <= 0.0 and t < RIDE:
		clack = 0.19
		UI.sfx("tick", -26.0)          # the wheels on the rail joints
	if t >= RIDE + 0.3:
		done = true
		UI.sfx("pop", -8.0)
		finished.emit()
		if standalone:
			get_tree().change_scene_to_file("res://main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and t > 0.4 and t < RIDE - 0.3:
		if event.physical_keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			t = RIDE - 0.3             # the rest of the way in a moment
			get_viewport().set_input_as_handled()


## How far up the car is, 0..1: it starts and stops gently.
func progress() -> float:
	return smoothstep(0.0, 1.0, clampf(t / RIDE, 0.0, 1.0))


# ------------------------------------------------------------------ drawing
func _c(i: int) -> Color:
	return Color(String(SKIES[sky][i]))


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, out_col := Color("15162b")) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= w
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, out_col)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _hash(i: int) -> float:
	return fposmod(sin(i * 127.1 + 31.7) * 43758.5453, 1.0)


func _draw() -> void:
	var k := minf(size.x / W, size.y / H)
	var o := (size - Vector2(W, H) * k) / 2.0
	var lit := sky != "day"                      # lamps and windows are on
	# sky over the whole screen: the top colour reaches far down, the bottom colour glows at the horizon
	var half := size.y * 0.52
	var between := _c(0).lerp(_c(1), 0.3)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, half), Vector2(0, half)]),
		PackedColorArray([_c(0), _c(0), between, between]))
	draw_polygon(PackedVector2Array([Vector2(0, half), Vector2(size.x, half), size, Vector2(0, size.y)]),
		PackedColorArray([between, between, _c(1), _c(1)]))
	draw_set_transform(o, 0.0, Vector2(k, k))
	if sky == "day":
		for i in 5:
			var cx := fposmod(_hash(i) * 1700.0 + t * (6.0 + i * 2.0), 1900.0) - 300.0
			var cy := 250.0 + _hash(i + 7) * 150.0
			for j in 4:
				draw_circle(Vector2(cx + j * 34.0, cy + (j % 2) * 9.0), 30.0 - j * 3.0, Color(1, 1, 1, 0.7))
	else:
		for i in 46:
			var tw := 0.5 + 0.5 * sin(t * (1.0 + _hash(i) * 2.0) + i)
			draw_circle(Vector2(_hash(i + 3) * 1700.0 - 200.0, _hash(i + 11) * 420.0), 1.2 + _hash(i + 5) * 1.3, Color(1, 1, 1, (0.25 if sky == "abend" else 0.5) + 0.4 * tw))
		if sky == "night":
			draw_circle(Vector2(660.0, 96.0), 34.0, Color("f4f1d8"))
			draw_circle(Vector2(674.0, 88.0), 30.0, _c(0))
	# the town below: roofs, and the two towers of the Grossmünster
	var town := _c(4)
	for i in 16:
		var hx := -260.0 + i * 62.0
		var hh := 46.0 + _hash(i + 40) * 58.0
		draw_rect(Rect2(hx, 606.0 - hh, 56.0, hh + 140.0), town)
		draw_colored_polygon(PackedVector2Array([Vector2(hx - 3.0, 606.0 - hh), Vector2(hx + 28.0, 606.0 - hh - 20.0), Vector2(hx + 59.0, 606.0 - hh)]), town.darkened(0.08))
		if lit:
			for wy in 2:
				for wx in 3:
					if _hash(i * 7 + wx + wy * 3) > 0.45:
						draw_rect(Rect2(hx + 8.0 + wx * 15.0, 618.0 - hh + wy * 18.0, 7.0, 9.0), Color("ffd98a"))
	for tx in [372.0, 412.0]:
		draw_rect(Rect2(tx, 446.0, 26.0, 200.0), town.darkened(0.05))
		draw_circle(Vector2(tx + 13.0, 446.0), 13.0, town.darkened(0.12))
		draw_rect(Rect2(tx + 11.0, 420.0, 4.0, 18.0), town.darkened(0.12))
	# the hill, the terrace and the main building on top
	var hill := PackedVector2Array([Vector2(-600, 640), Vector2(120, 632), Vector2(TO.x + 10.0, 372), Vector2(2200, 372), Vector2(2200, 1200), Vector2(-600, 1200)])
	draw_colored_polygon(hill, _c(2))
	draw_colored_polygon(PackedVector2Array([Vector2(120, 632), Vector2(TO.x + 10.0, 372), Vector2(TO.x + 10.0, 392), Vector2(190, 650)]), _c(3))
	for i in 9:
		var px := 250.0 + i * 92.0 + _hash(i + 60) * 30.0
		var py := FROM.y + (TO.y - FROM.y) * (px - FROM.x) / (TO.x - FROM.x) + 66.0 + _hash(i + 70) * 60.0
		var ph := 34.0 + _hash(i + 80) * 22.0
		draw_rect(Rect2(px - 2.5, py - 6.0, 5.0, 12.0), Color("4a3524"))
		draw_colored_polygon(PackedVector2Array([Vector2(px - ph * 0.36, py - 4.0), Vector2(px, py - ph), Vector2(px + ph * 0.36, py - 4.0)]), _c(2).darkened(0.25))
	var stone := _c(5)
	draw_rect(Rect2(TO.x + 6.0, 366.0, 1400.0, 30.0), stone.darkened(0.18))                 # terrace wall
	var bx := TO.x + 62.0                                                                    # the Hauptgebäude
	draw_rect(Rect2(bx, 262.0, 1300.0, 106.0), stone)
	draw_rect(Rect2(bx, 262.0, 1300.0, 12.0), stone.darkened(0.14))
	for i in 9:
		var wx2 := bx + 18.0 + i * 27.0
		draw_rect(Rect2(wx2, 286.0, 12.0, 34.0), Color("ffd98a") if lit else Color("3a4152"))
		draw_circle(Vector2(wx2 + 6.0, 286.0), 6.0, Color("ffd98a") if lit else Color("3a4152"))
		draw_rect(Rect2(wx2, 332.0, 12.0, 26.0), Color("ffd98a") if lit and i % 3 != 1 else Color("3a4152"))
	var dc := Vector2(bx + 128.0, 232.0)
	draw_rect(Rect2(dc.x - 52.0, 232.0, 104.0, 32.0), stone.darkened(0.06))                 # drum
	for i in 6:
		draw_rect(Rect2(dc.x - 46.0 + i * 16.5, 238.0, 6.0, 22.0), stone.darkened(0.3))
	var dome := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		dome.append(dc + Vector2(cos(a) * 56.0, sin(a) * 60.0))
	draw_colored_polygon(dome, Color("5f9e86") if sky == "day" else Color("3f6f66"))
	draw_rect(Rect2(dc.x - 6.0, dc.y - 76.0, 12.0, 18.0), stone.darkened(0.1))              # lantern
	draw_line(Vector2(dc.x, dc.y - 76.0), Vector2(dc.x, dc.y - 98.0), stone.darkened(0.3), 2.0)
	# Central: the little station house at the bottom
	draw_rect(Rect2(40.0, 566.0, 132.0, 74.0), stone.darkened(0.05))
	draw_colored_polygon(PackedVector2Array([Vector2(30.0, 566.0), Vector2(106.0, 536.0), Vector2(182.0, 566.0)]), RED.darkened(0.25))
	draw_rect(Rect2(86.0, 596.0, 40.0, 44.0), Color("ffd98a") if lit else Color("3a4152"))
	draw_rect(Rect2(56.0, 574.0, 100.0, 18.0), Color("15162b"))
	_text(Vector2(106.0, 588.0), "CENTRAL", 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(Rect2(TO.x + 20.0, 318.0, 150.0, 20.0), Color("15162b"))
	_text(Vector2(TO.x + 95.0, 333.0), "POLYTERRASSE", 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(Rect2(TO.x + 26.0, 338.0, 4.0, 30.0), Color("15162b"))
	draw_rect(Rect2(TO.x + 160.0, 338.0, 4.0, 30.0), Color("15162b"))
	# the track: bed, sleepers, two rails, and lamps that go on behind the car
	var p := progress()
	var dirv := (TO - FROM).normalized()
	var nrm := Vector2(-dirv.y, dirv.x)
	var length := FROM.distance_to(TO)
	draw_line(FROM - dirv * 12.0, TO + dirv * 12.0, Color("2a2c38"), 15.0, true)
	var d := 6.0
	while d < length:
		var sp := FROM + dirv * d
		draw_line(sp - nrm * 8.0, sp + nrm * 8.0, Color("6b5440"), 3.0)
		d += 17.0
	draw_line(FROM - dirv * 12.0 - nrm * 4.5, TO + dirv * 12.0 - nrm * 4.5, Color("c9ced8"), 2.0, true)
	draw_line(FROM - dirv * 12.0 + nrm * 4.5, TO + dirv * 12.0 + nrm * 4.5, Color("c9ced8"), 2.0, true)
	var lamps := 12
	for i in lamps:
		var u2 := (i + 0.5) / lamps
		var lp := FROM + dirv * length * u2 + nrm * 22.0
		var on := u2 <= p + 0.02
		draw_line(lp, lp - Vector2(0, 26.0), Color("15162b"), 3.0)
		if on:
			draw_circle(lp - Vector2(0, 28.0), 13.0, Color(UI.YELLOW, 0.22))
		draw_circle(lp - Vector2(0, 28.0), 5.0, UI.YELLOW if on else Color("596070"))
	# the car, tilted like the track, with the two at the windows
	var car := FROM + dirv * length * p - nrm * (22.0 + sin(t * 31.0) * 0.5)
	draw_set_transform(o + car * k, dirv.angle(), Vector2(k, k) * 1.3)
	draw_rect(Rect2(-66.0, -27.0, 132.0, 46.0), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(-64.0, -30.0, 128.0, 44.0), RED)
	draw_rect(Rect2(-64.0, -30.0, 128.0, 7.0), Color("f4f1ea"))
	draw_rect(Rect2(-64.0, 4.0, 128.0, 10.0), RED.darkened(0.28))
	for i in 4:
		var wr := Rect2(-56.0 + i * 29.0, -19.0, 23.0, 19.0)
		draw_rect(wr, Color("ffe7a8") if lit else Color("cfeaf7"))
		if i == 1 or i == 2:
			var look: Dictionary = Game.player_looks[i - 1]
			var hc := wr.position + Vector2(11.5, 12.0)
			draw_rect(Rect2(hc.x - 8.0, hc.y + 4.0, 16.0, 4.0), Color(String(KEYS.TAG_COLORS[i - 1])))
			draw_circle(hc, 6.2, ART.col(look, "skin", "f1c9a5"))
			draw_rect(Rect2(hc.x - 6.4, hc.y - 7.0, 12.8, 5.0), ART.col(look, "hair", "3b2a1e"))
		draw_rect(wr, Color("15162b"), false, 1.5)
	_text(Vector2(0.0, 13.0), "POLYBAHN", 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	draw_circle(Vector2(-40.0, 16.0), 6.0, Color("15162b"))
	draw_circle(Vector2(40.0, 16.0), 6.0, Color("15162b"))
	if lit:
		draw_circle(Vector2(66.0, -6.0), 15.0, Color(1.0, 0.95, 0.7, 0.25))
	draw_circle(Vector2(64.0, -6.0), 3.5, Color("fff3c0"))
	draw_set_transform(o, 0.0, Vector2(k, k))
	# which level: number, name, time
	var tag := String(lv.get("tag", "LEVEL %d" % n))
	var tagw := ThemeDB.fallback_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_rect(Rect2(66.0, 50.0, tagw + 28.0, 34.0), UI.PINK)
	_text(Vector2(80.0, 74.0), tag, 20, Color.WHITE)
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - t / 0.35)
	_text(Vector2(64.0, 168.0), String(lv.get("name", "")), int(82.0 * pop), UI.YELLOW, HORIZONTAL_ALIGNMENT_LEFT, 16)
	var secs := int(float(lv.get("time", 0.0)))
	if secs > 0 and String(lv.get("mode", "day")) != "night":
		_text(Vector2(68.0, 208.0), "%s %d:%02d" % [String(lv.get("timer_title", "ZEIT")), secs / 60, secs % 60], 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 6)
	# the motif of the level in a round frame
	var mc := Vector2(900.0, 152.0)
	draw_circle(mc, 92.0, Color(UI.NAVY, 0.92))
	draw_arc(mc, 92.0, 0.0, TAU, 64, UI.YELLOW, 5.0, true)
	_motif(mc + Vector2(0, sin(t * 2.2) * 4.0))
	# tip and how far it is
	var tipw := ThemeDB.fallback_font.get_string_size("Tipp: " + tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_rect(Rect2(40.0, 664.0, tipw + 36.0, 38.0), Color(UI.NAVY, 0.9))
	_text(Vector2(58.0, 690.0), "Tipp:", 18, UI.YELLOW)
	_text(Vector2(58.0 + ThemeDB.fallback_font.get_string_size("Tipp: ", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, 690.0), tip, 18, Color.WHITE)
	_text(Vector2(W - 40.0, 690.0), "%d %%" % int(p * 100.0), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## What the level is about, drawn around `c` (fits into a circle of about 70 px).
func _motif(c: Vector2) -> void:
	var ink := Color("15162b")
	match n:
		1:   # the green bag of the Ersti-Tag
			var bag := Color("2f9e5b")
			draw_colored_polygon(PackedVector2Array([c + Vector2(-34, -40), c + Vector2(34, -40), c + Vector2(42, 44), c + Vector2(-42, 44)]), bag)
			draw_rect(Rect2(c.x - 34.0, c.y - 40.0, 68.0, 10.0), bag.darkened(0.25))
			draw_line(c + Vector2(-30, -35), c + Vector2(-48, 30), Color("f3efe2"), 3.0, true)
			draw_line(c + Vector2(30, -35), c + Vector2(48, 30), Color("f3efe2"), 3.0, true)
			draw_rect(Rect2(c.x - 20.0, c.y - 14.0, 40.0, 30.0), Color("f3efe2"))
			_text(c + Vector2(0, 7), "ETH", 16, bag.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER)
		2:   # a tray from the Mensa
			draw_set_transform_matrix(get_transform_for(c, 0.0, Vector2(1.0, 0.55)))
			draw_circle(Vector2.ZERO, 64.0, Color("c98a4b"))
			draw_circle(Vector2.ZERO, 56.0, Color("d9a05f"))
			draw_circle(Vector2(-14, 0), 34.0, Color("f3efe2"))
			draw_circle(Vector2(-14, -2), 21.0, Color("a5612a"))
			draw_circle(Vector2(-22, 6), 8.0, Color("5a9b4a"))
			draw_set_transform_matrix(get_transform_for(Vector2.ZERO, 0.0, Vector2.ONE))
			draw_rect(Rect2(c.x + 26.0, c.y - 34.0, 20.0, 34.0), Color(0.75, 0.9, 1.0, 0.85))
			draw_rect(Rect2(c.x + 26.0, c.y - 34.0, 20.0, 34.0), ink, false, 2.0)
			for i in 3:
				var sx := c.x - 30.0 + i * 16.0
				draw_line(Vector2(sx, c.y - 22.0 - fposmod(t * 22.0 + i * 9.0, 26.0)), Vector2(sx + 4.0, c.y - 32.0 - fposmod(t * 22.0 + i * 9.0, 26.0)), Color(1, 1, 1, 0.6), 2.0)
		3:   # the mirror ball of the Polyball
			draw_line(c + Vector2(0, -92), c + Vector2(0, -46), ink, 3.0)
			draw_circle(c, 48.0, Color("8d93b8"))
			for row in 7:
				var ry := -48.0 + (row + 0.5) * 96.0 / 7.0
				var half := sqrt(maxf(0.0, 48.0 * 48.0 - ry * ry))
				for ci in 8:
					var u := fposmod(ci / 8.0 + t * 0.12 + row * 0.07, 1.0)
					var s := 6.0 * (0.5 + 0.5 * sin(u * PI))
					var shine := 0.35 + 0.65 * maxf(0.0, sin(t * 3.0 + row * 2.1 + ci * 1.7))
					draw_rect(Rect2(c + Vector2(-half + u * half * 2.0 - s / 2.0, ry - 4.0), Vector2(s, 8.0)), Color(1, 1, 1, 0.25 + 0.6 * shine))
			draw_arc(c, 48.0, 0.0, TAU, 40, ink, 2.0, true)
			for i in 4:
				var tw := maxf(0.0, sin(t * 3.0 + i * 1.6))
				if tw > 0.1:
					draw_colored_polygon(UI.star_points(c + Vector2.from_angle(i * 1.7 + 0.5) * 66.0, 11.0 * tw, 3.4 * tw, t), Color(1, 1, 1, 0.95))
		4:   # an Erlenmeyer flask that bubbles
			var glass := PackedVector2Array([c + Vector2(-12, -52), c + Vector2(12, -52), c + Vector2(12, -18), c + Vector2(46, 44), c + Vector2(-46, 44), c + Vector2(-12, -18)])
			draw_colored_polygon(glass, Color(0.85, 0.95, 1.0, 0.35))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-27, 10), c + Vector2(27, 10), c + Vector2(46, 44), c + Vector2(-46, 44)]), UI.GREEN)
			for i in 5:
				var by := fposmod(t * (26.0 + i * 7.0) + i * 17.0, 60.0)
				draw_circle(c + Vector2(-18.0 + i * 9.0 + sin(t * 3.0 + i) * 2.0, 34.0 - by), 3.0 + (i % 2) * 1.5, Color(1, 1, 1, 0.75 * (1.0 - by / 60.0)))
			draw_polyline(glass + PackedVector2Array([glass[0]]), Color("e9f4ff"), 3.0, true)
			draw_rect(Rect2(c.x - 15.0, c.y - 57.0, 30.0, 7.0), Color("e9f4ff"))
		20:  # skis in the snow
			for sgn in [-1.0, 1.0]:
				draw_set_transform_matrix(get_transform_for(c, sgn * 0.5, Vector2.ONE))
				draw_rect(Rect2(-7.0, -58.0, 14.0, 112.0), UI.PINK if sgn < 0.0 else UI.BLUE)
				draw_circle(Vector2(0, -58.0), 7.0, UI.PINK if sgn < 0.0 else UI.BLUE)
				draw_rect(Rect2(-7.0, -8.0, 14.0, 14.0), ink)
			draw_set_transform_matrix(get_transform_for(Vector2.ZERO, 0.0, Vector2.ONE))
			for i in 7:
				var fy := fposmod(t * (30.0 + i * 5.0) + i * 31.0, 150.0) - 75.0
				draw_circle(c + Vector2(-60.0 + i * 20.0 + sin(t + i) * 6.0, fy), 2.5 + (i % 3), Color(1, 1, 1, 0.9))
		_:   # the dome
			var dome := PackedVector2Array()
			for i in 21:
				var a := PI + PI * i / 20.0
				dome.append(c + Vector2(cos(a) * 50.0, 10.0 + sin(a) * 54.0))
			draw_colored_polygon(dome, Color("5f9e86"))
			draw_rect(Rect2(c.x - 54.0, c.y + 10.0, 108.0, 26.0), Color("e2d6b8"))
			draw_rect(Rect2(c.x - 5.0, c.y - 60.0, 10.0, 16.0), Color("e2d6b8"))


## The canvas transform of the layout (offset and scale) with one more step on top of it.
func get_transform_for(at: Vector2, rot: float, sc: Vector2) -> Transform2D:
	var k := minf(size.x / W, size.y / H)
	var o := (size - Vector2(W, H) * k) / 2.0
	return Transform2D(0.0, Vector2(k, k), 0.0, o) * Transform2D(rot, sc, 0.0, at)
