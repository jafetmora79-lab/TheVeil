extends CanvasLayer
class_name VeilHUD
## In-game HUD, built in code: crosshair dot, interaction prompt, subtle objective text, subtitles, fade,
## title card, inventory (Tab), pause menu (Esc) with settings, save and quit, and the end-of-opening card.

signal pause_toggled(paused: bool)
signal save_requested
signal quit_to_menu

var root: Control
var fade: ColorRect
var prompt: Label
var dot: ColorRect
var goal_l: Label
var step_l: Label
var obj_box: VBoxContainer
var sub: Label
var title: Label
var hint: Label
var speed_l: Label
var inv_panel: PanelContainer
var inv_list: VBoxContainer
var pause_panel: Control
var settings: SettingsPanel
var end_panel: PanelContainer
var click_hint: Label
var _obj_tween: Tween


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	dot = ColorRect.new()
	dot.color = Color(1, 1, 1, 0.55)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = -dot.size / 2
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)
	prompt = _centered_label("", 20, 0.5, 0.60)
	obj_box = VBoxContainer.new()
	obj_box.position = Vector2(34, 28)
	obj_box.modulate.a = 0.0
	root.add_child(obj_box)
	goal_l = VeilUI.label("", 15, VeilUI.MUTED)
	step_l = VeilUI.label("", 19)
	obj_box.add_child(goal_l)
	obj_box.add_child(step_l)
	sub = _centered_label("", 21, 0.5, 0.86)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title = _centered_label("", 34, 0.5, 0.42)
	title.modulate.a = 0.0
	hint = _centered_label("", 15, 0.5, 0.94)
	hint.add_theme_color_override("font_color", VeilUI.MUTED)
	speed_l = VeilUI.label("", 16, VeilUI.MUTED)
	speed_l.anchor_left = 1.0
	speed_l.anchor_right = 1.0
	speed_l.anchor_top = 1.0
	speed_l.anchor_bottom = 1.0
	speed_l.position = Vector2(-150, -48)
	root.add_child(speed_l)
	click_hint = _centered_label("Click to look around", 18, 0.5, 0.5)
	click_hint.visible = false
	_build_inventory()
	_build_pause()
	_build_end()
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	Game.objective_changed.connect(set_objective)
	Game.inventory_changed.connect(_refresh_inventory)
	Dialogue.line_started.connect(func(_s, t, _d): show_subtitle(t))
	Dialogue.line_finished.connect(func(): show_subtitle(""))


func _centered_label(text: String, size: int, ax: float, ay: float) -> Label:
	var l := VeilUI.label(text, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.15
	l.anchor_right = 0.85
	l.anchor_top = ay
	l.anchor_bottom = ay
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


var allow_pause := true


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") and allow_pause and not end_panel.visible:
		set_paused(not is_paused())
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("inventory") and not is_paused():
		toggle_inventory()
	elif e is InputEventMouseButton and e.pressed and not is_paused() and not end_panel.visible \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_d: float) -> void:
	click_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not is_paused() and not end_panel.visible \
		and fade.color.a < 0.5


# ------------------------------------------------------------------ basics
func set_prompt(t: String) -> void:
	prompt.text = t
	dot.color.a = 0.9 if t != "" else 0.45


func show_subtitle(t: String) -> void:
	sub.text = t


func set_hint(t: String) -> void:
	hint.text = t


func set_speed(kmh: float) -> void:
	speed_l.text = "%d km/h" % roundi(kmh) if kmh >= 0.0 else ""


func set_objective(goal: String, step: String) -> void:
	if _obj_tween:
		_obj_tween.kill()
	_obj_tween = create_tween()
	_obj_tween.tween_property(obj_box, "modulate:a", 0.0, 0.25)
	_obj_tween.tween_callback(func():
		goal_l.text = goal.to_upper() if goal != "" else ""
		step_l.text = step)
	_obj_tween.tween_property(obj_box, "modulate:a", 1.0, 0.5)
	_obj_tween.tween_interval(6.0)
	_obj_tween.tween_property(obj_box, "modulate:a", 0.55, 1.5)


func fade_to(alpha: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, t)
	await tw.finished


func title_card(text: String, hold := 2.6) -> void:
	title.text = text
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.9)
	tw.tween_interval(hold)
	tw.tween_property(title, "modulate:a", 0.0, 1.2)
	await tw.finished


# ------------------------------------------------------------------ inventory
func _build_inventory() -> void:
	inv_panel = PanelContainer.new()
	inv_panel.add_theme_stylebox_override("panel", VeilUI.panel_style())
	inv_panel.anchor_left = 0.62
	inv_panel.anchor_right = 0.97
	inv_panel.anchor_top = 0.12
	inv_panel.anchor_bottom = 0.12
	inv_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	inv_panel.add_child(v)
	v.add_child(VeilUI.label("INVENTORY", 22))
	inv_list = VBoxContainer.new()
	inv_list.add_theme_constant_override("separation", 8)
	v.add_child(inv_list)
	root.add_child(inv_panel)
	_refresh_inventory()


func _refresh_inventory() -> void:
	for c in inv_list.get_children():
		c.queue_free()
	if Game.inventory.is_empty():
		inv_list.add_child(VeilUI.label("Pockets are empty.", 16, VeilUI.MUTED))
	for id in Game.inventory:
		var info := Game.item_info(id)
		inv_list.add_child(VeilUI.label("%s   [%s]" % [info.get("name", id), str(info.get("category", "")).to_upper()], 18))
		var d := VeilUI.label(info.get("description", ""), 14, VeilUI.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(360, 0)
		inv_list.add_child(d)


func toggle_inventory() -> void:
	inv_panel.visible = not inv_panel.visible


# ------------------------------------------------------------------ pause
func _build_pause() -> void:
	pause_panel = CenterContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(shade)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", VeilUI.panel_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(VeilUI.label("PAUSED", 26))
	var b1 := VeilUI.button("Resume")
	b1.pressed.connect(func(): set_paused(false))
	var b2 := VeilUI.button("Save Game")
	b2.pressed.connect(func():
		save_requested.emit()
		b2.text = "Saved"
		get_tree().create_timer(1.2, true).timeout.connect(func(): b2.text = "Save Game"))
	var b3 := VeilUI.button("Settings")
	b3.pressed.connect(func():
		p.visible = false
		settings.visible = true)
	var b4 := VeilUI.button("Main Menu")
	b4.pressed.connect(func(): quit_to_menu.emit())
	var b5 := VeilUI.button("Quit Game")
	b5.pressed.connect(func(): get_tree().quit())
	b5.visible = OS.get_name() != "Web"
	for b in [b1, b2, b3, b4, b5]:
		v.add_child(b)
	pause_panel.add_child(p)
	settings = SettingsPanel.new()
	settings.visible = false
	settings.closed.connect(func():
		settings.visible = false
		p.visible = true)
	pause_panel.add_child(settings)
	root.add_child(pause_panel)


func set_paused(on: bool) -> void:
	pause_panel.visible = on
	settings.visible = false
	for c in pause_panel.get_children():
		if c is PanelContainer and not (c is SettingsPanel):
			c.visible = true
	get_tree().paused = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	pause_toggled.emit(on)


func is_paused() -> bool:
	return pause_panel.visible


# ------------------------------------------------------------------ end of the opening
func _build_end() -> void:
	end_panel = PanelContainer.new()
	end_panel.add_theme_stylebox_override("panel", VeilUI.panel_style())
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	end_panel.add_child(v)
	v.add_child(VeilUI.label("FRIDAY ERRANDS", 26))
	v.add_child(VeilUI.label("Groceries in the back seat, a new game for tonight.", 18, VeilUI.MUTED))
	v.add_child(VeilUI.label("The drive home continues in the next development phase.", 16, VeilUI.MUTED))
	var b := VeilUI.button("Back to Main Menu")
	b.pressed.connect(func(): quit_to_menu.emit())
	v.add_child(b)
	var c := VeilUI.button("Keep Exploring")
	c.pressed.connect(func():
		end_panel.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	v.add_child(c)
	root.add_child(end_panel)


func set_end_text(title: String, line_a: String, line_b: String) -> void:
	var v: VBoxContainer = end_panel.get_child(0)
	(v.get_child(0) as Label).text = title
	(v.get_child(1) as Label).text = line_a
	(v.get_child(2) as Label).text = line_b


func show_end(drive_seconds: float) -> void:
	var v: VBoxContainer = end_panel.get_child(0)
	var l := VeilUI.label("Drive time: %d s" % roundi(drive_seconds), 15, VeilUI.MUTED)
	v.add_child(l)
	v.move_child(l, 3)
	end_panel.visible = true
	end_panel.position = -end_panel.size / 2
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
