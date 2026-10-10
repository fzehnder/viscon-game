extends CanvasLayer
## Level 3: the moment the Prof badge is out of the pocket. Shown on the half of the screen of
## whoever pulled it, and the game goes on for both: the badge, big and shining, and what the two
## say about it. Nothing to press; it closes by itself and then emits `done`.

signal done

const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")
const Cutscene = preload("res://scripts/cutscene.gd")

const TIME := 6.4                 # seconds it stays
const LINES := [                  # [who says it: 0 = whoever pulled the badge, 1 = the other one, text]
	[0, "Ein echter Prof-Badge. Damit geht jede Tür im Departement auf."],
	[1, "Und der Besitzer sucht gerade seinen Garderobenzettel. Wir haben vielleicht zehn Minuten."],
]
const LINE_AT := [0.8, 3.5]       # seconds after which each line starts
const TYPE_SPEED := 46.0          # letters per second
const GOLD := Color("ffc93c")

var side := -1                    # 0 left half, 1 right half, -1 whole screen (the level sets it every frame)
var pid := 0                      # who pulled the badge
var looks: Array = [{}, {}]       # how the two look right now
var t := 0.0
var line := -1
var shown := 0.0
var closing := false
var root: Control
var stage: Control
var card: PanelContainer
var portrait: Control
var name_l: Label
var text_l: Label


## The professor's badge, drawn into `r` (74 x 104, or any size of that shape).
static func draw_card(ci: CanvasItem, r: Rect2) -> void:
	var k := r.size.x / 74.0
	var ink := Color("23264a")
	var soft := Color(0.14, 0.15, 0.29, 0.35)
	ci.draw_rect(r, Color("f4f1ea"))
	ci.draw_rect(r, ink, false, maxf(2.0, 1.5 * k))
	var photo := Rect2(r.position + Vector2(8, 10) * k, Vector2(26, 30) * k)
	ci.draw_rect(photo, Color("c9c4ba"))
	ci.draw_circle(photo.position + Vector2(13, 12) * k, 6.0 * k, Color("9a958b"))               # head and shoulders
	ci.draw_rect(Rect2(photo.position + Vector2(4, 20) * k, Vector2(18, 10) * k), Color("9a958b"))
	ci.draw_rect(Rect2(r.position + Vector2(40, 12) * k, Vector2(26, 5) * k), UI.ETH_BLUE)
	ci.draw_rect(Rect2(r.position + Vector2(40, 24) * k, Vector2(22, 4) * k), soft)
	ci.draw_rect(Rect2(r.position + Vector2(8, 52) * k, Vector2(58, 6) * k), soft)
	ci.draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 82) * k, "PROF", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * k), ink)


func _ready() -> void:
	layer = 19                    # under a minigame (20): whoever plays on is not covered
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = -40.0          # a little above the middle: the minimap stays free
	cc.offset_bottom = -40.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(v)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(440, 250)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.draw.connect(_draw_stage)
	v.add_child(stage)
	var head := UI.label("Der Badge!", 38, GOLD, 9)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	# what they say about it, one after the other in the same card
	card = UI.panel(UI.PAPER, UI.ETH_BLUE, 14, 12)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	v.add_child(card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	portrait = Cutscene.Portrait.new()
	portrait.custom_minimum_size = Vector2(96, 96)   # the size Cutscene.Portrait is made for
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(portrait)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	h.add_child(tv)
	name_l = UI.label("", 16, UI.INK)
	tv.add_child(name_l)
	text_l = UI.label("", 17, UI.INK, 0, true)
	text_l.custom_minimum_size = Vector2(330, 70)
	tv.add_child(text_l)
	_place()
	UI.pop_in(stage, 0.0, 0.5)
	UI.pop_in(head, 0.15, 0.6)
	UI.sfx("grant", -6.0)


func _process(delta: float) -> void:
	t += delta
	_place()
	stage.queue_redraw()
	# the next line
	if line + 1 < LINES.size() and t >= float(LINE_AT[line + 1]):
		line += 1
		var who: int = pid if int(LINES[line][0]) == 0 else 1 - pid
		var col := Color(String(KEYS.TAG_COLORS[who]))
		portrait.look = looks[who]
		portrait.col = col
		portrait.queue_redraw()
		name_l.text = Game.name_of(who)
		name_l.label_settings.font_color = col.darkened(0.18)
		card.add_theme_stylebox_override("panel", UI.box(UI.PAPER, col, 14, 3, 12))
		text_l.text = String(LINES[line][1])
		text_l.visible_characters = 0
		shown = 0.0
		card.modulate.a = 1.0
		UI.pop_in(card, 0.0, 0.85)
		UI.sfx("pop", -12.0)
	# letters come one by one
	if line >= 0 and text_l.visible_characters >= 0:
		var before := int(shown)
		shown += delta * TYPE_SPEED
		if int(shown) >= text_l.text.length():
			text_l.visible_characters = -1
		elif int(shown) != before:
			text_l.visible_characters = int(shown)
			if int(shown) % 3 == 0:
				UI.sfx("type", -20.0)
	if not closing and t >= TIME - 0.4:
		closing = true
		var tw := create_tween()
		tw.tween_property(root, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func():
			done.emit()
			queue_free())


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
	var k := clampf((half - 24.0) / 560.0, 0.5, 1.0)
	scale = Vector2(k, k)
	offset = Vector2(side * half, 0.0)
	root.position = Vector2.ZERO
	root.size = Vector2(half, vs.y) / k


func _draw_stage() -> void:
	var c := stage.size / 2.0 + Vector2(0, 6)
	var grow := clampf(t / 0.5, 0.0, 1.0)
	# a dark disc so that the badge reads on any floor, then rays that turn slowly
	stage.draw_circle(c, 132.0 * grow, Color(0.08, 0.09, 0.17, 0.72))
	for i in (12 if grow > 0.05 else 0):      # nothing to draw yet in the very first frames
		var a := TAU * i / 12.0 + t * 0.5
		var w := TAU / 48.0
		var far := 128.0 * grow * (1.0 if i % 2 == 0 else 0.78)
		stage.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - w) * far, c + Vector2.from_angle(a + w) * far]),
			Color(GOLD, 0.26 if i % 2 == 0 else 0.14))
	# the card flips in, then sways a little
	var flip := clampf((t - 0.1) / 0.45, 0.0, 1.0)
	var sx := sin(flip * PI * 1.5) * (1.0 - flip) * 0.9 + flip      # overshoots like a card that is turned over
	var size := Vector2(120, 169)
	stage.draw_set_transform(c + Vector2(0, sin(t * 2.4) * 4.0), sin(t * 1.7) * 0.05, Vector2(maxf(absf(sx), 0.02), 1.0))
	stage.draw_rect(Rect2(-size / 2.0 + Vector2(5, 7), size), Color(0, 0, 0, 0.35))
	draw_card(stage, Rect2(-size / 2.0, size))
	# the strap it hangs on
	stage.draw_rect(Rect2(-9, -size.y / 2.0 - 12, 18, 14), Color("23264a"))
	stage.draw_rect(Rect2(-5, -size.y / 2.0 - 30, 10, 20), UI.ETH_BLUE)
	stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# sparkles around it
	for i in 7:
		var a2 := TAU * i / 7.0 + 0.4
		var p := c + Vector2(cos(a2) * 104.0, sin(a2) * 84.0)
		var tw := maxf(0.0, sin(t * 3.2 + i * 1.9))
		if tw > 0.05 and flip >= 1.0:
			stage.draw_colored_polygon(UI.star_points(p, 11.0 * tw, 3.2 * tw, t * 0.8 + i), Color(1, 1, 1, 0.95))
