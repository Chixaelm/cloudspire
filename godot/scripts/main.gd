extends Node3D
## Entry point: registers the controls, loads the level, drops the player in and runs the HUD.

var player: Player
var level: Node3D
var hud: Hud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()

	level = (load("res://scripts/level_01.gd") as GDScript).new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)

	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.place(level.spawn)
	level.bind(player)

	hud = Hud.new()
	add_child(hud)
	hud.bind(player)
	hud.message(level.TITLE, 4.0)

	player.checkpoint_reached.connect(func(i: int) -> void:
		if i < 99:
			hud.message("Checkpoint", 1.6))
	level.finished.connect(func() -> void:
		hud.running = false
		hud.message("The first bell rings   ·   %.1f s\nThe proving yard is through the gate" % hud.time, 8.0))

	if "--selftest" in OS.get_cmdline_user_args():
		var test: Node = (load("res://scripts/selftest.gd") as GDScript).new()
		add_child(test)
		test.start(player, level)
	elif not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot(arg.trim_prefix("--shot="))


## Development aid:  -- --shot=out.png,x,y,z,yaw_deg,pitch_deg   renders one frame from that spot and quits.
func _shot(spec: String) -> void:
	var a := spec.split(",")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if a.size() >= 4:
		player.global_position = Vector3(float(a[1]), float(a[2]), float(a[3]))
	if a.size() >= 5:
		player.yaw = deg_to_rad(float(a[4]))
	if a.size() >= 6:
		player.pitch = deg_to_rad(float(a[5]))
	for i in 150:                       # let the bounced light and the fog settle
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(a[0])
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
	elif event.is_action_pressed("restart") and not get_tree().paused:
		player.respawn()
	elif event is InputEventMouseButton and event.pressed and not DisplayServer.is_touchscreen_available():
		if get_tree().paused:
			_set_paused(false)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_paused(p: bool) -> void:
	get_tree().paused = p
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED
	if p:
		hud.message("Paused\nEsc or click to continue  ·  R returns to the last checkpoint", 9999.0)
	else:
		hud.message("", 0.0)


# ───────────────────────── controls, defined in code so the project file stays readable
func _setup_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]], [JOY_BUTTON_DPAD_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]], [JOY_BUTTON_DPAD_RIGHT])
	_action("move_forward", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]], [JOY_BUTTON_DPAD_UP])
	_action("move_back", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]], [JOY_BUTTON_DPAD_DOWN])
	_action("look_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]], [])
	_action("look_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]], [])
	_action("look_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]], [])
	_action("look_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]], [])
	_action("jump", [KEY_SPACE], [], [], [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER])
	_action("crouch", [KEY_SHIFT, KEY_C, KEY_CTRL], [MOUSE_BUTTON_RIGHT], [[JOY_AXIS_TRIGGER_LEFT, 1.0]], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_STICK])
	_action("restart", [KEY_R], [], [], [JOY_BUTTON_Y])
	_action("pause", [KEY_ESCAPE], [], [], [JOY_BUTTON_START])


func _action(action: String, keys: Array, mouse: Array, axes: Array, buttons: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.2)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for m in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = m
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
