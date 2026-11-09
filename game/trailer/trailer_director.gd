extends CanvasLayer
class_name VeilTrailerDirector
## THE VEIL - the trailer, "The Change", played live in the game for recording (trailer mode: F12, or F11 -> Play
## the trailer). One world, no loading in between; the HUD hidden; nothing is ever saved (Game.no_save); at the end
## (or Esc) back to the main menu. Real game things only - a few moments are staged for the camera.
##   1 Ordinary   the car into the supermarket lot (radio); the groceries; the clerk; the game shelves; Eddie at his
##                counter. "Friday night. One last stop."
##   2 Falling    the shop's music fades; Eddie stops and looks past the camera; his view: the mist at the end of the
##                street; the lights stutter
##   3 Shape      low on the street: something enormous crosses the gap between two buildings, in the mist. Cut.
##   4 Run        the music hits: Eddie and Marcus sprint for the supermarket; the street bursts behind them; the doors
##                slide shut
##   5 Survive    in the dark store: a flashlight on the shelves; pallets shoved against a door; Marcus looking back;
##                something just past the light; a Hound slams the glass; the night's beds on the office floor.
##                "Find supplies." "Hold the doors." "Keep them alive."
##   6 Morning    the town after: a house stepped on, the protagonist's own home with its corner crushed
##   7 End        black, silence, a far-off call. THE VEIL.

signal finished

const RADIO := "res://game/audio/radio/midnight_drive_lofi.wav"
const STORE_MUSIC := "res://game/audio/radio/neon_hearts_pop.wav"
const P_EVENING := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Atmosphere_Presets/LGT_Ordinary_Evening.tres"
const P_APPROACH := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Atmosphere_Presets/STATE_VEIL_APPROACHING.tres"
const P_MARKET := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Atmosphere_Presets/LGT_Empty_Supermarket.tres"
const P_MORNING := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Atmosphere_Presets/LGT_Mist_Roadway.tres"
const COLOSSUS := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Colossus.tscn"
const TENTACLE := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn"
const SKITTER := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const HOUND := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const PALLETS := "res://THE_VEIL_ASSETS_V2/04_Commercial/Shared_Props/COM_PalletStack.glb"
const BLANKET := "res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_Blanket_Folded.glb"
const PILLOW := "res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_Pillow.glb"
const CARDBOARD := "res://THE_VEIL_ASSETS_V2/Materials_Godot/Furniture/M_Furn_Cardboard.tres"
const MIST_SHADER := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Fog/veil_mist_boundary.gdshader"
const MIST_NOISE := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Textures/T_Veil_MistNoise.png"

var world: Node
var cam: Camera3D
var aborted := false
var report := {"shots": 0, "segments": []}
var _black: ColorRect
var _card: Label
var _title: Label
var _spawned: Array = []
var _players: Array = []


## Start the trailer: a fresh world (no wake-up, no saving), then the director takes over.
static func start(tree: SceneTree) -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	Game.new_game()
	for f in ["intro_seen", "has_keys", "fridge_checked", "left_house", "entered_car", "arrival_shot"]:
		Game.flags[f] = true
	Game.no_save = true
	Game.set_meta("trailer_run", true)
	var d = (load("res://game/trailer/trailer_director.gd") as GDScript).new()
	d.name = "TrailerDirector"
	tree.root.add_child(d)
	tree.change_scene_to_file("res://game/scenes/World.tscn")
	d.run.call_deferred()


func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_card = _label(26)
	_title = _label(64)


func _label(size: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f = VeilUI.font()
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.modulate.a = 0.0
	add_child(l)
	return l


func run() -> void:
	# the world comes up behind the black
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
	for seg in [_seg_ordinary, _seg_falling, _seg_shape, _seg_run, _seg_survive, _seg_morning, _seg_end]:
		if aborted or not is_instance_valid(world):
			break
		await seg.call()
	_finish()


func _setup() -> void:
	var p: Node3D = world.player
	p.set("controls_enabled", false)
	p.set("look_enabled", false)
	p.visible = false
	p.set_physics_process(false)
	cam = Camera3D.new()
	cam.name = "TrailerShotCam"
	cam.fov = 55.0
	cam.far = 700.0
	world.add_child(cam)
	cam.current = true
	var tm = get_tree().root.get_node_or_null("TrailerMode")
	if tm and tm.has_method("set_clean") and not tm.clean:
		tm.set_clean(true)
	else:
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if n != self and n != tm:
				(n as CanvasLayer).visible = false
	_preset(P_EVENING, true)


# ------------------------------------------------------------------ 1 ordinary
func _seg_ordinary() -> void:
	(report["segments"] as Array).append("ordinary")
	var car: Node3D = world.sedan
	car.set_physics_process(false)
	var radio := _sound3d(RADIO, car, -6.0, 22.0)
	# the car along the main street and into the supermarket lot
	var path := [Vector3(-26, 0.12, -1.8), Vector3(8, 0.12, -1.8), Vector3(16, 0.12, -6.5), Vector3(19, 0.12, -16.0)]
	_drive(car, path, 6.0)
	_fade(0.0, 1.2)
	await _shot(Vector3(28, 1.4, -21), Vector3(27, 1.5, -20), Vector3(0, 0.8, -2), Vector3(19, 0.6, -15), 6.0, func(): return car.global_position + Vector3(0, 0.6, 0))
	if radio:
		var tw := create_tween()
		tw.tween_property(radio, "volume_db", -40.0, 2.0)
	# groceries: along a shelf of cans, then the clerk at his till
	var aisle := _shelf("Merch_can_", world.market)
	if not aisle.is_empty():
		var c: Vector3 = aisle[0]
		var al: Vector3 = aisle[1]
		var nr: Vector3 = aisle[2]
		await _shot(c + nr * 1.5 - al * 1.2 + Vector3(0, 0.3, 0), c + nr * 1.1 + al * 0.6 + Vector3(0, 0.1, 0), c - al * 0.5, c + al * 0.8, 3.4)
	else:
		_skip("aisle")
	if world.get("cashier"):
		var ch: Node3D = world.cashier
		var head := ch.global_position + Vector3(0, 1.55, 0)
		var fw: Vector3 = world.animators["Cashier"].world_forward() if world.animators.has("Cashier") else Vector3.FORWARD
		await _shot(head + fw * 2.4 + Vector3(0.6, 0.1, 0), head + fw * 2.0 + Vector3(0.3, 0.05, 0), head, head, 2.6)
	else:
		_skip("cashier")
	# the game shop: the shelves, then Eddie at his counter
	var music := _sound3d(STORE_MUSIC, world.game_shop, -12.0, 14.0)
	_players.append(music)
	var gs := _shelf("Merch_game_", world.game_shop)
	if not gs.is_empty():
		var c2: Vector3 = gs[0]
		var al2: Vector3 = gs[1]
		var nr2: Vector3 = gs[2]
		_card_show("Friday night.\nOne last stop.", 3.6)
		await _shot(c2 + nr2 * 1.7 - al2 * 1.3 + Vector3(0, 0.15, 0), c2 + nr2 * 1.45 + al2 * 1.1, c2 - al2 * 0.7, c2 + al2 * 0.8, 4.4)
	else:
		_skip("game_shelf")
	await _eddie_shot(3.0, false)


func _eddie_head() -> Vector3:
	return world.eddie.global_position + Vector3(0, 1.62, 0)


func _eddie_fwd() -> Vector3:
	var f: Vector3 = world.animators["Eddie"].world_forward() if world.animators.has("Eddie") else Vector3.FORWARD
	return f


func _eddie_shot(secs: float, close: bool) -> void:
	if world.get("eddie") == null:
		_skip("eddie")
		return
	var h := _eddie_head()
	var f := _eddie_fwd()
	var d := 1.2 if close else 2.6
	await _shot(h + f * (d + 0.3) + Vector3(0.4, 0.0, 0), h + f * d + Vector3(0.15, -0.02, 0), h, h, secs)


# ------------------------------------------------------------------ 2 the sound falls away
func _seg_falling() -> void:
	(report["segments"] as Array).append("falling")
	for pl in _players:
		if is_instance_valid(pl):
			var tw := create_tween()
			tw.tween_property(pl, "volume_db", -60.0, 3.0)
	Sfx.play("veil_rumble", world.game_shop.global_position + Vector3(0, 2, 0), -10.0)
	# Eddie stops; he looks past us at the window
	var door: Vector3 = (world.game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var out := ((door - (world.game_shop.get_node("Doorways/Entrance_Inside") as Node3D).global_position) * Vector3(1, 0, 1)).normalized()
	if world.animators.has("Eddie"):
		world.get_tree().create_timer(1.2).timeout.connect(func():
			world.animators["Eddie"].set_mood("scared")
			world.animators["Eddie"].face_towards(door + out * 20.0))
	await _eddie_shot(3.4, true)
	# his view: out through the glass, the far end of the street - the mist coming in
	var street := Vector3(1, 0, 0)
	var far := door + out * 6.0 + street * 120.0
	_mist_wall(far, -street, 3)
	_preset(P_APPROACH, false)
	world._stutter_lights(world.game_shop)
	var eye := _eddie_head()
	await _shot(eye, eye + (door - eye).normalized() * 0.6, door + out * 4.0 + street * 30.0, far + Vector3(0, 6, 0), 4.6)


# ------------------------------------------------------------------ 3 the shape between the buildings
func _seg_shape() -> void:
	(report["segments"] as Array).append("shape")
	var low := Vector3(62.0, 1.2, 1.5)
	var gap := Vector3(62.0, 30.0, 70.0)
	var col := _spawn(COLOSSUS, Vector3(30.0, 0.0, 105.0)) as Node3D
	if col:
		var model := col.get_node_or_null("Model") as Node3D
		if model:
			model.scale = Vector3.ONE * 6.0
		VeilCreatureLook.apply_colossus(col, 0.0)
		col.rotation.y = PI * 0.5
		var ap := col.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("Walk_Heavy"):
			ap.get_animation("Walk_Heavy").loop_mode = Animation.LOOP_LINEAR
			ap.play("Walk_Heavy")
			ap.speed_scale = 0.8
		var tw := create_tween()
		tw.tween_property(col, "global_position", Vector3(96.0, 0.0, 105.0), 4.0)
	Sfx.play("colossus_step", gap + Vector3(0, -20, 30), 4.0, 0.6)
	await _shot(low, low + Vector3(0, 0.1, 0.3), gap, gap + Vector3(4, 0, 0), 3.6)
	_fade(1.0, 0.0)                                          # hard cut
	if is_instance_valid(col):
		col.queue_free()
	await _hold(0.7)


# ------------------------------------------------------------------ 4 run
func _seg_run() -> void:
	(report["segments"] as Array).append("run")
	Sfx.play_music(Sfx.MUSIC_COLOSSUS, false, -3.0, 0.1)
	if world.get("marcus") == null and world.has_method("_p3_place_marcus_in_shop"):
		world._p3_place_marcus_in_shop()
	var sd: Vector3 = (world.game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var md: Vector3 = (world.market.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var runners: Array = []
	for nm in ["Eddie", "Marcus"]:
		var body = world.get(nm.to_lower())
		if body and world.animators.has(nm):
			var b := body as Node3D
			if b.get_parent() != world:
				b.reparent(world, true)
			b.visible = true
			b.global_position = sd + Vector3(1.5 if nm == "Marcus" else 0.0, 0.0, -1.0)
			world.animators[nm].set_mood("scared")
			world.animators[nm].walk_to([sd + Vector3(4, 0, -8), md + Vector3(0.6 if nm == "Marcus" else -0.6, 0, 1.5)], 4.6 if nm == "Eddie" else 4.2)
			runners.append(b)
	_preset(P_APPROACH, true)
	_fade(0.0, 0.0)
	var camp := sd + Vector3(9.0, 1.1, -9.0)
	world.get_tree().create_timer(2.2).timeout.connect(func(): _burst(sd + Vector3(3.0, 0, -4.0)))
	await _shot(camp, camp + Vector3(1.0, 0.1, -1.5), sd + Vector3(0, 1.2, 0), md + Vector3(0, 1.0, 0), 5.0,
		func(): return (runners[0] as Node3D).global_position + Vector3(0, 1.2, 0) if not runners.is_empty() else md)
	# inside: the doors slide shut
	var inside: Vector3 = world.market.global_transform * Vector3(0.6, 1.5, 5.0)
	var doors: Vector3 = world.market.global_transform * Vector3(0, 1.1, 0.0)
	world._doors_powered = true
	world._auto_open = false
	world._set_auto_doors(true)
	world.get_tree().create_timer(0.9).timeout.connect(func():
		world._auto_open = true
		for d in world._auto_doors:
			var tw := create_tween()
			tw.tween_property(d[0], "transform", d[1], 0.5))
	await _shot(inside, inside + Vector3(0, 0, -0.5), doors, doors, 2.4)


func _burst(at: Vector3) -> void:
	VeilTentacleMound.make(world, at, 913, 1.0)
	var t := _spawn(TENTACLE, at + Vector3(0, -6.0, 0)) as Node3D
	if t == null:
		return
	t.set("autoplay", "")
	t.set_process(false)
	var mats = t.get("_mats")
	if mats is Array:
		for m in mats:
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("mist_level", -50.0)
				(m as ShaderMaterial).set_shader_parameter("fade_height", 0.05)
	t.scale = Vector3.ONE * 0.9
	var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "global_position", at, 0.6)
	Sfx.play("tentacle_hiss", at + Vector3(0, 1, 0), 4.0, 0.8)


# ------------------------------------------------------------------ 5 survive (the store at night)
func _seg_survive() -> void:
	(report["segments"] as Array).append("survive")
	_fade(1.0, 0.0)
	world._market_blackout()
	_preset(P_MARKET, true)
	var torch := SpotLight3D.new()
	torch.spot_range = 20.0
	torch.spot_angle = 24.0
	torch.light_energy = 3.2
	torch.light_color = Color(1.0, 0.95, 0.85)
	torch.shadow_enabled = true
	cam.add_child(torch)
	_fade(0.0, 0.5)
	var M: Transform3D = world.market.global_transform
	# a flashlight searching dark shelves
	var shelf := _shelf("Merch_box_", world.market)
	if not shelf.is_empty():
		var c: Vector3 = shelf[0]
		var al: Vector3 = shelf[1]
		var nr: Vector3 = shelf[2]
		await _shot(c + nr * 2.2 - al * 0.6 + Vector3(0, 0.2, 0), c + nr * 2.0 + al * 0.4 + Vector3(0, 0.1, 0), c - al * 1.6 + Vector3(0, -0.2, 0), c + al * 1.4, 3.4)
	else:
		_skip("dark_shelf")
	_card_show("Find supplies.", 1.6)
	await _hold(0.4)
	# pallets shoved against a door
	var pal := _spawn(PALLETS, M * Vector3(8.0, 0.04, 14.6)) as Node3D
	if pal:
		pal.global_basis = M.basis
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.5)
		tw.tween_property(pal, "global_position", M * Vector3(8.0, 0.04, 16.2), 0.8)
		world.get_tree().create_timer(1.3).timeout.connect(func(): Sfx.play("door_close", M * Vector3(8, 1, 16.6), 2.0, 0.5))
	await _shot(M * Vector3(8.6, 0.9, 12.4), M * Vector3(8.3, 0.85, 12.9), M * Vector3(8.0, 0.6, 16.5), M * Vector3(8.0, 0.6, 16.8), 2.6)
	_card_show("Hold the doors.", 1.6)
	await _hold(0.4)
	# a survivor looking back; something just past the light
	var marcus = world.get("marcus")
	if marcus and world.animators.has("Marcus"):
		var mb := marcus as Node3D
		if mb.get_parent() != world:
			mb.reparent(world, true)
		mb.global_position = M * Vector3(-1.0, 0.04, 10.5)
		mb.global_rotation.y = world.market.global_rotation.y
		world.animators["Marcus"].walk_to([])
		world.animators["Marcus"].hold_facing = false
		world.get_tree().create_timer(0.8).timeout.connect(func(): world.animators["Marcus"].face_towards(cam.global_position))
		var mh := mb.global_position + Vector3(0, 1.6, 0)
		await _shot(M * Vector3(-1.0, 1.6, 7.6), M * Vector3(-1.0, 1.58, 8.0), mh, mh, 2.8)
	else:
		_skip("marcus")
	var sk := _spawn(SKITTER, M * Vector3(-7.0, 0.04, 15.0)) as Node3D
	if sk:
		VeilCreatureLook.apply_skitter(sk, sk.global_position.y)
		VeilCreatureLook.skitter_anim(sk, "scuttle", 8.0)
		var d2 := M.basis * Vector3(1, 0, 0)
		sk.rotation.y = atan2(d2.x, d2.z)
		var ts := create_tween()
		ts.tween_interval(0.7)
		ts.tween_property(sk, "global_position", M * Vector3(5.0, 0.04, 15.0), 0.8)
		world.get_tree().create_timer(0.8).timeout.connect(func(): Sfx.bank_at("sk_hiss", sk.global_position, -2.0, 10.0))
	await _shot(M * Vector3(-1.0, 1.5, 9.0), M * Vector3(-1.0, 1.5, 9.2), M * Vector3(-3.0, 0.8, 15.0), M * Vector3(1.0, 0.7, 15.0), 2.6)
	# the Hound slams the front glass
	var h := _spawn(HOUND, M * Vector3(-14.0, 0.04, -1.6)) as Node3D
	if h:
		var ap := h.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for a in ap.get_animation_list():
				if String(a).contains("Run"):
					ap.play(a)
					break
		var dir := M.basis * Vector3(1, 0, 0)
		h.rotation.y = atan2(dir.x, dir.z)
		var th := create_tween()
		th.tween_property(h, "global_position", M * Vector3(-1.0, 0.04, -1.2), 1.1)
		world.get_tree().create_timer(1.1).timeout.connect(func():
			Sfx.play("door_close", M * Vector3(0, 1.2, 0), 6.0, 0.45)
			Sfx.bank_at("hound_bark", M * Vector3(0, 1.2, -1), 2.0, 14.0)
			_shake(0.4, 0.06))
	await _shot(M * Vector3(1.2, 1.45, 4.0), M * Vector3(1.0, 1.45, 3.6), M * Vector3(-6.0, 1.0, -0.5), M * Vector3(-1.0, 1.0, -0.5), 2.8)
	# the night's beds on the office floor
	var bed_at: Vector3 = M * Vector3(-17.95, 0.04, 15.35)
	_bedroll(bed_at, world.market.global_rotation.y + PI * 0.5)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 0.9
	lamp.omni_range = 4.0
	world.add_child(lamp)
	lamp.global_position = bed_at + Vector3(0.6, 0.3, 0.6)
	_spawned.append(lamp)
	torch.visible = false
	_card_show("Keep them alive.", 2.2)
	await _shot(bed_at + Vector3(1.6, 1.6, 0.4), bed_at + Vector3(1.2, 1.3, 0.3), bed_at, bed_at, 3.2)
	torch.queue_free()
	Sfx.stop_music(2.0)
	_fade(1.0, 0.8)
	await _hold(1.0)


func _bedroll(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "Trailer_Bed"
	world.add_child(root)
	root.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	_spawned.append(root)
	var cm: Material = load(CARDBOARD) if ResourceLoader.exists(CARDBOARD) else null
	for k in 2:
		var s := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, 0.012, 0.82)
		bm.material = cm
		s.mesh = bm
		s.position = Vector3(0.02 * (1 - 2 * k), 0.006, (k - 0.5) * 0.8)
		root.add_child(s)
	if ResourceLoader.exists(BLANKET):
		var bl := (load(BLANKET) as PackedScene).instantiate() as Node3D
		bl.position = Vector3(0.0, 0.015, 0.35)
		root.add_child(bl)
	if ResourceLoader.exists(PILLOW):
		var pl := (load(PILLOW) as PackedScene).instantiate() as Node3D
		pl.position = Vector3(0.0, 0.012, -0.58)
		root.add_child(pl)


# ------------------------------------------------------------------ 6 the morning after
func _seg_morning() -> void:
	(report["segments"] as Array).append("morning")
	Game.flags["p3_two_hours_later"] = true                 # (no_save: nothing of this is kept)
	var td = world.get("town_destruction")
	if td and not td.applied:
		td.apply()
	_preset(P_MORNING, true)
	world.living.focus_override = Vector3(25, 0, -91)
	_fade(0.0, 1.4)
	var hs: Node3D = world.get_node_or_null("Residential/Houses/HOUSE_14")
	if hs:
		var c: Vector3 = hs.global_position + Vector3(0, 3, 6)
		await _shot(c + Vector3(16, 6, -14), c + Vector3(8, 4, -16), c, c + Vector3(-1, -1, 0), 4.4)
	else:
		_skip("stepped_house")
	var home: Node3D = world.get("home")
	if home:
		var hc: Vector3 = home.global_transform * Vector3(-4.0, 2.4, 9.0)
		var from: Vector3 = home.global_transform * Vector3(-12.0, 3.4, 20.0)
		await _shot(from, from.lerp(hc, 0.35), hc, hc, 4.6)
	_fade(1.0, 1.0)
	await _hold(1.2)


# ------------------------------------------------------------------ 7 the end
func _seg_end() -> void:
	(report["segments"] as Array).append("end")
	await _hold(1.6)                                          # silence
	if not aborted:
		Sfx.play("colossus_call", world.player.global_position + Vector3(120, 30, 0), -6.0, 0.5)
	await _hold(1.8)
	if not aborted:
		_title.text = "THE VEIL"
		var tw := create_tween()
		tw.tween_property(_title, "modulate:a", 1.0, 1.2)
		tw.tween_interval(3.2)
		tw.tween_property(_title, "modulate:a", 0.0, 1.0)
		await tw.finished
	report["done"] = true


func _finish() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	Engine.time_scale = 1.0
	Sfx.stop_music(0.2)
	Game.remove_meta("trailer_run")
	Game.no_save = false
	finished.emit()
	if get_tree().root.get_node_or_null("TrailerDirector") == self and not Game.has_meta("trailer_test"):
		get_tree().change_scene_to_file("res://game/scenes/MainMenu.tscn")
		queue_free()


# ------------------------------------------------------------------ helpers
func _process(_d: float) -> void:
	if Input.is_action_just_pressed("pause"):
		aborted = true


func _shot(a: Vector3, b: Vector3, la: Vector3, lb: Vector3, secs: float, follow := Callable()) -> void:
	if aborted or cam == null:
		return
	report["shots"] = int(report["shots"]) + 1
	var t := 0.0
	while t < secs and not aborted:
		var k := t / secs
		k = k * k * (3.0 - 2.0 * k)
		var p := a.lerp(b, k)
		var look: Vector3 = follow.call() if follow.is_valid() else la.lerp(lb, k)
		if (look - p).length() > 0.05:
			cam.global_transform = Transform3D(Basis.looking_at(look - p, Vector3.UP), p)
		world.living.focus_override = p
		await get_tree().process_frame
		t += get_process_delta_time()


func _skip(what: String) -> void:
	if not report.has("skipped"):
		report["skipped"] = []
	(report["skipped"] as Array).append(what)


func _hold(secs: float) -> void:
	var t := 0.0
	while t < secs and not aborted:
		await get_tree().process_frame
		t += get_process_delta_time()


func _fade(alpha: float, secs: float) -> void:
	if secs <= 0.0:
		_black.color.a = alpha
		return
	var tw := create_tween()
	tw.tween_property(_black, "color:a", alpha, secs)


func _card_show(text: String, hold: float) -> void:
	_card.text = text
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.4)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.5)


func _shake(secs: float, amount: float) -> void:
	var t := 0.0
	while t < secs and is_instance_valid(cam):
		cam.h_offset = randf_range(-amount, amount)
		cam.v_offset = randf_range(-amount, amount)
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(cam):
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _preset(path: String, instant: bool) -> void:
	if ResourceLoader.exists(path) and world.has_method("_atmo"):
		world._atmo().apply_preset(load(path), instant)


func _spawn(path: String, at: Vector3) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate()
	world.add_child(n)
	if n is Node3D:
		(n as Node3D).global_position = at
	for co in n.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0
		(co as CollisionObject3D).collision_mask = 0
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 0
		(n as CollisionObject3D).collision_mask = 0
	n.set_physics_process(false)
	_spawned.append(n)
	return n


func _sound3d(path: String, parent: Node3D, db: float, unit: float) -> AudioStreamPlayer3D:
	if not ResourceLoader.exists(path) or parent == null:
		return null
	var a := AudioStreamPlayer3D.new()
	a.stream = load(path)
	a.volume_db = db
	a.unit_size = unit
	parent.add_child(a)
	a.play()
	_spawned.append(a)
	return a


## A car driven along `path` over `secs` (its body moved, nose first; a look only).
func _drive(car: Node3D, path: Array, secs: float) -> void:
	var lengths: Array = [0.0]
	for i in range(1, path.size()):
		lengths.append(float(lengths[-1]) + (path[i] as Vector3).distance_to(path[i - 1]))
	var total: float = lengths[-1]
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(k: float):
		var s := k * total
		var i := 1
		while i < path.size() - 1 and float(lengths[i]) < s:
			i += 1
		var seg: float = float(lengths[i]) - float(lengths[i - 1])
		var u: float = (s - float(lengths[i - 1])) / maxf(seg, 0.01)
		var p: Vector3 = (path[i - 1] as Vector3).lerp(path[i], clampf(u, 0.0, 1.0))
		var d: Vector3 = (path[i] as Vector3) - (path[i - 1] as Vector3)
		if is_instance_valid(car):
			car.global_transform = Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.z)), p), 0.0, 1.0, secs)


func _shelf(prefix: String, inside: Node3D) -> Array:
	var merch = world.get("shop_merch") if inside == world.game_shop else world.get("market_merch")
	return shelf_of(merch, prefix.trim_prefix("Merch_"), inside)


## A shelf's merchandise: [centre, along it, out into the aisle] - from the store's own layout data (the positions
## the store's merchandise is built from; reading them back from the renderer is not reliable).
static func shelf_of(merch: Node, variant_prefix: String, store: Node3D) -> Array:
	if merch == null or not (merch is Node3D) or not merch.has_method("_layout"):
		return []
	var lay: Dictionary = merch._layout().get(String(merch.get("store_key")), {})
	var pts: Array = []
	var stat: Dictionary = lay.get("static", {})
	for v in stat:
		if not String(v).begins_with(variant_prefix):
			continue
		for r in stat[v]:
			pts.append((merch as Node3D).global_transform * Vector3(float(r[0]), float(r[1]), float(r[2])))
		if pts.size() > 60:
			break
	if pts.size() < 4:
		return []
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var far: Vector3 = pts[0]
	for p in pts:
		if (p as Vector3).distance_to(c) > far.distance_to(c):
			far = p
	var along := ((far - c) * Vector3(1, 0, 1))
	if along.length() < 0.2:
		return []
	along = along.normalized()
	var nrm := along.cross(Vector3.UP).normalized()
	var room: Vector3 = store.global_transform * Vector3(0, 1.5, 6.0)
	if nrm.dot(room - c) < 0.0:
		nrm = -nrm
	return [c, along, nrm]


## The Veil at the end of the street: layered curtains of the game's mist, creeping in.
func _mist_wall(at: Vector3, toward: Vector3, layers: int) -> void:
	var sh := load(MIST_SHADER) as Shader
	if sh == null:
		return
	var face := Basis.looking_at(-toward, Vector3.UP)
	for i in layers:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(260.0, 70.0 + i * 20.0)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("noise_tex", load(MIST_NOISE))
		mat.set_shader_parameter("curtain_height", 70.0 + i * 20.0)
		mat.set_shader_parameter("density", 0.55 + i * 0.18)
		mat.set_shader_parameter("base_color", Color(0.42, 0.45, 0.48))
		mat.set_shader_parameter("edge_color", Color(0.2, 0.22, 0.26))
		qm.material = mat
		mi.mesh = qm
		world.add_child(mi)
		mi.global_transform = Transform3D(face, at - toward * (i * 18.0) + Vector3(0, (70.0 + i * 20.0) * 0.5 - 2.0, 0))
		_spawned.append(mi)
		var tw := create_tween()
		tw.tween_property(mi, "global_position", mi.global_position + toward * 40.0, 14.0)
