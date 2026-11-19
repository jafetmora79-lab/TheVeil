extends SceneTree
## dev tool: load the world from each chapter-select start and check where the player really is
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter_select_world_audit.gd [-- 6 7 8]
const CS := preload("res://game/chapters/chapter_select.gd")


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(900.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	var which: Array = []
	for a in OS.get_cmdline_user_args():
		which.append(int(a))
	if which.is_empty():
		which = range(2, 17)
	for n in which:
		if not CS.prepare(game, n):
			print("WORLD ch%d prepare FAILED" % n)
			continue
		var world = load("res://game/scenes/World.tscn").instantiate()
		root.add_child(world)
		await frames(100)
		var p = world.player
		var space = world.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 0.5, 0), p.global_position + Vector3(0, -6, 0), 1, [p.get_rid()])
		var h = space.intersect_ray(q)
		var floor_gap: float = 99.0 if h.is_empty() else p.global_position.y - h["position"].y
		print("WORLD ch%d chapter=%s step=%s pos=%s on_floor=%s floor_gap=%.2f visible=%s controls=%s fall_recoveries=%s in_car=%s gun=%s" % [n, game.chapter_number(), game.current_step().get("id", ""), p.global_position.snapped(Vector3(0.1, 0.1, 0.1)), p.is_on_floor(), floor_gap, p.visible, p.controls_enabled, p.fall_recoveries, world.in_car, game.has_item("handgun")])
		world.queue_free()
		await frames(10)
	quit(0)
