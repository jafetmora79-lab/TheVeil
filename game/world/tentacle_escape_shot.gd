extends Node3D
## A short first-person near miss at the game shop exit. The street enemies keep their usual behaviour afterward.
const TENTACLE := preload("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn")
const CAMERA_MARGIN := 0.16

func play(world: Node) -> bool:
	var player: VeilPlayer = world.player
	var eye := player.camera.global_position
	var feet := player.global_position
	var exit_direction: Vector3 = world.market.to_global(Vector3.ZERO) - feet
	exit_direction.y = 0.0
	exit_direction = exit_direction.normalized()
	if exit_direction.is_zero_approx():
		return false
	var tentacle := TENTACLE.instantiate() as Node3D
	add_child(tentacle)
	var timing := TentacleAI.new()
	tentacle.add_child(timing)
	timing.set_process(false)
	var animation: AnimationPlayer = tentacle.get_animation_player()
	var stage := _find_stage(player, feet, eye, exit_direction, timing.reach)
	if stage.is_empty():
		return false

	tentacle.global_position = stage.ground
	tentacle.rotation.y = timing._yaw_to(feet)
	var camera := Camera3D.new()
	camera.near = player.camera.near
	camera.far = player.camera.far
	camera.fov = player.camera.fov
	add_child(camera)
	camera.global_transform = player.camera.global_transform
	camera.make_current()

	var start_rotation := camera.global_basis.get_rotation_quaternion()
	var target: Vector3 = stage.ground + Vector3.UP * 1.55
	var look_rotation := Basis.looking_at(target - eye).get_rotation_quaternion()
	tentacle.emerge()
	Sfx.play("tentacle_hiss", target, -4.0, 0.8)
	var look := create_tween()
	look.tween_method(func(weight: float):
		camera.global_basis = Basis(start_rotation.slerp(look_rotation, weight)), 0.0, 1.0, 0.28)
	look.tween_interval(clampf(animation.get_animation("Emerge").length - 0.28, 0.1, 1.1))
	await look.finished

	tentacle.play("Coil", 0.12)
	await get_tree().create_timer(0.32, false).timeout
	tentacle.play("Strike", 0.05)
	var dodge_time := clampf(timing.contact_time, 0.10, 0.85)
	var dodge := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dodge.tween_property(camera, "global_position", stage.dodge, dodge_time * 0.9)
	dodge.parallel().tween_property(camera, "rotation:z", camera.rotation.z + stage.bank, dodge_time * 0.9)
	await dodge.finished
	await get_tree().create_timer(0.10 + dodge_time * 0.10, false).timeout
	Sfx.play("tentacle_hiss", target, -1.0, 1.3)

	# Finish facing the escape route and blend back to the real player view at the same feet position.
	player.set_yaw_pitch(atan2(-exit_direction.x, -exit_direction.z), 0.0)
	var recover := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	recover.tween_property(camera, "global_transform", player.camera.global_transform, 0.42)
	recover.parallel().tween_property(tentacle, "visibility", 0.0, 0.42)
	await recover.finished
	player.camera.make_current()
	return true


func _find_stage(player: VeilPlayer, feet: Vector3, eye: Vector3, forward: Vector3, reach: float) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var side := forward.cross(Vector3.UP).normalized()
	var distance := clampf(reach * 0.72, 1.65, 3.3)
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
			if not _clear_sweep(space, ground + Vector3.UP * 0.22, ground + Vector3.UP * 2.6):
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
