extends Node2D
## World-space overlays: footstep noise, interaction highlight, goal markers, thrown wrench.

const TS := 32.0
var main
var t := 0.0
var throw_from := Vector2.ZERO
var throw_to := Vector2.ZERO
var throw_t := -1.0
var rings: Array = []


func _ready() -> void:
	z_index = 5


func throw(from: Vector2, to: Vector2) -> void:
	throw_from = from
	throw_to = to
	throw_t = 0.0


func ring(at: Vector2) -> void:
	rings.append([at, 0.0])


func _process(delta: float) -> void:
	t += delta
	if throw_t >= 0.0:
		throw_t += delta
		if throw_t > 0.45:
			throw_t = -1.0
	for r in rings:
		r[1] += delta
	rings = rings.filter(func(r): return r[1] < 1.2)
	queue_redraw()


func _draw() -> void:
	if main.state != "play" and main.state != "minigame":
		return
	var pl = main.player
	if pl.noise_radius > 0.0:
		var k := fmod(t * 1.6, 1.0)
		draw_arc(pl.global_position, pl.noise_radius * k, 0.0, TAU, 48, Color(1, 1, 1, 0.3 * (1.0 - k)), 2.0)
	for r in rings:
		var k2: float = r[1] / 1.2
		draw_arc(r[0], 7.0 * TS * k2, 0.0, TAU, 64, Color(1.0, 0.85, 0.4, 0.6 * (1.0 - k2)), 3.0)
	if throw_t >= 0.0:
		var u := throw_t / 0.45
		var p := throw_from.lerp(throw_to, u) + Vector2(0, -sin(u * PI) * 40.0)
		draw_set_transform(p, t * 18.0, Vector2.ONE)
		draw_rect(Rect2(-7, -1.5, 14, 3), Color(0.75, 0.78, 0.82))
		draw_circle(Vector2(7, 0), 3.0, Color(0.75, 0.78, 0.82))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var n = main.near
	if n != null and main.state == "play":
		var r: Rect2 = n["rect"]
		var pr := Rect2(r.position * TS - Vector2(4, 4), r.size * TS + Vector2(8, 8))
		var a := 0.55 + 0.45 * (sin(t * 6.0) * 0.5 + 0.5)
		draw_rect(pr, Color(0.95, 0.76, 0.3, a), false, 2.0)
	var bob := sin(t * 3.0) * 4.0
	for goal in main.goal_positions():
		var g: Vector2 = goal + Vector2(0, -26 + bob)
		draw_colored_polygon(PackedVector2Array([g + Vector2(0, -10), g + Vector2(8, 0), g + Vector2(0, 10), g + Vector2(-8, 0)]), Color(0.95, 0.76, 0.3, 0.92))
		draw_circle(g, 2.8, Color(0.16, 0.14, 0.06))
