extends RefCounted
class_name VeilSarahMeshyProto
## THE VEIL - prototype of the Meshy Sarah (NOT used by any scene: the playable Sarah is untouched).
## Loads the GLB and gives its material the PSX look in code: nearest-neighbour texture filtering (the 512 px texture
## stays chunky when close), no gloss, no mip blur. Animations (Godot strips the "-loop" suffix and sets looping): "idle", "walk", "head_turn".

const GLB := "res://game/prototypes/sarah_meshy/CHR_Sarah_Meshy_Proto.glb"


static func instantiate() -> Node3D:
	var ps := load(GLB) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	psx_look(n)
	return n


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
