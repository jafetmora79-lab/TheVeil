extends SceneTree
## The Mixamo-rigged NPCs (bomber, woman_red_plaid, tan_jacket) play their own clips: walk, run, jump, sit (NpcAnimator native mode).
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
var fails := 0


func ok(n: String, c: bool, d := "") -> void:
	print("TEST ", n, " PASS " if c else " FAIL ", d)
	if not c:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for sp in ["Civilian_A", "Civilian_B", "Res_Neighbour", "Eddie", "Marcus", "Officer", "Noah", "Ruth", "Survivor"]:
		var holder := Node3D.new()
		root.add_child(holder)
		var m := VeilMeshyNpcs.model_for(sp)
		holder.add_child(m)
		var a := NPC_ANIM.new()
		holder.add_child(a)
		await process_frame
		ok(sp + "_native", a._native and a._ap != null)
		a.walk_to([Vector3(0, 0, -30)], 1.25)
		for i in 90:
			await process_frame
		ok(sp + "_walking", a._clip == "Walking" and a._clip_on, a._clip)
		a.walk_to([Vector3(0, 0, -80)], 4.3)
		for i in 240:
			await process_frame
		ok(sp + "_running", a._clip == "Running", a._clip)
		a.walk_to([])
		for i in 120:
			await process_frame
		ok(sp + "_idle_back_to_animator", not a._clip_on)
		a.jump(0.5, 1.0)
		for i in 20:
			await process_frame
		ok(sp + "_jump", a._clip == "Jump" or not a._ap.has_animation("Jump"), a._clip)
		for i in 90:
			await process_frame
		a.set_seated(true)
		for i in 90:
			await process_frame
		ok(sp + "_sit", a._clip == "Chair_Sit_Idle_M" or not a._ap.has_animation("Chair_Sit_Idle_M"), a._clip)
		var hip := a.skel.get_bone_global_pose(a.bone("Hips")).origin.y + a.skel.position.y
		ok(sp + "_seated_pelvis_low", hip < 0.8, "%.2f" % hip)
		a.set_seated(false)
		for i in 120:
			await process_frame
		ok(sp + "_stands_again", not a._clip_on)
		holder.queue_free()
	print("RESULT ", "FAIL" if fails else "PASS", " fails=", fails)
	quit(1 if fails else 0)
