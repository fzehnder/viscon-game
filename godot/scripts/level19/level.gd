extends Node2D
## Elective "Freelancing" (block "W"): a job board with four freelance jobs (AMZ Racing, ARIS,
## Swissloop Tunneling and a made-up MedTech startup), then a job interview as a video call
## where the players answer out loud into the microphone (speech.gd, Whisper offline).
## Not part of the story: started from the transcript (Wahlfächer) whenever the players like.
## The board and the interviews are interview.gd, the jobs and questions jobs.gd.

const InterviewScript = preload("res://scripts/level19/interview.gd")
const LV = preload("res://scripts/levels.gd")
const Cutscene = preload("res://scripts/cutscene.gd")
const JOBS = preload("res://scripts/level19/jobs.gd")

const DEF := {
	"name": "Freelancing",
	"tag": "WAHLFACH · D-MAVT",
	"mode": "day",
	"time": 3600.0,   # the interviews decide, not the clock
	"course": "151-0889-00 L", "ects": 3, "block": "W",
	"start": Vector2(26.0, 42.0),
	"intro": "Wahlfach Freelancing am D-MAVT (Maschinenbau und Verfahrenstechnik): Bewerbt euch zu zweit auf einen Freelance-Job bei AMZ Racing, ARIS, Swissloop Tunneling oder einem MedTech-Startup. Das Interview läuft als Video-Call, und ihr antwortet laut ins Mikrofon.\n\nIhr habt nur eine Bewerbung pro Spiel, wählt die Firma gut. Wer gefragt wird, hält seine Taste gedrückt (%s: E, %s: Enter) und spricht, und zwar ausführlich, mit Beispielen. Nach 12 Sekunden Schweigen ist die Frage verloren. Fünf von sechs überzeugenden Antworten bringen den Job." % ["Pink", "Blau"],
	"hint": "Ohne Spracherkennung antwortet ihr mit den Zahlentasten (1 2 3 bzw. 8 9 0).",
	"start_toast": ["Bewerbung läuft", "Gleich geht's los."],
	"win_title": "Wahlfach Freelancing bestanden!",
	"win_text": "%s & %s haben sich auf dem Freelance-Markt behauptet.",
	"tasks": [
		{"id": "job", "name": "Bewerbungsgespräch führen", "where": "ETH Freelance-Börse, per Video-Call", "type": "level"},
	],
}

var main            # main.gd, set before _ready
var layer: CanvasLayer
var app = null
var finished := false
var intro_seen := false
var best := 0.0


func _process(_delta: float) -> void:
	if finished or app != null or main == null or main.state != "play":
		return
	if not intro_seen:
		_play_intro()
		return
	layer = CanvasLayer.new()
	layer.layer = 15   # above the HUD (10), below minigames (20)
	main.add_child(layer)
	app = InterviewScript.new()
	app.main = main
	app.finished.connect(_on_done)
	layer.add_child(app)
	main.hud.visible = false
	for pl in main.players:
		pl.enabled = false


func _play_intro() -> void:
	intro_seen = true
	main.state = "cutscene"
	main.hud.visible = false
	for pl in main.players:
		pl.enabled = false
	var steps := [
		{"say": 1, "text": "Mein Konto ist leer. Die Mensa allein frisst mein ganzes Budget."},
		{"say": 0, "text": "Dann suchen wir uns einen Freelance-Job. Am D-MAVT gibt's sogar ein Wahlfach dafür."},
		{"phones": "ETH Freelance-Börse", "text": "4 neue Jobs: AMZ, ARIS, Swissloop, Vitalfaden"},
		{"say": 1, "text": "Und wie bewirbt man sich?"},
		{"say": 0, "text": "Video-Call. Die stellen Fragen, wir antworten. Laut. Ins Mikrofon."},
		{"title": "WAHLFACH FREELANCING", "sub": "D-MAVT  ·  Bewerbung per Video-Call"},
	]
	var cs = Cutscene.new()
	main.add_child(cs)
	cs.play(steps, func(): main.state = "play")


func _on_done(grade: float) -> void:
	finished = true
	best = grade
	layer.queue_free()
	app = null
	main.hud.visible = true
	main._task_done(0, "job")
	main._task_done(1, "job")


## Own end screen: the grade is the best interview, not the clock (main._win_day).
func finale(_done: Callable) -> void:
	main._close_minis()
	main.state = "won"
	for pl in main.players:
		pl.enabled = false
	var grade := clampf(best, 1.0, 6.0)
	Game.add_grade(Game.level, grade, int(main.time_played), 0)
	var a := JOBS.application()
	var jobs := "\n(keine Bewerbung)"
	if not a.is_empty():
		var nm := String(JOBS.job(String(a["id"])).get("name", a["id"]))
		jobs = "\n•  %s: %s" % [nm, "angestellt" if a["outcome"] == "hired" else "Absage"]
	var verdict := "Hervorragend!" if grade >= 5.5 else ("Gut gemacht." if grade >= 4.5 else ("Bestanden." if grade >= 4.0 else "Knapp daneben."))
	main.hud.show_overlay(String(DEF["win_title"]),
		"%s\n\nEure Bewerbung:%s\n\nNote %s · %s\n\nIn der Schweiz ist 6 die Bestnote, ab 4 ist bestanden." % [
			String(DEF["win_text"]) % [Game.name_of(0), Game.name_of(1)], jobs, String.num(grade, 2), verdict],
		"R nochmals bewerben · L Leistungsüberblick · M zum Startbildschirm",
		"Nochmals bewerben", true, "win", String(DEF["tag"]))
