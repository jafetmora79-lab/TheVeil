extends Control
## THE VEIL - main menu: New Game, Continue (only with a valid save), Settings, Quit.

var menu: VBoxContainer
var settings: SettingsPanel
var loading: Label


func _ready() -> void:
	Sfx.play_music(Sfx.MUSIC_MENU, true, -8.0, 1.5)          # main menu theme (loops)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.039, 0.043, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var glow := ColorRect.new()          # faint warm horizon band: Friday evening, not mist
	glow.color = Color(0.42, 0.27, 0.18, 0.10)
	glow.anchor_right = 1.0
	glow.anchor_top = 0.62
	glow.anchor_bottom = 0.78
	add_child(glow)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	Game.new_game()
	_start()


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
