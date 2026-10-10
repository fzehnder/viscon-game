extends RefCounted
## Leaderboard of the ski level: every finished race of the players is saved in user://ski.cfg
## (its own file, so a new study in the menu does not wipe the records), plus the head-to-head
## record of every pair of names. NPCs and Opps have fixed times that are worked out from the
## par time of the course, so they stay the same from race to race.

const PATH := "user://ski.cfg"
const KEEP := 200            # saved player results, the slowest go first

# Rivals that are always on the board: [name, factor on the par time]. Below 1 = faster than par.
const RIVALS := [
	["Ueli, ASVZ-Skilehrer", 0.94],
	["Seraina, Akademischer Skiclub", 1.0],
	["Gian-Marco", 1.07],
	["Mirjam, Hilfsassistentin", 1.16],
	["Prof. Dr. Siedler", 1.35],
]
# Opps (people the players have wronged in earlier levels) ride hard: between these factors.
const OPP_FAST := 0.98
const OPP_SLOW := 1.15


## Saved results: [{"name", "total", "r1", "r2", "misses", "date"}], fastest first.
static func load_times() -> Array:
	var out: Array = []
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or not cfg.has_section("times"):
		return out
	for k in cfg.get_section_keys("times"):
		var e = cfg.get_value("times", k)
		if e is Dictionary and e.has("name") and e.has("total"):
			out.append(e)
	out.sort_custom(func(a, b): return float(a["total"]) < float(b["total"]))
	return out


## Head-to-head record: "A|B" (names sorted) -> [wins of A, wins of B].
static func load_duels() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or not cfg.has_section("duels"):
		return {}
	var out := {}
	for k in cfg.get_section_keys("duels"):
		out[k] = cfg.get_value("duels", k)
	return out


## Saves both results of a race and who won it. Returns the saved entries (to highlight them).
static func save_race(results: Array, winner: int, persist: bool) -> Array:
	var times := load_times()
	var duels := load_duels()
	var now := Time.get_datetime_string_from_system(false, true).substr(0, 16)
	var fresh: Array = []
	for r in results:
		var e := {"name": r["name"], "total": snappedf(r["total"], 0.01), "r1": snappedf(r["runs"][0], 0.01),
			"r2": snappedf(r["runs"][1], 0.01), "misses": r["misses"], "date": now}
		times.append(e)
		fresh.append(e)
	times.sort_custom(func(a, b): return float(a["total"]) < float(b["total"]))
	if times.size() > KEEP:
		times.resize(KEEP)
	if winner >= 0:
		var key := duel_key(results[0]["name"], results[1]["name"])
		var rec: Array = duels.get(key, [0, 0])
		var first_is_p0: bool = String(results[0]["name"]) <= String(results[1]["name"])
		rec[0 if (winner == 0) == first_is_p0 else 1] += 1
		duels[key] = rec
	if persist:
		var cfg := ConfigFile.new()
		for i in times.size():
			cfg.set_value("times", "t%03d" % i, times[i])
		for k in duels:
			cfg.set_value("duels", k, duels[k])
		cfg.save(PATH)
	return fresh


static func duel_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a <= b else "%s|%s" % [b, a]


## Wins of a against b so far: [wins a, wins b].
static func duel_record(a: String, b: String) -> Array:
	var rec: Array = load_duels().get(duel_key(a, b), [0, 0])
	return rec if a <= b else [rec[1], rec[0]]


## Best saved total of a name, or 0.0.
static func best_of(pname: String) -> float:
	for e in load_times():
		if e["name"] == pname:
			return float(e["total"])
	return 0.0


## NPC and Opp results for runs with these par times: same dictionaries as the saved ones plus
## "kind" ("npc" or "opp").
static func npc_times(pars: Array, opps: Dictionary) -> Array:
	var out: Array = []
	for r in RIVALS:
		out.append(_npc(String(r[0]), float(r[1]), pars, "npc"))
	for id in opps:
		var nm := String(opps[id]["name"])
		var k := float(absi(hash(nm)) % 1000) / 999.0
		out.append(_npc(nm, lerpf(OPP_FAST, OPP_SLOW, k), pars, "opp"))
	return out


static func _npc(nm: String, factor: float, pars: Array, kind: String) -> Dictionary:
	# a little difference between the two runs, always the same for the same name
	var wob := float(absi(hash(nm + "lauf")) % 100) / 100.0 * 0.04 - 0.02
	var r1 := float(pars[0]) * (factor + wob)
	var r2 := float(pars[1]) * (factor - wob)
	return {"name": nm, "total": snappedf(r1 + r2, 0.01), "r1": snappedf(r1, 0.01), "r2": snappedf(r2, 0.01),
		"misses": 0, "kind": kind}


static func fmt(t: float) -> String:
	var m := int(t) / 60
	var s := fmod(t, 60.0)
	return "%d:%05.2f" % [m, s] if m > 0 else "%.2f" % s
