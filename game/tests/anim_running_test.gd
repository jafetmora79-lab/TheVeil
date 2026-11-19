extends SceneTree
const Run = preload("res://game/animation/running_pose.gd")
const RIGS = ["Protagonist/CHR_Protagonist.glb", "Commercial_NPCs/CHR_Eddie.glb", "Marcus/CHR_Marcus.glb"]
var failed := false
var max_floor_error := 0.0
var max_slide := 0.0
var max_loop := 0.0

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var script: Script = load("res://game/animation/running_pose.gd")
	check(script.can_instantiate(), "Running helper must instantiate")
	var preview_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-output="):
			preview_path = argument.trim_prefix("--preview-output=")
	var frames: Array = []
	for path in RIGS:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		check(doc.append_from_file("res://THE_VEIL_ASSETS_V2/06_Characters/" + path, state) == OK, "Load " + path)
		var model := doc.generate_scene(state)
		root.add_child(model)
		var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var f := skel.get_bone_global_rest(skel.find_bone("LeftToes")).origin - skel.get_bone_global_rest(skel.find_bone("LeftFoot")).origin
		f.y = 0.0
		f = f.normalized()
		var r := f.cross(Vector3.UP).normalized()
				# Use the same arms-down preparation as NpcAnimator._build_rest().
		for side in ["Left", "Right"]:
			var out := -1.0 if side == "Left" else 1.0
			lower_arm(skel, side + "UpperArm", side + "LowerArm", (-Vector3.UP * cos(deg_to_rad(9.0)) + r * out * sin(deg_to_rad(9.0)) + f * 0.04).normalized())
			lower_arm(skel, side + "LowerArm", side + "Hand", (-Vector3.UP * cos(deg_to_rad(12.0)) + f * sin(deg_to_rad(12.0)) + r * out * 0.03).normalized())
		var local_rests: Array[Basis] = []
		var rests: Array[Transform3D] = []
		for i in skel.get_bone_count():
			rests.append(skel.get_bone_global_pose(i))
			local_rests.append(Basis(skel.get_bone_pose_rotation(i)))
		var hip := rests[skel.find_bone("LeftUpperLeg")].origin
		var knee := rests[skel.find_bone("LeftLowerLeg")].origin
		var ankle := rests[skel.find_bone("LeftFoot")].origin
		var a := hip.distance_to(knee)
		var b := knee.distance_to(ankle)
		var upper_angle := atan2((knee - hip).dot(f), hip.y - knee.y)
		var lower_angle := atan2((ankle - knee).dot(f), knee.y - ankle.y)
		var neutral := Vector3(upper_angle, lower_angle - upper_angle, (ankle - hip).dot(f))
		var output := {}
		var start := {}
		var contact_origins := {}
		for frame in 241:
			var phase := TAU * frame / 240.0
			Run.sample(phase, 1.0, Run.BONES, f, Vector3.UP, r, a, b, hip.y - ankle.y, neutral, output)
			skel.position.y = Run.bounce(phase, 1.0)
			for name in output:
				var q: Quaternion = output[name]
				check(q.is_finite() and absf(q.length() - 1.0) < 0.0001, "Finite normalized rotation " + name)
				var index := skel.find_bone(name)
				if index < 0:
					continue
				var parent := skel.get_bone_parent(index)
				var pb := rests[parent].basis if parent >= 0 else Basis.IDENTITY
				skel.set_bone_pose_rotation(index, (pb.inverse() * Basis(q) * pb * local_rests[index]).get_rotation_quaternion())
				if frame == 0:
					start[name] = q
				if frame == 240:
					max_loop = maxf(max_loop, q.angle_to(start[name]))
			for side_i in 2:
				var side := "Left" if side_i == 0 else "Right"
				var p := phase + side_i * PI
				var target := Run.foot_target(p)
				var t := fposmod(p / TAU, 1.0)
				var knee_q: Quaternion = output[side + "LowerLeg"]
				check(knee_q.get_angle() <= deg_to_rad(155.0), "Knee flexion limit")
				check(output[side + "UpperLeg"].get_angle() <= deg_to_rad(100.0), "Hip flexion limit")
				check(output[side + "LowerArm"].get_angle() <= deg_to_rad(100.0), "Elbow flexion limit")
				if t < Run.CONTACT:
					for end in ["Foot", "Toes"]:
						var index := skel.find_bone(side + end)
						var pos := skel.get_bone_global_pose(index).origin + skel.position
						max_floor_error = maxf(max_floor_error, absf(pos.y - rests[index].origin.y))
					var actual := skel.get_bone_global_pose(skel.find_bone(side + "Foot")).origin
					var world_x := actual.dot(f) + phase / TAU * Run.STRIDE
					var key := side + str(int(floor(p / TAU)))
					if not contact_origins.has(key):
						contact_origins[key] = world_x
					max_slide = maxf(max_slide, absf(world_x - contact_origins[key]))
			if not preview_path.is_empty() and path == RIGS[0] and frame % 4 == 0:
				var bones: Array = []
				for i in skel.get_bone_count():
					var pos := skel.get_bone_global_pose(i).origin + skel.position
					bones.append([pos.x, pos.y, pos.z])
				var surfaces: Array = []
				for mesh in model.find_children("*", "MeshInstance3D", true, false):
					if mesh.skin == null:
						continue
					for surface in mesh.mesh.get_surface_count():
						var arrays: Array = mesh.mesh.surface_get_arrays(surface)
						var vertices: Array = []
						for v in arrays[Mesh.ARRAY_VERTEX].size():
							var pos := Vector3.ZERO
							for influence in 4:
								var joint: int = arrays[Mesh.ARRAY_BONES][v * 4 + influence]
								var bone: int = mesh.skin.get_bind_bone(joint)
								if bone < 0:
									bone = skel.find_bone(mesh.skin.get_bind_name(joint))
								pos += (skel.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(joint) * arrays[Mesh.ARRAY_VERTEX][v]) * arrays[Mesh.ARRAY_WEIGHTS][v * 4 + influence]
							pos += skel.position
							vertices.append([pos.x, pos.y, pos.z])
						var mat: StandardMaterial3D = mesh.mesh.surface_get_material(surface)
						var colors: Array = []
						var tex: Image = mat.albedo_texture.get_image() if mat.albedo_texture else null
						for index in arrays[Mesh.ARRAY_INDEX]:
							var color := mat.albedo_color
							if tex:
								var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][index]
								color *= tex.get_pixel(int(fposmod(uv.x, 1.0) * tex.get_width()), int(fposmod(uv.y, 1.0) * tex.get_height()))
							colors.append([color.r, color.g, color.b])
						surfaces.append({"vertices": vertices, "indices": Array(arrays[Mesh.ARRAY_INDEX]), "colors": colors})
				frames.append(surfaces)
		# Zero-weight output must be neutral, even outside the valid weight range.
		Run.sample(0.8, -1.0, Run.BONES, f, Vector3.UP, r, a, b, hip.y - ankle.y, neutral, output)
		for q in output.values():
			check(q.is_equal_approx(Quaternion.IDENTITY), "Zero weight")
		print("Rig tested: ", path)
		model.free()
	check(max_floor_error <= 0.02, "Planted rig feet/toes exceed 2 cm")
	check(max_slide <= 0.02, "Planted rig foot slides more than 2 cm")
	check(max_loop <= 0.001, "Loop mismatch")
	if not preview_path.is_empty():
		var dump := FileAccess.open(preview_path, FileAccess.WRITE)
		check(dump != null, "Preview output writable")
		if dump:
			dump.store_string(JSON.stringify(frames))
			dump.close()
	print("RESULT floor_error_m=", max_floor_error, " rig_slide_m=", max_slide, " loop_rad=", max_loop)
	quit(1 if failed else 0)

func lower_arm(skel: Skeleton3D, from: String, to: String, direction: Vector3) -> void:
	var i := skel.find_bone(from)
	var child := skel.find_bone(to)
	var current := (skel.get_bone_global_pose(child).origin - skel.get_bone_global_pose(i).origin).normalized()
	var parent := skel.get_bone_parent(i)
	var pb := skel.get_bone_global_pose(parent).basis.orthonormalized()
	var rotation := Quaternion(current, direction)
	skel.set_bone_pose_rotation(i, (pb.inverse() * Basis(rotation) * pb * Basis(skel.get_bone_pose_rotation(i))).get_rotation_quaternion())
