extends TestCase
## Imported art: every file referenced by data/visuals.json exists, loads, has the
## animations it claims, and every model folder carries its license.


func _paths(v: Variant, out: Array) -> void:
	if v is String and (v as String).begins_with("res://"):
		out.append(v)
	elif v is Array:
		for x in v:
			_paths(x, out)
	elif v is Dictionary:
		for k in v:
			_paths(v[k], out)


func test_all_referenced_assets_load() -> void:
	var paths := []
	_paths(DataDB.visuals(), paths)
	check(paths.size() > 40, "visuals reference %d files" % paths.size())
	for p in paths:
		check(ResourceLoader.exists(p), "missing %s" % p)
		if p.ends_with(".glb") or p.ends_with(".fbx"):
			check(load(p) is PackedScene, "not a scene: %s" % p)


func test_creature_animations_exist() -> void:
	var vis := DataDB.visuals()
	var cfgs: Dictionary = vis.enemies.duplicate()
	cfgs["hero"] = vis.hero
	for key in cfgs:
		var node := Assets.creature(cfgs[key])
		check(node != null, "%s builds" % key)
		if node == null:
			continue
		var player: AnimationPlayer = node.get_meta("anim")
		check(player != null, "%s has an AnimationPlayer" % key)
		var anims: Dictionary = node.get_meta("anims")
		for role in anims:
			check(player != null and player.has_animation(anims[role]), "%s: clip %s (%s)" % [key, anims[role], role])
		if anims.has("move"):
			check(player.get_animation(anims.move).loop_mode != Animation.LOOP_NONE, "%s move clip loops" % key)
		node.free()


func test_every_enemy_and_structure_has_a_model() -> void:
	for type in DataDB.enemies():
		var m := Models.enemy(type, DataDB.enemy(type), false)
		check(m != null, "enemy %s" % type)
		m.free()
	for type in DataDB.structures():
		var s := Models.structure(type, DataDB.structure(type))
		check(s != null, "structure %s" % type)
		s.free()


func test_placeholder_fallback_when_assets_disabled() -> void:
	Assets.enabled = false
	var m := Models.enemy("grunt", DataDB.enemy("grunt"), false)
	check(not m.has_meta("anim"), "procedural model used")
	m.free()
	Assets.enabled = true


func test_licenses_present() -> void:
	for dir in ["res://assets/models/kenney_td", "res://assets/models/kenney_nature", "res://assets/models/kenney_castle",
			"res://assets/models/quaternius/monsters", "res://assets/models/quaternius/rpg"]:
		check(FileAccess.file_exists(dir.path_join("License.txt")), "license in %s" % dir)
	check(FileAccess.file_exists("res://assets/CREDITS.md"), "credits file")
