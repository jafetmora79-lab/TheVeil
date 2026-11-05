extends Control
## THE VEIL - main menu: New Game, Continue (only with a valid save), Settings, Quit.

var menu: VBoxContainer
var settings: SettingsPanel
var loading: Label
var name_dialog: ConfirmationDialog
var name_input: LineEdit


func _ready() -> void:
	Sfx.play_music(Sfx.MUSIC_MENU, true, -8.0, 1.5)          # main menu theme (loops)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.039, 0.043, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Actual Compatibility-renderer capture of the existing market, not concept art.
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://game/ui/backgrounds/greyhaven_market.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.anchor_left = 0.5
	add_child(c)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(menu)
	var t := VeilUI.label("T H E   V E I L", 58)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(t)
	var s := VeilUI.label("Greyhaven  ·  Friday", 18, VeilUI.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(s)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	menu.add_child(sp)
	var b_new := VeilUI.button("New Game")
	b_new.pressed.connect(_new_game)
	var b_cont := VeilUI.button("Continue")
	b_cont.disabled = not Game.has_save()
	if Game.has_save():
		b_cont.text = "Continue  -  " + Game.saved_chapter_name()
	b_cont.pressed.connect(_continue)
	var b_set := VeilUI.button("Settings")
	b_set.pressed.connect(func():
		menu.visible = false
		settings.visible = true)
	var b_quit := VeilUI.button("Quit")
	b_quit.pressed.connect(func(): get_tree().quit())
	b_quit.visible = OS.get_name() != "Web"
	for b in [b_new, b_cont, b_set, b_quit]:
		menu.add_child(b)
	b_new.grab_focus()
	settings = SettingsPanel.new()
	settings.visible = false
	settings.closed.connect(func():
		settings.visible = false
		menu.visible = true)
	c.add_child(settings)
	loading = VeilUI.label("Loading Greyhaven...", 20, VeilUI.MUTED)
	loading.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	loading.position.y -= 60
	loading.visible = false
	add_child(loading)
	var v := VeilUI.label("Phase 1 build · first playable opening", 13, Color(0.35, 0.38, 0.4))
	v.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	v.position += Vector2(16, -30)
	add_child(v)


func _new_game() -> void:
	if not is_instance_valid(name_dialog):
		name_dialog = ConfirmationDialog.new()
		name_dialog.title = "New Game"
		var fields := VBoxContainer.new()
		fields.add_theme_constant_override("separation", 12)
		name_dialog.add_child(fields)
		fields.add_child(VeilUI.label("What is your name?", 18))
		name_dialog.ok_button_text = "Begin"
		name_input = LineEdit.new()
		name_input.max_length = 24
		name_input.placeholder_text = "Your name (optional)"
		name_input.custom_minimum_size = Vector2(360, 40)
		fields.add_child(name_input)
		name_dialog.register_text_enter(name_input)
		name_dialog.confirmed.connect(func():
			Game.new_game(name_input.text)
			_start())
		add_child(name_dialog)
	name_input.text = ""
	name_dialog.popup_centered(Vector2i(420, 160))
	name_input.grab_focus()


func _continue() -> void:
	if Game.load_game():
		Game.load_requested = true
		_start()


func _start() -> void:
	menu.visible = false
	loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://game/scenes/World.tscn")
