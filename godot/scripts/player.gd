class_name Player
extends CharacterBody3D
## First-person monk. Everything is in metres and seconds, and gravity is real (9.81).
##
## The one deliberate cheat is the second jump. Everything else follows momentum:
##  - running builds pace gradually, and stopping takes friction;
##  - in the air there is almost no steering;
##  - a slide is a short shove followed by friction, unless a slope keeps feeding it;
##  - a wall only carries you while you are fast enough for your feet to grip, and the grip fades;
##  - hit an angled surface at speed and crouch on impact, and you ricochet off it instead of sticking.

signal checkpoint_reached(index: int)
signal respawned
signal move_event(what: String)

@export_group("Body")
@export var stand_height := 1.8
@export var crouch_height := 1.0
@export var radius := 0.3
@export var eye_drop := 0.12                 ## eyes sit this far below the top of the head

@export_group("Run")
@export var jog_speed := 5.5                 ## pace you reach almost at once
@export var sprint_speed := 8.5              ## pace you build up to by not stopping
@export var ground_accel := 24.0
@export var pace_gain := 1.5                 ## m/s gained per second of sustained running
@export var pace_loss := 7.0
@export var ground_friction := 18.0          ## braking with no input
@export var overspeed_drag := 2.5            ## how fast speed above your pace bleeds off on foot
@export var crouch_speed := 2.2
@export var slope_pull := 0.35               ## share of gravity felt along a slope while running

@export_group("Air")
@export var gravity := 9.81
@export var jump_speed := 4.5                ## about a 1 m standing jump
@export var hop_speed := 2.6                 ## let go of jump early and the rise is trimmed to this: a short hop
@export var double_jump_speed := 4.2
@export var double_jump_steer := 1.5         ## sideways shove the second jump may add
@export var air_accel := 5.0
@export var air_wish_speed := 1.2            ## air steering can only add this much speed in a new direction
@export var coyote_time := 0.1
@export var jump_buffer := 0.12

@export_group("Slide")
@export var slide_min_speed := 4.0
@export var slide_boost := 1.3               ## the push from dropping into a slide
@export var slide_boost_cap := 10.0          ## the push never takes you past this
@export var slide_boost_cooldown := 1.0
@export var slide_friction := 0.36           ## friction coefficient: on the flat you lose ~3.5 m/s every second
@export var slide_steer := 1.2
@export var slide_stop_speed := 1.5

@export_group("Wall run")
@export var wallrun_min_speed := 5.0         ## along-wall speed needed to start
@export var wallrun_hold_speed := 3.6        ## below this you peel off
@export var wallrun_grip := 0.85             ## at most this share of your weight is carried, at sprint pace
@export var wallrun_max_time := 1.6          ## grip fades to nothing over this long
@export var wallrun_drag := 1.4
@export var wall_jump_push := 4.0
@export var wall_jump_up := 4.2

@export_group("Ricochet")
@export var ricochet_window := 0.14          ## crouch this close to the impact, before or after
@export var ricochet_restitution := 0.8      ## how much of the impact comes back
@export var ricochet_min_impact := 2.5       ## m/s into the surface
@export var ricochet_min_angle := 12.0       ## degrees from flat
@export var ricochet_max_angle := 80.0

@export_group("Look")
@export var mouse_sensitivity := 0.0022
@export var stick_sensitivity := 3.2
@export var base_fov := 82.0
@export var kill_y := -14.0

var yaw := 0.0
var pitch := 0.0
var pace := 5.5
var height := 1.8
var crouching := false
var sliding := false
var wall_running := false
var wall_normal := Vector3.ZERO
var last_wall_normal := Vector3.ZERO
var wall_time := 0.0
var wall_end := ""                           ## why the last wall run ended (for tuning)
var air_jumps := 1
var checkpoint := Transform3D.IDENTITY
var checkpoint_index := -1
var frozen := false
var touch_look := Vector2.ZERO               ## set by the touch layer; consumed each frame

var _coyote := 0.0
var _jump_buf := 0.0
var _slide_cd := 0.0
var _ricochet_cd := 0.0
var _crouch_pressed_at := -10.0
var _impact_at := -10.0
var _impact_n := Vector3.UP
var _impact_v := Vector3.ZERO
var _was_on_floor := false
var _no_snap := 0.0
var _now := 0.0
var _roll := 0.0
var _land_dip := 0.0
var _bob := 0.0
var _rising := false                         ## in the rise of a ground jump that can still be cut short

var _shape: CapsuleShape3D
var _col: CollisionShape3D
var head: Node3D
var camera: Camera3D
var _figure: Node3D


func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.3
	floor_stop_on_slope = true
	floor_block_on_wall = true
	max_slides = 6
	safe_margin = 0.002
	height = stand_height
	pace = jog_speed

	_shape = CapsuleShape3D.new()
	_shape.radius = radius
	_shape.height = stand_height
	_col = CollisionShape3D.new()
	_col.shape = _shape
	_col.position.y = stand_height * 0.5
	add_child(_col)

	head = Node3D.new()
	head.position.y = stand_height - eye_drop
	add_child(head)
	camera = Camera3D.new()
	camera.fov = base_fov
	camera.near = 0.05
	camera.far = 4000.0
	camera.current = true
	head.add_child(camera)

	_build_figure()
	checkpoint = global_transform


## A human-proportioned figure that only casts a shadow, so you see a monk's shadow rather than a pill's.
func _build_figure() -> void:
	_figure = Node3D.new()
	add_child(_figure)
	var parts := [
		# [mesh kind, size a, size b, position]
		["sphere", 0.11, 0.0, Vector3(0, 1.66, 0)],            # head
		["capsule", 0.17, 0.62, Vector3(0, 1.24, 0)],          # torso
		["cone", 0.34, 0.95, Vector3(0, 0.5, 0)],              # robe
		["capsule", 0.055, 0.62, Vector3(-0.25, 1.16, 0)],     # arms
		["capsule", 0.055, 0.62, Vector3(0.25, 1.16, 0)],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		match p[0]:
			"sphere":
				var s := SphereMesh.new()
				s.radius = p[1]
				s.height = p[1] * 2.0
				mi.mesh = s
			"capsule":
				var c := CapsuleMesh.new()
				c.radius = p[1]
				c.height = p[2]
				mi.mesh = c
			"cone":
				var k := CylinderMesh.new()
				k.top_radius = 0.16
				k.bottom_radius = p[1]
				k.height = p[2]
				mi.mesh = k
		mi.position = p[3]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_figure.add_child(mi)


func place(t: Transform3D) -> void:
	global_position = t.origin
	yaw = t.basis.get_euler().y
	pitch = 0.0
	velocity = Vector3.ZERO
	checkpoint = t
	_reset_motion()


func _reset_motion() -> void:
	sliding = false
	crouching = false
	wall_running = false
	last_wall_normal = Vector3.ZERO
	air_jumps = 1
	pace = jog_speed
	_coyote = 0.0
	_jump_buf = 0.0
	_impact_at = -10.0


func set_checkpoint(t: Transform3D, index: int) -> void:
	if index > checkpoint_index:
		checkpoint_index = index
		checkpoint = t
		checkpoint_reached.emit(index)


func respawn() -> void:
	global_position = checkpoint.origin
	yaw = checkpoint.basis.get_euler().y
	pitch = 0.0
	velocity = Vector3.ZERO
	_reset_motion()
	respawned.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.5, 1.5)


func _process(delta: float) -> void:
	# look: right stick and touch drag (the mouse is handled as events)
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length_squared() > 0.0:
		var k := look.length()                    # squared response: finer aim near the centre
		yaw -= look.x * k * stick_sensitivity * delta
		pitch = clampf(pitch - look.y * k * stick_sensitivity * 0.7 * delta, -1.5, 1.5)
	if touch_look != Vector2.ZERO:
		yaw -= touch_look.x * 0.005
		pitch = clampf(pitch - touch_look.y * 0.005, -1.5, 1.5)
		touch_look = Vector2.ZERO

	# camera: lean on walls, dip on landings, widen with speed
	var target_roll := 0.0
	if wall_running:
		var right := Basis(Vector3.UP, yaw).x
		target_roll = -0.16 * signf(wall_normal.dot(right))
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-10.0 * delta))
	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-9.0 * delta))
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and not sliding:
		_bob += hs * delta * 1.9
	var bob := sin(_bob) * 0.022 * clampf(hs / sprint_speed, 0.0, 1.0)
	rotation.y = yaw
	head.position.y = height - eye_drop - _land_dip + bob
	head.rotation = Vector3(pitch, 0.0, _roll)
	var fov_k := clampf((hs - jog_speed) / (sprint_speed + 3.0 - jog_speed), 0.0, 1.0)
	camera.fov = lerpf(camera.fov, base_fov + 12.0 * fov_k, 1.0 - exp(-6.0 * delta))


func _physics_process(delta: float) -> void:
	_now += delta
	if frozen:
		return
	_coyote -= delta
	_jump_buf -= delta
	_slide_cd -= delta
	_ricochet_cd -= delta
	_no_snap -= delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var wish_len := minf(wish.length(), 1.0)
	if wish_len > 0.001:
		wish = wish / wish.length()
	var crouch_held := Input.is_action_pressed("crouch")
	if Input.is_action_just_pressed("jump"):
		_jump_buf = jump_buffer
	if Input.is_action_just_pressed("crouch"):
		_crouch_pressed_at = _now
		# crouched a hair late: the impact is still fresh enough to turn into a ricochet
		if _now - _impact_at <= ricochet_window and _ricochet_cd <= 0.0:
			_ricochet()

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = coyote_time
		if not _was_on_floor:
			_landed(crouch_held)
	if wall_running:
		_wall_run(delta, wish, wish_len, crouch_held)
	elif on_floor:
		_ground(delta, wish, wish_len, crouch_held)
	else:
		_air(delta, wish, wish_len)
	_was_on_floor = on_floor

	_update_height(delta, crouch_held)

	# leave ramps and crests with the velocity you have rather than being glued down
	floor_snap_length = 0.3 if (on_floor and velocity.y <= 0.6 and _no_snap <= 0.0) else 0.0
	var pre := velocity
	move_and_slide()
	_after_move(pre)

	if global_position.y < kill_y:
		respawn()


# ───────────────────────── ground
func _ground(delta: float, wish: Vector3, wish_len: float, crouch_held: bool) -> void:
	var n := get_floor_normal()
	var v := _tangent(velocity, n)                # stay in the plane of the floor, so a ramp's end launches you
	var speed := v.length()
	var pull := (Vector3.DOWN * gravity).slide(n)  # the part of gravity that points down the slope

	if not sliding and Input.is_action_just_pressed("crouch") and speed >= slide_min_speed and _ricochet_cd <= 0.0:
		_start_slide()
		v = _tangent(velocity, n)
		speed = v.length()

	if sliding:
		# a body on a surface: gravity along the slope, minus friction
		v += pull * delta
		var fr := slide_friction * gravity * n.y * delta
		speed = v.length()
		if speed > fr:
			v -= v / speed * fr
		else:
			v = Vector3.ZERO
		speed = v.length()
		if wish_len > 0.0 and speed > 0.5:          # lean to steer a little; it never adds speed
			var dir := v / speed
			var side := wish - dir * wish.dot(dir)
			v = (dir + side * slide_steer * delta).normalized() * speed
		var downhill := pull.length() > slide_friction * gravity * n.y
		if not crouch_held and _can_stand():
			_end_slide()
		elif speed < slide_stop_speed and not downhill:
			_end_slide()
			crouching = true
	else:
		crouching = crouch_held or (crouching and not _can_stand())
		var top := crouch_speed if crouching else pace
		# pace: hold a run and it builds from a jog to a sprint; ease off and it goes
		if not crouching and wish_len > 0.8 and speed > pace - 0.6:
			pace = minf(sprint_speed, pace + pace_gain * delta)
		elif speed < pace - 1.5:
			pace = maxf(jog_speed, pace - pace_loss * delta)
		if wish_len > 0.0:
			var wt := wish.slide(n)
			if wt.length_squared() > 0.0001:
				wt = wt.normalized()
			if speed <= top + 0.05:
				v = v.move_toward(wt * top * wish_len, ground_accel * delta)
			else:
				# carrying more speed than your legs make: you can turn it, but it bleeds away
				v = v.move_toward(wt * speed, ground_accel * 0.5 * delta)
				var s2 := v.length()
				if s2 > 0.001:
					v = v / s2 * maxf(top, s2 - overspeed_drag * delta)
		else:
			v = v.move_toward(Vector3.ZERO, ground_friction * delta)
		if v.length() > 1.0:
			v += pull * slope_pull * delta            # downhill is quicker, uphill costs
	velocity = v

	if _jump_buf > 0.0:
		_jump()


## The engine drops the vertical part of the velocity while you stand on a floor. Rebuild the true
## along-the-surface velocity from the horizontal part, so speed on a slope is neither lost nor invented.
func _tangent(v: Vector3, n: Vector3) -> Vector3:
	if n.y < 0.05:
		return v.slide(n)
	return Vector3(v.x, -(n.x * v.x + n.z * v.z) / n.y, v.z)


func _jump() -> void:
	_jump_buf = 0.0
	_coyote = 0.0
	if sliding:
		_end_slide()
	velocity.y = maxf(velocity.y, 0.0) + jump_speed
	_no_snap = 0.15
	_rising = true
	move_event.emit("jump")


func _start_slide() -> void:
	sliding = true
	crouching = true
	if _slide_cd <= 0.0:
		var hv := velocity
		var sp := hv.length()
		if sp > 0.01:
			var boosted := maxf(sp, minf(sp + slide_boost, slide_boost_cap))
			velocity = hv / sp * boosted
	move_event.emit("slide")


func _end_slide() -> void:
	sliding = false
	_slide_cd = slide_boost_cooldown


func _landed(crouch_held: bool) -> void:
	air_jumps = 1
	_rising = false
	last_wall_normal = Vector3.ZERO
	wall_running = false
	var hs := Vector2(velocity.x, velocity.z).length()
	# land already crouched and moving: go straight into a slide and keep the speed
	if crouch_held and hs >= slide_min_speed and _ricochet_cd <= 0.0 and not sliding:
		_start_slide()


# ───────────────────────── air
func _air(delta: float, wish: Vector3, wish_len: float) -> void:
	if sliding:
		_end_slide()
	velocity.y -= gravity * delta
	if _rising:
		if velocity.y <= hop_speed:
			_rising = false
		elif not Input.is_action_pressed("jump"):
			velocity.y = hop_speed
			_rising = false
	if wish_len > 0.0:
		# almost no thrust up here: you can nudge, not fly
		var cur := Vector3(velocity.x, 0.0, velocity.z).dot(wish)
		var add := air_wish_speed * wish_len - cur
		if add > 0.0:
			velocity += wish * minf(air_accel * delta, add)

	if _jump_buf > 0.0:
		if _coyote > 0.0:
			_jump()
		elif air_jumps > 0:
			air_jumps -= 1
			_jump_buf = 0.0
			velocity.y = maxf(velocity.y, 0.0) * 0.5 + double_jump_speed
			if wish_len > 0.0:
				velocity += wish * double_jump_steer
			move_event.emit("double_jump")

	# catch a wall?
	if is_on_wall_only() and _ricochet_cd <= 0.0:
		var wn := get_wall_normal()
		if absf(wn.y) < 0.2:
			wn = Vector3(wn.x, 0.0, wn.z).normalized()
			var along := Vector3(velocity.x, 0.0, velocity.z).slide(wn)
			var fresh := last_wall_normal == Vector3.ZERO or wn.dot(last_wall_normal) < 0.8
			if fresh and along.length() >= wallrun_min_speed and velocity.y > -7.0 and wish_len > 0.3 and wish.dot(along.normalized()) > 0.2 and _clearance_below() > 0.7:
				wall_running = true
				wall_normal = wn
				wall_time = 0.0
				if velocity.y < 0.0:
					velocity.y *= 0.4               # the first footfall takes some of the fall out
				move_event.emit("wall_run")


# ───────────────────────── wall
func _wall_run(delta: float, wish: Vector3, wish_len: float, crouch_held: bool) -> void:
	wall_time += delta
	var along := Vector3(velocity.x, 0.0, velocity.z).slide(wall_normal)
	var sp := maxf(0.0, along.length() - wallrun_drag * delta)
	var dir := along.normalized() if along.length_squared() > 0.0001 else Vector3.ZERO
	# grip: feet hold part of your weight, more the faster you go, and less with every stride
	var k := clampf((sp - wallrun_hold_speed) / (sprint_speed - wallrun_hold_speed), 0.0, 1.0)
	var grip := wallrun_grip * (0.35 + 0.65 * k) * clampf(1.0 - wall_time / wallrun_max_time, 0.0, 1.0)
	velocity.y -= gravity * (1.0 - grip) * delta
	velocity.x = dir.x * sp - wall_normal.x * 1.2    # lean into the wall to keep contact
	velocity.z = dir.z * sp - wall_normal.z * 1.2

	var pulling_away := wish_len > 0.5 and wish.dot(wall_normal) > 0.75
	if _jump_buf > 0.0:
		_jump_buf = 0.0
		velocity = dir * sp + wall_normal * wall_jump_push
		velocity.y = maxf(velocity.y, 0.0) * 0.5 + wall_jump_up
		_leave_wall()
		move_event.emit("wall_jump")
	elif sp < wallrun_hold_speed or wall_time >= wallrun_max_time or pulling_away or crouch_held or is_on_floor() or not _wall_still_there():
		wall_end = "slow" if sp < wallrun_hold_speed else "grip gone" if wall_time >= wallrun_max_time else "pulled away" if pulling_away else "crouch" if crouch_held else "floor" if is_on_floor() else "wall ended"
		velocity.x = dir.x * sp
		velocity.z = dir.z * sp
		_leave_wall()


func _leave_wall() -> void:
	wall_running = false
	last_wall_normal = wall_normal


func _wall_still_there() -> bool:
	var from := global_position + Vector3(0, height * 0.55, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from - wall_normal * (radius + 0.45))
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _clearance_below() -> float:
	var from := global_position + Vector3(0, 0.1, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return 3.0 if hit.is_empty() else from.y - (hit["position"] as Vector3).y


# ───────────────────────── collisions: landings and ricochets
func _after_move(pre: Vector3) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		var vn := pre.dot(n)
		if vn > -ricochet_min_impact:
			continue
		if n.y > 0.5 and vn < -5.0:
			_land_dip = clampf(-vn * 0.02, 0.0, 0.3)
		var angle := rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))   # 0 is a floor, 90 a wall
		if angle >= ricochet_min_angle and angle <= ricochet_max_angle:
			_impact_at = _now
			_impact_n = n
			_impact_v = pre
			if _now - _crouch_pressed_at <= ricochet_window and _ricochet_cd <= 0.0:
				_ricochet()
			return


## Bounce off an angled surface: the part of the velocity that drove into it comes back out.
func _ricochet() -> void:
	var vn := _impact_v.dot(_impact_n)
	if vn >= 0.0:
		return
	velocity = _impact_v - (1.0 + ricochet_restitution) * vn * _impact_n
	_impact_at = -10.0
	_crouch_pressed_at = -10.0
	_ricochet_cd = 0.35
	_no_snap = 0.25
	if sliding:
		_end_slide()
	wall_running = false
	_coyote = 0.0
	move_event.emit("ricochet")


# ───────────────────────── stance
func _can_stand() -> bool:
	var from := global_position + Vector3(0, height - radius, 0)
	var q := PhysicsRayQueryParameters3D.create(from, global_position + Vector3(0, stand_height + 0.05, 0))
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _update_height(delta: float, crouch_held: bool) -> void:
	var low := sliding or crouching or (not is_on_floor() and crouch_held and not wall_running)
	var target := crouch_height if low else stand_height
	if target > height and not _can_stand():
		target = height
	height = move_toward(height, target, 6.0 * delta)
	_shape.height = height
	_col.position.y = height * 0.5
	_figure.scale.y = height / stand_height


func speed_flat() -> float:
	return Vector2(velocity.x, velocity.z).length()


func state_name() -> String:
	if wall_running:
		return "WALL RUN"
	if sliding:
		return "SLIDE"
	if not is_on_floor():
		return "AIR"
	if crouching:
		return "CROUCH"
	return "RUN" if speed_flat() > 0.5 else ""
