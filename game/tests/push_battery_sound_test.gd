extends SceneTree
## The shove / drag sound and the battery-pull sound are LOW (no squeal), distinct from each other and from the pickup; the music bus rolls off the top end.
var fails := 0
func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1
func _initialize() -> void:
	_run.call_deferred()
	create_timer(120.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))
# loudest component and the share of energy above 1 kHz (coarse DFT over the first 0.6 s)
func _spectrum(s: AudioStreamWAV) -> Array:
	var rate := s.mix_rate
	var n := mini(int(rate * 0.6), s.data.size() / 2)
	var best := 0.0
	var best_f := 0.0
	var low := 0.0
	var high := 0.0
	for f in range(40, 4000, 40):
		var re := 0.0
		var im := 0.0
		for i in range(0, n, 3):
			var v := float(s.data.decode_s16(i * 2)) / 30000.0
			re += v * cos(TAU * f * i / rate)
			im += v * sin(TAU * f * i / rate)
		var m := re * re + im * im
		if m > best:
			best = m
			best_f = float(f)
		if f < 1000:
			low += m
		else:
			high += m
	return [best_f, high / maxf(low + high, 0.0001)]
func _run() -> void:
	var game = root.get_node("Game")
	load("res://game/chapters/setups/dev_chapter5.gd").prepare(game)
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 60: await physics_frame
	var p4 = w.phase4
	for id in ["scrape", "drag"]:
		var sp: Array = _spectrum(p4._streams[id])
		ok("push_sound_low_" + id, sp[0] <= 320.0 and sp[1] < 0.08, "peak %d Hz, share above 1 kHz %.3f" % [sp[0], sp[1]])
	var cq = load("res://game/world/car_quest.gd").new()
	root.add_child(cq)
	var ex = w.expedition
	if ex != null:
		cq.setup(ex)
		var sp2: Array = _spectrum(cq._streams["battery_pull"])
		ok("battery_sound_low", sp2[0] <= 700.0 and sp2[1] < 0.15, "peak %d Hz, share above 1 kHz %.3f" % [sp2[0], sp2[1]])
		ok("battery_sound_is_its_own", cq._streams["battery_pull"] != p4._streams["scrape"] and cq._streams["battery_pull"] != root.get_node("Sfx")._streams["pickup"])
		var sp3: Array = _spectrum(cq._streams["click"])
		ok("click_is_dull", sp3[1] < 0.2, "share above 1 kHz %.3f" % sp3[1])
	var mi := AudioServer.get_bus_index("Music")
	ok("music_bus_exists", mi >= 0)
	var has_lp := false
	for i in AudioServer.get_bus_effect_count(mi):
		has_lp = has_lp or AudioServer.get_bus_effect(mi, i) is AudioEffectLowPassFilter
	ok("music_bus_rolls_off_the_top", has_lp)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
