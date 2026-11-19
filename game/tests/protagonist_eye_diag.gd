extends SceneTree
## DIAGNOSTIC (nothing is changed permanently): the same eye close-up under different conditions, to find the source of the grey lines.
##   godot --path . --resolution 560x420 --script res://game/tests/protagonist_eye_diag.gd -- <out_dir>
const FACETEX := "res://game/prototypes/protagonist_meshy/face/CHR_Protagonist_FaceTex.glb"
const ORIG := "res://game/prototypes/protagonist_meshy/CHR_Protagonist_Meshy.glb"
const BASE_FACE := "res://creatures/humans/protagonist/work/face/face_flat.png"       # the original face capture (no cleanup)
var out := ""


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	_run.call_deferred()


func _mats(n: Node, fn: Callable) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i)
			var mat := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			fn.call(i, mat)
			m.set_surface_override_material(i, mat)


func _run() -> void:
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
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 7.0
	cam.position = Vector3(0.0, 1.62, -2.2)
	cam.look_at(Vector3(0.0, 1.615, 0.0))
	var base_img := Image.load_from_file(ProjectSettings.globalize_path(BASE_FACE))
	base_img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	var base_tex := ImageTexture.create_from_image(base_img)
	var base_mip := Image.load_from_file(ProjectSettings.globalize_path(BASE_FACE))
	base_mip.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	base_mip.generate_mipmaps()
	var base_tex_mip := ImageTexture.create_from_image(base_mip)

	var tests := []
	# 1: the ORIGINAL (uncleaned) face texture, unshaded, default filtering with mipmaps
	tests.append(["1 original tex, unshaded, linear+mipmaps", FACETEX, func(i, m):
		if i == 1:
			m.albedo_texture = base_tex_mip
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		else:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED])
	# 2: same, nearest, no mipmaps
	tests.append(["2 original tex, unshaded, NEAREST no mipmaps", FACETEX, func(i, m):
		if i == 1:
			m.albedo_texture = base_tex
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED])
	# 3: the current Godot material and lighting (cleaned neutral texture, lit, nearest)
	tests.append(["3 current material + lighting", FACETEX, func(i, m):
		if i == 1:
			m.albedo_texture = load("res://game/prototypes/protagonist_meshy/face/tex/face_neutral.png")
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			m.roughness = 1.0])
	# 3b: the ORIGINAL texture with the current material and lighting
	tests.append(["3b original tex + lighting", FACETEX, func(i, m):
		if i == 1:
			m.albedo_texture = base_tex
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			m.roughness = 1.0])
	# 4: geometry only: the face texture removed (plain skin colour), lit
	tests.append(["4 geometry only (no eye texture), lit", FACETEX, func(i, m):
		if i == 1:
			m.albedo_texture = null
			m.albedo_color = Color(0.93, 0.72, 0.58)
			m.roughness = 1.0])
	# 4b: geometry only, with smooth (averaged) normals would need a mesh change: instead show the plain skin UNSHADED to confirm nothing else draws lines
	tests.append(["4b geometry only, unshaded", FACETEX, func(i, m):
		if i == 1:
			m.albedo_texture = null
			m.albedo_color = Color(0.93, 0.72, 0.58)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED])
	# 5: the original model, no expression machinery, lit
	tests.append(["5 original model, lit", ORIG, func(i, m):
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.roughness = 1.0])
	# 5b: the original model, unshaded
	tests.append(["5b original model, unshaded", ORIG, func(i, m):
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED])
	var k := 0
	for t in tests:
		var ps := load(t[1]) as PackedScene
		var n := ps.instantiate() as Node3D
		root.add_child(n)
		_mats(n, t[2])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/diag_%d.png" % [out, k])
		print("DIAG ", k, " ", t[0])
		n.queue_free()
		await process_frame
		k += 1
	quit(0)
