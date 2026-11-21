extends SceneTree
## Chapter 7: the gun handover only happens with the presenter in plain view (they walk over if they are elsewhere in the shelter), and the front doors that
## something left standing open are shut again once nobody is at them.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/handover_doors_test.gd
const DEV := preload("res://game/chapters/setups/dev_chapter7.gd")
var fails := 0


class FakeChoice:
	extends Node
	func ask(_t: String, _o: Array, _p = null, _r = null) -> int:
		return 1


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(170.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(240)
	var sa = w.sidearm
	var who: String = sa.presenter()
	ok("presenter_exists", who != "", who)
	if who == "":
		print("RESULT FAIL fails=%d" % (fails + 1))
		quit(1)
		return
	var npc: Node3D = w.animators[who].root
	# the presenter is far off in the shelter, the player at the front doors
	var m: Node3D = w.market
	w.player.global_position = m.to_global(Vector3(0.0, 0.3, 3.0))
	w.place_survivor(npc, Vector3(-18.0, 0.04, 14.0))
	await frames(30)
	ok("presenter_not_at_hand", not sa._in_reach(npc))
	game.flags.erase("ch9_supermarket_lost")
	sa.st()["given"] = false
	game.inventory.erase("handgun")
	var done := [false]
	var run := func():
		await sa.handover(FakeChoice.new())
		done[0] = true
	run.call()
	var t := 0
	while not sa._in_reach(npc) and t < 60 * 16:
		await physics_frame
		t += 1
	ok("presenter_came_over", sa._in_reach(npc), "%.1f s" % (t / 60.0))
	t = 0
	while not done[0] and t < 60 * 60:
		await physics_frame
		t += 1
	ok("handover_ran_with_her_in_view", done[0] and (game.has_item("handgun") or bool(sa.st().get("given", false)) or sa.st().get("from", "") == who), str(sa.st()))
	# a door left open with nobody at it
	var c5 = w.phase4.chapter5
	w.player.global_position = m.to_global(Vector3(-6.0, 0.3, 12.0))
	c5._set_doors(true)
	w.expedition.story_departure = false
	await frames(60 * 9)
	ok("doors_shut_when_nobody_there", not c5._doors_open)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
