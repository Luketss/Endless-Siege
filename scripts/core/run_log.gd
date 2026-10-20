class_name RunLog
extends RefCounted
## Local, offline play log: one JSON line per finished journey in user://runs.jsonl.
## Nothing leaves the machine. Playtesters can send the file; tools/run_report.py
## summarises any number of them (win rate, where runs end, upgrade pick rates...).

const PATH := "user://runs.jsonl"
const MAX_BYTES := 4 * 1024 * 1024
const FORMAT := 1


static func record(run: RunState) -> Dictionary:
	var node := Journey.find(run.journey, run.current_node)
	return {
		"format": FORMAT,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"ended_at": Time.get_datetime_string_from_system(true),
		"seed": run.run_seed,
		"hero": run.hero_id,
		"map": run.map_id,
		"modifiers": run.modifiers,
		"unlocks": run.unlocks,
		"victory": run.victory,
		"end_node": run.current_node,
		"end_type": node.get("type", ""),
		"end_layer": int(node.get("layer", 0)),
		"stats": run.stats,
		"hero_level": run.hero_level,
		"upgrades": run.upgrades,
		"synergies": run.mods().active_synergies,
		"essence": run.essence_earned(),
		"log": run.history,
	}


## Appends one record; rotates the file to runs.old.jsonl when it grows too large.
static func append(run: RunState, path: String = PATH) -> bool:
	if FileAccess.file_exists(path) and FileAccess.open(path, FileAccess.READ).get_length() > MAX_BYTES:
		DirAccess.rename_absolute(path, path.get_basename() + ".old.jsonl")
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var f := FileAccess.open(path, mode)
	if f == null:
		push_warning("RunLog: cannot open %s" % path)
		return false
	f.seek_end()
	f.store_line(JSON.stringify(record(run)))
	f.close()
	return true


static func read_all(path: String = PATH) -> Array:
	var out := []
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var d: Variant = JSON.parse_string(line)
		if d is Dictionary:
			out.append(d)
	return out
