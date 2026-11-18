extends SceneTree
## THE VEIL - audit: at every chapter start, no NPC stands inside furniture / a wall / another character, floats,
## or crowds another (the recurring "Marcus inside the counter" class of bug).
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/audit_npc_placement_test.gd [-- 5 9 13]
## Per chapter n (3..16): load the chapter start, wait for its opening to settle, then for every visible survivor body:
##   * a floor under its feet within 0.15 m          (not floating, not sunk)
##   * its whole capsule fits in free space           (VeilSurvivorBody.is_clear: static world + other bodies)
##   * >= 0.45 m from every other visible survivor    (personal space)
## The player's save is backed up first and put back after (like chapter_select_test).

const CS := preload("res://game/chapters/chapter_select.gd")
const MIN_GAP := 0.45
var fails := 0
var game: Node
var w: Node
var _backup := {}


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(1500.0).timeout.connect(func():
		_restore()
		print("RESULT FAIL (watchdog)")
		quit(1))


func _restore() -> void:
	for p in _backup:
		if _backup[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(_backup[p])
			f.close()


func _run() -> void:
	game = root.get_node("Game")
	for p in [game.SAVE_PATH, CS.UNLOCK_PATH]:
		_backup[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			only.append(int(a))
	for n in range(3, CS.COUNT + 1):
		if not only.is_empty() and not (n in only):
			continue
		await _chapter(n)
	_restore()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


func _chapter(n: int) -> void:
	CS.prepare(game, n)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(420)                                     # the chapter's own opening has run and settled
	var tag := "ch%02d" % n
	var bodies: Array = []
	for speaker in w.animators:
		var a = w.animators[speaker]
		if not is_instance_valid(a) or not is_instance_valid(a.root):
			continue
		var b := a.root as VeilSurvivorBody
		if b != null and b.is_visible_in_tree() and not String(speaker).begins_with("Reflection") and speaker != "Protagonist":
			bodies.append([String(speaker), b])
	ok(tag + "_npcs_counted", true, "%d visible NPCs: %s" % [bodies.size(), bodies.map(func(e): return e[0])])
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	for e in bodies:
		var b: VeilSurvivorBody = e[1]
		var f := VeilSurvivorBody.floor_at(space, b.global_position, 0.3, 0.3)
		ok(tag + "_" + e[0] + "_on_floor", f.is_finite() and absf(f.y - b.global_position.y) < 0.15,
			"feet %.2f floor %s" % [b.global_position.y, f])
		ok(tag + "_" + e[0] + "_not_in_solid", b.is_clear(b.global_position), str(b.global_position))
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var d: float = (bodies[i][1].global_position - bodies[j][1].global_position).length()
			ok(tag + "_%s_%s_apart" % [bodies[i][0], bodies[j][0]], d >= MIN_GAP, "%.2f m" % d)
	w.queue_free()
	await frames(5)
