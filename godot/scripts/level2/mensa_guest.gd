extends CharacterBody2D
## Level 2: somebody in the Mensa. Stands in the queue, carries a tray to a seat, eats and leaves.
## The node only walks and draws itself; level.gd decides what it does next.
## Also used for the staff behind the counter (mode "still").

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")

var main
var look: Dictionary = {}
var mode := "queue"      # queue, walk, sit, still
# queue (set and moved by level.gd)
var qs := 0.0            # distance to the head of the queue, in tiles along the queue path
var q_state := "wait"    # wait, react (has not noticed the gap in front yet), move, served
var q_timer := 0.0
var q_total := 1.0       # full length of the running reaction time, for the arc in the bubble
var alert_t := 0.0       # heard something: watches the line and closes gaps at once
var slow := 1.0          # reaction time factor (headphones = slower)
# opp: somebody a player pushed in front of (level.gd decides, the Game autoload remembers)
var opp_id := ""
var pname := ""
var grudge_t := -1.0     # > 0: realises in this many seconds that somebody jumped the queue
var grudge_by := -1
var angry_t := 0.0
# walking
var path: Array = []
var speed := 64.0
var arrived: Callable = Callable()
# sitting
var seat := -1
var eat_t := 0.0
# drawing
var facing := 0
var phase := 0.0
var moving := false
var t := 0.0


func _ready() -> void:
	collision_layer = 0   # 32 while in the queue: then the players cannot walk through
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 9.0
	cs.shape = sh
	add_child(cs)
	t = randf() * 10.0


func face(v: Vector2) -> void:
	if v.length_squared() > 0.0001:
		facing = ART.facing_from_angle(v.angle())


## Walk along `p` (points in px), then call `then`.
func walk(p: Array, then: Callable = Callable()) -> void:
	path = p
	arrived = then
	mode = "walk"


func _physics_process(delta: float) -> void:
	t += delta
	alert_t = maxf(0.0, alert_t - delta)
	angry_t = maxf(0.0, angry_t - delta)
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
	if moving:
		phase += delta * 9.0
	queue_redraw()


func _bubble(col: Color, frac: float, top: float = -58.0) -> Vector2:
	var c := Vector2(0, top + sin(t * 14.0) * 1.5)
	draw_circle(c, 10.0, Color(0.08, 0.09, 0.17, 0.92))
	if frac >= 1.0:
		draw_arc(c, 10.0, 0.0, TAU, 24, col, 2.0)
	elif frac > 0.0:
		draw_arc(c, 10.5, -PI / 2.0, -PI / 2.0 + TAU * frac, 24, col, 2.5)
	return c


func _draw() -> void:
	ART.draw_character(self, look, facing, phase, moving)
	var font := ThemeDB.fallback_font
	var top := -58.0
	if opp_id != "":
		# an Opp: red name tag, like in opp.gd
		var w := font.get_string_size(pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_rect(Rect2(-w / 2.0 - 4.0, -71.0, w + 8.0, 14.0), Color(0.08, 0.09, 0.17, 0.75))
		draw_string(font, Vector2(-w / 2.0, -60.0), pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.RED)
		top = -84.0
	if angry_t > 0.0:
		var ca := _bubble(UI.RED, 1.0, top)
		draw_string(font, ca + Vector2(-3.5, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.RED)
		return
	if mode != "queue":
		return
	if alert_t > 0.0:
		# same "!" as the Erstis in level 1: this one is paying attention
		var c := _bubble(UI.YELLOW, 1.0, top)
		draw_string(font, c + Vector2(-3.5, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.YELLOW)
	elif q_state == "react":
		# distracted: the ring runs down until this one notices that the line has moved
		var c2 := _bubble(UI.GREEN, clampf(q_timer / maxf(0.01, q_total), 0.0, 1.0), top)
		for i in 3:
			draw_circle(c2 + Vector2(-4.5 + i * 4.5, 0.5), 1.5, UI.GREEN)
