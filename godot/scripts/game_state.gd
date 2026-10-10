extends Node
## Autoload "Game": story progress and the two players (names, Legi photos, looks).
## Story mode: levels run in order. Day and night are just level types.

const CH = preload("res://scripts/characters.gd")
const LV = preload("res://scripts/levels.gd")

var level := 1
var mode := "day"          # set from the level, never chosen by the player
var dept := "D-INFK"       # internal content set for quiz/Moodle texts and night content; not choosable

var names: Array = ["", ""]
var photos: Array = [null, null]      # Texture2D from the camera, or null (then the character is drawn)
var legi_ids: Array = ["", ""]
var player_looks: Array = []


func _ready() -> void:
	randomize()
	player_looks = [_default_look(0), _default_look(1)]
	for i in 2:
		legi_ids[i] = "26-%03d-%03d" % [randi_range(900, 999), randi_range(100, 999)]
	# dev shortcut, straight into a level: godot --path godot res://main.tscn -- --level=2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = int(a.trim_prefix("--level="))
	_apply_level()


func _default_look(i: int) -> Dictionary:
	var base: Dictionary = (CH.DEPTS["MAVT" if i == 0 else "D-INFK"]["look"] as Dictionary).duplicate(true)
	base["acc"] = ["backpack"]
	if base.get("top_style", "") == "overall":
		base["top_style"] = "tshirt"
	return base


func _apply_level() -> void:
	if not LV.has_level(level):
		level = 1
	LV.current = level
	mode = String(LV.level().get("mode", "day"))


func set_level(n: int) -> void:
	level = n
	_apply_level()


func reset_look(i: int) -> void:
	player_looks[i] = _default_look(i)


func look(i: int = 0) -> Dictionary:
	return player_looks[i]


func name_of(i: int) -> String:
	var n: String = String(names[i]).strip_edges()
	return n if n != "" else "Spieler*in %d" % (i + 1)


func has_profile() -> bool:
	return String(names[0]).strip_edges() != "" or String(names[1]).strip_edges() != ""
