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
##
## What fits into the picture: the camera of a laptop is close. Arms hanging down leave the
## picture at the bottom, arms stretched out or leaning sideways leave it at the sides or get in
## the way of the neighbour, because two people share the width. So all poses keep the arms up
## and above the dancer's own shoulders. When you record your own, check in track_debug that
## elbows and wrists stay in the picture, with two people standing next to each other.

const AUFGENOMMEN: Array = []

# Placeholders: name, then the direction of [left upper arm, left forearm, right upper arm,
# right forearm]. "Left" is the dancer's own left arm; in the mirrored camera picture that is
# also the left side. x to the right, y down. The first one is also the "ready" pose.
const PLATZHALTER := [
	["Hände hoch", Vector2(-0.12, -1.0), Vector2(0.0, -1.0), Vector2(0.12, -1.0), Vector2(0.0, -1.0)],       # both arms straight up
	["Dach", Vector2(-0.5, -0.87), Vector2(0.75, -0.66), Vector2(0.5, -0.87), Vector2(-0.75, -0.66)],        # hands meet above the head
	["Disco links", Vector2(-0.12, -1.0), Vector2(0.0, -1.0), Vector2(0.5, -0.87), Vector2(-0.75, -0.66)],   # left arm straight up, right hand to the head
	["Disco rechts", Vector2(-0.5, -0.87), Vector2(0.75, -0.66), Vector2(0.12, -1.0), Vector2(0.0, -1.0)],   # right arm straight up, left hand to the head
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
		out.append(_bauen(p))
	return out


## "Hands up": the pose that starts the dance. Whoever can strike it has their arms in the picture.
static func bereit() -> Dictionary:
	return _bauen(PLATZHALTER[0])


## The pose the dance begins with (not the ready pose again, the dancers are still standing in it).
static func erste() -> int:
	return 0 if not AUFGENOMMEN.is_empty() else 1


static func _bauen(p: Array) -> Dictionary:
	var pts: Array = []
	for i in 33:
		pts.append([0.5, 0.5, 0.0])   # not visible: left out when poses are compared
	var ls := Vector2(0.5 - SHOULDER, 0.62)
	var rs := Vector2(0.5 + SHOULDER, 0.62)
	var le := ls + _step(p[1], UPPER)
	var re := rs + _step(p[3], UPPER)
	var set_pt := func(i: int, v: Vector2): pts[i] = [v.x, v.y, 1.0]
	set_pt.call(11, ls)
	set_pt.call(12, rs)
	set_pt.call(13, le)
	set_pt.call(14, re)
	set_pt.call(15, le + _step(p[2], FORE))
	set_pt.call(16, re + _step(p[4], FORE))
	return {"name": p[0], "pts": pts}


static func _step(dir: Vector2, length: float) -> Vector2:
	var d := dir.normalized() * length
	return Vector2(d.x / ASPECT, d.y)
