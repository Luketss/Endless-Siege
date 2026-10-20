extends Node
## Smoke tests of the real scenes (headless): menu, game flow, battle, pause, result.

var failures: Array[String] = []
var current_test := ""


func check(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	get_tree().root.add_child(scene)
	await _frames(4)
	return scene


func test_main_menu_loads() -> void:
	var m := await _open("res://scenes/main_menu.tscn")
	check(m.ui != null and m.ui.get_child_count() > 1, "menu built")
	m._show("sanctuary")
	m._show("new_run")
	await _frames(2)
	m.queue_free()
	await _frames(2)


func test_game_journey_and_battle() -> void:
	var profile: Node = get_tree().root.get_node("Profile")
	profile.active_run = RunState.create(4242, "ranger", [], [])
	var g := await _open("res://scenes/game.tscn")
	check(g.overlay is JourneyPanel, "starts on the journey map")
	g._enter_node("0-0")
	await _frames(3)
	check(g.phase == "build", "combat starts in build phase")
	check(g.hud.visible, "HUD visible")
	# Build through the same API the controller uses.
	var st = null
	var s := 30.0
	while st == null and s < 100.0:
		var p: Vector2 = g.sim.map.path.sample(s)
		var t: Vector2 = g.sim.map.path.tangent(s)
		st = g.sim.build("arrow", p + Vector2(-t.y, t.x) * 4.8)
		s += 3.0
	check(st != null, "built a tower")
	await _frames(3)
	check(g.view.structure_node(st.id) != null, "tower has a 3D node")
	g._start_wave()
	check(g.phase == "wave", "wave started")
	var frames := 0
	while g.sim.time < 2.5 and frames < 2000:
		await get_tree().process_frame
		frames += 1
	check(g.sim.time >= 2.5, "simulation advanced (%.2f)" % g.sim.time)
	check(g.view._enemy_nodes.size() > 0 or g.sim.stats.kills > 0, "enemies rendered")
	g._set_paused(true)
	var t0: float = g.sim.time
	await _frames(10)
	check(is_equal_approx(g.sim.time, t0), "pause freezes the battle")
	g._set_paused(false)
	# Finish the encounter quickly: kill everything as it spawns.
	var guard := 0
	while g.phase != "done" and guard < 4000:
		guard += 1
		for e in g.sim.enemies:
			g.sim.damage_enemy(e, 99999.0, "ice", -1, 0.0)
		if g.phase == "build":
			g._start_wave()
		g.sim.step(1.0 / 60.0)
		for ev in g.sim.pop_events():
			g._on_event(ev)
	check(g.phase == "done", "encounter finished")
	check(g.run.stats.combats == 1, "combat counted")
	await get_tree().create_timer(1.5).timeout
	check(g.overlay != null, "reward cards shown")
	g.queue_free()
	await _frames(2)


func test_result_screen_loads() -> void:
	var profile: Node = get_tree().root.get_node("Profile")
	var run := RunState.create(1, "ranger", [], [])
	run.finished = true
	profile.set_meta("last_run", run)
	profile.set_meta("last_essence", 12)
	var r := await _open("res://scenes/result.tscn")
	check(r.get_child_count() > 1)
	r.queue_free()
	await _frames(2)
