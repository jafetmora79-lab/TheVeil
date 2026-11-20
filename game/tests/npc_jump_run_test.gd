extends SceneTree
## Meshy NPCs: the jump pose (crouch, flight with raised arms, landing) and the run pose (lean, arm pump). Headless measurements.
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
var fails := 0

func check(n: String, ok: bool, info := "") -> void:
	print("  %s %s %s" % ["ok  " if ok else "FAIL", n, info])
	if not ok: fails += 1

func _initialize() -> void:
	for sp in ["Sarah", "Protagonist", "Cashier"]:
		var holder := Node3D.new()
		root.add_child(holder)
		var model := VeilMeshyNpcs.model_for(sp)
		holder.add_child(model)
		var anim: Node = NPC_ANIM.new()
		holder.add_child(anim)
		await process_frame
		await process_frame
		var skel: Skeleton3D = anim.skel
		var head := skel.find_bone("Head")
		var hand := skel.find_bone("RightHand")
		var foot := skel.find_bone("LeftFoot")
		var rest_hand: float = (skel.global_transform * skel.get_bone_global_pose(hand).origin).y
		var rest_foot: float = (skel.global_transform * skel.get_bone_global_pose(foot).origin).y
		anim.jump(0.5, 0.75)
		var max_lift := 0.0
		var min_crouch := 0.0
		var hand_up := -9.0
		var foot_up := 0.0
		for i in 60:
			await physics_frame
			await process_frame
			var py: float = skel.position.y
			max_lift = maxf(max_lift, py)
			min_crouch = minf(min_crouch, py)
			hand_up = maxf(hand_up, (skel.global_transform * skel.get_bone_global_pose(hand).origin).y - rest_hand)
			foot_up = maxf(foot_up, (skel.global_transform * skel.get_bone_global_pose(foot).origin).y - rest_foot)
		print("[%s]" % sp)
		check("flight height", max_lift > 0.35 and max_lift < 0.6, str(max_lift))
		check("crouch lowers the body", min_crouch < -0.05, str(min_crouch))
		check("arms thrown above rest", hand_up > 0.4, str(hand_up))
		check("feet leave the ground", foot_up > 0.3, str(foot_up))
		check("jump ends", not anim.is_jumping())
		check("back to rest height", absf(skel.position.y) < 0.02, str(skel.position.y))
	# run: lean, arm pump and foot lift at 4.2 m/s versus a walk at 1.3 m/s
	var res := {}
	for mode in [["walk", 1.3], ["run", 4.2]]:
		var h2 := Node3D.new()
		root.add_child(h2)
		var m2 := VeilMeshyNpcs.model_for("Sarah")
		h2.add_child(m2)
		var a2: Node = NPC_ANIM.new()
		h2.add_child(a2)
		await process_frame
		await process_frame
		var sk: Skeleton3D = a2.skel
		var lf := sk.find_bone("LeftFoot")
		var rf := sk.find_bone("RightFoot")
		var hd := sk.find_bone("Head")
		var hp := sk.find_bone("Hips")
		var lh := sk.find_bone("LeftHand")
		a2.walk_to([Vector3(0, 0, -60)], mode[1])
		var foot_max := 0.0
		var lean := -9.0
		var hand_min := 9.0
		var hand_max := -9.0
		for i in 180:
			await physics_frame
			await process_frame
			if i < 60:
				continue
			var fp: Vector3 = sk.get_bone_global_pose(lf).origin
			var fr: Vector3 = sk.get_bone_global_pose(rf).origin
			foot_max = maxf(foot_max, maxf(fp.y, fr.y))
			var d: Vector3 = sk.get_bone_global_pose(hd).origin - sk.get_bone_global_pose(hp).origin
			lean = maxf(lean, absf(d.z))
			var hz: float = sk.get_bone_global_pose(lh).origin.z - sk.get_bone_global_pose(hp).origin.z
			hand_min = minf(hand_min, hz)
			hand_max = maxf(hand_max, hz)
		res[mode[0]] = {"foot": foot_max, "lean": lean, "swing": hand_max - hand_min}
		print("[%s] foot lift %.3f lean %.3f hand swing %.3f" % [mode[0], foot_max, lean, hand_max - hand_min])
	check("run lifts feet higher than walk", res["run"]["foot"] > res["walk"]["foot"] + 0.04)
	check("run arm swing (with bent elbows) at least as wide as walk", res["run"]["swing"] > res["walk"]["swing"] * 1.05)
	print("RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
