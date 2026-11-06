extends SceneTree
## THE VEIL - the explorable houses beyond the cottage: opened with the supply rule, supplies inside containers,
## refilled each new day (never ammo), nothing duplicated through save/load (headless).
const DEV := preload("res://game/tools/dev_chapter7.gd")
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


func boot() -> void:
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(90)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	game.world_state["shelter_nights"] = {}
	await boot()
	var hs: Dictionary = w.expedition.houses
	var open: Array = hs.keys().filter(func(k): return k != "_done")
	ok("houses_opened", open.size() == 3, str(open))
	var h = hs.get("HOUSE_15")
	ok("loot_inside", h != null and h.loot.size() == 3 and h.loot.values().all(func(it): return it.collision_layer == 0), str(h.loot.keys() if h else []))
	# take the food: open its cabinet, take it
	var food: Interactable = h.loot["canned_food_0"]
	var c: Interactable = h._loot_container["canned_food_0"]
	c.interact(w.player)
	await frames(40)
	food.interact(w.player)
	await frames(5)
	ok("taken", food.taken and game.has_item("canned_food"))
	# a new day: new supplies, the taken one stays taken; the rare round is not refilled
	var a34 = hs.get("EXT_HOUSE_34")
	var round_key: String = a34.loot["handgun_round_2"].state_key
	var nights: Dictionary = game.world_state["shelter_nights"]
	nights["test_day_1"] = {}
	await frames(5)
	ok("refilled", h.loot.size() == 3 and not h.loot["canned_food_0"].taken and h.loot["canned_food_0"].state_key.ends_with("_d1"))
	ok("ammo_not_refilled", a34.loot["handgun_round_2"].state_key == round_key)
	# save / load: the day-1 food is new, the day-0 one stays taken
	w.save()
	w.free()
	game.load_game()
	game.load_requested = true
	await boot()
	h = w.expedition.houses.get("HOUSE_15")
	ok("load_keeps_day", h != null and h.loot["canned_food_0"].state_key.ends_with("_d1") and not h.loot["canned_food_0"].taken
		and game.world_state.get("scav/HOUSE_15/loot_canned_food_0", {}).get("taken", false))
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
