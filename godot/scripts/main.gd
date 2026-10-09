extends Node2D
## ETH Zentrum – Tag & Nacht. Builds the round from the choices in the menu (Game autoload):
## department (MAVT, ITET, D-INFK) and mode (day: tasks against the clock, night: break into the lab).

const MapData = preload("res://scripts/map_data.gd")
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ProfScript = preload("res://scripts/professor.gd")
const StudentScript = preload("res://scripts/student.gd")
const HudScript = preload("res://scripts/hud.gd")
const FxScript = preload("res://scripts/fx.gd")
const MiniScript = preload("res://scripts/minigame.gd")
const CH = preload("res://scripts/characters.gd")
const TS := 32.0
const START := Vector2(12.5, 43.5)
const STATION := Rect2(0, 41, 10.2, 5)
const DAY_TIME := 300.0
const HG_ZONES := ["Hauptgebäude (HG)", "Haupthalle", "ETH-Bibliothek", "Lounge", "Seminarraum", "Labor · Robotik"]

var data: Dictionary
var world: Node2D
var actors: Node2D
var player: CharacterBody2D
var profs: Array = []
var students: Array = []
var hud: CanvasLayer
var fx: Node2D
var minigame = null

var dept := "MAVT"
var mode := "night"
var night := true
var state := "intro"   # intro, play, minigame, caught, won, lost
var zone := "Polyterrasse"
var time_played := 0.0
var spotted_count := 0
var mistakes_total := 0
var near = null

# night progress
var entered_hg := false
var has_prep := false
var lab_open := false
var has_item := false
# day progress
var done_tasks := {}
var turned_in := false
# abilities
var ability: Dictionary
var cooldown := 0.0
var blackout_t := 0.0
var ping_t := 0.0


func _ready() -> void:
	randomize()
	_setup_input()
	dept = Game.dept
	mode = Game.mode
	night = mode == "night"
	ability = CH.DEPTS[dept]["ability"]
	data = MapData.new().build(mode, dept)
	world = WorldScript.new()
	world.data = data
	world.main = self
	add_child(world)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	fx = FxScript.new()
	fx.main = self
	add_child(fx)
	player = PlayerScript.new()
	player.look = Game.look().duplicate(true)
	player.night = night
	player.position = START * TS
	actors.add_child(player)
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
	var d: Dictionary = CH.DEPTS[dept]
	if night:
		hud.show_overlay("%s · Nacht" % d["char"],
			"Es ist 00:30. %s\n\nDie Professoren drehen mit Taschenlampen ihre Runden. Bleibst du zu lange in einem Lichtkegel, bist du erwischt. Geh leise (Shift), versteck dich (E) und nutz deine Fähigkeit (Q): %s." % [d["night_text"], d["ability"]["name"]],
			"WASD gehen · Shift schleichen · E interagieren · Q Fähigkeit · Mausrad / +/- Zoom",
			"Los geht's")
	else:
		hud.show_overlay("%s · Tag" % d["char"],
			"Es ist 10:15 und %s wartet in der Haupthalle. Du hast %d Minuten für deine Aufgaben: %s\n\nDie gelben Markierungen zeigen dir, wo es etwas zu tun gibt. Jeder Fehler in den Minigames kostet dich etwas an der Note." % [d["prof"], int(DAY_TIME / 60), d["day_text"]],
			"WASD gehen · E interagieren · Mausrad / +/- Zoom",
			"Los geht's")


func _setup_input() -> void:
	var keys := {
		"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"sneak": [KEY_SHIFT], "interact": [KEY_E, KEY_SPACE], "restart": [KEY_R], "start": [KEY_ENTER, KEY_KP_ENTER],
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


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
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
		"play", "minigame":
			time_played += delta
			cooldown = maxf(0.0, cooldown - delta)
			blackout_t = maxf(0.0, blackout_t - delta)
			ping_t = maxf(0.0, ping_t - delta)
			zone = world.zone_at(player.global_position)
			if night and not entered_hg and zone in HG_ZONES:
				entered_hg = true
				hud.toast("Drin!", "Der Hintereingang war offen. Leise jetzt, im Gang patrouilliert Prof. Keller.")
			if not night and time_played >= DAY_TIME:
				_lose_day()
			elif state == "play":
				_update_near()
				if Input.is_action_just_pressed("interact"):
					_interact()
				if Input.is_action_just_pressed("ability"):
					_use_ability()
				if night and has_item and STATION.has_point(player.global_position / TS):
					_win_night()
	hud.refresh(delta)


func start_game() -> void:
	state = "play"
	player.enabled = true
	hud.hide_overlay()
	if night:
		hud.toast("Polyterrasse, 00:30", "Der Haupteingang ist sicher zu. Versuch es hinten an der Künstlergasse – und pass auf Prof. Widmer auf.", 6.0)
	else:
		hud.toast("Polyterrasse, 10:15", "Die Uhr läuft. Folge den gelben Markierungen zu deinen Aufgaben.", 5.0)


func on_overlay_button() -> void:
	if state == "intro":
		start_game()
	else:
		get_tree().reload_current_scene()


func on_overlay_menu() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")


# ------------------------------------------------------------------ interaction
func _update_near() -> void:
	near = null
	if player.hidden_mode:
		return
	var best := 1.3
	var p: Vector2 = player.global_position / TS
	for o in data["objs"]:
		if not o.has("use") or o.get("taken", false) or o.get("opened", false):
			continue
		var r: Rect2 = o["rect"]
		var c := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var dd := p.distance_to(c)
		if dd < best:
			best = dd
			near = o


func _interact() -> void:
	if player.hidden_mode:
		player.hidden_mode = false
		hud.toast("Raus aus dem Versteck", "Schau dich um, bevor du losgehst.", 2.5)
		return
	if near == null:
		return
	var o: Dictionary = near
	match o["use"]:
		"hide":
			player.hidden_mode = true
			hud.toast("Versteckt", "Solange du hier bleibst, sieht dich niemand. E drücken zum Verlassen.", 3.0)
		"info":
			var info: Array = o["info"]
			hud.toast(info[0], info[1])
		"prep":
			o["taken"] = true
			has_prep = true
			world.queue_redraw()
			if dept == "MAVT":
				hud.toast("Dietrich-Set", "Spanner und Haken aus der Werkzeugkiste. Damit bekommst du die Labortür im Ostflügel auf.")
			else:
				hud.toast("Schaltplan", "Der Plan zeigt, wie der Sicherungskasten neben dem Labor verdrahtet werden muss, damit das Türschloss stromlos wird.")
		"moodle_prep":
			if has_prep:
				hud.toast("Moodle", "Das Wartungspasswort hast du schon. Jetzt zum Kartenleser am Labor.")
			else:
				open_minigame("moodle", {"count": 2}, func():
					has_prep = true
					o["use"] = "info"
					o["info"] = ["Moodle", "Du bist noch eingeloggt. Das Passwort hast du bereits."]
					hud.toast("Passwort gefunden", "Im Moodle-Kurs «Robotik-Labor» steht das Wartungspasswort des Kartenlesers. Ab zum Labor!"))
		"labdoor":
			_lab_door()
		"fusebox":
			if not has_prep:
				hud.toast("Sicherungskasten", "Zu viele Kabel. Ohne Schaltplan weisst du nicht, was wohin gehört. An der Ausleihe der Bibliothek liegt einer.")
			else:
				open_minigame("wiring", {"title": "Sicherungskasten umverdrahten", "wires": 5}, func():
					_open_lab()
					hud.toast("Klick.", "Das Laborschloss ist stromlos. Drinnen sitzt Prof. Huber noch am Messplatz – warte, bis er dir den Rücken zudreht."))
		"goal":
			o["taken"] = true
			has_item = true
			world.queue_redraw()
			var names := {"MAVT": "Prototyp-Getriebe", "ITET": "Festplatte mit den Messdaten", "D-INFK": "USB-Stick mit deiner Bachelorarbeit"}
			hud.toast("%s gesichert" % names[dept], "Jetzt nichts wie raus – zurück zur Polybahn!")
		"station":
			_day_station(o)
		"turnin":
			_turn_in()


func _lab_door() -> void:
	match dept:
		"MAVT":
			if not has_prep:
				hud.toast("Verschlossen", "Ein altes Zylinderschloss. Mit Werkzeug ginge das – im Seminarraum steht eine Werkzeugkiste.")
			else:
				open_minigame("timing", {"title": "Schloss knacken", "hits": 4, "verb": "Stift", "speed": 280.0}, func():
					_open_lab()
					hud.toast("Offen!", "Der letzte Stift springt. Drinnen sitzt Prof. Huber – warte, bis er dir den Rücken zudreht."))
		"ITET":
			hud.toast("Elektronisches Schloss", "Die Tür hängt am Sicherungskasten links im Gang. Dort musst du ansetzen.")
		"D-INFK":
			if not has_prep:
				hud.toast("Kartenleser", "Er will ein Wartungspasswort. Vielleicht steht es im Moodle – der Katalog-PC in der Bibliothek ist noch an.")
			else:
				open_minigame("sequence", {"title": "Kartenleser hacken", "length": 6}, func():
					_open_lab()
					hud.toast("Zugriff gewährt", "Die Tür summt und springt auf. Drinnen sitzt Prof. Huber – warte auf deinen Moment."))


func _open_lab() -> void:
	lab_open = true
	world.open_door("lab")


func _day_station(o: Dictionary) -> void:
	var id: String = o["task"]
	if done_tasks.has(id):
		hud.toast("Erledigt", "Diese Aufgabe hast du schon abgeschlossen.", 2.5)
		return
	for tk in CH.DAY_TASKS[dept]:
		if tk["id"] == id:
			open_minigame(tk["game"], tk["params"], func():
				done_tasks[id] = true
				var left: int = CH.DAY_TASKS[dept].size() - done_tasks.size()
				if left > 0:
					hud.toast("%s erledigt" % tk["name"], "Noch %d Aufgabe%s." % [left, "" if left == 1 else "n"])
				else:
					hud.toast("Alles erledigt!", "Zurück zu %s in der Haupthalle." % CH.DEPTS[dept]["prof"]))
			return


func _turn_in() -> void:
	var left: int = CH.DAY_TASKS[dept].size() - done_tasks.size()
	var prof: String = CH.DEPTS[dept]["prof"]
	if left > 0:
		hud.toast(prof, "«Sie haben noch %d Aufgabe%s offen. Die Zeit läuft!»" % [left, "" if left == 1 else "n"])
		return
	turned_in = true
	state = "won"
	player.enabled = false
	var grade := 6.0 - 0.25 * mistakes_total - maxf(0.0, time_played - 150.0) / 30.0 * 0.25
	grade = clampf(snappedf(grade, 0.25), 1.0, 6.0)
	var verdict := "Hervorragend!" if grade >= 5.5 else ("Gut gemacht." if grade >= 4.5 else ("Bestanden." if grade >= 4.0 else "Knapp daneben."))
	var t := int(time_played)
	hud.show_overlay("Note " + String.num(grade, 2),
		"%s nickt: «%s»\n\nZeit: %d:%02d · Fehler in Minigames: %d\nIn der Schweiz ist 6 die Bestnote, ab 4 ist bestanden." % [prof, verdict, t / 60, t % 60, mistakes_total],
		"R neue Runde · M zurück zum Menü", "Nochmals spielen", true)


func _lose_day() -> void:
	if minigame:
		minigame.queue_free()
		minigame = null
	state = "lost"
	player.enabled = false
	hud.show_overlay("Zeit abgelaufen",
		"Die Abgabe ist geschlossen. %s schüttelt den Kopf: «Das war leider nichts. Note 3.»\n\nErledigt: %d von %d Aufgaben." % [CH.DEPTS[dept]["prof"], done_tasks.size(), CH.DAY_TASKS[dept].size()],
		"R neue Runde · M zurück zum Menü", "Nochmals versuchen", true)


# ------------------------------------------------------------------ minigames
func open_minigame(kind: String, params: Dictionary, on_success: Callable) -> void:
	state = "minigame"
	player.enabled = false
	near = null
	minigame = MiniScript.new()
	add_child(minigame)
	minigame.open(kind, params, dept)
	minigame.mistake.connect(_on_mini_mistake)
	minigame.finished.connect(func(ok: bool, _m: int):
		minigame = null
		if state != "minigame":
			return
		state = "play"
		player.enabled = true
		if ok:
			on_success.call()
		else:
			hud.toast("Abgebrochen", "Du kannst es jederzeit nochmals versuchen.", 2.5))


func _on_mini_mistake() -> void:
	mistakes_total += 1
	if night:
		make_noise(player.global_position, 5.5 * TS)
		hud.toast("Zu laut!", "Das hat jemand gehört …", 1.8)


func make_noise(at: Vector2, radius: float) -> void:
	for p in profs:
		var d: float = p.global_position.distance_to(at)
		var r := radius if world.line_clear(p.global_position, at) else radius * 0.5
		if d < r:
			p.hear(at)


# ------------------------------------------------------------------ abilities
func _use_ability() -> void:
	if not night:
		hud.toast(ability["name"], "Fähigkeiten brauchst du nur nachts.", 2.0)
		return
	if cooldown > 0.0:
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
	for tk in CH.DAY_TASKS[dept]:
		out.append(["%s · %s" % [tk["name"], tk["where"]], done_tasks.has(tk["id"]), true])
	out.append(["Zurück zu %s (Haupthalle)" % CH.DEPTS[dept]["prof"], turned_in, done_tasks.size() == CH.DAY_TASKS[dept].size()])
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
	if done_tasks.size() < CH.DAY_TASKS[dept].size():
		return _obj_center(func(o): return o.get("use", "") == "station" and not done_tasks.has(o["task"]))
	return [Vector2(55.5, 34.6) * TS]


func time_left() -> float:
	return maxf(0.0, DAY_TIME - time_played)


func max_meter() -> float:
	var m := 0.0
	for p in profs:
		m = maxf(m, p.meter)
	return m


func spotted() -> void:
	spotted_count += 1


func caught(prof) -> void:
	if state != "play" and state != "minigame":
		return
	if minigame:
		minigame.queue_free()
		minigame = null
	state = "caught"
	player.enabled = false
	player.hidden_mode = false
	hud.show_overlay("Erwischt!", "%s: «%s»" % [prof.pname, prof.quote],
		"R nochmals versuchen · M zurück zum Menü", "Nochmals versuchen", true)


func _win_night() -> void:
	state = "won"
	player.enabled = false
	var t := int(time_played)
	var rank := "Phantom der ETH" if spotted_count == 0 else ("Knapp entwischt" if spotted_count < 3 else "Mit Herzklopfen")
	hud.show_overlay("Geschafft!",
		"%s sitzt in der Polybahn, die Beute in der Tasche.\n\nZeit: %d:%02d · Fast entdeckt: %d× · Titel: %s" % [CH.DEPTS[dept]["char"], t / 60, t % 60, spotted_count, rank],
		"R neue Runde · M zurück zum Menü", "Nochmals spielen", true)


func day_total() -> float:
	return DAY_TIME
