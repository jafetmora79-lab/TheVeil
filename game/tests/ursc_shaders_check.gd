extends SceneTree
## THE VEIL - every URSC shader compiles on the real GL renderer (Compatibility). NOT a headless test: the dummy
## renderer compiles nothing. Run it through tools/check_ursc_shaders.sh (xvfb + software GL). Compile only.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths: Array = []
	var stack: Array = ["res://addons/ursc"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gdshader"):
				paths.append(d + "/" + f)
		for sd in DirAccess.get_directories_at(d):
			stack.append(d + "/" + sd)
	paths.sort()
	var holder := Node3D.new()
	root.add_child(holder)
	var n := 0
	for p in paths:
		var sh := load(p) as Shader
		if sh == null:
			print("URSC ", p, " LOAD_FAILED")
			continue
		var m := ShaderMaterial.new()
		m.shader = sh
		if sh.get_mode() == Shader.MODE_SPATIAL:
			var mi := MeshInstance3D.new()
			mi.mesh = QuadMesh.new()
			mi.material_override = m
			holder.add_child(mi)
		else:
			var cr := ColorRect.new()
			cr.material = m
			cr.size = Vector2(16, 16)
			root.add_child(cr)
		n += 1
	for i in 20:
		await process_frame
	print("URSC shaders loaded: ", n)
	quit(0)
