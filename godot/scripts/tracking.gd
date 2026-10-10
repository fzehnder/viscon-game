extends Node
## Autoload "Track": webcam tracking (faces, hands, body poses) and blowing into the microphone.
## The camera part runs in a second process (tracker/tracker.py, MediaPipe) that sends its results
## over UDP on localhost. Nothing is started and nothing costs time until someone calls use()
## or use_mic(). Whoever asked is released by itself when it leaves the tree (minigame closed).
##
##   Track.use(self, ["face"])          # "face", "hand", "pose", any mix
##   var f := Track.face(pid)            # {} while there is no face in that player's half
##   if not Track.alive: ...             # no tracker or no camera: offer the keyboard variant
##   Track.use_mic(self)                 # then Track.blow is 0..1 and Track.blowing true/false
##
## Positions are 0..1 in the mirrored camera picture (x = 0 left, y = 0 top), the same picture
## as Track.preview. Lists are sorted from left to right; P1 sits left, P2 right.
## What every entry contains and one example per planned minigame: tracker/README.md

const PORT_IN := 47800        # tracker -> game
const PORT_CMD := 47801       # game -> tracker
const HEARTBEAT := 0.5        # how often the game tells the tracker what it wants
const TIMEOUT := 1.5          # no packet for this long: the tracker counts as gone
const START_WAIT := 1.2       # wait this long for a tracker that is already running, then start one
const GIVE_UP := 8.0          # a started tracker that dies within this time did not work: try the next way
const KINDS := ["face", "hand", "pose"]

# Blowing is loud noise in the low frequencies; a voice has more in the middle.
const BLOW_BAND := Vector2(40.0, 250.0)      # Hz, the wind noise
const VOICE_BAND := Vector2(400.0, 3000.0)   # Hz, to tell blowing from talking
const BLOW_DB_MIN := -45.0                    # this loud counts as 0 (a quiet room is around -50 to -70)
const BLOW_DB_MAX := -15.0                    # this loud counts as 1
const BLOW_OVER_VOICE := 6.0                  # the low band has to be this many dB above the voice band
const BLOW_ON := 0.35                         # blowing starts above this ...
const BLOW_OFF := 0.2                         # ... and ends below this
const BLOW_SMOOTH := 14.0

var alive := false             # the tracker is sending results from a camera picture
var status := "aus"            # short German text for the UI
var fps := 0.0
var aspect := 4.0 / 3.0        # width / height of the camera picture
var faces: Array = []
var hands: Array = []
var poses: Array = []
var preview: ImageTexture      # mirrored camera picture, always the same object

var mic_ok := false            # the microphone delivers something
var blow := 0.0                # 0..1
var blowing := false
var blow_db := -80.0           # raw levels, for tuning (see track_debug)
var voice_db := -80.0

var _users := {}               # instance id -> {"kinds": Array, "preview": bool}
var _mic_users := {}           # instance id -> true
var _hooked := {}              # instance ids whose tree_exited is connected
var _in: PacketPeerUDP
var _out: PacketPeerUDP
var _now := 0.0
var _last_packet := -100.0     # anything from the tracker
var _last_data := -100.0       # results from a camera picture
var _cam_error := false
var _beat := 0.0
var _wait := 0.0
var _pid := -1
var _started_at := 0.0
var _launch_i := 0
var _no_launcher := false
var _mic_player: AudioStreamPlayer
var _spectrum: AudioEffectSpectrumAnalyzerInstance


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preview = ImageTexture.new()
	set_process(false)


# ------------------------------------------------------------------ for minigames
## Ask for tracking of these kinds as long as `who` is in the tree.
func use(who: Node, kinds: Array, with_preview: bool = true) -> void:
	_users[_hook(who)] = {"kinds": kinds.duplicate(), "preview": with_preview}
	_wake()


## Ask for the microphone as long as `who` is in the tree.
func use_mic(who: Node) -> void:
	_mic_users[_hook(who)] = true
	_mic_start()
	_wake()


## Give everything back early. Not needed when `who` is freed anyway.
func release(who: Node) -> void:
	_forget(who.get_instance_id())


## The face in player pid's half of the picture, or {}. pid -1: the one closest to the middle.
func face(pid: int = -1) -> Dictionary:
	return _pick(faces, pid)


func hand(pid: int = -1) -> Dictionary:
	return _pick(hands, pid)


func pose(pid: int = -1) -> Dictionary:
	return _pick(poses, pid)


func _pick(list: Array, pid: int) -> Dictionary:
	var best := {}
	var best_d := INF
	var want_x := 0.5 if pid < 0 else (0.25 if pid == 0 else 0.75)
	for e in list:
		var x: float = e["x"]
		if pid >= 0 and (pid == 0) != (x < 0.5):
			continue
		var d := absf(x - want_x)
		if d < best_d:
			best_d = d
			best = e
	return best


# ------------------------------------------------------------------ who uses it
func _hook(who: Node) -> int:
	var id := who.get_instance_id()
	if not _hooked.has(id):
		_hooked[id] = true
		who.tree_exited.connect(_on_user_gone.bind(id), CONNECT_ONE_SHOT)
	return id


func _on_user_gone(id: int) -> void:
	_hooked.erase(id)
	_forget(id)


func _forget(id: int) -> void:
	_users.erase(id)
	_mic_users.erase(id)
	if _users.is_empty():
		faces = []
		hands = []
		poses = []
		_send_want()
	if _mic_users.is_empty() and _mic_player != null and _mic_player.playing:
		_mic_player.stop()
		blow = 0.0
		blowing = false


func _wake() -> void:
	if _in == null:
		_in = PacketPeerUDP.new()
		if _in.bind(PORT_IN, "127.0.0.1") != OK:
			push_warning("Track: port %d is taken, is the game running twice?" % PORT_IN)
		_out = PacketPeerUDP.new()
		_out.set_dest_address("127.0.0.1", PORT_CMD)
	_beat = 0.0
	_now = Time.get_ticks_msec() / 1000.0
	set_process(true)


# ------------------------------------------------------------------ every frame (only after the first use)
func _process(delta: float) -> void:
	# network timing in real seconds: delta follows Engine.time_scale and --fixed-fps
	var now := Time.get_ticks_msec() / 1000.0
	var real := minf(now - _now, 0.5)
	_now = now
	_read_packets()
	var hears := _now - _last_packet < TIMEOUT
	alive = _now - _last_data < TIMEOUT and not _users.is_empty()
	# keep telling the tracker what is wanted; an empty list keeps it running with the camera off
	_beat -= real
	if _beat <= 0.0:
		_beat = HEARTBEAT
		_send_want()
	if not _users.is_empty() and not hears:
		_wait += real
		_look_after_tracker()
	else:
		_wait = 0.0
	if not alive:
		faces = []
		hands = []
		poses = []
	_update_mic(delta)
	_update_status(hears)


func _read_packets() -> void:
	while _in.get_available_packet_count() > 0:
		var pkt := _in.get_packet()
		if pkt.size() < 2:
			continue
		_last_packet = _now
		if pkt[0] == 0x4A:      # "J": JSON
			var d = JSON.parse_string(pkt.slice(1).get_string_from_utf8())
			if d is Dictionary:
				_apply(d)
		elif pkt[0] == 0x50:    # "P": JPEG of the mirrored camera picture
			var img := Image.new()
			if img.load_jpg_from_buffer(pkt.slice(1)) == OK:
				if preview.get_size() == Vector2(img.get_size()):
					preview.update(img)
				else:
					preview.set_image(img)


func _apply(d: Dictionary) -> void:
	_cam_error = d.has("error")
	if d.has("hello") or _cam_error or _users.is_empty():
		return
	_last_data = _now
	fps = float(d.get("fps", 0.0))
	aspect = float(d.get("aspect", aspect))
	faces = d.get("faces", [])
	hands = d.get("hands", [])
	poses = d.get("poses", [])


func _send_want() -> void:
	if _out == null:
		return
	var kinds: Array = []
	var with_preview := false
	for u in _users.values():
		with_preview = with_preview or u["preview"]
		for k in u["kinds"]:
			if KINDS.has(k) and not kinds.has(k):
				kinds.append(k)
	_out.put_packet(JSON.stringify({"want": kinds, "preview": with_preview}).to_utf8_buffer())


func _update_status(hears: bool) -> void:
	if _users.is_empty():
		status = "bereit" if hears else "aus"
	elif alive:
		status = "läuft"
	elif hears and _cam_error:
		status = "keine Kamera (Zugriff erlaubt?)"
	elif _no_launcher:
		status = "kein Tracker (siehe tracker/README.md)"
	else:
		status = "Kamera startet …"


# ------------------------------------------------------------------ the tracker process
func _look_after_tracker() -> void:
	if _pid >= 0:
		if OS.is_process_running(_pid):
			return
		# it ended by itself: right after the start means this way of starting it does not work
		if _now - _started_at < GIVE_UP:
			_launch_i += 1
		_pid = -1
		_wait = 0.0
	elif _wait > START_WAIT and not _no_launcher:
		_start_tracker()


func _tracker_dir() -> String:
	var res := ProjectSettings.globalize_path("res://")
	var exe := OS.get_executable_path().get_base_dir()
	# editor or `godot --path godot`: the folder next to godot/. Exported: next to the game or its .app.
	for d in [res.path_join("../tracker"), exe.path_join("tracker"), exe.path_join("../../../tracker")]:
		var p: String = d.simplify_path()
		if FileAccess.file_exists(p.path_join("tracker.py")):
			return p
	return ""


## Ways to start the tracker, best first: [program, arguments].
func _launchers(dir: String) -> Array:
	var script := dir.path_join("tracker.py")
	var win := OS.get_name() == "Windows"
	var home := OS.get_environment("USERPROFILE" if win else "HOME")
	var out: Array = []
	var own := OS.get_environment("VISCON_PYTHON")      # e.g. a Python that has mediapipe installed
	if own != "":
		out.append([own, [script, "--child"]])
	var venv := dir.path_join(".venv/Scripts/python.exe" if win else ".venv/bin/python")
	if FileAccess.file_exists(venv):
		out.append([venv, [script, "--child"]])
	# uv installs Python, MediaPipe and everything else by itself on the first run
	var uv_args := ["run", "--script", script, "--child"]
	if win:
		out.append([home.path_join(".local/bin/uv.exe"), uv_args])
		out.append(["uv", uv_args])
		out.append(["python", [script, "--child"]])
	else:
		# programs started from the Finder do not have Homebrew in their PATH: look in the usual places
		for p in ["/opt/homebrew/bin/uv", "/usr/local/bin/uv", home.path_join(".local/bin/uv"), home.path_join(".cargo/bin/uv")]:
			out.append([p, uv_args])
		for p in ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]:
			out.append([p, [script, "--child"]])
	return out


func _start_tracker() -> void:
	var dir := _tracker_dir()
	if dir == "":
		_no_launcher = true
		push_warning("Track: tracker/tracker.py not found")
		return
	var ways := _launchers(dir)
	while _launch_i < ways.size():
		var exe: String = ways[_launch_i][0]
		if exe.is_absolute_path() and not FileAccess.file_exists(exe):
			_launch_i += 1
			continue
		_pid = OS.create_process(exe, ways[_launch_i][1])
		if _pid >= 0:
			_started_at = _now
			print("Track: started the tracker with ", exe)
			return
		_launch_i += 1
	_no_launcher = true
	push_warning("Track: could not start the tracker, see tracker/README.md")


func _exit_tree() -> void:
	if _out == null:
		return
	# a tracker somebody started by hand keeps running, it only lets go of the camera
	var ours := _pid >= 0
	_out.put_packet(JSON.stringify({"quit": 1} if ours else {"want": []}).to_utf8_buffer())
	if ours and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1


# ------------------------------------------------------------------ microphone
func _mic_start() -> void:
	if _mic_player == null:
		if not ProjectSettings.get_setting("audio/driver/enable_input", false):
			push_warning("Track: audio/driver/enable_input is off in project.godot, the microphone stays silent")
		# own bus: analyse first, then turn it down so the microphone is never heard
		AudioServer.add_bus()
		var bus := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "TrackMic")
		AudioServer.add_bus_effect(bus, AudioEffectSpectrumAnalyzer.new(), 0)
		var quiet := AudioEffectAmplify.new()
		quiet.volume_db = -80.0
		AudioServer.add_bus_effect(bus, quiet, 1)
		_spectrum = AudioServer.get_bus_effect_instance(bus, 0) as AudioEffectSpectrumAnalyzerInstance
		_mic_player = AudioStreamPlayer.new()
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.bus = "TrackMic"
		add_child(_mic_player)
	if not _mic_player.playing:
		_mic_player.play()


func _band_db(band: Vector2) -> float:
	var m := _spectrum.get_magnitude_for_frequency_range(band.x, band.y)
	return linear_to_db(maxf(m.length(), 0.0001))


func _update_mic(delta: float) -> void:
	if _mic_users.is_empty() or _spectrum == null:
		return
	blow_db = _band_db(BLOW_BAND)
	voice_db = _band_db(VOICE_BAND)
	if blow_db > -79.0:
		mic_ok = true
	var raw := clampf(inverse_lerp(BLOW_DB_MIN, BLOW_DB_MAX, blow_db), 0.0, 1.0)
	if blow_db - voice_db < BLOW_OVER_VOICE:
		raw = 0.0      # talking, music, clapping: not mostly low noise
	blow = lerpf(blow, raw, 1.0 - exp(-BLOW_SMOOTH * delta))
	blowing = blow > (BLOW_OFF if blowing else BLOW_ON)
