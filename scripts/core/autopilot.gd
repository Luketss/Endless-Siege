class_name Autopilot
extends RefCounted
## Simple scripted player used by tests and the balance tool (never by the shipped game).
## It spends gold on towers/traps near the road and upgrades existing ones, so whole
## journeys can be simulated headless. It does not control the hero.

var rng := RandomNumberGenerator.new()
var _candidates: Array = []


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


func _build_candidates(sim: BattleSim) -> void:
	_candidates.clear()
	var path := sim.map.path
	var s := 4.0
	while s < path.length - 4.0:
		var p := path.sample(s)
		var t := path.tangent(s)
		var n := Vector2(-t.y, t.x)
		for side in [-1.0, 1.0]:
			_candidates.append({"kind": "tower", "pos": p + n * side * (sim.map.path_width * 0.5 + 2.2), "s": s})
		_candidates.append({"kind": "trap", "pos": p, "s": s})
		s += 3.0


## Spends gold. Prefers covering the second half of the road (closest to the core).
func spend(sim: BattleSim) -> void:
	if _candidates.is_empty():
		_build_candidates(sim)
	var guard := 0
	while guard < 40:
		guard += 1
		var choice := rng.randf()
		var did := false
		if choice < 0.3 and not sim.structures.is_empty():
			var st: Units.Structure = sim.structures[rng.randi() % sim.structures.size()]
			did = sim.upgrade(st)
		elif choice < 0.8:
			var type: String = ["arrow", "arrow", "cannon", "frost"][rng.randi() % 4]
			did = _try_place(sim, type, "tower")
		else:
			var type: String = ["spikes", "spikes", "spring"][rng.randi() % 3]
			did = _try_place(sim, type, "trap")
		if not did and sim.gold < 40:
			return


func _try_place(sim: BattleSim, type: String, kind: String) -> bool:
	if sim.gold < sim.structure_cost(type):
		return false
	for attempt in 12:
		var c: Dictionary = _candidates[rng.randi() % _candidates.size()]
		if c.kind != kind:
			continue
		# Bias towards the core: reject early-road spots half of the time.
		if float(c.s) < sim.map.path.length * 0.35 and rng.randf() < 0.5:
			continue
		if sim.build(type, c.pos) != null:
			return true
	return false


## Plays a whole combat node; returns waves cleared.
static func play_combat(run: RunState, node: Dictionary, pilot: Autopilot, dt: float = 1.0 / 30.0) -> int:
	var sim := RunFlow.make_sim(run)
	var waves := RunFlow.waves_for(run, node)
	var cleared := 0
	for w in waves:
		pilot.spend(sim)
		sim.start_wave(w)
		var t := 0.0
		while (sim.wave_active) and not sim.defeated and t < 600.0:
			sim.step(dt)
			sim.events.clear()
			t += dt
		if sim.defeated:
			break
		cleared += 1
	RunFlow.finish_combat(run, sim, node, cleared)
	return cleared


## Plays a full journey choosing random paths and rewards. Returns the final run.
static func play_journey(seed_value: int, unlocks: Array = [], modifiers: Array = []) -> RunState:
	var run := RunState.create(seed_value, "ranger", modifiers, unlocks)
	var pilot := Autopilot.new(seed_value)
	while not run.finished:
		var options := Journey.choices(run.journey, run.current_node)
		if options.is_empty():
			break
		var node := RunFlow.enter(run, options[pilot.rng.randi() % options.size()].id)
		match node.type:
			"combat", "elite", "boss":
				play_combat(run, node, pilot)
				if not run.finished:
					var picks := RunFlow.reward_choices(run, node)
					if not picks.is_empty():
						run.add_upgrade(picks[pilot.rng.randi() % picks.size()])
			"shop":
				var offer := RunFlow.shop_offer(run, node)
				for item in offer.items:
					RunFlow.buy(run, item)
			"rest":
				RunFlow.rest(run)
			"event":
				var ev := RunFlow.pick_event(run, node)
				var res := RunFlow.apply_event(run, node, ev, 0)
				if not res.get("ok", false):
					res = RunFlow.apply_event(run, node, ev, DataDB.events()[ev].choices.size() - 1)
				var ups: Array = res.get("upgrade_choices", [])
				if not ups.is_empty():
					run.add_upgrade(ups[0])
	return run
