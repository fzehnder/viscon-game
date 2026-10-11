extends Node
## Autoload "Game": story progress and the two players (names, Legi photos, looks).
## Story mode: levels run in order. Day and night are just level types.

const CH = preload("res://scripts/characters.gd")
const LV = preload("res://scripts/levels.gd")
const I18n = preload("res://scripts/i18n.gd")

# language of everything shown: "en" (default) or "de". The game is written in German; i18n.gd
# supplies the English. Saved with the game (section "settings"), kept by a new game.
var lang := "en"
var english: Translation = null
var english_on := false

var level := 1
var story_level := 1       # last story level that was started (electives do not count): "Weiterspielen"
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
# What happened in the electives of this game (one study), e.g. the freelance application:
# key -> any value. Kept across levels, cleared only by new_game().
var electives: Dictionary = {}
var save_path := "user://save.cfg"
var persist := true                   # --nosave on the command line: keep everything in memory

var names: Array = ["", ""]
var photos: Array = [null, null]      # Texture2D from the camera, or null (then the character is drawn)
var legi_ids: Array = ["26-622-806", "26-706-606"]
var birthdays: Array = ["01.11.2005", "06.06.2006"]
var programmes: Array = [0, 1]        # index into PROGRAMMES, chosen with the character design
var player_looks: Array = []

# study programmes to choose from: [name in the menu, how the Legi prints it]
const PROGRAMMES := [
	["Maschinenbau", "Mech. Engin BSc"], ["Informatik", "Comp. Science BSc"], ["Elektrotechnik", "Elec. Engin BSc"],
	["Bauingenieur", "Civil Engin BSc"], ["Architektur", "Architecture BSc"], ["Mathematik", "Mathematics BSc"],
	["Physik", "Physics BSc"], ["Chemie", "Chemistry BSc"], ["Biologie", "Biology BSc"],
	["Materialwiss.", "Mat. Science BSc"], ["Umweltingenieur", "Env. Engin BSc"], ["Gesundheit HST", "Hlth Sci Tech BSc"],
]


func _ready() -> void:
	randomize()
	player_looks = [_default_look(0), _default_look(1)]
	# dev shortcut, straight into a level: godot --path godot res://main.tscn -- --level=2
	var forced_lang := ""
	var forced_level := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level = int(a.trim_prefix("--level="))
			forced_level = true
		elif a == "--nosave":
			persist = false
		elif a.begins_with("--lang="):
			forced_lang = a.trim_prefix("--lang=")   # for testing: --lang=de or --lang=en
	load_game()
	if forced_lang != "":
		lang = forced_lang
	english = I18n.new()
	english.load_all()
	apply_lang()
	var saved_story := story_level   # from the save game: where "Weiterspielen" goes on
	_apply_level()
	if not forced_level and LV.has_level(saved_story) and not LV.is_elective(saved_story):
		story_level = saved_story


## The English is a script; Godot must let go of it before the scripts are freed at the end.
func _exit_tree() -> void:
	if english_on:
		TranslationServer.remove_translation(english)
		english_on = false


## Shows everything in `l` ("en" or "de") from now on and remembers it.
func set_lang(l: String) -> void:
	lang = "de" if l == "de" else "en"
	apply_lang()
	save_game()


func apply_lang() -> void:
	if lang == "en" and not english_on:
		TranslationServer.add_translation(english)
		english_on = true
	elif lang != "en" and english_on:
		TranslationServer.remove_translation(english)
		english_on = false
	# a change of locale makes every label translate itself again
	var other := "de" if lang == "en" else "en"
	TranslationServer.set_locale(other)
	TranslationServer.set_locale(lang)


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
	if not LV.is_elective(level):
		story_level = level
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
		if LV.order_of(int(opps[id]["level"])) < LV.order_of(n):   # earlier in the story
			ids.append(id)
	ids.sort_custom(func(a, b): return LV.order_of(int(opps[a]["level"])) < LV.order_of(int(opps[b]["level"])) or (int(opps[a]["level"]) == int(opps[b]["level"]) and a < b))
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
	if LV.is_elective(level):
		return   # an elective is outside the story, it does not undo anything
	var changed := false
	for id in opps.keys():
		if LV.order_of(int(opps[id]["level"])) >= LV.order_of(level):   # this level or later in the story
			opps.erase(id)
			changed = true
	for id in items.keys():
		if LV.order_of(int(items[id])) >= LV.order_of(level):
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


## State of an elective in this game (default if it has none yet).
func elective(key: String, default = null):
	return electives.get(key, default)


func set_elective(key: String, value) -> void:
	electives[key] = value
	save_game()


func new_game() -> void:
	opps.clear()
	grades.clear()
	items.clear()
	electives.clear()
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
	for key in electives:
		cfg.set_value("electives", key, electives[key])
	cfg.set_value("settings", "lang", lang)
	# who plays and how far the story got, so that "Weiterspielen" is still there after the game was closed
	# (the Legi photos are not kept: without one the Legi shows the drawn character)
	cfg.set_value("players", "names", names)
	cfg.set_value("players", "looks", player_looks)
	cfg.set_value("players", "programmes", programmes)
	cfg.set_value("players", "story_level", story_level)
	cfg.save(save_path)


func load_game() -> void:
	opps.clear()
	grades.clear()
	items.clear()
	electives.clear()
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	lang = String(cfg.get_value("settings", "lang", lang))
	var pn = cfg.get_value("players", "names", null)
	if pn is Array and pn.size() == 2:
		names = [String(pn[0]), String(pn[1])]
	var pl = cfg.get_value("players", "looks", null)
	if pl is Array and pl.size() == 2 and pl[0] is Dictionary and pl[1] is Dictionary:
		for i in 2:
			var look_i: Dictionary = _default_look(i)
			look_i.merge(pl[i] as Dictionary, true)
			player_looks[i] = look_i
	var pp = cfg.get_value("players", "programmes", null)
	if pp is Array and pp.size() == 2:
		programmes = [int(pp[0]), int(pp[1])]
	story_level = int(cfg.get_value("players", "story_level", story_level))
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
	if cfg.has_section("electives"):
		for key in cfg.get_section_keys("electives"):
			electives[key] = cfg.get_value("electives", key)


func reset_look(i: int) -> void:
	player_looks[i] = _default_look(i)


func look(i: int = 0) -> Dictionary:
	return player_looks[i]


func name_of(i: int) -> String:
	var n: String = String(names[i]).strip_edges()
	return n if n != "" else "Spieler*in %d" % (i + 1)


## The study programme as the Legi prints it.
func programme_of(i: int) -> String:
	return String(PROGRAMMES[int(programmes[i]) % PROGRAMMES.size()][1])


func has_profile() -> bool:
	return String(names[0]).strip_edges() != "" or String(names[1]).strip_edges() != ""
