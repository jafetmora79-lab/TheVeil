extends SceneTree
## The Hound is the Meshy dog with its own clips: every clip the creature code asks for exists, the gallop plays, the model stands on the ground and is hound-sized.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/hound_model_test.gd
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var h := (load("res://game/prototypes/monsters_meshy/MON_hound.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(h)
	root.add_child((load("res://game/prototypes/monsters_meshy/MON_hound.tscn") as PackedScene).instantiate())
	await process_frame
	var ap := h.get_node(String(h.get_meta("animation_player"))) as AnimationPlayer
	for c in ["Idle", "Walk", "Run", "Alert", "Sniff", "Detect", "Attack_Bite", "Hit_React", "Death"]:
		ok("clip_" + c, ap.has_animation(c))
	ap.play("Run")
	var sk := h.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var low := 1e9
	var hi := -1e9
	var nose := -1e9
	for s in 12:
		ap.seek(0.37 * s / 12.0, true)
		sk.force_update_all_bone_transforms()
		for tn in ["rearToe.L", "rearToe.R", "frontToe.L", "frontToe.R"]:
			low = minf(low, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(tn)).origin).y)
		hi = maxf(hi, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head")).origin).y)
		nose = maxf(nose, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("jaw")).origin - h.global_position).z)
	ok("feet_on_ground", absf(low) < 0.08, "lowest toe %.3f" % low)
	ok("hound_sized", hi > 0.5 and hi < 1.4 and nose > 0.5 and nose < 1.6, "head %.2f m, jaw %.2f m ahead" % [hi, nose])
	ok("own_library", ap.get_animation("Run") != (root.get_child(root.get_child_count() - 1).find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer).get_animation("Run"))
	ok("gallop_speed_meta", absf(float(h.get_meta("run_speed_mps")) - 6.82) < 0.01)
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
