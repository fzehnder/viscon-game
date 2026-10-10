extends Node2D
## Draws the campus at night, builds wall/furniture collisions and the patrol pathfinding grid.

const M = preload("res://scripts/map_data.gd")
const TS := 32.0
const TALL_KINDS := ["shelf", "cabinet", "lockers", "locker", "rack", "pillar"]   # furniture you cannot look over
const SIGHT_MASK := 1 | 64

var data: Dictionary
var main
var W := 112
var H := 84
var astar: AStarGrid2D
var door_bodies := {}
var _cc := {}


func _ready() -> void:
	z_index = -10
	W = data["W"]
	H = data["H"]
	_build_collision()
	_build_astar()
	queue_redraw()


# ---------------------------------------------------------------- map queries

func get_t(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return M.WALL
	return data["map"][y * W + x]


func is_solid_t(t: int) -> bool:
	return t == M.WALL or t == M.ROOF or t == M.RAIL


func zone_at(p_px: Vector2) -> String:
	var p := p_px / TS
	for z in data["zones"]:
		if (z[0] as Rect2).has_point(p):
			return z[1]
	return "Hochschulquartier"


# ---------------------------------------------------------------- physics

func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size / 2.0
	body.add_child(cs)


func _build_collision() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	for y in H:
		var x := 0
		while x < W:
			if is_solid_t(get_t(x, y)):
				var x0 := x
				while x < W and is_solid_t(get_t(x, y)):
					x += 1
				_add_rect(walls, Rect2(x0 * TS, y * TS, (x - x0) * TS, TS))
			else:
				x += 1
	# map border
	_add_rect(walls, Rect2(-TS, -TS, (W + 2) * TS, TS))
	_add_rect(walls, Rect2(-TS, H * TS, (W + 2) * TS, TS))
	_add_rect(walls, Rect2(-TS, 0, TS, H * TS))
	_add_rect(walls, Rect2(W * TS, 0, TS, H * TS))

	var furn := StaticBody2D.new()
	furn.collision_layer = 2
	furn.collision_mask = 0
	add_child(furn)
	var tall := StaticBody2D.new()   # also blocks the view of Opps (layer 64), see sight_clear
	tall.collision_layer = 2 | 64
	tall.collision_mask = 0
	add_child(tall)
	for o in data["objs"]:
		if not o["solid"]:
			continue
		var r: Rect2 = o["hit"] if o.has("hit") else o["rect"]
		if o.has("door"):
			var b := StaticBody2D.new()
			b.collision_layer = 1   # doors block sight like walls
			b.collision_mask = 0
			add_child(b)
			_add_rect(b, Rect2(r.position * TS, r.size * TS))
			door_bodies[o["door"]] = b
		else:
			var high: bool = o.get("tall", o["kind"] in TALL_KINDS)
			_add_rect(tall if high else furn, Rect2(r.position * TS, r.size * TS))


func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(TS, TS)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in H:
		for x in W:
			if is_solid_t(get_t(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)
	for o in data["objs"]:
		if o["solid"]:
			_set_rect_solid(o["hit"] if o.has("hit") else o["rect"], true)


func _set_rect_solid(r: Rect2, solid: bool) -> void:
	var g := r.grow(-0.12)
	for ty in range(int(floor(g.position.y)), int(floor(g.end.y)) + 1):
		for tx in range(int(floor(g.position.x)), int(floor(g.end.x)) + 1):
			if tx >= 0 and ty >= 0 and tx < W and ty < H:
				if not solid and is_solid_t(get_t(tx, ty)):
					continue
				astar.set_point_solid(Vector2i(tx, ty), solid)


func open_door(id: String) -> void:
	if door_bodies.has(id):
		door_bodies[id].queue_free()
		door_bodies.erase(id)
	for o in data["objs"]:
		if o.get("door", "") == id:
			o["opened"] = true
			o["solid"] = false
			_set_rect_solid(o["rect"], false)
	queue_redraw()


func _tile_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TS)), int(floor(p.y / TS)))


func _nearest_free(t: Vector2i) -> Vector2i:
	if astar.is_in_boundsv(t) and not astar.is_point_solid(t):
		return t
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := t + Vector2i(dx, dy)
				if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
					return c
	return t


func find_path(from_px: Vector2, to_px: Vector2) -> Array:
	var a := _nearest_free(_tile_of(from_px))
	var b := _nearest_free(_tile_of(to_px))
	var out: Array = []
	if a == b:
		return out
	var ids := astar.get_id_path(a, b)
	for i in range(1, ids.size()):
		out.append(Vector2(ids[i]) * TS + Vector2(TS / 2.0, TS / 2.0))
	return out


func ray_end(a: Vector2, b: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return b
	return hit["position"]


func line_clear(a: Vector2, b: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return space.intersect_ray(q).is_empty()


## Like line_clear and ray_end, but shelves and other tall furniture block the view as well.
func sight_clear(a: Vector2, b: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, SIGHT_MASK)
	return space.intersect_ray(q).is_empty()


func sight_end(a: Vector2, b: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, SIGHT_MASK)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return b
	return hit["position"]


# ---------------------------------------------------------------- drawing

func N(hex: String, lit: float = 0.0) -> Color:
	if data.get("mode", "night") == "day":
		return Color(hex)
	var key := hex + str(lit)
	if _cc.has(key):
		return _cc[key]
	var c := Color(hex).darkened(0.55 - lit * 0.8).lerp(Color("1c2b4d"), 0.3 - lit * 0.4)
	_cc[key] = c
	return c


func _hash(x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return h ^ (h >> 16)


func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shadow(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(2.5, 3.5), r.size), Color(0, 0, 0, 0.32))


func _draw_tile(t: int, x: int, y: int) -> void:
	var p := Vector2(x, y) * TS
	var s := TS
	var rc := Rect2(p, Vector2(s, s))
	var h := _hash(x, y)
	if t == M.GRASS:
		draw_rect(rc, N(["86b25e", "83af5b", "8ab662"][h % 3]))
		for i in 3:
			var a := (h >> (i * 6)) & 63
			draw_rect(Rect2(p + Vector2((a & 7) / 8.0 * s, (a >> 3) / 8.0 * s), Vector2(s * 0.07, s * 0.13)), Color(0.05, 0.1, 0.05, 0.35))
	elif t == M.ROAD:
		draw_rect(rc, N("5b5f66"))
	elif t == M.WALK:
		draw_rect(rc, N("bfbaaf"))
		draw_rect(Rect2(p.x, p.y + s - 1, s, 1), N("9f998d"))
		draw_rect(Rect2(p.x + s - 1, p.y, 1, s), N("9f998d"))
	elif t == M.PAVE:
		var hv := _hash(x >> 1, y >> 1)
		draw_rect(rc, N(["d6ccb8", "d2c8b3", "dad1be"][hv % 3]))
		if x % 2 == 1:
			draw_rect(Rect2(p.x + s - 1, p.y, 1.2, s), N("a99f8a"))
		if y % 2 == 1:
			draw_rect(Rect2(p.x, p.y + s - 1, s, 1.2), N("a99f8a"))
	elif t == M.STONE:
		draw_rect(rc, N("dcd8cf", 0.12))
		draw_rect(Rect2(p.x, p.y + s - 1, s, 1), N("b8b3a7", 0.12))
		draw_rect(Rect2(p.x + s - 1, p.y, 1, s), N("b8b3a7", 0.12))
	elif t == M.WOOD:
		draw_rect(rc, N("b98a57", 0.12))
		for i in [1, 2]:
			draw_rect(Rect2(p.x, p.y + i * s / 3.0 - 0.5, s, 1), N("94693e", 0.12))
		for i in 3:
			var o := ((h >> (i * 4)) & 3) / 4.0
			draw_rect(Rect2(p.x + o * s, p.y + i * s / 3.0, 1, s / 3.0), N("94693e", 0.12))
	elif t == M.MARBLE:
		draw_rect(rc, N("ebe6dc", 0.12) if (x + y) % 2 == 1 else N("cdc5b5", 0.12))
	elif t == M.TILE:
		draw_rect(rc, N("e3e9e9"))
		draw_rect(Rect2(p.x, p.y + s / 2.0, s, 1), N("b9c3c4"))
		draw_rect(Rect2(p.x + s / 2.0, p.y, 1, s), N("b9c3c4"))
	elif t == M.LAB:
		draw_rect(rc, N("cfd8dc", 0.1))
		draw_rect(Rect2(p.x, p.y + s - 1, s, 1), N("a7b3b8", 0.1))
		draw_rect(Rect2(p.x + s - 1, p.y, 1, s), N("a7b3b8", 0.1))
	elif t == M.ROOF:
		draw_rect(rc, N("8f9297"))
		var e := N("4c4f54")
		draw_line(p + Vector2(0, s), p + Vector2(s, 0), N("7f8287"), 1.0)
		if get_t(x, y - 1) != M.ROOF: draw_rect(Rect2(p.x, p.y, s, s * 0.12), e)
		if get_t(x, y + 1) != M.ROOF: draw_rect(Rect2(p.x, p.y + s * 0.88, s, s * 0.12), e)
		if get_t(x - 1, y) != M.ROOF: draw_rect(Rect2(p.x, p.y, s * 0.12, s), e)
		if get_t(x + 1, y) != M.ROOF: draw_rect(Rect2(p.x + s * 0.88, p.y, s * 0.12, s), e)
	elif t == M.RAIL:
		draw_rect(rc, N("8b8479"))
		draw_rect(Rect2(p.x + s * 0.05, p.y + s * 0.15, s * 0.9, s * 0.22), N("6b5440"))
		draw_rect(Rect2(p.x + s * 0.05, p.y + s * 0.65, s * 0.9, s * 0.22), N("6b5440"))
	elif t == M.WALL:
		draw_rect(rc, N("4b5058", 0.1))


func _draw_wall_top(x: int, y: int) -> void:
	var p := Vector2(x, y) * TS
	var s := TS
	var a := s * 0.3
	var b := s * 0.7
	var col := N("9aa0a7", 0.15)
	draw_rect(Rect2(p.x + a, p.y + a, b - a, b - a), col)
	if get_t(x, y - 1) == M.WALL: draw_rect(Rect2(p.x + a, p.y, b - a, a), col)
	if get_t(x, y + 1) == M.WALL: draw_rect(Rect2(p.x + a, p.y + b, b - a, s - b), col)
	if get_t(x - 1, y) == M.WALL: draw_rect(Rect2(p.x, p.y + a, a, b - a), col)
	if get_t(x + 1, y) == M.WALL: draw_rect(Rect2(p.x + b, p.y + a, s - b, b - a), col)


func _is_floor(t: int) -> bool:
	return t in [M.STONE, M.WOOD, M.MARBLE, M.TILE, M.CARPET, M.LAB, M.PAVE, M.WALK]


func _draw() -> void:
	var s := TS
	for y in H:
		for x in W:
			_draw_tile(get_t(x, y), x, y)
	# wall shadows
	for y in H:
		for x in W:
			if not _is_floor(get_t(x, y)):
				continue
			var above := get_t(x, y - 1)
			var left := get_t(x - 1, y)
			if above == M.WALL or above == M.ROOF:
				draw_rect(Rect2(x * s, y * s, s, s * 0.22), Color(0, 0, 0, 0.25))
			if left == M.WALL or left == M.ROOF:
				draw_rect(Rect2(x * s, y * s, s * 0.15, s), Color(0, 0, 0, 0.25))
	# road markings
	var white := Color(1, 1, 1, 0.35)
	var xm := 0.0
	while xm < 91.0:
		if xm < 55.6 or xm > 62.5:
			draw_rect(Rect2(xm * s, 16 * s - 1.5, s * 0.8, 3), white)
		xm += 1.6
	xm = 34.5
	while xm < 91.0:
		draw_rect(Rect2(xm * s, 69.5 * s - 1.5, s * 0.8, 3), white)
		xm += 1.6
	var zebra := N("f1c232", 0.15)
	var xz := 57.2
	while xz < 61.8:
		draw_rect(Rect2(xz * s, 14.1 * s, s * 0.32, s * 3.8), zebra)
		xz += 0.6
	var yz := 31.4
	while yz < 35.6:
		draw_rect(Rect2(92.1 * s, yz * s, s * 5.8, s * 0.32), zebra)
		yz += 0.6
	for cx in [93.6, 96.4]:
		draw_rect(Rect2((cx - 0.38) * s, 0, 2.5, H * s), Color(0.12, 0.13, 0.15))
		draw_rect(Rect2((cx + 0.3) * s, 0, 2.5, H * s), Color(0.12, 0.13, 0.15))
	# wall tops
	for y in H:
		for x in W:
			if get_t(x, y) == M.WALL:
				_draw_wall_top(x, y)
	# door markers
	for d in data["doors"]:
		var r := Rect2(Vector2(d.position) * s, Vector2(d.size) * s)
		var a: Vector2
		var b: Vector2
		if d.size.x == 1:
			a = Vector2(r.get_center().x, r.position.y)
			b = Vector2(r.get_center().x, r.end.y)
		else:
			a = Vector2(r.position.x, r.get_center().y)
			b = Vector2(r.end.x, r.get_center().y)
		var n := int(a.distance_to(b) / 9.0)
		for i in range(0, n, 2):
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(0.1, 0.1, 0.12, 0.5), 2.0)
	# objects: trees last so canopies sit on top
	var order: Array = data["objs"].duplicate()
	order.sort_custom(func(p, q):
		var pt := 1 if p["kind"] == "tree" else 0
		var qt := 1 if q["kind"] == "tree" else 0
		if pt != qt:
			return pt < qt
		return (p["rect"] as Rect2).end.y < (q["rect"] as Rect2).end.y)
	for o in order:
		if o["kind"] in ITEM_KINDS:
			continue
		_draw_obj(o)
	for o in data["objs"]:
		if o["kind"] in ITEM_KINDS and not o.get("taken", false):
			_draw_obj(o)
	# light pools (night only)
	for l in ([] if data.get("mode", "night") == "day" else data["lamps"]):
		var c: Color = l["col"]
		var r: float = l["r"] * s
		for i in 12:
			var k := 1.0 - i / 12.0
			draw_circle(l["p"] * s, r * k, Color(c.r, c.g, c.b, 0.018 + i * 0.004))
	# labels
	for l in data["labels"]:
		_draw_label(l)


func _draw_label(l: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(l["sz"] * TS)
	var t: String = l["t"]
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(l["p"] * TS, l.get("rot", 0.0), Vector2.ONE)
	var k: String = l["k"]
	if k == "floor":
		var fc := Color(0.3, 0.24, 0.18, 0.25) if data.get("mode", "night") == "day" else Color(0.85, 0.88, 0.95, 0.16)
		draw_string(font, Vector2(-w / 2.0, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fc)
	elif k == "street":
		draw_string(font, Vector2(-w / 2.0, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.3))
	else:
		draw_string(font, Vector2(-w / 2.0 + 2, fs * 0.35 + 3), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.4))
		draw_string(font, Vector2(-w / 2.0, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.85, 0.87, 0.9))
		if l.has("sub"):
			var f2 := int(TS * 0.4)
			var sub: String = l["sub"]
			var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, f2).x
			draw_string(font, Vector2(-w2 / 2.0, fs * 0.35 + f2 * 1.6), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, f2, Color(0.75, 0.78, 0.82))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


const ITEM_KINDS := ["toolbox", "plan", "goal"]
const BOOKS := ["8c2f39", "2f5d8c", "3e7d4f", "b5893a", "5d3f7a", "2b6e6e", "c4643a", "394150", "a39a8c", "d0b24a"]


func _draw_obj(o: Dictionary) -> void:
	var s := TS
	var r: Rect2 = o["rect"]
	var x := r.position.x * s
	var y := r.position.y * s
	var w := r.size.x * s
	var h := r.size.y * s
	var R2 := Rect2(x, y, w, h)
	var k: String = o["kind"]
	match k:
		"tree":
			var c: Vector2 = o["c"] * s
			var rr: float = o["r"] * s
			var hv := _hash(int(c.x), int(c.y))
			draw_circle(c + Vector2(rr * 0.25, rr * 0.3), rr, Color(0, 0, 0, 0.35))
			draw_circle(c, rr, N("3f7a3a" if hv % 2 == 0 else "467f37"))
			for i in 5:
				var a := i * 1.26 + hv % 7
				draw_circle(c + Vector2(cos(a), sin(a)) * rr * 0.42, rr * 0.48, N("4f8f45" if hv % 2 == 0 else "5a9440"))
		"planter":
			var c: Vector2 = o["c"] * s
			var rr: float = o["r"] * s
			_shadow(Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2))
			draw_rect(Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2), N("a49a88"))
			draw_rect(Rect2(c - Vector2(rr, rr) * 0.78, Vector2(rr, rr) * 1.56), N("6b5a43"))
			draw_circle(c, rr * 0.95, N("4f8f45"))
			draw_circle(c - Vector2(rr * 0.2, rr * 0.25), rr * 0.5, N("62a052"))
		"bench":
			_shadow(R2)
			draw_rect(R2, N("7a6450"))
			for i in 3:
				draw_rect(Rect2(x + 2, y + h * (0.12 + i * 0.3), w - 4, h * 0.18), N("9b8268"))
		"bikes":
			var i := 0.0
			while i < r.size.x:
				draw_line(Vector2(x + i * s + s * 0.3, y + 2), Vector2(x + i * s + s * 0.3, y + h), N("5e646b"), 2.0)
				i += 0.7
			i = 0.0
			var cols := ["c0392b", "2f5d8c", "2d2d2d", "3e7d4f"]
			while i < r.size.x - 0.5:
				draw_rect(Rect2(x + i * s + s * 0.18, y + s * 0.1, s * 0.24, h * 0.85), N(cols[int(i * 10) % 4]))
				i += 1.4
		"lamp":
			draw_circle(o["c"] * s, s * 0.2, Color(0.15, 0.16, 0.18))
			draw_circle(o["c"] * s, s * 0.11, Color(1.0, 0.92, 0.65))
		"scope":
			draw_circle(R2.get_center(), w * 0.32, N("3b4047"))
			draw_rect(Rect2(R2.get_center() - Vector2(s * 0.5, s * 0.08), Vector2(s * 0.5, s * 0.16)), N("6b737c"))
		"sign":
			_shadow(R2)
			draw_rect(R2, N("c0392b", 0.15))
			draw_rect(Rect2(x + w * 0.3, y + h * 0.2, w * 0.4, h * 0.6), N("ffffff", 0.15))
		"rail":
			draw_rect(R2, N("b8ae9b"))
			var j := 0.0
			while j < r.size.y:
				draw_rect(Rect2(x, y + j * s, w, s * 0.12), N("8f8676"))
				j += 0.5
		"funi":
			_shadow(R2)
			draw_rect(R2, N("b8322a", 0.15))
			draw_rect(Rect2(x + 4, y + 4, w - 8, h * 0.38), N("d6493d", 0.15))
			for i in 5:
				draw_rect(Rect2(x + s * (0.5 + i * 1.2), y + h * 0.62, s * 0.8, h * 0.2), Color(1.0, 0.9, 0.6, 0.7))
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(x + w * 0.27, y + h * 0.36), "POLYBAHN", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.38), Color(1, 1, 1, 0.85))
		"edgeline":
			draw_rect(R2, N("f2c14e", 0.2))
		"ticket":
			_shadow(R2)
			draw_rect(R2, N("c0392b", 0.15))
			draw_rect(Rect2(x + w * 0.2, y + h * 0.2, w * 0.6, h * 0.35), Color(0.4, 0.8, 1.0, 0.8))
		"board":
			draw_rect(R2, N("8a6a48", 0.15))
			var pc := ["f3efe2", "f2c14e", "9cc3e6", "f3efe2", "e8a39b"]
			for i in 5:
				draw_rect(Rect2(x + w * 0.15, y + s * (0.15 + i * 0.62), w * 0.7, s * 0.45), N(pc[i], 0.15))
		"plant":
			var c: Vector2 = o["c"] * s
			var rr: float = o["r"] * s
			draw_circle(c + Vector2(2, 3), rr, Color(0, 0, 0, 0.3))
			draw_circle(c, rr, N("8a5a3c", 0.1))
			for i in 6:
				var a := i * 1.05
				draw_circle(c + Vector2(cos(a), sin(a)) * rr * 0.45, rr * 0.42, N("4f8f45", 0.1))
		"pillar":
			var c: Vector2 = o["c"] * s
			var rr: float = o["r"] * s
			draw_circle(c + Vector2(3, 3.5), rr, Color(0, 0, 0, 0.32))
			draw_circle(c, rr, N("b9b2a3", 0.15))
			draw_circle(c - Vector2(rr, rr) * 0.15, rr * 0.68, N("d8d2c5", 0.15))
		"bust":
			_shadow(R2)
			draw_rect(R2, N("a49d90", 0.15))
			_ell(Vector2(x + w / 2, y + h * 0.55), w * 0.3, h * 0.26, N("6f6a62", 0.15))
			draw_circle(Vector2(x + w / 2, y + h * 0.45), s * 0.24, N("8a847a", 0.15))
		"infodesk":
			_shadow(R2)
			draw_rect(R2, N("29507f", 0.15))
			draw_rect(Rect2(x + 5, y + 5, w - 10, h * 0.42), N("e9e4d8", 0.15))
		"desk", "ctable":
			_shadow(R2)
			draw_rect(R2, N("c7b08f" if k == "desk" else "8a6a48", 0.12))
			if o.get("pc", false):
				draw_rect(Rect2(x + s * 0.3, y + s * 0.08, s * 1.1, s * 0.42), N("22262b", 0.1))
				draw_rect(Rect2(x + s * 0.36, y + s * 0.13, s * 0.98, s * 0.32), Color(0.98, 0.5, 0.07, 0.9))
				draw_rect(Rect2(x + s * 0.4, y + s * 0.52, s * 0.9, s * 0.14), N("3b3f46", 0.1))
		"chair":
			draw_rect(Rect2(x + 2, y + 2, w, h), Color(0, 0, 0, 0.25))
			draw_rect(R2, N("3d4e63", 0.12))
			draw_rect(Rect2(x + w * 0.15, y + h * 0.18, w * 0.7, h * 0.64), N("4f6380", 0.12))
		"sofa":
			_shadow(R2)
			draw_rect(R2, N("7b3f3f", 0.12))
			var fy := y + 3 if o.get("flip", false) else y + h * 0.36
			draw_rect(Rect2(x + 6, fy, w - 12, h * 0.56), N("954f4c", 0.12))
		"coffee":
			_shadow(R2)
			draw_rect(R2, N("2b2f35", 0.12))
			draw_circle(Vector2(x + w * 0.72, y + h * 0.35), 2.5, Color(0.6, 1.0, 0.6))
		"shelf":
			_shadow(R2)
			draw_rect(R2, N("5a3a22", 0.12))
			var n := int(round(r.size.x * 6))
			var bw := (w - 4) / n
			var hv := _hash(int(x), int(y))
			for i in n:
				draw_rect(Rect2(x + 2 + i * bw, y + 2, bw - 1, h / 2 - 3), N(BOOKS[(i * 3 + hv) % 10], 0.12))
				draw_rect(Rect2(x + 2 + i * bw, y + h / 2 + 1, bw - 1, h / 2 - 3), N(BOOKS[(i * 7 + hv) % 10], 0.12))
			draw_rect(Rect2(x, y + h / 2 - 1, w, 2), N("3b2615", 0.12))
		"cabinet":
			_shadow(R2)
			draw_rect(R2, N("3b3f45", 0.12))
			draw_rect(Rect2(x + 3, y + 3, w - 6, h - 6), N("bedceb", 0.12))
			for i in 5:
				draw_rect(Rect2(x + s * (0.3 + i * 0.72), y + h * 0.25, s * 0.4, h * 0.5), N("f3efe2", 0.12))
		"catalog":
			_shadow(R2)
			draw_rect(R2, N("c7b08f", 0.12))
			for dx in [0.5, 2.4]:
				draw_rect(Rect2(x + dx * s, y + s * 0.12, s * 0.9, s * 0.32), Color(0.35, 0.6, 0.95, 0.9))
		"rtable":
			_shadow(R2)
			draw_rect(R2, N("8a6a48", 0.15))
			draw_rect(Rect2(x + 3, y + 3, w - 6, h - 6), N("9d7b55", 0.15))
			for dx in [0.9, 2.7]:
				draw_circle(Vector2(x + dx * s, y + h / 2), s * 0.17, Color(0.95, 0.85, 0.45))
		"counter":
			_shadow(R2)
			draw_rect(R2, N("7a5032", 0.15))
			draw_rect(Rect2(x + 3, y + 3, w - 6, h * 0.35), N("e6dcc5", 0.15))
			draw_rect(Rect2(x + w * 0.62, y + h * 0.5, s * 0.6, s * 0.32), Color(0.35, 0.6, 0.95, 0.9))
		"lockers":
			draw_rect(R2, N("6d7b88", 0.12))
			var j := 0.0
			while j < r.size.x:
				draw_rect(Rect2(x + j * s, y, 1.5, h), N("4a5560", 0.12))
				j += 0.6
		"mcounter":
			_shadow(R2)
			draw_rect(R2, N("9aa4ad"))
			draw_rect(Rect2(x + 2, y + 2, w - 4, h * 0.45), N("c6ced5"))
		"mtable":
			draw_circle(o["c"] * s + Vector2(2, 3), o["r"] * s, Color(0, 0, 0, 0.3))
			draw_circle(o["c"] * s, o["r"] * s, N("f0ece2"))
		"labbench":
			_shadow(R2)
			draw_rect(R2, N("5f6b74", 0.15))
			draw_rect(Rect2(x + 3, y + 3, w - 6, h - 6), N("eef1f3", 0.12))
			for i in 3:
				var bx := x + s * (0.5 + i * 1.9)
				draw_rect(Rect2(bx, y + s * 0.2, s * 0.8, s * 0.45), N("2b2f35", 0.1))
				draw_rect(Rect2(bx + 3, y + s * 0.2 + 3, s * 0.8 - 6, s * 0.45 - 6), Color(0.3, 0.9, 0.6, 0.85) if i % 2 == 0 else Color(0.35, 0.65, 1.0, 0.85))
		"robot":
			var c: Vector2 = o["c"] * s
			draw_circle(c + Vector2(3, 3), s * 0.45, Color(0, 0, 0, 0.3))
			draw_circle(c, s * 0.45, N("e07a2f", 0.2))
			draw_line(c, c + Vector2(s * 0.9, -s * 0.5), N("f2a25a", 0.2), s * 0.22)
			draw_circle(c + Vector2(s * 0.9, -s * 0.5), s * 0.16, N("3b3f45", 0.2))
		"rack":
			_shadow(R2)
			draw_rect(R2, N("22262b", 0.1))
			var j := 0.3
			while j < r.size.y:
				draw_circle(Vector2(x + w * 0.3, y + j * s), 2.0, Color(0.3, 1.0, 0.5))
				draw_circle(Vector2(x + w * 0.6, y + j * s), 2.0, Color(1.0, 0.7, 0.2) if int(j * 10) % 3 == 0 else Color(0.3, 1.0, 0.5))
				j += 0.4
		"labdesk":
			_shadow(R2)
			draw_rect(R2, N("8a939b", 0.15))
			draw_rect(Rect2(x + 3, y + 3, w - 6, h - 6), N("d6dde2", 0.15))
		"locker":
			_shadow(R2)
			draw_rect(R2, N("6d7b88", 0.12))
			draw_rect(Rect2(x + w / 2 - 1, y, 2, h), N("4a5560", 0.12))
		"toolbox":
			draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Color(0, 0, 0, 0.5))
			draw_rect(R2, Color(0.8, 0.18, 0.15))
			draw_rect(Rect2(x + w * 0.3, y - 2, w * 0.4, 3), Color(0.25, 0.25, 0.28))
			draw_rect(Rect2(x, y + h * 0.45, w, 1.5), Color(0.5, 0.1, 0.08))
		"plan":
			draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Color(0, 0, 0, 0.5))
			draw_rect(R2, Color(0.2, 0.42, 0.75))
			for i in 3:
				draw_line(Vector2(x + 2, y + 3 + i * 4), Vector2(x + w - 2, y + 3 + i * 4), Color(0.85, 0.92, 1.0), 0.8)
		"goal":
			draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Color(0, 0, 0, 0.5))
			match o.get("item", "usb"):
				"gear":
					var gc := R2.get_center()
					for i in 8:
						var a := i * TAU / 8.0
						draw_rect(Rect2(gc + Vector2(cos(a), sin(a)) * 7.0 - Vector2(2, 2), Vector2(4, 4)), Color(0.8, 0.65, 0.2))
					draw_circle(gc, 7.0, Color(0.85, 0.7, 0.25))
					draw_circle(gc, 2.5, Color(0.3, 0.3, 0.32))
				"disk":
					draw_rect(R2, Color(0.25, 0.27, 0.3))
					draw_circle(R2.get_center(), 5.0, Color(0.7, 0.72, 0.75))
				_:
					draw_rect(Rect2(x, y, w * 0.7, h), Color(0.85, 0.2, 0.2))
					draw_rect(Rect2(x + w * 0.7, y + h * 0.2, w * 0.3, h * 0.6), Color(0.8, 0.82, 0.85))
		"legi_terminal":
			# blue validation terminal (Ersti-Tag)
			_shadow(R2)
			draw_rect(R2, Color("1f4f9a"))
			draw_rect(Rect2(x + 3, y + 3, w - 6, h * 0.45), Color("8fd3ff"))
			draw_rect(Rect2(x + w * 0.5 - 4, y + h * 0.62, 8, 3), Color("ffffff"))
			draw_rect(Rect2(x + w * 0.5 - 1.5, y + h * 0.62 - 2.5, 3, 8), Color("ffffff"))
			draw_rect(R2, Color("0f2a55"), false, 2.0)
		"fusebox":
			draw_rect(R2, N("8a939b", 0.2))
			draw_rect(R2.grow(-2), N("5b646d", 0.2))
			for i in 3:
				draw_rect(Rect2(x + 3, y + 5 + i * 11, w - 6, 5), Color(0.95, 0.76, 0.3) if i == 0 else N("c6ced5", 0.2))
		"locked_door":
			if not o.get("opened", false):
				draw_rect(R2, N("6b4a2f", 0.2))
				draw_rect(R2.grow(-3), N("8a6340", 0.2))
				draw_circle(R2.get_center(), 3.0, Color(1.0, 0.25, 0.2))
		"lab_door":
			if o.get("opened", false):
				draw_rect(Rect2(x - 4, y, 4, s * 0.6), Color(0.3, 1.0, 0.5))
			else:
				draw_rect(R2, N("6f7c87", 0.2))
				draw_rect(Rect2(x + w * 0.5 - 1, y, 2, h), N("4a5560", 0.2))
				draw_rect(Rect2(x - 5, y + h * 0.5 - 6, 4, 12), Color(1.0, 0.25, 0.2))
		"mensa_shutter":
			draw_rect(R2, N("7f868c"))
