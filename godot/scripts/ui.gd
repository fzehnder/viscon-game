extends RefCounted
## Shared playful UI kit: colours, chunky panels, 3D buttons, outlined labels, pop-in, shake, confetti.

const NAVY := Color("23264a")
const NAVY2 := Color("30356a")
const DARK := Color("15162b")
const CREAM := Color("fff8e7")
const WHITE := Color("ffffff")
const MUTED := Color("b9bde6")
const YELLOW := Color("ffc93c")
const PINK := Color("ff5d8f")
const GREEN := Color("3ddc97")
const BLUE := Color("4d8dff")
const PURPLE := Color("9b6bff")
const ORANGE := Color("ff8c42")
const RED := Color("ff4d5e")
const ETH_BLUE := Color("215caf")
const PARTY := ["ffc93c", "ff5d8f", "3ddc97", "4d8dff", "9b6bff", "ff8c42", "ffffff"]


static func sfx(sound: String, volume_db: float = -6.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var n = tree.root.get_node_or_null("Sfx")
	if n:
		n.play(sound, volume_db)


static func box(bg: Color, border: Color, radius: int = 18, bw: int = 4, pad: float = 14.0, shadow: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad + 4.0
	sb.content_margin_right = pad + 4.0
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad + 2.0
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(0, 7)
	return sb


static func panel(bg: Color = NAVY, border: Color = YELLOW, radius: int = 18, pad: float = 14.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, radius, 4, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String, size: int, color: Color = WHITE, outline: int = 0, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = DARK
		ls.shadow_size = 1
		ls.shadow_color = Color(0, 0, 0, 0.45)
		ls.shadow_offset = Vector2(0, 3)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _btn_box(c: Color, bottom: int, top_pad: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = c.darkened(0.35)
	sb.set_border_width_all(3)
	sb.border_width_bottom = bottom
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = top_pad
	sb.content_margin_bottom = 10
	return sb


## Chunky 3D button: pops on hover, presses down on click, clicks audibly.
static func button(text: String, c: Color = BLUE, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _btn_box(c, 8, 10))
	b.add_theme_stylebox_override("hover", _btn_box(c.lightened(0.12), 8, 10))
	b.add_theme_stylebox_override("pressed", _btn_box(c.darkened(0.05), 3, 15))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, WHITE)
	b.add_theme_color_override("font_outline_color", c.darkened(0.5))
	b.add_theme_constant_override("outline_size", 5)
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.06, 1.06), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.12))
	b.button_down.connect(func(): sfx("click"))
	return b


## Gentle endless "breathing" pulse, for the main call-to-action.
static func pulse(c: Control, amount: float = 0.05, period: float = 0.9) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size / 2.0)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(1.0 + amount, 1.0 + amount), period / 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, period / 2.0).set_trans(Tween.TRANS_SINE)


## Bouncy entrance: grows from small with an overshoot and fades in.
static func pop_in(c: Control, delay: float = 0.0, from: float = 0.55) -> void:
	c.pivot_offset = c.size / 2.0
	if c.size == Vector2.ZERO:
		c.resized.connect(func(): c.pivot_offset = c.size / 2.0, CONNECT_ONE_SHOT)
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.42).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.16).set_delay(delay)


## Little horizontal shake for "wrong".
static func shake(c: Control, strength: float = 9.0) -> void:
	var base := c.position
	var tw := c.create_tween()
	for i in 5:
		var s := strength * (1.0 - i / 5.0) * (1.0 if i % 2 == 0 else -1.0)
		tw.tween_property(c, "position", base + Vector2(s, 0), 0.04)
	tw.tween_property(c, "position", base, 0.04)


static func _confetti_tex() -> ImageTexture:
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


## One-shot confetti burst. `parent` can be any CanvasItem (UI or world). Frees itself.
## `power` scales speed, gravity and size (use about 0.3 inside the zoomed game world).
static func confetti(parent: Node, at: Vector2, amount: int = 90, up: bool = true, spread: float = 75.0, power: float = 1.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _confetti_tex()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 1.6
	p.position = at
	p.direction = Vector2.UP if up else Vector2.DOWN
	p.spread = spread
	p.initial_velocity_min = 320.0 * power
	p.initial_velocity_max = 720.0 * power
	p.gravity = Vector2(0, 980 * power)
	p.damping_min = 40.0 * power
	p.damping_max = 90.0 * power
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.8 * maxf(power, 0.35)
	p.scale_amount_max = 1.6 * maxf(power, 0.35)
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in PARTY.size():
		offs.append(float(i) / PARTY.size())
		cols.append(Color(PARTY[i]))
	g.offsets = offs
	g.colors = cols
	p.color_initial_ramp = g
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)
	return p


## Draws a 5-point star (for HUD and celebrations).
static func star_points(c: Vector2, r_out: float, r_in: float, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot - PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
