extends CanvasLayer
## Level 3: the wristband template, shown on the half of the screen of whoever is looking at it.
## The other player rebuilds it in the kitchen with the sequence minigame and cannot see this.
## Same four directions, in the same order, as the pads of that minigame (minigame.gd).

const UI = preload("res://scripts/ui.gd")
const DIRS := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]   # up, down, left, right
const COLS := ["ff5d8f", "4d8dff", "ffc93c", "3ddc97"]
const SEG := 62.0

var side := -1             # 0 left half, 1 right half, -1 whole screen
var pattern: Array = []
var accent := Color("ffc93c")
var hint := ""
var root: Control
var band: Control


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := UI.panel(UI.NAVY, accent, 24, 18.0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UI.label("Armband-Vorlage", 30, accent, 7))
	band = Control.new()
	band.custom_minimum_size = Vector2(SEG * pattern.size() + 60.0, 118.0)
	band.draw.connect(_draw_band)
	v.add_child(band)
	var info := UI.label(hint, 15, UI.MUTED, 0, true)
	info.custom_minimum_size = Vector2(band.custom_minimum_size.x, 0)
	v.add_child(info)
	_place()
	UI.pop_in(p, 0.0, 0.6)
	UI.sfx("whoosh", -10.0)


func _process(_delta: float) -> void:
	_place()


## Fits into the left or right half of the screen, like a minigame (minigame.gd, _place_half).
func _place() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if side < 0:
		scale = Vector2.ONE
		offset = Vector2.ZERO
		root.position = Vector2.ZERO
		root.size = vs
		return
	var half := vs.x / 2.0
	var k := clampf((half - 24.0) / 740.0, 0.5, 1.0)
	scale = Vector2(k, k)
	offset = Vector2(side * half, 0.0)
	root.position = Vector2.ZERO
	root.size = Vector2(half, vs.y) / k


func _draw_band() -> void:
	var font := ThemeDB.fallback_font
	var x0 := 30.0
	# the strap with its two ends
	band.draw_rect(Rect2(6.0, 22.0, SEG * pattern.size() + 48.0, 58.0), Color("e8dcc0"))
	band.draw_rect(Rect2(6.0, 22.0, SEG * pattern.size() + 48.0, 58.0), Color("8a7a55"), false, 2.0)
	for i in pattern.size():
		var k: int = pattern[i]
		var c := Vector2(x0 + SEG * i + SEG / 2.0, 51.0)
		band.draw_rect(Rect2(c - Vector2(27, 27), Vector2(54, 54)), Color(COLS[k]))
		band.draw_rect(Rect2(c - Vector2(27, 27), Vector2(54, 54)), UI.DARK, false, 2.0)
		var d: Vector2 = DIRS[k]
		var n := Vector2(-d.y, d.x)
		band.draw_colored_polygon(PackedVector2Array([c + d * 16.0, c - d * 10.0 + n * 13.0, c - d * 10.0 - n * 13.0]), UI.DARK)
		var num := str(i + 1)
		var w := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		band.draw_string(font, Vector2(c.x - w / 2.0, 104.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.MUTED)
