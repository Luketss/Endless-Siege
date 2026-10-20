extends SceneTree
## Balance report: plays whole journeys with the scripted Autopilot (no hero actions).
##   godot --headless --path . --script res://tools/balance_sim.gd
## Env: SIM_RUNS (default 12), SIM_MODS (comma separated challenge ids),
##      SIM_LOG (path: also write runs.jsonl records, readable by tools/run_report.py).
## The autopilot does not use the hero, so it is a "floor": a human should do better.


func _initialize() -> void:
	var n := int(OS.get_environment("SIM_RUNS")) if OS.get_environment("SIM_RUNS") != "" else 12
	var mods_env := OS.get_environment("SIM_MODS")
	var mods: Array = [] if mods_env == "" else Array(mods_env.split(","))
	var wins := 0
	var depth_sum := 0
	var deaths := {}
	var core_before_boss := []
	var gold_left := []
	var t0 := Time.get_ticks_msec()
	for i in n:
		var run := Autopilot.play_journey(1000 + i, ["banner", "tar", "legendary_pool"], mods)
		if OS.get_environment("SIM_LOG") != "":
			RunLog.append(run, OS.get_environment("SIM_LOG"))
		if run.victory:
			wins += 1
			core_before_boss.append(run.core_hp)
		else:
			var node := Journey.find(run.journey, run.current_node)
			var key := "%s@L%d" % [node.get("type", "?"), int(node.get("layer", 0))]
			deaths[key] = int(deaths.get(key, 0)) + 1
		depth_sum += run.depth()
		gold_left.append(run.gold)
		print("run %2d: %-7s layer %d  waves %2d  kills %4d  upgrades %d  core %.0f" % [i, "WIN" if run.victory else "LOSS",
			run.depth(), int(run.stats.waves), int(run.stats.kills), run.upgrades.size(), run.core_hp])
	print("\nwin rate: %d/%d (%.0f%%)   avg layer reached: %.1f / 6" % [wins, n, 100.0 * wins / n, float(depth_sum) / n])
	print("losses by encounter: ", deaths)
	print("simulated in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()
