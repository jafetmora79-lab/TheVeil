extends Node
class_name VeilCompanionFollow
## THE VEIL - an NPC companion that follows the player (first used in Chapter 5: Eddie on the supply run).
## Drives the existing NpcAnimator (procedural walk) along a breadcrumb trail of the player's own footsteps,
## with capsule collision and short grid detours around blocked breadcrumbs.
##   - keeps `gap` metres of trail behind the player and waits when the player stops;
##   - walks at walk_speed, speeds up to run_speed when it falls behind (never teleports while visible);
##   - recover_behind() re-places it on the trail behind the player, only for loads and only out of view.
## Attach as a child of the NPC root (the node that owns the "Animator" child). Call start()/stop().

const STEP := 0.45                 # metres between breadcrumbs

var gap := 2.4                     # trail distance kept behind the leader
var walk_speed := 1.35
var run_speed := 3.6
var leader: Node3D                 # usually the player
var npc: Node3D
var anim: Node                     # NpcAnimator
var active := false
var trail: Array = []              # world-space floor points, oldest first
var _repath := 0.0
var _detour_retry := 0.0
var _yield_for := 0.0
var _join_for := 0.0


func setup(p_npc: Node3D, p_leader: Node3D) -> void:
	npc = p_npc
	leader = p_leader
	anim = npc.get_node_or_null("Animator")


func start(via: Array = []) -> void:
	trail.clear()
	trail.append(_floor(npc.global_position))
	active = true
	_join_for = 0.0
	var frame := npc.get_parent_node_3d()
	if not via.is_empty() and frame and anim:
		var points: Array = via.map(func(point): return frame.to_local(point))
		anim.walk_to(points, walk_speed)
		_join_for = 12.0


func stop() -> void:
	active = false
	if anim:
		anim.walk_to([])


## Distance (m) from the companion to the leader along the trail (straight line if the trail is empty).
func lag() -> float:
	return npc.global_position.distance_to(leader.global_position)


func _physics_process(delta: float) -> void:
	if not active or npc == null or leader == null or anim == null:
		return
	_detour_retry -= delta
	_yield_for -= delta
	var here := _floor(leader.global_position)
	if trail.is_empty() or Vector2(here.x - trail[-1].x, here.z - trail[-1].z).length() >= STEP:
		trail.append(here)
		if trail.size() > 600:
			trail.pop_front()
	if _join_for > 0.0 and anim.is_walking():
		_join_for -= delta
		return
	_repath -= delta
	if _repath > 0.0:
		return
	_repath = 0.25
	# the companion walks the trail from the point nearest to it up to `gap` metres short of the leader
	var start := _nearest_index(npc.global_position)

	var end := trail.size() - 1
	var back := 0.0
	while end > start and back < gap:
		back += (trail[end] as Vector3).distance_to(trail[end - 1])
		end -= 1
	var flat := Vector3(leader.global_position.x - npc.global_position.x, 0, leader.global_position.z - npc.global_position.z)
	if _yield_for > 0.0 and anim.is_walking():
		return
	if flat.length() < PERSONAL:
		_step_aside(flat)
		return
	if end <= start or flat.length() < gap * 0.85:
		if anim.is_walking():
			anim.walk_to([])                     # the leader stopped: wait, turned towards them
		if not anim.is_walking():
			anim.face_towards(leader.global_position)
		trail = trail.slice(maxi(0, start - 8))
		return
	var pts: Array = []
	var parent := npc.get_parent_node_3d()
	var inv := parent.global_transform.affine_inverse() if parent else Transform3D()
	for i in range(start + 1, end + 1):
		pts.append(inv * (trail[i] as Vector3))
	var behind := 0.0
	for i in range(start, trail.size() - 1):
		behind += (trail[i] as Vector3).distance_to(trail[i + 1])
	var speed := walk_speed if behind < gap + 3.0 else lerpf(walk_speed, run_speed, clampf((behind - gap - 3.0) / 6.0, 0.0, 1.0))
	if not pts.is_empty():
		var next: Vector3 = parent.to_global(pts[0]) if parent else pts[0]
		_open_doors_ahead(next)
		var body := npc as VeilSurvivorBody
		var world := get_tree().get_first_node_in_group("veil_world")
		var motion := (next - npc.global_position) * Vector3(1, 0, 1)
		if body and world and parent and _detour_retry <= 0.0 and body.test_move(body.global_transform, motion):
			_detour_retry = 0.8
			for i in range(mini(pts.size(), 7) - 1, -1, -1):
				var safe := body.nearest_safe(parent.to_global(pts[i]), 0.5)
				if not safe.is_finite():
					continue
				var route: Array = world.npc_route(parent, body.position, parent.to_local(safe), body)
				if not route.is_empty():
					pts = route + pts.slice(i + 1)
					_repath = 0.6
					break
	anim.walk_to(pts, speed)
	trail = trail.slice(maxi(0, start - 8))


const PERSONAL := 0.95             ## closer than this to the leader and the companion steps aside
var doors_opened := 0              ## tests
var steps_aside := 0               ## tests


## A door the leader shut behind them lies across the trail: the companion opens it instead of walking through.
func _open_doors_ahead(next: Vector3) -> void:
	var a := npc.global_position + Vector3(0, 1.0, 0)
	var b := next + Vector3(0, 1.0, 0)
	if a.distance_to(b) < 0.05:
		return
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b + (b - a).normalized() * 0.6, 1))
	if hit.is_empty():
		return
	var n: Node = hit["collider"]
	for _i in 4:
		if n == null:
			return
		var it := n.get_node_or_null("Interact") as Interactable
		if it and it.kind == "hinge":
			if not it.is_open:
				it.set_open(true)
				Sfx.play("door_open", it.global_position, -2.0)
				doors_opened += 1
			return
		n = n.get_parent()


## Sidestep about a metre, perpendicular to the leader, onto walkable floor that no wall separates from him.
func _step_aside(to_leader: Vector3) -> void:
	var body := npc as VeilSurvivorBody
	var frame := npc.get_parent_node_3d()
	if body == null or frame == null:
		return
	var direction := to_leader.normalized() if to_leader.length() > 0.01 else Vector3.FORWARD
	var side := direction.cross(Vector3.UP).normalized()
	var space := body.get_world_3d().direct_space_state
	for offset in [side, -side, -direction, (side - direction).normalized(), (-side - direction).normalized()]:
		for distance in [1.15, 0.7, 0.4]:
			var want: Vector3 = body.global_position + offset * distance
			var floor_point := VeilSurvivorBody.floor_at(space, want)
			if not floor_point.is_finite() or not body.is_clear(floor_point):
				continue
			var motion := (floor_point - body.global_position) * Vector3(1, 0, 1)
			if body.test_move(body.global_transform, motion):
				continue
			anim.walk_to([frame.to_local(floor_point)], run_speed)
			_yield_for = 0.6
			steps_aside += 1
			return
	anim.walk_to([])


## Loads only (screen faded): put the companion back on the trail behind the leader, on solid floor.
func recover_behind(dist := 2.4) -> void:
	var back := -leader.global_transform.basis.z
	back.y = 0.0
	back = (-back).normalized() if back.length() > 0.01 else Vector3.BACK
	var want := leader.global_position + back * dist
	var space := npc.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(leader.global_position + Vector3(0, 0.6, 0), want + Vector3(0, 0.6, 0), 1)
	var hit := space.intersect_ray(q)
	if hit:
		want = leader.global_position + back * maxf((hit["position"] as Vector3).distance_to(leader.global_position + Vector3(0, 0.6, 0)) - 0.5, 0.4)
	var body := npc as VeilSurvivorBody
	if body:
		body.place_at(_floor(want))
	trail = [npc.global_position]


func _nearest_index(p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in trail.size():
		var d := (trail[i] as Vector3).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _floor(p: Vector3) -> Vector3:
	var space := npc.get_world_3d().direct_space_state if npc else null
	if space == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.8, 0), p + Vector3(0, -2.5, 0), 1)
	var hit := space.intersect_ray(q)
	return (hit["position"] as Vector3) if hit else p
