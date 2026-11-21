extends SceneTree
## Dev probe (review note #7): an ASCII map of the supermarket's free floor (market-local), with the shopper's current route marked.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = root.get_node("Game")
	game.new_game()
	game.flags["intro_seen"] = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 90: await process_frame
	var mk: Node3D = w.market
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	var sph := SphereShape3D.new()
	sph.radius = 0.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	q.collision_mask = 1
	q.exclude = [w.player.get_rid()]
	var route: Array = [Vector3(-4.0, 0.04, 7.2), Vector3(-4.0, 0.04, 12.75), Vector3(2.0, 0.04, 12.75), Vector3(2.0, 0.04, 7.2)]
	print("PROBE market origin ", mk.global_position, " yaw ", rad_to_deg(mk.global_rotation.y))
	for z in range(-1, 19):
		var line := ""
		for xi in range(-40, 41):
			var x := xi * 0.5
			var free := true
			for h in [0.5, 1.2]:
				q.transform = Transform3D(Basis(), mk.global_transform * Vector3(x, 0.04 + h, float(z)))
				if not space.intersect_shape(q, 1).is_empty():
					free = false
			var mark := "."
			for r in route:
				if absf(r.x - x) < 0.25 and absf(r.z - float(z)) < 0.5:
					mark = "R"
			line += ("#" if not free else mark) if mark == "." else mark
		print("PROBE z%3d %s" % [z, line])
	print("PROBE (x runs -20..20 in 0.5 m steps; # = within 0.5 m of something solid; R = a route waypoint)")
	quit()
