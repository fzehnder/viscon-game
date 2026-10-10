extends Node2D
## ETH Zentrum – Tag & Nacht. Two players on one keyboard.
## Builds the round from the menu choices (Game autoload): department and mode.
## Day = Level 1 (co-op tasks against the clock), night = break into the lab.
## Camera: one shared view while the players are close, split screen when they drift apart
## or while one of them is in a minigame (the minigame then opens on that player's half).

const MapData = preload("res://scripts/map_data.gd")
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ProfScript = preload("res://scripts/professor.gd")
const StudentScript = preload("res://scripts/student.gd")
const HudScript = preload("res://scripts/hud.gd")
const FxScript = preload("res://scripts/fx.gd")
const MiniScript = preload("res://scripts/minigame.gd")
const CH = preload("res://scripts/characters.gd")
const KEYS = preload("res://scripts/controls.gd")
const LV = preload("res://scripts/levels.gd")
const TS := 32.0
const START := Vector2(12.5, 43.5)
const STATION := Rect2(0, 41, 10.2, 5)
const HG_ZONES := ["Hauptgebäude (HG)", "Haupthalle", "ETH-Bibliothek", "Lounge", "Seminarraum", "Labor · Robotik"]
const CAM_OFFSET := Vector2(0, -18)
const ZOOM_MIN := 1.5
const ZOOM_MAX := 3.6
const SPLIT_AT := 0.7    # split when the players are further apart than this share of the screen
const MERGE_AT := 0.45   # merge again when closer than this share

var data: Dictionary
var world: Node2D
var actors: Node2D
var players: Array = []
var player: CharacterBody2D   # = players[0], kept for code that only knows one player
var profs: Array = []
var students: Array = []
var hud: CanvasLayer
var fx: Node2D
var minis: Array = [null, null]       # open minigame per player (same object twice for co-op games)
var nears: Array = [null, null]       # object each player could interact with
var near = null                       # = nears[0]
var open_task: Array = ["", ""]       # task id each player is working on

var dept := "MAVT"
var mode := "night"
var night := true
var state := "intro"   # intro, play, caught, won, lost
var zone := "Polyterrasse"
var time_played := 0.0
var day_time := 300.0
var spotted_count := 0
var mistakes_total := 0

# night progress
var entered_hg := false
var has_prep := false
var lab_open := false
var has_item := false
# day progress (Level 1)
var done_tasks := {}
var bag_watch := 0.0
var bag_warned := false
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
	dept = Game.dept
	mode = Game.mode
	night = mode == "night"
	ability = CH.DEPTS[dept]["ability"]
	data = MapData.new().build(mode, dept)
	if not night:
		day_time = float(LV.level(1)["time"])
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
	for i in 2:
		var pl = PlayerScript.new()
		pl.pid = i
		pl.main = self
		pl.look = _look_for(i)
		pl.night = night
		pl.position = (START + Vector2(0.0, -0.8 + 1.6 * i)) * TS
		actors.add_child(pl)
		players.append(pl)
	player = players[0]
	for p in data["profs"]:
		var pr = ProfScript.new()
		pr.setup(p, world, self)
		actors.add_child(pr)
		profs.append(pr)
	if not night:
		_spawn_students()
	hud = HudScript.new()
	hud.main = self
	add_child(hud)
	_update_cameras(true)
	var d: Dictionary = CH.DEPTS[dept]
	var controls := "P1: WASD · E · Shift sprinten · Ctrl schleichen      P2: Pfeile · Enter · . sprinten · - schleichen"
	if night:
		hud.show_overlay("%s · Nacht" % d["char"],
			"Es ist 00:30. %s\n\nDie Professoren drehen mit Taschenlampen ihre Runden. Bleibt ihr zu lange in einem Lichtkegel, seid ihr erwischt. Geht leise (schleichen), versteckt euch (Interagieren) und nutzt die Fähigkeit (Q, nur P1): %s." % [d["night_text"], d["ability"]["name"]],
			controls + "\nQ Fähigkeit · Mausrad / +/- Zoom",
			"Los geht's")
	else:
		hud.show_overlay(LV.level(1)["name"],
			String(LV.level(1)["intro"]) % int(day_time / 60.0),
			controls + "\nMausrad / +/- Zoom",
			"Los geht's")


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


func _look_for(i: int) -> Dictionary:
	if i == 0:
		return Game.look().duplicate(true)
	var order: Array = CH.DEPT_ORDER
	var other: String = order[(order.find(dept) + 1) % order.size()]
	return (Game.looks[other] as Dictionary).duplicate(true)


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
			var st = StudentScript.new()
			st.look = CH.random_student(rng)
			st.zone = z
			st.world = world
			st.position = pos
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
	divider.color = Color(0.02, 0.03, 0.05)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vroot.add_child(divider)
	_layout_views()


func _layout_views() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if split:
		var hw := floorf(vs.x / 2.0)
		vcs[0].position = Vector2.ZERO
		vcs[0].size = Vector2(hw - 2.0, vs.y)
		vcs[1].visible = true
		vcs[1].position = Vector2(hw + 2.0, 0.0)
		vcs[1].size = Vector2(vs.x - hw - 2.0, vs.y)
		divider.visible = true
		divider.position = Vector2(hw - 2.0, 0.0)
		divider.size = Vector2(4.0, vs.y)
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
		elif event.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			dz = -0.2
	if dz != 0.0:
		zoom = clampf(zoom + dz, ZOOM_MIN, ZOOM_MAX)
		for c in cams:
			c.zoom = Vector2(zoom, zoom)


## World position -> screen position in P1's view (used by the HUD ping arrows).
func world_to_screen(p: Vector2) -> Vector2:
	return vcs[0].position + vps[0].get_canvas_transform() * p


# ------------------------------------------------------------------ loop
func busy(i: int) -> bool:
	return minis[i] != null


func _process(delta: float) -> void:
	_update_cameras()
	if state in ["caught", "won", "lost"]:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
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
			bag_watch = maxf(0.0, bag_watch - delta)
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
			if state == "play" and Input.is_action_just_pressed("ability"):
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
	if night:
		hud.toast("Polyterrasse, 00:30", "Der Haupteingang ist sicher zu. Versucht es hinten an der Künstlergasse – und passt auf Prof. Widmer auf.", 6.0)
	else:
		hud.toast("Polyterrasse, 10:15", "Die Uhr läuft. Folgt den gelben Markierungen. Den Ersti-Stand gleich hier vorne erreicht ihr am besten schleichend.", 6.0)


func on_overlay_button() -> void:
	if state == "intro":
		start_game()
	else:
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
		_check_bag_noise(pl.global_position, radius)


func _check_bag_noise(at: Vector2, radius: float) -> void:
	if night or done_tasks.has("ersti"):
		return
	var tk: Dictionary = LV.task("ersti")
	if tk.is_empty():
		return
	var c: Vector2 = (tk["rect"] as Rect2).get_center() * TS
	if at.distance_to(c) > radius + TS:
		return
	bag_watch = 3.0
	if not bag_warned:
		bag_warned = true
		hud.toast("Die Helfer*innen schauen her", "Am Ersti-Stand hat man euch gehört. Wartet kurz und schleicht euch an (P1 Ctrl, P2 -).", 4.0)


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
		if o["use"] == "station" and done_tasks.has(o["task"]):
			continue
		var r: Rect2 = o["rect"]
		var c := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var dd := p.distance_to(c)
		if dd < best:
			best = dd
			nears[i] = o


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
			if dept == "MAVT":
				hud.toast("Dietrich-Set", "Spanner und Haken aus der Werkzeugkiste. Damit bekommt ihr die Labortür im Ostflügel auf.")
			else:
				hud.toast("Schaltplan", "Der Plan zeigt, wie der Sicherungskasten neben dem Labor verdrahtet werden muss, damit das Türschloss stromlos wird.")
		"moodle_prep":
			if has_prep:
				hud.toast("Moodle", "Das Wartungspasswort habt ihr schon. Jetzt zum Kartenleser am Labor.")
			else:
				var on_pw := func():
					has_prep = true
					o["use"] = "info"
					o["info"] = ["Moodle", "Du bist noch eingeloggt. Das Passwort habt ihr bereits."]
					hud.toast("Passwort gefunden", "Im Moodle-Kurs «Robotik-Labor» steht das Wartungspasswort des Kartenlesers. Ab zum Labor!")
				open_minigame("moodle", {"count": 2}, on_pw, i)
		"labdoor":
			_lab_door(i)
		"fusebox":
			if not has_prep:
				hud.toast("Sicherungskasten", "Zu viele Kabel. Ohne Schaltplan wisst ihr nicht, was wohin gehört. An der Ausleihe der Bibliothek liegt einer.")
			else:
				var on_fuse := func():
					_open_lab()
					hud.toast("Klick.", "Das Laborschloss ist stromlos. Drinnen sitzt Prof. Huber noch am Messplatz – wartet, bis er euch den Rücken zudreht.")
				open_minigame("wiring", {"title": "Sicherungskasten umverdrahten", "wires": 5}, on_fuse, i)
		"goal":
			o["taken"] = true
			has_item = true
			world.queue_redraw()
			var names := {"MAVT": "Prototyp-Getriebe", "ITET": "Festplatte mit den Messdaten", "D-INFK": "USB-Stick mit deiner Bachelorarbeit"}
			hud.toast("%s gesichert" % names[dept], "Jetzt nichts wie raus – zurück zur Polybahn!")
		"station":
			_day_station(o, i)


func _lab_door(i: int) -> void:
	match dept:
		"MAVT":
			if not has_prep:
				hud.toast("Verschlossen", "Ein altes Zylinderschloss. Mit Werkzeug ginge das – im Seminarraum steht eine Werkzeugkiste.")
			else:
				var on_lock := func():
					_open_lab()
					hud.toast("Offen!", "Der letzte Stift springt. Drinnen sitzt Prof. Huber – wartet, bis er euch den Rücken zudreht.")
				open_minigame("timing", {"title": "Schloss knacken", "hits": 4, "verb": "Stift", "speed": 280.0}, on_lock, i)
		"ITET":
			hud.toast("Elektronisches Schloss", "Die Tür hängt am Sicherungskasten links im Gang. Dort müsst ihr ansetzen.")
		"D-INFK":
			if not has_prep:
				hud.toast("Kartenleser", "Er will ein Wartungspasswort. Vielleicht steht es im Moodle – der Katalog-PC in der Bibliothek ist noch an.")
			else:
				var on_hack := func():
					_open_lab()
					hud.toast("Zugriff gewährt", "Die Tür summt und springt auf. Drinnen sitzt Prof. Huber – wartet auf euren Moment.")
				open_minigame("sequence", {"title": "Kartenleser hacken", "length": 6}, on_hack, i)


func _open_lab() -> void:
	lab_open = true
	world.open_door("lab")


# ------------------------------------------------------------------ Level 1 (day)
func _day_station(o: Dictionary, i: int) -> void:
	var id: String = o["task"]
	if done_tasks.has(id):
		hud.toast("Erledigt", "Diese Aufgabe habt ihr schon abgeschlossen.", 2.5)
		return
	if open_task[1 - i] == id:
		hud.toast("Besetzt", "%s ist hier schon dran." % KEYS.TAGS[1 - i], 2.5)
		return
	var tk: Dictionary = LV.task(id)
	if tk.is_empty():
		return
	if tk.get("sneak", false) and bag_watch > 0.0:
		hud.toast("Sie schauen gerade her", "Die Helfer*innen am Ersti-Stand haben euch gehört. Kurz warten, dann leise zugreifen.", 3.0)
		return
	if tk.get("coop", false):
		var other = players[1 - i]
		var center: Vector2 = (o["rect"] as Rect2).get_center() * TS
		if busy(1 - i) or other.global_position.distance_to(center) > 2.6 * TS:
			hud.toast("Zu zweit!", "Für einen High Five braucht ihr beide. Kommt zusammen zur Markierung.", 3.0)
			return
		var on_coop := func(): _task_done(tk)
		open_coop_minigame(tk["game"], tk["params"], on_coop)
		return
	open_task[i] = id
	var on_done := func(): _task_done(tk)
	open_minigame(tk["game"], tk["params"], on_done, i)


func _task_done(tk: Dictionary) -> void:
	var id: String = tk["id"]
	if done_tasks.has(id) or state != "play":
		return
	done_tasks[id] = true
	world.queue_redraw()
	var left: int = (LV.level(1)["tasks"] as Array).size() - done_tasks.size()
	if left > 0:
		hud.toast("%s erledigt" % tk["name"], "Noch %d Aufgabe%s." % [left, "" if left == 1 else "n"])
	else:
		_win_day()


func _win_day() -> void:
	_close_minis()
	state = "won"
	for pl in players:
		pl.enabled = false
	var grade := 6.0 - 0.25 * mistakes_total - maxf(0.0, time_played - day_time * 0.5) / 30.0 * 0.25
	grade = clampf(snappedf(grade, 0.25), 1.0, 6.0)
	var verdict := "Hervorragend!" if grade >= 5.5 else ("Gut gemacht." if grade >= 4.5 else ("Bestanden." if grade >= 4.0 else "Knapp daneben."))
	var t := int(time_played)
	hud.show_overlay("Note " + String.num(grade, 2),
		"Erster Tag geschafft: «%s»\n\nZeit: %d:%02d · Fehler in Minigames: %d\nIn der Schweiz ist 6 die Bestnote, ab 4 ist bestanden." % [verdict, t / 60, t % 60, mistakes_total],
		"R neue Runde · M zurück zum Menü", "Nochmals spielen", true)


func _lose_day() -> void:
	_close_minis()
	state = "lost"
	for pl in players:
		pl.enabled = false
	var total: int = (LV.level(1)["tasks"] as Array).size()
	hud.show_overlay("Zeit abgelaufen",
		"Der erste Tag ist vorbei, und es ist noch nicht alles erledigt.\n\nErledigt: %d von %d Aufgaben." % [done_tasks.size(), total],
		"R neue Runde · M zurück zum Menü", "Nochmals versuchen", true)


# ------------------------------------------------------------------ minigames
func _close_minis() -> void:
	var seen: Array = []
	for mg in minis:
		if mg != null and not seen.has(mg):
			seen.append(mg)
			mg.queue_free()
	minis = [null, null]
	open_task = ["", ""]


## Minigame for one player, on that player's half of the screen with that player's keys.
func open_minigame(kind: String, params: Dictionary, on_success: Callable, pid: int = 0) -> void:
	var mg = MiniScript.new()
	mg.screen_side = pid
	mg.keys = KEYS.keys_for(pid)
	mg.labels = KEYS.labels_for(pid)
	minis[pid] = mg
	nears[pid] = null
	players[pid].enabled = false
	_update_cameras()
	add_child(mg)
	mg.open(kind, params, dept)
	mg.mistake.connect(func(): _on_mini_mistake(pid))
	mg.finished.connect(func(ok: bool, _m: int):
		if minis[pid] == mg:
			minis[pid] = null
		open_task[pid] = ""
		if state != "play":
			return
		players[pid].enabled = true
		if ok:
			on_success.call()
		else:
			hud.toast("Abgebrochen", "Ihr könnt es jederzeit nochmals versuchen.", 2.5))


## Minigame for both players at once (full screen, P1 and P2 keys).
func open_coop_minigame(kind: String, params: Dictionary, on_success: Callable) -> void:
	var mg = MiniScript.new()
	mg.screen_side = -1
	mg.keys = KEYS.keys_for(0)
	mg.labels = KEYS.labels_for(0)
	mg.keys2 = KEYS.keys_for(1)
	mg.labels2 = KEYS.labels_for(1)
	for j in 2:
		minis[j] = mg
		nears[j] = null
		players[j].enabled = false
	add_child(mg)
	mg.open(kind, params, dept)
	mg.mistake.connect(func(): _on_mini_mistake(-1))
	mg.finished.connect(func(ok: bool, _m: int):
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
	fx.sound(at, 5.5 * TS, Color(1.0, 0.45, 0.35, 0.7), 1.0)
	if night:
		make_noise(at, 5.5 * TS)
		hud.toast("Zu laut!", "Das hat jemand gehört …", 1.8)
	else:
		_check_bag_noise(at, 5.5 * TS)


# ------------------------------------------------------------------ abilities (night, P1)
func _use_ability() -> void:
	if not night:
		hud.toast(ability["name"], "Fähigkeiten braucht ihr nur nachts.", 2.0)
		return
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
			hud.toast("Klirr!", "Der Schlüssel scheppert über den Boden. Wer in der Nähe ist, schaut nach.", 2.5)
		"blackout":
			blackout_t = 7.0
			hud.toast("Stromausfall!", "Für 7 Sekunden reichen die Taschenlampen nur halb so weit.", 3.0)
		"ping":
			ping_t = 6.0
			hud.toast("Ping", "Alle Professoren für 6 Sekunden geortet.", 2.5)


# ------------------------------------------------------------------ status for HUD / FX
func objectives() -> Array:
	if night:
		var prep := {"MAVT": "Dietrich-Set holen (Seminarraum)", "ITET": "Schaltplan holen (Ausleihe)", "D-INFK": "Passwort im Moodle finden (Bibliothek)"}
		var open := {"MAVT": "Labortür knacken", "ITET": "Sicherungskasten verdrahten", "D-INFK": "Kartenleser hacken"}
		var item := {"MAVT": "Prototyp-Getriebe holen", "ITET": "Festplatte holen", "D-INFK": "USB-Stick holen"}
		return [
			["Ins Hauptgebäude gelangen", entered_hg, true],
			[prep[dept], has_prep, entered_hg],
			[open[dept], lab_open, has_prep],
			[item[dept], has_item, lab_open],
			["Zur Polybahn fliehen", state == "won", has_item],
		]
	var out: Array = []
	for tk in LV.level(1)["tasks"]:
		out.append(["%s · %s" % [tk["name"], tk["where"]], done_tasks.has(tk["id"]), true])
	return out


func _obj_center(pred: Callable) -> Array:
	var out: Array = []
	for o in data["objs"]:
		if pred.call(o):
			out.append((o["rect"] as Rect2).get_center() * TS)
	return out


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
	return _obj_center(func(o): return o.get("use", "") == "station" and not done_tasks.has(o["task"]))


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
		"R nochmals versuchen · M zurück zum Menü", "Nochmals versuchen", true)


func _win_night() -> void:
	state = "won"
	for pl in players:
		pl.enabled = false
	var t := int(time_played)
	var rank := "Phantom der ETH" if spotted_count == 0 else ("Knapp entwischt" if spotted_count < 3 else "Mit Herzklopfen")
	hud.show_overlay("Geschafft!",
		"%s sitzt in der Polybahn, die Beute in der Tasche.\n\nZeit: %d:%02d · Fast entdeckt: %d× · Titel: %s" % [CH.DEPTS[dept]["char"], t / 60, t % 60, spotted_count, rank],
		"R neue Runde · M zurück zum Menü", "Nochmals spielen", true)


func day_total() -> float:
	return day_time
