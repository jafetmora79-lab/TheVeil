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
var confirm_l: Label         ## CLICK / E - CONTINUE  ·  HOLD E - SKIP while a line is up and the player is not free
var speaker_l: Label         ## the speaker's name above every subtitle
var caption_l: Label         ## location caption (arrival shot)
const SPEAKER_NAMES := {"": "PROTAGONIST", "Distant voice": "UNKNOWN VOICE"}
var _hold := 0.0
var _hold_spent := false
var title: Label
var hint: Label
var speed_l: Label
var inv_panel: VeilInventoryPanel
var quick: VeilQuickSlots
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
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 1))     # white pixel text, black outline
	speaker_l = _centered_label("", 15, 0.5, 0.80)         # who is talking, above the line
	speaker_l.add_theme_color_override("font_color", Color(0.93, 0.83, 0.55, 1))
	confirm_l = _centered_label("", 13, 0.5, 0.925)
	confirm_l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	confirm_l.visible = false
	caption_l = _centered_label("", 17, 0.5, 0.74)         # small location caption (never over a sign)
	caption_l.modulate.a = 0.0
	title = _centered_label("", 34, 0.5, 0.42)
	title.modulate.a = 0.0
	hint = _centered_label("", 15, 0.5, 0.965)
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
	_build_survival()
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	Game.objective_changed.connect(set_objective)
	Game.inventory_changed.connect(_refresh_inventory)
	Dialogue.line_started.connect(func(spk, t, _d):
		speaker_l.text = String(SPEAKER_NAMES.get(spk, String(spk).to_upper()))
		show_subtitle(t))
	Dialogue.line_finished.connect(func():
		speaker_l.text = ""
		show_subtitle(""))


# ------------------------------------------------------------------ survival (health / stamina)
var surv: Control
var hp_fill: ColorRect
var st_fill: ColorRect
var hurt_flash: ColorRect
const BAR_W := 168.0


## Small, restrained bars bottom-left (pixel-sized, no arcade frames); hidden during the ordinary opening.
func _build_survival() -> void:
	surv = Control.new()
	surv.anchor_top = 1.0
	surv.anchor_bottom = 1.0
	surv.position = Vector2(34, -92)
	surv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surv.visible = false
	surv.modulate.a = 0.0
	root.add_child(surv)
	var rows := [["HEALTH", Color(0.78, 0.16, 0.12)], ["STAMINA", Color(0.86, 0.86, 0.8)]]
	for i in 2:
		var l := VeilUI.label(rows[i][0], 15)
		l.position = Vector2(0, i * 34)
		surv.add_child(l)
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.75)
		bg.position = Vector2(150, i * 34 + 10)
		bg.size = Vector2(BAR_W + 4, 12)
		surv.add_child(bg)
		var fill := ColorRect.new()
		fill.color = rows[i][1]
		fill.position = Vector2(152, i * 34 + 12)
		fill.size = Vector2(BAR_W, 8)
		surv.add_child(fill)
		if i == 0:
			hp_fill = fill
		else:
			st_fill = fill
	hurt_flash = ColorRect.new()
	hurt_flash.color = Color(0.55, 0.0, 0.0, 0.0)
	hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_flash)


func set_survival_visible(on: bool) -> void:
	surv.visible = true
	create_tween().tween_property(surv, "modulate:a", 1.0 if on else 0.0, 0.8)
	if not on:
		get_tree().create_timer(0.8).timeout.connect(func(): surv.visible = false)


func set_health(v: float, m: float) -> void:
	hp_fill.size.x = roundf(BAR_W * clampf(v / m, 0.0, 1.0) / 4.0) * 4.0       # 4 px steps: pixel-style bar


func set_stamina(v: float, m: float) -> void:
	st_fill.size.x = roundf(BAR_W * clampf(v / m, 0.0, 1.0) / 4.0) * 4.0
	st_fill.color = Color(0.86, 0.86, 0.8) if v / m > 0.25 else Color(0.85, 0.55, 0.2)


func damage_flash(strength := 1.0) -> void:
	hurt_flash.color.a = 0.42 * strength
	create_tween().tween_property(hurt_flash, "color:a", 0.0, 0.5)


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


## The continue / skip prompt is up while a line is on screen and the player is not walking around freely
## (conversations, cinematics); then a click / E / tap advances exactly one line.
func _dialogue_prompt_on() -> bool:
	if not Dialogue.is_active() or is_paused() or inv_panel.visible:
		return false
	var w := get_parent()
	var p: Node = w.get("player") if w else null
	return Dialogue.confirm_mode or p == null or p.get("controls_enabled") != true


func _unhandled_input(e: InputEvent) -> void:
	if _dialogue_prompt_on() and ((e.is_action_pressed("interact") and not e.is_echo()) or e.is_action_pressed("ui_accept")
			or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
			or (e is InputEventScreenTouch and e.pressed)):
		Dialogue.advance_any()
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("pause") and allow_pause and not end_panel.visible:
		set_paused(not is_paused())
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("inventory") and not is_paused():
		toggle_inventory()
	elif e is InputEventMouseButton and e.pressed and not is_paused() and not end_panel.visible and not inv_panel.visible \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_d: float) -> void:
	_update_marker()
	# continue / skip prompt + hold-to-skip (hold E, the mouse button or a touch for 0.8 s; once per hold)
	var on := _dialogue_prompt_on()
	confirm_l.visible = on
	if on:
		var touch := DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")
		confirm_l.text = "TAP - CONTINUE      HOLD - SKIP" if touch else "CLICK / E - CONTINUE      HOLD E - SKIP"
		var held := Input.is_action_pressed("interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		_hold = _hold + _d if held else 0.0
		if not held:
			_hold_spent = false
		elif _hold > 0.8 and not _hold_spent:
			_hold_spent = true
			Dialogue.skip()
	else:
		_hold = 0.0
	click_hint.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not is_paused() and not end_panel.visible \
		and fade.color.a < 0.5 and not inv_panel.visible


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


## Small location caption near the bottom (the arrival shot uses it: the store's own sign is the focus).
func location_caption(text: String, hold := 2.2) -> void:
	caption_l.text = text
	var tw := create_tween()
	tw.tween_property(caption_l, "modulate:a", 1.0, 0.7)
	tw.tween_interval(hold)
	tw.tween_property(caption_l, "modulate:a", 0.0, 1.0)
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
	# the survival-horror inventory screen (game/ui/inventory_panel.gd); inv_panel / toggle_inventory() keep
	# their old meaning for callers (Chapter 5 opens it to check the supplies)
	inv_panel = VeilInventoryPanel.new()
	inv_panel.name = "Inventory"
	root.add_child(inv_panel)
	inv_panel.closed.connect(func(): _inventory_input(false))
	quick = VeilQuickSlots.new()
	quick.name = "QuickSlots"
	root.add_child(quick)


func _refresh_inventory() -> void:
	if inv_panel:
		inv_panel.refresh()


## While the inventory is open the world gets no input (no interacting or walking behind the screen).
var _inv_held := false


func _inventory_input(open: bool) -> void:
	var w := get_parent()
	var p: Node = w.get("player") if w else null
	if open:
		_inv_held = p != null and p.get("controls_enabled") == true
		if _inv_held:
			p.set("controls_enabled", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if _inv_held and p:
			p.set("controls_enabled", true)
		_inv_held = false
		if not is_paused():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ destination marker (one, reusable)
## set_marker(target, label): target is a Node3D (followed) or a Vector3; null hides it. A small pale diamond with
## the distance, clamped to the screen edge (pointing the way) when the target is off-screen or behind you.
var _mk: Control
var _mk_label: Label
var _mk_target: Variant = null
var _mk_name := ""
var marker_visible := false             ## tests


func set_marker(target: Variant, label := "") -> void:
	_mk_target = target
	_mk_name = label
	if _mk == null:
		_mk = Control.new()
		_mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d := ColorRect.new()
		d.color = Color(0.86, 0.9, 0.86, 0.85)
		d.size = Vector2(9, 9)
		d.pivot_offset = Vector2(4.5, 4.5)
		d.position = Vector2(-4.5, -4.5)
		d.rotation = PI / 4
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mk.add_child(d)
		_mk_label = VeilUI.label("", 13, VeilUI.MUTED)
		_mk_label.position = Vector2(-60, 8)
		_mk_label.size = Vector2(120, 20)
		_mk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mk.add_child(_mk_label)
		root.add_child(_mk)
		_mk.visible = false


func _update_marker() -> void:
	if _mk == null:
		return
	var pos: Variant = null
	if _mk_target is Node3D and is_instance_valid(_mk_target):
		pos = (_mk_target as Node3D).global_position
	elif _mk_target is Vector3:
		pos = _mk_target
	var cam := get_viewport().get_camera_3d()
	if pos == null or cam == null or inv_panel.visible or is_paused() or Dialogue.is_active():
		_mk.visible = false
		marker_visible = false
		return
	var p: Vector3 = pos
	var dist := cam.global_position.distance_to(p)
	if dist < 1.6:
		_mk.visible = false                       # you are there: the interaction prompt takes over
		marker_visible = false
		return
	var vs := get_viewport().get_visible_rect().size
	var sp := cam.unproject_position(p)
	if cam.is_position_behind(p):
		sp = vs - sp
		sp.y = vs.y - 40.0
	var m := 36.0
	sp = Vector2(clampf(sp.x, m, vs.x - m), clampf(sp.y, m, vs.y - m - 30.0))
	_mk.position = sp
	_mk_label.text = ("%s  %d m" % [_mk_name, roundi(dist)]) if _mk_name != "" else "%d m" % roundi(dist)
	_mk.visible = true
	marker_visible = true


func toggle_inventory() -> void:
	if inv_panel.visible:
		inv_panel.close()
	else:
		inv_panel.open()
		_inventory_input(true)


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
