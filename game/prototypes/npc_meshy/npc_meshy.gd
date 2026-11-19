extends RefCounted
class_name VeilNpcMeshy
## THE VEIL - the Meshy NPCs (NOT used by any scene yet). Same 51-bone humanoid rig, bone names and clips as the Meshy Sarah and protagonist
## (see sarah_meshy_proto.gd): "idle", "walk", "nervous_idle", "injured_idle" (loops), "head_turn", "scared_reaction" (one shot), "hand_*" poses.
## Original 2048 px Meshy textures, shown with nearest-neighbour filtering for the PSX look. No face expressions yet.
const SLUGS := ["eddie", "plaid_shirt", "police_officer", "teen_blue_jacket", "bearded_man", "police_cap", "elderly_woman", "police_redhair", "store_clerk"]
const HEIGHTS := {"eddie": 1.76, "plaid_shirt": 1.66, "police_officer": 1.82, "teen_blue_jacket": 1.62, "bearded_man": 1.80, "police_cap": 1.78, "elderly_woman": 1.58, "police_redhair": 1.68, "store_clerk": 1.70}   ## metres (assumed: Meshy normalises every model to the same size)


static func glb_path(slug: String) -> String:
	return "res://game/prototypes/npc_meshy/CHR_%s_FaceTex.glb" % slug      # (the plain CHR_<slug>_Meshy.glb was removed: the FaceTex GLB has the same rig, clips and body)


static func instantiate(slug: String) -> Node3D:
	var ps := load(glb_path(slug)) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	VeilSarahMeshyProto.psx_look(n)
	return n


## Ground speed (m/s) at which the walk's planted feet do not slide.
static func walk_speed(slug: String) -> float:
	var p := "res://game/prototypes/npc_meshy/%s.json" % slug
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else {}
	return float((d as Dictionary).get("walk_ground_speed", 0.55)) if d is Dictionary else 0.55
