extends RefCounted
class_name VeilMeshyNpcs
## THE VEIL - TRIAL SWITCH: lets the Meshy NPCs stand in for the old characters. OFF unless asked for. Turn it on with the launch argument
## `-- meshy_npcs` (godot --path . -- meshy_npcs) or the environment variable VEIL_MESHY_NPCS=1. With it off the game is exactly as before.
## world.gd `_spawn_npc` asks `model_for(speaker)`: a Meshy model (with face-texture expressions) when the switch is on and the speaker has one.
## Trial cast: "Cashier" -> store_clerk, "Eddie" -> eddie. Add more speakers to MAP to extend the trial.
const MAP := {"Cashier": "store_clerk", "Eddie": "eddie"}


static func enabled() -> bool:
	return OS.get_cmdline_user_args().has("meshy_npcs") or OS.get_environment("VEIL_MESHY_NPCS") == "1"


## The Meshy model for this speaker, or null (switch off / no Meshy model for this character).
static func model_for(speaker: String) -> Node3D:
	if not enabled() or not MAP.has(speaker):
		return null
	return VeilNpcFaceTex.instantiate(String(MAP[speaker]))


## The node that answers the world's VeilFace calls for a Meshy model.
static func face_for(model_parent: Node) -> Node:
	var m := model_parent.find_child("FaceTex", true, false) as VeilNpcFaceTex
	var a := VeilMeshyNpcFace.new()
	a.setup(m)
	return a
