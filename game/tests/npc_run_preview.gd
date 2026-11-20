extends SceneTree
## Frames of an NPC running with the game's own NpcAnimator (Gait), camera tracking the runner. Needs a real window (not --headless):
##   godot --path . --fixed-fps 60 --resolution 640x480 --script res://game/tests/npc_run_preview.gd -- <out_dir> <Speaker> <side|front|three> [speed m/s] [skip_frames] [every] [react]
## Every `every`-th frame (default 2 = 30 fps of the 60 fps simulation) after `skip_frames` (default 150: the run has reached its steady pace)
## is saved as run_NNN.png for 72 frames. The caller assembles them (docs: docs/animation/GAIT.md).
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")

var cam: Camera3D
var holder: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "."
	var who: String = a[1] if a.size() > 1 else "Marcus"
	var view: String = a[2] if a.size() > 2 else "side"
	var speed: float = float(a[3]) if a.size() > 3 else 4.3
	var skip: int = int(a[4]) if a.size() > 4 else 150
	var every: int = int(a[5]) if a.size() > 5 else 2
	var react: bool = a.size() > 6 and a[6] == "react"                       # trigger one chase reaction (raised palm + glance) after 0.5 s of capture
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.17, 0.19, 0.22)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	# a checkered floor so the ground visibly slides under the planted feet
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(0.30, 0.31, 0.34))
	img.set_pixel(1, 1, Color(0.30, 0.31, 0.34))
	img.set_pixel(1, 0, Color(0.20, 0.21, 0.23))
	img.set_pixel(0, 1, Color(0.20, 0.21, 0.23))
	var fl := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(200, 2000)
	fl.mesh = pl
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = ImageTexture.create_from_image(img)
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fm.uv1_scale = Vector3(100, 1000, 1)
	fm.roughness = 1.0
	fl.material_override = fm
	fl.position = Vector3(0, 0, -900)
	root.add_child(fl)
	cam = Camera3D.new()
	cam.fov = 38.0
	root.add_child(cam)
	cam.current = true
	holder = Node3D.new()
	holder.name = who
	root.add_child(holder)
	var model := VeilMeshyNpcs.model_for(who)
	holder.add_child(model)
	var anim: Node = NPC_ANIM.new()
	anim.name = "Animator"
	holder.add_child(anim)
	var f := VeilMeshyNpcs.face_for(model)
	f.name = "VeilFace"
	holder.add_child(f)
	anim.set_mood("scared")
	for extra in a.slice(7):                                                  # optional: twist=<deg> (forearm twist of the raised hand)
		if String(extra).begins_with("twist="):
			anim.react_twist_deg = float(String(extra).substr(6))
	anim.walk_to([Vector3(0, 0, -900)], speed)
	var n := 0
	var frame := 0
	while n < 72:
		await process_frame
		frame += 1
		var p := holder.global_position
		match view:
			"front":
				cam.position = p + Vector3(0.0, 1.25, -4.4)
			"three":
				cam.position = p + Vector3(2.5, 1.3, -3.6)
			"close":                                                       # chest-up from the front-right: hands, elbows, face
				cam.position = p + Vector3(1.6, 1.35, -1.7)
			_:
				cam.position = p + Vector3(4.2, 1.0, 0.0)                # +X looking -X: he runs from left to right on screen
		cam.look_at(p + Vector3(0, 0.92, 0), Vector3.UP)
		if react and frame == skip + 30:
			anim.react(1.0, 1.0)
		if frame > skip and (frame - skip) % every == 0:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/run_%03d.png" % [out, n])
			n += 1
	quit(0)
