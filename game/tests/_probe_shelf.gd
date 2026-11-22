extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = root.get_node("Game")
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	var m: Node3D = w.market
	var col: StaticBody3D = m.get_node("Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Col")
	print("COLXF ", col.global_transform, " mkt ", m.global_transform)
	for c in col.get_children():
		var cs := c as CollisionShape3D
		if cs:
			var sh := cs.shape
			if sh is ConcavePolygonShape3D:
				print("CONCAVE faces ", (sh as ConcavePolygonShape3D).get_faces().size())
			else:
				print("SHAPE ", sh.get_class(), " ", cs.position, " ", (sh as BoxShape3D).size if sh is BoxShape3D else "")
	var mi: MeshInstance3D = m.get_node("Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Mesh")
	print("MI xf ", mi.global_transform.origin, " ", m.to_local(mi.global_position))
	var sm = m.get_node("Merchandise")
	print("MERCH ", sm.get_class(), " ", sm.transform, " ", sm.get_script().resource_path if sm.get_script() else "")
	quit()
