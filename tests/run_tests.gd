extends SceneTree
## Headless test runner:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 1 when any test fails.

const SUITES := [
	"res://tests/test_combat.gd",
	"res://tests/test_build.gd",
	"res://tests/test_roguelike.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_scenes.gd",
]


func _initialize() -> void:
	var filter := OS.get_environment("TEST_FILTER")
	var total := 0
	var failed: Array[String] = []
	for path in SUITES:
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed.append("%s: failed to load (parse error?)" % path)
			continue
		var suite = script.new()
		if suite is Node:
			root.add_child.call_deferred(suite)
			await process_frame
			await process_frame
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_") or (filter != "" and not name.contains(filter)):
				continue
			suite.current_test = "%s::%s" % [path.get_file(), name]
			var before: int = suite.failures.size()
			var started := Time.get_ticks_msec()
			await suite.call(name)
			total += 1
			var ok: bool = suite.failures.size() == before
			print("%s %s (%d ms)" % ["PASS" if ok else "FAIL", suite.current_test, Time.get_ticks_msec() - started])
		failed.append_array(suite.failures)
		if suite is Node:
			suite.queue_free()
	print("")
	for f in failed:
		print("  x ", f)
	print("%d tests, %d failures" % [total, failed.size()])
	quit(1 if not failed.is_empty() else 0)
