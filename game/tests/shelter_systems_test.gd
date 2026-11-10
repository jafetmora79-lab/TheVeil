extends SceneTree
## Run with --headless --fixed-fps 60 --script res://game/tests/shelter_systems_test.gd.
const DEV5 := preload("res://game/chapters/setups/dev_chapter5.gd")
const DEV6 := preload("res://game/chapters/setups/dev_chapter6.gd")
const DEV7 := preload("res://game/chapters/setups/dev_chapter7.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(label: String, result: bool) -> void:
	print("TEST ", label, " ", "PASS" if result else "FAIL")
	if not result:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func check_roster(world: Node, chapter: int, names: Array) -> void:
	for speaker in names:
		var actor := (world.animators[speaker] as NpcAnimator).root as VeilSurvivorBody
		var inside: Vector3 = world.market.to_local(actor.global_position)
		print("POSITION ", speaker, " ", inside)
		check("chapter_%d_%s_clear" % [chapter, speaker], actor.visible and actor.is_clear(actor.global_position)
			and actor.get_parent() == world.market and inside.z >= 3.2)

func run() -> void:
	var game := root.get_node("Game")
	var packed := load("res://game/scenes/World.tscn") as PackedScene
	for chapter in [4, 5, 6, 7]:
		match chapter:
			4:
				DEV5.prepare(game)
				game.flags.erase("p4_slept")
			5: DEV5.prepare(game)
			6: DEV6.prepare(game)
			7: DEV7.prepare(game)
		game.world_state["supply_grace"] = true          # (exact stock arithmetic: no starting stores here)
		var world := packed.instantiate()
		root.add_child(world)
		await frames(8)
		check_roster(world, chapter, ["Marcus", "Eddie"] if chapter < 7 else ["Marcus", "Eddie", "Ruth", "Sarah"])
		if chapter == 4:
			var market := world.market as Node3D
			var marcus := world.marcus as VeilSurvivorBody
			var blocked := market.to_global(Vector3(6.0, 0.04, 5.0))
			check("actual_counter_blocks_capsule", not marcus.is_clear(blocked))
			var safe := marcus.nearest_safe(blocked)
			check("counter_destination_recovers_to_floor", safe.is_finite() and marcus.is_clear(safe)
				and absf(market.to_local(safe).y - 0.04) < 0.12)
			var front := market.to_global(Vector3(5.0, 0.04, 6.5))
			var back := market.to_global(Vector3(5.0, 0.04, 3.85))
			var hit := marcus.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
				front + Vector3.UP * 0.65, back + Vector3.UP * 0.65, 1))
			check("counter_furnishing_ray", not hit.is_empty() and String(hit.collider.get_path()).contains("Furnishing"))
			check("counter_impassable", marcus.test_move(Transform3D(Basis(), front), back - front))
			check("another_survivor_blocks_capsule", not marcus.is_clear(world.eddie.global_position))
			var path: Array = world.npc_route(market, market.to_local(front), market.to_local(back), marcus)
			check("counter_route_detours", path.size() > 1)
			marcus.place_at(front)
			world.npc_walk("Marcus", market.to_local(back), 2.5)
			await frames(240)
			check("counter_route_walks_around", marcus.global_position.distance_to(back) < 0.3 and marcus.is_clear(marcus.global_position))
		if chapter == 7:
			await check_supplies(world, game)
			world.player.health = 73.0
			world.save()
			var records: Dictionary = game.world_state["shelter_npc_positions"]
			var blocked: Vector3 = world.market.to_global(Vector3(6.0, 0.04, 5.0))
			records["Marcus"]["feet"] = [blocked.x, blocked.y, blocked.z]
			game.save_game()
			world.free()
			await frames(2)
			game.load_game()
			game.load_requested = true
			world = packed.instantiate()
			root.add_child(world)
			await frames(8)
			check_roster(world, 7, ["Marcus", "Eddie", "Ruth", "Sarah"])
			check("bad_saved_counter_position_rejected", world.marcus.global_position.distance_to(blocked) > 0.65)
			check("health_and_quickslot_saved", world.player.health == 73.0 and game.world_state["quickslots"][0] == "painkillers")
			check("supplies_saved", int(game.shelter_stock()["medical"]) == 1 and int(game.shelter_stock()["batteries"]) == 1)
			check("reloaded_night_is_idempotent", world.phase4.record_night("test_night").is_empty())
			var c7 = world.phase4.chapter5.chapter6.chapter7
			world.marcus.place_at(world.market.to_global(Vector3(2.1, 0.04, 6.0)))
			var arrival: Vector3 = world.marcus.global_position
			c7._returned()
			check("mission_return_does_not_teleport", world.marcus.global_position.is_equal_approx(arrival))
			await frames(300)
			check("mission_return_valid_home", world.marcus.global_position.distance_to(world.market.to_global(c7.MARCUS_NOTES)) < 0.3
				and world.marcus.is_clear(world.marcus.global_position))
		world.free()
		await frames(2)
	print("RESULT ", failures, " failures")
	quit(1 if failures else 0)


func check_supplies(world: Node, game: Node) -> void:
	var inv = world.hud.inv_panel
	var quick = world.hud.quick
	while game.has_item("painkillers"):
		game.remove_item("painkillers")
	game.add_item("painkillers")
	game.add_item("painkillers")
	var count: int = game.inventory.count("painkillers")
	world.player.health = 40.0
	var actions: Array = inv.actions_for("painkillers")
	check("inventory_offers_healing", not actions.is_empty())
	if not actions.is_empty():
		actions[0][1].call()
	check("inventory_heals_and_consumes_one", world.player.health == 65.0 and game.inventory.count("painkillers") == count - 1)
	quick.assign(0, "painkillers")
	world.player.health = 90.0
	check("hotbar_heals_and_caps", quick.use(0) and world.player.health == 100.0)
	game.add_item("painkillers")
	check("full_health_preserves_item", not quick.use(0) and game.inventory.count("painkillers") == 1)
	world.phase4._open_supplies()
	await frames(2)
	var choices = world.phase4.choice
	check("storage_panel_shows_actual_totals", choices.is_open() and "Food 0" in choices._title.text)
	var choices_buttons: Array = choices._box.get_children()
	for i in range(1, choices_buttons.size()):
		if "Deposit one Painkillers" in choices_buttons[i].text:
			choices.pick(i - 1)
			break
	await frames(2)
	choices.pick(choices._box.get_child_count() - 2)
	check("medical_deposit_from_panel", not game.has_item("painkillers") and game.shelter_stock().medical == 1)
	check("duplicate_deposit_rejected", not world.deposit_shelter_item("painkillers"))
	check("battery_deposit", world.deposit_shelter_item("batteries"))
	check("quest_item_protected", not world.deposit_shelter_item("groceries") and game.has_item("groceries"))
	game.add_item("canned_food")
	game.add_item("water_bottle")
	var food_before: int = game.inventory.count("canned_food")
	check("food_and_water_deposit", world.deposit_shelter_item("canned_food") and world.deposit_shelter_item("water_bottle")
		and game.inventory.count("canned_food") == food_before - 1)
	var report: Dictionary = world.phase4.record_night("test_night")
	check("night_counts_current_roster", report.roster == world.shelter_roster() and report.roster.size() >= 4
		and report.food_needed == report.roster.size() + int(report.get("extra", 0)))
	check("night_deducts_actual_stock_only", report.food_used == 1 and report.water_used == 1 and report.food_left == 0 and report.water_left == 0)
	check("night_does_not_consume_medical_or_batteries", game.shelter_stock().medical == 1 and game.shelter_stock().batteries == 1)
	check("night_cannot_double_charge", world.phase4.record_night("test_night").is_empty())
