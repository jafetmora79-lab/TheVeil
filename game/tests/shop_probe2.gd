extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = root.get_node("Game")
	game.new_game()
	game.flags["intro_seen"] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 90: await process_frame
	var X: Transform3D = w.game_shop.global_transform
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	print("PROBE heights (cm above floor) of the stock-room corner, shop-local; columns x -6.0..-3.2 step 0.2, rows z 8.5..10.5 step 0.2")
	for zi in range(0, 11):
		var z := 8.5 + zi * 0.2
		var line := ""
		for xi in range(0, 15):
			var x := -6.0 + xi * 0.2
			var from: Vector3 = X * Vector3(x, 2.4, z)
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 3.0, 0), 1, [w.player.get_rid()]))
			var hh := -1
			if not h.is_empty():
				hh = int(roundf(((h["position"] as Vector3).y - X.origin.y - 0.04) * 100.0))
			line += "%4d" % hh
		print("PROBE z%.1f %s" % [z, line])
	quit()
