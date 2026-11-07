extends CanvasLayer
class_name VeilChoicePanel
## THE VEIL - small modal choice UI (dialogue choices, "rest until morning?" confirmations).
## ask(title, options) shows buttons, frees the mouse, pauses player control, and returns the picked index
## (await), pausing the game while it is open. Keys 1..9 also pick. pick(i) lets tests answer without input.

signal picked(index: int)

var _panel: PanelContainer
var _box: VBoxContainer
var _title: Label
var _open := false
var _player: Node = null
var _paused_by_me := false                    ## the panel paused the game (monsters, NPCs, timers) and unpauses it


func _ready() -> void:
	add_to_group("veil_choice_panel")             # the world's talk camera holds while any choice is open
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", VeilUI.panel_style())
	_panel.visible = false
	c.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)
	_title = VeilUI.label("", 18, VeilUI.MUTED)
	_box.add_child(_title)


func is_open() -> bool:
	return _open


func ask(title: String, options: Array, player: Node = null) -> int:
	for c in _box.get_children():
		if c != _title:
			c.queue_free()
	_title.text = title
	_title.visible = title != ""
	for i in options.size():
		var b := VeilUI.button("%d.  %s" % [i + 1, options[i]])
		b.custom_minimum_size = Vector2(460, 44)
		b.pressed.connect(pick.bind(i))
		_box.add_child(b)
	_player = player
	if _player and "controls_enabled" in _player:
		_player.controls_enabled = false
		_player.look_enabled = false
	_open = true
	_panel.visible = true
	# a decision is modal: the world holds still while it is open (only unpaused again by whoever paused it)
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var i: int = await picked
	return i


func pick(i: int) -> void:
	if not _open:
		return
	_open = false
	_panel.visible = false
	if _paused_by_me:
		_paused_by_me = false
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _player and is_instance_valid(_player) and "controls_enabled" in _player:
		_player.controls_enabled = true
		_player.look_enabled = true
	picked.emit(i)


func _unhandled_input(e: InputEvent) -> void:
	if _open and e is InputEventKey and e.pressed and not e.echo:
		var n: int = e.physical_keycode - KEY_1
		if n >= 0 and n < _box.get_child_count() - 1:
			get_viewport().set_input_as_handled()
			pick(n)
