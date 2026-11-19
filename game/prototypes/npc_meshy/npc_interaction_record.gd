extends Node
## Plays a REAL conversation of the game (the game's talk camera, the speaker's face and body animation, the dialogue lines) and records it as PNG frames.
##   godot --path . --fixed-fps 24 --resolution 960x540 res://game/prototypes/npc_meshy/NpcInteractionRecord.tscn -- frames <out_dir> [eddie|cashier]
## eddie = "eddie_hello" in the game shop; cashier = "market_checkout" at lane 4. The save file is backed up and restored.
const CS := preload("res://game/chapters/chapter_select.gd")
const SAVE_BAK := "user://veil_save.json.record_backup"
var world: Node
var out := ""
var who := "eddie"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "frames" and i + 1 < a.size():
			out = a[i + 1]
		if a[i] in ["eddie", "cashier"]:
			who = a[i]
	var p := ProjectSettings.globalize_path("user://veil_save.json")
	if FileAccess.file_exists("user://veil_save.json") and not FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(p, ProjectSettings.globalize_path(SAVE_BAK))
	var game := get_node("/root/Game")
	get_node("/root/Dialogue").auto_confirm = true
	CS.prepare(game, 2)
	world = load("res://game/scenes/World.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _restore() -> void:
	if FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_BAK), ProjectSettings.globalize_path("user://veil_save.json"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_BAK))


func _run() -> void:
	for i in 150:
		await get_tree().process_frame
	world.hud.fade_to(0.0, 0.01)
	var npc: Node3D = world.eddie if who == "eddie" else world.cashier
	npc.visible = true
	var fwd: Vector3 = world.animators[String(npc.name)].world_forward()
	world.player.controls_enabled = true
	world._put_player(npc.global_position + fwd * 2.6, npc.global_position + Vector3(0, 1.45, 0))
	for i in 20:
		await get_tree().process_frame
	var ids: Array = ["eddie_hello"] if who == "eddie" else ["market_checkout"]
	print("RECORD talking to ", who, " can_talk=", world.can_talk(npc))
	world.converse(ids, [npc])
	var idx := 0
	var after := 0
	var started := false
	for k in 1800:
		await get_tree().process_frame
		if world.conversing:
			started = true
		if started and not world.conversing:
			after += 1
		if k % 2 == 0 and (started or k < 4):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/talk_%s_%03d.png" % [out, who, idx])
			idx += 1
		if after > 36:
			break
	print("RECORD frames ", idx, " started ", started)
	_restore()
	get_tree().quit()
