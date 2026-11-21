extends SceneTree
## The night sky before the Veil exists, shows in the ordinary night and is gone in the Veil's presets.
var fails := 0
func ck(n: String, c: bool) -> void:
	print("  ", "ok  " if c else "FAIL", " ", n)
	if not c: fails += 1
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g = root.get_node("Game"); g.new_game()
	g.no_save = true
	var w = load("res://game/scenes/World.tscn").instantiate()
	if w == null:
		print("no world scene"); quit(1); return
	root.add_child(w)
	for i in 30: await process_frame
	var sky = w.get_node_or_null("NightSky")
	ck("sky node exists", sky != null)
	if sky:
		ck("shader loaded", sky._mat.shader != null)
		ck("moon above horizon", sky.moon_direction().y > 0.3)
		ck("visible in the night preset", sky._is_night())
		for i in 200: await process_frame
		ck("faded in", sky._mi.visible)
		w._atmo().apply_preset(w.night_preset("approach"), true)
		for i in 200: await process_frame
		ck("gone in the Veil", not sky._mi.visible)
	print("TEST night_sky ", "PASS" if fails == 0 else "FAIL")
	quit(fails)
