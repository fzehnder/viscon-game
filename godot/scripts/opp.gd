extends CharacterBody2D
## An NPC who can become an "Opp": somebody you have wronged and who is after you from then on,
## also in later levels (the Game autoload remembers who is an Opp, see game_state.gd).
##
## States:  NEUTRAL -> MISSTRAUISCH -> JAGD -> SUCHEN -> ZURUECK -> LAUERN (or NEUTRAL again)
##   NEUTRAL       minds their own business, glances around now and then
##   MISSTRAUISCH  heard something, looks that way for a moment
##   JAGD          runs after a player; touching means caught
##   SUCHEN        lost sight: goes to where the player was last seen and looks around
##   ZURUECK       walks back to their place
##   LAUERN        back at their place, but angry: watches, and the suspicion bar fills when they see you
## Seeing a player does not start the chase at once: the suspicion bar fills while the player is
## visible (faster when close), the chase starts at 100 %. Walls and tall furniture block the view.
## Once an Opp has their bag back it is not worth the effort to them any more: they only trot
## after you, slower than you walk, and give up after a few seconds.
##
## Levels place these NPCs through "npcs" in their definition (see _spawn_npcs in main.gd):
##   {"id": "rucksack_a", "name": "Deniz", "pos": Vector2(tile), "face": angle, "mode": "sitzt",
##    "bag": Vector2(tile), "bag_acc": "erstibag", "bag_name": "Ersti-Bag", "hears": true,
##    "if_opp": "lauert" | "jagd"}
## A "bag" stands next to them and players can steal it: if the owner sees it, they turn into an
## Opp at once, otherwise they notice a little later. "bag_acc" is the accessory the thief then
## wears: "erstibag" (the green Ersti bag, on the back) or "loot" (a backpack in the hand).

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const CH = preload("res://scripts/characters.gd")
const UI = preload("res://scripts/ui.gd")
enum {NEUTRAL, MISSTRAUISCH, JAGD, SUCHEN, ZURUECK, LAUERN}

const WALK_SPEED := 70.0
const CHASE_SPEED := 152.0          # faster than a walking player (135), slower than a sprint (215)
const CATCH_D := 0.75 * TS
const NEAR_D := 1.4 * TS            # while hunting they notice you this close even behind their back
const LOSE_AFTER := 2.5             # seconds without seeing the player until the chase becomes a search
const SEARCH_TIME := 5.0
const MISTRUST_TIME := 3.0
const NOTICE := Vector2(6.0, 9.0)   # seconds until the owner notices a theft that nobody saw
const CALM := 4.0                   # seconds of peace after they got their bag back
const START_DELAY := 0.7            # a moment of shock before the chase, so the player gets a head start
const TIRED_SPEED := 100.0          # with their bag back: slower than a walking player (135)
const TIRED_CHASE := 3.0            # ... and only for this many seconds, then they let it be
const TIRED_CALM := 7.0             # ... and leave you alone for a while afterwards
const QUOTES := ["Dich kenn ich doch!", "Hab ich dich!", "Na warte, dich hab ich nicht vergessen!"]

var main
var world
var opp_id := ""
var pname := "Jemand"
var quote := ""
var look: Dictionary = {}
var home := Vector2.ZERO            # px
var home_dir := PI / 2.0
var seated := false
var hears := false                  # neutral NPCs only react to noise if the level says so
var range_px := 5.5 * TS
var half := deg_to_rad(38.0)
# opp
var angry := false
var foes: Array = []                # player ids this Opp is after (empty = both)
var state := NEUTRAL
var meter := 0.0                    # suspicion 0..1
var target = null
var last_seen := Vector2.ZERO
var lost_t := 0.0
var start_t := 0.0
var chase_t := 0.0                  # how long the running chase has lasted
var timer := 0.0
var calm_t := 0.0
var look_base := 0.0
var noise_at := Vector2.ZERO
var glance_t := 6.0
var glance_hold := 0.0
var glance_to := 0.0
# backpack
var bag_state := "none"             # none, there, stolen, carried (on the way back to its place)
var bag_pos := Vector2.ZERO         # px
var bag_col := Color("b5523a")
var bag_acc := "loot"               # what it looks like on whoever carries it
var bag_name := "Rucksack"
var bag_thief := -1
var notice_t := -1.0
var bag_node: Node2D
# movement and drawing
var path: Array = []
var repath_t := 0.0
var stuck_t := 0.0
var last_pos := Vector2.ZERO
var dir := PI / 2.0
var phase := 0.0
var moving := false
var t := 0.0
var shout_t := 0.0
var track_t := 0.0                  # "jagd" from the start: knows roughly where the players are for this long
var cone: Polygon2D


## The backpack on the floor. Its own node, so that it sorts with the characters.
class Bag:
	extends Node2D
	var col := Color("b5523a")
	var ersti := false

	func _draw() -> void:
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if ersti:
			# the green drawstring bag from the Ersti-Tag, same colours as on a character's back
			var green := Color("2f9e5b")
			var cord := Color("f3efe2")
			draw_rect(Rect2(-7.0, -14.0, 14.0, 12.5), green)
			draw_set_transform(Vector2(0, -1.5), 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, 7.0, green)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_rect(Rect2(-7.0, -14.0, 14.0, 1.8), green.darkened(0.25))
			draw_line(Vector2(-7.0, -13.1), Vector2(7.0, -13.1), cord, 1.1)
			draw_rect(Rect2(-2.8, -9.5, 5.6, 4.4), cord)
			draw_rect(Rect2(-1.7, -8.5, 3.4, 1.0), green)
			return
		draw_rect(Rect2(-6.5, -14.0, 13.0, 14.0), col)
		draw_rect(Rect2(-6.5, -14.0, 13.0, 4.0), col.darkened(0.25))
		draw_rect(Rect2(-4.0, -7.5, 8.0, 5.0), col.lightened(0.25))
		draw_arc(Vector2(0, -14.0), 3.0, PI, TAU, 8, col.darkened(0.4), 1.5)


func setup(d: Dictionary, m) -> void:
	main = m
	world = m.world
	opp_id = String(d.get("id", ""))
	home = (d["pos"] as Vector2) * TS
	home_dir = float(d.get("face", PI / 2.0))
	seated = String(d.get("mode", "steht")) == "sitzt"
	hears = bool(d.get("hears", false))
	range_px = float(d.get("range", 5.5)) * TS
	pname = String(d.get("name", "Jemand"))
	quote = String(d.get("quote", QUOTES[absi(hash(opp_id)) % QUOTES.size()]))
	if d.has("look"):
		look = (d["look"] as Dictionary).duplicate(true)
	else:
		# the same id always looks the same, so that players recognise them
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(opp_id)
		look = CH.random_student(rng)
	if d.has("bag"):
		bag_state = "there"
		bag_pos = (d["bag"] as Vector2) * TS
		bag_col = Color(String(d.get("bag_col", look.get("accent", "b5523a"))))
		bag_acc = String(d.get("bag_acc", "loot"))
		bag_name = String(d.get("bag_name", "Rucksack"))
	if opp_id != "" and Game.is_opp(opp_id):
		# an old acquaintance: starts angry
		var known: Dictionary = Game.opps[opp_id]
		angry = true
		pname = String(known.get("name", pname))
		look = (known.get("look", look) as Dictionary).duplicate(true)
		foes = (known.get("by", []) as Array).duplicate()
		state = LAUERN
		if String(d.get("if_opp", "lauert")) == "jagd":
			state = SUCHEN   # comes looking for the players straight away
			timer = SEARCH_TIME
			track_t = 25.0
	position = home
	dir = home_dir


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 8.0
	cs.shape = sh
	add_child(cs)
	cone = Polygon2D.new()
	cone.z_index = -1
	add_child(cone)
	last_pos = position
	glance_t = randf_range(4.0, 8.0)
	t = randf() * 10.0
	if bag_state == "there":
		bag_node = Bag.new()
		bag_node.col = bag_col
		bag_node.ersti = bag_acc == "erstibag"
		bag_node.position = bag_pos
		main.actors.add_child(bag_node)
	if state == SUCHEN:
		_hunt_nearest()


# ------------------------------------------------------------------ senses
func _foes() -> Array:
	if foes.is_empty():
		return main.players
	var out: Array = []
	for pid in foes:
		out.append(main.players[pid])
	return out


func can_see(pl, hunting: bool = false) -> bool:
	if pl.hidden_mode:
		return false
	var to: Vector2 = pl.global_position - global_position
	var d := to.length()
	if d > range_px * (1.3 if hunting else 1.0):
		return false
	if absf(wrapf(to.angle() - dir, -PI, PI)) > half and not (hunting and d < NEAR_D):
		return false
	return world.sight_clear(global_position, pl.global_position)


func _has_my_bag(pl) -> bool:
	return bag_state == "stolen" and main.players.find(pl) == bag_thief


## Fills the suspicion bar while a player is in view. At 100 % the chase starts.
func _watch(delta: float, gain: float = 1.0) -> void:
	if calm_t > 0.0:
		return
	var hunting := state == SUCHEN
	var best = null
	var best_d := INF
	for pl in _foes():
		var d: float = global_position.distance_to(pl.global_position)
		if d < best_d and can_see(pl, hunting):
			best = pl
			best_d = d
	if best == null:
		meter = maxf(0.0, meter - 0.35 * delta)
		return
	var rate := 0.55 + (1.0 - minf(best_d / range_px, 1.0)) * 1.6
	if _has_my_bag(best):
		rate *= 1.6   # walking around with their backpack is rather obvious
	if best.sneaking:
		rate *= 0.8
	meter = minf(1.0, meter + rate * gain * delta)
	last_seen = best.global_position
	if meter >= 1.0:
		_chase(best)


## Called by main.gd for footsteps (not sneaking) and minigame mistakes.
func hear(at: Vector2, radius: float) -> void:
	if not (hears or angry) or state == JAGD or calm_t > 0.0:
		return
	var r := radius if world.line_clear(global_position, at) else radius * 0.45
	if global_position.distance_to(at) > r:
		return
	noise_at = at
	if angry:
		# an Opp goes and has a look
		last_seen = at
		_search(at)
	else:
		state = MISSTRAUISCH
		timer = MISTRUST_TIME


# ------------------------------------------------------------------ becoming an opp
func become_opp(pid: int, seen: bool, why: String) -> void:
	if pid >= 0 and not foes.has(pid):
		foes.append(pid)
	var was := angry
	angry = true
	shout_t = 1.6
	if opp_id != "":
		Game.add_opp(opp_id, pname, look, foes, why)
	if not was:
		main.on_new_opp(self, seen)


## A player took the backpack. The owner reacts at once if they saw it, otherwise a little later.
func bag_taken(pid: int) -> void:
	bag_state = "stolen"
	bag_thief = pid
	if bag_node:
		bag_node.visible = false
	var pl = main.players[pid]
	if can_see(pl) or state == JAGD or state == SUCHEN:
		become_opp(pid, true, "%s geklaut" % bag_name)
		_chase(pl)
	else:
		notice_t = randf_range(NOTICE.x, NOTICE.y)


func _bag_clock(delta: float) -> void:
	if bag_state != "stolen" or notice_t <= 0.0:
		return
	notice_t -= delta
	var thief = main.players[bag_thief]
	if can_see(thief):
		# turned around and saw somebody walk off with it
		notice_t = -1.0
		become_opp(bag_thief, true, "%s geklaut" % bag_name)
		_chase(thief)
	elif notice_t <= 0.0:
		notice_t = -1.0
		become_opp(bag_thief, false, "%s geklaut" % bag_name)
		# gets up and looks for the thief, a few steps in the direction they went
		var to: Vector2 = thief.global_position - global_position
		last_seen = global_position + to.limit_length(6.0 * TS)
		_search(last_seen)


## Caught the thief: takes the backpack and carries it back to its place.
func take_back() -> void:
	bag_state = "carried"
	bag_thief = -1
	notice_t = -1.0
	ART.set_acc(look, bag_acc, true)
	look["loot_col"] = bag_col.to_html(false)
	meter = 0.0
	calm_t = CALM
	_go_home()


# ------------------------------------------------------------------ state changes
## True once the stolen bag is back with its owner (on the way home or at its place again).
func bag_is_back() -> bool:
	return bag_state == "carried" or bag_state == "there"


func _chase(pl) -> void:
	if state != JAGD:
		start_t = START_DELAY
		chase_t = 0.0
	state = JAGD
	target = pl
	meter = 1.0
	lost_t = 0.0
	repath_t = 0.0
	last_seen = pl.global_position
	if shout_t <= 0.0:
		shout_t = 0.8


func _search(at: Vector2) -> void:
	state = SUCHEN
	target = null
	path = world.find_path(global_position, at)
	timer = SEARCH_TIME
	look_base = dir


func _hunt_nearest() -> void:
	var best = null
	for pl in _foes():
		if best == null or global_position.distance_to(pl.global_position) < global_position.distance_to(best.global_position):
			best = pl
	if best != null:
		last_seen = best.global_position
		path = world.find_path(global_position, last_seen)


func _go_home() -> void:
	state = ZURUECK
	target = null
	path = world.find_path(global_position, home)
	path.append(home)


func _arrive_home() -> void:
	global_position = home
	dir = home_dir
	if bag_state == "carried":
		bag_state = "there"
		ART.set_acc(look, bag_acc, false)
		if bag_node:
			bag_node.visible = true
	state = LAUERN if angry else NEUTRAL


# ------------------------------------------------------------------ loop
func _follow(delta: float, spd: float) -> bool:
	if path.is_empty():
		return true
	var nxt: Vector2 = path[0]
	var to := nxt - global_position
	if to.length() < 6.0:
		path.pop_front()
		return path.is_empty()
	_step(to, spd, delta)
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


func _step(to: Vector2, spd: float, delta: float) -> void:
	velocity = to.normalized() * spd
	move_and_slide()
	moving = true
	dir = lerp_angle(dir, to.angle(), minf(1.0, delta * 9.0))


func _at_home() -> bool:
	return global_position.distance_to(home) < 2.0


func _physics_process(delta: float) -> void:
	t += delta
	moving = false
	if main.state != "play":
		queue_redraw()
		return
	shout_t = maxf(0.0, shout_t - delta)
	calm_t = maxf(0.0, calm_t - delta)
	match state:
		NEUTRAL:
			_bag_clock(delta)
			if state == NEUTRAL:
				_glance(delta)
		MISSTRAUISCH:
			dir = lerp_angle(dir, (noise_at - global_position).angle(), minf(1.0, delta * 7.0))
			_bag_clock(delta)
			if state == MISSTRAUISCH:
				timer -= delta
				if timer <= 0.0:
					state = LAUERN if angry else NEUTRAL
		LAUERN:
			# watches their place: seated people turn around towards their backpack
			var base := home_dir + (PI if seated else 0.0)
			dir = lerp_angle(dir, base + sin(t * 0.8) * 1.2, minf(1.0, delta * 5.0))
			_watch(delta)
		JAGD:
			_hunt(delta)
		SUCHEN:
			if track_t > 0.0:
				track_t -= delta
				repath_t -= delta
				if repath_t <= 0.0:
					repath_t = 1.0
					_hunt_nearest()
			if not path.is_empty():
				_follow(delta, WALK_SPEED * 1.4)
			else:
				timer -= delta
				dir = look_base + sin(timer * 2.2) * 1.3
			_watch(delta, 1.5)
			if state == SUCHEN and path.is_empty() and timer <= 0.0:
				_go_home()
		ZURUECK:
			if _follow(delta, WALK_SPEED):
				_arrive_home()
			elif angry:
				_watch(delta)
	if moving:
		phase += delta * (13.0 if (state == JAGD and not bag_is_back()) else 9.0)
	_update_cone()
	queue_redraw()


func _glance(delta: float) -> void:
	# looks over the shoulder every now and then
	glance_t -= delta
	if glance_t <= 0.0:
		glance_t = randf_range(5.0, 9.0)
		glance_hold = 1.5
		glance_to = home_dir + PI + randf_range(-0.7, 0.7)
	if glance_hold > 0.0:
		glance_hold -= delta
		dir = lerp_angle(dir, glance_to, minf(1.0, delta * 8.0))
	else:
		dir = lerp_angle(dir, home_dir, minf(1.0, delta * 6.0))


func _hunt(delta: float) -> void:
	var pl = target
	if pl == null:
		_search(last_seen)
		return
	var to: Vector2 = pl.global_position - global_position
	var d := to.length()
	if start_t > 0.0:
		# jumps up and stares before running
		start_t -= delta
		if can_see(pl, true):
			dir = lerp_angle(dir, to.angle(), minf(1.0, delta * 12.0))
			last_seen = pl.global_position
		return
	if d < CATCH_D and not pl.hidden_mode:
		main.opp_catch(self, pl)
		return
	# with the bag back they do not put much into it: slower, and not for long
	var tired := bag_is_back()
	var spd := TIRED_SPEED if tired else CHASE_SPEED
	chase_t += delta
	var sees := can_see(pl, true)
	if sees:
		last_seen = pl.global_position
		lost_t = 0.0
	else:
		lost_t += delta
	if tired and (chase_t > TIRED_CHASE or lost_t > 0.6):
		meter = 0.0
		calm_t = TIRED_CALM
		_go_home()
		return
	if lost_t > LOSE_AFTER:
		meter = 0.6
		_search(last_seen)
		return
	if sees and d < 2.5 * TS:
		_step(to, spd, delta)   # close enough: straight at them
		return
	repath_t -= delta
	if repath_t <= 0.0 or path.is_empty():
		repath_t = 0.3
		path = world.find_path(global_position, last_seen)
	_follow(delta, spd)


# ------------------------------------------------------------------ drawing
func _update_cone() -> void:
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 17:
		var a := dir - half + 2.0 * half * i / 16.0
		var end := global_position + Vector2.from_angle(a) * range_px
		pts.append(world.sight_end(global_position, end) - global_position)
	cone.polygon = pts
	if angry:
		cone.color = Color(1.0, 0.93 - meter * 0.6, 0.6 - meter * 0.45, 0.17 + meter * 0.18)
	else:
		cone.color = Color(0.8, 0.88, 1.0, 0.16 if state == MISSTRAUISCH else 0.09)


func _bubble(c: Vector2, mark: String, col: Color) -> void:
	draw_circle(c, 10.0, Color(0.08, 0.09, 0.17, 0.92))
	draw_arc(c, 10.0, 0.0, TAU, 24, col, 2.0)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, c + Vector2(-w / 2.0, 6), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _draw() -> void:
	var facing := ART.facing_from_angle(dir)
	ART.draw_character(self, look, facing, phase, moving)
	if seated and _at_home() and facing == ART.BACK:
		# back of the chair, it hides the legs
		draw_rect(Rect2(-7.0, 0.0, 2.5, 4.0), Color("2b3644"))
		draw_rect(Rect2(4.5, 0.0, 2.5, 4.0), Color("2b3644"))
		draw_rect(Rect2(-8.0, -17.0, 16.0, 17.0), Color("3d4e63"))
		draw_rect(Rect2(-6.0, -15.0, 12.0, 12.0), Color("4f6380"))
	var font := ThemeDB.fallback_font
	var top := -58.0
	if angry:
		# red name tag, like the tags of the players
		var w := font.get_string_size(pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_rect(Rect2(-w / 2.0 - 4.0, -71.0, w + 8.0, 14.0), Color(0.08, 0.09, 0.17, 0.75))
		draw_string(font, Vector2(-w / 2.0, -60.0), pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.RED)
		top = -84.0
	# suspicion bar: fills while they can see you, the chase starts when it is full
	if meter > 0.02 and state != JAGD:
		var bar := Rect2(-15.0, -54.0, 30.0, 4.0)
		draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * meter, bar.size.y)), UI.YELLOW.lerp(UI.RED, meter))
	var c := Vector2(0, top + sin(t * 14.0) * 1.5)
	if state == JAGD or shout_t > 0.0:
		_bubble(c, "!", UI.RED)
	elif state == SUCHEN:
		_bubble(c, "?", UI.RED)
	elif state == MISSTRAUISCH:
		_bubble(c, "?", UI.YELLOW)
