extends SceneTree
## dev tool: frames for the animated previews of the Meshy Sarah prototype (needs a window; the GIFs are assembled from the PNGs):
##   godot --path . --fixed-fps 24 --resolution 640x480 --script res://game/tests/sarah_meshy_preview.gd -- <out_dir> <body|face>
##   body: she walks, stops, glances around nervously, then reacts with fear.   face: blinking, talking, scared, angry (close-up).
## Rendering follows the game's intended look: Compatibility renderer, nearest-neighbour textures (the prototype sets them), no MSAA,
## and the film-look layer (vignette, grain) on top.
var out := ""
var mode := ""
const DT := 1.0 / 24.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	mode = a[1]
	_run.call_deferred()


func _run() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.58)
	e.fog_enabled = true                                   # a little mist, as in the supermarket scenes
	e.fog_light_color = Color(0.45, 0.47, 0.52)
	e.fog_density = 0.02
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 150, 0)
	sun.light_energy = 1.0
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.22, 0.24)
	fm.roughness = 1.0
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	var fx := CanvasLayer.new()                              # the film-look layer (the game's own shader: vignette, grain, bloom)
	fx.layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://game/ui/screen_fx.gdshader")
	sm.set_shader_parameter("grain", 0.012)                  # the game grain is 0.05; the previews use less so the GIFs stay small
	rect.material = sm
	fx.add_child(rect)
	root.add_child(fx)
	var n := VeilSarahMeshyProto.instantiate()
	root.add_child(n)
	var ap := VeilSarahMeshyProto.anim_player(n)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var face := VeilSarahMeshyProto.face(n)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var frame := 0
	var t := 0.0
	var v := VeilSarahMeshyProto.walk_speed()
	if mode == "body":
		cam.fov = 34.0
		cam.position = Vector3(2.4, 1.05, -3.3)
		cam.look_at(Vector3(0.1, 0.85, -0.1))
		n.position = Vector3(0, 0, 0.9)
		ap.play("walk")
		var total := 8.4
		var state := "walk"
		while t < total:
			if state == "walk" and t >= 3.4:
				state = "nervous"
				ap.play("nervous_idle", 0.4)
				ap.seek(0.5, false)
			elif state == "nervous" and t >= 6.0:
				state = "scared"
				face.expression = "scared"
				ap.play("scared_reaction", 0.05)
			if state == "walk":
				n.position.z -= v * DT
			ap.advance(DT)
			await process_frame
			if frame % 2 == 0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/body_%03d.png" % [out, frame / 2])
			frame += 1
			t += DT
	else:
		cam.fov = 12.0
		cam.position = Vector3(0.62, 1.57, -1.15)
		cam.look_at(Vector3(0.0, 1.535, 0.0))
		ap.play("idle")
		face.auto_blink = false
		var total := 7.4
		var events := [[0.5, "blink"], [1.0, "talk_on"], [3.0, "talk_off"], [3.3, "blink"], [3.9, "scared"], [5.0, "angry"], [6.3, "neutral"], [6.6, "blink"]]
		var ei := 0
		while t < total:
			while ei < events.size() and t >= events[ei][0]:
				match events[ei][1]:
					"blink":
						face.blink()
					"talk_on":
						face.talking = true
					"talk_off":
						face.talking = false
					"scared", "angry", "neutral":
						face.expression = events[ei][1]
				ei += 1
			ap.advance(DT)
			await process_frame
			if frame % 2 == 0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/face_%03d.png" % [out, frame / 2])
			frame += 1
			t += DT
	quit(0)
