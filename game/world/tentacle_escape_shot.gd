extends Node3D
## THE VEIL - the first street tentacle, outside the game shop: one timeline, every sound on its own action.
##   look    the view turns to the street, a short beat
##   warn    a low rumble (the advance warning); the asphalt cracks at the exact spot, the ground heaves (mound)
##   burst   the tip pierces the surface and thrusts straight up; the body feeds up through the same hole
##   curl    the upper body sweeps round in a circle facing the player, then turns towards them
##   notice  a breath; coil back; LASH across where the player stood - a scripted sidestep with a tilt; the tip hits
##           the ground in the vacated space: impact sound + camera jolt on the hit
##   handoff Eddie: run! The camera goes back to the player; the tentacle stays (the caller gives it to the chase)
## The pose is built bone by bone (VeilTentaclePoser): no canned clip, no lifting of a finished pose.

const TENTACLE := preload("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn")
const CAMERA_MARGIN := 0.16
const EXPOSED := 3.3                      ## metres of tentacle above the street once it is up

var tentacle: Node3D                      ## left in place for the chase
var poser: VeilTentaclePoser
var mound: VeilTentacleMound
var report := {"cues": []}
var _start_ms := 0


func _cue(id: String) -> void:
	(report["cues"] as Array).append([id, (Time.get_ticks_msec() - _start_ms) / 1000.0])


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _arr(lo: float, hi: float, from: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for i in poser.bones.size():
		a.append(hi if i >= from else lo)
	return a


## Ease the pose (per-bone curl / lean) to the targets over `secs`.
func _morph(c_to: PackedFloat32Array, l_to: PackedFloat32Array, secs: float, trans := Tween.TRANS_SINE, ease_t := Tween.EASE_IN_OUT) -> void:
	var c0 := poser.curl.duplicate()
	var l0 := poser.lean.duplicate()
	var tw := create_tween().set_trans(trans).set_ease(ease_t)
	tw.tween_method(func(k: float):
		for i in poser.bones.size():
			poser.curl[i] = lerpf(c0[i], c_to[i], k)
			poser.lean[i] = lerpf(l0[i], l_to[i], k)
		poser.apply(), 0.0, 1.0, secs)
	await tw.finished


func play(world: Node) -> bool:
	_start_ms = Time.get_ticks_msec()
	var player: VeilPlayer = world.player
	var eye := player.camera.global_position
	var feet := player.global_position
	var exit_direction: Vector3 = world.market.to_global(Vector3.ZERO) - feet
	exit_direction.y = 0.0
	exit_direction = exit_direction.normalized()
	if exit_direction.is_zero_approx():
		return false
	var stage := _find_stage(player, feet, eye, exit_direction, 2.6)
	if stage.is_empty():
		return false
	var ground: Vector3 = stage.ground
	report["ground"] = ground
	var camera := Camera3D.new()
	camera.near = player.camera.near
	camera.far = player.camera.far
	camera.fov = player.camera.fov
	add_child(camera)
	camera.global_transform = player.camera.global_transform
	camera.make_current()

	# --- look: the view turns naturally to the street, a short beat
	var q0 := camera.global_basis.get_rotation_quaternion()
	var q1 := Basis.looking_at(ground + Vector3.UP * 1.2 - eye).get_rotation_quaternion()
	var look := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look.tween_method(func(k: float): camera.global_basis = Basis(q0.slerp(q1, k)), 0.0, 1.0, 0.6)
	await look.finished
	await _wait(0.35)

	# --- warn: rumble first, then the asphalt cracks at the exact spot and the ground starts to heave
	_cue("rumble")
	Sfx.play("veil_rumble", ground + Vector3.UP * 0.3, 2.0, 1.2)
	world._shake(camera, 0.7, 0.012)
	await _wait(0.75)
	_cue("crack")
	world._ground_burst(ground)                          # the crack: one sound, chunks, a jolt
	mound = VeilTentacleMound.make(world, ground, int(ground.x * 13.0 + ground.z * 7.0), 0.12)
	var heave := create_tween()
	heave.tween_method(func(k: float): mound.grow(k), 0.12, 0.45, 0.55)
	await heave.finished

	# --- burst: the tip first, straight up; the body feeds through the same hole
	tentacle = TENTACLE.instantiate() as Node3D
	tentacle.name = "MistTentacle_Street"
	tentacle.set("autoplay", "")
	world.add_child(tentacle)
	var ap: AnimationPlayer = tentacle.call("get_animation_player") if tentacle.has_method("get_animation_player") else null
	if ap:
		ap.stop()
	var to_feet := (feet - ground) * Vector3(1, 0, 1)
	tentacle.global_position = ground
	tentacle.rotation.y = atan2(to_feet.x, to_feet.z)     # its +Z faces the player: lean > 0 bends towards them
	poser = VeilTentaclePoser.attach(tentacle)
	poser.set_all(0.0, 0.0)
	poser.apply()
	var length := poser.tip().distance_to(tentacle.global_position)
	report["length_m"] = length
	var y_up := ground.y - maxf(length - EXPOSED, 0.4)    # the root stays this far down in the hole
	tentacle.global_position = Vector3(ground.x, ground.y - length - 0.05, ground.z)   # the tip just under the street
	_cue("emerge")
	Sfx.bank_at("te_wet", ground + Vector3.UP * 0.5, 3.0, 8.0)
	var rise := create_tween()
	rise.tween_property(tentacle, "global_position:y", y_up, 1.25).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_method(func(k: float): mound.grow(k), 0.45, 1.0, 0.35)
	await rise.finished
	report["root_below_street_m"] = ground.y - tentacle.global_position.y

	# --- curl: the upper body sweeps round in a circle (in the plane facing the player), then turns to them
	await _morph(_arr(0.0, 0.92, 3), _arr(0.0, 0.0, 3), 0.85)
	await _morph(_arr(0.0, 0.0, 3), _arr(0.05, 0.2, 4), 0.55)
	report["emergence_s"] = (Time.get_ticks_msec() - _start_ms) / 1000.0

	# --- notice, coil back, lash across where the player stood
	await _wait(0.35)
	var hit_at := Vector3(feet.x, ground.y + 0.05, feet.z)
	var lash := _solve_lash(hit_at)                      # the forward bend that puts the tip on that spot
	report["lash_tip_error_m"] = lash[1]
	_morph(_arr(0.0, 0.0, 0), _arr(-0.04, -0.32, 4), 0.42)
	await _wait(0.25)
	# the sidestep starts as it draws back: out of the way before the tip arrives
	_cue("dodge")
	var dodge := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dodge.tween_property(camera, "global_position", stage.dodge, 0.3)
	dodge.parallel().tween_property(camera, "rotation:z", camera.rotation.z + float(stage.bank), 0.3)
	await _wait(0.17)
	_cue("lash")
	Sfx.bank_at("te_strike", tentacle.global_position + Vector3.UP * 2.0, 0.0, 8.0)
	await _morph(_arr(0.0, 0.0, 0), _arr(float(lash[2]), float(lash[0]), 4), 0.2, Tween.TRANS_QUAD, Tween.EASE_IN)
	_cue("impact")
	var tip := poser.tip()
	report["impact_to_spot_m"] = tip.distance_to(hit_at)
	report["camera_to_tip_m"] = camera.global_position.distance_to(tip)
	Sfx.bank_at("te_ground", hit_at, 2.0, 8.0)
	world._shake(camera, 0.22, 0.05)
	await _wait(0.35)

	# --- handoff: it rears up again, Eddie shouts, the view goes back to the player
	_morph(_arr(0.0, 0.0, 0), _arr(0.05, 0.12, 4), 0.5)
	_cue("eddie_run")
	Dialogue.say("p3_eddie_run", false, true)
	player.set_yaw_pitch(atan2(-exit_direction.x, -exit_direction.z), 0.0)
	var recover := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	recover.tween_property(camera, "global_transform", player.camera.global_transform, 0.38)
	await recover.finished
	player.camera.make_current()
	camera.queue_free()
	_cue("control")
	return true


## [upper bend, error, lower bend]: the per-bone forward bends of the upper body that brings the tip closest to `at`.
func _solve_lash(at: Vector3) -> Array:
	var keep_c := poser.curl.duplicate()
	var keep_l := poser.lean.duplicate()
	var best := [0.3, INF, 0.12]
	var lo := 0.0
	while lo <= 0.36:
		var s := 0.0
		while s <= 0.9:
			poser.curl = _arr(0.0, 0.0, 0)
			poser.lean = _arr(lo, s, 4)
			poser.apply()
			var e := poser.tip().distance_to(at)
			if e < float(best[1]):
				best = [s, e, lo]
			s += 0.02
		lo += 0.03
	poser.curl = keep_c
	poser.lean = keep_l
	poser.apply()
	return best


func _find_stage(player: VeilPlayer, feet: Vector3, eye: Vector3, forward: Vector3, reach: float) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var side := forward.cross(Vector3.UP).normalized()
	var distance := clampf(reach, 1.65, 3.3)
	for sign_value in [1.0, -1.0]:
		var sign_side: float = sign_value
		for angle in [0.35, 0.0, 0.75]:
			var base := feet + forward.rotated(Vector3.UP, angle * sign_side) * distance
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(base + Vector3.UP, base - Vector3.UP, 1))
			if hit.is_empty() or (hit.normal as Vector3).y < 0.75:
				continue
			var ground: Vector3 = hit.position
			var dodge := eye - side * sign_side * 0.70 - Vector3.UP * 0.52
			if not _clear_sweep(space, eye, dodge):
				continue
			if not _clear_sweep(space, eye, ground + Vector3.UP * 1.55):
				continue
			if not _clear_sweep(space, ground + Vector3.UP * 0.22, ground + Vector3.UP * 3.4):
				continue
			return {"ground": ground, "dodge": dodge, "bank": sign_side * 0.16}
	return {}


func _clear_sweep(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = CAMERA_MARGIN
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 4
	query.transform.origin = from
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.motion = to - from
	var travel := space.cast_motion(query)
	return travel.size() > 0 and travel[0] >= 0.999
