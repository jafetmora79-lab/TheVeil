extends SceneTree
## Renders every house of the real game scene (game/world/Greyhaven_Houses.tscn) from a 3/4 exterior view into one contact sheet.
## godot --path . --rendering-driver opengl3 --resolution 640x480 --script res://refine/tools/house_survey.gd -- <out.png> [interior]
var out := "res://refine/previews/houses_exterior.png"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	var scn: Node3D = (load("res://game/world/Greyhaven_Houses.tscn") as PackedScene).instantiate()
	root.add_child(scn)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.6, 0.62, 0.68)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -30, 0); root.add_child(sun)
	var cam := Camera3D.new(); cam.fov = 55; root.add_child(cam)
	root.size = Vector2i(480, 360)
	var houses := scn.get_node("Houses").get_children()
	var sheet := Image.create(480 * 6, 360 * ceili(houses.size() / 6.0), false, Image.FORMAT_RGB8)
	var i := 0
	for h in houses:
		var c: Vector3 = h.global_position
		var fwd: Vector3 = h.global_transform.basis.z  # front faces +Z of the house frame (checked visually)
		cam.global_position = c + fwd * 15.0 + Vector3(5, 7, 0) * 1.0
		cam.look_at(c + Vector3(0, 2, 0))
		await process_frame; await process_frame; await process_frame
		var img := root.get_texture().get_image(); img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, 480, 360), Vector2i((i % 6) * 480, (i / 6) * 360))
		print(i, " ", h.name, " ", h.get_meta("variant", ""))
		i += 1
	sheet.save_png(ProjectSettings.globalize_path(out))
	quit()
