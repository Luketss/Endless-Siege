extends Node3D
## Game scene: owns the battlefield, hero, camera, HUD and overlays, and drives the
## journey: journey map -> encounter (build phase / waves) -> rewards -> ... -> boss.

const STEP := 1.0 / 60.0
const SPEEDS := [1.0, 1.5, 2.0]

var run: RunState
var map: MapDef
var sim: BattleSim
var view: BattleView
var hero: HeroController
var rig: CameraRig
var build: BuildController
var hud: HUD
var ui_layer: CanvasLayer
var overlay: Control
var sun: DirectionalLight3D

var node: Dictionary = {}
var waves: Array = []
var wave_index := 0
var phase := "idle"  # idle | build | wave | done
var speed_index := 0
var _acc := 0.0
var _paused := false
var _tutorial_step := -1


func _ready() -> void:
	run = Profile.active_run
	if run == null:
		run = Profile.load_saved_run()
	if run == null:
		run = Profile.new_run([])
	map = MapDef.from_dict(DataDB.map(run.map_id))
	var refs := WorldBuilder.build(self, map, Settings.get_value("shadows"))
	for c in get_children():
		if c is DirectionalLight3D:
			sun = c
	view = BattleView.new()
	add_child(view)
	view.core_node = refs.core
	view.apply_settings()
	hero = HeroController.new()
	add_child(hero)
	rig = CameraRig.new()
	add_child(rig)
	rig.target = hero
	hero.rig = rig
	build = BuildController.new()
	add_child(build)
	build.rig = rig
	build.view = view
	build.message.connect(func(t, ok): hud.toast(t, UITheme.GOOD if ok else UITheme.BAD))
	ui_layer = CanvasLayer.new()
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)
	hud = HUD.new()
	ui_layer.add_child(hud)
	Settings.changed.connect(_on_settings_changed)
	_bind_display_sim()
	if run.finished:
		_finish_run()
	else:
		_show_journey()


func _on_settings_changed() -> void:
	view.apply_settings()
	if sun:
		sun.shadow_enabled = Settings.get_value("shadows")


## Builds a sim reflecting the run (defences) to show while on the journey map.
func _bind_display_sim() -> void:
	sim = RunFlow.make_sim(run)
	view.bind(sim)
	hero.sim = sim
	hero.place_at_spawn()
	build.sim = sim
	hud.build_hotbar(build.slots())
	hud.visible = false


# ================================================================ journey

func _show_journey() -> void:
	phase = "idle"
	Profile.save_run(run)
	_set_overlay(null)
	hud.visible = false
	hero.input_enabled = false
	rig.overview = true
	rig.overview_center = Vector3(0, 0, 0)
	rig.set_captured(false)
	Music.set_intensity(0.0)
	var jp := JourneyPanel.new()
	jp.setup(run)
	jp.node_chosen.connect(_enter_node)
	jp.save_and_quit.connect(func():
		Profile.save_run(run)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_set_overlay(jp)


func _enter_node(id: String) -> void:
	node = RunFlow.enter(run, id)
	if node.is_empty():
		return
	match node.type:
		"combat", "elite", "boss":
			_start_encounter()
		"shop":
			var offer := RunFlow.shop_offer(run, node)
			_set_overlay(Panels.shop(run, offer, func(): pass, _show_journey))
		"rest":
			var heal := run.core_max() * float(DataDB.balance().rest_heal_pct)
			_set_overlay(Panels.dialog(tr("NODE_REST"), tr("REST_TEXT") % int(heal), [
				{"text": tr("REST_DO"), "callback": func():
					RunFlow.rest(run)
					Sfx.play("upgrade")
					_show_journey()},
			]))
		"event":
			_show_event(RunFlow.pick_event(run, node))


func _show_event(ev_id: String) -> void:
	var ev: Dictionary = DataDB.events()[ev_id]
	var options := []
	for i in ev.choices.size():
		var choice: Dictionary = ev.choices[i]
		var idx: int = i
		options.append({"text": tr(choice.key) + Panels.cost_text(choice), "disabled": not RunFlow.can_afford(run, choice),
			"callback": func(): _resolve_event(ev_id, idx)})
	_set_overlay(Panels.dialog(tr(ev.title_key), tr(ev.text_key), options))


func _resolve_event(ev_id: String, idx: int) -> void:
	var res := RunFlow.apply_event(run, node, ev_id, idx)
	var lines := []
	if res.has("result"):
		lines.append(tr(res.result))
	if int(res.get("gold", 0)) > 0:
		lines.append("◆ +%d" % int(res.gold))
	if float(res.get("core_hp", 0.0)) > 0.0:
		lines.append("%s +%d" % [tr("HUD_CORE"), int(res.core_hp)])
	if run.harder_next > 0.0:
		lines.append(tr("EV_HARDER"))
	var ups: Array = res.get("upgrade_choices", [])
	if not ups.is_empty():
		_show_reward(ups, tr("REWARD_TITLE"), false)
	elif lines.is_empty():
		_show_journey()
	else:
		_set_overlay(Panels.dialog(tr("EV_RESULT"), "\n".join(lines), [{"text": tr("CONTINUE"), "callback": _show_journey}]))


func _show_reward(choices: Array, title: String, allow_skip: bool = true) -> void:
	rig.set_captured(false)
	var skip_gold := 30 + 5 * run.depth()
	var on_skip := func():
		run.gold += skip_gold
		RunFlow.record_reward(run, choices, "")
		_after_reward()
	_set_overlay(Panels.reward(choices, run.mods(), title, func(id):
		RunFlow.record_reward(run, choices, id)
		Sfx.play("synergy")
		_after_reward(), on_skip if allow_skip else Callable(), skip_gold))


func _after_reward() -> void:
	_bind_display_sim()
	_show_journey()


# ================================================================ encounters

func _start_encounter() -> void:
	_set_overlay(null)
	sim = RunFlow.make_sim(run)
	view.bind(sim)
	hero.sim = sim
	hero.place_at_spawn()
	build.sim = sim
	build.cancel()
	hud.build_hotbar(build.slots())
	hud.visible = true
	waves = RunFlow.waves_for(run, node)
	wave_index = 0
	phase = "build"
	rig.overview = false
	rig.yaw = PI
	rig.pitch = -0.45
	rig.set_captured(true)
	hero.input_enabled = true
	Music.set_intensity(0.15)
	hud.toast(Texts.node_name(node.type), UITheme.NODE_COLORS[node.type])
	if not bool(Profile.data.get("seen_tutorial", false)):
		_tutorial_step = 0
		_tutorial()


func _tutorial() -> void:
	var steps := ["TUT_1", "TUT_2", "TUT_3", "TUT_4"]
	if _tutorial_step < 0 or _tutorial_step >= steps.size():
		Profile.data.seen_tutorial = true
		Profile.save()
		_tutorial_step = -1
		return
	var text := tr(steps[_tutorial_step])
	if _tutorial_step == 1:
		text = text % Settings.action_label("slot_1")
	elif _tutorial_step == 2:
		text = text % Settings.action_label("start_wave")
	hud.toast(text, UITheme.GOLD)
	_tutorial_step += 1
	get_tree().create_timer(3.2).timeout.connect(_tutorial)


func _process(delta: float) -> void:
	if phase == "idle" or phase == "done" or sim == null:
		return
	_handle_input()
	if not _paused:
		_acc += minf(delta, 0.1) * SPEEDS[speed_index]
		var steps := 0
		while _acc >= STEP and steps < 12:
			sim.step(STEP)
			_acc -= STEP
			steps += 1
		for e in sim.pop_events():
			_on_event(e)
	hero.attack_blocked = build.is_building()
	build.update(not _paused and phase != "done")
	hud.refresh(sim, {"title": "%s · %s" % [Texts.node_name(node.get("type", "combat")), tr(map.name_key)],
		"wave": wave_index, "waves": waves.size(), "phase": phase, "speed": SPEEDS[speed_index],
		"captured": rig.is_captured()}, build)
	var intensity := 0.15
	if phase == "wave":
		intensity = 0.4 + minf(0.6, (sim.enemies.size() + sim.spawn_queue.size()) / 40.0)
		for e: Units.Enemy in sim.enemies:
			if e.boss:
				intensity = 1.0
	Music.set_intensity(intensity)


func _handle_input() -> void:
	if Input.is_action_just_pressed("pause"):
		if build.is_building():
			build.cancel()
		else:
			_set_paused(not _paused)
		return
	if _paused:
		return
	if Input.is_action_just_pressed("start_wave") and phase == "build":
		_start_wave()
	for i in 7:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)):
			build.select_slot(i)
	if Input.is_action_just_pressed("show_ranges"):
		view.show_all_ranges = not view.show_all_ranges
	if Input.is_action_just_pressed("game_speed"):
		speed_index = (speed_index + 1) % SPEEDS.size()
		hud.toast("%s x%.1f" % [tr("HUD_SPEED"), SPEEDS[speed_index]])
	if not rig.is_captured() and overlay == null and Input.is_action_just_pressed("attack"):
		rig.set_captured(true)


func _start_wave() -> void:
	if wave_index >= waves.size():
		return
	sim.start_wave(waves[wave_index])
	phase = "wave"
	Sfx.play("wave_start")
	hud.toast(tr("HUD_WAVE_START") % (wave_index + 1), UITheme.BAD)


func _on_event(e: Dictionary) -> void:
	view.handle_event(e)
	match e.type:
		"wave_cleared":
			wave_index += 1
			Sfx.play("wave_clear")
			hud.toast(tr("HUD_WAVE_CLEARED") % int(e.gold), UITheme.GOOD)
			if wave_index >= waves.size():
				_encounter_won()
			else:
				phase = "build"
				hud.toast(tr("HUD_CACHE_HINT"), UITheme.GOLD)
		"defeat":
			_encounter_lost()
		"boss_phase":
			hud.toast(tr("HUD_BOSS_PHASE") % (int(e.phase) + 1), Color("ff7a2a"))
		"level_up":
			hud.toast(tr("HUD_LEVEL_UP") % int(e.level), Color("b26bff"))
		"hero_down":
			hud.toast(tr("HUD_HERO_DOWN"), UITheme.BAD)
		"leak":
			if sim.core_hp < sim.core_max * 0.3:
				hud.toast(tr("HUD_CORE_LOW"), UITheme.BAD)


func _encounter_won() -> void:
	phase = "done"
	RunFlow.finish_combat(run, sim, node, wave_index)
	hero.input_enabled = false
	build.cancel()
	if run.finished:
		Sfx.play("victory")
		get_tree().create_timer(2.0).timeout.connect(_finish_run)
		return
	var choices := RunFlow.reward_choices(run, node)
	get_tree().create_timer(1.2).timeout.connect(func():
		hud.visible = false
		if choices.is_empty():
			_after_reward()
		else:
			_show_reward(choices, tr("REWARD_TITLE_ELITE") if node.type == "elite" else tr("REWARD_TITLE")))


func _encounter_lost() -> void:
	phase = "done"
	RunFlow.finish_combat(run, sim, node, wave_index)
	hero.input_enabled = false
	Sfx.play("defeat")
	hud.toast(tr("HUD_CORE_DESTROYED"), UITheme.BAD)
	get_tree().create_timer(2.5).timeout.connect(_finish_run)


func _finish_run() -> void:
	var essence := Profile.finish_run(run)
	Profile.set_meta("last_run", run)
	Profile.set_meta("last_essence", essence)
	rig.set_captured(false)
	get_tree().change_scene_to_file("res://scenes/result.tscn")


# ================================================================ pause / overlays

func _set_paused(v: bool) -> void:
	_paused = v
	if v:
		rig.set_captured(false)
		_set_overlay(_pause_menu())
	else:
		_set_overlay(null)
		rig.set_captured(true)


func _pause_menu() -> Control:
	var options := [
		{"text": tr("PAUSE_RESUME"), "callback": func(): _set_paused(false)},
		{"text": tr("MENU_SETTINGS"), "callback": func():
			var s := SettingsPanel.new()
			ui_layer.add_child(s)},
		{"text": tr("PAUSE_CONTROLS"), "callback": func():
			var s := Panels.dialog(tr("PAUSE_CONTROLS"), _controls_text(), [{"text": tr("BACK"), "callback": func(): _set_overlay(_pause_menu())}])
			_set_overlay(s)},
		{"text": tr("PAUSE_ABANDON"), "callback": func():
			_paused = false
			run.finished = true
			run.victory = false
			_finish_run()},
		{"text": tr("PAUSE_MENU_SAVE"), "callback": func():
			# Saving mid-battle restores the run at the start of this encounter.
			_paused = false
			run.visited.pop_back()
			run.current_node = run.visited.back() if not run.visited.is_empty() else ""
			Profile.save_run(run)
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")},
	]
	return Panels.dialog(tr("PAUSE_TITLE"), tr("PAUSE_SUB"), options)


func _controls_text() -> String:
	var lines := []
	for a in ["move_forward", "attack", "ability_1", "ability_2", "dodge", "interact", "slot_1", "start_wave", "upgrade", "sell", "target_mode", "show_ranges", "game_speed"]:
		lines.append("[b]%s[/b] — %s" % [Settings.action_label(a), tr("ACTION_" + a.to_upper())])
	lines.append("[b]RMB/Esc[/b] — %s" % tr("ACTION_CANCEL"))
	return "\n".join(lines)


func _set_overlay(c: Control) -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = c
	if c:
		ui_layer.add_child(c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase in ["build", "wave"] and not _paused:
		_set_paused(true)
