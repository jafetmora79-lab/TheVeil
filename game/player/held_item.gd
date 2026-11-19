extends Node
class_name VeilHeldItem
## THE VEIL - the item in the player's hand while it is used (water, soup, snacks, medicine).
## Instead of the item vanishing from the inventory the instant a button is pressed, its own model rises into the
## first-person view, is brought up to the face (drink / eat) or squeezed (medicine), the effect lands when the
## motion reaches its peak, and the item is lowered away again. The hand follows the view with a little lag
## (a mouse-look sway), and rocks with the walk.
##
## The motion is plain procedural animation (rise -> use -> lower). Headless runs (tests) skip it and apply the
## effect at once.

signal finished

const REST := Vector3(0.17, -0.20, -0.38)       ## lower right, like the handgun's rest pose
const RISE := 0.28
const LOWER := 0.22
const USE := {"drink": 1.05, "eat": 0.85, "take": 0.9}

var player: Node3D
var _view: Node3D
var _t := 0.0
var _kind := ""
var _effect: Callable
var _fired := false
var _active := false
var _lag := Vector2.ZERO                          ## smoothed look-turn lag (yaw, pitch), radians
var _last_yaw := 0.0
var _last_pitch := 0.0
var _time := 0.0


func is_busy() -> bool:
	return _active


## Raise `model_path` into view and use it as `kind` ("drink" | "eat" | "take"). `effect` runs once at the peak.
func use_item(model_path: String, kind: String, effect: Callable) -> void:
	if _active:
		return
	var ps := load(model_path) as PackedScene if model_path != "" and ResourceLoader.exists(model_path) else null
	if DisplayServer.get_name() == "headless" or ps == null or player == null or not is_instance_valid(player):
		effect.call()                              # nothing to show: the effect still lands
		finished.emit()
		return
	var cam: Camera3D = player.get("camera")
	if cam == null:
		effect.call()
		finished.emit()
		return
	_view = Node3D.new()
	_view.name = "HeldItemView"
	var model := ps.instantiate() as Node3D
	_view.add_child(model)
	# normalise: centre the model on the hand and scale it to a hand-sized object
	var box := Interactable.aabb_of(model)
	if box.size.length() > 0.001:
		var s := 0.20 / maxf(box.size.x, maxf(box.size.y, box.size.z))
		model.scale = Vector3.ONE * s
		model.position = -box.get_center() * s
	for gi in _view.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(_view)
	_view.position = REST + Vector3(0, -0.3, 0)
	_kind = kind
	_effect = effect
	_fired = false
	_t = 0.0
	_active = true
	_last_yaw = player.rotation.y
	_last_pitch = float(player.get("_pitch")) if player.get("_pitch") != null else 0.0
	_lag = Vector2.ZERO


func _total() -> float:
	return RISE + float(USE.get(_kind, 0.9)) + LOWER


func _process(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(_view) or not is_instance_valid(player) or not player.visible:
		_end()
		return
	_t += delta
	_time += delta
	var use_t := float(USE.get(_kind, 0.9))
	# phases: 0..1 rise, 0..1 use, 0..1 lower
	var rise := clampf(_t / RISE, 0.0, 1.0)
	var use := clampf((_t - RISE) / use_t, 0.0, 1.0)
	var lower := clampf((_t - RISE - use_t) / LOWER, 0.0, 1.0)
	var pos := REST
	var pitch := 0.0
	var roll := 0.0
	var yaw := -0.25                                # the item turned a little in towards the view
	var peak := sin(use * PI)                       # 0 -> 1 -> 0 across the use phase
	match _kind:
		"drink":
			# bring the bottle up and tip it back toward the mouth
			pos += Vector3(-0.15, 0.17, 0.12) * peak
			pitch = 0.0 + 1.1 * peak
			roll = -0.35 * peak
		"eat":
			pos += Vector3(-0.14, 0.13, 0.10) * peak
			pitch = 0.5 * peak
			# two small bites
			pos.y += 0.012 * sin(use * TAU * 2.0) * peak
		_:                                          # take (medicine): lift, then a small squeeze
			pos += Vector3(-0.12, 0.10, 0.08) * peak
			roll = 0.25 * peak
			pos.y += 0.01 * sin(use * TAU * 3.0) * peak
	pos.y -= 0.30 * (1.0 - smoothstep(0.0, 1.0, rise))
	pos.y -= 0.30 * smoothstep(0.0, 1.0, lower)
	# walking sway and look-turn lag
	var v: Vector3 = player.get("velocity") if player.get("velocity") != null else Vector3.ZERO
	var walk := clampf(Vector2(v.x, v.z).length() / 4.0, 0.0, 1.0)
	pos += Vector3(sin(_time * 4.2) * 0.010 * walk, absf(sin(_time * 8.4)) * -0.008 * walk, 0.0)
	var yaw_now := player.rotation.y
	var pitch_now := float(player.get("_pitch")) if player.get("_pitch") != null else 0.0
	var dy := wrapf(yaw_now - _last_yaw, -PI, PI)
	var dp := pitch_now - _last_pitch
	_last_yaw = yaw_now
	_last_pitch = pitch_now
	_lag += Vector2(dy, dp) * 0.6                   # the hand trails the view...
	_lag = _lag.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))   # ...and catches up
	_lag = _lag.clamp(Vector2(-0.25, -0.25), Vector2(0.25, 0.25))
	pos += Vector3(_lag.x * 0.22, -_lag.y * 0.15, 0.0)
	_view.position = pos
	_view.basis = Basis(Vector3.FORWARD, roll) * Basis(Vector3.RIGHT, pitch + _lag.y * 0.6) * Basis(Vector3.UP, yaw + _lag.x * 0.8)
	if not _fired and use >= 0.5:
		_fired = true
		_effect.call()
	if _t >= _total():
		_end()


func _end() -> void:
	if not _fired:
		_fired = true
		if _effect.is_valid():
			_effect.call()
	if is_instance_valid(_view):
		_view.queue_free()
	_view = null
	_active = false
	finished.emit()
