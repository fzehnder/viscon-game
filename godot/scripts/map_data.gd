extends RefCounted
## Builds the night-time ETH Zentrum: tiles, furniture, labels, lights and patrol routes.
## All coordinates are in tiles (1 tile = 32 px).

const W := 112
const H := 84
enum {GRASS, ROAD, WALK, PAVE, STONE, WOOD, WALL, MARBLE, TILE, ROOF, RAIL, CARPET, LAB}
const SOLID_TILES := [WALL, ROOF, RAIL]

var map: Array = []
var objs: Array = []
var doors: Array = []
var labels: Array = []
var lamps: Array = []
var zones: Array = []
var profs: Array = []
var rng := RandomNumberGenerator.new()
var mode := "night"
var dept := "MAVT"
var student_zones: Array = []
const CH = preload("res://scripts/characters.gd")
const LV = preload("res://scripts/levels.gd")


func gett(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return WALL
	return map[y * W + x]


func fill(x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	for y in range(maxi(0, y0), mini(H - 1, y1) + 1):
		for x in range(maxi(0, x0), mini(W - 1, x1) + 1):
			map[y * W + x] = t


func box(x0: int, y0: int, x1: int, y1: int, f: int) -> void:
	fill(x0, y0, x1, y1, WALL)
	fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, f)


func door(x0: int, y0: int, x1: int, y1: int, f: int) -> void:
	fill(x0, y0, x1, y1, f)
	doors.append(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))


func R(kind: String, x: float, y: float, w: float, h: float, extra: Dictionary = {}) -> Dictionary:
	var o := {"kind": kind, "rect": Rect2(x, y, w, h), "solid": true}
	o.merge(extra, true)
	objs.append(o)
	return o


func C(kind: String, cx: float, cy: float, r: float, extra: Dictionary = {}) -> Dictionary:
	var o := R(kind, cx - r, cy - r, r * 2.0, r * 2.0, extra)
	o["c"] = Vector2(cx, cy)
	o["r"] = r
	if o.has("hitr"):
		var hr: float = o["hitr"]
		o["hit"] = Rect2(cx - hr, cy - hr, hr * 2.0, hr * 2.0)
	return o


func L(text: String, x: float, y: float, sz: float, k: String, extra: Dictionary = {}) -> void:
	var l := {"t": text, "p": Vector2(x, y), "sz": sz, "k": k}
	l.merge(extra, true)
	labels.append(l)


func lamp(x: float, y: float, r: float, col: Color) -> void:
	lamps.append({"p": Vector2(x, y), "r": r, "col": col})


func build(p_mode: String = "night", p_dept: String = "MAVT") -> Dictionary:
	mode = p_mode
	dept = p_dept
	var night := mode == "night"
	rng.seed = 20261009
	map.resize(W * H)
	map.fill(GRASS)

	# --- streets ---
	fill(0, 12, 89, 13, WALK); fill(0, 18, 89, 19, WALK); fill(0, 14, 91, 17, ROAD)      # Tannenstrasse
	fill(90, 0, 91, H - 1, WALK); fill(98, 0, 99, H - 1, WALK); fill(92, 0, 97, H - 1, ROAD)  # Rämistrasse
	fill(34, 66, 89, 67, WALK); fill(34, 71, 89, 71, WALK); fill(34, 68, 91, 70, ROAD)   # Künstlergasse
	# neighbouring buildings (roofs)
	fill(3, 1, 27, 10, ROOF); fill(32, 1, 55, 10, ROOF); fill(60, 1, 87, 10, ROOF)
	fill(40, 74, 88, 83, ROOF)
	fill(101, 2, 110, 13, ROOF); fill(101, 20, 110, 36, ROOF); fill(101, 42, 110, 58, ROOF); fill(101, 64, 110, 80, ROOF)
	# Polyterrasse
	fill(10, 20, 37, 62, PAVE); fill(20, 63, 25, 63, PAVE)
	# Polybahn top station (exit)
	box(0, 36, 10, 46, STONE); fill(0, 37, 9, 40, RAIL); door(10, 42, 10, 44, STONE)
	# Mensa (open during the day)
	box(12, 64, 33, 77, TILE)
	if not night:
		door(21, 64, 24, 64, TILE)
	# Hauptgebäude
	box(38, 22, 87, 63, STONE)
	box(46, 30, 64, 55, MARBLE)
	door(46, 41, 46, 44, MARBLE); door(64, 41, 64, 44, MARBLE); door(54, 30, 56, 30, MARBLE); door(54, 55, 56, 55, MARBLE)
	box(68, 22, 87, 44, WOOD); door(68, 37, 68, 39, WOOD); door(87, 32, 87, 34, WOOD); fill(88, 32, 89, 34, PAVE)
	box(68, 47, 87, 63, LAB); door(68, 53, 68, 56, LAB)
	box(38, 22, 44, 28, STONE); door(44, 25, 44, 26, STONE)
	box(38, 56, 44, 63, STONE); door(44, 59, 44, 60, STONE)
	door(38, 40, 38, 44, STONE)
	door(58, 22, 60, 22, STONE); fill(57, 20, 61, 21, PAVE)
	door(56, 63, 58, 63, STONE); fill(55, 64, 59, 65, PAVE)

	# --- doors that are locked at night ---
	if night:
		_night_doors()

	_furniture()
	_dept_objects()
	_trees_labels_zones()
	_people()
	return {"W": W, "H": H, "map": map, "objs": objs, "doors": doors, "labels": labels,
		"lamps": lamps, "zones": zones, "profs": profs, "mode": mode, "dept": dept, "student_zones": student_zones}


func _night_doors() -> void:
	R("locked_door", 38, 40, 1, 5, {"door": "main", "use": "info", "label": "Haupteingang prüfen",
		"info": ["Abgeschlossen", "Die schwere Holztür zur Polyterrasse ist nachts verriegelt. Vielleicht ist der Hintereingang an der Künstlergasse offen."]})
	R("locked_door", 58, 22, 3, 1, {"door": "north", "use": "info", "label": "Nordeingang prüfen",
		"info": ["Abgeschlossen", "Der Eingang an der Tannenstrasse ist zu. Hier kommst du nicht rein."]})
	R("locked_door", 87, 32, 1, 3, {"door": "libeast", "use": "info", "label": "Bibliothekseingang prüfen",
		"info": ["Abgeschlossen", "Der Bibliothekseingang an der Rämistrasse ist verriegelt."]})
	var lab_labels := {"MAVT": "Labortür knacken", "ITET": "Labortür prüfen", "D-INFK": "Kartenleser hacken"}
	R("lab_door", 68, 53, 1, 4, {"door": "lab", "use": "labdoor", "label": lab_labels[dept]})
	R("mensa_shutter", 20.5, 63.1, 5, 0.7, {"solid": false, "use": "info", "label": "Mensa ansehen",
		"info": ["Mensa Polyterrasse", "Rollladen unten. Morgen gibt es Zürcher Geschnetzeltes – falls du die Nacht überstehst."]})


func _furniture() -> void:
	var night := mode == "night"
	# --- Polyterrasse ---
	R("rail", 10, 20, 0.3, 16.2); R("rail", 10, 46.8, 0.3, 16.2)
	for y in [26.0, 31.0, 52.0, 57.0]:
		R("bench", 13.5, y, 3, 0.7)
	for p in [Vector2(22, 25.5), Vector2(31, 25.5), Vector2(22, 34), Vector2(31, 34), Vector2(22, 50.5), Vector2(31, 50.5), Vector2(22, 58.5), Vector2(31, 58.5)]:
		C("planter", p.x, p.y, 1.05, {"hitr": 0.95, "use": "hide", "label": "Hinter dem Pflanzkübel ducken"} if night else {"hitr": 0.95})
	R("bikes", 12, 20.3, 6, 0.9); R("bikes", 28, 20.3, 7, 0.9)
	for p in [Vector2(18.5, 29), Vector2(18.5, 47.5), Vector2(34.5, 29), Vector2(34.5, 47.5), Vector2(26.5, 38), Vector2(26.5, 54)]:
		C("lamp", p.x, p.y, 0.22)
		lamp(p.x, p.y, 3.2, Color(1.0, 0.85, 0.5))
	R("scope", 10.5, 28.6, 0.8, 0.8, {"use": "info", "label": "Aussicht ansehen",
		"info": ["Zürich bei Nacht", "Die Altstadt leuchtet, die Türme des Grossmünsters, die Limmat. Ganz schön ruhig – bis auf deinen Puls."]})
	R("sign", 10.4, 40.6, 0.45, 1, {"use": "info", "label": "Polybahn-Schild lesen",
		"info": ["Polybahn", "Die rote Standseilbahn hinunter zum Central. Dein Fluchtweg – sobald du den USB-Stick hast."]})
	lamp(11.5, 43, 2.2, Color(1.0, 0.85, 0.5))
	# Polybahn station interior
	R("funi", 1.2, 37.3, 6.6, 2.4); R("edgeline", 0.9, 40.6, 9.1, 0.14, {"solid": false})
	R("bench", 1.6, 44.7, 3, 0.6); R("ticket", 8.4, 44.6, 0.9, 0.7)

	# --- HG corridors ---
	R("board", 39, 34.4, 0.35, 3.4, {"use": "info", "label": "Anschlagbrett lesen",
		"info": ["Anschlagbrett", "«Polyball – Tickets ab Montag.» Daneben: «Labor HG Ost – Robotik. Nachts verschlossen, Schloss elektronisch über den Sicherungskasten im Gang. – Der Hauswart»"]})
	for p in [Vector2(39.7, 32.8), Vector2(66.6, 23.7), Vector2(39.7, 54.4), Vector2(66.6, 62.3), Vector2(85.9, 45.6)]:
		C("plant", p.x, p.y, 0.36)
	R("bench", 48, 23.2, 3, 0.6); R("bench", 61.5, 23.2, 3, 0.6); R("bench", 48, 62.2, 3, 0.6); R("bench", 61, 62.2, 3, 0.6)
	for p in [Vector2(42, 35), Vector2(42, 49), Vector2(56, 26), Vector2(56, 59), Vector2(66, 34), Vector2(66, 50), Vector2(77, 45.5)]:
		lamp(p.x, p.y, 2.6, Color(0.75, 0.85, 1.0))
	# Haupthalle
	for y in [33.5, 37.0, 48.5, 52.0]:
		C("pillar", 48.6, y, 0.45); C("pillar", 62.4, y, 0.45)
	R("bench", 50.2, 38.3, 3, 0.7); R("bench", 57.8, 38.3, 3, 0.7); R("bench", 50.2, 46.6, 3, 0.7); R("bench", 57.8, 46.6, 3, 0.7)
	R("bust", 54.7, 32.2, 1.6, 1.3, {"use": "info", "label": "Tafel lesen",
		"info": ["Hauptgebäude", "Gottfried Semper baute hier das Polytechnikum, fertig 1864. Die Kuppel über dieser Halle kam später von Gustav Gull."]})
	R("infodesk", 53.4, 50, 4.2, 1.3, {"use": "hide", "label": "Hinter der Infotheke verstecken"} if night else {})
	lamp(55.5, 42.5, 5.5, Color(0.7, 0.8, 1.0))
	# Seminar room
	R("desk", 39.6, 23.6, 3.6, 0.7, {"pc": true}); R("desk", 39.6, 25.9, 3.6, 0.7, {"use": "hide", "label": "Unter das Pult kriechen"} if night else {})
	# Study lounge
	R("sofa", 39.2, 57.2, 3.0, 1.0, {"use": "hide", "label": "Hinter das Sofa ducken"} if night else {})
	R("ctable", 40.0, 59.0, 1.8, 0.9)
	R("sofa", 39.2, 61.8, 3.0, 1.0, {"flip": true})
	R("coffee", 42.5, 57.2, 1.0, 0.8, {"use": "info", "label": "Kaffeemaschine benutzen",
		"info": ["Kaffeemaschine", "Sie röchelt laut. Sehr laut. Vielleicht keine gute Idee um ein Uhr nachts."]})

	# --- ETH-Bibliothek ---
	R("cabinet", 69.3, 23.6, 3.9, 1.15, {"use": "info", "label": "Max Frisch-Archiv ansehen",
		"info": ["Max Frisch-Archiv", "Manuskripte und Tagebücher des Zürcher Schriftstellers, der an der ETH Architektur studiert hat."]})
	R("cabinet", 69.3, 26.7, 3.9, 1.15, {"use": "info", "label": "Thomas-Mann-Archiv ansehen",
		"info": ["Thomas-Mann-Archiv", "Nachlass und Arbeitszimmer von Thomas Mann, seit 1956 bei der ETH Zürich."]})
	R("catalog", 69.3, 29.8, 3.9, 1.0, {"use": "moodle_prep", "label": "Moodle öffnen (Wartungspasswort finden)"} if (night and dept == "D-INFK") else {})
	var shelf_cats := [[75, 24, "Mathematik"], [80.8, 24, "Physik"], [75, 27, "Informatik"], [80.8, 27, "Architektur"], [75, 30, "Chemie"], [80.8, 30, "Geschichte"]]
	for s in shelf_cats:
		R("shelf", s[0], s[1], 4.2, 0.9, {"cat": s[2]})
	for p in [Vector2(75, 34.2), Vector2(80.8, 34.2), Vector2(75, 38.4), Vector2(80.8, 38.4)]:
		R("rtable", p.x, p.y, 3.6, 1.2, {"use": "hide", "label": "Unter den Lesetisch kriechen"} if night else {})
		for dx in [0.4, 2.3]:
			R("chair", p.x + dx, p.y - 0.78, 0.66, 0.55, {"solid": false})
			R("chair", p.x + dx, p.y + 1.28, 0.66, 0.55, {"solid": false})
		lamp(p.x + 0.9, p.y + 0.6, 1.6, Color(1.0, 0.85, 0.45))
		lamp(p.x + 2.7, p.y + 0.6, 1.6, Color(1.0, 0.85, 0.45))
	R("counter", 69.3, 41, 3.5, 0.95)
	R("lockers", 75, 42.25, 10.2, 0.7, {"use": "hide", "label": "In einen Spind steigen"} if night else {})
	C("plant", 86.3, 23.7, 0.4); C("plant", 86.3, 43.2, 0.4); C("plant", 73.6, 42.9, 0.38)
	lamp(71, 40, 1.8, Color(0.6, 0.85, 1.0))

	# --- Labor (Robotik) ---
	for p in [Vector2(71, 48.4), Vector2(79, 48.4), Vector2(71, 51.0), Vector2(79, 51.0), Vector2(71, 57.6), Vector2(79, 57.6), Vector2(71, 60.6), Vector2(79, 60.6)]:
		R("labbench", p.x, p.y, 6.0, 1.1)
		lamp(p.x + 1.5, p.y + 0.5, 1.2, Color(0.4, 0.8, 1.0))
		lamp(p.x + 4.5, p.y + 0.5, 1.2, Color(0.5, 1.0, 0.7))
	C("robot", 78.0, 52.6, 0.45, {"hitr": 0.4})
	R("rack", 85.6, 48.2, 1.2, 3.0)
	R("labdesk", 85.3, 53.6, 1.5, 2.8)
	R("locker", 69.2, 59.2, 1.2, 3.4, {"use": "hide", "label": "Im Laborschrank verstecken"} if night else {})
	R("fusebox", 67.5, 48.3, 0.45, 1.3, {"solid": false})
	lamp(85.9, 55.0, 2.0, Color(0.5, 0.75, 1.0))



func _dept_objects() -> void:
	if mode == "night":
		match dept:
			"MAVT":
				R("toolbox", 42.2, 23.62, 0.95, 0.6, {"solid": false, "use": "prep", "label": "Dietrich-Set aus der Werkzeugkiste nehmen"})
			"ITET":
				R("plan", 70.1, 41.12, 0.75, 0.5, {"solid": false, "use": "prep", "label": "Schaltplan einstecken"})
		var items := {"MAVT": ["gear", "Prototyp-Getriebe nehmen"], "ITET": ["disk", "Festplatte mit Messdaten nehmen"], "D-INFK": ["usb", "USB-Stick nehmen"]}
		R("goal", 85.55, 54.7, 0.6, 0.5, {"solid": false, "use": "goal", "item": items[dept][0], "label": items[dept][1]})
		if dept == "ITET":
			for o in objs:
				if o["kind"] == "fusebox":
					o["use"] = "fusebox"
					o["label"] = "Sicherungskasten verdrahten"
	else:
		# Level 1 (day, co-op): every task with fixed places gets one station per spot (levels.gd)
		for tk in LV.tasks():
			if not tk.has("spots"):
				continue
			for r in tk["spots"]:
				var rr: Rect2 = r
				R(String(tk.get("kind", "station")), rr.position.x, rr.position.y, rr.size.x, rr.size.y,
					{"solid": false, "use": "station", "task": tk["id"], "label": tk["label"]})


func _trees_labels_zones() -> void:
	# --- Mensa (visible through the windows) ---
	R("mcounter", 14, 75.1, 18, 0.95)
	for x in [16.0, 20.6, 26.6, 30.6]:
		for y in [67.8, 71.4]:
			C("mtable", x, y, 0.75, {"hitr": 0.65})

	# --- street lamps ---
	for y in range(4, 82, 9):
		lamp(90.6, y, 3.0, Color(1.0, 0.8, 0.45))
	for x in range(6, 90, 11):
		lamp(x, 12.6, 3.0, Color(1.0, 0.8, 0.45))
	for x in range(38, 90, 12):
		lamp(x, 66.6, 2.8, Color(1.0, 0.8, 0.45))

	# --- trees ---
	var y_tree := 21.0
	while y_tree <= 64.0:
		C("tree", 88.9, y_tree, 0.95, {"hitr": 0.32})
		y_tree += 3.6
	y_tree = 4.0
	while y_tree <= 80.0:
		C("tree", 100.2, y_tree, 0.8, {"hitr": 0.3})
		y_tree += 5.5
	var placed: Array = []
	var tries := 0
	while tries < 900 and placed.size() < 70:
		tries += 1
		var x := 1.0 + rng.randf() * (W - 2)
		var y := 1.0 + rng.randf() * (H - 2)
		var ok := true
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if gett(int(x) + dx, int(y) + dy) != GRASS:
					ok = false
		if not ok:
			continue
		for t in placed:
			if (t as Vector2).distance_to(Vector2(x, y)) < 2.6:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector2(x, y))
		C("tree", x, y, 0.7 + rng.randf() * 0.45, {"hitr": 0.3})

	# --- labels ---
	L("POLYTERRASSE", 23.5, 41.6, 1.1, "floor")
	L("HAUPTHALLE", 55.5, 42.9, 0.85, "floor")
	L("ETH-BIBLIOTHEK", 78, 32.3, 0.7, "floor")
	L("LABOR · ROBOTIK", 77.5, 56.7, 0.6, "floor")
	L("SEMINAR", 41.5, 27.6, 0.42, "floor")
	L("LOUNGE", 41.0, 60.5, 0.42, "floor")
	L("MENSA POLYTERRASSE", 23, 73.6, 0.7, "floor")
	L("POLYBAHN", 5, 42.9, 0.62, "floor")
	L("HAUPTGEBÄUDE", 42, 47, 0.6, "floor", {"rot": -PI / 2})
	L("TANNENSTRASSE", 46, 16.05, 0.6, "street")
	L("TANNENSTRASSE", 78, 16.05, 0.6, "street")
	L("RÄMISTRASSE", 95, 22, 0.6, "street", {"rot": -PI / 2})
	L("RÄMISTRASSE", 95, 62, 0.6, "street", {"rot": -PI / 2})
	L("KÜNSTLERGASSE", 63, 69.55, 0.55, "street")
	L("ML", 15, 5.2, 1.3, "roof", {"sub": "MASCHINENLABORATORIUM"})
	L("CAB", 43.5, 5.2, 1.3, "roof", {"sub": "INFORMATIK"})
	L("CHN", 73.5, 5.2, 1.3, "roof", {"sub": "ETH ZENTRUM"})
	L("UNIVERSITÄT ZÜRICH", 64, 78.2, 1.1, "roof", {"sub": "NACHBARIN"})

	# --- zones (first match wins) ---
	zones = [
		[Rect2(69, 23, 18, 21), "ETH-Bibliothek"], [Rect2(69, 48, 18, 15), "Labor · Robotik"],
		[Rect2(47, 31, 17, 24), "Haupthalle"], [Rect2(39, 23, 5, 5), "Seminarraum"], [Rect2(39, 57, 5, 6), "Lounge"],
		[Rect2(38, 22, 50, 42), "Hauptgebäude (HG)"], [Rect2(0, 36, 11, 11), "Polybahn"],
		[Rect2(12, 64, 22, 14), "Mensa Polyterrasse"], [Rect2(10, 20, 28, 44), "Polyterrasse"],
		[Rect2(90, 0, 10, 84), "Rämistrasse"], [Rect2(0, 12, 90, 8), "Tannenstrasse"],
		[Rect2(34, 64, 58, 9), "Künstlergasse"], [Rect2(0, 20, 10, 44), "Hang zur Altstadt"],
	]



func _people() -> void:
	student_zones = [[11, 21, 36, 61, 7], [47, 31, 63, 54, 4], [39, 32, 45, 53, 2], [46, 23, 67, 29, 2], [46, 56, 67, 62, 2],
		[13, 65, 32, 74, 4], [0, 18, 89, 19, 3], [90, 0, 91, 83, 2], [74, 25, 86, 26, 1], [74, 31, 86, 33, 2], [34, 66, 89, 67, 2]]
	if mode == "day":
		profs = [{"name": CH.DEPTS[dept]["prof"], "static": true, "pts": [Vector2(55.5, 36.4)], "quote": ""}]
		return
	# --- professors on night duty (fictional) ---
	profs = [
		{"name": "Prof. Dr. Brunner", "speed": 48.0, "range": 6.5, "hair": "d8d4cc", "coat": "6b4f3a",
			"quote": "Um diese Zeit in der Haupthalle? Das gibt einen Eintrag ins Protokoll!",
			"pts": [Vector2(49.5, 33.5), Vector2(61.5, 33.5), Vector2(61.5, 52.5), Vector2(49.5, 52.5)]},
		{"name": "Prof. Dr. Keller", "speed": 56.0, "range": 6.5, "hair": "3b2a1e", "coat": "39465a",
			"quote": "Halt! Was suchen Sie um ein Uhr nachts im Hauptgebäude?",
			"pts": [Vector2(41.5, 31.5), Vector2(41.5, 54.5), Vector2(56.5, 59.5), Vector2(66.5, 59.5), Vector2(66.5, 26.5), Vector2(50.5, 26.5)]},
		{"name": "Prof. Dr. Meier", "speed": 42.0, "range": 6.0, "hair": "c9c4ba", "coat": "5d6b4a",
			"quote": "Psst! In der Bibliothek wird nicht eingebrochen. Raus hier!",
			"pts": [Vector2(74.5, 25.5), Vector2(86.5, 25.5), Vector2(86.5, 32.5), Vector2(74.5, 32.5), Vector2(73.5, 39.5), Vector2(70.5, 39.5)]},
		{"name": "Prof. Dr. Huber", "speed": 40.0, "range": 7.5, "hair": "e8e4dc", "coat": "e9ece8", "pmin": 2.5, "pmax": 4.5,
			"quote": "Finger weg von meinem Labor! Ihre Bachelorarbeit besprechen wir morgen früh.",
			"pts": [Vector2(71.5, 55.5), Vector2(84.0, 55.5)]},
		{"name": "Prof. Dr. Widmer", "speed": 58.0, "range": 6.5, "hair": "6b5040", "coat": "2f4f6f",
			"quote": "Grüezi und gute Nacht. Ihre Legi, bitte.",
			"pts": [Vector2(13.5, 28.5), Vector2(35.5, 28.5), Vector2(35.5, 60.5), Vector2(36.5, 66.5), Vector2(60.5, 66.5), Vector2(36.5, 66.5), Vector2(35.5, 47.5), Vector2(13.5, 54.5)]},
	]

