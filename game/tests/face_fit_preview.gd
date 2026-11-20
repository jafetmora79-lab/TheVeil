extends SceneTree
## Close-ups of a Mixamo model's expression faces (movable brows + VeilFaceFit), identical camera and light for every state. Needs a window.
##   godot --path . --resolution 640x360 --script res://game/tests/face_fit_preview.gd -- <out_dir> <slug>
## Saves <state>.png for neutral, scared, angry, worried, blink, talk_small, talk_wide.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var slug: String = a[1]
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
	var m := VeilMeshyNpcs.model_for({"eddie": "Eddie", "eddie_v2": "Eddie", "bearded_man": "Marcus", "police_officer": "Officer"}[slug])
	root.add_child(m)
	var ctrl := m.get_node("FaceTex") as VeilNpcFaceTex
	ctrl.auto_blink = false
	var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var lu := sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftUpLeg")).origin
	var ru := sk.get_bone_global_pose(sk.find_bone("mixamorig_RightUpLeg")).origin
	var rgt := ru - lu
	rgt.y = 0.0
	var fwd := Vector3.UP.cross(rgt.normalized()).normalized()
	var hp: Vector3 = sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")).origin
	var cam := Camera3D.new()
	cam.fov = 20.0
	root.add_child(cam)
	cam.global_position = hp + fwd * 1.6 + Vector3(0, 0.08, 0)
	cam.look_at(hp + Vector3(0, 0.07, 0), Vector3.UP)
	for st in ["neutral", "scared", "angry", "worried", "blink", "talk_small", "talk_wide"]:
		ctrl.expression = st if st in ["scared", "angry", "worried"] else "neutral"
		ctrl.talking = st.begins_with("talk")
		ctrl._blink_left = 5.0 if st == "blink" else 0.0
		if st.begins_with("talk"):
			ctrl._talk_i = 0 if st == "talk_small" else 1
			ctrl._talk_t = 99.0
		ctrl._apply()
		for i in 40:                                              # the brows ease in
			await process_frame
		ctrl._blink_left = 5.0 if st == "blink" else 0.0
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, st])
	print("RESULT done")
	quit(0)
