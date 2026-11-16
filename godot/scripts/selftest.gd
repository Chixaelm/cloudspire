extends Node
## Headless checks, run with:  godot --headless --fixed-fps 120 --path . -- --selftest
## Drives the real controls and prints what the body actually does, then tries to run the level.

var p: Player
var level: Node3D
var _failed := 0


func start(player: Player, lvl: Node3D) -> void:
	p = player
	level = lvl
	_run.call_deferred()


func _tick(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _release() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch"]:
		Input.action_release(a)


func _put(pos: Vector3, yaw := 0.0) -> void:
	_release()
	p.global_position = pos
	p.yaw = yaw
	p.rotation.y = yaw
	p.velocity = Vector3.ZERO
	p._reset_motion()
	await _tick(30)


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		_failed += 1
	print("%s  %-34s %s" % ["PASS" if ok else "FAIL", name, detail])


func _tap(action: String, hold := 2) -> void:
	Input.action_press(action)
	await _tick(hold)
	Input.action_release(action)


func _run() -> void:
	await _tick(20)
	var yard := 8.4
	var open := Vector3(-2.0, yard + 0.05, -158.0)       # open paving in the proving yard, facing -Z

	# 1. pace
	await _put(Vector3(4.5, yard + 0.05, -156.0))
	Input.action_press("move_forward")
	await _tick(60)
	var v_half := p.speed_flat()
	await _tick(300)
	var v_three := p.speed_flat()
	_check("run pace", v_half > 5.0 and v_half < 6.6 and v_three > 8.2 and v_three < 8.8, "0.5 s: %.2f m/s   3 s: %.2f m/s" % [v_half, v_three])
	Input.action_release("move_forward")
	var t := 0
	while p.speed_flat() > 0.1 and t < 400:
		await _tick()
		t += 1
	_check("stopping", t < 90, "from sprint to rest in %.2f s" % (t / 120.0))

	# 2. standing jump, and the second jump
	await _put(open)
	var y0 := p.global_position.y
	Input.action_press("jump")
	var apex := 0.0
	var air := 0
	await _tick(3)
	while not p.is_on_floor() and air < 600:
		apex = maxf(apex, p.global_position.y - y0)
		await _tick()
		air += 1
	_check("jump", apex > 0.9 and apex < 1.15, "apex %.2f m, %.2f s aloft" % [apex, air / 120.0])
	await _put(open)
	await _tap("jump")
	apex = 0.0
	await _tick(3)
	while not p.is_on_floor():
		apex = maxf(apex, p.global_position.y - y0)
		await _tick()
	_check("tapped hop", apex > 0.3 and apex < 0.6, "apex %.2f m" % apex)
	await _put(open)
	await _tap("jump", 50)
	await _tick(4)
	await _tap("jump")
	apex = 0.0
	air = 0
	while not p.is_on_floor() and air < 900:
		apex = maxf(apex, p.global_position.y - y0)
		await _tick()
		air += 1
	_check("second jump", apex > 1.7 and apex < 2.2, "apex %.2f m" % apex)

	# 3. running jump distance at a jog
	await _put(open)
	Input.action_press("move_forward")
	await _tick(50)
	var z0 := p.global_position.z
	Input.action_press("jump")
	await _tick(3)
	while not p.is_on_floor():
		await _tick()
	Input.action_release("jump")
	_check("jog jump length", absf(p.global_position.z - z0) > 4.2 and absf(p.global_position.z - z0) < 6.2, "%.2f m" % absf(p.global_position.z - z0))

	# 4. slide on the flat: a shove, then drag
	await _put(Vector3(4.5, yard + 0.05, -156.0))
	Input.action_press("move_forward")
	await _tick(240)
	var before := p.speed_flat()
	Input.action_press("crouch")
	await _tick(4)
	var kicked := p.speed_flat()
	await _tick(116)
	var after1 := p.speed_flat()
	z0 = p.global_position.z
	t = 0
	while p.sliding and t < 1200:
		await _tick()
		t += 1
	_check("slide on flat", kicked > before + 0.8 and after1 < kicked - 2.5 and not p.sliding, "%.1f → %.1f on entry, %.1f after 1 s, ended after %.1f s" % [before, kicked, after1, (t + 120) / 120.0])
	_release()

	# 5. slide down the 28° slope: gravity beats friction
	await _put(Vector3(-5.6, yard + 6.55, -159.6))
	Input.action_press("move_forward")
	await _tick(40)
	Input.action_press("crouch")
	await _tick(20)
	var s_top := p.velocity.length()
	var s_max := s_top
	t = 0
	while p.global_position.y > yard + 0.6 and t < 600:
		s_max = maxf(s_max, p.velocity.length())
		await _tick()
		t += 1
	_check("slide down slope", s_max > s_top + 2.0, "%.1f m/s at the top, %.1f m/s at the fastest" % [s_top, s_max])
	_release()

	# 6. ricochet off the 30° wedge
	await _put(Vector3(0, yard + 0.05, -150.5))
	Input.action_press("move_forward")
	var hit := false
	var got := [false]
	var cb := func(what: String) -> void:
		if what == "ricochet":
			got[0] = true
	p.move_event.connect(cb)
	t = 0
	while t < 700 and not got[0]:
		# crouch a few frames before the wedge's foot at z = -170
		if not hit and p.global_position.z < -170.0 + p.speed_flat() * 0.05 + 0.3:
			hit = true
			Input.action_press("crouch")
		await _tick()
		t += 1
	var vy := p.velocity.y
	var vh := p.speed_flat()
	Input.action_release("crouch")
	var peak := p.global_position.y
	for i in 240:
		peak = maxf(peak, p.global_position.y)
		await _tick()
	_check("ricochet", got[0] and vy > 4.0, "left the wedge at %.1f m/s up, %.1f m/s forward; rose %.2f m" % [vy, vh, peak - yard])
	# and without the crouch: you just run up it
	await _put(Vector3(0, yard + 0.05, -150.5))
	Input.action_press("move_forward")
	got[0] = false
	await _tick(420)
	_check("no crouch, no ricochet", not got[0], "ran the wedge normally")
	p.move_event.disconnect(cb)
	_release()

	# 7. wall run: sprint at a shallow angle toward the wall's face (at x = 8.0), jump just before touching it
	await _put(Vector3(5.6, yard + 0.05, -154.5), -0.13)
	Input.action_press("move_forward")
	t = 0
	while p.global_position.x < 7.25 and t < 600:
		await _tick()
		t += 1
	Input.action_press("jump")
	var ran := 0
	var wz0 := 0.0
	var wy_max := 0.0
	t = 0
	while t < 480:
		if p.wall_running:
			if ran == 0:
				wz0 = p.global_position.z
			ran += 1
			wy_max = maxf(wy_max, p.global_position.y - yard)
		elif ran > 0:
			break
		await _tick()
		t += 1
	var wlen := absf(p.global_position.z - wz0)
	_check("wall run", ran > 60 and ran < 240, "held %.2f s over %.1f m, peaked %.2f m up, ended: %s" % [ran / 120.0, wlen, wy_max, p.wall_end])
	_release()
	# and kicking off it
	await _put(Vector3(5.6, yard + 0.05, -154.5), -0.13)
	Input.action_press("move_forward")
	t = 0
	while p.global_position.x < 7.25 and t < 600:
		await _tick()
		t += 1
	Input.action_press("jump")
	t = 0
	while not p.wall_running and t < 240:
		await _tick()
		t += 1
	Input.action_release("jump")
	await _tick(40)
	await _tap("jump")
	await _tick(2)
	_check("wall kick", not p.wall_running and p.velocity.x < -3.0 and p.velocity.y > 3.0, "left at %.1f m/s away from the wall, %.1f m/s up" % [-p.velocity.x, p.velocity.y])
	_release()
	# too slow: the wall should not take you
	await _put(Vector3(7.4, yard + 0.05, -163.0))
	Input.action_press("move_forward")
	await _tick(20)
	await _tap("jump")
	Input.action_press("move_right")
	var slow := false
	for i in 200:
		slow = slow or p.wall_running
		await _tick()
	_check("no wall run when slow", not slow, "")
	_release()

	await _course()
	print("SELFTEST %s (%d failed)" % ["OK" if _failed == 0 else "FAILED", _failed])
	get_tree().quit(1 if _failed > 0 else 0)


## A plain runner: follows way-points, jumps where the floor stops or a step blocks the way,
## and takes the second jump at the top of the arc when the landing is not yet under it.
func _course() -> void:
	p.checkpoint_index = -1
	p.place(level.spawn)
	level.done = false
	var bell := [false]
	level.finished.connect(func() -> void: bell[0] = true)
	var way: Array[Vector3] = [Vector3(0, 0, -4), Vector3(0, 0, -8.2), Vector3(0.6, 0, -15), Vector3(-0.4, 0, -22.2), Vector3(0, 0.6, -27.6), Vector3(0, 0.6, -32), Vector3(0, 0.6, -70),
		Vector3(0, 0.6, -80), Vector3(0, 1.4, -89.2), Vector3(0, 2.2, -93.7), Vector3(0, 3.8, -99), Vector3(0, 3.8, -107), Vector3(0, 3.8, -120),
		Vector3(-1, 5.0, -126), Vector3(1, 6.2, -131.5), Vector3(-1, 7.4, -137), Vector3(0, 8.4, -142.5), Vector3(0, 8.4, -145)]
	var i := 0
	var t := 0
	var deaths := [0]
	var seen := 0
	p.respawned.connect(func() -> void: deaths[0] += 1)
	var space := p.get_world_3d().direct_space_state
	while not bell[0] and t < 120 * 150 and deaths[0] < 8:
		var pos := p.global_position
		while i < way.size() - 1 and Vector2(pos.x - way[i].x, pos.z - way[i].z).length() < 1.1 and pos.y > way[i].y - 0.3:
			i += 1
		if deaths[0] > seen and p.is_on_floor():              # after a fall, pick the route back up from where we are
			seen = deaths[0]
			print("   course: fell heading for way-point %d %s" % [i, way[i]])
			i = 0
			while i < way.size() - 1 and way[i].z > pos.z - 0.5:
				i += 1
		var to := way[i] - pos
		var flat := Vector3(to.x, 0, to.z)
		p.yaw = atan2(-flat.x, -flat.z)
		Input.action_release("move_back")
		Input.action_press("move_forward")
		var fwd := flat.normalized()
		if p.is_on_floor():
			var ahead := pos + fwd * 0.55 + Vector3(0, 0.3, 0)
			var q := PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 1.2)
			q.exclude = [p.get_rid()]
			var gap := space.intersect_ray(q).is_empty()
			var q2 := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.25, 0), pos + Vector3(0, 0.25, 0) + fwd * 1.3)
			q2.exclude = [p.get_rid()]
			var blocked := not space.intersect_ray(q2).is_empty()
			# before a long gap, back up nothing: just make sure there is pace
			if gap or blocked:
				Input.action_press("jump")
			else:
				Input.action_release("jump")
		else:
			if p.air_jumps > 0 and p.velocity.y < 0.4:
				var dy := pos.y - way[i].y
				var disc := p.velocity.y * p.velocity.y + 2.0 * p.gravity * dy
				var tf := (p.velocity.y + sqrt(disc)) / p.gravity if disc > 0.0 else 0.0
				var land := pos + Vector3(p.velocity.x, 0, p.velocity.z) * tf
				land.y = way[i].y
				var below := PhysicsRayQueryParameters3D.create(land + Vector3.UP * 0.6, land + Vector3.DOWN * 0.3)
				below.exclude = [p.get_rid()]
				if disc > 0.0 and (land - way[i]).dot(fwd) > 0.4:
					Input.action_release("move_forward")
					Input.action_press("move_back")
				elif disc <= 0.0 or space.intersect_ray(below).is_empty():
					Input.action_release("jump")
					await _tick(2)
					Input.action_press("jump")
		await _tick()
		t += 1
	_release()
	var falls: int = deaths[0]
	_check("course", bell[0], "bell %s after %.1f s, falls: %d, reached way-point %d of %d" % ["rung" if bell[0] else "NOT rung", t / 120.0, falls, i, way.size() - 1])
