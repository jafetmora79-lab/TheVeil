extends SceneTree
## EXPERIMENT check (headless): the face-texture material survives into Godot 4.3 and the expression textures swap.
##   godot --headless --path . --script res://game/tests/protagonist_face_tex_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ps := load("res://game/prototypes/protagonist_meshy/face/CHR_Protagonist_FaceTex.glb") as PackedScene
	var n := ps.instantiate()
	root.add_child(n)
	await process_frame
	var f := VeilProtagonistFaceTex.new()
	n.add_child(f)
	ok("second_material_found", f.setup(n))
	for nm in VeilProtagonistFaceTex.NAMES:
		ok("texture_" + nm, VeilProtagonistFaceTex.texture(nm) != null)
	f.auto_blink = false
	ok("neutral", f.state == "neutral")
	f.blink()
	ok("blink_texture", f.state == "blink")
	for i in 14:
		await process_frame
	ok("blink_ends", f.state == "neutral")
	f.expression = "scared"
	ok("scared_texture", f.state == "scared")
	f.expression = "neutral"
	f.talking = true
	var seen := {}
	for i in 120:
		await process_frame
		seen[f.state] = true
	ok("talking_cycles", seen.has("talk_small") and seen.has("talk_wide"), str(seen.keys()))
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
