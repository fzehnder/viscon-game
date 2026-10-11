extends Node
## Autoload "Ambience": what a place sounds like. Every room of the map gets a bed (wind, the hum
## of a fume hood, the murmur of a canteen), single sounds now and then (plates, pages, birds, a
## tram bell), an echo that fits the room for all effects of the game, and music where music
## fits: on the start page, outside by day, at night, in the lounge, and when somebody is chased.
## Everything is made in code like the other sounds of the game, there are no audio files.
##
## It works by itself: it reads the room of each player from world.zone_at() and maps the name to
## a kind of room by keywords (ROOMS). Two players in different rooms hear both, each half as
## loud. Everything comes and goes in a crossfade (FADE_TIME).
## While a minigame is open, the room steps back and a light tune for working fades in ("task").
## A minigame with its own music has a variable `ambience` with "none" (or the name of another
## tune); while the microphone is listening, everything from here is silent.
## On the loading screen the ride is heard: the Polybahn or the ETH-Link bus.
##
## A level can steer it in its DEF (optional):
##   "ambience": false                                  nothing at all in this level
##   "ambience": {"music": false}                       room sounds, but no music from here
##   "ambience": {"zones": {"Mensa Polyterrasse": "none", "Lounge": "office"}}   rooms by name
##   "ambience": {"all": "lecture"}                     one kind of room everywhere
##   "ambience": {"rest": "none"}                       every room that is not named in "zones"
##   "ambience": {"tasks": false}                       no tune for working in the minigames (silence)
## What levels get that say nothing themselves is listed in LEVELS.
##
## Switch it off for a test run: -- --noambience

const LV = preload("res://scripts/levels.gd")

const RATE := 22050
const BUS := "Ambience"        # beds and music
const ROOM_BUS := "Room"       # the effects of the game (Sfx) and the single sounds: with the echo of the room
const FADE_TIME := 1.6         # seconds in which something comes or goes (a crossfade in loudness)
const OFF := -60.0
const TASK_DUCK := -8.0        # the room behind an open minigame: this much quieter
const RIDE_DB := -17.0         # the ride on the loading screen
const GAIN_DB := 10.0          # everything from here, louder or quieter: the one knob to turn
const MUSIC_DB := -21.0
const DUCK_STATE := -7.0       # start card, cutscene, win and lose card: this much quieter
# for levels that say nothing in their DEF (their own "ambience" wins)
const LEVELS := {
	3: {"music": false, "tasks": false, "rest": "none", "zones": {"Mensa Polyterrasse": "kitchen"}},   # Polyball: its own music (level3/musik.gd); the Mensa is the kitchen of the ball and sounds like one
	19: false,                                # Freelancing listens to the microphone
	20: {"music": false, "all": "ski"},       # Skiing: wind and trees on the slope, nothing else
}

# kind of room -> beds {name: dB}, single sounds [name, shortest gap s, longest gap s, dB], echo 0..1, music
# The beds are kept low on purpose (first round of listening: too much rustling, above all in the
# lab): what makes a room is its single sounds, the bed is only the air under them.
const KINDS := {
	"outside": {"beds": {"wind": -35.0}, "shots": [["bird", 3.0, 8.0, -18.0], ["bird2", 5.0, 13.0, -20.0], ["tram", 20.0, 45.0, -24.0]], "wet": 0.0, "music": "day"},
	"street": {"beds": {"wind": -36.0}, "shots": [["car", 6.0, 14.0, -24.0], ["tram", 12.0, 28.0, -21.0], ["bird", 7.0, 16.0, -21.0]], "wet": 0.0, "music": "day"},
	"polybahn": {"beds": {"wind": -36.0}, "shots": [["tram", 6.0, 13.0, -19.0], ["bird", 5.0, 12.0, -20.0]], "wet": 0.0, "music": "day"},
	"hall": {"beds": {"murmur": -33.0, "roomtone": -42.0}, "shots": [["steps", 4.0, 10.0, -20.0], ["door", 11.0, 26.0, -22.0]], "wet": 0.45},
	"corridor": {"beds": {"roomtone": -42.0, "murmur": -41.0}, "shots": [["steps", 5.0, 12.0, -21.0], ["door", 9.0, 22.0, -22.0]], "wet": 0.35},
	"lecture": {"beds": {"roomtone": -42.0}, "shots": [["chalk", 5.0, 11.0, -27.0], ["page", 8.0, 18.0, -29.0], ["steps", 12.0, 26.0, -24.0], ["clock", 2.0, 2.0, -31.0]], "wet": 0.3},
	"library": {"beds": {"roomtone": -44.0}, "shots": [["page", 5.0, 12.0, -29.0], ["clock", 2.0, 2.0, -29.0], ["keys", 8.0, 20.0, -27.0]], "wet": 0.22},
	"lab": {"beds": {"hood": -43.0}, "shots": [["bubble", 2.0, 5.0, -19.0], ["glass", 4.0, 10.0, -22.0], ["beep", 9.0, 20.0, -25.0], ["keys", 12.0, 26.0, -27.0]], "wet": 0.14},
	"canteen": {"beds": {"murmur": -33.0, "kitchen": -44.0}, "shots": [["clink", 1.0, 2.6, -11.0], ["cutlery", 1.5, 3.5, -14.0], ["plates", 2.5, 6.0, -15.0], ["drop", 8.0, 18.0, -12.0], ["bell", 14.0, 30.0, -22.0]], "wet": 0.12},
	"kitchen": {"beds": {"kitchen": -42.0}, "shots": [["clink", 1.2, 3.0, -11.0], ["cutlery", 1.5, 3.5, -14.0], ["plates", 2.0, 5.0, -14.0], ["chop", 4.0, 9.0, -17.0], ["drop", 8.0, 18.0, -12.0]], "wet": 0.12},
	"ski": {"beds": {"wind": -29.0, "trees": -33.0}, "shots": [], "wet": 0.0},
	"office": {"beds": {"fan": -42.0}, "shots": [["keys", 2.0, 6.0, -23.0], ["clock", 2.0, 2.0, -29.0], ["page", 12.0, 26.0, -30.0]], "wet": 0.05},
	"lounge": {"beds": {"roomtone": -44.0}, "shots": [["glass", 6.0, 14.0, -24.0]], "wet": 0.1, "music": "lounge"},
	# at night
	"outside_night": {"beds": {"night": -31.0}, "shots": [["owl", 13.0, 30.0, -23.0]], "wet": 0.0},
	"inside_night": {"beds": {"roomtone": -42.0}, "shots": [["clock", 2.0, 2.0, -29.0], ["door", 18.0, 40.0, -27.0]], "wet": 0.4},
	"none": {"beds": {}, "shots": [], "wet": 0.0},
}
# the name of a zone contains ... -> kind of room (the first that fits)
const ROOMS := [
	["mensa", "canteen"], ["bibliothek", "library"], ["labor", "lab"], ["hörsaal", "lecture"], ["zeichensaal", "lecture"],
	["seminar", "lecture"], ["lounge", "lounge"], ["büro", "office"], ["kameraraum", "office"], ["campus info", "office"],
	["haupthalle", "hall"], ["rotunde", "hall"], ["foyer", "hall"], ["ausstellung", "hall"], ["e nord", "hall"], ["e süd", "hall"],
	["gang", "corridor"], ["flügel", "corridor"], ["ostblock", "corridor"], ["hauptgebäude", "corridor"],
	["polybahn", "polybahn"], ["strasse", "street"], ["gasse", "street"], ["haltestelle", "street"],
]
const OUTSIDE := ["outside", "street", "polybahn"]
const BEDS := ["wind", "night", "roomtone", "murmur", "kitchen", "hood", "fan", "ride", "bus", "trees"]
const SHOTS := ["bird", "bird2", "tram", "car", "steps", "door", "chalk", "page", "clock", "keys", "bubble", "glass", "plates", "bell", "owl",
	"cutlery", "drop", "beep", "arrive", "hiss", "clink", "chop"]
const SONGS := ["menu", "day", "suspense", "chase", "lounge", "task"]

var enabled := true
# Rendered sounds. Static, so that a worker thread that is still rendering does not reach into a
# node that is already gone when the game is closed right after its start.
static var pcm := {}           # name -> PackedByteArray (16 bit mono), filled by the worker threads
static var lock := Mutex.new()
var tasks: Array = []          # ids of the render tasks, waited for when the game closes
var streams := {}              # name -> AudioStreamWAV, made on the main thread when first needed
var layers := {}               # name -> AudioStreamPlayer (beds and music)
var shot_players: Array = []
var shot_next := 0
var timers := {}               # "kind/sound" -> seconds until it sounds again
var reverb: AudioEffectReverb
var wet := 0.0
var rng := RandomNumberGenerator.new()
var now_kinds := {}            # kind -> weight, for whoever wants to look (debug)
var now_music := ""
var gains := {}                # layer -> how loud it is right now (linear)
var aims := {}                 # layer -> where it is fading to, and ...
var steps := {}                # ... how fast, so that every fade takes FADE_TIME
var riding := false            # a loading screen is up
var hunt_states := {}          # script of an Opp -> the number of its state JAGD


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--noambience" in OS.get_cmdline_user_args():
		enabled = false
		return
	rng.randomize()
	AudioServer.set_bus_volume_db(_bus(BUS), GAIN_DB)
	var i := _bus(ROOM_BUS)
	if AudioServer.get_bus_effect_count(i) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.75
		rv.damping = 0.45
		rv.spread = 0.9
		rv.hipass = 0.15
		rv.dry = 1.0
		rv.wet = 0.0
		AudioServer.add_bus_effect(i, rv)
	reverb = AudioServer.get_bus_effect(i, 0) as AudioEffectReverb
	for p in Sfx.players:      # every effect of the game gets the echo of the room it sounds in
		(p as AudioStreamPlayer).bus = ROOM_BUS
	for k in 5:
		var sp := AudioStreamPlayer.new()
		sp.bus = ROOM_BUS
		add_child(sp)
		shot_players.append(sp)
	# everything is rendered once, in the background, the most needed first
	for name in ["roomtone", "wind", "menu", "day", "murmur"] + SHOTS + BEDS + SONGS:
		if not pcm.has(name):
			pcm[name] = PackedByteArray()
			tasks.append(WorkerThreadPool.add_task(_render.bind(name, rng.randi())))


## Closing the game while sounds are still being rendered: let the threads finish first.
func _exit_tree() -> void:
	for id in tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	tasks.clear()


func _bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


# ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	if not enabled:
		return
	var want := {}             # layer name -> dB
	var kinds := {}            # kind of room -> weight (0.5 per player)
	var music := ""
	var duck := 0.0
	var scene := get_tree().current_scene
	var main = scene if scene != null and "players" in scene and "world" in scene and "minis" in scene else null
	var loading := get_tree().get_first_node_in_group("loading_screen")
	var in_game := false       # single sounds only while the players walk around
	if loading != null:
		# the ride up: the Polybahn on its rails, or the ETH-Link bus
		var bus_ride: bool = String(LV.level().get("ride", "polybahn")) == "ethlink"
		want["bus" if bus_ride else "ride"] = RIDE_DB
		if not riding:
			_once("hiss" if bus_ride else "tram", -15.0)
		main = null
	elif main == null:
		if scene != null and String(scene.scene_file_path).contains("menu"):
			music = "menu"
	else:
		var lv: Dictionary = LV.level()
		var opt = lv.get("ambience", LEVELS.get(LV.current, true))
		var o: Dictionary = opt if opt is Dictionary else {}
		var task := _task(main)
		if task != "" and not bool(o.get("tasks", true)):
			task = "none"
		if (opt is bool and not opt) or task == "none" or main.world == null:
			main = null
		else:
			var night: bool = String(lv.get("mode", "day")) == "night" or String(lv.get("sky", "")) == "night"
			for pl in main.players:
				if not is_instance_valid(pl):
					continue
				var kind := _kind(String(main.world.zone_at(pl.global_position)), o, night)
				kinds[kind] = float(kinds.get(kind, 0.0)) + 1.0 / maxf(1.0, main.players.size())
			if bool(o.get("music", true)) or task != "":
				if _chased(main):
					music = "chase"
				elif task != "":
					music = task       # a minigame is open: the room steps back, the tune for working comes
				elif night:
					music = "suspense"
				else:
					for kind in kinds:
						if (KINDS[kind] as Dictionary).has("music") and (music == "" or float(kinds[kind]) > 0.5):
							music = String(KINDS[kind]["music"])
			if task != "":
				duck = TASK_DUCK
			elif String(main.state) != "play":
				duck = DUCK_STATE
			in_game = task == "" and String(main.state) == "play"
	if riding and loading == null:
		_once("arrive", -16.0)     # there
	riding = loading != null
	if get_tree().paused:
		duck -= 8.0
	# beds: every kind of room the players are in, quieter for a room only one of them is in
	var target_wet := 0.0
	for kind in kinds:
		var w: float = kinds[kind]
		var d: Dictionary = KINDS[kind]
		target_wet += float(d["wet"]) * w
		for bed in d["beds"]:
			var db: float = float(d["beds"][bed]) + linear_to_db(w) + duck
			want[bed] = maxf(float(want.get(bed, OFF)), db)
		_shots(kind, d, w, delta, in_game)
	if music != "":
		want[music] = MUSIC_DB + (3.0 if music in ["chase", "menu"] else 0.0) + (0.0 if music == "task" else duck)
	now_kinds = kinds
	now_music = music
	for name in want:
		if not layers.has(name) and _stream(name) != null:
			var p := AudioStreamPlayer.new()
			p.bus = BUS
			p.stream = _stream(name)
			p.volume_db = OFF
			add_child(p)
			layers[name] = p
	for name in layers:
		var p: AudioStreamPlayer = layers[name]
		var to: float = db_to_linear(float(want[name])) if want.has(name) else 0.0
		var g: float = gains.get(name, 0.0)
		if not is_equal_approx(float(aims.get(name, -1.0)), to):
			aims[name] = to
			steps[name] = absf(to - g) / FADE_TIME
		g = move_toward(g, to, float(steps.get(name, 1.0)) * delta)
		gains[name] = g
		p.volume_db = linear_to_db(maxf(g, 0.00001))
		if to > 0.0 and not p.playing:
			p.play(0.0 if name in SONGS else rng.randf() * p.stream.get_length())
		elif to <= 0.0 and g <= 0.0001 and p.playing:
			p.stop()
	wet = move_toward(wet, target_wet, delta * 0.8)
	if reverb != null:
		reverb.wet = wet


## What an open minigame wants to hear: "" none is open, "none" silence, else the name of a tune.
func _task(main) -> String:
	var mg = main.minis[0] if main.minis[0] != null else main.minis[1]
	if mg == null or not is_instance_valid(mg):
		return ""
	if "_mic_users" in Track and not (Track._mic_users as Dictionary).is_empty():
		return "none"          # the microphone is listening: nothing from the speakers
	if "ambience" in mg:
		var a := String(mg.ambience)
		return a if a == "none" or a in SONGS else "task"
	return "task"


## One single sound right now (the bell before the ride, the gong on arrival).
func _once(sound: String, db: float) -> void:
	var st := _stream(sound)
	if st == null:
		return
	var p: AudioStreamPlayer = shot_players[shot_next]
	shot_next = (shot_next + 1) % shot_players.size()
	p.stream = st
	p.volume_db = db + GAIN_DB
	p.pitch_scale = 1.0
	p.play()


func _kind(zone: String, o: Dictionary, night: bool) -> String:
	var kind := "outside"
	var by_level := false
	if o.has("all"):
		kind = String(o["all"])
		by_level = true
	var zones: Dictionary = o.get("zones", {})
	if zones.has(zone):
		kind = String(zones[zone])
		by_level = true
	elif not by_level and o.has("rest"):
		kind = String(o["rest"])
		by_level = true
	elif not by_level:
		var z := zone.to_lower()
		for r in ROOMS:
			if z.contains(String(r[0])):
				kind = String(r[1])
				break
	if not KINDS.has(kind):
		kind = "none"
	if night and not by_level and kind != "none":
		kind = "outside_night" if kind in OUTSIDE else "inside_night"
	return kind


## Is somebody running after a player right now? (Opps on the hunt, professors with a full meter)
func _chased(main) -> bool:
	if "opps" in main:
		for op in main.opps:
			if is_instance_valid(op) and "state" in op and int(op.state) == _hunt_state(op):
				return true
	if "profs" in main:
		for pr in main.profs:
			if is_instance_valid(pr) and "meter" in pr and float(pr.meter) >= 1.0:
				return true
	return false


## The number of the state JAGD in the script of this Opp (-1: it has none).
func _hunt_state(op: Object) -> int:
	var sc: Script = op.get_script()
	if sc == null:
		return -1
	if not hunt_states.has(sc):
		hunt_states[sc] = int(sc.get_script_constant_map().get("JAGD", -1))
	return int(hunt_states[sc])


func _shots(kind: String, d: Dictionary, w: float, delta: float, playing: bool) -> void:
	for s in d["shots"]:
		var key := "%s/%s" % [kind, s[0]]
		if not timers.has(key):
			timers[key] = rng.randf_range(0.3, float(s[2]))
		timers[key] = float(timers[key]) - delta
		if float(timers[key]) > 0.0:
			continue
		timers[key] = rng.randf_range(float(s[1]), float(s[2]))
		var st := _stream(String(s[0]))
		if st == null or not playing:
			continue
		var p: AudioStreamPlayer = shot_players[shot_next]
		shot_next = (shot_next + 1) % shot_players.size()
		p.stream = st
		p.volume_db = float(s[3]) + GAIN_DB + linear_to_db(w) + rng.randf_range(-3.0, 1.0)
		p.pitch_scale = 1.0 if String(s[0]) == "clock" else rng.randf_range(0.9, 1.12)
		p.play()


func _stream(sound: String) -> AudioStreamWAV:
	if streams.has(sound):
		return streams[sound]
	lock.lock()
	var bytes: PackedByteArray = pcm.get(sound, PackedByteArray())
	lock.unlock()
	if bytes.is_empty():
		return null            # not rendered yet
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if sound in BEDS or sound in SONGS:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = bytes.size() >> 1
	streams[sound] = s
	return s


# ================================================================== rendering (worker threads)
static func _render(sound: String, seed_value: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var buf := make(sound, r)
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	lock.lock()
	pcm[sound] = bytes
	lock.unlock()


## One sound as samples from -1 to 1. Beds and songs loop without a seam.
static func make(sound: String, r: RandomNumberGenerator) -> PackedFloat32Array:
	match sound:
		"wind":
			return _norm(_wind(6.0, r, 0.02, 1.0), 0.8)
		"night":
			return _norm(_night(6.0, r), 0.8)
		"roomtone":
			return _norm(_roomtone(4.0, r), 0.8)
		"murmur":
			return _norm(_murmur(6.0, r), 0.8)
		"kitchen":
			return _norm(_kitchen(6.0, r), 0.8)
		"hood":
			return _norm(_air(4.0, r, 230.0, 1.0, 600.0, 100.0), 0.8)
		"fan":
			return _norm(_air(4.0, r, 380.0, 0.6, 800.0, 120.0), 0.8)
		"trees":
			return _norm(_trees(7.0, r), 0.8)
		"ride":
			return _norm(_ride(4.8, r, false), 0.8)
		"bus":
			return _norm(_ride(4.0, r, true), 0.8)
		"menu", "day", "suspense", "chase", "lounge", "task":
			return _norm(_song(sound), 0.8)
	return _norm(_shot(sound, r), 0.8)


static func _zeros(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	b.fill(0.0)
	return b


static func _norm(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0001
	for v in b:
		top = maxf(top, absf(v))
	var k := peak / top
	for i in b.size():
		b[i] *= k
	return b


## Makes the first `n` samples of `b` loop: the rest is faded over the beginning.
static func _wrap(b: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var fade := b.size() - n
	for i in fade:
		var k := float(i) / fade
		b[i] = b[i] * k + b[n + i] * (1.0 - k)
	b.resize(n)
	return b


## White noise through a band-pass (state variable filter), `n` samples.
static func _band(n: int, r: RandomNumberGenerator, fc: float, damp: float) -> PackedFloat32Array:
	var b := _zeros(n)
	var f := 2.0 * sin(PI * fc / RATE)
	var low := 0.0
	var band := 0.0
	for i in n:
		var high := r.randf_range(-1.0, 1.0) - low - damp * band
		band += f * high
		low += f * band
		b[i] = band
	return b


## White noise through a low-pass (one pole), `n` samples.
static func _low(n: int, r: RandomNumberGenerator, a: float) -> PackedFloat32Array:
	var b := _zeros(n)
	var y := 0.0
	for i in n:
		y += a * (r.randf_range(-1.0, 1.0) - y)
		b[i] = y
	return b


static func _wind(secs: float, r: RandomNumberGenerator, a: float, gusts: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var m := n + (RATE >> 1)
	var deep := _low(m, r, a)
	var high := _band(m, r, 520.0, 1.2)
	var b := _zeros(m)
	for i in m:
		var t := float(i) / n
		var swell := 0.62 + gusts * (0.24 * sin(TAU * t) + 0.14 * sin(TAU * 3.0 * t + 1.0))
		b[i] = deep[i] * 9.0 * swell + high[i] * 0.06 * (0.4 + 0.3 * sin(TAU * 2.0 * t + 2.0))
	return _wrap(b, n)


## A quiet night: a little wind, two crickets.
static func _night(secs: float, r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _wind(secs, r, 0.012, 0.5)
	var n := b.size()
	for i in n:
		b[i] *= 0.5
	for c in 2:
		var freq := 4200.0 - c * 380.0
		var every := 0.75 if c == 0 else 1.0
		var start := 0.1 + c * 0.33
		var groups := int(secs / every)
		for g in groups:
			for pulse in 3:
				var i0 := int((start + g * every + pulse * 0.05) * RATE)
				var cnt := int(0.028 * RATE)
				for k in cnt:
					var e := sin(PI * k / cnt)
					b[(i0 + k) % n] += sin(TAU * freq * k / RATE) * e * e * (0.05 - c * 0.02)
	return b


static func _roomtone(secs: float, r: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var m := n + (RATE >> 1)
	var air := _low(m, r, 0.012)
	var b := _zeros(m)
	for i in m:
		var t := float(i) / RATE
		b[i] = air[i] * 6.0 + 0.05 * sin(TAU * 50.0 * t) + 0.03 * sin(TAU * 100.0 * t)
	return _wrap(b, n)


## Many people talking at once: voices are noise through a moving band-pass, in syllables.
static func _murmur(secs: float, r: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var m := n + (RATE >> 1)
	var b := _zeros(m)
	for voice in 7:
		var base := r.randf_range(230.0, 720.0)
		var loud := r.randf_range(0.5, 1.0)
		var low := 0.0
		var band := 0.0
		var i := int(r.randf_range(0.0, 0.3) * RATE)
		while i < m:
			var cnt := int(r.randf_range(0.11, 0.3) * RATE)
			var f := 2.0 * sin(PI * base * r.randf_range(0.8, 1.3) / RATE)
			var amp := loud * r.randf_range(0.35, 1.0)
			for k in cnt:
				if i + k >= m:
					break
				var high := r.randf_range(-1.0, 1.0) - low - 0.3 * band
				band += f * high
				low += f * band
				var e := sin(PI * k / cnt)
				b[i + k] += band * e * e * amp
			i += cnt + int(r.randf_range(0.02, 0.28) * RATE)
	return _wrap(b, n)


## The kitchen behind the counter: the extractor hums, something sizzles in a pan.
static func _kitchen(secs: float, r: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var m := n + (RATE >> 1)
	var air := _band(m, r, 700.0, 0.9)
	var b := _zeros(m)
	var prev := 0.0
	var crackle := 0.0
	for i in m:
		var t := float(i) / RATE
		var white := r.randf_range(-1.0, 1.0)
		var hiss := white - prev          # the high part of the noise
		prev = white
		if r.randf() < 0.0035:
			crackle = r.randf_range(0.5, 1.0)
		crackle *= 0.994
		b[i] = 0.25 * sin(TAU * 100.0 * t) + 0.12 * sin(TAU * 200.0 * t) + 0.05 * sin(TAU * 300.0 * t) \
			+ air[i] * 0.05 + hiss * (0.008 + 0.05 * crackle)
	return _wrap(b, n)


## Moving air: a fume hood, the fan of a computer.
static func _air(secs: float, r: RandomNumberGenerator, fc: float, damp: float, fc2: float, hum: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var m := n + (RATE >> 1)
	var a := _band(m, r, fc, damp)
	var a2 := _band(m, r, fc2, 0.7)
	var b := _zeros(m)
	for i in m:
		b[i] = a[i] * 0.5 + a2[i] * 0.04 + 0.1 * sin(TAU * hum * i / RATE)
	return _wrap(b, n)


## Wind in firs: a soft hiss that comes in waves and never stays the same for long.
static func _trees(secs: float, r: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var m := n + (RATE >> 1)
	var leaves := _band(m, r, 2600.0, 1.3)
	var needles := _band(m, r, 4200.0, 1.1)
	var b := _zeros(m)
	var flutter := 0.5
	for i in m:
		var t := float(i) / n
		flutter += 0.0004 * (r.randf() - flutter)
		var wave := maxf(0.0, 0.35 + 0.4 * sin(TAU * t + 0.6) + 0.25 * sin(TAU * 2.0 * t + 2.1) + 0.2 * sin(TAU * 5.0 * t))
		b[i] = (leaves[i] + needles[i] * 0.5) * wave * (0.6 + flutter)
	return _wrap(b, n)


## The ride on the loading screen. Polybahn: a low rumble and the wheels over the joints of the
## rails, two knocks at a time. Bus: the engine and the road.
static func _ride(secs: float, r: RandomNumberGenerator, bus: bool) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var m := n + (RATE >> 1)
	var road := _low(m, r, 0.02)
	var b := _zeros(m)
	var f := 62.0 if bus else 48.0
	for i in m:
		var t := float(i) / RATE
		var purr := 0.75 + 0.25 * sin(TAU * (8.0 if bus else 3.0) * t)
		b[i] = road[i] * (5.0 if bus else 7.0) + purr * (0.3 * sin(TAU * f * t) + 0.16 * sin(TAU * 2.0 * f * t) + (0.1 if bus else 0.03) * sin(TAU * 3.0 * f * t))
	b = _wrap(b, n)
	if not bus:
		var every := secs / 6.0
		for k in 6:
			for knock in 2:
				var i0 := int((k * every + knock * 0.13) * RATE)
				var cnt := int(0.07 * RATE)
				for j in cnt:
					var x := float(j) / cnt
					b[(i0 + j) % n] += (sin(TAU * 140.0 * j / RATE) * 0.5 + r.randf_range(-0.25, 0.25)) * exp(-x * 6.0) * (0.55 - knock * 0.15)
	return b


# ------------------------------------------------------------------ single sounds
## A tone that glides from f0 to f1 and dies away, added to `b` at second `t0`.
static func _tone(b: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, vol: float, decay: float) -> void:
	var i0 := int(t0 * RATE)
	var cnt := int(dur * RATE)
	var ph := 0.0
	for k in cnt:
		if i0 + k >= b.size():
			return
		var x := float(k) / cnt
		ph += TAU * lerpf(f0, f1, x) / RATE
		b[i0 + k] += sin(ph) * vol * exp(-decay * x) * minf(1.0, k / 40.0) * minf(1.0, (cnt - k) / 60.0)


## Something hard is struck and rings: a tone that is there at once (no soft start, that is what
## makes it sharp) and dies away. Nothing above 10 kHz, the sample rate cannot carry it.
static func _ping(b: PackedFloat32Array, t0: float, dur: float, f: float, vol: float, decay: float) -> void:
	if f > 10000.0:
		return
	var i0 := int(t0 * RATE)
	var cnt := int(dur * RATE)
	var w := TAU * f / RATE
	for k in cnt:
		if i0 + k >= b.size():
			return
		var x := float(k) / cnt
		b[i0 + k] += cos(w * k) * vol * exp(-decay * x) * minf(1.0, k / 3.0) * minf(1.0, (cnt - k) / 60.0)


## Two glasses touch: both ring, a little apart in pitch, with the tick of the contact in front.
static func _clink(b: PackedFloat32Array, r: RandomNumberGenerator, t0: float, f: float, vol: float) -> void:
	for g in 2:
		var fg := f * (1.0 if g == 0 else r.randf_range(1.12, 1.26))
		var t := t0 + g * r.randf_range(0.0, 0.004)
		_ping(b, t, 0.75, fg, vol * 0.55, 6.5)
		_ping(b, t, 0.5, fg * 2.32, vol * 0.4, 9.0)
		_ping(b, t, 0.3, fg * 3.1, vol * 0.25, 12.0)
	_puff(b, r, t0, 0.004, 6500.0, 0.9, vol * 0.8, 3.0)


## A puff of noise around `fc`, added to `b` at second `t0`.
static func _puff(b: PackedFloat32Array, r: RandomNumberGenerator, t0: float, dur: float, fc: float, damp: float, vol: float, decay: float = 0.0) -> void:
	var i0 := int(t0 * RATE)
	var cnt := int(dur * RATE)
	var f := 2.0 * sin(PI * fc / RATE)
	var low := 0.0
	var band := 0.0
	for k in cnt:
		if i0 + k >= b.size():
			return
		var high := r.randf_range(-1.0, 1.0) - low - damp * band
		band += f * high
		low += f * band
		var x := float(k) / cnt
		var e := exp(-decay * x) * minf(1.0, k / 30.0) if decay > 0.0 else sin(PI * x)
		b[i0 + k] += band * e * vol


static func _shot(sound: String, r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _zeros(int(3.0 * RATE))
	var end := 0.5
	match sound:
		"bird":       # a few quick chirps
			var t := 0.0
			for i in r.randi_range(3, 5):
				var f := r.randf_range(3000.0, 3700.0)
				_tone(b, t, 0.07, f, f * 1.35, 0.5, 1.5)
				t += r.randf_range(0.1, 0.17)
			end = t + 0.1
		"bird2":      # two notes, the second one lower
			_tone(b, 0.0, 0.16, 2700.0, 2800.0, 0.5, 1.0)
			_tone(b, 0.24, 0.3, 2250.0, 2150.0, 0.5, 1.5)
			end = 0.6
		"tram":       # the bell of a tram, twice
			for i in 2:
				for h in [[1320.0, 0.5], [1985.0, 0.3], [2650.0, 0.15]]:
					_tone(b, i * 0.32, 0.9, h[0], h[0], h[1], 5.0)
			end = 1.3
		"car":        # a car passes
			var cnt := int(2.6 * RATE)
			var road := _band(cnt, r, 320.0, 0.8)
			for k in cnt:
				var x := float(k) / cnt
				b[k] += road[k] * pow(sin(PI * x), 2.5) * 0.6
			end = 2.6
		"steps":      # somebody walks by, further away
			for i in r.randi_range(4, 6):
				_puff(b, r, i * 0.47, 0.07, 180.0, 0.6, 0.8 - i * 0.08, 6.0)
			end = 3.0
		"door":       # a door falls shut
			_puff(b, r, 0.0, 0.22, 110.0, 0.4, 1.0, 7.0)
			_tone(b, 0.0, 0.2, 90.0, 55.0, 0.6, 5.0)
			_puff(b, r, 0.06, 0.03, 2200.0, 0.8, 0.25, 5.0)
			end = 0.4
		"chalk":      # chalk on a blackboard
			var t2 := 0.0
			for i in r.randi_range(3, 5):
				var d := r.randf_range(0.09, 0.22)
				_puff(b, r, t2, d, r.randf_range(3200.0, 4600.0), 0.35, 0.6)
				_puff(b, r, t2, 0.012, 1500.0, 0.8, 0.5, 4.0)
				t2 += d + r.randf_range(0.05, 0.14)
			end = t2 + 0.05
		"page":       # a page is turned
			_puff(b, r, 0.0, 0.3, 1300.0, 1.2, 0.5)
			_puff(b, r, 0.2, 0.1, 2000.0, 1.0, 0.2)
			end = 0.4
		"clock":      # one tick
			_puff(b, r, 0.0, 0.012, 2600.0, 0.5, 0.7, 5.0)
			_tone(b, 0.0, 0.02, 1900.0, 1700.0, 0.3, 6.0)
			end = 0.05
		"keys":       # a few keys of a keyboard
			var t3 := 0.0
			for i in r.randi_range(4, 8):
				_puff(b, r, t3, 0.014, r.randf_range(2200.0, 3600.0), 0.7, 0.7, 5.0)
				_tone(b, t3, 0.02, 320.0, 240.0, 0.15, 5.0)
				t3 += r.randf_range(0.07, 0.16)
			end = t3 + 0.05
		"bubble":     # something bubbles in a flask
			var t4 := 0.0
			for i in r.randi_range(3, 6):
				var f2 := r.randf_range(260.0, 420.0)
				_tone(b, t4, 0.07, f2, f2 * 2.3, 0.5, 2.0)
				t4 += r.randf_range(0.07, 0.18)
			end = t4 + 0.1
		"glass":      # two glasses touch
			_clink(b, r, 0.0, r.randf_range(2000.0, 2800.0), 1.0)
			end = 0.8
		"clink":      # glasses against each other, two or three times
			var t8 := 0.0
			for i in r.randi_range(1, 3):
				_clink(b, r, t8, r.randf_range(1900.0, 2900.0), r.randf_range(0.6, 1.0))
				t8 += r.randf_range(0.12, 0.3)
			end = t8 + 0.7
		"plates":     # plates are stacked
			var t5 := 0.0
			for i in r.randi_range(2, 4):
				var f4 := r.randf_range(1700.0, 2600.0)
				_ping(b, t5, 0.3, f4, 0.5, 9.0)
				_ping(b, t5, 0.22, f4 * 1.47, 0.35, 11.0)
				_ping(b, t5, 0.14, f4 * 2.9, 0.25, 13.0)
				_puff(b, r, t5, 0.004, 5000.0, 0.9, 0.5, 3.0)
				t5 += r.randf_range(0.09, 0.26)
			end = t5 + 0.3
		"bell":       # the bell on the counter
			_tone(b, 0.0, 1.3, 2093.0, 2093.0, 0.5, 5.0)
			_tone(b, 0.0, 1.0, 4186.0, 4186.0, 0.15, 7.0)
			end = 1.3
		"cutlery":    # knives and forks against each other and against the plate
			var t6 := 0.0
			for i in r.randi_range(3, 6):
				var f5 := r.randf_range(3200.0, 4600.0)
				var loud := r.randf_range(0.4, 0.7)
				_ping(b, t6, 0.2, f5, loud, 8.0)
				_ping(b, t6, 0.15, f5 * 1.51, loud * 0.7, 10.0)
				_ping(b, t6, 0.1, f5 * 2.18, loud * 0.45, 12.0)
				_puff(b, r, t6, 0.003, 7000.0, 0.9, loud * 0.7, 3.0)
				t6 += r.randf_range(0.05, 0.19)
			end = t6 + 0.25
		"drop":       # a fork falls on the floor and dances until it lies still
			var t7 := 0.0
			var gap := r.randf_range(0.2, 0.27)
			var loud2 := 0.7
			var f6 := r.randf_range(2500.0, 3100.0)
			_puff(b, r, 0.0, 0.05, 260.0, 0.6, 0.4, 5.0)
			for i in 10:
				var ff := f6 * r.randf_range(0.96, 1.05)
				_ping(b, t7, 0.25, ff, loud2, 7.0)
				_ping(b, t7, 0.2, ff * 1.59, loud2 * 0.75, 8.0)
				_ping(b, t7, 0.14, ff * 2.71, loud2 * 0.5, 10.0)
				_puff(b, r, t7, 0.003, 7000.0, 0.9, loud2 * 0.6, 3.0)
				t7 += gap
				gap *= 0.72
				loud2 *= 0.8
			end = t7 + 0.35
		"chop":       # a knife on a board, quick
			var t9 := 0.0
			for i in r.randi_range(4, 8):
				_puff(b, r, t9, 0.03, 480.0, 0.5, 0.9, 5.0)
				_puff(b, r, t9, 0.003, 5000.0, 0.9, 0.4, 3.0)
				t9 += r.randf_range(0.11, 0.16)
			end = t9 + 0.1
		"beep":       # some instrument in the lab reports
			_tone(b, 0.0, 0.09, 1568.0, 1568.0, 0.4, 0.5)
			_tone(b, 0.16, 0.09, 1568.0, 1568.0, 0.4, 0.5)
			end = 0.3
		"arrive":     # the gong on arrival: two notes
			for h3 in [[0.0, 784.0], [0.38, 587.33]]:
				_tone(b, h3[0], 1.1, h3[1], h3[1], 0.5, 4.0)
				_tone(b, h3[0], 0.8, h3[1] * 2.0, h3[1] * 2.0, 0.12, 6.0)
			end = 1.5
		"hiss":       # the doors of the bus close
			_puff(b, r, 0.0, 0.55, 1700.0, 1.2, 0.4)
			_puff(b, r, 0.5, 0.06, 180.0, 0.5, 0.6, 5.0)
			end = 0.7
		"owl":
			for h2 in [[0.0, 0.34], [0.6, 0.18], [0.82, 0.4]]:
				_tone(b, h2[0], h2[1], 392.0, 370.0, 0.6, 1.2)
			end = 1.3
	b.resize(mini(b.size(), int(end * RATE)))
	return b


# ------------------------------------------------------------------ music
## One note of the tune, added to `b`; what runs over the end of the loop comes back in at its start.
static func _note(b: PackedFloat32Array, t0: float, dur: float, midi: float, vol: float, wave: String) -> void:
	var n := b.size()
	var f := 440.0 * pow(2.0, (midi - 69.0) / 12.0)
	var w := TAU * f / RATE
	var i0 := int(t0 * RATE)
	match wave:
		"pluck":      # a soft marimba
			var cnt := int(minf(dur + 0.5, 1.2) * RATE)
			for k in cnt:
				var t := float(k) / RATE
				b[(i0 + k) % n] += (sin(w * k) + 0.25 * sin(2.0 * w * k)) * vol * exp(-t * 7.0) * minf(1.0, k / 60.0)
		"bell":
			var len2 := int(2.2 * RATE)
			for k in len2:
				var t := float(k) / RATE
				b[(i0 + k) % n] += (sin(w * k) + 0.3 * sin(2.76 * w * k) * exp(-t * 6.0)) * vol * exp(-t * 2.4) * minf(1.0, k / 80.0)
		"ep":         # an electric piano
			var len3 := int((dur + 0.6) * RATE)
			for k in len3:
				var t := float(k) / RATE
				var rel := minf(1.0, (len3 - k) / (0.5 * RATE))
				b[(i0 + k) % n] += (sin(w * k) + 0.35 * sin(2.0 * w * k) * exp(-t * 8.0)) * vol * exp(-t * 1.8) * minf(1.0, k / 60.0) * rel
		"pad":        # strings that swell
			var len4 := int(dur * RATE)
			for k in len4:
				var x := float(k) / len4
				var e := minf(1.0, x / 0.3) * minf(1.0, (1.0 - x) / 0.3)
				b[(i0 + k) % n] += (sin(w * k) + sin(w * 1.004 * k) + 0.2 * sin(2.0 * w * k)) * 0.5 * vol * e
		"bass":
			var len5 := int(dur * RATE)
			for k in len5:
				var x := float(k) / len5
				b[(i0 + k) % n] += (sin(w * k) + 0.3 * sin(2.0 * w * k)) * vol * minf(1.0, k / 80.0) * minf(1.0, (1.0 - x) / 0.15) * (1.0 - 0.3 * x)
		"kick":
			var len6 := int(0.22 * RATE)
			var ph := 0.0
			for k in len6:
				var x := float(k) / len6
				ph += TAU * lerpf(110.0, 42.0, minf(1.0, x * 2.5)) / RATE
				b[(i0 + k) % n] += sin(ph) * vol * exp(-x * 5.0)
		"snare":
			var len8 := int(0.16 * RATE)
			var prev2 := 0.0
			var sd2 := int(t0 * 1000.0) * 6113 + 7
			for k in len8:
				sd2 = (sd2 * 1103515245 + 12345) & 0x7fffffff
				var white2 := float(sd2) / 1073741824.0 - 1.0
				var x := float(k) / len8
				b[(i0 + k) % n] += ((white2 + prev2) * 0.35 + sin(TAU * 190.0 * k / RATE) * 0.5 * exp(-x * 9.0)) * vol * exp(-x * 5.0)
				prev2 = white2
		"hat":
			var len7 := int(0.05 * RATE)
			var prev := 0.0
			var sd := int(t0 * 1000.0) * 7919 + 13
			for k in len7:
				sd = (sd * 1103515245 + 12345) & 0x7fffffff
				var white := float(sd) / 1073741824.0 - 1.0
				b[(i0 + k) % n] += (white - prev) * 0.5 * vol * exp(-float(k) / len7 * 6.0)
				prev = white


## The tunes of the game, all written for it. `beat` in seconds; times below are in beats.
static func _song(sound: String) -> PackedFloat32Array:
	match sound:
		"menu":       # the start page: up and going, a beat and a tune that climbs (was too calm at first)
			var beat := 60.0 / 122.0
			var b := _zeros(int(32.0 * beat * RATE))
			var chords := [[38, [62, 65, 69]], [34, [62, 65, 70]], [41, [60, 65, 69]], [36, [60, 64, 67]]]
			var arp := [0, 1, 2, 1, 0, 1, 2, 1]
			var hook := [[0.0, 74], [0.75, 77], [1.5, 81], [2.5, 79], [3.0, 77]]
			for bar in 8:
				var t0 := bar * 4.0
				var c: int = bar % 4
				var ch: Array = chords[c][1]
				for q in 4:
					_note(b, (t0 + q) * beat, 0.2, 0, 0.5, "kick")
					_note(b, (t0 + q + 0.5) * beat, 0.1, 0, 0.12, "hat")
					if q % 2 == 1:
						_note(b, (t0 + q) * beat, 0.2, 0, 0.3, "snare")
				for e in 8:
					_note(b, (t0 + e * 0.5) * beat, 0.4 * beat, chords[c][0] + (12 if e % 2 == 1 else 0), 0.3, "bass")
					_note(b, (t0 + e * 0.5) * beat, 0.3 * beat, ch[arp[e]] + 12, 0.11, "pluck")
				for off in [1.5, 3.5]:
					for m in ch:
						_note(b, (t0 + off) * beat, 0.4 * beat, m, 0.09, "ep")
				if bar >= 4:      # the tune comes in the second half, a step higher every bar
					for h in hook:
						_note(b, (t0 + h[0]) * beat, 0.5 * beat, h[1] + [0, 0, -2, -2][c], 0.2, "pluck")
				elif bar == 3:
					for h in [[2.0, 72], [2.5, 74], [3.0, 76], [3.5, 79]]:
						_note(b, (t0 + h[0]) * beat, 0.4 * beat, h[1], 0.18, "pluck")
			return b
		"task":       # for working on a task: light, keeps the pace, stays out of the way
			var beat6 := 60.0 / 100.0
			var b6 := _zeros(int(16.0 * beat6 * RATE))
			var chords6 := [[43, [59, 62, 67]], [40, [59, 64, 67]], [36, [60, 64, 67]], [38, [57, 62, 66]]]
			var pat := [0, 2, 1, 2, 0, 2, 1, 2]
			for bar in 4:
				var t0 := bar * 4.0
				_note(b6, t0 * beat6, 1.8 * beat6, chords6[bar][0], 0.28, "bass")
				_note(b6, (t0 + 2.0) * beat6, 1.4 * beat6, chords6[bar][0] + 7, 0.2, "bass")
				_note(b6, t0 * beat6, 0.2, 0, 0.3, "kick")
				_note(b6, (t0 + 2.5) * beat6, 0.2, 0, 0.2, "kick")
				for e in 8:
					_note(b6, (t0 + e * 0.5) * beat6, 0.3 * beat6, chords6[bar][1][pat[e]], 0.16, "pluck")
					if e % 2 == 1:
						_note(b6, (t0 + e * 0.5) * beat6, 0.1, 0, 0.07, "hat")
			for m2 in [[1.0, 79], [3.0, 78], [5.5, 76], [9.0, 79], [10.5, 76], [13.0, 74], [14.5, 78]]:
				_note(b6, m2[0] * beat6, beat6, m2[1], 0.11, "bell")
			return b6
		"day":        # light and bouncy: outside by day
			var beat2 := 60.0 / 108.0
			var b2 := _zeros(int(16.0 * beat2 * RATE))
			var chords2 := [[41, [53, 57, 60]], [36, [52, 55, 60]], [38, [53, 57, 62]], [34, [53, 58, 62]]]
			var tune := [[69, 72, 0, 77, 0, 74, 72, 0], [67, 72, 0, 76, 0, 72, 67, 0], [69, 74, 0, 77, 0, 74, 69, 0], [70, 74, 0, 77, 79, 77, 74, 0]]
			for bar in 4:
				var t0 := bar * 4.0
				_note(b2, t0 * beat2, 0.9 * beat2, chords2[bar][0], 0.32, "bass")
				_note(b2, (t0 + 2.0) * beat2, 0.9 * beat2, chords2[bar][0] + 7, 0.24, "bass")
				_note(b2, (t0 + 3.5) * beat2, 0.4 * beat2, chords2[bar][0] + 12, 0.18, "bass")
				for off in [1.0, 3.0]:
					for m in chords2[bar][1]:
						_note(b2, (t0 + off) * beat2, 0.5 * beat2, m, 0.08, "ep")
				for e in 8:
					if tune[bar][e] > 0:
						_note(b2, (t0 + e * 0.5) * beat2, 0.4 * beat2, tune[bar][e], 0.2, "pluck")
					if e % 2 == 1:
						_note(b2, (t0 + e * 0.5) * beat2, 0.1, 0, 0.06, "hat")
			return b2
		"suspense":   # slow and uneasy: at night
			var beat3 := 1.0
			var b3 := _zeros(int(16.0 * beat3 * RATE))
			for bar in 4:
				var t0 := bar * 4.0
				for m in [38, 45, 50]:
					_note(b3, t0, 4.6, m, 0.12, "pad")
				_note(b3, t0, 0.2, 0, 0.3, "kick")
				_note(b3, t0 + 0.36, 0.2, 0, 0.2, "kick")
			for m2 in [[1.0, 77], [3.0, 76], [6.0, 74], [8.5, 69], [10.0, 72], [13.0, 70], [15.0, 69]]:
				_note(b3, m2[0], 1.0, m2[1], 0.1, "bell")
			return b3
		"chase":      # fast: somebody is after you
			var beat4 := 60.0 / 160.0
			var b4 := _zeros(int(16.0 * beat4 * RATE))
			var roots := [38, 38, 34, 33]
			var steps := [0, 0, 3, 0, 5, 0, 3, 2]
			for bar in 4:
				var t0 := bar * 4.0
				for e in 8:
					_note(b4, (t0 + e * 0.5) * beat4, 0.42 * beat4, roots[bar] + steps[e], 0.34, "bass")
					if e % 2 == 0:
						_note(b4, (t0 + e * 0.5) * beat4, 0.2, 0, 0.45, "kick")
					else:
						_note(b4, (t0 + e * 0.5) * beat4, 0.1, 0, 0.1, "hat")
				for m in [[0.0, 69], [1.5, 69], [3.0, 72]]:
					_note(b4, (t0 + m[0]) * beat4, 0.4 * beat4, m[1] + (roots[bar] - 38), 0.16, "pluck")
			return b4
		_:            # "lounge": soft and warm, from a radio in the corner
			var beat5 := 60.0 / 76.0
			var b5 := _zeros(int(16.0 * beat5 * RATE))
			var chords5 := [[41, [57, 60, 64]], [40, [55, 59, 62]], [38, [53, 57, 60]], [43, [53, 59, 62]]]
			for bar in 4:
				var t0 := bar * 4.0
				for m in chords5[bar][1]:
					_note(b5, t0 * beat5, 2.4 * beat5, m, 0.1, "ep")
					_note(b5, (t0 + 2.5) * beat5, 0.9 * beat5, m, 0.07, "ep")
				_note(b5, t0 * beat5, 1.6 * beat5, chords5[bar][0], 0.3, "bass")
				_note(b5, (t0 + 2.0) * beat5, 1.2 * beat5, chords5[bar][0] + 7, 0.22, "bass")
				_note(b5, (t0 + 3.5) * beat5, 0.4 * beat5, chords5[(bar + 1) % 4][0] + 1, 0.16, "bass")
				for off in [1.0, 3.0]:
					_note(b5, (t0 + off) * beat5, 0.1, 0, 0.05, "hat")
			for m2 in [[1.0, 76], [2.5, 79], [4.5, 74], [9.0, 72], [10.0, 69], [11.0, 72], [12.0, 71], [14.5, 74]]:
				_note(b5, m2[0] * beat5, beat5, m2[1], 0.12, "bell")
			return b5
