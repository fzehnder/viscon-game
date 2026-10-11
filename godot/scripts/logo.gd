extends Control
## The game's logo, drawn in code: "Bib Bob" in the ETH house font, black, the letters bobbing a
## little. The ETH font is DIN Next (licensed, so it is not in the repo): the logo takes it if it is
## installed, otherwise the closest DIN on the computer (DIN Alternate on a Mac, Bahnschrift on
## Windows) and Arial last, the replacement ETH itself names.
## Sizes itself to its rect (the letters fill the height). Used on the start page (menu.gd) and in
## the pause menu (pause_menu.gd, there in white on the dark glass).
##
##   var logo := Logo.new()
##   logo.custom_minimum_size = Vector2(640, 150)

const FONTS := ["DIN Next LT Pro", "DIN Next", "DIN Alternate", "Bahnschrift", "D-DIN", "Arial"]

var col := Color.BLACK               # the letters
var bob := true                      # letters bob up and down a little
var t := 0.0
var _font: SystemFont = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(FONTS)
		_font.font_weight = 700
	var fs := int(size.y * 0.9)
	var text := "Bib Bob"
	var total := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := (size.x - total) / 2.0
	var base := size.y * 0.5 + _font.get_ascent(fs) * 0.36
	for i in text.length():
		var ch := text[i]
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if ch != " ":
			var dy := sin(t * 2.4 + i * 0.7) * fs * 0.02 if bob else 0.0
			draw_string(_font, Vector2(x, base + dy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += w
