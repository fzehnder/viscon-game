extends CharacterBody2D
## The student you play. Walking makes noise at night, sneaking (Shift) is silent but slow.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const WALK_SPEED := 135.0
const SNEAK_SPEED := 68.0
const ZOOM_MIN := 1.5
const ZOOM_MAX := 3.6

var look: Dictionary = {}
var dir := PI / 2.0
var facing := 0
var phase := 0.0
var moving := false
var sneaking := false
var hidden_mode := false
var enabled := false
var noise_radius := 0.0
var night := true
var cam: Camera2D
var zoom := 2.5


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 8.0
	cs.shape = sh
	add_child(cs)
	cam = Camera2D.new()
	cam.zoom = Vector2(zoom, zoom)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.offset = Vector2(0, -18)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(112 * TS)
	cam.limit_bottom = int(84 * TS)
	add_child(cam)
	cam.make_current()


func _unhandled_input(event: InputEvent) -> void:
	var dz := 0.0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dz = 0.15
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dz = -0.15
	elif event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_EQUAL, KEY_KP_ADD, KEY_PLUS]:
			dz = 0.2
		elif event.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			dz = -0.2
	if dz != 0.0:
		zoom = clampf(zoom + dz, ZOOM_MIN, ZOOM_MAX)
		cam.zoom = Vector2(zoom, zoom)


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if enabled and not hidden_mode:
		v = Input.get_vector("left", "right", "up", "down")
	sneaking = Input.is_action_pressed("sneak") and night
	velocity = v * (SNEAK_SPEED if sneaking else WALK_SPEED)
	move_and_slide()
	moving = v.length() > 0.1
	if moving:
		dir = v.angle()
		facing = ART.facing_from_angle(dir)
		phase += delta * (7.0 if sneaking else 11.0)
	noise_radius = 3.0 * TS if (night and moving and not sneaking) else 0.0
	queue_redraw()


func _draw() -> void:
	if hidden_mode:
		draw_arc(Vector2(0, -12), 12.0, 0.0, TAU, 24, Color(0.42, 0.61, 0.88, 0.6), 1.5)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color(0.42, 0.61, 0.88, 0.9), 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ART.draw_character(self, look, facing, phase, moving)
