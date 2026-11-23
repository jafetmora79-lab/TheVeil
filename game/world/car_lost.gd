extends Node
## Review note #128: after the supermarket falls the repaired car cannot be used any more, wherever it is. Skitters crawl over it and around it whenever the player is near it outdoors (never when they are
## inside a house); trying to get in says so ("I guess I lost my car now"). No new death: they keep their distance round the car.
const SKITTER := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
var world: Node
var _sk: Array = []
var _ang := 0.0
var _t := 0.0


func setup(w: Node) -> void:
	world = w


func lost() -> bool:
	return Game.has_flag("ch9_supermarket_lost")


func _near() -> bool:
	if not lost() or world.sedan == null or not is_instance_valid(world.sedan) or world.player == null:
		return false
	if world.in_car or not world.has_method("_outdoors") or not world._outdoors():
		return false
	return world.player.global_position.distance_to(world.sedan.global_position) < 22.0


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		if _near() and _sk.is_empty():
			_spawn()
		elif not _near() and not _sk.is_empty():
			_free()
	if _sk.is_empty():
		return
	_ang += delta * 0.9
	var car: Node3D = world.sedan
	for i in _sk.size():
		var sk: Node3D = _sk[i]
		if not is_instance_valid(sk):
			continue
		var a := _ang + float(i) * TAU / float(_sk.size())
		var tgt := car.global_position + Vector3(cos(a) * 3.2, 0.0, sin(a) * 3.2)
		var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(tgt + Vector3(0, 1.5, 0), tgt - Vector3(0, 2.0, 0), 1))
		if hit:
			tgt.y = (hit["position"] as Vector3).y
		var d := tgt - sk.global_position
		sk.global_position = tgt
		if d.length() > 0.001:
			sk.rotation.y = atan2(d.x, d.z)


func _spawn() -> void:
	var ps := load(VeilMeshyNpcs.monster_scene(SKITTER)) as PackedScene
	if ps == null:
		return
	for i in 3:
		var sk := ps.instantiate() as Node3D
		sk.name = "CarLost_Skitter_%d" % i
		world.add_child(sk)
		if sk is CollisionObject3D:
			(sk as CollisionObject3D).collision_layer = 0
			(sk as CollisionObject3D).collision_mask = 0
		sk.set_physics_process(false)
		sk.global_position = world.sedan.global_position
		VeilCreatureLook.apply_skitter(sk, sk.global_position.y)
		VeilCreatureLook.skitter_anim(sk, "scuttle", 4.0)
		_sk.append(sk)
	Sfx.bank_at("sk_stalk", world.sedan.global_position + Vector3(0, 0.5, 0), -6.0, 12.0)


func _free() -> void:
	for sk in _sk:
		if is_instance_valid(sk):
			sk.queue_free()
	_sk.clear()
