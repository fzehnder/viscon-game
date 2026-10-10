extends CanvasLayer
## Screen overlay in the playful style: one task card per player on that player's side of the
## screen (P1 left, P2 right), level and timer top centre, mini map bottom centre,
## interaction prompts, bouncy toasts, big "done!" celebrations with confetti, and the
## start / win / lose screens.
## The middle column (timer above, mini map below) stays clear of the players because main.gd
## splits the screen early when they move apart vertically (SPLIT_AT_Y).

const CH = preload("res://scripts/characters.gd")
const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const M = preload("res://scripts/map_data.gd")
const BAR_W := 132.0

var main
var root: Control
# one task card per player: [panel, zone label, counter label, box for the rows]
var cards: Array = []
var task_rows: Array = [[], []]   # per player: [row panel, tick, label, style box, picked]
var title_l: Label
var minimap: Control
# timer / meter
var meter_title: Label
var meter_l: Label
var meter_fill: ColorRect
var status_l: Label
var timer_card: PanelContainer
var last_sec := -1
# ability (night)
var ab_panel: PanelContainer
var ab_name: Label
var ab_fill: ColorRect
# prompts per player: [panel, label, was_visible]
var prompts: Array = []
# toast
var toast_p: PanelContainer
var toast_h: Label
var toast_b: Label
var toast_t := 0.0
var toast_tw: Tween
# overlay
var overlay: Control
var ov_card: PanelContainer
var ov_tag: Label
var ov_tag_p: PanelContainer
var ov_title: Label
var ov_body: Label
var ov_hint: Label
var ov_btn: Button
var ov_menu: Button
var blackout: ColorRect
var arrows: Control
var fx_layer: Control


## Spinning star burst behind a celebration.
class Burst:
	extends Control
	const UI2 = preload("res://scripts/ui.gd")
	var col := Color.WHITE
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		for i in 12:
			var a := t * 0.8 + i * TAU / 12.0
			var p1 := Vector2.from_angle(a - 0.12) * 40.0
			var p2 := Vector2.from_angle(a + 0.12) * 40.0
			var p3 := Vector2.from_angle(a) * 230.0
			draw_colored_polygon(PackedVector2Array([p1, p3, p2]), Color(col, 0.16))
		draw_colored_polygon(UI2.star_points(Vector2(-250, -10), 22, 9, t * 2.0), UI2.YELLOW)
		draw_colored_polygon(UI2.star_points(Vector2(250, -10), 22, 9, -t * 2.0), UI2.YELLOW)
		draw_colored_polygon(UI2.star_points(Vector2(-205, -60), 12, 5, -t * 3.0), UI2.PINK)
		draw_colored_polygon(UI2.star_points(Vector2(210, 45), 12, 5, t * 3.0), UI2.GREEN)


## Check box in front of a task: empty frame, filled with a tick once the task is done.
class Tick:
	extends Control
	var col := Color.WHITE
	var on := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, col if on else Color(0, 0, 0, 0.3))
		draw_rect(r, col, false, 2.0)
		if on:
			draw_polyline(PackedVector2Array([Vector2(3.5, 8.5), Vector2(7.0, 12.0), Vector2(12.5, 4.5)]), Color.WHITE, 2.2)


## Mini map: the whole campus, both players, what is still to do (in the colour of whoever still
## has to do it, yellow = both) and Opps that are chasing somebody right now.
class MiniMap:
	extends Control
	const M2 = preload("res://scripts/map_data.gd")
	const UI2 = preload("res://scripts/ui.gd")
	const KEYS2 = preload("res://scripts/controls.gd")
	const TS := 32.0
	const PX := 1.75   # screen pixels per tile
	var main
	var tex: ImageTexture
	var map_px := Vector2.ONE
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var w: int = main.data["W"]
		var h: int = main.data["H"]
		map_px = Vector2(w, h) * TS
		custom_minimum_size = Vector2(w, h) * PX
		var cols := {M2.GRASS: "86b25e", M2.ROAD: "5b5f66", M2.WALK: "bfbaaf", M2.PAVE: "d6ccb8", M2.STONE: "dcd8cf",
			M2.WOOD: "b98a57", M2.WALL: "3d4148", M2.MARBLE: "e1dccf", M2.TILE: "e3e9e9", M2.ROOF: "8f9297",
			M2.RAIL: "8b8479", M2.CARPET: "b98a57", M2.LAB: "cfd8dc"}
		var img := Image.create(w, h, false, Image.FORMAT_RGB8)
		for y in h:
			for x in w:
				var c := Color(String(cols.get(main.data["map"][y * w + x], "86b25e")))
				if main.night:
					c = c.darkened(0.5).lerp(Color("1c2b4d"), 0.3)
				img.set_pixel(x, y, c)
		tex = ImageTexture.create_from_image(img)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _at(world_px: Vector2) -> Vector2:
		return world_px / map_px * size

	func _draw() -> void:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		var dark := Color(0.08, 0.09, 0.17)
		if main.state == "play":
			# what is still to do
			for goal in main.goal_positions():
				var gp: Vector2 = goal[0] if goal is Array else goal
				var gc: Color = goal[1] if goal is Array else UI2.YELLOW
				var p := _at(gp)
				var dia := PackedVector2Array([p + Vector2(0, -4), p + Vector2(3.5, 0), p + Vector2(0, 4), p + Vector2(-3.5, 0)])
				draw_colored_polygon(dia, gc)
				draw_polyline(dia + PackedVector2Array([dia[0]]), dark, 1.0)
			# Opps on the hunt
			for op in main.opps:
				if op.angry and op.state == op.JAGD:
					var po := _at(op.global_position)
					draw_circle(po, 4.5 + sin(t * 12.0), UI2.RED)
					draw_arc(po, 6.5, 0.0, TAU, 16, UI2.RED, 1.0)
			# the dashed way to a picked task
			for i in main.players.size():
				var route: Array = main.routes[i]
				for j in range(1, route.size()):
					draw_dashed_line(_at(route[j - 1]), _at(route[j]), Color(KEYS2.TAG_COLORS[i]), 1.6, 3.0)
		# the two players, always on top
		for i in main.players.size():
			var pl = main.players[i]
			var pp := _at(pl.global_position)
			var col := Color(KEYS2.TAG_COLORS[i])
			draw_arc(pp, 6.0 + 2.0 * (sin(t * 4.0 + i * PI) * 0.5 + 0.5), 0.0, TAU, 16, Color(col, 0.55), 1.2)
			draw_circle(pp, 4.3, dark)
			draw_circle(pp, 3.2, col)


func _bar(w: float, fill_col: Color) -> Array:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(w, 12)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.35)
	bg.size = Vector2(w, 12)
	bar.add_child(bg)
	var f := ColorRect.new()
	f.color = fill_col
	f.size = Vector2(0, 12)
	bar.add_child(f)
	return [bar, f]


func _pill(text: String, bg: Color, size: int = 12) -> Array:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(text, size, UI.WHITE)
	p.add_child(l)
	return [p, l, sb]


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	blackout = ColorRect.new()
	blackout.color = Color(0.01, 0.02, 0.06, 0.5)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(blackout)
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout.visible = false

	arrows = Control.new()
	arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(arrows)
	arrows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arrows.draw.connect(_draw_arrows)

	# ---- top corners: the tasks of each player on that player's side (P1 left, P2 right)
	for i in 2:
		var pc := Color(KEYS.TAG_COLORS[i])
		var card := UI.panel(UI.NAVY, pc, 18, 12)
		card.custom_minimum_size = Vector2(236, 0)
		root.add_child(card)
		card.offset_top = 14
		if i == 0:
			card.offset_left = 16
		else:
			card.anchor_left = 1.0
			card.anchor_right = 1.0
			card.offset_left = -252
			card.offset_right = -16
			card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 5)
		card.add_child(v)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		v.add_child(head)
		head.add_child(_pill(Game.name_of(i), pc, 14)[0])
		var zl := UI.label("", 12, UI.MUTED)
		zl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zl.clip_text = true
		head.add_child(zl)
		var cl := UI.label("", 13, UI.MUTED)
		head.add_child(cl)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		v.add_child(box)
		var hint_l := UI.label("%s: Weg zur Aufgabe zeigen" % KEYS.SELECT_NAMES[i], 11, UI.MUTED)
		hint_l.visible = not main.night
		v.add_child(hint_l)
		cards.append([card, zl, cl, box])

	# ---- top centre: level and timer (or the visibility meter at night). Yellow = for both.
	timer_card = UI.panel(UI.NAVY, UI.YELLOW, 16, 8)
	root.add_child(timer_card)
	timer_card.anchor_left = 0.5
	timer_card.anchor_right = 0.5
	timer_card.offset_left = -125
	timer_card.offset_right = 125
	timer_card.offset_top = 14
	timer_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 0)
	timer_card.add_child(v2)
	var head2 := HBoxContainer.new()
	head2.alignment = BoxContainer.ALIGNMENT_CENTER
	head2.add_theme_constant_override("separation", 8)
	v2.add_child(head2)
	head2.add_child(_pill("LEVEL %d" % Game.level, UI.PINK, 11)[0])
	title_l = UI.label("Nacht" if main.night else String(main.lv["name"]), 16, UI.YELLOW, 4)
	head2.add_child(title_l)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 10)
	v2.add_child(row2)
	meter_l = UI.label("", 20 if main.night else 28, UI.GREEN, 6)
	row2.add_child(meter_l)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 2)
	row2.add_child(side)
	var mb := _bar(BAR_W, UI.GREEN)
	side.add_child(mb[0])
	meter_fill = mb[1]
	meter_title = UI.label("SICHTBARKEIT" if main.night else String(main.lv.get("timer_title", "ZEIT BIS FEIERABEND")), 10, UI.MUTED)
	side.add_child(meter_title)
	status_l = UI.label("", 10, UI.MUTED)
	side.add_child(status_l)

	# ---- bottom centre: mini map of the campus with both players and what is still to do
	var mp := UI.panel(UI.NAVY, UI.YELLOW, 12, 4)
	root.add_child(mp)
	mp.anchor_left = 0.5
	mp.anchor_right = 0.5
	mp.anchor_top = 1.0
	mp.anchor_bottom = 1.0
	mp.offset_left = -106
	mp.offset_right = 106
	mp.offset_top = -171
	mp.offset_bottom = -14
	mp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimap = MiniMap.new()
	minimap.main = main
	mp.add_child(minimap)

	# ---- bottom-left: ability (night only)
	ab_panel = UI.panel(UI.NAVY, UI.PURPLE, 16, 10)
	root.add_child(ab_panel)
	ab_panel.anchor_top = 1.0
	ab_panel.anchor_bottom = 1.0
	ab_panel.offset_left = 16
	ab_panel.offset_top = -84
	ab_panel.offset_bottom = -16
	ab_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var av := VBoxContainer.new()
	ab_panel.add_child(av)
	ab_name = UI.label(main.ability["name"], 15, UI.WHITE)
	av.add_child(ab_name)
	var abb := _bar(210, UI.PURPLE)
	av.add_child(abb[0])
	ab_fill = abb[1]
	ab_panel.visible = main.night

	# ---- bottom: one interaction prompt per player
	for i in 2:
		var pc := Color(KEYS.TAG_COLORS[i])
		var pp := UI.panel(UI.NAVY, pc, 16, 8)
		root.add_child(pp)
		pp.anchor_left = 0.25 + 0.5 * i   # under the middle of each player's half
		pp.anchor_right = 0.25 + 0.5 * i
		pp.anchor_top = 1.0
		pp.anchor_bottom = 1.0
		pp.offset_top = -74
		pp.offset_bottom = -20
		pp.grow_horizontal = Control.GROW_DIRECTION_BOTH
		pp.grow_vertical = Control.GROW_DIRECTION_BEGIN
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		pp.add_child(hb)
		var key := _pill(KEYS.KEY_NAMES[i], pc, 16)
		hb.add_child(key[0])
		var pl_l := UI.label("", 18, UI.WHITE, 4)
		hb.add_child(pl_l)
		pp.visible = false
		prompts.append([pp, pl_l, false])

	# ---- toast
	toast_p = UI.panel(UI.NAVY, UI.YELLOW, 18, 14)
	root.add_child(toast_p)
	toast_p.anchor_left = 0.5
	toast_p.anchor_right = 0.5
	toast_p.anchor_top = 1.0
	toast_p.anchor_bottom = 1.0
	toast_p.offset_left = -270
	toast_p.offset_right = 270
	toast_p.offset_bottom = -112   # shows in front of the mini map for a few seconds
	toast_p.offset_top = -210
	toast_p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var tv := VBoxContainer.new()
	toast_p.add_child(tv)
	toast_h = UI.label("", 21, UI.YELLOW, 5)
	tv.add_child(toast_h)
	toast_b = UI.label("", 16, UI.WHITE, 0, true)
	toast_b.custom_minimum_size = Vector2(500, 0)
	tv.add_child(toast_b)
	toast_p.visible = false

	# ---- celebration layer
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fx_layer)
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ---- overlay (start / win / lose)
	overlay = Control.new()
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.12, 0.7)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	overlay.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov_card = UI.panel(UI.NAVY, UI.YELLOW, 28, 26)
	ov_card.mouse_filter = Control.MOUSE_FILTER_STOP
	cc.add_child(ov_card)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 12)
	ov_card.add_child(ov)
	var tp := _pill("", UI.PINK, 14)
	ov_tag_p = tp[0]
	ov_tag = tp[1]
	ov_tag_p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ov.add_child(ov_tag_p)
	ov_title = UI.label("", 52, UI.YELLOW, 10)
	ov.add_child(ov_title)
	ov_body = UI.label("", 18, UI.WHITE, 0, true)
	ov_body.custom_minimum_size = Vector2(640, 0)
	ov.add_child(ov_body)
	ov_hint = UI.label("", 14, UI.MUTED, 0, true)
	ov_hint.custom_minimum_size = Vector2(640, 0)
	ov.add_child(ov_hint)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 14)
	ov.add_child(brow)
	ov_btn = UI.button("", UI.GREEN, 24)
	ov_btn.custom_minimum_size = Vector2(240, 60)
	ov_btn.pressed.connect(func(): main.on_overlay_button())
	brow.add_child(ov_btn)
	ov_menu = UI.button("Startbildschirm", UI.PURPLE, 18)
	ov_menu.custom_minimum_size = Vector2(200, 60)
	ov_menu.pressed.connect(func(): main.on_overlay_menu())
	brow.add_child(ov_menu)


# ------------------------------------------------------------------ overlay
## kind: "info" (start), "win" (confetti + fanfare), "lose" (shake).
func show_overlay(title: String, body: String, hint: String, button: String, with_menu: bool = false, kind: String = "info", tag: String = "") -> void:
	var col := UI.YELLOW
	var btn := UI.GREEN
	match kind:
		"win":
			col = UI.GREEN
		"lose":
			col = UI.RED
			btn = UI.ORANGE
	ov_card.add_theme_stylebox_override("panel", UI.box(UI.NAVY, col, 28, 5, 26))
	ov_title.text = title
	ov_title.label_settings.font_color = col
	ov_body.text = body
	ov_hint.text = hint
	ov_tag.text = tag
	ov_tag_p.visible = tag != ""
	ov_btn.text = button
	ov_btn.add_theme_stylebox_override("normal", UI._btn_box(btn, 8, 10))
	ov_btn.add_theme_stylebox_override("hover", UI._btn_box(btn.lightened(0.12), 8, 10))
	ov_menu.visible = with_menu
	overlay.visible = true
	UI.pop_in(ov_card, 0.05)
	match kind:
		"win":
			UI.sfx("fanfare")
			var vs: Vector2 = root.size
			for k in 3:
				get_tree().create_timer(0.15 + k * 0.35).timeout.connect(func():
					UI.confetti(fx_layer, Vector2(vs.x * 0.15, vs.y + 10), 110, true, 35.0, 1.3)
					UI.confetti(fx_layer, Vector2(vs.x * 0.85, vs.y + 10), 110, true, 35.0, 1.3))
		"lose":
			UI.sfx("fail")
			get_tree().create_timer(0.45).timeout.connect(func(): UI.shake(ov_card, 14.0))
		_:
			UI.sfx("pop")


func hide_overlay() -> void:
	overlay.visible = false


# ------------------------------------------------------------------ toast + celebrate
func toast(head: String, body: String, dur: float = 5.0) -> void:
	toast_h.text = head
	toast_b.text = body
	toast_t = dur
	if toast_tw and toast_tw.is_valid():
		toast_tw.kill()
	toast_p.visible = true
	toast_p.modulate.a = 1.0
	UI.pop_in(toast_p, 0.0, 0.8)
	UI.sfx("pop", -12.0)


## Big "done!" moment: star burst, bouncing title, confetti and a chime.
## side: 0 = left half, 1 = right half, -1 = middle of the screen.
func celebrate(title: String, sub: String, col: Color, side: int = -1) -> void:
	var vs: Vector2 = root.size
	var cx := vs.x / 2.0 if side < 0 else vs.x * (0.25 + 0.5 * side)
	var center := Vector2(cx, vs.y * 0.38)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = center
	fx_layer.add_child(holder)
	var burst := Burst.new()
	burst.col = col
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(burst)
	var big := UI.label(title, 50, col, 12)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.position = Vector2(-400, -62)
	big.size = Vector2(800, 70)
	holder.add_child(big)
	var done_l := UI.label("ERLEDIGT!", 24, UI.WHITE, 7)
	done_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done_l.position = Vector2(-400, -100)
	done_l.size = Vector2(800, 34)
	holder.add_child(done_l)
	var small := UI.label(sub, 20, UI.WHITE, 6)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.position = Vector2(-400, 14)
	small.size = Vector2(800, 30)
	holder.add_child(small)
	holder.scale = Vector2(0.15, 0.15)
	holder.rotation = -0.25
	var tw := holder.create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "scale", Vector2(1.12, 1.12), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "rotation", 0.04, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(holder, "scale", Vector2.ONE, 0.18)
	tw.chain().tween_property(holder, "rotation", 0.0, 0.12)
	tw.chain().tween_interval(1.1)
	tw.chain().tween_property(holder, "position", center + Vector2(0, -60), 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(holder.queue_free)
	UI.confetti(fx_layer, center + Vector2(0, 30), 90, true, 80.0, 1.0)
	UI.sfx("success")


# ------------------------------------------------------------------ task cards
func _build_tasks(pid: int, objs: Array) -> void:
	for r in task_rows[pid]:
		(r[0] as Control).queue_free()
	task_rows[pid] = []
	var box: VBoxContainer = cards[pid][3]
	for o in objs:
		# a row can be picked (key or click): then it is framed and the way is shown in the world
		var k: int = task_rows[pid].size()
		var rowp := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		rowp.add_theme_stylebox_override("panel", sb)
		rowp.mouse_filter = Control.MOUSE_FILTER_STOP
		rowp.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				main.pick(pid, k))
		box.add_child(rowp)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rowp.add_child(row)
		var tick := Tick.new()
		tick.col = Color(KEYS.TAG_COLORS[pid])
		tick.custom_minimum_size = Vector2(16, 16)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tick)
		var l := UI.label(String(o[0]), 16, UI.WHITE)
		row.add_child(l)
		task_rows[pid].append([rowp, tick, l, sb, false])


## Day: every task has a state per player. Night: one shared list, shown on both sides.
func _update_tasks() -> void:
	var objs: Array = main.objectives()
	for pid in 2:
		if task_rows[pid].size() != objs.size():
			_build_tasks(pid, objs)
		var n_done := 0
		for k in objs.size():
			var o: Array = objs[k]
			var r: Array = task_rows[pid][k]
			var per_player: bool = o[2] is Array
			var on: bool = o[2][pid] if per_player else o[1]
			var active: bool = true if per_player else o[2]
			if on:
				n_done += 1
			(r[2] as Label).label_settings.font_color = UI.GREEN if on else (UI.WHITE if active else Color(1, 1, 1, 0.35))
			var sel: bool = main.picked[pid] == k
			if sel != r[4]:
				r[4] = sel
				var pc := Color(KEYS.TAG_COLORS[pid])
				(r[3] as StyleBoxFlat).bg_color = Color(pc, 0.3) if sel else Color(0, 0, 0, 0)
				(r[3] as StyleBoxFlat).border_color = pc if sel else Color(0, 0, 0, 0)
				if sel:
					UI.pop_in(r[0], 0.0, 0.85)
			var tick: Tick = r[1]
			if on == tick.on:
				continue
			tick.on = on
			tick.queue_redraw()
			if on:
				tick.pivot_offset = tick.size / 2.0
				tick.scale = Vector2(2.2, 2.2)
				tick.create_tween().tween_property(tick, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		(cards[pid][2] as Label).text = "%d/%d" % [n_done, objs.size()]
		(cards[pid][1] as Label).text = main.world.zone_at(main.players[pid].global_position)


# ------------------------------------------------------------------ per frame
func refresh(delta: float) -> void:
	_update_tasks()
	if main.night:
		var m: float = main.max_meter()
		meter_fill.size = Vector2(BAR_W * m, 12)
		var c := UI.GREEN
		var txt := "UNENTDECKT"
		if m >= 0.6:
			c = UI.RED
			txt = "ENTDECKT!"
		elif m > 0.05:
			c = UI.YELLOW
			txt = "VERDÄCHTIG"
		meter_l.text = txt
		meter_l.label_settings.font_color = c
		meter_fill.color = c
		status_l.text = ""
		var cd: float = main.cooldown
		var total: float = main.ability["cooldown"]
		ab_fill.size = Vector2(210.0 * (1.0 - cd / total), 12)
	else:
		var left: float = main.time_left()
		var frac: float = left / main.day_total()
		meter_l.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
		var c2 := UI.GREEN if frac > 0.4 else (UI.YELLOW if frac > 0.15 else UI.RED)
		meter_l.label_settings.font_color = c2
		meter_fill.color = c2
		meter_fill.size = Vector2(BAR_W * frac, 12)
		status_l.text = "Fehler bisher: %d" % main.mistakes_total
		var sec := int(left)
		if main.state == "play" and sec != last_sec:
			last_sec = sec
			if sec <= 30:
				timer_card.pivot_offset = timer_card.size / 2.0
				timer_card.scale = Vector2(1.08, 1.08)
				timer_card.create_tween().tween_property(timer_card, "scale", Vector2.ONE, 0.25)
			if sec <= 10 and sec > 0:
				UI.sfx("tick")

	for i in prompts.size():
		var pp: PanelContainer = prompts[i][0]
		var pl_l: Label = prompts[i][1]
		var who = main.players[i]
		var vis := false
		if main.state == "play" and not main.busy(i):
			if who.hidden_mode:
				vis = true
				pl_l.text = "Versteck verlassen"
			elif main.nears[i] != null:
				vis = true
				pl_l.text = main.nears[i]["label"]
		pp.visible = vis
		if vis and not prompts[i][2]:
			UI.pop_in(pp, 0.0, 0.7)
		prompts[i][2] = vis

	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			toast_tw = toast_p.create_tween()
			toast_tw.tween_property(toast_p, "modulate:a", 0.0, 0.25)
			toast_tw.tween_callback(func():
				if toast_t <= 0.0:
					toast_p.visible = false)
	blackout.visible = main.blackout_t > 0.0
	arrows.queue_redraw()


func _draw_arrows() -> void:
	if main.ping_t <= 0.0:
		return
	var vs: Vector2 = arrows.size
	var font := ThemeDB.fallback_font
	var centre := vs / 2.0
	for p in main.profs:
		var sp: Vector2 = main.world_to_screen(p.global_position)
		var on_screen := Rect2(Vector2(40, 40), vs - Vector2(80, 80)).has_point(sp)
		var label: String = String(p.pname).replace("Prof. Dr. ", "")
		if on_screen:
			arrows.draw_arc(sp + Vector2(0, -26), 28.0, 0.0, TAU, 32, UI.BLUE, 2.0)
			arrows.draw_string(font, sp + Vector2(-40, -62), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.WHITE)
			continue
		var dirv := (sp - centre).normalized()
		var edge := centre + dirv * minf(absf((vs.x / 2.0 - 46) / dirv.x) if absf(dirv.x) > 0.001 else 1e9,
			absf((vs.y / 2.0 - 46) / dirv.y) if absf(dirv.y) > 0.001 else 1e9)
		var pv := Vector2(-dirv.y, dirv.x)
		arrows.draw_colored_polygon(PackedVector2Array([edge + dirv * 16, edge - dirv * 8 + pv * 11, edge - dirv * 8 - pv * 11]), UI.BLUE)
		arrows.draw_string(font, edge - dirv * 30 + Vector2(-36, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.WHITE)
