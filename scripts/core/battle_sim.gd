class_name BattleSim
extends RefCounted
## Real-time battle rules, independent of rendering. The 3D scene feeds it hero input
## and draws its state; tests and balance tools run it headless.
##
## Order of a tick: spawns -> enemies (status, movement, specials) -> structures ->
## projectiles -> zones -> hero -> cleanup/wave/defeat. Events describing what happened
## are queued in `events` for the presentation layer (VFX, sounds, numbers).

const HERO := -100
const GRID := 4.0
const FLY_HEIGHT := 3.6
const ATTACK_WINDUP := 0.4

var map: MapDef
var mods: RunMods
var balance: Dictionary
var rng := RandomNumberGenerator.new()
var unlocked: Dictionary = {}  # structure ids available this run

var enemies: Array = []
var structures: Array = []
var projectiles: Array = []
var zones: Array = []
var hero: Units.Hero
var cache: Dictionary = {}  # supply cache {pos: Vector3, gold: int} or empty

var gold: int = 0
var core_hp: float = 100.0
var core_max: float = 100.0
var depth: int = 0
## Scales gold from kills, wave clears and caches (the endless siege keeps income flat).
var income_mult: float = 1.0
## Extra enemy health (the endless siege grows it every round).
var enemy_hp_mult: float = 1.0
var time: float = 0.0
var next_id: int = 1
var spawn_queue: Array = []
var wave_time: float = 0.0
var wave_active: bool = false
var defeated: bool = false
var tower_shots: int = 0
var events: Array[Dictionary] = []
var stats: Dictionary = {"kills": 0, "gold_earned": 0, "leaks": 0, "damage": {}, "elite_kills": 0, "boss_kills": 0}

var _grid: Dictionary = {}


func setup(p_map: MapDef, p_mods: RunMods, p_gold: int, p_core_hp: float, p_core_max: float,
		hero_id: String, seed_value: int, p_unlocked: Array = []) -> void:
	map = p_map
	mods = p_mods
	balance = DataDB.balance()
	rng.seed = seed_value
	gold = p_gold
	core_max = p_core_max
	core_hp = minf(p_core_hp, core_max)
	for id in DataDB.structures():
		if DataDB.structure(id).get("unlocked", false) or p_unlocked.has(id):
			unlocked[id] = true
	hero = Units.Hero.new()
	hero.def = DataDB.hero(hero_id)
	hero.max_hp = float(hero.def.hp) + mods.stat("hero_max_hp_add")
	hero.hp = hero.max_hp
	hero.pos = map.to_3d(map.hero_spawn)


func set_mods(p_mods: RunMods) -> void:
	var old_max := hero.max_hp
	mods = p_mods
	hero.max_hp = float(hero.def.hp) + mods.stat("hero_max_hp_add") + (hero.level - 1) * float(hero.def.level_bonus.hp)
	hero.hp += maxf(0.0, hero.max_hp - old_max)


func _id() -> int:
	next_id += 1
	return next_id


func emit(e: Dictionary) -> void:
	events.append(e)


func pop_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


# ================================================================ structures

func structure_cost(type: String) -> int:
	var def := DataDB.structure(type)
	return int(round(float(def.get("cost", 0)) * maxf(0.3, 1.0 + mods.stat("cost_pct"))))


func _placed() -> Array:
	var out := []
	for st: Units.Structure in structures:
		out.append({"pos": st.pos2(), "def": st.def})
	return out


func can_build(type: String, p: Vector2) -> Dictionary:
	if not unlocked.has(type):
		return {"ok": false, "reason": "BUILD_ERR_LOCKED"}
	var def := DataDB.structure(type)
	var res := BuildRules.check(map, _placed(), def, BuildRules.snap(def, p))
	if res.ok and gold < structure_cost(type):
		return {"ok": false, "reason": "BUILD_ERR_GOLD"}
	return res


func build(type: String, p: Vector2) -> Units.Structure:
	var def := DataDB.structure(type)
	var snapped := BuildRules.snap(def, p)
	if not can_build(type, snapped).ok:
		return null
	var cost := structure_cost(type)
	gold -= cost
	var st := Units.Structure.new()
	st.id = _id()
	st.type = type
	st.def = def
	st.kind = def.kind
	st.invested = cost
	st.elevated = map.height_at(snapped) > 0.0
	st.pos = map.to_3d(snapped)
	structures.append(st)
	emit({"type": "built", "id": st.id, "structure": type, "pos": st.pos})
	return st


func upgrade_cost(st: Units.Structure) -> int:
	var costs: Array = balance.upgrade_level_cost
	if st.level > costs.size() or st.kind == "trap":
		return -1
	return int(round(float(st.def.cost) * float(costs[st.level - 1]) * maxf(0.3, 1.0 + mods.stat("cost_pct"))))


func upgrade(st: Units.Structure) -> bool:
	var c := upgrade_cost(st)
	if c < 0 or gold < c:
		return false
	gold -= c
	st.invested += c
	st.level += 1
	emit({"type": "upgraded", "id": st.id, "level": st.level, "pos": st.pos})
	return true


func sell_value(st: Units.Structure) -> int:
	return int(floor(st.invested * minf(1.0, float(balance.sell_refund) + mods.stat("refund_add"))))


func sell(st: Units.Structure) -> int:
	if not structures.has(st):
		return 0
	var v := sell_value(st)
	gold += v
	structures.erase(st)
	emit({"type": "sold", "id": st.id, "gold": v, "pos": st.pos})
	return v


func find_structure(id: int) -> Units.Structure:
	for st: Units.Structure in structures:
		if st.id == id:
			return st
	return null


## Snapshot used to carry defences between encounters / save files.
func structures_snapshot() -> Array:
	var out := []
	for st: Units.Structure in structures:
		out.append({"type": st.type, "pos": [st.pos.x, st.pos.z], "level": st.level, "invested": st.invested, "mode": st.target_mode})
	return out


func restore_structures(snapshot: Array) -> void:
	for s in snapshot:
		var def := DataDB.structure(s.type)
		if def.is_empty():
			continue
		var st := Units.Structure.new()
		st.id = _id()
		st.type = s.type
		st.def = def
		st.kind = def.kind
		st.level = int(s.get("level", 1))
		st.invested = int(s.get("invested", def.cost))
		st.target_mode = s.get("mode", "first")
		var p := Vector2(s.pos[0], s.pos[1])
		st.elevated = map.height_at(p) > 0.0
		st.pos = map.to_3d(p)
		structures.append(st)


# ---------------------------------------------------------------- tower stats

func _support_bonus(st: Units.Structure, key: String) -> float:
	var total := 0.0
	var war := mods.has("war_banner")
	for b: Units.Structure in structures:
		if b.kind != "support" or b.disabled_t > 0.0:
			continue
		var r := float(b.def.range) * (2.0 if war else 1.0) * (1.0 + 0.15 * (b.level - 1))
		if b.pos2().distance_to(st.pos2()) <= r:
			total += float(b.def.aura.get(key, 0.0)) * (1.0 + 0.5 * (b.level - 1))
	return total


func _formation_bonus(st: Units.Structure) -> float:
	var per := mods.flag("formation")
	if per <= 0.0:
		return 0.0
	var n := 0
	for o: Units.Structure in structures:
		if o != st and o.kind == "tower" and o.pos2().distance_to(st.pos2()) <= 7.0:
			n += 1
	return minf(per * n, 0.3)


func tower_damage(st: Units.Structure) -> float:
	var lvl: Dictionary = balance.upgrade_level_bonus
	var pct := mods.stat("tower_damage_pct") + mods.stat("%s_damage_pct" % st.type)
	pct += _support_bonus(st, "damage") + _formation_bonus(st)
	return float(st.def.damage) * (1.0 + float(lvl.damage) * (st.level - 1)) * (1.0 + pct)


func tower_range(st: Units.Structure) -> float:
	var lvl: Dictionary = balance.upgrade_level_bonus
	var r := float(st.def.range) * (1.0 + float(lvl.range) * (st.level - 1)) * (1.0 + mods.stat("tower_range_pct"))
	if st.elevated:
		r *= 1.2
	return r


func tower_rate(st: Units.Structure) -> float:
	var lvl: Dictionary = balance.upgrade_level_bonus
	var pct := mods.stat("tower_rate_pct") + _support_bonus(st, "rate")
	return float(st.def.rate) * (1.0 + float(lvl.rate) * (st.level - 1)) * (1.0 + pct)


func tower_crit(st: Units.Structure) -> float:
	var c := mods.stat("tower_crit")
	if mods.has("war_banner") and _support_bonus(st, "damage") > 0.0:
		c += 0.15
	return c


func crit_mult() -> float:
	return float(balance.crit_multiplier) + mods.stat("crit_mult_add")


# ================================================================ waves & spawning

func start_wave(entries: Array) -> void:
	spawn_queue = entries.duplicate()
	spawn_queue.sort_custom(func(a, b): return float(a.t) < float(b.t))
	wave_time = 0.0
	wave_active = true
	cache = {}
	emit({"type": "wave_start", "count": entries.size()})


func spawn_enemy(type: String, elite: bool = false, s0: float = 0.0, lateral: float = INF) -> Units.Enemy:
	var def := DataDB.enemy(type)
	if def.is_empty():
		return null
	var e := Units.Enemy.new()
	e.id = _id()
	e.type = type
	e.def = def
	e.boss = def.get("boss", false)
	e.flying = def.get("flying", false)
	e.max_hp = float(def.hp) * (1.0 + float(balance.get("enemy_hp_per_depth", 0.12)) * depth) * enemy_hp_mult
	e.armor = float(def.get("armor", 0))
	e.speed = float(def.speed) * (1.0 + mods.stat("enemy_speed_pct"))
	e.size = float(def.size)
	e.gold = int(def.gold)
	e.leak = int(def.leak)
	if elite:
		var el: Dictionary = balance.elite
		e.elite = true
		e.max_hp *= float(el.hp_mult)
		e.gold = int(e.gold * float(el.gold_mult))
		e.size *= float(el.scale)
		e.armor += 2.0
	e.hp = e.max_hp
	e.ability_t = float(def.get("hex", {}).get("interval", 6.0)) * rng.randf_range(0.5, 1.0)
	if e.boss:
		e.ability_t = float(def.phases[0].stomp_interval)
	if e.flying:
		e.fly_from = map.fly_spawns[rng.randi() % map.fly_spawns.size()] if not map.fly_spawns.is_empty() else map.path.points[0]
		e.s = 0.0
	else:
		e.s = s0
		e.lateral = lateral if lateral != INF else rng.randf_range(-1.0, 1.0) * (map.path_width * 0.5 - e.size - 0.2)
	_place_enemy(e)
	enemies.append(e)
	emit({"type": "spawn", "id": e.id, "enemy": type, "elite": elite})
	return e


func _place_enemy(e: Units.Enemy) -> void:
	if e.flying:
		var p := e.fly_from.lerp(map.core_pos, e.s)
		e.pos = Vector3(p.x, FLY_HEIGHT + sin(time * 3.0 + e.id) * 0.25, p.y)
	else:
		var p := map.path.sample(e.s)
		var tgt := map.path.tangent(e.s)
		var n := Vector2(-tgt.y, tgt.x)
		p += n * e.lateral
		var y := 0.0
		if e.launched_t > 0.0:
			var k := e.launched_t / 0.6
			y = 4.0 * 2.2 * k * (1.0 - k)
		e.pos = Vector3(p.x, y, p.y)


func progress(e: Units.Enemy) -> float:
	return e.s * map.path.length if e.flying else e.s


# ================================================================ tick

func step(dt: float) -> void:
	if defeated:
		return
	time += dt
	_spawn(dt)
	_rebuild_grid()
	_update_enemies(dt)
	_update_structures(dt)
	_update_projectiles(dt)
	_update_zones(dt)
	_update_hero(dt)
	_cleanup()


func _spawn(dt: float) -> void:
	if not wave_active:
		return
	wave_time += dt
	while not spawn_queue.is_empty() and float(spawn_queue[0].t) <= wave_time:
		var entry: Dictionary = spawn_queue.pop_front()
		spawn_enemy(entry.type, entry.get("elite", false))


func _rebuild_grid() -> void:
	_grid.clear()
	for e: Units.Enemy in enemies:
		if not e.alive:
			continue
		var key := Vector2i(floori(e.pos.x / GRID), floori(e.pos.z / GRID))
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(e)


## Enemies within `radius` (2D) of `p`. `air`/`ground` filter by movement type.
func enemies_near(p: Vector3, radius: float, air: bool = true, ground: bool = true) -> Array:
	var out := []
	var p2 := Vector2(p.x, p.z)
	var r := int(ceil(radius / GRID))
	var c := Vector2i(floori(p.x / GRID), floori(p.z / GRID))
	for gx in range(c.x - r, c.x + r + 1):
		for gz in range(c.y - r, c.y + r + 1):
			var cell: Array = _grid.get(Vector2i(gx, gz), [])
			for e: Units.Enemy in cell:
				if not e.alive or (e.flying and not air) or (not e.flying and not ground):
					continue
				if Vector2(e.pos.x, e.pos.z).distance_to(p2) <= radius + e.size:
					out.append(e)
	return out


# ---------------------------------------------------------------- enemies

func _update_enemies(dt: float) -> void:
	# Warden auras first (damage reduction for allies nearby).
	for e: Units.Enemy in enemies:
		e.shielded = 0.0
	for w: Units.Enemy in enemies:
		if not w.alive or not w.def.has("aura"):
			continue
		var aura: Dictionary = w.def.aura
		for o: Units.Enemy in enemies_near(w.pos, float(aura.radius)):
			if o != w:
				o.shielded = maxf(o.shielded, float(aura.reduction))
	for e: Units.Enemy in enemies:
		if not e.alive:
			continue
		_update_status(e, dt)
		if not e.alive:
			continue
		_move(e, dt)
		if e.def.has("hex"):
			_hexer(e, dt)
		if e.boss:
			_boss(e, dt)
		e.in_tar = 0.0


func _update_status(e: Units.Enemy, dt: float) -> void:
	e.contact_cd = maxf(0.0, e.contact_cd - dt)
	if e.attack_t > 0.0:
		_resolve_attack(e, dt)
	if e.chill_t > 0.0:
		e.chill_t -= dt
		e.chill_accum += dt
	else:
		e.chill_accum = 0.0
	e.frozen_t = maxf(0.0, e.frozen_t - dt)
	e.stun_t = maxf(0.0, e.stun_t - dt)
	e.oiled_t = maxf(0.0, e.oiled_t - dt)
	if e.burn_t > 0.0:
		e.burn_t -= dt
		damage_enemy(e, e.burn_dps * dt, "fire", e.last_hit_by, 0.0, {"tick": true})


func _move(e: Units.Enemy, dt: float) -> void:
	if e.launched_t > 0.0:
		e.launched_t -= dt
		if e.launched_t <= 0.0:
			e.launched_t = 0.0
			_on_land(e)
		_place_enemy(e)
		return
	var spd := e.speed
	if e.boss:
		spd *= float(_boss_phase_def(e).get("speed_mult", 1.0))
	if e.frozen_t > 0.0 or e.stun_t > 0.0:
		spd = 0.0
	elif e.chill_t > 0.0:
		spd *= 1.0 - e.chill_slow
	if e.in_tar > 0.0:
		spd *= 1.0 - e.in_tar
	if e.flying:
		var dist := maxf(1.0, e.fly_from.distance_to(map.core_pos))
		e.s += spd * dt / dist
		if e.s >= 1.0:
			_leak(e)
			return
	else:
		e.s += spd * dt
		if e.s >= map.path.length - map.core_radius * 0.6:
			_leak(e)
			return
	_place_enemy(e)


func _leak(e: Units.Enemy) -> void:
	e.alive = false
	core_hp -= e.leak
	stats.leaks += 1
	emit({"type": "leak", "id": e.id, "damage": e.leak, "pos": e.pos})
	if core_hp <= 0.0 and not defeated:
		core_hp = 0.0
		defeated = true
		emit({"type": "defeat"})


func _hexer(e: Units.Enemy, dt: float) -> void:
	e.ability_t -= dt
	if e.ability_t > 0.0:
		return
	var hex: Dictionary = e.def.hex
	e.ability_t = float(hex.interval)
	var hit := 0
	for st: Units.Structure in structures:
		if Vector2(e.pos.x, e.pos.z).distance_to(st.pos2()) <= float(hex.radius):
			st.disabled_t = maxf(st.disabled_t, float(hex.duration))
			hit += 1
	emit({"type": "hex", "pos": e.pos, "radius": float(hex.radius), "count": hit})


func _boss_phase_def(e: Units.Enemy) -> Dictionary:
	var phases: Array = e.def.phases
	return phases[mini(e.phase, phases.size() - 1)]


func _boss(e: Units.Enemy, dt: float) -> void:
	var phases: Array = e.def.phases
	var ratio := e.hp / e.max_hp
	while e.phase < phases.size() - 1 and ratio <= float(phases[e.phase].until):
		e.phase += 1
		var ph: Dictionary = phases[e.phase]
		e.armor += float(ph.get("armor_add", 0.0))
		e.ability_t = minf(e.ability_t, 1.5)
		e.summon_t = 1.0
		emit({"type": "boss_phase", "phase": e.phase, "pos": e.pos})
	var ph := _boss_phase_def(e)
	e.ability_t -= dt
	if e.ability_t <= 0.0:
		e.ability_t = float(ph.stomp_interval)
		var stomp: Dictionary = e.def.stomp
		var p2 := Vector2(e.pos.x, e.pos.z)
		for st: Units.Structure in structures:
			if p2.distance_to(st.pos2()) <= float(stomp.radius):
				st.disabled_t = maxf(st.disabled_t, float(stomp.disable))
		if hero.alive and Vector2(hero.pos.x, hero.pos.z).distance_to(p2) <= float(stomp.radius):
			damage_hero(float(stomp.hero_damage))
		emit({"type": "stomp", "pos": e.pos, "radius": float(stomp.radius)})
	if ph.has("summon"):
		e.summon_t -= dt
		if e.summon_t <= 0.0:
			var sm: Dictionary = ph.summon
			e.summon_t = float(sm.interval)
			for i in int(sm.count):
				spawn_enemy(sm.type, false, maxf(0.0, e.s - 1.5 - i * 0.6))
			emit({"type": "summon", "pos": e.pos, "count": int(sm.count)})


# ---------------------------------------------------------------- damage

## Applies one hit. opts: {"tick": bool (no crit/procs/events), "no_proc": bool}.
## Returns the damage dealt.
func damage_enemy(e: Units.Enemy, amount: float, dtype: String, source: int, crit_chance: float,
		opts: Dictionary = {}) -> float:
	if not e.alive or amount <= 0.0:
		return 0.0
	var crit := false
	if not opts.get("tick", false) and crit_chance > 0.0 and rng.randf() < crit_chance:
		crit = true
		amount *= crit_mult()
	match dtype:
		"physical":
			amount = maxf(amount * 0.25, amount - e.armor)
		"fire":
			if e.oiled_t > 0.0:
				amount *= 2.0 if mods.has("oil_slick") else 1.5
			amount *= 1.0 + (mods.stat("burn_damage_pct") if opts.get("tick", false) else 0.0)
		"lightning":
			if e.is_chilled():
				amount *= 1.5 + mods.stat("shock_bonus_pct")
	amount *= 1.0 - e.shielded
	e.hp -= amount
	e.last_hit_by = source
	var key := "hero" if source == HERO else _source_type(source)
	stats.damage[key] = float(stats.damage.get(key, 0.0)) + amount
	var st := find_structure(source) if source >= 0 else null
	if st:
		st.damage_done += amount
	if not opts.get("tick", false):
		emit({"type": "hit", "id": e.id, "pos": e.pos, "amount": amount, "crit": crit, "dtype": dtype, "hero": source == HERO})
	if crit and not opts.get("no_proc", false) and mods.flag("crit_explosion") > 0.0:
		aoe(e.pos, 2.6, amount * mods.flag("crit_explosion"), "fire", source, 0.0, {"no_proc": true, "fx": "crit_burst"})
		emit({"type": "synergy", "name": "SYN_FX_CRIT_BURST", "pos": e.pos})
	if e.hp <= 0.0:
		_kill(e, source)
	return amount if not crit else -amount  # negative signals a crit to callers


func _source_type(source: int) -> String:
	var st := find_structure(source)
	return st.type if st else "other"


func _kill(e: Units.Enemy, source: int) -> void:
	if not e.alive:
		return
	e.alive = false
	var g := int(round(e.gold * maxf(0.0, 1.0 + mods.stat("gold_kill_pct")) * income_mult))
	gold += g
	stats.gold_earned += g
	stats.kills += 1
	if e.elite:
		stats.elite_kills += 1
	if e.boss:
		stats.boss_kills += 1
	var st := find_structure(source) if source >= 0 else null
	if st:
		st.kills += 1
	emit({"type": "death", "id": e.id, "enemy": e.type, "pos": e.pos, "gold": g, "elite": e.elite, "boss": e.boss})
	_gain_xp(float(e.gold) * 2.0)
	if mods.flag("shatter") > 0.0 and e.is_chilled():
		emit({"type": "synergy", "name": "SYN_FX_SHATTER", "pos": e.pos})
		aoe(e.pos, 3.2, mods.flag("shatter") * (1.0 + 0.1 * depth), "ice", source, 0.0, {"no_proc": true, "fx": "shatter"})
	if mods.flag("leech") > 0.0 and e.has_element_status() and hero.alive:
		hero.hp = minf(hero.max_hp, hero.hp + mods.flag("leech"))
	if e.def.has("split") and not e.flying:
		var sp: Dictionary = e.def.split
		for i in int(sp.count):
			var child := spawn_enemy(sp.into, false, maxf(0.0, e.s - 0.4 * i), clampf(e.lateral + (i - 0.5) * 1.2, -2.0, 2.0))
			if child:
				child.pos = e.pos


func aoe(center: Vector3, radius: float, amount: float, dtype: String, source: int, crit_chance: float,
		opts: Dictionary = {}) -> int:
	var hit := 0
	var air: bool = opts.get("air", true)
	var ground: bool = opts.get("ground", true)
	for e: Units.Enemy in enemies_near(center, radius, air, ground):
		damage_enemy(e, amount, dtype, source, crit_chance, opts)
		if dtype == "fire" and opts.get("ignite", false):
			_ignite(e, source)
		hit += 1
	emit({"type": "explosion", "pos": center, "radius": radius, "dtype": dtype, "fx": opts.get("fx", "")})
	return hit


func _ignite(e: Units.Enemy, source: int) -> void:
	var dur := 2.5 * (2.0 if (mods.has("oil_slick") and e.oiled_t > 0.0) else 1.0)
	e.burn_t = maxf(e.burn_t, dur)
	e.burn_dps = maxf(e.burn_dps, 6.0 * (1.0 + 0.1 * depth))
	e.last_hit_by = source


func _chill(e: Units.Enemy, chill: Dictionary) -> void:
	var slow := minf(0.8, float(chill.slow) + mods.stat("chill_slow_add"))
	var dur := float(chill.duration) + mods.stat("chill_duration_add")
	if e.boss:
		slow *= 0.5
	e.chill_slow = maxf(e.chill_slow if e.chill_t > 0.0 else 0.0, slow)
	e.chill_t = maxf(e.chill_t, dur)
	var stun := mods.flag("deep_freeze_stun")
	if stun > 0.0 and e.chill_accum >= 2.5 and not e.boss:
		e.frozen_t = stun
		e.chill_accum = 0.0
		emit({"type": "synergy", "name": "SYN_FX_FREEZE", "pos": e.pos})


# ---------------------------------------------------------------- structures

func _update_structures(dt: float) -> void:
	for st: Units.Structure in structures:
		st.disabled_t = maxf(0.0, st.disabled_t - dt)
		st.chain_cd = maxf(0.0, st.chain_cd - dt)
		st.cooldown -= dt
		if st.disabled_t > 0.0:
			continue
		match st.kind:
			"tower":
				if st.cooldown <= 0.0:
					var target := _pick_target(st)
					if target:
						_fire(st, target)
						st.cooldown = 1.0 / tower_rate(st)
					else:
						st.cooldown = 0.0
			"trap":
				_update_trap(st)


func _pick_target(st: Units.Structure) -> Units.Enemy:
	var r := tower_range(st)
	var air: bool = st.def.get("hits_air", true)
	var best: Units.Enemy = null
	var best_score := -INF
	var origin := st.pos2()
	for e: Units.Enemy in enemies_near(st.pos, r, air, true):
		if map.blocks_los(origin, Vector2(e.pos.x, e.pos.z)):
			continue
		var score := 0.0
		match st.target_mode:
			"strong":
				score = e.hp
			"close":
				score = -origin.distance_to(Vector2(e.pos.x, e.pos.z))
			_:
				score = progress(e)
		if score > best_score:
			best_score = score
			best = e
	return best


func _fire(st: Units.Structure, target: Units.Enemy) -> void:
	st.shots += 1
	tower_shots += 1
	var proj: Dictionary = st.def.get("projectile", {})
	var p := Units.Projectile.new()
	p.id = _id()
	p.style = proj.get("style", "arrow")
	p.source = st.id
	p.speed = float(proj.get("speed", 30.0))
	p.damage = tower_damage(st)
	p.dtype = st.def.get("dtype", "physical")
	p.crit_chance = tower_crit(st)
	p.hits_air = st.def.get("hits_air", true)
	p.pos = st.pos + Vector3(0, float(st.def.get("height", 3.0)), 0)
	p.target_id = target.id
	match p.style:
		"ballistic":
			var flight := Vector2(p.pos.x, p.pos.z).distance_to(Vector2(target.pos.x, target.pos.z)) / p.speed + 0.25
			p.target_pos = _predict(target, flight)
			p.start = p.pos
			p.duration = flight
			p.splash = float(st.def.get("splash", 2.0)) * (1.0 + mods.stat("cannon_radius_pct"))
			p.hits_air = false
		"orb":
			p.chill = st.def.get("chill", {})
		_:
			var lead := p.pos.distance_to(target.pos) / p.speed
			var aim := _predict(target, lead) + Vector3(0, 0.6, 0)
			p.dir = (aim - p.pos).normalized()
			p.pierce = int(mods.flag("pierce"))
			p.ttl = (tower_range(st) + 4.0) / p.speed
	projectiles.append(p)
	emit({"type": "fire", "id": st.id, "structure": st.type, "pos": p.pos, "target": target.pos})
	var every := int(mods.flag("overcharge"))
	if every > 0 and tower_shots % every == 0:
		emit({"type": "synergy", "name": "SYN_FX_OVERCHARGE", "pos": target.pos})
		aoe(target.pos, 4.0, 28.0 * (1.0 + 0.15 * depth), "lightning", st.id, 0.0, {"no_proc": true, "fx": "nova"})


func _predict(e: Units.Enemy, t: float) -> Vector3:
	if e.flying or e.frozen_t > 0.0 or e.stun_t > 0.0 or e.launched_t > 0.0:
		return e.pos
	var spd := e.speed * ((1.0 - e.chill_slow) if e.chill_t > 0.0 else 1.0)
	var p := map.path.sample(e.s + spd * t)
	return Vector3(p.x, 0.0, p.y)


func _on_trap(st: Units.Structure, e: Units.Enemy) -> bool:
	if e.flying and not mods.has("trap_air"):
		return false
	if e.launched_t > 0.0:
		return false
	var half := float(st.def.size) * 0.5 + e.size * 0.5
	return absf(e.pos.x - st.pos.x) <= half and absf(e.pos.z - st.pos.z) <= half


func _trap_cooldown(st: Units.Structure) -> float:
	return float(st.def.cooldown) * maxf(0.2, 1.0 + mods.stat("trap_cooldown_pct"))


func _update_trap(st: Units.Structure) -> void:
	var near := enemies_near(st.pos, float(st.def.size), mods.has("trap_air"), true)
	if st.type == "tar":
		for e: Units.Enemy in near:
			if _on_trap(st, e):
				e.in_tar = float(st.def.slow)
				e.oiled_t = maxf(e.oiled_t, float(st.def.oil_duration))
		return
	if st.cooldown > 0.0:
		return
	var victims := []
	for e: Units.Enemy in near:
		if _on_trap(st, e):
			victims.append(e)
	if victims.is_empty():
		return
	_trigger_trap(st, victims)
	if mods.flag("chain_traps") > 0.0 and st.chain_cd <= 0.0:
		var chained := 0
		for o: Units.Structure in structures:
			if o == st or o.kind != "trap" or o.type == "tar" or o.disabled_t > 0.0:
				continue
			if o.pos2().distance_to(st.pos2()) <= mods.flag("chain_traps") and o.chain_cd <= 0.0:
				o.chain_cd = 2.5
				var ov := []
				for e: Units.Enemy in enemies_near(o.pos, float(o.def.size), mods.has("trap_air"), true):
					if _on_trap(o, e):
						ov.append(e)
				_trigger_trap(o, ov)
				chained += 1
		st.chain_cd = 2.5
		if chained > 0:
			emit({"type": "synergy", "name": "SYN_FX_CHAIN", "pos": st.pos})


func _trigger_trap(st: Units.Structure, victims: Array) -> void:
	st.cooldown = _trap_cooldown(st)
	st.shots += 1
	match st.type:
		"spikes":
			var dmg := _spike_damage(st)
			for e: Units.Enemy in victims:
				damage_enemy(e, dmg, "physical", st.id, 0.0)
		"spring":
			var n := 0
			for e: Units.Enemy in victims:
				if n >= int(st.def.get("max_targets", 6)) or e.boss:
					continue
				launch(e, float(st.def.push), st.id)
				n += 1
	emit({"type": "trap", "id": st.id, "structure": st.type, "pos": st.pos})


func _spike_damage(st: Units.Structure) -> float:
	return float(st.def.damage) * (1.0 + mods.stat("spikes_damage_pct")) * (1.0 + 0.1 * depth)


## Knocks a ground enemy back along the path and throws it in the air.
func launch(e: Units.Enemy, push: float, source: int) -> void:
	if e.flying or e.boss:
		return
	e.s = maxf(0.0, e.s - push)
	e.launched_t = 0.6
	e.last_hit_by = source
	emit({"type": "launch", "id": e.id, "pos": e.pos})


func _on_land(e: Units.Enemy) -> void:
	_place_enemy(e)
	for st: Units.Structure in structures:
		if st.type != "spikes" or st.disabled_t > 0.0 or not _on_trap(st, e):
			continue
		var bonus := 1.0 + mods.flag("spring_spikes") * 2.0
		damage_enemy(e, _spike_damage(st) * 2.0 * bonus, "physical", st.id, 0.0)
		if mods.flag("spring_spikes") > 0.0:
			emit({"type": "synergy", "name": "SYN_FX_IMPALE", "pos": e.pos})
		break


# ---------------------------------------------------------------- projectiles

func _find_enemy(id: int) -> Units.Enemy:
	for e: Units.Enemy in enemies:
		if e.id == id and e.alive:
			return e
	return null


func _update_projectiles(dt: float) -> void:
	for p: Units.Projectile in projectiles:
		if not p.alive:
			continue
		match p.style:
			"ballistic":
				p.t += dt
				var k := clampf(p.t / p.duration, 0.0, 1.0)
				var flat := p.start.lerp(p.target_pos, k)
				p.pos = flat + Vector3(0, 5.0 * 4.0 * k * (1.0 - k), 0)
				if k >= 1.0:
					p.alive = false
					aoe(p.target_pos, p.splash, p.damage, p.dtype, p.source, p.crit_chance, {"air": false, "fx": "cannon"})
					var fire := mods.flag("fire_ground")
					if fire > 0.0:
						add_zone("fire", p.target_pos, p.splash * 0.8, 6.0 * (1.0 + 0.1 * depth), fire, p.source)
			"orb":
				var t := _find_enemy(p.target_id)
				if t:
					p.target_pos = t.pos + Vector3(0, 0.5, 0)
				var to := p.target_pos - p.pos
				var stepd := p.speed * dt
				if to.length() <= stepd + 0.3:
					p.alive = false
					if t:
						_orb_hit(p, t)
				else:
					p.pos += to.normalized() * stepd
			_:
				_move_linear(p, dt)


func _orb_hit(p: Units.Projectile, t: Units.Enemy) -> void:
	damage_enemy(t, p.damage, p.dtype, p.source, p.crit_chance)
	if not p.chill.is_empty():
		_chill(t, p.chill)
	var arc := mods.flag("conductive")
	if arc > 0.0:
		var n := 0
		for o: Units.Enemy in enemies_near(t.pos, 5.0):
			if o == t or n >= 2:
				continue
			damage_enemy(o, arc * (1.0 + 0.1 * depth), "lightning", p.source, 0.0, {"no_proc": true})
			emit({"type": "arc", "from": t.pos, "to": o.pos})
			n += 1
		if n > 0 and t.is_chilled():
			emit({"type": "synergy", "name": "SYN_FX_CONDUCT", "pos": t.pos})


func _move_linear(p: Units.Projectile, dt: float) -> void:
	var from := p.pos
	var travel := p.speed * dt
	p.pos += p.dir * travel
	p.ttl -= dt
	if p.ttl <= 0.0 or p.pos.y < -0.5:
		p.alive = false
		return
	var mid := from.lerp(p.pos, 0.5)
	for e: Units.Enemy in enemies_near(mid, travel * 0.5 + 0.8, p.hits_air, p.hits_ground):
		if p.hit_ids.has(e.id):
			continue
		var q := Geometry3D.get_closest_point_to_segment(e.pos + Vector3(0, e.size, 0), from, p.pos)
		if q.distance_to(e.pos + Vector3(0, e.size, 0)) > e.size + 0.45:
			continue
		p.hit_ids.append(e.id)
		var dealt := damage_enemy(e, p.damage, p.dtype, p.source, p.crit_chance)
		if p.ignite > 0.0 and e.alive and rng.randf() < p.ignite:
			_ignite(e, p.source)
		if dealt < 0.0 and p.bounces < int(mods.flag("ricochet")):
			_ricochet(p, e)
		if p.pierce > 0:
			p.pierce -= 1
		else:
			p.alive = false
			return


func _ricochet(p: Units.Projectile, from_e: Units.Enemy) -> void:
	var best: Units.Enemy = null
	var best_d := INF
	for o: Units.Enemy in enemies_near(from_e.pos, 9.0, true, true):
		if o == from_e or p.hit_ids.has(o.id):
			continue
		var d := o.pos.distance_to(from_e.pos)
		if d < best_d:
			best_d = d
			best = o
	if best == null:
		return
	var b := Units.Projectile.new()
	b.id = _id()
	b.style = "arrow"
	b.source = p.source
	b.speed = p.speed
	b.damage = p.damage * 0.75
	b.dtype = p.dtype
	b.crit_chance = p.crit_chance
	b.bounces = p.bounces + 1
	b.hit_ids = p.hit_ids.duplicate()
	b.pos = from_e.pos + Vector3(0, from_e.size, 0)
	b.dir = (best.pos + Vector3(0, best.size, 0) - b.pos).normalized()
	b.ttl = 1.0
	projectiles.append(b)
	emit({"type": "synergy", "name": "SYN_FX_RICOCHET", "pos": from_e.pos})


# ---------------------------------------------------------------- zones

func add_zone(kind: String, pos: Vector3, radius: float, dps: float, ttl: float, source: int, hits: int = 0) -> Units.Zone:
	var z := Units.Zone.new()
	z.id = _id()
	z.kind = kind
	z.pos = pos
	z.radius = radius
	z.dps = dps
	z.ttl = ttl
	z.source = source
	z.hits_left = hits
	zones.append(z)
	emit({"type": "zone", "id": z.id, "kind": kind, "pos": pos, "radius": radius, "ttl": ttl})
	return z


func _update_zones(dt: float) -> void:
	for z: Units.Zone in zones:
		z.ttl -= dt
		z.tick -= dt
		if z.tick > 0.0:
			continue
		match z.kind:
			"fire":
				z.tick = 0.5
				for e: Units.Enemy in enemies_near(z.pos, z.radius, false, true):
					damage_enemy(e, z.dps * 0.5, "fire", z.source, 0.0, {"tick": true})
					_ignite(e, z.source)
			"rain":
				z.tick = 0.25
				if z.hits_left > 0:
					z.hits_left -= 1
					var meteor := mods.has("meteor")
					for e: Units.Enemy in enemies_near(z.pos, z.radius):
						damage_enemy(e, z.dps, "fire" if meteor else "physical", HERO, _hero_crit())
						if meteor:
							_ignite(e, HERO)
					emit({"type": "rain_tick", "pos": z.pos, "radius": z.radius})
	zones = zones.filter(func(z): return z.ttl > 0.0)


# ================================================================ hero

func hero_damage() -> float:
	var lvl := float(hero.def.level_bonus.damage) * (hero.level - 1)
	return float(hero.def.attack.damage) * (1.0 + mods.stat("hero_damage_pct") + lvl)


func _hero_crit() -> float:
	return float(hero.def.attack.get("crit", 0.0)) + mods.stat("hero_crit")


func _cd(base: float) -> float:
	return base * maxf(0.3, 1.0 + mods.stat("ability_cooldown_pct"))


func set_hero_position(p: Vector3) -> void:
	hero.pos = p


func hero_attack(origin: Vector3, dir: Vector3) -> bool:
	if not hero.alive or hero.attack_cd > 0.0:
		return false
	var a: Dictionary = hero.def.attack
	hero.attack_cd = float(a.interval)
	if a.get("melee", false):
		_hero_swing(origin, dir, a)
		return true
	var p := Units.Projectile.new()
	p.id = _id()
	p.style = a.get("style", "hero_arrow")
	p.source = HERO
	p.speed = float(a.speed)
	p.damage = hero_damage()
	p.dtype = a.get("dtype", "physical")
	p.ignite = float(a.get("ignite", 0.0))
	p.crit_chance = _hero_crit()
	p.pos = origin
	p.dir = dir.normalized()
	p.pierce = int(mods.flag("pierce"))
	p.ttl = float(a.range) / p.speed
	projectiles.append(p)
	emit({"type": "hero_fire", "pos": origin})
	return true


## Melee arc in front of the hero; hits every ground enemy inside it.
func _hero_swing(origin: Vector3, dir: Vector3, a: Dictionary) -> void:
	var f2 := Vector2(dir.x, dir.z).normalized()
	var o2 := Vector2(origin.x, origin.z)
	var half := deg_to_rad(float(a.angle) * 0.5)
	var hits := 0
	for e: Units.Enemy in enemies_near(origin, float(a.range), false, true):
		var to := Vector2(e.pos.x, e.pos.z) - o2
		if to.length() > e.size + 0.6 and absf(f2.angle_to(to)) > half:
			continue
		damage_enemy(e, hero_damage(), "physical", HERO, _hero_crit())
		hits += 1
	emit({"type": "hero_swing", "pos": origin, "dir": dir, "hits": hits})


## Ability ids of the current hero, e.g. ["rain", "blast"] or ["slam", "charge"].
func ability_id(slot: int) -> String:
	var list: Array = hero.def.get("abilities", ["rain", "blast"])
	return list[slot]


func ability_cooldown(slot: int) -> float:
	return _cd(float(hero.def[ability_id(slot)].cooldown))


func hero_rain(point: Vector3) -> bool:
	if not hero.alive or hero.rain_cd > 0.0 or not hero.def.has("rain"):
		return false
	var r: Dictionary = hero.def.rain
	hero.rain_cd = _cd(float(r.cooldown))
	var dmg := float(r.damage) * (1.0 + mods.stat("hero_damage_pct") + float(hero.def.level_bonus.damage) * (hero.level - 1))
	add_zone("rain", point, float(r.radius), dmg, float(r.duration) + 0.1, HERO, int(r.hits))
	emit({"type": "ability", "name": "rain", "pos": point})
	return true


func hero_blast(origin: Vector3, forward: Vector3) -> bool:
	if not hero.alive or hero.blast_cd > 0.0 or not hero.def.has("blast"):
		return false
	var b: Dictionary = hero.def.blast
	hero.blast_cd = _cd(float(b.cooldown))
	var f2 := Vector2(forward.x, forward.z).normalized()
	var o2 := Vector2(origin.x, origin.z)
	var half := deg_to_rad(float(b.angle) * 0.5)
	var dmg := float(b.damage) * (1.0 + mods.stat("hero_damage_pct"))
	for e: Units.Enemy in enemies_near(origin, float(b.range), false, true):
		var to := Vector2(e.pos.x, e.pos.z) - o2
		if to.length() > 0.1 and absf(f2.angle_to(to)) > half:
			continue
		damage_enemy(e, dmg, "physical", HERO, _hero_crit())
		if e.alive:
			launch(e, float(b.push), HERO)
	emit({"type": "ability", "name": "blast", "pos": origin, "dir": forward})
	return true


func _hero_scale() -> float:
	return 1.0 + mods.stat("hero_damage_pct") + float(hero.def.level_bonus.damage) * (hero.level - 1)


## Mage Q: frost nova at the crosshair. Chills everything inside (air too) and
## freezes non-boss enemies briefly, so ice synergies (shatter, deep freeze) apply.
func hero_nova(point: Vector3) -> bool:
	if not hero.alive or hero.rain_cd > 0.0 or not hero.def.has("nova"):
		return false
	var n: Dictionary = hero.def.nova
	hero.rain_cd = _cd(float(n.cooldown))
	for e: Units.Enemy in enemies_near(point, float(n.radius)):
		damage_enemy(e, float(n.damage) * _hero_scale(), "ice", HERO, _hero_crit())
		if not e.alive:
			continue
		_chill(e, {"slow": float(n.slow), "duration": float(n.chill)})
		if not e.boss:
			e.frozen_t = maxf(e.frozen_t, float(n.freeze))
	emit({"type": "ability", "name": "nova", "pos": point, "radius": float(n.radius)})
	return true


## Mage E: chain lightning from the hero to the enemy nearest `aim`, then jumping to
## the closest unhit enemy each time. Lightning already deals bonus damage to chilled.
func hero_chain(origin: Vector3, aim: Vector3) -> bool:
	if not hero.alive or hero.blast_cd > 0.0 or not hero.def.has("chain"):
		return false
	var c: Dictionary = hero.def.chain
	var first: Units.Enemy = null
	var best := INF
	for e: Units.Enemy in enemies_near(origin, float(c.range)):
		var d := Vector2(e.pos.x, e.pos.z).distance_to(Vector2(aim.x, aim.z))
		if d < best:
			best = d
			first = e
	if first == null:
		return false
	hero.blast_cd = _cd(float(c.cooldown))
	var dmg := float(c.damage) * _hero_scale()
	var hit: Array[int] = []
	var from := origin
	var cur := first
	while cur != null and hit.size() < int(c.targets):
		hit.append(cur.id)
		emit({"type": "arc", "from": from, "to": cur.pos + Vector3(0, cur.size, 0)})
		from = cur.pos + Vector3(0, cur.size, 0)
		var at := cur.pos
		damage_enemy(cur, dmg, "lightning", HERO, _hero_crit())
		dmg *= float(c.falloff)
		var nxt: Units.Enemy = null
		var nd := INF
		for o: Units.Enemy in enemies_near(at, float(c.bounce_range)):
			if hit.has(o.id) or not o.alive:
				continue
			var d := o.pos.distance_to(at)
			if d < nd:
				nd = d
				nxt = o
		cur = nxt
	emit({"type": "ability", "name": "chain", "pos": origin})
	return true


## Warrior Q: ground slam around the hero, damages and stuns (air included).
func hero_slam() -> bool:
	if not hero.alive or hero.rain_cd > 0.0 or not hero.def.has("slam"):
		return false
	var s: Dictionary = hero.def.slam
	hero.rain_cd = _cd(float(s.cooldown))
	var dmg := float(s.damage) * (1.0 + mods.stat("hero_damage_pct") + float(hero.def.level_bonus.damage) * (hero.level - 1))
	for e: Units.Enemy in enemies_near(hero.pos, float(s.radius)):
		damage_enemy(e, dmg, "physical", HERO, _hero_crit())
		if e.alive and not e.boss:
			e.stun_t = maxf(e.stun_t, float(s.stun))
	emit({"type": "ability", "name": "slam", "pos": hero.pos, "radius": float(s.radius)})
	return true


## Warrior E: shield charge. The controller moves the hero; here every ground enemy in
## the lane ahead is hit and knocked back down the road. Invulnerable while charging.
func hero_charge(forward: Vector3) -> bool:
	if not hero.alive or hero.blast_cd > 0.0 or not hero.def.has("charge"):
		return false
	var c: Dictionary = hero.def.charge
	hero.blast_cd = _cd(float(c.cooldown))
	hero.invuln_t = maxf(hero.invuln_t, float(c.duration) + 0.1)
	var f2 := Vector2(forward.x, forward.z).normalized()
	var o2 := Vector2(hero.pos.x, hero.pos.z)
	var dist := float(c.distance)
	var dmg := float(c.damage) * (1.0 + mods.stat("hero_damage_pct"))
	for e: Units.Enemy in enemies_near(hero.pos + Vector3(f2.x, 0, f2.y) * dist * 0.5, dist * 0.5 + float(c.width), false, true):
		var to := Vector2(e.pos.x, e.pos.z) - o2
		var along := to.dot(f2)
		if along < -0.5 or along > dist + 0.5 or absf(to.cross(f2)) > float(c.width) * 0.5 + e.size:
			continue
		damage_enemy(e, dmg, "physical", HERO, _hero_crit())
		if e.alive:
			launch(e, float(c.push), HERO)
	emit({"type": "ability", "name": "charge", "pos": hero.pos, "dir": forward})
	return true


func hero_dodge() -> bool:
	if not hero.alive or hero.dodge_cd > 0.0:
		return false
	var d: Dictionary = hero.def.dodge
	hero.dodge_cd = float(d.cooldown)
	hero.invuln_t = float(d.duration) + 0.1
	emit({"type": "dodge", "pos": hero.pos})
	return true


func hero_interact() -> bool:
	if cache.is_empty() or not hero.alive:
		return false
	if hero.pos.distance_to(cache.pos) > 3.0:
		return false
	gold += int(cache.gold)
	stats.gold_earned += int(cache.gold)
	emit({"type": "cache_collected", "pos": cache.pos, "gold": int(cache.gold)})
	cache = {}
	return true


func damage_hero(amount: float) -> void:
	if not hero.alive or hero.invuln_t > 0.0:
		return
	hero.hp -= amount
	hero.regen_delay = 4.0
	emit({"type": "hero_hit", "amount": amount})
	if hero.hp <= 0.0:
		hero.hp = 0.0
		hero.alive = false
		hero.respawn_t = float(balance.hero_respawn)
		emit({"type": "hero_down"})


func _gain_xp(amount: float) -> void:
	if not hero.alive:
		amount *= 0.5
	hero.xp += amount
	var curve: Array = hero.def.xp_curve
	while hero.level - 1 < curve.size() and hero.xp >= float(curve[hero.level - 1]):
		hero.level += 1
		hero.max_hp += float(hero.def.level_bonus.hp)
		hero.hp = minf(hero.max_hp, hero.hp + float(hero.def.level_bonus.hp) + hero.max_hp * 0.25)
		emit({"type": "level_up", "level": hero.level})


func xp_to_next() -> float:
	var curve: Array = hero.def.xp_curve
	if hero.level - 1 >= curve.size():
		return -1.0
	return float(curve[hero.level - 1])


func _update_hero(dt: float) -> void:
	hero.attack_cd = maxf(0.0, hero.attack_cd - dt)
	hero.dodge_cd = maxf(0.0, hero.dodge_cd - dt)
	hero.rain_cd = maxf(0.0, hero.rain_cd - dt)
	hero.blast_cd = maxf(0.0, hero.blast_cd - dt)
	hero.invuln_t = maxf(0.0, hero.invuln_t - dt)
	if not hero.alive:
		hero.respawn_t -= dt
		if hero.respawn_t <= 0.0:
			hero.alive = true
			hero.hp = hero.max_hp
			hero.pos = map.to_3d(map.hero_spawn)
			hero.invuln_t = 2.0
			emit({"type": "hero_respawn", "pos": hero.pos})
		return
	hero.regen_delay -= dt
	if hero.regen_delay <= 0.0:
		hero.hp = minf(hero.max_hp, hero.hp + float(hero.def.regen) * dt)
	for e: Units.Enemy in enemies_near(hero.pos, 2.5, false, true):
		var contact := float(e.def.get("contact", 0))
		if contact <= 0.0 or e.contact_cd > 0.0 or e.launched_t > 0.0:
			continue
		if e.attack_t <= 0.0 and e.frozen_t <= 0.0 and e.stun_t <= 0.0 and _hero_dist(e) <= e.size + 0.6:
			e.attack_t = ATTACK_WINDUP
			emit({"type": "enemy_attack", "id": e.id, "pos": e.pos})


func _hero_dist(e: Units.Enemy) -> float:
	return Vector2(e.pos.x, e.pos.z).distance_to(Vector2(hero.pos.x, hero.pos.z))


## Melee windup: the hit lands only if the hero is still in reach when it ends,
## so stepping away or dodging during the telegraph avoids the damage.
func _resolve_attack(e: Units.Enemy, dt: float) -> void:
	if e.frozen_t > 0.0 or e.launched_t > 0.0 or e.stun_t > 0.0:
		e.attack_t = 0.0
		e.contact_cd = 0.5
		return
	e.attack_t -= dt
	if e.attack_t > 0.0:
		return
	e.attack_t = 0.0
	e.contact_cd = 1.2
	if hero.alive and _hero_dist(e) <= e.size + 1.1:
		damage_hero(float(e.def.get("contact", 0)) * (1.5 if e.elite else 1.0))


# ================================================================ cleanup

func _cleanup() -> void:
	enemies = enemies.filter(func(e): return e.alive)
	projectiles = projectiles.filter(func(p): return p.alive)
	if wave_active and spawn_queue.is_empty() and enemies.is_empty() and not defeated:
		wave_active = false
		var bonus := int(round((float(balance.wave_clear_gold) + float(balance.wave_clear_gold_per_depth) * depth)
				* maxf(0.0, 1.0 + mods.stat("wave_gold_pct")) * income_mult))
		gold += bonus
		stats.gold_earned += bonus
		_spawn_cache()
		emit({"type": "wave_cleared", "gold": bonus})


## A supply cache appears somewhere off the road after each wave; the hero picks it up (F).
func _spawn_cache() -> void:
	for attempt in 30:
		var p := Vector2(rng.randf_range(map.bounds.position.x + 4, map.bounds.end.x - 4),
				rng.randf_range(map.bounds.position.y + 4, map.bounds.end.y - 4))
		if map.is_on_path(p, -1.0) or map.circle_hits_obstacle(p, 1.0) or not map.plateau_at(p).is_empty():
			continue
		if p.distance_to(map.core_pos) > 26.0:
			continue
		cache = {"pos": map.to_3d(p), "gold": int(round((20 + 6 * depth) * income_mult))}
		emit({"type": "cache_spawned", "pos": cache.pos})
		return
