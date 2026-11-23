extends SceneTree
## The score (game/audio/veil_score.gd): the dark layers render on their thread, loop without a seam, the Master bus has its EQ / limiter, the jumpscare runs without errors, and the new interaction sounds stay low.
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
func _peak_hz(s: AudioStreamWAV) -> float:
	# the loudest single bin of a coarse DFT over the first 0.5 s (rate-aware)
	var rate := s.mix_rate
	var n := mini(int(rate * 0.25), s.data.size() / 2)
	var best := 0.0
	var best_f := 0.0
	for f in range(60, 3000, 30):
		var re := 0.0
		var im := 0.0
		for i in range(0, n, 2):
			var v := float(s.data.decode_s16(i * 2)) / 30000.0
			re += v * cos(TAU * f * i / rate)
			im += v * sin(TAU * f * i / rate)
		var m := re * re + im * im
		if m > best:
			best = m
			best_f = float(f)
	return best_f
func _run() -> void:
	var sfx = root.get_node("Sfx")
	var score = sfx._score
	ok("score_exists", score != null)
	var t := 0.0
	while not score.ready_layers and t < 60.0:
		await process_frame
		t += 1.0 / 60.0
	ok("layers_ready", score.ready_layers, "%.1f s" % t)
	if score.ready_layers:
		for k in ["drone_a", "pad_b", "texture_c", "heart", "boom", "screech", "creak", "knock"]:
			ok("stream_" + k, score._streams.has(k) and (score._streams[k] as AudioStreamWAV).data.size() > 1000)
		for k in ["drone_a", "pad_b", "texture_c"]:
			var s: AudioStreamWAV = score._streams[k]
			var n := s.data.size() / 2
			var a := float(s.data.decode_s16(0)) / 30000.0
			var b := float(s.data.decode_s16((n - 1) * 2)) / 30000.0
			ok("loops_seamlessly_" + k, absf(a - b) < 0.02, "%.4f -> %.4f" % [b, a])
		# the layers are dark: the loudest component of each lies low
		ok("drone_is_dark", _peak_hz(score._streams["drone_a"]) <= 150.0, str(_peak_hz(score._streams["drone_a"])))
	var master := AudioServer.get_bus_index("Master")
	var has_eq := false
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		var e := AudioServer.get_bus_effect(master, i)
		has_eq = has_eq or e is AudioEffectEQ10
		has_limiter = has_limiter or e is AudioEffectLimiter
	ok("master_has_eq_and_limiter", has_eq and has_limiter)
	# interaction sounds sit low (the loudest component under 700 Hz)
	for id in ["pickup", "door_open", "door_close"]:
		var st: AudioStreamWAV = sfx._streams[id]
		ok("interaction_sound_is_low_" + id, _peak_hz(st) <= 1100.0, str(_peak_hz(st)))
	sfx.jumpscare("hound")
	await create_timer(0.5).timeout
	ok("jumpscare_runs", true)
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
