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
	var first := PadFocus.first_button(get_tree().root)
	check(first != null and m.is_ancestor_of(first), "gamepad finds a menu button to focus")
	var panel := SettingsPanel.new()
	m.ui.add_child(panel)
	await _frames(2)
	var over := PadFocus.first_button(get_tree().root)
	check(over != null and panel.is_ancestor_of(over), "gamepad focus moves to the settings overlay")
	panel.queue_free()
	await _frames(2)
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


func test_hero_and_build_input() -> void:
	var profile: Node = get_tree().root.get_node("Profile")
	profile.active_run = RunState.create(99, "ranger", [], [])
	var g := await _open("res://scenes/game.tscn")
	g._enter_node("0-0")
	await _frames(10)
	var start: Vector3 = g.hero.global_position
	Input.action_press("move_forward")
	await _physics(30)
	Input.action_release("move_forward")
	check(g.hero.global_position.distance_to(start) > 1.0, "WASD moves the hero (%.2f m)" % g.hero.global_position.distance_to(start))
	Input.action_press("attack")
	await _physics(3)
	Input.action_release("attack")
	# A fired shot starts the attack cooldown (the arrow itself may already have landed).
	check(g.sim.hero.attack_cd > 0.0, "attack fires arrows")
	Input.action_press("dodge")
	await _physics(2)
	Input.action_release("dodge")
	check(g.sim.hero.dodge_cd > 0.0, "dodge used")
	# Select slot 1 (arrow tower): the ghost appears under the crosshair.
	Input.action_press("slot_1")
	await _frames(2)
	Input.action_release("slot_1")
	check(g.build.selected == "arrow", "slot key selects a structure")
	check(g.hero.attack_blocked, "attack placement instead of shooting while building")
	Input.action_press("cancel")
	await _frames(2)
	Input.action_release("cancel")
	check(g.build.selected == "", "right click cancels")
	# Abilities aim while held (preview visible, nothing cast) and fire on release.
	Input.action_press("ability_1")
	await _physics(3)
	check(g.hero._rain_preview.visible and g.sim.hero.rain_cd <= 0.0, "holding Q shows the rain area")
	Input.action_release("ability_1")
	await _physics(2)
	check(g.sim.hero.rain_cd > 0.0 and not g.hero._rain_preview.visible, "releasing Q casts the rain")
	# Gamepad: d-pad cycles the hotbar, prompts follow the last device.
	Input.action_press("slot_next")
	await _frames(2)
	Input.action_release("slot_next")
	check(g.build.selected == "arrow", "d-pad right selects the first structure")
	Input.action_press("slot_prev")
	await _frames(2)
	Input.action_release("slot_prev")
	check(g.build.selected == "", "d-pad left past the start deselects")
	var settings: Node = get_tree().root.get_node("Settings")
	settings.using_pad = true
	check(settings.action_label("attack") == "RT" and settings.action_label("dodge") == "A", "pad prompts")
	settings.using_pad = false
	check(InputMap.has_action("look_left") and Settings.event_from_string("axis:5:+") is InputEventJoypadMotion, "pad bindings")
	Input.action_press("start_wave")
	await _frames(2)
	Input.action_release("start_wave")
	check(g.phase == "wave", "start wave key")
	g._set_paused(true)
	check(not g.hero.input_enabled, "no hero input behind the pause menu")
	g._set_paused(false)
	check(g.hero.input_enabled, "input back after resuming")
	g.queue_free()
	await _frames(2)


func test_warrior_in_battle() -> void:
	var profile: Node = get_tree().root.get_node("Profile")
	profile.active_run = RunState.create(98, "warrior", [], [])
	var g := await _open("res://scenes/game.tscn")
	g._enter_node("0-0")
	await _frames(10)
	check(g.hero.hero_id == "warrior", "warrior model")
	Input.action_press("attack")
	await _physics(3)
	Input.action_release("attack")
	check(g.sim.hero.attack_cd > 0.0, "sword swing")
	Input.action_press("ability_1")
	await _physics(3)
	check(g.hero._rain_preview.visible, "slam radius preview")
	Input.action_release("ability_1")
	await _physics(2)
	check(g.sim.hero.rain_cd > 0.0, "slam cast")
	var start: Vector3 = g.hero.global_position
	Input.action_press("ability_2")
	await _physics(2)
	Input.action_release("ability_2")
	await _physics(20)
	check(g.sim.hero.blast_cd > 0.0 and g.hero.global_position.distance_to(start) > 3.0, "charge dashes forward")
	g.queue_free()
	await _frames(2)


func test_mage_in_battle() -> void:
	var profile: Node = get_tree().root.get_node("Profile")
	profile.active_run = RunState.create(97, "mage", [], [])
	var g := await _open("res://scenes/game.tscn")
	g._enter_node("0-0")
	await _frames(10)
	check(g.hero.hero_id == "mage", "mage model")
	Input.action_press("attack")
	await _physics(3)
	Input.action_release("attack")
	check(g.sim.hero.attack_cd > 0.0, "fire bolt")
	Input.action_press("ability_1")
	await _physics(3)
	check(g.hero._rain_preview.visible, "nova area preview")
	Input.action_release("ability_1")
	await _physics(2)
	check(g.sim.hero.rain_cd > 0.0, "nova cast")
	g.queue_free()
	await _frames(2)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
