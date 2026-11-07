extends RefCounted
## Instance-only corrections for the existing FP mesh. The shipped GLB has no finger bones.
## Keep the wrist blend, bind the distal palm to its hand, and bend existing finger vertices
## continuously about their shared knuckle line using one inexpensive blend shape.
const SIDES := ["Left", "Right"]

static func prepare(model: Node3D, sk: Skeleton3D) -> void:
	var frames := {}
	var meshes: Array[MeshInstance3D] = []
	for side in SIDES:
		var hand := sk.find_bone(side + "Hand")
		var socket := sk.find_bone("Socket_" + side + "Hand")
		var rest := sk.get_bone_global_rest(hand)
		var fingers := (sk.get_bone_global_rest(socket).origin - rest.origin).normalized()
		# Measured broad palm face on the shipped low-poly FP mesh, in hand-bone space.
		var normal := Vector3(0.83585 if side == "Left" else -0.83585, 0.02471, -0.54840).normalized()
		var palm := rest.basis * normal
		palm = (palm - fingers * palm.dot(fingers)).normalized()
		frames[side] = {"hand": hand, "fingers": fingers, "palm": palm,
			"across": fingers.cross(palm).normalized(), "bounds": AABB(), "bounds_ready": false}
	model.set_meta("wash_frames", frames)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.skin == null:
			continue
		var original := mesh_node.mesh
		var mesh := ArrayMesh.new()
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		mesh.add_blend_shape("WashCurl")
		for surface in original.get_surface_count():
			var arrays := original.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bent := vertices.duplicate()
			var bent_normals := normals.duplicate()
			for i in vertices.size():
				for side in SIDES:
					var frame: Dictionary = frames[side]
					var slot := -1
					for influence in 4:
						var bind := bones[i * 4 + influence]
						if mesh_node.skin.get_bind_name(bind) == side + "Hand" and weights[i * 4 + influence] > 0.01:
							slot = influence
							break
					if slot < 0:
						continue
					var rest := sk.get_bone_global_rest(int(frame["hand"]))
					var offset := vertices[i] - rest.origin
					var along := offset.dot(frame["fingers"])
					if surface == 2:
						var local := rest.affine_inverse() * vertices[i]
						frame["bounds"] = (frame["bounds"] as AABB).expand(local) if frame["bounds_ready"] else AABB(local, Vector3.ZERO)
						frame["bounds_ready"] = true
					# Skin material only. Sleeves/cuffs retain their original weights.
					if surface == 2 and along > -0.025:
						var keep := 1.0 - smoothstep(-0.025, 0.005, along)
						var total := 0.0
						for influence in 4:
							weights[i * 4 + influence] *= keep
							total += weights[i * 4 + influence]
						weights[i * 4 + slot] += 1.0 - total
					if along > 0.075:
						var hinge: Vector3 = rest.origin + frame["fingers"] * 0.075
						var angle := deg_to_rad(5.0) * smoothstep(0.075, 0.13, along)
						var rotation := Basis(frame["across"], angle)
						bent[i] = hinge + rotation * (vertices[i] - hinge)
						bent_normals[i] = rotation * normals[i]
					break
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			var shape: Array = []
			shape.resize(Mesh.ARRAY_MAX)
			shape[Mesh.ARRAY_VERTEX] = bent
			shape[Mesh.ARRAY_NORMAL] = bent_normals
			if arrays[Mesh.ARRAY_TANGENT] != null:
				shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape])
			mesh.surface_set_material(surface, original.surface_get_material(surface))
		mesh_node.mesh = mesh
		meshes.append(mesh_node)
	model.set_meta("wash_meshes", meshes)
