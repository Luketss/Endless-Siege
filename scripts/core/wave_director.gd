class_name WaveDirector
extends RefCounted
## Builds wave compositions from a difficulty budget. Difficulty grows by introducing
## new enemy behaviours and combinations as the journey deepens, not only by numbers.
## Fully deterministic for a given RNG seed.

## Depth at which each enemy type joins the pool.
const INTRO := {"grunt": 0, "runner": 0, "wisp": 1, "brute": 2, "splitter": 2, "hexer": 3, "warden": 3}
## [min, max] group sizes.
const GROUP := {"grunt": [4, 8], "runner": [3, 5], "wisp": [2, 4], "brute": [1, 2], "splitter": [1, 3],
	"hexer": [1, 1], "warden": [1, 1]}


static func budget(depth: int, wave_index: int, mods: RunMods, kind: String) -> float:
	var b := 13.0 * (1.0 + 0.7 * depth) * (1.0 + 0.4 * wave_index)
	if kind == "elite":
		b *= 1.15
	return b * maxf(0.3, 1.0 + mods.stat("enemy_count_pct"))


static func pool(depth: int) -> Array[String]:
	var out: Array[String] = []
	for t in INTRO:
		if depth >= int(INTRO[t]):
			out.append(t)
	return out


## Returns spawn entries [{"t": float, "type": String, "elite": bool}].
static func build_wave(kind: String, depth: int, wave_index: int, waves_total: int, rng: RandomNumberGenerator,
		mods: RunMods, harder: float = 0.0) -> Array:
	var entries: Array = []
	var eff_depth := depth + (1 if kind == "elite" else 0)
	var remaining := budget(eff_depth, wave_index, mods, kind) * (1.0 + harder)
	var types := pool(eff_depth)
	var elite_chance := 0.0
	if kind == "elite":
		elite_chance = float(DataDB.balance().elite.chance)
	elif depth >= 3:
		elite_chance = 0.04
	var t := 1.0
	var is_boss_wave := kind == "boss" and wave_index == waves_total - 1
	if is_boss_wave:
		entries.append({"t": 4.0, "type": "golem", "elite": false})
		remaining *= 0.6
	var guard := 0
	while remaining > 0.5 and guard < 200:
		guard += 1
		var type := _pick_type(types, eff_depth, rng)
		var cost := float(DataDB.enemy(type).budget)
		var range_: Array = GROUP[type]
		var n := rng.randi_range(int(range_[0]), int(range_[1]))
		n = maxi(1, mini(n, int(ceil(remaining / cost))))
		var gap := rng.randf_range(0.45, 0.9)
		for i in n:
			entries.append({"t": t + i * gap, "type": type, "elite": rng.randf() < elite_chance and type != "grunt"})
		remaining -= cost * n
		# Wardens and hexers come with an escort they can empower or cover.
		if type == "warden" or type == "hexer":
			var escort := "brute" if eff_depth >= 4 and rng.randf() < 0.5 else "grunt"
			var en := 2 if escort == "brute" else 5
			for i in en:
				entries.append({"t": t + 0.3 + i * 0.5, "type": escort, "elite": false})
			remaining -= float(DataDB.enemy(escort).budget) * en
		t += n * gap + rng.randf_range(2.0, 3.6)
	entries.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return entries


static func _pick_type(types: Array[String], depth: int, rng: RandomNumberGenerator) -> String:
	var weights := []
	var total := 0.0
	for t in types:
		var w := 3.0 if t == "grunt" else 2.0
		# The newest behaviour shows up more often when it is introduced.
		if int(INTRO[t]) == depth:
			w += 2.0
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in types.size():
		r -= float(weights[i])
		if r <= 0.0:
			return types[i]
	return types[0]
