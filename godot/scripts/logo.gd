extends Control
## The game's logo, drawn in code: "Bib Bob" in heavy ETH blue letters with a 3D edge, bobbing a
## little.
## Sizes itself to its rect (the letters fill the height). Used on the start page (menu.gd).
##
##   var logo := Logo.new()
##   logo.custom_minimum_size = Vector2(640, 170)

const UI = preload("res://scripts/ui.gd")

var col := UI.ETH_BLUE               # the letters
var edge := Color("15306b")          # the 3D edge below them
var bob := true                      # letters bob up and down a little
var t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var fs := int(size.y * 0.86)
	var depth := fs * 0.06
	var bold := maxi(2, int(fs * 0.07))
	var parts := ["B", "i", "b", " ", "B", "o", "b"]
	var widths: Array = []
	var total := 0.0
	for ch in parts:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + bold * 0.6
		if ch == " ":
			w = fs * 0.28
		widths.append(w)
		total += w
	var x := (size.x - total) / 2.0
	var base := size.y * 0.5 + font.get_ascent(fs) * 0.36
	for i in parts.size():
		var ch: String = parts[i]
		var w: float = widths[i]
		var dy := sin(t * 2.4 + i * 0.7) * fs * 0.025 if bob else 0.0
		if ch != " ":
			var p := Vector2(x + bold * 0.3, base + dy)
			for k in 3:   # the edge: a few layers below, so it looks solid
				var e := Vector2(0, depth * (k + 1) / 3.0)
				draw_string_outline(font, p + e, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, bold, edge)
				draw_string(font, p + e, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, edge)
			draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, bold, col)
			draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += w

