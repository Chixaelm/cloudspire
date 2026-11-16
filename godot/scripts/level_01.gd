extends Node3D
## Level one — the Courtyard of First Steps.
## Teaches the three things every later level leans on: running builds pace, a jump carries the pace you had,
## and the second jump is there when the first is not enough. A proving yard past the bell lets you try the
## moves that later levels will teach properly: the slide, the ricochet and the wall run.

signal finished

const TITLE := "The Courtyard of First Steps"

var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 4))
var player: Player
var done := false

var _stone: StandardMaterial3D
var _pave: StandardMaterial3D
var _rock: StandardMaterial3D
var _wood: StandardMaterial3D
var _red: StandardMaterial3D
var _roof: StandardMaterial3D
var _plaster: StandardMaterial3D
var _gold: StandardMaterial3D
var _saffron: StandardMaterial3D
var _checkpoints := 0


func _ready() -> void:
	_stone = Build.mat(Color(0.5, 0.46, 0.42), 0.92, 0.0, 1.0, 0.6)
	_pave = Build.mat(Color(0.56, 0.5, 0.43), 0.85, 0.0, 0.8, 0.8)
	_rock = Build.mat(Color(0.36, 0.33, 0.31), 0.97, 0.0, 1.0, 0.07)
	_wood = Build.mat(Color(0.3, 0.19, 0.12), 0.8, 0.0, 0.6, 0.6)
	_red = Build.mat(Color(0.62, 0.11, 0.08), 0.42, 0.0, 0.25, 0.5)
	_roof = Build.mat(Color(0.16, 0.26, 0.28), 0.5, 0.0, 0.5, 0.8)
	_plaster = Build.mat(Color(0.74, 0.68, 0.58), 0.9, 0.0, 0.4, 0.6)
	_gold = Build.mat(Color(0.95, 0.72, 0.3), 0.3, 1.0, 0.0)
	_saffron = Build.mat(Color(0.91, 0.5, 0.12), 0.7, 0.0, 0.2, 0.5)
	_light()
	_start_terrace()
	_stepping_stones()
	_causeway()
	_steps()
	_long_gap()
	_bell_climb()
	_proving_yard()
	_scenery()


func bind(p: Player) -> void:
	player = p


# ───────────────────────── light and air
func _light() -> void:
	var mobile := OS.has_feature("mobile")
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-27.0, 128.0, 0.0)        # low, early light from ahead and over the drop on the right
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.7
	sun.light_angular_distance = 1.2                           # soft-edged shadows that widen with distance
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 130.0 if mobile else 260.0
	sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.36, 0.66)
	sky_mat.sky_horizon_color = Color(1.0, 0.74, 0.52)
	sky_mat.sky_curve = 0.09
	sky_mat.ground_horizon_color = Color(0.95, 0.72, 0.56)
	sky_mat.ground_bottom_color = Color(0.5, 0.42, 0.44)
	sky_mat.ground_curve = 0.06
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.12
	sky_mat.sky_energy_multiplier = 1.15
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.8, 0.72, 0.66)          # warm fill, so shade is not pure sky-blue
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	# distance haze that thickens low down, so the drop below reads as depth rather than a floor
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.68, 0.55)
	env.fog_sun_scatter = 0.35
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.25
	env.fog_height = -6.0
	env.fog_height_density = 0.045
	if not mobile:
		env.ssao_enabled = true
		env.ssao_radius = 1.4
		env.ssao_intensity = 2.2
		env.ssil_enabled = true
		env.sdfgi_enabled = true                                 # bounced light: red pillars tint the stone beside them
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 5
		env.sdfgi_min_cell_size = 0.25
		env.sdfgi_energy = 1.1
		env.volumetric_fog_enabled = true                        # visible shafts where the sun passes pillars
		env.volumetric_fog_density = 0.011
		env.volumetric_fog_albedo = Color(1.0, 0.9, 0.8)
		env.volumetric_fog_anisotropy = 0.7
		env.volumetric_fog_length = 140.0
		env.volumetric_fog_ambient_inject = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ───────────────────────── pieces
func _checkpoint(pos: Vector3, size: Vector3, face_yaw := 0.0) -> void:
	var index := _checkpoints
	_checkpoints += 1
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	a.add_child(cs)
	add_child(a)
	a.position = pos + Vector3(0, size.y * 0.5, 0)
	var t := Transform3D(Basis(Vector3.UP, face_yaw), pos + Vector3(0, 0.05, 0))
	a.body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			(b as Player).set_checkpoint(t, index))
	# a pair of saffron banners mark the spot
	for sx in [-1.0, 1.0]:
		Build.pillar(self, pos + Vector3(sx * (size.x * 0.5 - 0.3), 0, 0), 0.06, 2.6, _wood, false)
		Build.box(self, Vector3(0.5, 1.3, 0.03), pos + Vector3(sx * (size.x * 0.5 - 0.3), 1.9, 0), _saffron, Vector3.ZERO, false)


func _low_wall(a: Vector3, b: Vector3, h := 0.9) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var size := Vector3(absf(d.x) + 0.4, h, absf(d.z) + 0.4)
	Build.box(self, size, mid + Vector3(0, h * 0.5, 0), _plaster)
	Build.box(self, Vector3(size.x + 0.2, 0.14, size.z + 0.2), mid + Vector3(0, h + 0.07, 0), _roof, Vector3.ZERO, false)


func _start_terrace() -> void:
	Build.slab(self, Vector3(0, 0, 2), 12, 12, 3.0, _pave)                 # z from 8 to -4
	_low_wall(Vector3(-6, 0, 8), Vector3(6, 0, 8))
	_low_wall(Vector3(-6, 0, 8), Vector3(-6, 0, -1))
	_low_wall(Vector3(6, 0, 8), Vector3(6, 0, -1))
	Build.gate(self, Vector3(0, 0, -3.2), 4.2, 3.6, _red)
	Build.lantern(self, Vector3(-4.8, 1.5, 6.6))
	Build.lantern(self, Vector3(4.8, 1.5, 6.6))
	Build.sign(self, Vector3(0, 5.0, -3.2), "Run   W A S D  ·  left stick\nLook   mouse  ·  right stick", 0.0, 0.34)
	Build.sign(self, Vector3(0, 2.6, -5.6), "Jump   Space  ·  A", 0.0, 0.36)


func _stepping_stones() -> void:
	# gaps of 2.5, 3.2 and 3.8 m onto long stones: a jog and a full jump carries about five and a half metres,
	# so each landing is forgiving. Tap the jump instead of holding it and you only hop.
	Build.slab(self, Vector3(0, 0, -8.25), 3.2, 3.5, 6.0, _stone)          # -6.5 .. -10
	Build.slab(self, Vector3(0.6, 0, -14.95), 3.2, 3.5, 6.0, _stone)       # -13.2 .. -16.7
	Build.slab(self, Vector3(-0.4, 0, -22.25), 3.2, 3.5, 6.0, _stone)      # -20.5 .. -24
	Build.slab(self, Vector3(0, 0.6, -27.55), 3.2, 1.5, 6.6, _stone)       # -26.8 .. -28.3, a step up onto the next terrace
	Build.lantern(self, Vector3(2.0, 0.9, -14.95), 1.4, 6.0)
	Build.lantern(self, Vector3(-2.0, 1.5, -27.55), 1.4, 6.0)
	Build.sign(self, Vector3(0, 3.0, -10.5), "Hold jump for a full leap\ntap it for a short hop", 0.0, 0.28)


func _causeway() -> void:
	Build.slab(self, Vector3(0, 0.6, -32.3), 8, 8, 4.0, _pave)             # -28.3 .. -36.3
	_checkpoint(Vector3(0, 0.6, -31.0), Vector3(8, 3, 2))
	Build.sign(self, Vector3(0, 3.4, -36.0), "Keep running\nyour pace builds from a jog to a sprint", 0.0, 0.32)
	Build.slab(self, Vector3(0, 0.6, -53.15), 3.0, 33.7, 1.2, _stone)      # -36.3 .. -70, the run-up
	for i in 6:
		var z := -40.0 - i * 5.5
		Build.pillar(self, Vector3(-1.75, -6, z), 0.28, 6.0, _stone, false)
		Build.pillar(self, Vector3(1.75, -6, z), 0.28, 6.0, _stone, false)
		if i % 2 == 0:
			Build.pillar(self, Vector3(1.75, 0.6, z), 0.07, 1.6, _wood, false)
			Build.lantern(self, Vector3(1.75, 2.35, z), 1.6, 7.0)
	Build.sign(self, Vector3(0, 3.2, -68.5), "A sprinting jump clears this\nif you come up short — jump again in the air", 0.0, 0.3)
	# 6.5 m of air: a sprint makes it, a jog does not
	Build.slab(self, Vector3(0, 0.6, -81.5), 8, 10, 4.0, _pave)            # -76.5 .. -86.5
	_checkpoint(Vector3(0, 0.6, -79.5), Vector3(8, 3, 2))


func _steps() -> void:
	Build.sign(self, Vector3(0, 4.2, -86.3), "Jump again in the air\nSpace · Space", 0.0, 0.34)
	Build.slab(self, Vector3(0, 1.4, -89.25), 4.0, 2.5, 3.0, _stone)       # +0.8: one jump
	Build.slab(self, Vector3(0, 2.2, -93.75), 4.0, 2.5, 3.8, _stone)       # +0.8
	# +1.6: more than a jump reaches. The second jump is the only thing in this place that is not earned.
	Build.slab(self, Vector3(0, 3.8, -102.0), 5.0, 10.0, 5.4, _stone)      # -97 .. -107
	Build.box(self, Vector3(5.04, 0.12, 0.3), Vector3(0, 3.76, -97.1), _saffron, Vector3.ZERO, false)
	Build.lantern(self, Vector3(2.2, 4.6, -98.0), 1.6, 7.0)


func _long_gap() -> void:
	Build.sign(self, Vector3(0, 6.4, -106.6), "Run, jump at the edge,\nand jump again at the top of the arc", 0.0, 0.3)
	# 9.5 m: two jumps at a jog fall short, two jumps with a few strides of pace land it
	Build.slab(self, Vector3(0, 3.8, -119.5), 9, 6, 5.4, _pave)            # -116.5 .. -122.5
	_checkpoint(Vector3(0, 3.8, -119.5), Vector3(9, 3, 2))
	_low_wall(Vector3(-4.5, 3.8, -117), Vector3(-4.5, 3.8, -122))


func _bell_climb() -> void:
	# three stone piers, each 1.2 m above the last: more than one jump reaches, comfortably within two
	var tops := [Vector3(-1.0, 5.0, -126.0), Vector3(1.0, 6.2, -131.5), Vector3(-1.0, 7.4, -137.0)]
	for t in tops:
		Build.slab(self, t, 4.5, 4.0, 16.0, _stone)
		Build.box(self, Vector3(4.56, 0.12, 4.06), t - Vector3(0, 0.1, 0), _saffron, Vector3.ZERO, false)
	Build.lantern(self, Vector3(2.8, 7.0, -131.5), 1.2, 5.0)
	Build.sign(self, Vector3(0, 6.3, -122.8), "Two jumps a step", 0.0, 0.3)
	# the bell pavilion
	var c := Vector3(0, 8.4, -145.0)
	Build.slab(self, c, 9, 9, 5.0, _pave)                                   # -140.5 .. -149.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Build.pillar(self, c + Vector3(sx * 3.2, 0, sz * 3.2), 0.24, 4.2, _red)
	Build.box(self, Vector3(8.2, 0.3, 8.2), c + Vector3(0, 4.35, 0), _wood, Vector3.ZERO, false)
	Build.roof(self, c + Vector3(0, 5.6, 0), Vector3(9.6, 2.2, 9.6), _roof)
	Build.lantern(self, c + Vector3(-3.2, 3.3, 3.2), 2.4, 10.0, true)
	Build.lantern(self, c + Vector3(3.2, 3.3, -3.2), 2.4, 10.0)
	# the bell
	var bell := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.3
	bm.bottom_radius = 0.55
	bm.height = 1.1
	bell.mesh = bm
	bell.material_override = Build.mat(Color(0.66, 0.46, 0.18), 0.35, 1.0, 0.0)
	bell.position = c + Vector3(0, 2.7, 0)
	add_child(bell)
	Build.box(self, Vector3(0.06, 1.2, 0.06), c + Vector3(0, 3.8, 0), _wood, Vector3.ZERO, false)
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = 1.3
	s.height = 3.0
	cs.shape = s
	a.add_child(cs)
	a.position = c + Vector3(0, 1.5, 0)
	add_child(a)
	a.body_entered.connect(func(b: Node3D) -> void:
		if b is Player and not done:
			done = true
			(b as Player).set_checkpoint(Transform3D(Basis.IDENTITY, c + Vector3(0, 0.05, 2.5)), 99)
			finished.emit())
	Build.sign(self, c + Vector3(0, 3.3, 4.6), "Ring the bell", 0.0, 0.4)


func _proving_yard() -> void:
	# Past the bell: not part of level one. Three lanes to try what the next levels will teach.
	var y := 8.4
	Build.slab(self, Vector3(0, y, -151.5), 4, 4, 1.0, _stone)             # bridge -149.5 .. -153.5
	Build.slab(self, Vector3(0, y, -179.5), 22, 52, 4.0, _pave)            # yard -153.5 .. -205.5
	Build.gate(self, Vector3(0, y, -153.8), 3.6, 3.4, _red)
	Build.sign(self, Vector3(0, y + 4.5, -153.8), "The proving yard\nwhat the next courts will teach", 0.0, 0.34)

	# lane A (left): a tower and a 28° slope. On the flat a slide dies in a few metres; down this it keeps feeding.
	Build.ramp(self, Vector3(-9.2, y, -172.0), Vector3(-9.2, y + 6.5, -161.0), 2.4, 0.4, _wood)       # walk up
	Build.slab(self, Vector3(-7.4, y + 6.5, -159.0), 6.0, 4.0, 0.5, _stone)
	Build.pillar(self, Vector3(-7.4, y, -159.0), 0.5, 6.0, _stone)
	Build.ramp(self, Vector3(-5.6, y + 6.5, -161.0), Vector3(-5.6, y, -173.2), 3.0, 0.4, _saffron)    # slide down
	Build.sign(self, Vector3(-5.6, y + 8.6, -161.2), "Slide   Shift · B\nhold it down the slope", 0.0, 0.3)
	Build.sign(self, Vector3(-5.6, y + 2.4, -176.0), "On the flat it only drags", 0.0, 0.28)

	# lane B (middle): a 30° wedge. Run at it and crouch as you hit it.
	Build.ramp(self, Vector3(0, y, -170.0), Vector3(0, y + 1.9, -173.3), 4.0, 0.5, _saffron)
	Build.box(self, Vector3(4.0, 1.9, 0.3), Vector3(0, y + 0.95, -173.45), _stone)
	Build.sign(self, Vector3(0, y + 4.4, -173.5), "Ricochet\nhit the angle at speed and crouch on impact", 0.0, 0.3)

	# lane C (right): a mural wall. It only holds you while you are fast.
	Build.box(self, Vector3(0.4, 5.0, 16.0), Vector3(8.2, y + 2.5, -172.0), _plaster)
	Build.box(self, Vector3(0.44, 0.5, 16.0), Vector3(8.2, y + 1.6, -172.0), _saffron, Vector3.ZERO, false)
	Build.box(self, Vector3(0.6, 0.3, 16.4), Vector3(8.2, y + 5.15, -172.0), _red, Vector3.ZERO, false)
	Build.sign(self, Vector3(6.2, y + 3.4, -162.5), "Wall run\nsprint, jump into the wall, keep forward held\njump to kick off", 0.0, 0.26)

	# a second wedge on the far side set against a wall: ricochet up onto the ledge
	Build.slab(self, Vector3(0, y + 3.2, -198.0), 10, 6, 3.2, _stone)
	Build.ramp(self, Vector3(0, y, -190.5), Vector3(0, y + 1.6, -194.0), 5.0, 0.5, _saffron)
	Build.sign(self, Vector3(0, y + 5.6, -195.2), "A good ricochet reaches this ledge", 0.0, 0.28)
	for x in [-10.0, 10.0]:
		Build.lantern(self, Vector3(x, y + 1.4, -156.0), 2.0, 9.0)
		Build.lantern(self, Vector3(x, y + 1.4, -203.0), 2.0, 9.0)
	_low_wall(Vector3(-11, y, -205.5), Vector3(11, y, -205.5))


func _scenery() -> void:
	# the cliff the court is cut from, on the left; the drop is on the right
	Build.box(self, Vector3(40, 90, 70), Vector3(-27, -22, -20), _rock, Vector3(0, 6, 3))
	Build.box(self, Vector3(46, 110, 80), Vector3(-31, -18, -95), _rock, Vector3(0, -5, -2))
	Build.box(self, Vector3(50, 130, 90), Vector3(-37, -12, -178), _rock, Vector3(0, 4, 2))
	Build.box(self, Vector3(30, 60, 30), Vector3(-17, -27, -52), _rock, Vector3(8, 20, 0))
	# far ahead: the mountain this is all practice for
	var spire := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 70.0
	sm.bottom_radius = 240.0
	sm.height = 900.0
	sm.radial_segments = 24
	sm.rings = 12
	spire.mesh = sm
	spire.material_override = _rock
	spire.position = Vector3(160, 180, -1400)
	spire.rotation_degrees = Vector3(0, 0, 3)
	add_child(spire)
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 20.0
	cm.bottom_radius = 72.0
	cm.height = 90.0
	cap.mesh = cm
	cap.material_override = Build.mat(Color(0.9, 0.9, 0.93), 0.9, 0.0, 0.3, 0.02)
	cap.position = Vector3(160 - 26, 180 + 495, -1400)
	add_child(cap)
