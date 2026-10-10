extends Node2D
## Level 4 · Chemiepraktikum (day, two players). Definition (DEF), the lab (build_map) and logic.
## Everything of this level lives in this folder (found by levels.gd through the folder name).
##
## The robotics lab in the south wing of the main building becomes the teaching lab of general
## chemistry: benches with sinks and reagent shelves, fume hoods, an emergency shower, a blackboard,
## and in the pavilion behind it the store room with safety cabinet and gas cylinders.
## Prof. Dr. Siedler walks his rounds, other students work.
##
## Challenge 1, pipetting, for two and with the camera (pipette_game.gd): one player presses the
##   pipette (thumb and index finger pinched just the right amount), the other one holds the glass
##   (a flat hand held level and without shaking). Done when both are right at the same time
##   until the glass is full. Without a camera the same game is played with keys.
## Challenge 2, the fondue alarm (blow_game.gd): after the pipetting, the professor's fondue in
##   fume hood 1 starts to boil over. Both run there and cool it by blowing into the microphone;
##   without a microphone both hammer on their key. If it boils over, a jet of flame sets both
##   players on fire: they have to get under the emergency shower and then try again. Whoever
##   burns too long without showering makes the professor boil over.
## Challenge 3, the Testat: once both have pipetted, each player sits down at one of the two desks
##   in front of the professor and answers easy chemistry questions, series A at the left desk and
##   series B at the right one. The questions are meant to be passed by anybody, and one wrong
##   answer is allowed. Whoever still fails makes the professor boil over (prof_rage.gd), and both
##   start the level again.
##
## All positions are in tiles (1 tile = 32 px) unless a name ends in _px.

const TS := 32.0
const ART = preload("res://scripts/character_art.gd")
const CH = preload("res://scripts/characters.gd")
const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const Cutscene = preload("res://scripts/cutscene.gd")
const Person = preload("lab_person.gd")
const Quiz = preload("chem_quiz.gd")
const Rage = preload("prof_rage.gd")
const LabSfx = preload("lab_sfx.gd")
const PipetteGame = preload("pipette_game.gd")
const BlowGame = preload("blow_game.gd")

const DEF := {
	"name": "Chemiepraktikum",
	"tag": "LEVEL 4",
	"mode": "day",
	"time": 360.0,
	"start": Vector2(69.9, 63.2),   # just inside the lab door
	"timer_title": "PRAKTIKUM ENDET IN",
	"intro": "Praktikum Allgemeine Chemie bei Prof. Dr. Siedler. Er gilt als ruhig, solange niemand einen Fehler macht. Beide müssen alles erledigen:",
	"hint": "Pipettiert wird zu zweit vor der Kamera, gekühlt wird mit Pusten ins Mikrofon. Wer zu wenig pustet, fängt Feuer und muss unter die Notdusche. Im Testat ist ein Fehler erlaubt; fällt jemand durch, kocht der Professor über, und ihr fangt beide von vorne an.",
	"start_toast": ["Willkommen im Labor", "Geht zusammen an einen freien Platz mit gelber Matte. Wer dort drückt, nimmt die Pipette, die andere Person hält das Glas. Und: Im Labor wird nicht gerannt."],
	"win_title": "Testat bestanden",
	"win_text": "%s & %s haben pipettiert, ein Fondue gerettet und das Testat bestanden. Prof. Dr. Siedler bleibt unter 100 °C.",
	"lose_title": "Praktikum vorbei",
	"lose_text": "Die Laborzeit ist um, und das Testat ist nicht bestanden. Prof. Dr. Siedler notiert etwas. Mit Rotstift.",
	"tasks": [
		{"id": "pipette", "name": "Pipettieren", "where": "zu zweit an einem freien Laborplatz, vor der Kamera", "type": "level"},
		{"id": "cool", "name": "Blubber-Alarm stoppen", "where": "Kapelle 1, sobald es blubbert: zu zweit kühl pusten (Mikrofon)", "type": "level"},
		{"id": "testat", "name": "Testat bestehen", "where": "vorne beim Professor, Serie A und B", "type": "level"},
	],
}

# ---- tuning
const Q_COUNT := 4            # questions per player, drawn from the series of the desk
const Q_ALLOWED := 1          # wrong answers that are still a pass
const REACH := 0.85           # tiles: this close to a bench place or a desk, from any side, it can be used
const PARTNER_DIST := 2.6     # tiles: pipetting needs the second player this close, to hold the glass
const ALARM_START := 0.38     # how hot the fondue is when the alarm goes off (0..1, 1 = burnt)
const ALARM_RISE := 0.014     # per second while nobody cools it: about 45 seconds until it boils over
const FLARE_RESET := 0.5      # how hot the fondue is after it boiled over and the flame is out
const BURN_MAX := 20.0        # seconds a player may burn before it is too late
const SHOWER_TIME := 4.0      # seconds the emergency shower runs after one pull
const SOAK := 0.8             # seconds under the water until the fire is out
const WET := 7.0              # seconds a player drips afterwards
const RUN_SCOLD := 5.0        # seconds between two scoldings for running in the lab
const PROF_SPEED := 44.0      # px per second on his rounds
const PROF_PAUSE := Vector2(1.4, 3.0)
const PROF_NAME := "Prof. Dr. Siedler"

# ---- questions: [question, [answers], index of the correct answer]. The answers are shuffled.
const SET_NAMES := ["A", "B"]
const SET_A := [   # things everybody knows from the kitchen
	["Was ist H2O?", ["Wasser", "Orangensaft", "Benzin"], 0],
	["Was passiert mit Wasser bei 0 °C?", ["Es gefriert zu Eis", "Es fängt an zu brennen", "Es wird zu Gold"], 0],
	["Was passiert mit Wasser bei 100 °C?", ["Es kocht", "Es gefriert", "Es wird zu Schokolade"], 0],
	["Woraus besteht ein Eiswürfel?", ["Aus gefrorenem Wasser", "Aus Glas", "Aus Zucker"], 0],
	["Welches Gas brauchen wir zum Atmen?", ["Sauerstoff", "Helium", "Lachgas"], 0],
	["Was steigt aus kochendem Wasser auf?", ["Wasserdampf", "Rauchzeichen", "Sternenstaub"], 0],
	["Was streut man aufs Frühstücksei?", ["Salz", "Sand", "Zement"], 0],
	["Wie sieht reines Wasser im Glas aus?", ["Durchsichtig", "Pink", "Schwarz"], 0],
]
const SET_B := [   # staying alive in the lab
	["Was trägt man im Labor vor den Augen?", ["Eine Schutzbrille", "Eine Schlafmaske", "Eine Taucherbrille"], 0],
	["Darf man im Labor Chemikalien trinken?", ["Nein, niemals", "Ja, wenn sie blau sind", "Nur zum Znüni"], 0],
	["Was trägt man im Labor über den Kleidern?", ["Einen Labormantel", "Einen Bademantel", "Ein Superheldencape"], 0],
	["Was tut man, wenn es im Labor brennt?", ["Alarm schlagen und rausgehen", "Marshmallows holen", "Ein Selfie machen"], 0],
	["Darf man im Labor rennen?", ["Nein", "Ja, immer", "Nur rückwärts"], 0],
	["Womit misst man die Temperatur?", ["Mit einem Thermometer", "Mit einem Lineal", "Mit einer Waage"], 0],
	["Womit misst man 10.0 mL ab?", ["Mit einer Pipette", "Mit einer Gabel", "Mit dem Hut des Professors"], 0],
	["Was macht man nach dem Experiment mit den Händen?", ["Waschen", "Ablecken", "In die Hosentasche stecken"], 0],
]
const SETS := [SET_A, SET_B]

# ---- the order of the level
const PH_PIPETTE := 1
const PH_ALARM := 2
const PH_TESTAT := 3

# ---- what the professor shouts when somebody burnt down next to his burnt fondue
const FONDUE_RANTS := [
	"Brennende Studierende sind in der Laborordnung NICHT vorgesehen!",
	"Die Notdusche hängt seit 1987 an dieser Wand. NEUNZEHNHUNDERTSIEBENUNDACHTZIG!",
	"Gruyère und Vacherin, je zur Hälfte, und Sie machen daraus KOHLENSTOFF!",
	"Das war kein Käse mehr, das war eine PYROLYSE!",
	"Im Caquelon ist jetzt mehr Kohlenstoff als im ganzen Periodensystem!",
	"PUSTEN habe ich gesagt! Nicht ZUSCHAUEN!",
	"Wissen Sie, was ein Kilo Vacherin kostet?! Mehr als Ihr ganzes Praktikum!",
]

# ---- what the professor shouts while he boils over (two of these per fit, one on a repeat)
const RANTS := [
	"In DREISSIG Jahren Praktikum habe ich so etwas noch NIE gesehen!",
	"Das Periodensystem hat 118 Elemente. Sie haben soeben das 119. entdeckt: AHNUNGSLOSIUM!",
	"Mein pH-Wert ist gerade auf MINUS EINS gefallen. Ich bin SAUER!",
	"Mein Blutdruck hat jetzt mehr bar als jede Gasflasche in diesem Raum!",
	"Sie sind der einzige Katalysator hier: Sie beschleunigen meinen HERZINFARKT!",
	"Avogadro dreht sich im Grab. Und zwar 6.022 mal 10 hoch 23 Mal!",
	"Selbst die Edelgase reagieren mehr als Sie in diesem Testat!",
	"Das war keine Antwort. Das war eine exotherme Reaktion in MEINEM Kopf!",
]

# ---- the rooms (the former robotics lab: south wing and its pavilion) and their furniture
const ROOM := Rect2(69.0, 57.0, 18.0, 8.0)           # the teaching lab
const PAVILION := Rect2(78.0, 65.0, 9.0, 6.0)        # the store room, through the opening in the south wall
const WALL_Y := 56.0                                 # the wall row above the lab: board, periodic table, clock
const BENCHES := [Rect2(70.8, 60.9, 4.8, 1.2), Rect2(79.4, 60.9, 4.8, 1.2), Rect2(79.6, 67.9, 4.8, 1.2)]   # each blocks one tile row
const STATION_Y := 60.9                      # the two free places are on the first two benches
const STATION_X := [73.8, 81.2]
const DESKS := [Rect2(75.15, 58.25, 1.7, 0.85), Rect2(78.15, 58.25, 1.7, 0.85)]   # series A, series B
const PROF_FRONT := Vector2(77.5, 57.75)     # between the desks, in front of the blackboard
const AISLE_Y := 62.8                        # the cross aisle south of the benches
const ALARM_SPOT := Vector2(84.6, 62.8)      # where the professor stands during the fondue alarm
const PATROL := [Vector2(77.5, 57.75), Vector2(77.5, 62.8), Vector2(72.5, 62.8), Vector2(77.5, 62.8), Vector2(84.6, 62.8),
	Vector2(82.0, 62.8), Vector2(82.0, 66.9), Vector2(82.0, 62.8), Vector2(77.5, 62.8)]
const WORK := [Vector2(72.0, 60.75), Vector2(83.0, 60.75), Vector2(81.0, 67.75), Vector2(83.2, 67.75), Vector2(72.2, 63.85)]
const COOL_ONE := 1                          # this student wears headphones and notices nothing
const WALKER := 4                            # this one carries flasks between sink, fume hood and safety cabinet
const WALK_STOPS := [Vector2(85.3, 60.2), Vector2(82.8, 69.75), Vector2(72.2, 63.85)]
const HOODS := [Vector2(85.95, 58.9), Vector2(85.95, 61.9), Vector2(85.95, 66.4)]   # on the east walls
const HOOD_SIZE := Vector2(1.05, 2.6)
const SINK := Rect2(70.6, 64.1, 3.2, 0.85)
const SHELF := Rect2(74.2, 64.1, 4.6, 0.85)
const CABINET := Rect2(80.2, 70.1, 2.4, 0.85)
const WASTE := Rect2(83.0, 70.2, 1.5, 0.7)
const GAS := Rect2(78.1, 66.2, 1.4, 3.2)
const COATS := Rect2(69.0, 57.4, 0.5, 2.9)
const SHOWER := Rect2(85.45, 57.15, 1.4, 1.4)
const BOARD := Rect2(73.4, 56.1, 8.2, 0.85)   # on the north wall
const PTABLE := Rect2(69.7, 56.12, 3.3, 0.8)
const PROF_LOOK := {"skin": "f1c9a5", "hair": "ece8e0", "hair_style": "locken", "top": "f3f3f0", "top_style": "labcoat",
	"accent": "b7352d", "pants": "3b3f46", "shoes": "1f1f24", "acc": ["glasses", "beard"]}
const BOTTLES := ["8c5a2b", "2f5d8c", "e9ece8", "3e7d4f", "b7352d", "d9a441", "5d3f7a", "e9ece8"]
const LIQUIDS := ["3ddc97", "ff8c42", "4d8dff", "ff5d8f", "ffc93c", "9b6bff"]
const LIQUID := Color("4d8dff")   # what the players pipette

static var attempts := 0      # failed Testate in a row: survives the reload, the professor remembers

var main
var t := 0.0
var rng := RandomNumberGenerator.new()
var sfx
var prof
var students: Array = []
var benches: Array = []               # Rect2 in tiles, row by row
var desk_props: Array = []
# challenge 1
var st_done: Array = [-1, -1]         # station -> player who had the pipette there, -1 = not used
var st_busy: Array = [-1, -1]         # station -> player who has the pipette there right now
# challenge 2
var phase := PH_PIPETTE
# challenge 2
var alarm_heat := 0.0                 # the fondue: 0 = cold, 1 = burnt
var beep_t := 0.0
var cloud_col := UI.GREEN             # what comes out of fume hood 1 when the professor explodes
# on fire after the fondue boiled over
var burning: Array = [false, false]
var burn_t: Array = [0.0, 0.0]        # seconds left until it is too late
var soak: Array = [0.0, 0.0]          # seconds under the running shower
var wet_t: Array = [0.0, 0.0]         # dripping afterwards
var shower_t := 0.0                   # > 0: the emergency shower is running
var fx_top: Node2D                    # flames and water, drawn over the characters
var desk_who: Array = [-1, -1]        # desk -> player sitting there
var desk_done: Array = [false, false]
var desk_failed := -1
var p_desk: Array = [-1, -1]
var p_col: Array = [[0, 0], [0, 0]]   # collision layer and mask before sitting down
# professor and students
var prof_i := 0
var prof_wait := 2.0
var glance_t := 0.0
var walk_i := 0
var walk_wait := 3.0
var scold_t := 0.0
var coats_taken := 0
var greeted := false
# fail animation
var failing := false
var rage = null
var rattle := 0.0                     # glassware shakes while he rages
var boom_t := 0.0                     # the cloud from the fume hood after the bang


## Furniture that sorts with the characters (the desk hides the legs of whoever sits behind it).
class Prop:
	extends Node2D
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


# ================================================================== map
## Called by map_data.gd: clears out the robotics lab and furnishes the chemistry lab.
static func build_map(md) -> void:
	md.objs = md.objs.filter(func(o): return not (o["kind"] in ["labbench", "robot", "rack", "labdesk", "locker"]))
	for b in BENCHES:
		var br: Rect2 = b
		md.R("l4_bench", br.position.x, br.position.y, br.size.x, br.size.y)
	for d in DESKS:
		var r: Rect2 = d
		md.R("l4_desk", r.position.x, r.position.y, r.size.x, r.size.y)
	var hood_info := [
		["Kapelle 1", "Ein rotes Caquelon auf dem Bunsenbrenner, es riecht nach Käse. Am Glas klebt ein Zettel: «NICHT anfassen. Nicht probieren. S.»"],
		["Kapelle 2", "Ein Becherglas auf der Heizplatte. Es riecht nach Orange und nach Ärger."],
		["Kapelle 3", "Leer und blitzblank. Hier arbeitet der Professor persönlich."],
	]
	for i in HOODS.size():
		var hp: Vector2 = HOODS[i]
		md.R("l4_hood", hp.x, hp.y, HOOD_SIZE.x, HOOD_SIZE.y, {"use": "info", "label": "In die Kapelle schauen", "info": hood_info[i]})
	md.R("l4_sink", SINK.position.x, SINK.position.y, SINK.size.x, SINK.size.y)
	md.R("l4_shelf", SHELF.position.x, SHELF.position.y, SHELF.size.x, SHELF.size.y, {"use": "info", "label": "Glasschrank ansehen",
		"info": ["Glasschrank", "Erlenmeyerkolben, Bechergläser, Messzylinder. Jedes zerbrochene Stück kostet 12 Franken und einen Blick des Professors."]})
	md.R("l4_cabinet", CABINET.position.x, CABINET.position.y, CABINET.size.x, CABINET.size.y, {"use": "info", "label": "Gefahrstoffschrank ansehen",
		"info": ["Gefahrstoffschrank", "Abgeschlossen. Den Schlüssel trägt Prof. Dr. Siedler um den Hals, auch beim Schlafen."]})
	md.R("l4_waste", WASTE.position.x, WASTE.position.y, WASTE.size.x, WASTE.size.y)
	md.R("l4_gas", GAS.position.x, GAS.position.y, GAS.size.x, GAS.size.y, {"use": "info", "label": "Gasflaschen ansehen",
		"info": ["Gasflaschen", "Stickstoff, Sauerstoff, Argon, alle angekettet. Bis 200 bar. Der Professor schafft mehr."]})
	md.R("l4_coats", COATS.position.x, COATS.position.y, COATS.size.x, COATS.size.y)
	md.R("l4_shower", SHOWER.position.x, SHOWER.position.y, SHOWER.size.x, SHOWER.size.y, {"solid": false, "use": "info", "label": "Notdusche ansehen",
		"info": ["Notdusche", "Nur im Notfall ziehen. Der letzte Fehlalarm hat das Labor geflutet und den Professor auf 96 °C gebracht."]})
	md.R("l4_board", BOARD.position.x, BOARD.position.y, BOARD.size.x, BOARD.size.y, {"solid": false, "use": "info", "label": "Wandtafel lesen",
		"info": ["Wandtafel", "«Testat heute! Serie A und B, je %d Fragen, ein Fehler erlaubt. Wer durchfällt, erklärt es mir persönlich. S.»" % Q_COUNT]})
	for l in md.labels:
		if l["t"] == "LABOR · ROBOTIK":
			l["t"] = "CHEMIELABOR"
			l["p"] = Vector2(77.5, 62.95)
			l["sz"] = 0.5
	for z in md.zones:
		if z[1] == "Labor · Robotik":
			z[1] = "Chemielabor"


# ================================================================== setup
func _ready() -> void:
	z_index = -5   # floor decoration and furniture: above the map, below the characters
	rng.randomize()
	sfx = LabSfx.new()
	add_child(sfx)
	# Wake the tracker now, so the camera is ready when the players reach the bench.
	# It is let go again as soon as the pipetting is done (pipette_done).
	Track.use(self, ["hand"], false)
	benches = BENCHES.duplicate()
	for k in DESKS.size():
		var r: Rect2 = DESKS[k]
		var dp := Prop.new()
		dp.position = Vector2(r.get_center().x, r.end.y) * TS
		dp.paint = func(ci): _paint_desk(ci, k)
		main.actors.add_child(dp)
		desk_props.append(dp)
	_spawn_people()
	fx_top = Prop.new()
	fx_top.z_as_relative = false
	fx_top.z_index = 4   # over the characters, under the name tags of fx.gd
	fx_top.paint = _paint_top
	add_child(fx_top)


func _lab_look() -> Dictionary:
	var lk: Dictionary = CH.random_student(rng)
	lk["accent"] = lk["top"]
	lk["top"] = "f3f3f0"
	lk["top_style"] = "labcoat"
	lk["acc"] = ["goggles"]
	return lk


func _spawn_people() -> void:
	prof = Person.new()
	prof.main = main
	prof.is_prof = true
	prof.look = PROF_LOOK.duplicate(true)
	prof.speed = PROF_SPEED
	prof.facing = ART.FRONT
	prof.position = PROF_FRONT * TS
	main.actors.add_child(prof)
	for i in WORK.size():
		var s = Person.new()
		s.main = main
		s.look = _lab_look()
		s.facing = ART.FRONT
		s.home_facing = ART.FRONT
		s.position = (WORK[i] as Vector2) * TS
		if i == COOL_ONE:
			s.cool = true
			(s.look["acc"] as Array).append("headphones")
		main.actors.add_child(s)
		students.append(s)


# ================================================================== loop
func _process(delta: float) -> void:
	t += delta
	scold_t = maxf(0.0, scold_t - delta)
	boom_t = maxf(0.0, boom_t - delta * 0.45)
	if rage != null:
		prof.heat = rage.heat
		rattle = rage.heat
	elif not failing:
		prof.heat = move_toward(prof.heat, 0.0, delta * 0.12)
		if _alarm_on():
			prof.heat = maxf(prof.heat, alarm_heat * 0.75)
	if not greeted and main.state == "play":
		greeted = true
		if attempts > 0:
			main.hud.toast("Versuch Nr. %d" % (attempts + 1), "%s ist wieder auf 37 °C abgekühlt. Vorläufig. Also nochmals von vorne." % PROF_NAME, 6.0)
	queue_redraw()
	fx_top.queue_redraw()


func _physics_process(delta: float) -> void:
	if main.state != "play":
		return
	_update_prof(delta)
	_update_walker(delta)
	if _alarm_on():
		_update_alarm(delta)
	_update_fire(delta)


## Pipetting: he walks his rounds through the aisles. Alarm: he stands at the fume hood.
## Testat: he stands in front and watches.
func _update_prof(delta: float) -> void:
	if prof.mode == "walk" or phase == PH_ALARM:
		return
	if phase == PH_TESTAT:
		glance_t -= delta
		if glance_t <= 0.0:
			glance_t = 1.5
			var look_at: Array = [ART.FRONT]
			if desk_who[0] >= 0:
				look_at.append(ART.LEFT)
			if desk_who[1] >= 0:
				look_at.append(ART.RIGHT)
			prof.facing = look_at[rng.randi() % look_at.size()]
		return
	prof_wait -= delta
	if prof_wait > 0.0:
		return
	prof_i = (prof_i + 1) % PATROL.size()
	var target: Vector2 = PATROL[prof_i]
	prof.walk([target * TS], func():
		prof_wait = rng.randf_range(PROF_PAUSE.x, PROF_PAUSE.y)
		if target == PROF_FRONT or target.y > AISLE_Y + 1.0:
			prof.facing = ART.FRONT   # at the blackboard; in the store room he watches the bench there
		else:
			prof.facing = [ART.LEFT, ART.RIGHT, ART.BACK][rng.randi() % 3])


## One student carries flasks from the sink to the fume hood, to the safety cabinet and back.
func _update_walker(delta: float) -> void:
	var w = students[WALKER]
	if w.mode == "walk":
		return
	walk_wait -= delta
	if walk_wait > 0.0:
		return
	var stop: Vector2 = (WALK_STOPS[walk_i] as Vector2) * TS
	var arriving := walk_i
	walk_i = (walk_i + 1) % WALK_STOPS.size()
	var p: Array = main.world.find_path(w.global_position, stop)
	p.append(stop)
	w.carry = Color(LIQUIDS[rng.randi() % LIQUIDS.size()]) if arriving != 2 else Color(0, 0, 0, 0)
	w.speed = 52.0
	w.walk(p, func():
		walk_wait = rng.randf_range(3.0, 6.0)
		w.carry = Color(0, 0, 0, 0)
		w.facing = [ART.RIGHT, ART.FRONT, ART.FRONT][arriving]
		w.home_facing = w.facing)


# ================================================================== challenge 1: pipetting
## Where somebody stands who walks up to place k from the aisle (the side the door is on).
func _station_stand(k: int) -> Vector2:
	return Vector2(STATION_X[k], STATION_Y + (BENCHES[k] as Rect2).size.y + 0.3)


## Distance from `p` to the nearest point of `r`, in tiles: 0 inside, grows on every side.
func _dist_to(p: Vector2, r: Rect2) -> float:
	return p.distance_to(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))


func _station_rect(k: int) -> Rect2:
	return Rect2(float(STATION_X[k]) - 0.7, STATION_Y, 1.4, (BENCHES[k] as Rect2).size.y)


## The player who presses at the bench takes the pipette, the other one has to stand next to
## them and holds the glass.
func _use_station(pid: int, k: int) -> void:
	var other := 1 - pid
	if st_busy[k] >= 0 or main.busy(other):
		main.hud.toast("Moment!", "%s ist gerade beschäftigt." % Game.name_of(other), 2.5)
		return
	if main.players[other].global_position.distance_to(main.players[pid].global_position) > PARTNER_DIST * TS:
		main.hud.toast("Das geht nur zu zweit", "Du nimmst die Pipette, aber %s muss neben dir stehen und das Glas halten." % Game.name_of(other), 4.0)
		return
	for pl in main.players:
		# both turn to the bench, whichever side of it they are on
		var north: bool = pl.global_position.y < (STATION_Y + 0.6) * TS
		pl.dir = PI / 2.0 if north else -PI / 2.0
		pl.facing = ART.FRONT if north else ART.BACK
	st_busy[k] = pid
	start_pipette(pid, k)


## Challenge 1: the camera game for two (pipette_game.gd), opened like main.open_coop_minigame
## opens a co-op minigame. `pid` has the pipette, the other player holds the glass.
## It ends with exactly one of these:
##   pipette_done(pid, k)     the glass is full, the task is done for both
##   pipette_aborted(pid, k)  somebody left the game, nothing happens
##   pipette_failed(pid, k)   not used by the camera game (nobody can fail it), kept as a hook:
##                            the professor boils over and the level restarts
func start_pipette(pid: int, k: int) -> void:
	var mg = PipetteGame.new()
	mg.pipetter = pid
	mg.sfx = sfx
	for j in 2:
		main.minis[j] = mg
		main.nears[j] = null
		main.players[j].enabled = false
	main.add_child(mg)
	mg.open()
	_freeze_views(mg)
	mg.finished.connect(func(ok: bool):
		if main.minis[0] != mg and main.minis[1] != mg:
			return
		for j in 2:
			if main.minis[j] == mg:
				main.minis[j] = null
		if main.state != "play":
			return
		for pl in main.players:
			pl.enabled = true
		if ok:
			pipette_done(pid, k)
		else:
			pipette_aborted(pid, k)
			main.hud.toast("Abgebrochen", "Ihr könnt es jederzeit nochmals versuchen.", 2.5))


## The map is one huge drawing and takes most of the time of every frame. While a game covers the
## whole screen, the two views are not drawn again (they keep their last picture), so the camera
## picture and the gauges run smoothly. They are switched back on when the game leaves the tree.
func _freeze_views(mg: Node) -> void:
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


func pipette_done(pid: int, k: int) -> void:
	st_busy[k] = -1
	st_done[k] = pid
	Track.release(self)   # the camera is not needed any more in this level
	sfx.play("drip", -4.0)
	main._coop_done("pipette")
	var tw := create_tween()   # let the celebration finish first
	tw.tween_interval(2.0)
	tw.tween_callback(_start_alarm)


func pipette_failed(pid: int, k: int) -> void:
	st_busy[k] = -1
	_fail(pid, -1, 0, "pipette")


func pipette_aborted(_pid: int, k: int) -> void:
	st_busy[k] = -1


# ================================================================== challenge 2: the fondue alarm
func _hood_rect() -> Rect2:
	return Rect2(HOODS[0], HOOD_SIZE)


## On the floor in front of fume hood 1.
func _hood_stand() -> Vector2:
	var h: Vector2 = HOODS[0]
	return Vector2(h.x - 0.55, h.y + HOOD_SIZE.y / 2.0)


func _alarm_on() -> bool:
	return phase == PH_ALARM and not main.done[0].has("cool") and not failing


## The professor watched the pipetting and forgot his fondue on the burner in fume hood 1.
func _start_alarm() -> void:
	if main.state != "play" or phase != PH_PIPETTE:
		return
	phase = PH_ALARM
	alarm_heat = ALARM_START
	beep_t = 0.0
	prof.say("!", 4.0, UI.RED)
	prof.speed = 110.0
	var at: Vector2 = prof.global_position / TS
	var p: Array = []
	if absf(at.y - AISLE_Y) > 0.1:
		p.append(Vector2(at.x, AISLE_Y) * TS)   # down the middle aisle, or out of the store room
	p.append(ALARM_SPOT * TS)
	prof.walk(p, func(): prof.facing = ART.RIGHT)
	for s in students:
		if not s.cool:
			s.face(_hood_stand() * TS - s.global_position)
			s.say("!", 2.0)
	main.hud.toast("Blubber-Alarm!", "%s: «MEIN FONDUE! Kapelle 1! Schnell, zu zweit hin und kühl pusten, bevor es eine Stichflamme gibt!»" % PROF_NAME, 7.0)


## While nobody cools it, the fondue keeps getting hotter. At 1 it boils over.
func _update_alarm(delta: float) -> void:
	if _on_fire():
		return   # it waits until the fire is out
	var mg = main.minis[0]
	if mg != null and "temp" in mg:
		alarm_heat = float(mg.temp) / 100.0   # the game at the fume hood has it now
		return
	alarm_heat = minf(1.0, alarm_heat + ALARM_RISE * delta)
	beep_t -= delta
	if beep_t <= 0.0:
		beep_t = lerpf(1.4, 0.5, alarm_heat)
		sfx.play("alarm", -13.0)
	if alarm_heat >= 1.0:
		_flare()


func _use_hood(pid: int) -> void:
	var other := 1 - pid
	if _on_fire():
		main.hud.toast("Ihr brennt!", "Erst unter die Notdusche, gleich oberhalb von Kapelle 1. Dann nochmals pusten.", 3.0)
		return
	if main.busy(other):
		main.hud.toast("Moment!", "%s ist gerade beschäftigt." % Game.name_of(other), 2.5)
		return
	if main.players[other].global_position.distance_to(main.players[pid].global_position) > PARTNER_DIST * TS:
		main.hud.toast("Das geht nur zu zweit", "%s muss auch zur Kapelle 1 kommen. Allein bekommt ihr das Fondue nicht kühl." % Game.name_of(other), 4.0)
		return
	for pl in main.players:
		pl.dir = 0.0
		pl.facing = ART.RIGHT
	start_cooling(pid)


## Challenge 2: the game at the fume hood (blow_game.gd), for both players at once.
func start_cooling(pid: int) -> void:
	var mg = BlowGame.new()
	mg.temp = alarm_heat * 100.0
	mg.sfx = sfx
	for j in 2:
		main.minis[j] = mg
		main.nears[j] = null
		main.players[j].enabled = false
	main.add_child(mg)
	mg.open()
	_freeze_views(mg)
	var leave := func() -> bool:
		if main.minis[0] != mg and main.minis[1] != mg:
			return false
		alarm_heat = float(mg.temp) / 100.0
		for j in 2:
			if main.minis[j] == mg:
				main.minis[j] = null
		return main.state == "play"
	mg.finished.connect(func(ok: bool):
		if not leave.call():
			return
		for pl in main.players:
			pl.enabled = true
		if ok:
			_cooled()
		else:
			main.hud.toast("Abgebrochen", "Das Fondue wird weiter heisser. Schnell zurück an die Kapelle 1!", 3.0))
	mg.burnt.connect(func():
		if leave.call():
			for pl in main.players:
				pl.enabled = true
			_flare())


func _cooled() -> void:
	main._coop_done("cool")
	prof.say("...", 2.0, UI.WHITE)
	var tw := create_tween()   # let the celebration finish first
	tw.tween_interval(2.2)
	tw.tween_callback(_start_testat)


# ------------------------------------------------------------------ on fire
func _on_fire() -> bool:
	return burning[0] or burning[1]


## The fondue boils over and a jet of flame shoots out of the fume hood: both players burn.
## They have to get under the emergency shower (next to fume hood 1) and can then try again.
func _flare() -> void:
	if main.state != "play" or failing:
		return
	alarm_heat = FLARE_RESET
	main.mistakes_total += 1
	boom_t = 1.0
	cloud_col = Color("ff8c42")
	for pid in 2:
		burning[pid] = true
		burn_t[pid] = BURN_MAX
		soak[pid] = 0.0
		wet_t[pid] = 0.0
		main.players[pid].modulate = Color(1.0, 0.72, 0.6)
	prof.say("!", 3.0, UI.RED)
	prof.heat = maxf(prof.heat, 0.6)
	for s in students:
		if not s.cool:
			s.say("!", 2.5, UI.RED)
	sfx.play("boom", -8.0)
	UI.sfx("fail")
	main.fx.sound(_hood_stand() * TS, 5.0 * TS, Color(1.0, 0.5, 0.2, 0.8), 0.9)
	main.hud.toast("Stichflamme! Ihr brennt!", "Zu wenig gepustet: Das Fondue ist übergekocht. Sofort unter die Notdusche, gleich oberhalb von Kapelle 1, und dort ziehen! Ihr habt %d Sekunden." % int(BURN_MAX), 7.0)


func _pull_shower(_pid: int) -> void:
	shower_t = SHOWER_TIME
	sfx.play("hiss", -5.0)


## Burning players run out of time; under the running shower the fire goes out.
func _update_fire(delta: float) -> void:
	shower_t = maxf(0.0, shower_t - delta)
	var under := SHOWER.grow(0.3)
	for pid in 2:
		var pl = main.players[pid]
		if wet_t[pid] > 0.0:
			wet_t[pid] -= delta
			if wet_t[pid] <= 0.0:
				pl.modulate = Color.WHITE
		if not burning[pid]:
			continue
		if shower_t > 0.0 and under.has_point(pl.global_position / TS):
			soak[pid] += delta
			if soak[pid] >= SOAK:
				burning[pid] = false
				wet_t[pid] = WET
				pl.modulate = Color(0.72, 0.86, 1.0)
				sfx.play("hiss", -8.0, 1.5)
				if not _on_fire():
					main.hud.toast("Gelöscht!", "Tropfnass, aber am Leben. Zurück zur Kapelle 1: Das Fondue blubbert schon wieder.", 5.0)
				else:
					main.hud.toast("Gelöscht!", "%s brennt noch: auch unter die Notdusche!" % Game.name_of(1 - pid), 4.0)
			continue
		burn_t[pid] -= delta
		if burn_t[pid] <= 0.0:
			_fail(pid, -1, 0, "fire")
			return


# ================================================================== challenge 3: the Testat
func _start_testat() -> void:
	if main.state != "play" or phase == PH_TESTAT:
		return
	phase = PH_TESTAT
	prof.say("!", 3.0)
	prof.speed = 80.0
	var at: Vector2 = prof.global_position / TS
	var p: Array = []
	if at.y > AISLE_Y + 0.1:
		p.append(Vector2(at.x, AISLE_Y) * TS)   # out of the store room first
	if absf(at.x - PROF_FRONT.x) > 0.1:
		p.append(Vector2(PROF_FRONT.x, minf(at.y, AISLE_Y)) * TS)   # then to the middle aisle
	p.append(PROF_FRONT * TS)
	prof.walk(p, func(): prof.facing = ART.FRONT)
	UI.sfx("mail")
	main.hud.toast("Testat!", "%s: «Das Fondue hat niemand gesehen. Verstanden? Und jetzt: Testat! Serie A am linken Pult, Serie B am rechten. %d Fragen, EIN Fehler ist erlaubt.»" % [PROF_NAME, Q_COUNT], 7.0)


func _seat_px(k: int) -> Vector2:
	var r: Rect2 = DESKS[k]
	return Vector2(r.get_center().x, r.position.y + 0.38) * TS


func _stand_px(k: int) -> Vector2:
	var r: Rect2 = DESKS[k]
	return Vector2(r.get_center().x, r.position.y - 0.45) * TS


func _use_desk(pid: int, k: int) -> void:
	if phase == PH_ALARM:
		main.hud.toast("Jetzt nicht!", "Erst das Fondue in Kapelle 1 retten, dann gibt es das Testat.", 3.0)
		return
	if phase < PH_TESTAT:
		main.hud.toast("Noch nicht", "%s: «Zuerst wird pipettiert. Das Testat kommt früh genug.»" % PROF_NAME, 3.0)
		return
	if desk_who[k] >= 0:
		main.hud.toast("Besetzt", "Hier schreibt schon %s. Nimm das andere Pult." % Game.name_of(desk_who[k]), 2.5)
		return
	var pl = main.players[pid]
	desk_who[k] = pid
	p_desk[pid] = k
	p_col[pid] = [pl.collision_layer, pl.collision_mask]
	pl.collision_layer = 0   # the seat is inside the desk's collision box
	pl.collision_mask = 0
	pl.dir = PI / 2.0
	pl.facing = ART.FRONT
	create_tween().tween_property(pl, "global_position", _seat_px(k), 0.18)
	_open_test(pid, k)


## Opens the test like main.open_minigame opens a minigame: on this player's half, with their keys.
func _open_test(pid: int, k: int) -> void:
	var pool: Array = (SETS[k] as Array).duplicate()
	pool.shuffle()
	var q = Quiz.new()
	q.screen_side = pid
	q.keys = KEYS.keys_for(pid)
	q.labels = KEYS.labels_for(pid)
	q.accent = Color(KEYS.TAG_COLORS[pid])
	main.minis[pid] = q
	main.nears[pid] = null
	main.players[pid].enabled = false
	main._update_cameras()
	main.add_child(q)
	q.open("Testat · Serie %s" % SET_NAMES[k], Game.name_of(pid), pool.slice(0, Q_COUNT), Q_ALLOWED)
	q.mistake.connect(func(): main._on_mini_mistake(pid))
	q.finished.connect(func(ok: bool, _m: int):
		if main.minis[pid] != q:
			return
		main.minis[pid] = null
		if main.state != "play":
			return
		if ok:
			_passed(pid, k)
		else:
			_fail(pid, k, q.correct, "testat"))


func _passed(pid: int, k: int) -> void:
	var pl = main.players[pid]
	desk_done[k] = true
	desk_who[k] = -1
	p_desk[pid] = -1
	desk_props[k].queue_redraw()
	var tw := create_tween()
	tw.tween_property(pl, "global_position", _stand_px(k), 0.18)
	tw.tween_callback(func():
		pl.collision_layer = p_col[pid][0]
		pl.collision_mask = p_col[pid][1]
		if main.state == "play":
			pl.enabled = true)
	main._task_done(pid, "testat")
	if not main.done[1 - pid].has("testat"):
		main.hud.toast("Bestanden", "%s nickt. Jetzt hängt alles an %s." % [PROF_NAME, Game.name_of(1 - pid)], 4.0)


# ================================================================== the professor boils over
## `k`: desk of the failed series (-1 if it was the pipetting). `got`: right answers.
func _fail(pid: int, k: int, got: int, why: String) -> void:
	if failing:
		return
	failing = true
	attempts += 1
	desk_failed = k
	if k >= 0:
		desk_props[k].queue_redraw()
	main._close_minis()
	main.state = "cutscene"   # the clock stops; the lose screen comes after the fit
	main.hud.visible = false
	for pl in main.players:
		pl.enabled = false
	# everybody in the room freezes and looks at the professor
	var bad = main.players[pid]
	prof.stop()
	prof.face(bad.global_position - prof.global_position)
	prof.say("...", 1.4, UI.WHITE)
	prof.heat = maxf(prof.heat, 0.2)
	for s in students:
		s.stop()
		s.carry = Color(0, 0, 0, 0)
		s.scared = 1.0
		if not s.cool:
			s.face(prof.global_position - s.global_position)
			s.say("!", 1.6)
	create_tween().tween_property(main, "zoom", 3.3, 0.9).set_trans(Tween.TRANS_SINE)   # main.zoom moves both cameras
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_callback(func(): _play_rage(pid, k, got, why))


func _wears_coat(pid: int) -> bool:
	return String(main.players[pid].look.get("top_style", "")) == "labcoat"


## The beats of the fit (see prof_rage.gd). Shorter when the players have seen it before.
## `why`: "testat" (failed series k with `got` right answers), "fire" (burnt too long), "pipette".
func _rage_beats(pid: int, k: int, got: int, why: String) -> Array:
	var who: String = Game.name_of(pid)
	var first := attempts <= 1
	var out: Array = []
	var verdict := "%s: %d von %d richtig" % [who, got, Q_COUNT]
	var opening := "%s. Serie %s. %d von %d richtig." % [who, SET_NAMES[maxi(k, 0)], got, Q_COUNT]
	var pool: Array = RANTS.duplicate()
	var last := "RAUS AUS MEINEM LABOR! ALLES NOCHMAL VON VORNE!"
	var stamp := "DURCHGEFALLEN"
	match why:
		"fire":
			verdict = "%s: Notdusche nicht gefunden" % who
			opening = "%s. Sie brennen. Seit zwanzig Sekunden. Neben meinem Fondue." % who
			pool = FONDUE_RANTS.duplicate()
			last = "RAUS AUS MEINEM LABOR! UND ZWAR UNTER DIE DUSCHE!"
			stamp = "VERKOHLT"
		"pipette":
			verdict = "%s: daneben pipettiert" % who
			opening = "%s. Das waren keine 10.0 Milliliter." % who
	if first:
		out.append({"text": opening, "heat": 0.22, "size": 26, "speed": 22.0})
		out.append({"text": "Ganz ruhig, Siedler. Einatmen ... ausatmen ... einatm-", "heat": 0.45, "calm": true, "size": 24, "speed": 20.0})
	else:
		out.append({"text": "%s. Schon. Wieder. Das ist Versuch Nummer %d." % [who, attempts], "heat": 0.4, "size": 26, "speed": 22.0})
	pool.shuffle()
	var n := 2 if first else 1
	for i in n:
		out.append({"text": pool[i], "heat": 0.62 + 0.3 * float(i + 1) / n, "size": 28 + i * 3, "speed": 60.0})
	if why != "fire" and not _wears_coat(pid):
		out.append({"text": "Und einen LABORMANTEL tragen Sie AUCH nicht!", "heat": 0.95, "size": 31, "speed": 70.0})
	out.append({"text": last, "burst": true, "size": 40, "speed": 90.0})
	out.append({"stamp": stamp, "sub": verdict})
	return out


func _play_rage(pid: int, k: int, got: int, why: String) -> void:
	prof.facing = ART.FRONT
	prof.raging = true
	rage = Rage.new()
	rage.look = prof.look
	rage.pname = PROF_NAME
	rage.sfx = sfx
	rage.top_mark = "MEIN FONDUE" if why == "fire" else ""
	main.add_child(rage)
	cloud_col = Color("c8962e") if why == "fire" else UI.GREEN
	rage.burst.connect(func():
		boom_t = 1.0
		for s in students:
			s.ducked = true)
	rage.play(_rage_beats(pid, k, got, why), func(): _after_rage(pid, k, got, why))


## The generic lose screen: "Nochmals versuchen" (or R) reloads the level, M goes to the menu.
func _after_rage(pid: int, k: int, got: int, why: String) -> void:
	rage = null
	rattle = 0.4
	prof.heat = 1.0   # he keeps fuming behind the lose screen
	main.hud.visible = true
	main.state = "lost"
	var title := "Durchgefallen!"
	var what := "%s hat daneben pipettiert." % Game.name_of(pid)
	var tip := "Die Fragen sind einfacher, als der Professor aussieht."
	if why == "testat":
		what = "%s hat im Testat Serie %s nur %d von %d Fragen richtig, erlaubt ist ein Fehler." % [Game.name_of(pid), SET_NAMES[k], got, Q_COUNT]
	elif why == "fire":
		title = "Verkohlt!"
		what = "%s hat nach der Stichflamme zu lange gebrannt und es nicht unter die Notdusche geschafft." % Game.name_of(pid)
		tip = "Wenn ihr brennt: sofort unter die Notdusche oben rechts im Labor, gleich neben Kapelle 1, und dort ziehen."
	main.hud.show_overlay(title,
		"%s\n\n%s hat ebenfalls 100 °C erreicht, das Siedler-Meter ist geplatzt, und das Praktikum beginnt für euch beide von vorne.\n\nDas war Versuch %d. %s" % [what, PROF_NAME, attempts, tip],
		"R nochmals versuchen · M zum Startbildschirm", "Nochmals versuchen", true, "lose", "LEVEL %d" % Game.level)


# ================================================================== hooks called by main.gd
func update_near(pid: int) -> void:
	if failing or p_desk[pid] >= 0:
		return
	var p: Vector2 = main.players[pid].global_position / TS
	if burning[pid]:
		# nothing else matters now, not even reading the notes on the furniture
		main.nears[pid] = null
		if _dist_to(p, SHOWER) < REACH:
			main.nears[pid] = {"use": "level", "act": "shower", "label": "Notdusche ziehen!", "rect": SHOWER}
		return
	if not main.done[pid].has("pipette"):
		for k in STATION_X.size():
			if st_done[k] < 0 and _dist_to(p, _station_rect(k)) < REACH:
				main.nears[pid] = {"use": "level", "act": "pipette", "k": k, "label": "Pipettieren (zu zweit)", "rect": _station_rect(k)}
				return
	if _alarm_on() and _dist_to(p, _hood_rect()) < REACH:
		main.nears[pid] = {"use": "level", "act": "cool", "label": "Fondue kühl pusten (zu zweit)", "rect": _hood_rect()}
		return
	if not main.done[pid].has("testat"):
		for k in DESKS.size():
			var r: Rect2 = DESKS[k]
			if not desk_done[k] and _dist_to(p, r) < REACH:
				main.nears[pid] = {"use": "level", "act": "desk", "k": k, "rect": r,
					"label": "Testat Serie %s schreiben" % SET_NAMES[k] if phase == PH_TESTAT else "Testat-Pult ansehen"}
				return
	if not _wears_coat(pid) and coats_taken < 4 and p.distance_to(COATS.get_center() + Vector2(0.9, 0)) < 1.3:
		main.nears[pid] = {"use": "level", "act": "coat", "label": "Labormantel anziehen", "rect": COATS}


func interact(pid: int, o: Dictionary) -> void:
	match o["act"]:
		"pipette":
			_use_station(pid, o["k"])
		"shower":
			_pull_shower(pid)
		"cool":
			_use_hood(pid)
		"desk":
			_use_desk(pid, o["k"])
		"coat":
			_put_on_coat(pid)


## Not a task, but the professor notices who skipped it.
func _put_on_coat(pid: int) -> void:
	var pl = main.players[pid]
	pl.look["accent"] = pl.look.get("top", "2f4f8f")
	pl.look["top"] = "f3f3f0"
	pl.look["top_style"] = "labcoat"
	var acc: Array = pl.look.get("acc", [])
	acc.erase("backpack")
	if not acc.has("goggles"):
		acc.append("goggles")
	pl.look["acc"] = acc
	pl.queue_redraw()
	coats_taken += 1
	UI.sfx("steal")
	main.hud.toast("Sicherheit geht vor", "Labormantel und Schutzbrille sitzen. %s nickt kaum merklich." % PROF_NAME, 3.0)


## Goal markers for the HUD: [position in px, colour of whoever still needs it].
func goal_positions(id: String, n0: bool, n1: bool) -> Array:
	var out: Array = []
	match id:
		"pipette":
			for k in STATION_X.size():
				if st_done[k] < 0 and st_busy[k] < 0:
					out.append([Vector2(STATION_X[k], STATION_Y + 0.75) * TS, main._need_color(n0, n1)])
		"cool":
			if _on_fire():
				out.append([SHOWER.get_center() * TS, main._need_color(burning[0], burning[1])])
			elif _alarm_on():
				out.append([_hood_rect().get_center() * TS, UI.YELLOW])
		"testat":
			if phase == PH_TESTAT:
				for k in DESKS.size():
					if not desk_done[k] and desk_who[k] < 0:
						out.append([(DESKS[k] as Rect2).get_center() * TS, main._need_color(n0, n1)])
	return out


func _in_lab(p: Vector2) -> bool:
	return ROOM.has_point(p) or PAVILION.has_point(p)


## Where the dashed way of a picked task leads (Tab / comma): spots on the floor in front of the
## places. Whatever is picked, the way leads to what has to be done next.
func task_targets(id: String, pid: int) -> Array:
	var out: Array = []
	if burning[pid]:
		out.append(SHOWER.get_center() * TS)
	elif not main.done[pid].has("pipette"):
		for k in STATION_X.size():
			if st_done[k] < 0:
				out.append(_station_stand(k) * TS)
	elif _alarm_on():
		out.append(_hood_stand() * TS)
	elif id == "testat" and phase == PH_TESTAT:
		for k in DESKS.size():
			if not desk_done[k] and desk_who[k] < 0:
				var r: Rect2 = DESKS[k]
				out.append(Vector2(r.get_center().x, r.end.y + 0.45) * TS)
	return out


## Footsteps and minigame mistakes. Sprinting in the lab gets you told off.
func on_noise(at: Vector2, radius: float) -> void:
	if main.state != "play" or scold_t > 0.0 or radius < 5.0 * TS or not _in_lab(at / TS):
		return
	for pid in main.players.size():
		var pl = main.players[pid]
		if pl.gait != "sprint" or pl.global_position.distance_to(at) > 4.0:
			continue
		scold_t = RUN_SCOLD
		main.mistakes_total += 1
		if prof.mode != "walk":
			prof.face(pl.global_position - prof.global_position)
		prof.say("!", 2.0, UI.RED)
		prof.heat = 0.45
		main.fx.sound(prof.global_position, 2.6 * TS, Color(1.0, 0.4, 0.4, 0.7), 0.6)
		UI.sfx("fail")
		main.hud.toast("Nicht rennen!", "%s: «%s! Im Labor wird NICHT gerannt! Das gibt einen Strich.»" % [PROF_NAME, Game.name_of(pid)], 3.5)
		return


## Called by main.gd when every task is done: a short scene, then the win screen.
func finale(done: Callable) -> void:
	attempts = 0
	main.state = "cutscene"
	main.hud.visible = false
	for pl in main.players:
		pl.enabled = false
	prof.facing = ART.FRONT
	create_tween().tween_property(main, "zoom", 3.3, 0.9).set_trans(Tween.TRANS_SINE)   # main.zoom moves both cameras
	var steps := [
		{"say": -1, "name": PROF_NAME, "text": "Beide bestanden. Ich bin ... beinahe ... zufrieden. Mein Puls ist wieder zweistellig."},
		{"say": 0, "text": "Wir haben pipettiert, ein Fondue gerettet und nichts gesprengt. Ich finde, das zählt."},
		{"say": 1, "text": "Und er hat nicht gemerkt, dass wir gar nicht eingeschrieben sind."},
		{"title": "BESTANDEN", "sub": "Siedler-Meter: 37 °C  ·  vorläufig", "color": UI.GREEN, "sfx": "fanfare", "time": 3.2},
	]
	var cs = Cutscene.new()
	main.add_child(cs)
	cs.play(steps, func():
		main.hud.visible = true
		done.call())


# ================================================================== drawing
func _px(r: Rect2) -> Rect2:
	return Rect2(r.position * TS, r.size * TS)


func _shadow(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(2.5, 3.5), r.size), Color(0, 0, 0, 0.32))


## Glassware trembles while the professor rages.
func _rat(seed_v: float) -> Vector2:
	if rattle <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(t * 53.0 + seed_v), cos(t * 47.0 + seed_v * 1.7)) * 1.4 * rattle


## Erlenmeyer flask standing on `c` (middle of its base), with bubbles in the liquid.
func _flask(c: Vector2, s: float, liquid: Color) -> void:
	c += _rat(c.x)
	var glass := PackedVector2Array([c + Vector2(-2, -12) * s, c + Vector2(2, -12) * s, c + Vector2(2, -8) * s, c + Vector2(6, 0) * s,
		c + Vector2(-6, 0) * s, c + Vector2(-2, -8) * s])
	draw_colored_polygon(glass, Color(0.86, 0.95, 1.0, 0.7))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-3.5, -5) * s, c + Vector2(3.5, -5) * s, c + Vector2(6, 0) * s, c + Vector2(-6, 0) * s]), liquid)
	draw_polyline(glass + PackedVector2Array([glass[0]]), Color(0.2, 0.3, 0.4, 0.85), 0.8)
	for i in 2:
		var u := fmod(t * 0.9 + i * 0.5 + c.x * 0.13, 1.0)
		draw_circle(c + Vector2(-2.0 + i * 3.5, -0.8 - u * 3.6) * s, 0.8 * s, Color(1, 1, 1, 0.75 * (1.0 - u)))


func _beaker(c: Vector2, w: float, h: float, liquid: Color, fill: float) -> void:
	c += _rat(c.x + 3.0)
	var r := Rect2(c.x - w / 2.0, c.y - h, w, h)
	draw_rect(r, Color(0.86, 0.95, 1.0, 0.65))
	if fill > 0.0:
		draw_rect(Rect2(r.position.x + 1.0, r.end.y - (h - 1.0) * fill, w - 2.0, (h - 1.0) * fill), liquid)
	draw_rect(r, Color(0.2, 0.3, 0.4, 0.85), false, 0.8)
	for i in 3:
		draw_line(Vector2(r.position.x + 1.0, r.end.y - h * (0.25 + i * 0.22)), Vector2(r.position.x + 3.5, r.end.y - h * (0.25 + i * 0.22)), Color(0.2, 0.3, 0.4, 0.6), 0.6)


func _burner(c: Vector2) -> void:
	draw_rect(Rect2(c.x - 5.0, c.y - 2.5, 10.0, 2.5), Color("3b4149"))
	draw_rect(Rect2(c.x - 1.5, c.y - 9.0, 3.0, 7.0), Color("8d98a1"))
	var f := 1.0 + 0.25 * sin(t * 17.0 + c.x) + rattle * 0.9
	draw_colored_polygon(PackedVector2Array([c + Vector2(-2.6, -9.0), c + Vector2(0, -9.0 - 8.0 * f), c + Vector2(2.6, -9.0)]), Color(0.3, 0.6, 1.0, 0.9))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-1.3, -9.0), c + Vector2(0, -9.0 - 4.0 * f), c + Vector2(1.3, -9.0)]), Color(0.8, 0.95, 1.0, 0.95))


func _tubes(c: Vector2, n: int) -> void:
	c += _rat(c.x + 7.0)
	draw_rect(Rect2(c.x - 2.0, c.y - 4.0, n * 4.5 + 3.0, 4.0), Color("a9824f"))
	for i in n:
		var tx := c.x + i * 4.5
		draw_rect(Rect2(tx, c.y - 11.0, 3.0, 9.0), Color(0.86, 0.95, 1.0, 0.8))
		draw_rect(Rect2(tx + 0.5, c.y - 7.0 + (i % 2) * 1.5, 2.0, 4.5 - (i % 2) * 1.5), Color(LIQUIDS[(i + int(c.x)) % LIQUIDS.size()]))


func _draw() -> void:
	_draw_floor()
	_draw_walls()
	for i in benches.size():
		_draw_bench(i)
	for k in STATION_X.size():
		_draw_station(k)
	for i in HOODS.size():
		_draw_hood(i)
	_draw_south()
	_draw_gas()
	_draw_coats()
	_draw_shower()
	_draw_cloud()


func _draw_floor() -> void:
	# the Testat zone in front of the blackboard: dashed yellow frame, bright once the Testat is on
	var a: Rect2 = DESKS[0]
	var b: Rect2 = DESKS[1]
	var z := _px(Rect2(a.position.x - 0.45, a.position.y - 0.9, b.end.x - a.position.x + 0.9, a.size.y + 1.45))
	var alpha := 0.22 if phase < PH_TESTAT else 0.6 + 0.3 * sin(t * 5.0)
	var col := Color(UI.YELLOW, alpha)
	var x := z.position.x
	while x < z.end.x:
		var w := minf(9.0, z.end.x - x)
		draw_rect(Rect2(x, z.position.y, w, 2.0), col)
		draw_rect(Rect2(x, z.end.y - 2.0, w, 2.0), col)
		x += 15.0
	var y := z.position.y
	while y < z.end.y:
		var h := minf(9.0, z.end.y - y)
		draw_rect(Rect2(z.position.x, y, 2.0, h), col)
		draw_rect(Rect2(z.end.x - 2.0, y, 2.0, h), col)
		y += 15.0
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size("TESTAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(z.get_center().x - tw / 2.0, z.end.y - 6.0), "TESTAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UI.YELLOW, alpha + 0.1))
	# yellow line in front of the fume hoods
	for h in HOODS:
		var hp: Vector2 = h
		draw_rect(Rect2((hp.x - 0.42) * TS, hp.y * TS, 2.0, HOOD_SIZE.y * TS), Color(UI.YELLOW, 0.55))


## Things that hang on the north wall: periodic table, blackboard, clock, emergency sign.
func _draw_walls() -> void:
	var font := ThemeDB.fallback_font
	# periodic table
	var p := _px(PTABLE)
	draw_rect(p.grow(1.5), Color("2b2f35"))
	draw_rect(p, Color("f7f5ee"))
	var cw := (p.size.x - 4.0) / 18.0
	var chh := (p.size.y - 4.0) / 7.0
	for row in 7:
		for cx in 18:
			if row == 0 and cx > 0 and cx < 17:
				continue
			if row in [1, 2] and cx > 1 and cx < 12:
				continue
			var cc := Color("e8a23a")              # transition metals
			if cx < 2:
				cc = Color("e0574f")               # alkali and alkaline earth metals
			elif cx == 17:
				cc = Color("9b6bff")               # noble gases
			elif cx >= 12:
				cc = Color("3fae7a") if cx < 16 else Color("4d8dff")
			if row == 0 and cx == 0:
				cc = Color("4d8dff")               # hydrogen
			draw_rect(Rect2(p.position.x + 2.0 + cx * cw, p.position.y + 2.0 + row * chh, cw - 0.8, chh - 0.8), cc)
	# blackboard
	var b := _px(BOARD)
	draw_rect(b.grow(2.0), Color("6b4a2f"))
	draw_rect(b, Color("26493a"))
	var chalk := Color(1, 1, 1, 0.88)
	draw_string(font, b.position + Vector2(6, 12), "TESTAT HEUTE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.YELLOW)
	draw_string(font, b.position + Vector2(6, 23), "Serie A + B", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, chalk)
	draw_string(font, b.position + Vector2(98, 11), "pH = -log c(H+)", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, chalk)
	draw_string(font, b.position + Vector2(98, 22), "c = n / V    n = m / M", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, chalk)
	var hex := PackedVector2Array()
	var hc := b.position + Vector2(b.size.x - 22.0, b.size.y / 2.0)
	for i in 7:
		hex.append(hc + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * 9.5)
	draw_polyline(hex, chalk, 1.0)
	draw_arc(hc, 5.5, 0.0, TAU, 20, chalk, 1.0)
	draw_string(font, Vector2(hc.x - 46.0, b.position.y + 11.0), "C6H6 =", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.75, 0.8, 0.9))
	draw_rect(Rect2(b.position.x, b.end.y, b.size.x, 2.5), Color("8a6340"))
	draw_rect(Rect2(b.position.x + 30, b.end.y - 1.0, 7, 2.0), Color.WHITE)
	draw_rect(Rect2(b.position.x + 44, b.end.y - 1.0, 5, 2.0), UI.YELLOW)
	# clock
	var cl := Vector2(82.75, WALL_Y + 0.52) * TS
	draw_circle(cl, 10.0, Color("2b2f35"))
	draw_circle(cl, 8.5, Color("f7f5ee"))
	draw_line(cl, cl + Vector2.from_angle(-PI / 2.0 + t * 0.02) * 5.0, Color("2b2f35"), 1.5)
	draw_line(cl, cl + Vector2.from_angle(-PI / 2.0 + t * 0.24) * 7.0, Color("2b2f35"), 1.0)
	draw_line(cl, cl + Vector2.from_angle(-PI / 2.0 + floor(t) * TAU / 60.0) * 7.5, UI.RED, 0.6)
	# green sign above the emergency shower
	var sg := Rect2(84.3 * TS, (WALL_Y + 0.2) * TS, 46.0, 20.0)
	draw_rect(sg, Color("1f9d55"))
	draw_rect(sg, Color.WHITE, false, 1.0)
	draw_rect(Rect2(sg.position + Vector2(7, 3), Vector2(4, 14)), Color.WHITE)       # white cross
	draw_rect(Rect2(sg.position + Vector2(2, 8), Vector2(14, 4)), Color.WHITE)
	draw_circle(sg.position + Vector2(31, 6), 4.0, Color.WHITE)                      # shower head
	for i in 3:
		draw_line(sg.position + Vector2(27 + i * 4, 11), sg.position + Vector2(26 + i * 4.5, 17), Color.WHITE, 1.0)


func _draw_bench(i: int) -> void:
	var r := _px(benches[i])
	var left: bool = i != 1   # the sink is at the outer end
	_shadow(r)
	draw_rect(r, Color("55616b"))
	draw_rect(r.grow(-2.5), Color("f1f4f5"))
	draw_rect(Rect2(r.position.x + 2.5, r.end.y - 6.0, r.size.x - 5.0, 3.5), Color("d5dde1"))
	# sink at the outer end
	var sink := Rect2(r.position.x + 6.0 if left else r.end.x - 30.0, r.position.y + 8.0, 24.0, r.size.y - 17.0)
	draw_rect(sink, Color("8d98a1"))
	draw_rect(sink.grow(-2.5), Color("5d6972"))
	draw_circle(sink.get_center(), 1.8, Color("2b2f35"))
	draw_rect(Rect2(sink.get_center().x - 1.2, sink.position.y - 4.0, 2.4, 9.0), Color("c9d1d6"))
	draw_circle(Vector2(sink.get_center().x, sink.position.y - 4.0), 2.2, Color("c9d1d6"))
	# reagent shelf along the back edge
	var x0 := r.position.x + (36.0 if left else 8.0)
	var x1 := r.end.x - (8.0 if left else 36.0)
	draw_rect(Rect2(x0, r.position.y + 3.0, x1 - x0, 9.5), Color("a7b3ba"))
	var bx := x0 + 3.0
	var n := 0
	while bx + 5.0 < x1:
		var bo := _rat(bx)
		draw_rect(Rect2(bx + bo.x, r.position.y + 4.5 + bo.y, 5.0, 7.0), Color(BOTTLES[(i * 3 + n) % BOTTLES.size()]))
		draw_rect(Rect2(bx + 1.0 + bo.x, r.position.y + 3.0 + bo.y, 3.0, 2.0), Color("2b2f35"))
		bx += 8.5
		n += 1
	# gas taps
	for g in 2:
		var gx := lerpf(x0, x1, 0.3 + g * 0.4)
		draw_circle(Vector2(gx, r.position.y + 16.0), 1.8, UI.YELLOW if g == 0 else UI.RED)
	# glassware on the worktop (the players' places stay clear)
	var base_y := r.end.y - 8.0
	for j in 4:
		var gx2 := lerpf(x0 + 8.0, x1 - 10.0, j / 3.0)
		if i < STATION_X.size() and absf(gx2 - float(STATION_X[i]) * TS) < 34.0:
			continue
		var liquid := Color(LIQUIDS[(i * 2 + j) % LIQUIDS.size()])
		match (i + j * 3) % 4:
			0:
				_flask(Vector2(gx2, base_y), 1.0, liquid)
			1:
				_burner(Vector2(gx2, base_y))
			2:
				_tubes(Vector2(gx2 - 6.0, base_y), 3)
			3:
				_beaker(Vector2(gx2, base_y), 10.0, 11.0, liquid, 0.55)


## One of the two free places: stand with pipette, the glass under it, on a yellow mat (green when done).
func _draw_station(k: int) -> void:
	var x: float = float(STATION_X[k]) * TS
	var by: float = STATION_Y * TS
	var who: int = st_done[k]
	var busy: bool = st_busy[k] >= 0
	var mc := UI.YELLOW   # yellow = both, like everywhere
	if who >= 0:
		mc = UI.GREEN
	var mat := Rect2(x - 20.0, by + 13.5, 40.0, 20.5)
	draw_rect(mat, Color(mc, 0.25))
	draw_rect(mat, Color(mc, 0.95), false, 1.5)
	# stand: base, rod, clamp
	draw_rect(Rect2(x - 17.0, by + 28.5, 15.0, 3.5), Color("3b4149"))
	draw_rect(Rect2(x - 11.0, by + 5.0, 2.0, 24.0), Color("7f8a94"))
	draw_rect(Rect2(x - 11.0, by + 9.0, 15.0, 2.0), Color("7f8a94"))
	# pipette in the clamp
	var pip := Rect2(x + 2.5, by + 3.5, 3.6, 14.0)
	var left := 0.9 if who < 0 else 0.12
	draw_rect(pip, Color(0.86, 0.95, 1.0, 0.9))
	draw_rect(Rect2(pip.position.x + 0.7, pip.end.y - pip.size.y * left, 2.2, pip.size.y * left), LIQUID)
	draw_rect(pip, Color(0.2, 0.3, 0.4, 0.85), false, 0.7)
	draw_line(Vector2(pip.get_center().x, pip.end.y), Vector2(pip.get_center().x, pip.end.y + 3.0), Color(0.2, 0.3, 0.4, 0.85), 1.0)
	# the glass, with the mark it has to be filled to
	var fill := 0.0
	if who >= 0:
		fill = 0.62
	elif busy:
		fill = 0.62 * fmod(t * 0.45, 1.0)
	var gc := Vector2(x + 4.3, by + 32.5)
	_beaker(gc, 12.0, 11.5, LIQUID, fill)
	draw_line(Vector2(gc.x - 7.5, gc.y - 11.5 * 0.62), Vector2(gc.x + 7.5, gc.y - 11.5 * 0.62), UI.RED, 0.8)
	if busy:
		var u := fmod(t * 2.4, 1.0)
		draw_circle(Vector2(pip.get_center().x, lerpf(pip.end.y + 3.0, gc.y - 3.0, u)), 1.3, LIQUID)
	if who >= 0:
		var cp := Vector2(x + 14.0, by + 22.0)
		draw_polyline(PackedVector2Array([cp + Vector2(-3, 0), cp + Vector2(-0.5, 3), cp + Vector2(4, -4)]), UI.GREEN, 2.0)


## Fume hood on an east wall, open to the west.
func _draw_hood(i: int) -> void:
	var r := _px(Rect2(HOODS[i], HOOD_SIZE))
	_shadow(r)
	draw_rect(r, Color("69747e"))
	draw_rect(Rect2(r.position.x + 2.0, r.position.y + 3.0, r.size.x - 4.0, r.size.y - 6.0), Color("dde4e8"))
	draw_rect(Rect2(r.end.x - 7.0, r.position.y + 3.0, 5.0, r.size.y - 6.0), Color("3b434b"))
	for j in 5:
		draw_rect(Rect2(r.end.x - 6.0, r.position.y + 9.0 + j * (r.size.y - 18.0) / 4.0, 3.0, 1.5), Color("1f2429"))
	var c := Vector2(r.position.x + 15.0, r.get_center().y + 8.0)
	match i:
		0:
			_draw_fondue(c + Vector2(1.0, 2.0))
		1:
			draw_rect(Rect2(c.x - 9.0, c.y - 3.0, 18.0, 5.0), Color("2b2f35"))
			draw_rect(Rect2(c.x - 7.0, c.y - 2.0, 14.0, 1.5), Color(1.0, 0.45, 0.2, 0.6 + 0.3 * sin(t * 3.0)))
			_beaker(c + Vector2(0, -3.0), 12.0, 13.0, UI.ORANGE, 0.6)
		2:
			_tubes(c + Vector2(-7.0, 0), 3)
	if i == 0 and _alarm_on():
		# the alarm: the fume hood glows and flashes
		var pulse := 0.5 + 0.5 * sin(t * (6.0 + alarm_heat * 10.0))
		draw_rect(r, Color(1.0, 0.35, 0.1, 0.18 + 0.3 * alarm_heat * pulse))
		draw_rect(r.grow(3.0 + pulse * 3.0), Color(UI.RED, 0.35 + 0.6 * pulse), false, 3.0)
	# glass sash and the black and yellow edge
	draw_rect(Rect2(r.position.x, r.position.y + 3.0, 3.5, r.size.y - 6.0), Color(0.72, 0.9, 1.0, 0.62))
	var y := r.position.y
	var j2 := 0
	while y < r.end.y - 0.1:
		draw_rect(Rect2(r.position.x - 5.0, y, 3.0, minf(7.0, r.end.y - y)), UI.YELLOW if j2 % 2 == 0 else Color("22262b"))
		y += 7.0
		j2 += 1


## The professor's fondue in fume hood 1: a red caquelon on a burner. It bubbles and smokes
## the more, the hotter it is (alarm_heat).
func _draw_fondue(c: Vector2) -> void:
	var hot := alarm_heat if (phase == PH_ALARM or failing) else 0.12
	_burner(c + Vector2(0, 3.0))
	var top := c.y - 21.0
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - 10.0, top), Vector2(c.x + 10.0, top), Vector2(c.x + 8.0, c.y - 9.0), Vector2(c.x - 8.0, c.y - 9.0)]), Color("c0392b"))
	draw_rect(Rect2(c.x - 17.0, top + 2.0, 8.0, 2.5), Color("8e2a20"))   # handle
	draw_rect(Rect2(c.x - 1.0, top + 4.0, 2.0, 6.0), Color.WHITE)        # the white cross
	draw_rect(Rect2(c.x - 3.0, top + 6.0, 6.0, 2.0), Color.WHITE)
	var cheese := Color("ffd23f").lerp(Color("6b3d14"), clampf((hot - 0.55) / 0.45, 0.0, 1.0) * 0.85)
	draw_rect(Rect2(c.x - 9.0, top - 1.5, 18.0, 3.0), cheese)
	for n in 2 + int(hot * 4.0):
		var u := fmod(t * (0.6 + hot * 1.6) + n * 0.37, 1.0)
		draw_circle(Vector2(c.x - 7.0 + fmod(n * 5.3, 14.0), top - 1.0 - sin(u * PI) * (1.0 + hot * 2.0)), 1.2 + hot * 1.8 * sin(u * PI), cheese.lightened(0.15))
	var smoke := Color(1, 1, 1).lerp(Color(0.3, 0.27, 0.25), clampf((hot - 0.6) / 0.4, 0.0, 1.0))
	for n in 3 + int(hot * 5.0):
		var u2 := fmod(t * (0.4 + hot * 0.5) + n * 0.23, 1.0)
		draw_circle(Vector2(c.x - 5.0 + fmod(n * 3.7, 10.0) + sin(u2 * 5.0 + n) * 3.0, top - 5.0 - u2 * (16.0 + hot * 18.0)), 2.0 + u2 * (3.0 + hot * 4.0), Color(smoke, (0.25 + 0.35 * hot) * (1.0 - u2)))


## Along the south walls: washing-up sink and glass cupboard in the lab, safety cabinet and waste
## canisters in the store room.
func _draw_south() -> void:
	var s := _px(SINK)
	_shadow(s)
	draw_rect(s, Color("8d98a1"))
	draw_rect(s.grow(-2.0), Color("c3ccd2"))
	for i in 2:
		var basin := Rect2(s.position.x + 6.0 + i * 34.0, s.position.y + 5.0, 28.0, s.size.y - 10.0)
		draw_rect(basin, Color("5d6972"))
		draw_circle(basin.get_center(), 1.8, Color("2b2f35"))
		draw_rect(Rect2(basin.get_center().x - 1.2, s.end.y - 7.0, 2.4, 6.0), Color("e3e8eb"))
	for i in 5:   # drying rack
		draw_rect(Rect2(s.end.x - 26.0 + i * 4.5, s.position.y + 5.0, 2.0, s.size.y - 10.0), Color("f1f4f5"))
	var sh := _px(SHELF)
	_shadow(sh)
	draw_rect(sh, Color("7a5a3a"))
	draw_rect(sh.grow(-2.5), Color("efe9dc"))
	var gx := sh.position.x + 10.0
	var gi := 0
	while gx < sh.end.x - 8.0:
		if gi % 3 == 2:
			_beaker(Vector2(gx, sh.end.y - 5.0), 8.0, 10.0, Color(0, 0, 0, 0), 0.0)
		else:
			_flask(Vector2(gx, sh.end.y - 5.0), 0.85, Color(LIQUIDS[gi % LIQUIDS.size()], 0.0 if gi % 2 == 0 else 0.85))
		gx += 14.0
		gi += 1
	draw_rect(sh, Color(0.75, 0.9, 1.0, 0.22))   # glass doors
	draw_line(Vector2(sh.get_center().x, sh.position.y), Vector2(sh.get_center().x, sh.end.y), Color("7a5a3a"), 2.0)
	var cab := _px(CABINET)
	_shadow(cab)
	draw_rect(cab, Color("b8901a"))
	draw_rect(cab.grow(-2.5), Color("f2c230"))
	draw_line(Vector2(cab.get_center().x, cab.position.y + 2.0), Vector2(cab.get_center().x, cab.end.y - 2.0), Color("b8901a"), 1.5)
	for i in 2:   # hazard diamonds
		var dc := Vector2(cab.position.x + cab.size.x * (0.27 + i * 0.46), cab.get_center().y)
		draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -8), dc + Vector2(8, 0), dc + Vector2(0, 8), dc + Vector2(-8, 0)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -6.5), dc + Vector2(6.5, 0), dc + Vector2(0, 6.5), dc + Vector2(-6.5, 0)]), UI.RED if i == 0 else UI.ORANGE)
		draw_colored_polygon(PackedVector2Array([dc + Vector2(-2.2, 3.0), dc + Vector2(0, -3.8), dc + Vector2(2.2, 3.0)]), Color("22262b"))
	var w := _px(WASTE)
	for i in 2:
		var can := Rect2(w.position.x + i * 25.0, w.position.y, 21.0, w.size.y)
		_shadow(can)
		draw_rect(can, Color("2f5d8c"))
		draw_rect(Rect2(can.position.x + 3.0, can.position.y + 3.0, can.size.x - 6.0, 4.0), Color("4d8dff"))
		draw_circle(can.position + Vector2(can.size.x / 2.0, can.size.y - 7.0), 3.5, Color("22262b"))


func _draw_gas() -> void:
	var g := _px(GAS)
	_shadow(g)
	draw_rect(g, Color("4a525b"))
	draw_rect(g.grow(-2.0), Color("6a747e"))
	var cols := ["3a8f5a", "e3e8eb", "7a5a3a"]
	for i in 3:
		var c := Vector2(g.get_center().x, g.position.y + 18.0 + i * 31.0) + _rat(i * 5.0) * 0.6
		draw_circle(c + Vector2(1.5, 2.0), 13.0, Color(0, 0, 0, 0.3))
		draw_circle(c, 13.0, Color(cols[i]))
		draw_circle(c, 8.5, Color(cols[i]).lightened(0.18))
		draw_circle(c, 3.5, Color("c9a23c"))
		draw_rect(Rect2(c.x - 1.0, c.y - 6.5, 2.0, 5.0), Color("8d98a1"))
	draw_line(Vector2(g.position.x + 2.0, g.position.y + 3.0), Vector2(g.position.x + 2.0, g.end.y - 3.0), Color("c3ccd2"), 1.5)   # chain rail


## Coat hooks on the west wall. Four spare coats; the players may take one each.
func _draw_coats() -> void:
	var r := _px(COATS)
	draw_rect(Rect2(r.position.x, r.position.y, 4.0, r.size.y), Color("7a5a3a"))
	for i in 4:
		var y := r.position.y + 5.0 + i * 20.0
		draw_rect(Rect2(r.position.x + 3.0, y + 6.0, 5.0, 2.0), Color("3b4149"))
		if i < 4 - coats_taken:
			var coat := Rect2(r.position.x + 5.0, y, 15.0, 16.0)
			draw_rect(Rect2(coat.position + Vector2(1.5, 2.0), coat.size), Color(0, 0, 0, 0.25))
			draw_rect(coat, Color("f3f3f0"))
			draw_rect(Rect2(coat.position.x, coat.position.y, 4.0, coat.size.y), Color("dcdcd6"))
			draw_line(coat.position + Vector2(9.0, 2.0), coat.position + Vector2(9.0, 14.0), Color("c8c8c0"), 1.0)
	# box with safety goggles
	var box := Rect2(r.position.x + 3.0, r.end.y - 10.0, 18.0, 10.0)
	draw_rect(box, Color("3b4149"))
	for i in 2:
		draw_circle(box.position + Vector2(5.5 + i * 7.0, 5.0), 2.6, Color("7fc8e8"))


func _draw_shower() -> void:
	var r := _px(SHOWER)
	draw_rect(r, Color(0.15, 0.16, 0.18, 0.18))
	# black and yellow frame on the floor
	var n := 8
	for i in n:
		var c := UI.YELLOW if i % 2 == 0 else Color("22262b")
		var a := r.size.x * i / n
		var w := r.size.x / n
		draw_rect(Rect2(r.position.x + a, r.position.y, w, 3.0), c)
		draw_rect(Rect2(r.position.x + a, r.end.y - 3.0, w, 3.0), c)
		draw_rect(Rect2(r.position.x, r.position.y + a, 3.0, w), c)
		draw_rect(Rect2(r.end.x - 3.0, r.position.y + a, 3.0, w), c)
	var c2 := r.get_center()
	draw_circle(c2, 9.0, Color("5d6972"))   # drain
	for i in 3:
		draw_line(c2 + Vector2(-6.0, -4.0 + i * 4.0), c2 + Vector2(6.0, -4.0 + i * 4.0), Color("2b2f35"), 1.0)
	draw_circle(c2 + Vector2(0, -15.0), 5.5, Color("c3ccd2"))   # shower head
	draw_circle(c2 + Vector2(0, -15.0), 3.5, Color("8d98a1"))
	draw_line(c2 + Vector2(9.0, -17.0), c2 + Vector2(9.0, -7.0), Color("8d98a1"), 1.0)   # pull handle
	draw_colored_polygon(PackedVector2Array([c2 + Vector2(5.5, -7.0), c2 + Vector2(12.5, -7.0), c2 + Vector2(9.0, -1.5)]), UI.RED)


## What lies over the characters: flames on whoever burns, with the time that is left, the
## water of the emergency shower, and the drops of whoever just came out of it.
func _paint_top(ci: CanvasItem) -> void:
	if not is_instance_valid(main) or main.players.size() < 2:
		return
	if shower_t > 0.0:
		var r := _px(SHOWER)
		for i in 16:
			var u := fmod(t * 2.6 + i * 0.137, 1.0)
			var x := r.position.x + 4.0 + fmod(i * 7.3, r.size.x - 8.0)
			var y := r.position.y - 34.0 + u * (r.size.y + 30.0)
			ci.draw_line(Vector2(x, y), Vector2(x - 1.0, y + 9.0), Color(0.55, 0.8, 1.0, 0.85), 2.0)
		for i in 5:
			var u2 := fmod(t * 1.8 + i * 0.2, 1.0)
			ci.draw_arc(Vector2(r.position.x + 6.0 + fmod(i * 11.0, r.size.x - 12.0), r.end.y - 6.0 - fmod(i * 5.0, 18.0)), 2.0 + u2 * 6.0, 0.0, TAU, 12, Color(0.7, 0.9, 1.0, 0.8 * (1.0 - u2)), 1.2)
	for pid in 2:
		var at: Vector2 = main.players[pid].global_position
		if burning[pid]:
			var spots := [Vector2(-7, -8), Vector2(7, -11), Vector2(-4, -25), Vector2(5, -30), Vector2(-7, -40), Vector2(1, -47)]
			for i in spots.size():
				var f := 1.0 + 0.35 * sin(t * 19.0 + i * 1.9) + 0.2 * sin(t * 31.0 + i)
				var b: Vector2 = at + spots[i] + Vector2(sin(t * 13.0 + i) * 1.2, 0)
				ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-5.0, 2.0), b + Vector2(0, -13.0 * f), b + Vector2(5.0, 2.0)]), Color(1.0, 0.45, 0.1, 0.92))
				ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-2.6, 2.0), b + Vector2(0, -7.0 * f), b + Vector2(2.6, 2.0)]), Color(1.0, 0.85, 0.3, 0.95))
			for i in 3:
				var u3 := fmod(t * 0.9 + i * 0.33, 1.0)
				ci.draw_circle(at + Vector2(sin(u3 * 6.0 + i) * 5.0, -52.0 - u3 * 22.0), 3.0 + u3 * 5.0, Color(0.25, 0.23, 0.22, 0.5 * (1.0 - u3)))
			# how long there is left, where the bubbles of the other characters are
			var c := at + Vector2(0, -76.0)
			var left: float = clampf(float(burn_t[pid]) / BURN_MAX, 0.0, 1.0)
			ci.draw_circle(c, 11.0, Color(0.08, 0.09, 0.17, 0.92))
			ci.draw_arc(c, 11.0, -PI / 2.0, -PI / 2.0 + TAU * left, 28, UI.ORANGE if left > 0.3 else UI.RED, 3.0)
			var txt := str(int(ceil(float(burn_t[pid]))))
			var font := ThemeDB.fallback_font
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			ci.draw_string(font, c + Vector2(-w / 2.0, 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.WHITE)
		elif wet_t[pid] > 0.0:
			for i in 4:
				var u4 := fmod(t * 1.5 + i * 0.25, 1.0)
				ci.draw_circle(at + Vector2(-8.0 + i * 5.5, -30.0 + u4 * 28.0), 1.6, Color(0.55, 0.8, 1.0, 0.9 * (1.0 - u4)))


## The cloud out of fume hood 1 when the professor's thermometer bursts, or when the fondue boils over.
func _draw_cloud() -> void:
	if boom_t <= 0.0:
		return
	var h0: Vector2 = HOODS[0]
	var c := Vector2(h0.x * TS + 15.0, (h0.y + HOOD_SIZE.y / 2.0) * TS)
	var grow := 1.0 - boom_t
	for i in 7:
		var a := i * 0.9 + t * 0.4
		draw_circle(c + Vector2(-grow * 46.0, 0) + Vector2.from_angle(a) * (8.0 + grow * 26.0), 9.0 + grow * 22.0, Color(cloud_col, 0.5 * boom_t))


## A Testat desk, drawn from its front edge (it lives in main.actors and hides the sitter's legs).
func _paint_desk(ci: CanvasItem, k: int) -> void:
	var size: Vector2 = (DESKS[k] as Rect2).size * TS
	var r := Rect2(-size.x / 2.0, -size.y, size.x, size.y)
	ci.draw_rect(Rect2(r.position + Vector2(2.5, 3.5), r.size), Color(0, 0, 0, 0.3))
	ci.draw_rect(r, Color("8f6f47"))
	ci.draw_rect(r.grow(-2.0), Color("d9c6a5"))
	ci.draw_rect(Rect2(r.position.x + 2.0, r.end.y - 5.0, r.size.x - 4.0, 3.0), Color("c2ae8c"))
	# the exam sheet and a pen
	var sheet := Rect2(-9.0, r.position.y + 5.0, 18.0, 15.0)
	ci.draw_rect(sheet, Color.WHITE)
	for i in 4:
		ci.draw_line(sheet.position + Vector2(2.5, 3.0 + i * 3.0), sheet.position + Vector2(15.5 - (i % 2) * 4.0, 3.0 + i * 3.0), Color(0.3, 0.35, 0.45, 0.7), 0.7)
	ci.draw_line(Vector2(13.0, r.position.y + 8.0), Vector2(18.0, r.position.y + 17.0), UI.ETH_BLUE, 1.6)
	if desk_done[k]:
		ci.draw_polyline(PackedVector2Array([sheet.get_center() + Vector2(-5, 0), sheet.get_center() + Vector2(-1.5, 4), sheet.get_center() + Vector2(6, -5)]), UI.GREEN, 2.4)
	elif desk_failed == k:
		ci.draw_line(sheet.get_center() + Vector2(-5, -5), sheet.get_center() + Vector2(5, 5), UI.RED, 2.4)
		ci.draw_line(sheet.get_center() + Vector2(5, -5), sheet.get_center() + Vector2(-5, 5), UI.RED, 2.4)
	# which series this desk is
	var font := ThemeDB.fallback_font
	ci.draw_circle(Vector2(r.position.x + 9.0, r.position.y + 11.0), 7.0, UI.NAVY)
	ci.draw_arc(Vector2(r.position.x + 9.0, r.position.y + 11.0), 7.0, 0.0, TAU, 20, UI.YELLOW, 1.5)
	var letter: String = SET_NAMES[k]
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	ci.draw_string(font, Vector2(r.position.x + 9.0 - w / 2.0, r.position.y + 15.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.YELLOW)
