extends RefCounted
class_name VeilMeshyNpcs
## THE VEIL - the Meshy characters stand in for the old ones. ON by default. To play with the OLD characters instead launch with `-- old_npcs`
## (godot --path . -- old_npcs) or set the environment variable VEIL_OLD_NPCS=1.
## world.gd `_spawn_npc(...)` asks `model_for(speaker)`: the Meshy model (with face-texture expressions) when this speaker has one, else the old model.
## Edit MAP to change who plays whom (the slug is a folder name under game/prototypes/npc_meshy, or "protagonist" / "sarah").
const MAP := {
	"Protagonist": "protagonist", "Trailer_Driver": "protagonist",
	"Eddie": "eddie",
	"Marcus": "bearded_man",
	"Noah": "teen_blue_jacket",
	"Ruth": "elderly_woman",
	"Sarah": "sarah",
	"Lena": "plaid_shirt",
	"Frank": "police_cap",
	"Officer": "police_officer",
	"Cashier": "store_clerk", "Survivor": "store_clerk", "Civilian_A": "store_clerk", "LT_Window": "store_clerk",
	"Civilian_B": "police_redhair",
}
const PROTAGONIST_GLB := "res://game/prototypes/protagonist_meshy/face/CHR_Protagonist_FaceTex.glb"


static func enabled() -> bool:
	return not OS.get_cmdline_user_args().has("old_npcs") and OS.get_environment("VEIL_OLD_NPCS") != "1"


static func slug_for(speaker: String) -> String:
	if MAP.has(speaker):
		return String(MAP[speaker])
	if speaker.begins_with("LT_"):                   # the living town's drivers and extras
		return "store_clerk"
	return ""


## The Meshy model for this speaker, or null (old characters selected / no Meshy model for this speaker).
static func model_for(speaker: String) -> Node3D:
	var slug := slug_for(speaker)
	if not enabled() or slug == "":
		return null
	match slug:
		"protagonist":
			var n := (load(PROTAGONIST_GLB) as PackedScene).instantiate() as Node3D
			VeilSarahMeshyProto.psx_look(n)
			var f := VeilProtagonistFaceTex.new()
			f.name = "FaceTex"
			n.add_child(f)
			f.setup(n)
			return n
		"sarah":
			return VeilSarahMeshyProto.instantiate(true)                  # her face is the decal face (child "Face")
	return VeilNpcFaceTex.instantiate(slug)


## The node that answers the world's VeilFace calls for a Meshy model.
static func face_for(model_parent: Node) -> Node:
	var ctrl: Node = model_parent.find_child("FaceTex", true, false)
	if ctrl == null:
		ctrl = model_parent.find_child("Face", true, false)
	var a := VeilMeshyNpcFace.new()
	a.setup(ctrl)
	return a
