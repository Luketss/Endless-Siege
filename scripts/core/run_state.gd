class_name RunState
extends RefCounted
## Everything that persists across the encounters of one journey. Serializable so a run
## can be continued after closing the game (saved on the journey map, between encounters).

const VERSION := 1

var run_seed: int = 0
var hero_id: String = "ranger"
var map_id: String = "forest"
var modifiers: Array = []
var unlocks: Array = []
var gold: int = 0
var core_hp: float = 100.0
var upgrades: Array = []
var journey: Dictionary = {}
var current_node: String = ""
var visited: Array = []
## Chronological record of decisions and encounter outcomes (see RunLog).
var history: Array = []
var structures: Array = []
var harder_next: float = 0.0
var finished: bool = false
var victory: bool = false
var stats: Dictionary = {"waves": 0, "combats": 0, "elites": 0, "boss": 0, "kills": 0, "gold_earned": 0, "time": 0.0}
## Hero progression within the run.
var hero_level: int = 1
var hero_xp: float = 0.0


static func create(p_seed: int, p_hero: String, p_modifiers: Array, p_unlocks: Array) -> RunState:
	var r := RunState.new()
	r.run_seed = p_seed
	r.hero_id = p_hero
	r.modifiers = p_modifiers.duplicate()
	r.unlocks = p_unlocks.duplicate()
	r.gold = int(DataDB.balance().start_gold)
	r.journey = Journey.generate(p_seed)
	r.core_hp = r.core_max()
	return r


func mods() -> RunMods:
	return RunMods.build(upgrades, modifiers)


func core_max() -> float:
	return maxf(10.0, float(DataDB.balance().core_max_hp) + mods().stat("core_max_hp_add"))


## Deterministic per-node seed so rewards/waves do not depend on play order.
func node_seed(node_id: String, salt: String = "") -> int:
	return hash("%d|%s|%s" % [run_seed, node_id, salt])


func depth() -> int:
	var node := Journey.find(journey, current_node)
	return int(node.get("layer", 0))


func add_upgrade(id: String) -> void:
	if upgrades.has(id):
		return
	var before := core_max()
	upgrades.append(id)
	var u := DataDB.upgrade(id)
	var heal := float(u.get("on_pick", {}).get("heal_core", 0.0))
	core_hp = minf(core_max(), core_hp + heal + maxf(0.0, core_max() - before - heal))


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "seed": run_seed, "hero_id": hero_id, "map_id": map_id, "modifiers": modifiers,
		"unlocks": unlocks, "gold": gold, "core_hp": core_hp, "upgrades": upgrades, "journey": journey,
		"current_node": current_node, "visited": visited, "structures": structures, "harder_next": harder_next,
		"finished": finished, "victory": victory, "stats": stats, "hero_level": hero_level, "hero_xp": hero_xp, "log": history,
	}


static func from_dict(d: Dictionary) -> RunState:
	if int(d.get("version", 0)) != VERSION or not d.has("journey"):
		return null
	var r := RunState.new()
	r.run_seed = int(d.seed)
	r.hero_id = d.get("hero_id", "ranger")
	r.map_id = d.get("map_id", "forest")
	r.modifiers = d.get("modifiers", [])
	r.unlocks = d.get("unlocks", [])
	r.gold = int(d.get("gold", 0))
	r.core_hp = float(d.get("core_hp", 100))
	r.upgrades = d.get("upgrades", [])
	r.journey = d.journey
	r.current_node = d.get("current_node", "")
	r.visited = d.get("visited", [])
	r.structures = d.get("structures", [])
	r.harder_next = float(d.get("harder_next", 0.0))
	r.finished = d.get("finished", false)
	r.victory = d.get("victory", false)
	r.stats = d.get("stats", r.stats)
	r.hero_level = int(d.get("hero_level", 1))
	r.hero_xp = float(d.get("hero_xp", 0.0))
	r.history = d.get("log", [])
	return r


## Essence (permanent currency) earned by this run.
func essence_earned() -> int:
	var e: Dictionary = DataDB.balance().essence
	var total := float(stats.waves) * float(e.per_wave) + float(stats.combats) * float(e.per_combat)
	total += float(stats.elites) * float(e.per_elite) + float(stats.boss) * float(e.per_boss)
	if victory:
		total += float(e.victory_bonus)
	var mult := 1.0
	for m in modifiers:
		mult += float(DataDB.modifiers().get(m, {}).get("essence", 0.0))
	return int(round(total * mult))
