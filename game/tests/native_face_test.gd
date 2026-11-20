extends SceneTree
## Eddie as the Mixamo-rigged model: expression faces cut onto the new mesh, own clips, face controller answers the world's calls.
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
var fails := 0


func ok(n: String, c: bool, d := "") -> void:
	print("TEST ", n, " PASS " if c else " FAIL ", d)
	if not c:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var m := VeilMeshyNpcs.model_for("Eddie")
	holder.add_child(m)
	var a := NPC_ANIM.new()
	holder.add_child(a)
	await process_frame
	var ft := m.get_node_or_null("FaceTex") as VeilNpcFaceTex
	ok("mixamo_model", a._native)
	ok("face_controller", ft != null and ft._sm != null)
	var mesh: ArrayMesh
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin != null:
			mesh = (mi as MeshInstance3D).mesh as ArrayMesh
	ok("face_surface", mesh != null and mesh.get_surface_count() == 2)
	for ex in ["scared", "angry", "worried", "neutral"]:
		ft.expression = ex
		await process_frame
		ok("expression_" + ex, ft.state == ex or ft.state.begins_with(ex), ft.state)
	# the brows are their own geometry on the Head bone and move with the expression
	var bm := m.find_child("Brows", true, false) as MeshInstance3D
	ok("brow_geometry", bm != null and bm.mesh.get_surface_count() == 1)
	ft.expression = "scared"
	for i in 60:
		await process_frame
	var lift_scared: float = ft._brow.x
	ft.expression = "angry"
	for i in 60:
		await process_frame
	var lift_angry: float = ft._brow.x
	ok("brows_move", lift_scared > 0.006 and lift_angry < -0.003, "scared %.4f angry %.4f" % [lift_scared, lift_angry])
	ft.expression = "neutral"
	for i in 60:
		await process_frame
	ok("brows_return", absf(ft._brow.x) < 0.0005)
	ft.talking = true
	for i in 30:
		await process_frame
	ok("talking_cycles", ft.state.begins_with("talk") or ft.state == "neutral", ft.state)
	a.walk_to([Vector3(0, 0, -30)], 4.3)
	for i in 200:
		await process_frame
	ok("runs_with_own_clip", a._clip == "Running", a._clip)
	print("RESULT ", "FAIL" if fails else "PASS", " fails=", fails)
	quit(1 if fails else 0)
