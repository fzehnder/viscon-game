extends Node2D
## Level 6 · Basisprüfung, the last level of the story, in the ONA exam hall (computer exam).
## Both players sit left and right of a Streber and copy from his screen in first person
## (exam.gd): turn the head towards him to read, back to the own screen to type. He and the
## supervisor look up now and then; whoever is seen with the head turned is caught, and the exam
## is over for both (red light, green light). The camera is required (Track.face yaw, the
## direction is calibrated at the start).

const ExamScript = preload("res://scripts/level6/exam.gd")
const Cutscene = preload("res://scripts/cutscene.gd")

const DEF := {
	"name": "Basisprüfung",
	"tag": "LEVEL 6 · FINALE",
	"mode": "day",
	"time": 900.0,   # the exam has its own clock (exam.gd EXAM_TIME)
	"course": "252-0006-00 L", "ects": 8, "block": "B",
	"start": Vector2(26.0, 42.0),
	"intro": "Prüfungstag in der ONA-Halle, Computerprüfung. Gelernt habt ihr nichts, aber neben euch sitzt der Streber des Jahrgangs.\n\nSetzt euch nebeneinander vor die Kamera. Dreht den Kopf zu ihm (links sitzende Person nach links, rechts sitzende nach rechts), um auf seinen Bildschirm zu schauen, und wieder nach vorne, um es einzutippen. Der Streber zuckt, bevor er sich umdreht, die Aufsicht steht auf, bevor sie in die Halle schaut. Wer mit gedrehtem Kopf erwischt wird, fliegt, und ihr beide mit.",
	"hint": "Diese Prüfung geht nur mit Kamera.",
	"start_toast": ["Prüfung", "Viel Glück."],
	"win_title": "Basisprüfung bestanden!",
	"win_text": "%s & %s haben die Basisprüfung bestanden. Wie, fragt besser niemand.",
	"tasks": [
		{"id": "exam", "name": "Prüfung abschreiben", "where": "beim Streber, ohne erwischt zu werden", "type": "level"},
	],
}

var main            # main.gd, set before _ready
var layer: CanvasLayer
var exam = null
var started := false


func _process(_delta: float) -> void:
	if started or main == null or main.state != "play":
		return
	started = true
	main.state = "cutscene"
	main.hud.visible = false
	for pl in main.players:
		pl.enabled = false
	var steps := [
		{"say": 0, "text": "Prüfungstag. Hast du gelernt?"},
		{"say": 1, "text": "Nein. Wir waren in der Mensa, im Labor, am Polyball und nachts am Hönggerberg."},
		{"say": 0, "text": "Aber schau, wer neben uns sitzt: der Streber. Der hat alles richtig."},
		{"say": 1, "text": "Dann schauen wir halt ein bisschen rüber. Nur nicht erwischen lassen."},
		{"title": "BASISPRÜFUNG", "sub": "ONA-Halle  ·  Computerprüfung  ·  Blick auf den eigenen Bildschirm"},
	]
	var cs = Cutscene.new()
	main.add_child(cs)
	cs.play(steps, _open_exam)


func _open_exam() -> void:
	main.state = "play"
	layer = CanvasLayer.new()
	layer.layer = 15   # above the HUD (10), below minigames (20)
	main.add_child(layer)
	exam = ExamScript.new()
	exam.main = main
	exam.finished.connect(_on_exam_done)
	layer.add_child(exam)


func _on_exam_done(won: bool, info: Dictionary) -> void:
	if not won:
		main.state = "lost"
		var who: int = info["who"]
		var body := "Die Zeit ist um, und eure Blätter sind halb leer."
		var title := "Durchgefallen"
		if who >= 0:
			title = "Erwischt!"
			body = "Der Streber hat %s beim Abschreiben gesehen und die Aufsicht gerufen. Beide Prüfungen werden eingezogen." % Game.name_of(who)
		main.hud.visible = true
		main.hud.show_overlay(title, body, "R nochmals versuchen · M zum Startbildschirm", "Nochmals versuchen", true, "lose", String(DEF["tag"]))
		layer.queue_free()
		exam = null
		return
	main.mistakes_total = int(info["near"])   # close calls lower the grade a little
	layer.queue_free()
	exam = null
	main.hud.visible = true
	main._task_done(0, "exam")
	main._task_done(1, "exam")


## The end of the story: a short cutscene, then the normal win screen of main.gd.
func finale(done: Callable) -> void:
	main.state = "cutscene"
	main.hud.visible = false
	var steps := [
		{"phones": "ETH Zürich · Prüfungsplanstelle", "text": "Ihre Noten der Basisprüfung sind verfügbar"},
		{"say": 1, "text": "Bestanden. Ich glaub's nicht."},
		{"say": 0, "text": "Der Streber hat übrigens eine 6. Wir eine 4. Fair ist fair."},
		{"title": "BASISPRÜFUNG BESTANDEN", "sub": "Ende  ·  Danke fürs Spielen!"},
	]
	var cs = Cutscene.new()
	main.add_child(cs)
	cs.play(steps, func():
		main.state = "play"
		main.hud.visible = true
		done.call())
