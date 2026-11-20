extends Node
class_name VeilNpcFaceTex
## THE VEIL - EXPERIMENT (not used by any scene): an NPC's expressions as a swapped FACE TEXTURE (see protagonist_face_tex.gd for the idea).
## The model CHR_<slug>_FaceTex.glb has a second material (surface 1) on the face skin with front-projection UVs; each expression is a 512 px face
## image in game/prototypes/npc_meshy/face/<slug>/ (made from the user's aligned ChatGPT expression sheet).
##   expression : "neutral" | "scared" | "angry" | "worried"      talking : mouth cycles small / wide / closed (not while scared)
##   blink()    : eyes closed for a moment; auto_blink blinks every few seconds while the expression is neutral
const NAMES := ["neutral", "blink", "talk_small", "talk_wide", "scared", "angry", "worried"]
const TALK := ["talk_small", "talk_wide", "talk_small", "neutral", "talk_wide", "neutral", "talk_small", "talk_wide"]
static var _tex := {}
var slug := ""
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
var _sm: ShaderMaterial
var _brow_sm: ShaderMaterial                    ## the movable eyebrows of a Mixamo model (VeilFaceBrows)
var _brow := Vector3.ZERO                       ## current lift_in, lift_out, shift_in (metres)
## per expression: inner lift, outer lift, shift toward the nose (metres, on a head about 0.2 m wide)
const BROWS := {"neutral": Vector3(0.0, 0.0, 0.0), "scared": Vector3(0.010, 0.004, 0.0), "angry": Vector3(-0.006, 0.002, 0.002), "worried": Vector3(0.008, -0.001, 0.001)}
var _blink_left := 0.0
var _next_blink := 2.5
var _talk_t := 0.0
var _talk_i := 0
var _rng := RandomNumberGenerator.new()


static func glb_path(s: String) -> String:
	return "res://game/prototypes/npc_meshy/CHR_%s_FaceTex.glb" % s


static func texture(s: String, n: String) -> Texture2D:
	var k := s + "/" + n
	if not _tex.has(k):
		_tex[k] = load("res://game/prototypes/npc_meshy/face/%s/face_%s.png" % [s, n])
	return _tex[k]


## The NPC with its face-texture expressions: returns the model with a child "FaceTex" (this controller).
static func instantiate(s: String) -> Node3D:
	var ps := load(glb_path(s)) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	VeilSarahMeshyProto.psx_look(n)
	var f := VeilNpcFaceTex.new()
	f.name = "FaceTex"
	f.slug = s
	n.add_child(f)
	f.setup(n)
	return n


func setup(model_root: Node) -> bool:
	_rng.randomize()
	for mi in model_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null and m.mesh.get_surface_count() >= 2:
			var src := m.get_active_material(1)
			if src is ShaderMaterial:                       # a Mixamo model (VeilFaceFit): the face image over the model's own face where the expression changes it
				_sm = (src as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_surface_override_material(1, _sm)
				var bm := model_root.find_child("Brows", true, false) as MeshInstance3D
				if bm != null:
					_brow_sm = (bm.mesh.surface_get_material(0) as ShaderMaterial).duplicate() as ShaderMaterial
					bm.set_surface_override_material(0, _brow_sm)
				_apply()
				return true
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
	if _brow_sm != null:
		var want: Vector3 = BROWS.get(expression, BROWS["neutral"])
		_brow = _brow.lerp(want, minf(delta * 9.0, 1.0))
		_brow_sm.set_shader_parameter("lift_in", _brow.x)
		_brow_sm.set_shader_parameter("lift_out", _brow.y)
		_brow_sm.set_shader_parameter("shift_in", _brow.z)


func _apply() -> void:
	if (_mat == null and _sm == null) or slug == "":
		return
	var s := expression if expression in ["scared", "angry", "worried"] else "neutral"
	if talking and expression != "scared":
		s = TALK[_talk_i]
	if _blink_left > 0.0 and expression == "neutral":
		s = "blink"
	state = s
	if _sm != null:
		_sm.set_shader_parameter("face_tex", texture(slug, s))
		_sm.set_shader_parameter("amount", 0.0 if s == "neutral" else 1.0)
	else:
		_mat.albedo_texture = texture(slug, s)
