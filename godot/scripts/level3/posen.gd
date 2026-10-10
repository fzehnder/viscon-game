extends RefCounted
## Level 3: the target poses for the dance floor (camera minigame "tanz" in kamera_spiel.gd).
##
## >>> PLATZHALTER <<<
## The poses below are made up from arm directions, nobody has stood in front of a camera for
## them. To use real ones: start `godot --path godot res://track_debug.tscn`, press 3 (body),
## strike the pose, press P, and paste the content of the saved pose_target.json as one entry
## into AUFGENOMMEN, with a name:
##     {"name": "Jubel", "pts": [[0.46, 0.42, 0.99], ...33 points...]}
## As soon as AUFGENOMMEN is not empty, only those poses are used.
## Sitting in front of a laptop the camera only sees the upper body: arms and shoulders only.

const AUFGENOMMEN: Array = []

# Placeholders: name, then the direction of [left upper arm, left forearm, right upper arm,
# right forearm]. "Left" is the dancer's own left arm; in the mirrored camera picture that is
# also the left side. x to the right, y down.
const PLATZHALTER := [
	["Jubel", Vector2(-0.5, -0.87), Vector2(-0.5, -0.87), Vector2(0.5, -0.87), Vector2(0.5, -0.87)],   # both arms up in a V
	["Flieger", Vector2(-1.0, 0.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.0)],          # both arms straight out
	["Disco", Vector2(-0.6, 0.8), Vector2(-0.6, 0.8), Vector2(0.6, -0.8), Vector2(0.6, -0.8)],          # left arm down and out, right arm up
	["Kaktus", Vector2(-1.0, 0.0), Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],          # upper arms out, forearms up
]
const ASPECT := 4.0 / 3.0
const SHOULDER := 0.085      # half the shoulder width, in picture widths
const UPPER := 0.15          # length of the upper arm, in picture heights
const FORE := 0.14


## All target poses: [{"name": String, "pts": 33 x [x, y, visibility]}, ...] as from Track.pose().
static func alle() -> Array:
	if not AUFGENOMMEN.is_empty():
		return AUFGENOMMEN
	var out: Array = []
	for p in PLATZHALTER:
		var pts: Array = []
		for i in 33:
			pts.append([0.5, 0.5, 0.0])   # not visible: left out when poses are compared
		var ls := Vector2(0.5 - SHOULDER, 0.42)
		var rs := Vector2(0.5 + SHOULDER, 0.42)
		var le := ls + _step(p[1], UPPER)
		var re := rs + _step(p[3], UPPER)
		var set_pt := func(i: int, v: Vector2): pts[i] = [v.x, v.y, 1.0]
		set_pt.call(11, ls)
		set_pt.call(12, rs)
		set_pt.call(13, le)
		set_pt.call(14, re)
		set_pt.call(15, le + _step(p[2], FORE))
		set_pt.call(16, re + _step(p[4], FORE))
		out.append({"name": p[0], "pts": pts})
	return out


static func _step(dir: Vector2, length: float) -> Vector2:
	var d := dir.normalized() * length
	return Vector2(d.x / ASPECT, d.y)
