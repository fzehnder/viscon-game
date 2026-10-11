extends CanvasLayer
## Pause menu over the running game: the button "Menü · Esc" bottom right, or Esc while nothing
## else is using that key (main._esc_pauses). The tree is paused while it is open (main.open_pause),
## this layer keeps running. Dark blue glass like everything over the running game (ui.gd).
## Mouse, W/S or the arrow keys and E/Enter; Esc goes back into the game.

signal resume
signal restart
signal transcript
signal to_menu

const KEYS = preload("res://scripts/controls.gd")
const UI = preload("res://scripts/ui.gd")
const Logo = preload("res://scripts/logo.gd")

const ENTRIES := [["Weiter", "resume"], ["Level neu starten", "restart"], ["Leistungsüberblick", "transcript"],
	["Startbildschirm", "to_menu"]]
# the table of keys: [what, entry in KEYS.LABELS]
const KEY_ROWS := [["Bewegen", "dirs"], ["Benutzen", "ok"], ["Rennen", "sprint"], ["Schleichen", "sneak"],
	["Weg zur Aufgabe", "select"], ["Antworten", "nums"], ["Minigame verlassen", "abort"]]

var title := ""          # which level is paused, set by main before the menu is added
var buttons: Array = []
var marks: Array = []
var sel := 0
var born := 0
var leaving := false


## Small triangle in front of the entry that E / Enter would press.
class Mark:
	extends Control
	var on := false

	func _draw() -> void:
		if not on:
			return
		var c := size / 2.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -7), c + Vector2(6, 0), c + Vector2(-5, 7)]), Color("8fb4f0"))


func _ready() -> void:
	layer = 55                                   # over minigames (20) and cutscenes (30), under the transcript (60)
	process_mode = Node.PROCESS_MODE_ALWAYS
	born = Engine.get_process_frames()
	var dim := ColorRect.new()
	dim.color = Color(0.09, 0.1, 0.18, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # nothing behind the menu can be clicked
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var card := UI.panel(UI.GLASS, UI.GLASS_LINE, 20, 24.0)
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	# the name of the game on top, in light blue so that it reads on the dark glass
	var logo := Logo.new()
	logo.col = UI.SKY
	logo.edge = Color("0b1a3a")
	logo.custom_minimum_size = Vector2(320, 84)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(logo)
	var head := UI.label("Pause", 30, UI.ON_GLASS)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	if title != "":
		var sub := UI.label(title, 15, UI.ON_GLASS2)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sub)
	for i in ENTRIES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(row)
		var m := Mark.new()
		m.custom_minimum_size = Vector2(18, 48)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(m)
		marks.append(m)
		var b := UI.button(String(ENTRIES[i][0]), UI.ETH_BLUE if i == 0 else UI.INK2, 20)
		b.custom_minimum_size = Vector2(300, 48)
		var idx := i
		b.pressed.connect(func(): _press(idx))
		b.mouse_entered.connect(func(): _select(idx))
		row.add_child(b)
		buttons.append(b)
		var pad := Control.new()                 # as wide as the mark, so the button sits in the middle
		pad.custom_minimum_size = Vector2(18, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pad)
	var line := ColorRect.new()
	line.color = UI.GLASS_LINE
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	# the keys of both players
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	grid.add_child(UI.label("", 14, UI.ON_GLASS2))
	for i in 2:
		grid.add_child(UI.label(Game.name_of(i), 15, Color(String(KEYS.TAG_COLORS[i])).lightened(0.15)))
	for r in KEY_ROWS:
		grid.add_child(UI.label(String(r[0]), 14, UI.ON_GLASS2))
		for i in 2:
			grid.add_child(UI.label(String(KEYS.LABELS[i][r[1]]), 14, UI.ON_GLASS))
	var hint := UI.label("W/S oder Pfeiltasten wählen  ·  E oder Enter bestätigen  ·  Esc zurück ins Spiel", 12, UI.ON_GLASS2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_select(0)
	UI.pop_in(card, 0.0, 0.85)
	UI.sfx("pop")


func _select(i: int) -> void:
	sel = i
	for k in marks.size():
		(marks[k] as Mark).on = k == sel
		(marks[k] as Mark).queue_redraw()


func _press(i: int) -> void:
	if leaving:
		return
	var what := String(ENTRIES[i][1])
	if what == "resume":
		# E, Enter and Space are also the keys that interact: the game stays paused until that
		# press is over, or it would take it as an interaction the moment it runs again
		leaving = true
		await get_tree().process_frame
		await get_tree().process_frame
	emit_signal(what)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()        # no key reaches the game while the menu is open
	if event.echo or Engine.get_process_frames() - born < 2:
		return                                   # (the press that opened the menu is not for the menu)
	match event.physical_keycode:
		KEY_ESCAPE:
			resume.emit()
		KEY_W, KEY_UP:
			_select(posmod(sel - 1, buttons.size()))
			UI.sfx("tick")
		KEY_S, KEY_DOWN:
			_select(posmod(sel + 1, buttons.size()))
			UI.sfx("tick")
		KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			UI.sfx("click")
			_press(sel)
