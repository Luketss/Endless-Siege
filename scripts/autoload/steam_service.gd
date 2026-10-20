extends Node
## Optional Steamworks bridge. Uses the GodotSteam GDExtension when it is installed and
## the Steam client is running; otherwise every call is a silent no-op, so the game
## works offline, in the editor and in DRM-free builds. Achievement ids are the keys
## of data/achievements.json (create the same API names in Steamworks).

var steam: Object = null
var enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	var res = steam.call("steamInitEx")
	# GodotSteam returns {"status": 0} (or true on older builds) when Steam is ready.
	enabled = (res is Dictionary and int(res.get("status", 1)) == 0) or (res is bool and res)
	if not enabled:
		push_warning("Steam not available: %s" % [res])
		return
	# Catch up achievements earned while offline.
	for id in Profile.data.get("achievements", []):
		unlock(id, false)
	steam.call("storeStats")


func _process(_delta: float) -> void:
	if enabled:
		steam.call("run_callbacks")


func unlock(id: String, store: bool = true) -> void:
	if not enabled:
		return
	steam.call("setAchievement", id)
	if store:
		steam.call("storeStats")


## Rich presence line shown to friends, e.g. ("steam_display", "#InBattle").
func presence(key: String, value: String) -> void:
	if enabled:
		steam.call("setRichPresence", key, value)
