extends SceneTree
## dev tool: orthographic views of the handgun model (+ optional hands) to place the grip
##   godot --path . --script res://game/tests/gun_view.gd -- <out_dir> <tag> [hands]
var out_dir := ""
var tag := ""
var with_hands := false


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[0]
	tag = a[1]
	with_hands = a.size() > 2 and a[2] == "hands"
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(900, 600)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.57, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var gun := (load("res://THE_VEIL_ASSETS_V2/08_Inventory/Weapons/INV_Handgun.glb") as PackedScene).instantiate() as Node3D
	root.add_child(gun)
	if with_hands:
		var h = load("res://game/world/view_hands.gd").new()
		h.build(gun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.34
	root.add_child(cam)
	cam.current = true
	var c := Vector3(0, 0.07, 0)
	var views := {"side": Vector3(1, 0, 0), "back": Vector3(0, 0, 1), "top": Vector3(0, 1, 0.0001), "q": Vector3(0.8, 0.5, 0.9)}
	for k in views:
		var dir: Vector3 = views[k]
		if k == "q":
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 40
			cam.position = c + dir.normalized() * 0.55
		else:
			cam.position = c + dir.normalized() * 1.0
		cam.look_at(c, Vector3.UP if k != "top" else Vector3(0, 0, -1))
		await frames(3)
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, tag, k])
	quit(0)
