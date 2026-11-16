class_name Build
extends RefCounted
## Small helpers for blocking out levels in code: every piece is a StaticBody3D with a mesh and a matching
## collision shape, so what you see is exactly what you stand on.

static var _noise_cache := {}


## A tileable noise texture, optionally as a normal map. Cached by parameters.
static func noise_tex(seed_value: int, freq: float, as_normal := false, bump := 6.0) -> NoiseTexture2D:
	var key := "%d_%f_%s_%f" % [seed_value, freq, as_normal, bump]
	if _noise_cache.has(key):
		return _noise_cache[key]
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 5
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	t.as_normal_map = as_normal
	t.bump_strength = bump
	_noise_cache[key] = t
	return t


## A matte, slightly uneven material mapped in world space so boxes of any size share one texel density.
static func mat(color: Color, rough := 0.9, metal := 0.0, grain := 1.0, tile := 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if grain > 0.0:
		# light/dark mottling from noise, plus a bump map, both triplanar
		var g := Gradient.new()
		g.set_color(0, Color(1.0 - 0.45 * grain, 1.0 - 0.45 * grain, 1.0 - 0.45 * grain))
		g.set_color(1, Color(1, 1, 1))
		var albedo := noise_tex(11 + int(grain * 100.0), 0.012)      # one texture per grain strength, since the ramp differs
		albedo.color_ramp = g
		m.albedo_texture = albedo
		m.normal_enabled = true
		m.normal_texture = noise_tex(23, 0.03, true, 5.0 * grain)
		m.normal_scale = 0.8
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(tile, tile, tile)
	return m


static func glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _body(parent: Node3D, pos: Vector3, rot_deg: Vector3, collide: bool) -> Node3D:
	var b: Node3D = StaticBody3D.new() if collide else Node3D.new()
	parent.add_child(b)
	b.position = pos
	b.rotation_degrees = rot_deg
	return b


## An axis-aligned (or rotated) block. `pos` is its centre.
static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot_deg := Vector3.ZERO, collide := true) -> Node3D:
	var b := _body(parent, pos, rot_deg, collide)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	b.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		b.add_child(cs)
	return b


## A block whose TOP face is at `top_y`, handy for platforms: `center_xz` is the middle of the top.
static func slab(parent: Node3D, center: Vector3, size_x: float, size_z: float, thickness: float, material: Material) -> Node3D:
	return box(parent, Vector3(size_x, thickness, size_z), center - Vector3(0, thickness * 0.5, 0), material)


## A flat ramp whose top surface runs from `from` to `to` (both on the centre line of the top face).
static func ramp(parent: Node3D, from: Vector3, to: Vector3, width: float, thickness: float, material: Material) -> Node3D:
	var d := to - from
	var length := d.length()
	var fwd := d / length
	var up_hint := Vector3.UP if absf(fwd.y) < 0.99 else Vector3.FORWARD
	var basis := Basis.looking_at(fwd, up_hint)        # -Z along the ramp
	var b := StaticBody3D.new()
	parent.add_child(b)
	b.transform = Transform3D(basis, (from + to) * 0.5 - basis.y * thickness * 0.5)
	var size := Vector3(width, thickness, length)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	return b


## A round pillar standing on `base` (the centre of its foot).
static func pillar(parent: Node3D, base: Vector3, radius: float, height: float, material: Material, collide := true) -> Node3D:
	var b := _body(parent, base + Vector3(0, height * 0.5, 0), Vector3.ZERO, collide)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mi.mesh = mesh
	mi.material_override = material
	b.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		b.add_child(cs)
	return b


## A simple pitched roof (no collision): ridge runs along local X.
static func roof(parent: Node3D, center: Vector3, size: Vector3, material: Material, yaw_deg := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	parent.add_child(mi)
	mi.position = center
	mi.rotation_degrees = Vector3(0, yaw_deg, 0)
	return mi


## A paper lantern: a glowing block with a warm point light inside.
static func lantern(parent: Node3D, pos: Vector3, energy := 2.2, light_range := 9.0, shadows := false) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = pos
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.2
	mesh.height = 0.42
	mi.mesh = mesh
	mi.material_override = glow(Color(1.0, 0.55, 0.22), 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.3)
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	n.add_child(l)
	return n


## A torii-style gate spanning local X, standing on `base`.
static func gate(parent: Node3D, base: Vector3, width: float, height: float, material: Material, yaw_deg := 0.0) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = base
	n.rotation_degrees = Vector3(0, yaw_deg, 0)
	for sx in [-1.0, 1.0]:
		pillar(n, Vector3(sx * width * 0.5, 0, 0), 0.22, height, material)
	box(n, Vector3(width + 1.6, 0.3, 0.45), Vector3(0, height + 0.15, 0), material, Vector3.ZERO, false)
	box(n, Vector3(width + 0.6, 0.22, 0.3), Vector3(0, height - 0.6, 0), material, Vector3.ZERO, false)
	return n


## Floating text in the world, used for the teaching signs.
static func sign(parent: Node3D, pos: Vector3, text: String, yaw_deg := 0.0, size := 0.5) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.outline_size = 18
	l.modulate = Color(1.0, 0.93, 0.8)
	l.outline_modulate = Color(0.1, 0.05, 0.03, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.double_sided = true
	l.no_depth_test = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	l.position = pos
	l.rotation_degrees = Vector3(0, yaw_deg, 0)
	return l
