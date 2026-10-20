class_name Models
extends RefCounted
## Builds the 3D models. Imported art (data/visuals.json, via `Assets`) is used when
## available; otherwise stylized placeholders are built from primitives. Each model is a
## Node3D whose meta "parts" holds named sub-nodes the view animates (head, crystal...).
## Animated imported models also carry the meta set by `Assets.creature`.


static func enemy(type: String, def: Dictionary, elite: bool) -> Node3D:
	var imported := Assets.creature(DataDB.visuals().get("enemies", {}).get(type, {}))
	if imported:
		_decorate_elite(imported, float(def.get("size", 0.5)), elite)
		imported.set_meta("parts", {})
		imported.set_meta("base_color", Color(def.get("color", "888888")))
		return imported
	return _enemy_placeholder(type, def, elite)


static func _decorate_elite(root: Node3D, s: float, elite: bool) -> void:
	if not elite:
		return
	Art.part(root, Art.torus(s * 0.35, s * 0.5), Art.mat(Color("ffcf3a"), 2.5, 0.3), Vector3(0, s * 2.6 + 0.3, 0), Vector3.ZERO, Vector3.ONE, false)
	var aura := Art.part(root, Art.sphere(s * 1.6), Art.mat(Color(1, 0.3, 0.2, 0.12), 1.0, 1.0, true, true), Vector3(0, s * 1.2, 0), Vector3.ZERO, Vector3.ONE, false)
	aura.name = "elite_aura"
	root.scale = Vector3.ONE * float(DataDB.balance().elite.scale)


static func _enemy_placeholder(type: String, def: Dictionary, elite: bool) -> Node3D:
	var root := Node3D.new()
	var c := Color(def.get("color", "888888"))
	var s := float(def.get("size", 0.5))
	var body_m := Art.mat(c)
	var dark := Art.mat(c.darkened(0.35))
	var eye := Art.mat(Color("ffd25a") if not elite else Color("ff3b3b"), 3.0)
	var parts := {}
	match type:
		"brute":
			parts.body = Art.part(root, Art.box(Vector3(1.6, 1.4, 1.1) * s), body_m, Vector3(0, s * 1.0, 0))
			Art.part(root, Art.box(Vector3(1.9, 0.35, 1.3) * s), Art.mat(Color("8f8f96"), 0.0, 0.4), Vector3(0, s * 1.6, 0))
			parts.head = Art.part(root, Art.box(Vector3(0.7, 0.6, 0.6) * s), dark, Vector3(0, s * 2.0, s * 0.2))
		"wisp":
			parts.body = Art.part(root, Art.sphere(s * 0.8), Art.mat(c, 1.5), Vector3.ZERO)
			for i in 3:
				Art.part(root, Art.cone(s * 0.25, s * 1.2), Art.mat(c.lightened(0.2), 1.0, 0.8, true),
					Vector3(cos(i * 2.1) * s * 0.4, -s * 0.8, sin(i * 2.1) * s * 0.4), Vector3(180, 0, 0))
			parts.head = parts.body
		"splitter", "splitling":
			parts.body = Art.part(root, Art.sphere(s * 0.9), body_m, Vector3(0, s * 0.9, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
			Art.part(root, Art.sphere(s * 0.45), Art.mat(c.lightened(0.3), 0.6), Vector3(0, s * 1.5, 0))
			parts.head = parts.body
		"hexer":
			parts.body = Art.part(root, Art.cone(s * 0.8, s * 2.2), body_m, Vector3(0, s * 1.1, 0))
			parts.head = Art.part(root, Art.sphere(s * 0.4), dark, Vector3(0, s * 2.3, 0))
			parts.staff = Art.part(root, Art.cyl(0.04, 0.04, s * 2.6), Art.mat(Color("3a2a2a")), Vector3(s * 0.6, s * 1.3, 0))
			Art.part(root, Art.sphere(s * 0.22), Art.mat(Color("d36bff"), 4.0), Vector3(s * 0.6, s * 2.6, 0))
		"warden":
			parts.body = Art.part(root, Art.cyl(s * 0.55, s * 0.7, s * 1.6), body_m, Vector3(0, s * 0.8, 0))
			parts.head = Art.part(root, Art.sphere(s * 0.4), Art.mat(Color("9aa5b8"), 0.0, 0.3), Vector3(0, s * 1.85, 0))
			Art.part(root, Art.box(Vector3(0.15, 1.5, 1.1) * s), Art.mat(Color("c8d2e6"), 0.3, 0.3), Vector3(0, s * 1.0, s * 0.75))
		"golem":
			parts.body = Art.part(root, Art.box(Vector3(2.4, 2.2, 1.6) * s * 0.5), body_m, Vector3(0, s * 1.4, 0))
			parts.head = Art.part(root, Art.box(Vector3(1.0, 0.8, 0.9) * s * 0.5), dark, Vector3(0, s * 2.15, s * 0.15))
			for side in [-1, 1]:
				Art.part(root, Art.box(Vector3(0.6, 1.8, 0.6) * s * 0.5), dark, Vector3(side * s * 0.85, s * 1.1, 0))
				Art.part(root, Art.box(Vector3(0.7, 1.0, 0.7) * s * 0.5), body_m, Vector3(side * s * 0.4, s * 0.3, 0))
			for i in 5:
				Art.part(root, Art.prism(Vector3(0.3, 0.6, 0.3) * s), Art.mat(Color("ff8c3a"), 3.0),
					Vector3((i - 2) * s * 0.25, s * 2.0, -s * 0.2))
			Art.part(root, Art.sphere(s * 0.12), Art.mat(Color("ff5a1f"), 6.0), Vector3(0, s * 2.2, s * 0.4))
		_:  # grunt, runner
			var lean := Vector3(-18, 0, 0) if type == "runner" else Vector3.ZERO
			parts.body = Art.part(root, Art.cyl(s * 0.5, s * 0.65, s * 1.4), body_m, Vector3(0, s * 0.75, 0), lean)
			parts.head = Art.part(root, Art.sphere(s * 0.45), dark, Vector3(0, s * 1.65, s * (0.25 if type == "runner" else 0.05)))
			Art.part(root, Art.cone(s * 0.12, s * 0.5), Art.mat(Color("e8e0d0")), Vector3(-s * 0.3, s * 2.0, 0), Vector3(0, 0, 20))
			Art.part(root, Art.cone(s * 0.12, s * 0.5), Art.mat(Color("e8e0d0")), Vector3(s * 0.3, s * 2.0, 0), Vector3(0, 0, -20))
	# Eyes (front = -Z in Godot, models face -Z).
	var head: Node3D = parts.get("head", parts.body)
	var hs := s * (0.9 if type == "golem" else 0.35)
	for side in [-1, 1]:
		var e := Art.part(root, Art.sphere(maxf(0.05, s * 0.09)), eye, head.position + Vector3(side * hs * 0.4, hs * 0.1, -hs * 0.9), Vector3.ZERO, Vector3.ONE, false)
		e.name = "eye"
	if elite:
		Art.part(root, Art.torus(s * 0.35, s * 0.5), Art.mat(Color("ffcf3a"), 2.5, 0.3), head.position + Vector3(0, s * 0.55, 0), Vector3.ZERO, Vector3.ONE, false)
		var aura := Art.part(root, Art.sphere(s * 1.3), Art.mat(Color(1, 0.3, 0.2, 0.12), 1.0, 1.0, true, true), Vector3(0, s, 0), Vector3.ZERO, Vector3.ONE, false)
		aura.name = "elite_aura"
	root.set_meta("parts", parts)
	root.set_meta("base_color", c)
	return root


static func structure(type: String, def: Dictionary) -> Node3D:
	var cfg: Dictionary = DataDB.visuals().get("structures", {}).get(type, {})
	if not cfg.is_empty():
		var built := _imported_structure(cfg)
		if built:
			return built
	return _structure_placeholder(type, def)


static func _imported_structure(cfg: Dictionary) -> Node3D:
	var sc := float(cfg.get("scale", 1.0))
	var st := Assets.stack(cfg.get("stack", []), sc)
	if st.is_empty():
		return null
	var root: Node3D = st.root
	var parts := {}
	if cfg.has("head"):
		var head := Node3D.new()
		head.position = Vector3(0, float(st.top), 0)
		root.add_child(head)
		var weapon := Assets.prop(cfg.head, sc, float(cfg.get("head_rot_y", 0.0)))
		if weapon == null:
			root.free()
			return null
		head.add_child(weapon)
		Assets.no_self_shadow(weapon)
		parts.head = head
	if cfg.has("tint"):
		Assets.tint(root, Color(cfg.tint))
	if cfg.has("spin"):
		var spin := root.find_child(cfg.spin, true, false) as Node3D
		if spin:
			parts.crystal = spin
	var flag := root.find_child("flag*", true, false) as Node3D
	if flag:
		parts.flag = flag
	root.set_meta("parts", parts)
	root.set_meta("height", float(st.top))
	return root


static func _structure_placeholder(type: String, def: Dictionary) -> Node3D:
	var root := Node3D.new()
	var parts := {}
	var c := Color(def.get("color", "999999"))
	var stone := Art.mat(Art.PALETTE.stone)
	var wood := Art.mat(Art.PALETTE.wood)
	var wood_dark := Art.mat(Art.PALETTE.wood_dark)
	match type:
		"arrow":
			Art.part(root, Art.cyl(1.0, 1.15, 0.5, 8), stone, Vector3(0, 0.25, 0))
			for i in 4:
				var a := i * PI / 2.0 + PI / 4.0
				Art.part(root, Art.box(Vector3(0.22, 3.2, 0.22)), wood_dark, Vector3(cos(a) * 0.7, 1.9, sin(a) * 0.7))
			parts.head = Node3D.new()
			parts.head.position = Vector3(0, 3.4, 0)
			root.add_child(parts.head)
			Art.part(parts.head, Art.box(Vector3(1.8, 0.2, 1.8)), wood, Vector3.ZERO)
			Art.part(parts.head, Art.cone(1.35, 1.1, 4), Art.mat(Color("8c3b2e")), Vector3(0, 1.1, 0), Vector3(0, 45, 0))
			Art.part(parts.head, Art.box(Vector3(0.12, 0.12, 1.0)), wood_dark, Vector3(0, 0.35, -0.6))
		"cannon":
			Art.part(root, Art.cyl(1.25, 1.35, 1.6, 8), stone, Vector3(0, 0.8, 0))
			Art.part(root, Art.cyl(1.4, 1.4, 0.3, 8), Art.mat(Art.PALETTE.stone_dark), Vector3(0, 1.7, 0))
			parts.head = Node3D.new()
			parts.head.position = Vector3(0, 2.2, 0)
			root.add_child(parts.head)
			Art.part(parts.head, Art.sphere(0.65), Art.mat(Color("3d3f45"), 0.0, 0.35), Vector3.ZERO)
			parts.barrel = Art.part(parts.head, Art.cyl(0.32, 0.4, 1.8), Art.mat(Color("2e3035"), 0.0, 0.3), Vector3(0, 0.25, -0.8), Vector3(-75, 0, 0))
		"frost":
			Art.part(root, Art.cyl(0.9, 1.1, 0.6, 6), Art.mat(Color("a9b8c8")), Vector3(0, 0.3, 0))
			Art.part(root, Art.cyl(0.35, 0.6, 2.2, 6), Art.mat(Color("cfe3f2")), Vector3(0, 1.6, 0))
			parts.head = Node3D.new()
			parts.head.position = Vector3(0, 3.4, 0)
			root.add_child(parts.head)
			parts.crystal = Art.part(parts.head, Art.prism(Vector3(0.9, 1.6, 0.9)), Art.mat(c, 2.5, 0.1, false), Vector3.ZERO)
			Art.part(parts.head, Art.prism(Vector3(0.9, 1.0, 0.9)), Art.mat(c, 2.5, 0.1), Vector3(0, -1.1, 0), Vector3(180, 0, 0))
		"banner":
			Art.part(root, Art.cyl(0.6, 0.75, 0.4, 8), stone, Vector3(0, 0.2, 0))
			Art.part(root, Art.cyl(0.08, 0.1, 4.6), wood_dark, Vector3(0, 2.5, 0))
			parts.flag = Art.part(root, Art.box(Vector3(1.4, 1.6, 0.06)), Art.mat(c, 0.4), Vector3(0.72, 3.8, 0))
			Art.part(root, Art.sphere(0.18), Art.mat(Art.PALETTE.gold, 2.0, 0.3), Vector3(0, 4.85, 0))
		"spikes":
			Art.part(root, Art.box(Vector3(2.0, 0.12, 2.0)), Art.mat(Color("4a4a4f"), 0.0, 0.5), Vector3(0, 0.06, 0), Vector3.ZERO, Vector3.ONE, false)
			parts.spikes = Node3D.new()
			root.add_child(parts.spikes)
			for x in 4:
				for z in 4:
					Art.part(parts.spikes, Art.cone(0.12, 0.55, 4), Art.mat(Color("c9ccd2"), 0.0, 0.25),
						Vector3(-0.72 + x * 0.48, 0.3, -0.72 + z * 0.48), Vector3.ZERO, Vector3.ONE, false)
		"spring":
			Art.part(root, Art.box(Vector3(2.0, 0.14, 2.0)), Art.mat(Color("51412f")), Vector3(0, 0.07, 0), Vector3.ZERO, Vector3.ONE, false)
			parts.plate = Art.part(root, Art.box(Vector3(1.7, 0.18, 1.7)), Art.mat(c, 0.3), Vector3(0, 0.25, 0), Vector3.ZERO, Vector3.ONE, false)
			for i in 4:
				Art.part(root, Art.torus(0.12, 0.2), Art.mat(Color("b0b6bf"), 0.0, 0.3), Vector3((i % 2 - 0.5) * 1.1, 0.15, (i / 2 - 0.5) * 1.1))
		"tar":
			Art.part(root, Art.cyl(1.0, 1.0, 0.06, 20), Art.mat(Color("17110e"), 0.0, 0.1), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1.0, 1, 1.0), false)
			for i in 5:
				Art.part(root, Art.sphere(0.14), Art.mat(Color("2c2420"), 0.0, 0.05), Vector3(cos(i * 1.3) * 0.6, 0.08, sin(i * 1.3) * 0.6), Vector3.ZERO, Vector3(1, 0.4, 1), false)
	root.set_meta("parts", parts)
	return root


static func level_pips(parent: Node3D, level: int, height: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "pips"
	holder.position = Vector3(0, height + 0.9, 0)
	parent.add_child(holder)
	for i in level - 1:
		Art.part(holder, Art.prism(Vector3(0.3, 0.3, 0.1)), Art.mat(Art.PALETTE.gold, 2.0, 0.3),
			Vector3((i - (level - 2) * 0.5) * 0.4, 0, 0), Vector3.ZERO, Vector3.ONE, false)
	return holder


static func projectile(style: String) -> Node3D:
	var cfg: Dictionary = DataDB.visuals().get("projectiles", {}).get(style, {})
	if not cfg.is_empty():
		var p := Assets.prop(cfg.scene, float(cfg.get("scale", 1.0)), float(cfg.get("rot_y", 0.0)))
		if p:
			var holder := Node3D.new()
			holder.add_child(p)
			for mi in Assets._meshes(p):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return holder
	var root := Node3D.new()
	match style:
		"ballistic":
			Art.part(root, Art.sphere(0.32), Art.mat(Color("2a2b30"), 0.0, 0.3), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		"orb":
			Art.part(root, Art.sphere(0.28), Art.mat(Art.PALETTE.ice, 4.0, 0.1), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		"hero_arrow":
			Art.part(root, Art.box(Vector3(0.05, 0.05, 1.0)), Art.mat(Color("eadbb0"), 1.5), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			Art.part(root, Art.box(Vector3(0.12, 0.12, 0.25)), Art.mat(Color("7fffb0"), 4.0), Vector3(0, 0, -0.5), Vector3.ZERO, Vector3.ONE, false)
		_:
			Art.part(root, Art.box(Vector3(0.05, 0.05, 0.9)), Art.mat(Color("c9a26b"), 0.6), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	return root


static func core() -> Node3D:
	var root := Node3D.new()
	Art.part(root, Art.cyl(2.6, 3.0, 0.8, 8), Art.mat(Art.PALETTE.stone), Vector3(0, 0.4, 0))
	Art.part(root, Art.cyl(1.8, 2.2, 0.6, 8), Art.mat(Art.PALETTE.stone_dark), Vector3(0, 1.1, 0))
	for i in 6:
		var a := i * TAU / 6.0
		Art.part(root, Art.box(Vector3(0.4, 2.4, 0.4)), Art.mat(Art.PALETTE.stone), Vector3(cos(a) * 2.4, 1.6, sin(a) * 2.4))
	var crystal := Art.part(root, Art.prism(Vector3(1.4, 2.6, 1.4)), Art.mat(Art.PALETTE.crystal, 3.0, 0.1), Vector3(0, 3.4, 0))
	crystal.name = "crystal"
	Art.part(crystal, Art.prism(Vector3(1.4, 1.6, 1.4)), Art.mat(Art.PALETTE.crystal, 3.0, 0.1), Vector3(0, -2.1, 0), Vector3(180, 0, 0))
	var light := OmniLight3D.new()
	light.light_color = Art.PALETTE.crystal
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0, 3.5, 0)
	light.name = "light"
	root.add_child(light)
	return root


static func cache() -> Node3D:
	var root := Node3D.new()
	Art.part(root, Art.box(Vector3(1.2, 0.7, 0.8)), Art.mat(Art.PALETTE.wood), Vector3(0, 0.35, 0))
	Art.part(root, Art.box(Vector3(1.25, 0.25, 0.85)), Art.mat(Art.PALETTE.gold, 1.5, 0.3), Vector3(0, 0.8, 0))
	Art.part(root, Art.cyl(0.25, 0.25, 8.0, 8), Art.mat(Color(1, 0.85, 0.3, 0.25), 2.0, 1.0, true, true), Vector3(0, 4.0, 0), Vector3.ZERO, Vector3.ONE, false)
	return root


static func hero(id: String = "ranger") -> Node3D:
	var imported := Assets.creature(DataDB.visuals().get("heroes", {}).get(id, {}))
	if imported:
		imported.set_meta("parts", {})
		return imported
	var root := Node3D.new()
	var parts := {}
	var cloak := Art.mat(Art.PALETTE.hero)
	var skin := Art.mat(Color("d8b48c"))
	parts.body = Art.part(root, Art.cyl(0.32, 0.45, 1.1), cloak, Vector3(0, 0.75, 0))
	parts.head = Art.part(root, Art.sphere(0.27), skin, Vector3(0, 1.55, 0))
	Art.part(parts.head, Art.cone(0.34, 0.5), Art.mat(Art.PALETTE.hero.darkened(0.3)), Vector3(0, 0.22, 0.05), Vector3(-15, 0, 0))
	Art.part(root, Art.box(Vector3(0.5, 0.12, 0.3)), Art.mat(Color("6b4a2e")), Vector3(0, 0.95, 0))
	parts.bow = Node3D.new()
	parts.bow.position = Vector3(0.35, 1.1, -0.25)
	root.add_child(parts.bow)
	Art.part(parts.bow, Art.torus(0.55, 0.62), Art.mat(Color("7a4f2a")), Vector3.ZERO, Vector3(0, 0, 90), Vector3(1, 1, 0.35))
	Art.part(parts.bow, Art.cyl(0.01, 0.01, 1.15), Art.mat(Color("f0e6d0"), 0.5), Vector3(0, 0, 0.18))
	Art.part(root, Art.cyl(0.12, 0.12, 0.7), Art.mat(Color("5b3a22")), Vector3(-0.2, 1.1, 0.3), Vector3(20, 0, 0))
	root.set_meta("parts", parts)
	return root


static func portal() -> Node3D:
	var root := Node3D.new()
	Art.part(root, Art.torus(2.4, 3.0), Art.mat(Art.PALETTE.corruption, 2.5), Vector3(0, 3.0, 0), Vector3(90, 0, 0))
	var core := Art.part(root, Art.cyl(2.4, 2.4, 0.05, 24), Art.mat(Color(0.6, 0.2, 0.9, 0.5), 3.0, 1.0, true, true), Vector3(0, 3.0, 0), Vector3(90, 0, 0))
	core.name = "swirl"
	for side in [-1, 1]:
		Art.part(root, Art.box(Vector3(0.8, 6.5, 0.8)), Art.mat(Art.PALETTE.stone_dark), Vector3(side * 3.2, 3.2, 0))
	var light := OmniLight3D.new()
	light.light_color = Color("b06cff")
	light.light_energy = 3.0
	light.omni_range = 10.0
	light.position = Vector3(0, 3, 0)
	root.add_child(light)
	return root
