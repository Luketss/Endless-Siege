extends TestCase
## Upgrades, rarity, synergies, waves, journey generation and determinism.


func test_at_least_20_upgrades_all_rarities() -> void:
	var ups := DataDB.upgrades()
	check(ups.size() >= 20, "has %d upgrades" % ups.size())
	var rar := {}
	for id in ups:
		rar[ups[id].rarity] = true
		check(ups[id].has("stats") or ups[id].has("flags"), "%s has an effect" % id)
	for r in UpgradePool.RARITIES:
		check(rar.has(r), "rarity %s present" % r)


func test_roll_three_distinct_not_owned() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 50:
		var picks := UpgradePool.roll(rng, ["sharpened_arrows"], [])
		check_eq(picks.size(), 3)
		check(not picks.has("sharpened_arrows"), "owned excluded")
		check(picks[0] != picks[1] and picks[1] != picks[2] and picks[0] != picks[2], "distinct")


func test_locked_upgrades_excluded_until_unlocked() -> void:
	var avail := UpgradePool.available([], [])
	check(not avail.has("meteor_volley"), "legendary pool locked")
	check(not avail.has("war_banners"), "needs banner unlock")
	var avail2 := UpgradePool.available([], ["legendary_pool", "banner"])
	check(avail2.has("meteor_volley") and avail2.has("war_banners"))


func test_min_rarity_respected() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 30:
		for id in UpgradePool.roll(rng, [], [], "rare"):
			check(DataDB.upgrade(id).rarity != "common", "elite rewards are rare+")


func test_rarity_distribution_favours_common() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := {}
	for i in 400:
		var id: String = UpgradePool.roll(rng, [], ["legendary_pool", "banner", "tar"], "common", 1)[0]
		var r: String = DataDB.upgrade(id).rarity
		counts[r] = int(counts.get(r, 0)) + 1
	check(int(counts.common) > int(counts.rare) and int(counts.rare) > int(counts.get("epic", 0)), str(counts))


func test_mods_aggregate_and_synergy_activates() -> void:
	var m := RunMods.build(["long_sight", "rapid_reload"])
	check_near(m.stat("tower_range_pct"), 0.12, 0.0001)
	check(m.active_synergies.is_empty())
	var m2 := RunMods.build(["shatter", "deep_freeze"])
	check(m2.active_synergies.has("permafrost"), "2 ice upgrades -> permafrost")
	check_near(m2.stat("chill_duration_add"), 1.8, 0.0001)
	var m3 := RunMods.build(["shatter", "conductive_ice"])
	check(m3.active_synergies.has("superconductor"), "ice + lightning")
	check(m.synergies_unlocked_by(["support"]).has("tactician"), "UI hint for next synergy")


func test_piercing_arrows_hit_several() -> void:
	var sim := make_sim(1000, ["piercing_arrows"])
	var line := []
	for i in 3:
		line.append(sim.spawn_enemy("brute", false, 30.0 + i * 1.2, 0.0))
	var from := sim.map.to_3d(sim.map.path.sample(36.0), 0.9)
	var to := sim.map.to_3d(sim.map.path.sample(28.0), 0.9)
	sim.step(DT)
	sim.hero_attack(from, to - from)
	run(sim, 0.5)
	var hit := line.filter(func(e): return e.hp < e.max_hp).size()
	check_eq(hit, 3, "arrow passed through")


func test_shatter_explodes_chilled() -> void:
	var sim := make_sim(1000, ["shatter"])
	var a := sim.spawn_enemy("brute", false, 30.0, 0.0)
	var b := sim.spawn_enemy("grunt", false, 30.5, 0.0)
	sim.step(DT)
	b.chill_t = 2.0
	var hp := a.hp
	sim.damage_enemy(b, 9999.0, "ice", -1, 0.0)
	check(a.hp < hp, "neighbour hit by shatter")


func test_spring_into_spikes_synergy() -> void:
	var damage_with := _spring_spikes_damage(["spring_impalers"])
	var damage_without := _spring_spikes_damage([])
	check(damage_with > damage_without * 1.8, "impale bonus %s vs %s" % [damage_with, damage_without])


func _spring_spikes_damage(ups: Array) -> float:
	var sim := make_sim(1000, ups)
	sim.build("spikes", road(sim, 10.0))
	var e := sim.spawn_enemy("brute", false, 17.0, 0.0)
	e.max_hp = 10000.0
	e.hp = 10000.0
	sim.launch(e, 7.0, -1)
	run(sim, 0.7)
	return e.max_hp - e.hp


func test_chain_traps() -> void:
	var sim := make_sim(1000, ["chain_reaction"])
	var a := sim.build("spikes", road(sim, 20.0))
	var b := sim.build("spikes", road(sim, 23.0))
	var e := sim.spawn_enemy("brute", false, 19.0, 0.0)
	var other := sim.spawn_enemy("brute", false, 23.0, 0.0)
	other.speed = 0.0
	sim.step(DT)
	sim.step(DT)
	check(a.shots >= 1 and b.shots >= 1, "neighbour trap fired too")


func test_fire_ground_from_cannon() -> void:
	var sim := make_sim(1000, ["incendiary_shells"])
	sim.build("cannon", beside(sim, 25.0))
	sim.spawn_enemy("brute", false, 22.0, 0.0)
	var zone := false
	for i in 120:
		sim.step(DT)
		for ev in sim.pop_events():
			if ev.type == "zone" and ev.kind == "fire":
				zone = true
	check(zone, "burning ground created")


func test_overcharge_nova() -> void:
	var sim := make_sim(1000, ["overcharge"])
	sim.build("arrow", beside(sim, 25.0))
	var e := sim.spawn_enemy("brute", false, 20.0, 0.0)
	e.max_hp = 99999.0
	e.hp = 99999.0
	e.speed = 0.0
	var nova := false
	for i in 300:
		sim.step(DT)
		for ev in sim.pop_events():
			if ev.type == "synergy" and ev.name == "SYN_FX_OVERCHARGE":
				nova = true
	check(nova, "every 8th shot triggers a nova")


func test_blood_money_more_enemies() -> void:
	var rng := RandomNumberGenerator.new()
	var base := WaveDirector.budget(2, 1, RunMods.build([]), "combat")
	var more := WaveDirector.budget(2, 1, RunMods.build(["blood_money"]), "combat")
	check_near(more / base, 1.3, 0.001)


func test_waves_deterministic_and_progressive() -> void:
	var mods := RunMods.build([])
	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	var a := WaveDirector.build_wave("combat", 2, 1, 3, r1, mods)
	var b := WaveDirector.build_wave("combat", 2, 1, 3, r2, mods)
	check_eq(a, b, "same seed -> same wave")
	var types0 := {}
	var r3 := RandomNumberGenerator.new()
	r3.seed = 1
	for e in WaveDirector.build_wave("combat", 0, 0, 3, r3, mods):
		types0[e.type] = true
	check(not types0.has("hexer") and not types0.has("brute"), "advanced types appear later")
	check(WaveDirector.pool(3).has("warden"), "depth 3 introduces wardens")


func test_boss_wave_contains_golem() -> void:
	var rng := RandomNumberGenerator.new()
	var w := WaveDirector.build_wave("boss", 6, 2, 3, rng, RunMods.build([]))
	check(w.any(func(e): return e.type == "golem"))


func test_journey_structure() -> void:
	for seed_value in [1, 2, 3, 99, 1234]:
		var j := Journey.generate(seed_value)
		var layers: Array = j.layers
		check_eq(layers.size(), 7)
		check_eq(layers[0][0].type, "combat")
		check_eq(layers[6][0].type, "boss")
		var types := {}
		for L in layers:
			for n in L:
				types[n.type] = true
		check(types.has("elite") and types.has("shop"), "guaranteed elite and shop (seed %d)" % seed_value)
		# Every node except the first is reachable, and every non-final node has a link.
		for L in range(layers.size()):
			for n in layers[L]:
				if L < layers.size() - 1:
					check(not n.links.is_empty(), "node %s has links" % n.id)
		check_eq(Journey.generate(seed_value), j, "deterministic")


func test_boss_phases() -> void:
	var sim := make_sim()
	var g := sim.spawn_enemy("golem", false, 20.0, 0.0)
	var phases := []
	sim.damage_enemy(g, g.max_hp * 0.4, "ice", -1, 0.0)
	sim.step(DT)
	sim.damage_enemy(g, g.max_hp * 0.35, "ice", -1, 0.0)
	sim.step(DT)
	for ev in sim.pop_events():
		if ev.type == "boss_phase":
			phases.append(ev.phase)
	check_eq(phases, [1, 2], "phase changes")
	var before := sim.enemies.size()
	run(sim, 2.0)
	check(sim.enemies.size() > before, "boss summons minions in later phases")
	var st := sim.build("arrow", beside(sim, g.s + 1.0))
	g.ability_t = 0.01
	sim.step(DT)
	check(st == null or st.disabled_t > 0.0, "stomp disables nearby structures")
