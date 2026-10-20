class_name CameraRig
extends Node3D
## Over-the-shoulder third-person camera. Mouse moves the camera (captured cursor);
## the screen centre is the aim point for attacks, abilities and building.
## In "overview" mode (journey map / menus) it slowly orbits the battlefield.

const MIN_PITCH := -1.25
const MAX_PITCH := 0.3

var target: Node3D
var yaw := PI
var pitch := -0.42
var distance := 8.0
var overview := false
var overview_center := Vector3.ZERO
var spring: SpringArm3D
var camera: Camera3D
var _shoulder := Vector3(1.1, 0.0, 0.0)
var _trauma := 0.0


func _ready() -> void:
	spring = SpringArm3D.new()
	spring.collision_mask = WorldBuilder.WORLD_LAYER
	spring.margin = 0.3
	spring.spring_length = distance
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 400.0
	spring.add_child(camera)
	camera.make_current()


func set_captured(v: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if v else Input.MOUSE_MODE_VISIBLE


func is_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if overview:
		return
	if event is InputEventMouseMotion and is_captured():
		var sens := 0.0025 * float(Settings.get_value("mouse_sensitivity"))
		var inv := -1.0 if Settings.get_value("invert_y") else 1.0
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens * inv, MIN_PITCH, MAX_PITCH)
	elif event.is_action_pressed("zoom_in"):
		distance = clampf(distance - 0.8, 3.5, 14.0)
	elif event.is_action_pressed("zoom_out"):
		distance = clampf(distance + 0.8, 3.5, 14.0)


## Adds screen shake (0..1, decays; the offset grows with the square of trauma).
func add_shake(amount: float) -> void:
	if Settings.get_value("screen_shake"):
		_trauma = minf(1.0, _trauma + amount)


func _apply_shake(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	var k := _trauma * _trauma
	var t := Time.get_ticks_msec() / 1000.0
	camera.h_offset = k * 0.35 * sin(t * 47.0)
	camera.v_offset = k * 0.35 * sin(t * 53.0 + 1.7)


func _process(delta: float) -> void:
	_apply_shake(delta)
	if overview:
		yaw += delta * 0.06
		global_position = global_position.lerp(overview_center + Vector3(0, 6, 0), minf(1.0, delta * 2.0))
		rotation = Vector3(-0.75, yaw, 0)
		spring.spring_length = lerpf(spring.spring_length, 58.0, minf(1.0, delta * 2.0))
		spring.position = Vector3.ZERO
		return
	if target:
		var goal := target.global_position + Vector3(0, 1.7, 0)
		global_position = global_position.lerp(goal, minf(1.0, delta * 14.0))
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO and is_captured():
		var sens := float(Settings.get_value("mouse_sensitivity"))
		var inv := -1.0 if Settings.get_value("invert_y") else 1.0
		# Squared response: fine aim near the centre, fast turns at full tilt.
		look *= look.length()
		yaw -= look.x * 3.0 * sens * delta
		pitch = clampf(pitch - look.y * 1.8 * sens * inv * delta, MIN_PITCH, MAX_PITCH)
	rotation = Vector3(pitch, yaw, 0)
	spring.spring_length = lerpf(spring.spring_length, distance, minf(1.0, delta * 8.0))
	spring.position = _shoulder


func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func aim_ray() -> Dictionary:
	var vp := get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	return {"origin": camera.project_ray_origin(center), "dir": camera.project_ray_normal(center)}


## World hit under the crosshair (layer 1), or null.
func world_hit(max_dist: float = 120.0) -> Variant:
	var ray := aim_ray()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(ray.origin, ray.origin + ray.dir * max_dist, WorldBuilder.WORLD_LAYER)
	var hit := space.intersect_ray(q)
	return hit.position if not hit.is_empty() else null


## Point to shoot at: the enemy closest to the crosshair ray (aim assist), else the
## world under the crosshair, else far along the ray.
func aim_point(sim: BattleSim, from: Vector3) -> Vector3:
	var ray := aim_ray()
	var o: Vector3 = ray.origin
	var d: Vector3 = ray.dir
	var best: Units.Enemy = null
	var best_score := INF
	for e: Units.Enemy in sim.enemies:
		if not e.alive:
			continue
		var c := e.pos + Vector3(0, e.size, 0)
		var t := (c - o).dot(d)
		if t < 2.0 or c.distance_to(from) > 45.0:
			continue
		var perp := (o + d * t).distance_to(c)
		if perp < e.size + 0.9 and perp + t * 0.01 < best_score:
			best_score = perp + t * 0.01
			best = e
	if best:
		return best.pos + Vector3(0, best.size, 0)
	var hit = world_hit(60.0)
	if hit != null:
		return hit
	return o + d * 50.0
