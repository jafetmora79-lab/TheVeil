extends SceneTree
## THE VEIL - every staircase in every two-storey house in town, walked by the real player with real input:
## up (middle, hugging each side), sprinting up, down, sprinting down, stopping halfway and going on, turning back
## halfway. A case passes when the player reaches the other landing (within 0.5 m, on that floor) in 8 s.
## Prints one line per case that fails and a summary. Headless: run with --fixed-fps 60.
const DEV := preload("res://game/tools/dev_chapter7.gd")
const DATA := "res://game/data/house_stairs.json"

var w: Node
var p: CharacterBody3D
var fails := 0
var runs := 0


func _initialize() -> void:
	_run.call_deferred()


var crouch := false


func _walk(to: Vector3, secs: float, sprint := false, stop_after := -1.0, stop_for := 0.0) -> float:
	var t := 0.0
	var stopped := false
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	if crouch:
		Input.action_press("crouch")
	while t < secs:
		var d := to - p.global_position
		d.y = 0.0
		if d.length() < 0.3 and absf(to.y - p.global_position.y) < 0.4:
			break
		if stop_after >= 0.0 and t >= stop_after and not stopped:
			stopped = true
			Input.action_release("move_forward")
			Input.action_release("sprint")
			for i in int(stop_for * 60):
				await physics_frame
			Input.action_press("move_forward")
			if sprint:
				Input.action_press("sprint")
		p.set_yaw_pitch(atan2(-d.x, -d.z), 0.0)
		await physics_frame
		t += 1.0 / 60.0
	Input.action_release("move_forward")
	Input.action_release("sprint")
	Input.action_release("crouch")
	for i in 20:
		await physics_frame
	var r := to - p.global_position
	return Vector2(r.x, r.z).length() + maxf(absf(r.y) - 0.3, 0.0)


func _place(at: Vector3) -> void:
	p.global_position = at + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame


func _case(name: String, start: Vector3, to: Vector3, sprint := false, stop_after := -1.0, back_to := Vector3.INF) -> void:
	runs += 1
	await _place(start)
	var miss: float
	if back_to.is_finite():
		await _walk(to, 1.4)                       # half way up, then turn round and go back down
		miss = await _walk(back_to, 8.0)
	else:
		miss = await _walk(to, 8.0, sprint, stop_after, 0.8)
	if miss > 0.5:
		fails += 1
		var what := ""
		for i in p.get_slide_collision_count():
			var c := p.get_slide_collision(i)
			what += " %s(n=%s)" % [(c.get_collider() as Node).name if c.get_collider() else "?", str(c.get_normal().snapped(Vector3.ONE * 0.01))]
		var sp := p.get_world_3d().direct_space_state
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.34
		cap.height = 1.8
		q.shape = cap
		q.transform = Transform3D(Basis(), p.global_position + Vector3(0, 0.92, 0))
		q.exclude = [p.get_rid()]
		for r in sp.intersect_shape(q, 6):
			what += " near:%s/%s" % [(r["collider"] as Node).get_parent().name, (r["collider"] as Node).name]
		print("  FAIL %s: %.2f m short, stopped at %s  touching:%s" % [name, miss, str(p.global_position), what])


func _run() -> void:
	var game = root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 150:
		await process_frame
	p = w.player
	p.controls_enabled = true
	p.look_enabled = true
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var houses := 0
	var only := OS.get_cmdline_user_args()            # optional: -- HOUSE_ID ... tests just those houses
	for h in w.get_node("Residential/Houses").get_children():
		if not only.is_empty() and not (String(h.name) in only):
			continue
		var info: Dictionary = h.get_meta("veil_house", {})
		var key := String(info.get("design", "")) + ("_Mirror" if info.get("mirrored", false) else "")
		if not data.has(key):
			continue
		houses += 1
		var before := fails
		var flights: Array = data[key]
		for fi in flights.size():
			var f: Dictionary = flights[fi]
			var o: Array = f["origin"]
			var xf: Transform3D = (h as Node3D).global_transform * Transform3D(Basis(Vector3.UP, float(f["yaw"])), Vector3(o[0], o[1], o[2]))
			var wd := float(f["width"])
			var l := float(f["run"])
			var ht := float(f["height"])
			var foot := xf * Vector3(wd * 0.5, 0.0, -0.9)
			var top := xf * Vector3(wd * 0.5, ht, l + 0.9)
			var tag := "%s (%s) flight %d" % [h.name, key, fi]
			await _case(tag + " up", foot, top)
			await _case(tag + " up hugging side A", xf * Vector3(0.32, 0.0, -0.9), xf * Vector3(0.32, ht, l + 0.9))
			await _case(tag + " up hugging side B", xf * Vector3(wd - 0.32, 0.0, -0.9), xf * Vector3(wd - 0.32, ht, l + 0.9))
			await _case(tag + " sprint up", foot, top, true)
			await _case(tag + " down", top, foot)
			await _case(tag + " sprint down", top, foot, true)
			await _case(tag + " stop half way", foot, top, false, 1.3)
			await _case(tag + " turn back half way", foot, top, false, -1.0, foot)
			crouch = true
			await _case(tag + " crouched up", foot, top)
			await _case(tag + " crouched down", top, foot)
			crouch = false
		print("HOUSE %s %s: %s" % [h.name, key, "ok" if fails == before else "%d failing case(s)" % (fails - before)])
	print("STAIRS houses=%d cases=%d fails=%d" % [houses, runs, fails])
	quit(1 if fails > 0 else 0)
