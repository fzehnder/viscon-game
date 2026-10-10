extends Node2D
## Level 3 · Polyball (day mode, two players). Definition (DEF), ball furniture (build_map) and logic.
## Everything of this level lives in this folder (found by levels.gd through the folder name).
##
## A late November evening, the Polyball fills the Hauptgebäude. The players want the badge of a
## professor: it is in the inner pocket of his coat, and the coat hangs in the cloakroom.
##
## New here: disguises. Each one only works in its zone: evening wear in the ballroom (the whole
## Hauptgebäude), the kitchen whites in the kitchen (the Mensa). In the right clothes the light
## cones ignore you, in the wrong ones (or in your hoodie) the suspicion bar fills faster than
## normal. Outside those zones clothes make no difference.
## This is a factor on the Opp system (opp.gd), not a system of its own, and opp.gd is untouched:
## every physics frame, after the Opps have looked around, _apply_disguises() scales what each of
## them added to its bar by how suspicious the people in its view are.
## The security people, the cloakroom attendant and the cooks are ordinary opp.gd NPCs that are on
## guard from the start. Whoever they catch is thrown out, the level goes on. Opps from earlier
## levels stand at the bar and around the dance floor ("opp_spots"); they do not recognise you in
## evening wear either, but if one of them catches you the level is over, as everywhere.
##
## Three tasks can be played in front of the webcam (autoload Track, see tracker/README.md), and
## each of them works with the keys as well, so the level never depends on a camera:
##   dance floor  strike the poses that are shown, on the beat (kamera_spiel.gd, "tanz"): both
##                players if two people are in the picture, one for both if there is only one
##   Prof badge   pull it out of the pocket with two fingers and a steady hand ("badge"); the
##                keyboard version is the sequence minigame
##   buffet       the timing minigame; opening your mouth wide snaps as well as the key does
##
## All positions are in tiles (1 tile = 32 px) unless a name ends in _px.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const OPP = preload("res://scripts/opp.gd")
const Vorlage = preload("res://scripts/level3/vorlage.gd")
const KameraSpiel = preload("res://scripts/level3/kamera_spiel.gd")
const Fund = preload("res://scripts/level3/fund.gd")
const Abgang = preload("res://scripts/level3/abgang.gd")
const TM = preload("res://scripts/track_math.gd")

# ---- disguise (tuning)
const FACTOR_WRONG := 1.8               # wrong clothes or hoodie in a zone: the suspicion bar fills this much faster
const CHANGE_TIME := 1.6                # seconds to change clothes: you stand still, and anyone watching gets suspicious
const GUARD_CALM := 6.0                 # seconds a guard leaves you alone after throwing you out
const STUN := 1.4                       # seconds until you can move again after being thrown out
const METER_DECAY := 0.35               # per second, how fast a bar drains with nobody suspicious in view (as in opp.gd)

# ---- tasks (tuning)
const FRACK_HITS := 2                   # timing minigame for the tailcoat
const FRACK_SPEED := 300.0
const ARMBAND_LEN := 6                  # symbols on the wristband
const ARMBAND_SOLO := false             # true: the builder is shown the arrows first, as in the normal sequence minigame (to play alone)
const BADGE_SEQ := 5                    # length of the sequence for the inner pocket
const BUFFET_HITS := 3                  # timing minigame at the buffet
const BUFFET_SPEED := 280.0             # slower than usual: a mouth is not as quick as a key
const MOUTH_OPEN := 0.45                # buffet with the camera: mouth this far open (Track "mouth", 0..1) = snap
const MOUTH_SHUT := 0.25                # ... and it has to close this far before the next snap
const TANZ_RADIUS := 2.6                # tiles around the middle of the dance floor in which both have to stand
const PREWARM := true                   # start the camera tracker with the level (camera stays off), so it is ready in time

# ---- zones: where which disguise is the right one
const ZONES := {
	"saal": [Rect2(38, 20, 31, 52), Rect2(69, 38, 8, 17), Rect2(33, 42, 5, 8)],   # Hauptgebäude, rotunda, in front of the west entrance
	"kueche": [Rect2(12, 64, 22, 14)],                                            # the Mensa
}
const NEEDS := {"saal": "abend", "kueche": "schuerze"}
const OUTFIT_NAMES := {"hoodie": "Hoodie", "schuerze": "Küchenschürze", "abend": "Abendgarderobe"}
const LOOK_ABEND := {"top": "1b1d26", "top_style": "jacket", "accent": "f4f1ea", "pants": "1b1d26", "shoes": "0e0e12"}
const LOOK_SCHUERZE := {"top": "f1efe8", "top_style": "labcoat", "accent": "c8463c", "pants": "3a3f46", "shoes": "1f1f24"}

# ---- places
const GARDEROBE := Rect2(40, 35, 3, 7)  # the cloakroom: office on the west side, just north of the entrance hall, door at (43, 38)
const RACKS := [Rect2(40.1, 35.3, 0.7, 1.5), Rect2(40.1, 37.25, 0.7, 1.5), Rect2(40.1, 39.2, 0.7, 1.5)]
const BAR := Rect2(53.2, 45.1, 3.6, 0.9)
const BUFFETS := [Rect2(46.9, 45.1, 3.0, 0.9), Rect2(60.1, 45.1, 3.0, 0.9)]
const TISCH := Rect2(41.0, 48.05, 1.8, 0.7)      # table with the wristbands, in the entrance hall
const HAKEN := Rect2(18.9, 65.05, 1.6, 0.5)      # hooks with kitchen whites, just inside the Mensa door
const FRACK := Rect2(31.25, 67.6, 0.7, 2.6)      # staff wardrobe with the waiters' tailcoats
const BASTEL := Rect2(13.1, 70.6, 0.9, 1.8)      # corner where the wristband is built
const HERDE := [Rect2(16.0, 69.0, 4.0, 1.1), Rect2(24.5, 69.0, 4.0, 1.1)]
const DANCE := Vector2(71.2, 46.0)               # middle of the dance floor in the rotunda
const EJECT_SAAL := Vector2(30.5, 46.0)          # where security puts you: on the Polyterrasse
const EJECT_KUECHE := Vector2(22.5, 61.8)        # where the cooks put you: in front of the Mensa door
# where the guests stroll: [x0, y0, x1, y1, how many]
const GUESTS := [[47, 43, 65, 44, 7], [47, 47, 65, 48, 7], [69, 43, 73, 49, 7], [39, 43, 45, 48, 3],
	[44, 27, 45, 64, 2], [66, 29, 67, 62, 2], [47, 36, 59, 37, 2], [47, 54, 59, 55, 2], [26, 40, 36, 52, 5], [76, 37, 87, 55, 2]]
const SUITS := ["1b1d26", "22263a", "2a2320", "30343d", "3a2a3a"]
const GOWNS := ["8c2f39", "2f5d8c", "b5893a", "5d3f7a", "2b6e6e", "c4643a", "d0b24a", "3e7d4f", "a33b5c"]
const COATS := ["3a3f46", "6b5440", "2f4f8f", "8c2f39", "b5893a", "5d3f7a", "c9c4ba", "22263a", "a39a8c"]
const LODEN := Color("2f6b45")                   # the professor's coat is the green one

# ---- people
const BADGE_ITEM := "prof_badge"        # name of the badge in the save game: Game.has_item("prof_badge")
const HANS_ID := "hans_muster"          # stands at the bar; an Opp here if an earlier level made him one under this id
const GUARD_IDS := ["l3_tuer", "l3_saal", "l3_garderobe", "l3_koch", "l3_hilfe"]
const KITCHEN_IDS := ["l3_koch", "l3_hilfe"]
const LOOK_SECURITY := {"skin": "d9a67e", "hair": "2a2320", "hair_style": "kurz", "top": "15161c", "top_style": "jacket",
	"accent": "15161c", "pants": "15161c", "shoes": "0c0c10", "acc": ["headphones"]}
const LOOK_GARDEROBE := {"skin": "f1c9a5", "hair": "c9c4ba", "hair_style": "dutt", "top": "7a2f45", "top_style": "sweater",
	"accent": "e8dcc0", "pants": "2b2f38", "shoes": "1f1f24", "acc": ["glasses"]}
const LOOK_KOCH := {"skin": "e0ac85", "hair": "3b2a1e", "hair_style": "cap", "top": "f3f3f0", "top_style": "labcoat",
	"accent": "e9ece8", "pants": "3b3f46", "shoes": "1f1f24", "acc": []}

const DEF := {
	"name": "Polyball",
	"tag": "LEVEL 3",
	"mode": "day",
	"time": 480.0,
	"start": Vector2(27.0, 51.0),   # on the Polyterrasse, between the west entrance and the Mensa
	"timer_title": "GARDEROBE SCHLIESST IN",
	"intro": "Polyball: 9000 Gäste im Hauptgebäude. In der Garderobe hängt der Mantel eines Professors, sein Badge steckt in der Innentasche. Im Hoodie kommt ihr nicht weit. Beide müssen alles erledigen:",
	"hint": "Verkleidungen gelten nur an ihrem Ort: Abendgarderobe im Hauptgebäude, Küchenschürze in der Mensa. Falsch angezogen füllt sich der Balken schneller.",
	"start_toast": ["Zuerst in die Mensa", "Dort ist heute die Küche. Gleich neben der Tür hängen Schürzen, hinten rechts die Fracks der Kellner."],
	"win_title": "Badge gesichert",
	"win_text": "%s & %s tanzen mit dem Badge eines Professors aus dem Polyball.",
	"lose_title": "Garderobe geschlossen",
	"lose_text": "Der Professor hat seinen Mantel geholt und ist gegangen. Der Badge ist weg.",
	"npcs": [
		{"id": "l3_tuer", "name": "Türsteher", "pos": Vector2(39.7, 45.9), "face": PI, "look": LOOK_SECURITY},
		{"id": "l3_saal", "name": "Security", "pos": Vector2(65.6, 46.0), "face": PI, "look": LOOK_SECURITY},
		{"id": "l3_garderobe", "name": "Garderobiere", "pos": Vector2(41.7, 40.6), "face": -PI / 2.0, "look": LOOK_GARDEROBE},
		{"id": "l3_koch", "name": "Chefkoch", "pos": Vector2(18.5, 73.6), "face": -PI / 2.0, "look": LOOK_KOCH},
		{"id": "l3_hilfe", "name": "Küchenhilfe", "pos": Vector2(28.5, 73.6), "face": -PI / 2.0, "look": LOOK_KOCH},
		{"id": HANS_ID, "name": "Hans Muster", "pos": Vector2(55.0, 46.6), "face": -PI / 2.0, "if_opp": "lauert"},
	],
	# Opps from levels 1 and 2 come back here, oldest first: at the bar, around the dance floor,
	# and the last ones come looking for you.
	"opp_spots": [
		{"pos": Vector2(52.6, 46.6), "face": -PI / 2.0, "mode": "lauert"},
		{"pos": Vector2(70.4, 43.4), "face": PI / 2.0, "mode": "lauert"},
		{"pos": Vector2(57.4, 46.6), "face": -PI / 2.0, "mode": "lauert"},
		{"pos": Vector2(48.5, 36.5), "face": PI / 2.0, "mode": "jagd"},
		{"pos": Vector2(47.5, 54.5), "face": -PI / 2.0, "mode": "jagd"},
	],
	"tasks": [
		{"id": "abend", "name": "Abendgarderobe organisieren", "where": "Fracks in der Küche (Mensa)", "type": "level"},
		{"id": "armband", "name": "Armband fälschen", "where": "Vorlage beim Eingang, Bastelecke in der Küche", "type": "level"},
		{"id": "tanz", "name": "Im Takt über die Tanzfläche", "where": "zu zweit in der Rotunde", "type": "level"},
		{"id": "badge", "name": "Prof-Badge holen", "where": "grüner Lodenmantel, Garderobe", "type": "level"},
		{"id": "buffet", "name": "Buffet plündern", "where": "Buffet in der Haupthalle", "type": "level"},
	],
}

var main
var t := 0.0
var rng := RandomNumberGenerator.new()
# disguise
var base_look: Array = [{}, {}]       # what the players came in
var outfit: Array = ["hoodie", "hoodie"]
var owned: Array = [{}, {}]           # disguises each player has: "schuerze" / "abend" -> true
var changing: Array = [0.0, 0.0]      # seconds left while changing clothes
var change_to: Array = ["", ""]
var stun: Array = [0.0, 0.0]
var tray: Array = [false, false]      # loot from the buffet
var meters := {}                      # Opp (instance id) -> its suspicion bar after the last frame
var snaps := {}                       # Opp (instance id) -> what it was doing after the last frame
var told := {}                        # hints that have been shown
# tasks
var coat_rack := 0                    # which rack holds the professor's coat
var rack_coats: Array = []            # colours of the coats per rack
var pattern: Array = []               # the wristband: 0 up, 1 down, 2 left, 3 right
var viewer := -1                      # who is looking at the template right now
var panel = null
var builder := -1                     # who is rebuilding the wristband right now
var buffet_mg: Array = [null, null]   # the timing minigame at the buffet, while the mouth can snap
var mouth_open: Array = [false, false]
var badge_taken := false              # the badge is out of the pocket (the task is ticked a moment later, see _badge_moment)
var fund = null                       # the badge being shown off (fund.gd), while it is on the screen
var fund_pid := -1
var covers: Array = [0, 0]            # how many opaque minigames lie over each half of the screen
var view_mode: Array = [-1, -1]       # how each view was drawn before it was switched off (-1 = it is on)
var marks: Node2D


## What floats above the players' heads (disguise fits or not), drawn above everything in the world.
class Marks:
	extends Node2D
	var level

	func _draw() -> void:
		level._draw_marks(self)


# ================================================================== map
## Called by map_data.gd: the ball in the Hauptgebäude and the kitchen in the Mensa.
static func build_map(md) -> void:
	md.objs = md.objs.filter(func(o):
		var r: Rect2 = o["rect"]
		if o["kind"] == "infodesk" or o["kind"] == "mtable":
			return false
		if o["kind"] == "bench" and is_equal_approx(r.position.y, 45.2):
			return false
		if o["kind"] in ["desk", "chair"] and GARDEROBE.has_point(r.get_center()):
			return false
		return true)
	# Haupthalle: the bar where the info desk was, buffet tables where the benches were
	md.R("l3_bar", BAR.position.x, BAR.position.y, BAR.size.x, BAR.size.y)
	for r in BUFFETS:
		md.R("l3_buffet", r.position.x, r.position.y, r.size.x, r.size.y)
	md.R("l3_tisch", TISCH.position.x, TISCH.position.y, TISCH.size.x, TISCH.size.y)
	for r in RACKS:
		md.R("l3_rack", r.position.x, r.position.y, r.size.x, r.size.y)
	# kitchen
	md.R("l3_haken", HAKEN.position.x, HAKEN.position.y, HAKEN.size.x, HAKEN.size.y)
	md.R("l3_frack", FRACK.position.x, FRACK.position.y, FRACK.size.x, FRACK.size.y)
	md.R("l3_bastel", BASTEL.position.x, BASTEL.position.y, BASTEL.size.x, BASTEL.size.y)
	for r in HERDE:
		md.R("l3_herd", r.position.x, r.position.y, r.size.x, r.size.y)
	for l in md.labels:
		if l["t"] == "MENSA POLYTERRASSE":
			l["t"] = "KÜCHE · CATERING"
			l["sz"] = 0.55
	md.L("GARDEROBE", 41.9, 36.2, 0.3, "floor", {"rot": -PI / 2})
	# the students of the day are the guests of the ball
	md.student_zones = GUESTS.duplicate(true)


# ================================================================== setup
func _ready() -> void:
	z_index = -5                       # floor decoration: above the map, below the characters
	process_physics_priority = 10      # after the Opps: _apply_disguises corrects what they did this frame
	rng.randomize()
	coat_rack = rng.randi() % RACKS.size()
	for k in RACKS.size():
		var cs: Array = []
		for i in 4:
			cs.append(Color(String(COATS[rng.randi() % COATS.size()])))
		if k == coat_rack:
			cs[rng.randi() % 4] = LODEN
		rack_coats.append(cs)
	for i in ARMBAND_LEN:
		pattern.append(rng.randi() % 4)
	for pid in 2:
		base_look[pid] = (main.players[pid].look as Dictionary).duplicate(true)
	# security, cloakroom and kitchen staff watch from the start (they are never saved as Opps)
	for op in main.opps:
		if GUARD_IDS.has(op.opp_id):
			op.angry = true
			op.state = OPP.LAUERN
	_dress_guests()
	if PREWARM:
		Track.use(self, [], false)     # starts the tracker process, the camera only comes on in a camera minigame
	marks = Marks.new()
	marks.level = self
	marks.z_index = 11                 # relative to this node: above the characters and fx
	add_child(marks)


func _dress_guests() -> void:
	for st in main.students:
		var l: Dictionary = st.look
		l["acc"] = (l.get("acc", []) as Array).filter(func(a): return a in ["glasses", "beard"])
		if rng.randf() < 0.5:
			l["top_style"] = "jacket"
			l["top"] = SUITS[rng.randi() % SUITS.size()]
			l["accent"] = "f4f1ea"
			l["pants"] = l["top"]
		else:
			l["top_style"] = "sweater"   # top and legs in one colour: a long dress
			l["top"] = GOWNS[rng.randi() % GOWNS.size()]
			l["accent"] = l["top"]
			l["pants"] = l["top"]
		l["shoes"] = "0e0e12"


# ================================================================== disguise
## "saal", "kueche" or "" (clothes do not matter there).
func zone_at(p: Vector2) -> String:
	for z in ZONES:
		for r in ZONES[z]:
			if (r as Rect2).has_point(p):
				return z
	return ""


func zone_of(pid: int) -> String:
	return zone_at(main.players[pid].global_position / TS)


## How suspicious a player looks to a light cone right now: 0 = ignored (right clothes in the
## right zone), 1 = normal (no zone), FACTOR_WRONG = wrong clothes, hoodie, or changing in view.
func suspicion(pid: int) -> float:
	if changing[pid] > 0.0:
		return FACTOR_WRONG
	var need: String = NEEDS.get(zone_of(pid), "")
	if need == "":
		return 1.0
	return 0.0 if outfit[pid] == need else FACTOR_WRONG


## The most suspicious player this Opp can see right now (suspicion above 0), or -1.
func _worst_in_view(op) -> int:
	var worst := -1
	var f := 0.0
	var hunting: bool = op.state == OPP.SUCHEN or op.state == OPP.JAGD
	for pid in 2:
		if not (op.foes.is_empty() or op.foes.has(pid)):
			continue
		if suspicion(pid) > f and op.can_see(main.players[pid], hunting):
			f = suspicion(pid)
			worst = pid
	return worst


## The factor on the Opp system. An Opp only raises its bar while it sees somebody (opp.gd,
## _watch). Whatever it added this frame is scaled by the most suspicious person in its view;
## if everybody in view is dressed right, the bar drains as if nobody was there.
func _apply_disguises(delta: float) -> void:
	for op in main.opps:
		var id: int = op.get_instance_id()
		var before: float = meters.get(id, op.meter)
		var was: Array = snaps.get(id, [])
		if op.state == OPP.JAGD:
			# opp.gd runs after the nearest person it sees. If its chase began this frame and that
			# person is dressed right, it is after the wrong one: the suspicious one, or nobody.
			var tp: int = main.players.find(op.target)
			if not was.is_empty() and was[0] != OPP.JAGD and tp >= 0 and suspicion(tp) <= 0.0:
				var other := _worst_in_view(op)
				if other >= 0:
					op._chase(main.players[other])
				else:
					_restore(op, was)
					op.target = null
					op.shout_t = 0.0
					op.meter = maxf(0.0, before - METER_DECAY * delta)
		elif op.meter > before:
			var worst := _worst_in_view(op)
			if worst < 0:
				op.meter = maxf(0.0, before - METER_DECAY * delta)
			else:
				op.meter = minf(1.0, before + (op.meter - before) * suspicion(worst))
				if op.meter >= 1.0:
					op._chase(main.players[worst])
		meters[id] = op.meter
		snaps[id] = [op.state, op.path.duplicate(), op.timer, op.last_seen, op.look_base]


## Puts an Opp back to what it was doing after the last frame.
func _restore(op, s: Array) -> void:
	op.state = s[0]
	op.path = s[1]
	op.timer = s[2]
	op.last_seen = s[3]
	op.look_base = s[4]


## Footsteps and minigame mistakes, called by main.gd after the Opps have heard them. A guest in
## the right clothes walking past is nothing to look into: whoever set off to have a look goes
## back to what they were doing. Mistakes in a minigame still make them come over.
func on_noise(at: Vector2, _radius: float) -> void:
	var a: float = main.players[0].global_position.distance_to(at)
	var b: float = main.players[1].global_position.distance_to(at)
	var pid := 0 if a <= b else 1
	if main.busy(pid) or suspicion(pid) > 0.0:
		return
	for op in main.opps:
		var id: int = op.get_instance_id()
		if op.state != OPP.SUCHEN or not snaps.has(id) or not (op.noise_at as Vector2).is_equal_approx(at):
			continue
		var s: Array = snaps[id]
		if s[0] != OPP.JAGD:
			_restore(op, s)


func _wear(pid: int, what: String) -> void:
	outfit[pid] = what
	var l: Dictionary = (base_look[pid] as Dictionary).duplicate(true)
	if what != "hoodie":
		l.merge(LOOK_ABEND if what == "abend" else LOOK_SCHUERZE, true)
		if what == "abend":
			l["accent"] = Color(String(KEYS.TAG_COLORS[pid])).lightened(0.6).to_html(false)   # shirt in the player's colour
		l["acc"] = (l.get("acc", []) as Array).filter(func(a): return a != "backpack")
	if tray[pid]:
		ART.set_acc(l, "tray", true)
	main.players[pid].look = l
	main.players[pid].queue_redraw()


## The disguise this player could change into right here, or "".
func _other_outfit(pid: int) -> String:
	var need: String = NEEDS.get(zone_of(pid), "")
	if need != "":
		return need if (owned[pid].has(need) and outfit[pid] != need) else ""
	for o in ["abend", "schuerze"]:
		if owned[pid].has(o) and outfit[pid] != o:
			return o
	return ""


func _start_change(pid: int, to: String) -> void:
	changing[pid] = CHANGE_TIME
	change_to[pid] = to
	UI.sfx("whoosh", -8.0)


## A guard has caught somebody: out of the door, the level goes on. Old Opps are not handled here.
func on_opp_catch(op, pid: int) -> bool:
	if not GUARD_IDS.has(op.opp_id):
		return false
	var kitchen: bool = KITCHEN_IDS.has(op.opp_id)
	var pl = main.players[pid]
	main.mistakes_total += 1
	if main.minis[pid] != null:
		main._abort_mini(pid)
	if viewer == pid:
		_stop_view()
	changing[pid] = 0.0
	stun[pid] = STUN
	pl.enabled = false
	pl.global_position = (EJECT_KUECHE if kitchen else EJECT_SAAL) * TS
	op.meter = 0.0
	op.calm_t = GUARD_CALM
	op._go_home()
	UI.sfx("fail")
	main.fx.sound(pl.global_position, 3.0 * TS, Color(1.0, 0.4, 0.4, 0.7), 0.8)
	if kitchen:
		main.hud.toast("Raus aus meiner Küche!", "%s setzt dich vor die Tür. In der Küche fällt nur nicht auf, wer eine Schürze trägt." % op.pname, 4.5)
	else:
		main.hud.toast("Rausgeworfen!", "%s setzt dich vor die Tür. Im Hauptgebäude fällt nur nicht auf, wer Abendgarderobe trägt." % op.pname, 4.5)
	return true


# ================================================================== loop
func _process(delta: float) -> void:
	t += delta
	if main.state != "play" and panel != null:
		_stop_view()
	if panel != null:
		panel.side = main.screen_side(viewer)
		_view_info()
	if fund != null and is_instance_valid(fund):
		fund.side = main.screen_side(fund_pid)
		fund.visible = main.state == "play"
	if covers[0] > 0 or covers[1] > 0:
		_apply_covers()
	queue_redraw()
	marks.queue_redraw()


func _physics_process(delta: float) -> void:
	if main.state != "play":
		return
	for pid in 2:
		var pl = main.players[pid]
		stun[pid] = maxf(0.0, stun[pid] - delta)
		if changing[pid] > 0.0:
			changing[pid] -= delta
			if changing[pid] <= 0.0:
				_wear(pid, change_to[pid])
				UI.sfx("pop")
		if not main.busy(pid):
			pl.enabled = stun[pid] <= 0.0 and changing[pid] <= 0.0 and viewer != pid
		var z := zone_of(pid)
		if z != "" and suspicion(pid) > 1.0 and changing[pid] <= 0.0 and not told.has(z) and main.time_played > 3.0:
			told[z] = true
			if z == "saal":
				main.hud.toast("Im Hoodie am Polyball", "Hier gilt Abendgarderobe. Falsch angezogen füllt sich der Balken über Security und alten Bekannten viel schneller.", 5.0)
			else:
				main.hud.toast("Küche: nur Personal", "Ohne Küchenschürze fällst du hier auf. Die Schürzen hängen gleich neben der Tür.", 5.0)
	_apply_disguises(delta)
	# whoever rebuilds the wristband must not be shown the sequence (the minigame replays it after a mistake)
	if builder >= 0:
		var mg = main.minis[builder]
		if mg == null:
			builder = -1
		elif not ARMBAND_SOLO:
			if mg.seq_phase == "show":
				_blind(mg)
			_build_info(mg)
	_snap_with_mouth()


# ================================================================== interaction
func _near(act: String, label: String, rect: Rect2, extra: Dictionary = {}) -> Dictionary:
	var o := {"use": "level", "act": act, "label": label, "rect": rect}
	o.merge(extra)
	return o


## Everything this player could use right now.
func _spots(pid: int) -> Array:
	var out: Array = []
	var d: Dictionary = main.done[pid]
	if not owned[pid].has("schuerze"):
		out.append(_near("apron", "Küchenschürze nehmen", HAKEN))
	if not d.has("abend"):
		out.append(_near("frack", "Kellner-Frack nehmen", FRACK))
	if not d.has("armband"):
		out.append(_near("vorlage", "Armband-Vorlage ansehen und ansagen", TISCH))
		out.append(_near("basteln", "Armband nachbauen (jemand muss ansagen)", BASTEL))
	if not d.has("tanz"):
		out.append(_near("tanz", "Tanzen (zu zweit)", Rect2(DANCE - Vector2(2.0, 2.0), Vector2(4.0, 4.0))))
	if not d.has("badge") and not badge_taken:
		for k in RACKS.size():
			out.append(_near("mantel", "Mäntel durchsuchen", RACKS[k], {"rack": k}))
	if not d.has("buffet"):
		for r in BUFFETS:
			out.append(_near("buffet", "Buffet plündern", r))
	return out


func update_near(pid: int) -> void:
	if changing[pid] > 0.0 or stun[pid] > 0.0:
		main.nears[pid] = null
		return
	if viewer == pid:
		main.nears[pid] = _near("weg", "Vorlage weglegen", TISCH)
		return
	var p: Vector2 = main.players[pid].global_position / TS
	var best := 1.15
	for o in _spots(pid):
		var r: Rect2 = o["rect"]
		var c := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var dd := p.distance_to(c)
		if dd < best:
			best = dd
			main.nears[pid] = o
	# nothing else within reach: change clothes on the spot
	if main.nears[pid] == null:
		var to := _other_outfit(pid)
		if to != "":
			main.nears[pid] = _near("change", "Umziehen: %s" % OUTFIT_NAMES[to], Rect2(p - Vector2(0.5, 1.7), Vector2(1.0, 1.9)), {"to": to})


## "Ohne sie geht nichts anderes": every other task needs the evening wear first.
func _has_frack(pid: int) -> bool:
	if main.done[pid].has("abend"):
		return true
	UI.sfx("fail")
	main.hud.toast("Erst die Abendgarderobe", "Ohne Frack geht am Polyball gar nichts. Die Fracks der Kellner hängen in der Küche (Mensa).", 3.5)
	return false


func interact(pid: int, o: Dictionary) -> void:
	var pl = main.players[pid]
	match o["act"]:
		"change":
			_start_change(pid, o["to"])
		"apron":
			owned[pid]["schuerze"] = true
			_start_change(pid, "schuerze")
			if not told.has("apron"):
				told["apron"] = true
				main.hud.toast("Küchenschürze", "In der Küche übersehen dich die Köche jetzt. Draussen und im Hauptgebäude hilft sie nichts.", 4.5)
		"frack":
			if outfit[pid] != "schuerze":
				UI.sfx("fail")
				main.hud.toast("Nur für Personal", "An die Personalgarderobe kommt nur, wer eine Küchenschürze trägt.", 3.0)
				return
			var on_frack := func():
				owned[pid]["abend"] = true
				main._task_done(pid, "abend")
				main.hud.toast("Frack gesichert", "Zieh dich draussen um: stehen bleiben, wo nichts in der Nähe ist, und interagieren. Nicht dort, wo jemand zuschaut.", 5.5)
			main.open_minigame("timing", {"title": "Frack vom Bügel nehmen", "hits": FRACK_HITS, "verb": "Griff", "speed": FRACK_SPEED}, on_frack, pid)
		"vorlage":
			if _has_frack(pid):
				_view(pid)
		"weg":
			_stop_view()
		"basteln":
			if _has_frack(pid):
				_build(pid)
		"mantel":
			if not _has_frack(pid):
				return
			if outfit[pid] != "abend":
				UI.sfx("fail")
				main.hud.toast("So nicht", "Die Garderobiere lässt nur Gäste in Abendgarderobe an die Mäntel.", 3.0)
				return
			if int(o["rack"]) != coat_rack:
				UI.sfx("tick")
				main.hud.toast("Falscher Ständer", "Daunenjacken, ein Velohelm, ein vergessener Schal. Der Professor trägt einen grünen Lodenmantel.", 3.0)
				return
			_steal_badge(pid)
		"tanz":
			if not _has_frack(pid):
				return
			var other = main.players[1 - pid]
			if outfit[pid] != "abend" or outfit[1 - pid] != "abend":
				UI.sfx("fail")
				main.hud.toast("So nicht", "Auf die Tanzfläche geht es nur zu zweit und nur in Abendgarderobe.", 3.0)
				return
			if main.busy(1 - pid) or (other.global_position / TS).distance_to(DANCE) > TANZ_RADIUS:
				main.hud.toast("Zu zweit", "%s muss auch auf der Tanzfläche stehen." % Game.name_of(1 - pid), 3.0)
				return
			var on_dance := func():
				main._coop_done("tanz")
				main.hud.toast("Quer durch den Saal", "Niemand hat gemerkt, dass ihr gar keine Tickets habt.", 4.5)
			_open_cam("tanz", -1, on_dance)
		"buffet":
			if not _has_frack(pid):
				return
			var on_buffet := func():
				tray[pid] = true
				ART.set_acc(pl.look, "tray", true)
				pl.queue_redraw()
				main._task_done(pid, "buffet")
				main.hud.toast("Abendessen gesichert", "Drei Lachsbrötli, eine Mini-Quiche und vierzehn Schoggi-Mousses. Rein rechnerisch ist das ein Menü.", 4.5)
			main.open_minigame("timing", {"title": "Buffet plündern", "hits": BUFFET_HITS, "verb": "Häppchen", "speed": BUFFET_SPEED}, on_buffet, pid)
			_watch_mouth(pid)


# ------------------------------------------------------------------ in front of the camera
## Opens one of the camera minigames (kamera_spiel.gd) the way main.gd opens its own minigames:
## it sits in main.minis, so the players are busy, the screen splits for one player and
## main._abort_mini works. pid -1 = both players, the whole screen.
func _open_cam(kind: String, pid: int, on_ok: Callable, on_fallback: Callable = Callable()) -> void:
	var who: Array = [0, 1] if pid < 0 else [pid]
	var mg = KameraSpiel.new()
	mg.pid = pid
	mg.keys = KEYS.keys_for(who[0])
	mg.labels = KEYS.labels_for(who[0])
	if pid < 0:
		mg.keys2 = KEYS.keys_for(1)
		mg.labels2 = KEYS.labels_for(1)
	else:
		mg.accent = Color(String(KEYS.TAG_COLORS[pid]))
	for j in who:
		main.minis[j] = mg
		main.nears[j] = null
		main.players[j].enabled = false
	main.add_child(mg)
	mg.open(kind)
	_cover(mg, who)
	# true if this minigame was still the open one and the level is still running
	var release := func() -> bool:
		var mine := false
		for j in who:
			if main.minis[j] == mg:
				main.minis[j] = null
				mine = true
		return mine and main.state == "play"
	mg.mistake.connect(func(): main._on_mini_mistake(pid))
	mg.finished.connect(func(ok: bool, _m: int):
		if not release.call():
			return
		for j in who:
			main.players[j].enabled = true
		if ok:
			on_ok.call()
		else:
			main.hud.toast("Abgebrochen", "Das geht jederzeit nochmals.", 2.5))
	mg.fallback.connect(func():
		if release.call() and on_fallback.is_valid():
			on_fallback.call())


## The halves of the screen that an opaque minigame covers are not drawn while it is open.
## Drawing the map takes most of a frame (measured on a MacBook: the game draws about 35 pictures
## per second because of it). Without it, the camera picture and what is drawn on it run
## smoothly; with it, they stutter along at the pace of the map.
func _cover(mg: Node, sides: Array) -> void:
	for sd in sides:
		covers[sd] += 1
	mg.tree_exited.connect(func():
		for sd in sides:
			covers[sd] -= 1
		_apply_covers())
	_apply_covers()


## Switches the views off and on as the covers ask for it. View 0 is the left half and view 1 the
## right one only while the split stands upright. If main turns the split line with the players
## (it has `force_k` then, and sets the line upright when a minigame for one player opens), a
## single view is switched off only once the line stands; before that, part of it can still show
## on the other player's side.
func _apply_covers() -> void:
	if not is_instance_valid(main):
		return
	var upright: bool = (covers[0] > 0 and covers[1] > 0) or not ("force_k" in main) or main.force_k >= 0.99
	for sd in 2:
		var vp = main.vps[sd]
		if not is_instance_valid(vp):
			continue
		var off: bool = covers[sd] > 0 and upright
		if off and view_mode[sd] < 0:
			view_mode[sd] = vp.render_target_update_mode
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		elif not off and view_mode[sd] >= 0:
			vp.render_target_update_mode = view_mode[sd]
			view_mode[sd] = -1


## The badge: with two fingers in front of the camera, or with the sequence minigame.
func _steal_badge(pid: int) -> void:
	var on_badge := func():
		Game.add_item(BADGE_ITEM)
		_badge_moment(pid)
	var with_keys := func():
		main.open_minigame("sequence", {"title": "Mantel · Innentasche · Badge", "length": BADGE_SEQ}, on_badge, pid)
	_open_cam("badge", pid, on_badge, with_keys)


## The badge is out: it is shown off on that player's half of the screen while the game goes on
## for both (fund.gd), and what the two say about it comes now and not at the end of the level.
## The task is ticked when that is over. With little time left it is ticked at once, so that the
## clock cannot run out in between.
func _badge_moment(pid: int) -> void:
	badge_taken = true
	var late: bool = main.time_left() > Fund.TIME + 4.0
	if not late:
		main._coop_done("badge")
	fund = Fund.new()
	fund_pid = pid
	fund.pid = pid
	fund.side = main.screen_side(pid)
	fund.looks = [main.players[0].look, main.players[1].look]
	main.add_child(fund)
	fund.done.connect(func():
		fund = null
		if late:
			main._coop_done("badge"))


## Buffet: the timing minigame stays as it is, the camera only adds a second way to press.
func _watch_mouth(pid: int) -> void:
	var mg = main.minis[pid]
	if mg == null:
		return
	buffet_mg[pid] = mg
	mouth_open[pid] = true                 # has to close once before it counts
	Track.use(mg, ["face"], false)         # released by itself when the minigame closes
	var dim = mg.root.get_child(0)
	if dim is ColorRect:
		dim.color = KameraSpiel.LIGHT      # the buffet is brightly lit: the lamp for the camera
		_cover(mg, [pid])


func _snap_with_mouth() -> void:
	for pid in 2:
		var mg = buffet_mg[pid]
		if mg == null:
			continue
		if not is_instance_valid(mg) or main.minis[pid] != mg:
			buffet_mg[pid] = null
			continue
		if Track.alive and not (mg.info_l.text as String).contains("Mund"):
			mg.info_l.text += "   Oder vor der Kamera: Mund weit auf!"
		var f := TM.mine(Track.faces, pid)   # the face on this player's side, or the only one there is
		if f.is_empty():
			continue
		var m: float = f["mouth"]
		if m > MOUTH_OPEN and not mouth_open[pid]:
			mouth_open[pid] = true
			if mg.closing < 0.0:
				mg._timing_press()
		elif m < MOUTH_SHUT:
			mouth_open[pid] = false


# ------------------------------------------------------------------ wristband: one looks, the other builds
## One player looks at the template at the table in the entrance hall and reads it out, the other
## one rebuilds it at the craft corner in the kitchen. Each side is told what the other is doing.
func _view(pid: int) -> void:
	viewer = pid
	main.players[pid].enabled = false
	panel = Vorlage.new()
	panel.side = main.screen_side(pid)
	panel.pattern = pattern
	panel.accent = Color(String(KEYS.TAG_COLORS[pid]))
	panel.hint = "%s = Vorlage weglegen" % KEYS.labels_for(pid)["ok"]
	_view_info()
	main.add_child(panel)


func _stop_view() -> void:
	if panel != null:
		panel.queue_free()
	panel = null
	viewer = -1


## The minigame of whoever is building right now, or null.
func _build_mg():
	if builder < 0:
		return null
	var mg = main.minis[builder]
	return mg if (mg != null and is_instance_valid(mg)) else null


## Tells the one at the template how far the builder is.
func _view_info() -> void:
	var who: String = Game.name_of(1 - viewer)
	var mg = _build_mg()
	panel.wrong = false
	if mg == null:
		panel.built = -1
		panel.status = "Sag %s die Pfeile der Reihe nach an. %s baut sie in der Bastelecke der Küche nach (Mensa, links an der Wand) und ist noch nicht dort." % [who, who]
	elif mg.closing >= 0.0:
		panel.built = pattern.size()
		panel.status = "Geschafft, das Armband ist fertig!"
	elif mg.seq_phase == "wait":
		panel.built = 0
		panel.wrong = true
		panel.status = "Falsch getippt! %s fängt wieder beim ersten Pfeil an." % who
	else:
		panel.built = int(mg.input_i)
		panel.status = "%s baut: %d von %d. Sag den Pfeil Nummer %d an." % [who, mg.input_i, pattern.size(), mini(int(mg.input_i) + 1, pattern.size())]


## The existing sequence minigame, but with the wristband as the sequence and without showing it:
## the arrows are only on the template, somebody has to read them out.
func _build(pid: int) -> void:
	var on_ok := func():
		_stop_view()
		main._coop_done("armband")
		main.hud.toast("Sieht echt aus", "Zwei Armbänder aus Geschenkband und Alufolie. Aus zwei Metern Entfernung perfekt.", 4.5)
	var on_close := func(): builder = -1
	main.open_minigame("sequence", {"title": "Armband nachbauen", "length": ARMBAND_LEN}, on_ok, pid, Callable(), on_close)
	builder = pid
	var mg = main.minis[pid]
	mg.seq = pattern.duplicate()
	if ARMBAND_SOLO:
		mg._restart_show()
		return
	_blind(mg)
	_build_info(mg)


func _blind(mg) -> void:
	mg.seq_phase = "input"
	mg.input_i = 0
	mg.lit = -1
	mg._update_info()


## The text under the pads: why there are no arrows to copy here, and where they are.
func _build_info(mg) -> void:
	if mg.closing >= 0.0:
		return
	var who: String = Game.name_of(1 - builder)
	var s := ""
	var col := UI.WHITE
	if mg.seq_phase == "wait":
		s = "Falsch! Gleich geht es nochmals von vorne los, mit dem ersten Pfeil."
		col = UI.RED
	elif viewer < 0:
		s = "Die Pfeile stehen nicht hier, sondern auf der Vorlage am Bändel-Tisch beim Eingang des Hauptgebäudes. %s muss sie dort ansehen und dir ansagen." % who
		col = UI.YELLOW
	else:
		s = "%s sieht die Vorlage und sagt dir die Pfeile an. Tippe sie mit %s: %d von %d." % [who, mg.labels["dirs"], mg.input_i, mg.seq.size()]
	if mg.mistakes > 0:
		s += "   Fehler: %d" % mg.mistakes
	if mg.info_l.text != s:
		mg.info_l.text = s
	mg.info_l.label_settings.font_size = 17
	mg.info_l.label_settings.font_color = col


# ================================================================== markers and ways for the HUD
func _c(r: Rect2) -> Vector2:
	return r.get_center() * TS


## Where task `id` can be done by player `pid` right now, in px (for the dashed way).
func task_targets(id: String, pid: int) -> Array:
	match id:
		"abend":
			return [_c(FRACK) if owned[pid].has("schuerze") else _c(HAKEN) + Vector2(0, 0.9 * TS)]
		"armband":
			if viewer == 1 - pid:
				return [_c(BASTEL)]
			if builder == 1 - pid:
				return [_c(TISCH)]
			if viewer == pid or builder == pid:
				return []
			# nobody has started: whoever is closer to the template goes there, the other one builds
			var mine: float = main.players[pid].global_position.distance_to(_c(TISCH))
			var theirs: float = main.players[1 - pid].global_position.distance_to(_c(TISCH))
			return [_c(TISCH) if (mine < theirs or (mine == theirs and pid == 0)) else _c(BASTEL)]
		"tanz":
			return [DANCE * TS]
		"badge":
			return [] if badge_taken else [Vector2(42.5, 38.5) * TS]
		"buffet":
			return [_c(BUFFETS[0]) + Vector2(0, -0.9 * TS), _c(BUFFETS[1]) + Vector2(0, -0.9 * TS)]
	return []


## Goal markers: [position in px, colour of whoever still needs it].
func goal_positions(id: String, n0: bool, n1: bool) -> Array:
	var c: Color = main._need_color(n0, n1)
	var out: Array = []
	match id:
		"abend":
			var a0: bool = n0 and not owned[0].has("schuerze")
			var a1: bool = n1 and not owned[1].has("schuerze")
			if a0 or a1:
				out.append([_c(HAKEN), main._need_color(a0, a1)])
			out.append([_c(FRACK), c])
		"armband":
			out.append([_c(TISCH), c])
			out.append([_c(BASTEL), c])
		"tanz":
			out.append([DANCE * TS, c])
		"badge":
			if not badge_taken:
				out.append([_c(GARDEROBE), c])
		"buffet":
			for r in BUFFETS:
				out.append([_c(r), c])
	return out


## Called by main.gd when every task is done: the two dance out of the ball (abgang.gd), then the
## win screen. What they say about the badge itself comes when they take it (_badge_moment).
func finale(done: Callable) -> void:
	main.state = "cutscene"
	main.hud.visible = false
	_stop_view()
	if fund != null and is_instance_valid(fund):
		fund.queue_free()
	for pl in main.players:
		pl.enabled = false
	var a = Abgang.new()
	a.looks = [main.players[0].look, main.players[1].look]
	main.add_child(a)
	_cover(a, [0, 1])              # the scene fills the screen: the map behind it is not drawn
	a.play(func():
		main.hud.visible = true
		done.call())


# ================================================================== drawing
func _box(r: Rect2, col: Color, edge: Color) -> void:
	var px := Rect2(r.position * TS, r.size * TS)
	draw_rect(Rect2(px.position + Vector2(2, 3), px.size), Color(0, 0, 0, 0.22))
	draw_rect(px, col)
	draw_rect(px, edge, false, 1.5)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var gold := Color("d9b24c")
	# red carpet from the Polyterrasse through the hall to the dance floor
	var carpet := Rect2(Vector2(33.0, 46.2) * TS, Vector2(35.4, 0.9) * TS)
	draw_rect(carpet, Color("8c1c2c"))
	draw_line(carpet.position, carpet.position + Vector2(carpet.size.x, 0), gold, 1.5)
	draw_line(carpet.position + Vector2(0, carpet.size.y), carpet.end, gold, 1.5)
	draw_string(font, Vector2(30.4, 43.6) * TS, "POLYBALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, gold)
	draw_string(font, Vector2(30.4, 44.2) * TS, "Abendgarderobe", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(gold, 0.8))
	draw_string(font, Vector2(18.6, 63.7) * TS, "Küche · nur Personal", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.75))
	# strings of lights along the Haupthalle
	var cols := [UI.YELLOW, UI.PINK, UI.GREEN, UI.BLUE, UI.ORANGE]
	var i := 0
	var x := 46.4
	while x < 67.6:
		for y in [43.12, 48.88]:
			var tw: float = 0.55 + 0.45 * sin(t * 3.0 + i * 1.7)
			draw_circle(Vector2(x, y) * TS, 2.2, Color(cols[i % cols.size()], tw))
		i += 1
		x += 0.7
	# dance floor in the rotunda: tiles that light up in turn
	for ty in range(-3, 3):
		for tx in range(-3, 3):
			var c := DANCE + Vector2(tx + 0.5, ty + 0.5) * 0.8
			if c.distance_to(DANCE) > 2.5:
				continue
			var k: int = absi(tx * 3 + ty * 5 + int(t * 2.0)) % cols.size()
			var r := Rect2((c - Vector2(0.37, 0.37)) * TS, Vector2(0.74, 0.74) * TS)
			draw_rect(r, Color(cols[k], 0.22 + 0.16 * sin(t * 4.0 + tx + ty)))
			draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
	_draw_hall()
	_draw_kitchen()


func _draw_hall() -> void:
	# bar: dark wood, bottles and glasses
	_box(BAR, Color("4a3323"), Color("2b1d14"))
	var bp := BAR.position * TS
	draw_rect(Rect2(bp + Vector2(3, 3), Vector2(BAR.size.x * TS - 6, 7)), Color("6b4a33"))
	for k in 9:
		var bx := bp.x + 10.0 + k * 12.0
		draw_rect(Rect2(bx, bp.y + 12, 4, 10), Color(["3e7d4f", "8c2f39", "d0b24a", "2f5d8c"][k % 4]))
		draw_rect(Rect2(bx + 1, bp.y + 9, 2, 4), Color("d8d4cc"))
	# buffet tables: white cloth, platters
	for r in BUFFETS:
		_box(r, Color("f4f1ea"), Color("c9c4ba"))
		for k in 4:
			var c: Vector2 = (r.position + Vector2(0.45 + k * 0.7, 0.45)) * TS
			draw_set_transform(c, 0.0, Vector2(1.0, 0.7))
			draw_circle(Vector2.ZERO, 9.0, Color("d8d4cc"))
			draw_circle(Vector2.ZERO, 7.0, Color(["e8956b", "f0d9a0", "7a4b2a", "c7e0a0"][k]))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# table with the wristbands
	_box(TISCH, Color("f4f1ea"), Color("c9c4ba"))
	var tp := TISCH.position * TS
	draw_rect(Rect2(tp + Vector2(8, 6), Vector2(14, 9)), Color("3a3f46"))
	for k in 5:
		draw_rect(Rect2(tp + Vector2(28 + k * 5, 7), Vector2(4, 8)), Color(String(Vorlage.COLS[k % 4])))
	# coat racks: a rail with coats, one of them is the green loden coat
	for k in RACKS.size():
		var rr: Rect2 = RACKS[k]
		var p := rr.position * TS
		draw_rect(Rect2(p + Vector2(2, 3), rr.size * TS), Color(0, 0, 0, 0.2))
		draw_rect(Rect2(p + Vector2(9, 0), Vector2(3, rr.size.y * TS)), Color("2b2f38"))
		var cs: Array = rack_coats[k]
		for j in cs.size():
			var cc: Color = cs[j]
			var cp := p + Vector2(1, 3 + j * 11.0)
			draw_rect(Rect2(cp, Vector2(20, 9)), cc)
			draw_rect(Rect2(cp, Vector2(20, 9)), cc.darkened(0.35), false, 1.0)
			if cc == LODEN:
				draw_circle(cp + Vector2(15, 4.5), 1.6, Color("d9b24c"))


func _draw_kitchen() -> void:
	# hooks with kitchen whites next to the door
	var hp := HAKEN.position * TS
	draw_rect(Rect2(hp, Vector2(HAKEN.size.x * TS, 4)), Color("6b4a33"))
	for k in 4:
		var ap := hp + Vector2(4 + k * 12.0, 3)
		draw_rect(Rect2(ap, Vector2(9, 12)), Color("f1efe8"))
		draw_rect(Rect2(ap, Vector2(9, 12)), Color("b9b5aa"), false, 1.0)
		draw_rect(Rect2(ap + Vector2(3, 0), Vector2(3, 3)), Color("c8463c"))
	# staff wardrobe: tailcoats with white shirt fronts
	var fp := FRACK.position * TS
	draw_rect(Rect2(fp + Vector2(2, 3), FRACK.size * TS), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(fp + Vector2(9, 0), Vector2(3, FRACK.size.y * TS)), Color("2b2f38"))
	for k in 7:
		var cp := fp + Vector2(1, 4 + k * 11.0)
		draw_rect(Rect2(cp, Vector2(20, 9)), Color("1b1d26"))
		draw_rect(Rect2(cp + Vector2(8, 0), Vector2(4, 9)), Color("f4f1ea"))
	# the corner where the wristband is built: foil, ribbon, scissors
	_box(BASTEL, Color("b9bcc2"), Color("7d8189"))
	var kp := BASTEL.position * TS
	draw_rect(Rect2(kp + Vector2(6, 6), Vector2(16, 6)), Color("dfe3ea"))
	draw_rect(Rect2(kp + Vector2(6, 18), Vector2(16, 4)), Color("ff5d8f"))
	draw_rect(Rect2(kp + Vector2(6, 26), Vector2(16, 4)), Color("4d8dff"))
	draw_line(kp + Vector2(8, 38), kp + Vector2(20, 48), Color("3a3f46"), 2.0)
	draw_line(kp + Vector2(20, 38), kp + Vector2(8, 48), Color("3a3f46"), 2.0)
	# kitchen islands: steel, pots, flames
	for r in HERDE:
		_box(r, Color("aeb4bd"), Color("6f757f"))
		for k in 4:
			var c: Vector2 = (r.position + Vector2(0.55 + k * 0.95, 0.55)) * TS
			var hot := 0.5 + 0.5 * sin(t * 6.0 + k)
			draw_circle(c, 9.0, Color(1.0, 0.45 + 0.2 * hot, 0.15, 0.35))
			draw_circle(c, 7.0, Color("3a3f46"))
			draw_circle(c, 5.0, Color(["c7582f", "e8dcc0", "6fae4f", "d0b24a"][k]))


## Above the heads of the players: does the disguise fit here? (drawn by the Marks node)
func _draw_marks(ci: CanvasItem) -> void:
	if main.state != "play":
		return
	var font := ThemeDB.fallback_font
	for pid in 2:
		var pl = main.players[pid]
		var at: Vector2 = pl.global_position + Vector2(0, -80)   # above the name tag
		if changing[pid] > 0.0:
			ci.draw_arc(at, 7.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - changing[pid] / CHANGE_TIME), 20, UI.YELLOW, 3.0)
			continue
		if zone_of(pid) == "":
			continue
		var ok := suspicion(pid) <= 0.0
		var text := "passt" if ok else "fällt auf"
		var col := UI.GREEN if ok else UI.RED
		if not ok and fmod(t, 0.6) > 0.42:
			continue   # blinks
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		ci.draw_rect(Rect2(at.x - w / 2.0 - 4.0, at.y - 8.0, w + 8.0, 12.0), Color(0.08, 0.09, 0.17, 0.8))
		ci.draw_string(font, Vector2(at.x - w / 2.0, at.y + 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
