extends Node2D
## World-space overlays: sound rings, interaction highlights, goal markers, the dashed way to a
## picked task, P1/P2 tags, stamina, thrown wrench.

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


## Point and direction at distance `d` along a line of points.
func _along(points: Array, d: float) -> Array:
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var seg := a.distance_to(b)
		if d <= seg and seg > 0.01:
			return [a.lerp(b, d / seg), (b - a) / seg]
		d -= seg
	var last: Vector2 = points[points.size() - 1]
	var before: Vector2 = points[points.size() - 2]
	return [last, (last - before).normalized()]


## Dashes that run towards the goal, small arrows along the way and a big one at the end.
func _draw_route(points: Array, col: Color, pid: int) -> void:
	var total := 0.0
	for i in range(1, points.size()):
		total += (points[i - 1] as Vector2).distance_to(points[i])
	if total < 8.0:
		return
	var dark := Color(0.08, 0.09, 0.17, 0.55)
	var period := 15.0
	var dash := 8.0
	var d := fmod(t * 26.0, period) - period
	while d < total - 6.0:
		var d0 := maxf(d, 0.0)
		var d1 := minf(d + dash, total - 6.0)
		if d1 - d0 > 1.0:
			var p0: Vector2 = _along(points, d0)[0]
			var p1: Vector2 = _along(points, d1)[0]
			draw_line(p0, p1, dark, 4.2)
			draw_line(p0, p1, col, 2.4)
		d += period
	# small arrows, a little out of step for the two players so that they do not hide each other
	var step := 60.0
	var da := fmod(t * 26.0 + pid * 30.0, step) + 14.0
	while da < total - 16.0:
		var pa: Array = _along(points, da)
		_arrow(pa[0], pa[1], 5.5, col, dark)
		da += step
	var end: Array = _along(points, total)
	_arrow(end[0], end[1], 9.0 + sin(t * 6.0) * 1.2, col, dark)
	draw_arc(end[0], 11.0 + sin(t * 6.0) * 2.0, 0.0, TAU, 24, Color(col, 0.7), 1.6)


func _arrow(tip: Vector2, dirv: Vector2, size: float, col: Color, dark: Color) -> void:
	var side := Vector2(-dirv.y, dirv.x)
	var pts := PackedVector2Array([tip + dirv * size * 0.6, tip - dirv * size + side * size * 0.8, tip - dirv * size - side * size * 0.8])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), dark, 1.0)


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
	# goal markers: a bobbing diamond in the colour of whoever still needs it (yellow = both)
	var bob := sin(t * 3.0) * 4.0
	for goal in main.goal_positions():
		var gp: Vector2
		var gc := Color(0.95, 0.76, 0.3)
		if goal is Array:
			gp = goal[0]
			gc = goal[1]
		else:
			gp = goal
		var g: Vector2 = gp + Vector2(0, -26 + bob)
		var sc := 1.0 + 0.12 * sin(t * 6.0)
		var dia := PackedVector2Array([g + Vector2(0, -11) * sc, g + Vector2(9, 0) * sc, g + Vector2(0, 11) * sc, g + Vector2(-9, 0) * sc])
		draw_colored_polygon(dia, Color(gc, 0.95))
		draw_polyline(dia + PackedVector2Array([dia[0]]), Color(0.08, 0.09, 0.17), 1.5)
		draw_circle(g, 2.6, Color(0.08, 0.09, 0.17))
	# dashed way to the task a player has picked, in that player's colour
	for i in main.players.size():
		var route: Array = main.routes[i]
		if route.size() >= 2:
			_draw_route(route, Color(KEYS.TAG_COLORS[i]), i)
	# name tag and stamina bar above each player
	var font := ThemeDB.fallback_font
	for i in main.players.size():
		var pl = main.players[i]
		if pl.hidden_mode:
			continue
		var top: Vector2 = pl.global_position + Vector2(0, -60)
		var tc := Color(KEYS.TAG_COLORS[i])
		var tag: String = Game.name_of(i)
		var sz := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_rect(Rect2(top + Vector2(-sz.x / 2.0 - 4, -11), Vector2(sz.x + 8, 14)), Color(0.08, 0.09, 0.17, 0.75))
		draw_string(font, top + Vector2(-sz.x / 2.0, 0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tc)
		var f: float = pl.stamina_frac()
		if f < 0.999:
			var bar := Rect2(top + Vector2(-14, 6), Vector2(28, 3))
			draw_rect(bar, Color(0, 0, 0, 0.55))
			draw_rect(Rect2(bar.position, Vector2(28 * f, 3)), Color("ff5a4e") if pl.exhausted else tc)
