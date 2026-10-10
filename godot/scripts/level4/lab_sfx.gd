extends Node
## Level 4: sounds that only this level needs, synthesised like sfx.gd (no audio files).
##   play("boom" | "glass" | "stamp" | "blah" | "drip" | "alarm" | "hiss")   one-shots
##   kettle(heat)                                          the professor coming to the boil: a whistle
##                                                         that gets higher and louder with heat 0..1
##   kettle_off()

const RATE := 22050
const KETTLE_PERIOD := 16   # samples per cycle, so the loop closes without a click

var players: Array = []
var streams := {}
var next := 0
var kettle_p: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	kettle_p = AudioStreamPlayer.new()
	add_child(kettle_p)


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


func kettle(heat: float) -> void:
	if heat < 0.3:
		kettle_off()
		return
	if not kettle_p.playing:
		if not streams.has("kettle"):
			streams["kettle"] = _make("kettle")
		kettle_p.stream = streams["kettle"]
		kettle_p.play()
	var k := clampf((heat - 0.3) / 0.7, 0.0, 1.0)
	kettle_p.pitch_scale = lerpf(0.55, 2.1, k * k)
	kettle_p.volume_db = lerpf(-30.0, -9.0, k)


func kettle_off() -> void:
	if kettle_p.playing:
		kettle_p.stop()


func _make(sound: String) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	var ph := 0.0
	var loop := false
	match sound:
		"kettle":   # steady whistle with a bit of breath; pitch and volume are set while it plays
			var n := KETTLE_PERIOD * 512
			buf.resize(n)
			for i in n:
				var a := TAU * float(i) / KETTLE_PERIOD
				buf[i] = sin(a) * 0.42 + sin(a * 2.0) * 0.12 + sin(a * 3.0) * 0.05 + randf_range(-1.0, 1.0) * 0.07
			loop = true
		"boom":   # the thermometer goes: filtered noise over a falling bass note
			var n := int(1.0 * RATE)
			buf.resize(n)
			var lp := 0.0
			for i in n:
				var u := float(i) / n
				lp += (randf_range(-1.0, 1.0) - lp) * lerpf(0.55, 0.03, sqrt(u))
				ph += lerpf(120.0, 34.0, u) / RATE
				buf[i] = (lp * 1.1 + sin(TAU * ph) * 0.75) * pow(1.0 - u, 1.8)
		"glass":   # shards
			var n := int(0.7 * RATE)
			buf.resize(n)
			buf.fill(0.0)
			var freqs := [2350.0, 3140.0, 4180.0, 5270.0, 6630.0, 3720.0]
			for k in freqs.size():
				var start := int(k * 0.035 * RATE)
				var length := int(0.3 * RATE)
				for i in length:
					if start + i >= n:
						break
					var u := float(i) / length
					buf[start + i] += sin(TAU * float(freqs[k]) * i / RATE) * 0.2 * pow(1.0 - u, 3.0)
			for i in int(0.03 * RATE):
				buf[i] += randf_range(-1.0, 1.0) * 0.4 * (1.0 - float(i) / (0.03 * RATE))
		"stamp":   # rubber stamp on the exam sheet
			var n := int(0.4 * RATE)
			buf.resize(n)
			for i in n:
				var u := float(i) / n
				ph += lerpf(150.0, 45.0, u) / RATE
				var click := randf_range(-1.0, 1.0) * 0.6 if i < int(0.015 * RATE) else 0.0
				buf[i] = sin(TAU * ph) * 0.95 * pow(1.0 - u, 2.6) + click
		"blah":   # one syllable of the professor's voice, played at random pitches
			var n := int(0.075 * RATE)
			buf.resize(n)
			for i in n:
				var u := float(i) / n
				ph += lerpf(190.0, 150.0, u) / RATE
				var sq := 1.0 if fmod(ph, 1.0) < 0.42 else -1.0
				buf[i] = (sq * 0.3 + sin(TAU * ph * 2.0) * 0.15) * minf(1.0, i / (0.004 * RATE)) * pow(1.0 - u, 1.2)
		"alarm":   # smoke detector: two short beeps
			var n := int(0.3 * RATE)
			buf.resize(n)
			for i in n:
				var u := float(i) / n
				var on := u < 0.4 or (u > 0.55 and u < 0.95)
				ph += 2350.0 / RATE
				buf[i] = (0.28 if fmod(ph, 1.0) < 0.5 else -0.28) if on else 0.0
		"hiss":   # water on something hot: the emergency shower, a flame going out
			var n := int(1.1 * RATE)
			buf.resize(n)
			var lp := 0.0
			for i in n:
				var u := float(i) / n
				var w := randf_range(-1.0, 1.0)
				lp += (w - lp) * 0.35
				buf[i] = (w - lp) * 0.5 * minf(1.0, u * 12.0) * pow(1.0 - u, 1.4)
		"drip":
			var n := int(0.12 * RATE)
			buf.resize(n)
			for i in n:
				var u := float(i) / n
				ph += lerpf(620.0, 1500.0, u) / RATE
				buf[i] = sin(TAU * ph) * 0.4 * pow(1.0 - u, 2.0)
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
