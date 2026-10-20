extends Node
## Permanent progression (essence, unlocks, statistics) and the saved journey in progress.

const PROFILE_PATH := "user://profile.json"
const RUN_PATH := "user://run.json"
const DEFAULTS := {
	"version": 1,
	"essence": 0,
	"essence_total": 0,
	"unlocks": [],
	"modifiers": [],
	"stats": {"runs": 0, "victories": 0, "best_layer": 0, "kills": 0, "waves": 0},
	"seen_tutorial": false,
}

var data: Dictionary = {}
var load_status: String = ""
## The journey being played (shared between the menu and the game scene).
var active_run: RunState


func _ready() -> void:
	var r := SafeStore.read(PROFILE_PATH, DEFAULTS)
	load_status = r.status
	data = DEFAULTS.duplicate(true)
	for k in r.data:
		data[k] = r.data[k]


func save() -> void:
	SafeStore.save(PROFILE_PATH, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		if active_run and not active_run.finished:
			save_run(active_run)


# ---------------------------------------------------------------- unlocks

func is_unlocked(id: String) -> bool:
	return (data.unlocks as Array).has(id)


func unlock_cost(id: String) -> int:
	return int(DataDB.unlocks().get(id, {}).get("cost", 0))


func buy_unlock(id: String) -> bool:
	if is_unlocked(id) or not DataDB.unlocks().has(id) or int(data.essence) < unlock_cost(id):
		return false
	data.essence = int(data.essence) - unlock_cost(id)
	(data.unlocks as Array).append(id)
	save()
	return true


func challenges_available() -> bool:
	return is_unlocked("challenges")


# ---------------------------------------------------------------- runs

## Heroes the player can pick: always the Ranger, others once unlocked in the Sanctuary.
func available_heroes() -> Array:
	var out := []
	for id in DataDB.heroes():
		var unlock: String = DataDB.heroes()[id].get("unlock", "")
		if unlock == "" or is_unlocked(unlock):
			out.append(id)
	return out


func new_run(modifiers: Array, hero_id: String = "ranger") -> RunState:
	var seed_value := int(Time.get_unix_time_from_system()) ^ randi()
	if not available_heroes().has(hero_id):
		hero_id = "ranger"
	active_run = RunState.create(seed_value, hero_id, modifiers, data.unlocks)
	data.stats.runs = int(data.stats.runs) + 1
	save()
	save_run(active_run)
	return active_run


func has_saved_run() -> bool:
	var r := SafeStore.read(RUN_PATH, {})
	return not r.data.is_empty() and not r.data.get("finished", true)


func load_saved_run() -> RunState:
	var r := SafeStore.read(RUN_PATH, {})
	active_run = RunState.from_dict(r.data) if not r.data.is_empty() else null
	return active_run


func save_run(run: RunState) -> void:
	SafeStore.save(RUN_PATH, run.to_dict())


func clear_run() -> void:
	SafeStore.erase(RUN_PATH)


## Records a finished journey; returns essence gained.
func finish_run(run: RunState) -> int:
	var gained := run.essence_earned()
	data.essence = int(data.essence) + gained
	data.essence_total = int(data.essence_total) + gained
	var st: Dictionary = data.stats
	if run.victory:
		st.victories = int(st.victories) + 1
	st.best_layer = maxi(int(st.best_layer), run.depth())
	st.kills = int(st.kills) + int(run.stats.kills)
	st.waves = int(st.waves) + int(run.stats.waves)
	if Settings.get_value("run_log"):
		RunLog.append(run)
	save()
	clear_run()
	return gained
