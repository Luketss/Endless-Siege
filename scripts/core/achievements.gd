class_name Achievements
extends RefCounted
## Achievement rules from data/achievements.json, evaluated at the end of a journey.
## Pure logic: Profile stores the earned ids and SteamService mirrors them to Steam.


## Ids earned by this finished run that are not in `owned` yet. `stats` are the
## profile's lifetime statistics after the run was added.
static func check(run: RunState, stats: Dictionary, owned: Array) -> Array:
	var out := []
	var all := DataDB.achievements()
	for id in all:
		if owned.has(id):
			continue
		if met(all[id].rule, run, stats):
			out.append(id)
	return out


static func met(rule: Dictionary, run: RunState, stats: Dictionary) -> bool:
	match String(rule.type):
		"victory":
			if not run.victory:
				return false
			if rule.has("hero") and run.hero_id != rule.hero:
				return false
			if rule.has("map") and run.map_id != rule.map:
				return false
			if run.modifiers.size() < int(rule.get("modifiers_min", 0)):
				return false
			return run.core_hp >= run.core_max() * float(rule.get("core_ratio_min", 0.0))
		"depth":
			return run.depth() >= int(rule.min)
		"synergies":
			return run.mods().active_synergies.size() >= int(rule.min)
		"rarity":
			return run.upgrades.any(func(u): return DataDB.upgrade(u).rarity == rule.rarity)
		"endless":
			return run.endless_cleared() >= int(rule.min)
		"stat_total":
			return int(stats.get(rule.stat, 0)) >= int(rule.min)
	return false
