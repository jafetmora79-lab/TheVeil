extends Node
class_name VeilIntro
## THE VEIL - the opening cinematic (a new game only, once; hold E or Esc to skip). A normal Friday in Greyhaven,
## seen from too high up - then the first wrong notes - then home, the errands - then, far off in the haze,
## something enormous moves. Title. It hands over to the wake-up as before.
##   0  black: a car radio playing; it slips into static for half a second and comes back
##   1  over the town at dusk (main street, the lit supermarket); "GREYHAVEN / Friday, 6:40 PM"
##   2  along the shop row's sidewalk (people out, traffic)
##   3  the supermarket's lit front
##   4  the mist pooling where the woods road meets the trees
##   5  a streetlight flickers once
##   6  a dog barks at nothing on Maple Ave, then stops
##   7  home: the near-empty fridge with a note ("groceries + pick up the game"), the car keys on the counter
##   8  the driveway, the car - the camera rises over the rooftops: in the far haze a silhouette shifts. THE VEIL.
## Only real game things are shown; nothing is changed for good (the note on the fridge stays as a prop).

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
const COLOSSUS := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Colossus.tscn"


func play(w: Node) -> void:
	world = w
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hud: Node = world.hud
	hud.allow_pause = false
	world.player.set("controls_enabled", false)
	world.player.set("look_enabled", false)
	if hud.get("quick"):
		hud.quick.modulate.a = 0.0
	cam = Camera3D.new()
	cam.name = "IntroCam"
	cam.fov = 55.0
	cam.far = 600.0
	world.add_child(cam)
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
		Sfx.play("static", world.player.global_position + Vector3(0, 1, 0), -6.0)
		await _wait(0.5)
		_radio.stream_paused = false
	await _wait(1.0)
	# 1-3: the town at dusk
	cam.current = true
	_shot_living(true)
	hud.fade_to(0.0, 1.6)
	world.get_tree().create_timer(1.8).timeout.connect(func():
		if not skipped and is_instance_valid(world):
			hud.location_caption("GREYHAVEN\nFriday, 6:40 PM", 3.2))
	await _shot(Vector3(-30, 26, 30), Vector3(65, 22, 30), Vector3(10, 0, -12), Vector3(48, 0, -14), 7.5)
	await _shot(Vector3(2, 2.2, 1.6), Vector3(24, 2.2, 1.2), Vector3(6, 1.4, 6.5), Vector3(28, 1.4, 6.5), 6.0)
	await _shot(Vector3(24, 3.0, -4), Vector3(29, 4.2, -8), Vector3(31, 5.0, -30), Vector3(31, 5.0, -30), 4.5)
	_fade_radio(4.0)
	# 4-6: three quiet wrong notes
	await _shot(Vector3(184, 1.7, 86), Vector3(184, 1.7, 96), Vector3(184, 1.2, 150), Vector3(184, 1.2, 150), 4.0)
	var shelf := _game_shelf()
	if not shelf.is_empty():
		var c: Vector3 = shelf[0]
		var along: Vector3 = shelf[1]
		var nrm: Vector3 = shelf[2]
		world.get_tree().create_timer(1.6).timeout.connect(func():
			if not skipped and world.has_method("_stutter_lights"):
				world._stutter_lights(world.game_shop))     # the shop's lights stutter, once
		await _shot(c + nrm * 1.7 - along * 1.3 + Vector3(0, 0.15, 0), c + nrm * 1.45 + along * 1.1 + Vector3(0, 0.05, 0),
			c - along * 0.7, c + along * 0.8, 4.4)
	var yard := Vector3(60, 0.5, 476)
	world.get_tree().create_timer(0.6).timeout.connect(func(): if not skipped: Sfx.bank_at("hound_bark", yard + Vector3(-6, 1, 6), -4.0, 20.0))
	world.get_tree().create_timer(1.4).timeout.connect(func(): if not skipped: Sfx.bank_at("hound_bark", yard + Vector3(-6, 1, 6), -6.0, 20.0))
	await _shot(Vector3(70, 3.2, 466), Vector3(69, 3.0, 467), yard, yard + Vector3(-1, 0, 1), 4.2)
	# 7: home - the fridge and its note, the keys
	var fridge := world.home.find_child("Fridge_Retro_01", true, false) as Node3D if world.get("home") else null
	if fridge:
		var fz: Vector3 = fridge.global_transform.basis.z.normalized()
		var fc: Vector3 = fridge.global_transform * Vector3(0, 1.35, 0)
		var keys := _keys()
		var kp: Vector3 = keys.global_position if keys else fc + fridge.global_transform.basis.x * 1.2
		await _shot(fc + fz * 1.7 + Vector3(0, 0.15, 0), fc + fz * 1.4, fc + Vector3(0, -0.05, 0), kp, 5.0)
	# 8: the driveway; the rise over the roofs; the shape in the haze; the title
	var car: Node3D = world.sedan
	if car:
		var low: Vector3 = car.global_transform * Vector3(1.8, 1.0, 5.5)
		var dir := (Vector3(30, 0, -20) - car.global_position) * Vector3(1, 0, 1)
		dir = dir.normalized()
		var wall_at := car.global_position + dir * 190.0
		_build_veil_wall(wall_at, dir)
		_place_colossus(car.global_position + dir * 215.0)      # just inside the wall: a shape, barely there
		await _shot(low, low + Vector3(0, 0.6, 0), car.global_position + Vector3(0, 0.8, 0), car.global_position + Vector3(0, 0.8, 0), 2.6)
		if not skipped:
			Sfx.play_music(Sfx.MUSIC_COLOSSUS, false, -4.0, 1.5)    # the ominous turn, as the camera rises
			Sfx.play("veil_rumble", car.global_position + dir * 60.0 + Vector3(0, 10, 0), 0.0)
		await _shot(low + Vector3(0, 0.6, 0), car.global_position + Vector3(0, 24, 0) - dir * 6.0, car.global_position + Vector3(0, 0.8, 0),
			wall_at + Vector3(0, 28, 0), 6.0)
		_creep_wall(dir, 34.0, 7.0)                             # it keeps coming
		await _shot(car.global_position + Vector3(0, 24, 0) - dir * 6.0, car.global_position + Vector3(0, 21, 0) - dir * 10.0,
			wall_at + Vector3(0, 28, 0), wall_at + Vector3(0, 24, 0) - dir * 30.0, 4.5)
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


## One camera move: position from `a` to `b`, looking from `la` to `lb`, eased, `secs` long (skippable).
func _shot(a: Vector3, b: Vector3, la: Vector3, lb: Vector3, secs: float) -> void:
	if skipped:
		return
	report["shots"] = int(report["shots"]) + 1
	var t := 0.0
	while t < secs and not skipped:
		var k := t / secs
		k = k * k * (3.0 - 2.0 * k)
		var p := a.lerp(b, k)
		var look := la.lerp(lb, k)
		if (look - p).length() > 0.05:
			cam.global_transform = Transform3D(Basis.looking_at(look - p, Vector3.UP), p)
		var living = world.get("living")
		if living and living.get("focus_override") != null:
			living.focus_override = p
		await world.get_tree().process_frame
		t += world.get_process_delta_time()
		_check_skip(world.get_process_delta_time())


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


func _lamp_near(at: Vector3, lights: Array) -> Light3D:
	var best: Light3D = null
	var bd := 60.0
	for l in lights:
		if l is Light3D and (l as Light3D).visible:
			var d := (l as Light3D).global_position.distance_to(at)
			if d < bd:
				bd = d
				best = l
	return best


func _flicker(l: Light3D) -> void:
	var e0 := l.light_energy
	await _wait(1.0)
	for k in [0.0, e0 * 1.4, 0.0, e0]:
		if skipped or not is_instance_valid(l):
			break
		l.light_energy = k
		await _wait(0.08)
	if is_instance_valid(l):
		l.light_energy = e0


func _keys() -> Node3D:
	for it in world.interactables.values():
		if is_instance_valid(it) and String((it as Interactable).item_id) == "car_keys":
			return it as Node3D
	return null


## The errands, on a note stuck to the outside of the fridge door (it stays there, and swings with the door).
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
	return load("res://game/tools/trailer_director.gd").shelf_of(world.get("shop_merch"), "game_", world.game_shop)


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


## Far off in the haze, the Colossus: a dark shape shifting for a few seconds (it walks, slowly).
func _place_colossus(at: Vector3) -> void:
	if not ResourceLoader.exists(COLOSSUS):
		return
	_colossus = (load(COLOSSUS) as PackedScene).instantiate() as Node3D
	_colossus.name = "Intro_Colossus"
	world.add_child(_colossus)
	if _colossus is CollisionObject3D:
		(_colossus as CollisionObject3D).collision_layer = 0
		(_colossus as CollisionObject3D).collision_mask = 0
	_colossus.set_physics_process(false)
	var model := _colossus.get_node_or_null("Model") as Node3D
	if model:
		model.scale = Vector3.ONE * 6.0
	VeilCreatureLook.apply_colossus(_colossus, at.y)
	_colossus.global_position = at
	_colossus.rotation.y = randf_range(0.0, TAU)
	_wall.append(_colossus)                                   # (moves in with the mist)
	var ap := _colossus.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("Walk_Heavy"):
		ap.get_animation("Walk_Heavy").loop_mode = Animation.LOOP_LINEAR
		ap.play("Walk_Heavy")
		ap.speed_scale = 0.35
	report["colossus"] = true
