extends SceneTree
## Screenshot of a scene after N frames. godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://refine/tools/shot_scene.gd -- <scene> <out.png> [frames]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var s := (load(a[0]) as PackedScene).instantiate()
	root.add_child(s)
	var n := int(a[2]) if a.size() > 2 else 90
	for i in n: await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(a[1]))
	quit()
