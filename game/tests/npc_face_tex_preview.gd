extends SceneTree
## dev tool (needs a window): close-ups of each NPC's face-texture expressions in Godot 4.3 Compatibility (nearest filter, film grain layer).
##   godot --path . --resolution 420x420 --script res://game/tests/npc_face_tex_preview.gd -- <out_dir> <slug> [<slug> ...]


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(args: PackedStringArray) -> void:
	var out := args[0]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.58)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 160, 0)
	sun.light_energy = 1.0
	root.add_child(sun)
	var fx := CanvasLayer.new()
	fx.layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://game/ui/screen_fx.gdshader")
	sm.set_shader_parameter("grain", 0.012)
	rect.material = sm
	fx.add_child(rect)
	root.add_child(fx)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 11.0
	for si in range(1, args.size()):
		var slug := args[si]
		var n := VeilNpcFaceTex.instantiate(slug)
		root.add_child(n)
		await process_frame
		var sk := VeilSarahMeshyProto.skeleton(n)
		var hp: Vector3 = sk.global_transform * sk.get_bone_global_rest(sk.find_bone("Head")).origin
		cam.position = Vector3(hp.x, hp.y + 0.07, hp.z - 2.3)
		cam.look_at(Vector3(hp.x, hp.y + 0.065, hp.z))
		var f := n.get_node("FaceTex") as VeilNpcFaceTex
		f.auto_blink = false
		var k := 0
		for st in [["neutral", "neutral", false, false], ["blink", "neutral", true, false], ["talk_small", "neutral", false, true], ["scared", "scared", false, false], ["angry", "angry", false, false], ["worried", "worried", false, false]]:
			f.talking = false
			f._blink_left = 0.0
			f.expression = st[1]
			if st[3]:
				f.talking = true
				f._talk_i = 0
				f._talk_t = 9.0
			if st[2]:
				f.blink(5.0)
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%d_%s.png" % [out, slug, k, st[0]])
			k += 1
		n.queue_free()
		await process_frame
	quit(0)
