extends SceneTree
## THE VEIL - before the Veil drops, nothing leaves a store unpaid: walking out of the supermarket / game shop with
## something off its shelves, the cashier / Eddie calls the player back inside; once paid (or once the Veil is down)
## the way out is open. Headless.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/pay_first_test.gd

var fails := 0
var w: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


## Walk the player straight out through a store's door (inside marker -> 3 m past the outside one).
func _walk_out(st: Node3D) -> bool:
	var i: Vector3 = (st.get_node("Doorways/Entrance_Inside") as Node3D).global_position
	var o: Vector3 = (st.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var ax := ((o - i) * Vector3(1, 0, 1)).normalized()
	var p: Node3D = w.player
	p.global_position = Vector3(i.x, p.global_position.y, i.z)
	await frames(3)
	var steps := 40
	var dest := o + ax * 3.0
	for k in steps:
		if not p.get("controls_enabled"):
			break
		var q := i.lerp(dest, float(k + 1) / steps)
		p.global_position = Vector3(q.x, p.global_position.y, q.z)
		await frames(1)
	await frames(40)
	var rel := (p.global_position - i) * Vector3(1, 0, 1)
	return rel.dot(ax) / ((o - i) * Vector3(1, 0, 1)).length() > 1.2      # true: made it outside


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	game.new_game()
	for f in ["intro_seen", "has_keys", "fridge_checked", "left_house", "entered_car", "arrival_shot", "parked"]:
		game.flags[f] = true
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(30)
	w.player.set("controls_enabled", true)
	# nothing taken: free to go
	ok("empty_handed_walks_out", await _walk_out(w.market))
	# a cola off the shelf: called back
	w.market_merch.taken.emit("cola", "cola_bottle")
	game.add_item("cola_bottle")
	ok("unpaid_tracked", w.unpaid("market") == ["cola_bottle"], str(w.unpaid("market")))
	var stopped0: int = w.pay_report["stopped"]
	ok("market_stops_unpaid", not await _walk_out(w.market) and int(w.pay_report["stopped"]) > stopped0)
	ok("controls_come_back", w.player.get("controls_enabled"))
	# paid at the till: free to go
	w._checkout(w.player)
	await frames(5)
	ok("till_rings_it_up", w.unpaid("market").is_empty() and game.has_item("cola_bottle"))
	w._pay_cool = 0.0
	ok("paid_walks_out", await _walk_out(w.market))
	# the game shop: the game off the rack, Eddie calls you back; bought: free to go
	w.shop_merch.taken.emit("horror_game", "horror_game")
	game.add_item("horror_game")
	w._pay_cool = 0.0
	ok("shop_stops_unpaid", not await _walk_out(w.game_shop) and String(w.pay_report.get("last", "")) == "shop")
	w._paid("shop")
	game.set_flag("game_bought")
	w._pay_cool = 0.0
	ok("bought_walks_out", await _walk_out(w.game_shop))
	# after the Veil: nobody minds the till
	w.market_merch.taken.emit("cola", "chocolate_bar")
	game.add_item("chocolate_bar")
	game.flags["p3_mist"] = true
	w._pay_cool = 0.0
	ok("after_veil_no_paying", w.unpaid("market").is_empty())
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
