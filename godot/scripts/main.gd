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
## Camera: one shared view while the players are close, split screen when they drift apart
## or while one of them is in a minigame (the minigame then opens on that player's half).

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
const TS := 32.0
const START := Vector2(12.5, 43.5)
const STATION := Rect2(0, 41, 10.2, 5)
const HG_ZONES := ["Hauptgebäude (HG)", "Haupthalle", "ETH-Bibliothek", "Lounge", "Seminarraum", "Labor · Robotik"]
const CAM_OFFSET := Vector2(0, -18)
const ZOOM_MIN := 1.5
const ZOOM_MAX := 3.6
const SPLIT_AT := 0.7      # split when the players are further apart than this share of the screen
const MERGE_AT := 0.45     # merge again when closer than this share
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
# abilities (night, P1)
var ability: Dictionary
var cooldown := 0.0
var blackout_t := 0.0
var ping_t := 0.0

# split screen
var vcs: Array = []    # SubViewportContainer per view
var vps: Array = []    # SubViewport per view (both share one World2D)
var cams: Array = []
var divider: ColorRect
var split := false
var zoom := 2.5


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
	_update_cameras(true)
	var controls := "%s: WASD · E · Shift sprinten · Ctrl schleichen\n%s: Pfeile · Enter · . sprinten · - schleichen" % [Game.name_of(0), Game.name_of(1)]
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
		"ability": [KEY_Q], "menu": [KEY_M],
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
		var v := SubViewport.new()
		v.handle_input_locally = false
		c.add_child(v)
		vcs.append(c)
		vps.append(v)
	vps[1].world_2d = vps[0].world_2d
	for i in 2:
		var cam := Camera2D.new()
		cam.zoom = Vector2(zoom, zoom)
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 7.0
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(float(data["W"]) * TS)
		cam.limit_bottom = int(float(data["H"]) * TS)
		vps[i].add_child(cam)
		cam.make_current()
		cams.append(cam)
	divider = ColorRect.new()
	divider.color = UI.DARK
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vroot.add_child(divider)
	_layout_views()


func _layout_views() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if split:
		var hw := floorf(vs.x / 2.0)
		vcs[0].position = Vector2.ZERO
		vcs[0].size = Vector2(hw - 3.0, vs.y)
		vcs[1].visible = true
		vcs[1].position = Vector2(hw + 3.0, 0.0)
		vcs[1].size = Vector2(vs.x - hw - 3.0, vs.y)
		divider.visible = true
		divider.position = Vector2(hw - 3.0, 0.0)
		divider.size = Vector2(6.0, vs.y)
		vps[1].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		vcs[0].position = Vector2.ZERO
		vcs[0].size = vs
		vcs[1].visible = false
		divider.visible = false
		vps[1].render_target_update_mode = SubViewport.UPDATE_DISABLED


func _solo_minigame_open() -> bool:
	if minis[0] == null and minis[1] == null:
		return false
	return minis[0] != minis[1]


func _update_cameras(snap: bool = false) -> void:
	if players.size() < 2:
		return
	var a: Vector2 = players[0].global_position + CAM_OFFSET
	var b: Vector2 = players[1].global_position + CAM_OFFSET
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var d := (a - b).abs()
	if _solo_minigame_open():
		split = true
	elif split:
		if d.x < vs.x * MERGE_AT / zoom and d.y < vs.y * MERGE_AT / zoom:
			split = false
	elif d.x > vs.x * SPLIT_AT / zoom or d.y > vs.y * SPLIT_AT / zoom:
		split = true
	_layout_views()
	cams[0].global_position = a if split else (a + b) / 2.0
	cams[1].global_position = b
	if snap:
		for c in cams:
			c.reset_smoothing()


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
		for c in cams:
			c.zoom = Vector2(zoom, zoom)


## World position -> screen position in P1's view (used by the HUD ping arrows).
func world_to_screen(p: Vector2) -> Vector2:
	return vcs[0].position + vps[0].get_canvas_transform() * p


## Which half of the screen a player is on right now: 0 left, 1 right, -1 whole screen.
func screen_side(pid: int) -> int:
	return pid if split else -1


# ------------------------------------------------------------------ loop
func busy(i: int) -> bool:
	return minis[i] != null


func _process(delta: float) -> void:
	_update_cameras()
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
				if Input.is_action_just_pressed(KEYS.action(i, "interact")):
					_interact(i)
					if state != "play":
						break
			near = nears[0]
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
		hud.toast("Psst! Zu laut!", "Die Erstis hören dich und halten ihre Bag fest. Schleichen: %s Ctrl, %s -" % [Game.name_of(0), Game.name_of(1)], 5.0)


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
	var id := _bag_task()
	if id != "":
		_task_done(i, id)
	op.bag_taken(i)   # the owner reacts at once if they saw it, otherwise a little later


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
	_update_cameras()
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
## Night: [text, done, active]. Day: [name, where, [done P1, done P2]].
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
		out.append([tk["name"], tk["where"], [done[0].has(id), done[1].has(id)]])
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
			return [Vector2(57.5, 63.5) * TS]
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
