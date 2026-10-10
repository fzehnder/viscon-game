extends Node
## Autoload "Game": story progress and the two players (names, Legi photos, looks).
## Story mode: levels run in order. Day and night are just level types.

const CH = preload("res://scripts/characters.gd")
const LV = preload("res://scripts/levels.gd")

var level := 1
var mode := "day"          # set from the level, never chosen by the player
var dept := "D-INFK"       # internal content set for quiz/Moodle texts and night content; not choosable

# Opps: people you have wronged. They stay Opps in later levels and are saved to disk.
# opp id -> {"name": String, "look": Dictionary, "level": int, "by": [player ids], "why": String}
var opps: Dictionary = {}
var save_path := "user://save.cfg"
var persist := true                   # --nosave on the command line: keep everything in memory

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
		elif a == "--nosave":
			persist = false
	load_game()
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


# ------------------------------------------------------------------ opps
func is_opp(id: String) -> bool:
	return opps.has(id)


## Remembers somebody as an Opp (made in the running level). Returns true if they are new.
func add_opp(id: String, pname: String, look: Dictionary, by: Array, why: String) -> bool:
	var fresh := not opps.has(id)
	opps[id] = {"name": pname, "look": look.duplicate(true), "level": level if fresh else int(opps[id]["level"]),
		"by": by.duplicate(), "why": why}
	(opps[id]["look"]["acc"] as Array).erase("loot")
	save_game()
	return fresh


## Ids of the Opps from earlier levels, oldest first.
func opps_before(n: int) -> Array:
	var ids: Array = []
	for id in opps:
		if int(opps[id]["level"]) < n:
			ids.append(id)
	ids.sort_custom(func(a, b): return int(opps[a]["level"]) < int(opps[b]["level"]) or (int(opps[a]["level"]) == int(opps[b]["level"]) and a < b))
	return ids


## A level starts (again): what happened in it and after it has not happened yet.
func begin_level() -> void:
	var changed := false
	for id in opps.keys():
		if int(opps[id]["level"]) >= level:
			opps.erase(id)
			changed = true
	if changed:
		save_game()


func new_game() -> void:
	opps.clear()
	save_game()
	set_level(1)


func save_game() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	for id in opps:
		cfg.set_value("opps", id, opps[id])
	cfg.save(save_path)


func load_game() -> void:
	opps.clear()
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK or not cfg.has_section("opps"):
		return
	for id in cfg.get_section_keys("opps"):
		var d = cfg.get_value("opps", id)
		if d is Dictionary and d.has("name") and d.has("look") and d.has("level"):
			d["by"] = d.get("by", [])
			opps[id] = d


func reset_look(i: int) -> void:
	player_looks[i] = _default_look(i)


func look(i: int = 0) -> Dictionary:
	return player_looks[i]


func name_of(i: int) -> String:
	var n: String = String(names[i]).strip_edges()
	return n if n != "" else "Spieler*in %d" % (i + 1)


func has_profile() -> bool:
	return String(names[0]).strip_edges() != "" or String(names[1]).strip_edges() != ""
