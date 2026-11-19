extends RefCounted
class_name VeilUI
## Shared look for menus / HUD: dark blue-grey panels, warm off-white text, muted teal accent
## (the asset gallery's palette), no new artwork.

const BG := Color(0.063, 0.082, 0.102, 0.92)
const EDGE := Color(0.208, 0.259, 0.294, 1)
const TEXT := Color(1, 1, 1, 1)                     ## gameplay text: white with a black pixel outline
const MUTED := Color(0.86, 0.88, 0.9, 1)
const FONT_PATH := "res://game/ui/fonts/VeilPixel.ttf"
const OUTLINE := 6                                  ## outline in screen px (about 1.5 font pixels at 2x)
static var _font: FontFile


## THE VEIL pixel font (game/tools/make_pixel_font.py): square-pixel glyphs on a 13 px em, drawn without
## anti-aliasing / hinting / subpixel offsets so every glyph pixel stays a crisp square.
static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH) as FontFile
		if _font:
			_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			_font.hinting = TextServer.HINTING_NONE
			_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			_font.generate_mipmaps = false
	return _font


## Snap a requested size to a whole multiple of the 13 px pixel em (26 = 2x for body text, 39 = 3x titles).
static func px_size(size: int) -> int:
	return 26 if size < 30 else (39 if size < 46 else 52)


static func style_text(c: Control, size: int, color := TEXT) -> void:
	var f := font()
	if f:
		c.add_theme_font_override("font", f)
	c.add_theme_font_size_override("font_size", px_size(size))
	c.add_theme_color_override("font_color", color)
	c.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	c.add_theme_constant_override("outline_size", OUTLINE)
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
	style_text(l, size, color)
	l.add_theme_constant_override("line_spacing", 4)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 42)
	style_text(b, 19)
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
