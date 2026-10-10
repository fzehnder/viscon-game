extends Node2D
## Level 4: somebody in the chemistry lab, either the professor or a student at a bench.
## The node only walks and draws itself; level.gd decides what it does next.
## The professor has a temperature (`heat`): his face turns red with it, and once he is `raging`
## he hops, shakes and steams from the ears. Students can be `scared` (they tremble and sweat)
## and `ducked`. A student who is `cool` wears headphones and notices none of it.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")
const HOT := Color("e5372c")

var main
var look: Dictionary = {}
var is_prof := false
var mode := "still"      # still, walk
var facing := 0
var home_facing := 0     # students look back here after glancing around
var phase := 0.0
var moving := false
var path: Array = []
var speed := 46.0
var arrived: Callable = Callable()
var t := 0.0
var fidget := 0.0
var carry := Color(0, 0, 0, 0)   # alpha > 0: carries a flask with this liquid
# bubble above the head
var bubble := ""
var bubble_t := 0.0
var bubble_col := UI.YELLOW
# students
var scared := 0.0
var ducked := false
var cool := false
# professor
var heat := 0.0
var raging := false
var steam: Array = []    # [position, velocity, age]
var steam_t := 0.0


func _ready() -> void:
	t = randf() * 10.0
	fidget = randf_range(1.0, 4.0)


func face(v: Vector2) -> void:
	if v.length_squared() > 0.0001:
		facing = ART.facing_from_angle(v.angle())


## Walk along `p` (points in px), then call `then`.
func walk(p: Array, then: Callable = Callable()) -> void:
	path = p
	arrived = then
	mode = "walk"


func stop() -> void:
	path = []
	arrived = Callable()
	mode = "still"
	moving = false


func say(what: String, dur: float = 2.0, col: Color = UI.YELLOW) -> void:
	bubble = what
	bubble_t = dur
	bubble_col = col


func _physics_process(delta: float) -> void:
	t += delta
	bubble_t = maxf(0.0, bubble_t - delta)
	_update_steam(delta)
	scale = Vector2(1.0, 1.0)
	if raging:
		var k := sin(t * 11.0) * 0.07 * heat
		scale = Vector2(1.0 - k, 1.0 + k)   # squash and stretch while hopping
	elif ducked and not cool:
		scale = Vector2(1.04, 0.82)
	if main != null and not (main.state in ["play", "cutscene"]):
		moving = false
		queue_redraw()
		return
	if mode == "walk":
		moving = false
		if path.is_empty():
			var then := arrived
			arrived = Callable()
			mode = "still"
			if then.is_valid():
				then.call()
		else:
			var to: Vector2 = (path[0] as Vector2) - global_position
			var step := speed * delta
			if to.length() <= step:
				global_position = path[0]
				path.pop_front()
			else:
				global_position += to.normalized() * step
				face(to)
			moving = true
	elif not is_prof and scared <= 0.0:
		# working at the bench: glance left or right now and then
		fidget -= delta
		if fidget <= 0.0:
			fidget = randf_range(1.2, 4.5)
			facing = home_facing if randf() < 0.65 else [ART.LEFT, ART.RIGHT][randi() % 2]
	if moving:
		phase += delta * 9.0
	queue_redraw()


func _update_steam(delta: float) -> void:
	for s in steam:
		s[0] += (s[1] as Vector2) * delta
		s[2] += delta
	steam = steam.filter(func(s): return s[2] < 0.75)
	if not raging or heat < 0.35:
		return
	steam_t -= delta
	if steam_t <= 0.0:
		steam_t = lerpf(0.16, 0.045, heat)
		for side in [-1.0, 1.0]:
			steam.append([Vector2(side * 8.5, -35.0), Vector2(side * randf_range(18.0, 42.0), -randf_range(10.0, 30.0)), 0.0])


func _bubble_at(c: Vector2) -> void:
	draw_circle(c, 10.0, Color(0.08, 0.09, 0.17, 0.92))
	draw_arc(c, 10.0, 0.0, TAU, 24, bubble_col, 2.0)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, c + Vector2(-w / 2.0, 5.5), bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, bubble_col)


## The comic-book vein that pops up when somebody is really angry.
func _anger_mark(c: Vector2, s: float) -> void:
	for q in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		draw_polyline(PackedVector2Array([c + Vector2(q.x * 1.2, q.y * 4.2) * s, c + Vector2(q.x * 1.2, q.y * 1.2) * s,
			c + Vector2(q.x * 4.2, q.y * 1.2) * s]), Color("ff2a2a"), 1.6)


func _draw() -> void:
	var o := Vector2.ZERO
	if raging:
		o = Vector2(sin(t * 47.0) * 1.6 * heat, -absf(sin(t * 11.0)) * 9.0 * heat)
	elif scared > 0.0 and not cool:
		o = Vector2(sin(t * 38.0 + position.x) * 1.1 * scared, 0.0)
	var lk := look
	if heat > 0.01:
		lk = look.duplicate()
		lk["skin"] = ART.col(look, "skin").lerp(HOT, clampf(heat, 0.0, 1.0))
		lk["hair"] = ART.col(look, "hair").lerp(Color("ff6a3d"), heat * heat * 0.75)
	ART.draw_character(self, lk, facing, phase, moving, o)
	var hy := -35.0
	if carry.a > 0.0 and facing != ART.BACK:
		var hx := -8.0 if facing == ART.LEFT else 8.0
		var fc := o + Vector2(hx, -15.0)
		draw_colored_polygon(PackedVector2Array([fc + Vector2(-1, -6), fc + Vector2(1, -6), fc + Vector2(1, -3), fc + Vector2(3.5, 2),
			fc + Vector2(-3.5, 2), fc + Vector2(-1, -3)]), Color(0.82, 0.93, 1.0, 0.75))
		draw_colored_polygon(PackedVector2Array([fc + Vector2(-2.2, -0.5), fc + Vector2(2.2, -0.5), fc + Vector2(3.5, 2), fc + Vector2(-3.5, 2)]), carry)
	if is_prof and heat > 0.25 and facing == ART.FRONT:
		# angry eyebrows and a shouting mouth
		var k := clampf((heat - 0.25) / 0.75, 0.0, 1.0)
		var brow := Color("2b2018")
		draw_line(o + Vector2(-5.0, hy - 3.2 - k * 1.6), o + Vector2(-1.2, hy - 2.2), brow, 1.0)
		draw_line(o + Vector2(5.0, hy - 3.2 - k * 1.6), o + Vector2(1.2, hy - 2.2), brow, 1.0)
		if raging:
			var open := 0.8 + absf(sin(t * 15.0)) * 1.4
			draw_set_transform(o + Vector2(0, hy + 3.8), 0.0, Vector2(1.0, open / 2.2))
			draw_circle(Vector2.ZERO, 2.2, Color("3a1410"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for s in steam:
		var a: float = float(s[2]) / 0.75
		draw_circle(o + (s[0] as Vector2), 2.0 + a * 4.5, Color(1, 1, 1, 0.75 * (1.0 - a)))
	if raging:
		_anger_mark(o + Vector2(9.5, hy - 9.0), 0.9 + 0.2 * sin(t * 9.0))
	if cool:
		# music from the headphones: two little notes drifting up
		for i in 2:
			var u := fmod(t * 0.5 + i * 0.5, 1.0)
			var np := Vector2(10.0 + i * 5.0 + sin(u * 6.0) * 2.0, hy - 6.0 - u * 14.0)
			var nc := Color(UI.PURPLE, 1.0 - u)
			draw_circle(np, 1.6, nc)
			draw_line(np + Vector2(1.4, 0), np + Vector2(1.4, -5.0), nc, 1.0)
	elif scared > 0.0:
		# sweat drops
		for i in 2:
			var u2 := fmod(t * 1.3 + i * 0.5, 1.0)
			var sp := o + Vector2(-10.0 + i * 20.0, hy - 4.0 + u2 * 9.0)
			draw_circle(sp, 1.5, Color(0.55, 0.8, 1.0, 1.0 - u2))
	if bubble_t > 0.0 and bubble != "":
		_bubble_at(o + Vector2(0, -58.0 + sin(t * 14.0) * 1.5))
