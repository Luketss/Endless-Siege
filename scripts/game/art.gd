class_name Art
extends RefCounted
## Materials and primitive meshes for the stylized low-poly look (no imported assets yet).
## Materials/meshes are cached so hundreds of enemies share GPU resources.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}

const PALETTE := {
	"grass": Color("557a3e"), "grass_dark": Color("3f5c2f"), "corruption": Color("5b3a6e"),
	"dirt": Color("9a7650"), "dirt_edge": Color("6b5236"), "stone": Color("7d7a76"), "stone_dark": Color("54524f"),
	"wood": Color("8a6440"), "wood_dark": Color("5c4029"), "leaf": Color("3f5e3a"), "leaf_corrupt": Color("6a3f7a"),
	"crystal": Color("8be9ff"), "gold": Color("f2c14e"), "hero": Color("3f8f5a"), "ui_good": Color("5ad17a"),
	"ui_bad": Color("ff5a4f"), "fire": Color("ff7a2a"), "ice": Color("8fe3ff"), "lightning": Color("d7c6ff"),
	"poison": Color("8bd34f"),
}


static func mat(color: Color, emission: float = 0.0, roughness: float = 0.85, transparent: bool = false,
		unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%s" % [color.to_html(), emission, roughness, transparent, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if transparent or color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func box(size: Vector3) -> BoxMesh:
	var key := "box%s" % size
	if not _meshes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_meshes[key] = b
	return _meshes[key]


static func cyl(top: float, bottom: float, height: float, sides: int = 10) -> CylinderMesh:
	var key := "cyl%.2f|%.2f|%.2f|%d" % [top, bottom, height, sides]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = height
		c.radial_segments = sides
		c.rings = 1
		_meshes[key] = c
	return _meshes[key]


static func sphere(r: float, segments: int = 12) -> SphereMesh:
	var key := "sph%.2f|%d" % [r, segments]
	if not _meshes.has(key):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = segments
		s.rings = maxi(4, segments / 2)
		_meshes[key] = s
	return _meshes[key]


static func cone(r: float, height: float, sides: int = 8) -> CylinderMesh:
	return cyl(0.0, r, height, sides)


static func prism(size: Vector3) -> PrismMesh:
	var key := "prism%s" % size
	if not _meshes.has(key):
		var p := PrismMesh.new()
		p.size = size
		_meshes[key] = p
	return _meshes[key]


static func torus(inner: float, outer: float) -> TorusMesh:
	var key := "torus%.2f|%.2f" % [inner, outer]
	if not _meshes.has(key):
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 32
		t.ring_segments = 8
		_meshes[key] = t
	return _meshes[key]


static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Flat ring on the ground used for ranges and areas of effect.
static func ground_ring(parent: Node3D, radius: float, color: Color, width: float = 0.12) -> MeshInstance3D:
	var mi := part(parent, torus(1.0 - width / maxf(radius, 0.1), 1.0), mat(color, 1.5, 1.0, true, true),
		Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(radius, 0.02, radius), false)
	return mi


static func ground_disc(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	return part(parent, cyl(1.0, 1.0, 0.02, 32), mat(color, 0.6, 1.0, true, true),
		Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(radius, 1.0, radius), false)
