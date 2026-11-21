extends SceneTree
## Dev probe for review notes #2-#5 (the player's home): chair directions, curtains vs windows, what is outside the window, the roof coming through the ceiling.
func _initialize() -> void:
	_run.call_deferred()
func mesh_top_dir(mi: MeshInstance3D) -> Vector3:
	# the direction (world, horizontal) from the chair's middle to its high part = where the backrest is
	var m := mi.mesh
	var hi := -1e9
	var all: Array = []
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in vs:
			var w := mi.global_transform * v
			all.append(w)
			hi = maxf(hi, w.y)
	var c := Vector3.ZERO
	for w in all: c += w
	c /= maxf(all.size(), 1)
	var top := Vector3.ZERO
	var n := 0
	for w in all:
		if w.y > hi - 0.25:
			top += w
			n += 1
	top /= maxf(n, 1)
	var d := (top - Vector3(c.x, top.y, c.z)) * Vector3(1, 0, 1)
	return d
func _run() -> void:
	var game = root.get_node("Game")
	game.new_game()
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 90: await process_frame
	var home: Node = w.get_node("Residential/Houses/PLAYER_HOME")
	var table := home.find_child("DiningTable_Round_01", true, false) as Node3D
	print("PROBE table ", table.global_position if table else null)
	for ch in home.find_children("*Chair*", "Node3D", true, false):
		if not (ch is Node3D) or ch.get_child_count() == 0: continue
		var mi := ch.find_child("*Mesh", true, false) as MeshInstance3D
		if mi == null: continue
		var back := mesh_top_dir(mi)
		var to_table: Vector3 = (table.global_position - ch.global_position) * Vector3(1, 0, 1)
		print("PROBE chair ", ch.name, " pos ", ch.global_position, " yaw_deg ", rad_to_deg(ch.global_rotation.y), " back_dir ", back.normalized(), " to_table ", to_table.normalized(), " dot(back,to_table) ", snappedf(back.normalized().dot(to_table.normalized()), 0.01))
	for cu in home.find_children("*Curtain*", "Node3D", true, false):
		if cu.get_child_count() == 0: continue
		print("PROBE curtain ", cu.name, " pos ", cu.global_position, " yaw ", snappedf(rad_to_deg(cu.global_rotation.y), 0.1), " scale ", cu.scale)
		var mi2 := cu.find_child("*Mesh", true, false) as MeshInstance3D
		if mi2:
			var bb := mi2.global_transform * mi2.get_aabb()
			print("PROBE   curtain aabb pos ", bb.position, " size ", bb.size)
	for win in home.find_children("*Window*", "Node3D", true, false):
		if win.get_child_count() == 0: continue
		print("PROBE window ", win.name, " pos ", win.global_position, " yaw ", snappedf(rad_to_deg(win.global_rotation.y), 0.1))
	var ext3 := home.get_node("House/RES_PlayerHome").find_child("RES_PlayerHome_Exterior", true, false) as MeshInstance3D
	for sx in ext3.mesh.get_surface_count():
		var mt := ext3.mesh.surface_get_material(sx)
		if mt == null or mt.resource_name != "M_Arch_BrickRed": continue
		var arr := ext3.mesh.surface_get_arrays(sx)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := Vector3(-1e9, -1e9, -1e9)
		for v in vs:
			var q: Vector3 = ext3.global_transform * v
			mn = mn.min(q)
			mx = mx.max(q)
		print("PROBE brick surface bounds ", mn, " .. ", mx)
	for n in home.get_parent().get_parent().find_children("*Chimney*", "Node3D", true, false):
		print("PROBE chimney node ", n.get_path(), " ", (n as Node3D).global_position)
	quit()
