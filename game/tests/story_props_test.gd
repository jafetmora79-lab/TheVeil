extends SceneTree
## The Blender-made story props load and carry the nodes the chapters animate (levers, breakers, gauges, lamps, door leaves, the vent grate).
##   godot --headless --path . --script res://game/tests/story_props_test.gd
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c: fails += 1
func _initialize() -> void:
	var D := "res://game/prototypes/story_props/"
	var need := {"FAC_PowerControl.glb": ["MainLever", "Switch1", "Switch2", "Switch3", "Needle1", "Needle2", "Needle3", "Lamp1", "Lamp6"],
		"FAC_SlidingDoor.glb": ["LeafL", "LeafR", "Header"], "FAC_SlidingDoor_Rust.glb": ["LeafL", "LeafR", "Header"],
		"FAC_VentDuct.glb": ["Grate", "Back"], "FAC_DuctRun_3m.glb": ["Top"]}
	for f in need:
		var ps := load(D + f) as PackedScene
		ok("loads_" + f, ps != null)
		if ps == null: continue
		var n := ps.instantiate()
		for nm in need[f]:
			ok("%s_has_%s" % [f, nm], n.find_child(nm, true, false) != null)
		n.free()
	for f in ["PRP_Plank_1.0.glb", "PRP_Plank_1.4.glb", "PRP_Plank_1.0_Broken.glb", "PRP_Plank_1.6_Dark.glb", "PRP_Paper_Sheet_A.glb", "PRP_Paper_Pile_A.glb", "PRP_Paper_Pile_B.glb", "PRP_Paper_Pile_C.glb"]:
		ok("loads_" + f, load(D + f) != null)
	for t in ["art_safety", "art_grid", "art_schedule", "art_warning", "art_pinboard", "paper_a", "paper_b", "paper_c"]:
		ok("texture_" + t, load(D + "tex/" + t + ".png") != null)
	# the door's header must reach the frame's full height (nothing open above the door)
	var d := (load(D + "FAC_SlidingDoor.glb") as PackedScene).instantiate()
	var hd := d.find_child("Header", true, false) as MeshInstance3D
	var top: float = hd.get_aabb().end.y if hd else 0.0
	ok("door_header_at_ceiling", hd != null and top > 3.1, "top %.2f" % top)
	d.free()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
