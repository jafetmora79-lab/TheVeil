extends CharacterBody3D
class_name VeilSurvivorBody

const LAYER := 16
const SOLIDS := 1 | 2 | 4 | LAYER
const RADIUS := 0.28
const HEIGHT := 1.76
const FOOT_CLEARANCE := 0.035

var capsule := CapsuleShape3D.new()
var step_target := Vector3.INF
var _placement_valid := true

func _init() -> void:
	collision_layer = LAYER
	collision_mask = SOLIDS
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = HEIGHT * 0.5 + FOOT_CLEARANCE
	add_child(collider)
	visibility_changed.connect(_sync_collision_visibility)

func _sync_collision_visibility() -> void:
	if visible and not _placement_valid:
		hide()
	collision_layer = LAYER if is_visible_in_tree() and _placement_valid else 0

static func floor_at(space: PhysicsDirectSpaceState3D, point: Vector3, rise := 0.32, drop := 0.45) -> Vector3:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * rise, point - Vector3.UP * drop, 1))
	if hit.is_empty() or (hit.normal as Vector3).y < 0.72 or hit.collider.is_in_group("veil_furniture"):
		return Vector3.INF
	return hit.position

func clearance_at(point: Vector3) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = SOLIDS
	query.exclude = [get_rid()]
	query.transform.origin = point + Vector3.UP * (HEIGHT * 0.5 + FOOT_CLEARANCE)
	return query

func is_clear(point: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_shape(clearance_at(point), 1).is_empty()

func nearest_safe(requested: Vector3, max_distance := 3.0) -> Vector3:
	var space := get_world_3d().direct_space_state
	var floor_point := floor_at(space, requested)
	if floor_point.is_finite() and is_clear(floor_point):
		return floor_point
	for ring in range(1, int(max_distance / 0.25) + 1):
		for i in range(24):
			var angle := TAU * i / 24.0
			var candidate := requested + Vector3(cos(angle), 0, sin(angle)) * (ring * 0.25)
			floor_point = floor_at(space, candidate)
			if floor_point.is_finite() and is_clear(floor_point):
				return floor_point
	return Vector3.INF

## Explicit story placement only. A failed search never installs the requested position.
func place_at(requested: Vector3) -> bool:
	var safe := nearest_safe(requested)
	if not safe.is_finite():
		push_warning("No safe placement for %s near %s" % [name, requested])
		var floor_point := floor_at(get_world_3d().direct_space_state, global_position)
		if not floor_point.is_finite() or not is_clear(global_position):
			_placement_valid = false
			_sync_collision_visibility()
		return false
	_placement_valid = true
	step_target = Vector3.INF
	global_position = safe
	force_update_transform()
	_sync_collision_visibility()
	return true


## Sweep up, across and down, using the same low-step check for both character types.
static func step_up(body: CharacterBody3D, forward: Vector3, height: float) -> float:
	var landing := step_landing(body, forward, height)
	if not landing.is_finite():
		return 0.0
	var rise := landing.y - body.global_position.y
	body.global_position = landing
	return rise

static func step_landing(body: CharacterBody3D, forward: Vector3, height: float) -> Vector3:
	var origin := body.global_transform
	var hit := KinematicCollision3D.new()
	if not body.test_move(origin, forward, hit) or hit.get_normal().y > 0.7:
		return Vector3.INF
	var up := Vector3.UP * height
	if body.test_move(origin, up):
		return Vector3.INF
	var raised := origin.translated(up)
	if body.test_move(raised, forward):
		return Vector3.INF
	var ahead := raised.translated(forward)
	var down := KinematicCollision3D.new()
	if not body.test_move(ahead, Vector3.DOWN * (height + 0.05), down) or down.get_normal().y < 0.7:
		return Vector3.INF
	var rise := height - down.get_travel().length()
	if rise < 0.01:
		return Vector3.INF
	return ahead.origin + down.get_travel() + Vector3.UP * 0.002
