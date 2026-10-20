class_name TestCase
extends RefCounted
## Minimal assertion helpers. Each public method starting with "test_" is a test.

var failures: Array[String] = []
var current_test := ""


func check(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s %s" % [current_test, expected, actual, message])


func check_near(actual: float, expected: float, tol: float = 0.01, message: String = "") -> void:
	if absf(actual - expected) > tol:
		failures.append("%s: expected ~%s, got %s %s" % [current_test, expected, actual, message])


# ---------------------------------------------------------------- fixtures

const DT := 1.0 / 30.0


func make_sim(gold: int = 1000, upgrades: Array = [], seed_value: int = 1, unlocks: Array = ["banner", "tar"], hero_id: String = "ranger") -> BattleSim:
	var sim := BattleSim.new()
	sim.setup(MapDef.from_dict(DataDB.map("forest")), RunMods.build(upgrades), gold, 100.0, 100.0, hero_id, seed_value, unlocks)
	sim.hero.pos = Vector3(30, 0, 30)  # out of the way unless a test moves it
	return sim


## Point on the road at distance s, and a point beside the road (for towers).
func road(sim: BattleSim, s: float) -> Vector2:
	return sim.map.path.sample(s)


func beside(sim: BattleSim, s: float, offset: float = 4.8) -> Vector2:
	var t := sim.map.path.tangent(s)
	return sim.map.path.sample(s) + Vector2(-t.y, t.x) * offset


func run(sim: BattleSim, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not sim.defeated:
		sim.step(DT)
		t += DT


func run_until_clear(sim: BattleSim, max_seconds: float = 300.0) -> void:
	var t := 0.0
	while sim.wave_active and not sim.defeated and t < max_seconds:
		sim.step(DT)
		t += DT
