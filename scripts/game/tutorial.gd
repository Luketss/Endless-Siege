class_name Tutorial
extends RefCounted
## First-battle tutorial: one objective at a time, each advancing when the player
## actually does it (move, shoot, pick and place a structure, use an ability, start
## the wave). Prompts are rebuilt every frame so they follow remaps and the gamepad.

const STEPS := ["move", "shoot", "pick", "place", "ability", "wave", "core"]

var step := 0
var _start_pos := Vector3.ZERO
var _core_t := 0.0


func _init(hero_pos: Vector3) -> void:
	_start_pos = hero_pos


func done() -> bool:
	return step >= STEPS.size()


## Advances when the current objective is met. `ctx` keys: hero_pos (Vector3),
## sim (BattleSim), selected (String), phase (String), dt (float).
func update(ctx: Dictionary) -> bool:
	if done():
		return false
	var sim: BattleSim = ctx.sim
	var met := false
	match STEPS[step]:
		"move":
			met = (ctx.hero_pos as Vector3).distance_to(_start_pos) > 3.0
		"shoot":
			met = sim.hero.attack_cd > 0.0
		"pick":
			met = ctx.selected != "" or not sim.structures.is_empty()
		"place":
			met = not sim.structures.is_empty()
		"ability":
			met = sim.hero.rain_cd > 0.0 or sim.hero.blast_cd > 0.0
		"wave":
			met = ctx.phase == "wave"
		"core":
			_core_t += float(ctx.dt)
			met = _core_t > 7.0
	if met:
		step += 1
	return met


## Objective text for the current step, with the player's current bindings.
func text() -> String:
	if done():
		return ""
	var L := func(a: String) -> String: return Settings.action_label(a)
	match STEPS[step]:
		"move":
			var keys: String = tr("TUT_STICK_L") if Settings.using_pad else "%s %s %s %s" % [L.call("move_forward"), L.call("move_left"), L.call("move_back"), L.call("move_right")]
			return tr("TUT_MOVE") % keys
		"shoot":
			return tr("TUT_SHOOT") % L.call("attack")
		"pick":
			var keys: String = "%s / %s" % [L.call("slot_prev"), L.call("slot_next")] if Settings.using_pad else "%s…%s" % [L.call("slot_1"), L.call("slot_7")]
			return tr("TUT_PICK") % keys
		"place":
			return tr("TUT_PLACE") % [L.call("attack"), L.call("cancel")]
		"ability":
			return tr("TUT_ABILITY") % [L.call("ability_1"), L.call("ability_2")]
		"wave":
			return tr("TUT_WAVE") % L.call("start_wave")
		"core":
			return tr("TUT_CORE")
	return ""
