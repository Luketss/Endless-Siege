class_name HeroController
extends CharacterBody3D
## Player-controlled hero (Ranger): WASD movement relative to the camera, LMB shoots,
## Q arrow rain at the crosshair, E concussive blast, Space dodge roll, F interact.
## Abilities aim while the key is held (area/cone preview) and fire on release;
## a quick tap fires immediately. Right click cancels the aim.
## Gameplay effects go through BattleSim so they are testable and consistent.

const GRAVITY := 26.0

var sim: BattleSim
var rig: CameraRig
var input_enabled := false
var attack_blocked := false  # true while placing a structure
var model: Node3D
var _dodge_t := 0.0
var _dodge_dir := Vector3.ZERO
var _was_alive := true
var _recoil := 0.0
var _time := 0.0
var _aiming_ability := ""  # ability id ("rain", "slam", ...) while its key is held
var _cast_t := 0.0  # plays the cast animation
var _charging := false
var _dash_dist := 0.0
var hero_id := "ranger"
var _rain_preview: Node3D
var _blast_preview: MeshInstance3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = WorldBuilder.WORLD_LAYER
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	model = Models.hero()
	add_child(model)
	_build_previews()


func _build_previews() -> void:
	_rain_preview = Node3D.new()
	_rain_preview.top_level = true
	add_child(_rain_preview)
	var disc := MeshInstance3D.new()
	disc.mesh = Art.cyl(1.0, 1.0, 0.04, 40)
	disc.material_override = _preview_mat(0.22)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_preview.add_child(disc)
	var edge := MeshInstance3D.new()
	edge.mesh = Art.torus(0.93, 1.0)
	edge.material_override = _preview_mat(0.8)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_preview.add_child(edge)
	_rain_preview.visible = false
	_blast_preview = MeshInstance3D.new()
	_blast_preview.top_level = true
	_blast_preview.material_override = _preview_mat(0.3)
	_blast_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blast_preview)
	_blast_preview.visible = false


func _preview_mat(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = Color(0.67, 1.0, 0.72, alpha)
	return m


## Flat fan mesh for the blast cone (pointing along -Z).
static func cone_mesh(radius: float, angle_deg: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(angle_deg * 0.5)
	var seg := 16
	for i in seg:
		var a0 := -half + 2.0 * half * i / seg
		var a1 := -half + 2.0 * half * (i + 1) / seg
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0), 0, -cos(a0)) * radius)
		st.add_vertex(Vector3(sin(a1), 0, -cos(a1)) * radius)
	return st.commit()


## Swaps the model when the run uses another hero.
func set_hero(id: String) -> void:
	if id == hero_id and model:
		return
	hero_id = id
	if model:
		model.queue_free()
	model = Models.hero(id)
	add_child(model)


## Roll / charge: moves `distance` metres along `dir` in `duration` seconds.
func _dash(dir: Vector3, distance: float, duration: float) -> void:
	_dodge_t = duration
	_dodge_dir = dir
	_dash_dist = distance / duration


func place_at_spawn() -> void:
	global_position = sim.hero.pos + Vector3(0, 0.1, 0)
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	var h := sim.hero
	if not h.alive:
		_cancel_aim()
		if model.has_meta("anim"):
			if _was_alive:
				Assets.play(model, "death", 1.0, 0.05)
		else:
			model.visible = false
		_was_alive = false
		return
	if not _was_alive:
		_was_alive = true
		place_at_spawn()
	model.visible = true
	var def: Dictionary = h.def
	var move := Vector3.ZERO
	if input_enabled:
		var f := rig.forward_flat()
		var r := rig.right_flat()
		move = f * Input.get_axis("move_back", "move_forward") + r * Input.get_axis("move_left", "move_right")
		if move.length() > 1.0:
			move = move.normalized()
		if Input.is_action_just_pressed("dodge") and sim.hero_dodge():
			_dash(move.normalized() if move.length() > 0.1 else f, float(def.dodge.distance), float(def.dodge.duration))
	var vel := move * float(def.speed)
	if _dodge_t > 0.0:
		_dodge_t -= delta
		vel = _dodge_dir * _dash_dist
		if _dodge_t <= 0.0:
			_charging = false
	velocity.x = vel.x
	velocity.z = vel.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < -5.0:
		place_at_spawn()
	sim.set_hero_position(global_position)
	_combat_input()
	_animate(delta, move)


func _combat_input() -> void:
	if not input_enabled:
		_cancel_aim()
		return
	if Input.is_action_pressed("attack") and not attack_blocked:
		if sim.hero.def.attack.get("melee", false):
			if sim.hero_attack(global_position + Vector3(0, 1.0, 0), rig.forward_flat()):
				_recoil = 1.0
		else:
			var muzzle := global_position + Vector3(0, 1.45, 0) + rig.right_flat() * 0.35
			var aim := rig.aim_point(sim, muzzle)
			if sim.hero_attack(muzzle, aim - muzzle):
				_recoil = 1.0
	if Input.is_action_just_pressed("ability_1"):
		_aiming_ability = sim.ability_id(0)
	elif Input.is_action_just_pressed("ability_2"):
		_aiming_ability = sim.ability_id(1)
	if _aiming_ability != "" and Input.is_action_just_pressed("cancel"):
		_aiming_ability = ""
	if _aiming_ability != "":
		var key := "ability_1" if _aiming_ability == sim.ability_id(0) else "ability_2"
		if Input.is_action_pressed(key):
			_show_preview()
		else:
			var id := _aiming_ability
			_aiming_ability = ""
			if not _cast(id):
				Sfx.play("deny", 0.3)
	_rain_preview.visible = _aiming_ability == "rain" or _aiming_ability == "slam"
	_blast_preview.visible = _aiming_ability == "blast" or _aiming_ability == "charge"
	if Input.is_action_just_pressed("interact"):
		sim.hero_interact()


func _cast(id: String) -> bool:
	match id:
		"rain":
			return sim.hero_rain(rain_target())
		"blast":
			return sim.hero_blast(global_position, rig.forward_flat())
		"slam":
			if sim.hero_slam():
				_cast_t = 0.5
				return true
		"charge":
			if sim.hero_charge(rig.forward_flat()):
				var c: Dictionary = sim.hero.def.charge
				_dash(rig.forward_flat(), float(c.distance), float(c.duration))
				_charging = true
				return true
	return false


func _cancel_aim() -> void:
	_aiming_ability = ""
	_rain_preview.visible = false
	_blast_preview.visible = false


## Ground point for the arrow rain: under the crosshair, clamped to 32 m.
func rain_target() -> Vector3:
	var p = rig.world_hit(40.0)
	if p == null:
		p = global_position + rig.forward_flat() * 12.0
	var target: Vector3 = p
	if Vector2(target.x, target.z).distance_to(Vector2(global_position.x, global_position.z)) > 32.0:
		var dir := (target - global_position)
		dir.y = 0.0
		target = global_position + dir.normalized() * 32.0
	return target


func _show_preview() -> void:
	var h := sim.hero
	var ready := (h.rain_cd if _aiming_ability == sim.ability_id(0) else h.blast_cd) <= 0.0
	var col := Color(0.67, 1.0, 0.72) if ready else Color(1.0, 0.45, 0.4)
	match _aiming_ability:
		"rain", "slam":
			var at := rain_target() if _aiming_ability == "rain" else global_position
			_rain_preview.global_position = at + Vector3(0, 0.08, 0)
			_rain_preview.scale = Vector3.ONE * float(h.def[_aiming_ability].radius)
			for c: MeshInstance3D in _rain_preview.get_children():
				var m := c.material_override as StandardMaterial3D
				m.albedo_color = Color(col, m.albedo_color.a)
		_:
			if _blast_preview.get_meta("for", "") != _aiming_ability:
				var d: Dictionary = h.def[_aiming_ability]
				_blast_preview.mesh = cone_mesh(float(d.range), float(d.angle)) if _aiming_ability == "blast" \
						else lane_mesh(float(d.distance), float(d.width))
				_blast_preview.set_meta("for", _aiming_ability)
			_blast_preview.global_position = global_position + Vector3(0, 0.1, 0)
			_blast_preview.rotation = Vector3(0, rig.yaw, 0)
			var bm := _blast_preview.material_override as StandardMaterial3D
			bm.albedo_color = Color(col, bm.albedo_color.a)


## Flat rectangle for the charge lane (pointing along -Z).
static func lane_mesh(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := width * 0.5
	for v in [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, 0, -length), Vector3(-w, 0, 0), Vector3(w, 0, -length), Vector3(-w, 0, -length)]:
		st.add_vertex(v)
	return st.commit()


func _animate(delta: float, move: Vector3) -> void:
	var parts: Dictionary = model.get_meta("parts")
	var aiming := input_enabled and (Input.is_action_pressed("attack") or _recoil > 0.0)
	var face := rig.forward_flat() if aiming else move
	if face.length() > 0.1:
		var yaw := atan2(-face.x, -face.z)
		model.rotation.y = lerp_angle(model.rotation.y, yaw, minf(1.0, delta * 14.0))
	var speed := Vector2(velocity.x, velocity.z).length()
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	_cast_t = maxf(0.0, _cast_t - delta)
	if model.has_meta("anim"):
		_animate_imported(speed)
	else:
		parts.body.position.y = 0.75 + absf(sin(_time * 10.0)) * 0.06 * minf(1.0, speed / 6.0)
		if parts.has("bow"):
			parts.bow.position.z = -0.25 + _recoil * 0.12
		model.rotation.x = -TAU * (1.0 - _dodge_t / 0.32) if _dodge_t > 0.0 else 0.0
	# Flicker while invulnerable after respawn.
	model.visible = sim.hero.invuln_t <= 0.0 or _dodge_t > 0.0 or int(_time * 12.0) % 2 == 0


## Skeletal animation for the imported hero model.
func _animate_imported(speed: float) -> void:
	if _dodge_t > 0.0 and _charging:
		Assets.play(model, "attack", 1.5, 0.05)
	elif _dodge_t > 0.0:
		Assets.play(model, "roll", 1.6, 0.05)
	elif _cast_t > 0.0:
		Assets.play(model, "cast", 1.4, 0.05)
	elif _recoil > 0.0 or (input_enabled and Input.is_action_pressed("attack") and not attack_blocked):
		Assets.play(model, "attack", 2.0, 0.08)
	elif speed > 0.5:
		Assets.play(model, "run", clampf(speed / 6.0, 0.6, 1.4))
	else:
		Assets.play(model, "idle")
