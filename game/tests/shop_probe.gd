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
	print("PROBE shop origin ", X.origin, " yaw ", rad_to_deg(w.game_shop.global_rotation.y))
	for k in ["SEAT_BOX", "SEAT_DOCS", "EDDIE_STAND", "STOCK_CIRCLE", "STOCK_IN"]:
		var v: Vector3 = w.get(k)
		print("PROBE ", k, " local ", v, " world ", X * v)
	var note_hit := Vector3(9.24, 0.98, 16.34)
	print("PROBE note hit in shop-local ", X.affine_inverse() * note_hit, "  camera local ", X.affine_inverse() * Vector3(11.12, 1.8, 16.75))
	# the boxes near there
	for n in w.game_shop.find_children("*", "Node3D", true, false):
		var l: Vector3 = X.affine_inverse() * (n as Node3D).global_position
		if l.x < 2.0 and l.x > -7.0 and l.z > 7.5 and l.z < 12.5 and ("Box" in String(n.name) or "Doc" in String(n.name) or "Crate" in String(n.name)):
			print("PROBE node ", n.name, " local ", l)
	quit()
