class_name UpgradePool
extends RefCounted
## Rolls upgrade choices. Rarity is weighted (common > rare > epic > legendary);
## upgrades already owned, locked by meta-progression or needing a locked structure
## are excluded.

const RARITIES := ["common", "rare", "epic", "legendary"]


static func available(owned: Array, unlocks: Array) -> Array[String]:
	var locked_by_pool := {}
	for uid in DataDB.unlocks():
		var u: Dictionary = DataDB.unlocks()[uid]
		if u.kind == "pool" and not unlocks.has(uid):
			for up in u.upgrades:
				locked_by_pool[up] = true
	var out: Array[String] = []
	for id in DataDB.upgrades():
		if owned.has(id) or locked_by_pool.has(id):
			continue
		var req: String = DataDB.upgrade(id).get("requires_unlock", "")
		if req != "" and not unlocks.has(req):
			continue
		out.append(id)
	return out


static func roll(rng: RandomNumberGenerator, owned: Array, unlocks: Array, min_rarity: String = "common",
		count: int = 3) -> Array[String]:
	var pool := available(owned, unlocks)
	var by_rarity := {}
	for id in pool:
		var r: String = DataDB.upgrade(id).rarity
		if not by_rarity.has(r):
			by_rarity[r] = []
		by_rarity[r].append(id)
	var weights: Dictionary = DataDB.balance().rarity_weights
	var min_idx := RARITIES.find(min_rarity)
	var picks: Array[String] = []
	var guard := 0
	while picks.size() < count and guard < 100:
		guard += 1
		var rarity := _roll_rarity(rng, weights, min_idx)
		# Fall back to the closest rarity that still has candidates.
		var idx := RARITIES.find(rarity)
		var chosen := ""
		for delta in [0, -1, 1, -2, 2, -3, 3]:
			var j: int = idx + delta
			if j < min_idx or j >= RARITIES.size():
				continue
			var cands: Array = by_rarity.get(RARITIES[j], []).filter(func(x): return not picks.has(x))
			if not cands.is_empty():
				chosen = cands[rng.randi() % cands.size()]
				break
		if chosen == "":
			break
		picks.append(chosen)
	return picks


static func _roll_rarity(rng: RandomNumberGenerator, weights: Dictionary, min_idx: int) -> String:
	var total := 0.0
	for i in range(min_idx, RARITIES.size()):
		total += float(weights[RARITIES[i]])
	var r := rng.randf() * total
	for i in range(min_idx, RARITIES.size()):
		r -= float(weights[RARITIES[i]])
		if r <= 0.0:
			return RARITIES[i]
	return RARITIES[RARITIES.size() - 1]
