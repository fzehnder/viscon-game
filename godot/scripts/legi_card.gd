extends Control
## A student ID card ("Legi") with the player's photo, name and a made-up number.
## Without a photo, the player's character is drawn instead. `validated` shows a stamp.

const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")
const CARD := Vector2(420, 262)

var photo: Texture2D
var pname := ""
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


func _draw() -> void:
	var k := minf(size.x / CARD.x, size.y / CARD.y)
	var o := (size - CARD * k) / 2.0
	draw_set_transform(o, 0.0, Vector2(k, k))
	var font := ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, CARD)
	# card body with shadow
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.35)
	shadow.set_corner_radius_all(20)
	draw_style_box(shadow, Rect2(Vector2(0, 8), CARD))
	var body := StyleBoxFlat.new()
	body.bg_color = Color("f7f9fc")
	body.border_color = Color("1c1d33")
	body.set_border_width_all(4)
	body.set_corner_radius_all(20)
	draw_style_box(body, r)
	# header band
	var band := StyleBoxFlat.new()
	band.bg_color = UI.ETH_BLUE
	band.corner_radius_top_left = 18
	band.corner_radius_top_right = 18
	draw_style_box(band, Rect2(4, 4, CARD.x - 8, 50))
	draw_string(font, Vector2(22, 38), "ETH Zürich", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(font, Vector2(CARD.x - 22 - 70, 37), "LEGI", HORIZONTAL_ALIGNMENT_RIGHT, 70, 22, Color(1, 1, 1, 0.85))
	# shine sweep
	var sx := fmod(t * 160.0, CARD.x + 300.0) - 150.0
	draw_colored_polygon(PackedVector2Array([Vector2(sx, 54), Vector2(sx + 40, 54), Vector2(sx - 30, CARD.y - 6), Vector2(sx - 70, CARD.y - 6)]), Color(1, 1, 1, 0.18))
	# photo
	var pr := Rect2(22, 70, 120, 160)
	draw_rect(pr.grow(3), Color("1c1d33"))
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
		ART.draw_character(self, look, 0, 0.0, false, o + (pr.position + Vector2(pr.size.x / 2.0, pr.size.y + 34)) * k, 3.4 * k)
		draw_set_transform(o, 0.0, Vector2(k, k))
		draw_rect(Rect2(pr.position + Vector2(0, pr.size.y), Vector2(pr.size.x, 60)), Color("f7f9fc"))
		draw_rect(pr.grow(3), Color("1c1d33"), false, 3.0)
	# text
	var x := 162.0
	draw_string(font, Vector2(x, 88), "Name", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("6b7385"))
	draw_string(font, Vector2(x, 116), pname, HORIZONTAL_ALIGNMENT_LEFT, CARD.x - x - 18, 26, Color("1c1d33"))
	draw_string(font, Vector2(x, 148), "Studierendennummer", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("6b7385"))
	draw_string(font, Vector2(x, 172), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("1c1d33"))
	draw_string(font, Vector2(x, 204), "Gültig", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("6b7385"))
	draw_string(font, Vector2(x, 226), "HS 2026" if validated else "--", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("1c1d33"))
	# chip
	draw_rect(Rect2(CARD.x - 74, 196, 46, 34), Color("e0b84d"))
	draw_rect(Rect2(CARD.x - 74, 196, 46, 34), Color("a8812b"), false, 2.0)
	draw_line(Vector2(CARD.x - 51, 196), Vector2(CARD.x - 51, 230), Color("a8812b"), 2.0)
	draw_line(Vector2(CARD.x - 74, 213), Vector2(CARD.x - 28, 213), Color("a8812b"), 2.0)
	# validated stamp
	if validated:
		var e := stamp_t
		var sc := 1.0 + (1.0 - ease(e, 0.4)) * 1.8
		var c := Vector2(CARD.x - 120, 130)
		draw_set_transform(o + c * k, -0.22, Vector2(k * sc, k * sc))
		var a := clampf(e * 2.0, 0.0, 1.0)
		var green := Color(0.16, 0.7, 0.4, 0.92 * a)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = green
		sb.set_border_width_all(5)
		sb.set_corner_radius_all(10)
		draw_style_box(sb, Rect2(-96, -30, 192, 60))
		draw_string(font, Vector2(-96, 12), "VALIDIERT", HORIZONTAL_ALIGNMENT_CENTER, 192, 30, green)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
