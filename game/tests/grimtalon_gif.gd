extends SceneTree
## Frames for the Grimtalon animation GIF: a single bird passing, a swarm over the mist, and the abduction of a man. Needs a window:
##   godot --path . --fixed-fps 30 --resolution 640x360 --script res://game/tests/grimtalon_gif.gd -- <out_dir>
var cam: Camera3D
var out := ""
var n := 0


func _initialize() -> void:
	call_deferred("_run")


func _snap() -> void:
	await RenderingServer.frame_post_draw
	if n % 1 == 0:
		root.get_texture().get_image().save_png("%s/f%04d.png" % [out, n])
	n += 1


func _run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.30, 0.33, 0.36)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.58)
	e.fog_enabled = true
	e.fog_light_color = Color(0.30, 0.33, 0.36)
	e.fog_density = 0.004
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.0
	root.add_child(sun)
	var fl := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(1200, 1200)
	fl.mesh = pl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.13, 0.14, 0.15)
	fl.material_override = fm
	root.add_child(fl)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 900.0
	root.add_child(cam)
	cam.current = true
	var G = load("res://game/animals/grimtalon.gd")
	# ---- 1: one bird, passing close
	var holder := Node3D.new()
	root.add_child(holder)
	var g = G.spawn(holder, Vector3(0, 6, 0))
	g.fly_circle(Vector3(0, 0, 0), 7.0, 5.0, 6.0)
	for i in 90:
		var a: float = g._ang
		cam.global_position = Vector3(0, 4.0, 15.0)
		cam.fov = 42.0
		cam.look_at(g.global_position * 0.7 + Vector3(0, 1.5, 0), Vector3.UP)
		await process_frame
		if i % 2 == 0:
			await _snap()
	g.queue_free()
	# ---- 2: the swarm over the mist, seen from the street
	var birds: Array = G.flock(holder, 11, Vector3(0, 0, -45), null, Vector2(14, 42), Vector2(20, 38), Vector2(6, 9))
	for i in 120:
		cam.global_position = Vector3(0, 1.7, 12.0)
		cam.fov = 62.0
		cam.look_at(Vector3(0, 26.0, -45.0), Vector3.UP)
		await process_frame
		if i % 2 == 0:
			await _snap()
	for b in birds:
		b.queue_free()
	# ---- 3: the man in the street, the dive, the grab, the climb
	var man = (load("res://THE_VEIL_ASSETS_V2/06_Characters/Commercial_NPCs/CHR_Frank.glb") as PackedScene).instantiate() as Node3D
	root.add_child(man)
	man.global_position = Vector3(0, 0, -20)
	var b2 = G.spawn(holder, Vector3(0, 50, -75))
	var done := [false]
	var run := func():
		await b2.abduct(man, Vector3(-1, 0, -0.2), Callable(), Vector3(0.3, 0, -1))
		done[0] = true
	run.call()
	var i := 0
	while not done[0] and i < 300:
		cam.global_position = Vector3(2.5, 1.5, -11.0)
		cam.fov = 70.0 if i < 80 else 60.0
		if i < 70:
			cam.look_at(man.global_position + Vector3(0, 6.0 + (1.0 - float(i) / 70.0) * 14.0, 0), Vector3.UP)
		else:
			cam.look_at(b2.global_position.lerp(man.global_position + Vector3(0, 2.0, 0), 0.15), Vector3.UP)
		await process_frame
		if i % 2 == 0:
			await _snap()
		i += 1
	print("FRAMES ", n)
	quit()
