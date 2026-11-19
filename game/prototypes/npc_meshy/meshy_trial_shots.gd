extends Node
## Screenshots of the Meshy NPC trial in the real world (needs a window):
##   godot --path . --resolution 960x540 res://game/prototypes/npc_meshy/MeshyTrialShots.tscn -- meshy_npcs shots <out_dir>
const CS := preload("res://game/chapters/chapter_select.gd")
const SAVE_BAK := "user://veil_save.json.trial_backup"
var world: Node
var out := ""


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "shots" and i + 1 < a.size():
			out = a[i + 1]
	var p := ProjectSettings.globalize_path("user://veil_save.json")
	if FileAccess.file_exists("user://veil_save.json") and not FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(p, ProjectSettings.globalize_path(SAVE_BAK))
	var game := get_node("/root/Game")
	get_node("/root/Dialogue").auto_confirm = false
	CS.prepare(game, 7)
	world = load("res://game/scenes/World.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/trial_%s.png" % [out, name])


func _face(body: Node3D, from_dist: float, height: float, name: String) -> void:
	body.visible = true
	var hp := body.global_position + Vector3(0, height, 0)
	var fwd: Vector3 = world.animators[String(body.name)].world_forward()
	world._put_player(body.global_position + fwd * from_dist, hp)
	world.player.controls_enabled = false
	await _shot(name)


func _run() -> void:
	for i in 100:
		await get_tree().process_frame
	world.hud.fade_to(0.0, 0.01)
	var fl = get_tree().get_first_node_in_group("veil_flashlight")
	if fl:
		fl.set_on(true)
	world.cashier.visible = true                      # (from chapter 7 on the world hides the cashier: people are going missing)
	await _face(world.cashier, 2.6, 1.3, "cashier_medium")
	await _face(world.cashier, 1.1, 1.55, "cashier_close")
	(world.faces["Cashier"] as Node).set_expression("scared")
	world.animators["Cashier"].set_mood("scared")
	for i in 40:
		await get_tree().process_frame
	await _face(world.cashier, 1.3, 1.55, "cashier_scared")
	await _face(world.eddie, 2.8, 1.3, "eddie_medium")
	await _face(world.eddie, 1.1, 1.55, "eddie_close")
	(world.faces["Eddie"] as Node).start_talking()
	world.animators["Eddie"].talk(6.0)
	for i in 30:
		await get_tree().process_frame
	await _face(world.eddie, 1.2, 1.55, "eddie_talking")
	if FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_BAK), ProjectSettings.globalize_path("user://veil_save.json"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_BAK))
	get_tree().quit()
