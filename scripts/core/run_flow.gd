class_name RunFlow
extends RefCounted
## Journey rules shared by the game UI, tests and the balance tool: entering nodes,
## building battles, rewards, shop, events and rest.


static func make_sim(run: RunState) -> BattleSim:
	var sim := BattleSim.new()
	var map := MapDef.from_dict(DataDB.map(run.map_id))
	var node := Journey.find(run.journey, run.current_node)
	sim.setup(map, run.mods(), run.gold, run.core_hp, run.core_max(), run.hero_id,
		run.node_seed(run.current_node, "battle"), run.unlocks)
	sim.depth = int(node.get("layer", 0))
	sim.restore_structures(run.structures)
	# Hero keeps its level across the journey.
	while sim.hero.level < run.hero_level:
		sim.hero.level += 1
		sim.hero.max_hp += float(sim.hero.def.level_bonus.hp)
	sim.hero.hp = sim.hero.max_hp
	sim.hero.xp = run.hero_xp
	return sim


static func waves_for(run: RunState, node: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = run.node_seed(node.id, "waves")
	var n := int(DataDB.journey().waves.get(node.type, 3))
	var mods := run.mods()
	var out := []
	for i in n:
		out.append(WaveDirector.build_wave(node.type, int(node.layer), i, n, rng, mods, run.harder_next))
	return out


## Copies the battle outcome back into the run. `waves_cleared` counts completed waves.
static func finish_combat(run: RunState, sim: BattleSim, node: Dictionary, waves_cleared: int) -> void:
	var damage := {}
	for k in sim.stats.damage:
		damage[k] = int(round(float(sim.stats.damage[k])))
	run.history.append({"t": "encounter", "node": node.id, "type": node.type, "layer": int(node.layer),
		"core_before": int(round(run.core_hp)), "core_after": int(round(sim.core_hp)), "waves": waves_cleared,
		"time": snappedf(sim.time, 0.1), "leaks": int(sim.stats.leaks), "kills": int(sim.stats.kills),
		"structures": sim.structures.size(), "gold_after": sim.gold, "damage": damage, "defeated": sim.defeated})
	run.gold = sim.gold
	run.core_hp = sim.core_hp
	run.structures = sim.structures_snapshot()
	run.hero_level = sim.hero.level
	run.hero_xp = sim.hero.xp
	run.stats.waves += waves_cleared
	run.stats.kills += int(sim.stats.kills)
	run.stats.gold_earned += int(sim.stats.gold_earned)
	run.stats.time += sim.time
	if sim.defeated:
		run.finished = true
		run.victory = false
		return
	run.harder_next = 0.0
	match node.type:
		"combat":
			run.stats.combats += 1
		"elite":
			run.stats.elites += 1
		"boss":
			run.stats.boss += 1
			run.finished = true
			run.victory = true


static func enter(run: RunState, node_id: String) -> Dictionary:
	var valid := false
	for n in Journey.choices(run.journey, run.current_node):
		if n.id == node_id:
			valid = true
	if not valid:
		return {}
	run.current_node = node_id
	run.visited.append(node_id)
	return Journey.find(run.journey, node_id)


static func reward_choices(run: RunState, node: Dictionary) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = run.node_seed(node.id, "reward")
	var min_rarity := "rare" if node.type == "elite" else "common"
	return UpgradePool.roll(rng, run.upgrades, run.unlocks, min_rarity, 3)


## Shop: 3 upgrades with prices + a core repair.
static func shop_offer(run: RunState, node: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run.node_seed(node.id, "shop")
	var shop: Dictionary = DataDB.balance().shop
	var items := []
	for id in UpgradePool.roll(rng, run.upgrades, run.unlocks, "common", 3):
		items.append({"id": id, "price": int(shop.prices[DataDB.upgrade(id).rarity])})
	return {"items": items, "repair_cost": int(shop.repair_cost), "repair_amount": float(shop.repair_amount)}


static func buy(run: RunState, item: Dictionary) -> bool:
	if run.gold < int(item.price) or run.upgrades.has(item.id):
		return false
	run.history.append({"t": "shop", "node": run.current_node, "bought": item.id, "price": int(item.price)})
	run.gold -= int(item.price)
	run.add_upgrade(item.id)
	return true


static func repair(run: RunState, cost: int, amount: float) -> bool:
	if run.gold < cost or run.core_hp >= run.core_max():
		return false
	run.gold -= cost
	run.core_hp = minf(run.core_max(), run.core_hp + amount)
	return true


static func rest(run: RunState) -> float:
	var heal := run.core_max() * float(DataDB.balance().rest_heal_pct)
	var before := run.core_hp
	run.core_hp = minf(run.core_max(), run.core_hp + heal)
	return run.core_hp - before


static func pick_event(run: RunState, node: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = run.node_seed(node.id, "event")
	var ids := DataDB.events().keys()
	ids.sort()
	return ids[rng.randi() % ids.size()]


static func can_afford(run: RunState, choice: Dictionary) -> bool:
	var cost: Dictionary = choice.get("cost", {})
	if run.gold < int(cost.get("gold", 0)):
		return false
	if run.core_hp <= float(cost.get("core_hp", 0)):
		return false
	return true


## Applies an event choice. Returns {"upgrade_choices": Array, "text": String key, ...}.
static func apply_event(run: RunState, node: Dictionary, event_id: String, choice_index: int) -> Dictionary:
	var ev: Dictionary = DataDB.events()[event_id]
	var choice: Dictionary = ev.choices[choice_index]
	if not can_afford(run, choice):
		return {"ok": false}
	run.history.append({"t": "event", "node": node.id, "event": event_id, "choice": choice_index})
	var cost: Dictionary = choice.get("cost", {})
	run.gold -= int(cost.get("gold", 0))
	run.core_hp -= float(cost.get("core_hp", 0))
	var reward: Dictionary = choice.get("reward", {})
	var out := {"ok": true, "upgrade_choices": [], "gold": 0, "core_hp": 0.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = run.node_seed(node.id, "event_reward")
	if reward.has("gamble"):
		# Coin flip: double or lose part of the current gold.
		if rng.randf() < float(reward.gamble):
			reward = {"gold": 100, "upgrade": "rare"}
			out.result = "EV_GAMBLE_WIN"
		else:
			run.core_hp -= 15.0
			out.result = "EV_GAMBLE_LOSE"
	if reward.has("gold"):
		run.gold += int(reward.gold)
		out.gold = int(reward.gold)
	if reward.has("core_hp"):
		run.core_hp = minf(run.core_max(), run.core_hp + float(reward.core_hp))
		out.core_hp = float(reward.core_hp)
	if reward.has("next_combat_harder"):
		run.harder_next = float(reward.next_combat_harder)
	if reward.has("upgrade"):
		out.upgrade_choices = UpgradePool.roll(rng, run.upgrades, run.unlocks, reward.upgrade, 3)
	run.core_hp = maxf(1.0, run.core_hp)
	return out


## Records an upgrade offer and the player's answer ("" = skipped).
static func record_reward(run: RunState, offered: Array, picked: String, source: String = "reward") -> void:
	run.history.append({"t": source, "node": run.current_node, "offered": offered.duplicate(), "picked": picked})
	if picked != "":
		run.add_upgrade(picked)
