extends TestCase
## Free placement, economy (cost/upgrade/sell) and towers/traps working.


func test_tower_must_be_off_road_and_trap_on_road() -> void:
	var sim := make_sim()
	check(not sim.can_build("arrow", road(sim, 20.0)).ok, "tower on road rejected")
	check_eq(sim.can_build("arrow", road(sim, 20.0)).reason, "BUILD_ERR_ON_PATH")
	check(sim.can_build("arrow", beside(sim, 20.0)).ok, "tower beside road ok")
	check(sim.can_build("spikes", road(sim, 20.0)).ok, "trap on road ok")
	check_eq(sim.can_build("spikes", beside(sim, 20.0)).reason, "BUILD_ERR_NEED_PATH")


func test_overlap_obstacles_bounds() -> void:
	var sim := make_sim()
	var p := beside(sim, 20.0)
	check(sim.build("arrow", p) != null)
	check_eq(sim.can_build("arrow", p + Vector2(0.5, 0)).reason, "BUILD_ERR_OVERLAP")
	var rock: Vector2 = sim.map.obstacles[0].pos
	check_eq(sim.can_build("arrow", rock).reason, "BUILD_ERR_BLOCKED")
	check_eq(sim.can_build("arrow", Vector2(31.8, 0)).reason, "BUILD_ERR_BOUNDS")
	check(sim.build("spikes", road(sim, 40.0)) != null)
	check_eq(sim.can_build("spikes", road(sim, 40.0) + Vector2(1, 0)).reason, "BUILD_ERR_OVERLAP")


func test_plateau_edge_and_range_bonus() -> void:
	var sim := make_sim()
	var pl: Rect2 = sim.map.plateaus[0].rect
	check_eq(sim.can_build("arrow", Vector2(pl.position.x, pl.get_center().y)).reason, "BUILD_ERR_SLOPE")
	var st := sim.build("arrow", pl.get_center())
	check(st != null and st.elevated, "built on plateau")
	check_near(st.pos.y, 1.6, 0.001)
	var low := sim.build("arrow", beside(sim, 20.0))
	check_near(sim.tower_range(st), sim.tower_range(low) * 1.2, 0.01, "+20% range when elevated")


func test_costs_upgrade_sell() -> void:
	var sim := make_sim(500)
	var st := sim.build("arrow", beside(sim, 20.0))
	check_eq(sim.gold, 440)
	var dmg1 := sim.tower_damage(st)
	var c := sim.upgrade_cost(st)
	check(sim.upgrade(st))
	check_eq(sim.gold, 440 - c)
	check(sim.tower_damage(st) > dmg1 * 1.4, "level 2 is stronger")
	check(sim.upgrade(st))
	check_eq(sim.upgrade_cost(st), -1, "max level 3")
	var value := sim.sell_value(st)
	var before := sim.gold
	check_eq(sim.sell(st), value)
	check_eq(sim.gold, before + value)
	check(value == int(floor(st.invested * 0.7)), "70% refund")
	check(sim.structures.is_empty())


func test_not_enough_gold_and_locked() -> void:
	var sim := make_sim(50, [], 1, [])
	check_eq(sim.can_build("cannon", beside(sim, 20.0)).reason, "BUILD_ERR_GOLD")
	check_eq(sim.can_build("banner", beside(sim, 20.0)).reason, "BUILD_ERR_LOCKED")


func test_master_builder_discount() -> void:
	var sim := make_sim(1000, ["master_builder"])
	check_eq(sim.structure_cost("arrow"), 54)


func test_arrow_tower_kills_grunts() -> void:
	var sim := make_sim()
	sim.build("arrow", beside(sim, 25.0))
	sim.start_wave([{"t": 0.0, "type": "grunt"}, {"t": 0.5, "type": "grunt"}])
	run_until_clear(sim)
	check_eq(sim.stats.kills, 2, "both killed")
	check_eq(sim.stats.leaks, 0)


func test_cannon_splash_hits_groups_but_not_air() -> void:
	var sim := make_sim()
	var st := sim.build("cannon", beside(sim, 25.0))
	var es := []
	for i in 4:
		es.append(sim.spawn_enemy("brute", false, 22.0 + i * 0.4, 0.0))
	var w := sim.spawn_enemy("wisp")
	w.fly_from = sim.map.path.sample(26.0)
	run(sim, 3.0)
	var hurt := es.filter(func(e): return e.hp < e.max_hp).size()
	check(hurt >= 3, "splash damaged several (%d)" % hurt)
	check_eq(w.hp, w.max_hp, "cannon cannot hit air")
	check(st.shots > 0)


func test_frost_tower_chills() -> void:
	var sim := make_sim()
	sim.build("frost", beside(sim, 25.0))
	var e := sim.spawn_enemy("brute", false, 20.0, 0.0)
	run(sim, 2.5)
	check(e.chill_t > 0.0, "enemy chilled")


func test_line_of_sight_blocked_by_tall_wall() -> void:
	var sim := make_sim()
	# Wall at x=-4..3, z=-15..-13.8 sits between this spot and the first road segment.
	var st := sim.build("arrow", Vector2(-1, -11))
	check(st != null)
	var e := sim.spawn_enemy("brute", false, 6.0, 0.0)  # at (0,-26): behind the wall
	check(sim.map.blocks_los(st.pos2(), Vector2(e.pos.x, e.pos.z)), "wall blocks sight")
	run(sim, 1.0)
	check_eq(st.shots, 0, "no shots without line of sight")


func test_spikes_damage_ground_enemies() -> void:
	var sim := make_sim()
	sim.build("spikes", road(sim, 20.0))
	var e := sim.spawn_enemy("brute", false, 17.0, 0.0)
	run(sim, 2.5)
	check(e.hp < e.max_hp)


func test_spring_launches_back() -> void:
	var sim := make_sim()
	sim.build("spring", road(sim, 20.0))
	var e := sim.spawn_enemy("brute", false, 18.5, 0.0)
	var launched := false
	for i in 60:
		sim.step(DT)
		for ev in sim.pop_events():
			if ev.type == "launch":
				launched = true
	check(launched, "launched")
	check(e.s < 18.5, "pushed back along the road")


func test_tar_slows_and_oils() -> void:
	var sim := make_sim()
	sim.build("tar", road(sim, 20.0))
	var e := sim.spawn_enemy("grunt", false, 19.5, 0.0)
	sim.step(DT)
	sim.step(DT)
	check(e.oiled_t > 0.0, "oiled")


func test_support_banner_buffs_towers_in_range() -> void:
	var sim := make_sim()
	var st := sim.build("arrow", beside(sim, 25.0))
	var base := sim.tower_damage(st)
	sim.build("banner", beside(sim, 25.0, 7.6))
	check(sim.tower_damage(st) > base * 1.15, "aura damage bonus")


func test_snapshot_restore_keeps_defences() -> void:
	var sim := make_sim()
	var st := sim.build("arrow", beside(sim, 25.0))
	sim.upgrade(st)
	sim.build("spikes", road(sim, 30.0))
	var snap := sim.structures_snapshot()
	var sim2 := make_sim()
	sim2.restore_structures(snap)
	check_eq(sim2.structures.size(), 2)
	check_eq(sim2.structures[0].level, 2)
	check_eq(sim2.structures[0].invested, st.invested)
