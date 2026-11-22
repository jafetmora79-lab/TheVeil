extends Node
class_name TentacleAI
## THE VEIL - hostile behaviour for a Pack 07 Mist Tentacle (VeilMistTentacle stays presentation-only).
## SEARCH (sway, slowly turn) -> ACQUIRE (player within detect_range: turn to face) -> WIND-UP ("Coil", readable)
## -> STRIKE ("Strike": the direction is locked at the start, so the player can sidestep) -> damage ONLY at the
## measured contact frame and only if the player is really inside the tip's reach and strike cone -> RECOVER
## -> back to search. Far away for a while -> RETRACT into the mist; RE-EMERGE when the player comes close.
## The reach, strike direction and contact time are measured from the Strike clip itself (tip bone T_10), so
## the hit matches what the animation shows.

signal struck(tentacle: Node3D, damage: float)

@export var detect_range := 8.0
@export var damage := 22.0
@export var windup_time := 0.75
@export var recover_time := 1.1
@export var retract_after := 5.0         ## seconds with the player beyond `lose_range`
@export var lose_range := 16.0
@export var emerge_range := 11.0

var target: Node3D                        ## the player (needs `survival_active`)
var tentacle: Node3D
var state := "search"
var reach := 4.0
var contact_time := 0.6
var strike_len := 1.4
var strike_dir_local := Vector3(0, 0, 1)  ## horizontal direction of the tip at contact, tentacle-local
var _t := 0.0
var _far_t := 0.0
var _hit_done := false
var _locked_yaw := 0.0
var _anim: AnimationPlayer
## The octopus-arm attack (review notes #27 / #29): instead of the stiff Strike clip the arm COILS (curls up on itself), UNRAVELS toward the player along its whole length, GRIPS
## (wraps round them and squeezes, writhing), then lets go and re-coils to try again. Built bone by bone with VeilTentaclePoser + VeilTentacleGrab; the clips still drive search / retract.
var use_grab := true
const OPEN_TIME := 0.36
const WRAP_TIME := 0.38
var _grab: VeilTentacleGrab
var _poser: VeilTentaclePoser
var _grip_t := -1.0                       ## seconds into the grip (drives the writhe while it holds)


func _ready() -> void:
	tentacle = get_parent() as Node3D
	_anim = tentacle.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_measure_strike()
	if use_grab:
		contact_time = OPEN_TIME + WRAP_TIME * 0.7           # the grip closes round them: that is the contact
		strike_len = OPEN_TIME + WRAP_TIME + 0.55            # open, wrap, squeeze, let go


func _ensure_grab() -> bool:
	if _grab != null and is_instance_valid(_grab):
		return true
	_poser = VeilTentaclePoser.attach(tentacle)
	if _poser == null:
		use_grab = false
		return false
	_poser.weight = 0.0
	_grab = VeilTentacleGrab.attach(tentacle, _poser)
	return _grab != null


func _grab_point() -> Vector3:
	return target.global_position + Vector3(0, 0.9, 0)


func _grab_begin() -> void:
	if not use_grab or not _ensure_grab():
		return
	_grab.begin(_grab_point, 0.4, 0.0)
	_poser.weight = 1.0
	_grab.ease_to("load_k", 1.0, windup_time * 0.9)          # the coil: curled up tight, tip tucked in


func _grab_unravel() -> void:
	if _grab == null or not _grab.active:
		return
	_grip_t = -1.0
	await _grab.ease_to("open_k", 1.0, OPEN_TIME, Tween.TRANS_QUAD, Tween.EASE_OUT)       # unravels fast, whole length, toward them
	if _grab == null or not _grab.active:
		return
	_grip_t = 0.0
	await _grab.ease_to("wrap_k", 1.0, WRAP_TIME, Tween.TRANS_SINE, Tween.EASE_IN)         # and grips


func _grab_release() -> void:
	if _grab == null or not _grab.active:
		return
	_grip_t = -1.0
	await _grab.ease_to("release_k", 1.0, 0.45)
	if _grab == null or not _grab.active:
		return
	_grab.end()
	_grab.load_k = 0.0
	_grab.open_k = 0.0
	_grab.wrap_k = 0.0
	_grab.squeeze = 0.0
	_grab.release_k = 0.0
	if _poser:
		var tw := create_tween()
		tw.tween_property(_poser, "weight", 0.0, 0.3)           # back to the clip's own pose without a snap


func _clear_to_target() -> bool:
	## nothing solid between the tentacle's base and the player (a wall or the door they closed stops it: it never reaches through)
	var space := tentacle.get_world_3d().direct_space_state
	var a := tentacle.global_position + Vector3(0, 0.8, 0)
	var q := PhysicsRayQueryParameters3D.create(a, target.global_position + Vector3(0, 0.9, 0), 1, [target.get_rid()])
	return space.intersect_ray(q).is_empty()


## Sample the Strike clip: the frame with the tip farthest out horizontally = contact.
func _measure_strike() -> void:
	if _anim == null or not _anim.has_animation("Strike"):
		return
	var skel := tentacle.find_children("*", "Skeleton3D", true, false)
	if skel.is_empty():
		return
	var sk := skel[0] as Skeleton3D
	var tip := sk.find_bone("T_10")
	if tip < 0:
		return
	var a := _anim.get_animation("Strike")
	strike_len = a.length
	var best := -1.0
	var prev := _anim.current_animation
	_anim.play("Strike", 0.0)
	var t := 0.0
	while t <= a.length:
		_anim.seek(t, true)
		var p_root := tentacle.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(tip).origin)
		var hz := Vector2(p_root.x, p_root.z).length()
		if hz > best:
			best = hz
			contact_time = t
			strike_dir_local = Vector3(p_root.x, 0, p_root.z).normalized()
		t += 1.0 / 30.0
	reach = best * tentacle.scale.x
	if prev != "":
		_anim.play(prev, 0.0)


func _yaw_to(world_pos: Vector3) -> float:
	var d := world_pos - tentacle.global_position
	var want := atan2(d.x, d.z)                                   # world yaw of the direction to the target
	var local := atan2(strike_dir_local.x, strike_dir_local.z)    # yaw of the strike direction in the model
	return want - local


func _turn_toward(world_pos: Vector3, rate: float, delta: float) -> void:
	var goal := _yaw_to(world_pos)
	var cur := tentacle.rotation.y
	var diff := wrapf(goal - cur, -PI, PI)
	tentacle.rotation.y = cur + clampf(diff, -rate * delta, rate * delta)


func _play(clip: String, blend := 0.25) -> void:
	if tentacle.has_method("play"):
		tentacle.play(clip, blend)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not tentacle.is_visible_in_tree():
		return
	var active: bool = target.get("survival_active") == true
	var dist := Vector2(target.global_position.x - tentacle.global_position.x, target.global_position.z - tentacle.global_position.z).length()
	_t += delta
	match state:
		"search":
			tentacle.rotation.y += sin(Time.get_ticks_msec() * 0.0007 + tentacle.position.x) * 0.25 * delta
			if active and dist < detect_range:
				state = "acquire"
				_t = 0.0
			elif dist > lose_range:
				_far_t += delta
				if _far_t > retract_after:
					state = "hidden"
					_play("Retract")
					Sfx.bank_at("te_retreat", tentacle.global_position + Vector3(0, 1.0, 0), -6.0, 5.0)
			else:
				_far_t = 0.0
		"acquire":
			_turn_toward(target.global_position, 2.6, delta)
			if not active or dist > detect_range * 1.4:
				state = "search"
				_play("Search")
				Sfx.bank_at("te_search", tentacle.global_position + Vector3(0, 1.0, 0), -8.0, 5.0)
			elif absf(wrapf(_yaw_to(target.global_position) - tentacle.rotation.y, -PI, PI)) < 0.25:
				state = "windup"
				_t = 0.0
				if use_grab and _ensure_grab():
					_grab_begin()
				else:
					_play("Coil", 0.2)
				Sfx.bank_at("te_wet", tentacle.global_position + Vector3(0, 1.0, 0), -6.0, 5.0)
		"windup":
			_turn_toward(target.global_position, 1.4, delta)          # still tracking, slower: readable tell
			if _t >= windup_time:
				state = "strike"
				_t = 0.0
				_hit_done = false
				_locked_yaw = tentacle.rotation.y
				if _grab != null and _grab.active:
					_grab_unravel()
				else:
					_play("Strike", 0.1)
				Sfx.bank_at("te_strike", tentacle.global_position + Vector3(0, 1.0, 0), 0.0, 5.0)
		"strike":
			tentacle.rotation.y = _locked_yaw
			if not _hit_done and _t >= contact_time:
				_hit_done = true
				Sfx.bank_at("te_ground", tentacle.global_position + Vector3(0, 0.5, 0), -3.0, 5.0)
				if _target_in_strike() and _clear_to_target():
					struck.emit(tentacle, damage)
			if _grab != null and _grab.active and _grip_t >= 0.0:      # gripping: it writhes and squeezes
				_grip_t += delta
				_grab.squeeze = 0.5 + 0.5 * sin(_grip_t * 14.0)
				tentacle.rotation.y = _locked_yaw + sin(_grip_t * 9.0) * 0.06
			if _t >= strike_len:
				state = "recover"
				_t = 0.0
				if _grab != null and _grab.active:
					_grab_release()
				else:
					_play("Search", 0.35)
		"recover":
			if _t >= recover_time:
				state = "search"
				_t = 0.0
		"hidden":
			if dist < emerge_range:
				state = "search"
				_far_t = 0.0
				if tentacle.has_method("emerge"):
					tentacle.emerge()


## Contact test at the contact frame: within the tip's reach (plus body radius) and inside the strike cone.
func _target_in_strike() -> bool:
	var to := target.global_position - tentacle.global_position
	to.y = 0.0
	if to.length() > reach + 0.45:
		return false
	var dir := (tentacle.global_transform.basis * strike_dir_local)
	dir.y = 0.0
	return dir.normalized().angle_to(to.normalized()) < deg_to_rad(40.0)
