class_name Journey
extends RefCounted
## Branching journey (Slay-the-Spire-like layers). Each node is an encounter: combat,
## elite, shop, event, rest or the final boss. The player sees node types before choosing.

const TYPES := ["combat", "elite", "shop", "event", "rest"]


## Returns {"layers": [[node, ...], ...]} where node = {"id", "layer", "index", "type", "links": [ids]}.
static func generate(seed_value: int) -> Dictionary:
	var cfg := DataDB.journey()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n_layers := int(cfg.layers)
	var layers: Array = []
	for L in n_layers:
		var count := 1
		if L != 0 and L != n_layers - 1:
			count = rng.randi_range(int(cfg.min_nodes), int(cfg.max_nodes))
		var layer: Array = []
		for i in count:
			var type: String
			if L == 0:
				type = cfg.first
			elif L == n_layers - 1:
				type = cfg.last
			elif L == 1:
				type = "combat"  # one more fight before anything fancy
			else:
				type = _weighted(cfg.weights, rng)
			layer.append({"id": "%d-%d" % [L, i], "layer": L, "index": i, "type": type, "links": []})
		layers.append(layer)
	_guarantee(layers, "elite", rng)
	_guarantee(layers, "shop", rng)
	# The layer before the boss always offers a way to recover.
	var pre: Array = layers[n_layers - 2]
	var has_recovery := false
	for node in pre:
		if node.type == "rest" or node.type == "shop":
			has_recovery = true
	if not has_recovery:
		pre[rng.randi() % pre.size()].type = "rest"
	# Links: each node connects to the proportionally closest 1-2 nodes of the next layer,
	# and every node is reachable.
	for L in range(n_layers - 1):
		var cur: Array = layers[L]
		var nxt: Array = layers[L + 1]
		for node in cur:
			var pos := 0.0 if cur.size() == 1 else float(node.index) / (cur.size() - 1)
			var target := int(round(pos * (nxt.size() - 1)))
			node.links.append(nxt[target].id)
			if nxt.size() > 1 and rng.randf() < 0.55:
				var other := clampi(target + (1 if rng.randf() < 0.5 else -1), 0, nxt.size() - 1)
				if not node.links.has(nxt[other].id):
					node.links.append(nxt[other].id)
		for n in nxt:
			var reached := false
			for node in cur:
				if node.links.has(n.id):
					reached = true
			if not reached:
				var pos := 0.0 if nxt.size() == 1 else float(n.index) / (nxt.size() - 1)
				cur[int(round(pos * (cur.size() - 1)))].links.append(n.id)
	return {"layers": layers}


static func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return "combat"


static func _guarantee(layers: Array, type: String, rng: RandomNumberGenerator) -> void:
	for L in range(2, layers.size() - 1):
		for node in layers[L]:
			if node.type == type:
				return
	var L := rng.randi_range(2, layers.size() - 2)
	var layer: Array = layers[L]
	layer[rng.randi() % layer.size()].type = type


static func find(journey: Dictionary, id: String) -> Dictionary:
	for layer in journey.layers:
		for node in layer:
			if node.id == id:
				return node
	return {}


## Nodes the player may pick next (after `current_id`, or the first layer if empty).
static func choices(journey: Dictionary, current_id: String) -> Array:
	if current_id == "":
		return journey.layers[0]
	var cur := find(journey, current_id)
	var out := []
	for id in cur.get("links", []):
		out.append(find(journey, id))
	return out


static func is_combat(type: String) -> bool:
	return type == "combat" or type == "elite" or type == "boss"
