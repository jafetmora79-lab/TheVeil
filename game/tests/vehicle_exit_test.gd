extends SceneTree
## THE VEIL - audit: the player can always get out of the car, even when every usual exit spot is blocked.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/vehicle_exit_test.gd
## A bare physics world (a floor and the sedan); boxes on every spot PlayerSedan.exit_spot tries first; the answer must
## still be a standable point clear of the boxes (the car "must never hold the player inside").

var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _box(parent: Node, at: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	b.add_child(cs)
	parent.add_child(b)
	b.global_position = at


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_box(world, Vector3(0, -0.5, 0), Vector3(80, 1, 80))                    # the floor (top at y = 0)
	var car = load("res://game/vehicles/player_sedan.gd").new()            # (by path, as world.gd does)
	world.add_child(car)
	car.global_position = Vector3(0, 0.05, 0)
	for i in 6:
		await physics_frame
	car.set_physics_process(false)                  # parked: the pillars below must not shove it about
	var space: PhysicsDirectSpaceState3D = car.get_world_3d().direct_space_state
	var player_rid := RID()
	# 1. open ground: the usual door-side spot
	var open: Variant = car.exit_spot(space, player_rid)
	ok("open_ground_has_exit", open is Vector3, str(open))
	# 2. every spot the function tries is walled in (0.6 x 2.5 x 0.6 m pillars: a capsule centred on a spot cannot stand there)
	var offs := [Vector3(-1.6, 0, -0.3), Vector3(1.6, 0, -0.3), Vector3(-1.6, 0, 1.1), Vector3(1.6, 0, 1.1),
			Vector3(-2.2, 0, -0.3), Vector3(2.2, 0, -0.3), Vector3(0, 0, 3.1), Vector3(0, 0, -3.1)]
	for o in offs:
		_box(world, car.global_transform * o + Vector3(0, 1.25, 0), Vector3(0.6, 2.5, 0.6))
	for i in 4:
		await physics_frame
	space = car.get_world_3d().direct_space_state
	var blocked: Variant = car.exit_spot(space, player_rid)
	ok("all_usual_spots_blocked_still_has_exit", blocked is Vector3, str(blocked))
	if blocked is Vector3:
		var p: Vector3 = blocked
		var capsule := CapsuleShape3D.new()
		var PL = load("res://game/player/player.gd")
		capsule.radius = PL.RADIUS
		capsule.height = PL.HEIGHT
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.collision_mask = 1 | 4
		q.transform = Transform3D(Basis(), p + Vector3.UP * capsule.height * 0.5)
		# (the car's own body is on layer 4: the spot must be clear of it as well)
		ok("exit_spot_is_clear", space.intersect_shape(q, 1).is_empty(), str(p))
		ok("exit_spot_on_floor", absf(p.y) < 0.2, "%.2f" % p.y)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
