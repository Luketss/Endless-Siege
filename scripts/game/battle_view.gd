class_name BattleView
extends Node3D
## Draws a BattleSim: keeps one pooled 3D node per enemy/structure/projectile/zone and
## turns simulation events into effects and sounds. Never changes gameplay state.

var sim: BattleSim
var fx: FX
var core_node: Node3D
var show_all_ranges := false
var highlight_id := -1

var _enemy_nodes := {}
var _enemy_pool := {}  # "type|elite" -> Array[Node3D]
var _struct_nodes := {}
var _proj_nodes := {}
var _proj_pool := {}
var _zone_nodes := {}
var _cache_node: Node3D
var _time := 0.0
var _dying: Array[Dictionary] = []
var _hp_bar_mesh := QuadMesh.new()


func _ready() -> void:
	fx = FX.new()
	add_child(fx)
	_hp_bar_mesh.size = Vector2(1, 0.12)


func bind(p_sim: BattleSim) -> void:
	sim = p_sim
	for id in _enemy_nodes.keys():
		_release_enemy(id)
	for id in _proj_nodes.keys():
		_release_projectile(id)
	for id in _zone_nodes.keys():
		_zone_nodes[id].queue_free()
	_zone_nodes.clear()
	# Structures are rebuilt from the new sim's snapshot (ids change between encounters).
	for id in _struct_nodes.keys():
		_struct_nodes[id].queue_free()
	_struct_nodes.clear()


func apply_settings() -> void:
	fx.low_quality = Settings.get_value("effects_quality") == "low"
	fx.show_numbers = Settings.get_value("damage_numbers")


func _process(delta: float) -> void:
	_time += delta
	_update_dying(delta)
	if sim == null:
		return
	_sync_enemies(delta)
	_sync_structures(delta)
	_sync_projectiles()
	_sync_zones()
	_sync_cache()
	_animate_core()


# ---------------------------------------------------------------- enemies

func _sync_enemies(delta: float) -> void:
	var seen := {}
	for e: Units.Enemy in sim.enemies:
		if not e.alive:
			continue
		seen[e.id] = true
		var node: Node3D = _enemy_nodes.get(e.id)
		if node == null:
			node = _acquire_enemy(e)
			_enemy_nodes[e.id] = node
			node.position = e.pos
		var prev: Vector3 = node.position
		node.position = e.pos
		var vel := e.pos - prev
		vel.y = 0.0
		if vel.length() > 0.001:
			var yaw := atan2(-vel.x, -vel.z)
			node.rotation.y = lerp_angle(node.rotation.y, yaw, minf(1.0, delta * 12.0))
		if node.has_meta("anim"):
			_animate_enemy(node, e)
		var parts: Dictionary = node.get_meta("parts")
		var body: Node3D = parts.get("body")
		if body and not e.flying and e.frozen_t <= 0.0:
			var base_y: float = body.get_meta("base_y", body.position.y)
			body.set_meta("base_y", base_y)
			body.position.y = base_y + absf(sin(_time * e.speed * 3.0 + e.id)) * e.size * 0.12
		_status_visuals(node, e)
		_hp_bar(node, e)
	for id in _enemy_nodes.keys():
		if not seen.has(id):
			_release_enemy(id)


func _acquire_enemy(e: Units.Enemy) -> Node3D:
	var key := "%s|%s" % [e.type, e.elite]
	var pool: Array = _enemy_pool.get(key, [])
	var node: Node3D
	if pool.is_empty():
		node = Models.enemy(e.type, e.def, e.elite)
		node.set_meta("pool_key", key)
		add_child(node)
	else:
		node = pool.pop_back()
		node.visible = true
	return node


func _release_enemy(id: int) -> void:
	var node: Node3D = _enemy_nodes[id]
	_enemy_nodes.erase(id)
	# Animated models play their death clip before going back to the pool.
	var t := minf(1.1, Assets.clip_length(node, "death"))
	if t > 0.0 and node.visible and not fx.low_quality and Assets.play(node, "death", 1.0, 0.05):
		var bar: Node3D = node.get_meta("hp_bar") if node.has_meta("hp_bar") else null
		if bar:
			bar.visible = false
		_dying.append({"node": node, "t": t})
		return
	_to_pool(node)


func _to_pool(node: Node3D) -> void:
	node.visible = false
	_enemy_pool.get_or_add(node.get_meta("pool_key"), []).append(node)


func _update_dying(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for d in _dying:
		d.t -= delta
		if d.t <= 0.0:
			_to_pool(d.node)
		else:
			keep.append(d)
	_dying = keep


func _animate_enemy(node: Node3D, e: Units.Enemy) -> void:
	var player: AnimationPlayer = node.get_meta("anim")
	if player == null:
		return
	if e.frozen_t > 0.0 or e.launched_t > 0.0:
		player.speed_scale = 0.0
		return
	var factor := e.speed / maxf(0.1, float(e.def.speed))
	if e.chill_t > 0.0:
		factor *= 1.0 - e.chill_slow
	if e.in_tar > 0.0:
		factor *= 1.0 - e.in_tar
	Assets.play(node, "move", clampf(factor, 0.2, 2.5))


func _status_visuals(node: Node3D, e: Units.Enemy) -> void:
	_overlay(node, "chill", e.chill_t > 0.0 and e.frozen_t <= 0.0, func():
		return Art.part(node, Art.sphere(e.size * 1.15), Art.mat(Color(0.55, 0.85, 1.0, 0.28), 1.0, 1.0, true, true), Vector3(0, e.size * 0.9, 0), Vector3.ZERO, Vector3.ONE, false))
	_overlay(node, "frozen", e.frozen_t > 0.0, func():
		return Art.part(node, Art.box(Vector3(1.6, 2.2, 1.6) * e.size), Art.mat(Color(0.7, 0.92, 1.0, 0.55), 1.5, 0.1, true), Vector3(0, e.size * 1.0, 0), Vector3(0, 20, 0), Vector3.ONE, false))
	_overlay(node, "burn", e.burn_t > 0.0, func():
		var f := Node3D.new()
		node.add_child(f)
		for i in 3:
			Art.part(f, Art.cone(e.size * 0.3, e.size * 0.9, 5), Art.mat(Art.PALETTE.fire, 4.0, 1.0, false, true),
				Vector3((i - 1) * e.size * 0.35, e.size * 1.8, 0), Vector3.ZERO, Vector3.ONE, false)
		return f)
	_overlay(node, "oiled", e.oiled_t > 0.0, func():
		return Art.part(node, Art.cyl(e.size * 0.8, e.size * 0.8, 0.03, 10), Art.mat(Color(0.05, 0.04, 0.03, 0.8), 0.0, 0.05, true), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, false))
	_overlay(node, "shield", e.shielded > 0.0, func():
		return Art.part(node, Art.sphere(e.size * 1.35), Art.mat(Color(0.45, 0.65, 1.0, 0.18), 1.5, 1.0, true, true), Vector3(0, e.size, 0), Vector3.ZERO, Vector3.ONE, false))
	var burn: Node3D = (node.get_meta("ov_burn") if node.has_meta("ov_burn") else null)
	if burn and burn.visible:
		burn.scale = Vector3.ONE * (0.85 + 0.25 * sin(_time * 18.0 + e.id))


func _overlay(node: Node3D, key: String, visible: bool, make: Callable) -> void:
	var meta := "ov_" + key
	var ov: Node3D = (node.get_meta(meta) if node.has_meta(meta) else null)
	if visible and ov == null:
		ov = make.call()
		node.set_meta(meta, ov)
	if ov:
		ov.visible = visible


func _hp_bar(node: Node3D, e: Units.Enemy) -> void:
	var bar: Node3D = (node.get_meta("hp_bar") if node.has_meta("hp_bar") else null)
	var show := e.hp < e.max_hp or e.boss or e.elite
	if bar == null:
		if not show:
			return
		bar = Node3D.new()
		node.add_child(bar)
		var bg := MeshInstance3D.new()
		bg.mesh = _hp_bar_mesh
		bg.material_override = _bar_mat(Color(0, 0, 0, 0.7))
		bar.add_child(bg)
		var fill := MeshInstance3D.new()
		fill.mesh = _hp_bar_mesh
		fill.name = "fill"
		bar.add_child(fill)
		node.set_meta("hp_bar", bar)
		var w := 1.0 + e.size * (3.0 if e.boss else 0.8)
		bar.scale = Vector3(w, 1.0 if not e.boss else 2.2, 1)
		var cfg: Dictionary = DataDB.visuals().get("enemies", {}).get(e.type, {})
		var bar_y: float = float(cfg.bar_y) if cfg.has("bar_y") and node.has_meta("anim") else e.size * (2.3 if not e.boss else 1.6) + 0.5
		bar.position = Vector3(0, bar_y, 0)
	bar.visible = show
	if not show:
		return
	var ratio := clampf(e.hp / e.max_hp, 0.0, 1.0)
	var fill: MeshInstance3D = bar.get_node("fill")
	fill.scale = Vector3(ratio, 0.75, 1)
	fill.position = Vector3(-(1.0 - ratio) * 0.5, 0, 0.001)
	var c := Color("ff5a4f") if ratio < 0.35 else (Color("ffd25a") if ratio < 0.7 else Color("6fe08a"))
	if e.boss:
		c = Color("ff7a2a")
	fill.material_override = _bar_mat(c)


var _bar_mats := {}


func _bar_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _bar_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = c
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		m.render_priority = 5
		_bar_mats[key] = m
	return _bar_mats[key]


# ---------------------------------------------------------------- structures

func _sync_structures(delta: float) -> void:
	var seen := {}
	for st: Units.Structure in sim.structures:
		seen[st.id] = true
		var node: Node3D = _struct_nodes.get(st.id)
		if node == null:
			node = Models.structure(st.type, st.def)
			node.position = st.pos
			node.set_meta("level", 0)
			add_child(node)
			_struct_nodes[st.id] = node
			fx.ring(st.pos, 2.5, Color(1, 1, 1, 0.8), 0.4)
		if int(node.get_meta("level")) != st.level:
			var old := node.get_node_or_null("pips")
			if old:
				old.queue_free()
			if st.level > 1:
				Models.level_pips(node, st.level, float(node.get_meta("height")) if node.has_meta("height") else float(st.def.get("height", 0.5)))
			node.set_meta("level", st.level)
		var parts: Dictionary = node.get_meta("parts")
		if parts.has("head") and node.has_meta("aim"):
			var aim: Vector3 = node.get_meta("aim")
			var to := aim - st.pos
			var yaw := atan2(-to.x, -to.z)
			parts.head.rotation.y = lerp_angle(parts.head.rotation.y, yaw, minf(1.0, delta * 10.0))
		if parts.has("crystal"):
			parts.crystal.rotation.y += delta * 1.5
		if parts.has("flag"):
			parts.flag.rotation.y = sin(_time * 2.0 + st.id) * 0.25
		_disabled_visual(node, st)
		_range_visual(node, st)
	for id in _struct_nodes.keys():
		if not seen.has(id):
			var n: Node3D = _struct_nodes[id]
			fx.burst(n.position + Vector3(0, 1, 0), 2.0, Color(1, 0.85, 0.4, 0.6), 0.3)
			n.queue_free()
			_struct_nodes.erase(id)


func _disabled_visual(node: Node3D, st: Units.Structure) -> void:
	var ov: Node3D = (node.get_meta("ov_disabled") if node.has_meta("ov_disabled") else null)
	if st.disabled_t > 0.0 and ov == null:
		ov = Art.part(node, Art.torus(0.9, 1.2), Art.mat(Color("b05ad0"), 3.0, 1.0, false, true),
			Vector3(0, float(st.def.get("height", 1.0)) + 0.4, 0), Vector3.ZERO, Vector3.ONE, false)
		node.set_meta("ov_disabled", ov)
	if ov:
		ov.visible = st.disabled_t > 0.0
		ov.rotation.y = _time * 4.0


func _range_visual(node: Node3D, st: Units.Structure) -> void:
	var r := 0.0
	if st.kind == "tower":
		r = sim.tower_range(st)
	elif st.kind == "support":
		r = float(st.def.range) * (2.0 if sim.mods.has("war_banner") else 1.0) * (1.0 + 0.15 * (st.level - 1))
	if r <= 0.0:
		return
	var ring: MeshInstance3D = (node.get_meta("range_ring") if node.has_meta("range_ring") else null)
	var want := show_all_ranges or highlight_id == st.id
	if want and ring == null:
		ring = Art.ground_ring(node, 1.0, Color(1, 1, 1, 0.5) if st.kind == "tower" else Color(1, 0.85, 0.3, 0.5), 0.06)
		node.set_meta("range_ring", ring)
	if ring:
		ring.visible = want
		ring.scale = Vector3(r, 0.02, r)


func structure_node(id: int) -> Node3D:
	return _struct_nodes.get(id)


# ---------------------------------------------------------------- projectiles, zones, cache

func _sync_projectiles() -> void:
	var seen := {}
	for p: Units.Projectile in sim.projectiles:
		if not p.alive:
			continue
		seen[p.id] = true
		var node: Node3D = _proj_nodes.get(p.id)
		if node == null:
			var pool: Array = _proj_pool.get(p.style, [])
			if pool.is_empty():
				node = Models.projectile(p.style)
				add_child(node)
			else:
				node = pool.pop_back()
				node.visible = true
			node.set_meta("style", p.style)
			node.position = p.pos
			_proj_nodes[p.id] = node
		var prev := node.position
		node.position = p.pos
		var dir := p.pos - prev
		if dir.length() > 0.01:
			node.look_at(p.pos + dir, Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.RIGHT)
	for id in _proj_nodes.keys():
		if not seen.has(id):
			_release_projectile(id)


func _release_projectile(id: int) -> void:
	var node: Node3D = _proj_nodes[id]
	_proj_nodes.erase(id)
	node.visible = false
	_proj_pool.get_or_add(node.get_meta("style"), []).append(node)


func _sync_zones() -> void:
	var seen := {}
	for z: Units.Zone in sim.zones:
		seen[z.id] = true
		var node: Node3D = _zone_nodes.get(z.id)
		if node == null:
			node = Node3D.new()
			node.position = z.pos
			add_child(node)
			match z.kind:
				"fire":
					Art.ground_disc(node, z.radius, Color(1.0, 0.4, 0.1, 0.45))
					for i in 6:
						var a := i * TAU / 6.0
						Art.part(node, Art.cone(0.3, 0.9, 5), Art.mat(Art.PALETTE.fire, 4.0, 1.0, false, true),
							Vector3(cos(a), 0.45, sin(a)) * Vector3(z.radius * 0.6, 1, z.radius * 0.6), Vector3.ZERO, Vector3.ONE, false)
				"rain":
					Art.ground_ring(node, z.radius, Color(0.6, 1.0, 0.7, 0.8), 0.08)
			_zone_nodes[z.id] = node
		if z.kind == "fire":
			node.scale = Vector3.ONE * (0.95 + 0.08 * sin(_time * 14.0 + z.id))
	for id in _zone_nodes.keys():
		if not seen.has(id):
			_zone_nodes[id].queue_free()
			_zone_nodes.erase(id)


func _sync_cache() -> void:
	if sim.cache.is_empty():
		if _cache_node:
			_cache_node.visible = false
		return
	if _cache_node == null:
		_cache_node = Models.cache()
		add_child(_cache_node)
	_cache_node.visible = true
	_cache_node.position = sim.cache.pos
	_cache_node.rotation.y = _time


func _animate_core() -> void:
	if core_node == null:
		return
	var crystal: Node3D = core_node.get_node_or_null("crystal")
	if crystal:
		crystal.rotation.y = _time * 0.6
		crystal.position.y = 3.4 + sin(_time * 1.5) * 0.15
	var light: OmniLight3D = core_node.get_node_or_null("light")
	if light:
		var ratio := sim.core_hp / maxf(1.0, sim.core_max)
		light.light_color = Art.PALETTE.crystal.lerp(Color("ff4040"), 1.0 - ratio)
		light.light_energy = 1.5 + (1.0 - ratio) * (1.0 + sin(_time * 8.0))


# ---------------------------------------------------------------- events

func handle_event(e: Dictionary) -> void:
	match e.type:
		"hit":
			if e.crit:
				fx.number(e.pos, "%d!" % int(e.amount), Color("ffd84a"), 72)
				fx.sparks(e.pos + Vector3(0, 0.8, 0), Color("ffe08a"), 10, 6.0)
				Sfx.play_at("crit", e.pos, 0.05)
			else:
				fx.number(e.pos, str(int(round(e.amount))), _dtype_color(e.dtype), 44)
		"death":
			var c := Color("ff9a3a") if e.boss else Color(0.9, 0.85, 0.75)
			fx.burst(e.pos + Vector3(0, 0.6, 0), 1.6 if not e.boss else 6.0, Color(c, 0.6), 0.35)
			fx.sparks(e.pos + Vector3(0, 0.6, 0), Color("c8b8a8"), 8 if not e.boss else 40, 4.0)
			fx.number(e.pos + Vector3(0, 0.8, 0), "+%d" % int(e.gold), Art.PALETTE.gold, 40, 0.9)
			Sfx.play_at("death", e.pos, 0.04)
		"explosion":
			var col := _dtype_color(e.dtype)
			fx.burst(e.pos, float(e.radius), Color(col, 0.55), 0.35)
			fx.ring(e.pos, float(e.radius), Color(col, 0.9), 0.4)
			fx.sparks(e.pos + Vector3(0, 0.5, 0), col, 14, 7.0)
			Sfx.play_at("explosion" if e.fx == "cannon" else "hit", e.pos, 0.06)
		"fire":
			var node: Node3D = _struct_nodes.get(e.id)
			if node:
				node.set_meta("aim", e.target)
			match e.structure:
				"arrow":
					Sfx.play_at("arrow_tower", e.pos, 0.05)
				"cannon":
					Sfx.play_at("cannon", e.pos, 0.08)
					fx.burst(e.pos, 0.8, Color(1, 0.9, 0.7, 0.6), 0.2)
				"frost":
					Sfx.play_at("frost", e.pos, 0.08)
		"trap":
			var node: Node3D = _struct_nodes.get(e.id)
			if e.structure == "spikes":
				Sfx.play_at("spikes", e.pos, 0.05)
				if node:
					var spikes: Node3D = node.get_meta("parts").get("spikes")
					if spikes:
						var tw := create_tween()
						tw.tween_property(spikes, "position:y", 0.35, 0.05)
						tw.tween_property(spikes, "position:y", 0.0, 0.25)
			elif e.structure == "spring":
				Sfx.play_at("spring", e.pos, 0.05)
				fx.ring(e.pos, 2.5, Color(1, 0.6, 0.3, 0.8), 0.35)
				if node:
					var plate: Node3D = node.get_meta("parts").get("plate")
					if plate:
						var tw := create_tween()
						tw.tween_property(plate, "position:y", 1.0, 0.06)
						tw.tween_property(plate, "position:y", 0.25, 0.4)
		"launch":
			fx.sparks(e.pos, Color("d9b38c"), 6, 3.0)
		"arc":
			fx.arc(e.from + Vector3(0, 1, 0), e.to + Vector3(0, 1, 0))
		"zone":
			if e.kind == "fire":
				fx.burst(e.pos, float(e.radius), Color(1, 0.5, 0.1, 0.5), 0.3)
		"rain_tick":
			for i in 3:
				var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * float(e.radius) * 0.8
				fx.streak(e.pos + off + Vector3(0.6, 6, 0.3), e.pos + off, Color("e8ffd8"), 0.2)
			Sfx.play_at("arrow_tower", e.pos, 0.1, 1.4)
		"synergy":
			fx.number(e.pos + Vector3(0, 1.5, 0), tr(e.name), Color("c9a6ff"), 80, 1.1)
			fx.ring(e.pos, 3.0, Color("c9a6ff"), 0.5)
			Sfx.play_at("synergy", e.pos, 0.25)
		"stomp":
			fx.ring(e.pos, float(e.radius), Color("ff8c3a"), 0.7, 0.2)
			fx.burst(e.pos, float(e.radius) * 0.6, Color(0.6, 0.45, 0.3, 0.5), 0.5)
			Sfx.play_at("stomp", e.pos)
		"hex":
			fx.ring(e.pos, float(e.radius), Color("b05ad0"), 0.6, 0.15)
			Sfx.play_at("hex", e.pos, 0.2)
		"boss_phase":
			fx.column(e.pos, 3.5, 14.0, Color(1, 0.45, 0.15, 0.6), 1.0)
			Sfx.play("stomp")
		"summon":
			fx.ring(e.pos, 4.0, Color("ff8c3a"), 0.5)
		"leak":
			fx.burst(core_node.position + Vector3(0, 3, 0) if core_node else e.pos, 3.0, Color(1, 0.2, 0.2, 0.5), 0.4)
			Sfx.play("leak", 0.15)
		"built":
			Sfx.play_at("build", e.pos)
			fx.sparks(e.pos + Vector3(0, 0.5, 0), Color("e8d8b0"), 16, 4.0)
		"upgraded":
			Sfx.play_at("upgrade", e.pos)
			fx.column(e.pos, 1.4, 6.0, Color(1, 0.85, 0.3, 0.5), 0.6)
		"sold":
			Sfx.play_at("sell", e.pos)
			fx.number(e.pos + Vector3(0, 2, 0), "+%d" % int(e.gold), Art.PALETTE.gold, 56)
		"cache_spawned":
			fx.column(e.pos, 1.0, 10.0, Color(1, 0.85, 0.3, 0.6), 1.0)
		"cache_collected":
			fx.number(e.pos + Vector3(0, 1, 0), "+%d" % int(e.gold), Art.PALETTE.gold, 72)
			Sfx.play("gold")
		"hero_fire":
			Sfx.play_at("bow", e.pos, 0.03)
		"ability":
			if e.name == "rain":
				fx.ring(e.pos, 4.2, Color("aaffb8"), 0.5)
			else:
				fx.burst(e.pos + Vector3(0, 1, 0) + (e.dir as Vector3).normalized() * 2.5, 3.0, Color(0.8, 1.0, 0.85, 0.5), 0.3)
			Sfx.play_at("spring", e.pos, 0.0, 1.3)
		"dodge":
			Sfx.play("dodge")
		"level_up":
			Sfx.play("level_up")
		"hero_hit":
			Sfx.play("hurt", 0.2)


func _dtype_color(dtype: String) -> Color:
	match dtype:
		"fire":
			return Art.PALETTE.fire
		"ice":
			return Art.PALETTE.ice
		"lightning":
			return Art.PALETTE.lightning
	return Color(1, 1, 1)
