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


func _ready() -> void:
	tentacle = get_parent() as Node3D
	_anim = tentacle.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_measure_strike()


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
			else:
				_far_t = 0.0
		"acquire":
			_turn_toward(target.global_position, 2.6, delta)
			if not active or dist > detect_range * 1.4:
				state = "search"
				_play("Search")
			elif absf(wrapf(_yaw_to(target.global_position) - tentacle.rotation.y, -PI, PI)) < 0.25:
				state = "windup"
				_t = 0.0
				_play("Coil", 0.2)
		"windup":
			_turn_toward(target.global_position, 1.4, delta)          # still tracking, slower: readable tell
			if _t >= windup_time:
				state = "strike"
				_t = 0.0
				_hit_done = false
				_locked_yaw = tentacle.rotation.y
				_play("Strike", 0.1)
		"strike":
			tentacle.rotation.y = _locked_yaw
			if not _hit_done and _t >= contact_time:
				_hit_done = true
				if _target_in_strike():
					struck.emit(tentacle, damage)
			if _t >= strike_len:
				state = "recover"
				_t = 0.0
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
