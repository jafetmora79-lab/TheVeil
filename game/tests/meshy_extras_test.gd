extends SceneTree
## THE VEIL - the five newer Meshy characters (neighbours, walkers, the new store clerk) load, have the shared skeleton and a face controller; David = the old clerk.
##   godot --headless --path . --script res://game/tests/meshy_extras_test.gd
func _initialize() -> void:
	var fails := 0
	for spk in ["Cashier", "Survivor", "Civilian_A", "Civilian_B", "Joan", "Res_Walker", "Res_Neighbour", "Res_Driveway", "LT_Driver", "LT_Window", "LT_Drv_3", "LT_Drv_8"]:
		var m := VeilMeshyNpcs.model_for(spk)
		var good := m != null
		var sk := 0
		if good:
			root.add_child(m)
			sk = m.find_children("*", "Skeleton3D", true, false).size()
			good = sk == 1 and VeilMeshyNpcs.face_for(m) != null
		print("TEST ", spk, " -> ", VeilMeshyNpcs.slug_for(spk), " ", "PASS" if good else "FAIL")
		if not good:
			fails += 1
	print("RESULT ", "PASS" if fails == 0 else "FAIL", " fails=", fails)
	quit(fails)
