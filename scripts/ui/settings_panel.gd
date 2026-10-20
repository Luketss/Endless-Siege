class_name SettingsPanel
extends Control
## Settings with tabs: video, audio, controls (with key remapping) and game.

signal closed

var _waiting_action := ""
var _bind_buttons := {}


func _ready() -> void:
	theme = UITheme.get_theme()
	UITheme.full_rect(self)
	add_child(UITheme.dimmer())
	var center := CenterContainer.new()
	UITheme.full_rect(center)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 700)
	center.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UITheme.label(tr("MENU_SETTINGS"), "Header"))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_video_tab())
	tabs.add_child(_audio_tab())
	tabs.add_child(_controls_tab())
	tabs.add_child(_game_tab())
	var close := UITheme.button(tr("BACK"), true)
	close.pressed.connect(func():
		closed.emit()
		queue_free())
	v.add_child(close)


func _row(parent: Control, text: String, control: Control) -> void:
	var h := HBoxContainer.new()
	var l := UITheme.label(text)
	l.custom_minimum_size = Vector2(340, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	parent.add_child(h)


func _option(items: Array, current: Variant, on_select: Callable) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(str(items[i][1]), i)
		if items[i][0] == current:
			o.select(i)
	o.item_selected.connect(func(i): on_select.call(items[i][0]))
	return o


func _check(key: String) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = Settings.get_value(key)
	c.toggled.connect(func(on): Settings.set_value(key, on))
	return c


func _slider(key: String, min_v: float, max_v: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = float(Settings.get_value(key))
	s.custom_minimum_size = Vector2(300, 30)
	s.value_changed.connect(func(val): Settings.set_value(key, val, false))
	s.drag_ended.connect(func(_c): Settings.save())
	return s


func _tab(name_key: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = tr(name_key)
	return v


func _video_tab() -> Control:
	var v := _tab("SET_VIDEO")
	_row(v, tr("SET_WINDOW"), _option([["windowed", tr("SET_WINDOWED")], ["borderless", tr("SET_BORDERLESS")], ["fullscreen", tr("SET_FULLSCREEN")]],
		Settings.get_value("window_mode"), func(val): Settings.set_value("window_mode", val)))
	var res := [[[1280, 720], "1280×720"], [[1600, 900], "1600×900"], [[1920, 1080], "1920×1080"], [[2560, 1440], "2560×1440"], [[3840, 2160], "3840×2160"]]
	_row(v, tr("SET_RESOLUTION"), _option(res, Settings.get_value("resolution"), func(val): Settings.set_value("resolution", val)))
	_row(v, tr("SET_VSYNC"), _check("vsync"))
	_row(v, tr("SET_MAX_FPS"), _option([[0, tr("SET_UNLIMITED")], [30, "30"], [60, "60"], [120, "120"], [144, "144"]],
		int(Settings.get_value("max_fps")), func(val): Settings.set_value("max_fps", val)))
	_row(v, tr("SET_UI_SCALE"), _slider("ui_scale", 0.75, 1.5, 0.05))
	_row(v, tr("SET_SHADOWS"), _check("shadows"))
	_row(v, tr("SET_EFFECTS"), _option([["high", tr("SET_HIGH")], ["low", tr("SET_LOW")]],
		Settings.get_value("effects_quality"), func(val): Settings.set_value("effects_quality", val)))
	return v


func _audio_tab() -> Control:
	var v := _tab("SET_AUDIO")
	_row(v, tr("SET_MASTER"), _slider("master_volume", 0.0, 1.0, 0.05))
	_row(v, tr("SET_MUSIC"), _slider("music_volume", 0.0, 1.0, 0.05))
	_row(v, tr("SET_SFX"), _slider("sfx_volume", 0.0, 1.0, 0.05))
	return v


func _controls_tab() -> Control:
	var outer := _tab("SET_CONTROLS")
	_row(outer, tr("SET_SENSITIVITY"), _slider("mouse_sensitivity", 0.2, 3.0, 0.05))
	_row(outer, tr("SET_INVERT"), _check("invert_y"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	for action in Settings.REMAPPABLE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 40)
		b.pressed.connect(func():
			_waiting_action = action
			b.text = tr("SET_PRESS_KEY"))
		_bind_buttons[action] = b
		_row(v, tr("ACTION_" + action.to_upper()), b)
	var reset := UITheme.button(tr("SET_RESET_KEYS"))
	reset.pressed.connect(func():
		Settings.reset_bindings()
		_refresh_binds())
	outer.add_child(reset)
	_refresh_binds()
	return outer


func _game_tab() -> Control:
	var v := _tab("SET_GAME")
	_row(v, tr("SET_LANGUAGE"), _option([["auto", tr("LANG_AUTO")], ["pt", "Português"], ["en", "English"]],
		Settings.get_value("language"), func(val): Settings.set_value("language", val)))
	_row(v, tr("SET_DAMAGE_NUMBERS"), _check("damage_numbers"))
	_row(v, tr("SET_SCREEN_SHAKE"), _check("screen_shake"))
	_row(v, tr("SET_RUN_LOG"), _check("run_log"))
	var hint := UITheme.label(tr("SET_RUN_LOG_HINT") % ProjectSettings.globalize_path(RunLog.PATH), "Dim")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(800, 0)
	v.add_child(hint)
	var replay := UITheme.button(tr("SET_TUTORIAL"))
	replay.pressed.connect(func():
		Profile.data.seen_tutorial = false
		Profile.save()
		replay.text = tr("SET_TUTORIAL_DONE")
		replay.disabled = true)
	v.add_child(replay)
	return v


func _refresh_binds() -> void:
	for action in _bind_buttons:
		(_bind_buttons[action] as Button).text = Settings.action_label(action)


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	var ok: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if not ok:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_waiting_action = ""
		_refresh_binds()
		return
	Settings.rebind(_waiting_action, event)
	_waiting_action = ""
	Sfx.play("ui")
	_refresh_binds()
