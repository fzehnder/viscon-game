extends Translation
## English for the whole game. The game is written in German; this Translation hands Godot the
## English text for every German one while the language is English (Game.lang, toggle on the
## start page). Labels, buttons and rich text translate themselves; text that is drawn with
## draw_string or typed letter by letter goes through tr() (or UI.T() where there is no node).
##
## The English lives next to the German, as `const EN := {"German": "English", ...}`:
##   scripts/i18n_en.gd             everything outside the level folders
##   scripts/level<N>/en.gd         one per level folder (found by itself, like the levels)
## Keys are the German strings exactly as they stand in the code (same escapes).
##
## How a text is found, in this order:
##   1. exactly as a key
##   2. as a key with format codes: "%s hat dich gesehen" also covers "Lea hat dich gesehen".
##      The English uses the same codes in the same order, or {1}, {2}, ... for another order.
##      What %s stands for is translated as well (a task name inside a sentence).
##   3. line by line, for texts put together from several lines. So a German key with line
##      breaks needs an English one with just as many lines.
## Whatever is not found stays German. tools/i18n_check.py lists German text without English.

const MAX_LEVEL := 20
const CORE := "res://scripts/i18n_en.gd"
const SPEC := "%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdfxXc]"

var exact: Dictionary = {}      # German -> English
var patterns: Array = []        # [literal prefix, RegEx, English, codes]
var memo: Dictionary = {}
var spec_re := RegEx.new()


func _init() -> void:
	locale = "en"
	spec_re.compile(SPEC)


## Reads the English of the core and of every level folder.
func load_all() -> void:
	exact.clear()
	patterns.clear()
	memo.clear()
	var files: Array = [CORE]
	for n in range(1, MAX_LEVEL + 1):
		files.append("res://scripts/level%d/en.gd" % n)
	for path in files:
		if not ResourceLoader.exists(path):
			continue
		var scr = load(path)
		if scr == null or not ("EN" in scr.get_script_constant_map()):
			continue
		var d: Dictionary = scr.get_script_constant_map()["EN"]
		for k in d:
			add(String(k), String(d[k]))
	# the most specific first: "%s hat dich gesehen" before "%s: %s"
	patterns.sort_custom(func(a, b): return int(a[4]) > int(b[4]))


func add(de: String, en: String) -> void:
	exact[de] = en
	if spec_re.search(de) != null:
		_add_pattern(de, en)
	# keys with several lines also count line by line (step 3)
	if de.contains("\n"):
		var dl := de.split("\n")
		var el := en.split("\n")
		if dl.size() == el.size():
			for i in dl.size():
				var d := dl[i].strip_edges()
				if d != "" and not exact.has(d):
					exact[d] = el[i].strip_edges()
					if spec_re.search(d) != null:
						_add_pattern(d, el[i].strip_edges())


func _add_pattern(de: String, en: String) -> void:
	# how much fixed text there is around the codes; nothing at all ("%s", "%s\n%s") would match anything
	var fixed := spec_re.sub(de, "", true).strip_edges()
	if fixed == "" and not de.contains("   "):
		return
	var rx := "^"
	var codes: Array = []
	var last := 0
	var ms := spec_re.search_all(de)
	for k in ms.size():
		var m: RegExMatch = ms[k]
		rx += _escape(de.substr(last, m.get_start() - last))
		var code := de[m.get_end() - 1]
		codes.append(code)
		if code == "d" or code == "x" or code == "X":
			rx += "([-+]?[0-9a-fA-F]+)"
		elif code == "f":
			rx += "([-+]?[0-9]*\\.?[0-9]+)"
		elif k == ms.size() - 1:
			rx += "(.*)"
		else:
			rx += "(.*?)"
		last = m.get_end()
	rx += _escape(de.substr(last)) + "$"
	var re := RegEx.new()
	if re.compile("(?s)" + rx) != OK:
		return
	var prefix := de.substr(0, ms[0].get_start()) if ms.size() > 0 else de
	patterns.append([prefix, re, en, codes, fixed.length(), de.contains("\n")])


func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		if "\\^$.|?*+()[]{}".contains(ch):
			out += "\\" + ch
		else:
			out += ch
	return out


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	return StringName(translate_text(String(src_message)))


func translate_text(s: String, depth: int = 0) -> String:
	if s.length() < 2 or not _has_letters(s):   # numbers, times, symbols: nothing to translate
		return s
	if memo.has(s):
		return memo[s]
	var out = exact.get(s)
	if out == null:
		# the same with spaces around it
		var core := s.strip_edges()
		if core != s and core != "":
			var t := translate_text(core, depth + 1)
			if t != core:
				var start := s.find(core)
				out = s.substr(0, start) + t + s.substr(start + core.length())
	if out == null:
		out = _match_pattern(s, depth)
	if out == null and s.contains("\n") and depth < 4:
		var lines := s.split("\n")
		var changed := false
		for i in lines.size():
			var t2 := translate_text(lines[i], depth + 1)
			if t2 != lines[i]:
				lines[i] = t2
				changed = true
		if changed:
			out = "\n".join(lines)
	if out == null:
		out = s
	if memo.size() > 6000:
		memo.clear()
	if depth == 0:
		memo[s] = out
	return out


func _match_pattern(s: String, depth: int):
	if depth > 3:
		return null
	var lines := s.contains("\n")
	for p in patterns:
		if not s.begins_with(p[0]):
			continue
		if lines and not p[5]:
			continue   # a text with several lines only matches a key with several lines, else line by line
		var m: RegExMatch = (p[1] as RegEx).search(s)
		if m == null:
			continue
		var caps: Array = []
		for g in range(1, m.get_group_count() + 1):
			var c := m.get_string(g)
			if (p[3] as Array)[g - 1] == "s":
				c = translate_text(c, depth + 1)
			caps.append(c)
		return _fill(String(p[2]), caps)
	return null


## Puts the parts into the English: {1}, {2}, ... if it has them, otherwise the codes in order.
func _fill(en: String, caps: Array) -> String:
	if en.contains("{1}"):
		for i in caps.size():
			en = en.replace("{%d}" % (i + 1), caps[i])
		return en
	var out := ""
	var last := 0
	var k := 0
	for m in spec_re.search_all(en):
		out += en.substr(last, m.get_start() - last)
		out += caps[k] if k < caps.size() else ""
		k += 1
		last = m.get_end()
	return out + en.substr(last)


func _has_letters(s: String) -> bool:
	for ch in s:
		if ch.to_lower() != ch.to_upper():
			return true
	return false
