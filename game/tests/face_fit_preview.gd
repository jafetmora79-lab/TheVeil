extends SceneTree
## Close-ups of a Mixamo model's expression faces (VeilFaceFit) next to the old model's. Needs a window.
##   godot --path . --resolution 640x360 --script res://game/tests/face_fit_preview.gd -- <out_dir> <slug> [scale=0.9] [dr=0] [du=0]
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var slug: String = a[1]
	var ov := {}
	for e in a:
		if String(e).begins_with("scale="): ov["scale"] = float(String(e).substr(6))
		if String(e).begins_with("dr="): ov["dr"] = float(String(e).substr(3))
		if String(e).begins_with("du="): ov["du"] = float(String(e).substr(3))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.25)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-20, 0, 0)
	root.add_child(sun)
	var nodes := []
	for k in 2:
		var holder := Node3D.new()
		root.add_child(holder)
		var m: Node3D
		var ctrl: VeilNpcFaceTex
		if k == 0:
			m = VeilNpcFaceTex.instantiate(slug)
			ctrl = m.get_node("FaceTex")
		else:
			m = (load("res://game/prototypes/npc_meshy/CHR_%s_Mixamo.glb" % slug) as PackedScene).instantiate()
			VeilSarahMeshyProto.psx_look(m)
			print("fit ok ", VeilFaceFit.apply(m, slug, ov))
			ctrl = VeilNpcFaceTex.new()
			ctrl.slug = slug
			m.add_child(ctrl)
			print("controller setup ", ctrl.setup(m))
		ctrl.auto_blink = false
		holder.add_child(m)
		holder.position.x = -0.25 + 0.5 * k
		nodes.append([holder, ctrl, m])
	var cam := Camera3D.new()
	cam.fov = 20.0
	root.add_child(cam)
	# the heads face +Z (old) or -Z (new): the camera looks from the side the face is on
	var vps := {}
	for k in 2:
		pass
	var states := ["neutral", "scared", "talk_wide", "angry"]
	for st in states:
		for nd in nodes:
			var c: VeilNpcFaceTex = nd[1]
			if st.begins_with("talk"):
				c.expression = "neutral"
			else:
				c.expression = st
			c.state = st
			c._apply()
		for k in 2:
			var h: Node3D = nodes[k][0]
			var sk := (nodes[k][2] as Node3D).find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var hb := sk.find_bone("Head" if k == 0 else "mixamorig_Head")
			var hp := sk.global_transform * sk.get_bone_global_pose(hb).origin
			var lu := sk.get_bone_global_pose(sk.find_bone("LeftUpperLeg" if k == 0 else "mixamorig_LeftUpLeg")).origin
			var ru := sk.get_bone_global_pose(sk.find_bone("RightUpperLeg" if k == 0 else "mixamorig_RightUpLeg")).origin
			var rgt: Vector3 = sk.global_transform.basis * (ru - lu)
			rgt.y = 0.0
			var fwd: Vector3 = Vector3.UP.cross(rgt.normalized()).normalized()
			cam.global_position = hp + fwd * 1.6 + Vector3(0, 0.08, 0)
			cam.look_at(hp + Vector3(0, 0.07, 0), Vector3.UP)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, st, k])
	print("RESULT done")
	quit(0)
