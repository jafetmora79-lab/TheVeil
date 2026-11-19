extends SceneTree
## dev tool: frames for a GIF of the Meshy protagonist watching the Colossus (needs a window; the GIF is assembled from the PNGs):
##   godot --path . --fixed-fps 24 --resolution 640x400 --script res://game/tests/protagonist_colossus_preview.gd -- <out_dir>
const DT := 1.0 / 24.0
const COLOSSUS := preload("res://THE_VEIL_ASSETS_V2/07_Creatures/Colossus/CRT_Colossus.glb")
var out := ""


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	_run.call_deferred()


func _run() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.30, 0.33, 0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.46, 0.49, 0.52)
	e.fog_enabled = true
	e.fog_light_color = Color(0.40, 0.43, 0.45)
	e.fog_density = 0.011
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 40, 0)
	sun.light_energy = 0.9
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.20, 0.21, 0.21)
	fm.roughness = 1.0
	floor_mi.material_override = fm
	root.add_child(floor_mi)
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

	var colossus: Node3D = COLOSSUS.instantiate()
	root.add_child(colossus)
	var cap: AnimationPlayer
	var players := colossus.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		cap = players[0]
		for nm in ["Walk_Heavy", "Crawl", "Idle_Twitch", "Idle"]:
			if cap.has_animation(nm):
				cap.play(nm)
				break
	var h := 1.0
	for mi in colossus.find_children("*", "MeshInstance3D", true, false):
		h = maxf(h, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).size.y)
	print("COLOSSUS native height ", h)
	colossus.scale = Vector3.ONE * 2.2
	colossus.position = Vector3(-6, 0, -46)
	colossus.look_at(Vector3(0, 0, 0), Vector3.UP)

	var n := VeilProtagonistMeshy.instantiate()
	root.add_child(n)
	n.rotation_degrees.y = 12                         # facing the Colossus, a little toward the camera
	var ap := VeilSarahMeshyProto.anim_player(n)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var face := VeilProtagonistMeshy.face(n)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 34.0
	var frame := 0
	var t := 0.0
	var total := 7.5
	var state := "calm"
	ap.play("idle")
	var CUT := 2.6
	while t < total:
		if state == "calm" and t >= CUT:
			state = "scared"
			face.expression = "scared"
			ap.play("scared_reaction", 0.05)
			face.blink(0.0)
		colossus.position = Vector3(-4, 0, -42).lerp(Vector3(-2, 0, -27), clampf(t / total, 0.0, 1.0))
		if state == "calm":
			# over his shoulder: the Colossus walks out of the mist ahead of him
			cam.fov = 52.0
			cam.position = Vector3(1.0, 1.62, 1.6)
			cam.look_at(Vector3(-3.0, 9.0, -32.0))
		else:
			# cut to his face: the shake of every footstep
			cam.fov = 34.0
			var shake := 0.014 * clampf((t - CUT) / 0.8, 0.0, 1.0) * (1.0 + 0.6 * sin((t - CUT) * 9.0))
			cam.position = Vector3(-0.95, 1.6, -0.8) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake
			cam.look_at(Vector3(-0.05, 1.56, -0.08))
		ap.advance(DT)
		await process_frame
		if frame % 2 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/col_%03d.png" % [out, frame / 2])
		frame += 1
		t += DT
	quit(0)
