extends CharacterBody2D
## One of the two students. Each step sends out a sound ring: sneaking is almost silent,
## walking is normal, sprinting is loud. Sprint lasts 2 s, then stamina refills over a few seconds.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const KEYS = preload("res://scripts/controls.gd")
const WALK_SPEED := 135.0
const SNEAK_SPEED := 68.0
const SPRINT_SPEED := 215.0
const STAMINA_MAX := 2.0       # seconds of sprint
const STAMINA_REGEN := 0.7     # per second, empty to full in about 3 s
const STAMINA_RESUME := 0.35   # after running dry, sprint again once this share is back
const NOISE := {"sneak": 0.7, "walk": 3.0, "sprint": 6.0}   # ring radius in tiles
const STEP := {"sneak": 0.55, "walk": 0.36, "sprint": 0.24}  # seconds between footsteps
const ANIM := {"sneak": 7.0, "walk": 11.0, "sprint": 15.0}

var pid := 0
var main
var look: Dictionary = {}
var dir := PI / 2.0
var facing := 0
var phase := 0.0
var moving := false
var sneaking := false
var sprinting := false
var gait := "idle"   # idle, sneak, walk, sprint
var hidden_mode := false
var enabled := false
var noise_radius := 0.0
var night := true
var stamina := STAMINA_MAX
var exhausted := false
var step_t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 8.0
	cs.shape = sh
	add_child(cs)


func _act(what: String) -> String:
	return KEYS.action(pid, what)


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if enabled and not hidden_mode:
		v = Input.get_vector(_act("left"), _act("right"), _act("up"), _act("down"))
	moving = v.length() > 0.1
	sneaking = moving and Input.is_action_pressed(_act("sneak"))
	sprinting = moving and not sneaking and not exhausted and stamina > 0.0 and Input.is_action_pressed(_act("sprint"))
	if sprinting:
		stamina = maxf(0.0, stamina - delta)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
		if exhausted and stamina >= STAMINA_MAX * STAMINA_RESUME:
			exhausted = false

	if not moving:
		gait = "idle"
	elif sneaking:
		gait = "sneak"
	elif sprinting:
		gait = "sprint"
	else:
		gait = "walk"

	var spd := WALK_SPEED
	if gait == "sneak":
		spd = SNEAK_SPEED
	elif gait == "sprint":
		spd = SPRINT_SPEED
	velocity = v * spd
	move_and_slide()

	noise_radius = 0.0
	if moving:
		dir = v.angle()
		facing = ART.facing_from_angle(dir)
		phase += delta * float(ANIM[gait])
		noise_radius = float(NOISE[gait]) * TS
		step_t -= delta
		if step_t <= 0.0:
			step_t = float(STEP[gait])
			if main:
				main.on_step(self, noise_radius)
	else:
		step_t = 0.0
	queue_redraw()


func stamina_frac() -> float:
	return stamina / STAMINA_MAX


func _draw() -> void:
	if hidden_mode:
		draw_arc(Vector2(0, -12), 12.0, 0.0, TAU, 24, Color(0.42, 0.61, 0.88, 0.6), 1.5)
		return
	var ring_col := Color(KEYS.TAG_COLORS[pid])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color(ring_col, 0.9), 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ART.draw_character(self, look, facing, phase, moving)
