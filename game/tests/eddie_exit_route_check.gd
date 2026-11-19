extends Node
## Chapter 5 regression: the player leaves the store the moment the doors open, while Eddie is still at the vestibule wall finishing his line.
## When he starts following he must go out through the doors (not the straight line through the walls to the player, which left him stuck inside).
##   godot --headless --path . --fixed-fps 60 res://game/tests/eddie_exit_route_check.tscn
## (Your save file is overwritten by the chapter 5 dev setup, like the chapter tests.)
const DEV := preload("res://game/chapters/setups/dev_chapter5.gd")
var world: Node
var c5: Node
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	var game := get_node("/root/Game")
	get_node("/root/Dialogue").auto_confirm = true
	DEV.prepare(game)
	world = load("res://game/scenes/World.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


## one experiment: Eddie at the vestibule wall, the player already in the street, Eddie starts following (with or without the exit route)
func _try(with_route: bool) -> Dictionary:
	var mk: Node3D = world.market
	var eddie: Node3D = c5.eddie
	if eddie.get_parent() != world:
		c5._reparent(eddie, world)
	var follow = c5.eddie_follow
	follow.stop()
	world.player.controls_enabled = false
	var street := mk.to_global(Vector3(0.0, 0.3, -9.0))
	world._put_player(street, mk.to_global(Vector3(0.0, 1.5, -20.0)))
	eddie.global_position = mk.to_global(Vector3(1.5, 0.04, 4.3))
	eddie.global_position.y = mk.to_global(Vector3(1.5, 0.04, 4.3)).y
	await frames(10)
	c5._set_doors(true)
	if with_route:
		follow.start(c5._eddie_exit_route())
	else:
		follow.start()
	var t := 0.0
	var out_at := -1.0
	while t < 40.0:
		await frames(30)
		t += 0.5
		var el: Vector3 = mk.to_local(eddie.global_position)
		if el.z < c5.OUTSIDE_Z and out_at < 0.0:
			out_at = t
		if out_at > 0.0 and t > out_at + 3.0:
			break
	var el2: Vector3 = mk.to_local(eddie.global_position)
	follow.stop()
	return {"outside": el2.z < c5.OUTSIDE_Z, "out_at": out_at, "end": el2}


func _run() -> void:
	for i in 80:
		await get_tree().physics_frame
	c5 = world.phase4.chapter5 if world.phase4 else null
	ok("chapter_5_loaded", c5 != null)
	if c5 == null:
		get_tree().quit(1)
		return
	var old: Dictionary = await _try(false)
	print("INFO without the route: ", old)
	var fixed: Dictionary = await _try(true)
	print("INFO with the route:    ", fixed)
	ok("with_the_route_eddie_gets_outside", fixed["outside"], str(fixed["end"]))
	ok("with_the_route_he_is_out_within_30s", fixed["out_at"] > 0.0 and fixed["out_at"] < 30.0, str(fixed["out_at"]))
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	get_tree().quit(1 if fails else 0)
