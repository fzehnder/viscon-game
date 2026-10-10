extends CanvasLayer
## Level 3: the wristband template, shown on the half of the screen of whoever is looking at it.
## The other player rebuilds it in the kitchen with the sequence minigame and cannot see this.
## Same four directions, in the same order, as the pads of that minigame (minigame.gd).
## The template also shows how far the builder has got, so that the one who reads it out knows
## which arrow comes next and sees when the builder has to start again.

const UI = preload("res://scripts/ui.gd")
const DIRS := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]   # up, down, left, right
const COLS := ["ff5d8f", "4d8dff", "ffc93c", "3ddc97"]
const SEG := 62.0

var side := -1             # 0 left half, 1 right half, -1 whole screen
var pattern: Array = []
var accent := Color("ffc93c")
var hint := ""             # how to put it away
var status := ""           # what the builder is doing right now (set by the level every frame)
var built := -1            # how many arrows the builder has got right so far, -1 = nobody is building
var wrong := false         # the builder just pressed a wrong one
var t := 0.0
var root: Control
var band: Control
var status_l: Label


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := UI.panel(UI.PAPER, accent, 14, 18.0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UI.label("Armband-Vorlage", 30, accent.darkened(0.18)))
	band = Control.new()
	band.custom_minimum_size = Vector2(SEG * pattern.size() + 60.0, 118.0)
	band.draw.connect(_draw_band)
	v.add_child(band)
	status_l = UI.label(status, 17, UI.INK, 0, true)
	status_l.custom_minimum_size = Vector2(band.custom_minimum_size.x, 46)
	v.add_child(status_l)
	var info := UI.label(hint, 14, UI.INK2, 0, true)
	info.custom_minimum_size = Vector2(band.custom_minimum_size.x, 0)
	v.add_child(info)
	_place()
	UI.pop_in(p, 0.0, 0.6)
	UI.sfx("whoosh", -10.0)


func _process(delta: float) -> void:
	t += delta
	_place()
	if status_l.text != status:
		status_l.text = status
	status_l.label_settings.font_color = UI.RED if wrong else UI.INK
	band.queue_redraw()


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
		var box := Rect2(c - Vector2(27, 27), Vector2(54, 54))
		band.draw_rect(box, Color(COLS[k]))
		band.draw_rect(box, UI.DARK, false, 2.0)
		var d: Vector2 = DIRS[k]
		var n := Vector2(-d.y, d.x)
		band.draw_colored_polygon(PackedVector2Array([c + d * 16.0, c - d * 10.0 + n * 13.0, c - d * 10.0 - n * 13.0]), UI.DARK)
		var num_col := UI.INK2
		if built >= 0 and i < built:
			# already built: ticked off
			band.draw_rect(box, Color(0.08, 0.09, 0.17, 0.55))
			band.draw_polyline(PackedVector2Array([c + Vector2(-13, 1), c + Vector2(-4, 11), c + Vector2(14, -11)]), UI.GREEN, 5.0)
			num_col = UI.OK
		elif built >= 0 and i == built:
			# the one to read out next
			band.draw_rect(box.grow(4.0 + 2.0 * sin(t * 6.0)), UI.INK, false, 4.0)
			num_col = UI.INK
		var num := str(i + 1)
		var w := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		band.draw_string(font, Vector2(c.x - w / 2.0, 104.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, num_col)
