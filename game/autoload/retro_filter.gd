extends CanvasLayer
## THE VEIL - the retro PS1 look over the 3D view (Settings: Retro filter Off / Light / Classic).
## One full-screen pass on canvas layer 5: under the HUD (10), menus, subtitles and struggle prompts, so text stays
## sharp; over the world, cutscene cameras and the car's driver camera alike. The shader is
## game/render/retro_filter.gdshader.

const SHADER := preload("res://game/render/retro_filter.gdshader")
const MODES := [["Off", 0.0, 256.0, 0.0], ["Light", 360.0, 32.0, 0.6], ["Classic", 240.0, 32.0, 1.0]]   # name, lines, levels, dither

var _rect: ColorRect


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "RetroFilter"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	_rect.material = m
	add_child(_rect)
	Game.settings_changed.connect(apply)
	apply()


func apply() -> void:
	var i := clampi(int(Game.settings.get("retro_filter", 1)), 0, MODES.size() - 1)
	var md: Array = MODES[i]
	_rect.visible = i > 0
	var m := _rect.material as ShaderMaterial
	m.set_shader_parameter("lines", float(md[1]))
	m.set_shader_parameter("levels", float(md[2]))
	m.set_shader_parameter("dither", float(md[3]))
