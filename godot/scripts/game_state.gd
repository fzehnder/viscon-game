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
# Grades: the best grade per level that was won, shown in the transcript (transcript.gd) and saved to disk.
# level number -> {"grade": float, "time": int (seconds), "mistakes": int}
var grades: Dictionary = {}
# Things the players carry from level to level (e.g. "prof_badge" from the Polyball).
# item id -> level in which they got it
var items: Dictionary = {}
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
	for carried in ["loot", "erstibag"]:   # remembered as they look without the bag they carried home
		(opps[id]["look"]["acc"] as Array).erase(carried)
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


# ------------------------------------------------------------------ items
func has_item(id: String) -> bool:
	return items.has(id)


## Remembers something the players got hold of in the running level, also for later levels.
func add_item(id: String) -> void:
	items[id] = level
	save_game()


## A level starts (again): what happened in it and after it has not happened yet.
func begin_level() -> void:
	var changed := false
	for id in opps.keys():
		if int(opps[id]["level"]) >= level:
			opps.erase(id)
			changed = true
	for id in items.keys():
		if int(items[id]) >= level:
			items.erase(id)
			changed = true
	if changed:
		save_game()


## Remembers the grade of a level that was just won. Only the best one counts; returns true if this is it.
func add_grade(n: int, grade: float, time: int, mistakes: int) -> bool:
	if grades.has(n) and float(grades[n]["grade"]) >= grade:
		return false
	grades[n] = {"grade": grade, "time": time, "mistakes": mistakes}
	save_game()
	return true


## Best grade of level `n`, or 0.0 if it has never been won.
func grade_of(n: int) -> float:
	return float(grades[n]["grade"]) if grades.has(n) else 0.0


func new_game() -> void:
	opps.clear()
	grades.clear()
	items.clear()
	save_game()
	set_level(1)


func save_game() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	for id in opps:
		cfg.set_value("opps", id, opps[id])
	for n in grades:
		cfg.set_value("grades", str(n), grades[n])
	for id in items:
		cfg.set_value("items", id, items[id])
	cfg.save(save_path)


func load_game() -> void:
	opps.clear()
	grades.clear()
	items.clear()
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	if cfg.has_section("opps"):
		for id in cfg.get_section_keys("opps"):
			var d = cfg.get_value("opps", id)
			if d is Dictionary and d.has("name") and d.has("look") and d.has("level"):
				d["by"] = d.get("by", [])
				opps[id] = d
	if cfg.has_section("grades"):
		for key in cfg.get_section_keys("grades"):
			var g = cfg.get_value("grades", key)
			if g is Dictionary and g.has("grade"):
				grades[int(key)] = g
	if cfg.has_section("items"):
		for id in cfg.get_section_keys("items"):
			items[id] = int(cfg.get_value("items", id))


func reset_look(i: int) -> void:
	player_looks[i] = _default_look(i)


func look(i: int = 0) -> Dictionary:
	return player_looks[i]


func name_of(i: int) -> String:
	var n: String = String(names[i]).strip_edges()
	return n if n != "" else "Spieler*in %d" % (i + 1)


func has_profile() -> bool:
	return String(names[0]).strip_edges() != "" or String(names[1]).strip_edges() != ""
