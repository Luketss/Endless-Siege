extends SceneTree
## Renders every configured model side by side next to a 1.8 m reference pole, seen from
## the front (models must face -Z). Used to calibrate scale/rotation in data/visuals.json.
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
##       --rendering-method gl_compatibility --rendering-driver opengl3 --script res://tools/model_lineup.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("SHOT_DIR")
	if out == "":
		out = "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("6d7f8f")
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 160, 0)
	world.add_child(sun)
	Art.part(world, Art.box(Vector3(60, 0.1, 20)), Art.mat(Color("557a3e")), Vector3(0, -0.05, 0))
	var vis := DataDB.visuals()
	var items: Array = []
	for type in vis.enemies:
		items.append([type, Assets.creature(vis.enemies[type])])
	for id in vis.heroes:
		items.append([id, Assets.creature(vis.heroes[id])])
	var x := -float(items.size()) * 1.6
	for it in items:
		var node: Node3D = it[1]
		if node == null:
			print("MISSING ", it[0])
			continue
		world.add_child(node)
		node.position = Vector3(x, 0, 0)
		Assets.play(node, "move")
		Assets.play(node, "idle")
		var pole := Art.part(world, Art.box(Vector3(0.08, 1.8, 0.08)), Art.mat(Color.RED), Vector3(x + 1.0, 0.9, 0))
		var l := Label3D.new()
		l.text = it[0]
		l.pixel_size = 0.01
		l.position = Vector3(x, -0.1, -1.2)
		l.rotation_degrees.y = 180
		world.add_child(l)
		x += 3.2
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 3.5, -16)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.make_current()
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("lineup_creatures.png"))
	# Structures and props.
	for c in world.get_children():
		if c is Node3D and c != cam and not (c is DirectionalLight3D) and not (c is WorldEnvironment):
			if c.position.y >= -0.01 and c.get_class() != "MeshInstance3D":
				c.queue_free()
	var sx := -12.0
	for type in ["arrow", "cannon", "frost", "banner"]:
		var model := Models.structure(type, DataDB.structure(type))
		world.add_child(model)
		model.position = Vector3(sx, 0, 3)
		sx += 5.0
	for i in range(3):
		var tree := Assets.prop(vis.environment.trees[i], float(vis.environment.tree_scale))
		if tree:
			world.add_child(tree)
			tree.position = Vector3(sx + i * 3.0, 0, 3)
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("lineup_structures.png"))
	print("lineup saved")
	quit()
