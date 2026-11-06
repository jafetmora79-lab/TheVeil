extends SceneTree
## THE VEIL - the supermarket's two-night starting stores and the companions at its glass doors (headless).
const DEV := preload("res://game/tools/dev_chapter7.gd")
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	game.world_state["shelter_stock"] = {"food": 1, "water": 0, "medical": 0, "batteries": 0}
	game.world_state.erase("supply_grace")
	game.world_state["shelter_nights"] = {}
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 90:
		await process_frame
	var n: int = w.shelter_roster().size() + 1
	var need: Dictionary = w.expedition.supply_need()
	ok("two_nights_stocked", need["food"] == 2 * n and need["water"] == 2 * n and need["need"] == n, str(need))
	ok("sleep_allowed_with_stores", w.expedition.sleep_gate() == "")
	game.world_state["shelter_stock"] = {"food": 0, "water": 0, "medical": 0, "batteries": 0}
	ok("grace_once", w.expedition.supply_need()["food"] == 0)
	# a companion at the shut glass doors pulls them open
	var c5 = w.phase4.chapter5
	if c5._doors_open:
		c5._set_doors(false)
	var o: Vector3 = (w.market.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	w.companion_at_market_doors(o + Vector3(0.3, 0, 0.3))
	ok("companion_opens_doors", c5._doors_open or w._auto_open)
	print("RESULT %s" % ("PASS" if fails == 0 else "%d failures" % fails))
	quit(0 if fails == 0 else 1)
