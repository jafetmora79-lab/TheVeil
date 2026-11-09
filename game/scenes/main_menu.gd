extends Control
## THE VEIL - main menu: New Game, Continue (only with a valid save), Chapters (once the game has been finished),
## Settings, Quit.

var menu: VBoxContainer
const MENU_W := 520.0
var settings: SettingsPanel
var loading: Label
var name_dialog: ConfirmationDialog
var name_input: LineEdit
var chapters: VBoxContainer
var chapter_confirm: ConfirmationDialog
var _pending_chapter := 0
const CHAPTER_SELECT := preload("res://game/chapters/chapter_select.gd")


func _ready() -> void:
	Game.no_save = false                                      # (never left off by an interrupted trailer run)
	if Game.has_meta("trailer_run") and get_tree().root.get_node_or_null("TrailerDirector") == null:
		Game.remove_meta("trailer_run")
	Sfx.play_music(Sfx.MUSIC_MENU, true, -8.0, 1.5)          # main menu theme (loops)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.039, 0.043, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Actual Compatibility-renderer capture of the existing game shop, not concept art.
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://game/ui/backgrounds/game_haven_mist.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var mist := ColorRect.new()
	mist.name = "MenuMist"
	mist.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mist_material := ShaderMaterial.new()
	mist_material.shader = preload("res://game/ui/backgrounds/menu_mist.gdshader")
	mist_material.set_shader_parameter("noise_tex", preload("res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Textures/T_Veil_MistNoise.png"))
	mist.material = mist_material
	add_child(mist)
	_alive(backdrop, mist_material)
	# a soft dark band on the left behind the text (the storefront stays clear on the right)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ss := Shader.new()
	ss.code = "shader_type canvas_item;\nvoid fragment(){ COLOR = vec4(0.0, 0.0, 0.0, 0.7 * (1.0 - smoothstep(0.05, 0.55, UV.x))); }"
	var sm := ShaderMaterial.new()
	sm.shader = ss
	shade.material = sm
	add_child(shade)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.anchor_left = 0.5
	add_child(c)
	var left := Control.new()                          # title and options: upper left, never over the shop sign
	left.anchor_left = 0.07
	left.anchor_top = 0.14
	left.anchor_right = 0.5
	left.anchor_bottom = 0.95
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	menu = VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_theme_constant_override("separation", 8)
	menu.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_child(menu)
	var t := preload("res://game/ui/pixel_title.gd").new()      # hand-drawn pixel letters (no stray font pixel)
	t.name = "Title"
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu.add_child(t)
	var s := VeilUI.label("Greyhaven  ·  Friday", 18, VeilUI.MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu.add_child(s)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 40)
	menu.add_child(sp)
	var b_new := VeilUI.button("New Game")
	b_new.pressed.connect(_new_game)
	var b_cont := VeilUI.button("Continue")
	b_cont.disabled = not Game.has_save()
	if Game.has_save():
		b_cont.text = "Continue  -  " + Game.saved_chapter_name()
		_fit_button.call_deferred(b_cont)
	b_cont.pressed.connect(_continue)
	var b_set := VeilUI.button("Settings")
	b_set.pressed.connect(func():
		menu.visible = false
		settings.visible = true)
	var b_quit := VeilUI.button("Quit")
	b_quit.pressed.connect(func(): get_tree().quit())
	b_quit.visible = OS.get_name() != "Web"
	var buttons: Array = [b_new, b_cont, b_set, b_quit]
	if CHAPTER_SELECT.unlocked():
		var b_ch := VeilUI.button("Chapters")
		b_ch.name = "ChaptersButton"
		b_ch.pressed.connect(_show_chapters)
		buttons.insert(2, b_ch)
	var trailer_script = load("res://game/trailer/trailer_mode.gd")
	if trailer_script.wanted():
		# trailer mode (TheVeil_TrailerMode.bat): the trailer straight from here - start recording, then click it (or T)
		trailer_script.ensure(get_tree())
		var b_tr := VeilUI.button("PLAY TRAILER")
		b_tr.pressed.connect(func(): load("res://game/trailer/trailer_director.gd").start(get_tree()))
		buttons.push_front(b_tr)
	for b in buttons:
		b.custom_minimum_size = Vector2(MENU_W, 34)     # one width for the column: long labels fit inside it
		b.clip_text = true
		_flat(b)
		menu.add_child(b)
	(buttons[0] as Button).grab_focus()
	_build_chapters(left)
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


func _new_game() -> void:
	if not is_instance_valid(name_dialog):
		name_dialog = ConfirmationDialog.new()
		name_dialog.title = "New Game"
		var fields := VBoxContainer.new()
		fields.add_theme_constant_override("separation", 12)
		name_dialog.add_child(fields)
		fields.add_child(VeilUI.label("What is your name?", 15))
		name_dialog.ok_button_text = "Begin"
		name_input = LineEdit.new()
		name_input.max_length = 24
		name_input.placeholder_text = "Your name (optional)"
		name_input.custom_minimum_size = Vector2(280, 34)
		VeilUI.style_text(name_input, 14)
		name_input.add_theme_color_override("font_placeholder_color", VeilUI.MUTED * Color(1, 1, 1, 0.55))
		fields.add_child(name_input)
		_style_dialog(name_dialog)
		name_dialog.register_text_enter(name_input)
		name_dialog.confirmed.connect(func():
			Game.new_game(name_input.text)
			_start())
		add_child(name_dialog)
	name_input.text = ""
	name_dialog.popup_centered(Vector2i(330, 140))
	name_input.grab_focus()


# ------------------------------------------------------------------ chapter select
func _build_chapters(parent: Control) -> void:
	chapters = VBoxContainer.new()
	chapters.name = "ChapterList"
	chapters.set_anchors_preset(Control.PRESET_FULL_RECT)
	chapters.add_theme_constant_override("separation", 6)
	chapters.visible = false
	parent.add_child(chapters)
	var head := VeilUI.label("CHAPTERS", 22)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	chapters.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chapters.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	scroll.add_child(col)
	for n in range(1, CHAPTER_SELECT.COUNT + 1):
		var b := VeilUI.button(Game.chapter_name(n))
		b.name = "Chapter%d" % n
		b.custom_minimum_size = Vector2(MENU_W, 30)
		b.clip_text = true
		_flat(b)
		b.pressed.connect(_pick_chapter.bind(n))
		col.add_child(b)
	var back := VeilUI.button("Back")
	back.custom_minimum_size = Vector2(MENU_W, 32)
	_flat(back)
	back.pressed.connect(func():
		chapters.visible = false
		menu.visible = true)
	chapters.add_child(back)


func _show_chapters() -> void:
	menu.visible = false
	chapters.visible = true
	var first := chapters.find_child("Chapter1", true, false) as Button
	if first:
		first.grab_focus()


func _pick_chapter(n: int) -> void:
	_pending_chapter = n
	if not Game.has_save():
		_start_chapter()
		return
	if not is_instance_valid(chapter_confirm):
		chapter_confirm = ConfirmationDialog.new()
		chapter_confirm.title = "Start Chapter"
		chapter_confirm.ok_button_text = "Start"
		_style_dialog(chapter_confirm)
		chapter_confirm.confirmed.connect(_start_chapter)
		add_child(chapter_confirm)
	chapter_confirm.dialog_text = "Start %s?\nThis replaces your current save." % Game.chapter_name(n)
	chapter_confirm.popup_centered(Vector2i(420, 150))


func _start_chapter() -> void:
	if Game.has_save() and Game.load_game():
		pass                                               # (keeps the player's name for the new run)
	chapters.visible = false
	loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	CHAPTER_SELECT.start(get_tree(), _pending_chapter)


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


## The name prompt in the menu's own look: pixel font, dark panel with the accent edge, menu-style buttons.
func _style_dialog(d: ConfirmationDialog) -> void:
	var th := Theme.new()
	th.default_font = VeilUI.font()
	th.default_font_size = VeilUI.px_size(13)
	var panel := StyleBoxFlat.new()
	panel.bg_color = VeilUI.BG
	panel.border_color = VeilUI.ACCENT
	panel.set_border_width_all(1)
	panel.set_content_margin_all(14)
	th.set_stylebox("panel", "AcceptDialog", panel)
	th.set_stylebox("panel", "ConfirmationDialog", panel)
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color(0.11, 0.14, 0.17, 0.95)
	edit.border_color = VeilUI.ACCENT
	edit.set_border_width_all(1)
	edit.set_content_margin_all(6)
	th.set_stylebox("normal", "LineEdit", edit)
	th.set_stylebox("focus", "LineEdit", edit)
	d.theme = th
	d.add_theme_font_override("title_font", VeilUI.font())
	d.add_theme_font_size_override("title_font_size", VeilUI.px_size(13))
	for b in [d.get_ok_button(), d.get_cancel_button()]:
		var mb := VeilUI.button(b.text)
		b.custom_minimum_size = Vector2(110, 32)
		for k in ["normal", "hover", "pressed", "focus"]:
			if mb.has_theme_stylebox_override(k):
				b.add_theme_stylebox_override(k, mb.get_theme_stylebox(k))
		VeilUI.style_text(b, 14)
		b.add_theme_color_override("font_hover_color", VeilUI.ACCENT)
		mb.free()


## A long Continue label (the chapter name) steps down in size until it fits its button.
func _fit_button(b: Button) -> void:
	await get_tree().process_frame
	var f: Font = VeilUI.font()
	if f == null:
		return
	for size in [19, 17, 15, 13, 11]:
		var px := VeilUI.px_size(size)
		b.add_theme_font_size_override("font_size", px)
		if f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= MENU_W - 36.0:
			return


## The background breathes: a slow push-in and pan on the shot, a second faster mist layer, the street lights
## stuttering now and then, a fine drizzle, and darker edges. All 2D over the existing picture: cheap.
func _alive(backdrop: TextureRect, mist_mat: ShaderMaterial) -> void:
	backdrop.pivot_offset = get_viewport_rect().size * 0.5
	var tw := backdrop.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(backdrop, "scale", Vector2.ONE * 1.07, 28.0)
	tw.parallel().tween_property(backdrop, "position", Vector2(-24, -8), 28.0)
	tw.tween_property(backdrop, "scale", Vector2.ONE, 28.0)
	tw.parallel().tween_property(backdrop, "position", Vector2.ZERO, 28.0)
	var mist2 := ColorRect.new()
	mist2.set_anchors_preset(Control.PRESET_FULL_RECT)
	mist2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m2 := mist_mat.duplicate() as ShaderMaterial
	m2.set_shader_parameter("drift", Vector2(-0.03, 0.004))
	m2.set_shader_parameter("density", 0.38)
	mist2.material = m2
	add_child(mist2)
	var rain := CPUParticles2D.new()
	rain.amount = 160
	rain.lifetime = 1.1
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(get_viewport_rect().size.x * 0.6, 4)
	rain.position = Vector2(get_viewport_rect().size.x * 0.5, -10)
	rain.direction = Vector2(-0.15, 1)
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 700.0
	rain.initial_velocity_max = 900.0
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 1.0
	rain.color = Color(0.7, 0.75, 0.8, 0.22)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	rain.color_ramp = g
	var tex := GradientTexture2D.new()
	tex.width = 1
	tex.height = 10
	rain.texture = tex
	add_child(rain)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = "shader_type canvas_item;\nvoid fragment(){ vec2 d = UV - 0.5; COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.35, 0.85, length(d * vec2(1.2, 1.0))) * 0.75); }"
	var vm := ShaderMaterial.new()
	vm.shader = vs
	vig.material = vm
	add_child(vig)
	var flick := ColorRect.new()
	flick.set_anchors_preset(Control.PRESET_FULL_RECT)
	flick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flick.color = Color(0, 0, 0, 0)
	add_child(flick)
	_stutter(flick)


func _stutter(r: ColorRect) -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(4.0, 10.0)).timeout
		if not is_instance_valid(r):
			return
		for i in randi_range(1, 3):
			r.color.a = randf_range(0.18, 0.32)
			await get_tree().create_timer(randf_range(0.04, 0.09)).timeout
			r.color.a = 0.0
			await get_tree().create_timer(randf_range(0.05, 0.12)).timeout


## A menu option as plain text (no box): pale, and pale yellow with a small arrow when selected (mouse or keys).
func _flat(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for k in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(k, empty)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", VeilUI.px_size(20))
	b.add_theme_color_override("font_color", Color(0.84, 0.85, 0.83))
	b.add_theme_color_override("font_hover_color", Color(0.97, 0.93, 0.7))
	b.add_theme_color_override("font_focus_color", Color(0.97, 0.93, 0.7))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.97, 0.8))
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.44, 0.45))
	b.text = b.text.to_upper()
	var base := b.text
	b.set_meta("base", base)
	var on := func():
		if not b.disabled:
			b.text = "›  " + String(b.get_meta("base"))
	var off := func(): b.text = String(b.get_meta("base"))
	b.focus_entered.connect(on)
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_exited.connect(off)
