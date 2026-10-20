class_name RunMods
extends RefCounted
## Aggregated effect of everything that modifies a run: picked upgrades, active
## synergies and challenge modifiers. Numeric "stats" add up; "flags" keep the
## strongest value. Gameplay code only asks `stat()` / `flag()`, so new upgrades are
## usually pure data.

var stats: Dictionary = {}
var flags: Dictionary = {}
var upgrades: Array[String] = []
var active_synergies: Array[String] = []
var tag_counts: Dictionary = {}


static func build(upgrade_ids: Array, modifier_ids: Array = []) -> RunMods:
	var m := RunMods.new()
	for id in upgrade_ids:
		var u := DataDB.upgrade(id)
		if u.is_empty():
			continue
		m.upgrades.append(id)
		m._apply(u)
		for t in u.get("tags", []):
			m.tag_counts[t] = int(m.tag_counts.get(t, 0)) + 1
	for sid in DataDB.synergies():
		var syn: Dictionary = DataDB.synergies()[sid]
		var ok := true
		for tag in syn.requires:
			if int(m.tag_counts.get(tag, 0)) < int(syn.requires[tag]):
				ok = false
				break
		if ok:
			m.active_synergies.append(sid)
			m._apply(syn)
	for mid in modifier_ids:
		var mod: Dictionary = DataDB.modifiers().get(mid, {})
		m._apply(mod)
	return m


func _apply(effect: Dictionary) -> void:
	var s: Dictionary = effect.get("stats", {})
	for k in s:
		stats[k] = float(stats.get(k, 0.0)) + float(s[k])
	var f: Dictionary = effect.get("flags", {})
	for k in f:
		flags[k] = maxf(float(flags.get(k, 0.0)), float(f[k]))


func stat(key: String, default: float = 0.0) -> float:
	return float(stats.get(key, default))


func flag(key: String) -> float:
	return float(flags.get(key, 0.0))


func has(key: String) -> bool:
	return flags.has(key) and float(flags[key]) > 0.0


## Synergies that would activate with one more upgrade carrying `tags` (for UI hints).
func synergies_unlocked_by(tags: Array) -> Array[String]:
	var out: Array[String] = []
	for sid in DataDB.synergies():
		if active_synergies.has(sid):
			continue
		var req: Dictionary = DataDB.synergies()[sid].requires
		var ok := true
		for tag in req:
			var have := int(tag_counts.get(tag, 0)) + (1 if tags.has(tag) else 0)
			if have < int(req[tag]):
				ok = false
				break
		if ok:
			out.append(sid)
	return out
