extends SceneTree
## Godot 4.3 --headless --fixed-fps 60 --script res://game/tests/handwash_test.gd
var failures := 0
var wet_frames := 0
var dry_frames := 0
var hand_frames := 0
var max_contact_error := 0.0
var min_hand_gap := INF
var world: Node
var checked_mesh := false
var previous_rotations := {}
var max_wrist_step := 0.0
var furthest_hand := -INF
var max_reach := 0.0

func check(label: String, ok: bool) -> void:
	print("TEST ", label, " ", "PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game := root.get_node("Game")
	game.new_game()
	root.get_node("Dialogue").auto_confirm = true
	world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	for i in 3000:
		await process_frame
		var cam := world.get_node_or_null("WashFaceCam") as Camera3D
		if cam:
			for arms in cam.get_children():
				if arms.has_meta("sk") and arms.visible:
					inspect(arms, cam)
		if game.has_flag("washed_face"):
			break
	check("wash_completes", game.has_flag("washed_face"))
	check("player_control_and_camera_restored", world.player.controls_enabled and world.player.look_enabled and world.player.is_physics_processing()
		and root.get_viewport().get_camera_3d() == world.player.camera)
	check("chapter1_still_kitchen_objective", game.current_step().get("id", "") == "check_kitchen" and game.chapter_number() == 1)
	check("both_hands_sampled", hand_frames > 120)
	check("hands_separate", min_hand_gap > 0.09)
	check("wrist_turns_are_smooth", max_wrist_step < 0.25)
	check("whole_hands_clear_wall", furthest_hand <= world.bathroom.WALL_R - 0.024)
	check("arm_extension_limited", max_reach <= 1.55)
	check("water_meets_hands", wet_frames > 15)
	check("spray_stops_outside_water", dry_frames > 15)
	check("contact_stays_on_stream", max_contact_error <= 0.0071)
	await create_timer(1.0).timeout
	check("tap_and_spray_cleanup", world.bathroom.find_children("TapWater", "", true, false).is_empty())
	print("METRICS hand_frames=",hand_frames," wet=",wet_frames," dry=",dry_frames," min_wrist_gap=",min_hand_gap," contact_error=",max_contact_error," max_wrist_step_rad=",max_wrist_step," hand_max_x=",furthest_hand," reach=",max_reach)
	world.free()
	print("RESULT ",failures," failures")
	quit(1 if failures else 0)

func inspect(arms: Node3D, cam: Camera3D) -> void:
	hand_frames += 1
	var sk: Skeleton3D = arms.get_meta("sk")
	for side in ["Left", "Right"]:
		var pose: Transform3D = arms.get_meta("posed_" + side)
		var frame: Dictionary = arms.get_meta("wash_frames")[side]
		var bounds: AABB = (world.home.global_transform.affine_inverse() * sk.global_transform * pose) * (frame["bounds"] as AABB).grow(0.008)
		furthest_hand = maxf(furthest_hand, bounds.end.x)
		max_reach = maxf(max_reach, arms.get_meta("reach_" + side))
		var rotation := pose.basis.get_rotation_quaternion()
		if previous_rotations.has(side):
			max_wrist_step = maxf(max_wrist_step, rotation.angle_to(previous_rotations[side]))
		previous_rotations[side] = rotation
		if not pose.is_finite() or absf(pose.basis.determinant() - 1.0) > 0.001:
			failures += 1
	var left: Transform3D = arms.get_meta("posed_Left")
	var right: Transform3D = arms.get_meta("posed_Right")
	min_hand_gap = minf(min_hand_gap, left.origin.distance_to(right.origin))
	var spray: CPUParticles3D = arms.get_meta("splashes")
	var tap: Vector3 = arms.get_meta("tap")
	if spray.emitting:
		wet_frames += 1
		max_contact_error = maxf(max_contact_error, Vector2(spray.global_position.x-tap.x,spray.global_position.z-tap.z).length())
	else:
		dry_frames += 1
	if not checked_mesh:
		checked_mesh = true
		for mi in arms.get_meta("wash_meshes"):
			check("existing_mesh_has_small_curl", mi.mesh.get_blend_shape_count() == 1)
			var arrays: Array = mi.mesh.surface_get_arrays(2)
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var fixed := 0
			for i in verts.size():
				for k in 4:
					var name: String = mi.skin.get_bind_name(bones[i*4+k])
					if name in ["LeftHand", "RightHand"] and weights[i*4+k] > 0.01:
						var frame: Dictionary = arms.get_meta("wash_frames")[name.trim_suffix("Hand")]
						var offset := verts[i] - sk.get_bone_global_rest(int(frame["hand"])).origin
						if offset.dot(frame["fingers"]) > 0.005:
							if weights[i*4+k] < 0.999:
								failures += 1
							fixed += 1
			check("palms_follow_hand_without_forearm_stretch", fixed > 100)
