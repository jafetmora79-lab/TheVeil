extends SceneTree
## THE VEIL - (1) no floating [E] markers in the game shop, (2) the gas station scene (Joan) starts once the player
## is there - an idle struggle controller no longer holds every town scene back - and only the quest's gas can is
## out before the car runs, (3) the shelter's ward: trip creatures stop hunting by the shelter and never come near
## it, (4) the danger rises every five minutes. Headless, short.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/four_fixes_test.gd

const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(200.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _cans(w: Node) -> int:
	var n := 0
	for c in w.find_children("*", "Node3D", true, false):
		if String((c as Node).scene_file_path).get_file() == "GasCanister.tscn" and (c as Node3D).is_visible_in_tree():
			n += 1
	return n


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(200)
	var ex = w.expedition
	# ---- 1. the game shop: the prompt alone, no floating [E]
	ok("no_shop_markers", w.get_node_or_null("StoreMarkers") == null)
	# ---- 2. gas: one can before the car runs; the gas station scene starts
	ok("one_can_before_repair", _cans(w) == 1, "%d" % _cans(w))
	var lt = w.living
	if w.get_node_or_null("Struggle") == null:
		var s := Node.new()
		s.name = "Struggle"
		s.set_script(load("res://game/encounters/struggle.gd"))
		w.add_child(s)
	ok("idle_struggle_not_busy", not lt._story_busy())
	w.player.global_position = Vector3(145.0, 0.4, -30.0)
	var t := 0
	while t < 60 * 8 and not (lt.report["events"] as Array).has("joan"):
		await physics_frame
		t += 1
	ok("gas_station_scene_starts", (lt.report["events"] as Array).has("joan"), str(lt.report["events"]))
	game.set_flag("vehicle_repaired")
	ex._spawn_caches()
	await frames(5)
	ok("refuel_cans_after_repair", _cans(w) >= 2 and _cans(w) <= 3, "%d" % _cans(w))
	# ---- 3. the shelter's ward
	var door: Vector3 = ex.shelter_spot()
	ok("shelter_known", door.is_finite(), str(door))
	ok("ward_radius", ex.shelter_safe(door + Vector3(10, 0, -10)) and not ex.shelter_safe(door + Vector3(0, 0, -60)))
	var sc := GDScript.new()
	sc.source_code = "extends Node3D\nvar state := \"CHASE\"\nvar home := Vector3.ZERO\nvar leash := 30.0\n"
	sc.reload()
	var near_c := Node3D.new()
	near_c.set_script(sc)
	w.add_child(near_c)
	near_c.global_position = door + Vector3(4.0, 0.0, -12.0)
	var far_c := Node3D.new()
	far_c.set_script(sc)
	w.add_child(far_c)
	far_c.global_position = door + Vector3(0.0, 0.0, -110.0)
	ex.creatures.append({"ai": near_c, "node": near_c, "role": "hunter", "kind": "Hound"})
	ex.creatures.append({"ai": far_c, "node": far_c, "role": "roamer", "kind": "Hound"})
	w.player.global_position = door + Vector3(0.0, 0.2, -100.0)      # out in town: the far one may hunt
	ex._shelter_ward()
	ok("near_shelter_turned_away", String(ex.creatures[-2]["role"]) == "leaving" and near_c.state == "RETURN"
		and Vector2(near_c.home.x - door.x, near_c.home.z - door.z).length() > ex.SAFE_R + 30.0)
	ok("far_hunt_untouched", String(ex.creatures[-1]["role"]) == "roamer" and far_c.state == "CHASE")
	w.player.global_position = door + Vector3(0.0, 0.2, -6.0)          # back by the doors
	ok("no_chase_by_shelter", not ex._may_chase(far_c))
	ex._shelter_ward()
	ok("hunt_ends_by_shelter", String(ex.creatures[-1]["role"]) == "leaving")
	ex.creatures.clear()
	# ---- 4. danger every five minutes
	var th: Array = ex.cfg.get("danger_thresholds_s", [])
	ok("danger_every_5_min", th.map(func(x): return int(x)) == [300, 600, 900, 1200], str(th))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
