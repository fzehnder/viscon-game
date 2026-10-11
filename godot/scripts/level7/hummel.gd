extends Node
## Background music of the exam: "Flight of the Bumblebee" (Nikolai Rimsky-Korsakov, 1900, public
## domain) as a piano piece, made in code like the other sounds of the game (sfx.gd, musik.gd of
## level 3): the notes below and a piano tone synthesised per pitch. Rendered once in a thread when
## the exam starts (one or two seconds), kept for restarts, then played in a loop.
## The right hand runs in sixteenths (the famous chromatic buzzing), the left hand plays bass and
## chord on the two beats of each bar. Nobody has listened to it while it was written: tempo,
## loudness and tone are a first guess (constants below).

const RATE := 22050
const SIXTEENTH := 0.1        # seconds per sixteenth: 150 quarter notes a minute (frantic, still clear)
const VOL := -13.0            # dB of the loop
const FADE := 0.8             # seconds to fade out at the end of the exam
const TONE := 0.4             # seconds of each synthesised piano tone (longest a note can ring)

# the right hand: one bar = 8 sixteenths, as MIDI numbers (69 = a', 76 = e'')
const DOWN := [[88, 87, 86, 85, 86, 85, 84, 83], [84, 83, 82, 81, 80, 79, 78, 77],
	[76, 75, 74, 73, 74, 73, 72, 71], [72, 71, 70, 69, 68, 67, 66, 65]]   # chromatic descent from e'''
const T1 := [76, 75, 74, 73, 72, 77, 76, 75]     # the theme: e'' d#'' d'' c#'' c'' f'' e'' d#''
const T2 := [76, 75, 74, 73, 72, 73, 74, 75]     # ... and back up to e''
const T3 := [76, 75, 74, 73, 74, 73, 72, 71]
const T4 := [72, 73, 74, 75, 76, 77, 76, 75]
const RUN_UP := [76, 77, 78, 79, 80, 81, 82, 83]
const TO_TOP := [84, 85, 86, 87, 88, 89, 88, 87]
# harmony of a bar: [bass, chord] (the bass is doubled an octave lower)
const AM := [45, [57, 60, 64]]
const DM := [50, [62, 65, 69]]
const E7 := [40, [56, 59, 62]]

static var _pcm := PackedByteArray()   # the rendered loop (16 bit mono); survives a restart of the level
var _task := -1
var _player: AudioStreamPlayer = null
var _fading := false


func _ready() -> void:
	if _pcm.is_empty():
		_task = WorkerThreadPool.add_task(_render_static)
	else:
		_play()


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if not _fading:
			_play()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)   # a thread still rendering must not outlive the node
		_task = -1


## Fades out and then removes itself.
func stop() -> void:
	_fading = true
	if _player == null:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_player, "volume_db", -60.0, FADE)
	tw.tween_callback(queue_free)


func _play() -> void:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = _pcm
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = _pcm.size() / 2
	_player = AudioStreamPlayer.new()
	_player.stream = st
	_player.volume_db = -40.0
	add_child(_player)
	_player.play()
	create_tween().tween_property(_player, "volume_db", VOL, 1.2)


static func _render_static() -> void:
	_pcm = _render()


## The piece as bars: [right hand, harmony]. About 21 seconds, then it starts over.
static func _bars() -> Array:
	var b: Array = []
	for i in 4:
		b.append([DOWN[i], AM])
	for pair in [[T1, AM], [T2, AM], [T1, AM], [T2, AM], [T3, AM], [T4, AM], [T3, AM], [RUN_UP, E7]]:
		b.append(pair)
	for rh in [T1, T2, T1, T2]:   # the theme an octave higher
		b.append([_up(rh, 12), AM])
	for rh in [T1, T2, T1, T2]:   # and in d minor, a fourth higher
		b.append([_up(rh, 5), DM])
	for pair in [[T1, AM], [T2, AM], [T3, AM], [T4, AM], [RUN_UP, E7], [TO_TOP, E7]]:
		b.append(pair)
	return b


static func _up(rh: Array, n: int) -> Array:
	var out: Array = []
	for m in rh:
		out.append(int(m) + n)
	return out


static func _render() -> PackedByteArray:
	var bars := _bars()
	var step := int(SIXTEENTH * RATE)
	var total := bars.size() * 8 * step
	var mix := PackedFloat32Array()
	mix.resize(total)
	var tones := {}
	# notes: [start sample, MIDI, held samples, loudness]
	var notes: Array = []
	for bi in bars.size():
		var rh: Array = bars[bi][0]
		var harm: Array = bars[bi][1]
		var bar0 := bi * 8 * step
		for k in 8:
			var accent := 1.0 if k % 4 == 0 else 0.82
			notes.append([bar0 + k * step, int(rh[k]), int(step * 1.25), 0.55 * accent])
		notes.append([bar0, int(harm[0]), int(step * 1.6), 0.5])           # beat 1: bass in octaves
		notes.append([bar0, int(harm[0]) - 12, int(step * 1.6), 0.38])
		for m in harm[1]:                                                    # beat 2: the chord
			notes.append([bar0 + 4 * step, int(m), int(step * 1.4), 0.2])
	var release := int(0.05 * RATE)
	for n in notes:
		var m: int = n[1]
		if not tones.has(m):
			tones[m] = _tone(m)
		var src: PackedFloat32Array = tones[m]
		var held: int = n[2]
		var amp: float = n[3]
		var length := mini(src.size(), held + release)
		var s0: int = n[0]
		for j in length:
			var g := amp if j < held else amp * (1.0 - float(j - held) / release)
			var at := (s0 + j) % total   # notes at the end ring into the start: the loop has no seam
			mix[at] += src[j] * g
	var peak := 0.001
	for v in mix:
		peak = maxf(peak, absf(v))
	var out := PackedByteArray()
	out.resize(total * 2)
	var k2 := 0.9 / peak
	for i in total:
		out.encode_s16(i * 2, int(clampf(mix[i] * k2, -1.0, 1.0) * 32767.0))
	return out


## One piano tone: a few slightly stretched overtones that die away faster the higher they are,
## a quick attack and a tiny knock of the hammer.
static func _tone(m: int) -> PackedFloat32Array:
	var f := 440.0 * pow(2.0, (m - 69) / 12.0)
	var n := int(TONE * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var tau := clampf(0.55 * sqrt(262.0 / f), 0.12, 0.9)
	var parts: Array = []
	var norm := 0.0
	for k in range(1, 8):
		var fk := k * f * sqrt(1.0 + 0.0004 * k * k)
		if fk > 7000.0:
			break
		var a := 1.0 / pow(k, 1.4)
		parts.append([TAU * fk / RATE, a, exp(-1.0 / (RATE * tau / (1.0 + 0.6 * (k - 1))))])
		norm += a
	var rng := RandomNumberGenerator.new()
	rng.seed = m
	for p in parts:
		var w: float = p[0]
		var env: float = p[1] / norm
		var dec: float = p[2]
		for i in n:
			out[i] += sin(w * i) * env
			env *= dec
	var attack := int(0.004 * RATE)
	var knock := int(0.008 * RATE)
	for i in mini(n, knock):
		out[i] += rng.randf_range(-1.0, 1.0) * 0.06 * (1.0 - float(i) / knock)
	for i in mini(n, attack):
		out[i] *= float(i) / attack
	return out
