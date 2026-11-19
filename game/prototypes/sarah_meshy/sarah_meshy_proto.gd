extends RefCounted
class_name VeilSarahMeshyProto
## THE VEIL - prototype of the Meshy Sarah (NOT used by any scene: the playable Sarah is untouched).
## Loads the GLB, gives every material the PSX look in code (nearest-neighbour texture filtering so the 512 px skin and the face decals
## stay chunky, no gloss, no mip blur) and adds the face-expression controller (sarah_face.gd) as a child named "Face".
## Body animations (Godot strips the "-loop" suffix and sets looping): "idle", "walk", "nervous_idle", "injured_idle" (loops),
## "head_turn", "scared_reaction" (one shots) and one-frame hand poses "hand_relaxed", "hand_open", "hand_fist", "hand_grip", "hand_point".
## The walk is built on planted-foot IK: it does not slide when the body moves at walk_speed() metres per second (scale the animation
## speed to move faster or slower, speed_scale = wanted_speed / walk_speed()).

const GLB := "res://game/prototypes/sarah_meshy/CHR_Sarah_Meshy_Proto.glb"
const INFO := "res://game/prototypes/sarah_meshy/sarah_meshy_proto.json"


static func instantiate(with_face := true) -> Node3D:
	var ps := load(GLB) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	psx_look(n)
	if with_face:
		var f := VeilSarahFace.new()
		f.name = "Face"
		n.add_child(f)
		f.setup(n)
	return n


static func info() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(INFO)) if FileAccess.file_exists(INFO) else {}
	return d if d is Dictionary else {}


## Ground speed (m/s) at which the walk's planted feet do not slide.
static func walk_speed() -> float:
	return float(info().get("walk_ground_speed", 0.51))


static func psx_look(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.get_surface_override_material_count():
			var src: Material = m.get_active_material(i)
			if src is BaseMaterial3D:
				var mat := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.roughness = 1.0
				mat.metallic = 0.0
				mat.metallic_specular = 0.0
				mat.cull_mode = BaseMaterial3D.CULL_BACK
				m.set_surface_override_material(i, mat)


static func anim_player(root: Node) -> AnimationPlayer:
	var a := root.find_children("*", "AnimationPlayer", true, false)
	return a[0] as AnimationPlayer if not a.is_empty() else null


static func skeleton(root: Node) -> Skeleton3D:
	var s := root.find_children("*", "Skeleton3D", true, false)
	return s[0] as Skeleton3D if not s.is_empty() else null


static func face(root: Node) -> VeilSarahFace:
	return root.get_node_or_null("Face") as VeilSarahFace
