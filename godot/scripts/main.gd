extends Node2D
## ETH Zentrum – Tag & Nacht. Story mode for two players on one keyboard.
## The level comes from the Game autoload (levels.gd). Level 1 is the Ersti-Tag (day).
## Later levels bring their own logic node (`logic`, see levels.gd) for tasks of type "level".
## Hooks that this script calls on it, all optional:
##   update_near(pid)             may set nears[pid] = {"use": "level", "label": ..., "rect": ..., ...}
##   interact(pid, o)             the player pressed interact on such an entry
##   goal_positions(id, n0, n1)   markers for a "level" task: [[position px, colour], ...]
##   on_noise(at, radius)         footsteps and minigame mistakes
##   finale(done)                 after the last task, e.g. a cutscene; must call done
##   task_targets(id, pid)        where a "level" task can be done right now (px), for the dashed way
## Camera: one shared view that zooms out (up to OUT_MAX) as the players drift apart. When even
## that is not enough, the screen splits and both views slowly zoom back in.
## The split is a line through the screen centre, always at right angles to the line between the
## players, so each player is on the side where they really are (P2 to the left of P1 = P2 left,
## P2 above = horizontal split with P2 on top) and the line turns as they walk around each other.
## There are always two full-screen views; P2's view lies on top, cut off at the split line
## (SPLIT_SHADER). While both cameras sit on the middle between the players the two pictures are
## identical and the cut is invisible; splitting moves the cameras apart, so nothing ever jumps.
## A minigame for one player turns the split vertical (P1 left, P2 right) and opens on that half.
## The HUD is a separate layer and never moves.

const MapData = preload("res://scripts/map_data.gd")
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ProfScript = preload("res://scripts/professor.gd")
const StudentScript = preload("res://scripts/student.gd")
const OppScript = preload("res://scripts/opp.gd")
const HudScript = preload("res://scripts/hud.gd")
const FxScript = preload("res://scripts/fx.gd")
const MiniScript = preload("res://scripts/minigame.gd")
const CH = preload("res://scripts/characters.gd")
const ART = preload("res://scripts/character_art.gd")
const KEYS = preload("res://scripts/controls.gd")
const LV = preload("res://scripts/levels.gd")
const UI = preload("res://scripts/ui.gd")
const Transcript = preload("res://scripts/transcript.gd")
const TS := 32.0
const START := Vector2(12.5, 43.5)
const STATION := Rect2(0, 41, 10.2, 5)
const HG_ZONES := ["Hauptgebäude (HG)", "Haupthalle", "Rotunde", "ETH-Bibliothek", "Lounge", "Seminarraum", "Labor · Robotik",
	"E Nord", "E Süd", "Hörsaal E1", "Hörsaal E3", "Hörsaal E5", "Hörsaal E7"]
const CAM_OFFSET := Vector2(0, -18)
const ZOOM_MIN := 1.5
const ZOOM_MAX := 3.6
const OUT_MAX := 2.2       # the shared view zooms out up to this factor, then the screen splits
const MERGE_OUT := 1.8     # split views join again once the shared view would need less than this
# In the shared view the players stay within this share of the screen width (FIT_X) and height
# (FIT_Y, less, so nobody ends up behind the timer at the top or the mini map at the bottom).
# In split screen each player sits this far from the centre, about the middle of their half.
const FIT_X := 0.5
const FIT_Y := 0.42
const ZOOM_BACK := 1.5     # seconds (roughly) to zoom back in after a split, or out again after joining
const ZOOM_IN := 1.0       # seconds (roughly) to zoom in when the players come closer in the shared view
const SPLIT_TIME := 0.7    # seconds for the split to turn upright when a minigame opens
const SPLIT_TURN := 10.0   # how quickly the split line follows the players (higher = tighter)
const CAM_FOLLOW := 9.0    # how quickly the cameras follow (higher = tighter)
const SPLIT_SHADER := """
shader_type canvas_item;
uniform vec2 normal = vec2(1.0, 0.0);
uniform vec2 size = vec2(1280.0, 720.0);
void fragment() {
	if (dot(UV * size - size * 0.5, normal) < 0.0) {
		discard;
	}
}
"""
const STEAL_BEHIND := 1.9  # rad: you must be at least this far from where the Ersti is looking

var data: Dictionary
var lv: Dictionary            # definition of the running level (levels.gd)
var logic: Node = null        # per-level logic node, null in level 1
var world: Node2D
var actors: Node2D
var players: Array = []
var player: CharacterBody2D   # = players[0], kept for code that only knows one player
var profs: Array = []
var students: Array = []
var opps: Array = []          # NPCs that can be or become Opps (opp.gd)
var hud: CanvasLayer
var fx: Node2D
var minis: Array = [null, null]       # open minigame per player (same object twice for co-op games)
var nears: Array = [null, null]       # thing each player could interact with
var near = null                       # = nears[0]
var busy_spot: Array = [null, null]   # station object each player is using

var dept := "D-INFK"
var mode := "day"
var night := false
var state := "intro"   # intro, play, cutscene, caught, won, lost
var zone := "Polyterrasse"
var time_played := 0.0
var day_time := 420.0
var gather_time := 7.0
var spotted_count := 0
var mistakes_total := 0
var hint_noise_shown := false

# night progress
var entered_hg := false
var has_prep := false
var lab_open := false
var has_item := false
# day progress: per player, task id -> true
var done: Array = [{}, {}]
# the task each player has picked (index into LV.tasks(), -1 = none) and the dashed way to where
# it can be done: points in px, drawn by fx.gd and on the mini map
var picked: Array = [-1, -1]
var routes: Array = [[], []]       # the way to the picked task per player: points in px, about 8 px apart
var route_t: Array = [0.0, 0.0]
var route_age: Array = [9.0, 9.0]  # seconds since a player's way changed to a different one (it fades in then)
# abilities (night, P1)
var ability: Dictionary
var cooldown := 0.0
var blackout_t := 0.0
var ping_t := 0.0

# split screen
var vcs: Array = []    # SubViewportContainer per view
var vps: Array = []    # SubViewport per view (both share one World2D)
var cams: Array = []
var divider: Control
var split_mat: ShaderMaterial   # cuts P2's view off at the split line
var split := false       # true = two separate views (too far apart, or a minigame for one player)
var split_k := 0.0       # how visible the split is: 0 = one seamless picture, 1 = clearly two views
var split_n := Vector2.RIGHT   # split line normal on screen, from P1's side to P2's side
var force_k := 0.0       # 0..1: a minigame for one player turns the split upright (P1 left, P2 right)
var out := 1.0           # dynamic zoom-out on top of `zoom`: 1 = normal, up to OUT_MAX
var catching_up := false # just joined: zoom out smoothly until both players fit again
var cam_a := Vector2.ZERO   # smoothed camera positions of P1's and P2's view
var cam_b := Vector2.ZERO
var zoom := 2.5 / 1.3    # about 1.92. Change this (also in tweens), both cameras follow; `out` comes on top

# the transcript (level overview) on top of the running game: L or the button, the game pauses
var tr_layer: CanvasLayer = null
var tr_closed_frame := -10


## Layer for the transcript that keeps running while the game is paused; L closes it again
## (Esc and Backspace are handled by transcript.gd itself).
class TranscriptLayer:
	extends CanvasLayer
	var main

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_L:
			get_viewport().set_input_as_handled()
			main.close_transcript()


func _ready() -> void:
	randomize()
	_setup_input()
	KEYS.setup()
	Game.begin_level()
	dept = Game.dept
	mode = Game.mode
	night = mode == "night"
	ability = CH.DEPTS[dept]["ability"]
	data = MapData.new().build(mode, dept)
	lv = LV.level()
	if not night:
		day_time = float(lv["time"])
		gather_time = float(lv.get("gather", 0.0))
	_build_views()
	world = WorldScript.new()
	world.data = data
	world.main = self
	vps[0].add_child(world)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	vps[0].add_child(actors)
	fx = FxScript.new()
	fx.main = self
	vps[0].add_child(fx)
	var start: Vector2 = START if night else (lv["start"] as Vector2)
	for i in 2:
		var pl = PlayerScript.new()
		pl.pid = i
		pl.main = self
		pl.look = (Game.player_looks[i] as Dictionary).duplicate(true)
		pl.night = night
		pl.position = (start + Vector2(-0.6 + 1.2 * i, 0.3)) * TS
		pl.dir = 0.0
		pl.facing = ART.facing_from_angle(0.0)
		actors.add_child(pl)
		players.append(pl)
	player = players[0]
	for p in data["profs"]:
		if not night:
			continue   # Level 1: no professors on the map
		var pr = ProfScript.new()
		pr.setup(p, world, self)
		actors.add_child(pr)
		profs.append(pr)
	if not night:
		_spawn_students()
		if lv.has("crowd"):
			_spawn_crowd(lv)
	_spawn_npcs()
	logic = LV.new_logic()
	if logic != null:
		logic.main = self
		vps[0].add_child(logic)
	hud = HudScript.new()
	hud.main = self
	add_child(hud)
	_add_transcript_button()
	_update_cameras(0.0, true)
	var controls := ""
	for i in 2:
		var kl: Dictionary = KEYS.labels_for(i)
		controls += "%s: %s · %s · %s sprinten · %s schleichen · %s Weg zur Aufgabe\n" % [Game.name_of(i), "WASD" if i == 0 else "Pfeile", kl["ok"], kl["sprint"], kl["sneak"], kl["select"]]
	controls += "L: Leistungsüberblick (Levels und Wahlfächer)"
	if night:
		var d: Dictionary = CH.DEPTS[dept]
		hud.show_overlay("Nacht", "Es ist 00:30. %s\n\nBleibt nicht zu lange im Lichtkegel der Professoren." % d["night_text"],
			controls, "Los geht's!", false, "info", "LEVEL %d" % Game.level)
	else:
		var lines := String(lv["intro"]) + "\n"
		for tk in LV.tasks():
			lines += "\n•  %s  –  %s" % [tk["name"], tk["where"]]
		var mins := "%d Minuten" % int(day_time / 60.0)
		if int(day_time) % 60 != 0:
			mins = "%d:%02d Minuten" % [int(day_time) / 60, int(day_time) % 60]
		lines += "\n\nIhr habt %s. %s" % [mins, lv.get("hint", "Leise sein (schleichen), sonst merken die Erstis was.")]
		hud.show_overlay(String(lv["name"]), lines, controls, "Los geht's!", false, "info", String(lv["tag"]))


func _setup_input() -> void:
	var keys := {
		"interact": [KEY_E, KEY_SPACE], "restart": [KEY_R], "start": [KEY_ENTER, KEY_KP_ENTER],
		"ability": [KEY_Q], "menu": [KEY_M], "transcript": [KEY_L],
	}
	for a in keys:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)


func _new_student(rng: RandomNumberGenerator, pos_px: Vector2, z: Array) -> CharacterBody2D:
	var st = StudentScript.new()
	st.look = CH.random_student(rng)
	st.zone = z
	st.world = world
	st.main = self
	st.position = pos_px
	return st


## Older students spread over the campus (no bags).
func _spawn_students() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for z in data["student_zones"]:
		for i in int(z[4]):
			var pos := Vector2.ZERO
			var ok := false
			for tries in 20:
				var tile := Vector2i(rng.randi_range(z[0], z[2]), rng.randi_range(z[1], z[3]))
				if world.astar.is_in_boundsv(tile) and not world.astar.is_point_solid(tile):
					pos = (Vector2(tile) + Vector2(0.5, 0.5)) * TS
					ok = true
					break
			if not ok:
				continue
			var st = _new_student(rng, pos, z)
			actors.add_child(st)
			students.append(st)


## People from the level definition ("npcs") and Opps from earlier levels ("opp_spots"), see opp.gd.
func _spawn_npcs() -> void:
	var placed: Array = []
	for d in lv.get("npcs", []):
		_add_opp(d)
		placed.append(String(d.get("id", "")))
	# whoever became an Opp in an earlier level comes back at the spots this level offers
	var spots: Array = lv.get("opp_spots", [])
	var k := 0
	for id in Game.opps_before(Game.level):
		if k >= spots.size():
			break
		if placed.has(id):
			continue
		var sp: Dictionary = spots[k]
		k += 1
		_add_opp({"id": id, "pos": sp["pos"], "face": sp.get("face", PI / 2.0), "if_opp": sp.get("mode", "lauert")})


func _add_opp(d: Dictionary):
	var op = OppScript.new()
	op.setup(d, self)
	actors.add_child(op)
	opps.append(op)
	return op


## The Ersti welcome crowd around the players. Some of them carry an Ersti bag.
func _spawn_crowd(lv: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var center: Vector2 = lv["start"]
	var n := int(lv["crowd"])
	var bags := int(lv["bags"])
	var spots: Array = []
	var tries := 0
	while spots.size() < n and tries < n * 40:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf())
		var p := center + Vector2(cos(a) * r * 6.5, sin(a) * r * 5.0)
		var tile := Vector2i(int(floor(p.x)), int(floor(p.y)))
		if not world.astar.is_in_boundsv(tile) or world.astar.is_point_solid(tile):
			continue
		if p.distance_to(center) < 1.4:
			continue
		var free := true
		for q in spots:
			if (q as Vector2).distance_to(p) < 0.95:
				free = false
				break
		if free:
			spots.append(p)
	var zones: Array = data["student_zones"]
	for k in spots.size():
		var st = _new_student(rng, (spots[k] as Vector2) * TS, zones[rng.randi() % zones.size()])
		st.gathering = true
		st.face_point = (lv["speaker"] as Vector2) * TS
		st.wait = rng.randf_range(0.0, 2.0)
		if k < bags:
			st.set_bag(true)
		actors.add_child(st)
		students.append(st)


# ------------------------------------------------------------------ split screen
func _build_views() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var vroot := Control.new()
	vroot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vroot)
	vroot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 2:
		var c := SubViewportContainer.new()
		c.stretch = true
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vroot.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var v := SubViewport.new()
		v.handle_input_locally = false
		c.add_child(v)
		vcs.append(c)
		vps.append(v)
	var sh := Shader.new()
	sh.code = SPLIT_SHADER
	split_mat = ShaderMaterial.new()
	split_mat.shader = sh
	vcs[1].material = split_mat
	vps[1].world_2d = vps[0].world_2d
	vps[1].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 2:
		var cam := Camera2D.new()
		cam.zoom = Vector2(zoom, zoom)
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(float(data["W"]) * TS)
		cam.limit_bottom = int(float(data["H"]) * TS)
		vps[i].add_child(cam)
		cam.make_current()
		cams.append(cam)
	divider = Control.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.draw.connect(_draw_divider)
	vroot.add_child(divider)
	divider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_views()


func _layout_views() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	split_mat.set_shader_parameter("normal", split_n)
	split_mat.set_shader_parameter("size", vs)
	divider.queue_redraw()


## The divider grows in along the split line while the two pictures drift apart.
func _draw_divider() -> void:
	var e := smoothstep(0.0, 1.0, split_k)
	if e <= 0.01:
		return
	var c := divider.size / 2.0
	var along := Vector2(-split_n.y, split_n.x) * divider.size.length()
	divider.draw_line(c - along, c + along, Color(UI.DARK, e), 6.0 * e)


func _solo_minigame_open() -> bool:
	if minis[0] == null and minis[1] == null:
		return false
	return minis[0] != minis[1]


## Keeps a camera centre so far from the map border that the view shows no outside.
func _clamp_view(p: Vector2, view: Vector2) -> Vector2:
	var m := Vector2(float(data["W"]), float(data["H"])) * TS
	var x := m.x / 2.0 if view.x >= m.x else clampf(p.x, view.x / 2.0, m.x - view.x / 2.0)
	var y := m.y / 2.0 if view.y >= m.y else clampf(p.y, view.y / 2.0, m.y - view.y / 2.0)
	return Vector2(x, y)


func _update_cameras(delta: float = 0.0, snap: bool = false) -> void:
	if players.size() < 2:
		return
	var a: Vector2 = players[0].global_position + CAM_OFFSET
	var b: Vector2 = players[1].global_position + CAM_OFFSET
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var d := b - a
	# how far the shared view has to zoom out to show both players
	var need := maxf(absf(d.x) * zoom / (vs.x * FIT_X), absf(d.y) * zoom / (vs.y * FIT_Y))
	var forced := _solo_minigame_open()
	if forced or need > OUT_MAX:
		split = true
	elif split and need < MERGE_OUT:
		split = false
		catching_up = true
	# zoom: split views go back to normal; the shared view keeps both players in the picture
	var f_back := 1.0 if snap else 1.0 - exp(-3.0 * delta / ZOOM_BACK)
	var f_in := 1.0 if snap else 1.0 - exp(-3.0 * delta / ZOOM_IN)
	if split:
		out += (1.0 - out) * f_back
	else:
		var goal := clampf(need, 1.0, OUT_MAX)
		out += (goal - out) * (f_back if catching_up else f_in)
		if catching_up and out >= goal - 0.01:
			catching_up = false
		if not catching_up:
			out = maxf(out, goal)   # zooming out follows the players at once, nobody leaves the picture
	var z := zoom / out
	# direction of the split: at right angles to the line between the players, upright for a minigame
	force_k = (1.0 if forced else 0.0) if snap else move_toward(force_k, 1.0 if forced else 0.0, delta / SPLIT_TIME)
	var fk := smoothstep(0.0, 1.0, force_k)
	var n_goal := d.normalized() if d.length() > 1.0 else split_n
	n_goal = n_goal.slerp(Vector2.RIGHT, fk)
	if snap or split_k < 0.01:
		split_n = n_goal   # nothing visible yet, so the line may jump
	else:
		split_n = split_n.slerp(n_goal, 1.0 - exp(-SPLIT_TURN * delta)).normalized()
	var n := split_n
	# shared picture: both cameras on the middle. Once the players are further apart than fits (r,
	# measured along n), the cameras move from the middle towards their players by the excess, so
	# each player stays r away from the screen centre on their own side of the line.
	var m := (a + b) / 2.0
	var r := minf(vs.x * FIT_X / 2.0 / maxf(absf(n.x), 0.001), vs.y * FIT_Y / 2.0 / maxf(absf(n.y), 0.001))
	var excess := maxf(0.0, d.length() / 2.0 - r / z)
	var goal_a := m - n * excess
	var goal_b := m + n * excess
	if fk > 0.0:
		# minigame: each player in the middle of their own half
		goal_a = goal_a.lerp(a + n * vs.x / 4.0 / z, fk)
		goal_b = goal_b.lerp(b - n * vs.x / 4.0 / z, fk)
	var view := vs / z
	var f := 1.0 if snap else 1.0 - exp(-CAM_FOLLOW * delta)
	cam_a += (_clamp_view(goal_a, view) - cam_a) * f
	cam_b += (_clamp_view(goal_b, view) - cam_b) * f
	cams[0].global_position = cam_a
	cams[1].global_position = cam_b
	for c in cams:
		c.zoom = Vector2(z, z)
	# the divider shows as much as the two pictures differ
	split_k = clampf(cam_a.distance_to(cam_b) * z / 24.0, 0.0, 1.0)
	_layout_views()


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
		elif event.physical_keycode in [KEY_KP_SUBTRACT]:
			dz = -0.2
	if dz != 0.0:
		zoom = clampf(zoom + dz, ZOOM_MIN, ZOOM_MAX)


## World position -> screen position in P1's view (used by the HUD ping arrows).
func world_to_screen(p: Vector2) -> Vector2:
	return vcs[0].position + vps[0].get_canvas_transform() * p


## Which half of the screen a player is on right now: 0 left, 1 right, -1 whole screen.
## With a slanted split it is the half (left or right) that holds most of the player's view.
func screen_side(pid: int) -> int:
	if force_k > 0.5:
		return pid
	if split_k < 0.5:
		return -1
	var p2_right := split_n.x >= 0.0
	if pid == 1:
		return 1 if p2_right else 0
	return 0 if p2_right else 1


# ------------------------------------------------------------------ loop
func busy(i: int) -> bool:
	return minis[i] != null


func _process(delta: float) -> void:
	_update_cameras(delta)
	if Input.is_action_just_pressed("transcript"):
		open_transcript()
		return
	if state in ["caught", "won", "lost"]:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		elif state == "won" and Input.is_action_just_pressed("start") and LV.next_after(Game.level) > 0:
			_next_level()
		elif Input.is_action_just_pressed("menu"):
			get_tree().change_scene_to_file("res://menu.tscn")
		hud.refresh(delta)
		return
	match state:
		"intro":
			if Input.is_action_just_pressed("start") or Input.is_action_just_pressed("interact"):
				start_game()
		"play":
			time_played += delta
			cooldown = maxf(0.0, cooldown - delta)
			blackout_t = maxf(0.0, blackout_t - delta)
			ping_t = maxf(0.0, ping_t - delta)
			zone = world.zone_at(players[0].global_position)
			if night and not entered_hg:
				for pl in players:
					if world.zone_at(pl.global_position) in HG_ZONES:
						entered_hg = true
						hud.toast("Drin!", "Der Hintereingang war offen. Leise jetzt, im Gang patrouilliert Prof. Keller.")
						break
			if not night and time_played >= day_time:
				_lose_day()
				hud.refresh(delta)
				return
			for i in players.size():
				if busy(i):
					nears[i] = null
					continue
				_update_near(i)
				if Input.is_action_just_pressed(KEYS.action(i, "select")):
					pick_next(i)
				if Input.is_action_just_pressed(KEYS.action(i, "interact")):
					_interact(i)
					if state != "play":
						break
			near = nears[0]
			if state == "play":
				_check_escapes()
			if state == "play":
				_update_routes(delta)
			if state == "play" and night and Input.is_action_just_pressed("ability"):
				_use_ability()
			if state == "play" and night and has_item:
				for pl in players:
					if STATION.has_point(pl.global_position / TS):
						_win_night()
						break
	hud.refresh(delta)


func start_game() -> void:
	state = "play"
	for pl in players:
		pl.enabled = true
	hud.hide_overlay()
	UI.sfx("pop")
	if night:
		hud.toast("Polyterrasse, 00:30", "Der Haupteingang ist zu. Versucht es hinten an der Künstlergasse.", 6.0)
	else:
		var st: Array = lv.get("start_toast", ["Willkommen, Erstis!", "Die grünen Bags sind auf den Rucksäcken. Von hinten anschleichen, nicht rennen!"])
		hud.toast(st[0], st[1], 6.0)


func on_overlay_button() -> void:
	if state == "intro":
		start_game()
	elif state == "won" and LV.next_after(Game.level) > 0:
		_next_level()
	else:
		get_tree().reload_current_scene()


func _next_level() -> void:
	Game.set_level(LV.next_after(Game.level))
	get_tree().reload_current_scene()


func on_overlay_menu() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")


# ------------------------------------------------------------------ transcript in the game
## Small button bottom right, above everything except cutscenes: the transcript is always one click away.
func _add_transcript_button() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 16   # over the HUD and over full-screen level scenes such as the ski race
	add_child(cl)
	var b := UI.button("Leistungsüberblick · L", UI.NAVY2, 14)
	b.anchor_left = 1.0
	b.anchor_top = 1.0
	b.anchor_right = 1.0
	b.anchor_bottom = 1.0
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.grow_vertical = Control.GROW_DIRECTION_BEGIN
	b.offset_right = -14.0
	b.offset_bottom = -12.0
	b.modulate.a = 0.85
	b.pressed.connect(open_transcript)
	cl.add_child(b)


## Shows the transcript over the game and pauses it. A click on a course starts that level
## (story or elective); Esc, Backspace or L goes back into the game.
func open_transcript() -> void:
	if tr_layer != null or Engine.get_process_frames() - tr_closed_frame < 3:
		return
	tr_layer = TranscriptLayer.new()
	tr_layer.main = self
	tr_layer.layer = 60
	tr_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tr_layer)
	var tr := Transcript.new()
	tr_layer.add_child(tr)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.back.connect(close_transcript)
	tr.start_level.connect(func(n: int):
		get_tree().paused = false
		Game.set_level(n)
		get_tree().reload_current_scene())
	get_tree().paused = true
	UI.sfx("pop")


func close_transcript() -> void:
	if tr_layer == null:
		return
	get_tree().paused = false
	tr_layer.queue_free()
	tr_layer = null
	tr_closed_frame = Engine.get_process_frames()


# ------------------------------------------------------------------ sound
## Called by a player on every footstep.
func on_step(pl, radius: float) -> void:
	var col := Color(1, 1, 1, 0.35)
	if pl.gait == "sprint":
		col = Color(1.0, 0.8, 0.4, 0.6)
	elif pl.gait == "sneak":
		col = Color(0.7, 0.85, 1.0, 0.3)
	fx.sound(pl.global_position, radius, col, 0.8 if pl.gait == "sprint" else 0.6)
	if not night and pl.gait != "sneak":
		_alert_erstis(pl.global_position, radius)
	if pl.gait != "sneak":
		for op in opps:
			op.hear(pl.global_position, radius)
	if logic != null and logic.has_method("on_noise"):
		logic.on_noise(pl.global_position, radius)


## Erstis with a bag hear noise within `radius` px, turn around and hold their bag.
func _alert_erstis(at: Vector2, radius: float) -> void:
	var any := false
	for st in students:
		if not st.has_bag or st.frozen:
			continue
		if st.global_position.distance_to(at) < radius + 0.4 * TS:
			if st.alert_t <= 0.0:
				any = true
			st.alert(at, 3.0)
	if any and not hint_noise_shown:
		hint_noise_shown = true
		hud.toast("Psst! Zu laut!", "Die Erstis hören dich und halten ihre Bag fest. Schleichen: %s %s, %s %s" % [Game.name_of(0), KEYS.labels_for(0)["sneak"], Game.name_of(1), KEYS.labels_for(1)["sneak"]], 5.0)


func make_noise(at: Vector2, radius: float) -> void:
	for p in profs:
		var d: float = p.global_position.distance_to(at)
		var r := radius if world.line_clear(p.global_position, at) else radius * 0.5
		if d < r:
			p.hear(at)


# ------------------------------------------------------------------ interaction
func _update_near(i: int) -> void:
	nears[i] = null
	var pl = players[i]
	if pl.hidden_mode:
		return
	var best := 1.3
	var p: Vector2 = pl.global_position / TS
	for o in data["objs"]:
		if not o.has("use") or o.get("taken", false) or o.get("opened", false):
			continue
		if o["use"] == "station" and done[i].has(o["task"]):
			continue
		var r: Rect2 = o["rect"]
		var c := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var dd := p.distance_to(c)
		if dd < best:
			best = dd
			nears[i] = o
	for op in opps:
		if op.bag_state != "there":
			continue
		var db: float = p.distance_to(op.bag_pos / TS)
		if db < best and db < 1.1:
			best = db
			nears[i] = {"use": "bag", "opp": op, "label": "%s klauen" % op.bag_name,
				"rect": Rect2(op.bag_pos / TS - Vector2(0.35, 0.6), Vector2(0.7, 0.75))}
	if night:
		return
	if not done[i].has("ersti") and not LV.task("ersti").is_empty():
		for st in students:
			if not st.has_bag or st.frozen:
				continue
			var ds: float = p.distance_to(st.global_position / TS)
			if ds < best and ds < 1.25:
				best = ds
				nears[i] = {"use": "steal", "student": st, "label": "Ersti-Bag klauen",
					"rect": Rect2(st.global_position / TS - Vector2(0.5, 1.7), Vector2(1.0, 1.9))}
	if not done[i].has("highfive") and not LV.task("highfive").is_empty() and best > 0.6:
		var other = players[1 - i]
		var op: Vector2 = other.global_position / TS
		if p.distance_to(op) < 1.8 and not busy(1 - i) and not other.hidden_mode:
			var mid := (p + op) / 2.0
			nears[i] = {"use": "highfive", "label": "High Five!", "rect": Rect2(mid - Vector2(1.3, 1.7), Vector2(2.6, 2.1))}
	if logic != null and logic.has_method("update_near"):
		logic.update_near(i)


func _interact(i: int) -> void:
	var pl = players[i]
	if pl.hidden_mode:
		pl.hidden_mode = false
		hud.toast("Raus aus dem Versteck", "Schau dich um, bevor du losgehst.", 2.5)
		return
	if nears[i] == null:
		return
	var o: Dictionary = nears[i]
	match o["use"]:
		"hide":
			pl.hidden_mode = true
			hud.toast("Versteckt", "Solange du hier bleibst, sieht dich niemand. Nochmals interagieren zum Verlassen.", 3.0)
		"info":
			var info: Array = o["info"]
			hud.toast(info[0], info[1])
		"prep":
			o["taken"] = true
			has_prep = true
			world.queue_redraw()
			hud.toast("Gefunden", "Das hilft euch am Labor weiter.")
		"moodle_prep":
			if has_prep:
				hud.toast("Moodle", "Das Wartungspasswort habt ihr schon. Jetzt zum Kartenleser am Labor.")
			else:
				var on_pw := func():
					has_prep = true
					o["use"] = "info"
					o["info"] = ["Moodle", "Du bist noch eingeloggt. Das Passwort habt ihr bereits."]
					hud.toast("Passwort gefunden", "Ab zum Labor!")
				open_minigame("moodle", {"count": 2}, on_pw, i)
		"labdoor":
			_lab_door(i)
		"fusebox":
			if not has_prep:
				hud.toast("Sicherungskasten", "Zu viele Kabel. Ohne Schaltplan wisst ihr nicht, was wohin gehört.")
			else:
				var on_fuse := func():
					_open_lab()
					hud.toast("Klick.", "Das Laborschloss ist stromlos.")
				open_minigame("wiring", {"title": "Sicherungskasten umverdrahten", "wires": 5}, on_fuse, i)
		"goal":
			o["taken"] = true
			has_item = true
			world.queue_redraw()
			hud.toast("Gesichert!", "Jetzt nichts wie raus – zurück zur Polybahn!")
		"station":
			_day_station(o, i)
		"steal":
			_steal(i, o["student"])
		"highfive":
			_highfive(i)
		"level":
			logic.interact(i, o)
		"bag":
			_steal_bag(i, o["opp"])


func _lab_door(i: int) -> void:
	match dept:
		"MAVT":
			if not has_prep:
				hud.toast("Verschlossen", "Ein altes Zylinderschloss. Mit Werkzeug ginge das.")
			else:
				var on_lock := func():
					_open_lab()
					hud.toast("Offen!", "Der letzte Stift springt.")
				open_minigame("timing", {"title": "Schloss knacken", "hits": 4, "verb": "Stift", "speed": 280.0}, on_lock, i)
		"ITET":
			hud.toast("Elektronisches Schloss", "Die Tür hängt am Sicherungskasten links im Gang.")
		_:
			if not has_prep:
				hud.toast("Kartenleser", "Er will ein Wartungspasswort. Vielleicht steht es im Moodle.")
			else:
				var on_hack := func():
					_open_lab()
					hud.toast("Zugriff gewährt", "Die Tür summt und springt auf.")
				open_minigame("sequence", {"title": "Kartenleser hacken", "length": 6}, on_hack, i)


func _open_lab() -> void:
	lab_open = true
	world.open_door("lab")


# ------------------------------------------------------------------ Level 1 (day)
func _day_station(o: Dictionary, i: int) -> void:
	var id: String = o["task"]
	if done[i].has(id):
		hud.toast("Schon erledigt", "Das hast du schon. Schau, was noch fehlt.", 2.5)
		return
	if busy_spot[1 - i] == o:
		hud.toast("Besetzt", "%s ist hier gerade dran. Es gibt noch andere Plätze." % Game.name_of(1 - i), 2.5)
		return
	var tk: Dictionary = LV.task(id)
	if tk.is_empty():
		return
	var params: Dictionary = (tk["params"] as Dictionary).duplicate()
	if id == "legi":
		params["legi"] = i
	busy_spot[i] = o
	var on_ok := func(): _task_done(i, id)
	var on_close := func(): busy_spot[i] = null
	open_minigame(String(tk["game"]), params, on_ok, i, Callable(), on_close)


func _steal(i: int, st) -> void:
	var pl = players[i]
	if done[i].has("ersti") or not st.has_bag:
		return
	if st.alert_t > 0.0:
		hud.toast("Festgehalten!", "Die Ersti hält die Bag gerade gut fest. Kurz warten, dann leise von hinten.", 3.0)
		UI.sfx("fail")
		return
	var to: Vector2 = pl.global_position - st.global_position
	var ang := absf(wrapf(to.angle() - st.dir, -PI, PI))
	if ang < STEAL_BEHIND or pl.gait == "sprint":
		st.alert(pl.global_position, 3.5)
		fx.sound(st.global_position, 2.0 * TS, Color(1.0, 0.4, 0.4, 0.7), 0.6)
		hud.toast("Bemerkt!", "Von vorne klappt das nicht. Schleich dich von hinten an.", 3.0)
		UI.sfx("fail")
		return
	st.frozen = true
	var on_ok := func():
		st.frozen = false
		st.set_bag(false)
		_give_bag(i)
		_task_done(i, "ersti")
	var on_mistake := func():
		st.frozen = false
		st.alert(pl.global_position, 4.0)
		_abort_mini(i)
		hud.toast("Ups, gemerkt!", "Die Ersti hat dich gespürt. Versuch's gleich nochmal bei jemand anderem.", 3.0)
	var on_close := func(): st.frozen = false
	open_minigame("timing", {"title": "Ersti-Bag klauen", "hits": 2, "verb": "Griff", "speed": 330.0}, on_ok, i, on_mistake, on_close)


func _give_bag(i: int) -> void:
	var pl = players[i]
	var acc: Array = pl.look.get("acc", [])
	if not acc.has("erstibag"):
		acc.append("erstibag")
	pl.look["acc"] = acc
	pl.queue_redraw()
	UI.sfx("steal")
	UI.confetti(fx, pl.global_position + Vector2(0, -30), 40, true, 70.0, 0.3)


func _highfive(i: int) -> void:
	var other = players[1 - i]
	if busy(1 - i):
		hud.toast("Moment!", "%s ist gerade beschäftigt." % Game.name_of(1 - i), 2.5)
		return
	if other.global_position.distance_to(players[i].global_position) > 1.9 * TS:
		hud.toast("Zu weit weg", "Für einen High Five müsst ihr nebeneinander stehen.", 2.5)
		return
	var tk: Dictionary = LV.task("highfive")
	var on_ok := func(): _coop_done("highfive")
	open_coop_minigame(String(tk["game"]), tk["params"], on_ok)


# ------------------------------------------------------------------ opps
func _bag_task() -> String:
	for tk in LV.tasks():
		if String(tk.get("type", "")) == "bag":
			return tk["id"]
	return ""


func _steal_bag(i: int, op) -> void:
	var pl = players[i]
	for other in opps:
		if other.bag_state == "stolen" and other.bag_thief == i:
			hud.toast("Hände voll", "Du hast schon eine Beute dabei.", 2.5)
			return
	ART.set_acc(pl.look, op.bag_acc, true)
	pl.look["loot_col"] = op.bag_col.to_html(false)
	pl.queue_redraw()
	UI.sfx("steal")
	UI.confetti(fx, pl.global_position + Vector2(0, -30), 40, true, 70.0, 0.3)
	op.bag_taken(i)   # the owner reacts at once if they saw it, otherwise a little later
	# the task is not done yet: the thief has to get out of the room with it (_check_escapes)
	if state == "play" and not op.angry:
		hud.toast("Geklaut!", "Jetzt leise raus hier. Die Beute zählt erst, wenn du draussen bist (%s verlassen), ohne erwischt zu werden." % op.home_zone, 4.5)


## A stolen bag counts once its thief has left the room it was taken from without being caught.
func _check_escapes() -> void:
	var id := _bag_task()
	if id == "":
		return
	for op in opps:
		if op.bag_state != "stolen" or op.bag_thief < 0:
			continue
		var pid: int = op.bag_thief
		if not done[pid].has(id) and world.zone_at(players[pid].global_position) != op.home_zone:
			_task_done(pid, id)


## The Opp whose bag this player is carrying out right now (stolen, not out of the room yet), or null.
func _carrying(pid: int):
	var id := _bag_task()
	for op in opps:
		if op.bag_state == "stolen" and op.bag_thief == pid and not done[pid].has(id):
			return op
	return null


## Nearest free tile outside the room `zone_name`, seen from where the player stands.
func _way_out(pid: int, zone_name: String) -> Vector2:
	var start := Vector2i((players[pid].global_position / TS).floor())
	var seen := {start: true}
	var todo: Array = [start]
	var i := 0
	while i < todo.size() and i < 2500:
		var c: Vector2i = todo[i]
		i += 1
		var p := (Vector2(c) + Vector2(0.5, 0.5)) * TS
		if world.zone_at(p) != zone_name:
			return p
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not world.astar.is_in_boundsv(n) or world.astar.is_point_solid(n):
				continue
			seen[n] = true
			todo.append(n)
	return players[pid].global_position


## Somebody turned into an Opp just now (called by opp.gd, or by a level for its own people).
func on_new_opp(op, seen: bool) -> void:
	if state != "play":
		return
	UI.sfx("doom", -9.0)
	fx.sound(op.global_position, 3.0 * TS, Color(1.0, 0.4, 0.4, 0.7), 0.8)
	if seen:
		hud.toast("Neuer Opp: %s" % op.pname, "%s hat dich gesehen und ist jetzt hinter dir her. Lauf!" % op.pname, 4.0)
	else:
		hud.toast("Neuer Opp: %s" % op.pname, "%s hat es bemerkt und sucht dich. Bleib ausser Sicht." % op.pname, 4.0)


## An Opp touched a player. With their bag on you: you lose it. Otherwise the level is over.
func opp_catch(op, pl) -> void:
	if state != "play":
		return
	var pid := players.find(pl)
	if logic != null and logic.has_method("on_opp_catch") and logic.on_opp_catch(op, pid):
		return
	if op.bag_state == "stolen" and op.bag_thief == pid:
		mistakes_total += 1
		ART.set_acc(pl.look, op.bag_acc, false)
		pl.queue_redraw()
		done[pid].erase(_bag_task())
		op.take_back()
		if minis[pid] != null:
			_abort_mini(pid)
		pl.enabled = false
		var tw := create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(func():
			if state == "play" and not busy(pid):
				pl.enabled = true)
		fx.sound(pl.global_position, 3.0 * TS, Color(1.0, 0.4, 0.4, 0.7), 0.8)
		UI.sfx("fail")
		hud.toast("Erwischt!", "%s hat die Beute zurück und passt jetzt besser auf. Hol sie dir nochmals, wenn niemand hinschaut." % op.pname, 4.5)
		return
	caught(op)


func _left(pid: int) -> int:
	return LV.tasks().size() - done[pid].size()


func _task_done(pid: int, id: String) -> void:
	if done[pid].has(id) or state != "play":
		return
	done[pid][id] = true
	world.queue_redraw()
	var tk: Dictionary = LV.task(id)
	var left := _left(pid)
	var sub := "%s · noch %d" % [Game.name_of(pid), left] if left > 0 else "%s hat alles!" % Game.name_of(pid)
	hud.celebrate(String(tk["name"]), sub, Color(KEYS.TAG_COLORS[pid]), screen_side(pid))
	_check_win()


func _coop_done(id: String) -> void:
	if state != "play":
		return
	for pid in 2:
		done[pid][id] = true
	var tk: Dictionary = LV.task(id)
	hud.celebrate(String(tk["name"]) + "!", "%s & %s" % [Game.name_of(0), Game.name_of(1)], UI.YELLOW, -1)
	_check_win()


func _check_win() -> void:
	if _left(0) == 0 and _left(1) == 0:
		get_tree().create_timer(1.4).timeout.connect(func():
			if state != "play":
				return
			if logic != null and logic.has_method("finale"):
				logic.finale(_win_day)   # e.g. a cutscene; it calls _win_day when it is over
			else:
				_win_day())


func _win_day() -> void:
	_close_minis()
	state = "won"
	for pl in players:
		pl.enabled = false
	var grade := 6.0 - 0.25 * mistakes_total - maxf(0.0, time_played - day_time * 0.5) / 30.0 * 0.25
	grade = clampf(snappedf(grade, 0.25), 1.0, 6.0)
	var verdict := "Hervorragend!" if grade >= 5.5 else ("Gut gemacht." if grade >= 4.5 else ("Bestanden." if grade >= 4.0 else "Knapp daneben."))
	var t := int(time_played)
	Game.add_grade(Game.level, grade, t, mistakes_total)   # for the transcript in the menu
	var story: String = String(lv.get("win_text", "%s & %s haben den ersten Tag überlebt.")) % [Game.name_of(0), Game.name_of(1)]
	var nxt := LV.next_after(Game.level)
	var more := nxt > 0
	hud.show_overlay(String(lv.get("win_title", "Ersti-Tag geschafft!")),
		"%s\n\nNote %s · %s\nZeit: %d:%02d · Fehler: %d\n\nIn der Schweiz ist 6 die Bestnote, ab 4 ist bestanden." % [story, String.num(grade, 2), verdict, t / 60, t % 60, mistakes_total],
		("Enter weiter · " if more else "") + "R nochmals spielen · M zum Startbildschirm",
		"Weiter zu Level %d" % nxt if more else "Nochmals spielen", true, "win", "LEVEL %d" % Game.level)


func _lose_day() -> void:
	_close_minis()
	state = "lost"
	for pl in players:
		pl.enabled = false
	var total := LV.tasks().size()
	hud.show_overlay(String(lv.get("lose_title", "Zeit abgelaufen")),
		"%s\n\n%s: %d von %d\n%s: %d von %d" % [lv.get("lose_text", "Der erste Tag ist vorbei, und es ist noch nicht alles erledigt."), Game.name_of(0), done[0].size(), total, Game.name_of(1), done[1].size(), total],
		"R nochmals versuchen · M zum Startbildschirm", "Nochmals versuchen", true, "lose", "LEVEL %d" % Game.level)


# ------------------------------------------------------------------ minigames
func _close_minis() -> void:
	var seen: Array = []
	for mg in minis:
		if mg != null and not seen.has(mg):
			seen.append(mg)
			mg.queue_free()
	minis = [null, null]
	busy_spot = [null, null]
	for st in students:
		st.frozen = false


func _abort_mini(pid: int) -> void:
	var mg = minis[pid]
	if mg == null:
		return
	mg.finished.emit(false, mg.mistakes)
	mg.queue_free()


## Minigame for one player, on that player's half of the screen with that player's keys.
func open_minigame(kind: String, params: Dictionary, on_success: Callable, pid: int = 0,
		on_mistake: Callable = Callable(), on_close: Callable = Callable()) -> void:
	var mg = MiniScript.new()
	mg.screen_side = pid
	mg.keys = KEYS.keys_for(pid)
	mg.labels = KEYS.labels_for(pid)
	mg.accent = Color(KEYS.TAG_COLORS[pid])
	minis[pid] = mg
	nears[pid] = null
	players[pid].enabled = false
	add_child(mg)
	mg.open(kind, params, dept)
	mg.mistake.connect(func():
		_on_mini_mistake(pid)
		if on_mistake.is_valid():
			on_mistake.call())
	mg.finished.connect(func(ok: bool, _m: int):
		if minis[pid] != mg:
			return
		minis[pid] = null
		if on_close.is_valid():
			on_close.call()
		if state != "play":
			return
		players[pid].enabled = true
		if ok:
			on_success.call()
		else:
			hud.toast("Abgebrochen", "Du kannst es jederzeit nochmals versuchen.", 2.5))


## Minigame for both players at once (full screen, P1 and P2 keys).
func open_coop_minigame(kind: String, params: Dictionary, on_success: Callable) -> void:
	var mg = MiniScript.new()
	mg.screen_side = -1
	mg.keys = KEYS.keys_for(0)
	mg.labels = KEYS.labels_for(0)
	mg.keys2 = KEYS.keys_for(1)
	mg.labels2 = KEYS.labels_for(1)
	mg.accent = UI.YELLOW
	for j in 2:
		minis[j] = mg
		nears[j] = null
		players[j].enabled = false
	add_child(mg)
	mg.open(kind, params, dept)
	mg.mistake.connect(func(): _on_mini_mistake(-1))
	mg.finished.connect(func(ok: bool, _m: int):
		if minis[0] != mg and minis[1] != mg:
			return
		for j in 2:
			if minis[j] == mg:
				minis[j] = null
		if state != "play":
			return
		for pl in players:
			pl.enabled = true
		if ok:
			on_success.call()
		else:
			hud.toast("Abgebrochen", "Ihr könnt es jederzeit nochmals versuchen.", 2.5))


func _on_mini_mistake(pid: int) -> void:
	mistakes_total += 1
	var at: Vector2 = (players[0].global_position + players[1].global_position) / 2.0
	if pid >= 0:
		at = players[pid].global_position
	fx.sound(at, 4.0 * TS, Color(1.0, 0.45, 0.35, 0.7), 1.0)
	if night:
		make_noise(at, 5.5 * TS)
		hud.toast("Zu laut!", "Das hat jemand gehört …", 1.8)
	else:
		_alert_erstis(at, 3.0 * TS)
	for op in opps:
		op.hear(at, 4.0 * TS)
	if logic != null and logic.has_method("on_noise"):
		logic.on_noise(at, 3.0 * TS)


# ------------------------------------------------------------------ abilities (night, P1)
func _use_ability() -> void:
	if cooldown > 0.0 or busy(0):
		return
	cooldown = ability["cooldown"]
	match ability["id"]:
		"wrench":
			var from: Vector2 = player.global_position + Vector2(0, -16)
			var target := from + Vector2.from_angle(player.dir) * 4.5 * TS
			var end: Vector2 = world.ray_end(from, target)
			var land := end - Vector2.from_angle(player.dir) * 10.0 + Vector2(0, 16)
			fx.throw(from, land)
			get_tree().create_timer(0.45).timeout.connect(func():
				fx.ring(land)
				make_noise(land, 7.0 * TS))
			hud.toast("Klirr!", "Der Schlüssel scheppert über den Boden.", 2.5)
		"blackout":
			blackout_t = 7.0
			hud.toast("Stromausfall!", "Für 7 Sekunden reichen die Taschenlampen nur halb so weit.", 3.0)
		"ping":
			ping_t = 6.0
			hud.toast("Ping", "Alle Professoren für 6 Sekunden geortet.", 2.5)


# ------------------------------------------------------------------ status for HUD / FX
## Night: [text, done, active]. Day: [name, where, [done P1, done P2], [note P1, note P2]].
func objectives() -> Array:
	if night:
		return [
			["Ins Hauptgebäude gelangen", entered_hg, true],
			["Vorbereitung finden", has_prep, entered_hg],
			["Labor öffnen", lab_open, has_prep],
			["Beute holen", has_item, lab_open],
			["Zur Polybahn fliehen", state == "won", has_item],
		]
	var out: Array = []
	for tk in LV.tasks():
		var id: String = tk["id"]
		# fourth entry: a short note per player while the task is half done (bag taken, not out yet)
		var notes: Array = ["", ""]
		if String(tk.get("type", "")) == "bag":
			for pid in 2:
				if _carrying(pid) != null:
					notes[pid] = "raus!"
		out.append([tk["name"], tk["where"], [done[0].has(id), done[1].has(id)], notes])
	return out


func _obj_center(pred: Callable) -> Array:
	var out: Array = []
	for o in data["objs"]:
		if pred.call(o):
			out.append((o["rect"] as Rect2).get_center() * TS)
	return out


func _need_color(n0: bool, n1: bool) -> Color:
	if n0 and n1:
		return UI.YELLOW
	return Color(KEYS.TAG_COLORS[0 if n0 else 1])


## Night: plain positions. Day: [position, colour] (colour = who still needs it).
func goal_positions() -> Array:
	if night:
		if not entered_hg:
			return [Vector2(53.5, 69.5) * TS]   # the south entrance, open at night
		if not has_prep:
			return _obj_center(func(o): return o.get("use", "") in ["prep", "moodle_prep"])
		if not lab_open:
			return _obj_center(func(o): return o.get("use", "") == ("fusebox" if dept == "ITET" else "labdoor"))
		if not has_item:
			return _obj_center(func(o): return o.get("use", "") == "goal")
		return [Vector2(10.5, 43.0) * TS]
	var out: Array = []
	for tk in LV.tasks():
		var id: String = tk["id"]
		var n0: bool = not done[0].has(id)
		var n1: bool = not done[1].has(id)
		if not (n0 or n1):
			continue
		var c := _need_color(n0, n1)
		match String(tk.get("type", "")):
			"steal":
				for st in students:
					if st.has_bag:
						out.append([st.global_position + Vector2(0, -30), c])
			"coop":
				pass
			"bag":
				for op in opps:
					if op.bag_state == "there":
						out.append([op.bag_pos, c])
			"level":
				if logic != null and logic.has_method("goal_positions"):
					out.append_array(logic.goal_positions(id, n0, n1))
			_:
				for p in _obj_center(func(o): return o.get("use", "") == "station" and o.get("task", "") == id):
					out.append([p, c])
	return out


# ------------------------------------------------------------------ picked task and the way to it
## Next task this player still has to do; after the last one nothing is picked.
func pick_next(pid: int) -> void:
	if night:
		return
	var tasks: Array = LV.tasks()
	var k: int = picked[pid] + 1
	while k < tasks.size() and done[pid].has(tasks[k]["id"]):
		k += 1
	pick(pid, k if k < tasks.size() else -1)


## Picks task number k for a player (again: drops it). Also called by a click on the task card.
func pick(pid: int, k: int) -> void:
	if night or state != "play":
		return
	picked[pid] = -1 if (k == picked[pid] or k < 0 or done[pid].has(LV.tasks()[k]["id"])) else k
	routes[pid] = []
	route_t[pid] = 0.0
	UI.sfx("click")


## Where task `id` can be done by player `pid` right now, in px.
func task_targets(id: String, pid: int) -> Array:
	var out: Array = []
	match String(LV.task(id).get("type", "")):
		"bag":
			var mine = _carrying(pid)
			if mine != null:
				out.append(_way_out(pid, mine.home_zone))   # got it: now out of the room
			else:
				for op in opps:
					if op.bag_state == "there":
						out.append(op.bag_pos)
		"steal":
			for st in students:
				if st.has_bag:
					out.append(st.global_position)
		"coop":
			out.append(players[1 - pid].global_position)   # together: go to the other one
		"level":
			if logic != null and logic.has_method("task_targets"):
				out = logic.task_targets(id, pid)
			elif logic != null and logic.has_method("goal_positions"):
				for g in logic.goal_positions(id, pid == 0, pid == 1):
					out.append(g[0])
		_:
			out = _obj_center(func(o): return o.get("use", "") == "station" and o.get("task", "") == id)
	return out


## Keeps the dashed way of each player up to date: the shortest way to the nearest place.
func _update_routes(delta: float) -> void:
	var tasks: Array = LV.tasks()
	for pid in players.size():
		var k: int = picked[pid]
		if k >= 0 and (k >= tasks.size() or done[pid].has(tasks[k]["id"])):
			picked[pid] = -1   # done, nothing left to show
			k = -1
		if k < 0 or busy(pid):
			routes[pid] = []
			continue
		var from: Vector2 = players[pid].global_position
		route_t[pid] -= delta
		route_age[pid] += delta
		if route_t[pid] > 0.0:
			routes[pid] = _trim_route(routes[pid], from)   # between two searches the line gets shorter at the feet
			continue
		route_t[pid] = 0.2
		var best: Array = []
		var best_len := INF
		for target in task_targets(tasks[k]["id"], pid):
			var p: Array = world.find_path(from, target)
			if p.size() > 1:
				p.pop_front()   # the first tile is where the player stands anyway
			p.push_front(from)
			p.append(target)
			var total := 0.0
			for j in range(1, p.size()):
				total += (p[j - 1] as Vector2).distance_to(p[j])
			if total < best_len:
				best_len = total
				best = p
		var fresh: Array = world.smooth_path(best) if best_len > 1.5 * TS else []   # standing in front of it: no line needed
		if _other_way(routes[pid], fresh):
			route_age[pid] = 0.0
		routes[pid] = fresh


## The way without the part the player has already walked: it starts at the feet again.
func _trim_route(r: Array, from: Vector2) -> Array:
	if r.size() < 3:
		return r
	var best := 0
	var best_d := INF
	for i in mini(r.size() - 1, 16):   # the nearest point within the first stretch
		var d := (r[i] as Vector2).distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = i
	var out: Array = r.slice(best + 1)
	out.push_front(from)
	return out


## True if `b` is a different way than `a` and not just the same one a few steps on: measured
## back from the goal (the points are about 8 px apart), the two are far from each other somewhere.
func _other_way(a: Array, b: Array) -> bool:
	if a.is_empty() or b.is_empty():
		return a.is_empty() != b.is_empty()
	for k in [0, 12, 40, 80, 140]:
		if k >= a.size() or k >= b.size():
			break
		if (a[a.size() - 1 - k] as Vector2).distance_to(b[b.size() - 1 - k]) > 2.0 * TS:
			return true
	return false


func time_left() -> float:
	return maxf(0.0, day_time - time_played)


func max_meter() -> float:
	var m := 0.0
	for p in profs:
		m = maxf(m, p.meter)
	return m


func spotted() -> void:
	spotted_count += 1


func caught(prof) -> void:
	if state != "play":
		return
	_close_minis()
	state = "caught"
	for pl in players:
		pl.enabled = false
		pl.hidden_mode = false
	hud.show_overlay("Erwischt!", "%s: «%s»" % [prof.pname, prof.quote],
		"R nochmals versuchen · M zum Startbildschirm", "Nochmals versuchen", true, "lose")


func _win_night() -> void:
	state = "won"
	for pl in players:
		pl.enabled = false
	var t := int(time_played)
	hud.show_overlay("Geschafft!", "Ihr sitzt in der Polybahn, die Beute in der Tasche.\n\nZeit: %d:%02d · Fast entdeckt: %d×" % [t / 60, t % 60, spotted_count],
		"R nochmals spielen · M zum Startbildschirm", "Nochmals spielen", true, "win")


func day_total() -> float:
	return day_time
