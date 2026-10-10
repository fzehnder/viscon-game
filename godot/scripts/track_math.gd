extends RefCounted
## Turns the raw data of the autoload "Track" into signals a minigame can use directly.
## Everything takes the dictionaries from Track.face(pid) / Track.hand(pid) / Track.pose(pid).
## An empty dictionary (nobody in the picture) always gives the harmless answer.
##
##   const TM = preload("res://scripts/track_math.gd")
##   if TM.eyes_closed(Track.face(pid)): ...
## The numbers below are starting points, tune them in the playtest (res://track_debug.tscn shows them live).

const BLINK_AT := 0.5          # eye counts as closed above this (0 = wide open, 1 = shut)
const PINCH_CLOSED := 0.15     # Track "pinch" when thumb and index finger touch
const PINCH_OPEN := 1.0        # ... and when they are spread wide
const FIST_AT := 1.25          # Track "open" below this is a fist (flat hand is about 2)
const LOOK_AWAY := 0.45        # eyes turned this far (0..1) count as looking away
const HEAD_AWAY := 25.0        # degrees of head turn that count as looking away
const POSE_TOLERANCE := 55.0   # degrees a limb may be off before it scores 0
const POSE_MIN_VIS := 0.5      # body points less visible than this are ignored

# Limbs compared by pose_match: [from, to] in MediaPipe's 33 body points.
# 11/12 shoulders, 13/14 elbows, 15/16 wrists, 23/24 hips, 25/26 knees, 27/28 ankles (odd = the player's left).
const LIMBS := [[11, 13], [13, 15], [12, 14], [14, 16], [11, 12], [11, 23], [12, 24], [23, 25], [25, 27], [24, 26], [26, 28]]


# ------------------------------------------------------------------ face
## Both eyes shut (blinking or keeping them closed).
static func eyes_closed(face: Dictionary) -> bool:
	if face.is_empty():
		return false
	return minf(face["blink_l"], face["blink_r"]) > BLINK_AT


## Not looking at the screen: eyes or head turned away, or no face at all.
static func looking_away(face: Dictionary) -> bool:
	if face.is_empty():
		return true
	if absf(face["yaw"]) > HEAD_AWAY or absf(face["pitch"]) > HEAD_AWAY:
		return true
	return Vector2(face["look_x"], face["look_y"]).length() > LOOK_AWAY


## How far the head has moved since `frozen` (an earlier copy of the face), in centimetres.
## A lost face counts as a lot of movement.
static func moved_cm(face: Dictionary, frozen: Dictionary) -> float:
	if frozen.is_empty():
		return 0.0
	if face.is_empty():
		return 99.0
	var dx: float = (face["x"] - frozen["x"]) * frozen["cm_per_x"]
	var dy: float = (face["y"] - frozen["y"]) * frozen["cm_per_y"]
	return Vector2(dx, dy).length()


# ------------------------------------------------------------------ hand
## Distance between thumb and index finger: 0 = touching, 1 = spread wide.
static func pinch01(hand: Dictionary) -> float:
	if hand.is_empty():
		return 1.0
	return clampf(inverse_lerp(PINCH_CLOSED, PINCH_OPEN, hand["pinch"]), 0.0, 1.0)


static func is_fist(hand: Dictionary) -> bool:
	return not hand.is_empty() and hand["open"] < FIST_AT


## Tip of the index finger as a position inside `rect` (for a hand that works like a mouse pointer).
static func pointer(hand: Dictionary, rect: Rect2) -> Vector2:
	return rect.position + Vector2(hand["x"], hand["y"]) * rect.size


# ------------------------------------------------------------------ body
## How well a pose matches a target pose (both from Track.pose), 0..100. Compares the direction
## of arms, shoulders, torso and legs, so distance to the camera and body size do not matter.
## Limbs that are not visible in the target are left out; not visible in the pose scores 0.
static func pose_match(pose: Dictionary, target: Dictionary, aspect: float = 4.0 / 3.0) -> float:
	if pose.is_empty() or target.is_empty():
		return 0.0
	var a: Array = pose["pts"]
	var b: Array = target["pts"]
	var sum := 0.0
	var n := 0
	for limb in LIMBS:
		var i: int = limb[0]
		var j: int = limb[1]
		if minf(b[i][2], b[j][2]) < POSE_MIN_VIS:
			continue
		n += 1
		if minf(a[i][2], a[j][2]) < POSE_MIN_VIS:
			continue
		var da := Vector2((a[j][0] - a[i][0]) * aspect, a[j][1] - a[i][1])
		var db := Vector2((b[j][0] - b[i][0]) * aspect, b[j][1] - b[i][1])
		var off := absf(rad_to_deg(da.angle_to(db)))
		sum += clampf(1.0 - off / POSE_TOLERANCE, 0.0, 1.0)
	return 100.0 * sum / n if n > 0 else 0.0


# ------------------------------------------------------------------ over time
## Recognises nodding and head shaking. Keep one per player and feed it every frame:
##   var ns := TM.NodShake.new()
##   match ns.push(Track.face(pid), delta): "nod": ...  "shake": ...
class NodShake:
	const SWING := 7.0      # degrees the head has to travel before it turns around
	const WINDOW := 1.6     # seconds in which the turns have to happen
	const TURNS := 3        # down-up-down or left-right-left
	var _t := 0.0
	var _pitch := _Axis.new()
	var _yaw := _Axis.new()

	func push(face: Dictionary, delta: float) -> String:
		_t += delta
		if face.is_empty():
			return ""
		var n := _pitch.add(face["pitch"], _t, SWING, WINDOW)
		var s := _yaw.add(face["yaw"], _t, SWING, WINDOW)
		if maxi(n, s) < TURNS or n == s:
			return ""
		_pitch.clear()
		_yaw.clear()
		return "nod" if n > s else "shake"


## One angle of NodShake: counts how often it turned around recently.
class _Axis:
	var _ext := 0.0         # last extreme
	var _dir := 0           # +1 rising, -1 falling, 0 not moving yet
	var _have := false
	var _turns: Array = []

	func add(v: float, now: float, swing: float, window: float) -> int:
		if not _have:
			_ext = v
			_have = true
		elif _dir != 0 and (v - _ext) * _dir > 0.0:
			_ext = v                         # still going the same way
		elif absf(v - _ext) >= swing:
			_dir = 1 if v > _ext else -1     # went far enough the other way: a turn
			_ext = v
			_turns.append(now)
		while not _turns.is_empty() and now - _turns[0] > window:
			_turns.pop_front()
		return _turns.size()

	func clear() -> void:
		_turns.clear()
		_dir = 0
		_have = false


## How shaky a point is (a hand that trembles), in thousandths of the picture width.
## Smooth movement in one direction does not count, only the wobble around it.
##   var jt := TM.Jitter.new()
##   var shake := jt.push(Vector2(h["palm"][0], h["palm"][1]), delta)
## The measurement wobbles by itself, more so far from the camera: read the value of a calm hand
## in track_debug at playing distance and put the limit clearly above it.
class Jitter:
	const WINDOW := 0.4
	var _t := 0.0
	var _pts: Array = []    # [time, position]

	func push(p: Vector2, delta: float) -> float:
		_t += delta
		# the camera is slower than the game: the same point again is not a new measurement
		if _pts.is_empty() or p != _pts[-1][1]:
			_pts.append([_t, p])
		while not _pts.is_empty() and _t - _pts[0][0] > WINDOW:
			_pts.pop_front()
		if _pts.size() < 3:
			return 0.0
		var sum := 0.0
		for i in range(1, _pts.size() - 1):
			var mid: Vector2 = (_pts[i - 1][1] + _pts[i + 1][1]) / 2.0
			sum += (_pts[i][1] as Vector2).distance_squared_to(mid)
		return sqrt(sum / (_pts.size() - 2)) * 1000.0
