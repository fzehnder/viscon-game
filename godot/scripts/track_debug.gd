extends Control
## Test screen for the autoload "Track": camera picture with everything that is recognised, and
## every signal from track_math.gd live. Not part of the game.
##   godot --path godot res://track_debug.tscn      (or open the scene in the editor and press F6)
## Keys: 1 face · 2 hands · 3 body · M microphone · F freeze the heads (movement in cm)
##       P save the body pose in the middle as target (user://pose_target.json) · Esc quit

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const TM = preload("res://scripts/track_math.gd")
const PIC := Rect2(30, 96, 520, 390)
const COL_X := [580.0, 930.0]
const TARGET_FILE := "user://pose_target.json"

var on := {"face": true, "hand": true, "pose": false}
var mic := false
var nods: Array = [TM.NodShake.new(), TM.NodShake.new()]
var jitters: Array = [TM.Jitter.new(), TM.Jitter.new()]
var shake: Array = [0.0, 0.0]
var gesture: Array = ["", ""]
var gesture_t: Array = [0.0, 0.0]
var frozen: Array = [{}, {}]
var target := {}
var note := ""


func _ready() -> void:
	if FileAccess.file_exists(TARGET_FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(TARGET_FILE))
		if d is Dictionary:
			target = d
	_apply()


func _apply() -> void:
	var kinds: Array = []
	for k in on:
		if on[k]:
			kinds.append(k)
	Track.use(self, kinds)


func _process(delta: float) -> void:
	for pid in 2:
		var g: String = nods[pid].push(Track.face(pid), delta)
		if g != "":
			gesture[pid] = "Nicken" if g == "nod" else "Kopfschütteln"
			gesture_t[pid] = 1.5
		gesture_t[pid] = maxf(0.0, gesture_t[pid] - delta)
		var h := Track.hand(pid)
		if not h.is_empty():
			shake[pid] = jitters[pid].push(Vector2(h["palm"][0], h["palm"][1]), delta)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1:
			on["face"] = not on["face"]
			_apply()
		KEY_2:
			on["hand"] = not on["hand"]
			_apply()
		KEY_3:
			on["pose"] = not on["pose"]
			_apply()
		KEY_M:
			mic = not mic
			if mic:
				Track.use_mic(self)
			else:
				Track.release(self)
				_apply()
		KEY_F:
			for pid in 2:
				frozen[pid] = Track.face(pid).duplicate()
			note = "Köpfe eingefroren. Wer sich bewegt, sieht es in cm."
		KEY_P:
			var p := Track.pose(-1)
			if p.is_empty():
				note = "Keine Pose im Bild (Taste 3 schaltet den Körper ein)."
			else:
				target = p.duplicate(true)
				var f := FileAccess.open(TARGET_FILE, FileAccess.WRITE)
				f.store_string(JSON.stringify(target))
				note = "Zielpose gespeichert: %s" % ProjectSettings.globalize_path(TARGET_FILE)
		KEY_ESCAPE:
			get_tree().quit()


# ------------------------------------------------------------------ drawing
func _at(x: float, y: float) -> Vector2:
	return PIC.position + Vector2(x, y) * PIC.size


func _text(pos: Vector2, s: String, size: int = 16, c: Color = UI.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _bar(pos: Vector2, v: float, c: Color, label: String) -> void:
	draw_rect(Rect2(pos, Vector2(120, 12)), UI.NAVY2)
	draw_rect(Rect2(pos, Vector2(120.0 * clampf(v, 0.0, 1.0), 12)), c)
	_text(pos + Vector2(130, 11), label, 14, UI.MUTED)


func _draw() -> void:
	_text(Vector2(30, 44), "Tracking-Test", 30, UI.YELLOW)
	var flags := "[1] Gesicht %s   [2] Hand %s   [3] Körper %s   [M] Mikrofon %s   [F] einfrieren   [P] Zielpose   [Esc]" % [
		_onoff(on["face"]), _onoff(on["hand"]), _onoff(on["pose"]), _onoff(mic)]
	_text(Vector2(30, 76), "Tracker: %s · %.0f Bilder/s      %s" % [Track.status, Track.fps, flags], 15, UI.MUTED)

	draw_rect(PIC, UI.DARK)
	if Track.preview.get_width() > 0:
		draw_texture_rect(Track.preview, PIC, false)
	else:
		_text(PIC.position + Vector2(20, 40), Track.status, 20, UI.MUTED)
	draw_line(_at(0.5, 0.0), _at(0.5, 1.0), Color(1, 1, 1, 0.25), 1.0)
	_text(_at(0.0, 1.0) + Vector2(8, -10), "P1", 18, Color(KEYS.TAG_COLORS[0]))
	_text(_at(1.0, 1.0) + Vector2(-34, -10), "P2", 18, Color(KEYS.TAG_COLORS[1]))

	for f in Track.faces:
		var c := _color_at(f["x"])
		var b: Array = f["box"]
		draw_rect(Rect2(_at(b[0], b[1]), Vector2(b[2], b[3]) * PIC.size), c, false, 2.0)
		for e in f["eyes"]:
			draw_circle(_at(e[0], e[1]), 3.0, c)
	for h in Track.hands:
		var c := _color_at(h["x"])
		var pts: Array = h["pts"]
		for p in pts:
			draw_circle(_at(p[0], p[1]), 3.0, c)
		draw_line(_at(pts[4][0], pts[4][1]), _at(pts[8][0], pts[8][1]), UI.YELLOW, 2.0)
	for p in Track.poses:
		_draw_pose(p, _color_at(p["x"]), 3.0)
	if not target.is_empty() and on["pose"]:
		_draw_pose(target, Color(1, 1, 1, 0.45), 6.0)

	for pid in 2:
		_draw_player(pid)
	var y := PIC.end.y + 34.0
	_bar(Vector2(30, y - 11), Track.blow, UI.GREEN if Track.blowing else UI.BLUE,
		"Pusten %.2f%s   tief %.0f dB · Stimme %.0f dB%s" % [Track.blow, "  PUSTET" if Track.blowing else "",
		Track.blow_db, Track.voice_db, "" if mic else "   (M schaltet das Mikrofon ein)"])
	_text(Vector2(30, y + 30), note, 15, UI.YELLOW)


func _draw_pose(p: Dictionary, c: Color, width: float) -> void:
	var pts: Array = p["pts"]
	for limb in TM.LIMBS:
		var a: Array = pts[limb[0]]
		var b: Array = pts[limb[1]]
		if minf(a[2], b[2]) >= TM.POSE_MIN_VIS:
			draw_line(_at(a[0], a[1]), _at(b[0], b[1]), c, width)


func _draw_player(pid: int) -> void:
	var c := Color(KEYS.TAG_COLORS[pid])
	var x: float = COL_X[pid]
	var y := 116.0
	_text(Vector2(x, y), "%s (%s Bildhälfte)" % [KEYS.TAGS[pid], "linke" if pid == 0 else "rechte"], 20, c)
	var f := Track.face(pid)
	y += 34.0
	if f.is_empty():
		_text(Vector2(x, y), "kein Gesicht", 15, UI.MUTED)
		y += 130.0
	else:
		_text(Vector2(x, y), "Kopf: dreh %+.0f°  nick %+.0f°  neig %+.0f°" % [f["yaw"], f["pitch"], f["roll"]], 14)
		_bar(Vector2(x, y + 14), f["blink_l"], UI.PINK, "linkes Auge zu %.2f" % f["blink_l"])
		_bar(Vector2(x, y + 32), f["blink_r"], UI.PINK, "rechtes Auge zu %.2f" % f["blink_r"])
		_text(Vector2(x, y + 66), "Blick %+.2f / %+.2f   Mund %.2f" % [f["look_x"], f["look_y"], f["mouth"]], 14)
		_text(Vector2(x, y + 88), "Bewegt seit [F]: %.1f cm" % TM.moved_cm(f, frozen[pid]), 14,
			UI.RED if TM.moved_cm(f, frozen[pid]) > 2.0 else UI.WHITE)
		var flags := ("AUGEN ZU  " if TM.eyes_closed(f) else "") + ("SCHAUT WEG  " if TM.looking_away(f) else "")
		_text(Vector2(x, y + 112), flags + (gesture[pid] if gesture_t[pid] > 0.0 else ""), 18, UI.GREEN)
		y += 130.0
	var h := Track.hand(pid)
	if h.is_empty():
		_text(Vector2(x, y), "keine Hand", 15, UI.MUTED)
	else:
		_bar(Vector2(x, y - 11), TM.pinch01(h), UI.YELLOW, "Pinch %.2f" % TM.pinch01(h))
		_text(Vector2(x, y + 24), "Hand %s   %s   Zittern %.1f" % [h["side"], "FAUST" if TM.is_fist(h) else "offen", shake[pid]], 14)
	y += 56.0
	var p := Track.pose(pid)
	if p.is_empty():
		_text(Vector2(x, y), "kein Körper", 15, UI.MUTED)
	elif target.is_empty():
		_text(Vector2(x, y), "Körper erkannt · [P] = Zielpose", 14)
	else:
		var m := TM.pose_match(p, target, Track.aspect)
		_bar(Vector2(x, y - 11), m / 100.0, UI.GREEN if m > 80.0 else UI.ORANGE, "Pose %.0f %%" % m)


func _onoff(b: bool) -> String:
	return "an" if b else "aus"


func _color_at(x: float) -> Color:
	return Color(KEYS.TAG_COLORS[0 if x < 0.5 else 1])
