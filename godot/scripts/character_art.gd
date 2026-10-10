extends RefCounted
## Modular 3/4-view character renderer.
## A character is a Dictionary "look" (see characters.gd) drawn from body parts:
## legs + shoes, torso (by top_style), arms + hands, head + face, hair (by hair_style), accessories.
## Origin is between the feet. At scale 1 a figure is about 46 px tall.

enum {FRONT, BACK, LEFT, RIGHT}


static func facing_from_angle(a: float) -> int:
	var d := wrapf(a, -PI, PI)
	if d > PI * 0.25 and d < PI * 0.75:
		return FRONT
	if d < -PI * 0.25 and d > -PI * 0.75:
		return BACK
	return LEFT if absf(d) >= PI * 0.75 else RIGHT


static func col(look: Dictionary, key: String, fallback: String = "888888") -> Color:
	var v = look.get(key, fallback)
	if v is Color:
		return v
	return Color(String(v))


static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)


static func _cap(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, color: Color) -> void:
	# filled circle segment between two angles (degrees, 270 = straight up)
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / n))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, color)


static func _rect(ci: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), color)


static func draw_character(ci: CanvasItem, look: Dictionary, facing: int, phase: float, moving: bool, origin: Vector2 = Vector2.ZERO, sc: float = 1.0) -> void:
	ci.draw_set_transform(origin, 0.0, Vector2(sc, sc))
	var skin := col(look, "skin", "f1c9a5")
	var hair := col(look, "hair", "3b2a1e")
	var top := col(look, "top", "2f4f8f")
	var accent := col(look, "accent", "e07a2f")
	var pants := col(look, "pants", "2d3a52")
	var shoes := col(look, "shoes", "1f1f24")
	var style: String = look.get("top_style", "tshirt")
	var hstyle: String = look.get("hair_style", "kurz")
	var acc: Array = look.get("acc", [])
	if style == "overall":
		pants = top
	var sw := sin(phase) if moving else 0.0
	var b := absf(sin(phase)) * 1.2 if moving else 0.0   # body bob
	var hy := -35.0 - b                                    # head centre y
	var dark := Color(0, 0, 0, 0.18)

	# shadow
	_ell(ci, Vector2(0, 0), 10.0, 3.6, Color(0, 0, 0, 0.32))

	if facing == FRONT or facing == BACK:
		var front := facing == FRONT
		# long hair / ponytail behind the body when seen from the front
		if front and hstyle == "lang":
			_rect(ci, -7.5, hy - 1, 15, 15, hair)
			_ell(ci, Vector2(0, hy + 14), 7.5, 2.5, hair)
		# legs
		var ll := maxf(0.0, sw) * 2.5
		var lr := maxf(0.0, -sw) * 2.5
		_rect(ci, -5.2, -14 - b, 4.2, 12.5 + b - ll, pants)
		_rect(ci, 1.0, -14 - b, 4.2, 12.5 + b - lr, pants)
		_rect(ci, -5.7, -3 - ll, 5.0, 3.0, shoes)
		_rect(ci, 0.7, -3 - lr, 5.0, 3.0, shoes)
		# coat skirt
		if style == "labcoat":
			_rect(ci, -7.6, -15 - b, 15.2, 8.5, top)
			if front:
				_rect(ci, -0.5, -15 - b, 1.0, 8.5, top.darkened(0.2))
		# hood behind neck
		if style == "hoodie" and front:
			_ell(ci, Vector2(0, -28.5 - b), 7.5, 3.0, top.darkened(0.2))
		# torso
		_rect(ci, -7.0, -28 - b, 14.0, 15.0, top)
		ci.draw_circle(Vector2(-5.5, -25.5 - b), 3.0, top)
		ci.draw_circle(Vector2(5.5, -25.5 - b), 3.0, top)
		_rect(ci, -7.0, -16 - b, 14.0, 3.0, top.darkened(0.12))
		if front:
			match style:
				"overall":
					_rect(ci, -7.0, -28 - b, 14.0, 5.0, accent)
					_rect(ci, -5.0, -24 - b, 10.0, 10.0, top)
					_rect(ci, -4.6, -28 - b, 1.6, 5.0, top.darkened(0.15))
					_rect(ci, 3.0, -28 - b, 1.6, 5.0, top.darkened(0.15))
					_rect(ci, -2.0, -22 - b, 4.0, 3.0, top.darkened(0.15))
				"hoodie":
					_rect(ci, -4.5, -20 - b, 9.0, 4.0, top.darkened(0.15))
					ci.draw_line(Vector2(-1.5, -28 - b), Vector2(-1.5, -23 - b), accent, 0.9)
					ci.draw_line(Vector2(1.5, -28 - b), Vector2(1.5, -23 - b), accent, 0.9)
				"labcoat":
					ci.draw_colored_polygon(PackedVector2Array([Vector2(-3, -28 - b), Vector2(3, -28 - b), Vector2(0, -22 - b)]), accent)
					_rect(ci, -0.5, -22 - b, 1.0, 9.0, top.darkened(0.2))
					_rect(ci, 3.0, -21 - b, 3.0, 2.0, top.darkened(0.12))
				"jacket":
					_rect(ci, -2.0, -28 - b, 4.0, 13.0, accent)
					ci.draw_colored_polygon(PackedVector2Array([Vector2(-2, -28 - b), Vector2(-4.5, -28 - b), Vector2(-1, -21 - b)]), top.darkened(0.2))
					ci.draw_colored_polygon(PackedVector2Array([Vector2(2, -28 - b), Vector2(4.5, -28 - b), Vector2(1, -21 - b)]), top.darkened(0.2))
				"sweater":
					_rect(ci, -3.0, -28 - b, 6.0, 1.5, accent)
				_:
					ci.draw_circle(Vector2(0, -27.5 - b), 2.2, skin.darkened(0.05))
					_rect(ci, -3.5, -24 - b, 7.0, 4.0, accent)
		else:
			if style == "hoodie":
				_ell(ci, Vector2(0, -26.5 - b), 5.5, 3.5, top.darkened(0.18))
		if "toolbelt" in acc:
			_rect(ci, -7.2, -16.5 - b, 14.4, 2.6, Color("6b4a2f"))
			_rect(ci, -6.5, -15 - b, 3.0, 3.5, Color("8a6340"))
			_rect(ci, 3.5, -15 - b, 3.0, 3.5, Color("8a6340"))
		if "lanyard" in acc and front:
			ci.draw_line(Vector2(-2.5, -28 - b), Vector2(0, -21 - b), accent, 0.8)
			ci.draw_line(Vector2(2.5, -28 - b), Vector2(0, -21 - b), accent, 0.8)
			_rect(ci, -1.8, -21 - b, 3.6, 4.5, Color("f3efe2"))
		if "backpack" in acc:
			if front:
				_rect(ci, -5.5, -28 - b, 1.6, 9.0, Color("3a3f46"))
				_rect(ci, 3.9, -28 - b, 1.6, 9.0, Color("3a3f46"))
			else:
				_rect(ci, -5.5, -27 - b, 11.0, 12.0, Color("3a3f46"))
				_rect(ci, -4.5, -20 - b, 9.0, 4.0, Color("4a5058"))
		if "erstibag" in acc:
			# green drawstring bag from the Ersti-Tag, worn on the back
			var cord := Color("f3efe2")
			if front:
				ci.draw_line(Vector2(-4.5, -28 - b), Vector2(-6.8, -17 - b), cord, 1.1)
				ci.draw_line(Vector2(4.5, -28 - b), Vector2(6.8, -17 - b), cord, 1.1)
			else:
				var bag := Color("2f9e5b")
				_rect(ci, -7.0, -30 - b, 14.0, 13.5, bag)
				_ell(ci, Vector2(0, -16.5 - b), 7.0, 2.4, bag)
				_rect(ci, -7.0, -30 - b, 14.0, 1.6, bag.darkened(0.25))
				ci.draw_line(Vector2(-7.0, -29.2 - b), Vector2(7.0, -29.2 - b), cord, 1.1)
				_rect(ci, -2.6, -25.5 - b, 5.2, 4.2, cord)
				_rect(ci, -1.6, -24.6 - b, 3.2, 1.0, bag)
		# arms
		var sleeve := skin if style == "tshirt" else top
		var al := sw * 1.6
		_rect(ci, -9.8, -27 - b - al, 3.6, 11.0, sleeve)
		_rect(ci, 6.2, -27 - b + al, 3.6, 11.0, sleeve)
		if style == "tshirt":
			_rect(ci, -9.8, -27 - b - al, 3.6, 4.0, top)
			_rect(ci, 6.2, -27 - b + al, 3.6, 4.0, top)
		ci.draw_circle(Vector2(-8.0, -15.5 - b - al), 2.1, skin)
		ci.draw_circle(Vector2(8.0, -15.5 - b + al), 2.1, skin)
		if "laptop" in acc and front:
			_rect(ci, 6.5, -24 - b + al, 6.5, 9.0, Color("8a939b"))
			_rect(ci, 7.2, -23.3 - b + al, 5.1, 7.6, Color("b9c3c9"))
		if "flashlight" in acc:
			_rect(ci, 7.0, -17 - b + al, 2.0, 5.0, Color("2b2f35"))
			ci.draw_circle(Vector2(8.0, -11.8 - b + al), 1.4, Color(1, 0.95, 0.7))
		if "tray" in acc:
			# Mensa tray, carried with both hands
			if front:
				_tray(ci, Vector2(0, -18.5 - b), 18.0)
			else:
				_rect(ci, -10.5, -19.5 - b, 3.0, 2.2, Color("c98a4b"))
				_rect(ci, 7.5, -19.5 - b, 3.0, 2.2, Color("c98a4b"))
		# head
		_rect(ci, -2.0, -30 - b, 4.0, 3.0, skin.darkened(0.08))
		ci.draw_circle(Vector2(0, hy), 7.5, skin)
		if front:
			ci.draw_circle(Vector2(-7.4, hy + 0.5), 1.5, skin.darkened(0.06))
			ci.draw_circle(Vector2(7.4, hy + 0.5), 1.5, skin.darkened(0.06))
			if "beard" in acc:
				_cap(ci, Vector2(0, hy), 7.6, 10, 170, hair)
				_rect(ci, -2.2, hy + 3.0, 4.4, 1.2, skin.darkened(0.25))
			_rect(ci, -3.3, hy - 0.8, 1.7, 2.4, Color("1f1a17"))
			_rect(ci, 1.6, hy - 0.8, 1.7, 2.4, Color("1f1a17"))
			if not "beard" in acc:
				_rect(ci, -1.2, hy + 3.4, 2.4, 0.9, skin.darkened(0.3))
			if "glasses" in acc:
				var gc := Color("22262b")
				ci.draw_rect(Rect2(-4.6, hy - 1.9, 4.0, 3.6), gc, false, 0.8)
				ci.draw_rect(Rect2(0.6, hy - 1.9, 4.0, 3.6), gc, false, 0.8)
				ci.draw_line(Vector2(-0.6, hy - 0.5), Vector2(0.6, hy - 0.5), gc, 0.8)
		# hair
		_draw_hair_fb(ci, hstyle, hair, accent, hy, front)
		# head accessories
		if "goggles" in acc:
			_rect(ci, -7.8, hy - 5.5, 15.6, 2.2, Color("2b2f35"))
			if front:
				ci.draw_circle(Vector2(-3.0, hy - 4.5), 2.5, Color("7fc8e8"))
				ci.draw_circle(Vector2(3.0, hy - 4.5), 2.5, Color("7fc8e8"))
		if "headphones" in acc:
			ci.draw_arc(Vector2(0, hy - 1), 8.6, deg_to_rad(195), deg_to_rad(345), 14, Color("22262b"), 1.8)
			_rect(ci, -9.6, hy - 2.5, 3.0, 5.0, Color("22262b"))
			_rect(ci, 6.6, hy - 2.5, 3.0, 5.0, Color("22262b"))
			_rect(ci, -9.0, hy - 1.5, 1.6, 3.0, accent)
			_rect(ci, 7.4, hy - 1.5, 1.6, 3.0, accent)
		if not front and hstyle == "lang":
			_rect(ci, -7.5, hy - 1, 15, 14, hair)
			_ell(ci, Vector2(0, hy + 13), 7.5, 2.5, hair)
	else:
		var k := -1.0 if facing == LEFT else 1.0
		var d := sw * 3.0
		# back leg, front leg
		_rect(ci, -2.0 - d, -14 - b, 4.2, 12.5 + b, pants.darkened(0.2))
		_rect(ci, -2.0 - d + (0.5 if k > 0 else -2.5), -3, 4.8, 3.0, shoes.darkened(0.2))
		if style == "labcoat":
			_rect(ci, -5.5, -15 - b, 11.0, 8.5, top)
		_rect(ci, -2.0 + d, -14 - b, 4.2, 12.5 + b, pants)
		_rect(ci, -2.0 + d + (0.5 if k > 0 else -2.5), -3, 4.8, 3.0, shoes)
		if style == "labcoat":
			_rect(ci, -5.5, -15 - b, 11.0, 8.5, top)
		# backpack
		if "backpack" in acc:
			_rect(ci, -k * 5.0 - 3.0, -27 - b, 6.0, 11.0, Color("3a3f46"))
		if "erstibag" in acc:
			_rect(ci, -k * 5.6 - 3.6, -30 - b, 7.2, 13.5, Color("2f9e5b"))
			_rect(ci, -k * 5.6 - 1.4, -25.5 - b, 2.8, 3.2, Color("f3efe2"))
		# torso
		_rect(ci, -5.0, -28 - b, 10.0, 15.0, top)
		_rect(ci, -5.0, -16 - b, 10.0, 3.0, top.darkened(0.12))
		if style == "overall":
			_rect(ci, -5.0, -28 - b, 10.0, 4.0, accent)
			_rect(ci, -1.0, -28 - b, 2.0, 5.0, top.darkened(0.15))
		elif style == "hoodie":
			_ell(ci, Vector2(-k * 3.5, -27.5 - b), 3.5, 3.0, top.darkened(0.18))
		elif style == "jacket" or style == "labcoat":
			_rect(ci, k * 3.0 - 1.0, -28 - b, 2.0, 6.0, accent)
		if "toolbelt" in acc:
			_rect(ci, -5.2, -16.5 - b, 10.4, 2.6, Color("6b4a2f"))
			_rect(ci, k * 2.0 - 1.5, -15 - b, 3.0, 3.5, Color("8a6340"))
		# arm
		var sleeve := skin if style == "tshirt" else top
		_rect(ci, -1.8 + d * 0.8, -27 - b, 3.6, 11.0, sleeve)
		if style == "tshirt":
			_rect(ci, -1.8 + d * 0.8, -27 - b, 3.6, 4.0, top)
		ci.draw_circle(Vector2(d * 0.8, -15.5 - b), 2.1, skin)
		if "laptop" in acc:
			_rect(ci, -1.5 + d * 0.8 + k * 1.0, -24 - b, 3.0, 9.5, Color("8a939b"))
		if "flashlight" in acc:
			_rect(ci, d * 0.8 + (0.0 if k > 0 else -5.0), -16.5 - b, 5.0, 2.0, Color("2b2f35"))
			ci.draw_circle(Vector2(d * 0.8 + k * 5.5, -15.5 - b), 1.4, Color(1, 0.95, 0.7))
		if "tray" in acc:
			_tray(ci, Vector2(k * 8.5, -18.5 - b), 11.0)
		# head
		_rect(ci, -2.0, -30 - b, 4.0, 3.0, skin.darkened(0.08))
		ci.draw_circle(Vector2(k * 0.6, hy), 7.3, skin)
		ci.draw_circle(Vector2(k * 6.8, hy + 1.0), 1.3, skin)
		if "beard" in acc:
			_cap(ci, Vector2(k * 0.6, hy), 7.4, 20 if k > 0 else 70, 110 if k > 0 else 160, hair)
		_rect(ci, k * 3.6 - 0.8, hy - 0.8, 1.7, 2.4, Color("1f1a17"))
		if "glasses" in acc:
			ci.draw_rect(Rect2(k * 3.6 - 2.2, hy - 1.9, 4.4, 3.6), Color("22262b"), false, 0.8)
			ci.draw_line(Vector2(k * 1.4, hy - 0.5), Vector2(-k * 1.5, hy - 1.0), Color("22262b"), 0.8)
		_draw_hair_side(ci, hstyle, hair, accent, hy, k)
		if "goggles" in acc:
			_rect(ci, -7.0, hy - 5.5, 14.0, 2.2, Color("2b2f35"))
			ci.draw_circle(Vector2(k * 4.5, hy - 4.5), 2.4, Color("7fc8e8"))
		if "headphones" in acc:
			ci.draw_arc(Vector2(0, hy - 1), 8.4, deg_to_rad(200), deg_to_rad(340), 14, Color("22262b"), 1.8)
			ci.draw_circle(Vector2(-k * 0.8, hy), 3.0, Color("22262b"))
			ci.draw_circle(Vector2(-k * 0.8, hy), 1.6, accent)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Mensa tray with a plate and a glass, centred on `c` (also used for trays standing on tables).
static func _tray(ci: CanvasItem, c: Vector2, w: float) -> void:
	_rect(ci, c.x - w / 2.0, c.y - 2.2, w, 4.4, Color("c98a4b"))
	_rect(ci, c.x - w / 2.0, c.y + 1.2, w, 1.0, Color("9a6431"))
	_ell(ci, c + Vector2(-w * 0.14, -0.6), w * 0.24, 1.7, Color("f3efe2"))
	_ell(ci, c + Vector2(-w * 0.14, -0.9), w * 0.15, 1.0, Color("a5612a"))
	_rect(ci, c.x + w * 0.2, c.y - 4.0, 2.4, 3.6, Color("9cc3e6"))


static func _draw_hair_fb(ci: CanvasItem, hstyle: String, hair: Color, accent: Color, hy: float, front: bool) -> void:
	var c := Vector2(0, hy)
	if not front:
		match hstyle:
			"glatze":
				_cap(ci, c, 7.6, 20, 160, hair)
			"cap":
				ci.draw_circle(c, 7.8, hair)
				_cap(ci, c, 8.2, 180, 360, accent)
			_:
				ci.draw_circle(c, 7.9, hair)
		match hstyle:
			"zopf":
				_ell(ci, Vector2(0, hy + 7.5), 2.6, 4.5, hair)
				_rect(ci, -1.5, hy + 3.0, 3.0, 2.0, Color("c0392b"))
			"dutt":
				ci.draw_circle(Vector2(0, hy - 8.5), 3.6, hair)
			"locken":
				for i in 7:
					var a := deg_to_rad(180 + i * 30)
					ci.draw_circle(c + Vector2(cos(a), sin(a)) * 7.2, 2.8, hair)
		return
	match hstyle:
		"kurz":
			_cap(ci, c, 7.9, 185, 355, hair)
			_rect(ci, -7.6, hy - 2.5, 2.0, 3.5, hair)
			_rect(ci, 5.6, hy - 2.5, 2.0, 3.5, hair)
		"lang":
			_cap(ci, c, 8.0, 180, 360, hair)
			_rect(ci, -8.0, hy - 2.0, 2.6, 11.0, hair)
			_rect(ci, 5.4, hy - 2.0, 2.6, 11.0, hair)
		"zopf":
			_cap(ci, c, 7.9, 182, 358, hair)
			_ell(ci, Vector2(-8.2, hy + 3.0), 1.8, 3.6, hair)
		"dutt":
			_cap(ci, c, 7.9, 185, 355, hair)
			ci.draw_circle(Vector2(0, hy - 8.5), 3.6, hair)
		"locken":
			_cap(ci, c, 7.6, 185, 355, hair)
			for i in 7:
				var a := deg_to_rad(185 + i * 28)
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * 7.0, 2.8, hair)
		"cap":
			_cap(ci, c, 8.3, 180, 360, accent)
			_ell(ci, Vector2(0, hy - 2.2), 7.5, 2.0, accent.darkened(0.25))
			_rect(ci, -7.6, hy - 1.5, 1.8, 3.0, hair)
			_rect(ci, 5.8, hy - 1.5, 1.8, 3.0, hair)
		"glatze":
			_rect(ci, -7.6, hy - 1.0, 1.6, 3.0, hair)
			_rect(ci, 6.0, hy - 1.0, 1.6, 3.0, hair)
			ci.draw_circle(Vector2(-2.5, hy - 4.5), 1.5, Color(1, 1, 1, 0.25))


static func _draw_hair_side(ci: CanvasItem, hstyle: String, hair: Color, accent: Color, hy: float, k: float) -> void:
	var c := Vector2(k * 0.6, hy)
	match hstyle:
		"glatze":
			_cap(ci, c, 7.4, 90 if k > 0 else 30, 150 if k > 0 else 90, hair)
			return
		"cap":
			_cap(ci, c, 8.0, 180, 360, accent)
			_ell(ci, Vector2(k * 7.5, hy - 2.0), 4.0, 1.6, accent.darkened(0.25))
			_rect(ci, -k * 7.2 - 1.0, hy - 2.0, 2.4, 5.0, hair)
			return
	# hair covers top and back of the head
	_cap(ci, c, 7.9, 180, 360, hair)
	if k > 0:
		_cap(ci, c, 7.9, 90, 200, hair)
	else:
		_cap(ci, c, 7.9, -20, 90, hair)
	match hstyle:
		"lang":
			_rect(ci, -k * 7.5 - 2.0, hy - 1.0, 4.5, 13.0, hair)
		"zopf":
			_ell(ci, Vector2(-k * 9.0, hy + 2.0), 2.4, 4.6, hair)
			_rect(ci, -k * 7.8 - 1.0, hy - 1.0, 2.0, 2.0, Color("c0392b"))
		"dutt":
			ci.draw_circle(Vector2(-k * 2.0, hy - 8.5), 3.6, hair)
		"locken":
			for i in 6:
				var a := deg_to_rad(200 + i * 30) if k > 0 else deg_to_rad(-20 - i * 30 + 360)
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * 7.0, 2.8, hair)
