extends Node
## Plays the REAL game's Colossus encounter (the Veil rolls in, the player steps outside, the leg slams down, the protagonist's frightened face, the camera
## follows his gaze up into the mist) and records it as PNG frames. The save file is backed up and restored.
##   godot --path . --fixed-fps 24 --resolution 960x540 res://game/prototypes/npc_meshy/ColossusEncounterRecord.tscn -- frames <out_dir> [market]
## (steps out of the game shop by default; `market` steps out of the supermarket instead)
const CS := preload("res://game/chapters/chapter_select.gd")
const SAVE_BAK := "user://veil_save.json.record_backup"
var world: Node
var out := ""
var market := false


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "frames" and i + 1 < a.size():
			out = a[i + 1]
		if a[i] == "market":
			market = true
	var p := ProjectSettings.globalize_path("user://veil_save.json")
	if FileAccess.file_exists("user://veil_save.json") and not FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(p, ProjectSettings.globalize_path(SAVE_BAK))
	var game := get_node("/root/Game")
	get_node("/root/Dialogue").auto_confirm = true
	CS.prepare(game, 3)
	world = load("res://game/scenes/World.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _restore() -> void:
	if FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_BAK), ProjectSettings.globalize_path("user://veil_save.json"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_BAK))


func _run() -> void:
	for i in 120:
		await get_tree().process_frame
	var game := get_node("/root/Game")
	print("RECORD start: flags mist=%s stepped_out=%s" % [game.has_flag("p3_mist"), game.has_flag("p3_stepped_out")])
	# the Veil rolls in once the errands are done
	var waited := 0
	while not game.has_flag("p3_mist") and waited < 900:
		await get_tree().process_frame
		waited += 1
	print("RECORD mist after ", waited, " frames: ", game.has_flag("p3_mist"))
	for i in 96:
		await get_tree().process_frame
	# step outside the store
	var store: Node3D = world.market if market else world.game_shop
	var d_in := (store.get_node("Doorways/Entrance_Inside") as Node3D).global_position
	var d_out := (store.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var n := ((d_out - d_in) * Vector3(1, 0, 1)).normalized()
	world.player.controls_enabled = true
	world._put_player(d_out + n * 2.2, d_out + n * 12.0 + Vector3(0, 1.4, 0))
	var idx := 0
	var started := false
	var frames_after := 0
	for k in 1500:
		await get_tree().process_frame
		if world._encounter_running:
			started = true
		if started and not world._encounter_running:
			frames_after += 1
		if k % 2 == 0 and (started or k < 6):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/enc_%03d.png" % [out, idx])
			idx += 1
		if frames_after > 72:
			break
	print("RECORD frames ", idx, " encounter started ", started)
	_restore()
	get_tree().quit()
