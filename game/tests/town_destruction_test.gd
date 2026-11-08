extends SceneTree
## THE VEIL - post-time-skip town destruction: intact before p3_two_hours_later, the damaged models after it,
## lootable / story houses untouched, sidewalks and interactables clear, save/load keeps it with no duplicates.
## Headless, short; how it looks is for the playtest.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/town_destruction_test.gd

const STORY := ["PLAYER_HOME", "HOUSE_03", "HOUSE_04", "HOUSE_05", "HOUSE_06", "HOUSE_19", "HOUSE_20", "MILL_HOUSE", "FARMHOUSE"]
var fails := 0
var w: Node
var game: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(240.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _world() -> void:
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(120)


func _houses() -> Node:
	return w.get_node("Residential/Houses")


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	game.new_game()
	await _world()
	var td = w.town_destruction
	var T: Dictionary = td.TARGETS
	# ---- 1. before the skip: the town as it was
	var intact := true
	for id in T:
		var hh: Node3D = _houses().get_node(String(id))
		intact = intact and hh.get_node_or_null("Destroyed") == null and (hh.get_node("House") as Node3D).visible
	ok("intact_before_skip", not td.applied and intact)
	# ---- 2. the skip
	game.set_flag("p3_two_hours_later")
	await frames(60)
	ok("applied_after_skip", td.applied)
	var swapped: Array = []
	var bad: Array = []
	for id in T:
		var h: Node3D = _houses().get_node(String(id))
		var d := h.get_node_or_null("Destroyed")
		var col := h.get_node_or_null("DestroyedCol")
		var hidden := not (h.get_node("House") as Node3D).visible
		var remapped := false
		if d:
			for mi in d.find_children("Exterior*", "MeshInstance3D", true, false):
				var m := (mi as MeshInstance3D).get_surface_override_material(0)
				remapped = m != null and m.resource_path.begins_with("res://THE_VEIL_ASSETS_V2")
		if d and col and col.get_child_count() > 0 and hidden and remapped:
			swapped.append(id)
		else:
			bad.append("%s d=%s col=%s hidden=%s mat=%s" % [id, d != null, col != null, hidden, remapped])
	ok("all_variants_swapped", swapped.size() == T.size(), str(bad))
	var kinds := {}
	for id in T:
		kinds[T[id]] = true
	ok("six_kinds", kinds.size() == 6, str(kinds.keys()))
	ok("models_damaged", T.keys().all(func(id): return int(td.report[id].get("collision_meshes", 0)) >= 2))
	ok("skitter_inside", td.skitters.size() == 2 and td.skitters.all(func(s): return is_instance_valid(s["node"])))
	ok("tentacle_dressing", td.report["HOUSE_09"].get("tentacle", false))
	# ---- 3. lootable and story houses untouched
	var specs: Dictionary = load("res://game/world/scavenge_house.gd").load_specs()
	var keep: Array = (specs.get("houses", {}) as Dictionary).keys() + STORY
	var touched := keep.filter(func(id): return _houses().get_node_or_null(String(id)) != null and _houses().get_node(String(id)).get_node_or_null("Destroyed") != null)
	ok("protected_untouched", touched.is_empty() and not keep.any(func(id): return T.has(id)), str(touched))
	# ---- 4. sidewalks / roads clear; nothing on what the player uses
	var space: PhysicsDirectSpaceState3D = (w.get_world_3d() as World3D).direct_space_state
	var blocked: Array = []
	var near_it: Array = []
	var its: Array = w.find_children("*", "Interactable", true, false).map(func(i): return (i as Node3D).global_position)
	for id in T:
		var h: Node3D = _houses().get_node(String(id))
		var d := h.get_node("Destroyed")
		for mi in d.find_children("Debris*", "MeshInstance3D", true, false):
			var p: Vector3 = (mi as Node3D).global_position
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p - Vector3.UP * 3.0, 1, [h.get_node("DestroyedCol").get_rid()]))
			if hit and (String((hit["collider"] as Node).name).begins_with("RD_") or String((hit["collider"] as Node).name).begins_with("SW_")):
				blocked.append("%s:%s" % [id, mi.name])
			for ip in its:
				if Vector2(p.x - ip.x, p.z - ip.z).length() < 2.0:
					near_it.append("%s:%s" % [id, mi.name])
	ok("no_debris_on_paving", blocked.is_empty(), str(blocked.slice(0, 6)))
	ok("no_debris_on_interactables", near_it.is_empty(), str(near_it.slice(0, 6)))
	# a person fits on every sidewalk tile beside a damaged house
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	var walk_bad: Array = []
	var checked := 0
	for sw in w.find_children("SW_*", "Node3D", true, false):
		if String(sw.get_parent().name).begins_with("SW_") or sw is CollisionObject3D or sw is MeshInstance3D:
			continue
		var a: AABB = (sw as Node3D).global_transform * Interactable.aabb_of(sw as Node3D)
		var c := a.get_center()
		var near := T.keys().any(func(id): return (_houses().get_node(String(id)) as Node3D).global_position.distance_to(c) < 16.0)
		if not near:
			continue
		checked += 1
		q.transform = Transform3D(Basis(), Vector3(c.x, a.end.y + 1.0, c.z))
		for hh in space.intersect_shape(q, 6):
			var n: Node = hh["collider"]
			if String(n.name) == "DestroyedCol" or String(n.name) == "LeftCarCol":
				walk_bad.append(String(n.get_parent().name))
	ok("sidewalks_walkable", checked > 5 and walk_bad.is_empty(), "%d tiles, blocked by %s" % [checked, walk_bad])
	# ---- 5. save / load: still destroyed, nothing doubled
	game.save_game()
	w.queue_free()
	await frames(5)
	game.load_game()
	game.load_requested = true
	await _world()
	await frames(30)
	td = w.town_destruction
	var once := true
	for id in T:
		var hh: Node = _houses().get_node(String(id))
		once = once and hh.find_children("Destroyed", "", false, false).size() == 1 and hh.find_children("DestroyedCol", "", false, false).size() == 1
	ok("destroyed_after_reload", td.applied and once)
	ok("skitters_not_doubled", td.skitters.size() == 2)
	ok("dressing_not_doubled", T.keys().all(func(id): return _houses().get_node(String(id)).find_children("Dress_LeftCar", "", false, false).size() <= 1))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
