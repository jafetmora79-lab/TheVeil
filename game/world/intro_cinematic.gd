extends Node
class_name VeilIntro
## THE VEIL - the opening cinematic (a new game only, once; hold E or Esc to skip). Rebuilt: it never shows the inside of the home any more
## (the wake-up follows the intro, as before). A normal Friday in Greyhaven seen from above and from the street, with its people (the Meshy
## characters of the living town), then the first wrong notes, then - far off in the haze - the Veil rising and the tripod Colossus walking in it. Title.
##   0  black from the first frame (the camera is parked outside before anything is shown): a car radio; static for half a second
##   1  a crane move over the town at dusk (main street, the lit supermarket); "GREYHAVEN / Friday, 6:40 PM"
##   2  a slow dolly along the shop row's sidewalk: people out, traffic
##   3  the supermarket's lit front, pushing in
##   4  the mist pooling where the woods road meets the trees
##   5  the game shop's lights stutter once
##   6  a dog barks at nothing on Maple Ave, then stops
##   7  the driveway and the car; the camera rises over the rooftops: in the far haze the Veil comes up, the tripod Colossus walks in it, slowly. THE VEIL.
## Only real game things are shown; nothing is changed for good.

signal finished

var world: Node
var cam: Camera3D
var skipped := false
var report := {"shots": 0}
var _radio: AudioStreamPlayer
var _hold := 0.0
var _colossus: Node3D
var _wall: Array = []                 ## the mist curtains of the last shot

const RADIO := "res://game/audio/radio/midnight_drive_lofi.wav"
const COLOSSUS_H := 70.0              ## the tripod's height in the haze (m)


func play(w: Node) -> void:
	world = w
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hud: Node = world.hud
	hud.allow_pause = false
	world.player.set("controls_enabled", false)
	world.player.set("look_enabled", false)
	if hud.get("quick"):
		hud.quick.modulate.a = 0.0
	hud.fade.color.a = 1.0                                   # black from the very first frame
	cam = Camera3D.new()
	cam.name = "IntroCam"
	cam.fov = 55.0
	cam.far = 900.0
	world.add_child(cam)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3(10, 0, -12) - Vector3(-30, 26, 30), Vector3.UP), Vector3(-30, 26, 30))
	cam.current = true                                       # parked outside already: the home is never on screen
	_note_on_fridge()
	# 0: black, the radio
	if ResourceLoader.exists(RADIO):
		_radio = AudioStreamPlayer.new()
		_radio.stream = load(RADIO)
		_radio.volume_db = -10.0
		add_child(_radio)
		_radio.play(18.0)
	await _wait(2.2)
	if _radio and not skipped:
		_radio.stream_paused = true
		Sfx.play("static", Vector3(-30, 26, 30), -6.0)
		await _wait(0.5)
		_radio.stream_paused = false
	await _wait(1.0)
	# 1-3: the town at dusk
	_shot_living(true)
	hud.fade_to(0.0, 1.6)
	world.get_tree().create_timer(1.8).timeout.connect(func():
		if not skipped and is_instance_valid(world):
			hud.location_caption("GREYHAVEN\nFriday, 6:40 PM", 3.2))
	# a crane move: high over the main street, sinking and drifting along it
	await _shot(Vector3(-30, 26, 30), Vector3(52, 14, 26), Vector3(10, 0, -12), Vector3(44, 0, -14), 8.0, 50.0, 0.0)
	# the shop row at eye level: a slow dolly beside the people on the pavement
	await _shot(Vector3(2, 1.7, 1.8), Vector3(26, 1.7, 1.4), Vector3(14, 1.5, 7.0), Vector3(38, 1.5, 7.0), 7.0, 42.0, 0.02)
	# the supermarket's lit front, pushing in
	await _shot(Vector3(22, 2.4, -2), Vector3(28, 2.6, -8), Vector3(31, 4.2, -30), Vector3(31, 4.2, -30), 5.0, 38.0, 0.015)
	_fade_radio(4.0)
	# 4-6: three quiet wrong notes
	await _shot(Vector3(184, 1.7, 86), Vector3(184, 1.7, 96), Vector3(184, 1.2, 150), Vector3(184, 1.2, 150), 4.5, 45.0, 0.02)
	var shelf := _game_shelf()
	if not shelf.is_empty():
		var c: Vector3 = shelf[0]
		var along: Vector3 = shelf[1]
		var nrm: Vector3 = shelf[2]
		world.get_tree().create_timer(1.6).timeout.connect(func():
			if not skipped and world.has_method("_stutter_lights"):
				world._stutter_lights(world.game_shop))     # the shop's lights stutter, once
		await _shot(c + nrm * 1.7 - along * 1.3 + Vector3(0, 0.15, 0), c + nrm * 1.45 + along * 1.1 + Vector3(0, 0.05, 0),
			c - along * 0.7, c + along * 0.8, 4.4, 50.0, 0.0)
	var yard := Vector3(60, 0.5, 476)
	world.get_tree().create_timer(0.6).timeout.connect(func(): if not skipped: Sfx.bank_at("hound_bark", yard + Vector3(-6, 1, 6), -4.0, 20.0))
	world.get_tree().create_timer(1.4).timeout.connect(func(): if not skipped: Sfx.bank_at("hound_bark", yard + Vector3(-6, 1, 6), -6.0, 20.0))
	await _shot(Vector3(70, 3.2, 466), Vector3(69, 3.0, 467), yard, yard + Vector3(-1, 0, 1), 4.2, 45.0, 0.02)
	# 7: the driveway and the car; the rise over the roofs; the Veil coming up with the Colossus in it; the title
	var car: Node3D = world.sedan
	if car:
		var low: Vector3 = car.global_transform * Vector3(1.8, 1.0, 5.5)
		var dir := (Vector3(30, 0, -20) - car.global_position) * Vector3(1, 0, 1)
		dir = dir.normalized()
		var wall_at := car.global_position + dir * 190.0
		_build_veil_wall(wall_at, dir)
		_place_colossus(car.global_position + dir * 235.0)      # inside the wall: a huge shape, barely there
		await _shot(low, low + Vector3(0, 0.6, 0), car.global_position + Vector3(0, 0.8, 0), car.global_position + Vector3(0, 0.8, 0), 2.6, 50.0, 0.015)
		if not skipped:
			Sfx.play_music(Sfx.MUSIC_COLOSSUS, false, -4.0, 1.5)    # the ominous turn, as the camera rises
			Sfx.play("veil_rumble", car.global_position + dir * 60.0 + Vector3(0, 10, 0), 0.0)
		await _shot(low + Vector3(0, 0.6, 0), car.global_position + Vector3(0, 24, 0) - dir * 6.0, car.global_position + Vector3(0, 0.8, 0),
			wall_at + Vector3(0, 30, 0), 6.5, 50.0, 0.0)
		_creep_wall(dir, 30.0, 8.0)                             # it keeps coming
		await _shot(car.global_position + Vector3(0, 24, 0) - dir * 6.0, car.global_position + Vector3(0, 21, 0) - dir * 10.0,
			wall_at + Vector3(0, 30, 0), wall_at + Vector3(0, 26, 0) - dir * 30.0, 5.0, 32.0, 0.0)      # a long lens: it looms
		if not skipped:
			Sfx.play("colossus_call", wall_at + Vector3(0, 30, 0), -1.0, 0.55)
	if not skipped:
		hud.title_card("THE VEIL", 2.6)
		await _wait(3.4)
	await _end()


func _end() -> void:
	var hud: Node = world.hud
	Sfx.stop_music(1.2)
	await hud.fade_to(1.0, 0.6)
	for wl in _wall:
		if is_instance_valid(wl):
			wl.queue_free()
	_wall.clear()
	_shot_living(false)
	if _radio:
		_radio.queue_free()
	if is_instance_valid(_colossus):
		_colossus.queue_free()
	if is_instance_valid(cam):
		cam.queue_free()
	world.player.camera.current = true
	if hud.get("quick"):
		hud.quick.modulate.a = 1.0
	Game.set_flag("intro_seen")
	report["done"] = true
	report["skipped"] = skipped
	finished.emit()


## One camera move: position from `a` to `b`, looking from `la` to `lb`, eased, `secs` long (skippable). `fov` eases from the previous lens to this one;
## `sway` is a faint handheld drift (metres). Near geometry never sits between the camera and what it looks at (the camera is pulled in front of it).
func _shot(a: Vector3, b: Vector3, la: Vector3, lb: Vector3, secs: float, fov := 55.0, sway := 0.0) -> void:
	if skipped:
		return
	report["shots"] = int(report["shots"]) + 1
	var t := 0.0
	var fov0 := cam.fov
	while t < secs and not skipped:
		var k := t / secs
		k = k * k * (3.0 - 2.0 * k)
		var p := a.lerp(b, k)
		var look := la.lerp(lb, k)
		if sway > 0.0:
			p += Vector3(sin(t * 1.3), sin(t * 1.9 + 1.0) * 0.7, sin(t * 1.1 + 2.0)) * sway
		p = _clear(p, look)
		cam.fov = lerpf(fov0, fov, minf(t / 1.5, 1.0))
		if (look - p).length() > 0.05:
			cam.global_transform = Transform3D(Basis.looking_at(look - p, Vector3.UP), p)
		var living = world.get("living")
		if living and living.get("focus_override") != null:
			living.focus_override = p
		await world.get_tree().process_frame
		t += world.get_process_delta_time()
		_check_skip(world.get_process_delta_time())


## Pull a close camera in front of a wall / car / sign that would block the view (only for shots within 30 m of their target).
func _clear(p: Vector3, look: Vector3) -> Vector3:
	var d := p.distance_to(look)
	if d > 30.0 or d < 0.8 or not is_instance_valid(world):
		return p
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(look, p)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return p
	return (hit["position"] as Vector3) + (look - p).normalized() * 0.35


func _wait(secs: float) -> void:
	var t := 0.0
	while t < secs and not skipped:
		await world.get_tree().process_frame
		t += world.get_process_delta_time()
		_check_skip(world.get_process_delta_time())


func _check_skip(dt: float) -> void:
	if Input.is_action_pressed("pause"):
		skipped = true
	_hold = _hold + dt if Input.is_action_pressed("interact") else 0.0
	if _hold > 0.8:
		skipped = true


## The town lives where the camera is (people walking, traffic), not round the sleeping protagonist.
func _shot_living(on: bool) -> void:
	var living = world.get("living")
	if living and living.get("focus_override") != null:
		living.focus_override = cam.global_position if on else Vector3.INF


func _fade_radio(secs: float) -> void:
	if _radio == null:
		return
	var tw := create_tween()
	tw.tween_property(_radio, "volume_db", -40.0, secs)


func _keys() -> Node3D:
	for it in world.interactables.values():
		if is_instance_valid(it) and String((it as Interactable).item_id) == "car_keys":
			return it as Node3D
	return null


## The errands, on a note stuck to the outside of the fridge door (a prop of the home: it stays there, and swings with the door).
func _note_on_fridge() -> void:
	var fridge := world.home.find_child("Fridge_Retro_01", true, false) as Node3D if world.get("home") else null
	var door := fridge.find_child("INT_ApplianceDoor_Fridge", true, false) as Node3D if fridge else null
	if door == null or door.get_node_or_null("IntroNote"):
		return
	var note := MeshInstance3D.new()
	note.name = "IntroNote"
	var q := QuadMesh.new()
	q.size = Vector2(0.15, 0.15)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.88, 0.45)
	q.material = m
	note.mesh = q
	door.add_child(note)
	note.position = Vector3(0.5, 1.32, 0.104)                  # door-local: its outer face is +Z (0.1)
	note.rotation.z = deg_to_rad(-4.0)
	var txt := Label3D.new()
	txt.text = "groceries\n+ pick up\nthe game"
	txt.font_size = 18
	txt.pixel_size = 0.0017
	txt.modulate = Color(0.15, 0.12, 0.1)
	txt.outline_size = 0
	txt.position = Vector3(0, 0, 0.002)
	note.add_child(txt)


## The game shop's own game shelf (its merchandise): [centre, along the shelf, out of the shelf into the room].
func _game_shelf() -> Array:
	return load("res://game/trailer/trailer_director.gd").shelf_of(world.get("shop_merch"), "game_", world.game_shop)


## The Veil itself, far off: three vast curtains of the game's mist (the mist-boundary shader), one behind the other,
## dense at the ground and thinning upward; the Colossus walks between the first and the second.
func _build_veil_wall(at: Vector3, dir: Vector3) -> void:
	var sh := load("res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Fog/veil_mist_boundary.gdshader") as Shader
	var noise := load("res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Textures/T_Veil_MistNoise.png") as Texture2D
	if sh == null:
		return
	var face := Basis.looking_at(dir, Vector3.UP)              # its face toward the town (and the camera)
	var layers := [[0.0, 0.55, 140.0], [35.0, 0.78, 170.0], [80.0, 0.95, 200.0]]
	for L in layers:
		var mi := MeshInstance3D.new()
		mi.name = "Intro_VeilWall"
		var qm := QuadMesh.new()
		qm.size = Vector2(900.0, float(L[2]))
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("noise_tex", noise)
		mat.set_shader_parameter("curtain_height", float(L[2]))
		mat.set_shader_parameter("density", float(L[1]))
		mat.set_shader_parameter("base_color", Color(0.36, 0.38, 0.42))
		mat.set_shader_parameter("edge_color", Color(0.16, 0.17, 0.22))
		mat.set_shader_parameter("rise_speed", 0.05)
		qm.material = mat
		mi.mesh = qm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		mi.global_transform = Transform3D(face, at + dir * float(L[0]) + Vector3(0, float(L[2]) * 0.5 - 2.0, 0))
		_wall.append(mi)
	report["veil_wall"] = layers.size()


## The wall (and what walks in it) rolls toward the town.
func _creep_wall(dir: Vector3, metres: float, secs: float) -> void:
	for n in _wall:
		if is_instance_valid(n):
			var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(n, "global_position", (n as Node3D).global_position - dir * metres, secs)


## Far off in the haze, the Colossus: the Meshy tripod, huge, walking toward the town very slowly - the two front legs first, then the rear one.
## It is not carried along with the mist: it moves only as fast as its own legs walk (ground_speed), so its feet do not slide.
func _place_colossus(at: Vector3) -> void:
	var tc := VeilTripodColossus.new()
	tc.name = "Intro_Colossus"
	world.add_child(tc)
	tc.build(COLOSSUS_H, at.y)
	_colossus = tc
	tc.global_position = at
	var toward: Vector3 = ((world.sedan.global_position if world.get("sedan") else Vector3.ZERO) - at) * Vector3(1, 0, 1)
	toward = toward.normalized()
	tc.rotation.y = atan2(-toward.x, -toward.z)                # (its model faces -Z)
	tc.set_walking(true, 0.9)
	var tw := create_tween()
	tw.tween_property(tc, "global_position", at + toward * tc.ground_speed() * 24.0, 24.0)
	report["colossus"] = true
	report["colossus_faces_camera"] = true
