extends CanvasLayer
## THE VEIL - TEMPORARY touch controls for trying the game on an Android phone / tablet (autoload).
## Only active on a touchscreen device (does nothing on desktop). Left half: drag = walk (a virtual stick; it also
## steers / drives the car). Right half: drag = look. Buttons (bottom right): E use / talk / continue, INV inventory,
## RUN (hold), LIGHT flashlight, II pause. Taps on menus and the inventory still work as normal taps.

const BUTTONS := [["E", "interact", Vector2(-110, -120)], ["INV", "inventory", Vector2(-220, -70)],
	["RUN", "sprint", Vector2(-110, -240)], ["LIGHT", "flashlight", Vector2(-220, -190)], ["II", "pause", Vector2(-80, 60)]]
const STICK_R := 90.0
const LOOK_SENS := 0.006

var active := false
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _look_id := -1
var _button_ids := {}            ## touch index -> action held by that touch
var _rects: Array = []           ## [Rect2, action]
var _stick_ui: Control
var _knob: Control


func _ready() -> void:
	active = DisplayServer.is_touchscreen_available()
	if not active:
		return
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stick_ui = _circle(STICK_R * 2.0, Color(1, 1, 1, 0.10))
	add_child(_stick_ui)
	_knob = _circle(70.0, Color(1, 1, 1, 0.25))
	_stick_ui.add_child(_knob)
	_stick_ui.visible = false
	for b in BUTTONS:
		var c := _circle(84.0, Color(0.05, 0.06, 0.07, 0.55))
		var l := Label.new()
		l.text = b[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.add_theme_font_size_override("font_size", 20)
		c.add_child(l)
		c.set_meta("action", b[1])
		c.set_meta("offset", b[2])
		add_child(c)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _circle(d: float, col: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = col
	st.set_corner_radius_all(int(d / 2))
	st.border_color = Color(1, 1, 1, 0.3)
	st.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", st)
	return p


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	_rects.clear()
	for c in get_children():
		if c.has_meta("action"):
			var off: Vector2 = c.get_meta("offset")
			var at := Vector2(vs.x + off.x if off.x < 0 else off.x, vs.y + off.y if off.y < 0 else off.y)
			if c.get_meta("action") == "pause":
				at = Vector2(vs.x + off.x, off.y - 40)
			c.position = at - c.size * 0.5
			_rects.append([Rect2(c.position, c.size).grow(10), c.get_meta("action")])


func _player() -> Node:
	var s := get_tree().current_scene
	return s.get("player") if s else null


func _menu_open() -> bool:
	if get_tree().paused:
		return true
	var inv := get_tree().get_first_node_in_group("veil_inventory_panel") as Control
	return inv != null and inv.visible


func _input(e: InputEvent) -> void:
	if not active:
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			for r in _rects:
				if (r[0] as Rect2).has_point(t.position) and (not _menu_open() or r[1] == "inventory" or r[1] == "pause"):
					_button_ids[t.index] = r[1]
					_send(r[1], true)
					get_viewport().set_input_as_handled()
					return
			if _menu_open():
				return                                  # a normal tap on the menu / inventory
			if t.position.x < get_viewport().get_visible_rect().size.x * 0.5 and _stick_id < 0:
				_stick_id = t.index
				_stick_origin = t.position
				_stick_ui.position = t.position - _stick_ui.size * 0.5
				_knob.position = (_stick_ui.size - _knob.size) * 0.5
				_stick_ui.visible = true
			elif _look_id < 0:
				_look_id = t.index
		else:
			if _button_ids.has(t.index):
				_send(_button_ids[t.index], false)
				_button_ids.erase(t.index)
			if t.index == _stick_id:
				_stick_id = -1
				_stick_ui.visible = false
				_set_stick(Vector2.ZERO)
			if t.index == _look_id:
				_look_id = -1
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _stick_id:
			var v := (d.position - _stick_origin).limit_length(STICK_R)
			_knob.position = (_stick_ui.size - _knob.size) * 0.5 + v
			_set_stick(v / STICK_R)
		elif d.index == _look_id and not _menu_open():
			var p = _player()
			if p and p.get("look_enabled"):
				p.rotation.y -= d.relative.x * LOOK_SENS
				var pitch: float = clampf(float(p.get("_pitch")) - d.relative.y * LOOK_SENS, deg_to_rad(-85), deg_to_rad(85))
				p.set("_pitch", pitch)
				(p.get("head") as Node3D).rotation.x = pitch


func _set_stick(v: Vector2) -> void:
	_axis("move_right", "move_left", v.x)
	_axis("move_back", "move_forward", v.y)


func _axis(pos: String, neg: String, x: float) -> void:
	if x > 0.15:
		Input.action_press(pos, x)
		Input.action_release(neg)
	elif x < -0.15:
		Input.action_press(neg, -x)
		Input.action_release(pos)
	else:
		Input.action_release(pos)
		Input.action_release(neg)


## Send an action as a real input event, so _input / _unhandled_input handlers (talk, inventory, pause) react too.
func _send(action: String, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
