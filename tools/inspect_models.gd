extends SceneTree
## Prints size, meshes and animations of every imported model (asset integration helper).
##   godot --headless --path . --script res://tools/inspect_models.gd


func _initialize() -> void:
	var files: Array[String] = []
	_collect("res://assets/models", files)
	for path in files:
		var packed: PackedScene = load(path)
		if packed == null:
			print("FAILED ", path)
			continue
		var node := packed.instantiate()
		var aabb := _aabb(node, Transform3D.IDENTITY)
		var meshes: Array[String] = []
		var anims: Array[String] = []
		_walk(node, meshes, anims)
		print("%s  size=(%.2f, %.2f, %.2f) min_y=%.2f center=(%.2f, %.2f)  meshes=%s  anims=%s" % [path.get_file(),
			aabb.size.x, aabb.size.y, aabb.size.z, aabb.position.y, aabb.get_center().x, aabb.get_center().z, meshes, anims])
		node.free()
	quit()


func _collect(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb") or f.ends_with(".fbx"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)


func _walk(n: Node, meshes: Array[String], anims: Array[String]) -> void:
	if n is MeshInstance3D:
		meshes.append(n.name)
	if n is AnimationPlayer:
		for a in n.get_animation_list():
			anims.append(a)
	for c in n.get_children():
		_walk(c, meshes, anims)


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and n.mesh:
		var a: AABB = t * n.mesh.get_aabb()
		out = a
		first = false
	for c in n.get_children():
		var ca := _aabb(c, t)
		if ca.size != Vector3.ZERO:
			out = ca if first else out.merge(ca)
			first = false
	return out
