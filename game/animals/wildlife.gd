extends Node
class_name VeilWildlife
## THE VEIL - the animals of the woods before the Veil comes (world.gd adds one of these).
##  1. Life in the trees: a few deer, rabbits and ravens near whoever is walking or driving through the woods (never in town, never after the Veil, never in a scene).
##     Animals appear beside a tree at the edge of view and are removed again when the player has left them far behind. The deer and the rabbits bolt when you come close;
##     the ravens wheel overhead.
##  2. The deer on the road: once, on the drive into town, a deer bursts out of the roadside right in front of the car and leaps across (timed so that it clears the car
##     by a couple of metres: a near miss, never a hit; the deer has no collision, so if the player brakes or swerves nothing changes).

const STING := "res://game/audio/the_veil_jumpscare_sting.wav"
const SCATTER := "res://game/world/scatter.json"
const TOWN := Vector3(40.0, 0.0, -10.0)
const MAX_ANIMALS := 5
const SCARE_FLAG := "deer_scare_done"

var world: Node
var animals: Array = []
var report := {"spawned": 0, "scare": false, "scare_miss_m": -1.0}
var _trees: Array = []
var _t := 0.0
var _scare: VeilAnimal
var _scare_t := -1.0
var _scare_clear := 1e9
var _scare_car: Node3D
var _rng := RandomNumberGenerator.new()


func setup(w: Node) -> void:
	world = w
	_rng.randomize()
	var f := FileAccess.open(SCATTER, FileAccess.READ)
	if f:
		var d: Dictionary = JSON.parse_string(f.get_as_text())
		for it in d["items"]:
			if String(it[0]).begins_with("VG_Tree"):
				_trees.append(Vector2(it[1], it[2]))


func _player_pos() -> Vector3:
	var lt = world.get("living")
	if lt:
		return lt.focus()
	return world.player.global_position


func _active() -> bool:
	if world == null or world.player == null:
		return false
	if Game.has_flag("p3_mist") or (world.get("intro") != null and is_instance_valid(world.intro)) or world.get("_cine") != null:
		return false
	var lt = world.get("living")
	if lt and lt._story_busy():
		return false
	return true


func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	_scare_step(delta)
	if not _active():
		return
	var p := _player_pos()
	for a in animals.duplicate():
		if not is_instance_valid(a):
			animals.erase(a)
		elif a.global_position.distance_to(p) > 150.0:
			a.queue_free()
			animals.erase(a)
		else:
			a.threat = p
	if _t > 1.2 and animals.size() < MAX_ANIMALS and not _trees.is_empty() and p.distance_to(TOWN) > 120.0:
		_t = 0.0
		_try_spawn(p)
	_scare_watch(p)


## One animal beside a tree that is 35-110 m from the player, outside town and off the road.
func _try_spawn(p: Vector3) -> void:
	var cam := world.get_viewport().get_camera_3d()
	for attempt in 12:
		var tr: Vector2 = _trees[_rng.randi() % _trees.size()]
		var at := Vector3(tr.x + _rng.randf_range(-2.5, 2.5), 0.0, tr.y + _rng.randf_range(-2.5, 2.5))
		var d := (at * Vector3(1, 0, 1)).distance_to(p * Vector3(1, 0, 1))
		if d < 35.0 or d > 110.0 or at.distance_to(TOWN) < 110.0:
			continue
		if cam != null and cam.is_position_in_frustum(at + Vector3(0, 1, 0)) and d < 70.0:
			continue                                        # never pops up in plain view
		var lt = world.get("living")
		var g := _ground(at)
		if not g.is_finite() or (lt and (lt._on_road(g) or lt.in_house(g))):
			continue
		var kinds := ["deer", "rabbit", "rabbit", "raven", "raven"]
		var have_deer := animals.any(func(a): return is_instance_valid(a) and a.kind == "deer")
		var k: String = kinds[_rng.randi() % kinds.size()]
		if k == "deer" and have_deer:
			k = "rabbit"
		var a := VeilAnimal.spawn(world, k, g, _rng.randf() * TAU)
		if k == "raven":
			a.fly_circle(Vector3(p.x, 0.0, p.z) + Vector3(_rng.randf_range(-30, 30), 0, _rng.randf_range(-30, 30)), _rng.randf_range(18.0, 34.0), _rng.randf_range(16.0, 30.0), _rng.randf_range(7.0, 10.0))
		else:
			a.shy_distance = 18.0 if k == "deer" else 9.0
			a.idle()
		animals.append(a)
		report["spawned"] = int(report["spawned"]) + 1
		return


func _ground(p: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p - Vector3.UP * 20.0, 1))
	return (h["position"] as Vector3) if not h.is_empty() else Vector3.INF


# ------------------------------------------------------------------ the deer on the road
## The drive into town (before the Veil): the car is out in the woods, moving, heading to town.
func _scare_watch(_p: Vector3) -> void:
	if _scare != null or Game.has_flag(SCARE_FLAG) or not world.in_car or world.sedan == null or not world.sedan.driven:
		return
	var car: Node3D = world.sedan
	var fwd := -car.global_transform.basis.z
	var to_town := (TOWN - car.global_position) * Vector3(1, 0, 1)
	var d_town := to_town.length()
	# out in the woods (140-420 m from the town centre), heading towards town, at a driving speed
	if d_town < 140.0 or d_town > 420.0 or fwd.dot(to_town.normalized()) < 0.2 or float(car.speed) < 5.0 or Game.has_flag("arrival_shot"):
		return
	start_scare()


## A deer from the roadside, 4.5 m to the car's right, running across; it reaches the car's line 0.4 s before the car does.
func start_scare() -> void:
	var car: Node3D = world.sedan
	var fwd := -car.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right: Vector3 = car.global_transform.basis.x                                  # (to the car's right)
	right.y = 0.0
	right = right.normalized()
	var v: float = maxf(float(car.speed), 7.0)
	var lateral := 4.5
	var run_speed: float = float(VeilAnimal.DEFS["deer"]["speed"]["run"])
	var t1 := lateral / run_speed
	var ahead := v * (t1 + 0.4)
	var at: Vector3 = car.global_position + fwd * ahead + right * lateral
	var g := _ground(at)
	if not g.is_finite():
		g = Vector3(at.x, car.global_position.y, at.z)
	_scare = VeilAnimal.spawn(world, "deer", g, atan2(-right.x, -right.z))
	_scare_car = car
	var exit_at: Vector3 = g - right * 36.0 + fwd * 8.0
	_scare.run_to(exit_at)
	_scare_clear = 1e9
	_scare_t = 0.0
	Game.set_flag(SCARE_FLAG)
	report["scare"] = true
	var s := AudioStreamPlayer.new()
	s.stream = load(STING)
	s.volume_db = -7.0
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


func _scare_step(delta: float) -> void:
	if _scare == null:
		return
	if not is_instance_valid(_scare):
		_scare = null
		return
	_scare_t += delta
	if is_instance_valid(_scare_car):
		var d := _scare.global_position.distance_to(_scare_car.global_position)
		_scare_clear = minf(_scare_clear, d)
		report["scare_miss_m"] = _scare_clear
	if _scare_t > 9.0 or (_scare.state == "idle" and _scare_t > 1.0):
		_scare.queue_free()
		_scare = null
