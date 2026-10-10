extends CanvasLayer
## Level 3: the two minigames that are played in front of the webcam (autoload Track).
##   "tanz"   strike the dance pose that is shown, on the beat (body pose). Whoever puts the
##            hands up at the start dances: one person for both players, or two, and then both
##            have to hit. Everybody else in the picture is an onlooker and does not count.
##   "badge"  one player pulls the badge out of the coat with two fingers and a steady hand
## Same contract as minigame.gd, so that main.gd treats it like any minigame: the signals
## `finished(success, mistakes)` and `mistake`, the counter `mistakes`, and it sits in main.minis
## while it is open (see _open_cam in level.gd).
## While it runs, the screen (or the player's half) is bright: in the story that is the spotlight,
## in a dark room it is the lamp without which the camera finds nobody.
## No camera, no tracker or nobody in the picture for CAM_WAIT seconds: "tanz" goes on with the
## keys, "badge" emits `fallback` and the level opens the sequence minigame instead. The interact
## key does the same at any time.
##
## The camera of a laptop is close: sitting at the keyboard only head and shoulders are in the
## picture. So the dance starts with "hands up": whoever can strike that has moved back far
## enough for the arms to be seen, and all poses keep the arms up.
##
## What the camera recognises is restless: points tremble, people are lost for single frames,
## and with several people around the laptop it reports now these, now those. Nothing of that
## is shown or scored raw. Every body in the picture is followed from frame to frame by where it
## is (class Followed), smoothed over time and kept for a moment when it is lost. Who dances is
## decided once, by the hands-up, and which hand plays only changes for a good reason.

signal finished(success: bool, mistakes: int)
signal mistake
signal fallback

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const TM = preload("res://scripts/track_math.gd")
const Posen = preload("res://scripts/level3/posen.gd")
const Fund = preload("res://scripts/level3/fund.gd")

# ---- tuning
const CAM_WAIT := 5.0            # seconds without a result from the camera until the keys take over
const CAM_PATIENCE := 3.0        # ... times this if the camera works but nobody is in the picture
const LIGHT := Color(1.0, 0.98, 0.93)   # the spotlight: the whole screen, nothing shines through
# how calm the display is
const SMOOTH := 0.08             # seconds over which recognised points are smoothed (smaller = quicker but shakier)
const HOLD := 0.5                # seconds somebody the camera lost for a moment stays where they were
const BAR_SMOOTH := 0.12         # seconds over which the percent bars follow
const SHOW_VIS := 0.3            # body points the camera is less sure of than this are not drawn
# tanz
const POSE_OK := 50.0            # percent the arms have to match the pose (see _arms). Measured in front of a
                                 # laptop camera: a pose struck well gives 50 to 65, another pose under 40
const OK_SLACK := 6.0            # a pose that sits keeps sitting until it falls this far under POSE_OK: somebody
                                 # holding a pose wobbles by a few percent, and the bar must not flicker for that
const READY_OK := 42.0           # percent for the "hands up" that starts the dance
const ARM_TOLERANCE := 70.0      # degrees an upper arm or forearm may be off before it scores 0
const READY_HOLD := 0.5          # seconds the hands have to stay up
const JOIN := 1.5                # seconds after the first "hands up" in which a second dancer can still join
const PAIR_MEMORY := 6.0         # seconds one of two dancers can be gone (costs a beat) before the other one dances for both
const REACQUIRE := 3.0           # seconds the only dancer can be gone before whoever is closest to the camera takes over
const BEAT := 3.4                # seconds per pose
const BEAT_WINDOW := 1.4         # the last seconds of a beat, in which the pose has to sit
const DANCE_HITS := 4            # poses that have to be hit to get across the floor
# badge
const PINCH_GRAB := 0.3          # fingers closer than this (TM.pinch01) hold the badge
const PINCH_DROP := 0.6          # fingers further apart than this let go of it
const PULL := 0.16               # how far the hand has to go up, in picture heights
const JITTER_MAX := 12.0         # a hand shakier than this (TM.Jitter) ...
const JITTER_TIME := 0.35        # ... for this long makes the coat rustle: mistake, start again
const HAND_LOST := 0.8           # seconds without a hand in the picture until the badge slips back
const HAND_REACH := 0.22         # a hand further away than this from the one that plays is another hand
# who is who in the picture
const SAME_PERSON := 0.13        # a body further away than this (in picture widths) from where one was is somebody else
const REJOIN := 0.3              # ... and this far for somebody the camera had lost for a while: they may have moved on
const SAME_BODY := 0.05          # two bodies closer together than this are one person the camera reports twice
const KEEP_VIS := 0.3            # somebody who is followed stays followed down to this sureness of the shoulders
                                 # (somebody new needs TM.POSE_MIN_VIS), so nobody at the edge flickers in and out
const MAX_BODIES := 6

const INK := Color("23264a")
const SOFT := Color(0.14, 0.15, 0.29, 0.35)
const MUTED := Color(0.14, 0.15, 0.29, 0.62)
const BOTH := Color("d99a00")    # one dancer for both players
const DIR_NAMES := ["up", "down", "left", "right"]
const DIR_VECS := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]

var kind := ""
var pid := -1                    # the player ("badge"), -1 = both ("tanz")
var screen_side := -1            # for one player: the half it is on (0 left, 1 right). Set by the level before it
                                 # opens; main turns the split so that this half is the player's (main._pick_force_flip)
var mistakes := 0
var keys: Dictionary = {}        # of P1, or of the one player
var keys2: Dictionary = {}       # of P2 ("tanz")
var labels: Dictionary = {}
var labels2: Dictionary = {}
var accent := Color("ffc93c")
var t := 0.0
var closing := -1.0
var state := "warm"              # warm (waiting for the camera), ready ("hands up"), play, done
var no_cam := 0.0                # seconds without a result from the camera
var use_keys := false
var flash := 0.0
var flash_ok := true
var root: Control
var canvas: Control
var info: Label
# tanz
var poses: Array = []
var ready_pose: Dictionary = {}
var round_i := 0
var beat_t := 0.0
var hits := 0
var hit_now := false
var pressed: Array = [false, false]
var match_pc: Array = [0.0, 0.0]
var shown_pc: Array = [0.0, 0.0] # what the bars show and what counts: match_pc, following softly
var sits: Array = [false, false] # the pose sits (bar green): over POSE_OK, and not yet OK_SLACK under it again
var bodies: Array = []           # everybody the camera follows right now (Followed)
var team: Array = []             # the dancers among them: one (dances for both) or two (P1 left, P2 right)
var dancers: Array = [{}, {}]    # the poses of P1 and P2, smoothed ({} = not in the picture for a while)
var solo := true                 # one person dances for both (false: two dancers, both have to hit)
var join_t := 0.0                # running since the first one had the hands up
# badge
var holding := false
var armed := true                # false after the coat rustled: open the fingers before grabbing again
var hand: Dictionary = {}        # the hand that is playing, as the camera sees it this frame ({} = none)
var hand_show := Followed.new()  # the same hand, smoothed, for the display
var hand_age := 99.0             # seconds since that hand was seen
var palm := Vector2.ZERO
var y0 := 0.0
var progress := 0.0
var shaky_t := 0.0
var shake := 0.0
var lost_t := 0.0
var jitter = null


## Somebody (or a hand) the camera follows. The points are smoothed over time. When the camera
## loses them for a moment they stay where they were, then fade out; somebody new fades in. So
## nothing pops in and out, and what the camera sees for a single frame only is never shown.
class Followed:
	const FADE_IN := 0.2         # seconds until somebody new is fully drawn
	var pts: Array = []          # like "pts" of a pose or hand from Track
	var x := 0.5
	var age := 99.0              # seconds since the camera last saw them
	var shown := 0.0             # 0..1: rises while the camera sees them, falls towards the end of the hold
	var mid := Vector2(0.5, 0.5) # bodies: middle between the shoulders as last seen (not smoothed), to tell who is who
	var size := 0.0              # bodies: shoulder width in the picture (bigger = closer to the camera)
	var ready_t := 0.0           # bodies: how long the hands have been up
	var score := 0.0
	var matched := false

	func feed(seen: Dictionary, delta: float, smooth: float, hold: float) -> void:
		if seen.is_empty():
			age += delta
			shown = minf(shown, clampf((hold - age) / (hold * 0.6), 0.0, 1.0))   # solid at first, gone when the hold is over
			return
		var src: Array = seen["pts"]
		if pts.size() != src.size() or age > hold:
			pts = src.duplicate(true)       # new, or back after a while: no gliding in from the old place
			x = seen["x"]
			shown = 0.0
		else:
			var k := 1.0 - exp(-(delta + age) / maxf(smooth, 0.001))
			for i in src.size():
				for c in (src[i] as Array).size():
					pts[i][c] = lerpf(pts[i][c], src[i][c], k)
			x = lerpf(x, seen["x"], k)
		age = 0.0
		shown = minf(1.0, shown + delta / FADE_IN)
		if pts.size() == 33:
			mid = Vector2((src[11][0] + src[12][0]) / 2.0, (src[11][1] + src[12][1]) / 2.0)
			size = Vector2(pts[11][0] - pts[12][0], pts[11][1] - pts[12][1]).length()

	func there(hold: float) -> bool:
		return not pts.is_empty() and age <= hold

	func pose(hold: float) -> Dictionary:
		return {"x": x, "pts": pts} if there(hold) else {}

	## How strongly to draw it, 0..1. Nothing at all for the first moment: a body the camera
	## reports for one frame only (a coat on a chair, a poster) never shows up.
	func alpha() -> float:
		return smoothstep(0.3, 1.0, shown)

	## Bodies: the middle between the shoulders, smoothed like the rest that is drawn.
	func chest() -> Vector2:
		return Vector2((pts[11][0] + pts[12][0]) / 2.0, (pts[11][1] + pts[12][1]) / 2.0)

	func clear() -> void:
		pts = []
		age = 99.0
		shown = 0.0


func open(k: String) -> void:
	kind = k
	layer = 20
	root = Control.new()
	add_child(root)
	var light := ColorRect.new()
	light.color = LIGHT
	root.add_child(light)
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	cc.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UI.label("Im Takt über die Tanzfläche" if kind == "tanz" else "Badge aus der Innentasche ziehen", 30, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var ab: String = labels.get("abort", "Esc")
	if kind == "tanz":
		ab = "%s / %s" % [ab, labels2.get("abort", "Backspace")]
	head.add_child(UI.label("%s · abbrechen" % ab, 13, MUTED))
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(900, 500) if kind == "tanz" else Vector2(640, 380)
	canvas.draw.connect(_on_draw)
	v.add_child(canvas)
	info = UI.label("", 17, INK, 0, true)
	info.custom_minimum_size = Vector2(canvas.custom_minimum_size.x, 52)   # two lines: the layout does not jump when the text changes
	info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(info)
	if kind == "tanz":
		poses = Posen.alle()
		ready_pose = Posen.bereit()
		round_i = Posen.erste()
		Track.use(self, ["pose"])
	else:
		jitter = TM.Jitter.new()
		Track.use(self, ["hand"])
	_place()
	_update_info()
	UI.sfx("whoosh", -10.0)


## The whole screen for two, the player's half for one (like minigame.gd, _place_half).
func _place() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if pid < 0:
		var k0 := clampf(minf(vs.x / 980.0, vs.y / 690.0), 0.5, 1.2)
		scale = Vector2(k0, k0)
		offset = Vector2.ZERO
		root.position = Vector2.ZERO
		root.size = vs / k0
		return
	var half := vs.x / 2.0
	var k := clampf((half - 24.0) / 700.0, 0.5, 1.0)
	scale = Vector2(k, k)
	offset = Vector2((screen_side if screen_side >= 0 else pid) * half, 0.0)
	root.position = Vector2.ZERO
	root.size = Vector2(half, vs.y) / k


func _process(delta: float) -> void:
	t += delta
	_place()
	flash = maxf(0.0, flash - delta)
	if closing >= 0.0:
		closing -= delta
		if closing < 0.0:
			finished.emit(true, mistakes)
			queue_free()
			return
	elif kind == "tanz":
		_tanz(delta)
	else:
		_badge(delta)
	_update_info()
	canvas.queue_redraw()


func _has(d: Dictionary, what: String, k: int) -> bool:
	return k in (d.get(what, []) as Array)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if _has(keys, "abort", k) or _has(keys2, "abort", k):
		get_viewport().set_input_as_handled()
		finished.emit(false, mistakes)
		queue_free()
		return
	if closing >= 0.0:
		return
	if not use_keys and (_has(keys, "interact", k) or _has(keys2, "interact", k)):
		get_viewport().set_input_as_handled()
		_to_keys()
		return
	if kind == "tanz" and use_keys and state == "play" and beat_t <= BEAT_WINDOW:
		var want := round_i % 4
		for j in 2:
			var kk: Dictionary = keys if j == 0 else keys2
			for d in 4:
				if _has(kk, DIR_NAMES[d], k):
					pressed[j] = d == want
					get_viewport().set_input_as_handled()


## The camera is of no use right now: go on with the keys.
func _to_keys() -> void:
	if kind == "tanz":
		use_keys = true
		if state != "play":
			state = "play"
			beat_t = BEAT + 1.0
	else:
		fallback.emit()
		queue_free()


func _miss() -> void:
	mistakes += 1
	flash = 0.5
	flash_ok = false
	UI.sfx("fail", -8.0)
	mistake.emit()


func _win() -> void:
	state = "done"
	closing = 1.2
	flash = 1.2
	flash_ok = true
	UI.sfx("grant", -6.0)


# ------------------------------------------------------------------ tanz
## Follows every body in the picture from frame to frame. The camera reports up to four people,
## in no fixed order, not always the same ones and now and then one of them twice. A body stays
## the same body as long as its shoulders are close to where they were. New people get a new
## entry, people who are gone for longer than HOLD are dropped (dancers are kept, they may come
## back, and are looked for in a wider circle the longer they are gone).
func _follow_bodies(delta: float) -> void:
	var seen: Array = []             # [entry, middle between the shoulders, how sure the camera is of the shoulders]
	if Track.alive:
		var list: Array = Track.poses.duplicate()
		list.sort_custom(func(a, b): return TM.size_of(a) > TM.size_of(b))
		for e in list:
			var q: Array = e["pts"]
			var sure: float = minf(q[11][2], q[12][2])
			if sure < KEEP_VIS:
				continue
			var m := Vector2((q[11][0] + q[12][0]) / 2.0, (q[11][1] + q[12][1]) / 2.0)
			var twice := false
			for o in seen:
				if (o[1] as Vector2).distance_to(m) < SAME_BODY:
					twice = true         # the same person again: the bigger one came first and stays
					break
			if not twice:
				seen.append([e, m, sure])
	var pairs: Array = []            # [distance, body, entry]: closest first
	for bi in bodies.size():
		var b: Followed = bodies[bi]
		b.matched = false
		var reach: float = lerpf(SAME_PERSON, REJOIN, clampf(b.age / HOLD, 0.0, 1.0))
		for si in seen.size():
			var d: float = b.mid.distance_to(seen[si][1])
			if d < reach:
				pairs.append([d, bi, si])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	var used := {}
	for pr in pairs:
		var b: Followed = bodies[pr[1]]
		if b.matched or used.has(pr[2]):
			continue
		b.matched = true
		used[pr[2]] = true
		b.feed(seen[pr[2]][0], delta, SMOOTH, HOLD)
	for b in bodies:
		if not (b as Followed).matched:
			(b as Followed).feed({}, delta, SMOOTH, HOLD)
	for si in seen.size():
		if not used.has(si) and seen[si][2] >= TM.POSE_MIN_VIS and bodies.size() < MAX_BODIES:
			var nb := Followed.new()
			nb.feed(seen[si][0], delta, SMOOTH, HOLD)
			bodies.append(nb)
	bodies = bodies.filter(func(b): return b.age <= HOLD or team.has(b))


## Before the dance: whoever puts the hands up is in. That also shows that their arms are in the
## picture. The first one opens a short window in which a second one can join; onlookers who
## keep their hands down never count, however many of them stand around the laptop.
func _ready_up(delta: float) -> void:
	for b in bodies:
		b.score = _arms(b.pose(HOLD), ready_pose)
		b.ready_t = minf(READY_HOLD, b.ready_t + delta) if b.score >= READY_OK else maxf(0.0, b.ready_t - 2.0 * delta)
		if b.ready_t >= READY_HOLD and not team.has(b) and team.size() < 2:
			team.append(b)
			UI.sfx("tick", -6.0)
	team = team.filter(func(b): return b.age <= HOLD)
	if team.is_empty():
		join_t = 0.0
		return
	join_t += delta
	if team.size() == 2 or join_t >= JOIN or bodies.size() == 1:
		team.sort_custom(func(a, b): return a.mid.x < b.mid.x)
		solo = team.size() == 1
		state = "play"
		beat_t = BEAT + 0.6
		flash = 0.4
		flash_ok = true
		UI.sfx("pop", -6.0)


## During the dance: the poses of the dancers. Returns how many of them are there.
func _team_poses() -> int:
	if team.size() == 2:
		for b in team:
			if b.age > PAIR_MEMORY:
				team.erase(b)        # gone for good: the other one dances for both from now on
				break
	solo = team.size() < 2
	if team.is_empty():
		dancers = [{}, {}]
		return 0
	if solo:
		if (team[0] as Followed).age > REACQUIRE:
			# the dancer has left: whoever is closest to the camera goes on
			var best: Followed = null
			for b in bodies:
				if b.age <= HOLD and (best == null or b.size > best.size):
					best = b
			if best != null:
				team = [best]
		var p: Dictionary = (team[0] as Followed).pose(HOLD)
		dancers = [p, p]
		return 0 if p.is_empty() else 1
	var n := 0
	for j in 2:
		dancers[j] = (team[j] as Followed).pose(HOLD)
		if not (dancers[j] as Dictionary).is_empty():
			n += 1
	return n


## How well somebody's arms match the target pose, 0..100. Per arm: upper arm and forearm are
## compared by direction (so distance and body size do not matter); half the score of an arm is
## the average of the two, half is the worse one. The worse arm counts. So one arm in the wrong
## place cannot be made up for by the other one, and the shoulders, which always match, do not
## help. Arms that are not in the picture score 0.
func _arms(pose: Dictionary, target: Dictionary) -> float:
	if pose.is_empty() or target.is_empty():
		return 0.0
	var a: Array = pose["pts"]
	var b: Array = target["pts"]
	var asp: float = Track.aspect
	var worst := 1.0
	for arm in [[11, 13, 15], [12, 14, 16]]:
		var sum := 0.0
		var low := 1.0
		for k in 2:
			var i: int = arm[k]
			var j: int = arm[k + 1]
			var sc := 0.0
			if minf(a[i][2], a[j][2]) >= TM.POSE_MIN_VIS:
				var da := Vector2((a[j][0] - a[i][0]) * asp, a[j][1] - a[i][1])
				var db := Vector2((b[j][0] - b[i][0]) * asp, b[j][1] - b[i][1])
				sc = clampf(1.0 - absf(rad_to_deg(da.angle_to(db))) / ARM_TOLERANCE, 0.0, 1.0)
			sum += sc
			low = minf(low, sc)
		worst = minf(worst, (sum / 2.0 + low) / 2.0)
	return worst * 100.0


func _tanz(delta: float) -> void:
	var n := 0
	if not use_keys:
		_follow_bodies(delta)
		if state == "play":
			n = _team_poses()
			var target: Dictionary = poses[round_i % poses.size()]
			for j in 2:
				match_pc[j] = _arms(dancers[j], target)
				# what is shown is what counts: the bar follows softly, and green means the pose sits
				shown_pc[j] = lerpf(shown_pc[j], match_pc[j], 1.0 - exp(-delta / BAR_SMOOTH))
				sits[j] = shown_pc[j] >= POSE_OK - (OK_SLACK if sits[j] else 0.0)
		else:
			n = bodies.size()
		no_cam = 0.0 if n > 0 else no_cam + delta
		if no_cam > CAM_WAIT * (CAM_PATIENCE if Track.alive else 1.0):
			_to_keys()
	if state == "warm":
		if n > 0:
			state = "ready"
		return
	if state == "ready":
		_ready_up(delta)
		return
	beat_t -= delta
	if beat_t <= BEAT_WINDOW and not hit_now:
		var ok: bool = (pressed[0] and pressed[1]) if use_keys else (n > 0 and sits[0] and sits[1])
		if ok:
			hit_now = true
			hits += 1
			flash = 0.4
			flash_ok = true
			UI.sfx("pop", -6.0)
			beat_t = minf(beat_t, 0.7)   # a short breath, then the next pose
			if hits >= DANCE_HITS:
				_win()
				return
	if beat_t <= 0.0:
		if not hit_now:
			_miss()   # one of the two was off: both stand out
		round_i += 1
		beat_t = BEAT
		hit_now = false
		pressed = [false, false]
		shown_pc = [0.0, 0.0]     # a new pose: the bars start again, the old pose does not count for it
		sits = [false, false]


# ------------------------------------------------------------------ badge
## The hand that plays. Any hand in the picture will do (only one player steals at a time), but it
## stays the same hand: the one that was playing a moment ago, as long as it is there. Another
## hand only takes over when the first one is gone, or is open while the other one pinches.
func _find_hand(delta: float) -> void:
	var list: Array = Track.hands if Track.alive else []
	var mine := {}
	var other := {}                  # the hand that pinches hardest
	for h in list:
		var p := Vector2(h["palm"][0], h["palm"][1])
		if hand_age < HAND_LOST and p.distance_to(palm) < HAND_REACH:
			if mine.is_empty() or p.distance_to(palm) < Vector2(mine["palm"][0], mine["palm"][1]).distance_to(palm):
				mine = h
		if other.is_empty() or float(h["pinch"]) < float(other["pinch"]):
			other = h
	if mine.is_empty() and not holding:
		mine = other
	elif not mine.is_empty() and not holding and other != mine and TM.pinch01(mine) > PINCH_DROP and TM.pinch01(other) < PINCH_GRAB:
		mine = other
		hand_show.clear()
	hand = mine
	if hand.is_empty():
		hand_age += delta
	else:
		hand_age = 0.0
		palm = Vector2(hand["palm"][0], hand["palm"][1])
	hand_show.feed(hand, delta, SMOOTH, HOLD)


func _badge(delta: float) -> void:
	_find_hand(delta)
	var seen := not hand.is_empty()
	no_cam = 0.0 if seen else no_cam + delta
	if no_cam > CAM_WAIT * (CAM_PATIENCE if Track.alive else 1.0):
		_to_keys()
		return
	if state == "warm":
		if seen:
			state = "play"
		return
	if not seen:
		lost_t += delta
		if lost_t > HAND_LOST:
			holding = false
			progress = 0.0
		return
	lost_t = 0.0
	var p := TM.pinch01(hand)
	if not holding:
		shake = lerpf(shake, 0.0, 1.0 - exp(-delta / BAR_SMOOTH))
		if p > PINCH_DROP:
			armed = true
		if armed and p < PINCH_GRAB:
			holding = true
			y0 = palm.y
			progress = 0.0
			shaky_t = 0.0
			jitter = TM.Jitter.new()
			UI.sfx("tick", -6.0)
		return
	if p > PINCH_DROP:
		holding = false     # let go: the badge slips back, nobody noticed
		progress = 0.0
		return
	progress = maxf(progress, clampf((y0 - palm.y) / PULL, 0.0, 1.0))
	shake = jitter.push(palm, delta)
	shaky_t = shaky_t + delta if shake > JITTER_MAX else 0.0
	if shaky_t > JITTER_TIME:
		holding = false
		armed = false
		progress = 0.0
		_miss()             # the coat rustles
	elif progress >= 1.0:
		_win()


# ------------------------------------------------------------------ texts
func _update_info() -> void:
	var s := ""
	var with_keys := "   (%s oder %s: mit Tasten tanzen)" % [labels.get("ok", "E"), labels2.get("ok", "Enter")]
	if kind == "tanz":
		if state == "done":
			s = "Ihr tanzt, als hättet ihr nie etwas anderes gemacht."
		elif use_keys:
			s = "Ohne Kamera: Drückt beide die gezeigte Richtung, sobald der Balken grün ist (%s, %s)." % [labels.get("dirs", "WASD"), labels2.get("dirs", "Pfeiltasten")]
		elif state == "warm":
			s = ("Niemand im Bild. Rückt vom Bildschirm weg, bis Kopf, Schultern und erhobene Arme zu sehen sind." if Track.alive else "Kamera startet …") + with_keys
		elif state == "ready":
			s = "Wer tanzt, rückt so weit zurück, dass die erhobenen Hände im Bild sind, und dann: Hände hoch! Zu zweit beide gleichzeitig. Wer zuschaut, zählt nicht." + with_keys
		else:
			s = "Macht die Pose nach, solange der Balken grün ist. Getroffen: %d von %d." % [hits, DANCE_HITS]
	else:
		if state == "done":
			s = "Der Badge ist draussen."
		elif state == "warm":
			if not Track.alive:
				s = "Kamera startet … (%s: mit Tasten)" % labels.get("ok", "E")
			else:
				s = "Halte eine Hand vor die Kamera. (%s: mit Tasten)" % labels.get("ok", "E")
		elif not holding:
			s = "Daumen und Zeigefinger zusammendrücken: So greifst du den Badge." if armed else "Der Mantel hat geraschelt! Finger kurz öffnen, dann nochmals greifen."
		else:
			s = "Zugedrückt lassen und die Hand langsam nach oben ziehen. Ruhige Hand, sonst raschelt der Mantel!"
	if mistakes > 0 and state != "done":
		s += "   Fehler: %d" % mistakes
	if info.text != s:
		info.text = s


# ------------------------------------------------------------------ drawing
func _txt(pos: Vector2, s: String, size: int, col: Color, centered: bool = false) -> void:
	var font := ThemeDB.fallback_font
	if centered:
		pos.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	canvas.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar(r: Rect2, v: float, col: Color) -> void:
	canvas.draw_rect(r, Color(0.14, 0.15, 0.29, 0.14))
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), col)
	canvas.draw_rect(r, SOFT, false, 1.5)


## The biggest rectangle with the shape of the camera picture inside `r`.
func _fit(r: Rect2) -> Rect2:
	var asp: float = Track.aspect
	var size := Vector2(r.size.x, r.size.x / asp)
	if size.y > r.size.y:
		size = Vector2(r.size.y * asp, r.size.y)
	return Rect2(r.position + (r.size - size) / 2.0, size)


## A pose as a stick figure with head and torso, fitted into `r` around the shoulders.
func _figure(pose: Dictionary, r: Rect2, col: Color, width: float) -> void:
	if pose.is_empty():
		return
	var pts: Array = pose["pts"]
	var asp: float = Track.aspect
	var ls := Vector2(pts[11][0] * asp, pts[11][1])
	var rs := Vector2(pts[12][0] * asp, pts[12][1])
	var mid := (ls + rs) / 2.0
	var sw := r.size.x * 0.22                          # shoulder width on screen
	var k := sw / maxf(ls.distance_to(rs), 0.01)
	var o := Vector2(r.get_center().x, r.position.y + r.size.y * 0.66)
	var at := func(i: int) -> Vector2: return o + (Vector2(pts[i][0] * asp, pts[i][1]) - mid) * k
	canvas.draw_colored_polygon(PackedVector2Array([o + Vector2(-sw / 2.0, 0), o + Vector2(sw / 2.0, 0),
		o + Vector2(sw * 0.4, r.size.y * 0.3), o + Vector2(-sw * 0.4, r.size.y * 0.3)]), Color(col, 0.3))
	canvas.draw_circle(o + Vector2(0, -sw * 0.62), sw * 0.36, Color(col, 0.55))
	for limb in [[11, 13], [13, 15], [12, 14], [14, 16]]:
		if minf(pts[limb[0]][2], pts[limb[1]][2]) < TM.POSE_MIN_VIS:
			continue
		var a: Vector2 = at.call(limb[0])
		var b: Vector2 = at.call(limb[1])
		canvas.draw_line(a, b, col, width)
		canvas.draw_circle(a, width * 0.62, col)
		canvas.draw_circle(b, width * 0.62, col)


## What the camera recognises of somebody, drawn onto the camera picture in `view`. Parts the
## camera is less sure of fade out instead of popping in and out.
func _skeleton(pose: Dictionary, view: Rect2, col: Color, width: float = 5.0) -> void:
	var pts: Array = pose["pts"]
	var at := func(i: int) -> Vector2: return view.position + Vector2(pts[i][0], pts[i][1]) * view.size
	var sure := func(v: float) -> float: return clampf(inverse_lerp(SHOW_VIS, TM.POSE_MIN_VIS + 0.2, v), 0.0, 1.0)
	for limb in [[11, 12], [11, 13], [13, 15], [12, 14], [14, 16]]:
		var s: float = sure.call(minf(pts[limb[0]][2], pts[limb[1]][2]))
		if s <= 0.0:
			continue
		var pa: Vector2 = at.call(limb[0])
		var pb: Vector2 = at.call(limb[1])
		canvas.draw_line(pa, pb, Color(1, 1, 1, 0.9 * s * col.a), width + 3.0, true)
		canvas.draw_line(pa, pb, Color(col, s * col.a), width, true)
	for i in [11, 12, 13, 14, 15, 16]:
		var s: float = sure.call(pts[i][2])
		if s > 0.0:
			canvas.draw_circle(at.call(i), width + 1.0, Color(col, s * col.a))


func _arrow(c: Vector2, d: int, size: float, col: Color) -> void:
	var dv: Vector2 = DIR_VECS[d]
	var n := Vector2(-dv.y, dv.x)
	canvas.draw_colored_polygon(PackedVector2Array([c + dv * size, c - dv * size * 0.6 + n * size * 0.8, c - dv * size * 0.6 - n * size * 0.8]), col)


func _on_draw() -> void:
	if flash > 0.0:
		var fc := UI.GREEN if flash_ok else UI.RED
		canvas.draw_rect(Rect2(Vector2(-8, -8), canvas.size + Vector2(16, 16)), Color(fc, minf(1.0, flash * 2.0) * 0.8), false, 8.0)
	if kind == "tanz":
		_draw_tanz()
	else:
		_draw_badge()


## One dancer's line under the camera picture: name, bar with the mark it has to reach, and a
## word under it. The line keeps its shape whatever happens, and there is no number that runs.
func _draw_score(x: float, w: float, who: String, col: Color, j: int, limit: float) -> void:
	_txt(Vector2(x, 414), who, 18, col.darkened(0.15))
	if use_keys:
		var done: bool = pressed[j] or hit_now
		_txt(Vector2(x, 446), "gedrückt" if done else "…", 24, UI.GREEN.darkened(0.25) if done else SOFT)
		return
	var ok: bool = sits[j] or hit_now
	_bar(Rect2(x, 426, w, 18), shown_pc[j] / 100.0, UI.GREEN if ok else col)
	canvas.draw_line(Vector2(x + w * limit / 100.0, 421), Vector2(x + w * limit / 100.0, 449), INK, 2.0)
	if (dancers[j] as Dictionary).is_empty():
		_txt(Vector2(x, 474), "nicht im Bild", 18, UI.RED)
	elif ok:
		_txt(Vector2(x, 474), "passt", 18, UI.GREEN.darkened(0.25))


func _draw_tanz() -> void:
	var playing := state == "play" or state == "done"
	# left: the camera picture as a mirror with what is recognised, or the direction to press
	var pic := Rect2(10, 10, 500, 375)
	canvas.draw_rect(pic, Color(0.14, 0.15, 0.29, 0.1))
	if use_keys:
		var pad := Rect2(pic.get_center() - Vector2(70, 70), Vector2(140, 140))
		canvas.draw_rect(pad, Color(1, 1, 1, 0.85))
		canvas.draw_rect(pad, INK, false, 4.0)
		_arrow(pad.get_center(), round_i % 4, 40.0, INK)
		_txt(Vector2(pic.get_center().x, pic.position.y + 60), "Diese Richtung, wenn der Balken grün ist", 18, MUTED, true)
	else:
		var view := _fit(pic)
		if Track.preview.get_width() > 0:
			canvas.draw_texture_rect(Track.preview, view, false)
		else:
			_txt(pic.get_center(), "Kamera startet …" if not Track.alive else "kein Bild", 20, MUTED, true)
		if not playing:
			# everybody the camera follows, thin; whoever puts the hands up turns to colour, with a ring that fills
			for b in bodies:
				var p: Dictionary = (b as Followed).pose(HOLD)
				if p.is_empty():
					continue
				var up: float = 1.0 if team.has(b) else b.ready_t / READY_HOLD
				var a: float = b.alpha()
				_skeleton(p, view, Color(Color(1, 1, 1).lerp(BOTH, up), lerpf(0.75, 1.0, up) * a), lerpf(3.0, 5.0, up))
				if up > 0.0:
					var c: Vector2 = view.position + b.chest() * view.size + Vector2(0, 26)
					canvas.draw_arc(c, 13.0, -PI / 2.0, -PI / 2.0 + TAU * up, 24, Color(UI.GREEN, a), 5.0, true)
		else:
			# only the dancers: one in gold for both, or two in the colours of the players
			for j in team.size():
				var d: Followed = team[j]
				if d.there(HOLD):
					_skeleton(d.pose(HOLD), view, Color(BOTH if solo else Color(String(KEYS.TAG_COLORS[j])), d.alpha()))
	canvas.draw_rect(pic, INK, false, 3.0)
	# under it: who is in, or how well the dancers match
	if use_keys:
		for j in 2:
			_draw_score(10.0 + j * 256.0, 244.0, Game.name_of(j), Color(String(KEYS.TAG_COLORS[j])), j, POSE_OK)
	elif not playing:
		_txt(Vector2(10, 414), "Wer die Hände hebt, tanzt mit", 18, INK)
		var who := "noch niemand" if team.is_empty() else ("eine Person, tanzt für beide" if team.size() == 1 else "zwei Personen")
		_txt(Vector2(10, 446), "Dabei: %s" % who, 20, UI.GREEN.darkened(0.25) if not team.is_empty() else MUTED)
	elif solo:
		_draw_score(10.0, 500.0, "Eine Person tanzt für beide", BOTH, 0, POSE_OK)
	else:
		for j in 2:
			_draw_score(10.0 + j * 256.0, 244.0, Game.name_of(j), Color(String(KEYS.TAG_COLORS[j])), j, POSE_OK)
	# right: the pose to strike, and the beat
	var box := Rect2(570, 10, 320, 300)
	canvas.draw_rect(box, Color(1, 1, 1, 0.7))
	canvas.draw_rect(box, INK, false, 3.0)
	if state == "warm":
		_txt(Vector2(box.get_center().x, box.get_center().y), "Gleich geht's los", 22, MUTED, true)
	elif not playing:
		_figure(ready_pose, box, INK, 11.0)
		_txt(Vector2(box.get_center().x, 342), "Zum Start: Hände hoch!", 24, INK, true)
		if not team.is_empty():
			_bar(Rect2(570, 356, 320, 18), join_t / JOIN, UI.GREEN)
	else:
		var target: Dictionary = poses[round_i % poses.size()]
		_figure(target, box, INK, 11.0)
		_txt(Vector2(box.get_center().x, 342), String(target.get("name", "Pose %d" % (round_i % poses.size() + 1))), 24, INK, true)
		var now := beat_t <= BEAT_WINDOW
		_bar(Rect2(570, 356, 320, 18), beat_t / BEAT, UI.GREEN if now else INK)
		if hit_now:
			_txt(Vector2(box.get_center().x, 408), "Sitzt!", 28, UI.GREEN.darkened(0.25), true)
		elif now:
			_txt(Vector2(box.get_center().x, 408), "JETZT!", 28, UI.GREEN.darkened(0.25), true)
	for i in DANCE_HITS:
		var c := Vector2(box.get_center().x - (DANCE_HITS - 1) * 19.0 + i * 38.0, 452.0)
		canvas.draw_circle(c, 13.0, Color(0.14, 0.15, 0.29, 0.18))
		if i < hits:
			canvas.draw_circle(c, 10.0, UI.GREEN)


func _draw_badge() -> void:
	var loden := Color("2f6b45")
	var coat := Rect2(40, 20, 250, 330)
	var slit := 222.0                                  # where the inner pocket opens
	canvas.draw_rect(coat, loden)
	canvas.draw_line(coat.position + Vector2(40, 0), coat.position + Vector2(110, 150), loden.darkened(0.3), 4.0)   # lapel
	canvas.draw_circle(coat.position + Vector2(206, 60), 7.0, Color("d9b24c"))
	# the badge comes up out of the pocket
	var card := Rect2(128, slit - 12.0 - 104.0 * progress, 74, 104)
	Fund.draw_card(canvas, card)
	# front of the pocket hides the part that is still inside
	canvas.draw_rect(Rect2(coat.position.x, slit, coat.size.x, coat.end.y - slit), loden.lightened(0.06))
	canvas.draw_line(Vector2(80, slit), Vector2(250, slit), loden.darkened(0.4), 4.0)
	_bar(Rect2(40, 360, 250, 12), progress, UI.GREEN)
	# the hand: thumb and index finger as the camera sees them (smoothed), on the picture of the coat
	var mine := Color(String(KEYS.TAG_COLORS[pid])) if pid >= 0 else INK
	var shown := hand_show.pose(HOLD)
	var fade := hand_show.alpha()
	var hc := Color(UI.GREEN, fade) if holding else Color(1, 1, 1, 0.9 * fade)
	if not shown.is_empty():
		var pts: Array = shown["pts"]
		var to := func(q: Array) -> Vector2: return coat.position + Vector2(float(q[0]), float(q[1])) * coat.size
		var a: Vector2 = to.call(pts[4])
		var b: Vector2 = to.call(pts[8])
		canvas.draw_line(a, b, hc, 3.0, true)
		canvas.draw_circle(a, 9.0, hc)
		canvas.draw_circle(b, 9.0, hc)
		canvas.draw_arc(a, 9.0, 0.0, TAU, 20, Color(INK, fade), 2.0, true)
		canvas.draw_arc(b, 9.0, 0.0, TAU, 20, Color(INK, fade), 2.0, true)
		if holding:
			canvas.draw_line((a + b) / 2.0, card.position + Vector2(card.size.x / 2.0, 0), Color(Color("d9b24c"), fade), 2.0, true)
	# what the camera sees
	var pr := Rect2(330, 20, 290, 218)
	canvas.draw_rect(pr, Color(0.14, 0.15, 0.29, 0.12))
	var view := _fit(pr)
	if Track.preview.get_width() > 0:
		canvas.draw_texture_rect(Track.preview, view, false)
		if not shown.is_empty():
			var hp: Array = shown["pts"]
			var pa := view.position + Vector2(hp[4][0], hp[4][1]) * view.size
			var pb := view.position + Vector2(hp[8][0], hp[8][1]) * view.size
			canvas.draw_line(pa, pb, Color(1, 1, 1, 0.9 * fade), 4.0, true)
			canvas.draw_circle(pa, 6.0, Color(UI.GREEN if holding else mine, fade))
			canvas.draw_circle(pb, 6.0, Color(UI.GREEN if holding else mine, fade))
	canvas.draw_rect(pr, INK, false, 2.0)
	_txt(Vector2(330, 270), "Ruhige Hand", 15, INK)
	_bar(Rect2(330, 280, 290, 12), shake / JITTER_MAX, UI.RED if shake > JITTER_MAX else mine)
