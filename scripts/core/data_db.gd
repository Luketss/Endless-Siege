class_name DataDB
extends RefCounted
## Read-only access to the JSON design data in res://data. Files are parsed once and cached.
## Everything gameplay-related (stats, waves, upgrades, unlocks) lives in data, not code.

static var _cache: Dictionary = {}


static func _load(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("Invalid JSON: %s" % path)
		parsed = {}
	_cache[path] = parsed
	return parsed


static func balance() -> Dictionary:
	return _load("res://data/balance.json")


static func structures() -> Dictionary:
	return _load("res://data/structures.json")


static func structure(id: String) -> Dictionary:
	return structures().get(id, {})


static func enemies() -> Dictionary:
	return _load("res://data/enemies.json")


static func enemy(id: String) -> Dictionary:
	return enemies().get(id, {})


static func upgrades() -> Dictionary:
	return _load("res://data/upgrades.json")


static func upgrade(id: String) -> Dictionary:
	return upgrades().get(id, {})


static func synergies() -> Dictionary:
	return _load("res://data/synergies.json")


static func map(id: String) -> Dictionary:
	return _load("res://data/maps/%s.json" % id)


static func journey() -> Dictionary:
	return _load("res://data/journey.json")


static func events() -> Dictionary:
	return _load("res://data/events.json")


static func unlocks() -> Dictionary:
	return _load("res://data/unlocks.json")


static func modifiers() -> Dictionary:
	return _load("res://data/modifiers.json")


static func heroes() -> Dictionary:
	return _load("res://data/heroes.json")


static func visuals() -> Dictionary:
	return _load("res://data/visuals.json")


static func hero(id: String) -> Dictionary:
	return heroes().get(id, {})


## Clears the cache (used by tests that patch data).
static func reload() -> void:
	_cache.clear()
