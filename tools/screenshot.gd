extends SceneTree
## Captures screenshots for visual review / store page drafts (needs a display):
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
##       --rendering-method gl_compatibility --rendering-driver opengl3 --script res://tools/screenshot.gd
## Env: SHOT_DIR (default user://shots), SHOT_LANG (pt/en), SHOT_HERO (ranger/warrior), SHOT_MAP (forest/frost).

var out_dir := ""


func _initialize() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir == "":
		out_dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	var lang := OS.get_environment("SHOT_LANG")
	var settings: Node = root.get_node("/root/Settings")
	if lang != "":
		settings.data.language = lang
		settings.apply_all()
	var profile: Node = root.get_node("/root/Profile")

	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(40)
	await _shot("01_menu")
	menu.queue_free()
	await _frames(2)

	var hero_id := OS.get_environment("SHOT_HERO") if OS.get_environment("SHOT_HERO") != "" else "ranger"
	var map_id := OS.get_environment("SHOT_MAP") if OS.get_environment("SHOT_MAP") != "" else "forest"
	var run := RunState.create(777, hero_id, [], ["banner", "tar"], map_id)
	for id in ["sharpened_arrows", "shatter", "deep_freeze", "incendiary_shells"]:
		run.add_upgrade(id)
	run.gold = 1400
	profile.active_run = run
	var g: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(g)
	await _frames(30)
	await _shot("02_journey")
	g._enter_node("0-0")
	await _frames(5)
	# A believable mid-game defence along the road.
	var sim: BattleSim = g.sim
	var placed := 0
	var s := 20.0
	var types := ["arrow", "frost", "cannon", "arrow", "banner", "frost", "arrow", "cannon"]
	while s < sim.map.path.length - 10.0 and placed < types.size():
		var p := sim.map.path.sample(s)
		var t := sim.map.path.tangent(s)
		var st := sim.build(types[placed], p + Vector2(-t.y, t.x) * 4.6)
		if st == null:
			st = sim.build(types[placed], p - Vector2(-t.y, t.x) * 4.6)
		if st:
			if placed % 3 == 0:
				sim.upgrade(st)
			placed += 1
		s += 9.0
	for k in [40.0, 70.0, 95.0]:
		sim.build("spikes", sim.map.path.sample(k))
	sim.build("spring", sim.map.path.sample(52.0))
	sim.build("tar", sim.map.path.sample(80.0))
	sim.depth = 3
	var mods := sim.mods
	var w := WaveDirector.build_wave("elite", 3, 1, 3, RandomNumberGenerator.new(), mods)
	g._start_wave()
	sim.start_wave(w)
	# Let the battle develop with the camera behind the hero, looking down the road.
	g.hero.global_position = Vector3(-7.0, 0.2, -12.5)
	g.rig.yaw = deg_to_rad(-30.0)
	g.rig.pitch = -0.42
	g.rig.distance = 10.0
	for i in 260:
		await process_frame
		if i % 12 == 0 and sim.hero.alive:
			var target := Vector3.ZERO
			for e in sim.enemies:
				target = e.pos
				break
			if target != Vector3.ZERO:
				sim.hero_attack(sim.hero.pos + Vector3(0, 1.4, 0), target - sim.hero.pos)
		if i == 150:
			var tgt := sim.map.path.sample(18.0)
			match sim.ability_id(0):
				"rain":
					sim.hero_rain(Vector3(tgt.x, 0, tgt.y))
				"nova":
					sim.hero_nova(Vector3(tgt.x, 0, tgt.y))
				"slam":
					sim.hero_slam()
	g.view.show_all_ranges = false
	await _shot("03_battle")
	# Build mode ghost + range preview.
	g.build.selected = "cannon"
	g.rig.pitch = -0.7
	await _frames(10)
	await _shot("04_build_mode")
	g.build.cancel()
	# Boss.
	var golem := sim.spawn_enemy("golem", false, 40.0, 0.0)
	var gp := sim.map.path.sample(32.0) + Vector2(6, 6)
	g.hero.global_position = Vector3(gp.x, 0.2, gp.y)
	g.rig.yaw = deg_to_rad(200.0)
	g.rig.pitch = -0.3
	for i in 90:
		await process_frame
	sim.damage_enemy(golem, golem.max_hp * 0.4, "ice", -1, 0.0)
	await _frames(20)
	await _shot("05_boss")
	# Reward cards.
	g._show_reward(["piercing_arrows", "conductive_ice", "meteor_volley"], tr("REWARD_TITLE"))
	await _frames(10)
	await _shot("06_reward")
	g._set_overlay(SettingsPanel.new())
	await _frames(10)
	await _shot("07_settings")
	quit()
