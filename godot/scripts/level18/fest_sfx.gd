extends Node
## Level 18 (Ersti-Fest): the beat of the party and a few sounds, synthesised like sfx.gd (no audio files).
##   beat_on() / beat_off()                      a two-second loop, four beats at BPM
##   play("hit" | "miss" | "cheer" | "scratch" | "thud")

const RATE := 22050
const BPM := 120.0

var players: Array = []
var streams := {}
var next := 0
var beat_p: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	beat_p = AudioStreamPlayer.new()
	add_child(beat_p)


func play(sound: String, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	if not streams.has(sound):
		streams[sound] = _make(sound)
	if streams[sound] == null:
		return
	var p: AudioStreamPlayer = players[next]
	next = (next + 1) % players.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func beat_on(volume_db: float = -9.0) -> void:
	if not streams.has("beat"):
		streams["beat"] = _make("beat")
	beat_p.stream = streams["beat"]
	beat_p.volume_db = volume_db
	beat_p.play()


func beat_off() -> void:
	beat_p.stop()


func _make(sound: String) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	var loop := false
	match sound:
		"beat":   # kick on every beat, clap on 2 and 4, hi-hat in between, a bass line
			var n := int(4.0 * 60.0 / BPM * RATE)
			buf.resize(n)
			var beat := 60.0 / BPM
			var bass := [55.0, 55.0, 65.4, 49.0]
			var ph := 0.0
			var bph := 0.0
			for i in n:
				var tt := float(i) / RATE
				var b := int(tt / beat)
				var u := tt - b * beat          # seconds since the last beat
				var v := 0.0
				if u < 0.2:   # kick
					ph += lerpf(130.0, 42.0, u / 0.2) / RATE
					v += sin(TAU * ph) * 0.8 * pow(1.0 - u / 0.2, 1.6)
				if b % 2 == 1 and u < 0.11:   # clap
					v += randf_range(-1.0, 1.0) * 0.32 * pow(1.0 - u / 0.11, 1.4)
				var o := u - beat / 2.0         # seconds since the off-beat
				if o >= 0.0 and o < 0.05:      # hi-hat
					v += randf_range(-1.0, 1.0) * 0.16 * (1.0 - o / 0.05)
				if o >= 0.0 and o < 0.2:       # bass
					bph += float(bass[b % 4]) * 2.0 / RATE
					v += (0.22 if fmod(bph, 1.0) < 0.5 else -0.22) * (1.0 - o / 0.2)
				buf[i] = v
			loop = true
		"hit":
			var n := int(0.09 * RATE)
			buf.resize(n)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += lerpf(880.0, 1500.0, u) / RATE
				buf[i] = sin(TAU * ph) * 0.4 * pow(1.0 - u, 1.5)
		"miss":
			var n := int(0.14 * RATE)
			buf.resize(n)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += 130.0 / RATE
				buf[i] = (0.3 if fmod(ph, 1.0) < 0.5 else -0.3) * (1.0 - u)
		"scratch":
			var n := int(0.28 * RATE)
			buf.resize(n)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += (500.0 + 900.0 * absf(sin(u * PI * 2.0))) / RATE
				buf[i] = (sin(TAU * ph) * 0.3 + randf_range(-1.0, 1.0) * 0.12) * sin(u * PI)
		"cheer":   # a crowd: noise that swells and fades
			var n := int(1.3 * RATE)
			buf.resize(n)
			var lp := 0.0
			for i in n:
				var u := float(i) / n
				lp += (randf_range(-1.0, 1.0) - lp) * 0.22
				buf[i] = lp * 0.9 * sin(u * PI) * (0.8 + 0.2 * sin(u * 60.0))
		"thud":
			var n := int(0.3 * RATE)
			buf.resize(n)
			var ph := 0.0
			for i in n:
				var u := float(i) / n
				ph += lerpf(120.0, 40.0, u) / RATE
				buf[i] = sin(TAU * ph) * 0.9 * pow(1.0 - u, 2.2)
		_:
			return null
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s
