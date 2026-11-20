extends RefCounted
class_name VeilMeshyNpcs
## THE VEIL - the Meshy characters stand in for the old ones. ON by default. To play with the OLD characters instead launch with `-- old_npcs`
## (godot --path . -- old_npcs) or set the environment variable VEIL_OLD_NPCS=1.
## world.gd `_spawn_npc(...)` asks `model_for(speaker)`: the Meshy model (with face-texture expressions) when this speaker has one, else the old model.
## Edit MAP to change who plays whom (the slug is a folder name under game/prototypes/npc_meshy, or "protagonist" / "sarah").
const MAP := {
	"Protagonist": "protagonist", "Trailer_Driver": "protagonist", "Reflection": "protagonist",
	"Eddie": "eddie",
	"Marcus": "bearded_man",
	"Noah": "teen_blue_jacket",
	"Ruth": "elderly_woman",
	"Sarah": "sarah",
	"Lena": "plaid_shirt",
	"Frank": "police_cap",
	"Officer": "police_officer",
	"Cashier": "clerk_burgundy",                       # the new store clerk
	"Survivor": "store_clerk",                          # the old clerk: David (his name is set in hud.gd SPEAKER_NAMES)
	"Civilian_A": "bomber", "Civilian_B": "woman_red_plaid", "Joan": "woman_red_plaid",
	"Res_Walker": "plaid_man", "Res_Neighbour": "tan_jacket", "Res_Driveway": "bomber",
	"LT_Driver": "bomber", "LT_Window": "woman_red_plaid",
}
## Characters that have only their painted neutral face (no expression sheet): plain rigged GLBs `CHR_<slug>_Meshy.glb`, a VeilPlainFace as their face controller.
const PLAIN := ["bomber", "clerk_burgundy", "woman_red_plaid", "tan_jacket", "plaid_man"]
const MIXAMO := ["bomber", "woman_red_plaid", "tan_jacket"]                    ## played by the Mixamo-rigged model that plays its own Walking / Running clips (NpcAnimator native mode)
const FACE_MIXAMO := ["eddie"]               ## Mixamo-rigged models whose expression faces are cut onto the new mesh (game/npc/face_fit.gd, face_fit/<slug>.json)
const EXTRAS := ["bomber", "woman_red_plaid", "tan_jacket", "plaid_man"]     # the town's neighbours, walkers and drivers (LT_*)
const PROTAGONIST_GLB := "res://game/prototypes/protagonist_meshy/face/CHR_Protagonist_FaceTex.glb"


static func enabled() -> bool:
	return not OS.get_cmdline_user_args().has("old_npcs") and OS.get_environment("VEIL_OLD_NPCS") != "1"


static func slug_for(speaker: String) -> String:
	if MAP.has(speaker):
		return String(MAP[speaker])
	if speaker.begins_with("LT_"):                   # the living town's drivers and extras
		return String(EXTRAS[absi(speaker.hash()) % EXTRAS.size()])
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
	if PLAIN.has(slug):
		var ps := load("res://game/prototypes/npc_meshy/CHR_%s_Mixamo.glb" % slug if MIXAMO.has(slug) else "res://game/prototypes/npc_meshy/CHR_%s_Meshy.glb" % slug) as PackedScene
		if ps == null:
			return null
		var pn := ps.instantiate() as Node3D
		VeilSarahMeshyProto.psx_look(pn)
		var pf := VeilPlainFace.new()
		pf.name = "FaceTex"
		pn.add_child(pf)
		return pn
	if FACE_MIXAMO.has(slug):
		var mps := load("res://game/prototypes/npc_meshy/CHR_%s_Mixamo.glb" % slug) as PackedScene
		if mps != null:
			var mn := mps.instantiate() as Node3D
			VeilSarahMeshyProto.psx_look(mn)
			if VeilFaceFit.apply(mn, slug):
				var mf := VeilNpcFaceTex.new()
				mf.name = "FaceTex"
				mf.slug = slug
				mn.add_child(mf)
				mf.setup(mn)
				return mn
			mn.free()
	return VeilNpcFaceTex.instantiate(slug)


## The node that answers the world's VeilFace calls for a Meshy model.
static func face_for(model_parent: Node) -> Node:
	var ctrl: Node = model_parent.find_child("FaceTex", true, false)
	if ctrl == null:
		ctrl = model_parent.find_child("Face", true, false)
	var a := VeilMeshyNpcFace.new()
	a.setup(ctrl)
	return a


## The Meshy MONSTERS (game/prototypes/monsters_meshy) stand in for the old creatures where a scene has been converted (so far: the roof Skitter). ON by default;
## `-- old_monsters` (or VEIL_OLD_MONSTERS=1) plays with the old creatures.
static func monsters_enabled() -> bool:
	return not OS.get_cmdline_user_args().has("old_monsters") and OS.get_environment("VEIL_OLD_MONSTERS") != "1"


## The Colossus is the Meshy tripod (a searchlight eye that scans the city and locks on). `-- old_colossus` (or VEIL_OLD_COLOSSUS=1) plays the original stomping encounter.
static func tripod_enabled() -> bool:
	return not OS.get_cmdline_user_args().has("old_colossus") and OS.get_environment("VEIL_OLD_COLOSSUS") != "1"


## The Skitter scene to load: the Meshy Skitter (same bones, clip names and metadata as the old one) unless `-- old_monsters`.
static func skitter_scene(old_path: String) -> String:
	return "res://game/prototypes/monsters_meshy/MON_skitter.tscn" if monsters_enabled() else old_path


## Creature scenes: the Meshy version of an old creature scene path (same interface: clip names, metadata, markers), unless `-- old_monsters`.
const MONSTER_SCENES := {
	"CRT_Shellcrawler.tscn": "res://game/prototypes/monsters_meshy/MON_crab.tscn",
	"CRT_Skitter.tscn": "res://game/prototypes/monsters_meshy/MON_skitter.tscn",
	"CRT_Hound.tscn": "res://game/prototypes/monsters_meshy/MON_hound.tscn",
	"CRT_MistTentacle_Thin.tscn": "res://game/prototypes/monsters_meshy/MON_tentacle_thin.tscn",
	"CRT_MistTentacle_Medium.tscn": "res://game/prototypes/monsters_meshy/MON_tentacle_medium.tscn",
	"CRT_MistTentacle_Large.tscn": "res://game/prototypes/monsters_meshy/MON_tentacle_large.tscn",
}


static func monster_scene(old_path: String) -> String:
	if not monsters_enabled():
		return old_path
	return String(MONSTER_SCENES.get(old_path.get_file(), old_path))
