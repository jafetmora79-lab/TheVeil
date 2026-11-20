extends SceneTree
## AUDIT of every NPC body at the start of every chapter, and of scripted walks:
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/npc_physics_audit_test.gd [-- 6 7]
## Per chapter start it lists each VeilSurvivorBody: hidden / not placed / inside a solid / not on the floor.
## Then it walks a body through a wall with the scripted walk (walk_to) to show whether walls stop it.
## Prints one line per problem and "RESULT". Backs up and restores the save slot.

const CS := preload("res://game/chapters/chapter_select.gd")

var fails := 0
var game: Node
var w: Node
var ps: PackedScene
var _backup := {}


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(k: int) -> void:
	for i in k:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(1800.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _floor_gap(b: VeilSurvivorBody) -> float:
	var q := PhysicsRayQueryParameters3D.create(b.global_position + Vector3(0, 0.6, 0), b.global_position + Vector3(0, -4.0, 0), 1)
	var h: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(q)
	return b.global_position.y - (h.position as Vector3).y if not h.is_empty() else INF


func audit(tag: String) -> void:
	for b in w.find_children("*", "VeilSurvivorBody", true, false):
		var body := b as VeilSurvivorBody
		var where := "%s at %s" % [body.name, body.global_position.snappedf(0.1)]
		var vis := body.is_visible_in_tree()
		var placed: bool = body._placement_valid
		var clear := body.is_clear(body.global_position)
		var gap := _floor_gap(body)
		var an1 := body.get_node_or_null("Animator")
		if an1 != null and (an1.seated or an1.is_walking()):
			continue                                     # (a walker mid-kerb is a moment, not a defect)                                     # sitting on a crate / chair / in a car: overlapping furniture is the pose
		var meta := " vis=%s placed=%s clear=%s floor_gap=%.2f" % [vis, placed, clear, gap]
		# a hidden survivor is only fine when the story hides it on purpose (inside the car, dead, gone)
		if not clear:
			var an0 := body.get_node_or_null("Animator")
			if an0 != null:
				meta += " [walking=%s seated=%s hold=%s layer=%d unsticks=%d]" % [an0.is_walking(), an0.seated, an0.hold_facing, body.collision_layer, body.unsticks]
			var hits: Array = w.get_world_3d().direct_space_state.intersect_shape(body.clearance_at(body.global_position), 6)
			meta += " overlaps=" + str(hits.map(func(h): return "%s/%s" % [(h["collider"] as Node).get_parent().name if (h["collider"] as Node).get_parent() else "", (h["collider"] as Node).name]))
		ok(tag + "_" + String(body.name) + "_placed", placed, where + meta)
		if vis:
			ok(tag + "_" + String(body.name) + "_clear", clear, where + meta)
			ok(tag + "_" + String(body.name) + "_on_floor", gap < 0.4 and gap > -0.2, where + meta)
		else:
			print("NOTE %s hidden: %s%s" % [tag, where, meta])


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	ps = load("res://game/scenes/World.tscn")
	for p in [game.SAVE_PATH]:
		_backup[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			only.append(int(a))
	for n in range(2, CS.COUNT + 1):
		if not only.is_empty() and not n in only:
			continue
		if not CS.prepare(game, n):
			ok("c%d_prepare" % n, false)
			continue
		w = ps.instantiate()
		root.add_child(w)
		await frames(90)
		for i in 600:                                    # let the chapter's own opening scene finish placing people
			await process_frame
		audit("c%d" % n)
		w.free()
		await frames(5)
	# ---- a scripted walk straight through a wall: does anything stop it?
	if only.is_empty() or 1 in only:
		CS.prepare(game, 6)
		w = ps.instantiate()
		root.add_child(w)
		await frames(120)
		var eddie: VeilSurvivorBody = w.eddie as VeilSurvivorBody
		if eddie != null:
			eddie.place_at(eddie.global_position)
			var start := eddie.global_position
			var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
			var wall := Vector3.INF
			for ang in 24:                               # the nearest wall the body could be sent through
				var dir := Vector3(cos(ang * TAU / 24.0), 0, sin(ang * TAU / 24.0))
				var h: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(start + Vector3(0, 0.9, 0), start + Vector3(0, 0.9, 0) + dir * 8.0, 1))
				if not h.is_empty() and (wall == Vector3.INF or (h.position as Vector3).distance_to(start) < wall.distance_to(start)):
					wall = h.position
			if wall != Vector3.INF:
				var dir := ((wall - start) * Vector3(1, 0, 1)).normalized()
				var goal := wall + dir * 2.5
				var an: NpcAnimator = eddie.get_node("Animator")
				an.walk_to([eddie.get_parent_node_3d().to_local(Vector3(goal.x, start.y, goal.z))], 2.0)
				await frames(60 * 6)
				var through := eddie.global_position.distance_to(start) > wall.distance_to(start) + 0.6
				# a wall may only be crossed as the declared last resort (no detour exists): then the walk recorded a jam
				ok("scripted_walk_stopped_by_wall", not through or an.jams > 0, "walked %.1f m, wall at %.1f m, jams=%d" % [eddie.global_position.distance_to(start), wall.distance_to(start), an.jams])
				print("NOTE walk through=%s jams=%d" % [through, an.jams])
				ok("scripted_walk_end_clear", eddie.is_clear(eddie.global_position), str(eddie.global_position.snappedf(0.1)))
		# ---- the player left inside a prop by a scene's hand-typed teleport is lifted out; a drop out of the world is recovered quickly
		await frames(120)
		var pl: CharacterBody3D = w.player
		pl.controls_enabled = true
		pl.global_position = Vector3(40.0, 5.0, 40.0) if false else pl.global_position
		var box := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.2, 1.0, 1.2)
		cs.shape = bs
		box.add_child(cs)
		w.add_child(box)
		box.global_position = pl.global_position + Vector3(0, 0.5, 0)       # a crate dropped onto the player's feet
		var un0: int = pl.unsticks
		await frames(60 * 4)
		var pq := PhysicsShapeQueryParameters3D.new()
		pq.shape = pl.capsule
		pq.collision_mask = 1
		pq.exclude = [pl.get_rid()]
		pq.transform = Transform3D(Basis.IDENTITY, pl.global_position + Vector3(0, pl.capsule.height * 0.5 + 0.02, 0))
		var still: bool = not w.get_world_3d().direct_space_state.intersect_shape(pq, 1).is_empty()
		ok("player_lifted_out_of_prop", not still, "unsticks %d -> %d, still inside=%s at %s" % [un0, pl.unsticks, still, pl.global_position.snappedf(0.1)])
		box.queue_free()
		w.free()
	for p in _backup:
		if _backup[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(_backup[p])
			f.close()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
