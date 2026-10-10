extends Control
## A student ID card ("Legi") in the layout of the real ETH Legi: slanted ETH logo top left, a light
## blue band across the card with surname, first name and birthday, the photo top right in a white
## frame, below it the study programme and number, and the rewritable strip that shows the validity
## (S, date, ASVZ) once the card is validated.
## `set_player(i)` fills in everything from the Game autoload. The surname line only appears if
## the player entered one. Without a photo, the player's character is drawn instead.
## `validated` shows the validity on the strip, `validate()` prints it with a little pop.

const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")
const CARD := Vector2(420, 262)
const VALID := "07.03.2027"
const INK := Color("232323")
const BAND := Color("aab9ec")
const PAPER := Color("fcfcfa")
const STRIP := Color("f3f3ef")
const PRINT := Color("2b2427")    # the dark brown-black of the thermal print on the strip

var photo: Texture2D
var pname := ""
var surname := ""
var birthday := ""
var programme := ""
var number := ""
var look: Dictionary = {}
var accent := Color("4d8dff")
var validated := false
var stamp_t := 1.0
var t := 0.0


func _init() -> void:
	custom_minimum_size = CARD
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func validate() -> void:
	validated = true
	stamp_t = 0.0


func _process(delta: float) -> void:
	t += delta
	stamp_t = minf(1.0, stamp_t + delta * 3.0)
	queue_redraw()


## Everything the card shows about player `i`, from the Game autoload.
func set_player(i: int) -> void:
	photo = Game.photos[i]
	pname = Game.name_of(i)
	surname = String(Game.surnames[i]).strip_edges()
	birthday = String(Game.birthdays[i])
	programme = Game.programme_of(i)
	number = String(Game.legi_ids[i])
	look = Game.player_looks[i]


## Text in the largest size up to `fs` that fits into `w`.
func _fit(font: Font, s: String, pos: Vector2, w: float, fs: int, col: Color, bold: bool = false) -> void:
	while fs > 8 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	if bold:
		draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, col)
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw() -> void:
	var k := minf(size.x / CARD.x, size.y / CARD.y)
	var o := (size - CARD * k) / 2.0
	draw_set_transform(o, 0.0, Vector2(k, k))
	var font := ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, CARD)
	# card body with shadow; the lower part is the rewritable strip, barely greyer
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.35)
	shadow.set_corner_radius_all(14)
	draw_style_box(shadow, Rect2(Vector2(0, 8), CARD))
	var body := StyleBoxFlat.new()
	body.bg_color = PAPER
	body.set_corner_radius_all(14)
	draw_style_box(body, r)
	var strip := StyleBoxFlat.new()
	strip.bg_color = STRIP
	strip.corner_radius_bottom_left = 14
	strip.corner_radius_bottom_right = 14
	draw_style_box(strip, Rect2(0, 186, CARD.x, CARD.y - 186))
	# light blue band across the whole card
	draw_rect(Rect2(0, 92, CARD.x, 94), BAND)
	# logo, slanted: "ETH" heavy, "zürich" light
	draw_set_transform_matrix(Transform2D(Vector2(k, 0), Vector2(-0.2 * k, k), o + Vector2(31, 50) * k))
	draw_string_outline(font, Vector2.ZERO, "ETH", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, 7, INK)
	draw_string(font, Vector2.ZERO, "ETH", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, INK)
	var eth_w := font.get_string_size("ETH", HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	draw_string(font, Vector2(eth_w + 6, 0), "zürich", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, INK)
	draw_set_transform(o, 0.0, Vector2(k, k))
	# photo top right; its white frame reaches into the band and is deeper below the photo
	var frame := Rect2(287, 34, 111, 124)
	var pr := Rect2(296, 34, 91, 115)
	draw_rect(frame, Color.WHITE)
	if photo:
		var ts := photo.get_size()
		var want := pr.size.x / pr.size.y
		var src := Rect2(Vector2.ZERO, ts)
		if ts.x / ts.y > want:
			src.size.x = ts.y * want
			src.position.x = (ts.x - src.size.x) / 2.0
		else:
			src.size.y = ts.x / want
			src.position.y = (ts.y - src.size.y) / 2.0
		draw_texture_rect_region(photo, pr, src)
	else:
		draw_rect(pr, accent.lightened(0.55))
		# draw_character sets its own transform, so pass the final position and scale
		ART.draw_character(self, look, 0, 0.0, false, o + (pr.position + Vector2(pr.size.x / 2.0, pr.size.y + 26)) * k, 2.45 * k)
		draw_set_transform(o, 0.0, Vector2(k, k))
		# cover what hangs out of the photo: the frame again, the band below it
		draw_rect(Rect2(frame.position.x, pr.end.y, frame.size.x, frame.end.y - pr.end.y), Color.WHITE)
		draw_rect(Rect2(frame.position.x, pr.position.y, pr.position.x - frame.position.x, pr.size.y), Color.WHITE)
		draw_rect(Rect2(pr.end.x, pr.position.y, frame.end.x - pr.end.x, pr.size.y), Color.WHITE)
		draw_rect(Rect2(frame.position.x - 10, frame.end.y, frame.size.x + 20, 186 - frame.end.y), BAND)
	draw_string(font, Vector2(200, 178), "Gültig bis / valid through", HORIZONTAL_ALIGNMENT_RIGHT, 197, 11, INK)
	# surname (if there is one), first name and, after a gap, the birthday in the band
	if surname != "":
		_fit(font, surname, Vector2(34, 116), 230, 17, INK)
		_fit(font, pname, Vector2(34, 134), 230, 17, INK)
	else:
		_fit(font, pname, Vector2(34, 116), 230, 17, INK)
	draw_string(font, Vector2(34, 168), birthday, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	# programme and Legi number, printed onto the strip
	_fit(font, "Studies", Vector2(40, 204), 190, 14, PRINT, true)
	_fit(font, programme, Vector2(40, 230), 190, 14, PRINT, true)
	_fit(font, number, Vector2(40, 245), 190, 13, PRINT, true)
	# laminate shine
	var sx := fmod(t * 160.0, CARD.x + 300.0) - 150.0
	draw_colored_polygon(PackedVector2Array([Vector2(sx, 6), Vector2(sx + 40, 6), Vector2(sx - 30, CARD.y - 6), Vector2(sx - 70, CARD.y - 6)]), Color(1, 1, 1, 0.16))
	# validity printed onto the strip: big S, the date, the ASVZ box
	if validated:
		var e := stamp_t
		var a := clampf(e * 2.0, 0.0, 1.0)
		var col := Color(PRINT, a)
		var sc := 1.0 + (1.0 - ease(e, 0.4)) * 0.6
		var c := Vector2(322, 222)
		draw_set_transform(o + c * k, 0.0, Vector2(k * sc, k * sc))
		draw_string_outline(font, Vector2(-76, 23), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, 5, col)
		draw_string(font, Vector2(-76, 23), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, col)
		draw_string_outline(font, Vector2(-33, -10), VALID, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 2, col)
		draw_string(font, Vector2(-33, -10), VALID, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, col)
		draw_rect(Rect2(10, -6, 70, 24), col, false, 2.5)
		draw_string_outline(font, Vector2(10, 13), "ASVZ", HORIZONTAL_ALIGNMENT_CENTER, 70, 17, 2, col)
		draw_string(font, Vector2(10, 13), "ASVZ", HORIZONTAL_ALIGNMENT_CENTER, 70, 17, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
