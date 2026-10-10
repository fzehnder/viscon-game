extends RefCounted
## Builds the ETH Zentrum: tiles, furniture, labels, lights and patrol routes.
## All coordinates are in tiles (1 tile = 32 px). North is up, the Polyterrasse lies to the west
## of the Hauptgebäude, Rämistrasse to the east.
##
## The Hauptgebäude (x 38..87, y 20..71) follows the real ground floor (E-Geschoss), simplified:
##   - main block (x 38..68, y 22..69) with the west entrance from the Polyterrasse, corner
##     pavilions and a centre part that stand out from the facade by one tile
##   - the Haupthalle band (rows 43..48) runs from the west entrance through the building and
##     ends in the rotunda, which bulges into the forecourt towards Rämistrasse
##   - north and south of it "E Nord" and "E Süd": a big lecture hall (E1 / E7), a small one
##     with rounded corners next to the Haupthalle (E3 / E5), foyers and passages around them
##   - a ring of corridors (rows 27..28 and 63..64, columns 44..45 and 66..67), rooms along
##     the outside, north and south entrances in the middle of those sides
##   - two wings to the east with end pavilions: library in the north, lab in the south
## The south half mirrors the north half: row y corresponds to row 91 - y.

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
	fill(34, 72, 89, 73, WALK); fill(34, 77, 89, 77, WALK); fill(34, 74, 91, 76, ROAD)   # Künstlergasse
	# neighbouring buildings (roofs)
	fill(3, 1, 27, 10, ROOF); fill(32, 1, 55, 10, ROOF); fill(60, 1, 87, 10, ROOF)
	fill(40, 79, 88, 83, ROOF)
	fill(101, 2, 110, 13, ROOF); fill(101, 20, 110, 36, ROOF); fill(101, 42, 110, 58, ROOF); fill(101, 64, 110, 80, ROOF)
	# Polyterrasse
	fill(10, 20, 37, 62, PAVE); fill(20, 63, 25, 63, PAVE)
	# Polybahn top station (exit)
	box(0, 36, 10, 46, STONE); fill(0, 37, 9, 40, RAIL); door(10, 42, 10, 44, STONE)
	# Mensa (open during the day)
	box(12, 64, 33, 77, TILE)
	if not night:
		door(21, 64, 24, 64, TILE)
	_hauptgebaeude()

	# --- doors that are locked at night ---
	if night:
		_night_doors()

	_furniture()
	_dept_objects()
	_trees_labels_zones()
	_people()
	LV.build_map(self)   # the running level may add or replace furniture
	return {"W": W, "H": H, "map": map, "objs": objs, "doors": doors, "labels": labels,
		"lamps": lamps, "zones": zones, "profs": profs, "mode": mode, "dept": dept, "student_zones": student_zones}


## Fills a rectangle and its mirror image in the south half of the Hauptgebäude.
func mfill(x0: int, y0: int, x1: int, y1: int, t: int) -> void:
	fill(x0, y0, x1, y1, t)
	fill(x0, 91 - y1, x1, 91 - y0, t)


func mdoor(x0: int, y0: int, x1: int, y1: int, f: int) -> void:
	door(x0, y0, x1, y1, f)
	door(x0, 91 - y1, x1, 91 - y0, f)


func _hauptgebaeude() -> void:
	# main block
	fill(38, 22, 68, 69, WALL)
	fill(39, 23, 67, 68, STONE)
	# west facade: corner pavilions and the centre stand out, the parts between are set back
	mfill(38, 28, 38, 41, PAVE)
	mfill(39, 28, 39, 41, WALL)
	# forecourt towards Rämistrasse, between the two wings
	fill(69, 36, 89, 55, PAVE)
	# north wing with pavilion: library. South wing with pavilion: lab.
	fill(69, 26, 87, 35, WALL); fill(69, 27, 86, 34, WOOD)
	fill(77, 20, 87, 26, WALL); fill(78, 21, 86, 25, WOOD); fill(80, 26, 84, 26, WOOD)
	fill(69, 56, 87, 65, WALL); fill(69, 57, 86, 64, LAB)
	fill(77, 65, 87, 71, WALL); fill(78, 66, 86, 70, LAB); fill(80, 65, 84, 65, LAB)
	# rotunda: half a circle in front of the east wall of the main block
	for y in range(38, 55):
		for x in range(69, 77):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(68.5, 46.0))
			if d <= 5.6:
				map[y * W + x] = MARBLE
			elif d <= 6.6:
				map[y * W + x] = WALL

	# rooms along the west side (wall towards the west corridor: column 43)
	mfill(43, 22, 43, 42, WALL)
	mfill(39, 28, 43, 28, WALL)
	mfill(40, 34, 43, 34, WALL)
	mfill(38, 42, 43, 42, WALL)
	mdoor(43, 27, 43, 27, STONE); mdoor(43, 31, 43, 31, STONE); mdoor(43, 38, 43, 38, STONE)
	# rooms along the north side, entrance in the middle (and the same in the south)
	mfill(43, 26, 67, 26, WALL)
	mfill(51, 23, 51, 25, WALL); mfill(55, 23, 55, 25, WALL); mfill(61, 23, 61, 25, WALL)
	mdoor(47, 26, 47, 26, STONE); mdoor(52, 26, 54, 26, STONE); mdoor(58, 26, 58, 26, STONE); mdoor(64, 26, 64, 26, STONE)
	mdoor(52, 22, 54, 22, STONE)
	mfill(51, 20, 55, 21, PAVE)
	# inner walls of the corridor ring
	mfill(46, 29, 65, 29, WALL)
	mfill(46, 29, 46, 42, WALL)
	mfill(65, 29, 65, 42, WALL)
	mfill(46, 42, 65, 42, WALL)
	# rooms between the courtyard and the east corridor
	mfill(60, 29, 60, 42, WALL)
	mfill(61, 30, 64, 41, WOOD)
	mfill(61, 35, 64, 35, WALL)
	mdoor(65, 32, 65, 32, WOOD); mdoor(65, 38, 65, 38, WOOD)
	# E Nord / E Süd: big lecture hall, small hall with rounded corners, passages on both sides
	mfill(49, 29, 57, 35, WALL); mfill(50, 30, 56, 34, WOOD)
	mfill(50, 34, 51, 34, WALL); mfill(55, 34, 56, 34, WALL)   # the stage is a niche, the seats fan out from it
	mfill(49, 38, 57, 42, WALL); mfill(50, 39, 56, 41, WOOD)
	mfill(50, 39, 50, 39, WALL); mfill(56, 39, 56, 39, WALL)
	mdoor(49, 32, 49, 32, WOOD); mdoor(57, 32, 57, 32, WOOD)
	mdoor(53, 38, 53, 38, WOOD); mdoor(54, 42, 54, 42, WOOD)
	mdoor(47, 29, 48, 29, STONE); mdoor(58, 29, 59, 29, STONE)
	mdoor(47, 42, 48, 42, STONE); mdoor(58, 42, 59, 42, STONE)
	# Haupthalle band: entrance hall in the west, hall, then through the east wall into the rotunda
	fill(46, 43, 67, 48, MARBLE)
	door(38, 44, 38, 47, STONE)
	fill(68, 44, 68, 47, MARBLE)
	door(74, 45, 74, 46, MARBLE)
	# wings: library and lab open off the corridor ring, the library also towards Rämistrasse
	door(68, 27, 68, 28, WOOD)
	door(68, 63, 68, 64, LAB)
	door(87, 30, 87, 31, WOOD); fill(88, 30, 89, 31, PAVE)


func _night_doors() -> void:
	R("locked_door", 38, 44, 1, 4, {"door": "main", "use": "info", "label": "Haupteingang prüfen",
		"info": ["Abgeschlossen", "Die schwere Holztür zur Polyterrasse ist nachts verriegelt. Vielleicht ist der Hintereingang an der Künstlergasse offen."]})
	R("locked_door", 52, 22, 3, 1, {"door": "north", "use": "info", "label": "Nordeingang prüfen",
		"info": ["Abgeschlossen", "Der Eingang an der Tannenstrasse ist zu. Hier kommst du nicht rein."]})
	R("locked_door", 74, 45, 1, 2, {"door": "east", "use": "info", "label": "Eingang Rämistrasse prüfen",
		"info": ["Abgeschlossen", "Die Türen der Rotunde sind zu. Durch das Glas siehst du die leere Vorhalle."]})
	R("locked_door", 87, 30, 1, 2, {"door": "libeast", "use": "info", "label": "Bibliothekseingang prüfen",
		"info": ["Abgeschlossen", "Der Bibliothekseingang an der Rämistrasse ist verriegelt."]})
	var lab_labels := {"MAVT": "Labortür knacken", "ITET": "Labortür prüfen", "D-INFK": "Kartenleser hacken"}
	R("lab_door", 68, 63, 1, 2, {"door": "lab", "use": "labdoor", "label": lab_labels[dept]})
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

	# --- HG: entrance hall and corridors ---
	R("bust", 40.2, 43.1, 1.6, 1.2, {"use": "info", "label": "Tafel lesen",
		"info": ["Hauptgebäude", "Gottfried Semper baute hier das Polytechnikum, fertig 1864. Die Kuppel und die Rotunde zur Rämistrasse kamen später von Gustav Gull."]})
	R("board", 45.65, 31.0, 0.35, 3.4, {"use": "info", "label": "Anschlagbrett lesen",
		"info": ["Anschlagbrett", "«Polyball – Tickets ab Montag.» Daneben: «Labor HG Südost – Robotik. Nachts verschlossen, Schloss elektronisch über den Sicherungskasten im Gang. – Der Hauswart»"]})
	for p in [Vector2(43.5, 43.5), Vector2(43.5, 48.5), Vector2(67.5, 29.6), Vector2(67.5, 59.4), Vector2(47.5, 36.4), Vector2(59.5, 54.6)]:
		C("plant", p.x, p.y, 0.36)
	R("bench", 48.5, 27.05, 3, 0.6); R("bench", 60.0, 27.05, 3, 0.6); R("bench", 48.5, 64.35, 3, 0.6); R("bench", 60.0, 64.35, 3, 0.6)
	for p in [Vector2(44.5, 35), Vector2(44.5, 56), Vector2(55.5, 27.5), Vector2(55.5, 63.5), Vector2(66.5, 35), Vector2(66.5, 56), Vector2(53.5, 36.5), Vector2(53.5, 54.5)]:
		lamp(p.x, p.y, 2.6, Color(0.75, 0.85, 1.0))
	# Haupthalle
	for x in [49.9, 52.4, 56.4, 60.9, 63.9]:
		C("pillar", x, 43.5, 0.45); C("pillar", x, 48.5, 0.45)
	R("infodesk", 53.2, 45.1, 3.6, 1.0, {"use": "hide", "label": "Hinter der Infotheke verstecken"} if night else {})
	R("bench", 47.2, 45.2, 2.4, 0.7); R("bench", 60.4, 45.2, 2.4, 0.7)
	lamp(55.5, 45.5, 5.0, Color(0.7, 0.8, 1.0))
	# rotunda
	for a in [-65.0, -25.0, 25.0, 65.0]:
		var pr := Vector2(68.5, 46.0) + Vector2.from_angle(deg_to_rad(a)) * 3.9
		C("pillar", pr.x, pr.y, 0.45)
	lamp(71.5, 46.0, 3.6, Color(0.7, 0.8, 1.0))
	# forecourt towards Rämistrasse: fence with a gate in the middle
	R("rail", 88.3, 36.0, 0.3, 8.0); R("rail", 88.3, 48.0, 0.3, 8.0)
	for p in [Vector2(80.5, 38.5), Vector2(80.5, 53.5), Vector2(85.0, 41.5), Vector2(85.0, 50.5)]:
		C("planter", p.x, p.y, 1.05, {"hitr": 0.95, "use": "hide", "label": "Hinter dem Pflanzkübel ducken"} if night else {"hitr": 0.95})
	for p in [Vector2(78.5, 44.0), Vector2(78.5, 48.0)]:
		C("lamp", p.x, p.y, 0.22)
		lamp(p.x, p.y, 3.2, Color(1.0, 0.85, 0.5))
	# lecture halls: rows of seats that get wider towards the back, a desk at the front
	R("bench", 50.9, 30.3, 5.2, 0.6); R("bench", 51.2, 31.3, 4.6, 0.6); R("bench", 51.7, 32.3, 3.6, 0.6)
	R("desk", 52.7, 34.15, 1.6, 0.55, {"use": "hide", "label": "Hinter das Rednerpult ducken"} if night else {})
	R("desk", 52.7, 57.3, 1.6, 0.55, {"use": "hide", "label": "Hinter das Rednerpult ducken"} if night else {})
	R("bench", 51.7, 59.1, 3.6, 0.6); R("bench", 51.2, 60.1, 4.6, 0.6); R("bench", 50.9, 61.1, 5.2, 0.6)
	R("bench", 51.1, 39.3, 1.7, 0.6); R("bench", 54.2, 39.3, 1.7, 0.6); R("bench", 50.4, 40.5, 2.4, 0.6); R("bench", 54.2, 40.5, 2.4, 0.6)
	R("bench", 50.4, 50.9, 2.4, 0.6); R("bench", 54.2, 50.9, 2.4, 0.6); R("bench", 51.1, 52.1, 1.7, 0.6); R("bench", 54.2, 52.1, 1.7, 0.6)
	# Seminar room (north-west corner)
	R("desk", 39.3, 23.3, 2.6, 0.7, {"pc": true}); R("desk", 39.3, 25.5, 2.6, 0.7, {"use": "hide", "label": "Unter das Pult kriechen"} if night else {})
	# Study lounge (south-west corner)
	R("sofa", 39.1, 64.3, 2.8, 1.0, {"use": "hide", "label": "Hinter das Sofa ducken"} if night else {})
	R("ctable", 39.7, 65.9, 1.8, 0.9)
	R("sofa", 39.1, 67.8, 2.8, 1.0, {"flip": true})
	R("coffee", 42.0, 68.0, 0.9, 0.8, {"use": "info", "label": "Kaffeemaschine benutzen",
		"info": ["Kaffeemaschine", "Sie röchelt laut. Sehr laut. Vielleicht keine gute Idee um ein Uhr nachts."]})
	# offices and small seminar rooms along the outside and next to the courtyards
	for r in [Vector2(40.2, 29.3), Vector2(40.2, 35.3), Vector2(40.2, 50.3), Vector2(40.2, 58.3),
			Vector2(44.4, 23.3), Vector2(56.4, 23.3), Vector2(62.4, 23.3), Vector2(44.4, 67.9), Vector2(56.4, 67.9), Vector2(62.4, 67.9),
			Vector2(61.3, 30.3), Vector2(61.3, 36.3), Vector2(61.3, 50.3), Vector2(61.3, 57.3)]:
		R("desk", r.x, r.y, 2.4, 0.7)
		R("chair", r.x + 0.85, r.y + (-0.7 if r.y > 67.0 else 0.85), 0.66, 0.55, {"solid": false})

	# --- ETH-Bibliothek: north wing and its pavilion ---
	R("shelf", 70.6, 27.15, 4.2, 0.9, {"cat": "Mathematik"}); R("shelf", 75.2, 27.15, 4.2, 0.9, {"cat": "Physik"})
	R("shelf", 78.2, 21.2, 4.2, 0.9, {"cat": "Informatik"}); R("shelf", 82.6, 21.2, 4.2, 0.9, {"cat": "Architektur"})
	R("cabinet", 78.2, 23.2, 3.9, 1.15, {"use": "info", "label": "Max Frisch-Archiv ansehen",
		"info": ["Max Frisch-Archiv", "Manuskripte und Tagebücher des Zürcher Schriftstellers, der an der ETH Architektur studiert hat."]})
	R("cabinet", 82.9, 23.2, 3.9, 1.15, {"use": "info", "label": "Thomas-Mann-Archiv ansehen",
		"info": ["Thomas-Mann-Archiv", "Nachlass und Arbeitszimmer von Thomas Mann, seit 1956 bei der ETH Zürich."]})
	R("catalog", 69.4, 33.7, 3.9, 1.0, {"use": "moodle_prep", "label": "Moodle öffnen (Wartungspasswort finden)"} if (night and dept == "D-INFK") else {})
	for p in [Vector2(74.2, 29.4), Vector2(79.4, 29.4), Vector2(74.2, 32.6), Vector2(79.4, 32.6)]:
		R("rtable", p.x, p.y, 3.6, 1.2, {"use": "hide", "label": "Unter den Lesetisch kriechen"} if night else {})
		for dx in [0.4, 2.3]:
			R("chair", p.x + dx, p.y - 0.78, 0.66, 0.55, {"solid": false})
			R("chair", p.x + dx, p.y + 1.28, 0.66, 0.55, {"solid": false})
		lamp(p.x + 0.9, p.y + 0.6, 1.6, Color(1.0, 0.85, 0.45))
		lamp(p.x + 2.7, p.y + 0.6, 1.6, Color(1.0, 0.85, 0.45))
	R("counter", 69.4, 31.2, 3.5, 0.95)
	R("lockers", 83.4, 34.2, 3.4, 0.7, {"use": "hide", "label": "In einen Spind steigen"} if night else {})
	C("plant", 86.4, 27.6, 0.4); C("plant", 86.4, 25.4, 0.4); C("plant", 86.4, 33.4, 0.38)
	lamp(71, 31.5, 1.8, Color(0.6, 0.85, 1.0))

	# --- Labor (Robotik): south wing and its pavilion ---
	for p in [Vector2(70.5, 57.5), Vector2(77.5, 57.5), Vector2(70.5, 60.2), Vector2(77.5, 60.2)]:
		R("labbench", p.x, p.y, 6.0, 1.1)
		lamp(p.x + 1.5, p.y + 0.5, 1.2, Color(0.4, 0.8, 1.0))
		lamp(p.x + 4.5, p.y + 0.5, 1.2, Color(0.5, 1.0, 0.7))
	C("robot", 84.6, 62.4, 0.45, {"hitr": 0.4})
	R("rack", 85.6, 57.4, 1.2, 3.0)
	R("labdesk", 84.9, 66.5, 1.5, 2.8)
	R("locker", 78.3, 66.3, 1.2, 3.2, {"use": "hide", "label": "Im Laborschrank verstecken"} if night else {})
	R("fusebox", 67.55, 61.3, 0.45, 1.3, {"solid": false})
	lamp(85.6, 67.9, 2.0, Color(0.5, 0.75, 1.0))



func _dept_objects() -> void:
	if mode == "night":
		match dept:
			"MAVT":
				R("toolbox", 41.5, 25.52, 0.95, 0.6, {"solid": false, "use": "prep", "label": "Dietrich-Set aus der Werkzeugkiste nehmen"})
			"ITET":
				R("plan", 70.2, 31.32, 0.75, 0.5, {"solid": false, "use": "prep", "label": "Schaltplan einstecken"})
		var items := {"MAVT": ["gear", "Prototyp-Getriebe nehmen"], "ITET": ["disk", "Festplatte mit Messdaten nehmen"], "D-INFK": ["usb", "USB-Stick nehmen"]}
		R("goal", 85.15, 67.6, 0.6, 0.5, {"solid": false, "use": "goal", "item": items[dept][0], "label": items[dept][1]})
		if dept == "ITET":
			for o in objs:
				if o["kind"] == "fusebox":
					o["use"] = "fusebox"
					o["label"] = "Sicherungskasten verdrahten"
	else:
		# day levels: every task with fixed places gets one station per spot (levels.gd)
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
		lamp(x, 72.6, 2.8, Color(1.0, 0.8, 0.45))

	# --- trees ---
	for ty in [22.0, 25.6, 33.6, 57.6, 61.2, 66.6, 70.2]:   # along Rämistrasse, not in front of the forecourt
		C("tree", 88.9, ty, 0.95, {"hitr": 0.32})
	var y_tree := 4.0
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
	L("HAUPTHALLE", 56.0, 46.9, 0.7, "floor")
	L("ROTUNDE", 71.6, 46.0, 0.36, "floor", {"rot": -PI / 2})
	L("ETH-BIBLIOTHEK", 78.5, 31.6, 0.6, "floor")
	L("LABOR · ROBOTIK", 78.0, 63.0, 0.6, "floor")
	L("SEMINAR", 41.0, 27.3, 0.36, "floor")
	L("LOUNGE", 41.0, 67.2, 0.36, "floor")
	L("HÖRSAAL E1", 53.5, 33.6, 0.34, "floor")
	L("E3", 53.5, 41.3, 0.4, "floor")
	L("E5", 53.5, 50.0, 0.4, "floor")
	L("HÖRSAAL E7", 53.5, 58.4, 0.34, "floor")
	L("E NORD", 53.5, 37.0, 0.42, "floor")
	L("E SÜD", 53.5, 55.0, 0.42, "floor")
	L("MENSA POLYTERRASSE", 23, 73.6, 0.7, "floor")
	L("POLYBAHN", 5, 42.9, 0.62, "floor")
	L("HAUPTGEBÄUDE", 45.0, 37.0, 0.5, "floor", {"rot": -PI / 2})
	L("TANNENSTRASSE", 46, 16.05, 0.6, "street")
	L("TANNENSTRASSE", 78, 16.05, 0.6, "street")
	L("RÄMISTRASSE", 95, 22, 0.6, "street", {"rot": -PI / 2})
	L("RÄMISTRASSE", 95, 62, 0.6, "street", {"rot": -PI / 2})
	L("KÜNSTLERGASSE", 63, 75.55, 0.55, "street")
	L("ML", 15, 5.2, 1.3, "roof", {"sub": "MASCHINENLABORATORIUM"})
	L("CAB", 43.5, 5.2, 1.3, "roof", {"sub": "INFORMATIK"})
	L("CHN", 73.5, 5.2, 1.3, "roof", {"sub": "ETH ZENTRUM"})
	L("UNIVERSITÄT ZÜRICH", 64, 80.6, 0.9, "roof", {"sub": "NACHBARIN"})

	# --- zones (first match wins) ---
	zones = [
		[Rect2(69, 27, 18, 8), "ETH-Bibliothek"], [Rect2(78, 21, 9, 6), "ETH-Bibliothek"],
		[Rect2(69, 57, 18, 8), "Labor · Robotik"], [Rect2(78, 65, 9, 6), "Labor · Robotik"],
		[Rect2(50, 30, 7, 5), "Hörsaal E1"], [Rect2(50, 39, 7, 3), "Hörsaal E3"],
		[Rect2(50, 50, 7, 3), "Hörsaal E5"], [Rect2(50, 57, 7, 5), "Hörsaal E7"],
		[Rect2(46, 43, 22, 6), "Haupthalle"], [Rect2(68, 39, 8, 14), "Rotunde"],
		[Rect2(39, 23, 4, 5), "Seminarraum"], [Rect2(39, 64, 4, 5), "Lounge"],
		[Rect2(47, 30, 13, 12), "E Nord"], [Rect2(47, 50, 13, 12), "E Süd"],
		[Rect2(69, 36, 21, 20), "Vorhof Rämistrasse"],
		[Rect2(38, 20, 50, 52), "Hauptgebäude (HG)"], [Rect2(0, 36, 11, 11), "Polybahn"],
		[Rect2(12, 64, 22, 14), "Mensa Polyterrasse"], [Rect2(10, 20, 28, 44), "Polyterrasse"],
		[Rect2(90, 0, 10, 84), "Rämistrasse"], [Rect2(0, 12, 90, 8), "Tannenstrasse"],
		[Rect2(34, 72, 58, 6), "Künstlergasse"], [Rect2(0, 20, 10, 44), "Hang zur Altstadt"],
	]



func _people() -> void:
	# where students stroll: [x0, y0, x1, y1, how many]
	student_zones = [[11, 21, 36, 61, 7], [47, 43, 65, 48, 4], [44, 27, 45, 64, 2], [44, 27, 67, 28, 2], [44, 63, 67, 64, 2],
		[13, 65, 32, 74, 4], [0, 18, 89, 19, 3], [90, 0, 91, 83, 2], [69, 28, 86, 28, 1], [69, 31, 73, 33, 2], [34, 72, 89, 73, 2],
		[66, 29, 67, 62, 2], [47, 36, 59, 37, 1], [47, 54, 59, 55, 1], [76, 37, 87, 55, 2]]
	if mode == "day":
		profs = [{"name": CH.DEPTS[dept]["prof"], "static": true, "pts": [Vector2(55.5, 44.4)], "quote": ""}]
		return
	# --- professors on night duty (fictional) ---
	profs = [
		{"name": "Prof. Dr. Brunner", "speed": 48.0, "range": 6.5, "hair": "d8d4cc", "coat": "6b4f3a",
			"quote": "Um diese Zeit in der Haupthalle? Das gibt einen Eintrag ins Protokoll!",
			"pts": [Vector2(47.5, 44.5), Vector2(65.5, 44.5), Vector2(71.5, 46.0), Vector2(65.5, 47.5), Vector2(47.5, 47.5)]},
		{"name": "Prof. Dr. Keller", "speed": 56.0, "range": 6.5, "hair": "3b2a1e", "coat": "39465a",
			"quote": "Halt! Was suchen Sie um ein Uhr nachts im Hauptgebäude?",
			"pts": [Vector2(44.5, 30.5), Vector2(44.5, 61.5), Vector2(55.5, 63.5), Vector2(66.5, 63.5), Vector2(66.5, 27.5), Vector2(50.5, 27.5)]},
		{"name": "Prof. Dr. Meier", "speed": 42.0, "range": 6.0, "hair": "c9c4ba", "coat": "5d6b4a",
			"quote": "Psst! In der Bibliothek wird nicht eingebrochen. Raus hier!",
			"pts": [Vector2(70.5, 28.5), Vector2(85.5, 28.5), Vector2(82.5, 24.8), Vector2(85.5, 31.5), Vector2(73.5, 31.5)]},
		{"name": "Prof. Dr. Huber", "speed": 40.0, "range": 7.5, "hair": "e8e4dc", "coat": "e9ece8", "pmin": 2.5, "pmax": 4.5,
			"quote": "Finger weg von meinem Labor! Ihre Bachelorarbeit besprechen wir morgen früh.",
			"pts": [Vector2(70.5, 62.5), Vector2(84.0, 62.5), Vector2(82.5, 68.0)]},
		{"name": "Prof. Dr. Widmer", "speed": 58.0, "range": 6.5, "hair": "6b5040", "coat": "2f4f6f",
			"quote": "Grüezi und gute Nacht. Ihre Legi, bitte.",
			"pts": [Vector2(13.5, 28.5), Vector2(35.5, 28.5), Vector2(35.5, 60.5), Vector2(36.5, 72.5), Vector2(60.5, 72.5), Vector2(36.5, 72.5), Vector2(35.5, 47.5), Vector2(13.5, 54.5)]},
	]

