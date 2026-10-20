class_name Assets
extends RefCounted
## Loads the imported art (CC0 packs listed in assets/CREDITS.md) as configured in
## data/visuals.json. Every function returns null when a file is missing, so callers can
## fall back to the procedural placeholder models in `Models`.

const LOOPING := ["move", "idle", "run"]

static var _scenes: Dictionary = {}
static var _tex_mats: Dictionary = {}
## Set to false to force the procedural placeholders (debugging / comparisons).
static var enabled := true


static func scene(path: String) -> PackedScene:
	if not enabled or path == "":
		return null
	if _scenes.has(path):
		return _scenes[path]
	var packed: PackedScene = null
	if ResourceLoader.exists(path):
		packed = load(path) as PackedScene
	if packed == null:
		push_warning("Asset missing, using placeholder: %s" % path)
	_scenes[path] = packed
	return packed


static func instance(path: String) -> Node3D:
	var packed := scene(path)
	return packed.instantiate() as Node3D if packed else null


## Character/creature with skeleton animations. Returns a wrapper whose meta "anim"
## is the AnimationPlayer and "anims" maps roles (move, death, ...) to clip names.
static func creature(cfg: Dictionary) -> Node3D:
	if cfg.is_empty():
		return null
	var model := instance(cfg.get("scene", ""))
	if model == null:
		return null
	var root := Node3D.new()
	root.add_child(model)
	model.scale = Vector3.ONE * float(cfg.get("scale", 1.0))
	model.rotation_degrees.y = float(cfg.get("rot_y", 0.0))
	model.position.y = float(cfg.get("y", 0.0))
	_apply_textures(model, cfg)
	var player := _find_player(model)
	var anims: Dictionary = cfg.get("anims", {})
	if player:
		for role in LOOPING:
			if anims.has(role) and player.has_animation(anims[role]):
				player.get_animation(anims[role]).loop_mode = Animation.LOOP_LINEAR
	root.set_meta("anim", player)
	root.set_meta("anims", anims)
	root.set_meta("anim_speed", float(cfg.get("anim_speed", 1.0)))
	root.set_meta("model", model)
	_shadows(model)
	return root


## Plays an animation role ("move", "death", ...) if the model has it.
static func play(node: Node3D, role: String, speed: float = 1.0, blend: float = 0.15) -> bool:
	if node == null or not node.has_meta("anim"):
		return false
	var player: AnimationPlayer = node.get_meta("anim")
	var anims: Dictionary = node.get_meta("anims")
	if player == null or not anims.has(role) or not player.has_animation(anims[role]):
		return false
	var clip: String = anims[role]
	player.speed_scale = speed * float(node.get_meta("anim_speed", 1.0))
	if player.current_animation != clip or not player.is_playing():
		player.play(clip, blend)
	return true


static func clip_length(node: Node3D, role: String) -> float:
	if node == null or not node.has_meta("anim"):
		return 0.0
	var player: AnimationPlayer = node.get_meta("anim")
	var anims: Dictionary = node.get_meta("anims")
	if player == null or not anims.has(role) or not player.has_animation(anims[role]):
		return 0.0
	return player.get_animation(anims[role]).length


## Stacks static pieces (e.g. tower bottom/middle/top) on top of each other.
## Returns {"root": Node3D, "top": float (height of the stack)} or {} if any piece is missing.
static func stack(paths: Array, scale: float) -> Dictionary:
	var root := Node3D.new()
	var y := 0.0
	for path in paths:
		var piece := instance(path)
		if piece == null:
			root.free()
			return {}
		piece.scale = Vector3.ONE * scale
		piece.position.y = y
		root.add_child(piece)
		y += _height(piece) * scale
		no_self_shadow(piece)
	shadow_proxy_cylinder(root, 0.45 * scale, y)
	return {"root": root, "top": y}


## Kenney's textured kits self-shadow badly (fine striped acne that no bias removes),
## so their meshes do not cast shadows; a simple invisible proxy casts it instead.
static func no_self_shadow(n: Node) -> void:
	for mi in _meshes(n):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func shadow_proxy_cylinder(parent: Node3D, radius: float, height: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Art.cyl(radius, radius, height, 10)
	mi.position.y = height * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	parent.add_child(mi)
	return mi


static func shadow_proxy_box(parent: Node3D, size: Vector3, center: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Art.box(size)
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	parent.add_child(mi)
	return mi


static func prop(path: String, scale: float, rot_y: float = 0.0) -> Node3D:
	var p := instance(path)
	if p == null:
		return null
	p.scale = Vector3.ONE * scale
	p.rotation_degrees.y = rot_y
	_shadows(p)
	return p


## Multiplies the model colors by `color` (optionally adding a soft glow). Materials are
## cached per (source material, color) so repeated props share them.
static func tint(node: Node, color: Color, glow: bool = true) -> void:
	for mi in _meshes(node):
		var base: Material = mi.get_active_material(0)
		var key := "%s|%s|%s" % [base.get_instance_id() if base else 0, color.to_html(), glow]
		if not _tex_mats.has(key):
			var m := StandardMaterial3D.new()
			if base is StandardMaterial3D:
				m = (base as StandardMaterial3D).duplicate()
			m.albedo_color = m.albedo_color * color
			if glow:
				m.emission_enabled = true
				m.emission = color
				m.emission_energy_multiplier = 0.35
			_tex_mats[key] = m
		mi.material_override = _tex_mats[key]


static func _height(n: Node) -> float:
	var top := 0.0
	for c in n.get_children():
		if c is MeshInstance3D and c.mesh:
			var a: AABB = (c as MeshInstance3D).transform * c.mesh.get_aabb()
			top = maxf(top, a.end.y)
		top = maxf(top, _height(c))
	return top


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var p := _find_player(c)
		if p:
			return p
	return null


static func _apply_textures(model: Node, cfg: Dictionary) -> void:
	var map: Dictionary = cfg.get("textures", {})
	if cfg.has("texture"):
		map = {"*": cfg.texture}
	if map.is_empty():
		return
	for mi in _meshes(model):
		var path: String = map.get("*", "")
		for key in map:
			if key != "*" and String(mi.name).contains(key):
				path = map[key]
		if path != "":
			mi.material_override = _tex_mat(path)


static func _tex_mat(path: String) -> StandardMaterial3D:
	if _tex_mats.has(path):
		return _tex_mats[path]
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.roughness = 0.9
	_tex_mats[path] = m
	return m


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


static func _shadows(n: Node) -> void:
	for mi in _meshes(n):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
