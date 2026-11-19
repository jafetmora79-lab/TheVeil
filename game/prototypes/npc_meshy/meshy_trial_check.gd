extends Node
## Automated check of the Meshy NPC trial (Cashier -> store_clerk, Eddie -> eddie) inside the REAL world (headless, needs the autoloads, so it is a scene):
##   godot --headless --path . res://game/prototypes/npc_meshy/MeshyTrialCheck.tscn                      (switch off: the old characters must be untouched)
##   godot --headless --path . res://game/prototypes/npc_meshy/MeshyTrialCheck.tscn -- meshy_npcs       (switch on: the Meshy characters stand in)
## Your save file is backed up and restored.
const CS := preload("res://game/chapters/chapter_select.gd")
const SAVE_BAK := "user://veil_save.json.trial_backup"
var world: Node
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _ready() -> void:
	var p := ProjectSettings.globalize_path("user://veil_save.json")
	if FileAccess.file_exists("user://veil_save.json") and not FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(p, ProjectSettings.globalize_path(SAVE_BAK))
	var game := get_node("/root/Game")
	get_node("/root/Dialogue").auto_confirm = false
	if not CS.prepare(game, 7):
		print("RESULT FAIL (could not prepare chapter 7)")
		_done()
		return
	world = load("res://game/scenes/World.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _done() -> void:
	if FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_BAK), ProjectSettings.globalize_path("user://veil_save.json"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_BAK))
	get_tree().quit(1 if fails else 0)


func _bones(n: Node) -> int:
	var s := n.find_children("*", "Skeleton3D", true, false)
	return (s[0] as Skeleton3D).get_bone_count() if not s.is_empty() else 0


func _run() -> void:
	for i in 100:
		await get_tree().process_frame
	var on := VeilMeshyNpcs.enabled()
	print("SWITCH ", "ON" if on else "off")
	for pair in [["Cashier", world.cashier], ["Eddie", world.eddie]]:
		var nm: String = pair[0]
		var body: Node3D = pair[1]
		ok(nm + "_exists", body != null)
		if body == null:
			continue
		var bones := _bones(body)
		var face: Node = world.faces.get(nm)
		var anim: Node = world.animators.get(nm)
		ok(nm + "_animator", anim != null)
		ok(nm + "_face_node", face != null and body.get_node_or_null("VeilFace") != null)
		if on:
			ok(nm + "_is_meshy_51_bones", bones == 51, str(bones))
			ok(nm + "_face_is_meshy", face is VeilMeshyNpcFace)
			var f := face as VeilMeshyNpcFace
			f.set_expression("scared")
			ok(nm + "_scared", f.face.state == "scared")
			f.set_expression("neutral")
			f.start_talking()
			var seen := {}
			for i in 60:
				await get_tree().process_frame
				seen[f.face.state] = true
			ok(nm + "_talks", seen.has("talk_small") or seen.has("talk_wide"), str(seen.keys()))
			f.stop_talking()
			f.set_expression("shocked")
			ok(nm + "_shocked_maps_to_scared", f.face.state == "scared")
			f.set_expression("sad")
			ok(nm + "_sad_maps_to_worried", f.face.state == "worried")
			f.set_expression("neutral")
			f.widen_eyes(0.2)
			ok(nm + "_widen_eyes", f.face.state == "scared")
		else:
			ok(nm + "_old_model_untouched", bones != 51, str(bones))
			ok(nm + "_old_face_script", not (face is VeilMeshyNpcFace))
		# the body stands on the floor, visible, with the capsule the game gave it
		ok(nm + "_on_the_floor", body.global_position.y > -0.5 and body.global_position.y < 3.0, str(body.global_position))
	# the game keeps running with them for a while (the animator turns them, nothing errors)
	for i in 240:
		await get_tree().process_frame
	ok("still_running", world.is_inside_tree())
	print("RESULT ", "PASS" if fails == 0 else "%d failures" % fails)
	_done()
