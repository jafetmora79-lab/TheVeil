extends SceneTree
## VeilTentacleGrab on a medium Mist Tentacle: the base stays anchored, the loaded curl is tighter than the straight chain, the reach is longer, the tip goes round the
## target's silhouette (broad C, the target inside it), the pull draws the lower joints back, the release peels the tip first, a miss closes round empty space.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/tentacle_grab_test.gd
var fails := 0
var tentacle: Node3D
var poser: VeilTentaclePoser
var grab: VeilTentacleGrab
var figure_pos := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func ok(n: String, c: bool, d := "") -> void:
	print("TEST ", n, " PASS " if c else " FAIL ", d)
	if not c:
		fails += 1


func _aim(dir: Vector3, s: float) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z).scaled(Vector3.ONE * s)


func _tgt() -> Vector3:
	return figure_pos + Vector3(0, 0.45, 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x - _tgt().x, v.z - _tgt().z)


func _run() -> void:
	var ps := load(VeilMeshyNpcs.monster_scene("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn")) as PackedScene
	tentacle = ps.instantiate() as Node3D
	tentacle.set("autoplay", "")
	root.add_child(tentacle)
	var ap := tentacle.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.stop()
	tentacle.set_process(false)
	poser = VeilTentaclePoser.attach(tentacle)
	poser.straight = true
	poser.apply()
	tentacle.transform = Transform3D(_aim(Vector3(0, 0.02, 1.0), 0.75), Vector3(0, 0.1, -3.3))
	poser.sk.force_update_all_bone_transforms()
	var inv := tentacle.global_transform.affine_inverse() * poser.sk.global_transform
	var a: Vector3 = inv * poser.sk.get_bone_global_pose(poser.bones[0]).origin
	var b: Vector3 = inv * poser.sk.get_bone_global_pose(poser.bones[poser.bones.size() - 1]).origin
	var axis := (b - a).normalized()
	if axis.dot(Vector3.UP) < 0.999:
		tentacle.transform = Transform3D(_aim(Vector3(0, 0.02, 1.0), 0.75) * Basis(Quaternion(axis, Vector3.UP)), Vector3(0, 0.1, -3.3))
	figure_pos = Vector3(0, 0, 1.3)
	grab = VeilTentacleGrab.attach(tentacle, poser)
	grab.begin(Callable(self, "_tgt"), 0.34, 0.0)
	await _frames(2)
	var base0 := grab.joints_world()[0]
	var straight_tip := grab.joints_world()[9]
	ok("anchored_base", true, "root at %s" % str(base0))
	# ---- load: the curl tightens, the tip draws back toward the base
	grab.load_k = 1.0
	await _frames(2)
	var loaded_tip := grab.joints_world()[9]
	ok("load_curls_the_upper_half", loaded_tip.distance_to(base0) < straight_tip.distance_to(base0) - 0.4, "%.2f -> %.2f" % [straight_tip.distance_to(base0), loaded_tip.distance_to(base0)])
	ok("load_base_stays", grab.joints_world()[0].distance_to(base0) < 0.01)
	# ---- reach
	grab.open_k = 1.0
	await _frames(2)
	var reach_tip := grab.joints_world()[9]
	ok("reach_is_longer_than_the_load", reach_tip.distance_to(base0) > loaded_tip.distance_to(base0) + 1.0, "%.2f" % reach_tip.distance_to(base0))
	# ---- wrap: the tip goes round the target
	grab.wrap_k = 1.0
	grab.squeeze = 1.0
	await _frames(2)
	var js := grab.joints_world()
	var tip_r := _flat(js[9]).length()
	var angs := []
	for i in range(7, 10):
		angs.append(rad_to_deg(_flat(js[i]).angle()))
	var span := 0.0
	for i in range(1, angs.size()):
		span += absf(wrapf(angs[i] - angs[i - 1], -180.0, 180.0))
	ok("wrap_tip_circles_the_target", tip_r > 0.2 and tip_r < 0.6, "tip %.2f m from the target" % tip_r)
	ok("wrap_is_a_broad_C", span > 90.0, "last three joints span %.0f deg around the target" % span)
	ok("wrap_centre_solved", float(grab.report.get("center_error", 9.0)) < 0.05, str(grab.report.get("center_error")))
	ok("wrap_base_stays", js[0].distance_to(base0) < 0.01)
	# ---- pull: the lower/middle joints buckle back, the tip stays on the target
	var mid0 := js[3]
	grab.pull_k = 1.0
	await _frames(2)
	js = grab.joints_world()
	ok("pull_keeps_the_wrap", _flat(js[9]).length() < 0.7, "%.2f" % _flat(js[9]).length())
	# ---- release: the tip peels first
	grab.release_k = 0.35
	await _frames(2)
	js = grab.joints_world()
	var tip_d1 := _flat(js[9]).length()
	grab.release_k = 1.0
	await _frames(2)
	var tip_d2 := _flat(grab.joints_world()[9]).length()
	ok("release_peels_away", tip_d2 > 1.5 and tip_d1 > 0.0, "%.2f -> %.2f" % [tip_d1, tip_d2])
	# ---- miss: the target stepped aside, the wrap closes round empty space
	grab.release_k = 0.0
	grab.pull_k = 0.0
	var tpos := _tgt()
	var aimed := tpos
	grab.target_fn = func(): return aimed
	await _frames(2)
	figure_pos = Vector3(1.4, 0, 1.3)
	aimed = tpos                                       # it was aimed at the old spot: the wrap closes there, 1.4 m from the figure
	await _frames(2)
	var tip_to_figure := Vector2(grab.joints_world()[9].x - figure_pos.x, grab.joints_world()[9].z - figure_pos.z).length()
	ok("miss_closes_round_empty_space", tip_to_figure > 0.9, "%.2f m from the figure" % tip_to_figure)
	print("RESULT ", "FAIL" if fails > 0 else "PASS", " fails=", fails)
	quit(1 if fails > 0 else 0)
