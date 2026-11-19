extends CanvasLayer
class_name VeilScreenFX
## THE VEIL - the screen "film look": vignette, faint lens curve and colour fringing, moving film grain
## (game/ui/screen_fx.gdshader). Sits above the 3D view and below the HUD (layer 5; the HUD is 10), so text and
## icons stay sharp. Switch it off in Settings ("Film look"); it is also off in headless runs.
## Health drives a gentle "danger" tint: the vignette tightens and the edges flush red when the player is hurt.

const SHADER := preload("res://game/ui/screen_fx.gdshader")

var rect: ColorRect
var mat: ShaderMaterial
var danger := 0.0


func _ready() -> void:
	layer = 5
	add_to_group("veil_screen_fx")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	add_child(rect)
	_apply_setting()


## Called by the settings panel and on start-up.
func _apply_setting() -> void:
	var on: bool = bool(Game.settings.get("film_look", true)) and DisplayServer.get_name() != "headless"
	rect.visible = on


func _process(delta: float) -> void:
	if not rect.visible:
		return
	var want := 0.0
	var p = get_parent().get("player") if get_parent() else null
	if p and p.get("survival_active") and float(p.get("health")) > 0.0:
		want = clampf(1.0 - float(p.get("health")) / float(VeilPlayer.MAX_HEALTH) * 1.8, 0.0, 1.0)   # starts below ~55% health
	danger = lerpf(danger, want, clampf(delta * 3.0, 0.0, 1.0))
	mat.set_shader_parameter("danger", danger)
