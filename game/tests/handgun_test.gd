extends SceneTree
## THE VEIL - the handgun's first-person view, magazine / reserve, reload and scarce rounds (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/handgun_test.gd
## From the Chapter 8 developer entry (the supermarket is the shelter, the supply rule is on).

const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0
var world: Node
var game: Node
var sa: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func key(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await frames(2)


func _initialize() -> void:
	_run.call_deferred()
	create_timer(600.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _load_world() -> void:
	world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(90)
	sa = world.sidearm
	world.player.controls_enabled = true
	world.hud.fade_to(0.0, 0.01)


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	await _load_world()
	var fl = root.get_tree().get_first_node_in_group("veil_flashlight")

	# ---- pickup, drawn into view
	# (Sarah hands it over now; the practice is skipped here - final_repairs_test covers it)
	ok("pickup_in_office", sa.pickup == null and sa.handover_pending(), sa.presenter())
	sa.handover(world.phase4.choice)
	for i in 60 * 30:
		if world.phase4.choice.is_open():
			break
		await process_frame
	world.phase4.choice.pick(1)
	await frames(30)
	ok("pickup_six_loaded", sa.has_gun() and sa.mag() == 6 and sa.reserve() == 0 and sa.drawn())
	ok("gun_in_view", sa.view_shown() and sa._equip >= 1.0 and sa._view.position.distance_to(sa.REST) < 0.05, str(sa._view.position if sa._view else null))
	# ---- holster / draw with H; F is the flashlight's while holstered
	await key(KEY_H)
	await frames(2)
	ok("holster_hides", not sa.drawn() and not sa.view_shown())
	var on0: bool = fl.on
	await key(KEY_F)
	ok("f_flashlight_when_holstered", fl.on != on0 and sa.report["shots"] == 0)
	await key(KEY_H)
	await frames(3)
	ok("draw_rises", sa.drawn() and sa.view_shown() and sa._equip < 1.0)
	await frames(30)
	var on1: bool = fl.on
	# ---- fire: kick, flash, one round
	await key(KEY_F)
	ok("fire_spends_one", sa.mag() == 5 and sa.report["shots"] == 1 and fl.on == on1)
	ok("fire_kick_and_flash", sa._kick > 0.5 and sa._flash.visible)
	await frames(30)
	ok("kick_settles", sa._kick == 0.0 and sa._view.position.distance_to(sa.REST) < 0.05)
	# ---- aim (right mouse)
	Input.parse_input_event(_mouse(MOUSE_BUTTON_RIGHT, true))
	await frames(25)
	ok("aim_raises_to_centre", sa._aim >= 1.0 and absf(sa._view.position.x) < 0.03)
	Input.parse_input_event(_mouse(MOUSE_BUTTON_RIGHT, false))
	await frames(25)
	# ---- reload: only from carried rounds, never duplicated
	await key(KEY_R)
	ok("no_reserve_no_reload", not sa.reloading() and sa.mag() == 5)
	game.add_item("handgun_rounds")
	await frames(3)
	ok("loose_rounds_two", sa.reserve() == 2 and not game.has_item("handgun_rounds"))
	await key(KEY_R)
	ok("reload_started", sa.reloading())
	await key(KEY_F)
	ok("no_fire_during_reload", sa.mag() == 5 and sa.report["shots"] == 1)
	await frames(int(sa.RELOAD_TIME * 60) + 10)
	ok("reload_moves_rounds", not sa.reloading() and sa.mag() == 6 and sa.reserve() == 1 and sa.ammo() == 7)
	await key(KEY_R)
	ok("full_mag_no_reload", not sa.reloading() and sa.ammo() == 7)
	# interrupted reload moves nothing
	sa.fire()
	await frames(20)
	await key(KEY_R)
	await frames(30)
	await key(KEY_H)
	await frames(5)
	ok("interrupted_reload_no_change", sa.mag() == 5 and sa.reserve() == 1 and not sa.reloading())
	await key(KEY_H)
	await frames(30)
	# ---- empty
	for i in 5:
		sa._cd = 0.0
		sa.fire()
	sa._cd = 0.0
	var shots: int = sa.report["shots"]
	sa.fire()
	ok("empty_cannot_fire", sa.mag() == 0 and sa.report["shots"] == shots and sa.report["dry"] == 1)
	# ---- locks: car and cinematic
	world.in_car = true
	await frames(2)
	sa._cd = 0.0
	ok("no_fire_in_car", not sa.can_fire() and not sa.view_shown())
	world.in_car = false
	var cine := Camera3D.new()
	world.add_child(cine)
	world._cine = cine
	await frames(2)
	ok("no_fire_in_cinematic", not sa.can_fire() and not sa.view_shown())
	world._cine = null
	cine.queue_free()
	await frames(2)
	# ---- scarce rounds: one-time finds, not restocked; food still restocks
	var ex = world.expedition
	var ammo_keys: Array = ex.its.keys().filter(func(k): return String(k).begins_with("exp/cache_ammo"))
	ok("ammo_finds_few", ammo_keys.size() == 3, str(ammo_keys))
	var total := 0
	for c in ex.cfg["caches"]:
		total += int(game.item_info(String(c["item"])).get("rounds", 0))
	ok("ammo_total_scarce", total <= 9, "%d rounds in the town" % total)
	var ak: String = ammo_keys[0]
	(ex.its[ak] as Interactable).interact(world.player)
	await frames(3)
	var food_key: String = ex.its.keys().filter(func(k): return String(k).begins_with("exp/cache_lot_food"))[0]
	(ex.its[food_key] as Interactable).interact(world.player)
	await frames(3)
	var r_before: int = sa.reserve()
	var h: Dictionary = game.world_state.get("shelter_nights", {})
	h["test_new_day"] = {}
	game.world_state["shelter_nights"] = h
	await frames(10)
	var new_food: Array = ex.its.keys().filter(func(k): return String(k).begins_with("exp/cache_lot_food_d"))
	ok("food_restocks", not new_food.is_empty() and is_instance_valid(ex.its[new_food[0]]) and not ex.its[new_food[0]].taken)
	ok("ammo_not_restocked", ex.its.keys().filter(func(k): return String(k).begins_with("exp/cache_ammo") and "_d" in String(k)).is_empty()
		and ex.its[ak].taken and sa.reserve() == r_before)
	# ---- save / load
	sa.st()["mag"] = 3
	var res0: int = sa.reserve()
	world.save()
	world.free()
	game.load_game()
	game.load_requested = true
	await _load_world()
	ok("save_load_ammo", sa.has_gun() and sa.mag() == 3 and sa.reserve() == res0 and sa.drawn(), "%d | %d" % [sa.mag(), sa.reserve()])
	ok("taken_ammo_stays_taken", world.expedition.its.has(ak) and world.expedition.its[ak].taken)
	# ---- an older save (one pool of rounds) converts without gaining any
	game.world_state["sidearm"] = {"ammo": 9, "given": true}
	ok("old_save_converts", sa.mag() == 6 and sa.reserve() == 3 and sa.ammo() == 9)
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)


func _mouse(b: MouseButton, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = down
	return e
