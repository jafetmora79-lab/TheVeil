extends VeilTrailerDirector
class_name VeilPreviewDirector
## THE VEIL - the game preview, "WHAT COMES OUT OF THE FOG" (~75 s). Played live in the real world (the trailer director's camera, clearance, fade and card tools), made for
## recording: game/preview/render_preview.gd drives it and Godot's movie writer records picture and sound. Everything on screen is the game's own: the town at dusk and its
## people, the Veil's wall, the Meshy tripod walking out of it with its Grimtalons, the Meshy hounds, a street tentacle, a Grimtalon taking a man, the dark shelter, the title.
##   1  dusk      the radio; a crane over Main St; the shop row; the supermarket's lit front. "ONE LAST STOP."
##   2  wrong     the light goes, the lamps stutter; a flock of Grimtalons crosses the dusk; a wall of mist stands at the end of the street
##   3  colossus  the tripod walks out of the Veil toward the camera, its Grimtalons wheeling; the eye finds the lens
##   4  hounds    five hounds run down the street straight at the camera
##   5  tentacle  the road breaks beside the lens; a tentacle rises and lashes
##   6  taken     a man looks up; a Grimtalon takes him into the mist
##   7  shelter   the dark supermarket, a flashlight, the long aisle
##   8  title      THE VEIL
## Launch: godot --path . --fixed-fps 30 --resolution 1920x1080 --write-movie out.avi --script res://game/preview/render_preview.gd

const TITLE_FONT_SIZE := 120
var grain: ColorRect
var bars: Array = []
var _birds: Array = []
var P: Vector3                  # the supermarket's front, on the pavement
var N: Vector3                  # out of the doors, across the street
var S: Vector3                  # along the street (N x up)
var timeline := {}              ## tests / the render script: shot name -> start second


func _ready() -> void:
	super._ready()
	# a film look over everything: 2.39:1 bars, a soft vignette and fine grain (screen-space, over the picture, under the black and the cards)
	layer = 99
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.55;
float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.85, 0.2, length(uv * vec2(1.0, 1.15)));
	float g = (hash(UV * vec2(1920.0, 1080.0) + TIME * 37.0) - 0.5) * 0.07;
	COLOR = vec4(0.0, 0.0, 0.0, clamp((1.0 - v) * strength - g, 0.0, 1.0));
}
"""
	grain = ColorRect.new()
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = sh
	grain.material = m
	add_child(grain)
	move_child(grain, 0)
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.anchor_left = 0.0
		b.anchor_right = 1.0
		if top:
			b.anchor_top = 0.0
			b.anchor_bottom = 0.0
			b.offset_bottom = 0.0
		else:
			b.anchor_top = 1.0
			b.anchor_bottom = 1.0
		add_child(b)
		bars.append(b)
	_card.add_theme_font_size_override("font_size", 46)
	_layout_bars()
	get_viewport().size_changed.connect(_layout_bars)


func _layout_bars() -> void:
	var sz := get_viewport().get_visible_rect().size
	var h := maxf((sz.y - sz.x / 2.39) * 0.5, 0.0)
	(bars[0] as ColorRect).offset_bottom = h
	(bars[1] as ColorRect).offset_top = -h


## While recording nothing may stop the run (a key pressed in the window used to abort the trailer's director at the first shot).
func _process(_d: float) -> void:
	pass


static func start_preview(tree: SceneTree) -> VeilPreviewDirector:
	Engine.time_scale = 1.0
	tree.paused = false
	Game.new_game()
	for f in ["intro_seen", "has_keys", "fridge_checked", "left_house", "entered_car", "arrival_shot"]:
		Game.flags[f] = true
	Game.no_save = true
	Game.set_meta("trailer_run", true)
	var d := VeilPreviewDirector.new()
	d.name = "PreviewDirector"
	tree.root.add_child(d)
	var w := (load("res://game/scenes/World.tscn") as PackedScene).instantiate()
	tree.root.add_child(w)
	d.run.call_deferred()
	return d


func run() -> void:
	for i in 600:
		await get_tree().process_frame
		world = get_tree().get_first_node_in_group("veil_world")
		if world and world.get("player") and world.get("living") and world.get("market"):
			break
	if world == null:
		_finish()
		return
	for i in 90:
		await get_tree().process_frame
	_setup()
	_stage_geometry()
	for seg in [_p1_dusk, _p2_wrong, _p3_colossus, _p4_hounds, _p5_tentacle, _p6_taken, _p7_shelter, _p8_title]:
		if aborted or not is_instance_valid(world):
			break
		var t0 := Time.get_ticks_msec()
		await seg.call()
		(report["segments"] as Array).append(String(seg.get_method()))
		print("PREVIEW segment %s took %.1f s" % [seg.get_method(), (Time.get_ticks_msec() - t0) / 1000.0])
	_finish()


func _stage_geometry() -> void:
	var m: Node3D = world.market
	var din: Vector3 = (m.get_node("Doorways/Entrance_Inside") as Node3D).global_position
	var dout: Vector3 = (m.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	N = ((dout - din) * Vector3(1, 0, 1)).normalized()
	S = N.cross(Vector3.UP).normalized()
	P = dout + N * 1.2
	P.y = 0.15
	for n in [world.get("eddie"), world.get("marcus"), world.get("cashier")]:
		pass


## The thin mist thickness for a shot (the presets' fog is heavy: monsters in it read as pale grey ghosts).
func _fog(density: float, ambient := -1.0) -> void:
	var we := world.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we and we.environment:
		we.environment.fog_enabled = true
		we.environment.fog_density = density
		if ambient >= 0.0:
			we.environment.ambient_light_energy = ambient


## Shader parameters on every surface of a creature that has the Veil look (the sweet spot between lost in the mist and plain: faint but readable).
func _tune(n: Node, params: Dictionary) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var sm := m.get_surface_override_material(i) as ShaderMaterial
			if sm:
				for k in params:
					sm.set_shader_parameter(k, params[k])


## The street's people take fright: they turn their backs on `from` and run along the street, away from it, in the Veil's mood.
func _people_flee(from: Vector3, speed := 3.5, within := 90.0) -> void:
	var lt = world.living
	for k in lt.people:
		var p: Dictionary = lt.people[k]
		var b = p.get("body")
		if not is_instance_valid(b) or not (b as Node3D).visible or String(p.get("state", "")) == "event":
			continue
		var bp: Vector3 = (b as Node3D).global_position
		if bp.distance_to(from) > within:
			continue
		var away := (bp - from) * Vector3(1, 0, 1)
		away = away.normalized() if away.length() > 0.1 else S
		var dir: Vector3 = S if away.dot(S) >= 0.0 else -S
		var to := bp + dir * 60.0
		p["state"] = "event"
		var a = p["anim"]
		a.set_process(true)
		a.set_mood("scared")
		a.walk_to([lt._ground(to)], speed)


func _eye(at: Vector3, h := 1.6) -> Vector3:
	return Vector3(at.x, at.y + h, at.z)


# ------------------------------------------------------------------ 1 dusk
func _p1_dusk() -> void:
	_preset(P_EVENING, true)
	var radio := _sound3d(RADIO, world.sedan, -4.0, 40.0)
	_fade(1.0, 0.0)
	await _hold(0.4)
	_fade(0.0, 1.6)
	_title.text = ""
	# the crane: high over Main St, sinking and drifting along it
	_cfg("dusk_crane", 50.0)
	_card_show("GREYHAVEN", 2.2)
	await _shot(Vector3(-22, 15, 24), Vector3(44, 8.5, 22), Vector3(10, 0, -10), Vector3(40, 0, -12), 5.6)
	# the shop row at eye level: a slow dolly beside the people on the pavement
	_cfg("shop_row", 42.0)
	await _shot(Vector3(2, 1.7, 1.8), Vector3(26, 1.7, 1.4), Vector3(14, 1.5, 7.0), Vector3(38, 1.5, 7.0), 4.6)
	# the supermarket's lit front, pushing in
	_cfg("market_front", 38.0)
	_card_show("ONE LAST STOP.", 1.6, true)
	await _shot(P + N * 9.0 + S * -5.0 + Vector3(0, 1.4, 0), P + N * 4.0 + S * 1.0 + Vector3(0, 1.8, 0), P + Vector3(0, 4.0, 0), P + Vector3(0, 4.2, 0), 4.0)
	if radio:
		var tw := create_tween()
		tw.tween_property(radio, "volume_db", -40.0, 2.0)


# ------------------------------------------------------------------ 2 something is wrong
func _p2_wrong() -> void:
	_preset(P_APPROACH, false)
	Sfx.play("static", P + Vector3(0, 2, 0), -6.0)
	for l in world.market.get_node("Lights").get_children():
		if l is Light3D:
			(l as Light3D).visible = false
	await _hold(0.0)
	# the flock: Grimtalons crossing the dusk high over the street, seen from the pavement
	var centre := P + N * 22.0 + Vector3(0, 0, 0)
	var anchor := Node3D.new()
	world.add_child(anchor)
	anchor.global_position = centre + S * 50.0
	_spawned.append(anchor)
	_birds = VeilGrimtalon.flock(world, 9, anchor.global_position, anchor, Vector2(8, 22), Vector2(20, 36), Vector2(9, 13))
	for b in _birds:
		_spawned.append(b)
	var drift := create_tween()
	drift.tween_property(anchor, "global_position", centre - S * 60.0, 7.0)
	_people_flee(P + N * 10.0, 3.2)
	_cfg("flock_over_street", 52.0)
	var cam_at := P + N * 6.0 + Vector3(0, 1.4, 0)
	await _shot(cam_at, cam_at + S * 2.0, centre + S * 30.0 + Vector3(0, 26, 0), centre - S * 20.0 + Vector3(0, 28, 0), 4.4)
	# the wall of mist at the end of the street
	var wall_at := P + N * 105.0
	_mist_wall(wall_at, -N, 3, 0.7)
	Sfx.play("veil_rumble", P + N * 30.0 + Vector3(0, 2, 0), 0.0, 0.8)
	_cfg("the_wall", 46.0)
	await _shot(P + Vector3(0, 1.3, 0) + S * 3.0, P + Vector3(0, 1.4, 0) + S * 3.0 + N * 3.0, P + N * 100.0 + Vector3(0, 12, 0), P + N * 100.0 + Vector3(0, 16, 0), 3.2)


# ------------------------------------------------------------------ 3 the colossus
func _p3_colossus() -> void:
	world._atmo().apply_preset(world.night_preset("approach"), false)
	_fog(0.0035, 0.8)
	for b in _birds:
		if is_instance_valid(b):
			b.queue_free()
	_birds.clear()
	var ground := P.y
	Sfx.play_music(Sfx.MUSIC_COLOSSUS, false, -5.0, 0.6, Sfx.MUSIC_GAMEPLAY)
	var tc := VeilTripodColossus.new()
	tc.name = "Preview_Colossus"
	world.add_child(tc)
	_spawned.append(tc)
	tc.build(85.0, ground)
	tc.enable_stomps()
	var A := P + N * 135.0 - S * 14.0
	A.y = ground
	var end := P + N * 90.0 - S * 3.0
	var wd := ((end - A) * Vector3(1, 0, 1)).normalized()
	tc.global_position = A
	tc.rotation.y = atan2(-wd.x, -wd.z)
	tc.set_walking(true, 1.35)
	_tune(tc, {"conceal_start": 70.0, "conceal_end": 260.0, "albedo_mul": 1.0, "distance_fade": 0.0016, "mist_col": Color(0.08, 0.09, 0.13), "emission_energy": 0.25})
	tc.eye.search_on = true
	tc.eye.aim_direct = true
	tc.eye.level = 1.0
	_people_flee(P + N * 40.0, 3.6)
	var scan := Node3D.new()
	world.add_child(scan)
	_spawned.append(scan)
	tc.eye.target = scan
	# the thick wall it comes out of, and the thinner mist in front of the camera
	var near_curtains: Array = world._enc_mist(P, N, ground)
	var entry: Array = world._enc_mist(P, N, ground, [[96.0, 150.0], [102.0, 170.0], [108.0, 190.0]])
	for c in near_curtains:
		((c as MeshInstance3D).mesh as QuadMesh).material.set_shader_parameter("density", 0.45)
	var te := create_tween().set_parallel(true)
	for c in entry:
		var em := ((c as MeshInstance3D).mesh as QuadMesh).material as ShaderMaterial
		em.set_shader_parameter("density", 0.97)
		te.tween_method(func(v: float): em.set_shader_parameter("density", v), 0.97, 0.3, 3.0).set_delay(5.6)
	_spawned.append_array(near_curtains)
	_spawned.append_array(entry)
	_birds = VeilGrimtalon.flock(world, 10, A, tc, Vector2(26, 70), Vector2(14, 80), Vector2(8, 13))
	for b in _birds:
		_spawned.append(b)
	var walk := create_tween()
	walk.tween_property(tc, "global_position", end, 9.0).set_trans(Tween.TRANS_LINEAR)
	var steps := func():
		for k in 4:
			await get_tree().create_timer(1.9).timeout
			Sfx.play("colossus_step", tc.global_position + Vector3(0, 1, 0), 5.0, 0.55)
	steps.call()
	scan.global_position = P + N * 40.0 + S * -50.0
	var sweep := create_tween()
	sweep.tween_property(scan, "global_position", P + N * 40.0 + S * 8.0, 7.0).set_trans(Tween.TRANS_SINE)
	# the camera: low in the street, looking down it as the shape comes out of the wall; a slow push, then a drift up to the eye
	var cam_a := P + Vector3(0, 1.5, 0) + S * 2.0
	var cam_b := P + N * 3.0 + Vector3(0, 1.6, 0) + S * 2.5
	_cfg("colossus_walks_out", 40.0)
	_card_show("", 0.1)
	await _shot(cam_a, cam_b, tc.global_position + Vector3(0, 30, 0), P + N * 92.0 + Vector3(0, 40, 0), 6.2, func(): return tc.global_position + Vector3(0, 32.0, 0))
	# the eye finds the lens: lock, a punch in on the light, hard cut
	tc.eye.target = cam
	tc.eye.max_angle = PI
	tc.eye.level = 0.9
	tc.eye.beam_on = false                                  # (the flare whites the frame out: the lens is seen as an eye, not a glare)
	Sfx.play("colossus_call", cam.global_position + N * 4.0 + Vector3(0, 2, 0), 12.0, 1.1)
	_cfg("colossus_locks_on", 34.0)
	var z := create_tween()
	z.tween_property(cam, "fov", 38.0, 1.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await _shot(cam_b, cam_b + N * 0.5, tc.eye.eye_world_pos(), tc.eye.eye_world_pos(), 2.0, func(): return tc.eye.eye_world_pos())
	_fade(1.0, 0.0)
	await _hold(0.5)
	for c in near_curtains + entry:
		if is_instance_valid(c):
			c.queue_free()
	tc.queue_free()
	for b in _birds:
		if is_instance_valid(b):
			b.queue_free()
	_birds.clear()


# ------------------------------------------------------------------ 4 the hounds
func _p4_hounds() -> void:
	world._atmo().apply_preset(world.night_preset("active"), true)
	_fog(0.004)
	_people_flee(P + N * 25.0, 4.0, 120.0)
	var ground := P.y
	var ps := load(VeilMeshyNpcs.monster_scene(HOUND)) as PackedScene
	var pack: Array = []
	var cam_p := P + N * 2.0 + S * 3.0 + Vector3(0, 0.55, 0)
	for i in 5:
		var h := ps.instantiate() as Node3D
		world.add_child(h)
		_spawned.append(h)
		for co in h.find_children("*", "CollisionObject3D", true, false):
			(co as CollisionObject3D).collision_layer = 0
			(co as CollisionObject3D).collision_mask = 0
		if h is CollisionObject3D:
			(h as CollisionObject3D).collision_layer = 0
			(h as CollisionObject3D).collision_mask = 0
		h.set_physics_process(false)
		h.scale = Vector3.ONE * 1.3
		VeilCreatureLook.apply_ground(h, ground)
		_tune(h, {"distance_fade": 0.004, "albedo_mul": 0.5, "ambient": 0.22, "key_energy": 0.9, "mist_col": Color(0.05, 0.06, 0.09), "emission_energy": 0.0})
		var start := cam_p + N * (20.0 + i * 5.0) + S * ((i - 2) * 0.55)
		start.y = ground
		var to := cam_p + S * ((i - 2) * 0.35)
		to.y = ground
		var dv := to - start
		h.global_position = start
		h.rotation.y = atan2(dv.x, dv.z)
		var ap := h.get_node_or_null(String(h.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
		var v := 13.0
		if ap and ap.has_animation("Run"):
			ap.play("Run")
			ap.speed_scale = v / maxf(float(h.get_meta("run_speed_mps", 6.8)) * h.scale.x, 0.5)
			ap.seek(i * 0.11, true)
		var tw := h.create_tween()
		tw.tween_interval(0.0)
		tw.tween_property(h, "global_position", to + dv.normalized() * 6.0, (start.distance_to(to) + 6.0) / v)
		pack.append(h)
	Sfx.bank_at("hound_bark", cam_p + N * 30.0, 2.0, 40.0)
	Sfx.play("colossus_call", cam_p + N * 60.0 + Vector3(0, 10, 0), -2.0, 0.7)
	_fade(0.0, 0.0)
	var hl := SpotLight3D.new()
	hl.spot_range = 60.0
	hl.spot_angle = 30.0
	hl.light_energy = 5.0
	hl.light_color = Color(0.75, 0.82, 1.0)
	cam.add_child(hl)
	_spawned.append(hl)
	_cfg("hounds_run", 40.0)
	await _shot(cam_p, cam_p + S * 0.2, cam_p + N * 30.0 + Vector3(0, 0.55, 0), cam_p + N * 6.0 + Vector3(0, 0.7, 0), 2.6)
	hl.queue_free()
	Sfx.bank_at("hound_bark", cam_p, 6.0, 20.0)
	_shake(0.5, 0.012)
	var sting := AudioStreamPlayer.new()
	sting.stream = load("res://game/audio/the_veil_jumpscare_sting.wav")
	sting.volume_db = -2.0
	add_child(sting)
	sting.play()
	await _hold(0.35)
	_fade(1.0, 0.0)
	await _hold(0.4)
	for h in pack:
		if is_instance_valid(h):
			h.queue_free()


# ------------------------------------------------------------------ 5 the tentacle
func _p5_tentacle() -> void:
	world._atmo().apply_preset(world.night_preset("active"), true)
	_fog(0.006)
	_fade(0.0, 0.0)
	var ground := P.y
	var at := P + N * 6.0 - S * 2.5
	at.y = ground
	var cam_p := at - N * 5.2 + S * 1.2 + Vector3(0, 0.9, 0)
	var tent: Node3D = (load(VeilMeshyNpcs.monster_scene("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn")) as PackedScene).instantiate()
	tent.set("autoplay", "")
	world.add_child(tent)
	_spawned.append(tent)
	var ap := tent.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.stop()
	var to_cam := (cam_p - at) * Vector3(1, 0, 1)
	tent.global_position = at
	tent.rotation.y = atan2(to_cam.x, to_cam.z)
	var poser := VeilTentaclePoser.attach(tent)
	poser.set_all(0.0, 0.0)
	poser.apply()
	var length := poser.tip().distance_to(tent.global_position)
	tent.global_position = Vector3(at.x, ground - length - 0.05, at.z)
	var mound := VeilTentacleMound.make(world, at, 77, 0.12)
	mound.scale = Vector3.ONE * 1.75
	_spawned.append(mound)
	var look := at + Vector3(0, 2.0, 0)
	var tl := SpotLight3D.new()
	tl.spot_range = 40.0
	tl.spot_angle = 35.0
	tl.light_energy = 7.0
	tl.light_color = Color(0.9, 0.85, 0.75)
	cam.add_child(tl)
	_spawned.append(tl)
	_cfg("tentacle_rises", 46.0)
	var rise := func():
		await get_tree().create_timer(0.9).timeout
		world._ground_burst(at)
		var heave := create_tween()
		heave.tween_method(func(k: float): mound.grow(k), 0.12, 0.5, 0.3)
		await get_tree().create_timer(0.35).timeout
		Sfx.play("veil_rumble", at, 3.0, 1.2)
		var up := create_tween()
		up.tween_property(tent, "global_position:y", ground - maxf(length - 3.6, 0.4), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		up.parallel().tween_method(func(k: float): mound.grow(k), 0.5, 1.0, 0.25)
		Sfx.bank_at("te_wet", at + Vector3.UP * 0.5, 3.0, 8.0)
		await up.finished
		# a rear-up, a pause, then the lash across the lens
		var c0 := poser.curl.duplicate()
		var l0 := poser.lean.duplicate()
		var mk := func(from_i: int, lo: float, hi: float) -> PackedFloat32Array:
			var a := PackedFloat32Array()
			for i in poser.bones.size():
				a.append(hi if i >= from_i else lo)
			return a
		var curl_to: PackedFloat32Array = mk.call(3, 0.0, 0.8)
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(func(k: float):
			for i in poser.bones.size():
				poser.curl[i] = lerpf(c0[i], curl_to[i], k)
			poser.apply(), 0.0, 1.0, 0.45)
		await tw.finished
		await get_tree().create_timer(0.3).timeout
		var lean_to: PackedFloat32Array = mk.call(4, -0.06, -0.5)
		var back := create_tween().set_trans(Tween.TRANS_SINE)
		var cl := poser.curl.duplicate()
		var ll := poser.lean.duplicate()
		back.tween_method(func(k: float):
			for i in poser.bones.size():
				poser.curl[i] = lerpf(cl[i], 0.0, k)
				poser.lean[i] = lerpf(ll[i], lean_to[i], k)
			poser.apply(), 0.0, 1.0, 0.35)
		await back.finished
		Sfx.bank_at("te_strike", tent.global_position + Vector3.UP * 2.0, 3.0, 8.0)
		var lash_to: PackedFloat32Array = mk.call(4, 0.0, 0.8)
		var ls := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var ll2 := poser.lean.duplicate()
		ls.tween_method(func(k: float):
			for i in poser.bones.size():
				poser.lean[i] = lerpf(ll2[i], lash_to[i], k)
			poser.apply(), 0.0, 1.0, 0.16)
		await ls.finished
		world._shake(cam, 0.3, 0.05)
	rise.call()
	await _shot(cam_p, cam_p + S * 0.3, look + Vector3(0, -0.5, 0), look + Vector3(0, 1.2, 0), 3.8)
	tl.queue_free()
	_shake(0.4, 0.02)
	_fade(1.0, 0.0)
	await _hold(0.4)
	if is_instance_valid(tent):
		tent.queue_free()


# ------------------------------------------------------------------ 6 taken
func _p6_taken() -> void:
	world._atmo().apply_preset(world.night_preset("approach"), true)
	_fog(0.004, 1.1)
	_fade(0.0, 0.0)
	var lt = world.living
	var officer_p: Dictionary = lt.people.get("Officer", {})
	var body: Node3D = officer_p.get("body") if not officer_p.is_empty() else null
	var ground := P.y
	var spot := P + N * 16.0 - S * 14.0
	spot.y = ground
	spot = lt._ground(spot)
	if body == null or not is_instance_valid(body):
		return
	# the street runs: everybody near turns and bolts, the officer too - he looks back over his shoulder as he goes
	body.visible = true
	body.global_position = spot
	officer_p["state"] = "event"
	officer_p["keep_in_shot"] = true
	var a = officer_p["anim"]
	a.set_process(true)
	a.walk_to([], 0.0)
	a.set_mood("scared")
	var bird := VeilGrimtalon.spawn(world, spot + N * 4.0 + Vector3(0, 50, 0) + S * 30.0, 0.0)
	_spawned.append(bird)
	a.face_towards(bird.global_position)
	a.look_target = bird
	var cam_p := spot + N * 6.0 + S * 6.0 + Vector3(0, 0.9, 0)
	var key := OmniLight3D.new()
	key.light_energy = 3.2
	key.omni_range = 18.0
	key.light_color = Color(0.65, 0.72, 1.0)
	world.add_child(key)
	_spawned.append(key)
	key.global_position = spot + Vector3(0, 5.0, 0)
	var run := func():
		Sfx.play("colossus_call", spot + Vector3(0, 40, 0), 2.0, 1.9)
		await get_tree().create_timer(0.5).timeout
		_people_flee(spot, 3.8, 120.0)
		a.talk(1.2)
		await get_tree().create_timer(0.6).timeout
		a.walk_to([lt._ground(spot + S * 40.0)], 3.6)
		await get_tree().create_timer(0.6).timeout
		var state_cb := func(st: String):
			if st == "grab":
				a.walk_to([], 0.0)
				a.look_target = null
				a.talk(6.0)                                           # arms and head flailing in its grip
				Sfx.play("hurt", body.global_position + Vector3(0, 1.4, 0), 4.0, 0.9)
		await bird.abduct(body, S * 0.3 + N * 0.8, state_cb, -S * 0.2 + N * 0.9, 0.5)
	run.call()
	var tracker := func() -> Vector3:
		if is_instance_valid(key) and body.global_position.y < 6.0:
			key.global_position = body.global_position + Vector3(0, 5.0, 0)
		return body.global_position + Vector3(0, 1.5, 0) if body.global_position.y < 3.0 else bird.global_position
	var cs := SpotLight3D.new()
	cs.spot_range = 70.0
	cs.spot_angle = 34.0
	cs.light_energy = 9.0
	cs.light_color = Color(0.85, 0.9, 1.0)
	cam.add_child(cs)
	_spawned.append(cs)
	_cfg("man_is_taken", 44.0)
	await _shot(cam_p, cam_p + S * 3.0, spot + Vector3(0, 1.6, 0), spot + S * 10.0 + Vector3(0, 4, 0), 6.0, tracker)
	key.queue_free()
	cs.queue_free()
	_fade(1.0, 0.4)
	await _hold(0.5)
	if is_instance_valid(bird):
		bird.queue_free()
	body.visible = false
	a.look_target = null


# ------------------------------------------------------------------ 7 the shelter
func _p7_shelter() -> void:
	world._atmo().apply_preset(world.night_preset("active"), true)
	_fade(0.0, 0.0)
	var m: Node3D = world.market
	for l in m.get_node("Lights").get_children():
		if l is Light3D:
			(l as Light3D).visible = false
	_focus_lock = Vector3(400, 0, 400)                         # nobody walks the aisles
	for k in world.living.people:
		var pb = world.living.people[k].get("body")
		if is_instance_valid(pb):
			(pb as Node3D).visible = false
	world.cashier.visible = false
	# the dark sales floor (the lights are off): a flashlight on the lens, walking the long aisle
	var a_start: Vector3 = m.to_global(Vector3(-4.0, 1.5, 6.9))
	var a_end: Vector3 = m.to_global(Vector3(-4.0, 1.5, 12.6))
	var spot := SpotLight3D.new()
	spot.spot_range = 26.0
	spot.spot_angle = 22.0
	spot.spot_attenuation = 1.6
	spot.spot_angle_attenuation = 2.2
	spot.light_energy = 7.0
	spot.shadow_enabled = true
	cam.add_child(spot)
	_spawned.append(spot)
	Sfx.play_music(Sfx.MUSIC_GAMEPLAY, true, -8.0, 1.0, "")
	_cfg("flashlight_aisle", 58.0)
	await _shot(a_start, a_end, m.to_global(Vector3(-4.0, 1.2, 14.5)), m.to_global(Vector3(-4.6, 0.9, 15.5)), 5.0)
	spot.queue_free()
	_focus_lock = Vector3.INF


# ------------------------------------------------------------------ 8 title
func _p8_title() -> void:
	_fade(1.0, 0.4)
	await _hold(1.2)
	Sfx.play("colossus_call", cam.global_position, -6.0, 0.55)
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.text = "THE VEIL"
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 1.6)
	tw.tween_interval(2.2)
	await tw.finished
	_card.offset_top = 170.0
	_card.offset_bottom = 170.0
	_card_show("SURVIVE THE NIGHT.", 2.0)
	await _hold(2.8)
	var out := create_tween()
	out.tween_property(_title, "modulate:a", 0.0, 1.2)
	await out.finished
	await _hold(0.6)
