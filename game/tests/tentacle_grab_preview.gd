extends SceneTree
## A stage for the tentacle grab: a doorway opening (the base stays planted at it), a standing figure, and a medium Mist Tentacle posed by VeilTentacleGrab through every phase:
## load, uncoil and reach, wrap, squeeze, pull (the figure is drawn toward the opening), release. `miss` closes around empty space (the figure has stepped aside) and recoils.
## Three cameras (top, side, first person from the figure's eyes) are saved each time. Needs a window.
##   godot --path . --fixed-fps 60 --resolution 640x360 --script res://game/tests/tentacle_grab_preview.gd -- <out_dir> [miss] [every=3] [door]
const TENTACLE := "res://game/prototypes/monsters_meshy/MON_tentacle_medium.tscn"
var vps := {}
var cams := {}
var tentacle: Node3D
var poser: VeilTentaclePoser
var grab: VeilTentacleGrab
var figure: Node3D
var out := "."
var every := 3
var n := 0
var f := 0
var log_lines := []


func _initialize() -> void:
	_run.call_deferred()


func _box(parent: Node, pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos


func _aim(dir: Vector3, s: float) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.05:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z).scaled(Vector3.ONE * s)


func _place(root_pos: Vector3, dir: Vector3, s: float) -> void:
	var fix := Basis()
	tentacle.transform = Transform3D(_aim(dir, s) * fix, root_pos)
	poser.sk.force_update_all_bone_transforms()
	var inv := tentacle.global_transform.affine_inverse() * poser.sk.global_transform
	var a: Vector3 = inv * poser.sk.get_bone_global_pose(poser.bones[0]).origin
	var b: Vector3 = inv * poser.sk.get_bone_global_pose(poser.bones[poser.bones.size() - 1]).origin
	var axis := (b - a).normalized()
	if axis.length() > 0.5 and axis.dot(Vector3.UP) < 0.999:
		fix = Basis(Quaternion(axis, Vector3.UP))
	tentacle.transform = Transform3D(_aim(dir, s) * fix, root_pos)


func _capture() -> void:
	f += 1
	if f % every != 0:
		return
	await RenderingServer.frame_post_draw
	for k in vps:
		(vps[k] as SubViewport).get_texture().get_image().save_png("%s/%s_%04d.png" % [out, k, n])
	var tip := grab.joints_world()[9]
	var fig := figure.global_position
	var ang := rad_to_deg(atan2(tip.x - fig.x, tip.z - fig.z))
	log_lines.append("GRAB n %d tip_to_figure %.2f m tip_angle_around_figure %.0f load %.2f open %.2f wrap %.2f squeeze %.2f pull %.2f release %.2f" % [n, tip.distance_to(Vector3(fig.x, tip.y, fig.z)), ang, grab.load_k, grab.open_k, grab.wrap_k, grab.squeeze, grab.pull_k, grab.release_k])
	print(log_lines[log_lines.size() - 1])
	n += 1


func _hold(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await process_frame
		t += 1.0 / 60.0
		await _capture()


func _ease(param: String, v: float, secs: float, trans := Tween.TRANS_SINE) -> void:
	var from: float = grab.get(param)
	var t := 0.0
	while t < secs:
		await process_frame
		t += 1.0 / 60.0
		var k := clampf(t / secs, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		grab.set(param, lerpf(from, v, k))
		await _capture()
	grab.set(param, v)


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var miss := a.has("miss")
	var door := a.has("door")
	for e in a:
		if String(e).begins_with("every="):
			every = int(String(e).substr(6))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.11, 0.13)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.56, 0.62)
	e.fog_enabled = true
	e.fog_light_color = Color(0.2, 0.21, 0.25)
	e.fog_density = 0.01
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.9
	root.add_child(sun)
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(0.3, 0.31, 0.34))
	img.set_pixel(1, 1, Color(0.3, 0.31, 0.34))
	img.set_pixel(1, 0, Color(0.2, 0.21, 0.23))
	img.set_pixel(0, 1, Color(0.2, 0.21, 0.23))
	var fl := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(80, 80)
	fl.mesh = pl
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = ImageTexture.create_from_image(img)
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fm.uv1_scale = Vector3(40, 40, 1)
	fl.material_override = fm
	root.add_child(fl)
	# the opening: a wall at z = 0 with a low gap (the loading-bay door gap) when `door`, else just the street (a hole in the ground: the base is planted at it)
	if door:
		_box(root, Vector3(-3.2, 1.2, 0.0), Vector3(5.0, 2.4, 0.3), Color(0.36, 0.34, 0.3))
		_box(root, Vector3(3.2, 1.2, 0.0), Vector3(5.0, 2.4, 0.3), Color(0.36, 0.34, 0.3))
		_box(root, Vector3(0, 1.65, 0.0), Vector3(1.4, 1.5, 0.3), Color(0.3, 0.3, 0.32))       # the door slab, 0.9 m clear under it
	var ps := load(VeilMeshyNpcs.monster_scene("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn")) as PackedScene
	tentacle = ps.instantiate() as Node3D
	tentacle.set("autoplay", "")
	root.add_child(tentacle)
	var ap := tentacle.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.stop()
	tentacle.set_process(false)
	for m in tentacle.get("_mats"):
		(m as ShaderMaterial).set_shader_parameter("mist_level", -50.0)
		(m as ShaderMaterial).set_shader_parameter("fade_height", 0.05)
	poser = VeilTentaclePoser.attach(tentacle)
	poser.straight = true
	poser.apply()
	_place(Vector3(0, 0.3 if door else 0.1, -4.6 if door else -3.3), Vector3(0, 0.02, 1.0), 0.75)
	figure = Node3D.new()
	root.add_child(figure)
	var cap := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.75
	cap.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.3, 0.45, 0.7)
	cap.material_override = cmat
	figure.add_child(cap)
	cap.position = Vector3(0, 0.875, 0)
	var start_d := 4.6
	figure.position = Vector3(0, 0, tentacle.global_position.z + start_d)
	if door:
		figure.position = Vector3(0, 0, 0.0 + 1.2)
	var target := Callable(self, "_target")
	grab = VeilTentacleGrab.attach(tentacle, poser)
	var views := {"top": [Vector3(0, 9.0, figure.position.z - 1.2), Vector3(0, 0, figure.position.z - 1.2), Vector3(0, 0, -1), 50.0],
		"side": [Vector3(7.0, 1.6, figure.position.z - 1.4), Vector3(0, 0.7, figure.position.z - 1.4), Vector3.UP, 52.0],
		"first_person": [Vector3(0, 1.62, figure.position.z + 0.0), Vector3(0, 0.5, figure.position.z - 1.6), Vector3.UP, 75.0]}
	for k in views:
		var vp := SubViewport.new()
		vp.size = Vector2i(640, 360)
		vp.world_3d = root.world_3d
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = views[k][3]
		cam.far = 200.0
		vp.add_child(cam)
		cam.global_position = views[k][0]
		cam.look_at(views[k][1], views[k][2])
		vps[k] = vp
		cams[k] = cam
	grab.begin(target, 0.34, 0.0)
	await _hold(0.5)
	# ---- load: the upper half curls tighter, the base leans only to aim
	await _ease("load_k", 1.0, 0.7)
	await _hold(0.35)
	# ---- uncoil and reach: the middle joints open in sequence, the upper joints follow, the tip still slightly hooked
	await _ease("open_k", 1.0, 0.9)
	await _hold(0.3)
	if miss:
		# ---- the figure steps aside as the tip comes past: the wrap closes around empty space, then it recoils toward the opening
		var side_step := create_tween()
		side_step.tween_property(figure, "position:x", 1.3, 0.6)
		await _ease("wrap_k", 1.0, 0.9)
		await _ease("squeeze", 1.0, 0.25)
		await _hold(0.2)
		await _ease("pull_k", 1.0, 0.5)
		await _ease("release_k", 1.0, 0.7)
	else:
		await _ease("wrap_k", 1.0, 1.0)
		await _ease("squeeze", 1.0, 0.25)
		await _hold(0.25)
		if a.has("dump"):
			var js := grab.joints_world()
			var tg: Vector3 = _target()
			for i in js.size():
				print("JOINT %d rel_target x %.2f z %.2f y %.2f  dist_xz %.2f" % [i, js[i].x - tg.x, js[i].z - tg.z, js[i].y - tg.y, Vector2(js[i].x - tg.x, js[i].z - tg.z).length()])
			print("ROOT ", tentacle.global_position, " scale ", poser.sk.global_transform.basis.get_scale(), " side ", grab.side, " report ", grab.report)
			quit(0)
			return
		# ---- pull: the figure is drawn toward the opening while the tip and upper chain stay wrapped
		var drag := create_tween()
		drag.tween_property(figure, "position:z", figure.position.z - 1.2, 1.3).set_trans(Tween.TRANS_SINE)
		await _ease("pull_k", 1.0, 1.3)
		await _hold(0.25)
		await _ease("release_k", 1.0, 1.0)
	await _hold(0.4)
	print("RESULT captured ", n)
	quit(0)


func _target() -> Vector3:
	return figure.global_position + Vector3(0, 0.45, 0)
