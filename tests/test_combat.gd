extends TestCase
## Damage resolution, statuses, enemy movement, leaks and defeat.


func test_enemy_walks_the_road_and_leaks() -> void:
	var sim := make_sim()
	var e := sim.spawn_enemy("runner")
	var len := sim.map.path.length
	run(sim, len / e.speed + 2.0)
	check(not sim.enemies.has(e), "runner reached the core")
	check_near(sim.core_hp, 99.0, 0.001, "leak damage")
	check_eq(sim.stats.leaks, 1)


func test_defeat_when_core_destroyed() -> void:
	var sim := make_sim()
	sim.core_hp = 2.0
	var e := sim.spawn_enemy("brute")
	e.s = sim.map.path.length - 3.0
	run(sim, 3.0)
	check(sim.defeated, "core destroyed -> defeat")
	check_eq(sim.core_hp, 0.0)


func test_armor_reduces_physical_but_not_elements() -> void:
	var sim := make_sim()
	var e := sim.spawn_enemy("brute")  # armor 5
	var hp := e.hp
	sim.damage_enemy(e, 10.0, "physical", -1, 0.0)
	check_near(hp - e.hp, 5.0, 0.001, "10 - 5 armor")
	hp = e.hp
	sim.damage_enemy(e, 4.0, "physical", -1, 0.0)
	check_near(hp - e.hp, 1.0, 0.001, "minimum 25% gets through")
	hp = e.hp
	sim.damage_enemy(e, 10.0, "ice", -1, 0.0)
	check_near(hp - e.hp, 10.0, 0.001, "elements ignore armor")


func test_crit_multiplies_damage() -> void:
	var sim := make_sim()
	var e := sim.spawn_enemy("grunt")
	var dealt := sim.damage_enemy(e, 5.0, "ice", -1, 1.0)
	check(dealt < 0.0, "crit flagged")
	check_near(e.max_hp - e.hp, 10.0, 0.001)


func test_oiled_enemies_take_more_fire() -> void:
	var sim := make_sim()
	var e := sim.spawn_enemy("brute")
	e.oiled_t = 3.0
	var hp := e.hp
	sim.damage_enemy(e, 10.0, "fire", -1, 0.0)
	check_near(hp - e.hp, 15.0, 0.001, "oil x1.5 without upgrade")
	var sim2 := make_sim(1000, ["oil_slick"])
	var e2 := sim2.spawn_enemy("brute")
	e2.oiled_t = 3.0
	sim2.damage_enemy(e2, 10.0, "fire", -1, 0.0)
	check_near(e2.max_hp - e2.hp, 20.0, 0.001, "oil slick doubles fire damage")


func test_chilled_enemies_take_bonus_lightning() -> void:
	var sim := make_sim()
	var e := sim.spawn_enemy("brute")
	e.chill_t = 2.0
	sim.damage_enemy(e, 10.0, "lightning", -1, 0.0)
	check_near(e.max_hp - e.hp, 15.0, 0.001)


func test_chill_slows_and_freeze_stops() -> void:
	var sim := make_sim()
	var a := sim.spawn_enemy("grunt", false, 10.0, 0.0)
	var b := sim.spawn_enemy("grunt", false, 10.0, 0.0)
	b.chill_t = 10.0
	b.chill_slow = 0.5
	var c := sim.spawn_enemy("grunt", false, 10.0, 0.0)
	c.frozen_t = 10.0
	run(sim, 2.0)
	check_near(a.s - 10.0, a.speed * 2.0, 0.2)
	check_near(b.s - 10.0, b.speed * 2.0 * 0.5, 0.2, "50% slow")
	check_near(c.s, 10.0, 0.001, "frozen")


func test_warden_shields_nearby_allies() -> void:
	var sim := make_sim()
	var w := sim.spawn_enemy("warden", false, 20.0, 0.0)
	var g := sim.spawn_enemy("grunt", false, 21.0, 0.0)
	sim.step(DT)
	check(g.shielded > 0.3, "ally inside aura is shielded")
	check_eq(w.shielded, 0.0, "warden does not shield itself")
	var hp := g.hp
	sim.damage_enemy(g, 10.0, "ice", -1, 0.0)
	check_near(hp - g.hp, 6.5, 0.01)


func test_splitter_splits_on_death() -> void:
	var sim := make_sim()
	var e := sim.spawn_enemy("splitter", false, 30.0)
	sim.damage_enemy(e, 9999.0, "ice", -1, 0.0)
	var children := sim.enemies.filter(func(x): return x.type == "splitling" and x.alive)
	check_eq(children.size(), 2)


func test_hexer_disables_structures() -> void:
	var sim := make_sim()
	var st := sim.build("arrow", beside(sim, 30.0))
	check(st != null, "tower built")
	var h := sim.spawn_enemy("hexer", false, 30.0, 0.0)
	h.ability_t = 0.01
	sim.step(DT)
	check(st.disabled_t > 0.0, "tower disabled by hex")


func test_gold_on_kill_and_bounty() -> void:
	var sim := make_sim(0, ["bounty_hunter"])
	var e := sim.spawn_enemy("grunt")
	sim.damage_enemy(e, 9999.0, "ice", -1, 0.0)
	check_eq(sim.gold, int(round(float(DataDB.enemy("grunt").gold) * 1.25)))


func test_wave_clear_gives_bonus_and_cache() -> void:
	var sim := make_sim(0)
	sim.start_wave([{"t": 0.0, "type": "grunt"}])
	sim.step(DT)
	for e in sim.enemies:
		sim.damage_enemy(e, 9999.0, "ice", -1, 0.0)
	sim.step(DT)
	check(not sim.wave_active, "wave cleared")
	check(sim.gold >= int(DataDB.balance().wave_clear_gold) + int(DataDB.enemy("grunt").gold), "kill + clear bonus")
	check(not sim.cache.is_empty(), "supply cache spawned")
	var g := sim.gold
	sim.hero.pos = sim.cache.pos
	check(sim.hero_interact(), "hero picks up cache")
	check(sim.gold > g)


func test_flyers_ignore_road_and_ground_traps() -> void:
	var sim := make_sim()
	var spikes := sim.build("spikes", road(sim, 8.0))
	check(spikes != null)
	var w := sim.spawn_enemy("wisp")
	run(sim, 3.0)
	check(w.pos.y > 2.0, "flying height")
	check_eq(w.hp, w.max_hp, "ground trap cannot hit flyers")
