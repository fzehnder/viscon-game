extends Node
## The music of the Polyball: one loop of disco house, eight bars at 128 beats per minute, made
## in code like the sounds in sfx.gd (the game has no audio files).
## It is rendered once, in a thread, when the level starts (about a second), kept for restarts
## of the level, and then plays in a loop on an audio bus of its own with a low-pass filter.
## The level says how close the players are to the dance floor (`near`, 0 .. 1): far away the
## music is quiet and dull, as through walls, on the dance floor loud and clear. `full` opens
## everything (dance minigame, ending).
## beat_pos() is where the music is, in beats: the dance changes its poses on the beat.
## Nobody has listened to it while it was written: levels and sounds are a first guess.

const RATE := 22050
const BPM := 128.0
const BARS := 8
const BUS := "Polyball"
# ---- tuning: how loud (dB) and how dull (cut-off of the low-pass, Hz)
const VOL_FAR := -27.0           # near = 0: a thump from far away
const VOL_NEAR := -10.0          # near = 1: on the dance floor
const VOL_FULL := -5.0           # dance minigame and ending
const CUT_FAR := 420.0
const CUT_NEAR := 9000.0
const CUT_FULL := 20000.0
const FOLLOW := 0.5              # seconds over which volume and filter follow
# ---- the tune: one chord per bar, twice through: A minor, F, C, G
const ROOTS := [55.0, 43.65, 65.41, 49.0]            # bass: A1 F1 C2 G1
const CHORDS := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
const STABS := [0, 3, 6, 10, 13]                     # the sixteenths of a bar on which the chord is hit
# melody: [bar, eighth of that bar, frequency]. A pick-up in bars 2 and 4, the tune in bars 5 to 8.
const LEAD := [
	[1, 6, 440.0], [1, 7, 523.25], [3, 6, 493.88], [3, 7, 587.33],
	[4, 0, 659.26], [4, 2, 659.26], [4, 3, 587.33], [4, 5, 523.25], [4, 7, 440.0],
	[5, 0, 523.25], [5, 2, 440.0], [5, 4, 523.25], [5, 6, 587.33],
	[6, 0, 659.26], [6, 2, 783.99], [6, 3, 659.26], [6, 5, 587.33], [6, 7, 523.25],
	[7, 0, 587.33], [7, 2, 493.88], [7, 4, 587.33], [7, 5, 659.26], [7, 6, 587.33],
]

static var _pcm := PackedByteArray()   # the rendered loop (16 bit mono); survives a restart of the level

var near := 0.0                  # 0 far from the dance floor .. 1 on it, set by the level
var full := false                # everything open: dance minigame, ending
var player: AudioStreamPlayer
var filter: AudioEffectLowPassFilter
var render_ms := 0               # how long the rendering took (for the README and for tests)
var _thread: Thread
var _stop := false
var _vol := -60.0
var _cut := CUT_FAR


func _ready() -> void:
	_bus()
	player = AudioStreamPlayer.new()
	player.bus = BUS
	player.volume_db = _vol
	add_child(player)
	if _pcm.is_empty():
		_thread = Thread.new()
		_thread.start(_render)
	else:
		_start()


## The bus of the music: Master with a low-pass in front. Made here and taken away again in
## _exit_tree, so the other levels never see it.
func _bus() -> void:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
		AudioServer.add_bus_effect(i, AudioEffectLowPassFilter.new())
	filter = AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
	filter.cutoff_hz = _cut


func _exit_tree() -> void:
	if _thread != null:
		_stop = true
		_thread.wait_to_finish()
		_thread = null
	var i := AudioServer.get_bus_index(BUS)
	if i >= 0:
		AudioServer.remove_bus(i)


func _process(delta: float) -> void:
	if _thread != null and not _thread.is_alive():
		_pcm = _thread.wait_to_finish()
		_thread = null
		_start()
	var k := clampf(near, 0.0, 1.0)
	var vol := VOL_FULL if full else lerpf(VOL_FAR, VOL_NEAR, pow(k, 0.7))
	var cut := CUT_FULL if full else exp(lerpf(log(CUT_FAR), log(CUT_NEAR), k))
	var a := 1.0 - exp(-delta / FOLLOW)
	_vol = lerpf(_vol, vol, a)
	_cut = exp(lerpf(log(_cut), log(cut), a))
	player.volume_db = _vol
	filter.cutoff_hz = _cut


func _start() -> void:
	if _pcm.is_empty() or player == null:
		return
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = _pcm
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = _pcm.size() / 2
	player.stream = s
	player.play()


## From the first bar again: the dance and the ending start on a bar.
func restart() -> void:
	if player != null and player.stream != null:
		player.play(0.0)


## Where the music is, in beats since the loop began (0 .. BARS * 4). -1 while there is none.
func beat_pos() -> float:
	if player == null or not player.playing:
		return -1.0
	var p := player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	var beat := 60.0 / BPM
	return fposmod(p, BARS * 4 * beat) / beat


# ------------------------------------------------------------------ rendering (runs in the thread)
func _at(beat: float) -> int:
	return int(round(beat * 60.0 / BPM * RATE))


## The bass drum: a sine whose pitch drops fast.
func _kick() -> PackedFloat32Array:
	var n := int(0.24 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var u := float(i) / n
		ph += (46.0 + 115.0 * exp(-u * 14.0)) / RATE
		out[i] = sin(TAU * ph) * pow(1.0 - u, 2.0)
	return out


## Noise that dies away: bright for the hi-hat, dull for the clap.
func _noise(rng: RandomNumberGenerator, length: float, decay: float, bright: bool) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var v := rng.randf_range(-1.0, 1.0)
		out[i] = ((v - prev) if bright else (v + prev) * 0.5) * pow(1.0 - float(i) / n, decay)
		prev = v
	return out


## A note from a few harmonics ([multiple, level]), with a short attack and a decay.
func _tone(freq: float, length: float, harm: Array, decay: float, vibrato: float = 0.0) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var attack := 0.004 * RATE
	for i in n:
		var tt := float(i) / RATE
		var ph := TAU * freq * tt + vibrato * sin(TAU * 5.5 * tt)
		var v := 0.0
		for h in harm:
			v += sin(ph * h[0]) * h[1]
		out[i] = v * minf(1.0, i / attack) * pow(1.0 - float(i) / n, decay)
	return out


## Adds a sound to the loop. What runs over the end comes in again at the beginning.
func _mix(buf: PackedFloat32Array, s: PackedFloat32Array, at: int, vol: float) -> void:
	var total := buf.size()
	var n := s.size()
	if at + n <= total:
		for i in n:
			buf[at + i] += s[i] * vol
	else:
		for i in n:
			buf[(at + i) % total] += s[i] * vol


func _render() -> PackedByteArray:
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 128
	var total := _at(BARS * 4)
	var drums := PackedFloat32Array()
	drums.resize(total)
	var tonal := PackedFloat32Array()
	tonal.resize(total)
	var kick := _kick()
	var hat := _noise(rng, 0.045, 2.0, true)
	var clap := _noise(rng, 0.15, 2.6, false)
	var bass_h := [[1.0, 1.0], [2.0, 0.45], [3.0, 0.2]]
	var stab_h := [[1.0, 1.0], [2.0, 0.5], [3.0, 0.33], [4.0, 0.2], [5.0, 0.12]]
	var lead_h := [[1.0, 1.0], [2.0, 0.25], [3.0, 0.1]]
	var bass: Array = []
	var bass_hi: Array = []
	var stabs: Array = []
	for c in 4:
		bass.append(_tone(ROOTS[c], 0.21, bass_h, 1.6))
		bass_hi.append(_tone(ROOTS[c] * 2.0, 0.19, bass_h, 1.8))
		var notes: Array = []
		for f in CHORDS[c]:
			notes.append(_tone(f, 0.17, stab_h, 2.4))
		stabs.append(notes)
		if _stop:
			return PackedByteArray()
	var leads := {}
	for l in LEAD:
		if not leads.has(l[2]):
			leads[l[2]] = _tone(l[2], 0.27, lead_h, 1.8, 0.25)
	for bar in BARS:
		if _stop:
			return PackedByteArray()
		var c := bar % 4
		for beat in 4:
			var b := float(bar * 4 + beat)
			_mix(drums, kick, _at(b), 0.95)                            # four on the floor
			_mix(drums, hat, _at(b + 0.5), 0.17)                       # hi-hat between the beats
			_mix(drums, hat, _at(b + 0.25), 0.05)
			_mix(drums, hat, _at(b + 0.75), 0.05)
			if beat % 2 == 1:
				_mix(drums, clap, _at(b), 0.42)                        # clap on two and four
			_mix(tonal, bass_hi[c] if beat == 3 else bass[c], _at(b + 0.5), 0.55)   # the bass answers the drum
		for s in STABS:
			for note in stabs[c]:
				_mix(tonal, note, _at(bar * 4 + s * 0.25), 0.13)
	for k in 3:                                                         # three claps lead back to the start
		_mix(drums, clap, _at((BARS - 1) * 4 + 3.25 + k * 0.25), 0.2 + k * 0.07)
	for l in LEAD:
		_mix(tonal, leads[l[2]], _at(l[0] * 4 + l[1] * 0.5), 0.2)
	# everything but the drums ducks under each bass drum (the pumping of house music); then a
	# soft limit, and as loud as 16 bit allow without clipping
	var step := 60.0 / BPM * RATE
	var peak := 0.001
	for i in total:
		var since := fmod(float(i), step) / RATE
		var v := tanh((drums[i] + tonal[i] * (1.0 - 0.55 * exp(-since / 0.11))) * 0.9)
		drums[i] = v
		peak = maxf(peak, absf(v))
	if _stop:
		return PackedByteArray()
	var gain := 0.9 / peak * 32767.0
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		bytes.encode_s16(i * 2, int(drums[i] * gain))
	render_ms = Time.get_ticks_msec() - t0
	return bytes
