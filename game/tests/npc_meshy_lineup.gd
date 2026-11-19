extends SceneTree
## dev tool (needs a window): a line-up of the five Meshy NPCs in Godot 4.3 Compatibility, each in a different clip, then all walking.
##   godot --path . --fixed-fps 24 --resolution 960x540 --script res://game/tests/npc_meshy_lineup.gd -- <out_dir>
const DT := 1.0 / 24.0


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args()[0])


func _run(out: String) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.25)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.58)
	e.fog_enabled = true
	e.fog_light_color = Color(0.3, 0.32, 0.35)
	e.fog_density = 0.02
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 160, 0)
	sun.light_energy = 1.0
	root.add_child(sun)
	var fl := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(40, 40)
	fl.mesh = pl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.22, 0.24)
	fm.roughness = 1.0
	fl.material_override = fm
	root.add_child(fl)
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
	cam.fov = 36.0
	cam.position = Vector3(0, 1.15, -6.4)
	cam.look_at(Vector3(0, 0.95, 0))
	var clips := ["idle", "walk", "nervous_idle", "injured_idle", "scared_reaction"]
	var nodes := []
	var aps := []
	for i in VeilNpcMeshy.SLUGS.size():
		var n := VeilNpcMeshy.instantiate(VeilNpcMeshy.SLUGS[i])
		root.add_child(n)
		n.position = Vector3(float(i - 2) * 1.15, 0, 0)
		var ap := VeilSarahMeshyProto.anim_player(n)
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		ap.play(clips[i])
		nodes.append(n)
		aps.append(ap)
	# still: each in a different clip
	for k in 40:
		for ap in aps:
			ap.advance(DT)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/lineup_clips.png")
	# walking toward the camera, all five (each at its own planted-foot speed)
	for i in nodes.size():
		var slug: String = VeilNpcMeshy.SLUGS[i]
		(nodes[i] as Node3D).position = Vector3(float(i - 2) * 1.15, 0, 3.0)
		aps[i].play("walk")
	var frame := 0
	for k in 96:
		for i in nodes.size():
			(nodes[i] as Node3D).position.z -= VeilNpcMeshy.walk_speed(VeilNpcMeshy.SLUGS[i]) * DT
			aps[i].advance(DT)
		await process_frame
		if k % 2 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/walk_%03d.png" % [out, frame])
			frame += 1
	quit(0)
