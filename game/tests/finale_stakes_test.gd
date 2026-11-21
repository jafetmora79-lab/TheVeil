extends SceneTree
## The finale's stakes: a player who stands still out on the road is warned, then hunted by the Colossus, then taken; moving releases it. Below, standing still
## in the falling-stone horror brings the stone down on the player.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/finale_stakes_test.gd
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c: fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(300.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)"); quit(1))
func _run() -> void:
	var game = root.get_node("Game")
	var DEV = load("res://game/chapters/setups/dev_chapter15.gd")
	DEV.prepare(game)
	var world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	for i in 90: await process_frame
	var c5 = world.phase4.chapter5; var c10 = c5.chapter6.chapter7.chapter8.chapter9.chapter10
	var c15 = c10.chapter11.chapter12.chapter13.chapter14.chapter15
	ok("c15_exists", c15 != null)
	var player = world.player
	player.set_survival(true)
	player.controls_enabled = true
	game.flags["ch15_set_out"] = true
	game.flags.erase("ch15_in_passage")
	c15._busy.clear()
	# standing still outdoors
	player.global_position = Vector3(-90.0, 0.2, 0.0)
	c15._stall_pos = player.global_position
	for i in 40: c15._stall_tick(0.5)            # 20 s
	ok("stall_warns", c15._stall_stage >= 1 and int(c15.report.get("stall_warnings", 0)) >= 1, "stage %d" % c15._stall_stage)
	for i in 30: c15._stall_tick(0.5)            # 15 s more
	ok("colossus_comes", c15.colossus != null and is_instance_valid(c15.colossus) and c15._stall_stage >= 2, "stage %d" % c15._stall_stage)
	# the player moves: it is released
	player.global_position += Vector3(8.0, 0, 0)
	c15._stall_tick(0.1)
	ok("moving_releases", c15._stall_stage == 0 and not c15._busy.get("stalk", false))
	# standing still all the way: taken
	c15._stall_pos = player.global_position
	for i in 200: c15._stall_tick(0.5)
	ok("idle_is_fatal", int(c15.report.get("stall_deaths", 0)) >= 1 and player.health <= 0.0, "health %.0f deaths %d" % [player.health, int(c15.report.get("stall_deaths", 0))])
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(fails)
