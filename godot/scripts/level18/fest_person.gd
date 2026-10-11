extends Node2D
## Level 18 (Ersti-Fest): somebody at the party. Stands, or dances on the spot to the beat.
## level.gd places them and tells them what to do; the node only draws itself.

const ART = preload("res://scripts/character_art.gd")
const UI = preload("res://scripts/ui.gd")

var main
var look: Dictionary = {}
var facing := 0
var dancing := false
var beat := 0.5          # seconds per beat
var t := 0.0
var turn_t := 0.0
var bubble := ""
var bubble_t := 0.0
var bubble_col := UI.YELLOW
var glide_to := Vector2.ZERO   # px; moves there when set_glide was called
var gliding := false


func _ready() -> void:
	t = randf() * 10.0
	turn_t = randf_range(0.5, 3.0)


func say(what: String, dur: float = 2.0, col: Color = UI.YELLOW) -> void:
	bubble = what
	bubble_t = dur
	bubble_col = col


func glide(to_px: Vector2) -> void:
	glide_to = to_px
	gliding = true


func _process(delta: float) -> void:
	t += delta
	bubble_t = maxf(0.0, bubble_t - delta)
	if gliding:
		global_position = global_position.move_toward(glide_to, 70.0 * delta)
		gliding = global_position.distance_to(glide_to) > 0.5
	if dancing:
		turn_t -= delta
		if turn_t <= 0.0:
			turn_t = beat * [2, 4, 4, 8][randi() % 4]
			facing = [ART.FRONT, ART.LEFT, ART.RIGHT, ART.FRONT, ART.BACK][randi() % 5]
	queue_redraw()


func _draw() -> void:
	var o := Vector2.ZERO
	if dancing:
		var b := absf(sin(t * PI / beat))
		o = Vector2(sin(t * PI / beat * 0.5) * 2.0, -b * 3.5)
	ART.draw_character(self, look, facing, t * (8.0 if dancing else 0.0), dancing or gliding, o)
	if bubble_t > 0.0 and bubble != "":
		var c := o + Vector2(0, -58.0 + sin(t * 14.0) * 1.5)
		draw_circle(c, 10.0, Color(0.08, 0.09, 0.17, 0.92))
		draw_arc(c, 10.0, 0.0, TAU, 24, bubble_col, 2.0)
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, c + Vector2(-w / 2.0, 5.5), bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, bubble_col)
