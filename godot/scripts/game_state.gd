extends Node
## Autoload "Game": remembers the chosen department, look and day/night mode across scene reloads.

const CH = preload("res://scripts/characters.gd")

var dept := "MAVT"
var mode := "night"   # "day" or "night"
var looks := {}       # per department, customised copies of the default looks


func _ready() -> void:
	for d in CH.DEPTS:
		looks[d] = (CH.DEPTS[d]["look"] as Dictionary).duplicate(true)


func look() -> Dictionary:
	return looks[dept]


func reset_look(d: String) -> void:
	looks[d] = (CH.DEPTS[d]["look"] as Dictionary).duplicate(true)
