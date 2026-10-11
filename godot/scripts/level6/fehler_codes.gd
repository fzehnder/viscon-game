extends RefCounted
## Level 6, «Fehler finden»: short Python programs in which exactly one line is wrong.
## One round per entry, played in this order:
##   "zeilen"  the program, 4 to 6 lines (indent with four spaces)
##   "falsch"  index of the wrong line, 0 = the first one
##   "warum"   what is wrong with it, shown once the line is found
## Everything except that one line has to be real, correct Python, and every round has a
## different kind of mistake. Swap them as you like; the English of the lines and of "warum"
## is in en.gd (a line without English is shown as it stands here).

const RUNDEN := [
	{   # a bracket that is never closed
		"zeilen": [
			"zahlen = [3, 5, 8]",
			"summe = 0",
			"for z in zahlen:",
			"    summe = summe + z",
			"print(summe",
		],
		"falsch": 4,
		"warum": "Die Klammer von print geht auf und nie wieder zu.",
	},
	{   # = instead of ==
		"zeilen": [
			"def ist_gerade(n):",
			"    if n % 2 = 0:",
			"        return True",
			"    return False",
		],
		"falsch": 1,
		"warum": "Verglichen wird mit ==. Ein einzelnes = weist zu.",
	},
	{   # text plus number
		"zeilen": [
			"name = \"ETH\"",
			"print(\"Hallo \" + name)",
			"alter = 5",
			"print(\"Alter: \" + alter)",
		],
		"falsch": 3,
		"warum": "Text plus Zahl geht nicht. Richtig wäre str(alter).",
	},
]
