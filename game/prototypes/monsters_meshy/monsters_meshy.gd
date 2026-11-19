extends RefCounted
class_name VeilMonstersMeshy
## THE VEIL - the five Meshy monsters, rigged (NOT used by the game yet). Faces +Z-forward like the characters (they look toward Godot -Z). Textures nearest-neighbour.
## hound (4 legs, head, tail), spider (8 legs), crab (10 legs), tentacle_v1 / tentacle_v3 (a 9-bone chain).
## Clips (Godot strips "-loop"): legged: "idle", "walk"; tentacles: "idle", "strike" (one shot), "retract" (one shot).
## <slug>.json next to the GLB has size_m, height_m and (legged) walk_ground_speed / walk_cycle_s. Bone names are NEW (Body, Leg0_L_Up / Leg0_L_Lo ..., Head, Tail1, T0..T8):
## code written for the old creature rigs (hound_ai.gd, the Skitter and Shellcrawler scenes, the tentacle poser) needs adapting before it can drive these.
const SLUGS := ["hound", "spider", "crab", "tentacle_v1", "tentacle_v3"]
const OLD_EQUIVALENT := {"hound": "Hounds/CRT_Hound", "spider": "Skitter/CRT_Skitter", "crab": "Shellcrawler", "tentacle_v1": "Mist_Tentacles", "tentacle_v3": "Mist_Tentacles"}


static func instantiate(slug: String) -> Node3D:
	var ps := load("res://game/prototypes/monsters_meshy/MON_%s.glb" % slug) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	VeilSarahMeshyProto.psx_look(n)
	return n


static func info(slug: String) -> Dictionary:
	var p := "res://game/prototypes/monsters_meshy/%s.json" % slug
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else {}
	return d if d is Dictionary else {}
