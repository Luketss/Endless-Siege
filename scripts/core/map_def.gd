class_name MapDef
extends RefCounted
## Gameplay geometry of a battlefield, built from data/maps/*.json.
## Coordinates: Vector2(x, z) on the ground plane; heights in metres.

var id: String = ""
var name_key: String = ""
var bounds: Rect2
var path: PathLine
var path_width: float = 5.0
var core_pos: Vector2
var core_radius: float = 3.0
var hero_spawn: Vector2
var fly_spawns: Array[Vector2] = []
## [{"pos": Vector2, "radius": float, "tall": bool}]
var obstacles: Array[Dictionary] = []
## [{"rect": Rect2, "tall": bool}]
var walls: Array[Dictionary] = []
## [{"rect": Rect2, "height": float, "ramp": String}]
var plateaus: Array[Dictionary] = []


static func from_dict(d: Dictionary) -> MapDef:
	var m := MapDef.new()
	m.id = d.get("id", "")
	m.name_key = d.get("name_key", "")
	var b: Array = d.bounds
	m.bounds = Rect2(b[0], b[1], b[2], b[3])
	var pts := PackedVector2Array()
	for p in d.path:
		pts.append(Vector2(p[0], p[1]))
	m.path = PathLine.new(pts)
	m.path_width = float(d.get("path_width", 5.0))
	m.core_pos = Vector2(d.core.pos[0], d.core.pos[1])
	m.core_radius = float(d.core.get("radius", 3.0))
	m.hero_spawn = Vector2(d.hero_spawn[0], d.hero_spawn[1])
	for f in d.get("fly_spawns", []):
		m.fly_spawns.append(Vector2(f[0], f[1]))
	for o in d.get("obstacles", []):
		m.obstacles.append({"pos": Vector2(o.pos[0], o.pos[1]), "radius": float(o.radius), "tall": bool(o.get("tall", false))})
	for w in d.get("walls", []):
		var r: Array = w.rect
		m.walls.append({"rect": Rect2(r[0], r[1], r[2], r[3]), "tall": bool(w.get("tall", true))})
	for p in d.get("plateaus", []):
		var r: Array = p.rect
		m.plateaus.append({"rect": Rect2(r[0], r[1], r[2], r[3]), "height": float(p.height), "ramp": p.get("ramp", "")})
	return m


func plateau_at(p: Vector2) -> Dictionary:
	for pl in plateaus:
		if (pl.rect as Rect2).has_point(p):
			return pl
	return {}


func height_at(p: Vector2) -> float:
	var pl := plateau_at(p)
	return 0.0 if pl.is_empty() else float(pl.height)


func to_3d(p: Vector2, extra_height: float = 0.0) -> Vector3:
	return Vector3(p.x, height_at(p) + extra_height, p.y)


func is_on_path(p: Vector2, margin: float = 0.0) -> bool:
	return path.distance_to(p) <= path_width * 0.5 - margin


## True when the straight line a->b is blocked by a tall obstacle or wall.
## Structures on a plateau see over short obstacles only (tall ones still block).
func blocks_los(a: Vector2, b: Vector2) -> bool:
	for o in obstacles:
		if not o.tall:
			continue
		var q := Geometry2D.get_closest_point_to_segment(o.pos, a, b)
		if q.distance_to(o.pos) < float(o.radius) * 0.85:
			return true
	for w in walls:
		if not w.tall:
			continue
		if _segment_hits_rect(a, b, w.rect):
			return true
	return false


static func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


func circle_hits_obstacle(p: Vector2, radius: float) -> bool:
	for o in obstacles:
		if p.distance_to(o.pos) < radius + float(o.radius):
			return true
	for w in walls:
		var r: Rect2 = w.rect
		var cx := clampf(p.x, r.position.x, r.end.x)
		var cz := clampf(p.y, r.position.y, r.end.y)
		if p.distance_to(Vector2(cx, cz)) < radius:
			return true
	return false
