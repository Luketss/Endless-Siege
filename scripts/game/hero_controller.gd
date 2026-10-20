class_name HeroController
extends CharacterBody3D
## Player-controlled hero (Ranger): WASD movement relative to the camera, LMB shoots,
## Q arrow rain at the crosshair, E concussive blast, Space dodge roll, F interact.
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


func place_at_spawn() -> void:
	global_position = sim.hero.pos + Vector3(0, 0.1, 0)
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	var h := sim.hero
	if not h.alive:
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
			_dodge_t = float(def.dodge.duration)
			_dodge_dir = move.normalized() if move.length() > 0.1 else f
	var vel := move * float(def.speed)
	if _dodge_t > 0.0:
		_dodge_t -= delta
		vel = _dodge_dir * float(def.dodge.distance) / float(def.dodge.duration)
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
		return
	var muzzle := global_position + Vector3(0, 1.45, 0) + rig.right_flat() * 0.35
	if Input.is_action_pressed("attack") and not attack_blocked:
		var aim := rig.aim_point(sim, muzzle)
		if sim.hero_attack(muzzle, aim - muzzle):
			_recoil = 1.0
	if Input.is_action_just_pressed("ability_1"):
		var p = rig.world_hit(40.0)
		if p == null:
			p = global_position + rig.forward_flat() * 12.0
		var target: Vector3 = p
		if Vector2(target.x, target.z).distance_to(Vector2(global_position.x, global_position.z)) > 32.0:
			var dir := (target - global_position)
			dir.y = 0.0
			target = global_position + dir.normalized() * 32.0
		if not sim.hero_rain(target):
			Sfx.play("deny", 0.3)
	if Input.is_action_just_pressed("ability_2"):
		if not sim.hero_blast(global_position, rig.forward_flat()):
			Sfx.play("deny", 0.3)
	if Input.is_action_just_pressed("interact"):
		sim.hero_interact()


func _animate(delta: float, move: Vector3) -> void:
	var parts: Dictionary = model.get_meta("parts")
	var aiming := input_enabled and (Input.is_action_pressed("attack") or _recoil > 0.0)
	var face := rig.forward_flat() if aiming else move
	if face.length() > 0.1:
		var yaw := atan2(-face.x, -face.z)
		model.rotation.y = lerp_angle(model.rotation.y, yaw, minf(1.0, delta * 14.0))
	var speed := Vector2(velocity.x, velocity.z).length()
	parts.body.position.y = 0.75 + absf(sin(_time * 10.0)) * 0.06 * minf(1.0, speed / 6.0)
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	parts.bow.position.z = -0.25 + _recoil * 0.12
	if _dodge_t > 0.0:
		model.rotation.x = -TAU * (1.0 - _dodge_t / 0.32)
	else:
		model.rotation.x = 0.0
	# Flicker while invulnerable after respawn.
	model.visible = sim.hero.invuln_t <= 0.0 or _dodge_t > 0.0 or int(_time * 12.0) % 2 == 0
