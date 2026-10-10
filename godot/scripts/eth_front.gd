extends RefCounted
## The ETH main building seen from the front (Polyterrasse side) in pixel art, drawn pixel by pixel.
## Used by the start page (menu.gd) and for the boot splash (tools/make_splash.gd writes splash.png).
## The scene is drawn in colour first and then toned towards the navy of the menu (ui.gd).

const W := 320
const H := 180

const SKY_TOP := Color("2f6fc4")
const SKY_LOW := Color("b5d6f2")
const CLOUD := Color("eef5fc")
const HILL := Color("2f5a3c")
const HILL_LIT := Color("3d7049")
const CITY := Color("c9cbd0")
const CITY_DARK := Color("9298a3")
const ROOF := Color("4f3a31")
const ROOF_LIT := Color("6a4e41")
const STONE := Color("dccdaa")
const STONE_LIT := Color("ebe0c4")
const STONE_DARK := Color("b5a382")
const SHADOW := Color("8c7b5e")
const WINDOW := Color("33343c")
const WINDOW_LIT := Color("5b6170")
const DOOR := Color("8b4a2b")
const DOME := Color("463630")
const DOME_LIT := Color("5c4840")
const COPPER := Color("5f9e86")
const PLAZA := Color("cfcdc8")
const PLAZA_DARK := Color("b4b2ad")
const ROAD := Color("57575a")
const HEDGE := Color("3f7a3a")
const PINE := Color("2b5530")
const PINE_LIT := Color("3e7343")
const TRUNK := Color("5a3d2a")

# Tone of the finished screen, matches UI.DARK / UI.NAVY / UI.MUTED.
const TONE_DARK := Color("30356a")
const TONE_LIGHT := Color("eef0fa")
const TEXT := Color("fff8e7")
const TEXT_DIM := Color("b9bde6")
const EDGE := Color("23264a")

## 5 x 7 pixel letters for the loading label.
const GLYPHS := {
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	".": ["00000", "00000", "00000", "00000", "00000", "00000", "00100"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}

var img: Image


## Returns the picture at 320 x 180. With `loading`, a "LADEN..." label and a bar sit at the bottom.
static func render(loading := false) -> Image:
	var e := new()
	e.img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	e._sky()
	e._hills()
	e._wings()
	e._rotunda()
	e._dome()
	e._plaza()
	e._trees()
	e._grade()
	if loading:
		e._overlay()
	return e.img


func _r(x: int, y: int, w: int, h: int, c: Color) -> void:
	if w <= 0 or h <= 0:
		return
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, W, H))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and x < W and y >= 0 and y < H:
		img.set_pixel(x, y, c)


## Filled ellipse, only the part with min_y <= y <= max_y.
func _ellipse(cx: float, cy: float, rx: float, ry: float, c: Color, max_y := 9999, min_y := -9999) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 1):
		if y > max_y:
			break
		if y < min_y:
			continue
		var dy := (y + 0.5 - cy) / ry
		if absf(dy) > 1.0:
			continue
		var half := rx * sqrt(1.0 - dy * dy)
		_r(int(round(cx - half)), y, int(round(half * 2.0)), 1, c)


func _sky() -> void:
	# Banded gradient, eight steps, like an old game.
	for y in 100:
		var k := floorf(y / 100.0 * 8.0) / 7.0
		_r(0, y, W, 1, SKY_TOP.lerp(SKY_LOW, k))
	# Long thin cirrus streaks.
	for s: Array in [[20, 14, 70], [150, 9, 90], [230, 22, 60], [60, 30, 40], [255, 6, 50]]:
		_r(s[0], s[1], s[2], 1, CLOUD)
		_r(s[0] + 8, s[1] + 1, s[2] - 20, 1, CLOUD.lerp(SKY_TOP, 0.35))


func _hills() -> void:
	# Zürichberg behind the building.
	for x in W:
		var top := 74 + int(6.0 * sin(x * 0.018 + 0.6) + 3.0 * sin(x * 0.061))
		_r(x, top, 1, 100 - top, HILL)
		if (x / 3) % 2 == 0:
			_px(x, top, HILL_LIT)
	# City between hill and roofs.
	var bx := 0
	var i := 0
	while bx < W:
		var bw := 4 + (i * 7) % 6
		var bh := 3 + (i * 5) % 7
		_r(bx, 92 - bh, bw, bh + 8, CITY if i % 3 else CITY_DARK)
		_r(bx, 92 - bh, bw, 1, ROOF_LIT if i % 2 else CITY_DARK)
		bx += bw + (i % 2)
		i += 1


func _window_column(x: int, y0: int) -> void:
	# Three floors: two square windows and one arched ground-floor window.
	_r(x, y0, 3, 5, WINDOW)
	_px(x, y0, WINDOW_LIT)
	_r(x, y0 + 10, 3, 6, WINDOW)
	_px(x, y0 + 10, WINDOW_LIT)
	_r(x, y0 + 21, 3, 7, WINDOW)
	_px(x, y0 + 20, WINDOW)
	_px(x + 1, y0 + 20, WINDOW)


func _wings() -> void:
	# Left and right wings, set back behind the rotunda, with steep roofs.
	for side in 2:
		var x0 := 0 if side == 0 else 196
		var w := 124
		_r(x0, 101, w, 46, STONE)
		_r(x0, 101, w, 2, STONE_LIT)
		_r(x0, 145, w, 2, STONE_DARK)
		# Floor bands.
		_r(x0, 112, w, 1, STONE_DARK)
		_r(x0, 123, w, 1, STONE_DARK)
		# Roof: trapezoid with dormers.
		for y in range(88, 101):
			_r(x0, y, w, 1, ROOF if y % 4 else ROOF_LIT)
		for dx in range(6, w - 6, 14):
			_r(x0 + dx, 93, 4, 4, STONE_LIT)
			_r(x0 + dx + 1, 94, 2, 3, WINDOW)
		for dx in range(4, w - 3, 8):
			_window_column(x0 + dx, 105)
		# Corner pavilions a little taller.
		var px0 := 0 if side == 0 else W - 22
		_r(px0, 84, 22, 63, STONE_DARK)
		_r(px0 + 1, 84, 20, 63, STONE)
		_r(px0, 80, 22, 5, ROOF)
		_r(px0 + 2, 78, 18, 2, ROOF_LIT)
		for dx: int in [5, 14]:
			_window_column(px0 + dx, 105)
	# Shadow where the wings meet the rotunda.
	_r(118, 101, 6, 46, SHADOW)
	_r(196, 101, 6, 46, SHADOW)


func _rotunda() -> void:
	var x0 := 120
	var w := 80
	# Body, lighter in the middle to suggest the curve.
	for x in w:
		var k := absf(x - w / 2.0) / (w / 2.0)
		var c := STONE_LIT.lerp(STONE_DARK, k * k)
		_r(x0 + x, 98, 1, 52, c)
	# Cornice and balustrade.
	_r(x0 - 2, 96, w + 4, 3, STONE_LIT)
	_r(x0 - 2, 99, w + 4, 1, SHADOW)
	_r(x0, 131, w, 2, STONE_LIT)
	for x in range(x0 + 1, x0 + w - 1, 3):
		_r(x, 133, 1, 3, SHADOW)
	_r(x0, 136, w, 1, STONE_LIT)
	# Columns with deep shadow between them.
	for i in 12:
		var cx := x0 + 4 + i * 6
		_r(cx + 2, 103, 4, 27, SHADOW)
		_r(cx + 3, 106, 2, 6, WINDOW)
		_r(cx + 3, 117, 2, 8, WINDOW)
		_r(cx, 102, 2, 29, STONE_LIT)
		_r(cx, 102, 2, 1, STONE)
	# Ground floor: three arched wooden doors, small windows between.
	for dx: int in [12, 36, 60]:
		_r(x0 + dx, 140, 8, 10, DOOR)
		_r(x0 + dx + 1, 139, 6, 1, DOOR)
		_r(x0 + dx + 2, 138, 4, 1, DOOR)
		_r(x0 + dx + 3, 141, 1, 9, DOOR.darkened(0.4))
	for dx: int in [26, 51]:
		_r(x0 + dx, 141, 3, 5, WINDOW)
	_r(x0, 148, w, 2, STONE_DARK)


func _dome() -> void:
	# Drum with arched windows.
	_r(130, 80, 60, 16, STONE)
	_r(130, 80, 60, 1, STONE_LIT)
	_r(130, 95, 60, 1, SHADOW)
	for x in range(133, 187, 6):
		_r(x, 85, 3, 7, WINDOW)
		_px(x + 1, 84, WINDOW)
	_r(130, 80, 3, 16, STONE_DARK)
	_r(187, 80, 3, 16, STONE_DARK)
	# Dome, light from the upper left.
	_ellipse(160, 80, 32, 30, DOME, 79)
	_ellipse(154, 72, 18, 18, DOME_LIT, 79)
	for i in 5:
		var x := 136 + i * 12
		_r(x, 66 + absi(2 - i) * 3, 1, 12 - absi(2 - i) * 3, DOME.darkened(0.35))
	# Lantern with copper cap.
	_r(153, 44, 14, 8, STONE)
	_r(153, 44, 14, 1, STONE_LIT)
	for x: int in [155, 159, 163]:
		_r(x, 46, 2, 5, WINDOW)
	_r(151, 51, 18, 2, STONE_LIT)
	_ellipse(160, 44, 9, 6, COPPER, 43)
	_r(157, 37, 6, 2, COPPER.lightened(0.2))
	_r(159, 32, 2, 5, COPPER)
	_px(159, 31, COPPER.lightened(0.3))


func _plaza() -> void:
	_r(0, 147, W, 33, ROAD)
	# Light sidewalk in front of the wings.
	_r(0, 147, W, 4, PLAZA_DARK)
	# Big half-oval forecourt in front of the rotunda.
	_ellipse(165, 150, 125, 26, PLAZA, 9999, 150)
	_r(40, 147, 250, 3, PLAZA)
	# Paving joints.
	for x in range(60, 290, 10):
		_px(x, 156, PLAZA_DARK)
		_px(x + 5, 162, PLAZA_DARK)
	# Hedge along the right edge of the plaza.
	_r(208, 146, 80, 3, HEDGE)
	_r(208, 146, 80, 1, HEDGE.lightened(0.2))
	# Bollards and tiny people.
	for x: int in [230, 246, 262]:
		_r(x, 168, 3, 3, Color.WHITE)
	_r(176, 155, 2, 4, Color("2b2d33"))
	_px(176, 154, Color("e0b896"))
	_r(260, 160, 2, 4, Color("2b2d33"))
	_px(260, 159, Color("e0b896"))
	_r(258, 163, 6, 1, Color("2b2d33"))
	# Street edge.
	_r(0, 176, W, 1, PLAZA_DARK)


func _pine(cx: int, base: int, height: int, wide: int) -> void:
	_r(cx - 1, base - height / 2, 3, height / 2, TRUNK)
	var layers := 5
	for i in layers:
		var y := base - height + i * height / (layers + 1)
		var rx := wide * (0.45 + 0.55 * float(i) / layers)
		_ellipse(cx + (i % 2) * 3 - 1, y + 6, rx, 7, PINE)
		_ellipse(cx + (i % 2) * 3 - 4, y + 4, rx * 0.5, 3, PINE_LIT)


func _trees() -> void:
	_pine(40, 168, 82, 22)
	_pine(88, 178, 62, 26)
	_pine(12, 150, 50, 14)
	# Small round tree on the right.
	_r(299, 135, 2, 15, TRUNK)
	_ellipse(300, 128, 9, 12, PINE_LIT)
	_ellipse(298, 124, 5, 6, HEDGE.lightened(0.15))


## Softens the colour picture towards the menu's navy, with slightly darker edges.
func _grade() -> void:
	var centre := Vector2(W / 2.0, H * 0.45)
	for y in H:
		for x in W:
			var c := img.get_pixel(x, y)
			var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			var t := TONE_DARK.lerp(TONE_LIGHT, lum).lerp(c, 0.35)
			var d := (Vector2(x, y) - centre) / Vector2(W * 0.7, H * 0.7)
			var v := clampf(d.length() - 0.5, 0.0, 1.0)
			img.set_pixel(x, y, t.lerp(EDGE, v * 0.8))


func _text(s: String, x: int, y: int, scale: int, c: Color) -> void:
	for ch in s:
		var g: Array = GLYPHS.get(ch, GLYPHS[" "])
		for gy in 7:
			for gx in 5:
				if g[gy][gx] == "1":
					_r(x + gx * scale, y + gy * scale, scale, scale, c)
		x += 6 * scale


## "LADEN..." and an empty bar on a dark strip at the bottom.
func _overlay() -> void:
	for y in range(150, H):
		var k := (y - 150) / 30.0
		for x in W:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(EDGE, 0.35 + k * 0.5))
	var label := "LADEN..."
	var lx := (W - (label.length() * 6 - 1)) / 2
	_text(label, lx + 1, 159, 1, EDGE)
	_text(label, lx, 158, 1, TEXT)
	var bw := 90
	var bx := (W - bw) / 2
	_r(bx, 169, bw, 4, TEXT_DIM)
	_r(bx + 1, 170, bw - 2, 2, EDGE)
	_r(bx + 1, 170, 14, 2, TEXT)
