extends SceneTree
## Review notes #14 / #15 / #18 / #19 / #21 / #20: the rebuilt supermarket fixtures stand where the old ones were (and the old ones are gone), the game-shop case is rebuilt,
## Frank's scene is staged out of doors, and the encounter's mist carries on from its current density.
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = root.get_node("Game")
	game.new_game()
	game.flags["intro_seen"] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await process_frame
	var fx: Node = w.market.get_node_or_null("RebuiltFixtures")
	ok("market_fixtures_placed", fx != null and fx.get_child_count() == 12, str(fx.get_child_count() if fx else -1))
	var sfx: Node = w.game_shop.get_node_or_null("RebuiltFixtures")
	ok("shop_case_placed", sfx != null and sfx.get_child_count() == 1)
	# the old fixtures' triangles are gone from the furnishing mesh: nothing of it is left in the cut regions
	var mi: MeshInstance3D = w.market.get_node("Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Mesh")
	var inv: Transform3D = w.market.global_transform.affine_inverse() * mi.global_transform
	var left := 0
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in range(0, ix.size() - 2, 3):
			var c: Vector3 = inv * ((vs[ix[t]] + vs[ix[t + 1]] + vs[ix[t + 2]]) / 3.0)
			for r in w.market_fixes_cuts():
				if c.x >= r[0] and c.x <= r[1] and c.y >= r[2] and c.y <= r[3] and c.z >= r[4] and c.z <= r[5]:
					left += 1
	ok("old_fixtures_removed", left == 0, str(left))
	# each new model sits in its footprint (market-local)
	var bad := []
	for n in fx.get_children():
		var a := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (n.global_transform.affine_inverse() * (m as MeshInstance3D).global_transform) * (m as MeshInstance3D).get_aabb()
			a = b if first else a.merge(b)
			first = false
		if a.size.y < 0.5 or a.size.y > 2.6 or a.size.x > 2.6 or a.size.z > 2.6:
			bad.append("%s %s" % [n.name, a.size])
	ok("model_sizes", bad.is_empty(), str(bad))
	# Frank is staged out of doors even from a shop doorway (note #21)
	var lt = w.get("living")
	ok("point_outdoors", w.point_outdoors(w.market.to_global(Vector3(0, 0, -6.0))) and not w.point_outdoors(w.market.to_global(Vector3(0, 0, 8.0))) and not w.point_outdoors(w.market.to_global(Vector3(0, 0, -0.5)), 1.0))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
