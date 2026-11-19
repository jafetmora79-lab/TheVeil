extends Node
class_name VeilProtagonistFaceTex
## THE VEIL - EXPERIMENT (not used by any scene): the protagonist's expressions as a swapped FACE TEXTURE.
## The model's face skin is a second material (surface 1 of the body mesh) whose UVs are a plain front projection, so each expression is a
## 512 px face image (the base face with the feature edited). Swapping that texture changes the expression: same triangles, same shading.
##   expression : "neutral" | "scared"        talking : mouth cycles small / wide / closed        blink() / auto_blink
const DIR := "res://creatures/humans/protagonist/face_geo/tex/"
const NAMES := ["neutral", "blink", "talk_small", "talk_wide", "scared"]
static var _tex := {}
var expression := "neutral":
	set(v):
		expression = v
		_apply()
var talking := false:
	set(v):
		talking = v
		_apply()
var auto_blink := true
var state := "neutral"                          ## the texture currently shown (read by tests)
var _mat: BaseMaterial3D
var _blink_left := 0.0
var _next_blink := 2.5
var _talk_t := 0.0
var _talk_i := 0
var _rng := RandomNumberGenerator.new()
const TALK := ["talk_small", "talk_wide", "talk_small", "neutral", "talk_wide", "neutral", "talk_small", "talk_wide"]


static func texture(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR + "face_%s.png" % n)
	return _tex[n]


func setup(model_root: Node) -> bool:
	_rng.randomize()
	for mi in model_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null and m.mesh.get_surface_count() >= 2:
			var src := m.get_active_material(1)
			if src is BaseMaterial3D:
				_mat = (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				_mat.roughness = 1.0
				_mat.metallic = 0.0
				_mat.metallic_specular = 0.0
				m.set_surface_override_material(1, _mat)
				_apply()
				return true
	return false


func blink(duration := 0.13) -> void:
	_blink_left = duration
	_apply()


func _process(delta: float) -> void:
	var dirty := false
	if _blink_left > 0.0:
		_blink_left -= delta
		dirty = true
	elif auto_blink and expression == "neutral":
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink_left = 0.13
			_next_blink = _rng.randf_range(2.2, 5.0)
			dirty = true
	if talking:
		_talk_t -= delta
		if _talk_t <= 0.0:
			_talk_t = _rng.randf_range(0.08, 0.15)
			_talk_i = (_talk_i + 1) % TALK.size()
			dirty = true
	if dirty:
		_apply()


func _apply() -> void:
	if _mat == null:
		return
	var s := "neutral"
	if expression == "scared":
		s = "scared"
	if talking and expression != "scared":
		s = TALK[_talk_i]
	if _blink_left > 0.0 and expression == "neutral":
		s = "blink"
	state = s
	_mat.albedo_texture = texture(s)
