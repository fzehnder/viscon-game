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
	"win_title": "Wahlfach Freelancing\nbestanden!",
	"lose_title": "Wahlfach Freelancing\nnicht bestanden",
	"denied_title": "Bewerbung\nabgelehnt",
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
		{"title": "WAHLFACH\nFREELANCING", "sub": "D-MAVT  ·  Bewerbung per Video-Call"},
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
		jobs = ""
		var said_no: Array = (a.get("rejected", []) as Array).duplicate()
		if a["outcome"] != "hired" and not said_no.has(a["id"]):
			said_no.append(a["id"])
		for id in said_no:
			jobs += "\n•  %s: %s" % [String(JOBS.job(String(id)).get("name", id)), "Absage"]
		if a["outcome"] == "hired":
			jobs += "\n•  %s: %s" % [String(JOBS.job(String(a["id"])).get("name", a["id"])), "angestellt"]
	var passed := grade >= 4.0
	var verdict := "Hervorragend!" if grade >= 5.5 else ("Gut gemacht." if grade >= 4.5 else ("Bestanden." if passed else "Knapp daneben."))
	var story := String(DEF["win_text"]) % [Game.name_of(0), Game.name_of(1)] if passed \
		else "%s & %s haben es versucht. Diesmal hat es mit dem Job nicht geklappt." % [Game.name_of(0), Game.name_of(1)]
	var title := String(DEF["win_title"]) if passed else String(DEF["lose_title"])
	# no job: the end screen says so, whatever the grade (4 of 6 right is a pass, but no job)
	var denied: bool = not a.is_empty() and a["outcome"] != "hired"
	if denied:
		passed = false
		title = String(DEF["denied_title"])
		verdict = "Diesmal kein Job."
		story = "%s & %s haben den Job bei %s nicht bekommen." % [Game.name_of(0), Game.name_of(1),
			String(JOBS.job(String(a["id"])).get("name", a["id"]))]
	main.hud.show_overlay(title,
		"%s\n\nEure Bewerbung:%s\n\nNote %s · %s" % [
			story, jobs, String.num(grade, 2), verdict],
		"R neu starten · L Leistungsüberblick · M zum Startbildschirm",
		"Neu starten", true, "win" if passed else "lose", String(DEF["tag"]))
