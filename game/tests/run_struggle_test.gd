extends SceneTree
## The click-to-run along a set path (review note #120): idle = caught, clicking = reaches the end. A stand-in player and world: no real scene needed.
var fails := 0


func ok(n: String, c: bool, d := "") -> void:
	print("TEST %s %s %s" % [n, "PASS" if c else "FAIL", d])
	if not c:
		fails += 1


class FakePlayer extends Node3D:
	var controls_enabled := true
	var velocity := Vector3.ZERO
	var health := 100.0
	var head := Node3D.new()
	var camera := Camera3D.new()
	func _init() -> void:
		add_child(head)
		head.add_child(camera)
	func set_yaw_pitch(y: float, p: float) -> void:
		rotation.y = y
		head.rotation.x = p


class FakeWorld extends Node:
	var player: Node3D


func _run(clicking: bool, evs := []) -> Dictionary:
	var w := FakeWorld.new()
	var pl := FakePlayer.new()
	w.player = pl
	root.add_child(w)
	w.add_child(pl)
	var chasers: Array = []
	for i in 3:
		var c := Node3D.new()
		w.add_child(c)
		chasers.append(c)
	var pts: Array = [Vector3(0, 0, 0), Vector3(30, 0, 0), Vector3(30, 0, 10), Vector3(36, 0, 10)]
	var rs = load("res://game/encounters/run_struggle.gd").new()
	w.add_child(rs)
	var res := [{}]
	var task := func(): res[0] = await rs.run(w, pts, chasers, {"from_dir": Vector3(-1, 0, 0), "lead": 34.0, "chase_speed": 5.0, "seconds": 12.0, "cap_index": 3, "cap_gap": 1.0, "events": evs})
	task.call()
	var t := 0.0
	while res[0].is_empty() and t < 20.0:
		await process_frame
		t += 1.0 / 60.0
		if clicking:
			var sg = w.get_node_or_null("Struggle")
			if sg and sg.active and fmod(t, 0.3) < 1.0 / 60.0:
				sg._prog = minf(sg._prog + 0.1, 1.0)
	var out: Dictionary = res[0].duplicate()
	out["end"] = pl.global_position
	out["t"] = t
	w.queue_free()
	await process_frame
	return out


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var idle := await _run(false)
	ok("idle_caught", idle.get("caught", false) and not idle.get("won", true), str(idle))
	var fast := await _run(true)
	ok("clicking_wins", fast.get("won", false) and (fast["end"] as Vector3).distance_to(Vector3(36, 0, 10)) < 0.5, str(fast))
	var fired := [0]
	var ev := await _run(true, [{"at": 0.5, "call": func(): fired[0] += 1}])
	ok("event_once", fired[0] == 1 and ev.get("won", false), str(fired))
	print("RESULT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()
