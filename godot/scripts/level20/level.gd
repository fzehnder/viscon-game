extends Node2D
## Elective "Skifahren" (block "W"): a giant slalom duel of the two players, two runs, steered with
## the body in front of the camera (or with the keys). Not part of the story: it is started from
## the transcript (Wahlfächer) whenever the players like, and it is never the "next level".
## Number 20 keeps it out of the way of the story levels, which count up from 2. The race itself is ski_race.gd, the
## leaderboard with the saved times and the NPC and Opp times is ski_board.gd.
## The race opens full screen as soon as the level starts; when the players leave its final
## screen, both get the task and the level is won with the grade from their times.

const RaceScript = preload("res://scripts/level20/ski_race.gd")
const LV = preload("res://scripts/levels.gd")
const Cutscene = preload("res://scripts/cutscene.gd")

const DEF := {
	"name": "Skifahren (Riesenslalom)",
	"tag": "WAHLFACH · D-HEST",
	"mode": "day",
	"time": 3600.0,   # the race decides, not the clock
	"course": "376-0905-00 L", "ects": 2, "block": "W",
	"start": Vector2(26.0, 42.0),
	"intro": "Wahlfach Skifahren am D-HEST (Gesundheitswissenschaften und Technologie). Riesenslalom, zwei Läufe, ihr fahrt gleichzeitig gegeneinander. Die Zeiten werden addiert und kommen in die Bestenliste, gegen den Skilehrer, die Hilfsassistentin und eure Opps.\n\nStellt euch nebeneinander vor die Kamera: links fährt, wer Pink hat (Spieler*in 1), rechts Blau (Spieler*in 2). Nach links und rechts gehen lenkt, in die Hocke gehen macht schneller (lenkt aber schlechter). Ein verpasstes Tor kostet 2 Sekunden.",
	"hint": "Ohne Kamera: A / D und Pfeile links / rechts lenken, S und Pfeil runter ist die Hocke.",
	"start_toast": ["Ab auf die Piste!", "Gleich geht's los."],
	"win_title": "Wahlfach bestanden!",
	"win_text": "%s & %s haben den Riesenslalom hinter sich.",
	"tasks": [
		{"id": "ski", "name": "Zwei Läufe fahren", "where": "Riesenslalom, gegeneinander", "type": "level"},
	],
}

var main            # main.gd, set before _ready
var layer: CanvasLayer
var race = null
var raced := false
var intro_seen := false
var results: Array = []


func _process(_delta: float) -> void:
	if raced or race != null or main == null or main.state != "play":
		return
	if not intro_seen:
		_play_intro()
		return
	layer = CanvasLayer.new()
	layer.layer = 15   # above the HUD (10), below minigames (20)
	main.add_child(layer)
	race = RaceScript.new()
	race.main = main
	race.finished.connect(_on_race_done)
	layer.add_child(race)
	main.hud.visible = false
	for pl in main.players:
		pl.enabled = false


## Short story before the first run: the players learn that the elective at D-HEST is skiing.
## The clock stands still meanwhile (main.state "cutscene").
func _play_intro() -> void:
	intro_seen = true
	main.state = "cutscene"
	main.hud.visible = false
	for pl in main.players:
		pl.enabled = false
	var steps := [
		{"phones": "myStudies · D-HEST", "text": "Einschreibung bestätigt: Wahlfach 376-0905-00 L"},
		{"say": 0, "text": "Ich hab uns für ein Wahlfach eingeschrieben. Am D-HEST."},
		{"say": 1, "text": "HEST? Gesundheitswissenschaften und Technologie? Lernen wir da Knochen auswendig?"},
		{"mail": {"from": "D-HEST · Bewegungswissenschaften und Sport", "to": "%s, %s" % [Game.name_of(0), Game.name_of(1)],
			"subject": "Wahlfach Skifahren: Prüfung auf der Piste",
			"body": "Liebe Studierende\n\nDas Wahlfach findet nicht im Hörsaal statt, sondern im Schnee. Die Prüfung: zwei Läufe Riesenslalom, die Zeiten werden addiert. Ein verpasstes Tor kostet 2 Sekunden.\n\nDie Note gibt es nach Zeit. Die Bestenliste hängt im Skikeller, auch die Zeiten der Assistierenden.\n\nSportliche Grüsse\nDas Kursteam",
			"footer": "2 KP · Wahlfach · Note nach Zeit"}},
		{"say": 0, "text": "Zwei Kreditpunkte fürs Skifahren? Bin dabei."},
		{"say": 1, "text": "Abgemacht. Aber ich bin schneller unten als du."},
		{"title": "WAHLFACH SKIFAHREN", "sub": "D-HEST  ·  Riesenslalom  ·  2 Läufe"},
	]
	var cs = Cutscene.new()
	main.add_child(cs)
	cs.play(steps, func(): main.state = "play")


func _on_race_done(res: Array) -> void:
	raced = true
	results = res
	layer.queue_free()
	race = null
	main.hud.visible = true
	main._task_done(0, "ski")
	main._task_done(1, "ski")


## Our own end screen: the grade comes from the race times, not from the clock (main._win_day).
func finale(_done: Callable) -> void:
	main._close_minis()
	main.state = "won"
	for pl in main.players:
		pl.enabled = false
	var grade := snappedf((float(results[0]["grade"]) + float(results[1]["grade"])) / 2.0, 0.25)
	var misses := int(results[0]["misses"]) + int(results[1]["misses"])
	var fastest := 0 if results[0]["total"] <= results[1]["total"] else 1
	Game.add_grade(Game.level, grade, int(results[fastest]["total"]), misses)
	var lines := ""
	for r in results:
		lines += "\n%s: %.2f s · Note %s" % [r["name"], r["total"], String.num(r["grade"], 2)]
	var verdict := "Hervorragend!" if grade >= 5.5 else ("Gut gefahren." if grade >= 4.5 else ("Bestanden." if grade >= 4.0 else "Knapp daneben."))
	var nxt := LV.next_after(Game.level)
	var more := nxt > 0
	main.hud.show_overlay(String(DEF["win_title"]),
		"%s\n%s\n\nNote %s · %s\nVerpasste Tore: %d\n\nIn der Schweiz ist 6 die Bestnote, ab 4 ist bestanden." % [
			String(DEF["win_text"]) % [Game.name_of(0), Game.name_of(1)], lines, String.num(grade, 2), verdict, misses],
		("Enter weiter · " if more else "") + "R nochmals fahren · L Leistungsüberblick · M zum Startbildschirm",
		"Weiter zu Level %d" % nxt if more else "Nochmals fahren", true, "win", String(DEF["tag"]))
