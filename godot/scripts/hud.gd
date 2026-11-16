class_name Hud
extends CanvasLayer
## Minimal heads-up display: a dot to aim with, a speed read-out for judging the feel, the run timer,
## and a line of text for messages. On a touchscreen it also draws and reads the thumb controls.

var player: Player
var _speed: Label
var _state: Label
var _timer: Label
var _msg: Label
var _msg_until := 0.0
var _flash: Label
var _flash_until := 0.0
var _clock := 0.0
var time := 0.0
var running := true
var _touch: TouchPad


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.75)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)

	_speed = _label(root, 34, Control.PRESET_BOTTOM_LEFT, Vector2(28, -92))
	_state = _label(root, 18, Control.PRESET_BOTTOM_LEFT, Vector2(30, -46))
	_state.modulate = Color(0.95, 0.75, 0.42)
	_timer = _label(root, 26, Control.PRESET_TOP_RIGHT, Vector2(-150, 22))
	_msg = _label(root, 30, Control.PRESET_CENTER_TOP, Vector2(-500, 120))
	_msg.custom_minimum_size = Vector2(1000, 0)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash = _label(root, 22, Control.PRESET_CENTER, Vector2(-200, 40))
	_flash.custom_minimum_size = Vector2(400, 0)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.modulate = Color(0.95, 0.75, 0.42)

	if DisplayServer.is_touchscreen_available():
		_touch = TouchPad.new()
		root.add_child(_touch)


func _label(parent: Control, font_size: int, preset: int, offset: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.set_anchors_preset(preset)
	l.position += offset
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func bind(p: Player) -> void:
	player = p
	if _touch:
		_touch.player = p
	p.move_event.connect(_on_move)


func message(text: String, seconds := 3.5) -> void:
	_msg.text = text
	_msg.modulate.a = 1.0
	_msg_until = _clock + seconds


func _on_move(what: String) -> void:
	var names := {"ricochet": "RICOCHET", "wall_run": "WALL RUN", "wall_jump": "KICK OFF", "double_jump": "SECOND JUMP", "slide": "SLIDE"}
	if names.has(what):
		_flash.text = names[what]
		_flash.modulate.a = 1.0
		_flash_until = _clock + 0.7


func _process(delta: float) -> void:
	_clock += delta
	if running and not get_tree().paused:
		time += delta
	if player:
		_speed.text = "%4.1f m/s" % player.speed_flat()
		_state.text = player.state_name()
	_timer.text = "%d:%04.1f" % [int(time) / 60, fmod(time, 60.0)]
	if _clock > _msg_until:
		_msg.modulate.a = maxf(0.0, _msg.modulate.a - delta * 1.5)
	if _clock > _flash_until:
		_flash.modulate.a = maxf(0.0, _flash.modulate.a - delta * 4.0)


## Thumb controls: the left side of the screen is a floating stick, the right side looks around,
## and two round buttons in the bottom-right corner jump and crouch/slide.
class TouchPad:
	extends Control

	var player: Player
	var _stick_id := -1
	var _stick_origin := Vector2.ZERO
	var _stick_vec := Vector2.ZERO
	var _look_id := -1
	var _btn_ids := {}                       # touch index -> action

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _buttons() -> Dictionary:
		var s := get_viewport_rect().size
		var r := minf(s.x, s.y) * 0.085
		return {"jump": [Vector2(s.x - r * 1.7, s.y - r * 1.9), r * 1.15], "crouch": [Vector2(s.x - r * 4.3, s.y - r * 1.5), r]}

	func _input(event: InputEvent) -> void:
		var s := get_viewport_rect().size
		if event is InputEventScreenTouch:
			if event.pressed:
				var b := _buttons()
				for action in b:
					if event.position.distance_to(b[action][0]) <= b[action][1] * 1.25:
						_btn_ids[event.index] = action
						Input.action_press(action)
						queue_redraw()
						return
				if event.position.x < s.x * 0.45 and _stick_id < 0:
					_stick_id = event.index
					_stick_origin = event.position
					_stick_vec = Vector2.ZERO
				elif _look_id < 0:
					_look_id = event.index
			else:
				if _btn_ids.has(event.index):
					Input.action_release(_btn_ids[event.index])
					_btn_ids.erase(event.index)
				if event.index == _stick_id:
					_stick_id = -1
					_stick_vec = Vector2.ZERO
					_apply_stick()
				if event.index == _look_id:
					_look_id = -1
			queue_redraw()
		elif event is InputEventScreenDrag:
			if event.index == _stick_id:
				var reach := minf(s.x, s.y) * 0.13
				_stick_vec = ((event.position - _stick_origin) / reach).limit_length(1.0)
				_apply_stick()
				queue_redraw()
			elif event.index == _look_id or _btn_ids.has(event.index):
				if player:
					player.touch_look += event.relative        # dragging off a button still turns the view

	func _apply_stick() -> void:
		var v := _stick_vec
		_axis("move_left", "move_right", v.x)
		_axis("move_forward", "move_back", v.y)

	func _axis(neg: String, pos: String, value: float) -> void:
		if value < -0.12:
			Input.action_press(neg, -value)
			Input.action_release(pos)
		elif value > 0.12:
			Input.action_press(pos, value)
			Input.action_release(neg)
		else:
			Input.action_release(neg)
			Input.action_release(pos)

	func _draw() -> void:
		var s := get_viewport_rect().size
		var b := _buttons()
		for action in b:
			var held: bool = _btn_ids.values().has(action)
			draw_circle(b[action][0], b[action][1], Color(1, 0.9, 0.75, 0.32 if held else 0.14))
			draw_arc(b[action][0], b[action][1], 0.0, TAU, 40, Color(1, 0.9, 0.75, 0.6), 2.0)
		if _stick_id >= 0:
			var reach := minf(s.x, s.y) * 0.13
			draw_arc(_stick_origin, reach, 0.0, TAU, 40, Color(1, 0.9, 0.75, 0.4), 2.0)
			draw_circle(_stick_origin + _stick_vec * reach, reach * 0.42, Color(0.95, 0.75, 0.42, 0.6))
