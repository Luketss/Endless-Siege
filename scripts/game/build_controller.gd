class_name BuildController
extends Node3D
## Free placement of structures with a ghost preview under the crosshair (green = valid,
## red = invalid + reason), range preview, and quick actions on the structure you aim at:
## upgrade (U), sell (X), cycle targeting (Y). No nested menus.

signal message(text: String, ok: bool)

const ORDER := ["arrow", "cannon", "frost", "banner", "spikes", "spring", "tar"]

var sim: BattleSim
var rig: CameraRig
var view: BattleView
var selected := ""
var hovered: Units.Structure
var last_check := {}
var _ghost: Node3D
var _ghost_type := ""
var _range: MeshInstance3D
var _ok_mat := Art.mat(Color(0.3, 1.0, 0.45, 0.45), 1.0, 1.0, true, true)
var _bad_mat := Art.mat(Color(1.0, 0.25, 0.2, 0.45), 1.0, 1.0, true, true)


func slots() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if sim and sim.unlocked.has(id):
			out.append(id)
	return out


func select_slot(i: int) -> void:
	var s := slots()
	if i < 0 or i >= s.size():
		return
	selected = "" if selected == s[i] else s[i]
	Sfx.play("ui")


## Gamepad: step through the hotbar (wraps; one step past the ends deselects).
func cycle_slot(dir: int) -> void:
	var s := slots()
	if s.is_empty():
		return
	var i := s.find(selected)
	if i == -1:
		i = 0 if dir > 0 else s.size() - 1
	else:
		i += dir
	selected = s[i] if i >= 0 and i < s.size() else ""
	Sfx.play("ui")


func cancel() -> void:
	selected = ""
	_clear_ghost()


func is_building() -> bool:
	return selected != ""


func update(active: bool) -> void:
	if sim == null:
		return
	if not active:
		_clear_ghost()
		view.highlight_id = -1
		hovered = null
		return
	var hit = rig.world_hit(70.0)
	if selected != "":
		hovered = null
		view.highlight_id = -1
		_update_ghost(hit)
		if Input.is_action_just_pressed("attack") and hit != null:
			_try_build(Vector2(hit.x, hit.z))
		if Input.is_action_just_pressed("cancel"):
			cancel()
		return
	_clear_ghost()
	hovered = _structure_at(hit) if hit != null else null
	view.highlight_id = hovered.id if hovered else -1
	if hovered:
		if Input.is_action_just_pressed("upgrade"):
			var c := sim.upgrade_cost(hovered)
			if c < 0:
				message.emit(tr("MSG_MAX_LEVEL"), false)
			elif not sim.upgrade(hovered):
				message.emit(tr("BUILD_ERR_GOLD"), false)
				Sfx.play("deny", 0.2)
		elif Input.is_action_just_pressed("sell"):
			sim.sell(hovered)
			hovered = null
		elif Input.is_action_just_pressed("target_mode") and hovered.kind == "tower":
			var modes := ["first", "strong", "close"]
			hovered.target_mode = modes[(modes.find(hovered.target_mode) + 1) % modes.size()]
			Sfx.play("ui")


func _structure_at(hit: Vector3) -> Units.Structure:
	var p := Vector2(hit.x, hit.z)
	var best: Units.Structure = null
	var best_d := INF
	for st: Units.Structure in sim.structures:
		var d := p.distance_to(st.pos2())
		var r := float(st.def.get("radius", float(st.def.get("size", 2.0)) * 0.6)) + 0.6
		if d < r and d < best_d:
			best_d = d
			best = st
	return best


func _try_build(p: Vector2) -> void:
	var res := sim.can_build(selected, p)
	if not res.ok:
		message.emit(tr(res.reason), false)
		Sfx.play("deny", 0.2)
		return
	sim.build(selected, p)


func _update_ghost(hit: Variant) -> void:
	if hit == null:
		_clear_ghost()
		return
	var def := DataDB.structure(selected)
	var p := BuildRules.snap(def, Vector2(hit.x, hit.z))
	if _ghost_type != selected:
		_clear_ghost()
		_ghost = Models.structure(selected, def)
		_ghost_type = selected
		add_child(_ghost)
		if def.kind != "trap":
			_range = Art.ground_ring(_ghost, 1.0, Color(1, 1, 1, 0.6), 0.05)
	last_check = sim.can_build(selected, p)
	_ghost.position = sim.map.to_3d(p)
	_tint(_ghost, _ok_mat if last_check.ok else _bad_mat)
	if _range:
		var r := float(def.get("range", 0.0)) * (1.0 + sim.mods.stat("tower_range_pct"))
		if def.kind == "tower" and sim.map.height_at(p) > 0.0:
			r *= 1.2
		if def.kind == "support" and sim.mods.has("war_banner"):
			r *= 2.0
		_range.scale = Vector3(r, 0.02, r)


func _tint(node: Node, m: Material) -> void:
	for c in node.get_children():
		if c is MeshInstance3D and c.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			c.visible = false  # shadow proxy: the ghost casts no shadow
		elif c is MeshInstance3D and c != _range:
			c.material_override = m
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tint(c, m)


func _clear_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	_ghost = null
	_range = null
	_ghost_type = ""
	last_check = {}
