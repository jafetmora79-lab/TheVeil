extends SceneTree
func _initialize() -> void:
	var scene := (load("res://THE_VEIL_ASSETS_V2/04_Commercial/Merchandise/COM_Merch_Library.glb") as PackedScene).instantiate()
	root.add_child(scene)
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb := m.get_aabb()
		var mats: Array = []
		for i in m.mesh.get_surface_count():
			var mt := m.mesh.surface_get_material(i)
			mats.append(mt.resource_name if mt else "-")
		print("PROBE ", m.name, " size ", snapped(bb.size.x, 0.001), "x", snapped(bb.size.y, 0.001), "x", snapped(bb.size.z, 0.001), " min_y ", snapped(bb.position.y, 0.001), " centre_xz ", snapped(bb.get_center().x, 0.001), ",", snapped(bb.get_center().z, 0.001), " ", mats)
	quit()
