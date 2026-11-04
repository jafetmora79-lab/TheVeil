extends PanelContainer
class_name SettingsPanel
## Mouse sensitivity, master volume, fullscreen (desktop; on the web it asks the browser), head bob.

signal closed


func _ready() -> void:
	add_theme_stylebox_override("panel", VeilUI.panel_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(VeilUI.label("SETTINGS", 26))
	v.add_child(_slider("Mouse sensitivity", "mouse_sensitivity", 0.05, 0.6, 0.01))
	v.add_child(_slider("Master volume", "master_volume", 0.0, 1.0, 0.05))
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Game.settings["fullscreen"]
	fs.toggled.connect(func(on): Game.set_fullscreen(on))
	v.add_child(fs)
	var hb := CheckButton.new()
	hb.text = "Head bob"
	hb.button_pressed = Game.settings.get("head_bob", true)
	hb.toggled.connect(func(on):
		Game.settings["head_bob"] = on
		Game.save_settings())
	v.add_child(hb)
	var back := VeilUI.button("Back")
	back.pressed.connect(func():
		Game.save_settings()
		closed.emit())
	v.add_child(back)


func _slider(title: String, key: String, lo: float, hi: float, step: float) -> Control:
	var box := VBoxContainer.new()
	var l := VeilUI.label("%s: %.2f" % [title, Game.settings[key]], 16)
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = Game.settings[key]
	s.custom_minimum_size = Vector2(320, 24)
	s.value_changed.connect(func(val):
		Game.settings[key] = val
		l.text = "%s: %.2f" % [title, val]
		Game.apply_settings())
	box.add_child(s)
	return box
