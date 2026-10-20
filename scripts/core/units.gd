class_name Units
extends RefCounted
## Plain data objects used by BattleSim. Kept together because they are small.


class Enemy:
	extends RefCounted
	var id: int = 0
	var type: String = ""
	var def: Dictionary = {}
	var hp: float = 1.0
	var max_hp: float = 1.0
	var armor: float = 0.0
	var speed: float = 3.0
	var size: float = 0.5
	var gold: int = 0
	var leak: int = 1
	var flying: bool = false
	var elite: bool = false
	var boss: bool = false
	## Ground: distance along the path. Flying: 0..1 along the straight flight line.
	var s: float = 0.0
	var lateral: float = 0.0
	var fly_from: Vector2 = Vector2.ZERO
	var pos: Vector3 = Vector3.ZERO
	var alive: bool = true
	# Status effects (timers in seconds).
	var chill_t: float = 0.0
	var chill_slow: float = 0.0
	var frozen_t: float = 0.0
	var stun_t: float = 0.0  # warrior slam: no movement or attacks
	var chill_accum: float = 0.0
	var burn_t: float = 0.0
	var burn_dps: float = 0.0
	var oiled_t: float = 0.0
	var launched_t: float = 0.0
	var in_tar: float = 0.0
	var shielded: float = 0.0
	var contact_cd: float = 0.0
	var attack_t: float = 0.0  # melee windup on the hero; hits when it reaches 0
	var ability_t: float = 0.0
	var summon_t: float = 0.0
	var phase: int = 0
	var last_hit_by: int = -1  # structure id or HERO

	func is_chilled() -> bool:
		return chill_t > 0.0 or frozen_t > 0.0

	func has_element_status() -> bool:
		return chill_t > 0.0 or frozen_t > 0.0 or burn_t > 0.0


class Structure:
	extends RefCounted
	var id: int = 0
	var type: String = ""
	var def: Dictionary = {}
	var kind: String = "tower"
	var pos: Vector3 = Vector3.ZERO
	var level: int = 1
	var invested: int = 0
	var cooldown: float = 0.0
	var disabled_t: float = 0.0
	var target_mode: String = "first"
	var shots: int = 0
	var damage_done: float = 0.0
	var kills: int = 0
	var elevated: bool = false
	var chain_cd: float = 0.0

	func pos2() -> Vector2:
		return Vector2(pos.x, pos.z)


class Projectile:
	extends RefCounted
	var id: int = 0
	var style: String = "arrow"
	var pos: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3.FORWARD
	var speed: float = 30.0
	var target_id: int = -1
	var target_pos: Vector3 = Vector3.ZERO
	var damage: float = 1.0
	var dtype: String = "physical"
	var splash: float = 0.0
	var pierce: int = 0
	var hit_ids: Array[int] = []
	var source: int = -1
	var crit_chance: float = 0.0
	var ttl: float = 3.0
	var chill: Dictionary = {}
	var hits_air: bool = true
	var hits_ground: bool = true
	var bounces: int = 0
	var ignite: float = 0.0  # chance to set the target on fire
	# Ballistic arc.
	var start: Vector3 = Vector3.ZERO
	var t: float = 0.0
	var duration: float = 1.0
	var alive: bool = true


class Zone:
	extends RefCounted
	var id: int = 0
	var kind: String = "fire"
	var pos: Vector3 = Vector3.ZERO
	var radius: float = 2.0
	var dps: float = 0.0
	var dtype: String = "fire"
	var ttl: float = 3.0
	var tick: float = 0.0
	var hits_left: int = 0
	var source: int = -1


class Hero:
	extends RefCounted
	var def: Dictionary = {}
	var pos: Vector3 = Vector3.ZERO
	var hp: float = 100.0
	var max_hp: float = 100.0
	var alive: bool = true
	var respawn_t: float = 0.0
	var invuln_t: float = 0.0
	var level: int = 1
	var xp: float = 0.0
	var attack_cd: float = 0.0
	var dodge_cd: float = 0.0
	var rain_cd: float = 0.0  # ability 1 cooldown (rain / slam)
	var blast_cd: float = 0.0  # ability 2 cooldown (blast / charge)
	var regen_delay: float = 0.0
