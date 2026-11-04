extends Node
class_name VeilCompanionFollow
## THE VEIL - an NPC companion that follows the player (first used in Chapter 5: Eddie on the supply run).
## Drives the existing NpcAnimator (procedural walk) along a breadcrumb trail of the player's own footsteps,
## so the companion only ever walks where the player could walk: no wall clipping, no navmesh needed.
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


func setup(p_npc: Node3D, p_leader: Node3D) -> void:
	npc = p_npc
	leader = p_leader
	anim = npc.get_node_or_null("Animator")


func start() -> void:
	trail.clear()
	trail.append(_floor(npc.global_position))
	active = true


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
	_keep_on_floor(delta)
	var here := _floor(leader.global_position)
	if trail.is_empty() or Vector2(here.x - trail[-1].x, here.z - trail[-1].z).length() >= STEP:
		trail.append(here)
		if trail.size() > 600:
			trail.pop_front()
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
	if end <= start or flat.length() < gap * 0.85:
		if anim.is_walking():
			anim.walk_to([])                     # the leader stopped: wait
		trail = trail.slice(start)
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
	anim.walk_to(pts, speed)
	trail = trail.slice(start)


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
	npc.global_position = _floor(want)
	trail = [npc.global_position]


## NpcAnimator walks horizontally only; this keeps the companion's feet on the floor under it (porch steps,
## raised house floors, curbs), eased so a step reads as a step rather than a pop.
func _keep_on_floor(delta: float) -> void:
	var space := npc.get_world_3d().direct_space_state
	var p := npc.global_position
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.9, 0), p + Vector3(0, -1.5, 0), 1))
	if hit:
		var fy: float = (hit["position"] as Vector3).y
		npc.global_position.y = move_toward(p.y, fy, maxf(absf(fy - p.y) * 12.0, 1.5) * delta)


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
