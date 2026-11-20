extends SceneTree
## Frames of a creature clip, camera tracking it, the creature travelling at the speed the game moves it so planted feet should stay put on the floor. Needs a window:
##   godot --path . --fixed-fps 60 --resolution 640x480 --script res://game/tests/monster_preview.gd -- <out_dir> <scene.tscn|model.glb> <Clip> <side|three|front|top|low> [speed m/s] [frames=72] [every=2] [fog] [turn180] [loop] [size=<m>] [look=<y>]
## `turn180` for a raw .glb that faces -Z (the creature scenes already turn it). `fog` adds the game's grey mist. The checkered floor is 1 m squares.
var cam: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _find_player(n: Node) -> AnimationPlayer:
	for c in n.find_children("*", "AnimationPlayer", true, false):
		return c as AnimationPlayer
	return null


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var path: String = a[1]
	var clip: String = a[2]
	var view: String = a[3]
	var speed: float = float(a[4]) if a.size() > 4 else 0.0
	var count: int = int(a[5]) if a.size() > 5 else 72
	var every: int = int(a[6]) if a.size() > 6 else 2
	var fog: bool = a.has("fog")
	var turn: bool = a.has("turn180")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.17, 0.19, 0.22) if not fog else Color(0.30, 0.33, 0.36)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.62)
	if fog:
		e.fog_enabled = true
		e.fog_light_color = Color(0.30, 0.33, 0.36)
		e.fog_density = 0.055
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(0.30, 0.31, 0.34))
	img.set_pixel(1, 1, Color(0.30, 0.31, 0.34))
	img.set_pixel(1, 0, Color(0.20, 0.21, 0.23))
	img.set_pixel(0, 1, Color(0.20, 0.21, 0.23))
	var fl := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(400, 2000)
	fl.mesh = pl
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = ImageTexture.create_from_image(img)
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fm.uv1_scale = Vector3(200, 1000, 1)
	fm.roughness = 1.0
	fl.material_override = fm
	root.add_child(fl)
	cam = Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true
	var holder := Node3D.new()
	root.add_child(holder)
	var ps := load(path) as PackedScene
	var m: Node3D = ps.instantiate()
	if turn:
		m.rotation.y = PI
	holder.add_child(m)
	var ap := _find_player(m)
	var anim_len := 0.0
	if ap != null and ap.has_animation(clip):
		var an := ap.get_animation(clip)
		if a.has("loop"):
			an.loop_mode = Animation.LOOP_LINEAR
		anim_len = an.length
		ap.play(clip)
	else:
		push_error("no clip " + clip + " in " + path)
	var frame := 0
	var n := 0
	var dist := 0.0
	var size_ref := 1.6
	var look_y := 0.55
	for extra in a:
		if String(extra).begins_with("size="):
			size_ref = float(String(extra).substr(5))
		if String(extra).begins_with("look="):
			look_y = float(String(extra).substr(5))
	while n < count:
		await process_frame
		frame += 1
		var dt := 1.0 / 60.0
		holder.position.z += speed * dt                              # the creature faces +Z and travels along it
		var p := holder.global_position
		match view:
			"front":
				cam.position = p + Vector3(0.0, 1.0, 5.0) * size_ref * 0.6
			"three":
				cam.position = p + Vector3(-3.4, 1.7, 3.6) * size_ref * 0.6
			"top":
				cam.position = p + Vector3(0.0, 8.0, 0.4) * size_ref * 0.6
			"low":
				cam.position = p + Vector3(-4.2, 0.5, 0.0) * size_ref * 0.6
			_:
				cam.position = p + Vector3(-5.0, 1.1, 0.0) * size_ref * 0.6
		cam.look_at(p + Vector3(0, look_y, 0), Vector3.UP)
		if frame % every == 0:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/f_%03d.png" % [out, n])
			n += 1
	quit(0)
