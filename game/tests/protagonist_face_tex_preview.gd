extends SceneTree
## dev tool (needs a window): close-up frames of the face-texture expressions in Godot 4.3 Compatibility (nearest filter, film grain layer).
##   godot --path . --fixed-fps 24 --resolution 560x560 --script res://game/tests/protagonist_face_tex_preview.gd -- <out_dir>
const DT := 1.0 / 24.0


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args()[0])


func _run(out: String) -> void:
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
	var ps := load("res://creatures/humans/protagonist/face_geo/CHR_Protagonist_FaceTex.glb") as PackedScene
	var n := ps.instantiate() as Node3D
	root.add_child(n)
	n.rotation_degrees.y = 180.0 + 0.0                       # the face toward the camera on +Z... the model faces -Z, the camera sits at -Z
	n.rotation_degrees.y = 0.0
	var f := VeilProtagonistFaceTex.new()
	n.add_child(f)
	f.setup(n)
	f.auto_blink = true
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 12.0
	cam.position = Vector3(0.0, 1.6, -2.0)
	cam.look_at(Vector3(0.0, 1.59, 0.0))
	var frame := 0
	var t := 0.0
	var total := 7.0
	while t < total:
		f.talking = t >= 1.6 and t < 3.6
		if t >= 4.0 and t < 5.8:
			f.expression = "scared"
		else:
			f.expression = "neutral"
		await process_frame
		if frame % 2 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/ft_%03d.png" % [out, frame / 2])
		frame += 1
		t += DT
	quit(0)
