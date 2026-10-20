extends Node3D
## Main menu over a slowly orbiting view of the battlefield.
## Pages: home, new journey (hero + challenges), sanctuary (permanent unlocks), settings.

var ui: Control
var _pages := {}
var _modifiers: Array = []
var _rig: CameraRig


func _ready() -> void:
	var map := MapDef.from_dict(DataDB.map("forest"))
	WorldBuilder.build(self, map, Settings.get_value("shadows"))
	_rig = CameraRig.new()
	add_child(_rig)
	_rig.overview = true
	_rig.set_captured(false)
	Music.set_intensity(0.0)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.theme = UITheme.get_theme()
	UITheme.full_rect(ui)
	layer.add_child(ui)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.45)
	UITheme.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	_modifiers = (Profile.data.get("modifiers", []) as Array).duplicate()
	_build()
	_show("home")
	if Profile.load_status == SafeStore.STATUS_RECOVERED:
		_notice(tr("SAVE_RECOVERED"))
	elif Profile.load_status == SafeStore.STATUS_RESET:
		_notice(tr("SAVE_RESET"))


func _notice(text: String) -> void:
	var l := UITheme.label(text, "", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", UITheme.GOLD)
	ui.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.position.y -= 40


func _build() -> void:
	for p in _pages.values():
		p.queue_free()
	_pages.clear()
	_pages.home = _home()
	_pages.new_run = _new_run_page()
	_pages.sanctuary = _sanctuary()
	for p in _pages.values():
		ui.add_child(p)


func _show(page: String) -> void:
	for k in _pages:
		_pages[k].visible = k == page


func _left_column() -> VBoxContainer:
	var m := MarginContainer.new()
	UITheme.full_rect(m)
	m.add_theme_constant_override("margin_left", 110)
	m.add_theme_constant_override("margin_top", 90)
	m.add_theme_constant_override("margin_bottom", 90)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_theme_constant_override("separation", 16)
	m.add_child(v)
	var holder := Control.new()
	UITheme.full_rect(holder)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(m)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("column", v)
	return holder


func _home() -> Control:
	var holder := _left_column()
	var v: VBoxContainer = holder.get_meta("column")
	v.add_child(UITheme.label("Endless Siege", "Title"))
	v.add_child(UITheme.label(tr("MENU_TAGLINE"), "Dim"))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	v.add_child(spacer)
	if Profile.has_saved_run():
		var cont := UITheme.button(tr("MENU_CONTINUE"), true, Vector2(0, 64))
		cont.pressed.connect(func():
			if Profile.load_saved_run():
				get_tree().change_scene_to_file("res://scenes/game.tscn"))
		v.add_child(cont)
	var new := UITheme.button(tr("MENU_NEW_RUN"), not Profile.has_saved_run(), Vector2(0, 64))
	new.pressed.connect(func(): _show("new_run"))
	v.add_child(new)
	var sanct := UITheme.button(tr("MENU_SANCTUARY") + "  ◈ %d" % int(Profile.data.essence), false, Vector2(0, 56))
	sanct.pressed.connect(func(): _show("sanctuary"))
	v.add_child(sanct)
	var settings := UITheme.button(tr("MENU_SETTINGS"), false, Vector2(0, 56))
	settings.pressed.connect(func():
		var s := SettingsPanel.new()
		s.closed.connect(_build_and_home)
		ui.add_child(s))
	v.add_child(settings)
	var quit := UITheme.button(tr("MENU_QUIT"), false, Vector2(0, 56))
	quit.pressed.connect(func(): get_tree().quit())
	v.add_child(quit)
	var st: Dictionary = Profile.data.stats
	v.add_child(UITheme.label(tr("MENU_STATS") % [int(st.runs), int(st.victories), int(st.best_layer) + 1, int(st.kills)], "Dim"))
	v.add_child(UITheme.label("v" + str(ProjectSettings.get_setting("application/config/version")), "Small"))
	return holder


func _build_and_home() -> void:
	_build()
	_show("home")


func _new_run_page() -> Control:
	var holder := _left_column()
	var v: VBoxContainer = holder.get_meta("column")
	v.add_child(UITheme.label(tr("MENU_NEW_RUN"), "Header"))
	v.add_child(UITheme.label(tr("MENU_CHOOSE_HERO"), "Dim"))
	var hero := PanelContainer.new()
	var hv := VBoxContainer.new()
	hero.add_child(hv)
	hv.add_child(UITheme.label(tr("H_RANGER"), "Header"))
	var d := RichTextLabel.new()
	d.bbcode_enabled = true
	d.fit_content = true
	d.custom_minimum_size = Vector2(480, 0)
	d.text = tr("H_RANGER_DESC")
	hv.add_child(d)
	v.add_child(hero)
	if Profile.challenges_available():
		v.add_child(UITheme.label(tr("MENU_CHALLENGES"), "Header"))
		for mid in DataDB.modifiers():
			var mod: Dictionary = DataDB.modifiers()[mid]
			var c := CheckButton.new()
			c.text = "%s  (+%d%% ◈)" % [tr(mod.name_key), int(float(mod.essence) * 100)]
			c.tooltip_text = tr(mod.name_key + "_DESC")
			c.button_pressed = _modifiers.has(mid)
			c.toggled.connect(func(on):
				if on and not _modifiers.has(mid):
					_modifiers.append(mid)
				elif not on:
					_modifiers.erase(mid))
			v.add_child(c)
	else:
		v.add_child(UITheme.label(tr("MENU_CHALLENGES_LOCKED"), "Dim"))
	var start := UITheme.button(tr("MENU_START"), true, Vector2(0, 64))
	start.pressed.connect(func():
		Profile.data.modifiers = _modifiers.duplicate()
		Profile.clear_run()
		Profile.new_run(_modifiers)
		get_tree().change_scene_to_file("res://scenes/game.tscn"))
	v.add_child(start)
	var back := UITheme.button(tr("BACK"))
	back.pressed.connect(func(): _show("home"))
	v.add_child(back)
	return holder


func _sanctuary() -> Control:
	var holder := _left_column()
	var v: VBoxContainer = holder.get_meta("column")
	v.custom_minimum_size = Vector2(640, 0)
	v.add_child(UITheme.label(tr("MENU_SANCTUARY"), "Header"))
	var ess := UITheme.label(tr("SANCT_ESSENCE") % int(Profile.data.essence), "")
	ess.add_theme_color_override("font_color", Color("b48cf0"))
	ess.add_theme_font_size_override("font_size", 28)
	v.add_child(ess)
	v.add_child(UITheme.label(tr("SANCT_SUB"), "Dim"))
	for uid in DataDB.unlocks():
		var u: Dictionary = DataDB.unlocks()[uid]
		var row := PanelContainer.new()
		var h := HBoxContainer.new()
		row.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UITheme.label(tr(u.name_key), "Header"))
		var desc := UITheme.label(tr("UNL_" + uid.to_upper() + "_DESC"), "Dim")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(380, 0)
		info.add_child(desc)
		h.add_child(info)
		var b := UITheme.button("", false, Vector2(150, 52))
		if Profile.is_unlocked(uid):
			b.text = tr("SANCT_OWNED")
			b.disabled = true
		else:
			b.text = "◈ %d" % int(u.cost)
			b.disabled = int(Profile.data.essence) < int(u.cost)
			b.pressed.connect(func():
				if Profile.buy_unlock(uid):
					Sfx.play("upgrade")
					_build()
					_show("sanctuary"))
		h.add_child(b)
		v.add_child(row)
	var back := UITheme.button(tr("BACK"))
	back.pressed.connect(func(): _build_and_home())
	v.add_child(back)
	return holder
