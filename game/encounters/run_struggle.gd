extends Node
## A scripted run along a SET PATH, driven by click mashing (review note #120). The player runs the path with a click-struggle bar: the more they click, the further along they get, while chasers
## (skitters, a hound...) run the same path from behind at a fixed pace. Bar full = the end of the path. Caught up (or out of time) = caught: the caller plays whatever follows.
## Nothing here uses the world's collision: the path is chosen by the caller, so the cinematic always goes where it is meant to (through the doors, not into the wall).
## run() leaves the player's physics OFF and controls OFF: the caller turns them back on.

var world: Node
var player: Node3D
var _path: Array = []
var _cum: Array = []
var _over := false
var _won := false


func _build(pts: Array) -> void:
	_path = pts
	_cum = [0.0]
	for i in range(1, pts.size()):
		_cum.append(float(_cum[i - 1]) + (pts[i] as Vector3).distance_to(pts[i - 1]))


## [position, direction] at distance u along the path (before the start / past the end it continues straight).
func _at(u: float) -> Array:
	var n := _path.size()
	if u <= 0.0:
		var d0: Vector3 = ((_path[1] as Vector3) - (_path[0] as Vector3)).normalized()
		return [(_path[0] as Vector3) + d0 * u, d0]
	if u >= float(_cum[n - 1]):
		var d1: Vector3 = ((_path[n - 1] as Vector3) - (_path[n - 2] as Vector3)).normalized()
		return [(_path[n - 1] as Vector3) + d1 * (u - float(_cum[n - 1])), d1]
	for i in range(1, n):
		if u <= float(_cum[i]):
			var a: Vector3 = _path[i - 1]
			var b: Vector3 = _path[i]
			var seg := float(_cum[i]) - float(_cum[i - 1])
			var k := (u - float(_cum[i - 1])) / maxf(seg, 0.001)
			return [a.lerp(b, k), (b - a).normalized()]
	return [_path[n - 1], Vector3.FORWARD]


func _go(sg: Node, title: String, hint: String, seconds: float, per_click: float) -> void:
	_won = await sg.rescue(title, hint, seconds, "hs_hold", per_click)
	_over = true


## pts: world points, pts[0] = where the player is now. o: from_dir (where the chasers come from, relative to the player), lead (their head start in metres), chase_speed, spacing,
## seconds, title, hint, cap_index (index into pts of the point the chasers may not pass, e.g. the door line), cap_gap.
## Returns {"won": bool, "caught": bool}.
func run(w: Node, pts: Array, chasers: Array, o := {}) -> Dictionary:
	world = w
	player = w.player
	var lead: float = float(o.get("lead", 34.0))
	var speed: float = float(o.get("chase_speed", 5.0))
	var spacing: float = float(o.get("spacing", 3.0))
	var from_dir: Vector3 = o.get("from_dir", Vector3(-1, 0, 0))
	var full: Array = [(pts[0] as Vector3) + from_dir.normalized() * lead]
	full.append_array(pts)
	_build(full)
	var total: float = float(_cum[_cum.size() - 1])
	var cap_u: float = total
	if o.has("cap_index"):
		cap_u = float(_cum[int(o["cap_index"]) + 1]) - float(o.get("cap_gap", 0.8))
	var sg = w.get_node_or_null("Struggle")
	if sg == null:
		sg = load("res://game/encounters/struggle.gd").new()
		sg.name = "Struggle"
		w.add_child(sg)
		sg.setup(w)
	var base_y: Array = []
	for c in chasers:
		base_y.append((c as Node3D).global_position.y)
	player.controls_enabled = false
	player.set("auto_input", Vector2.ZERO)
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	var music := String(o.get("music", ""))
	if music != "":
		Sfx.play_music(music, true, -4.0, 0.5)                 # frantic chase music for the length of the run
	var allies: Array = o.get("allies", [])                    # [{"anim": NpcAnimator, "side": 1.3}]: they run beside the player at the same speed
	for al in allies:
		al["anim"].free_walk = true
		al["anim"].set_mood("scared")
		al["react_t"] = 0.8
	var v_now := 0.0
	_over = false
	_won = false
	# the player never runs faster than vmax (a hard sprint, not a flight): the bar is sized so that steady clicking (~3 a second) fills it in about the time the run takes at that speed
	var vmax: float = float(o.get("max_speed", 6.5))
	var t_run: float = (total - lead) / vmax
	_go(sg, String(o.get("title", "RUN!  CLICK RAPIDLY")), String(o.get("hint", "LEFT CLICK, AGAIN AND AGAIN")), t_run * 1.45 + 2.0, 1.0 / (t_run * 3.1))
	var u_p := lead
	var t := 0.0
	var caught := false
	while not _over:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var prog: float = sg.rescue_progress()
		var u_target := lead + prog * (total - lead)
		var u_before := u_p
		u_p = minf(maxf(u_p, lerpf(u_p, u_target, 1.0 - exp(-5.0 * dt))), u_p + vmax * dt)
		v_now = (u_p - u_before) / maxf(dt, 0.001)
		_run_allies(allies, u_p, v_now, dt, chasers)
		_place_player(u_p, t, dt)
		var front := minf(t * speed, cap_u)
		for i in chasers.size():
			var ch := chasers[i] as Node3D
			if not is_instance_valid(ch):
				continue
			var ui := minf(front - i * spacing, cap_u - i * 0.6)
			var pd := _at(ui)
			var side := Vector3(-pd[1].z, 0.0, pd[1].x) * ((i % 3) - 1) * 0.9
			var pp: Vector3 = pd[0] + side
			ch.global_position = Vector3(pp.x, base_y[i], pp.z)
			ch.rotation.y = atan2(pd[1].x, pd[1].z)
		if front >= u_p - 1.6 and front < cap_u:
			caught = true
			sg.abort_rescue()
			_over = true
	if _won:
		while u_p < total - 0.15:                       # the last metres after the bar fills
			await get_tree().process_frame
			var d2 := get_process_delta_time()
			t += d2
			u_p = minf(u_p + vmax * d2, total)
			_place_player(u_p, t, d2)
			_run_allies(allies, u_p, vmax, d2, chasers)
	for al in allies:
		al["anim"].walk_to([])
		al["anim"].free_walk = false
	if player.get("camera") != null:
		(player.camera as Camera3D).v_offset = 0.0
	if music != "":
		if _won and not caught:
			Sfx.play_music(Sfx.MUSIC_GAMEPLAY, true, -14.0, 3.0)   # safe: the soundtrack comes back
		else:
			Sfx.stop_music(1.0)
	return {"won": _won and not caught, "caught": caught, "u": u_p}


## Each ally keeps a slot beside and just behind the player and runs at the player's own speed (a little more when he has fallen back); now and then he throws a look back at the chasers.
func _run_allies(allies: Array, u: float, v: float, dt: float, _chasers: Array) -> void:
	for al in allies:
		var anim = al["anim"]
		var pd := _at(u - float(al.get("behind", 1.3)))
		var side := Vector3(-pd[1].z, 0.0, pd[1].x) * float(al.get("side", 0.9))
		var slot: Vector3 = pd[0] + side
		var root := anim.root as Node3D
		# placed exactly on the slot every frame (right behind the player, never lagging, never left outside); the animator is told he is running so the legs and arms go
		anim.walk_speed = maxf(v, 4.5)
		anim.walk_to([slot + (pd[1] as Vector3) * 1.0])
		root.global_position = slot
		al["react_t"] = float(al["react_t"]) - dt
		if float(al["react_t"]) <= 0.0:
			al["react_t"] = randf_range(1.0, 1.8)
			anim.react(0.7, 1.0 if float(al.get("side", 0.9)) < 0.0 else -1.0)   # the glance goes back over the shoulder, towards the chasers


func _place_player(u: float, t: float, dt: float) -> void:
	var pd := _at(u)
	var p: Vector3 = pd[0]
	player.global_position = p
	player.velocity = Vector3.ZERO
	var want := atan2(-pd[1].x, -pd[1].z)
	player.set_yaw_pitch(lerp_angle(player.rotation.y, want, minf(1.0, 6.0 * dt)), lerpf(player.head.rotation.x, 0.0, minf(1.0, 5.0 * dt)))
	if player.get("camera") != null:
		(player.camera as Camera3D).v_offset = sin(t * 12.5) * 0.05
