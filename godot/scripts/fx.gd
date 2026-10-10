extends Node2D
## World-space overlays: sound rings, interaction highlights, goal markers, P1/P2 tags, stamina, thrown wrench.

const TS := 32.0
const KEYS = preload("res://scripts/controls.gd")
var main
var t := 0.0
var throw_from := Vector2.ZERO
var throw_to := Vector2.ZERO
var throw_t := -1.0
var rings: Array = []   # [pos, radius, age, duration, colour]


func _ready() -> void:
	z_index = 5


func throw(from: Vector2, to: Vector2) -> void:
	throw_from = from
	throw_to = to
	throw_t = 0.0


## A sound ring that grows from `at` to `radius` px. Footsteps, mistakes, thrown objects.
func sound(at: Vector2, radius: float, col: Color = Color(1, 1, 1, 0.45), dur: float = 0.7) -> void:
	if radius <= 0.0:
		return
	rings.append([at, radius, 0.0, dur, col])


## Old single-call ring used by the wrench (kept for the night ability).
func ring(at: Vector2) -> void:
	sound(at, 7.0 * TS, Color(1.0, 0.85, 0.4, 0.6), 1.2)


func _process(delta: float) -> void:
	t += delta
	if throw_t >= 0.0:
		throw_t += delta
		if throw_t > 0.45:
			throw_t = -1.0
	for r in rings:
		r[2] += delta
	rings = rings.filter(func(r): return r[2] < r[3])
	queue_redraw()


func _draw() -> void:
	if main.state != "play":
		return
	for r in rings:
		var k: float = r[2] / r[3]
		var c: Color = r[4]
		draw_arc(r[0], r[1] * k, 0.0, TAU, 48, Color(c, c.a * (1.0 - k)), 2.0)
	if throw_t >= 0.0:
		var u := throw_t / 0.45
		var p := throw_from.lerp(throw_to, u) + Vector2(0, -sin(u * PI) * 40.0)
		draw_set_transform(p, t * 18.0, Vector2.ONE)
		draw_rect(Rect2(-7, -1.5, 14, 3), Color(0.75, 0.78, 0.82))
		draw_circle(Vector2(7, 0), 3.0, Color(0.75, 0.78, 0.82))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# interaction highlight, one per player, in that player's colour
	for i in main.players.size():
		var n = main.nears[i]
		if n == null or main.busy(i):
			continue
		var rr: Rect2 = n["rect"]
		var pr := Rect2(rr.position * TS - Vector2(4, 4), rr.size * TS + Vector2(8, 8))
		var a := 0.55 + 0.45 * (sin(t * 6.0) * 0.5 + 0.5)
		draw_rect(pr, Color(Color(KEYS.TAG_COLORS[i]), a), false, 2.0)
	var bob := sin(t * 3.0) * 4.0
	for goal in main.goal_positions():
		var g: Vector2 = goal + Vector2(0, -26 + bob)
		draw_colored_polygon(PackedVector2Array([g + Vector2(0, -10), g + Vector2(8, 0), g + Vector2(0, 10), g + Vector2(-8, 0)]), Color(0.95, 0.76, 0.3, 0.92))
		draw_circle(g, 2.8, Color(0.16, 0.14, 0.06))
	# P1 / P2 tag and stamina bar above each player
	var font := ThemeDB.fallback_font
	for i in main.players.size():
		var pl = main.players[i]
		if pl.hidden_mode:
			continue
		var top: Vector2 = pl.global_position + Vector2(0, -60)
		var tc := Color(KEYS.TAG_COLORS[i])
		var tag: String = KEYS.TAGS[i]
		var sz := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(font, top + Vector2(-sz.x / 2.0, 0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)
		var f: float = pl.stamina_frac()
		if f < 0.999:
			var bar := Rect2(top + Vector2(-14, 4), Vector2(28, 3))
			draw_rect(bar, Color(0, 0, 0, 0.55))
			draw_rect(Rect2(bar.position, Vector2(28 * f, 3)), Color("ff5a4e") if pl.exhausted else tc)
