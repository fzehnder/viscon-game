extends RefCounted
## Two players on one keyboard. Physical key positions (US layout), so it works on Swiss keyboards too.
## P1 (left hand side):  WASD move · E interact · Shift sprint · Ctrl sneak · Esc leave minigame · 1 2 3 answers
## P2 (right hand side): arrows move · Enter interact · . sprint · - (US: /) sneak · Backspace leave minigame · 8 9 0 answers

const PLAYER_KEYS := [
	{
		"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"interact": [KEY_E, KEY_SPACE], "sprint": [KEY_SHIFT], "sneak": [KEY_CTRL],
		"abort": [KEY_ESCAPE], "nums": [KEY_1, KEY_2, KEY_3],
	},
	{
		"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
		"interact": [KEY_ENTER, KEY_KP_ENTER], "sprint": [KEY_PERIOD], "sneak": [KEY_SLASH],
		"abort": [KEY_BACKSPACE], "nums": [KEY_8, KEY_9, KEY_0],
	},
]

# Single-player minigame keys (original behaviour, used when no player is given).
const SOLO_KEYS := {
	"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E, KEY_SPACE, KEY_ENTER], "abort": [KEY_ESCAPE], "nums": [KEY_1, KEY_2, KEY_3],
}

const LABELS := [
	{"ok": "E", "nums": "1 2 3", "dirs": "WASD", "abort": "Esc"},
	{"ok": "Enter", "nums": "8 9 0", "dirs": "Pfeiltasten", "abort": "Backspace"},
]
const SOLO_LABELS := {"ok": "E oder Leertaste", "nums": "1 2 3", "dirs": "Pfeiltasten oder WASD", "abort": "Esc"}
const KEY_NAMES := ["E", "Enter"]
const TAGS := ["P1", "P2"]
const TAG_COLORS := ["ff5d8f", "4d8dff"]   # P1 pink, P2 blue (yellow = both)


static func action(pid: int, what: String) -> String:
	return "p%d_%s" % [pid + 1, what]


static func setup() -> void:
	for pid in PLAYER_KEYS.size():
		var keys: Dictionary = PLAYER_KEYS[pid]
		for what in ["up", "down", "left", "right", "interact", "sprint", "sneak"]:
			var a := action(pid, what)
			if InputMap.has_action(a):
				continue
			InputMap.add_action(a)
			for k in keys[what]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(a, ev)


static func keys_for(pid: int) -> Dictionary:
	if pid < 0 or pid >= PLAYER_KEYS.size():
		return SOLO_KEYS
	return PLAYER_KEYS[pid]


static func labels_for(pid: int) -> Dictionary:
	if pid < 0 or pid >= LABELS.size():
		return SOLO_LABELS
	return LABELS[pid]
