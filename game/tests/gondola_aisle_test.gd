extends SceneTree
## A shelf aisle cut out of the building and made a movable prop (the supermarket's gondola next to the rear doorway).
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))
func _tris(mi: MeshInstance3D) -> int:
	var n := 0
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		n += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n
func _run() -> void:
	var game = root.get_node("Game")
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	var m: Node3D = w.market
	var mi := m.get_node("Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Mesh") as MeshInstance3D
	var col := m.get_node("Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Col") as StaticBody3D
	var t0 := _tris(mi)
	var f0 := ((col.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().size()
	var prop: Node3D = load("res://game/world/gondola_aisle.gd").detach(m, Vector3(9.5, 0.0, 10.0), 90.0)
	var t1 := _tris(mi)
	var f1 := ((col.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().size()
	ok("mesh_cut", t1 < t0 and t0 - t1 < 400, "%d -> %d" % [t0, t1])
	ok("collision_cut", f1 < f0, "%d -> %d" % [f0, f1])
	var mmn := 0
	for c in prop.get_children():
		if c is MultiMeshInstance3D:
			mmn += (c as MultiMeshInstance3D).multimesh.instance_count
	ok("products_move_along", mmn > 50, str(mmn))
	ok("prop_there", prop != null and prop.get_node_or_null("AisleBody") != null)
	var again = load("res://game/world/gondola_aisle.gd").detach(m, Vector3(9.5, 0.0, 10.0), 90.0)
	ok("once", again == prop)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
