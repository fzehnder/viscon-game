extends Control
## A small telling-off: somebody pops in at the side of the screen, wags a finger and says one
## strict, slightly funny line. For tasks that go wrong: caught with the loot, a mistake in a
## minigame, running in the lab. It does not stop the game, takes no input and goes by itself.
##
##   Scold.tell(main, pid, look, "Name", "Text")        pid: on whose side of the screen (0 left, 1 right)
##   Scold.tell(main, pid, op.look, op.pname, Scold.line(Scold.BAG, op.bag_name), "bag")
##   Scold.tell(main, pid, players[pid].look, name, Scold.line(Scold.OOPS), "oops", true)
## `kind` keeps the same thing from popping up again within COOLDOWN seconds on that side.
## `own` true: it is the player talking to themselves (sheepish instead of strict, no finger),
## and the card sits at the bottom, clear of the minigame.
## Ready-made lines: BAG (the owner of what was stolen; %s is the thing), OOPS (to oneself).

const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")

const SIZE := Vector2(340.0, 116.0)
const FACE := Vector2(92.0, 100.0)
const STAY := 3.8             # seconds it stays
const SLIDE := 0.3
const TYPE_SPEED := 46.0      # letters per second
const COOLDOWN := 6.0
const LAYER := 22             # above the minigames (20), below cutscenes (30)
const BAG := [
	"Das ist MEINE %s. Da sind meine Gratis-Kugelschreiber drin!",
	"Finger weg! Für die %s bin ich um sechs Uhr aufgestanden.",
	"Netter Versuch. Die %s bleibt bei mir, und du bleibst mir vom Leib.",
	"Klauen am ersten Tag? Das merke ich mir bis zum Master.",
]
const OOPS := [
	"Ups. Das war nichts.",
	"Konzentration. Das ist die ETH, nicht der Kindergarten.",
	"Das hat niemand gesehen. Hoffentlich.",
	"Nochmal. Diesmal mit Hirn.",
]

static var last := {}         # "side/kind" -> when it was shown last (msec)

var look: Dictionary = {}
var who := ""
var text := ""
var side := 0
var own := false
var t := 0.0
var face: Control


static func pick(lines: Array) -> String:
	return String(lines[randi() % lines.size()])


## One of `lines` in the language of the game; a %s in it becomes `thing` (also translated).
static func line(lines: Array, thing: String = "") -> String:
	var s := UI.T(pick(lines))
	return s % UI.T(thing) if s.contains("%s") else s


## Shows a telling-off on the side of player `pid`. false if one of this kind was just there.
static func tell(main: Node, pid: int, p_look: Dictionary, p_who: String, p_text: String, kind: String = "", p_own: bool = false) -> bool:
	if main == null or not is_instance_valid(main):
		return false
	var p_side := clampi(pid, 0, 1)
	var key := "%d/%s" % [p_side, kind]
	var now := Time.get_ticks_msec()
	if kind != "" and now - int(last.get(key, -100000)) < int(COOLDOWN * 1000.0):
		return false
	last[key] = now
	var layer: CanvasLayer = main.get_node_or_null("ScoldLayer")
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "ScoldLayer"
		layer.layer = LAYER
		main.add_child(layer)
	for c in layer.get_children():
		if "side" in c and c.side == p_side:
			c.queue_free()            # one at a time per side
	var card = load("res://scripts/scold.gd").new()
	card.look = p_look
	card.who = p_who
	card.text = p_text
	card.side = p_side
	card.own = p_own
	layer.add_child(card)
	return true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = SIZE
	face = Control.new()                 # the head, cut off at the chest by this frame
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.clip_contents = true
	face.size = FACE
	face.position = Vector2(8.0 if side == 0 else SIZE.x - FACE.x - 8.0, 8.0)
	face.draw.connect(_draw_face)
	add_child(face)
	_place()
	UI.sfx("pop", -9.0)


func _place() -> void:
	var vs := get_viewport_rect().size
	var a := clampf(t / SLIDE, 0.0, 1.0)
	var out := clampf((t - STAY) / SLIDE, 0.0, 1.0)
	var k := (1.0 - pow(1.0 - a, 3.0)) * (1.0 - out * out)
	var inside := 16.0 if side == 0 else vs.x - SIZE.x - 16.0
	var outside := -SIZE.x - 20.0 if side == 0 else vs.x + 20.0
	position = Vector2(lerpf(outside, inside, k), vs.y - SIZE.y - 70.0 if own else vs.y * 0.57)


func _process(delta: float) -> void:
	t += delta
	if t >= STAY + SLIDE:
		queue_free()
		return
	_place()
	queue_redraw()
	face.queue_redraw()


func _draw() -> void:
	draw_style_box(UI.box(UI.PAPER, UI.DARK, 14, 3, 0.0, true), Rect2(Vector2.ZERO, SIZE))
	var font := ThemeDB.fallback_font
	var x := FACE.x + 22.0 if side == 0 else 16.0
	var w := SIZE.x - FACE.x - 38.0
	draw_string(font, Vector2(x, 26.0), who, HORIZONTAL_ALIGNMENT_LEFT, w, 13, Color("8c1c2b") if not own else UI.ETH_BLUE)
	draw_multiline_string(font, Vector2(x, 47.0), text.substr(0, int(t * TYPE_SPEED)), HORIZONTAL_ALIGNMENT_LEFT, w, 15, -1, UI.INK)


func _draw_face() -> void:
	face.draw_rect(Rect2(Vector2.ZERO, FACE), Color("23263a"))
	var sc := 2.7
	var bob := sin(t * 9.0) * 1.2 if t < 2.2 else 0.0
	var at := Vector2(FACE.x / 2.0, FACE.y + 15.0 * sc + bob)
	ART.draw_character(face, look, ART.FRONT, 0.0, false, at, sc)
	face.draw_set_transform(at, 0.0, Vector2(sc, sc))
	var ink := Color("15162b")
	var typing := t * TYPE_SPEED < text.length()
	if own:
		# sheepish: eyebrows up at the outside, a drop of sweat
		face.draw_line(Vector2(-6.5, -42.4), Vector2(-1.6, -41.0), ink, 1.1)
		face.draw_line(Vector2(6.5, -42.4), Vector2(1.6, -41.0), ink, 1.1)
		var dy := fmod(t * 5.0, 4.0)
		face.draw_circle(Vector2(8.6, -40.0 + dy), 1.3, Color("7fc4ff"))
	else:
		# strict: eyebrows down in the middle, and the finger
		face.draw_line(Vector2(-6.5, -41.4), Vector2(-1.5, -39.2), ink, 1.3)
		face.draw_line(Vector2(6.5, -41.4), Vector2(1.5, -39.2), ink, 1.3)
		var skin: Color = ART.col(look, "skin", "f1c9a5")
		var hand := Vector2(11.5 if side == 0 else -11.5, -22.5)
		var wag := sin(t * 13.0) * 0.5 if t < 2.4 else 0.0
		face.draw_circle(hand, 3.4, skin)
		face.draw_line(hand, hand + Vector2(sin(wag) * 8.0, -cos(wag) * 8.0), skin, 2.6)
	face.draw_rect(Rect2(-2.4, -30.5, 4.8, 1.1 + (2.2 * absf(sin(t * 17.0)) if typing else 0.0)), ink)
	face.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	face.draw_rect(Rect2(Vector2.ZERO, FACE), UI.DARK, false, 3.0)
