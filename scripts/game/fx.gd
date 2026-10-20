class_name FX
extends Node3D
## Lightweight pooled visual effects. Everything fades out by itself.
## `low_quality` skips particles and limits floating text for performance/readability.

var low_quality := false
var show_numbers := true

var _active: Array[Dictionary] = []
var _mesh_pool: Array[MeshInstance3D] = []
var _label_pool: Array[Label3D] = []
var _particle_pool: Array[CPUParticles3D] = []
var _labels_alive := 0


func _get_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D
	if _mesh_pool.is_empty():
		mi = MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		add_child(mi)
	else:
		mi = _mesh_pool.pop_back()
	mi.mesh = mesh
	(mi.material_override as StandardMaterial3D).albedo_color = color
	mi.visible = true
	mi.rotation = Vector3.ZERO
	return mi


func ring(pos: Vector3, radius: float, color: Color, dur: float = 0.5, thickness: float = 0.12) -> void:
	var mi := _get_mesh(Art.torus(1.0 - thickness, 1.0), color)
	mi.position = pos + Vector3(0, 0.15, 0)
	_active.append({"kind": "ring", "node": mi, "t": 0.0, "dur": dur, "r": radius, "color": color})


func burst(pos: Vector3, radius: float, color: Color, dur: float = 0.35) -> void:
	var mi := _get_mesh(Art.sphere(1.0, 14), color)
	mi.position = pos
	_active.append({"kind": "burst", "node": mi, "t": 0.0, "dur": dur, "r": radius, "color": color})


func column(pos: Vector3, radius: float, height: float, color: Color, dur: float = 0.6) -> void:
	var mi := _get_mesh(Art.cyl(1.0, 1.0, 1.0, 16), color)
	mi.position = pos + Vector3(0, height * 0.5, 0)
	_active.append({"kind": "column", "node": mi, "t": 0.0, "dur": dur, "r": radius, "h": height, "color": color})


func streak(from: Vector3, to: Vector3, color: Color, dur: float = 0.25) -> void:
	var mi := _get_mesh(Art.box(Vector3(0.06, 0.06, 1.0)), color)
	var mid := from.lerp(to, 0.5)
	mi.position = mid
	if from.distance_to(to) > 0.01:
		mi.look_at_from_position(mid, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	mi.scale = Vector3(1, 1, from.distance_to(to))
	_active.append({"kind": "fade", "node": mi, "t": 0.0, "dur": dur, "color": color})


func arc(from: Vector3, to: Vector3, color: Color = Color("cdb8ff")) -> void:
	# Zig-zag lightning made of short streaks.
	var segs := 5
	var prev := from
	for i in range(1, segs + 1):
		var p := from.lerp(to, float(i) / segs)
		if i < segs:
			p += Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4))
		streak(prev, p, color, 0.18)
		prev = p


func sparks(pos: Vector3, color: Color, amount: int = 12, speed: float = 5.0) -> void:
	if low_quality:
		return
	var p: CPUParticles3D
	if _particle_pool.is_empty():
		p = CPUParticles3D.new()
		p.one_shot = true
		p.explosiveness = 0.95
		p.lifetime = 0.5
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3(0, -12, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		var q := BoxMesh.new()
		q.size = Vector3(0.12, 0.12, 0.12)
		q.material = m
		p.mesh = q
		add_child(p)
	else:
		p = _particle_pool.pop_back()
	p.position = pos
	p.amount = amount
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.color = color
	p.emitting = false
	p.restart()
	p.emitting = true
	_active.append({"kind": "particles", "node": p, "t": 0.0, "dur": 0.8})


func number(pos: Vector3, text: String, color: Color, size: int = 48, dur: float = 0.8) -> void:
	if not show_numbers or (_labels_alive > 18 and size < 60) or (low_quality and size < 60):
		return
	var l: Label3D
	if _label_pool.is_empty():
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.outline_size = 12
		l.outline_modulate = Color(0, 0, 0, 0.8)
		l.render_priority = 10
		add_child(l)
	else:
		l = _label_pool.pop_back()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.position = pos + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3))
	l.visible = true
	_labels_alive += 1
	_active.append({"kind": "label", "node": l, "t": 0.0, "dur": dur, "start": l.position, "color": color})


func _process(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for e in _active:
		e.t += delta
		var k: float = clampf(e.t / e.dur, 0.0, 1.0)
		var node: Node3D = e.node
		match e.kind:
			"ring":
				var r: float = lerpf(0.2, e.r, ease(k, 0.35))
				node.scale = Vector3(r, 0.05, r)
				_fade(node, e.color, 1.0 - k)
			"burst":
				var r: float = lerpf(e.r * 0.3, e.r, ease(k, 0.3))
				node.scale = Vector3(r, r, r)
				_fade(node, e.color, (1.0 - k) * 0.7)
			"column":
				node.scale = Vector3(e.r * (1.0 - k * 0.5), e.h, e.r * (1.0 - k * 0.5))
				_fade(node, e.color, (1.0 - k) * 0.6)
			"fade":
				_fade(node, e.color, 1.0 - k)
			"label":
				node.position = (e.start as Vector3) + Vector3(0, k * 1.4, 0)
				(node as Label3D).modulate = Color(e.color, 1.0 - k * k)
		if e.t >= e.dur:
			_release(e)
		else:
			keep.append(e)
	_active = keep


func _fade(node: Node3D, color: Color, a: float) -> void:
	var mi := node as MeshInstance3D
	if mi:
		(mi.material_override as StandardMaterial3D).albedo_color = Color(color, color.a * a)


func _release(e: Dictionary) -> void:
	var node: Node3D = e.node
	match e.kind:
		"label":
			node.visible = false
			_label_pool.append(node)
			_labels_alive -= 1
		"particles":
			_particle_pool.append(node)
		_:
			node.visible = false
			node.scale = Vector3.ONE
			_mesh_pool.append(node)
