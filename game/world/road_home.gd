extends Node
class_name VeilRoadHome
## THE VEIL - the long road home through the woods (the rural road east of town up to Maple Ave), after the Veil
## (p3_two_hours_later):
##   - wrecked and abandoned cars left among the trees beside it (6, fixed places, 9-18 m off the road, on the ground,
##     never on the road itself), each with simple box collision;
##   - while the player drives it (in the car, moving), Skitters dart through the trees 10-20 m from the car: across
##     the road ahead or racing along the verge, then gone into the woods. Looks only - no AI, no collision, at most
##     two at a time - and never during a scripted drive or a scene.
## Nothing is saved: the wrecks come from the flag, the Skitters are momentary.

const FLAG := "p3_two_hours_later"
const SKITTER := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const RATTLE := "res://game/encounters/skitter_rattle.wav"
const WRECKS := ["res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_Sedan_Damaged.glb",
	"res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_Pickup_Abandoned.glb",
	"res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_PoliceCruiser_Abandoned.glb",
	"res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_Sedan_Dusty.glb",
	"res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_DeliveryVan_BrokenDown.glb",
	"res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_Sedan_Damaged.glb"]
const MAX_DARTS := 2

var world: Node
var road: Array = []                   ## [centre Vector3, direction Vector3] of each rural road piece on the way home
var wrecks: Array = []
var darts: Array = []                  ## {node, from, to, t, dur, mode}
var report := {"darts": 0, "wrecks": 0}
var _t := 0.0
var _next := 3.0
var _placed := false


func setup(w: Node) -> void:
	world = w
	for i in 3:
		await get_tree().process_frame
	for n in world.find_children("RD_*", "Node3D", true, false):
		var nm := String(n.name)
		if not (nm.begins_with("RD_Shoulder_Rural") or nm.begins_with("RD_Curve_Gentle") or nm.begins_with("RD_Transition")):
			continue
		if n is MeshInstance3D or n is CollisionObject3D or String(n.get_parent().name).begins_with("RD_"):
			continue
		var a: AABB = (n as Node3D).global_transform * Interactable.aabb_of(n as Node3D)
		var c := a.get_center()
		if c.x < 100.0 or c.z < 20.0:
			continue                                    # (the west road and the town itself are not the way home)
		road.append([c, Vector3(1, 0, 0) if a.size.x >= a.size.z else Vector3(0, 0, 1)])
	# each piece's direction from its nearest neighbour (the pieces are about as wide as they are long)
	for r in road:
		var best := INF
		var dir := Vector3(0, 0, 1)
		for o in road:
			if o == r:
				continue
			var d: Vector3 = ((o[0] as Vector3) - (r[0] as Vector3)) * Vector3(1, 0, 1)
			if d.length() > 0.5 and d.length() < best:
				best = d.length()
				dir = d.normalized()
		r[1] = dir
	report["road_pieces"] = road.size()
	if after_skip():
		_place_wrecks()


func on_road_home(p: Vector3) -> bool:
	for r in road:
		if Vector2(p.x - r[0].x, p.z - r[0].z).length() < 9.0:
			return true
	return false


# ------------------------------------------------------------------ wrecks in the trees
func _place_wrecks() -> void:
	if _placed or road.size() < 8:
		return
	_placed = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var step := maxi(road.size() / (WRECKS.size() + 1), 1)
	for i in WRECKS.size():
		var r: Array = road[clampi((i + 1) * step, 0, road.size() - 1)]
		var c: Vector3 = r[0]
		var along: Vector3 = r[1]
		var side := along.cross(Vector3.UP).normalized() * (1.0 if i % 2 == 0 else -1.0)
		var spot := Vector3.INF
		for off in [11.0, 13.5, 9.5, 16.0, 18.0]:
			var p: Vector3 = c + side * float(off) + along * rng.randf_range(-3.0, 3.0)
			var hit := _ray_down(p)
			if hit.is_empty() or not String((hit["collider"] as Node).name).begins_with("TOWN_Ground"):
				continue                                # never on the road, a drive or another thing
			if _blocked(hit["position"]):
				continue
			spot = hit["position"]
			break
		if not spot.is_finite() or not ResourceLoader.exists(WRECKS[i]):
			continue
		var car := (load(WRECKS[i]) as PackedScene).instantiate() as Node3D
		car.name = "RoadHome_Wreck_%d" % i
		add_child(car)
		var yaw := atan2(along.x, along.z) + rng.randf_range(-1.1, 1.1) + (PI if rng.randf() < 0.5 else 0.0)
		var roll := rng.randf_range(-0.12, 0.12)                    # nosed off the road onto uneven ground
		car.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, roll), spot + Vector3(0, -0.04, 0))
		var ab := Interactable.aabb_of(car)
		var body := StaticBody3D.new()
		body.name = "WreckCol"
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = ab.size * Vector3(0.92, 0.85, 0.95)
		cs.shape = bs
		cs.position = ab.get_center()
		body.add_child(cs)
		car.add_child(body)
		wrecks.append(car)
	report["wrecks"] = wrecks.size()


## Something solid there already (a tree trunk, a fence): a 2 m clear patch is needed for a car.
func _blocked(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.2, 1.2, 4.6)
	q.shape = bx
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.9, 0))
	for h in (world.get_world_3d() as World3D).direct_space_state.intersect_shape(q, 4):
		if not String((h["collider"] as Node).name).begins_with("TOWN_Ground"):
			return true
	return false


func _ray_down(p: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p - Vector3.UP * 20.0, 1)
	var ex: Array[RID] = [world.player.get_rid()]
	if world.sedan:
		ex.append((world.sedan as CollisionObject3D).get_rid())
	q.exclude = ex
	return (world.get_world_3d() as World3D).direct_space_state.intersect_ray(q)


# ------------------------------------------------------------------ Skitters in the trees as you drive
func _process(delta: float) -> void:
	if world == null:
		return
	if not _placed and after_skip():
		_place_wrecks()
	_tick_darts(delta)
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	if not after_skip() or not world.in_car or world.sedan == null:
		return
	var car: Node3D = world.sedan
	if car.drive_script.is_valid() or absf(float(car.speed)) < 5.0 or not on_road_home(car.global_position):
		return
	if world.get("_cine") != null or world.get("_encounter_running") == true:
		return
	_next -= 0.25
	if _next > 0.0 or darts.size() >= MAX_DARTS:
		return
	_next = randf_range(3.5, 8.0)
	_dart(car)


func _dart(car: Node3D) -> void:
	var fwd := -car.global_basis.z * Vector3(1, 0, 1)
	fwd = fwd.normalized() * signf(float(car.speed))
	var side := fwd.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
	var ahead := randf_range(10.0, 20.0)
	var mode := "cross" if randf() < 0.55 else "verge"
	var from: Vector3
	var to: Vector3
	var dur: float
	if mode == "cross":                              # out of the trees on one side, over the road ahead, gone
		from = car.global_position + fwd * ahead + side * 11.0
		to = car.global_position + fwd * (ahead + 6.0) - side * 13.0
		dur = randf_range(0.9, 1.3)
	else:                                            # racing the car along the verge, then off into the woods
		var off := randf_range(10.0, 14.0)
		from = car.global_position + fwd * (ahead - 6.0) + side * off
		to = from + fwd * (absf(float(car.speed)) * 1.6 + 8.0) + side * 6.0
		dur = 1.6
	var sk := (load(SKITTER) as PackedScene).instantiate() as Node3D
	sk.name = "RoadHome_Skitter"
	add_child(sk)
	for co in sk.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0
		(co as CollisionObject3D).collision_mask = 0
	if sk is CollisionObject3D:
		(sk as CollisionObject3D).collision_layer = 0
		(sk as CollisionObject3D).collision_mask = 0
	sk.set_physics_process(false)
	var g0 := _ray_down(from)
	sk.global_position = (g0["position"] as Vector3) if g0 else from
	VeilCreatureLook.apply_skitter(sk, sk.global_position.y)
	VeilCreatureLook.skitter_anim(sk, "scuttle", 9.0)
	var dir := to - from
	sk.rotation.y = atan2(dir.x, dir.z)
	if ResourceLoader.exists(RATTLE):
		var a := AudioStreamPlayer3D.new()
		a.stream = load(RATTLE)
		a.volume_db = -4.0
		a.unit_size = 8.0
		sk.add_child(a)
		a.play()
	darts.append({"node": sk, "from": from, "to": to, "t": 0.0, "dur": dur, "mode": mode})
	report["darts"] = int(report["darts"]) + 1
	report["last_dist"] = sk.global_position.distance_to(car.global_position)


func _tick_darts(delta: float) -> void:
	var keep: Array = []
	for d in darts:
		var sk: Node3D = d["node"]
		if not is_instance_valid(sk):
			continue
		d["t"] = float(d["t"]) + delta
		var k := clampf(float(d["t"]) / float(d["dur"]), 0.0, 1.0)
		var p: Vector3 = (d["from"] as Vector3).lerp(d["to"], k)
		var g := _ray_down(p)
		sk.global_position = Vector3(p.x, (g["position"] as Vector3).y if g else p.y, p.z)    # on the ground
		if k >= 1.0:
			sk.queue_free()
			continue
		keep.append(d)
	darts = keep


## The two-hour skip has happened (its own flag, or any story step that only comes after it - older saves too).
static func after_skip() -> bool:
	for f in ["p3_two_hours_later", "p3_fled_together", "p3_in_market", "c5_started"]:
		if Game.has_flag(f):
			return true
	return false
