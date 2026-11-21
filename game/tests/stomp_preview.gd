extends SceneTree
## Short clip of the tripod walking through the dense woods and leaving footprints / felled trees (a bare forest stage; a "house" in the way shows the avoidance).
##   godot --path . --fixed-fps 30 --resolution 1280x720 --write-movie out.avi --script res://game/tests/stomp_preview.gd
var tc
var cam: Camera3D
var t := 0.0
var shots := []
var st
var shake := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.04, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.30, 0.34, 0.46)
	e.ambient_light_energy = 0.9
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.06, 0.1)
	e.fog_density = 0.006
	we.environment = e
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 200, 0)
	sun.light_color = Color(0.6, 0.68, 0.95)
	sun.light_energy = 0.9
	stage.add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.07, 0.085, 0.05)
	gm.roughness = 1.0
	pm.material = gm
	g.mesh = pm
	g.position = Vector3(230, 0.15, 200)
	stage.add_child(g)
	var sc = load("res://game/world/scatter.gd").new()
	sc.name = "Scatter"
	stage.add_child(sc)
	# a house in the way: it must not get a footprint on it
	var house := StaticBody3D.new()
	house.name = "House"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(12, 8, 10)
	cs.shape = bs
	house.add_child(cs)
	var hm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.4, 0.34, 0.3)
	bm.material = hmat
	hm.mesh = bm
	house.add_child(hm)
	stage.add_child(house)
	await process_frame
	tc = VeilTripodColossus.new()
	stage.add_child(tc)
	tc.build(40.0, 0.15)
	var start := Vector3(222, 0.15, 330)
	tc.global_position = start
	tc.set_walking(true, 1.0)
	st = tc.enable_stomps(sc)
	st.play_sound = true
	st.stomped.connect(func(pos, r): shake = maxf(shake, 1.0 / maxf(pos.distance_to(cam.global_position) / 30.0, 1.0)))
	house.position = start + Vector3(10.5, 4.15, -36)          # lands under the right leg's path
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 700
	stage.add_child(cam)
	cam.current = true
	var dir := Vector3(0, 0, -1)
	process_frame.connect(func():
		var dt := 1.0 / 30.0
		t += dt
		tc.global_position += dir * tc.ground_speed() * dt
		var p: Vector3 = tc.global_position
		if t < 9.0:      # low, ahead and to the side, looking at the feet
			cam.global_position = p + Vector3(-16, 2.2, -22)
			cam.look_at(p + Vector3(2, 5, 0), Vector3.UP)
		elif t < 17.0:   # from behind, the trail of prints
			cam.global_position = p + Vector3(10, 7, 38)
			cam.look_at(p + Vector3(-2, 3, 8), Vector3.UP)
		else:
			cam.global_position = p + Vector3(48, 30, 16)
			cam.look_at(p + Vector3(-6, 0, -6), Vector3.UP)
		shake = maxf(shake - dt * 2.2, 0.0)
		cam.h_offset = randf_range(-1, 1) * shake * shake * 0.6
		cam.v_offset = randf_range(-1, 1) * shake * shake * 0.6
		if t > 24.0:
			print("STOMPS prints=%d blocked=%d felled=%d" % [st.count, st.blocked_count, st.felled])
			quit())
