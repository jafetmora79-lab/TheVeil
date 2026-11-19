extends SceneTree
## EXPERIMENT check (headless): every NPC that has face-texture expressions loads with its second material and swaps textures.
##   godot --headless --path . --script res://game/tests/npc_face_tex_test.gd
const SLUGS := ["police_officer", "eddie", "plaid_shirt", "bearded_man", "police_cap"]
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for slug in SLUGS:
		var n := VeilNpcFaceTex.instantiate(slug)
		if n == null:
			ok(slug + "_loads", false)
			continue
		root.add_child(n)
		await process_frame
		var f := n.get_node("FaceTex") as VeilNpcFaceTex
		var all_tex := true
		for nm in VeilNpcFaceTex.NAMES:
			all_tex = all_tex and VeilNpcFaceTex.texture(slug, nm) != null
		ok(slug + "_textures", all_tex)
		var mi: MeshInstance3D = null
		for m in n.find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).mesh.get_surface_count() >= 2:
				mi = m
		ok(slug + "_second_material", mi != null)
		f.auto_blink = false
		f.blink()
		ok(slug + "_blink", f.state == "blink")
		for i in 14:
			await process_frame
		ok(slug + "_blink_ends", f.state == "neutral")
		f.expression = "scared"
		ok(slug + "_scared", f.state == "scared")
		f.expression = "angry"
		ok(slug + "_angry", f.state == "angry")
		f.expression = "worried"
		ok(slug + "_worried", f.state == "worried")
		f.expression = "neutral"
		f.talking = true
		var seen := {}
		for i in 100:
			await process_frame
			seen[f.state] = true
		ok(slug + "_talking", seen.has("talk_small") and seen.has("talk_wide"), str(seen.keys()))
		var anim_ok := VeilSarahMeshyProto.anim_player(n) != null and VeilSarahMeshyProto.anim_player(n).has_animation("walk")
		ok(slug + "_keeps_clips", anim_ok)
		n.queue_free()
		await process_frame
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
