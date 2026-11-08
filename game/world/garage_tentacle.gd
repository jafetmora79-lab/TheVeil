extends Node
class_name VeilGarageTentacle
## THE VEIL - Chapter 4: the loading-bay tentacle. The roll-up door is still open (the 0.9 m gap); something waits
## outside. On the player's approach (after the breaker, before the door is pulled down):
##   reveal (camera held): the view turns to the gap; THREE Mist Tentacles, one beat at a time - the floor one
##     pushes in under the door, pauses, grabs left to right; the upper one reaches down; the side one lashes across
##   escape: control comes back, THEN a 10 s countdown: pull the loading door down (the existing handle)
##   success: the tentacle is forced back out, the door shuts, one heavy impact, silence, "Holy shit..."
##   failure: it takes his leg - first person: look down, fall, dragged across the floor to the gap, black, YOU DIED
##     -> RETRY (the save made when the encounter started: the door open, the tentacle hidden, the timer reset)
## Flag p4_garage_done once survived (never replays).

const TENTACLE := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn"
const ROOT := Vector3(20.3, 0.35, 15.9)              # market frame: just outside the roll-up door's plane (x 20.05)
const GAP_LOOK := Vector3(19.6, 0.45, 15.9)
const ESCAPE_S := 10.0
## Not lying flat along the floor (it read as a tube slid in on its side): it rises from the gap at about 20 degrees,
## at the player, its base out of sight outside the door (0.25 m in, it is 9 cm higher: still under the 0.9 m gap).
const LIFT := PI * 0.5 - 0.35

var p4: Node
var world: Node
var player: Node3D
var running := false
var closing := false
var time_left := 0.0
var report := {}


func setup(phase4: Node) -> void:
	p4 = phase4
	world = p4.world
	player = p4.player



## Checked every 0.2 s (not an area's body_entered: the breaker panel stands inside the loading bay, so the player is
## already in there when the breaker comes on and would never "enter"): towards the door, past the breaker.
var _tick := 0.0
func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0 or running or player == null:
		return
	_tick = 0.2
	var l: Vector3 = p4.market.to_local(player.global_position)
	if l.x > 17.2 and l.x < 20.0 and absf(l.z - 15.9) < 1.8 and player.get("controls_enabled") \
			and world.get("_world_live") == true and Game.has_flag("p4_flashlight"):
		_on_enter()                                  # (never while a load / retry is still restoring the world)


func _on_enter() -> void:
	if running or Game.has_flag("p4_garage_done") or Game.has_flag("p4_loading_down") or not Game.has_flag("p4_started"):
		return
	running = true
	world.save()                                       # the checkpoint: RETRY comes back to here
	var back: Vector3 = p4.ml(Vector3(15.6, 0.0, 15.9))
	back.y = player.global_position.y
	Game.player_state["pos"] = [back.x, back.y, back.z]   # ...a step back from the door, outside the trigger
	Game.save_game()
	await _reveal()
	await _escape()


# ------------------------------------------------------------------ reveal
func _reveal() -> void:
	player.set("velocity", Vector3.ZERO)
	var src: Camera3D = player.get("camera")
	var cam := Camera3D.new()
	cam.name = "GarageCam"
	world.add_child(cam)
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.current = true
	p4._hold_cam(cam)
	# 1. warning (short): a scrape outside, the door rattles in its rails, something heavy hits it
	p4._play("slither", p4.ml(GAP_LOOK), 2.0)            # something heavy and wet outside
	await p4._fp_face(cam, p4.ml(GAP_LOOK + Vector3(0, 0.4, 0)), 0.35)
	var ld: Node3D = p4.its.get("loading_door")
	if ld:
		var t0 := ld.transform
		var tr := create_tween()
		for k in 3:
			tr.tween_property(ld, "transform", Transform3D(t0.basis, t0.origin + Vector3(0, 0.03 * (1 - 2 * (k % 2)), 0)), 0.05)
		tr.tween_property(ld, "transform", t0, 0.05)
	await get_tree().create_timer(0.25).timeout
	p4._play("impact", p4.ml(Vector3(20.1, 0.9, 15.9)), 4.0)
	world._shake(cam, 0.2, 0.03)
	await get_tree().create_timer(0.3).timeout
	# 2. the three, one beat at a time
	_spawn_trio()
	world._shake(cam, 0.3, 0.04)
	await p4._fp_face(cam, p4.ml(GAP_LOOK + Vector3(-0.8, 0.3, 0)), 0.3)
	await _beat("A", "push")
	await _beat("A", "sense")
	await _beat("A", "sweep")
	Sfx.play("hurt", player.global_position, -10.0, 1.4)            # a gasp: it missed, just
	world._shake(cam, 0.25, 0.05)
	await p4._fp_face(cam, p4.ml(Vector3(19.8, 1.0, float(trio["B"]["root"].z))), 0.25)
	await _beat("B", "reach")
	await p4._fp_face(cam, p4.ml(Vector3(19.6, 0.5, float(trio["C"]["root"].z) + 0.6)), 0.2)
	_beat("C", "lash")
	await get_tree().create_timer(0.3).timeout
	report["revealed"] = trio.size() == 3
	report["clearance_hits"] = _clearance()
	# control back (move + look), then the timer
	p4._cam_held = null
	var fwd := -cam.global_basis.z
	player.call("set_yaw_pitch", atan2(-fwd.x, -fwd.z), clampf(asin(clampf(fwd.y, -1.0, 1.0)), -0.6, 0.6))
	cam.queue_free()
	src.current = true
	player.set("controls_enabled", true)
	player.set("look_enabled", true)


# ------------------------------------------------------------------ 10 s escape
func _escape() -> void:
	report["control_before_timer"] = player.get("controls_enabled") and player.get("look_enabled")
	time_left = ESCAPE_S
	var hud: Node = world.get("hud")
	hud.title_card("CLOSE THE GARAGE DOOR — NOW!", 1.4)
	p4._music("chase", -14.0)
	var mp: AudioStreamPlayer = p4._music_player
	while time_left > 0.0 and not closing:
		var dt := get_process_delta_time()
		time_left -= dt
		hud.set_hint("CLOSE THE GARAGE DOOR — NOW!   %.1f" % maxf(time_left, 0.0))
		if mp:
			mp.volume_db = lerpf(-14.0, -1.0, 1.0 - time_left / ESCAPE_S)      # it builds as time runs out
		_trio_tick(dt)
		await get_tree().process_frame
	hud.set_hint("")
	report["time_left"] = time_left
	if closing:
		await _survived()
	else:
		await _taken()


## The real Pack 07 Mist Tentacle three times (its own mesh, rig and dark material - no stand-in), one controller.
## Each tentacle: root outside the building (behind the door / frame), chain along its +Y aimed into the bay, pose
## built on its bones (VeilTentaclePoser: bends only on the part inside, the part under / behind the door stays
## straight). Motion is in beats - a push, a pause, a sudden sweep, a pull back - never a constant wiggle.
##   A  floor  under the door, the original entry: slow push, a pause (sensing), a sudden left-right grab, back
##   B  upper  root high outside, enters at the top of the gap and reaches DOWN at the player
##   C  side   along the opening's edge, lashes ACROSS the opening
var trio := {}                                         ## "A"/"B"/"C" -> {node, poser, root, dir, scale, slide, yaw, busy}
var beat_log: Array = []                               ## (tests) the beats in the order they started
var _beat_t := 0.0
var _beat_next := 0


func _door_span() -> Vector2:
	var ld: Node3D = p4.its.get("loading_door")
	if ld:
		var b: AABB = (p4.market.global_transform.affine_inverse() * ld.global_transform) * Interactable.aabb_of(ld)
		if b.size.z > 1.0:
			return Vector2(b.position.z, b.end.z)
	return Vector2(ROOT.z - 1.4, ROOT.z + 1.4)


func _spawn_trio() -> void:
	var span := _door_span()
	var zc := (span.x + span.y) * 0.5
	report["door_span"] = span
	var gap_top := 0.8
	# [root (market frame, outside), aim (into the bay), scale]
	var spec := {
		"A": [Vector3(22.6, 0.28, zc), Vector3(-1.0, 0.03, 0.0), 0.75],
		"B": [Vector3(21.9, 1.5, minf(zc + 0.8, span.y - 0.4)), Vector3(20.05, gap_top - 0.02, minf(zc + 0.8, span.y - 0.4)) - Vector3(21.9, 1.5, minf(zc + 0.8, span.y - 0.4)), 0.65],
		"C": [Vector3(21.9, 0.45, span.x + 0.3), Vector3(-1.0, 0.02, 0.5), 0.65],
	}
	for k in spec:
		var t := (load(TENTACLE) as PackedScene).instantiate() as Node3D
		t.name = "P4_GarageTentacle_" + k
		t.set("autoplay", "")
		p4.market.add_child(t)
		var ap := t.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			ap.stop()
		# its own dark material, fully shown: the mist-fade line is put well below the floor (the scene's
		# tentacles lie low along the floor, which the fade would otherwise dither away)
		t.set_process(false)
		for m in t.get("_mats"):
			(m as ShaderMaterial).set_shader_parameter("mist_level", -50.0)
			(m as ShaderMaterial).set_shader_parameter("fade_height", 0.05)
		var po := VeilTentaclePoser.attach(t)
		trio[k] = {"node": t, "poser": po, "root": spec[k][0], "dir": (spec[k][1] as Vector3).normalized(),
			"scale": float(spec[k][2]), "slide": -1.6, "yaw": 0.0, "busy": false}
		_apply(k)
	report["tentacles"] = trio.size()


func _aim(dir: Vector3, s: float) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.05:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z).scaled(Vector3.ONE * s)


func _apply(k: String) -> void:
	var d: Dictionary = trio[k]
	var t: Node3D = d["node"]
	if not is_instance_valid(t):
		return
	var dir: Vector3 = (d["dir"] as Vector3).rotated(Vector3.UP, float(d["yaw"]))
	t.transform = Transform3D(_aim(dir, float(d["scale"])), (d["root"] as Vector3) + dir * float(d["slide"]))


## Bend only the inside part (bones from `from` on): `lean` up / down (about the bone X), `curl` sideways.
func _pose(k: String, from: int, lean: float, curl := 0.0) -> void:
	var po: VeilTentaclePoser = trio[k]["poser"]
	if po:
		po.set_split(from, 0.0, 0.0, curl, lean)
		po.apply()


## Tween a tentacle's slide / yaw / bend together over `secs` (heavy: eased, never oscillating).
func _move(k: String, slide: float, yaw: float, lean: float, secs: float, trans := Tween.TRANS_SINE, ease_t := Tween.EASE_IN_OUT) -> void:
	var d: Dictionary = trio[k]
	var s0: float = d["slide"]
	var y0: float = d["yaw"]
	var po: VeilTentaclePoser = d["poser"]
	var l0: float = po.lean[po.lean.size() - 1] if po else 0.0
	var from := 4 if k == "A" else 5
	var tw := create_tween().set_trans(trans).set_ease(ease_t)
	tw.tween_method(func(f: float):
		if not trio.has(k) or not is_instance_valid(d["node"]):
			return
		d["slide"] = lerpf(s0, slide, f)
		d["yaw"] = lerpf(y0, yaw, f)
		_apply(k)
		_pose(k, from, lerpf(l0, lean, f)), 0.0, 1.0, secs)
	await tw.finished


func _beat(k: String, what: String, pace := 1.0) -> void:
	if not trio.has(k) or trio[k]["busy"]:
		return
	trio[k]["busy"] = true
	beat_log.append("%s:%s" % [k, what])
	var at: Vector3 = p4.market.to_global(trio[k]["root"])
	match what:
		"push":                                           # slowly further in under the door
			Sfx.bank_at("te_wet", at, 0.0, 8.0)
			await _move(k, 0.0, -0.45, 0.04, 2.2 * pace)
		"sense":                                          # it stops; the tip lifts a little, searching
			await _move(k, 0.0, -0.45, 0.2, 0.8 * pace)
		"sweep":                                          # sudden: left to right across where the player stands
			Sfx.bank_at("te_strike", at, 2.0, 8.0)
			await _move(k, 0.15, 0.45, -0.03, 0.32 * pace, Tween.TRANS_EXPO)
			await _move(k, -0.35, 0.3, 0.06, 0.55 * pace)     # and back a little, heavy
		"sweep_back":
			Sfx.bank_at("te_strike", at, 0.0, 8.0)
			await _move(k, 0.15, -0.45, -0.03, 0.32 * pace, Tween.TRANS_EXPO)
			await _move(k, -0.35, -0.3, 0.06, 0.55 * pace)
		"reach":                                          # B: in at the top of the gap and down at the player
			Sfx.bank_at("te_strike", at, 0.0, 8.0)
			await _move(k, 0.0, 0.0, 0.22, 0.25 * pace, Tween.TRANS_QUAD, Tween.EASE_OUT)
			await _move(k, 0.0, 0.0, -0.08, 0.4 * pace, Tween.TRANS_EXPO)
			await _move(k, -0.7, 0.0, 0.1, 0.7 * pace)
		"lash":                                           # C: across the opening
			Sfx.bank_at("te_strike", at, 0.0, 8.0)
			await _move(k, 0.0, -0.35, 0.05, 0.22 * pace, Tween.TRANS_QUAD, Tween.EASE_OUT)
			await _move(k, 0.0, 0.4, 0.02, 0.3 * pace, Tween.TRANS_EXPO)
			await _move(k, -0.8, 0.1, 0.05, 0.65 * pace)
		"retract":
			await _move(k, -2.6, 0.0, 0.0, 0.45, Tween.TRANS_EXPO, Tween.EASE_IN)
	if trio.has(k):
		trio[k]["busy"] = false


## During the 10 s: one beat at a time across the three, closer together as time runs out.
func _trio_tick(dt: float) -> void:
	if trio.is_empty():
		return
	_beat_t -= dt
	if _beat_t > 0.0:
		return
	var k := 1.0 - clampf(time_left / ESCAPE_S, 0.0, 1.0)
	_beat_t = lerpf(2.2, 0.9, k)
	var order := [["A", "sweep_back"], ["B", "reach"], ["C", "lash"], ["A", "sweep"]]
	var step: Array = order[_beat_next % order.size()]
	_beat_next += 1
	_beat(step[0], step[1], lerpf(1.0, 0.7, k))


func _free_trio() -> void:
	for k in trio:
		var t = trio[k]["node"]
		if is_instance_valid(t):
			t.queue_free()
	trio.clear()


## Solid things the inside parts would pass through right now (bone joints inside the bay vs the world).
func _clearance() -> Array:
	var hits := []
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.07
	q.shape = sph
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	for k in trio:
		var po: VeilTentaclePoser = trio[k]["poser"]
		if po == null:
			continue
		po.sk.force_update_all_bone_transforms()
		for b in po.bones:
			var g: Vector3 = po.sk.global_transform * po.sk.get_bone_global_pose(b).origin
			if p4.market.to_local(g).x > 19.9:
				continue                                   # under / behind the door: not the bay
			q.transform = Transform3D(Basis(), g)
			for h in space.intersect_shape(q, 4):
				hits.append("%s:%s" % [k, String((h["collider"] as Node).name)])
	return hits


## Phase 4's loading handle was used: the door comes down.
func on_close_started() -> void:
	if running and time_left > 0.0:
		closing = true


func _survived() -> void:
	for k in trio:                                     # forced back out under the closing door
		trio[k]["busy"] = false
		_beat(k, "retract")
	report["retracted"] = true
	while not Game.has_flag("p4_loading_down"):
		await get_tree().process_frame
	p4._play("impact", p4.ml(Vector3(20.1, 0.9, 15.9)), 6.0)   # one heavy hit on the shut door
	world._shake(player.get("camera"), 0.3, 0.04)
	p4._music_stop(0.15)
	_free_trio()
	report["cleaned_up"] = true
	await get_tree().create_timer(1.4).timeout         # silence
	Dialogue.say("p4_garage_safe", false, true)
	Sfx.start_ambience()
	Game.set_flag("p4_garage_done")
	report["survived"] = true
	running = false


# ------------------------------------------------------------------ failure: dragged out
func _taken() -> void:
	report["taken"] = true
	var src: Camera3D = player.get("camera")
	var cam := Camera3D.new()
	cam.name = "GarageDeathCam"
	world.add_child(cam)
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.current = true
	p4._hold_cam(cam)
	var feet := player.global_position
	var out_dir: Vector3 = (p4.ml(ROOT) - feet) * Vector3(1, 0, 1)
	out_dir = out_dir.normalized()
	# the tentacle lashes to his leg
	for k in ["B", "C"]:
		if trio.has(k):
			trio[k]["busy"] = false
			_beat(k, "retract")
	if trio.has("A"):
		var lf: Vector3 = p4.market.to_local(feet) - (trio["A"]["root"] as Vector3)
		trio["A"]["dir"] = Vector3(lf.x, 0.0, lf.z).normalized()
		trio["A"]["yaw"] = 0.0
		_move("A", maxf(lf.length() - 3.6, 0.0), 0.0, -0.05, 0.25, Tween.TRANS_EXPO)   # its tip at his ankle
	Sfx.play("hurt", feet, -2.0, 0.7)
	await p4._fp_face(cam, feet + Vector3(0, 0.1, 0) - out_dir * 0.15, 0.3)   # looks down: it has his leg
	await get_tree().create_timer(0.45).timeout
	# he falls
	var tf := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tf.tween_property(cam, "global_position", feet + Vector3(0, 0.32, 0) - out_dir * 0.2, 0.35)
	tf.parallel().tween_property(cam, "rotation:z", deg_to_rad(22.0), 0.35)
	await tf.finished
	world._shake(cam, 0.25, 0.06)
	p4._play("impact", feet, -4.0)
	# dragged across the floor, out under the door
	var gap: Vector3 = p4.ml(Vector3(20.6, 0.32, 15.9))
	var start := cam.global_position
	var t := 0.0
	var dur := 1.7
	while t < dur:
		t += get_process_delta_time()
		var k := clampf(t / dur, 0.0, 1.0)
		cam.global_position = start.lerp(gap, k * k) + Vector3(randf_range(-0.02, 0.02), randf_range(-0.015, 0.015), 0)
		var back := Transform3D(Basis(), cam.global_position).looking_at(cam.global_position - out_dir * 2.0 + Vector3(0, 0.6, 0), Vector3.UP).basis
		cam.global_basis = Basis(cam.global_basis.get_rotation_quaternion().slerp(back.get_rotation_quaternion(), minf(get_process_delta_time() * 4.0, 1.0)))
		if trio.has("A") and is_instance_valid(trio["A"]["node"]):
			var lc: Vector3 = p4.market.to_local(cam.global_position) - (trio["A"]["root"] as Vector3)
			trio["A"]["slide"] = maxf(Vector2(lc.x, lc.z).length() - 3.6, -1.5)   # it keeps hold, pulling him to the gap
			_apply("A")
		await get_tree().process_frame
	p4._play("slither", gap, 6.0)
	var hud: Node = world.get("hud")
	await hud.fade_to(1.0, 0.25)                        # into the dark
	p4._music_stop(0.1)
	report["dragged_out"] = true
	var panel := VeilChoicePanel.new()
	panel.name = "DeathPanel"
	world.add_child(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var i: int = await panel.ask("YOU DIED", ["RETRY", "MAIN MENU"])
	# leave nothing running into the reload: the held camera, the creature, the music, any pause
	p4._cam_held = null
	_free_trio()
	p4._music_stop(0.0)
	running = false
	get_tree().paused = false
	if i == 0:
		# the checkpoint saved when the encounter began (a step back from the door); reloaded on the next frame,
		# outside this button's signal
		(func(): VeilDeathSequence.retry()).call_deferred()
	else:
		world.call("_to_menu")
