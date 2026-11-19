extends SceneTree
## Experiment check (headless): the geometric face shape keys arrive in Godot 4.3 as blend shapes and move vertices.
##   godot --headless --path . --script res://game/tests/protagonist_face_geo_test.gd
func _initialize() -> void:
	var ps := load("res://creatures/humans/protagonist/face_geo/protagonist_face_geo.glb") as PackedScene
	if ps == null:
		print("RESULT FAIL (glb not loaded)")
		quit(1)
		return
	var n := ps.instantiate()
	root.add_child(n)
	var mi: MeshInstance3D
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh.get_blend_shape_count() > 0:
			mi = m
	var names := []
	for i in mi.mesh.get_blend_shape_count():
		names.append(String(mi.mesh.get_blend_shape_name(i)))
	print("BLENDSHAPES ", names)
	var ok := names.has("blink") and names.has("talk_small") and names.has("talk_wide")
	var base_aabb := mi.get_aabb()
	mi.set("blend_shapes/blink", 1.0)
	print("RESULT ", "PASS" if ok else "FAIL", " verts mesh surfaces=", mi.mesh.get_surface_count())
	quit(0 if ok else 1)
