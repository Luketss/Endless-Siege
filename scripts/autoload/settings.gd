extends Node
## Player settings (video, audio, controls, gameplay) persisted in user://settings.json.
## Also owns the input map: default bindings live here and user remaps are applied on top.

signal changed

const PATH := "user://settings.json"

## action -> list of default events: "key:W", "mouse:1" (left), "mouse:2" (right), "wheel_up", ...
const DEFAULT_BINDINGS := {
	"move_forward": ["key:W"], "move_back": ["key:S"], "move_left": ["key:A"], "move_right": ["key:D"],
	"attack": ["mouse:1"], "cancel": ["mouse:2"], "ability_1": ["key:Q"], "ability_2": ["key:E"],
	"dodge": ["key:Space"], "interact": ["key:F"], "start_wave": ["key:G"],
	"upgrade": ["key:U"], "sell": ["key:X"], "target_mode": ["key:Y"], "show_ranges": ["key:Tab"],
	"game_speed": ["key:T"], "pause": ["key:Escape"],
	"slot_1": ["key:1"], "slot_2": ["key:2"], "slot_3": ["key:3"], "slot_4": ["key:4"],
	"slot_5": ["key:5"], "slot_6": ["key:6"], "slot_7": ["key:7"],
	"zoom_in": ["wheel_up"], "zoom_out": ["wheel_down"],
}
## Gamepad layout (Xbox naming; Steam Input maps other pads onto it). Always active
## alongside the keyboard bindings; not remappable in game (Steam Input covers that).
const PAD_BINDINGS := {
	"move_forward": ["axis:1:-"], "move_back": ["axis:1:+"], "move_left": ["axis:0:-"], "move_right": ["axis:0:+"],
	"look_up": ["axis:3:-"], "look_down": ["axis:3:+"], "look_left": ["axis:2:-"], "look_right": ["axis:2:+"],
	"attack": ["axis:5:+"], "cancel": ["joy:1"], "dodge": ["joy:0"], "interact": ["joy:2"], "start_wave": ["joy:3"],
	"ability_1": ["joy:9"], "ability_2": ["joy:10"], "upgrade": ["joy:11"], "sell": ["joy:12"],
	"slot_prev": ["joy:13"], "slot_next": ["joy:14"], "target_mode": ["joy:8"], "game_speed": ["joy:7"],
	"show_ranges": ["joy:4"], "pause": ["joy:6"],
}
const PAD_NAMES := {"joy:0": "A", "joy:1": "B", "joy:2": "X", "joy:3": "Y", "joy:4": "View", "joy:6": "Menu",
	"joy:7": "L3", "joy:8": "R3", "joy:9": "LB", "joy:10": "RB", "joy:11": "D↑", "joy:12": "D↓",
	"joy:13": "D←", "joy:14": "D→", "axis:5:+": "RT"}
## Actions shown in the remapping screen, in order.
const REMAPPABLE := ["move_forward", "move_back", "move_left", "move_right", "attack", "ability_1", "ability_2",
	"dodge", "interact", "start_wave", "upgrade", "sell", "target_mode", "show_ranges", "game_speed",
	"slot_1", "slot_2", "slot_3", "slot_4", "slot_5", "slot_6", "slot_7"]

const DEFAULTS := {
	"window_mode": "windowed",  # windowed | fullscreen | borderless
	"resolution": [1600, 900],
	"vsync": true,
	"max_fps": 0,
	"ui_scale": 1.0,
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"effects_quality": "high",  # high | low
	"damage_numbers": true,
	"screen_shake": true,
	"shadows": true,
	"mouse_sensitivity": 1.0,
	"invert_y": false,
	"language": "auto",
	"run_log": true,
	"bindings": {},
}

var data: Dictionary = {}
## True while the last input came from a gamepad (prompts switch to pad buttons).
var using_pad := false

signal device_changed


func _ready() -> void:
	_ensure_buses()
	data = DEFAULTS.duplicate(true)
	var loaded: Dictionary = SafeStore.read(PATH, DEFAULTS).data
	for k in loaded:
		data[k] = loaded[k]
	apply_all()


func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 4.0):
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit()


func get_value(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant, save_now: bool = true) -> void:
	data[key] = value
	apply_all()
	if save_now:
		save()
	changed.emit()


func save() -> void:
	SafeStore.save(PATH, data)


func apply_all() -> void:
	_apply_language()
	_apply_audio()
	_apply_input()
	if DisplayServer.get_name() != "headless":
		_apply_video()


func _apply_language() -> void:
	var lang: String = data.language
	if lang == "auto":
		lang = "pt" if OS.get_locale_language() == "pt" else "en"
	TranslationServer.set_locale(lang)


func _ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(data.master_volume))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(data.music_volume))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(data.sfx_volume))))


func _apply_video() -> void:
	var win := get_window()
	match data.window_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen := DisplayServer.window_get_current_screen()
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var res: Array = data.resolution
			DisplayServer.window_set_size(Vector2i(int(res[0]), int(res[1])))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(data.max_fps)
	win.content_scale_factor = float(data.ui_scale)


# ---------------------------------------------------------------- input

static func event_from_string(s: String) -> InputEvent:
	if s.begins_with("key:"):
		var e := InputEventKey.new()
		e.physical_keycode = OS.find_keycode_from_string(s.substr(4))
		return e
	if s.begins_with("mouse:"):
		var m := InputEventMouseButton.new()
		m.button_index = int(s.substr(6)) as MouseButton
		return m
	if s.begins_with("joy:"):
		var j := InputEventJoypadButton.new()
		j.button_index = int(s.substr(4)) as JoyButton
		return j
	if s.begins_with("axis:"):
		var parts := s.split(":")
		var a := InputEventJoypadMotion.new()
		a.axis = int(parts[1]) as JoyAxis
		a.axis_value = -1.0 if parts[2] == "-" else 1.0
		return a
	if s == "wheel_up" or s == "wheel_down":
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_UP if s == "wheel_up" else MOUSE_BUTTON_WHEEL_DOWN
		return w
	return null


static func event_to_string(e: InputEvent) -> String:
	if e is InputEventKey:
		var code: Key = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		return "key:" + OS.get_keycode_string(code)
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				return "wheel_up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "wheel_down"
		return "mouse:%d" % e.button_index
	return ""


static func display_name(s: String) -> String:
	if s.begins_with("key:"):
		return s.substr(4)
	match s:
		"mouse:1":
			return "LMB"
		"mouse:2":
			return "RMB"
		"mouse:3":
			return "MMB"
		"wheel_up":
			return "Wheel↑"
		"wheel_down":
			return "Wheel↓"
	return s.replace("mouse:", "Mouse ")


func bindings_for(action: String) -> Array:
	var custom: Dictionary = data.get("bindings", {})
	return custom.get(action, DEFAULT_BINDINGS.get(action, []))


func rebind(action: String, event: InputEvent) -> void:
	var s := event_to_string(event)
	if s == "":
		return
	var custom: Dictionary = data.get("bindings", {}).duplicate()
	# A key can only do one thing: remove it from other remappable actions.
	for other in REMAPPABLE:
		if other != action and bindings_for(other).has(s):
			var list: Array = bindings_for(other).duplicate()
			list.erase(s)
			custom[other] = list
	custom[action] = [s]
	set_value("bindings", custom)


func reset_bindings() -> void:
	set_value("bindings", {})


func _apply_input() -> void:
	var actions := DEFAULT_BINDINGS.keys()
	for a in PAD_BINDINGS:
		if not actions.has(a):
			actions.append(a)
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		InputMap.action_erase_events(action)
		for s in bindings_for(action) + PAD_BINDINGS.get(action, []):
			var e := event_from_string(s)
			if e:
				InputMap.action_add_event(action, e)


func action_label(action: String) -> String:
	if using_pad:
		var pad: Array = PAD_BINDINGS.get(action, [])
		return PAD_NAMES.get(pad[0], "—") if not pad.is_empty() else ""
	var list := bindings_for(action)
	return display_name(list[0]) if not list.is_empty() else "—"
