extends SceneTree
## Renders the flat-lit front crop of each Mixamo-rigged NPC's face (1000 x 1000, black background, 0.30 m square) for the ChatGPT expression kit. Needs a window.
##   godot --path . --resolution 1000x1000 --script res://game/tools/render_face_kit.gd -- <out_dir>
## head-local eye centre (right, up) in metres where known; others are framed at the default.
const EYES := {"eddie": [0.0106, 0.0503], "bearded_man": [0.0036, 0.0597], "police_officer": [0.0034, 0.1172]}
const SIZES := {"police_redhair": 0.34, "teen_blue_jacket": 0.34, "store_clerk": 0.34, "police_cap": 0.36, "elderly_woman": 0.34}   ## metres across the crop (default 0.30)
const SLUGS := ["eddie", "bearded_man", "police_officer", "tan_jacket", "bomber", "police_redhair", "teen_blue_jacket", "store_clerk", "police_cap", "elderly_woman"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var vp := SubViewport.new()
	vp.size = Vector2i(1000, 1000)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	env.environment = e
	vp.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.30
	cam.far = 10.0
	vp.add_child(cam)
	var proj := {}
	for slug in SLUGS:
		var m := (load("res://game/prototypes/npc_meshy/CHR_%s_Mixamo.glb" % slug) as PackedScene).instantiate() as Node3D
		vp.add_child(m)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mm := mi as MeshInstance3D
			var src := mm.get_active_material(0)
			if src is BaseMaterial3D:
				var d := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
				mm.set_surface_override_material(0, d)
		var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var lu := sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftUpLeg")).origin
		var ru := sk.get_bone_global_pose(sk.find_bone("mixamorig_RightUpLeg")).origin
		var rg := ru - lu
		rg.y = 0.0
		var rv := rg.normalized()
		var fv := Vector3.UP.cross(rv).normalized()
		var hp := sk.get_bone_global_pose(sk.find_bone("mixamorig_Head")).origin
		var eye: Array = EYES.get(slug, [0.0, 0.085])
		cam.size = float(SIZES.get(slug, 0.30))
		var centre := hp + rv * float(eye[0]) + Vector3.UP * (float(eye[1]) - 0.012)
		cam.global_position = centre + fv * 1.0
		cam.look_at(centre, Vector3.UP)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s_face_base_1000.png" % [out, slug])
		proj[slug] = {"centre_r": float(eye[0]), "centre_u": float(eye[1]) - 0.012, "size": cam.size}
		print("RENDERED ", slug)
		m.queue_free()
		await process_frame
	var pf := FileAccess.open("%s/kit_projection.json" % out, FileAccess.WRITE)
	pf.store_string(JSON.stringify(proj, "  "))
	pf.close()
	print("RESULT done")
	quit(0)
