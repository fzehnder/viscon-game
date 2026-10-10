extends Control
## Story intro, in order:
## start page -> hacking the (fake) ETH application portal -> both names -> Legi photo per player
## (device camera, falls back to a drawn portrait) -> character design per player -> Ersti-Tag.

const CH = preload("res://scripts/characters.gd")
const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")
const LV = preload("res://scripts/levels.gd")
const LegiCard = preload("res://scripts/legi_card.gd")
const Transcript = preload("res://scripts/transcript.gd")
const EthFront = preload("res://scripts/eth_front.gd")

const HACK := [
	["> verbinde mit bewerbung.ethz.ch ...", false],
	["> firewall gefunden: ETH-WALL 3.1", false],
	["> firewall umgehen ", true],
	["> erstis.sql laden ", true],
	["> UPDATE bewerbungen SET status = 'zugelassen';", false],
	["> UPDATE bewerbungen SET frist = 'egal';", false],
	["> spuren verwischen ", true],
	["", false],
	[">>> ZUGANG ERTEILT <<<", false],
]

const CAM_SHADER := """
shader_type canvas_item;
uniform int mode = 0;
uniform sampler2D cbcr_tex;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (mode == 1) {
		float y = c.r;
		vec2 cc = texture(cbcr_tex, UV).rg - vec2(0.5);
		COLOR = vec4(y + 1.402 * cc.y, y - 0.344 * cc.x - 0.714 * cc.y, y + 1.772 * cc.x, 1.0);
	} else if (mode == 2) {
		float y = c.r;
		vec2 cc = c.gb - vec2(0.5);
		COLOR = vec4(y + 1.402 * cc.y, y - 0.344 * cc.x - 0.714 * cc.y, y + 1.772 * cc.x, 1.0);
	} else {
		COLOR = vec4(c.rgb, 1.0);
	}
}
"""

var stage := ""
var stage_root: Control
var bg: Control
var t := 0.0
var mono: SystemFont
# hack
var browser: PanelContainer
var page_status: Label
var page_text: Label
var term_panel: PanelContainer
var term_l: Label
var glitch: Control
var hack_t := 0.0
var hack_line := 0
var hack_char := 0.0
var hack_prog := -1.0
var hack_pause := 0.0
var hack_lines: Array = []
var hack_cur := ""
var hack_finished := false
var hack_end_t := 0.0
# names
var name_edits: Array = []
var surname_edits: Array = []
# photo
var photo_pid := 0
var cam_feed: CameraFeed
var cam_vp: SubViewport
var cam_rect: TextureRect
var cam_mat: ShaderMaterial
var cam_view: TextureRect
var cam_dt := -1
var cam_wait := 0.0
var cam_failed := false
var cam_status: Label
var cam_portrait: Control
var shoot_btn: Button
var countdown := -1.0
var count_l: Label
var flash_rect: ColorRect
# custom
var previews: Array = [null, null]
var swatches: Array = [{}, {}]


## Rotating character on a little podium (also used as the camera fallback).
class Preview:
	extends Control
	const ART2 = preload("res://scripts/character_art.gd")
	var look: Dictionary = {}
	var accent := Color.WHITE
	var t := 0.0
	var facing := 0
	var spin := true
	var hop := 0.0

	func _process(delta: float) -> void:
		t += delta
		hop = maxf(0.0, hop - delta * 3.0)
		if spin:
			facing = int(t / 1.6) % 4
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y * 0.84 - sin(hop * PI) * 18.0)
		var sc := minf(size.y / 60.0, 6.5)
		var pts := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			pts.append(Vector2(size.x / 2.0, size.y * 0.84) + Vector2(cos(a) * 26 * sc, sin(a) * 8 * sc))
		draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, 0.25))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(accent.r, accent.g, accent.b, 0.9), 3.0)
		var order := [0, 3, 1, 2]
		ART2.draw_character(self, look, order[facing], t * 7.0, true, c, sc)


## Floating confetti-like shapes on a navy background, or the ETH main building (start page).
class Bg:
	extends Control
	const UI2 = preload("res://scripts/ui.gd")
	var t := 0.0
	var dark := false
	var photo: Texture2D
	var show_photo := false

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if show_photo and photo:
			# Cover the whole screen, keep the aspect ratio, crop what sticks out.
			var ps := photo.get_size()
			var sc := maxf(size.x / ps.x, size.y / ps.y)
			var ds := ps * sc
			draw_texture_rect(photo, Rect2((size - ds) / 2.0, ds), false)
			draw_rect(Rect2(Vector2.ZERO, size), Color(UI2.PAPER, 0.18))
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b0f14") if dark else Color("f6f2e8"))
		var grid := Color(1, 1, 1, 0.035) if dark else Color(UI2.ETH_BLUE, 0.07)
		var step := 48.0
		var gx := fmod(t * 12.0, step)
		var x := -step + gx
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1.0)
			x += step
		var y := -step + gx
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), grid, 1.0)
			y += step
		if dark:
			return
		for i in 26:
			var sx := fmod(i * 197.3 + t * (14.0 + i % 5 * 6.0), size.x + 80.0) - 40.0
			var sy := fmod(i * 131.7 + t * (9.0 + i % 3 * 7.0), size.y + 80.0) - 40.0
			var col := UI2.ETH_BLUE.lightened(0.15 * (i % 4))
			col.a = 0.1
			if i % 3 == 0:
				draw_colored_polygon(UI2.star_points(Vector2(sx, sy), 14, 6, t * (0.5 + i % 4 * 0.3)), col)
			elif i % 3 == 1:
				draw_circle(Vector2(sx, sy), 9.0 + i % 4 * 3.0, col)
			else:
				draw_set_transform(Vector2(sx, sy), t * (1.0 + i % 3), Vector2.ONE)
				draw_rect(Rect2(-9, -5, 18, 10), col)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Short cyan / magenta interference bars during the hack.
class Glitch:
	extends Control
	var amount := 0.0

	func _process(delta: float) -> void:
		amount = maxf(0.0, amount - delta * 2.5)
		queue_redraw()

	func _draw() -> void:
		if amount <= 0.0:
			return
		for i in int(10 * amount) + 1:
			var y := randf() * size.y
			var h := randf_range(2.0, 16.0)
			var c := Color(0.2, 1.0, 0.9, 0.18 * amount) if i % 2 == 0 else Color(1.0, 0.2, 0.7, 0.18 * amount)
			draw_rect(Rect2(randf_range(-30.0, 30.0), y, size.x, h), c)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Monaco", "Consolas", "Courier New", "monospace"])
	bg = Bg.new()
	bg.photo = ImageTexture.create_from_image(EthFront.render())
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_root = Control.new()
	stage_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_root)
	stage_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_go("title")


func _go(s: String) -> void:
	if stage == "photo":
		_stop_camera()   # also between P1's and P2's photo; _build_photo starts it again
	stage = s
	for c in stage_root.get_children():
		c.queue_free()
	bg.dark = s == "hack"
	bg.show_photo = s == "title"
	stage_root.modulate.a = 0.0
	stage_root.create_tween().tween_property(stage_root, "modulate:a", 1.0, 0.25)
	match s:
		"title": _build_title()
		"transcript": _build_transcript()
		"hack": _build_hack()
		"names": _build_names()
		"photo": _build_photo()
		"legi": _build_legi()
		"custom": _build_custom()
		"loading": _build_loading()


func _center() -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return cc


func _vbox(sep: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v


func _centered(l: Control) -> Control:
	if l is Label:
		(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l


# ------------------------------------------------------------------ 1 · start page
func _build_title() -> void:
	var card := UI.panel(UI.PAPER, UI.ETH_BLUE, 20, 34)
	_center().add_child(card)
	var v := _vbox(10)
	card.add_child(v)
	v.add_child(_centered(UI.label("ETH ZENTRUM", 24, UI.INK2)))
	var title := _centered(UI.label("Tag & Nacht", 96, UI.ETH_BLUE))
	v.add_child(title)
	v.add_child(_centered(UI.label("Ein Story-Abenteuer für zwei an einer Tastatur", 22, UI.INK)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	var start := UI.button("START", UI.ETH_BLUE, 38)
	start.custom_minimum_size = Vector2(320, 86)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_new_game)
	v.add_child(start)
	UI.pulse(start, 0.06, 1.0)
	if Game.has_profile():
		var cont := UI.button("Weiterspielen als %s & %s" % [Game.name_of(0), Game.name_of(1)], UI.ETH_BLUE.lightened(0.2), 20)
		cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cont.pressed.connect(func():
			Game.set_level(Game.story_level)   # not the elective that was played last
			_go("loading"))
		v.add_child(cont)
	v.add_child(_centered(UI.label("Enter drücken", 15, UI.INK2)))
	# the levels as a transcript of records: grades so far, and a click goes straight into a level
	# (skips the intro), handy for testing and demos
	var levels := UI.button("Leistungsüberblick · Level wählen", UI.INK2, 16)
	levels.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	levels.pressed.connect(func(): _go("transcript"))
	v.add_child(levels)
	UI.pop_in(title, 0.05, 0.3)
	title.resized.connect(func(): title.pivot_offset = title.size / 2.0)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "rotation", 0.015, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "rotation", -0.015, 1.6).set_trans(Tween.TRANS_SINE)


func _new_game() -> void:
	Game.new_game()   # level 1, nobody is an Opp yet, no grades
	_go("hack")


# ------------------------------------------------------------------ level overview (transcript.gd)
func _build_transcript() -> void:
	var tr := Transcript.new()
	stage_root.add_child(tr)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.back.connect(func(): _go("title"))
	tr.start_level.connect(func(n: int):
		Game.set_level(n)
		_go("loading"))


# ------------------------------------------------------------------ 2 · hacking the application portal
## A browser window with a fake ETH portal page. Returns the page content box.
func _browser(url: String) -> VBoxContainer:
	browser = PanelContainer.new()
	browser.add_theme_stylebox_override("panel", UI.box(Color("f4f6fa"), UI.DARK, 16, 4, 0))
	browser.custom_minimum_size = Vector2(940, 560)
	_center().add_child(browser)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	browser.add_child(outer)
	# tab bar with dots and address field
	var bar := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("dfe3ec")
	bsb.corner_radius_top_left = 12
	bsb.corner_radius_top_right = 12
	bsb.content_margin_left = 14
	bsb.content_margin_right = 14
	bsb.content_margin_top = 10
	bsb.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", bsb)
	outer.add_child(bar)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 8)
	bar.add_child(bh)
	for c in [UI.RED, UI.YELLOW, UI.GREEN]:
		var dot := Panel.new()
		var ds := StyleBoxFlat.new()
		ds.bg_color = c
		ds.set_corner_radius_all(7)
		dot.add_theme_stylebox_override("panel", ds)
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bh.add_child(dot)
	var addr := PanelContainer.new()
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color.WHITE
	asb.set_corner_radius_all(9)
	asb.content_margin_left = 12
	asb.content_margin_right = 12
	asb.content_margin_top = 4
	asb.content_margin_bottom = 5
	addr.add_theme_stylebox_override("panel", asb)
	addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(addr)
	var al := UI.label(url, 15, Color("3a4150"))
	al.label_settings.font = mono
	addr.add_child(al)
	# ETH-style header band
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = UI.ETH_BLUE
	hsb.content_margin_left = 30
	hsb.content_margin_right = 30
	hsb.content_margin_top = 16
	hsb.content_margin_bottom = 16
	head.add_theme_stylebox_override("panel", hsb)
	outer.add_child(head)
	var hh := HBoxContainer.new()
	head.add_child(hh)
	var logo := UI.label("ETH zürich", 30, UI.WHITE)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(logo)
	hh.add_child(UI.label("Online-Bewerbung · Bachelor HS 2026", 15, Color(1, 1, 1, 0.85)))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 34)
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(m)
	m.add_child(content)
	return content


func _build_hack() -> void:
	hack_t = 0.0
	hack_line = 0
	hack_char = 0.0
	hack_prog = -1.0
	hack_pause = 0.0
	hack_lines = []
	hack_cur = ""
	hack_finished = false
	hack_end_t = 0.0
	var content := _browser("https://bewerbung.ethz.ch/status")
	page_status = UI.label("Bewerbungsfrist abgelaufen", 34, UI.RED)
	content.add_child(page_status)
	page_text = UI.label("Leider ist die Frist für das Herbstsemester 2026 vorbei. Ihre Bewerbung kann nicht mehr bearbeitet werden.\n\nBei Fragen wenden Sie sich bitte an … ach, egal.", 18, Color("3a4150"), 0, true)
	page_text.custom_minimum_size = Vector2(860, 0)
	content.add_child(page_text)
	UI.pop_in(browser, 0.0, 0.85)
	# terminal on top of the browser
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	term_panel = PanelContainer.new()
	term_panel.add_theme_stylebox_override("panel", UI.box(Color("0b0f14"), Color("39ff88"), 12, 3, 16))
	term_panel.custom_minimum_size = Vector2(640, 330)
	layer.add_child(term_panel)
	term_panel.anchor_left = 0.5
	term_panel.anchor_top = 0.5
	term_panel.anchor_right = 0.5
	term_panel.anchor_bottom = 0.5
	term_panel.offset_left = -170
	term_panel.offset_top = -40
	term_panel.offset_right = 470
	term_panel.offset_bottom = 290
	term_l = UI.label("", 17, Color("39ff88"))
	term_l.label_settings.font = mono
	term_l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	term_panel.add_child(term_l)
	term_panel.visible = false
	glitch = Glitch.new()
	glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(glitch)
	glitch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var skip := UI.label("Enter = überspringen", 14, UI.MUTED)
	stage_root.add_child(skip)
	skip.position = Vector2(20, 16)


func _hack_bar(p: float) -> String:
	var n := int(p * 16.0)
	return "[%s%s] %3d%%" % ["#".repeat(n), ".".repeat(16 - n), int(p * 100.0)]


func _process_hack(delta: float) -> void:
	hack_t += delta
	if hack_t < 1.3:
		return
	if not term_panel.visible:
		term_panel.visible = true
		UI.pop_in(term_panel, 0.0, 0.7)
		UI.sfx("whoosh")
		glitch.amount = 0.8
	if hack_finished:
		hack_end_t += delta
		if hack_end_t > 1.6:
			_go("names")
		return
	if hack_pause > 0.0:
		hack_pause -= delta
	else:
		var line: Array = HACK[hack_line]
		var txt: String = line[0]
		if hack_char < txt.length():
			var before := int(hack_char)
			hack_char += delta * 58.0
			if int(hack_char) != before and int(hack_char) % 2 == 0:
				UI.sfx("type", -16.0)
			hack_cur = txt.substr(0, int(hack_char))
		elif line[1] and hack_prog < 1.0:
			hack_prog = maxf(hack_prog, 0.0) + delta / 0.8
			hack_cur = txt + _hack_bar(minf(hack_prog, 1.0))
			glitch.amount = maxf(glitch.amount, 0.35)
		else:
			hack_lines.append(txt + (_hack_bar(1.0) if line[1] else ""))
			hack_line += 1
			hack_char = 0.0
			hack_prog = -1.0
			hack_pause = 0.14
			hack_cur = ""
			if hack_line >= HACK.size():
				_hack_granted()
	var shown: Array = hack_lines.duplicate()
	shown.append(hack_cur + ("_" if int(t * 4.0) % 2 == 0 else " "))
	if shown.size() > 12:
		shown = shown.slice(shown.size() - 12)
	term_l.text = "\n".join(PackedStringArray(shown))


func _hack_granted() -> void:
	hack_finished = true
	UI.sfx("grant")
	glitch.amount = 1.0
	page_status.text = "Zulassung erteilt!"
	page_status.label_settings.font_color = Color("1f9d55")
	page_text.text = "Willkommen an der ETH Zürich. Ihre Bewerbung wurde soeben (ganz legal) angenommen."
	var big := UI.label("ZUGANG ERTEILT", 72, Color("39ff88"), 14)
	big.label_settings.font = mono
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_root.add_child(big)
	big.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	big.grow_horizontal = Control.GROW_DIRECTION_BOTH
	big.grow_vertical = Control.GROW_DIRECTION_BOTH
	UI.pop_in(big, 0.0, 2.2)
	UI.confetti(stage_root, Vector2(size.x / 2.0, size.y * 0.6), 120, true, 80.0, 1.1)


# ------------------------------------------------------------------ 3 · names
func _build_names() -> void:
	var content := _browser("https://bewerbung.ethz.ch/zulassung")
	var ok := UI.label("Zulassung erteilt!", 34, Color("1f9d55"))
	content.add_child(ok)
	content.add_child(UI.label("Fast geschafft. Wie heisst ihr?", 20, Color("3a4150")))
	name_edits = []
	surname_edits = []
	for i in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		content.add_child(row)
		var tag := UI.label("Spieler*in %d  (%s)" % [i + 1, "WASD · E" if i == 0 else "Pfeile · Enter"], 18, Color(KEYS.TAG_COLORS[i]).darkened(0.15))
		tag.custom_minimum_size = Vector2(250, 0)
		row.add_child(tag)
		var e := _name_edit("Vorname", String(Game.names[i]), 14)
		row.add_child(e)
		name_edits.append(e)
		# surname: optional, only shown on the Legi
		var se := _name_edit("Nachname (optional)", String(Game.surnames[i]), 18)
		row.add_child(se)
		surname_edits.append(se)
		var idx := i
		e.text_submitted.connect(func(_s: String): se.grab_focus())
		se.text_submitted.connect(func(_s: String): _name_submitted(idx))
	var send := UI.button("Bewerbung abschicken", UI.ETH_BLUE, 22)
	send.size_flags_horizontal = Control.SIZE_SHRINK_END
	send.pressed.connect(_names_done)
	content.add_child(send)
	UI.pop_in(browser, 0.0, 0.85)
	(name_edits[0] as LineEdit).call_deferred("grab_focus")


func _name_edit(placeholder: String, text: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.max_length = max_len
	e.placeholder_text = placeholder
	e.text = text
	e.custom_minimum_size = Vector2(250, 52)
	e.add_theme_font_size_override("font_size", 24)
	e.add_theme_color_override("font_color", Color("1c1d33"))
	e.add_theme_color_override("caret_color", UI.ETH_BLUE)
	e.add_theme_color_override("font_placeholder_color", Color("9aa3b5"))
	e.add_theme_stylebox_override("normal", UI.box(Color.WHITE, Color("b9c0cf"), 10, 3, 10, false))
	e.add_theme_stylebox_override("focus", UI.box(Color.WHITE, UI.ETH_BLUE, 10, 3, 10, false))
	e.text_changed.connect(func(_s: String): UI.sfx("type", -14.0))
	return e


func _name_submitted(i: int) -> void:
	if i == 0:
		(name_edits[1] as LineEdit).grab_focus()
	else:
		_names_done()


func _names_done() -> void:
	for i in 2:
		Game.names[i] = (name_edits[i] as LineEdit).text.strip_edges()
		Game.surnames[i] = (surname_edits[i] as LineEdit).text.strip_edges()
	UI.sfx("grant")
	photo_pid = 0
	_go("photo")


# ------------------------------------------------------------------ 4 · Legi photo with the device camera
func _build_photo() -> void:
	countdown = -1.0
	cam_failed = false
	cam_wait = 0.0
	var pc := Color(KEYS.TAG_COLORS[photo_pid])
	var card := UI.panel(UI.PAPER, pc, 20, 24)
	_center().add_child(card)
	var v := _vbox(12)
	card.add_child(v)
	v.add_child(_centered(UI.label("Legi-Foto", 20, UI.INK2)))
	v.add_child(_centered(UI.label(Game.name_of(photo_pid), 46, pc, 10)))
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(300, 375)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(frame)
	var border := Panel.new()
	border.add_theme_stylebox_override("panel", UI.box(UI.DARK, pc, 16, 5, 0, false))
	frame.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var portrait := Preview.new()
	portrait.look = Game.player_looks[photo_pid]
	portrait.accent = pc
	portrait.spin = false
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 8
	portrait.offset_top = 8
	portrait.offset_right = -8
	portrait.offset_bottom = -8
	cam_portrait = portrait
	_start_camera()
	cam_view = TextureRect.new()
	cam_view.texture = cam_vp.get_texture()
	cam_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cam_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cam_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(cam_view)
	cam_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_view.offset_left = 6
	cam_view.offset_top = 6
	cam_view.offset_right = -6
	cam_view.offset_bottom = -6
	cam_view.visible = false
	count_l = UI.label("", 140, UI.WHITE, 22)
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(count_l)
	count_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_status = UI.label("Kamera wird gesucht …", 16, UI.INK2, 0, true)
	cam_status.custom_minimum_size = Vector2(420, 0)
	cam_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cam_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	shoot_btn = UI.button("Foto machen", UI.ETH_BLUE, 24)
	shoot_btn.pressed.connect(_shoot)
	row.add_child(shoot_btn)
	var skip := UI.button("Ohne Foto", UI.INK2, 18)
	skip.pressed.connect(func(): _use_photo(null))
	row.add_child(skip)
	v.add_child(_centered(UI.label("Leertaste, E oder Enter = Foto", 14, UI.INK2)))
	UI.pop_in(card, 0.0, 0.7)


func _start_camera() -> void:
	# newer Godot versions only list cameras while monitoring is on
	if CameraServer.has_method("set_monitoring_feeds"):
		CameraServer.call("set_monitoring_feeds", true)
	cam_feed = null
	cam_dt = -1
	cam_vp = SubViewport.new()
	cam_vp.size = Vector2i(360, 450)
	cam_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(cam_vp)
	var back := ColorRect.new()
	back.color = UI.DARK
	back.size = Vector2(360, 450)
	cam_vp.add_child(back)
	cam_rect = TextureRect.new()
	cam_rect.size = Vector2(360, 450)
	cam_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cam_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cam_rect.flip_h = true
	cam_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CAM_SHADER
	cam_mat.shader = sh
	cam_rect.material = cam_mat
	cam_vp.add_child(cam_rect)


func _stop_camera() -> void:
	if cam_feed != null:
		cam_feed.feed_is_active = false
		cam_feed = null
	if cam_vp != null:
		cam_vp.queue_free()
		cam_vp = null


func _apply_feed(dt: int) -> void:
	cam_dt = dt
	var id: int = cam_feed.get_id()
	if dt == CameraFeed.FEED_YCBCR_SEP:
		var ty := CameraTexture.new()
		ty.camera_feed_id = id
		ty.which_feed = CameraServer.FEED_Y_IMAGE
		var tc := CameraTexture.new()
		tc.camera_feed_id = id
		tc.which_feed = CameraServer.FEED_CBCR_IMAGE
		cam_rect.texture = ty
		cam_mat.set_shader_parameter("cbcr_tex", tc)
		cam_mat.set_shader_parameter("mode", 1)
	elif dt == CameraFeed.FEED_YCBCR:
		var t1 := CameraTexture.new()
		t1.camera_feed_id = id
		t1.which_feed = CameraServer.FEED_YCBCR_IMAGE
		cam_rect.texture = t1
		cam_mat.set_shader_parameter("mode", 2)
	else:
		var t2 := CameraTexture.new()
		t2.camera_feed_id = id
		t2.which_feed = CameraServer.FEED_RGBA_IMAGE
		cam_rect.texture = t2
		cam_mat.set_shader_parameter("mode", 0)
	if dt != CameraFeed.FEED_NOIMAGE:
		cam_view.visible = true
		cam_portrait.visible = false
		cam_status.text = "Lächeln! Gleich wird's offiziell."


func _process_photo(delta: float) -> void:
	if cam_feed == null and not cam_failed:
		cam_wait += delta
		if CameraServer.get_feed_count() > 0:
			cam_feed = CameraServer.get_feed(0)
			cam_feed.feed_is_active = true
			cam_status.text = "Kamera gefunden. Einen Moment …"
		elif cam_wait > 4.0:
			cam_failed = true
			cam_status.text = "Keine Kamera gefunden (oder kein Zugriff). Kein Problem: wir zeichnen dich!"
			shoot_btn.text = "Weiter"
	elif cam_feed != null:
		var dt: int = cam_feed.get_datatype()
		if dt != cam_dt:
			_apply_feed(dt)
	if countdown > 0.0:
		var before := ceili(countdown)
		countdown -= delta
		var now := ceili(countdown)
		if countdown <= 0.0:
			count_l.text = ""
			_capture()
		elif now != before:
			_count_pop(now)


func _count_pop(n: int) -> void:
	count_l.text = str(n)
	count_l.pivot_offset = count_l.size / 2.0
	count_l.scale = Vector2(1.8, 1.8)
	count_l.create_tween().tween_property(count_l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UI.sfx("tick")


func _shoot() -> void:
	if countdown > 0.0:
		return
	if cam_failed or cam_feed == null or not cam_view.visible:
		_use_photo(null)
		return
	countdown = 3.0
	_count_pop(3)


func _capture() -> void:
	countdown = -1.0
	var img: Image = cam_vp.get_texture().get_image()
	UI.sfx("shutter")
	flash_rect.color = Color(1, 1, 1, 1)
	flash_rect.create_tween().tween_property(flash_rect, "color:a", 0.0, 0.5)
	_use_photo(ImageTexture.create_from_image(img) if img != null else null)


## First P1 takes their photo, then P2; then the character design, and at the end both Legis side by side.
func _use_photo(tex) -> void:
	Game.photos[photo_pid] = tex
	if photo_pid == 0:
		photo_pid = 1
		_go("photo")
	else:
		_go("custom")


# ------------------------------------------------------------------ 5 · the Legi
func _build_legi() -> void:
	var v := _vbox(18)
	_center().add_child(v)
	v.add_child(_centered(UI.label("Eure Legis sind da!", 44, UI.ETH_BLUE)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	v.add_child(row)
	for i in 2:
		var pc := Color(KEYS.TAG_COLORS[i])
		var col := _vbox(8)
		row.add_child(col)
		col.add_child(_centered(UI.label(Game.name_of(i), 24, pc, 6)))
		var card := LegiCard.new()
		card.set_player(i)
		card.accent = pc
		card.custom_minimum_size = Vector2(520, 324)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(card)
		# card flip-in, the second one a moment later
		card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
		card.scale = Vector2(0.05, 1.0)
		card.rotation = -0.2 if i == 0 else 0.2
		var tw := card.create_tween().set_parallel(true)
		tw.tween_property(card, "scale", Vector2.ONE, 0.55).set_delay(0.15 + 0.2 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "rotation", 0.0, 0.55).set_delay(0.15 + 0.2 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# then the validity (S, date, ASVZ) is printed onto the strip
		tw.tween_callback(func():
			card.validate()
			UI.sfx("click", -4.0)).set_delay(0.9 + 0.25 * i)
	var next := UI.button("Ab zum Ersti-Tag!", UI.ETH_BLUE, 28)
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(_legi_next)
	v.add_child(next)
	get_tree().create_timer(0.35).timeout.connect(func():
		if stage == "legi":
			UI.sfx("success")
			UI.confetti(stage_root, Vector2(size.x * 0.3, size.y + 10), 90, true, 30.0, 1.25)
			UI.confetti(stage_root, Vector2(size.x * 0.7, size.y + 10), 90, true, 30.0, 1.25))


func _legi_next() -> void:
	_go("loading")


# ------------------------------------------------------------------ 6 · character design
func _build_custom() -> void:
	var v := _vbox(14)
	_center().add_child(v)
	v.add_child(_centered(UI.label("Gestaltet eure Figuren", 40, UI.ETH_BLUE)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in 2:
		row.add_child(_custom_column(i))
	var go := UI.button("Weiter zur Legi", UI.ETH_BLUE, 28)
	go.custom_minimum_size = Vector2(340, 70)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func(): _go("legi"))
	v.add_child(go)
	UI.pulse(go, 0.05, 1.0)
	v.add_child(_centered(UI.label("Enter = weiter", 14, UI.INK2)))


func _custom_column(i: int) -> Control:
	var pc := Color(KEYS.TAG_COLORS[i])
	var card := UI.panel(UI.PAPER, pc, 16, 16)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := _vbox(8)
	card.add_child(v)
	v.add_child(_centered(UI.label(Game.name_of(i), 30, pc, 7)))
	var pv := Preview.new()
	pv.look = Game.player_looks[i]
	pv.accent = pc
	pv.custom_minimum_size = Vector2(260, 220)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pv)
	previews[i] = pv
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	swatches[i] = {}
	var rows := [["hair_style", "Frisur", CH.HAIR_STYLES], ["hair", "Haarfarbe", CH.HAIR_COLORS], ["skin", "Hautton", CH.SKIN_TONES],
		["top", "Oberteil", CH.TOP_COLORS], ["pants", "Hose", CH.PANTS_COLORS]]
	for r in rows:
		var key: String = r[0]
		var opts: Array = r[2]
		var nl := UI.label(r[1], 15, UI.INK2)
		nl.custom_minimum_size = Vector2(88, 0)
		grid.add_child(nl)
		var prev := UI.button("<", UI.ETH_BLUE, 16)
		prev.pressed.connect(func(): _cycle(i, key, opts, -1))
		grid.add_child(prev)
		var sw := PanelContainer.new()
		sw.custom_minimum_size = Vector2(118, 34)
		var swl := UI.label("", 15, UI.INK)
		swl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sw.add_child(swl)
		grid.add_child(sw)
		swatches[i][key] = [sw, swl]
		var nxt := UI.button(">", UI.ETH_BLUE, 16)
		nxt.pressed.connect(func(): _cycle(i, key, opts, 1))
		grid.add_child(nxt)
	# study programme, printed on the Legi
	var pl := UI.label("Studium", 15, UI.INK2)
	pl.custom_minimum_size = Vector2(88, 0)
	grid.add_child(pl)
	var pprev := UI.button("<", UI.ETH_BLUE, 16)
	grid.add_child(pprev)
	var psw := PanelContainer.new()
	psw.custom_minimum_size = Vector2(118, 34)
	psw.add_theme_stylebox_override("panel", UI.box(UI.PAPER2, UI.LINE, 10, 2, 4, false))
	var psl := UI.label("", 14, UI.INK)
	psl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	psw.add_child(psl)
	grid.add_child(psw)
	var pnext := UI.button(">", UI.ETH_BLUE, 16)
	grid.add_child(pnext)
	var show_prog := func():
		psl.text = String(Game.PROGRAMMES[int(Game.programmes[i])][0])
	var step_prog := func(dir: int):
		var n: int = Game.PROGRAMMES.size()
		Game.programmes[i] = (int(Game.programmes[i]) + dir + n) % n
		UI.sfx("pop", -8.0)
		show_prog.call()
	pprev.pressed.connect(func(): step_prog.call(-1))
	pnext.pressed.connect(func(): step_prog.call(1))
	show_prog.call()
	_refresh_swatches(i)
	return card


func _cycle(i: int, key: String, opts: Array, dir: int) -> void:
	var lk: Dictionary = Game.player_looks[i]
	var k := opts.find(lk.get(key, opts[0]))
	k = (k + dir + opts.size()) % opts.size()
	lk[key] = opts[k]
	if key == "top" and lk.get("top_style", "") == "overall":
		lk["pants"] = opts[k]
	if previews[i]:
		previews[i].look = lk
		previews[i].hop = 1.0
	UI.sfx("pop", -8.0)
	_refresh_swatches(i)


func _refresh_swatches(i: int) -> void:
	var lk: Dictionary = Game.player_looks[i]
	for key in swatches[i]:
		var sw: PanelContainer = swatches[i][key][0]
		var swl: Label = swatches[i][key][1]
		if key == "hair_style":
			sw.add_theme_stylebox_override("panel", UI.box(UI.PAPER2, UI.LINE, 10, 2, 4, false))
			swl.text = String(lk.get(key, "kurz")).capitalize()
		else:
			sw.add_theme_stylebox_override("panel", UI.box(Color(String(lk.get(key, "888888"))), UI.LINE, 10, 2, 4, false))
			swl.text = ""


# ------------------------------------------------------------------ 7 · into the level
func _build_loading() -> void:
	var lv: Dictionary = LV.level()
	var v := _vbox(10)
	_center().add_child(v)
	v.add_child(_centered(UI.label(String(lv["tag"]), 24, UI.INK2)))
	var title := _centered(UI.label(String(lv["name"]), 96, UI.ETH_BLUE))
	v.add_child(title)
	var dots: Label = UI.label("lädt", 26, UI.INK)
	v.add_child(_centered(dots))
	UI.pop_in(title, 0.0, 0.3)
	UI.sfx("whoosh")
	var tw := dots.create_tween()
	for k in 4:
		tw.tween_callback(func(): dots.text = "lädt" + ".".repeat(k))
		tw.tween_interval(0.3)
	tw.tween_callback(func():
		Game._apply_level()
		get_tree().change_scene_to_file("res://main.tscn"))


# ------------------------------------------------------------------ loop + keys
func _process(delta: float) -> void:
	t += delta
	match stage:
		"hack":
			_process_hack(delta)
		"photo":
			_process_photo(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	var ok := k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]
	match stage:
		"title":
			if ok:
				_new_game()
		"hack":
			if ok:
				_go("names")
		"photo":
			if ok:
				_shoot()
		"legi":
			if ok:
				_legi_next()
		"custom":
			if k in [KEY_ENTER, KEY_KP_ENTER]:
				_go("legi")
