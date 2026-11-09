extends SceneTree
## THE VEIL - chapter select: every chapter (1-16) starts from the list into a complete, playable state: the story
## in that chapter, the player on clear ground with control, the car parked on the ground in the supermarket lot
## (and the keys to it), the survivors of that point present and standing on the floor (script errors between the CHAPTER n markers: the
## runner counts them). The
## player's own save is backed up first and put back after.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter_select_test.gd [-- 4 7]

const CS := preload("res://game/chapters/chapter_select.gd")
var fails := 0
var game: Node
var w: Node


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
		_restore_files()
		print("RESULT FAIL (watchdog)")
		quit(1))


var _backup := {}


func _backup_files() -> void:
	for p in [game.SAVE_PATH, CS.UNLOCK_PATH]:
		_backup[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null


func _restore_files() -> void:
	for p in _backup:
		if _backup[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(_backup[p])
			f.close()


func _ground_below(at: Vector3, exclude: Array) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.0, 0), at + Vector3(0, -3.0, 0), 1)
	q.exclude = exclude
	var h = w.get_world_3d().direct_space_state.intersect_ray(q)
	return at.y - (h.position as Vector3).y if not h.is_empty() else INF


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	_backup_files()
	# the unlock
	if FileAccess.file_exists(CS.UNLOCK_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CS.UNLOCK_PATH))
	var had_endings := FileAccess.file_exists(CS.ENDINGS_PATH)
	ok("locked_without_completion", had_endings or not CS.unlocked())
	CS.unlock_all()
	ok("unlock_all", CS.unlocked())
	# the menu shows the list
	change_scene_to_file("res://game/scenes/MainMenu.tscn")
	await frames(10)
	var mb := current_scene.find_child("ChaptersButton", true, false) as Button
	ok("menu_has_chapters", mb != null)
	if mb:
		mb.pressed.emit()
		await frames(2)
		var list := current_scene.find_child("ChapterList", true, false) as Control
		var n_buttons := 0
		for n in range(1, 17):
			if current_scene.find_child("Chapter%d" % n, true, false) != null:
				n_buttons += 1
		ok("menu_lists_16", list != null and list.visible and n_buttons == 16, "%d" % n_buttons)
	current_scene.queue_free()
	await frames(2)
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			only.append(int(a))
	if only.is_empty() or (0 in only):
		await _menu_path()
	for n in range(1, CS.COUNT + 1):
		if not only.is_empty() and not (n in only):
			continue
		await _chapter(n)
	_restore_files()
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)


func _chapter(n: int) -> void:
	print("== CHAPTER %d BEGIN" % n)                        # (script errors between the markers: counted by the runner)
	CS.prepare(game, n)
	var replays: Array = []                                # one-time scenes of OTHER chapters that fire on this start
	var watch := func(f: String):
		if (f.begins_with("chapter_card_") and f != "chapter_card_%d" % n) or f == "arrival_shot":
			replays.append(f)
	game.flag_set.connect(watch)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(300)
	var tag := "ch%02d" % n
	game.flag_set.disconnect(watch)
	if n == 1:
		ok(tag + "_opening_plays", not game.has_flag("intro_seen") or w.get("intro") != null or w.player.camera.current)
	else:
		# (Chapter 4 begins the moment they run for the supermarket: the number turns over as they go)
		ok(tag + "_in_chapter", game.chapter_number() == n or (n == 4 and game.chapter_number() == 3), "chapter %d" % game.chapter_number())
		ok(tag + "_hook_ran", int(w.chapter_start_report.get("chapter", 0)) == n and not game.world_state.has("chapter_start"))
		if n <= 5:
			ok(tag + "_player_placed", w.chapter_start_report.get("player_clear", false))
		var p: Node3D = w.player
		var pg := _ground_below(p.global_position, [p.get_rid()])
		ok(tag + "_player_on_ground", pg > -0.3 and pg < 0.6, "%.2f m above ground" % pg)
		ok(tag + "_player_not_in_wall", w._stand_clear(p.global_position) or w.in_car, str(p.global_position))
		ok(tag + "_car_keys", game.has_item("car_keys"))
		ok(tag + "_no_other_chapter_scenes", replays.is_empty(), str(replays))
		# where the chapter starts: Chapters 2-5 at the hook's spot; 6-16 where the chapter's own opening puts them
		# (some open by moving everyone, e.g. 13 and 16 into the refuge) - and nothing moves them after that
		var sp: Vector3 = w.chapter_start_report.get("start_pos", Vector3.INF)
		if n <= 5:
			ok(tag + "_at_canonical_start", p.global_position.distance_to(sp) < 4.0, "%.1f m from %s" % [p.global_position.distance_to(sp), sp])
		var at0 := p.global_position
		await frames(90)
		ok(tag + "_stays_put", not w.in_car and p.global_position.distance_to(at0) < 1.0, "%.2f m" % p.global_position.distance_to(at0))
		var car: Node3D = w.sedan
		var cg := _ground_below(car.global_position, [car.get_rid()])
		ok(tag + "_car_on_ground", cg > -0.4 and cg < 0.8, "%.2f m at %s" % [cg, car.global_position])
		ok(tag + "_car_not_repaired", not game.has_flag("vehicle_repaired") and not car.get("survival"))
		ok(tag + "_car_overlaps_nothing", _car_hits(car).is_empty(), str(_car_hits(car)))
		ok(tag + "_car_in_market_lot", car.global_position.distance_to(Vector3(34.7, 0.0, -22.6)) < 3.0, str(car.global_position))
		# the survivors of this point: present, visible, standing on the floor
		var want: Array = []
		if n >= 3:
			want.append("Eddie")
		if n >= 4 and n <= 10:
			want.append("Marcus")
		var missing: Array = []
		var floating: Array = []
		for nm in want:
			var an = w.animators.get(nm)
			var body: Node3D = an.root if an else null
			if body == null or not is_instance_valid(body) or not body.is_visible_in_tree():
				missing.append(nm)
				continue
			var g := _ground_below(body.global_position, [(body as CollisionObject3D).get_rid()] if body is CollisionObject3D else [])
			if g < -0.3 or g > 0.6:
				floating.append("%s %.2f" % [nm, g])
		ok(tag + "_survivors_present", missing.is_empty(), "missing %s" % str(missing))
		ok(tag + "_survivors_grounded", floating.is_empty(), str(floating))
		if n == 3 or n == 4:
			var in_shop: bool = w.game_shop.to_local((w.animators["Eddie"].root as Node3D).global_position).z > -0.5
			ok(tag + "_eddie_in_game_shop", in_shop)
		if n == 4:
			ok(tag + "_run_ready", w._p3_shop_talked and not w._p3_npcs_moved)
	print("== CHAPTER %d END" % n)
	w.queue_free()
	await frames(5)


## Anything solid the parked car's own collision overlaps (lifted 0.3 m off the ground so the lot itself doesn't count).
func _car_hits(car: Node3D) -> Array:
	var out: Array = []
	var ex: Array[RID] = [(car as CollisionObject3D).get_rid()]
	for cs in car.find_children("*", "CollisionShape3D", true, false):
		if (cs as CollisionShape3D).shape == null or (cs as CollisionShape3D).disabled:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = (cs as CollisionShape3D).shape
		q.transform = Transform3D(Basis(), Vector3(0, 0.3, 0)) * (cs as CollisionShape3D).global_transform
		q.collision_mask = 1
		q.exclude = ex
		for h in w.get_world_3d().direct_space_state.intersect_shape(q, 4):
			var co = h.get("collider")
			if co is Node and not (co as Node).is_ancestor_of(car) and not car.is_ancestor_of(co) and co != w.player:
				out.append(String((co as Node).name))
	return out


## Through the menu, the way a player does it - with an old save on disk (Chapter 8, driving) and saving left OFF
## (as an interrupted trailer run can leave it): the chapter picked must start, never the old save.
func _menu_path() -> void:
	CS.prepare(game, 8)
	game.player_state = {"in_vehicle": true, "pos": [-60.0, 0.3, 40.0], "yaw": 0.0, "health": 100.0}
	game.world_state.erase("chapter_start")
	game.save_game()
	game.no_save = true
	change_scene_to_file("res://game/scenes/MainMenu.tscn")
	await frames(10)
	(current_scene.find_child("ChaptersButton", true, false) as Button).pressed.emit()
	await frames(1)
	(current_scene.find_child("Chapter12", true, false) as Button).pressed.emit()
	await frames(1)
	current_scene.get("chapter_confirm").confirmed.emit()
	await frames(360)
	w = current_scene
	ok("menu_starts_picked_chapter", w.name == "World" and game.chapter_number() == 12 and not w.in_car,
		"chapter %d in_car %s" % [game.chapter_number(), w.get("in_car")])
	ok("menu_saving_back_on", not game.no_save)
	w.queue_free()
	await frames(5)
