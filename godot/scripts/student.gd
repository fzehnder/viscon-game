extends CharacterBody2D
## Daytime crowd: students who wander between spots on campus.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")

var look: Dictionary = {}
var zone: Array = []
var world
var path: Array = []
var wait := 0.0
var speed := 50.0
var facing := 0
var phase := 0.0
var moving := false
var stuck := 0.0
var last := Vector2.ZERO


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 7.0
	cs.shape = sh
	add_child(cs)
	wait = randf_range(0.0, 3.0)
	speed = randf_range(38.0, 62.0)


func _pick() -> void:
	for i in 12:
		var p := Vector2(randf_range(zone[0], zone[2] + 1), randf_range(zone[1], zone[3] + 1)) * TS
		var pth: Array = world.find_path(global_position, p)
		if not pth.is_empty():
			path = pth
			return
	wait = 2.0


func _physics_process(delta: float) -> void:
	moving = false
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
			facing = ART.facing_from_angle(to.angle())
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
