extends CharacterBody3D
class_name PlayerSedan
## THE VEIL - the protagonist's sedan (Pack 05 Protagonist_Sedan.tscn) with an accessible arcade driving model.
## W accelerate, S brake / reverse, A/D steer, Space handbrake, E exit. Forward is -Z (Pack 05 convention).
## The model's moving parts are reused: wheels spin and the front pair steers, the steering wheel turns, the
## driver's door swings open on entry / exit. The GLB's own convex collision hulls become this body's shapes.

signal entered
signal exited
signal speed_changed(kmh: float)

const SEDAN_SCENE := preload("res://THE_VEIL_ASSETS_V2/05_Vehicles/Godot_Scenes/Protagonist_Sedan.tscn")
const TOP_SPEED := 15.3          # m/s (55 km/h) - an older everyday sedan on 25 mph town streets
const REVERSE_SPEED := 4.5
const ACCEL := 4.2
const BRAKE := 11.0
const COAST := 1.6
const HANDBRAKE := 14.0
const MAX_STEER := deg_to_rad(33.0)
const WHEELBASE := 2.72
const WHEEL_R := 0.31
const GRAVITY := 14.0

var car: Node3D
var model: Node3D
var driver_cam: Camera3D
var driven := false
var speed := 0.0
var steer := 0.0
var autopilot: Callable = Callable()     # tests: func(delta) -> Vector3(throttle, brake, steer)
var _wheels := {}
var _wheel_base := {}
var _spin := 0.0
var _sw: Node3D
var _sw_base: Basis
var _door: Node3D
var _door_base: Basis
var _look_yaw := 0.0
var _engine: AudioStreamPlayer3D
var _gen: AudioStreamGeneratorPlayback
var _phase := 0.0
var entry_area: Interactable


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_max_angle = deg_to_rad(40.0)
	floor_snap_length = 0.5
	wall_min_slide_angle = deg_to_rad(5)
	car = SEDAN_SCENE.instantiate()
	car.name = "Car"
	add_child(car)
	model = car.get_node("Model")
	driver_cam = car.get_node("DriverCamera")
	driver_cam.far = 700.0
	# move the imported convex hulls onto this body, drop their static bodies (they would block the car itself)
	for sb in model.find_children("*", "StaticBody3D", true, false):
		for cs in sb.get_children():
			if cs is CollisionShape3D:
				var n := CollisionShape3D.new()
				n.shape = cs.shape
				n.transform = global_transform.affine_inverse() * cs.global_transform if is_inside_tree() else (model.transform * _rel(sb, cs))
				add_child(n)
		sb.queue_free()
	# low chassis box: the GLB hulls start 0.22 m up (body), this one carries the car at wheel height
	var chassis := CollisionShape3D.new()
	var cb := BoxShape3D.new()
	cb.size = Vector3(1.66, 0.42, 4.5)
	chassis.shape = cb
	chassis.position = Vector3(0, 0.25, 0)
	add_child(chassis)
	for w in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
		var n := model.find_child(w, true, false) as Node3D
		if n:
			_wheels[w] = n
			_wheel_base[w] = n.transform.basis
	_sw = model.find_child("SteeringWheel", true, false)
	if _sw:
		_sw_base = _sw.transform.basis
	_door = model.find_child("Door_FL", true, false)
	if _door:
		_door_base = _door.transform.basis
	# entry point on the driver's side (Marker_Entry_Driver: x -1.54)
	entry_area = Interactable.new()
	entry_area.name = "DriverDoor"
	entry_area.kind = "custom"
	entry_area.label = "Car"
	entry_area.prompt_text = "[E] Enter Vehicle"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 1.3, 1.4)
	cs.shape = bs
	cs.position = Vector3(-0.95, 0.9, -0.35)
	entry_area.add_child(cs)
	add_child(entry_area)
	_setup_audio()


func _rel(sb: Node3D, cs: Node3D) -> Transform3D:
	var t := cs.transform
	var p := sb
	while p and p != model:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t


# ------------------------------------------------------------------ entry / exit
func get_prompt() -> String:
	return "[E] Enter Vehicle"


func set_driven(on: bool) -> void:
	driven = on
	driver_cam.current = on
	_look_yaw = 0.0
	driver_cam.rotation = Vector3.ZERO
	var lights := car.get_node_or_null("Lights")
	if lights:
		for l in lights.get_children():
			l.visible = on and (l.name.begins_with("Taillight") or l.name.begins_with("Headlight"))
	if _engine:
		if on:
			_engine.play()
			_gen = _engine.get_stream_playback()
		else:
			_engine.stop()
			_gen = null
	if on:
		entered.emit()
	else:
		exited.emit()


func swing_door(open: bool, t := 0.35) -> void:
	if not _door:
		return
	var b := _door_base * Basis(Vector3.UP, deg_to_rad(-62.0) if open else 0.0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_door, "transform:basis", b, t)
	await tw.finished


## World position for the player to stand after leaving the car (driver side, then passenger side).
func exit_spot(space: PhysicsDirectSpaceState3D, player_rid: RID) -> Variant:
	var capsule := CapsuleShape3D.new()
	capsule.radius = VeilPlayer.RADIUS
	capsule.height = VeilPlayer.HEIGHT
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.collision_mask = 1 | 4
	clearance.exclude = [player_rid]
	for side in [-1.0, 1.0]:
		var p := global_transform * Vector3(1.6 * side, 0.0, -0.3)
		var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p - Vector3.UP * 0.55, 1, [player_rid])
		var ground := space.intersect_ray(ray)
		if ground.is_empty() or ground.normal.y < cos(deg_to_rad(46.0)):
			continue
		var feet: Vector3 = ground.position + Vector3.UP * 0.03
		clearance.transform = Transform3D(Basis(), feet + Vector3.UP * capsule.height * 0.5)
		if space.intersect_shape(clearance, 1).is_empty():
			return feet
	return null


# ------------------------------------------------------------------ driving
func _unhandled_input(event: InputEvent) -> void:
	if driven and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Game.settings["mouse_sensitivity"] * 0.01
		_look_yaw = clampf(_look_yaw - event.relative.x * s, deg_to_rad(-110), deg_to_rad(110))
		driver_cam.rotation.x = clampf(driver_cam.rotation.x - event.relative.y * s, deg_to_rad(-50), deg_to_rad(35))


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var brake := 0.0
	var steer_in := 0.0
	var hb := false
	if driven:
		if autopilot.is_valid():
			var a: Vector3 = autopilot.call(delta)
			throttle = a.x
			brake = a.y
			steer_in = a.z
		else:
			throttle = Input.get_action_strength("move_forward")
			brake = Input.get_action_strength("move_back")
			steer_in = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
			hb = Input.is_action_pressed("handbrake")
	# longitudinal (arcade): S brakes while rolling forward, then reverses
	if throttle > 0.0:
		speed += (ACCEL * throttle * (1.0 - clampf(speed / TOP_SPEED, 0.0, 1.0) * 0.55) if speed >= 0.0 else BRAKE * throttle) * delta
	if brake > 0.0:
		if speed > 0.2:
			speed -= BRAKE * brake * delta
		else:
			speed -= ACCEL * 0.8 * brake * delta
	if throttle == 0.0 and brake == 0.0:
		speed = move_toward(speed, 0.0, COAST * delta)
	if hb:
		speed = move_toward(speed, 0.0, HANDBRAKE * delta)
	speed = clampf(speed, -REVERSE_SPEED, TOP_SPEED)
	# steering: full lock at low speed, gentler at speed; returns to centre
	var lock := MAX_STEER * lerpf(1.0, 0.42, clampf(absf(speed) / TOP_SPEED, 0.0, 1.0))
	steer = move_toward(steer, steer_in * lock, delta * (2.4 if steer_in != 0.0 else 3.2))
	if absf(speed) > 0.05:
		var yaw_rate := speed / WHEELBASE * tan(steer) * (1.35 if hb else 1.0)
		rotate_y(yaw_rate * delta)
	var fwd := -global_transform.basis.z
	var vy := velocity.y
	velocity = fwd * speed
	velocity.y = vy - GRAVITY * delta if not is_on_floor() else -1.0
	var before := global_position
	move_and_slide()
	# hitting something scrubs speed (no bouncing simulation)
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var n := get_slide_collision(i).get_normal()
			if absf(n.y) < 0.6 and n.dot(fwd * signf(speed)) < -0.5:
				speed *= 0.4
	var moved := (global_position - before).dot(fwd)
	_spin += moved / WHEEL_R
	_animate(delta)
	if driven:
		driver_cam.rotation.y = lerp_angle(driver_cam.rotation.y, _look_yaw, delta * 10.0)
		speed_changed.emit(absf(speed) * 3.6)
	_audio()


func _animate(_delta: float) -> void:
	for w in _wheels:
		var b: Basis = _wheel_base[w]
		var st := steer if w.ends_with("FL") or w.ends_with("FR") else 0.0
		_wheels[w].transform.basis = Basis(Vector3.UP, st) * b * Basis(Vector3.RIGHT, -_spin)
	if _sw:
		_sw.transform.basis = _sw_base * Basis(Vector3.FORWARD, steer * 4.0)


# ------------------------------------------------------------------ engine sound (procedural, original)
func _setup_audio() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = gen
	_engine.unit_size = 6.0
	_engine.volume_db = -8.0
	_engine.position = Vector3(0, 0.6, -1.6)
	add_child(_engine)


func _audio() -> void:
	if _gen == null:
		return
	var rpm := 0.18 + absf(speed) / TOP_SPEED * 0.82
	var f0 := 28.0 + rpm * 70.0
	var n := _gen.get_frames_available()
	var inc := f0 / 22050.0
	for i in n:
		_phase = fmod(_phase + inc, 1.0)
		var s := (sin(_phase * TAU) * 0.55 + sin(_phase * TAU * 2.0) * 0.25 + (randf() - 0.5) * 0.12) * (0.22 + rpm * 0.2)
		_gen.push_frame(Vector2(s, s))


func state() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y}


func restore(d: Dictionary) -> void:
	if d.has("pos"):
		global_position = Vector3(d["pos"][0], d["pos"][1] + 0.05, d["pos"][2])
		rotation.y = d.get("yaw", rotation.y)
