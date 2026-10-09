extends CharacterBody2D
## A professor on a late-night walk: patrols waypoints, looks around, sees with a flashlight cone,
## hears footsteps, investigates, and catches the player when the alarm meter fills.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const CH = preload("res://scripts/characters.gd")

var pname := ""
var quote := ""
var points: Array = []
var wp := 0
var path: Array = []
var world
var main
var dir := 0.0
var phase := 0.0
var speed := 55.0
var range_px := 208.0
var half := deg_to_rad(38.0)
var pause_min := 0.8
var pause_max := 2.2
var state := "patrol"   # patrol, pause, investigate, look
var timer := 0.0
var look_base := 0.0
var meter := 0.0
var sees := false
var moving := false
var stuck_t := 0.0
var last_pos := Vector2.ZERO
var repath_t := 0.0
var flagged := false
var look: Dictionary = {}
var static_mode := false
var cone: Polygon2D


func setup(p: Dictionary, w, m) -> void:
	world = w
	main = m
	pname = p["name"]
	quote = p["quote"]
	for v in p["pts"]:
		points.append((v as Vector2) * TS)
	speed = p.get("speed", 55.0)
	range_px = p.get("range", 6.5) * TS
	pause_min = p.get("pmin", 0.8)
	pause_max = p.get("pmax", 2.2)
	look = CH.PROF_LOOKS.get(pname, CH.PROF_LOOKS["Prof. Dr. Brunner"]).duplicate(true)
	static_mode = p.get("static", false)
	if static_mode:
		look["acc"] = (look["acc"] as Array).filter(func(a): return a != "flashlight")
	position = points[0]
	wp = 1 % points.size()


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 9.0
	cs.shape = sh
	add_child(cs)
	cone = Polygon2D.new()
	cone.z_index = -1
	cone.color = Color(1.0, 0.93, 0.6, 0.2)
	add_child(cone)
	cone.visible = not static_mode
	last_pos = position
	if static_mode:
		dir = PI / 2.0
		return
	if points.size() > 1:
		dir = ((points[wp] as Vector2) - position).angle()
	_repath_wp()


func _repath_wp() -> void:
	path = world.find_path(global_position, points[wp])


func _physics_process(delta: float) -> void:
	if main.state == "caught" or main.state == "won" or static_mode:
		queue_redraw()
		return
	moving = false
	match state:
		"patrol":
			if _follow(delta, speed):
				state = "pause"
				timer = randf_range(pause_min, pause_max)
				look_base = dir
		"pause":
			timer -= delta
			dir = look_base + sin(timer * 1.6) * 0.9
			if timer <= 0.0:
				wp = (wp + 1) % points.size()
				_repath_wp()
				state = "patrol"
		"investigate":
			repath_t -= delta
			if _follow(delta, speed * 1.3):
				state = "look"
				timer = 3.0
				look_base = dir
		"look":
			timer -= delta
			dir = look_base + sin(timer * 2.2) * 1.3
			if timer <= 0.0:
				_repath_wp()
				state = "patrol"
	if moving:
		phase += delta * 8.0
	_update_cone()
	if main.state == "play":
		_detect(delta)
	queue_redraw()


func _follow(delta: float, spd: float) -> bool:
	if path.is_empty():
		return true
	var nxt: Vector2 = path[0]
	var to := nxt - global_position
	if to.length() < 6.0:
		path.pop_front()
		return path.is_empty()
	velocity = to.normalized() * spd
	move_and_slide()
	moving = true
	dir = lerp_angle(dir, to.angle(), minf(1.0, delta * 7.0))
	if global_position.distance_to(last_pos) < spd * delta * 0.25:
		stuck_t += delta
	else:
		stuck_t = 0.0
	last_pos = global_position
	if stuck_t > 0.7:
		stuck_t = 0.0
		var goal: Vector2 = path.back()
		path = world.find_path(global_position, goal)
		if path.is_empty():
			return true
	return false


func hear(at: Vector2) -> void:
	if static_mode or state == "investigate":
		return
	meter = maxf(meter, 0.15)
	_investigate(at)


func _range() -> float:
	return range_px * (0.45 if main.blackout_t > 0.0 else 1.0)


func _investigate(at: Vector2) -> void:
	state = "investigate"
	repath_t = 0.5
	path = world.find_path(global_position, at)


func _detect(delta: float) -> void:
	var pl = main.player
	sees = false
	var d: float = global_position.distance_to(pl.global_position)
	if not pl.hidden_mode:
		if d < 0.75 * TS:
			main.caught(self)
			return
		var to: Vector2 = pl.global_position - global_position
		var ang := absf(wrapf(to.angle() - dir, -PI, PI))
		if (d < _range() and ang < half) or d < 1.5 * TS:
			if world.line_clear(global_position, pl.global_position):
				sees = true
	if sees:
		var rate := 0.7 + (1.0 - minf(d / _range(), 1.0)) * 2.0
		if pl.sneaking:
			rate *= 0.8
		meter = minf(1.0, meter + rate * delta)
		if meter >= 1.0:
			main.caught(self)
			return
		if meter > 0.2 and (state != "investigate" or repath_t <= 0.0):
			_investigate(pl.global_position)
		if meter > 0.5 and not flagged:
			flagged = true
			main.spotted()
	else:
		meter = maxf(0.0, meter - 0.25 * delta)
		if meter < 0.1:
			flagged = false
		if pl.noise_radius > 0.0 and (state == "patrol" or state == "pause"):
			var r: float = pl.noise_radius
			if not world.line_clear(global_position, pl.global_position):
				r *= 0.45
			if d < r:
				meter = maxf(meter, 0.15)
				_investigate(pl.global_position)


func _update_cone() -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var n := 16
	for i in range(n + 1):
		var a := dir - half + (2.0 * half) * float(i) / float(n)
		var end := global_position + Vector2.from_angle(a) * _range()
		pts.append(world.ray_end(global_position, end) - global_position)
	cone.polygon = pts
	var alert := clampf(meter, 0.0, 1.0)
	cone.color = Color(1.0, 0.93 - alert * 0.6, 0.6 - alert * 0.45, 0.17 + alert * 0.18)


func _draw() -> void:
	ART.draw_character(self, look, ART.facing_from_angle(dir), phase, moving)
	if static_mode:
		return
	if meter > 0.05 or state == "investigate" or state == "look":
		var alarm := meter > 0.6
		var col := Color("ff5a4e") if alarm else Color("f2c14e")
		var mark := "!" if alarm else "?"
		var c := Vector2(0, -58)
		draw_circle(c, 10.0, Color(0.06, 0.08, 0.11, 0.9))
		if meter > 0.0:
			draw_arc(c, 11.0, -PI / 2.0, -PI / 2.0 + TAU * meter, 24, col, 2.5)
		var font := ThemeDB.fallback_font
		var sz := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, c + Vector2(-sz.x / 2.0, 6), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
