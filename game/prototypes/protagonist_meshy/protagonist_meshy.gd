extends RefCounted
class_name VeilProtagonistMeshy
## THE VEIL - prototype of the Meshy protagonist (NOT used by any scene yet). Same rig, bone names and clips as the Meshy Sarah
## (see sarah_meshy_proto.gd), original 2048 px Meshy texture untouched, shown with nearest-neighbour filtering for the PSX look.
## Clips: "idle", "walk", "nervous_idle", "injured_idle" (loops), "head_turn", "scared_reaction" (one shot), hand poses "hand_*".
## The walk does not slide when the body moves at walk_speed() metres per second.

const GLB := "res://game/prototypes/protagonist_meshy/CHR_Protagonist_Meshy.glb"
const INFO := "res://game/prototypes/protagonist_meshy/protagonist_meshy.json"


static func instantiate(with_face := true) -> Node3D:
	var ps := load(GLB) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	VeilSarahMeshyProto.psx_look(n)
	if with_face:
		var f := VeilSarahFace.new()                      # the same decal-face controller as Sarah's (neutral / scared / angry, talking, blinking)
		f.name = "Face"
		n.add_child(f)
		f.setup(n)
	return n


static func face(root: Node) -> VeilSarahFace:
	return root.get_node_or_null("Face") as VeilSarahFace


static func walk_speed() -> float:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(INFO)) if FileAccess.file_exists(INFO) else {}
	return float((d as Dictionary).get("walk_ground_speed", 0.55)) if d is Dictionary else 0.55
