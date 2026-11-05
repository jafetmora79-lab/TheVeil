extends CharacterBody3D
class_name PlayerSedan
## THE VEIL - the protagonist's sedan (Pack 05 Protagonist_Sedan.tscn) with an accessible arcade driving model.
## W accelerate, S brake / reverse, A/D steer, Space handbrake, E exit. Forward is -Z (Pack 05 convention).
## The model's moving parts are reused: wheels spin and the front pair steers, the steering wheel turns, the
## driver's door swings open on entry / exit. The GLB's own convex collision hulls become this body's shapes.

signal entered
signal exited
signal speed_changed(kmh: float)
signal radio_changed(station: String)

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
## cinematic assist (arrival shot): while > 0, the car eases down to this forward speed (m/s); steering stays with
## the driver, throttle is cut above the cap and a gentle brake is applied - no stop, no teleport
var speed_cap := -1.0
## scripted manoeuvre (automatic parking): func(delta) -> Vector2(target speed m/s, signed; target steer angle rad).
## The car still moves through move_and_slide (collisions respected, no teleport); speed and the front wheels
## change at realistic rates. Takes precedence over the player's input and the test autopilot.
var drive_script: Callable = Callable()
## parked with the brake on: the car holds still until the player presses throttle / brake
var parking_brake := false:
	set(v):
		parking_brake = v
		_brake_armed = false
var _brake_armed := false
const SCRIPT_ACCEL := 1.6        # m/s^2 for scripted speed changes
const STEER_RATE := 1.3          # rad/s at the front wheels while scripted (a driver turning the wheel)
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
	_setup_mirrors()
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
	_mirrors_on(on)
	_radio_apply()                                   # the radio plays only while driving (station remembered)
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
# ------------------------------------------------------------------ car radio (Q while driving): off -> 3 stations
const STATIONS := [["", ""], ["LAST EXIT — ROCK", "res://game/audio/radio/last_exit_rock.wav"],
	["NEON HEARTS — POP", "res://game/audio/radio/neon_hearts_pop.wav"],
	["MIDNIGHT DRIVE — LO-FI", "res://game/audio/radio/midnight_drive_lofi.wav"]]
var radio_station := 0
var _radio: AudioStreamPlayer


func next_station() -> void:
	radio_station = (radio_station + 1) % STATIONS.size()
	Sfx.play("static", global_position + Vector3(0, 1, 0), -18.0, 1.6)   # the dial click / static
	_radio_apply()
	radio_changed.emit(STATIONS[radio_station][0])


func _radio_apply() -> void:
	if _radio == null:
		_radio = AudioStreamPlayer.new()
		_radio.name = "CarRadio"
		add_child(_radio)
	var on := driven and radio_station > 0
	if on:
		var path: String = STATIONS[radio_station][1]
		if not (_radio.playing and _radio.has_meta("path") and _radio.get_meta("path") == path):
			_radio.stream = Sfx._looped(path, true)
			_radio.set_meta("path", path)
			_radio.volume_db = -6.0
			_radio.play()
	else:
		_radio.stop()
		_radio.remove_meta("path")
	Sfx.duck_music(on)


func _unhandled_input(event: InputEvent) -> void:
	if driven and event.is_action_pressed("car_radio"):
		next_station()
		get_viewport().set_input_as_handled()
		return
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
	# arrival assist: a smooth, gentle brake down to the cap (no sudden stop)
	if speed_cap > 0.0 and speed > speed_cap:
		throttle = 0.0
		brake = maxf(brake, clampf((speed - speed_cap) * 0.25, 0.03, 0.3))
	elif speed_cap > 0.0 and speed > speed_cap * 0.85:
		throttle = minf(throttle, 0.15)
	var scripted := drive_script.is_valid()
	if scripted:
		var cmd: Vector2 = drive_script.call(delta)
		speed = move_toward(speed, cmd.x, SCRIPT_ACCEL * delta)
		steer = move_toward(steer, clampf(cmd.y, -MAX_STEER, MAX_STEER), STEER_RATE * delta)
		throttle = 0.0
		brake = 0.0
	elif parking_brake:
		# released by a fresh press: input still held from before the brake went on is ignored
		if throttle == 0.0 and brake == 0.0:
			_brake_armed = true
		elif _brake_armed:
			parking_brake = false
		if parking_brake:
			speed = 0.0
	# longitudinal (arcade): S brakes while rolling forward, then reverses
	if scripted or parking_brake:
		pass
	elif throttle > 0.0:
		speed += (ACCEL * throttle * (1.0 - clampf(speed / TOP_SPEED, 0.0, 1.0) * 0.55) if speed >= 0.0 else BRAKE * throttle) * delta
	if brake > 0.0:
		if speed > 0.2:
			speed -= BRAKE * brake * delta
		else:
			speed -= ACCEL * 0.8 * brake * delta
	if throttle == 0.0 and brake == 0.0 and not scripted:
		speed = move_toward(speed, 0.0, COAST * delta)
	if hb:
		speed = move_toward(speed, 0.0, HANDBRAKE * delta)
	speed = clampf(speed, -REVERSE_SPEED, TOP_SPEED)
	# steering: full lock at low speed, gentler at speed; returns to centre
	if not scripted:
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


# ------------------------------------------------------------------ mirrors (rear-view + both door mirrors)
## Each mirror glass is a small quad showing a low-res rear-facing camera (its own SubViewport, same world), drawn
## flipped like a real mirror. They only render while the car is driven. Positions are the Pack 05 sedan's mirror
## faces (veh_models.py: door mirror heads at z -0.72, interior mirror at (0, 1.27, -0.12)), in the model frame.
const MIRRORS := [
	# [name, glass centre, glass size (w, h), viewport px, camera fov]
	["Mirror_Rear", Vector3(0.0, 1.27, -0.104), Vector2(0.23, 0.06), Vector2i(256, 68), 40.0],
	["Mirror_L", Vector3(-0.985, 0.952, -0.679), Vector2(0.09, 0.105), Vector2i(96, 112), 45.0],
	["Mirror_R", Vector3(0.985, 0.952, -0.679), Vector2(0.09, 0.105), Vector2i(96, 112), 45.0],
]
var _mirror_vps: Array = []


func _setup_mirrors() -> void:
	for m in MIRRORS:
		var vp := SubViewport.new()
		vp.name = m[0] + "_View"
		vp.size = m[3]
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(vp)                                   # no own world: it renders the game world
		var cam := Camera3D.new()
		cam.fov = m[4]
		cam.near = 0.15
		cam.far = 250.0
		vp.add_child(cam)
		var q := MeshInstance3D.new()
		q.name = m[0]
		var qm := QuadMesh.new()
		qm.size = m[2]
		q.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = vp.get_texture()
		mat.uv1_scale = Vector3(-1, 1, 1)              # mirrored left-right, like a real mirror
		mat.uv1_offset = Vector3(1, 0, 0)
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(q)
		q.position = m[1] + Vector3(0, 0, 0.004)        # just proud of the mirror face; faces +Z (backwards)
		q.visible = false
		_mirror_vps.append([vp, cam, q])


func _mirrors_on(on: bool) -> void:
	for e in _mirror_vps:
		(e[0] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		(e[2] as Node3D).visible = on


func _process(_delta: float) -> void:
	if not driven:
		return
	for e in _mirror_vps:
		var q: Node3D = e[2]
		var cam: Camera3D = e[1]
		# the camera sits at the mirror and looks back along the car (+Z of the model), level with the road
		var back := q.global_transform.basis.z
		back.y = 0.0
		cam.global_transform = Transform3D(Basis(), q.global_position + back.normalized() * 0.05).looking_at(
			q.global_position + back.normalized() * 10.0, Vector3.UP)
