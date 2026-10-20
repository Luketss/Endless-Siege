extends TestCase
## Run flow, hero, persistence and full journeys.


func _path(name: String) -> String:
	return "user://test_%s_%d.json" % [name, Time.get_ticks_usec()]


func test_safe_store_roundtrip_and_recovery() -> void:
	var p := _path("store")
	check(SafeStore.save(p, {"a": 1}))
	check(SafeStore.save(p, {"a": 2}))
	var r := SafeStore.read(p, {"a": 0})
	check_eq(r.status, SafeStore.STATUS_OK)
	check_eq(int(r.data.a), 2)
	# Corrupt the main file: backup (previous good save) is used.
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{garbage")
	f.close()
	r = SafeStore.read(p, {"a": 0})
	check_eq(r.status, SafeStore.STATUS_RECOVERED)
	check_eq(int(r.data.a), 1)
	# Tampered checksum is detected too.
	f = FileAccess.open(p + ".bak", FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 1, "sum": "x", "data": "{}"}))
	f.close()
	r = SafeStore.read(p, {"a": 0})
	check_eq(r.status, SafeStore.STATUS_RESET)
	check_eq(int(r.data.a), 0)
	SafeStore.erase(p)
	check_eq(SafeStore.read(p, {"a": 7}).status, SafeStore.STATUS_NEW)


func test_run_state_serialization() -> void:
	var run := RunState.create(77, "ranger", ["hordes"], ["banner"])
	run.add_upgrade("reinforced_core")
	run.gold = 321
	var copy := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(copy != null)
	check_eq(copy.gold, 321)
	check_eq(copy.upgrades, ["reinforced_core"])
	check_eq(copy.journey.layers.size(), run.journey.layers.size())
	check_near(copy.core_max(), 125.0, 0.001)
	check(RunState.from_dict({"version": 999}) == null, "incompatible save rejected")


func test_enter_only_linked_nodes() -> void:
	var run := RunState.create(5, "ranger", [], [])
	check(RunFlow.enter(run, "3-0").is_empty(), "cannot skip ahead")
	var first := RunFlow.enter(run, "0-0")
	check_eq(first.type, "combat")
	var nexts := Journey.choices(run.journey, run.current_node)
	check(not nexts.is_empty())
	check(not RunFlow.enter(run, nexts[0].id).is_empty())


func test_shop_rest_event() -> void:
	var run := RunState.create(8, "ranger", [], [])
	run.gold = 500
	run.core_hp = 40.0
	var node := {"id": "2-0", "type": "shop", "layer": 2}
	var offer := RunFlow.shop_offer(run, node)
	check_eq(offer.items.size(), 3)
	check(RunFlow.buy(run, offer.items[0]))
	check(run.upgrades.has(offer.items[0].id))
	check(not RunFlow.buy(run, offer.items[0]), "cannot buy twice")
	check(RunFlow.repair(run, offer.repair_cost, offer.repair_amount))
	var before := run.core_hp
	check(RunFlow.rest(run) > 0.0)
	check(run.core_hp > before)
	run.gold = 0
	var res := RunFlow.apply_event(run, node, "wandering_merchant", 0)
	check(not res.ok, "cannot afford")
	res = RunFlow.apply_event(run, node, "dark_altar", 0)
	check(res.ok and res.upgrade_choices.size() == 3, "altar gives rare choices")


func test_essence_rewards() -> void:
	var run := RunState.create(1, "ranger", [], [])
	run.stats.waves = 9
	run.stats.combats = 2
	run.stats.elites = 1
	check_eq(run.essence_earned(), 9 + 8 + 8)
	run.modifiers = ["hordes"]
	check_eq(run.essence_earned(), int(round(25 * 1.3)))


func test_hero_attack_cooldowns_and_respawn() -> void:
	var sim := make_sim()
	sim.hero.pos = Vector3(0, 0, 20)
	check(sim.hero_attack(sim.hero.pos, Vector3.FORWARD))
	check(not sim.hero_attack(sim.hero.pos, Vector3.FORWARD), "attack cooldown")
	check(sim.hero_rain(Vector3(0, 0, 0)))
	check(not sim.hero_rain(Vector3(0, 0, 0)), "rain cooldown")
	check(sim.hero_dodge())
	sim.damage_hero(50)
	check_eq(sim.hero.hp, sim.hero.max_hp, "invulnerable while dodging")
	run(sim, 0.5)
	sim.damage_hero(9999)
	check(not sim.hero.alive, "hero down")
	check(not sim.hero_attack(sim.hero.pos, Vector3.FORWARD), "dead heroes cannot attack")
	run(sim, float(DataDB.balance().hero_respawn) + 0.2)
	check(sim.hero.alive, "respawned")
	check(not sim.defeated, "hero death is not defeat")


func test_hero_blast_pushes_enemies() -> void:
	var sim := make_sim()
	var e := sim.spawn_enemy("brute", false, 30.0, 0.0)
	var p := sim.map.path.sample(27.0)
	sim.hero.pos = Vector3(p.x, 0, p.y)
	sim.step(DT)
	var fwd := e.pos - sim.hero.pos
	check(sim.hero_blast(sim.hero.pos, fwd))
	check(e.s < 30.0 and e.hp < e.max_hp, "damaged and pushed")


func test_hero_levels_up() -> void:
	var sim := make_sim()
	for i in 12:
		var e := sim.spawn_enemy("brute")
		sim.damage_enemy(e, 99999.0, "ice", -1, 0.0)
	check(sim.hero.level >= 2, "level %d" % sim.hero.level)


func test_full_combat_node() -> void:
	var run := RunState.create(3, "ranger", [], [])
	var node := RunFlow.enter(run, "0-0")
	var cleared := Autopilot.play_combat(run, node, Autopilot.new(3))
	check_eq(cleared, 3, "first fight is winnable by a basic build")
	check(not run.finished)
	check_eq(run.stats.combats, 1)
	check(not run.structures.is_empty(), "defences persist")


func test_full_journeys_finish() -> void:
	var outcomes := []
	for seed_value in [11, 12, 13]:
		var run := Autopilot.play_journey(seed_value)
		check(run.finished, "journey %d finished" % seed_value)
		outcomes.append("%s@%s(%dw)" % ["WIN" if run.victory else "LOSS", run.current_node, run.stats.waves])
	print("    journeys: ", outcomes)


func test_run_log_records_decisions() -> void:
	var run := RunState.create(21, "ranger", [], [])
	var node := RunFlow.enter(run, "0-0")
	Autopilot.play_combat(run, node, Autopilot.new(21))
	var picks := RunFlow.reward_choices(run, node)
	RunFlow.record_reward(run, picks, picks[0])
	var enc := run.history.filter(func(e): return e.t == "encounter")
	check_eq(enc.size(), 1, "encounter logged")
	check(enc[0].has("damage") and enc[0].has("core_after"), "encounter details")
	var rew := run.history.filter(func(e): return e.t == "reward")
	check(rew.size() == 1 and rew[0].picked == picks[0] and rew[0].offered.size() == 3, "reward offer and pick")
	check(run.upgrades.has(picks[0]), "picked upgrade applied")
	var copy := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check_eq(copy.history.size(), run.history.size(), "history survives save/load")
	var path := "user://test_runs_%d.jsonl" % Time.get_ticks_usec()
	check(RunLog.append(run, path))
	check(RunLog.append(run, path))
	var all := RunLog.read_all(path)
	check_eq(all.size(), 2, "two journeys appended")
	check_eq(all[0].seed, 21)
	DirAccess.remove_absolute(path)


func _attack_setup() -> Array:
	var sim := make_sim()
	var e := sim.spawn_enemy("brute", false, 20.0, 0.0)
	sim.hero.pos = e.pos
	sim.step(DT)
	return [sim, e]


func test_enemy_attack_has_windup() -> void:
	var setup := _attack_setup()
	var sim: BattleSim = setup[0]
	var e: Units.Enemy = setup[1]
	check(e.attack_t > 0.0, "windup started")
	check(sim.events.any(func(ev): return ev.type == "enemy_attack"), "telegraph event")
	check_eq(sim.hero.hp, sim.hero.max_hp, "no damage at windup start")
	for i in 40:
		sim.hero.pos = e.pos
		sim.step(DT)
	check(sim.hero.hp < sim.hero.max_hp, "hit lands after the windup")


func test_stepping_away_avoids_enemy_attack() -> void:
	var setup := _attack_setup()
	var sim: BattleSim = setup[0]
	var e: Units.Enemy = setup[1]
	sim.hero.pos = e.pos + Vector3(6, 0, 0)
	run(sim, 0.6)
	check_eq(sim.hero.hp, sim.hero.max_hp, "out of reach when the windup ends")
	check(e.contact_cd > 0.0, "attack spent")


func test_tutorial_advances_on_actions() -> void:
	var sim := make_sim()
	var tut := Tutorial.new(Vector3.ZERO)
	var ctx := {"hero_pos": Vector3.ZERO, "sim": sim, "selected": "", "phase": "build", "dt": 0.1}
	check(not tut.update(ctx) and tut.step == 0, "waits until the hero moves")
	check(tut.text() != "", "objective text")
	ctx.hero_pos = Vector3(5, 0, 0)
	check(tut.update(ctx) and tut.step == 1, "move done")
	sim.hero.pos = Vector3(0, 0, 20)
	sim.hero_attack(sim.hero.pos, Vector3.FORWARD)
	tut.update(ctx)
	ctx.selected = "arrow"
	tut.update(ctx)
	check_eq(tut.step, 3, "shoot and pick done")
	var p := sim.map.path.sample(30.0)
	var t := sim.map.path.tangent(30.0)
	check(sim.build("arrow", p + Vector2(-t.y, t.x) * 4.6) != null or sim.build("arrow", p - Vector2(-t.y, t.x) * 4.6) != null, "built")
	tut.update(ctx)
	sim.hero_rain(Vector3(0, 0, 10))
	tut.update(ctx)
	ctx.phase = "wave"
	tut.update(ctx)
	check_eq(tut.step, 6, "place, ability and wave done")
	for i in 80:
		tut.update(ctx)
	check(tut.done(), "core reminder times out")


func _warrior_near(type: String = "brute") -> Array:
	var sim := make_sim(1000, [], 1, ["banner", "tar"], "warrior")
	var e := sim.spawn_enemy(type, false, 30.0, 0.0)
	sim.step(DT)
	return [sim, e]


func test_warrior_swing_hits_in_front_only() -> void:
	var setup := _warrior_near()
	var sim: BattleSim = setup[0]
	var e: Units.Enemy = setup[1]
	sim.hero.pos = e.pos + Vector3(2, 0, 0)  # enemy 2 m to the -X side
	check(sim.hero_attack(sim.hero.pos, Vector3(1, 0, 0)), "swing")
	check_eq(e.hp, e.max_hp, "enemy behind is not hit")
	sim.hero.attack_cd = 0.0
	check(sim.hero_attack(sim.hero.pos, Vector3(-1, 0, 0)), "swing again")
	check(e.hp < e.max_hp, "enemy in front is hit")


func test_warrior_slam_stuns_and_charge_pushes() -> void:
	var setup := _warrior_near()
	var sim: BattleSim = setup[0]
	var e: Units.Enemy = setup[1]
	sim.hero.pos = e.pos + Vector3(1.5, 0, 0)
	check(sim.hero_slam(), "slam")
	check(e.stun_t > 0.0 and e.hp < e.max_hp, "stunned and damaged")
	var s_before := e.s
	run(sim, 0.5)
	check_near(e.s, s_before, 0.01, "stunned enemies do not move")
	check(not sim.hero_slam(), "slam cooldown")
	run(sim, 1.2)
	sim.hero.pos = e.pos + Vector3(3, 0, 0)
	var hp := e.hp
	check(sim.hero_charge(Vector3(-1, 0, 0)), "charge")
	check(e.hp < hp and e.launched_t > 0.0, "charge hits and knocks back")
	check(sim.hero.invuln_t > 0.0, "invulnerable while charging")
	check_eq(sim.ability_id(0), "slam")


func test_warrior_needs_unlock() -> void:
	check(DataDB.heroes().has("warrior"))
	check_eq(str(DataDB.heroes().warrior.unlock), "warrior")
	check(DataDB.unlocks().has("warrior"), "sold in the sanctuary")
	var run := RunState.create(4, "warrior", [], [])
	check_eq(RunFlow.make_sim(run).hero.def.name_key, "H_WARRIOR")


func test_frost_map_plays() -> void:
	var run := RunState.create(3, "ranger", [], [], "frost")
	var copy := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check_eq(copy.map_id, "frost", "map survives save/load")
	var node := RunFlow.enter(run, "0-0")
	var cleared := Autopilot.play_combat(run, node, Autopilot.new(3))
	check_eq(cleared, 3, "first fight on the frost map is winnable")
	check(not run.structures.is_empty())
	check(DataDB.unlocks().frost_map.map == "frost", "unlockable")
