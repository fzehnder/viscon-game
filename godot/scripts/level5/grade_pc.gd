extends CanvasLayer
## The professor's computer: the grade list of the design studio (Notenverwaltung). On the half of
## the screen of the player who sits at it, like the other minigames (registered in main.minis).
## Pick the submission with the 6 (up / down, interact), then type your own name over the student's
## by hammering interact. Opening a wrong one beeps (mistake: the guards hear it). A submission that
## already carries the other player's name does not count. Esc / Backspace (abort) leaves.

signal finished(success: bool, mistakes: int)
signal mistake

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")

const STUDENTS := ["Lea Graf", "Noah Steiner", "Mia Kunz", "Elias Frei", "Lina Vogt", "Jonas Roth", "Sara Bühler", "Luca Meier"]
const PROJECTS := ["Wohnhaus am Hang", "Pavillon aus Holz", "Turm am See", "Markthalle", "Schulhaus Nord", "Brücke Limmat", "Atelierhaus", "Bad im Fels"]
const GRADES := [6.0, 6.0, 5.5, 5.0, 4.75, 4.5, 4.0, 3.5]
const CHARS_PER_PRESS := 2      # letters per press of interact while typing

var pid := 0
var main
var mistakes := 0
var rows: Array = []            # [{"name", "project", "grade", "mine": pid or -1}] shared, see open()
var sel := 0
var typing := -1                # row being renamed
var typed := 0.0
var done_t := -1.0
var abort_held := true          # the abort key counts only after it was let go once
var t := 0.0
var root: Control
var view: Control


class View:
	extends Control
	var pc

	func _draw() -> void:
		pc._draw_pc(self)


## rows: the list kept by the level, so both players see the same entries and renamed names stay.
func open(p_rows: Array) -> void:
	rows = p_rows
	layer = 20
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	view = View.new()
	view.pc = self
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(view)
	sel = 0
	UI.sfx("click")


## Fresh list for a new level start: random order.
static func make_rows() -> Array:
	var out: Array = []
	var order: Array = range(STUDENTS.size())
	order.shuffle()
	for i in STUDENTS.size():
		out.append({"name": STUDENTS[order[i]], "project": PROJECTS[i], "grade": GRADES[(i * 3) % GRADES.size()], "mine": -1})
	return out


func _process(delta: float) -> void:
	t += delta
	# keep to the half of the screen of this player (the split can still be moving)
	var vs := root.get_viewport_rect().size
	var side: int = main.screen_side(pid) if main != null else pid
	if side < 0:
		side = pid
	root.position = Vector2(side * vs.x / 2.0, 0)
	root.size = Vector2(vs.x / 2.0, vs.y)
	view.position = Vector2(30, 70)
	view.size = root.size - Vector2(60, 150)
	view.queue_redraw()
	if done_t >= 0.0:
		done_t += delta
		if done_t > 1.2:
			finished.emit(true, mistakes)
			queue_free()
		return
	# abort keys are physical keys (controls.gd), there is no input action for them
	var abort_now := false
	for k in KEYS.keys_for(pid)["abort"]:
		abort_now = abort_now or Input.is_physical_key_pressed(k)
	if abort_now and not abort_held:
		finished.emit(false, mistakes)
		queue_free()
		return
	abort_held = abort_now
	if typing >= 0:
		if Input.is_action_just_pressed(KEYS.action(pid, "interact")):
			typed += CHARS_PER_PRESS
			UI.sfx("type", -10.0)
			if typed >= Game.name_of(pid).length():
				rows[typing]["name"] = Game.name_of(pid)
				rows[typing]["mine"] = pid
				typing = -1
				done_t = 0.0
				UI.sfx("success")
		return
	if Input.is_action_just_pressed(KEYS.action(pid, "up")):
		sel = (sel - 1 + rows.size()) % rows.size()
		UI.sfx("tick", -12.0)
	if Input.is_action_just_pressed(KEYS.action(pid, "down")):
		sel = (sel + 1) % rows.size()
		UI.sfx("tick", -12.0)
	if Input.is_action_just_pressed(KEYS.action(pid, "interact")):
		var r: Dictionary = rows[sel]
		if float(r["grade"]) >= 6.0 and int(r["mine"]) < 0:
			typing = sel
			typed = 0.0
			UI.sfx("click")
		else:
			mistakes += 1
			mistake.emit()
			UI.sfx("buzz")


func _draw_pc(ci: Control) -> void:
	var font := ThemeDB.fallback_font
	var w := ci.size.x
	var h := ci.size.y
	var col := Color(KEYS.TAG_COLORS[pid])
	# monitor
	ci.draw_rect(Rect2(-14, -14, w + 28, h + 28), Color("1c1d22"))
	ci.draw_rect(Rect2(0, 0, w, h), Color("eef1f6"))
	ci.draw_rect(Rect2(0, 0, w, 30), Color("1f407a"))
	ci.draw_string(font, Vector2(10, 21), "Notenverwaltung D-ARCH · Entwurf HS26 · Prof. Dr. Kuster", HORIZONTAL_ALIGNMENT_LEFT, w - 20, 14, Color.WHITE)
	ci.draw_string(font, Vector2(14, 56), "Name", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("5b6170"))
	ci.draw_string(font, Vector2(w * 0.42, 56), "Abgabe", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("5b6170"))
	ci.draw_string(font, Vector2(w - 70, 56), "Note", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("5b6170"))
	var row_h := minf(40.0, (h - 150) / rows.size())
	for i in rows.size():
		var r: Dictionary = rows[i]
		var y := 66.0 + i * row_h
		var mine: int = r["mine"]
		var bg := Color.WHITE if i % 2 == 0 else Color("f6f8fb")
		if i == sel and typing < 0 and done_t < 0.0:
			bg = Color(col, 0.22)
		ci.draw_rect(Rect2(6, y, w - 12, row_h - 2), bg)
		var name_txt: String = r["name"]
		var name_col := Color("1c2033")
		if i == typing:
			var target := Game.name_of(pid)
			var n := int(typed)
			name_txt = target.substr(0, n) + ("|" if fmod(t, 0.6) < 0.3 else " ")
			name_col = col.darkened(0.2)
		elif mine >= 0:
			name_col = Color(KEYS.TAG_COLORS[mine]).darkened(0.2)
		ci.draw_string(font, Vector2(14, y + row_h * 0.68), name_txt, HORIZONTAL_ALIGNMENT_LEFT, w * 0.4 - 20, 16, name_col)
		ci.draw_string(font, Vector2(w * 0.42, y + row_h * 0.68), r["project"], HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, 15, Color("33383d"))
		var g: float = r["grade"]
		ci.draw_string(font, Vector2(w - 70, y + row_h * 0.68), ("%.2f" % g).trim_suffix("0").trim_suffix("0").trim_suffix("."), HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color("1e8f5a") if g >= 6.0 else Color("1c2033"))
	# help line
	var hint := "%s: hoch / runter wählen · %s: Abgabe öffnen · %s: weg vom PC" % [
		"W / S" if pid == 0 else "Pfeile", "E" if pid == 0 else "Enter", "Esc" if pid == 0 else "Rücktaste"]
	if typing >= 0:
		hint = "Namen eintippen: %s hämmern!" % ("E" if pid == 0 else "Enter")
	elif done_t >= 0.0:
		hint = "Gespeichert. Die 6 gehört jetzt %s." % Game.name_of(pid)
	ci.draw_rect(Rect2(0, h - 40, w, 40), Color("dfe5ee"))
	ci.draw_string(font, Vector2(12, h - 14), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 24, 14, Color("1c2033"))
	if mistakes > 0:
		ci.draw_string(font, Vector2(w - 200, 21), "Piep! (%d)" % mistakes, HORIZONTAL_ALIGNMENT_RIGHT, 190, 13, UI.YELLOW)
