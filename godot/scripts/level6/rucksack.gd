extends RefCounted
## Level 6, «Mate klauen»: the backpacks next to two chairs, what is in them and how long it
## takes until the owner misses it. Eating and drinking are not allowed in the library, so the
## Mate is contraband anyway.
## Everything that can be tuned about this task is in here.

# Seconds until the owner notices that the Mate is gone, if nobody saw the theft: somewhere
# between x and y. Seen with the Mate before that (they turn around): at once.
const NOTICE := Vector2(6.0, 9.0)

const MATES := 1            # bottles in every backpack: one, so each player needs a backpack of their own
const ZIP_HITS := 3         # goes of the timing minigame until the zip is open
const ZIP_SPEED := 250.0    # how fast the pointer runs, px per second
const ZIP_EVEN := true      # the pointer keeps this speed (false: 15 % faster after every hit, as in minigame.gd)
const ZIP_KEPT := true      # a zip stays open as far as somebody got, also after being interrupted

# One backpack per entry: whose it is (id in DEF.npcs of level.gd), where it stands (tiles) and
# its colour. The owners sit with their back to it.
const BACKPACKS := [
	{"owner": "l6_dario", "pos": Vector2(77.55, 31.25), "col": "c8463c"},
	{"owner": "l6_nina", "pos": Vector2(80.85, 34.45), "col": "2f5d8c"},
]
