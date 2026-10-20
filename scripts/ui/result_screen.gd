extends Control
## End-of-journey summary: outcome, statistics, build, essence earned.


func _ready() -> void:
	theme = UITheme.get_theme()
	UITheme.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	UITheme.full_rect(bg)
	add_child(bg)
	var run: RunState = Profile.get_meta("last_run") if Profile.has_meta("last_run") else null
	var essence: int = Profile.get_meta("last_essence") if Profile.has_meta("last_essence") else 0
	var center := CenterContainer.new()
	UITheme.full_rect(center)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	if run == null:
		v.add_child(UITheme.label(tr("RESULT_NONE"), "Header"))
	else:
		var title := UITheme.label(tr("RESULT_VICTORY") if run.victory else tr("RESULT_DEFEAT"), "Title", HORIZONTAL_ALIGNMENT_CENTER)
		title.add_theme_color_override("font_color", UITheme.GOOD if run.victory else UITheme.BAD)
		v.add_child(title)
		v.add_child(UITheme.label(tr("RESULT_REACHED") % [run.depth() + 1, run.journey.layers.size()], "Dim", HORIZONTAL_ALIGNMENT_CENTER))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 40)
		v.add_child(h)
		var stats := RichTextLabel.new()
		stats.bbcode_enabled = true
		stats.fit_content = true
		stats.custom_minimum_size = Vector2(440, 0)
		var st: Dictionary = run.stats
		stats.text = "[color=#f2c14e]%s[/color]\n%s: %d\n%s: %d\n%s: %d\n%s: %d\n%s: %d\n%s: %s\n%s: %d" % [
			tr("RESULT_STATS"), tr("RESULT_WAVES"), int(st.waves), tr("RESULT_COMBATS"), int(st.combats),
			tr("RESULT_ELITES"), int(st.elites), tr("RESULT_KILLS"), int(st.kills), tr("RESULT_GOLD"), int(st.gold_earned),
			tr("RESULT_TIME"), Texts.time_text(float(st.time)), tr("HUD_LEVEL"), run.hero_level]
		h.add_child(stats)
		var build := RichTextLabel.new()
		build.bbcode_enabled = true
		build.fit_content = true
		build.custom_minimum_size = Vector2(440, 0)
		var txt := "[color=#f2c14e]%s[/color]\n" % tr("RESULT_BUILD")
		var mods := run.mods()
		for s in mods.active_synergies:
			txt += "[color=#c9a6ff]✦ %s[/color]\n" % Texts.synergy_name(s)
		for id in run.upgrades:
			txt += "[color=#%s]• %s[/color]\n" % [(UITheme.RARITY[DataDB.upgrade(id).rarity] as Color).to_html(false), Texts.upgrade_name(id)]
		build.text = txt
		h.add_child(build)
		var ess := UITheme.label(tr("RESULT_ESSENCE") % essence, "Header", HORIZONTAL_ALIGNMENT_CENTER)
		ess.add_theme_color_override("font_color", Color("b48cf0"))
		v.add_child(ess)
		v.add_child(UITheme.label(tr("RESULT_ESSENCE_HINT"), "Dim", HORIZONTAL_ALIGNMENT_CENTER))
		var earned: Array = Profile.get_meta("last_achievements") if Profile.has_meta("last_achievements") else []
		for id in earned:
			var a := UITheme.label("★ %s — %s" % [tr("RESULT_ACHIEVEMENT"), tr(DataDB.achievements()[id].name_key)], "", HORIZONTAL_ALIGNMENT_CENTER)
			a.add_theme_color_override("font_color", UITheme.GOLD)
			v.add_child(a)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var again := UITheme.button(tr("RESULT_AGAIN"), true, Vector2(280, 60))
	again.pressed.connect(func():
		if run:
			Profile.new_run(Profile.data.get("modifiers", []), run.hero_id, run.map_id)
		else:
			Profile.new_run(Profile.data.get("modifiers", []))
		get_tree().change_scene_to_file("res://scenes/game.tscn"))
	row.add_child(again)
	var menu := UITheme.button(tr("RESULT_MENU"), false, Vector2(280, 60))
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(menu)
	Sfx.play("victory" if run and run.victory else "ui")
