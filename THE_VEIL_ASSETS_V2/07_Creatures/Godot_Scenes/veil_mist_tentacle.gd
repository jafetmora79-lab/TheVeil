@tool
class_name VeilMistTentacle
extends Node3D
## THE VEIL - Pack 07 Mist Tentacle: an appendage rising out of the supernatural mist. There is no visible body.
## Presentation only: no damage, no AI, no targeting.
##
## Place the scene where the tentacle should rise. "MistRoot" marks the mist surface; below it the tentacle
## dithers away (crt_mist_fade.gdshader), so Emerge / Retract read as rising out of and sinking into the mist.
## Clips (Model/AnimationPlayer): Emerge, Search, Coil, Reach, Strike, Retract. All three variants share the same
## skeleton (Root, T_01..T_10) and clip names, so code written for one drives the others.

const FADE_SHADER := preload("res://THE_VEIL_ASSETS_V2/07_Creatures/Shared_Materials/crt_mist_fade.gdshader")

## 0 = hidden, 1 = fully visible (ordered dither, no transparency sorting).
@export_range(0.0, 1.0) var visibility := 1.0:
	set(v):
		visibility = v
		_push()
## Metres above the mist surface over which the tentacle fades in.
@export_range(0.0, 5.0) var fade_height := 0.6:
	set(v):
		fade_height = v
		_push()
## Clip played when the scene starts (empty = none). Not played in the editor.
@export var autoplay := "Search"
## Blend time used by play().
@export_range(0.0, 2.0) var blend_time := 0.3

var _mats: Array[ShaderMaterial] = []
var _anim: AnimationPlayer


func _ready() -> void:
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_build_materials()
	if autoplay != "" and not Engine.is_editor_hint():
		play(autoplay, 0.0)


func _process(_delta: float) -> void:
	_push_level()


## Play a clip with the default (or given) blend.
func play(clip: String, blend := -1.0) -> void:
	if _anim and _anim.has_animation(clip):
		_anim.play(clip, blend_time if blend < 0.0 else blend)


## Rise out of the mist, then keep searching.
func emerge() -> void:
	play("Emerge", 0.0)
	if _anim:
		_anim.queue("Search")


## Sink back into the mist (ends below the mist surface, fully dithered away).
func retract() -> void:
	play("Retract")


func get_animation_player() -> AnimationPlayer:
	return _anim


func _build_materials() -> void:
	_mats.clear()
	for mi in find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i) as StandardMaterial3D
			var sm := ShaderMaterial.new()
			sm.shader = FADE_SHADER
			if src:
				sm.set_shader_parameter("albedo_tex", src.albedo_texture)
				sm.set_shader_parameter("emission_tex", src.emission_texture)
				sm.set_shader_parameter("emission_energy", src.emission_energy_multiplier if src.emission_enabled else 0.0)
				sm.set_shader_parameter("roughness_v", src.roughness)
			(mi as MeshInstance3D).set_surface_override_material(i, sm)
			_mats.append(sm)
	_push()


func _push() -> void:
	for m in _mats:
		m.set_shader_parameter("visibility", visibility)
		m.set_shader_parameter("fade_height", fade_height)
	_push_level()


func _push_level() -> void:
	if not is_inside_tree():
		return
	var marker := get_node_or_null("MistRoot") as Node3D
	var y := marker.global_position.y if marker else global_position.y
	for m in _mats:
		m.set_shader_parameter("mist_level", y)
