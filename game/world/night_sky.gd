class_name VeilNightSky
extends Node3D
## The sky of the ordinary night before the Veil: stars, a moon (where the night's moonlight comes from) and a few clouds.
## A dome that follows whichever camera is active. It shows only while the "night" preset is the atmosphere's look; the
## Veil's presets (approach, active) are dense mist that hides the sky, so it fades out when they take over.

const SHADER := "res://game/world/night_sky.gdshader"
const RADIUS := 300.0                    # inside the smallest far plane in the game (the player's 400 m / 600 m)

var world: Node
var _mi: MeshInstance3D
var _mat: ShaderMaterial
var _fade := 0.0


func setup(w: Node) -> void:
	world = w
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 48
	sm.rings = 24
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	_mat.render_priority = -90
	_mi = MeshInstance3D.new()
	_mi.name = "Dome"
	_mi.mesh = sm
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 16384.0
	add_child(_mi)
	_mat.set_shader_parameter("moon_dir", moon_direction())
	_mat.set_shader_parameter("fade", 0.0)
	_mi.visible = false


## The moon sits where the night's directional light comes from (its pitch / yaw in the "night" preset), so shadows agree with it.
func moon_direction() -> Vector3:
	var pitch := -38.0
	var yaw := 200.0
	var b := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))
	return b.z.normalized()                # light shines along -Z: the moon is the other way


func _is_night() -> bool:
	if world == null:
		return false
	var a = world._atmo()
	var cur = a.get("current") if a else null
	return cur != null and String(cur.get("preset_name")) == "NIGHT_NIGHT"


func _process(delta: float) -> void:
	var target := 1.0 if _is_night() else 0.0
	_fade = move_toward(_fade, target, delta * 0.5)
	_mi.visible = _fade > 0.001
	if not _mi.visible:
		return
	_mat.set_shader_parameter("fade", _fade)
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position
