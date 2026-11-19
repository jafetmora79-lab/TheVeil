extends Node
## THE VEIL - TEST SCENE: the nine Meshy NPCs (with their face-texture expressions) standing in the real chapter 7 supermarket, animated by the game's own
## NpcAnimator (idle, look-at, talking gestures, scared mood). Nothing in the game's scenes or scripts is changed: this scene reaches into a running world.
##   godot --path . res://game/prototypes/npc_meshy/NpcSupermarketTest.tscn            (walk around: WASD; your save file is backed up and restored)
## Keys: 1-9 pick an NPC (shown in the title), then  T talk on/off, B blink, S scared (body + face), A angry, W worried, N neutral.
## Screenshot mode (needs a window):  ... NpcSupermarketTest.tscn -- shots <out_dir> chapter 7

const CS := preload("res://game/chapters/chapter_select.gd")
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
const SAVE_BAK := "user://veil_save.json.npc_test_backup"
const ORDER := ["police_officer", "eddie", "plaid_shirt", "bearded_man", "police_cap", "elderly_woman", "police_redhair", "store_clerk", "teen_blue_jacket"]

var world: Node
var shots_dir := ""
var chapter := 7
var npcs := {}                                ## slug -> {"holder": Node3D, "anim": NPC_ANIM, "face": VeilNpcFaceTex}
var picked := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "shots" and i + 1 < args.size():
			shots_dir = args[i + 1]
		if args[i] == "chapter" and i + 1 < args.size():
			chapter = int(args[i + 1])
	_backup_save()
	var game := get_node("/root/Game")
	get_node("/root/Dialogue").auto_confirm = false
	if not CS.prepare(game, chapter):
		push_error("npc test: could not prepare the chapter state")
		return
	world = load("res://game/scenes/World.tscn").instantiate()
	add_child(world)
	_setup.call_deferred()


func _backup_save() -> void:
	var p := ProjectSettings.globalize_path("user://veil_save.json")
	if FileAccess.file_exists("user://veil_save.json") and not FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(p, ProjectSettings.globalize_path(SAVE_BAK))


func _restore_save() -> void:
	if FileAccess.file_exists(SAVE_BAK):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_BAK), ProjectSettings.globalize_path("user://veil_save.json"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_BAK))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_restore_save()


func _exit_tree() -> void:
	_restore_save()


func _setup() -> void:
	for i in 90:
		await get_tree().process_frame
	var clerk: Node3D = world.cashier
	var cp: Vector3 = world.market.to_local(clerk.global_position)
	# the nine NPCs stand in a loose row east of the till, facing the shop floor
	for i in ORDER.size():
		var slug: String = ORDER[i]
		var holder := Node3D.new()
		holder.name = "NPC_" + slug
		world.market.add_child(holder)
		var model := VeilNpcFaceTex.instantiate(slug)
		holder.add_child(model)
		var anim: Node = NPC_ANIM.new()
		anim.name = "Animator"
		holder.add_child(anim)
		var face := model.get_node("FaceTex") as VeilNpcFaceTex
		holder.position = cp + Vector3(2.6 + (i % 2) * 0.5, 0.0, -3.4 + float(i) * 0.95)
		holder.rotation.y = -PI * 0.5                     # faces -Z in its own frame; turn toward +X (where the player stands)
		npcs[slug] = {"holder": holder, "anim": anim, "face": face}
	get_node("/root/Dialogue").clear()
	print("NPC TEST ready: ", npcs.size(), " NPCs around ", cp)
	if shots_dir != "":
		_shots.call_deferred()


func _pick(slug: String) -> Dictionary:
	return npcs[slug]


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo) or npcs.is_empty():
		return
	var k := (e as InputEventKey).physical_keycode
	if k >= KEY_1 and k <= KEY_9:
		picked = k - KEY_1
		print("picked ", ORDER[picked])
		return
	var d: Dictionary = npcs[ORDER[picked]]
	var f: VeilNpcFaceTex = d["face"]
	match k:
		KEY_T:
			f.talking = not f.talking
			d["anim"].talk(8.0 if f.talking else 0.0)
		KEY_B:
			f.blink()
		KEY_S:
			f.expression = "scared"
			d["anim"].set_mood("scared")
		KEY_A:
			f.expression = "angry"
		KEY_W:
			f.expression = "worried"
		KEY_N:
			f.expression = "neutral"
			d["anim"].set_mood("calm")


# ---------------------------------------------------------------- screenshot mode
func _shot(name: String) -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/npcs_%s.png" % [shots_dir, name])


func _stand(at_local: Vector3, look_local: Vector3) -> void:
	var m: Node3D = world.market
	world._put_player(m.to_global(at_local), m.to_global(look_local))
	world.player.controls_enabled = false


func _shots() -> void:
	world.hud.fade_to(0.0, 0.01)
	var fl = get_tree().get_first_node_in_group("veil_flashlight")
	if fl:
		fl.set_on(true)
	var cp: Vector3 = world.market.to_local(world.cashier.global_position)
	var mid := cp + Vector3(2.8, 1.3, 0.8)
	# 1. the whole group from the shop floor, 2. from further back
	_stand(cp + Vector3(7.0, 0, 0.8), mid)
	for i in 30:
		await get_tree().process_frame
	await _shot("1_group")
	_stand(cp + Vector3(5.2, 0, 0.8), mid)
	for i in 20:
		await get_tree().process_frame
	await _shot("2_group_closer")
	# 3. three of them react: one scared (body and face), one talking, one angry
	(npcs["police_officer"]["face"] as VeilNpcFaceTex).expression = "scared"
	npcs["police_officer"]["anim"].set_mood("scared")
	(npcs["elderly_woman"]["face"] as VeilNpcFaceTex).talking = true
	npcs["elderly_woman"]["anim"].talk(10.0)
	(npcs["teen_blue_jacket"]["face"] as VeilNpcFaceTex).expression = "angry"
	(npcs["store_clerk"]["face"] as VeilNpcFaceTex).expression = "worried"
	for i in 50:
		await get_tree().process_frame
	await _shot("3_reacting")
	# 4. close-ups of a few
	for slug in ["police_officer", "elderly_woman", "teen_blue_jacket", "store_clerk"]:
		var hp: Vector3 = (npcs[slug]["holder"] as Node3D).position
		_stand(hp + Vector3(1.0, 0, 0.1), hp + Vector3(0, 1.55, 0))
		for i in 14:
			await get_tree().process_frame
		await _shot("4_close_" + slug)
	get_tree().quit()
