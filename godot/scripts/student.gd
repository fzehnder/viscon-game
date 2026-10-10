extends CharacterBody2D
## Daytime crowd: students who wander between spots on campus.
## Erstis start gathered in a crowd facing the main building, then spread out.
## Some carry an Ersti bag. Noise makes them turn around and hold on to it for a moment.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")

var look: Dictionary = {}
var zone: Array = []
var world
var main
var path: Array = []
var wait := 0.0
var speed := 50.0
var dir := PI / 2.0
var facing := 0
var phase := 0.0
var moving := false
var stuck := 0.0
var last := Vector2.ZERO
# Ersti-Tag
var has_bag := false
var gathering := false
var face_point := Vector2.ZERO
var alert_t := 0.0
var frozen := false
var t := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 7.0
	cs.shape = sh
	add_child(cs)
	if wait <= 0.0:
		wait = randf_range(0.0, 3.0)
	speed = randf_range(38.0, 62.0)
	if gathering:
		_face(face_point)


func _face(p: Vector2) -> void:
	dir = (p - global_position).angle()
	facing = ART.facing_from_angle(dir)


func set_bag(on: bool) -> void:
	has_bag = on
	var acc: Array = look.get("acc", [])
	acc.erase("erstibag")
	if on:
		acc.append("erstibag")
	look["acc"] = acc
	queue_redraw()


## Something loud happened nearby: turn towards it and clutch the bag for a while.
func alert(at: Vector2, dur: float = 3.0) -> void:
	alert_t = maxf(alert_t, dur)
	_face(at)
	wait = maxf(wait, 0.8)


func _pick() -> void:
	for i in 12:
		var p := Vector2(randf_range(zone[0], zone[2] + 1), randf_range(zone[1], zone[3] + 1)) * TS
		var pth: Array = world.find_path(global_position, p)
		if not pth.is_empty():
			path = pth
			return
	wait = 2.0


func _physics_process(delta: float) -> void:
	t += delta
	moving = false
	if main != null and main.state != "play":
		queue_redraw()
		return
	alert_t = maxf(0.0, alert_t - delta)
	if frozen:
		queue_redraw()
		return
	if gathering:
		if main == null or main.time_played >= main.gather_time:
			gathering = false
			wait = randf_range(0.0, 2.5)
		queue_redraw()
		return
	if wait > 0.0:
		wait -= delta
	elif path.is_empty():
		_pick()
	else:
		var to: Vector2 = (path[0] as Vector2) - global_position
		if to.length() < 5.0:
			path.pop_front()
			if path.is_empty():
				wait = randf_range(1.0, 5.0)
		else:
			velocity = to.normalized() * speed
			move_and_slide()
			moving = true
			dir = to.angle()
			facing = ART.facing_from_angle(dir)
			phase += delta * 9.0
			if global_position.distance_to(last) < speed * delta * 0.2:
				stuck += delta
				if stuck > 1.0:
					stuck = 0.0
					path.clear()
			else:
				stuck = 0.0
			last = global_position
	queue_redraw()


func _draw() -> void:
	ART.draw_character(self, look, facing, phase, moving)
	if alert_t > 0.0 and has_bag:
		var c := Vector2(0, -58 + sin(t * 14.0) * 1.5)
		draw_circle(c, 10.0, Color(0.08, 0.09, 0.17, 0.92))
		draw_arc(c, 10.0, 0.0, TAU, 24, Color("ffc93c"), 2.0)
		var font := ThemeDB.fallback_font
		draw_string(font, c + Vector2(-3.5, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("ffc93c"))
