class_name BuildRules
extends RefCounted
## Free placement validation (no fixed slots):
## - towers/support: off the road, inside bounds, clear of obstacles, other structures and the core;
## - traps: square footprint fully on the road, not overlapping other traps.
## Positions are snapped to a 0.5 m grid so lines of defences look tidy.

const SNAP := 0.5
const TRAP_SNAP := 1.0


static func snap(def: Dictionary, p: Vector2) -> Vector2:
	var step := TRAP_SNAP if def.get("kind", "") == "trap" else SNAP
	return Vector2(snappedf(p.x, step), snappedf(p.y, step))


static func footprint_radius(def: Dictionary) -> float:
	if def.get("kind", "") == "trap":
		return float(def.get("size", 2.0)) * 0.5 * 1.41
	return float(def.get("radius", 1.0))


## structures: Array of {"pos": Vector2, "def": Dictionary}. Returns {"ok": bool, "reason": String}.
static func check(map: MapDef, structures: Array, def: Dictionary, p: Vector2) -> Dictionary:
	if def.is_empty():
		return {"ok": false, "reason": "BUILD_ERR_UNKNOWN"}
	var kind: String = def.get("kind", "tower")
	if kind == "trap":
		var half := float(def.get("size", 2.0)) * 0.5
		if not map.is_on_path(p, half * 0.6):
			return {"ok": false, "reason": "BUILD_ERR_NEED_PATH"}
		for s in structures:
			var sd: Dictionary = s.def
			if sd.get("kind", "") != "trap":
				continue
			var other_half := float(sd.get("size", 2.0)) * 0.5
			var d: Vector2 = (s.pos as Vector2) - p
			if absf(d.x) < half + other_half - 0.01 and absf(d.y) < half + other_half - 0.01:
				return {"ok": false, "reason": "BUILD_ERR_OVERLAP"}
	else:
		var r := float(def.get("radius", 1.0))
		if not map.bounds.grow(-r).has_point(p):
			return {"ok": false, "reason": "BUILD_ERR_BOUNDS"}
		if map.path.distance_to(p) < map.path_width * 0.5 + r:
			return {"ok": false, "reason": "BUILD_ERR_ON_PATH"}
		if map.circle_hits_obstacle(p, r):
			return {"ok": false, "reason": "BUILD_ERR_BLOCKED"}
		if p.distance_to(map.core_pos) < map.core_radius + r + 0.5:
			return {"ok": false, "reason": "BUILD_ERR_BLOCKED"}
		if not _on_flat_ground(map, p, r):
			return {"ok": false, "reason": "BUILD_ERR_SLOPE"}
		for s in structures:
			var sd: Dictionary = s.def
			if sd.get("kind", "") == "trap":
				continue
			if p.distance_to(s.pos) < r + float(sd.get("radius", 1.0)) + 0.2:
				return {"ok": false, "reason": "BUILD_ERR_OVERLAP"}
	return {"ok": true, "reason": ""}


## A tower may not straddle a plateau edge.
static func _on_flat_ground(map: MapDef, p: Vector2, r: float) -> bool:
	var h := map.height_at(p)
	for dir in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if not is_equal_approx(map.height_at(p + dir), h):
			return false
	return true
