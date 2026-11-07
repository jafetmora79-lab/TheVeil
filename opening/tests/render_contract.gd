extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://opening/opening.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var original: Dictionary = {}
	for node in scene.get_node("World").find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or node.skin != null or node.mesh.get_blend_shape_count() > 0:
			continue
		original[node.get_instance_id()] = node.mesh
	var count: int = scene._prepare_static_meshes()
	var valid := count > 1000
	for node in scene.get_node("World").find_children("*", "MeshInstance3D", true, false):
		if not original.has(node.get_instance_id()): continue
		var before: Mesh = original[node.get_instance_id()]
		var after: Mesh = node.mesh
		valid = valid and before.get_surface_count() == after.get_surface_count()
		for surface in range(before.get_surface_count()):
			valid = valid and not bool(after.surface_get_format(surface) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
			valid = valid and before.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] == after.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			valid = valid and before.surface_get_material(surface) == after.surface_get_material(surface)
	var environment: WorldEnvironment = scene.get_node("World/Greyhaven_Town/Environment/WorldEnvironment")
	valid = valid and not environment.environment.fog_enabled
	print("RENDER_CONTRACT: ", "PASS" if valid else "FAIL", " • static instances: ", count)
	quit(0 if valid else 1)
