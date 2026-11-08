extends SceneTree
## THE VEIL - click-to-win meters (headless, short): the car repair effort (battery, fuel cap, fuse) and a real Hound
## struggle. ~2.5 clicks a second must win; no clicks must lose.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/click_struggle_test.gd

const DEV := preload("res://game/tools/dev_chapter7.gd")
var fails := 0
var w: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(300.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _click() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	Input.parse_input_event(e)


## Clicks every `gap` frames while `busy` holds (24 frames = 2.5 a second).
func _clicker(busy: Callable, gap: int) -> void:
	var n := 0
	while busy.call() and n < 600:
		_click()
		await frames(gap)
		n += 1


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(120)
	var p = w.player
	p.controls_enabled = true
	# ---- the car repair effort (the battery pull and the others share it)
	var q = w.expedition.quest
	var res := [null]
	var run := func(): res[0] = await q.effort("CLICK REPEATEDLY — PULL BATTERY")
	run.call()
	await frames(2)
	await _clicker(func(): return q.pulling, 24)
	await frames(2)
	ok("battery_pull_wins", res[0] == true, "pull %.2f" % q.pull)
	res[0] = null
	run.call()
	await frames(60 * 10)
	ok("battery_no_clicks_loses", res[0] == false)
	# ---- a real monster struggle (a Hound with its AI, started the way its bite starts it)
	var h := (load(w.expedition.HOUND_PATH) as PackedScene).instantiate() as CharacterBody3D
	w.add_child(h)
	h.global_position = p.global_position + (-p.global_basis.z) * 1.4
	var ai: Node = w.expedition.HOUND_AI.new()
	h.add_child(ai)
	ai.setup(h, p, [h.global_position])
	w.expedition._hook_struggle(ai, "hound")
	var sg = w.get_node("Struggle")
	sg._cool = 0.0
	p.survival_active = true
	p.health = 100.0
	var started: bool = false
	for i in 40:
		if sg.try_start(ai):
			started = true
			break
		sg._cool = 0.0
		await frames(1)
	ok("hound_struggle_starts", started and sg.active)
	await _clicker(func(): return sg.active, 24)
	await frames(5)
	ok("hound_struggle_wins_at_2_5_per_s", not sg.active and sg.last_won, "won %s" % str(sg.last_won))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
