extends Node
## Autoload "Sfx": tiny synthesizer, so the game has satisfying sounds without any audio files.
## Sfx.play("click" | "pop" | "success" | "fanfare" | "fail" | "type" | "shutter" | "grant" | "steal" | "tick" | "whoosh")

const RATE := 22050
var players: Array = []
var cache := {}
var next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		players.append(p)


func play(sound: String, volume_db: float = -6.0) -> void:
	if not cache.has(sound):
		cache[sound] = _make(sound)
	var s: AudioStreamWAV = cache[sound]
	if s == null:
		return
	var p: AudioStreamPlayer = players[next]
	next = (next + 1) % players.size()
	p.stream = s
	p.volume_db = volume_db
	p.play()


# notes: [frequency Hz (0 = noise), start s, length s, volume 0..1, wave "sine"|"tri"|"square"|"noise", end frequency]
func _make(sound: String) -> AudioStreamWAV:
	var notes: Array = []
	match sound:
		"click":
			notes = [[1400.0, 0.0, 0.035, 0.35, "tri", 900.0]]
		"tick":
			notes = [[2000.0, 0.0, 0.025, 0.25, "square", 2000.0]]
		"type":
			notes = [[0.0, 0.0, 0.018, 0.18, "noise", 0.0], [2600.0, 0.0, 0.012, 0.12, "square", 2600.0]]
		"pop":
			notes = [[520.0, 0.0, 0.09, 0.5, "sine", 1250.0]]
		"whoosh":
			notes = [[0.0, 0.0, 0.22, 0.25, "noise", 0.0], [300.0, 0.0, 0.22, 0.2, "sine", 900.0]]
		"success":
			notes = [[523.3, 0.0, 0.12, 0.45, "tri", 523.3], [659.3, 0.07, 0.12, 0.45, "tri", 659.3],
				[784.0, 0.14, 0.12, 0.45, "tri", 784.0], [1046.5, 0.21, 0.28, 0.5, "tri", 1046.5],
				[2093.0, 0.21, 0.2, 0.12, "sine", 2093.0]]
		"fanfare":
			notes = [[523.3, 0.0, 0.14, 0.4, "square", 523.3], [659.3, 0.12, 0.14, 0.4, "square", 659.3],
				[784.0, 0.24, 0.14, 0.4, "square", 784.0], [1046.5, 0.36, 0.55, 0.45, "square", 1046.5],
				[659.3, 0.36, 0.55, 0.25, "tri", 659.3], [784.0, 0.36, 0.55, 0.25, "tri", 784.0],
				[2093.0, 0.5, 0.4, 0.1, "sine", 2093.0]]
		"fail":
			notes = [[300.0, 0.0, 0.14, 0.4, "square", 240.0], [220.0, 0.13, 0.26, 0.4, "square", 150.0]]
		"shutter":
			notes = [[0.0, 0.0, 0.05, 0.6, "noise", 0.0], [0.0, 0.07, 0.09, 0.45, "noise", 0.0]]
		"grant":
			notes = [[660.0, 0.0, 0.12, 0.4, "square", 660.0], [990.0, 0.12, 0.3, 0.4, "square", 990.0]]
		"steal":
			notes = [[0.0, 0.0, 0.12, 0.3, "noise", 0.0], [400.0, 0.05, 0.12, 0.45, "sine", 1600.0],
				[1318.5, 0.16, 0.18, 0.4, "tri", 1318.5]]
		_:
			return null
	var total := 0.0
	for n in notes:
		total = maxf(total, float(n[1]) + float(n[2]))
	var count := int(total * RATE) + 32
	var buf := PackedFloat32Array()
	buf.resize(count)
	buf.fill(0.0)
	for n in notes:
		var f0: float = n[0]
		var start := int(float(n[1]) * RATE)
		var length := int(float(n[2]) * RATE)
		var vol: float = n[3]
		var wave: String = n[4]
		var f1: float = n[5]
		var ph := 0.0
		for i in length:
			var u := float(i) / float(length)
			var env := minf(1.0, i / (0.005 * RATE)) * pow(1.0 - u, 2.2)
			var f := lerpf(f0, f1, u)
			ph += f / RATE
			var v := 0.0
			match wave:
				"sine":
					v = sin(TAU * ph)
				"tri":
					v = 1.0 - 4.0 * absf(fmod(ph, 1.0) - 0.5)
				"square":
					v = (1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * 0.6
				_:
					v = randf_range(-1.0, 1.0)
			var idx := start + i
			if idx < count:
				buf[idx] += v * vol * env
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s
