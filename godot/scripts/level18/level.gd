extends Node2D
## Elective "Ersti-Fest" (block "W", number 18): the Ersti Fest (ESF) of the VSETH in the Mensa, at night.
## Not part of the story: started from the transcript (Wahlfächer) whenever the players like.
##
## Three challenges, in this order:
##   1. Getting in (sneak_game.gd): the party is sold out and the bouncer lets nobody past the
##      rope. At the coat rack next to the entrance the two climb into one long coat, one on the
##      other's shoulders, and walk past him as one tall guest. Together, or not at all.
##   2. The DJ battle (dj_game.gd): they take over the DJ table and play against each other,
##      notes falling down for the keys of each player's side of the keyboard.
##   3. The dance battle (dance_game.gd): they dance one after the other in front of the camera,
##      three rounds of five seconds, and the crazier dance gets the higher score.
## The level is won when all three are done; who won the two battles is announced at the end.
##
## The Mensa becomes the club in build_map; the night is a dark sheet that this node draws over
## the day map and under the characters. All positions are in tiles (1 tile = 32 px).

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const CH = preload("res://scripts/characters.gd")
const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const Cutscene = preload("res://scripts/cutscene.gd")
const Person = preload("fest_person.gd")
const FestSfx = preload("fest_sfx.gd")
const SneakGame = preload("sneak_game.gd")
const DjGame = preload("dj_game.gd")
const DanceGame = preload("dance_game.gd")

const DEF := {
	"name": "Ersti-Fest",
	"tag": "WAHLFACH · VSETH",
	"mode": "day",
	"sky": "night",      # the loading screen of the night at Hönggerberg (level 5): the ETH-Link
	"ride": "ethlink",   # drives up at night, instead of the Polybahn
	"motif": false,      # ... and without the round picture (it would be the dome of the Hauptgebäude)
	# Ambience (scripts/ambience.gd): outside it is a night in town; inside, the party makes its own
	# sound (fest_sfx.gd), and there is no music from outside the level
	"ambience": {"music": false, "zones": {"Mensa Polyterrasse": "none"}},
	"time": 900.0,
	"course": "851-0018-00 L", "ects": 1, "block": "W",
	"start": Vector2(22.5, 60.6),   # on the Polyterrasse, in front of the Mensa
	"timer_title": "DAS FEST ENDET IN",
	"intro": "Das Ersti-Fest in der Mensa ist ausverkauft, und ihr steht draussen. Heute zählt nur eines: reinkommen, das DJ-Pult kapern und die Tanzfläche gewinnen.",
	"hint": "Am DJ-Pult und auf der Tanzfläche spielt ihr gegeneinander. Für das Dance-Battle braucht ihr die Kamera und etwas Platz.",
	"start_toast": ["Ausverkauft!", "So lässt euch der Türsteher nicht rein. Schaut euch die Garderobe rechts neben dem Eingang an."],
	"win_title": "Was für ein Fest!",
	"win_text": "%s & %s haben das Ersti-Fest gerockt.",
	"lose_title": "Das Fest ist vorbei",
	"lose_text": "Die Lichter gehen an, und ihr habt nicht alles geschafft.",
	"tips": [
		"Zwei Erstis in einem Mantel sind ein grosser Gast.",
		"Im DJ-Battle zählt die Serie: Wer nichts verpasst, bekommt bis zu doppelte Punkte.",
		"Im Dance-Battle gilt: je verrückter, desto besser. Arme hoch!",
	],
	"tasks": [
		{"id": "sneak", "name": "Reinkommen", "where": "zu zweit am Türsteher vorbei: Garderobe neben dem Eingang", "type": "level"},
		{"id": "dj", "name": "DJ-Pult kapern", "where": "DJ-Battle gegeneinander, hinten in der Mensa", "type": "level"},
		{"id": "dance", "name": "Dance-Battle", "where": "auf der Tanzfläche, vor der Kamera", "type": "level"},
	],
}

# ---- tuning
const REACH := 0.9            # tiles: this close to a place it can be used, from any side
const PARTNER_DIST := 3.0     # tiles: everything here needs the second player this close
const BPM := 120.0

# ---- places
const MENSA := Rect2(13.0, 65.0, 20.0, 12.0)
const ROPE := Rect2(21.0, 64.0, 4.0, 1.0)             # across the door, until they are in
const BOUNCER_AT := Vector2(22.5, 63.55)
const BOUNCER_ASIDE := Vector2(20.4, 63.55)
const RACK := Rect2(25.7, 62.15, 1.7, 0.7)            # coat rack on the Polyterrasse
const INSIDE := [Vector2(22.1, 65.9), Vector2(23.2, 65.9)]   # where they stand after getting in
const DJ_TABLE := Rect2(19.5, 74.3, 6.0, 1.2)
const DJ_AT := Vector2(22.5, 76.3)
const SPEAKERS := [Rect2(17.4, 73.9, 1.7, 1.9), Rect2(25.9, 73.9, 1.7, 1.9)]
const BAR := Rect2(13.2, 67.0, 1.3, 5.5)
const SOFAS := [Rect2(30.4, 67.4, 2.2, 1.0), Rect2(30.4, 70.6, 2.2, 1.0)]
const FLOOR := Rect2(17.0, 67.0, 11.0, 6.0)           # the dance floor
const FLOOR_MID := Vector2(22.5, 70.0)
const QUEUE := [Vector2(19.6, 62.7), Vector2(18.6, 62.7), Vector2(17.6, 62.7), Vector2(16.5, 62.7), Vector2(15.4, 62.7)]
const DANCERS := [Vector2(18.2, 68.0), Vector2(20.0, 67.6), Vector2(25.2, 67.7), Vector2(26.9, 68.4), Vector2(17.8, 71.2),
	Vector2(27.0, 71.4), Vector2(19.6, 72.4), Vector2(25.6, 72.5), Vector2(15.6, 69.6), Vector2(29.2, 69.4)]
const BOUNCER_LOOK := {"skin": "c68863", "hair": "1a1a1a", "hair_style": "glatze", "top": "15161c", "top_style": "jacket",
	"accent": "15161c", "pants": "15161c", "shoes": "0c0c10", "acc": ["glasses"]}
const DJ_LOOK := {"skin": "f1c9a5", "hair": "6b2d8f", "hair_style": "cap", "top": "ff5d8f", "top_style": "hoodie",
	"accent": "ffc93c", "pants": "23264a", "shoes": "e9ece8", "acc": ["headphones"]}
const LIGHTS := ["ff5d8f", "4d8dff", "3ddc97", "ffc93c", "9b6bff", "ff8c42"]

var main
var t := 0.0
var rng := RandomNumberGenerator.new()
var sfx
var bouncer
var dj
var guests: Array = []
var dj_scores: Array = []     # [P1, P2] once the DJ battle is over
var dance_scores: Array = []
var hint_bouncer := false


# ================================================================== map
## Called by map_data.gd: the Mensa becomes the club.
static func build_map(md) -> void:
	md.objs = md.objs.filter(func(o): return not (o["kind"] in ["mcounter", "mtable"]))
	md.R("l18_rope", ROPE.position.x, ROPE.position.y, ROPE.size.x, ROPE.size.y, {"door": "fest"})
	md.R("l18_rack", RACK.position.x, RACK.position.y, RACK.size.x, RACK.size.y)
	md.R("l18_dj", DJ_TABLE.position.x, DJ_TABLE.position.y, DJ_TABLE.size.x, DJ_TABLE.size.y)
	for sp in SPEAKERS:
		var r: Rect2 = sp
		md.R("l18_speaker", r.position.x, r.position.y, r.size.x, r.size.y)
	md.R("l18_bar", BAR.position.x, BAR.position.y, BAR.size.x, BAR.size.y, {"use": "info", "label": "Bar ansehen",
		"info": ["Bar", "Rivella, Mate und ein Schild: «Erstis bekommen zwei Mate zum Preis von drei.»"]})
	for so in SOFAS:
		var r2: Rect2 = so
		md.R("l18_sofa", r2.position.x, r2.position.y, r2.size.x, r2.size.y)
	for l in md.labels:
		if l["t"] == "MENSA POLYTERRASSE":
			l["t"] = ""
	# nobody strolls through the party who does not belong to it
	md.student_zones = md.student_zones.filter(func(z): return not (z[0] == 13 and z[1] == 65))


# ================================================================== setup
func _ready() -> void:
	z_index = -5   # above the map, below the characters
	rng.randomize()
	sfx = FestSfx.new()
	add_child(sfx)
	bouncer = _person(BOUNCER_LOOK.duplicate(true), BOUNCER_AT, ART.FRONT, false)
	dj = _person(DJ_LOOK.duplicate(true), DJ_AT, ART.BACK, true)
	for q in QUEUE:
		_person(CH.random_student(rng), q, ART.RIGHT, false)
	for d in DANCERS:
		guests.append(_person(CH.random_student(rng), d, ART.FRONT, true))


func _person(look: Dictionary, at: Vector2, facing: int, dancing: bool):
	var p = Person.new()
	p.main = main
	p.look = look
	p.look["acc"] = (p.look.get("acc", []) as Array).filter(func(a): return a != "laptop" and a != "backpack")
	p.facing = facing
	p.dancing = dancing
	p.beat = 60.0 / BPM
	p.position = at * TS
	main.actors.add_child(p)
	return p


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


# ================================================================== opening the three games
## Distance from `p` to the nearest point of `r`, in tiles.
func _dist_to(p: Vector2, r: Rect2) -> float:
	return p.distance_to(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))


func _together(pid: int, what: String) -> bool:
	var other := 1 - pid
	if main.busy(other):
		main.hud.toast("Moment!", "%s ist gerade beschäftigt." % Game.name_of(other), 2.5)
		return false
	if main.players[other].global_position.distance_to(main.players[pid].global_position) > PARTNER_DIST * TS:
		main.hud.toast("Das geht nur zu zweit", what % Game.name_of(other), 4.0)
		return false
	return true


## Puts a full-screen game for both players on the screen, the way main.open_coop_minigame does,
## and stops the map behind it from being drawn while it is open (it would cost the frame rate).
func _open(mg: Node) -> void:
	for j in 2:
		main.minis[j] = mg
		main.nears[j] = null
		main.players[j].enabled = false
	main.add_child(mg)
	mg.open()
	var modes: Array = []
	for vp in main.vps:
		modes.append(vp.render_target_update_mode)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mg.tree_exited.connect(func():
		if not is_instance_valid(main):
			return
		for i in main.vps.size():
			if is_instance_valid(main.vps[i]):
				main.vps[i].render_target_update_mode = modes[i])


## Takes the game off again. False if it was not ours any more or the level is over.
func _close(mg: Node) -> bool:
	if main.minis[0] != mg and main.minis[1] != mg:
		return false
	for j in 2:
		if main.minis[j] == mg:
			main.minis[j] = null
	if main.state != "play":
		return false
	for pl in main.players:
		pl.enabled = true
	return true


# ------------------------------------------------------------------ 1 · getting in
func _use_rack(pid: int) -> void:
	if not _together(pid, "Für den Manteltrick braucht es zwei: %s muss auch zur Garderobe kommen."):
		return
	var mg = SneakGame.new()
	mg.legs = pid
	mg.sfx = sfx
	_open(mg)
	mg.mistake.connect(func(): main.mistakes_total += 1)
	mg.finished.connect(func(ok: bool):
		if not _close(mg):
			return
		if ok:
			_let_in()
		else:
			main.hud.toast("Abgebrochen", "Der Mantel hängt noch an der Garderobe.", 2.5))


func _let_in() -> void:
	main.world.open_door("fest")
	bouncer.glide(BOUNCER_ASIDE * TS)
	bouncer.facing = ART.RIGHT
	for pid in 2:
		main.players[pid].global_position = (INSIDE[pid] as Vector2) * TS
		main.players[pid].dir = PI / 2.0
		main.players[pid].facing = ART.FRONT
	sfx.beat_on(-20.0)   # the party, from now on in the background
	main._coop_done("sneak")
	main.hud.toast("Drin!", "Niemand hat etwas gemerkt. Jetzt nach hinten zum DJ-Pult: Das gehört heute euch.", 6.0)


# ------------------------------------------------------------------ 2 · the DJ battle
func _use_dj(pid: int) -> void:
	if not _together(pid, "Ein Battle braucht zwei: %s muss auch ans DJ-Pult kommen."):
		return
	dj.say("!", 2.0)
	var mg = DjGame.new()
	mg.sfx = sfx
	_open(mg)
	mg.finished.connect(func(scores: Array):
		var ok := _close(mg)
		sfx.beat_on(-20.0)
		if not ok:
			return
		if scores.is_empty():
			main.hud.toast("Abgebrochen", "Der DJ schaut euch böse an. Das Pult ist noch frei.", 2.5)
			return
		dj_scores = scores
		Track.use(self, ["pose"], false)   # wake the camera for the dance battle
		main._coop_done("dj")
		var w := _winner(scores)
		var who: String = "Unentschieden am Pult" if w < 0 else "DJ %s legt besser auf" % Game.name_of(w)
		main.hud.toast(who, "%d zu %d. Die Menge will mehr: ab in die Mitte der Tanzfläche zum Dance-Battle!" % [int(scores[0]), int(scores[1])], 7.0))


# ------------------------------------------------------------------ 3 · the dance battle
func _use_floor(pid: int) -> void:
	if not _together(pid, "Zum Battle gehören zwei: %s muss auch auf die Tanzfläche kommen."):
		return
	var mg = DanceGame.new()
	mg.sfx = sfx
	mg.first = pid
	_open(mg)
	mg.finished.connect(func(totals: Array):
		var ok := _close(mg)
		sfx.beat_on(-20.0)
		if not ok:
			return
		if totals.is_empty():
			main.hud.toast("Abgebrochen", "Die Tanzfläche wartet.", 2.5)
			return
		dance_scores = totals
		Track.release(self)
		main._coop_done("dance"))


## 0 or 1, or -1 for a draw.
func _winner(pair: Array) -> int:
	if pair.size() < 2 or is_equal_approx(float(pair[0]), float(pair[1])):
		return -1
	return 0 if float(pair[0]) > float(pair[1]) else 1


# ================================================================== hooks called by main.gd
func update_near(pid: int) -> void:
	var p: Vector2 = main.players[pid].global_position / TS
	if not main.done[pid].has("sneak"):
		if _dist_to(p, RACK) < REACH:
			main.nears[pid] = {"use": "level", "act": "rack", "label": "In den Mantel steigen (zu zweit)", "rect": RACK}
		elif _dist_to(p, ROPE) < REACH + 0.5:
			main.nears[pid] = {"use": "level", "act": "bouncer", "label": "Mit dem Türsteher reden", "rect": ROPE}
	elif not main.done[pid].has("dj"):
		if _dist_to(p, DJ_TABLE) < REACH:
			main.nears[pid] = {"use": "level", "act": "dj", "label": "DJ-Pult kapern (zu zweit)", "rect": DJ_TABLE}
	elif not main.done[pid].has("dance"):
		if p.distance_to(FLOOR_MID) < 1.8:
			main.nears[pid] = {"use": "level", "act": "floor", "label": "Dance-Battle starten (zu zweit)",
				"rect": Rect2(FLOOR_MID - Vector2(1.5, 1.5), Vector2(3.0, 3.0))}


func interact(pid: int, o: Dictionary) -> void:
	match o["act"]:
		"rack":
			_use_rack(pid)
		"bouncer":
			bouncer.say("!", 2.0)
			main.hud.toast("Türsteher", "«Ausverkauft. Ohne Bändeli kommt hier keiner rein.» Er mustert euch. «Und für die Garderobe da drüben seid ihr eh zu klein.»", 6.0)
		"dj":
			_use_dj(pid)
		"floor":
			_use_floor(pid)


## Goal markers for the HUD and the mini map: [position in px, colour].
func goal_positions(id: String, _n0: bool, _n1: bool) -> Array:
	match id:
		"sneak":
			return [[RACK.get_center() * TS, UI.YELLOW]]
		"dj":
			if main.done[0].has("sneak"):
				return [[DJ_TABLE.get_center() * TS, UI.YELLOW]]
		"dance":
			if main.done[0].has("dj"):
				return [[FLOOR_MID * TS, UI.YELLOW]]
	return []


## Where the way of a picked task leads: always to what has to be done next.
func task_targets(_id: String, pid: int) -> Array:
	if not main.done[pid].has("sneak"):
		return [Vector2(RACK.get_center().x, RACK.position.y - 0.4) * TS]
	if not main.done[pid].has("dj"):
		return [Vector2(DJ_TABLE.get_center().x, DJ_TABLE.position.y - 0.5) * TS]
	return [FLOOR_MID * TS]


## Called by main.gd when all three are done: who won what, then the usual end of a level.
func finale(done: Callable) -> void:
	main.state = "cutscene"
	main.hud.visible = false
	for pl in main.players:
		pl.enabled = false
	var a := _winner(dj_scores)
	var b := _winner(dance_scores)
	var legend := "UNENTSCHIEDEN"
	var points := [0, 0]
	for w in [a, b]:
		if w >= 0:
			points[w] += 1
	if points[0] != points[1]:
		legend = Game.name_of(0 if points[0] > points[1] else 1).to_upper()
	var steps := [
		{"say": -1, "name": "DJ-Battle", "text": "%s %d  ·  %s %d" % [Game.name_of(0), int(dj_scores[0]), Game.name_of(1), int(dj_scores[1])]},
		{"say": -1, "name": "Dance-Battle", "text": "%s %.1f  ·  %s %.1f" % [Game.name_of(0), float(dance_scores[0]), Game.name_of(1), float(dance_scores[1])]},
		{"title": legend, "sub": "Legende des Ersti-Fests" if legend != "UNENTSCHIEDEN" else "Zwei Legenden des Ersti-Fests", "color": UI.YELLOW, "sfx": "fanfare", "time": 4.0},
	]
	var cs = Cutscene.new()
	main.add_child(cs)
	cs.play(steps, func():
		main.hud.visible = true
		sfx.beat_off()
		done.call())


# ================================================================== drawing
func _px(r: Rect2) -> Rect2:
	return Rect2(r.position * TS, r.size * TS)


func _draw() -> void:
	var beat := 60.0 / BPM
	var pump := pow(1.0 - fmod(t, beat) / beat, 2.0)
	var step := int(t / beat)
	# the night: one dark sheet over the day map. Characters are drawn above it and stay bright.
	draw_rect(Rect2(0, 0, 112.0 * TS, 84.0 * TS), Color(0.02, 0.03, 0.11, 0.62))
	# string lights over the way to the door
	for i in 24:
		var lx := (15.0 + i * 0.62) * TS
		var ly := 61.75 * TS + sin(i * 0.9) * 5.0
		draw_circle(Vector2(lx, ly), 3.0, Color(Color(LIGHTS[i % LIGHTS.size()]), 0.65 + 0.35 * sin(t * 3.0 + i)))
	# the names in neon on the wall beside the door
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(14.2, 64.75) * TS, UI.T("ERSTI-FEST"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(UI.PINK, 0.75 + 0.25 * sin(t * 5.0)))
	draw_string(font, Vector2(26.2, 64.75) * TS, "VSETH", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(UI.BLUE, 0.75 + 0.25 * sin(t * 5.0 + 1.5)))
	# the club: light on the floor that changes with the beat
	var m := _px(MENSA)
	draw_rect(m, Color(0.05, 0.02, 0.12, 0.35))
	var fl := _px(FLOOR)
	for y in int(FLOOR.size.y):
		for x in int(FLOOR.size.x):
			var on := (x * 3 + y * 5 + step) % 4 == 0
			draw_rect(Rect2(fl.position.x + x * TS + 1.5, fl.position.y + y * TS + 1.5, TS - 3.0, TS - 3.0),
				Color(Color(LIGHTS[(x + y * 2 + step) % LIGHTS.size()]), 0.5 if on else 0.13))
	for i in 5:   # spots wandering over the floor
		var c := fl.get_center() + Vector2(sin(t * 0.7 + i * 1.9) * fl.size.x * 0.42, cos(t * 0.9 + i * 2.3) * fl.size.y * 0.4)
		draw_circle(c, 34.0 + pump * 8.0, Color(Color(LIGHTS[i]), 0.1 + 0.06 * pump))
	if main != null and main.done[0].has("dj") and not main.done[0].has("dance"):
		# the circle the crowd leaves free for the battle
		draw_arc(FLOOR_MID * TS, 1.6 * TS, 0.0, TAU, 40, Color(UI.YELLOW, 0.5 + 0.4 * sin(t * 5.0)), 3.0)
	_draw_club(pump)
	_draw_entrance()


func _draw_club(pump: float) -> void:
	# DJ table with two turntables and the mixer
	var d := _px(DJ_TABLE)
	draw_rect(Rect2(d.position + Vector2(2.5, 3.5), d.size), Color(0, 0, 0, 0.4))
	draw_rect(d, Color("15101f"))
	draw_rect(d, Color("5a4a8a"), false, 2.0)
	for i in 2:
		var c := Vector2(d.position.x + d.size.x * (0.2 + 0.6 * i), d.get_center().y)
		draw_circle(c, 14.0, Color("08060f"))
		draw_circle(c, 5.0, Color(KEYS.TAG_COLORS[i]))
		draw_line(c, c + Vector2.from_angle(t * 4.0 * (1.0 if i == 0 else -1.0)) * 13.0, Color(1, 1, 1, 0.3), 1.5)
	draw_rect(Rect2(d.get_center().x - 20.0, d.position.y + 6.0, 40.0, d.size.y - 12.0), Color("241a3d"))
	for j in 5:
		draw_rect(Rect2(d.get_center().x - 16.0 + j * 7.0, d.get_center().y + 8.0 - (4.0 + 10.0 * absf(sin(t * 8.0 + j))) * (0.4 + 0.6 * pump), 4.0, (4.0 + 10.0 * absf(sin(t * 8.0 + j))) * (0.4 + 0.6 * pump)), UI.GREEN)
	for sp in SPEAKERS:
		var r := _px(sp)
		draw_rect(Rect2(r.position + Vector2(2.5, 3.5), r.size), Color(0, 0, 0, 0.4))
		draw_rect(r, Color("0b0716"))
		draw_rect(r, Color("3a2d5c"), false, 2.0)
		for j in 2:
			var cc := Vector2(r.get_center().x, r.position.y + r.size.y * (0.3 + 0.42 * j))
			draw_circle(cc, 10.0 + pump * 2.5, Color("241a3d"))
			draw_circle(cc, 5.0 + pump * 2.5, Color("5a4a8a"))
	# the bar with its bottles
	var b := _px(BAR)
	draw_rect(Rect2(b.position + Vector2(2.5, 3.5), b.size), Color(0, 0, 0, 0.4))
	draw_rect(b, Color("3b2a1e"))
	draw_rect(b.grow(-3.0), Color("6b4a2f"))
	for i in 8:
		draw_rect(Rect2(b.position.x + 8.0, b.position.y + 10.0 + i * 20.0, 7.0, 12.0), Color(Color(LIGHTS[i % LIGHTS.size()]), 0.9))
		draw_rect(Rect2(b.position.x + 10.0, b.position.y + 6.0 + i * 20.0, 3.0, 5.0), Color("e9ece8"))
		draw_circle(Vector2(b.position.x + 28.0, b.position.y + 16.0 + i * 20.0), 4.0, Color(1, 1, 1, 0.25))
	for so in SOFAS:
		var s := _px(so)
		draw_rect(Rect2(s.position + Vector2(2.5, 3.5), s.size), Color(0, 0, 0, 0.4))
		draw_rect(s, Color("5d3f7a"))
		draw_rect(Rect2(s.position.x, s.position.y, s.size.x, 9.0), Color("46305c"))
		draw_rect(Rect2(s.get_center().x - 1.0, s.position.y + 9.0, 2.0, s.size.y - 9.0), Color("46305c"))


func _draw_entrance() -> void:
	# light falling out of the door
	var r := _px(ROPE)
	draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x + 30.0, r.position.y - 60.0), Vector2(r.position.x - 30.0, r.position.y - 60.0)]),
		Color(1.0, 0.45, 0.7, 0.1 + 0.05 * sin(t * 6.0)))
	# the rope across the door, until they are in
	for px in [r.position.x + 5.0, r.end.x - 5.0]:
		draw_circle(Vector2(px, r.position.y + 14.0), 6.0, Color("8a6f25"))
		draw_circle(Vector2(px, r.position.y + 12.0), 5.0, Color("c9a23c"))
	if main != null and not main.done[0].has("sneak"):
		var pts := PackedVector2Array()
		for i in 13:
			var u := i / 12.0
			pts.append(Vector2(lerpf(r.position.x + 5.0, r.end.x - 5.0, u), r.position.y + 12.0 + sin(u * PI) * 7.0))
		draw_polyline(pts, Color("b7352d"), 4.0)
	# the coat rack: a rail, a few jackets, and one very long coat with a hat
	var k := _px(RACK)
	draw_rect(Rect2(k.position + Vector2(2.5, 3.5), k.size), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(k.position.x, k.position.y, 3.0, k.size.y), Color("8d98a1"))
	draw_rect(Rect2(k.end.x - 3.0, k.position.y, 3.0, k.size.y), Color("8d98a1"))
	draw_rect(Rect2(k.position.x, k.position.y + 2.0, k.size.x, 3.0), Color("c3ccd2"))
	var jackets := ["2f4f8f", "3e7d4f", "a33b5c"]
	for i in jackets.size():
		draw_rect(Rect2(k.position.x + 6.0 + i * 9.0, k.position.y + 5.0, 7.0, 13.0), Color(jackets[i]))
	var coat := Rect2(k.end.x - 20.0, k.position.y + 5.0, 12.0, 24.0)
	draw_rect(coat, Color("c8a878"))
	draw_rect(Rect2(coat.position.x, coat.position.y + 10.0, coat.size.x, 2.0), Color("8f7650"))
	draw_rect(Rect2(coat.position.x - 3.0, coat.position.y - 5.0, coat.size.x + 6.0, 2.0), Color("3b2a1e"))
	draw_rect(Rect2(coat.position.x + 1.0, coat.position.y - 9.0, coat.size.x - 2.0, 5.0), Color("3b2a1e"))
