extends Node2D
## World-space overlays: sound rings, interaction highlights, goal markers, the way to a
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


## The way to a picked task: a soft band along it and chevrons that flow towards the goal.
## `points` are about 8 px apart and already smooth (world.smooth_path). Everything is measured
## back from the goal, so the pattern stays where it is on the ground while the player walks and
## the way gets shorter at the feet.
func _draw_route(points: Array, col: Color, pid: int, fade: float) -> void:
	var n := points.size()
	var acc := PackedFloat32Array()
	acc.resize(n)
	acc[0] = 0.0
	for i in range(1, n):
		acc[i] = acc[i - 1] + (points[i - 1] as Vector2).distance_to(points[i])
	var total := acc[n - 1]
	if total < 12.0:
		return
	var dark := Color(0.08, 0.09, 0.17)
	# the two players' ways lie next to each other where they share a corridor
	var shift := (pid * 2 - 1) * 2.5
	var line := PackedVector2Array()
	for i in n:
		var dirv: Vector2 = ((points[mini(i + 1, n - 1)] as Vector2) - (points[maxi(i - 1, 0)] as Vector2)).normalized()
		line.append((points[i] as Vector2) + Vector2(-dirv.y, dirv.x) * shift)
	draw_polyline(line, Color(dark, 0.28 * fade), 7.0, true)
	draw_polyline(line, Color(col, 0.30 * fade), 3.6, true)
	# chevrons: one every GAP px, moving towards the goal; one walk along the line places them all
	const GAP := 24.0
	const NEAR := 1300.0            # further away from the player than this only the band is drawn
	var g := total - GAP + fmod(t * 38.0, GAP)  # distance from the start of the chevron closest to the goal; it grows, so they run to the goal
	var i2 := n - 1
	while g > 0.0:
		while i2 > 0 and acc[i2 - 1] > g:
			i2 -= 1
		if i2 <= 0:
			break
		if g < NEAR and total - g > 9.0:
			var seg := acc[i2] - acc[i2 - 1]
			var u2 := (g - acc[i2 - 1]) / maxf(seg, 0.001)
			var p: Vector2 = line[i2 - 1].lerp(line[i2], u2)
			var tangent: Vector2 = (line[mini(i2 + 1, n - 1)] - line[maxi(i2 - 2, 0)]).normalized()
			# soft at both ends: at the feet, at the goal, and where it runs out in the distance
			var a := fade * clampf(g / 30.0, 0.0, 1.0) * clampf((total - g) / 22.0, 0.0, 1.0) * clampf((NEAR - g) / 200.0, 0.0, 1.0)
			var glow := 0.84 + 0.16 * sin(g * 0.045 - t * 5.0)     # a wave of light running to the goal
			_chevron(p, tangent, 5.6, Color(col.lightened(0.3 * glow), a * glow), Color(dark, 0.55 * a * glow))
		g -= GAP
	# the goal: a ring that breathes and an arrow head pointing at it
	var end: Vector2 = line[n - 1]
	var into: Vector2 = (line[n - 1] - line[maxi(n - 3, 0)]).normalized()
	var beat := sin(t * 5.0)
	draw_arc(end, 12.0 + beat * 2.0, 0.0, TAU, 32, Color(col, 0.85 * fade), 2.0, true)
	draw_arc(end, 18.0 + beat * 3.0, 0.0, TAU, 32, Color(col, 0.3 * fade), 1.5, true)
	var tip := end - into * (15.0 + beat * 2.0)
	var side := Vector2(-into.y, into.x)
	var head := PackedVector2Array([tip + into * 9.0, tip - into * 5.0 + side * 7.5, tip - into * 1.5, tip - into * 5.0 - side * 7.5])
	draw_colored_polygon(head, Color(col, fade))
	draw_polyline(head + PackedVector2Array([head[0]]), Color(dark, 0.8 * fade), 1.2, true)


## One ">" of the way: tip at `p`, pointing along `dirv`.
func _chevron(p: Vector2, dirv: Vector2, size: float, col: Color, dark: Color) -> void:
	var side := Vector2(-dirv.y, dirv.x)
	var pts := PackedVector2Array([p - dirv * size * 0.7 + side * size, p + dirv * size * 0.55, p - dirv * size * 0.7 - side * size])
	draw_polyline(pts, dark, 4.6, true)
	draw_polyline(pts, col, 2.6, true)


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
	# the way to the task a player has picked, in that player's colour
	for i in main.players.size():
		var route: Array = main.routes[i]
		if route.size() >= 2:
			_draw_route(route, Color(KEYS.TAG_COLORS[i]), i, clampf(float(main.route_age[i]) / 0.25, 0.0, 1.0))
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
