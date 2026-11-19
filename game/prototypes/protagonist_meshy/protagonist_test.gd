extends Node
## THE VEIL - TEST SCENE: the Meshy protagonist standing at the supermarket till (lane 4), inside the real world with its mist and lighting.
##   godot --path . res://game/prototypes/protagonist_meshy/ProtagonistTest.tscn
## Starts from a chapter start (default 7, the supermarket as the shelter; `-- chapter 5` = the first, pitch dark night) (just inside the supermarket, the Veil outside) and replaces the cashier's model, procedural body animation
## (the game's own NpcAnimator: idle, look-at, talking gestures, scared mood) and face with the Meshy protagonist. Walk up to him and press E to talk.
## Nothing in the game's scenes or scripts is changed: this scene reaches into a running world.
## Your save file is backed up when this starts and put back when it ends (the world needs a save slot to load from).
##   Keys here:  1 neutral  2 scared  3 angry  4 talk on/off  5 blink  6 body mood calm  7 body mood scared  8 walk her to the doors and back
## Screenshot mode (needs a window):  ... ClerkTest.tscn -- shots <out_dir>

const CS := preload("res://game/chapters/chapter_select.gd")
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
const SAVE_BAK := "user://veil_save.json.clerk_test_backup"

var world: Node
var sarah: Node3D
var clerk: Node3D
var adapter: VeilSarahFaceAdapter
var shots_dir := ""
var lookcheck := false
var assist: VeilSarahLookAssist
var chapter := 7                          ## which chapter start to use: 5 = the first night (power out, pitch dark), 7 = the supermarket as the shelter, lights on
var _frames := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "shots" and i + 1 < args.size():
			shots_dir = args[i + 1]
		if args[i] == "lookcheck":
			lookcheck = true
		if args[i] == "chapter" and i + 1 < args.size():
			chapter = int(args[i + 1])
	_backup_save()
	var game := get_node("/root/Game")
	get_node("/root/Dialogue").auto_confirm = false
	if not CS.prepare(game, chapter):
		push_error("protagonist test: could not prepare the chapter 5 state")
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
	clerk = world.cashier
	if clerk == null:
		push_error("protagonist test: the world has no cashier")
		return
	# 1. the cashier's own model goes (freed now: the animator looks for a skeleton the moment it is added)
	for c in clerk.get_children():
		if c is Node3D and c.name != "Animator" and not c.find_children("*", "Skeleton3D", true, false).is_empty():
			clerk.remove_child(c)
			c.free()
	var old_anim := clerk.get_node_or_null("Animator")
	if old_anim:
		clerk.remove_child(old_anim)
		old_anim.free()
	var old_face := clerk.get_node_or_null("VeilFace")
	if old_face:
		clerk.remove_child(old_face)
		old_face.free()
	# 2. the Meshy protagonist, with the game's own procedural animator
	sarah = VeilProtagonistMeshy.instantiate()
	clerk.add_child(sarah)
	var anim: Node = NPC_ANIM.new()
	anim.name = "Animator"
	clerk.add_child(anim)
	world.animators["Cashier"] = anim
	assist = VeilSarahLookAssist.new()
	assist.name = "LookAssist"
	clerk.add_child(assist)
	assist.setup(anim, clerk)
	clerk.transform = Transform3D(Basis(), clerk.transform.origin)
	var want: Vector3 = world.market.global_transform.basis * (Basis(Vector3.UP, -PI * 0.5) * Vector3(0, 0, -1))
	want.y = 0.0
	clerk.rotate_y(anim.world_forward().signed_angle_to(want.normalized(), Vector3.UP))
	# 3. her face answers the world's VeilFace calls
	adapter = VeilSarahFaceAdapter.new()
	adapter.name = "VeilFace"
	clerk.add_child(adapter)
	adapter.setup(null)                                   # no face expressions for him yet: the adapter only keeps the world's calls harmless
	world.faces["Cashier"] = adapter
	clerk.visible = true
	# 4. a way to talk to her
	var it := Interactable.attach(clerk, {"kind": "custom", "label": "Protagonist", "prompt_text": "[E] Talk to him"})
	it.used.connect(func(_by):
		if world.can_talk(clerk):
			world.converse(["market_checkout"], [clerk]))
	get_node("/root/Dialogue").clear()
	print("CLERK TEST ready: the protagonist at ", clerk.global_position)
	if shots_dir != "":
		_shots.call_deferred()
	if lookcheck:
		_lookcheck.call_deferred()


func _process(_d: float) -> void:
	if clerk and is_instance_valid(clerk):
		clerk.visible = true                               # the world hides the clerk once the Veil has come; for this test she stays


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo) or adapter == null:
		return
	match (e as InputEventKey).physical_keycode:
		KEY_1:
			adapter.set_expression("neutral")
		KEY_2:
			adapter.set_expression("scared")
		KEY_3:
			adapter.set_expression("angry")
		KEY_4:
			adapter.stop_talking() if adapter.talking else adapter.start_talking()
		KEY_5:
			adapter.blink()
		KEY_6:
			world.animators["Cashier"].set_mood("calm")
		KEY_7:
			world.animators["Cashier"].set_mood("scared")
		KEY_8:
			var a = world.animators["Cashier"]
			var home: Vector3 = world.CASHIER_AT
			a.walk_to([Vector3(-3.5, 0.04, 4.0), Vector3(-1.5, 0.04, 6.0), Vector3(-3.5, 0.04, 4.0), home], 1.2)


# ---------------------------------------------------------------- screenshot mode
func _shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/clerk_%s.png" % [shots_dir, name])


func _stand(at_local: Vector3, look_local: Vector3) -> void:
	var m: Node3D = world.market
	world._put_player(m.to_global(at_local), m.to_global(look_local))
	world.player.controls_enabled = false


func _shots() -> void:
	world.hud.fade_to(0.0, 0.01)
	var fl = get_tree().get_first_node_in_group("veil_flashlight")
	if fl:
		fl.set_on(true)
	var look := Vector3(-4.85, 1.35, 4.0)
	var clerk_pos: Vector3 = world.market.to_local(clerk.global_position)
	# a wide view from inside the shop, a medium view, a close-up, from the side, and talking / scared
	_stand(clerk_pos + Vector3(2.0, 0, 5.0), look)
	await _shot("1_wide")
	_stand(clerk_pos + Vector3(1.2, 0, 2.2), look)
	await _shot("2_medium")
	_stand(clerk_pos + Vector3(0.5, 0, 1.0), Vector3(clerk_pos.x, 1.55, clerk_pos.z))
	await _shot("3_close")
	adapter.start_talking()
	for i in 14:
		await get_tree().process_frame
	await _shot("4_talking")
	adapter.stop_talking()
	adapter.set_expression("scared")
	world.animators["Cashier"].set_mood("scared")
	for i in 40:
		await get_tree().process_frame
	await _shot("5_scared")
	adapter.set_expression("neutral")
	world.animators["Cashier"].set_mood("calm")
	_stand(clerk_pos + Vector3(-3.0, 0, 2.0), look)
	for i in 60:
		await get_tree().process_frame
	await _shot("6_side")
	get_tree().quit()


# ---------------------------------------------------------------- how well does her head follow the player?
func _head_error() -> Array:
	var a: Node = world.animators["Cashier"]
	var sk: Skeleton3D = a.skel
	var head: int = a.bone("Head")
	var gp := sk.get_bone_global_pose(head)
	var rest := sk.get_bone_global_rest(head)
	var fwd_local: Vector3 = (gp.basis * rest.basis.inverse()) * a.F                 # the head's forward, in skeleton space
	var fwd: Vector3 = sk.global_transform.basis * fwd_local
	var head_w: Vector3 = sk.global_transform * gp.origin
	var to: Vector3 = world.player.camera.global_position - head_w
	var h_to := Vector3(to.x, 0, to.z).normalized()
	var h_f := Vector3(fwd.x, 0, fwd.z).normalized()
	var body: Vector3 = a.world_forward()
	return [rad_to_deg(h_f.signed_angle_to(h_to, Vector3.UP)), rad_to_deg(Vector3(body.x, 0, body.z).normalized().signed_angle_to(h_to, Vector3.UP)),
		rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()) - atan2(fwd.y, Vector2(fwd.x, fwd.z).length()))]


func _lookcheck() -> void:
	world.hud.fade_to(0.0, 0.01)
	var m: Node3D = world.market
	var cp: Vector3 = m.to_local(clerk.global_position)
	var a = world.animators["Cashier"]
	a.turn_to_face = false                                # measure the head alone: the body stays put
	assist.enabled = "noassist" not in OS.get_cmdline_user_args()
	var fwd_l: Vector3 = m.to_local(clerk.global_position + a.world_forward()) - cp
	for deg in [0, 20, 40, 60, 80, 100]:
		var ang := deg_to_rad(float(deg))
		var dir := Vector3(fwd_l.x * cos(ang) - fwd_l.z * sin(ang), 0, fwd_l.x * sin(ang) + fwd_l.z * cos(ang)).normalized()
		_stand(cp + dir * 1.8, cp + Vector3(0, 0, 0))
		for i in 150:
			await get_tree().process_frame
		var e := _head_error()
		print("LOOK target %3d deg off her facing: head yaw error %.1f deg (body error %.1f), pitch error %.1f" % [deg, e[0], e[1], e[2]])
	get_tree().quit()
