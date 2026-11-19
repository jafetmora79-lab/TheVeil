extends SceneTree
## THE VEIL - a chapter start carries what the story would have handed over by then (headless, no world needed):
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/chapter_select_items_test.gd
const CS := preload("res://game/chapters/chapter_select.gd")
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	for n in range(2, 17):
		ok("prepare_%d" % n, CS.prepare(game, n))
		var sa: Dictionary = game.world_state.get("sidearm", {})
		if n <= 8:
			ok("ch%d_no_gun_yet" % n, not game.has_item("handgun"))
		else:
			ok("ch%d_has_handgun_with_rounds" % n, game.has_item("handgun") and int(sa.get("mag", 0)) == 6 and bool(sa.get("given", false)), str(sa))
		ok("ch%d_map" % n, game.has_flag("map_acquired") == (n >= 7))
		ok("ch%d_car_keys" % n, game.has_item("car_keys"))
		if n >= 6:
			ok("ch%d_flashlight" % n, game.has_item("flashlight"))
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	quit(1 if fails else 0)
