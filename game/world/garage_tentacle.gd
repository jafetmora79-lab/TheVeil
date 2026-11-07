extends Node
class_name VeilGarageTentacle
## THE VEIL - Chapter 4: the loading-bay tentacle. The roll-up door is still open (the 0.9 m gap); something waits
## outside. On the player's approach (after the breaker, before the door is pulled down):
##   reveal (camera held, ~2.5 s): the view turns to the gap; a Pack 07 Mist Tentacle lying on its side slides in
##     under the door out of the dark (its Emerge clip: the part still outside dithers away); a wet drag
##   escape: control comes back, THEN a 10 s countdown: pull the loading door down (the existing handle)
##   success: the tentacle is forced back out, the door shuts, one heavy impact, silence, "Holy shit..."
##   failure: it takes his leg - first person: look down, fall, dragged across the floor to the gap, black, YOU DIED
##     -> RETRY (the save made when the encounter started: the door open, the tentacle hidden, the timer reset)
## Flag p4_garage_done once survived (never replays).

const TENTACLE := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn"
const ROOT := Vector3(20.3, 0.35, 15.9)              # market frame: just outside the roll-up door's plane (x 20.05)
const GAP_LOOK := Vector3(19.6, 0.45, 15.9)
const ESCAPE_S := 10.0

var p4: Node
var world: Node
var player: Node3D
var running := false
var closing := false
var tentacle: Node3D
var time_left := 0.0
var report := {}


func setup(phase4: Node) -> void:
	p4 = phase4
	world = p4.world
	player = p4.player



## Checked every 0.2 s (not an area's body_entered: the breaker panel stands inside the loading bay, so the player is
## already in there when the breaker comes on and would never "enter"): towards the door, past the breaker.
var _tick := 0.0
func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0 or running or player == null:
		return
	_tick = 0.2
	var l: Vector3 = p4.market.to_local(player.global_position)
	if l.x > 17.2 and l.x < 20.0 and absf(l.z - 15.9) < 1.8 and player.get("controls_enabled") \
			and world.get("_world_live") == true and Game.has_flag("p4_flashlight"):
		_on_enter()                                  # (never while a load / retry is still restoring the world)


func _on_enter() -> void:
	if running or Game.has_flag("p4_garage_done") or Game.has_flag("p4_loading_down") or not Game.has_flag("p4_started"):
		return
	running = true
	world.save()                                       # the checkpoint: RETRY comes back to here
	var back: Vector3 = p4.ml(Vector3(15.6, 0.0, 15.9))
	back.y = player.global_position.y
	Game.player_state["pos"] = [back.x, back.y, back.z]   # ...a step back from the door, outside the trigger
	Game.save_game()
	await _reveal()
	await _escape()


# ------------------------------------------------------------------ reveal
func _reveal() -> void:
	player.set("velocity", Vector3.ZERO)
	var src: Camera3D = player.get("camera")
	var cam := Camera3D.new()
	cam.name = "GarageCam"
	world.add_child(cam)
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.current = true
	p4._hold_cam(cam)
	# 1. warning (short): a scrape outside, the door rattles in its rails, something heavy hits it
	p4._play("scrape" if p4._streams.has("scrape") else "slither", p4.ml(GAP_LOOK), 2.0)
	await p4._fp_face(cam, p4.ml(GAP_LOOK + Vector3(0, 0.4, 0)), 0.35)
	var ld: Node3D = p4.its.get("loading_door")
	if ld:
		var t0 := ld.transform
		var tr := create_tween()
		for k in 3:
			tr.tween_property(ld, "transform", Transform3D(t0.basis, t0.origin + Vector3(0, 0.03 * (1 - 2 * (k % 2)), 0)), 0.05)
		tr.tween_property(ld, "transform", t0, 0.05)
	await get_tree().create_timer(0.25).timeout
	p4._play("impact", p4.ml(Vector3(20.1, 0.9, 15.9)), 4.0)
	world._shake(cam, 0.2, 0.03)
	await get_tree().create_timer(0.3).timeout
	# 2. the thrust: from outside, under the door, in a fifth of a second - hard acceleration, a dead stop
	var ps := load(TENTACLE) as PackedScene
	if ps:
		tentacle = ps.instantiate() as Node3D
		tentacle.name = "P4_GarageTentacle"
		tentacle.set("autoplay", "")
		p4.market.add_child(tentacle)
		var aim := _aim_basis()
		tentacle.transform = Transform3D(aim, ROOT + Vector3(2.2, 0, 0))      # out of sight, outside the door
		if tentacle.has_method("emerge"):
			tentacle.call("emerge")
		if tentacle.has_method("play"):
			tentacle.call("play", "Strike", 0.05)
		var th := tentacle.create_tween()
		th.tween_property(tentacle, "position", ROOT, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	p4._play("slither", p4.ml(GAP_LOOK), 6.0)
	world._shake(cam, 0.35, 0.05)
	await p4._fp_face(cam, p4.ml(GAP_LOOK + Vector3(-1.2, 0.2, 0)), 0.18)    # the view snaps to it
	# 3. a breath of stillness, then it lunges for the player and is jerked short at the end of its reach
	await get_tree().create_timer(0.4).timeout
	if tentacle and is_instance_valid(tentacle):
		var to: Vector3 = p4.market.to_local(player.global_position) - ROOT
		to.y = 0.0
		var reach := clampf(to.length() - 1.4, 0.4, 2.0)
		tentacle.transform.basis = _aim_basis()
		var tg := tentacle.create_tween()
		tg.tween_property(tentacle, "position", ROOT + to.normalized() * reach, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tg.tween_property(tentacle, "position", ROOT + to.normalized() * reach * 0.55, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("hurt", player.global_position, -10.0, 1.4)            # a gasp: it missed, just
		world._shake(cam, 0.3, 0.06)
	await get_tree().create_timer(0.5).timeout
	report["revealed"] = tentacle != null
	# control back (move + look), then the timer
	p4._cam_held = null
	var fwd := -cam.global_basis.z
	player.call("set_yaw_pitch", atan2(-fwd.x, -fwd.z), clampf(asin(clampf(fwd.y, -1.0, 1.0)), -0.6, 0.6))
	cam.queue_free()
	src.current = true
	player.set("controls_enabled", true)
	player.set("look_enabled", true)


# ------------------------------------------------------------------ 10 s escape
func _escape() -> void:
	report["control_before_timer"] = player.get("controls_enabled") and player.get("look_enabled")
	time_left = ESCAPE_S
	var hud: Node = world.get("hud")
	hud.title_card("CLOSE THE GARAGE DOOR — NOW!", 1.4)
	p4._music("chase", -14.0)
	var mp: AudioStreamPlayer = p4._music_player
	while time_left > 0.0 and not closing:
		var dt := get_process_delta_time()
		time_left -= dt
		hud.set_hint("CLOSE THE GARAGE DOOR — NOW!   %.1f" % maxf(time_left, 0.0))
		if mp:
			mp.volume_db = lerpf(-14.0, -1.0, 1.0 - time_left / ESCAPE_S)      # it builds as time runs out
		_creep(dt)
		await get_tree().process_frame
	hud.set_hint("")
	report["time_left"] = time_left
	if closing:
		await _survived()
	else:
		await _taken()


## On its side, pointing into the bay (+Y -> -X), swung towards the player (kept within the door opening's arc).
func _aim_basis() -> Basis:
	var to: Vector3 = p4.market.to_local(player.global_position) - ROOT
	return Basis(Vector3.UP, clampf(atan2(-to.z, -to.x), -0.9, 0.9)) * Basis(Vector3(0, 0, 1), PI * 0.5)


## While the player runs: the tentacle keeps searching and turns after him; past half time it reaches.
func _creep(dt: float) -> void:
	if tentacle == null:
		return
	var to: Vector3 = p4.market.to_local(player.global_position) - ROOT
	var yaw := atan2(-to.z, -to.x)                     # in the floor plane, from -X
	var want := Basis(Vector3.UP, clampf(yaw, -0.9, 0.9)) * Basis(Vector3(0, 0, 1), PI * 0.5)
	tentacle.transform.basis = tentacle.transform.basis.slerp(want, minf(dt * 1.5, 1.0))
	if time_left < ESCAPE_S * 0.5 and not tentacle.has_meta("reaching") and tentacle.has_method("play"):
		tentacle.set_meta("reaching", true)
		tentacle.call("play", "Reach")


## Phase 4's loading handle was used: the door comes down.
func on_close_started() -> void:
	if running and time_left > 0.0:
		closing = true


func _survived() -> void:
	if tentacle and tentacle.has_method("retract"):
		tentacle.call("retract")                        # forced back out under the closing door
		var tw := tentacle.create_tween()
		tw.tween_property(tentacle, "position", ROOT + Vector3(2.4, 0, 0), 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	while not Game.has_flag("p4_loading_down"):
		await get_tree().process_frame
	p4._play("impact", p4.ml(Vector3(20.1, 0.9, 15.9)), 6.0)   # one heavy hit on the shut door
	world._shake(player.get("camera"), 0.3, 0.04)
	p4._music_stop(0.15)
	if tentacle:
		tentacle.queue_free()
	await get_tree().create_timer(1.4).timeout         # silence
	Dialogue.say("p4_garage_safe", false, true)
	Sfx.start_ambience()
	Game.set_flag("p4_garage_done")
	report["survived"] = true
	running = false


# ------------------------------------------------------------------ failure: dragged out
func _taken() -> void:
	report["taken"] = true
	var src: Camera3D = player.get("camera")
	var cam := Camera3D.new()
	cam.name = "GarageDeathCam"
	world.add_child(cam)
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.current = true
	p4._hold_cam(cam)
	var feet := player.global_position
	var out_dir: Vector3 = (p4.ml(ROOT) - feet) * Vector3(1, 0, 1)
	out_dir = out_dir.normalized()
	# the tentacle lashes to his leg
	if tentacle:
		var to: Vector3 = p4.market.to_local(feet) - ROOT
		tentacle.transform.basis = Basis(Vector3.UP, atan2(-to.z, -to.x)) * Basis(Vector3(0, 0, 1), PI * 0.5)
		if tentacle.has_method("play"):
			tentacle.call("play", "Strike", 0.05)
		var reach := minf(to.length() - 3.6, 3.0)       # its tip at his ankle
		if reach > 0.0:
			var tw := tentacle.create_tween()
			tw.tween_property(tentacle, "position", ROOT + Vector3(to.x, 0, to.z).normalized() * reach, 0.3)
	Sfx.play("hurt", feet, -2.0, 0.7)
	await p4._fp_face(cam, feet + Vector3(0, 0.1, 0) - out_dir * 0.15, 0.3)   # looks down: it has his leg
	await get_tree().create_timer(0.45).timeout
	# he falls
	var tf := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tf.tween_property(cam, "global_position", feet + Vector3(0, 0.32, 0) - out_dir * 0.2, 0.35)
	tf.parallel().tween_property(cam, "rotation:z", deg_to_rad(22.0), 0.35)
	await tf.finished
	world._shake(cam, 0.25, 0.06)
	p4._play("impact", feet, -4.0)
	# dragged across the floor, out under the door
	var gap: Vector3 = p4.ml(Vector3(20.6, 0.32, 15.9))
	var start := cam.global_position
	var t := 0.0
	var dur := 1.7
	while t < dur:
		t += get_process_delta_time()
		var k := clampf(t / dur, 0.0, 1.0)
		cam.global_position = start.lerp(gap, k * k) + Vector3(randf_range(-0.02, 0.02), randf_range(-0.015, 0.015), 0)
		var back := Transform3D(Basis(), cam.global_position).looking_at(cam.global_position - out_dir * 2.0 + Vector3(0, 0.6, 0), Vector3.UP).basis
		cam.global_basis = Basis(cam.global_basis.get_rotation_quaternion().slerp(back.get_rotation_quaternion(), minf(get_process_delta_time() * 4.0, 1.0)))
		if tentacle:
			tentacle.global_position = tentacle.global_position.lerp(cam.global_position + out_dir * 3.4 - Vector3(0, 0.0, 0), minf(get_process_delta_time() * 6.0, 1.0))
		await get_tree().process_frame
	p4._play("slither", gap, 6.0)
	var hud: Node = world.get("hud")
	await hud.fade_to(1.0, 0.25)                        # into the dark
	p4._music_stop(0.1)
	report["dragged_out"] = true
	var panel := VeilChoicePanel.new()
	panel.name = "DeathPanel"
	world.add_child(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var i: int = await panel.ask("YOU DIED", ["RETRY", "MAIN MENU"])
	# leave nothing running into the reload: the held camera, the creature, the music, any pause
	p4._cam_held = null
	if tentacle and is_instance_valid(tentacle):
		tentacle.queue_free()
	tentacle = null
	p4._music_stop(0.0)
	running = false
	get_tree().paused = false
	if i == 0:
		# the checkpoint saved when the encounter began (a step back from the door); reloaded on the next frame,
		# outside this button's signal
		(func(): VeilDeathSequence.retry()).call_deferred()
	else:
		world.call("_to_menu")
