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
## Not lying flat along the floor (it read as a tube slid in on its side): it rises from the gap at about 20 degrees,
## at the player, its base out of sight outside the door (0.25 m in, it is 9 cm higher: still under the 0.9 m gap).
const LIFT := PI * 0.5 - 0.35

var p4: Node
var world: Node
var player: Node3D
var running := false
var closing := false
var tentacle: VeilDoorwayTentacle      ## its own creature (game/enemies/doorway_tentacle.gd)
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
	# 2. the thrust: the doorway tentacle (game/enemies/doorway_tentacle.gd), its root buried outside the dock. The
	#    tip shoots under the door and along the floor, then rears up into the player's line of sight; every segment
	#    follows the same line through the gap
	tentacle = VeilDoorwayTentacle.create(p4.market)
	tentacle.name = "P4_GarageTentacle"
	_aim_path(cam.global_position, (p4.ml(GAP_LOOK + Vector3(0, 0.5, 0)) - cam.global_position))
	tentacle.writhe = 1.3
	tentacle.writhe_hz = 5.0
	p4._play("slither", p4.ml(GAP_LOOK), 6.0)
	var th := create_tween()
	th.tween_property(tentacle, "head", ROOT_TO_GAP + 0.6, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	th.tween_property(tentacle, "head", tentacle.path_length(), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	world._shake(cam, 0.35, 0.05)
	await p4._fp_face(cam, p4.ml(GAP_LOOK + Vector3(0, 0.5, 0)), 0.2)        # the view snaps to where it comes in
	await th.finished
	# 3. the scare beat: its tip right in front of the face, lashing
	tentacle.writhe = 1.6
	tentacle.writhe_hz = 6.0
	Sfx.play("hurt", player.global_position, -10.0, 1.4)            # a gasp
	world._shake(cam, 0.3, 0.06)
	_measure_gaze(cam)
	await get_tree().create_timer(0.6).timeout
	tentacle.writhe = 1.0                            # then a fast, searching writhe while it waits
	tentacle.writhe_hz = 3.6
	report["revealed"] = tentacle != null
	report["clearance_hits"] = _clearance()
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


## The body's line (market frame): root under the dock outside -> up to the gap -> under the door (0.32 m up, the gap
## is 0.9 m) -> along the floor into the bay -> rising to `eye`'s height, ending 0.85 m short of it, straight in its
## line of sight. The lateral position at the door follows the player but stays inside the door's width.
const ROOT_TO_GAP := 1.75
const GAP_Y := 0.32


func _aim_path(eye_world: Vector3, view_world := Vector3.ZERO) -> void:
	if tentacle == null or not is_instance_valid(tentacle):
		return
	var eye: Vector3 = p4.market.to_local(eye_world)
	var zc := clampf(eye.z, ROOT.z - 0.7, ROOT.z + 0.7)
	var gap := Vector3(20.05, GAP_Y, zc)
	var inside := Vector3(19.55, GAP_Y + 0.02, lerpf(zc, eye.z, 0.35))
	var to_eye := eye - inside
	var stop := eye - to_eye.normalized() * 0.85
	if view_world != Vector3.ZERO:
		# right where the player is looking: 0.85 m out along the view (never below knee height)
		var v: Vector3 = (p4.market.global_transform.basis.inverse() * view_world).normalized()
		stop = eye + v * 0.85
		stop.y = maxf(stop.y, 0.55)
	var rise := inside.lerp(stop, 0.45)
	rise.y = lerpf(inside.y, stop.y, 0.3)
	tentacle.set_path([Vector3(21.7, -0.55, zc), Vector3(21.0, 0.15, zc), gap, inside, rise, stop])


## At the scare beat: how close the tip is to the eye, and how far off the centre of view (degrees).
func _measure_gaze(cam: Camera3D) -> void:
	var tip: Vector3 = tentacle.tip_global()
	var to := tip - cam.global_position
	report["tip_to_eye_m"] = to.length()
	report["tip_off_view_deg"] = rad_to_deg((-cam.global_basis.z).angle_to(to))


## Solid things the exposed body would pass through at full reach (spheres on the joints, root side excluded).
func _clearance() -> Array:
	var hits := []
	if tentacle == null:
		return hits
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.09
	q.shape = sph
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var js: PackedVector3Array = tentacle.joints()
	for i in js.size():
		var lp: Vector3 = js[i]
		if lp.x > 20.3:
			continue                                       # outside / under the dock
		q.transform = Transform3D(Basis(), p4.market.to_global(lp))
		for h in space.intersect_shape(q, 4):
			hits.append("%d:%s" % [i, String((h["collider"] as Node).name)])
	return hits


## On its side, pointing into the bay (+Y -> -X), swung towards the player (kept within the door opening's arc).
func _aim_basis() -> Basis:
	var to: Vector3 = p4.market.to_local(player.global_position) - ROOT
	return Basis(Vector3.UP, clampf(atan2(-to.z, -to.x), -0.9, 0.9)) * Basis(Vector3(0, 0, 1), LIFT)


## While the player runs: the tentacle keeps searching and turns after him; past half time it reaches.
func _creep(dt: float) -> void:
	if tentacle == null or not is_instance_valid(tentacle):
		return
	_creep_t -= dt
	if _creep_t <= 0.0:
		_creep_t = 0.2
		var cam: Camera3D = player.get("camera")
		_aim_path(cam.global_position, -cam.global_basis.z)   # it keeps its tip up in the player's face
		tentacle.head = tentacle.path_length()
	if time_left < ESCAPE_S * 0.5 and not tentacle.has_meta("reaching"):
		tentacle.set_meta("reaching", true)
		_writhe(1.3, 4.6)                             # more frantic as time runs out
var _creep_t := 0.0


## Phase 4's loading handle was used: the door comes down.
func on_close_started() -> void:
	if running and time_left > 0.0:
		closing = true


## The writhe's strength and pace (eased by the modifier itself).
func _writhe(strength: float, hz: float) -> void:
	if tentacle and is_instance_valid(tentacle):
		tentacle.writhe = strength
		tentacle.writhe_hz = hz


func _survived() -> void:
	_writhe(1.5, 6.5)                                  # thrashing as the door forces it out
	if tentacle and is_instance_valid(tentacle):
		# back out the way it came: the tip is the last thing to go under the door
		var tw := create_tween()
		tw.tween_property(tentacle, "head", 0.0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		report["retracted"] = true
	while not Game.has_flag("p4_loading_down"):
		await get_tree().process_frame
	p4._play("impact", p4.ml(Vector3(20.1, 0.9, 15.9)), 6.0)   # one heavy hit on the shut door
	world._shake(player.get("camera"), 0.3, 0.04)
	p4._music_stop(0.15)
	if tentacle:
		tentacle.queue_free()
	tentacle = null
	report["cleaned_up"] = true
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
		_writhe(1.4, 5.5)
		_aim_path(feet + Vector3(0, 1.0, 0))           # (ends 0.85 m short of that: at the ankle)
		tentacle.head = tentacle.path_length()
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
		if tentacle and is_instance_valid(tentacle):
			_aim_path(cam.global_position + Vector3(0, 0.6, 0))     # it keeps hold as it drags him to the gap
			tentacle.head = tentacle.path_length()
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
