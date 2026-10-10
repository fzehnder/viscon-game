extends RefCounted
## Level 5: security cameras and the view from inside a cupboard.

const UI = preload("res://scripts/ui.gd")
const KEYS = preload("res://scripts/controls.gd")


## A camera on the wall: sweeps left and right, its cone is red. Whoever stays in it too long
## sets off the alarm (level.alarm): the nearest guards run there. It cannot catch anybody itself.
class Cam:
	extends Node2D
	const TS := 32.0
	const SEE_TIME := 0.8        # seconds in the cone until the alarm
	const COOL := 7.0            # seconds before it can raise the alarm again
	var main
	var level
	var base := 0.0
	var sweep := 0.6
	var speed := 0.55
	var range_px := 8.0 * TS
	var half := 0.4
	var dir := 0.0
	var t := 0.0
	var meter := 0.0
	var cool := 0.0
	var cone: Polygon2D

	func _ready() -> void:
		cone = Polygon2D.new()
		cone.z_index = -1
		add_child(cone)
		t = randf() * 10.0

	func _process(delta: float) -> void:
		t += delta
		dir = base + sin(t * speed) * sweep
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			var a := dir - half + 2.0 * half * i / 12.0
			pts.append(main.world.ray_end(global_position, global_position + Vector2.from_angle(a) * range_px) - global_position)
		cone.polygon = pts
		cone.color = Color(1.0, 0.25, 0.25, 0.1 + 0.3 * meter) if cool <= 0.0 else Color(1.0, 0.6, 0.3, 0.08)
		queue_redraw()
		if main.state != "play":
			return
		cool = maxf(0.0, cool - delta)
		var target = null
		for pl in main.players:
			if pl.hidden_mode or not pl.visible:
				continue
			var to: Vector2 = pl.global_position - global_position
			if to.length() < range_px and absf(wrapf(to.angle() - dir, -PI, PI)) < half and main.world.line_clear(global_position, pl.global_position):
				target = pl
		if target != null and cool <= 0.0:
			meter = minf(1.0, meter + delta / SEE_TIME)
			if meter >= 1.0:
				meter = 0.0
				cool = COOL
				level.alarm(target.global_position)
		else:
			meter = maxf(0.0, meter - delta * 0.7)

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, dir, Vector2.ONE)
		draw_rect(Rect2(-6, -5, 14, 10), Color("2b2f35"))
		draw_rect(Rect2(6, -3, 5, 6), Color("15162b"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var on := fmod(t, 1.0) < 0.5 or meter > 0.0
		draw_circle(Vector2(-3, -7), 2.5, UI.RED if on else Color("5a1a1a"))


## Drawn over the game: a cupboard door with slats around whoever is hiding, red at the edges when
## a guard comes close; and a red pulse while the alarm is on.
class Overlay:
	extends Control
	var level
	var main
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var vs := size
		if level.alarm_t > 0.0:
			var a := 0.1 + 0.08 * sin(t * 9.0)
			draw_rect(Rect2(Vector2.ZERO, vs), Color(1.0, 0.0, 0.05, a))
			draw_rect(Rect2(Vector2.ZERO, vs), Color(1.0, 0.1, 0.1, 0.6), false, 8.0)
		for pid in 2:
			if main.players[pid].hidden_mode and not level.boarded[pid]:
				_slats(pid)


	## Where the player is on the screen (the view that follows them).
	func _screen_pos(pid: int) -> Vector2:
		var v: int = pid if main.vcs.size() > pid else 0
		return main.vcs[v].position + main.vps[v].get_canvas_transform() * main.players[pid].global_position

	## A cupboard door around the hidden player: dark wood, a few narrow slats to look through,
	## red at the edges and a heartbeat when a guard comes close.
	func _slats(pid: int) -> void:
		var vs := size
		var c := _screen_pos(pid) + Vector2(0, -20)
		var box := Rect2(c - Vector2(250, 180), Vector2(500, 360))
		box.position.x = clampf(box.position.x, 0.0, vs.x - box.size.x)
		box.position.y = clampf(box.position.y, 60.0, vs.y - box.size.y - 40.0)
		var wood := Color(0.16, 0.11, 0.07, 0.96)
		var gap := Rect2(box.position + Vector2(box.size.x * 0.14, box.size.y * 0.24), Vector2(box.size.x * 0.72, box.size.y * 0.5))
		draw_rect(Rect2(box.position, Vector2(box.size.x, gap.position.y - box.position.y)), wood)
		draw_rect(Rect2(box.position.x, gap.end.y, box.size.x, box.end.y - gap.end.y), wood)
		draw_rect(Rect2(box.position.x, gap.position.y, gap.position.x - box.position.x, gap.size.y), wood)
		draw_rect(Rect2(gap.end.x, gap.position.y, box.end.x - gap.end.x, gap.size.y), wood)
		var n := 6
		var slat := gap.size.y / n
		for i in n:
			draw_rect(Rect2(gap.position.x, gap.position.y + i * slat, gap.size.x, slat * 0.58), Color(0.1, 0.07, 0.04, 0.95))
			draw_line(Vector2(gap.position.x, gap.position.y + i * slat + slat * 0.58), Vector2(gap.end.x, gap.position.y + i * slat + slat * 0.58), Color(0.45, 0.33, 0.2, 0.8), 2.0)
		draw_rect(box, Color(0.3, 0.21, 0.12), false, 6.0)
		draw_rect(Rect2(box.position.x + box.size.x / 2.0 - 2.0, box.position.y, 4.0, box.size.y), Color(0.08, 0.05, 0.03))   # the two doors
		draw_circle(Vector2(box.position.x + box.size.x / 2.0 - 14.0, box.get_center().y + 40.0), 5.0, Color(0.75, 0.7, 0.55))
		var danger: float = level.danger[pid]
		if danger > 0.0:
			var beat := 0.5 + 0.5 * sin(t * (6.0 + danger * 10.0))
			draw_rect(box.grow(4.0), Color(0.95, 0.05, 0.1, danger * (0.45 + 0.45 * beat)), false, 10.0 + danger * 18.0)
		var font := ThemeDB.fallback_font
		var check: float = level.check_t[pid]
		if check > 0.05:
			var tp := Vector2(box.position.x - 60.0, box.position.y + 52.0)
			draw_string_outline(font, tp, "Er macht den Schrank auf!", HORIZONTAL_ALIGNMENT_CENTER, box.size.x + 120.0, 30, 8, Color("15162b"))
			draw_string(font, tp, "Er macht den Schrank auf!", HORIZONTAL_ALIGNMENT_CENTER, box.size.x + 120.0, 30, UI.RED)
		var key := "E" if pid == 0 else "Enter"
		draw_string_outline(font, Vector2(box.position.x, box.end.y - 22.0), "Versteckt · %s: raus" % key, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 17, 6, Color("15162b"))
		draw_string(font, Vector2(box.position.x, box.end.y - 22.0), "Versteckt · %s: raus" % key, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 17, Color(KEYS.TAG_COLORS[pid]))
