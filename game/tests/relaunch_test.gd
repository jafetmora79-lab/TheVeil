extends SceneTree
## THE VEIL - save, quit the program, start it again, Continue: run three times in a row (separate processes).
##   godot ... -s res://game/tests/relaunch_test.gd -- setup   : a Chapter 7 game with known state, saved, quit
##   godot ... -s res://game/tests/relaunch_test.gd -- check   : Continue (load + world), compare, save again, quit
## The expected state is written to user://relaunch_expect.json by "setup".
const DEV := preload("res://game/tools/dev_chapter7.gd")
const EXPECT := "user://relaunch_expect.json"

var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _snapshot(game: Node, w: Node) -> Dictionary:
	var inv: Dictionary = {}
	for id in game.inventory:
		inv[id] = int(inv.get(id, 0)) + 1
	var fl = w.get_tree().get_first_node_in_group("veil_flashlight")
	return {"inv": inv, "packs": game.world_state.get("companion_packs", {}), "stock": game.shelter_stock(),
		"quick": game.world_state.get("quickslots", []), "flags": game.flags.size(),
		"spares": int(fl.spares) if fl else -1, "fuel": snappedf(float(w.sedan.fuel), 0.001),
		"cond": snappedf(float(w.sedan.condition), 0.001), "taken": game.world_state.keys().filter(func(k): return String(k).begins_with("scav/")).size(),
		"quest": _quest(game, w)}


## The car quest as the world shows it (not just the saved dictionary): steps, props, the guard's place.
func _quest(game: Node, w: Node) -> Dictionary:
	var q = w.expedition.quest
	var bat: Node3D = q.sites["car_battery"]["battery"]
	var door: Node3D = q.sites["car_fuse"]["door"]
	return {"gas": q.acquired("fuel_can"), "can_visible": (q.sites["fuel_can"]["root"] as Node3D).visible,
		"bat": q.part_state("car_battery"), "clamp": snappedf((bat.get_node("ClampNeg") as Node3D).position.y, 0.001),
		"fuse": q.part_state("car_fuse"), "door": snappedf(door.rotation.y, 0.01),
		"alarm": int(q.q().get("alarm_uses", 0)), "parts": w.expedition.st().get("car_parts", {}),
		"live": q.steps.keys().filter(func(k): return q.steps[k].collision_layer == 8)}


func _run() -> void:
	var game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	var mode := "check" if OS.get_cmdline_user_args().has("check") else "setup"
	if mode == "setup":
		DEV.prepare(game)
	else:
		ok("continue_loads", game.load_game())
		game.load_requested = true
	change_scene_to_file("res://game/scenes/World.tscn")
	await _frames(240)
	var w = current_scene
	if mode == "setup":
		for i in 3:
			game.add_item("water_bottle")
			game.add_item("canned_food")
		game.add_item("painkillers")
		w.survivors._pack_put("Eddie", "water_bottle")
		w.survivors._pack_put("Ruth", "canned_food")
		var st: Dictionary = game.shelter_stock()
		st["food"] = 5
		st["water"] = 4
		game.world_state["shelter_stock"] = st
		VeilQuickSlots.assign(0, "painkillers")
		# the car quest part way: the canister in hand, the battery's negative cable off, the sedan's door and fuse
		# panel open, the alarm used once
		var q = w.expedition.quest
		q._take_gas()
		await _frames(120)
		q._battery_inspect()
		await _frames(200)
		q._battery_cable("neg")
		await _frames(120)
		q._fuse_inspect()
		await _frames(160)
		q._fuse_door()
		await _frames(90)
		q._fuse_panel()
		await _frames(150)
		q.q()["alarm_uses"] = 1
		await _frames(3)
		w.sedan.fuel = 0.42
		w.sedan.condition = 0.63
		await _frames(30)
		w.save()
		var snap := _snapshot(game, w)
		var f := FileAccess.open(EXPECT, FileAccess.WRITE)
		f.store_string(JSON.stringify(snap))
		print("SETUP saved %s" % JSON.stringify(snap))
	else:
		var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
		var have := _snapshot(game, w)
		for k in want:
			ok("same_" + k, JSON.stringify(want[k]) == JSON.stringify(have[k]), "want %s have %s" % [JSON.stringify(want[k]), JSON.stringify(have[k])])
		w.save()                                          # the next run checks the re-saved game against the same
	print("RELAUNCH %s fails=%d" % [mode, fails])
	quit(1 if fails > 0 else 0)
