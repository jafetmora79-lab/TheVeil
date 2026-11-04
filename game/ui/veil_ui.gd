extends RefCounted
class_name VeilUI
## Shared look for menus / HUD: dark blue-grey panels, warm off-white text, muted teal accent
## (the asset gallery's palette), no new artwork.

const BG := Color(0.063, 0.082, 0.102, 0.92)
const EDGE := Color(0.208, 0.259, 0.294, 1)
const TEXT := Color(0.91, 0.925, 0.933, 1)
const MUTED := Color(0.64, 0.69, 0.72, 1)
const ACCENT := Color(0.655, 0.831, 0.80, 1)


static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG
	s.border_color = EDGE
	s.set_border_width_all(1)
	s.set_content_margin_all(22)
	return s


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 42)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.43, 0.45))
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.11, 0.14, 0.17, 0.95)
	n.border_color = EDGE
	n.set_border_width_all(1)
	var h := n.duplicate()
	h.border_color = ACCENT
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", n)
	return b
