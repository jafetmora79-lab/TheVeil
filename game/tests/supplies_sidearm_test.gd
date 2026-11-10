extends SceneTree
## THE VEIL - supply runs that never dead-end, and the handgun (headless):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/supplies_sidearm_test.gd
## From the Chapter 8 developer entry (the supermarket is the shelter, the supply rule is on). Checks: the handgun in
## the manager's office, six rounds; a short night shows the supplies (or the doors) lit and offers "sleep anyway";
## the supply finds restock on a new day; firing drives off a roaming Hound and spends a round; an empty gun clicks;
## ammo boxes add six; no firing during a choice.

const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0
var world: Node
var game: Node
var ex: Node
var sa: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(600.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	game.world_state["shelter_stock"] = {"food": 0, "water": 0, "medical": 0, "batteries": 0}
	game.world_state["supply_grace"] = true            # (the two-night starting stores are tested on their own)
	game.save_game()
	game.load_game()
	world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	await frames(90)
	ex = world.expedition
	sa = world.sidearm
	var p4 = world.phase4

	# ---- the handgun in the office
	# (no longer on the office floor: Sarah hands it over; the practice is skipped here)
	ok("gun_in_office", sa.pickup == null and not sa.has_gun() and sa.handover_pending(), sa.presenter())
	sa.handover(p4.choice)
	for i in 60 * 30:
		if p4.choice.is_open():
			break
		await process_frame
	p4.choice.pick(1)
	await frames(5)
	ok("gun_taken", sa.has_gun() and sa.ammo() == 6, "ammo %d" % sa.ammo())

	# ---- a short night: guidance and "sleep anyway"
	for id in game.inventory.duplicate():
		if game.shelter_resource(id) in ["food", "water"]:
			game.inventory.erase(id)
	var why: String = ex.sleep_gate()
	ok("short_night_explained", why != "" and "Plan a supply run" in why and world.get_node_or_null("Beacon_supplies_hint") != null, why)
	game.add_item("canned_food")
	why = ex.sleep_gate()
	ok("carried_points_to_supplies", "SHELTER SUPPLIES" in why, why)
	var rest: VeilRestPoint = p4.rest
	rest.can_rest = Callable()                         # (the chapter's own "not tired yet" rule aside)
	var slept := [false]
	rest.slept.connect(func(_id): slept[0] = true)
	rest.request()
	await frames(5)
	ok("choice_offered", p4.choice.is_open() and "NOT ENOUGH" in p4.choice._title.text)
	ok("no_firing_in_choice", not sa.can_fire())
	p4.choice.pick(0)
	await frames(10)
	ok("not_yet_keeps_awake", not slept[0])
	rest.request()
	await frames(5)
	p4.choice.pick(1)
	ok("sleep_anyway", await _wait(func(): return slept[0], 300) and rest.hungry_nights == 1)
	await frames(30)
	world.hud.fade_to(0.0, 0.01)
	world.player.controls_enabled = true

	# ---- the supply finds restock on a new day
	var n0: int = ex._cache_nodes.size()
	var first: Node3D = ex._cache_nodes[0]
	(first.get_node("Interact") as Interactable).interact(world.player)
	await frames(3)
	var h: Dictionary = game.world_state.get("shelter_nights", {})
	h["test_new_day"] = {}
	game.world_state["shelter_nights"] = h
	await frames(10)
	var n1: int = ex._cache_nodes.size()
	ok("finds_restock_daily", n1 >= 6 and n1 <= 16 and ex._cache_nodes.all(func(n): return is_instance_valid(n) and n.visible), "%d finds (about half restock each day)" % n1)

	# ---- firing: a roaming Hound is driven off
	ex.start("scavenge", false)
	var m: Node3D = world.market
	world.player.global_position = m.global_transform * Vector3(0.3, 0.3, -8.0)
	await frames(10)
	ok("hound_spawned", ex._spawn_hound(2) or ex.creatures.size() > 0)
	var hound: Node3D = ex.creatures[-1]["node"]
	var cam: Camera3D = world.player.camera
	var fwd := -cam.global_transform.basis.z * Vector3(1, 0, 1)
	hound.global_position = world.player.global_position + fwd.normalized() * 14.0
	hound.global_position.y = world.player.global_position.y - 0.9
	await frames(2)
	var v: Vector3 = (hound.global_position + Vector3(0, 0.6, 0)) - cam.global_position
	world.player.set_yaw_pitch(atan2(-v.x, -v.z), asin(clampf(v.normalized().y, -1.0, 1.0)))
	await frames(2)
	sa._cd = 0.0
	sa.fire()
	ok("hit_drives_off", sa.report["hits"] == 1 and sa.report["driven_off"] == 1 and ex.creatures[-1]["ai"].state == "RETURN" and sa.ammo() == 5,
		str(sa.report))
	# ---- empty, then an ammo box
	for i in 5:
		sa._cd = 0.0
		sa.fire()
	sa._cd = 0.0
	sa.fire()
	ok("empty_clicks", sa.ammo() == 0 and sa.report["dry"] == 1)
	game.add_item("handgun_ammo")
	await frames(3)
	ok("ammo_box_adds_six", sa.ammo() == 6 and not game.has_item("handgun_ammo"))
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)


func _wait(cond: Callable, n: int) -> bool:
	for i in n:
		if cond.call():
			return true
		await process_frame
	return cond.call()
