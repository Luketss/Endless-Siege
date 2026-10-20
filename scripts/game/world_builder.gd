class_name WorldBuilder
extends RefCounted
## Builds the 3D battlefield (visuals + colliders) from a MapDef.
## Collision layer 1 = world geometry (ground, plateaus, ramps, obstacles, borders).

const WORLD_LAYER := 1


static func build(root: Node3D, map: MapDef, shadows: bool = true) -> Dictionary:
	var refs := {}
	_environment(root, shadows)
	_ground(root, map)
	_road(root, map)
	for pl in map.plateaus:
		_plateau(root, pl)
	for o in map.obstacles:
		_obstacle(root, map, o)
	for w in map.walls:
		_wall(root, w)
	_borders(root, map)
	_decor(root, map)
	var portal := Models.portal()
	var start := map.path.points[0]
	portal.position = Vector3(start.x, 0, start.y + 1.0)
	root.add_child(portal)
	refs.portal = portal
	var core := Models.core()
	core.position = Vector3(map.core_pos.x, 0, map.core_pos.y)
	root.add_child(core)
	refs.core = core
	_static_cylinder(root, Vector3(map.core_pos.x, 1.5, map.core_pos.y), map.core_radius - 0.4, 3.0)
	return refs


static func _environment(root: Node3D, shadows: bool) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("2c2440")
	mat.sky_horizon_color = Color("a58aa0")
	mat.ground_horizon_color = Color("4a3f52")
	mat.ground_bottom_color = Color("1a1520")
	mat.sun_angle_max = 30.0
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color("7a6f8a")
	env.fog_density = 0.0035
	env.fog_aerial_perspective = 0.3
	env.ssao_enabled = shadows
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("ffe2c2")
	sun.light_energy = 1.25
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 90.0
	root.add_child(sun)


static func _static_box(root: Node3D, center: Vector3, size: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.position = center
	body.rotation_degrees = rot_deg
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	root.add_child(body)
	return body


static func _static_cylinder(root: Node3D, center: Vector3, radius: float, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.position = center
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	shape.shape = c
	body.add_child(shape)
	root.add_child(body)
	return body


static func _ground(root: Node3D, map: MapDef) -> void:
	var size := map.bounds.size + Vector2(60, 60)
	var center := map.bounds.get_center()
	Art.part(root, Art.box(Vector3(size.x, 1.0, size.y)), Art.mat(Art.PALETTE.grass), Vector3(center.x, -0.5, center.y), Vector3.ZERO, Vector3.ONE, false)
	_static_box(root, Vector3(center.x, -0.5, center.y), Vector3(size.x, 1.0, size.y))
	# Darker play area outline so the buildable zone reads clearly.
	Art.part(root, Art.box(Vector3(map.bounds.size.x + 0.6, 0.02, map.bounds.size.y + 0.6)), Art.mat(Art.PALETTE.grass_dark),
		Vector3(center.x, 0.005, center.y), Vector3.ZERO, Vector3.ONE, false)
	Art.part(root, Art.box(Vector3(map.bounds.size.x, 0.02, map.bounds.size.y)), Art.mat(Art.PALETTE.grass),
		Vector3(center.x, 0.01, center.y), Vector3.ZERO, Vector3.ONE, false)
	# Corruption patches spreading from the portal.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 18:
		var p := Vector2(rng.randf_range(map.bounds.position.x, map.bounds.end.x), rng.randf_range(map.bounds.position.y, map.bounds.position.y + 26))
		Art.part(root, Art.cyl(1.0, 1.0, 0.02, 12), Art.mat(Art.PALETTE.corruption.darkened(0.2)), Vector3(p.x, 0.012, p.y),
			Vector3.ZERO, Vector3(rng.randf_range(1.5, 4.0), 1, rng.randf_range(1.5, 4.0)), false)


static func _road(root: Node3D, map: MapDef) -> void:
	var pts := map.path.points
	var w := map.path_width
	var dirt := Art.mat(Art.PALETTE.dirt)
	var edge := Art.mat(Art.PALETTE.dirt_edge)
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		var ang := rad_to_deg(atan2(b.x - a.x, b.y - a.y))
		Art.part(root, Art.box(Vector3(w + 0.6, 0.04, length)), edge, Vector3(mid.x, 0.02, mid.y), Vector3(0, ang, 0), Vector3.ONE, false)
		Art.part(root, Art.box(Vector3(w, 0.06, length)), dirt, Vector3(mid.x, 0.03, mid.y), Vector3(0, ang, 0), Vector3.ONE, false)
	for i in range(1, pts.size() - 1):
		Art.part(root, Art.cyl(w * 0.5 + 0.3, w * 0.5 + 0.3, 0.04, 16), edge, Vector3(pts[i].x, 0.021, pts[i].y), Vector3.ZERO, Vector3.ONE, false)
		Art.part(root, Art.cyl(w * 0.5, w * 0.5, 0.06, 16), dirt, Vector3(pts[i].x, 0.031, pts[i].y), Vector3.ZERO, Vector3.ONE, false)
	# Stones along the edges.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var s := 2.0
	while s < map.path.length:
		var p := map.path.sample(s)
		var t := map.path.tangent(s)
		var n := Vector2(-t.y, t.x) * (1.0 if rng.randf() < 0.5 else -1.0)
		var q := p + n * (w * 0.5 + 0.35)
		if map.path.distance_to(q) > w * 0.5 + 0.1:
			Art.part(root, Art.sphere(0.25, 6), Art.mat(Art.PALETTE.stone_dark), Vector3(q.x, 0.1, q.y), Vector3.ZERO, Vector3(1, 0.6, 1.2), false)
		s += rng.randf_range(1.5, 3.5)


static func _plateau(root: Node3D, pl: Dictionary) -> void:
	var r: Rect2 = pl.rect
	var h := float(pl.height)
	var c := r.get_center()
	Art.part(root, Art.box(Vector3(r.size.x, h, r.size.y)), Art.mat(Art.PALETTE.stone_dark), Vector3(c.x, h * 0.5, c.y))
	Art.part(root, Art.box(Vector3(r.size.x - 0.2, 0.08, r.size.y - 0.2)), Art.mat(Color("4d5a45")), Vector3(c.x, h + 0.04, c.y), Vector3.ZERO, Vector3.ONE, false)
	_static_box(root, Vector3(c.x, h * 0.5, c.y), Vector3(r.size.x, h, r.size.y))
	var ramp_len := 4.5
	var ramp_w := 3.2
	var angle := rad_to_deg(atan2(h, ramp_len))
	var hyp := sqrt(h * h + ramp_len * ramp_len)
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	match pl.get("ramp", ""):
		"east":
			pos = Vector3(r.end.x + ramp_len * 0.5, h * 0.5, c.y)
			rot = Vector3(0, 0, -angle)
		"west":
			pos = Vector3(r.position.x - ramp_len * 0.5, h * 0.5, c.y)
			rot = Vector3(0, 0, angle)
		"north":
			pos = Vector3(c.x, h * 0.5, r.position.y - ramp_len * 0.5)
			rot = Vector3(-angle, 0, 0)
		"south":
			pos = Vector3(c.x, h * 0.5, r.end.y + ramp_len * 0.5)
			rot = Vector3(angle, 0, 0)
		_:
			return
	var size := Vector3(hyp, 0.3, ramp_w) if pl.ramp in ["east", "west"] else Vector3(ramp_w, 0.3, hyp)
	Art.part(root, Art.box(size), Art.mat(Art.PALETTE.stone), pos - Vector3(0, 0.1, 0), rot)
	_static_box(root, pos - Vector3(0, 0.1, 0), size, rot)


static func _obstacle(root: Node3D, map: MapDef, o: Dictionary) -> void:
	var p: Vector2 = o.pos
	var r := float(o.radius)
	if o.tall:
		# Ruined pillar / corrupted crystal spire: blocks line of sight.
		Art.part(root, Art.cyl(r * 0.75, r, 4.5, 6), Art.mat(Art.PALETTE.stone), Vector3(p.x, 2.25, p.y))
		Art.part(root, Art.prism(Vector3(r * 0.9, 2.0, r * 0.9)), Art.mat(Art.PALETTE.corruption, 1.2), Vector3(p.x + r * 0.2, 5.2, p.y), Vector3(0, 0, 8))
		_static_cylinder(root, Vector3(p.x, 2.5, p.y), r, 5.0)
	else:
		Art.part(root, Art.sphere(r, 7), Art.mat(Art.PALETTE.stone), Vector3(p.x, r * 0.45, p.y), Vector3(0, r * 40.0, 0), Vector3(1.0, 0.7, 0.85))
		_static_cylinder(root, Vector3(p.x, 0.6, p.y), r * 0.9, 1.2)


static func _wall(root: Node3D, w: Dictionary) -> void:
	var r: Rect2 = w.rect
	var c := r.get_center()
	var h := 3.2
	Art.part(root, Art.box(Vector3(r.size.x, h, r.size.y)), Art.mat(Color("6c665f")), Vector3(c.x, h * 0.5, c.y))
	# Broken crenellations.
	var n := int(maxf(r.size.x, r.size.y) / 1.4)
	for i in n:
		if i % 3 == 2:
			continue
		var t := (i + 0.5) / n
		var q := Vector2(lerpf(r.position.x, r.end.x, t), c.y) if r.size.x > r.size.y else Vector2(c.x, lerpf(r.position.y, r.end.y, t))
		Art.part(root, Art.box(Vector3(0.7, 0.6, 0.7)), Art.mat(Color("6c665f")), Vector3(q.x, h + 0.3, q.y))
	_static_box(root, Vector3(c.x, h * 0.5, c.y), Vector3(r.size.x, h, r.size.y))


static func _borders(root: Node3D, map: MapDef) -> void:
	var b := map.bounds.grow(1.0)
	var c := b.get_center()
	var h := 6.0
	_static_box(root, Vector3(c.x, h * 0.5, b.position.y), Vector3(b.size.x, h, 1.0))
	_static_box(root, Vector3(c.x, h * 0.5, b.end.y), Vector3(b.size.x, h, 1.0))
	_static_box(root, Vector3(b.position.x, h * 0.5, c.y), Vector3(1.0, h, b.size.y))
	_static_box(root, Vector3(b.end.x, h * 0.5, c.y), Vector3(1.0, h, b.size.y))


static func _decor(root: Node3D, map: MapDef) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var b := map.bounds
	# Dense corrupted forest framing the arena.
	for i in 140:
		var p := Vector2(rng.randf_range(b.position.x - 22, b.end.x + 22), rng.randf_range(b.position.y - 22, b.end.y + 22))
		if b.grow(1.5).has_point(p):
			continue
		_tree(root, p, rng)
	# Small details inside (no collision, never block building).
	for i in 70:
		var p := Vector2(rng.randf_range(b.position.x + 1, b.end.x - 1), rng.randf_range(b.position.y + 1, b.end.y - 1))
		if map.path.distance_to(p) < map.path_width * 0.5 + 0.5 or not map.plateau_at(p).is_empty():
			continue
		if rng.randf() < 0.6:
			Art.part(root, Art.cone(0.18, 0.5, 5), Art.mat(Color("5d7a4a")), Vector3(p.x, 0.25, p.y), Vector3.ZERO, Vector3.ONE, false)
		else:
			Art.part(root, Art.cyl(0.05, 0.06, 0.3, 5), Art.mat(Color("e0d6c0")), Vector3(p.x, 0.15, p.y), Vector3.ZERO, Vector3.ONE, false)
			Art.part(root, Art.sphere(0.2, 6), Art.mat(Color("b05ad0"), 1.5), Vector3(p.x, 0.35, p.y), Vector3.ZERO, Vector3(1, 0.5, 1), false)


static func _tree(root: Node3D, p: Vector2, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.8, 1.6)
	var corrupt := rng.randf() < 0.35
	Art.part(root, Art.cyl(0.25 * s, 0.35 * s, 2.0 * s, 6), Art.mat(Art.PALETTE.wood_dark), Vector3(p.x, 1.0 * s, p.y))
	var leaf := Art.mat(Art.PALETTE.leaf_corrupt if corrupt else Art.PALETTE.leaf, 0.3 if corrupt else 0.0)
	Art.part(root, Art.cone(1.6 * s, 2.6 * s, 7), leaf, Vector3(p.x, 2.8 * s, p.y))
	Art.part(root, Art.cone(1.2 * s, 2.0 * s, 7), leaf, Vector3(p.x, 3.9 * s, p.y))
