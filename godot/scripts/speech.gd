extends Node
## Speech recognition for levels: hold a key, speak, get the text. Add it as a child:
##
##   var speech := Speech.new()
##   add_child(speech)                 # starts tracker/speech.py (Whisper, offline) by itself
##   speech.heard.connect(func(id, text): ...)
##   speech.begin()                    # key down: start recording the microphone
##   var id := speech.finish("AMZ Formula Student")   # key up: words to expect help Whisper
##
## `is_ready` is true once the model is loaded; `state` is a short German text for the UI.
## Without Python, uv or the model, `failed` becomes true: offer a keyboard variant then.
## The game records the microphone itself (needs audio/driver/enable_input in project.godot)
## and hands the Python process a WAV file; nothing leaves the computer.
## `level` (0..1) is the loudness of the microphone, also while not recording.

signal heard(id: int, text: String)

const PORT_IN := 47802        # speech.py -> game
const PORT_OUT := 47803       # game -> speech.py
const HEARTBEAT := 0.5
const TIMEOUT := 1.5          # no hello for this long: the process counts as gone
const START_WAIT := 1.2       # wait this long for a speech.py that is already running
const GIVE_UP := 10.0         # a started process that dies within this time did not work: try the next way
const ANSWER_WAIT := 25.0     # no text after this long: give up on that recording
const MAX_SECONDS := 20.0     # recordings are cut off after this
const LEVEL_DB := Vector2(-55.0, -15.0)   # microphone loudness that counts as 0 and as 1

var is_ready := false
var failed := false
var state := "startet …"
var level := 0.0
var recording := false
var rec_time := 0.0

var _in: PacketPeerUDP
var _out: PacketPeerUDP
var _now := 0.0
var _last_hello := -100.0
var _beat := 0.0
var _wait := 0.0
var _pid := -1
var _started_at := 0.0
var _launch_i := 0
var _model_state := ""
var _error := ""
var _next_id := 0
var _pending := {}            # id -> time sent
var _record: AudioEffectRecord
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _mic: AudioStreamPlayer
var _bus := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_in = PacketPeerUDP.new()
	if _in.bind(PORT_IN, "127.0.0.1") != OK:
		push_warning("Speech: port %d is taken" % PORT_IN)
	_out = PacketPeerUDP.new()
	_out.set_dest_address("127.0.0.1", PORT_OUT)
	_now = Time.get_ticks_msec() / 1000.0
	_mic_start()


func _exit_tree() -> void:
	if _out != null:
		_out.put_packet(JSON.stringify({"quit": 1} if _pid >= 0 else {"want": 0}).to_utf8_buffer())
	if _pid >= 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	if _mic != null:
		_mic.stop()
	if _bus >= 0 and _bus < AudioServer.bus_count and AudioServer.get_bus_name(_bus) == "SpeechMic":
		AudioServer.remove_bus(_bus)


# ------------------------------------------------------------------ recording
## Starts recording the microphone.
func begin() -> void:
	if _record == null or recording:
		return
	recording = true
	rec_time = 0.0
	_record.set_recording_active(true)


## Stops recording and sends it off. Returns the id that `heard` will carry, or -1 if nothing
## could be sent (then `heard` follows right away with an empty text).
func finish(prompt: String = "") -> int:
	if not recording:
		return -1
	recording = false
	var wav := _record.get_recording()
	_record.set_recording_active(false)
	_next_id += 1
	var id := _next_id
	if wav == null or not is_ready:
		_emit_later(id, "")
		return id
	var path := ProjectSettings.globalize_path("user://speech_%d.wav" % id)
	if wav.save_to_wav(path) != OK:
		_emit_later(id, "")
		return id
	_pending[id] = _now
	_out.put_packet(JSON.stringify({"wav": path, "id": id, "prompt": prompt}).to_utf8_buffer())
	return id


## Throws a recording away.
func cancel() -> void:
	if recording:
		recording = false
		_record.set_recording_active(false)


func _emit_later(id: int, text: String) -> void:
	heard.emit.call_deferred(id, text)


func _mic_start() -> void:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		push_warning("Speech: audio/driver/enable_input is off in project.godot")
	AudioServer.add_bus()
	_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_bus, "SpeechMic")
	_record = AudioEffectRecord.new()
	_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(_bus, _record, 0)
	AudioServer.add_bus_effect(_bus, AudioEffectSpectrumAnalyzer.new(), 1)
	var quiet := AudioEffectAmplify.new()
	quiet.volume_db = -80.0          # analyse and record, but never play the microphone back
	AudioServer.add_bus_effect(_bus, quiet, 2)
	_spectrum = AudioServer.get_bus_effect_instance(_bus, 1) as AudioEffectSpectrumAnalyzerInstance
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "SpeechMic"
	add_child(_mic)
	_mic.play()


# ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var real := minf(now - _now, 0.5)
	_now = now
	if _spectrum != null:
		var m := _spectrum.get_magnitude_for_frequency_range(120.0, 4000.0)
		var db := linear_to_db(maxf(m.length(), 0.00001))
		var raw := clampf(inverse_lerp(LEVEL_DB.x, LEVEL_DB.y, db), 0.0, 1.0)
		level = lerpf(level, raw, 1.0 - exp(-18.0 * delta))
	if recording:
		rec_time += real
	_read()
	var hears := _now - _last_hello < TIMEOUT
	is_ready = hears and _model_state == "ready"
	_beat -= real
	if _beat <= 0.0:
		_beat = HEARTBEAT
		_out.put_packet(JSON.stringify({"want": 1}).to_utf8_buffer())
	if not hears and not failed:
		_wait += real
		_look_after_process()
	else:
		_wait = 0.0
	for id in _pending.keys():
		if _now - float(_pending[id]) > ANSWER_WAIT:
			_pending.erase(id)
			heard.emit(id, "")
	if failed:
		state = "keine Spracherkennung"
	elif not hears:
		state = "startet …"
	elif _model_state == "loading":
		state = "lädt das Sprachmodell …"
	elif _model_state == "error":
		state = "Sprachmodell fehlt"
		failed = true
	else:
		state = "bereit"


func _read() -> void:
	while _in.get_available_packet_count() > 0:
		var d = JSON.parse_string(_in.get_packet().get_string_from_utf8())
		if not (d is Dictionary):
			continue
		if d.has("hello"):
			_last_hello = _now
			_model_state = String(d.get("state", ""))
			_error = String(d.get("error", ""))
		elif d.has("id"):
			var id := int(d["id"])
			if _pending.has(id):
				_pending.erase(id)
				heard.emit(id, String(d.get("text", "")))


# ------------------------------------------------------------------ the Python process
func _look_after_process() -> void:
	if _pid >= 0:
		if OS.is_process_running(_pid):
			return
		if _now - _started_at < GIVE_UP:
			_launch_i += 1   # ended right away: this way of starting it does not work
		_pid = -1
		_wait = 0.0
	elif _wait > START_WAIT:
		_start_process()


func _script_path() -> String:
	var res := ProjectSettings.globalize_path("res://")
	var exe := OS.get_executable_path().get_base_dir()
	for d in [res.path_join("../tracker"), exe.path_join("tracker"), exe.path_join("../../../tracker")]:
		var p: String = (d as String).simplify_path().path_join("speech.py")
		if FileAccess.file_exists(p):
			return p
	return ""


## Ways to start speech.py, best first: [program, arguments]. Same order as the camera tracker.
func _launchers(script: String) -> Array:
	var dir := script.get_base_dir()
	var win := OS.get_name() == "Windows"
	var home := OS.get_environment("USERPROFILE" if win else "HOME")
	var out: Array = []
	for env in ["VISCON_SPEECH_PYTHON", "VISCON_PYTHON"]:
		var own := OS.get_environment(env)
		if own != "":
			out.append([own, [script, "--child"]])
	var venv := dir.path_join(".venv/Scripts/python.exe" if win else ".venv/bin/python")
	if FileAccess.file_exists(venv):
		out.append([venv, [script, "--child"]])
	var uv_args := ["run", "--script", script, "--child"]
	if win:
		out.append([home.path_join(".local/bin/uv.exe"), uv_args])
		out.append(["uv", uv_args])
		out.append(["python", [script, "--child"]])
	else:
		for p in ["/opt/homebrew/bin/uv", "/usr/local/bin/uv", home.path_join(".local/bin/uv"), home.path_join(".cargo/bin/uv")]:
			out.append([p, uv_args])
		for p in ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]:
			out.append([p, [script, "--child"]])
	return out


func _start_process() -> void:
	var script := _script_path()
	if script == "":
		failed = true
		push_warning("Speech: tracker/speech.py not found")
		return
	var ways := _launchers(script)
	while _launch_i < ways.size():
		var exe: String = ways[_launch_i][0]
		if exe.is_absolute_path() and not FileAccess.file_exists(exe):
			_launch_i += 1
			continue
		_pid = OS.create_process(exe, ways[_launch_i][1])
		if _pid >= 0:
			_started_at = _now
			print("Speech: started speech.py with ", exe)
			return
		_launch_i += 1
	failed = true
	push_warning("Speech: could not start speech.py, see tracker/README.md")
