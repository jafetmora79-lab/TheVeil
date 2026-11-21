extends SceneTree
## Renders the game preview. With the movie writer (picture and sound into one AVI):
##   godot --path . --fixed-fps 30 --resolution 1920x1080 --write-movie out.avi --script res://game/preview/render_preview.gd
## For checking the framing without a video: add `-- capture=<dir> every=<frames>` and PNGs are written instead.
var d
var cap_dir := ""
var every := 15
var n := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("capture="):
			cap_dir = a.substr(8)
		elif a.begins_with("every="):
			every = int(a.substr(6))
	d = load("res://game/preview/preview_director.gd").start_preview(self)
	d.finished.connect(func():
		print("PREVIEW finished after %d frames" % n)
		quit())
	if cap_dir != "":
		process_frame.connect(_cap)


func _cap() -> void:
	n += 1
	if n % every == 0:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/f%05d.png" % [cap_dir, n])
