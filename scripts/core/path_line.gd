class_name PathLine
extends RefCounted
## Polyline on the ground plane (x, z). Ground enemies are positioned by the distance
## travelled along it (`s`), which makes knockback, "first" targeting and leaks trivial.

var points: PackedVector2Array = PackedVector2Array()
var cumulative: PackedFloat32Array = PackedFloat32Array()
var length: float = 0.0


func _init(p_points: PackedVector2Array = PackedVector2Array()) -> void:
	points = p_points
	cumulative.resize(points.size())
	length = 0.0
	for i in points.size():
		if i > 0:
			length += points[i - 1].distance_to(points[i])
		cumulative[i] = length


func _segment_at(s: float) -> int:
	for i in range(1, points.size()):
		if s <= cumulative[i]:
			return i - 1
	return points.size() - 2


func sample(s: float) -> Vector2:
	s = clampf(s, 0.0, length)
	var i := _segment_at(s)
	var seg_len := cumulative[i + 1] - cumulative[i]
	var t := 0.0 if seg_len <= 0.0 else (s - cumulative[i]) / seg_len
	return points[i].lerp(points[i + 1], t)


func tangent(s: float) -> Vector2:
	var i := _segment_at(clampf(s, 0.0, length))
	return (points[i + 1] - points[i]).normalized()


## Closest point on the path: {"s": float, "dist": float, "point": Vector2}.
func closest(p: Vector2) -> Dictionary:
	var best := {"s": 0.0, "dist": INF, "point": points[0] if points.size() > 0 else Vector2.ZERO}
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d < best.dist:
			best = {"s": cumulative[i] + a.distance_to(q), "dist": d, "point": q}
	return best


func distance_to(p: Vector2) -> float:
	return closest(p).dist
