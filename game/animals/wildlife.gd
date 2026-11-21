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
var _yaw_hist: Array = []
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
	_town_flocks(delta)
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
	# only on a straight stretch: the heading has been steady for the last second and a half (the scene is staged in straight lines, not on a bend)
	var yaw := atan2(fwd.x, fwd.z)
	_yaw_hist.append(yaw)
	if _yaw_hist.size() > 90:
		_yaw_hist.pop_front()
	if _yaw_hist.size() < 60 or absf(angle_difference(_yaw_hist[0], yaw)) > 0.04 or absf(float(car.steer)) > 0.03:
		return
	# out in the woods (140-420 m from the town centre), heading towards town, at a driving speed
	if d_town < 140.0 or d_town > 420.0 or fwd.dot(to_town.normalized()) < 0.2 or float(car.speed) < 5.0 or Game.has_flag("arrival_shot"):
		return
	start_scare()


## The deer scare as a little cinematic: sting + tyre screech, the protagonist stands on the brake, the deer leaps out of the roadside and stops a hand's breadth
## in front of the bumper, freezes (its own idle clip) and stares, then bolts; the protagonist breathes out and the player has the car back.
func start_scare() -> void:
	var car: Node3D = world.sedan
	var fwd := -car.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right: Vector3 = car.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var v: float = maxf(float(car.speed), 6.0)
	var decel := 15.0                                                       # a hard stop (m/s^2)
	var stop_d := v * v / (2.0 * decel) + 0.5                             # (the car overruns a little: one frame of lag before it bites)
	var front := 2.35                                                       # car centre to bumper
	var gap := 3.6                                                          # bumper to the deer's middle (its body is ~1.6 m long facing the car: the nose ends a few centimetres off the bumper)
	var at: Vector3 = car.global_position + fwd * (stop_d + front + gap)
	var g := _ground(at)
	if not g.is_finite():
		g = Vector3(at.x, car.global_position.y, at.z)
	var from: Vector3 = g + right * 7.0
	var gf := _ground(from)
	if gf.is_finite():
		from.y = gf.y
	_scare = VeilAnimal.spawn(world, "deer", from, atan2(-right.x, -right.z))
	_scare_car = car
	_scare_t = 0.0
	_scare_clear = 1e9
	Game.set_flag(SCARE_FLAG)
	report["scare"] = true
	_cine(car, _scare, g, fwd, right, decel)


func _cine(car: Node3D, deer: VeilAnimal, stop_at: Vector3, fwd: Vector3, right: Vector3, decel: float) -> void:
	var old_decel: float = car.script_decel
	car.script_decel = decel
	car.drive_script = func(_d): return Vector2(0.0, 0.0)                   # off the throttle, straight, brakes hard
	_sound(STING, -7.0)
	_sound_skid()
	_cam_dip(car)
	deer.run_to(stop_at)
	await deer.arrived
	if not is_instance_valid(deer):
		car.drive_script = Callable()
		car.script_decel = old_decel
		return
	report["scare_stop_m"] = deer.global_position.distance_to(car.global_position)
	# it plants its feet and stares into the headlights (its own idle clip), the head turns to the car
	var face := atan2(-fwd.x, -fwd.z)
	var tw := deer.create_tween()
	tw.tween_property(deer, "rotation:y", lerp_angle(deer.rotation.y, face, 1.0), 0.35)
	deer._yaw = face
	while absf(float(car.speed)) > 0.15 and is_instance_valid(deer):
		await world.get_tree().process_frame
	Dialogue.say("deer_stop", false, true)
	await world.get_tree().create_timer(2.2).timeout
	if is_instance_valid(deer):
		deer.run_to(deer.global_position - right * 40.0)
	await world.get_tree().create_timer(2.0).timeout
	Dialogue.say("deer_after", false, false)
	await world.get_tree().create_timer(1.6).timeout
	car.drive_script = Callable()                                            # the drive is the player's again
	car.script_decel = old_decel
	report["scare_done"] = true


func _sound(path: String, db: float) -> void:
	var s := AudioStreamPlayer.new()
	s.stream = load(path)
	s.volume_db = db
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


## Tyres locking up: a rough, wavering noise that falls in pitch as the car stops (made here, there is no sample for it).
func _sound_skid() -> void:
	var rate := 22050
	var n := int(rate * 1.3)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var env := minf(t * 14.0, 1.0) * pow(1.0 - t, 0.8)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
		ph += TAU * lerpf(900.0, 520.0, t) / rate
		var x := (lp * 0.7 + sin(ph) * 0.25 * sin(t * 40.0)) * env * 0.6
		data.encode_s16(i * 2, int(clampf(x, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	var s := AudioStreamPlayer.new()
	s.stream = w
	s.volume_db = -6.0
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


## The windscreen dips forward as the car noses down under braking, then settles.
func _cam_dip(car: Node3D) -> void:
	var cam: Camera3D = car.driver_cam
	if cam == null:
		return
	var base := cam.rotation.x
	var tw := create_tween()
	tw.tween_property(cam, "rotation:x", base - 0.07, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.6)
	tw.tween_property(cam, "rotation:x", base, 0.9).set_trans(Tween.TRANS_SINE)


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
	if report.get("scare_done", false) and _scare.state == "idle" or _scare_t > 20.0:
		_scare.queue_free()
		_scare = null


# ------------------------------------------------------------------ the Grimtalons over the town
## Once the Veil is up, flocks of Grimtalons wheel over the town in the mist, high above the roofs: two swarms whose centres drift slowly across the town.
## They are spawned when the player is within reach of the town and put away (hidden, not freed) when he is far off.
var _flock_anchors: Array = []
var _flock_birds: Array = []
var _flock_t := 0.0


func _town_flocks(delta: float) -> void:
	if world == null or world.player == null or not Game.has_flag("p3_mist") or not VeilMeshyNpcs.monsters_enabled():
		return
	var near: bool = world.player.global_position.distance_to(TOWN) < 420.0
	if _flock_birds.is_empty():
		if not near:
			return
		for spec in [[7, Vector2(55, 130), Vector2(48, 78), Vector2(8, 12), Vector3(0, 0, 0)], [5, Vector2(90, 190), Vector2(62, 95), Vector2(9, 14), Vector3(70, 0, -50)]]:
			var anchor := Node3D.new()
			anchor.name = "GrimtalonFlockAnchor"
			world.add_child(anchor)
			anchor.global_position = TOWN + (spec[4] as Vector3)
			_flock_anchors.append([anchor, spec[4]])
			_flock_birds.append_array(VeilGrimtalon.flock(world, int(spec[0]), anchor.global_position, anchor, spec[1], spec[2], spec[3]))
		report["flock_birds"] = _flock_birds.size()
	_flock_t += delta
	for i in _flock_anchors.size():
		var an: Node3D = _flock_anchors[i][0]
		var base: Vector3 = TOWN + (_flock_anchors[i][1] as Vector3)
		if is_instance_valid(an):
			an.global_position = base + Vector3(sin(_flock_t * (0.045 + 0.01 * i)) * 80.0, 0.0, cos(_flock_t * (0.038 + 0.012 * i)) * 80.0)
	for g in _flock_birds:
		if is_instance_valid(g):
			g.visible = near
			g.set_process(near)
