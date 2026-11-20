extends SceneTree
## THE VEIL - the rescued Noah in displayed chapters 15 and 16 (story pass B5), headless:
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/noah_late_test.gd
## With the rescue done (flags set the way chapter12_noah.gd leaves them): in the last shelter Noah reads his watch log and names his evacuation partner; in the finale he
## is at the refuge and has his last lines in each ending. Without the rescue none of it appears.
const DEV14 := preload("res://game/chapters/setups/dev_chapter14.gd")
const DEV15 := preload("res://game/chapters/setups/dev_chapter15.gd")

var fails := 0
var world: Node
var game: Node
var ps: PackedScene
var said: Array = []
var c14: Node
var c15: Node


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func bind() -> void:
	var p4 = world.phase4
	var c5 = p4.chapter5
	var c6 = c5.chapter6
	var c7 = c6.chapter7
	var c8 = c7.chapter8
	var c9 = c8.chapter9
	var c10 = c9.chapter10
	var c11 = c10.chapter11
	var c12 = c11.chapter12
	var c13 = c12.chapter13
	c14 = c13.chapter14 if c13 else null
	c15 = c14.chapter15 if c14 else null


func start(prep: Callable, noah: bool) -> void:
	prep.call()
	if noah:
		for f in ["ch12_noah_found", "ch12_noah_home", "ch12_rescue_started", "ch12_ribbon_read", "ch12_house19_entered", "ch12_below_explained"]:
			game.flags[f] = true
		game.world_state["noah"] = {"status": "home", "role": "signaller", "companion": "Eddie"}
	world = ps.instantiate()
	root.add_child(world)
	await frames(90)
	bind()
	Engine.time_scale = 6.0
	for c in [c14, c15]:                                           # (let the chapter's own opening finish first: it speaks too)
		if c != null:
			await wait_until(func(): return not c._busy.get("opening", false) and world.player.controls_enabled, 60 * 40)
	Engine.time_scale = 1.0
	said.clear()


func _initialize() -> void:
	_run.call_deferred()
	create_timer(900.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	game = root.get_node("Game")
	var dlg = root.get_node("Dialogue")
	ps = load("res://game/scenes/World.tscn")
	dlg.line_started.connect(func(_s, t, _d): said.append(t))
	dlg.auto_confirm = true
	# ---- the last shelter (displayed 15), rescue done
	await start(func(): DEV14.prepare(game), true)
	ok("n14_noah_in_the_house", c14 != null and c14._noah_node() != null and c14._noah_node().visible)
	await c14._noah_meeting()
	ok("n14_log", said.has("Fog line, hour by hour. It doesn't come on Mondays.") and said.has("Then it's coming."), str(said))
	var partner := String(c14.st().get("noah_partner", ""))
	ok("n14_partner", partner in ["Ruth", "Marcus", "Sarah"], partner)
	ok("n14_partner_line", said.has("I know the route. I drew it.") or said.has("Dad. I know the route. I drew it."))
	world.free()
	said.clear()
	# ---- the finale (displayed 16), rescue done
	await start(func(): DEV15.prepare(game), true)
	ok("n15_noah_at_refuge", c15 != null and c15._noah_node() != null)
	await c15._noah_end("A")
	await c15._noah_end("B")
	await c15._noah_end("C")
	await c15._knock_motif()
	ok("n15_end_a", said.has("I know. I counted.") or said.has("The sky."), str(said) + str(c15.present()))
	ok("n15_end_b", said.has("The old man had a route to the next town. I know the first three turns."))
	ok("n15_end_c", said.has("He knocked back.") and said.has("(Three short, one long, on the stone.)"))
	world.free()
	said.clear()
	# ---- no rescue: nothing of it
	await start(func(): DEV15.prepare(game), false)
	ok("n15_none_without_rescue", c15 != null and c15._noah_node() == null)
	await c15._noah_end("A")
	ok("n15_no_lines_without_rescue", not said.has("He knocked back.") and not said.has("I know. I counted."))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
