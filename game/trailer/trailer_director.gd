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
var report := {"shots": 0, "segments": [], "shot_names": [], "clip": [], "clip_fixed": [], "clip_hits": {}, "creature_mats": {}, "lens_props": {}}
var _last_hit := ""
const CLEARANCE := 0.2
var _next_name := ""
var _next_fov := 48.0
var _watched: Array = []
var _focus_lock := Vector3.INF
var _props: Array = []
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
	_card = _label(34)
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
	if tm:
		for k in ["_help", "_status"]:
			var l = tm.get(k)
			if l is CanvasItem:
				(l as CanvasItem).visible = false
	_preset(P_EVENING, true)
	# the game's own town destruction (all 36 houses, collision for every piece of rubble: seconds of work) must never
	# start during the trailer - only the two filmed houses are swapped, for the look (see _seg_morning)
	var td = world.get("town_destruction")
	if td:
		td.applied = true


# ------------------------------------------------------------------ 1 ordinary
func _seg_ordinary() -> void:
	(report["segments"] as Array).append("ordinary")
	var car: Node3D = world.sedan
	car.set_physics_process(false)
	var radio := _sound3d(RADIO, car, -6.0, 22.0)
	# the car along the main street and into the supermarket lot: seen from the lot's sidewalk, eye height, the
	# car coming on front-left three-quarters and turning in left to right (the camera pans with it, < 35 deg)
	var path := [Vector3(-14, 0.12, -1.8), Vector3(27.5, 0.12, -1.8), Vector3(32.0, 0.12, -6.0), Vector3(32.0, 0.12, -14.0)]
	var driver := _driver(car)
	report["car_path_hits"] = _car_path_hits(car, path)
	_drive(car, path, 6.0)
	_fade(0.0, 1.2)
	_cfg("1_car_arrival", 46.0)
	await _shot(Vector3(38.5, 1.55, -15.5), Vector3(38.2, 1.55, -15.2), Vector3(0, 0.8, -2), Vector3(32, 0.6, -13), 6.0,
		func(): return car.global_position.lerp(Vector3(32, 0.7, -14), 0.2) + Vector3(0, 0.7, 0))
	if radio:
		var tw := create_tween()
		tw.tween_property(radio, "volume_db", -40.0, 2.0)
	if is_instance_valid(driver):
		driver.visible = false
	# groceries: a slow track along the cans, 0.9 m off the shelf at 1.35 m, angled 20 deg onto the goods
	var aisle := _shelf("Merch_can_", world.market)
	if not aisle.is_empty():
		var c: Vector3 = aisle[0]
		var al: Vector3 = aisle[1]
		var nr: Vector3 = aisle[2]
		var y0: float = world.market.global_position.y
		var p0 := Vector3(c.x, y0 + 1.35, c.z) + nr * _aisle_d(Vector3(c.x, y0 + 1.35, c.z), nr, al, -0.75, 0.65, [1.0, 0.9, 0.8]) - al * 0.75
		var view := (-nr).rotated(Vector3.UP, 0.0) * cos(deg_to_rad(20.0)) + al * sin(deg_to_rad(20.0))
		var drop := Vector3(0, -0.25, 0)
		_cfg("2_groceries", 44.0)
		await _shot(p0, p0 + al * 1.4, p0 + view * 3.0 + drop, p0 + al * 1.4 + view * 3.0 + drop, 3.4)
	else:
		_skip("aisle")
	# the clerk at his till, three-quarters from the customer's side; he minds the register, not us
	if world.get("cashier"):
		var ch: Node3D = world.cashier
		var head := ch.global_position + Vector3(0, 1.55, 0)
		var fw: Vector3 = world.animators["Cashier"].world_forward() if world.animators.has("Cashier") else Vector3.FORWARD
		var till: Vector3 = world.market.to_global(Vector3(-4.1, 1.0, 4.0))
		if world.animators.has("Cashier"):
			world.animators["Cashier"].look_target = _mark(till + Vector3(0, -0.05, 0))
		var best := _vantage(ch, head, fw, [35.0, -35.0, 30.0, -30.0, 40.0, -40.0, 20.0, -20.0], [2.3, 2.0, 1.7], -0.1)
		report["clerk_seen"] = best != Vector3.INF
		if best == Vector3.INF:
			best = head + fw * 1.8
		var focus := head.lerp(till, 0.3)
		_cfg("3_clerk", 44.0)
		await _shot(best, best + (focus - best).normalized() * 0.3, focus, focus + Vector3(0, -0.03, 0), 2.6)
	else:
		_skip("cashier")
	# the game shop: along the aisle toward the horror game, it sits in the right third, the card in the left
	var music := _sound3d(STORE_MUSIC, world.game_shop, -12.0, 14.0)
	_players.append(music)
	var gs := _shelf("Merch_game_", world.game_shop)
	if not gs.is_empty():
		var c2: Vector3 = gs[0]
		var al2: Vector3 = gs[1]
		var nr2: Vector3 = gs[2]
		var y1: float = world.game_shop.global_position.y
		var feat := c2 + al2 * minf(0.8, (float(gs[3]) if gs.size() > 3 else 1.0) * 0.6)
		var gd := _aisle_d(Vector3(c2.x, y1 + 1.45, c2.z), nr2, al2, -1.8, -0.5, [1.3, 1.2, 1.1, 1.0, 0.9, 0.8])
		var s0 := Vector3(c2.x, y1 + 1.45, c2.z) + nr2 * gd - al2 * 1.8
		var s1 := Vector3(c2.x, y1 + 1.42, c2.z) + nr2 * (gd - 0.08) - al2 * 0.5
		# aim a little left of the game, so it sits a third in from the right edge
		var aim := func(from: Vector3) -> Vector3:
			var d := (feat - from)
			var right := d.cross(Vector3.UP).normalized()
			return feat - right * d.length() * tan(deg_to_rad(_next_fov_h(46.0) / 6.0))
		_card_show("Friday night.\nOne last stop.", 3.6, true)
		_cfg("4_game_shelves", 46.0)
		await _shot(s0, s1, aim.call(s0), aim.call(s1), 4.4)
	else:
		_skip("game_shelf")
	await _eddie_shot(3.0, false)


## The protagonist at the wheel (the game's own model, seated on the car's driver marker, facing the windscreen).
func _driver(car: Node3D) -> Node3D:
	var seat := car.find_child("Marker_Seat_Driver", true, false) as Node3D
	if seat == null or not world.has_method("_spawn_npc"):
		return null
	var body: Node3D = world._spawn_npc(load(world.PROTAG_PATH), load(world.PROTAG_FACE_PATH), world, seat.global_position, 0.0, "Trailer_Driver")
	if body is CollisionObject3D:
		(body as CollisionObject3D).collision_layer = 0
		(body as CollisionObject3D).collision_mask = 0
	body.reparent(seat, false)
	body.global_transform = Transform3D(car.global_basis, seat.global_position - Vector3(0, 0.51, 0))
	var an = world.animators["Trailer_Driver"]
	preload("res://game/world/survivors.gd").face_forward(body, an, car)
	an.walk_to([])
	an.hold_facing = true
	an.set_seated(true, 0.45)
	_spawned.append(body)
	report["driver"] = true
	return body


## The car's own collision swept along the drive (lifted off the road a little, so kerbs and the ground don't count):
## anything solid it would pass through.
func _car_path_hits(car: Node3D, path: Array) -> Array:
	var hits: Array = []
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for co in car.find_children("*", "CollisionObject3D", true, false):
		ex.append((co as CollisionObject3D).get_rid())
	if car is CollisionObject3D:
		ex.append((car as CollisionObject3D).get_rid())
	var shapes := car.find_children("*", "CollisionShape3D", true, false)
	var inv := car.global_transform.affine_inverse()
	var lengths: Array = [0.0]
	for i in range(1, path.size()):
		lengths.append(float(lengths[-1]) + (path[i] as Vector3).distance_to(path[i - 1]))
	var total: float = lengths[-1]
	for k in 80:
		var sd := total * k / 79.0
		var i := 1
		while i < path.size() - 1 and float(lengths[i]) < sd:
			i += 1
		var u := (sd - float(lengths[i - 1])) / maxf(float(lengths[i]) - float(lengths[i - 1]), 0.01)
		var at: Vector3 = (path[i - 1] as Vector3).lerp(path[i], clampf(u, 0.0, 1.0)) + Vector3(0, 0.3, 0)
		var d: Vector3 = (path[i] as Vector3) - (path[i - 1] as Vector3)
		var xf := Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.z)), at)
		for cs in shapes:
			if (cs as CollisionShape3D).shape == null or (cs as CollisionShape3D).disabled:
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = (cs as CollisionShape3D).shape
			q.transform = xf * (inv * (cs as CollisionShape3D).global_transform)
			q.collision_mask = 1
			q.exclude = ex
			for h in space.intersect_shape(q, 4):
				var co = h.get("collider")
				var nm := str(co.get_path()) if co is Node else "?"
				if not hits.has(nm):
					hits.append(nm)
	return hits


## A camera spot looking at `subject` (an actor; `aim` its head): around its facing `fwd` at the given angles and
## distances, the first that is clear of the set and sees the head and chest with nothing solid in between.
## Vector3.INF when none does.
func _vantage(subject: Node3D, aim: Vector3, fwd: Vector3, angles: Array, dists: Array, dy: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for co in subject.find_children("*", "CollisionObject3D", true, false):
		ex.append((co as CollisionObject3D).get_rid())
	if subject is CollisionObject3D:
		ex.append((subject as CollisionObject3D).get_rid())
	for d in dists:
		for a in angles:
			var cp: Vector3 = aim + _yaw(fwd, float(a)) * float(d) + Vector3(0, dy, 0)
			if not _path_clear(cp, cp):
				continue
			var seen := true
			for t in [aim, aim + Vector3(0, -0.45, 0)]:
				var q := PhysicsRayQueryParameters3D.create(cp, t, 1)
				q.exclude = ex
				if not space.intersect_ray(q).is_empty():
					seen = false
			if seen:
				return cp
	return Vector3.INF


## The horizontal angle of view for a vertical fov (16:9).
func _next_fov_h(vfov: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(vfov) * 0.5) * 16.0 / 9.0))


func _eddie_head() -> Vector3:
	return world.eddie.global_position + Vector3(0, 1.62, 0)


func _eddie_fwd() -> Vector3:
	var f: Vector3 = world.animators["Eddie"].world_forward() if world.animators.has("Eddie") else Vector3.FORWARD
	return f


## Eddie behind his counter: a medium shot 35 deg off his front; he talks to the player's place, 20 deg off our lens.
## `close`: the reaction - his eyes go first, then his head turns ~55 deg to the window and holds.
func _eddie_shot(secs: float, close: bool) -> void:
	if world.get("eddie") == null:
		_skip("eddie")
		return
	var h := _eddie_head()
	var f := _eddie_fwd()
	var an = world.animators.get("Eddie")
	var dist := 1.5 if close else 2.3
	var p1 := _vantage(world.eddie, h, f, [35.0, -35.0, 30.0, -30.0, 40.0, -40.0, 25.0, -25.0], [dist, dist - 0.3, dist + 0.4], -0.12)
	report["eddie_seen_" + ("close" if close else "mid")] = p1 != Vector3.INF
	if p1 == Vector3.INF:
		p1 = h + _yaw(f, 35.0) * dist + Vector3(0, -0.12, 0)
	var cdir := ((p1 - h) * Vector3(1, 0, 1)).normalized()
	var p0 := p1 + cdir * 0.25
	if not _path_clear(p0, p1):
		p0 = p1
	var focus := h + Vector3(0, -0.15 if not close else -0.05, 0)
	if an:
		an.walk_to([])
		an.hold_facing = true                                              # the body stays put; only the head moves
		var lens_side := signf(f.cross(cdir).y)
		var gaze := _mark(h + _yaw(f, (35.0 - 20.0) * lens_side) * 2.2 + Vector3(0, -0.05, 0))   # 20 deg off the lens
		an.look_target = gaze
		if close:
			var door: Vector3 = (world.game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
			var side := signf(f.cross(door - h).y)
			if side == 0.0:
				side = -lens_side
			var win := h + _yaw(f, 55.0 * side) * 5.0                       # 55 deg: the window side
			get_tree().create_timer(0.5).timeout.connect(func():               # the eyes (a small flick) ...
				if is_instance_valid(gaze):
					gaze.global_position = h + _yaw(f, 15.0 + 12.0 * side) * 2.2)
			get_tree().create_timer(1.05).timeout.connect(func():              # ... then the head, held to the cut
				an.set_mood("scared")
				if is_instance_valid(gaze):
					gaze.global_position = win)
	_cfg("6_eddie_hears" if close else "5_eddie_counter", 42.0 if close else 44.0)
	await _shot(p0, p1, focus, focus, secs)


# ------------------------------------------------------------------ 2 the sound falls away
func _seg_falling() -> void:
	(report["segments"] as Array).append("falling")
	for pl in _players:
		if is_instance_valid(pl):
			var tw := create_tween()
			tw.tween_property(pl, "volume_db", -60.0, 3.0)
	Sfx.play("veil_rumble", world.game_shop.global_position + Vector3(0, 2, 0), -10.0)
	# Eddie hears it: eyes, then head to the window (held)
	await _eddie_shot(3.4, true)
	# his view: from his eye line, out through the window frame - three layers of mist coming down the street
	var door: Vector3 = (world.game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var out := ((door - (world.game_shop.get_node("Doorways/Entrance_Inside") as Node3D).global_position) * Vector3(1, 0, 1)).normalized()
	var street := Vector3(1, 0, 0)
	var far := door + out * 6.0 + street * 70.0
	_mist_wall(far, -street, 3)
	_preset(P_APPROACH, false)
	world._stutter_lights(world.game_shop)
	var eye := _eddie_head()
	eye.y = world.game_shop.global_position.y + 1.65
	world.eddie.visible = false                                     # (we are him: his own head is not in the way)
	var step := ((door - eye) * Vector3(1, 0, 1)).normalized() * minf(0.8, maxf(0.0, eye.distance_to(door) - 2.2))
	var l0 := door + out * 5.0 + street * 14.0 + Vector3(0, 0.3, 0)
	var l1 := door + out * 5.0 + street * 20.0 + Vector3(0, 0.9, 0)
	_cfg("7_eddie_view", 50.0)
	await _shot(eye, eye + step, l0, l1, 4.6)


# ------------------------------------------------------------------ 3 the shape between the buildings
func _seg_shape() -> void:
	(report["segments"] as Array).append("shape")
	# low on the street (0.9 m), tilted up 10 deg; it crosses the gap left to right, half lost in the mist
	var low := Vector3(62.0, 0.9, 1.5)
	var dist := 103.5
	var gap := low + Vector3(0, dist * tan(deg_to_rad(10.0)), dist)
	# its walk carries it (scale) x (anim speed) m/s - measured off the Walk_Heavy cycle; any faster and it skates
	var cscale := 3.5
	var cspeed := 1.5
	var pace := cscale * cspeed
	var x0 := 62.0 + pace * 1.9
	_focus_lock = Vector3(400, 0, 400)                         # the town's walk-ons stay away from this shot
	_clear_extras(low, gap)
	var col := _spawn(COLOSSUS, Vector3(x0, 0.0, 105.0)) as Node3D
	if col:
		var model := col.get_node_or_null("Model") as Node3D
		if model:
			model.scale = Vector3.ONE * cscale
		VeilCreatureLook.apply_colossus(col, 0.0)
		_mats_ok(col, "colossus")
		col.rotation.y = -PI * 0.5                          # heading -x: left to right for a camera looking +z
		var ap := col.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("Walk_Heavy"):
			ap.get_animation("Walk_Heavy").loop_mode = Animation.LOOP_LINEAR
			ap.play("Walk_Heavy")
			ap.speed_scale = cspeed
		var tw := create_tween()
		tw.tween_property(col, "global_position", Vector3(x0 - pace * 4.0, 0.0, 105.0), 4.0)
		_watch(col, "colossus_visible", true)
		_step_sync(col, 3.6)
	_mist_wall(Vector3(62.0, 0.0, 86.0), Vector3(0, 0, -1), 1, 0.3)    # a thin veil in front of it
	_cfg("8_colossus", 62.0)
	await _shot(low, low + Vector3(0, 0.05, 0.3), gap, gap + Vector3(-3, 0, 0), 3.6)
	_watched.clear()
	_focus_lock = Vector3.INF
	_fade(1.0, 0.0)                                          # hard cut
	if is_instance_valid(col):
		col.queue_free()
	await _hold(0.7)


## Town walk-ons (people, cars of the living town) inside the view between the camera and `to` are hidden for it.
func _clear_extras(from: Vector3, to: Vector3) -> void:
	var dir := ((to - from) * Vector3(1, 0, 1)).normalized()
	var hidden := 0
	for k in world.animators:
		if String(k) in ["Eddie", "Marcus", "Cashier", "Trailer_Driver"]:
			continue
		var an = world.animators[k]
		if an == null or not is_instance_valid(an) or an.root == null:
			continue
		var p: Vector3 = (an.root as Node3D).global_position
		var v := (p - from) * Vector3(1, 0, 1)
		if v.dot(dir) > 0.0 and v.length() < 160.0 and absf(v.cross(dir).y) < v.dot(dir) * 0.9:
			(an.root as Node3D).visible = false
			hidden += 1
	report["extras_hidden"] = hidden


## The Colossus's footfalls on the sound track: a step each time a foot comes down (it stops going down) - read
## off the animated skeleton, so sound and impact land together.
func _step_sync(col: Node3D, secs: float) -> void:
	var skel: Skeleton3D = null
	for n in col.find_children("*", "Skeleton3D", true, false):
		skel = n
		break
	var feet: Array = []
	if skel:
		for i in skel.get_bone_count():
			var bn := skel.get_bone_name(i).to_lower()
			if bn.contains("foot") and not bn.contains("end") and not bn.contains("toe"):
				feet.append(i)
	report["colossus_steps"] = 0
	var prev := {}
	var falling := {}
	var cool := 0.0
	var t := 0.0
	while t < secs and not aborted and is_instance_valid(col):
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		cool -= dt
		for b in feet:
			var p: Vector3 = skel.global_transform * skel.get_bone_global_pose(b).origin
			if prev.has(b):
				var vy: float = (p.y - float(prev[b])) / maxf(dt, 0.001)
				if vy < -0.5:
					falling[b] = true
				elif falling.get(b, false) and vy > -0.1:
					falling[b] = false
					if cool <= 0.0:
						cool = 0.45
						report["colossus_steps"] = int(report["colossus_steps"]) + 1
						Sfx.play("colossus_step", Vector3(p.x, 0.0, p.z), 6.0, 0.6)
						_shake(0.25, 0.02)
			prev[b] = p.y


# ------------------------------------------------------------------ 4 run
func _seg_run() -> void:
	(report["segments"] as Array).append("run")
	Sfx.play_music(Sfx.MUSIC_COLOSSUS, false, -3.0, 0.1)
	if world.get("marcus") == null and world.has_method("_p3_place_marcus_in_shop"):
		world._p3_place_marcus_in_shop()
	var sd: Vector3 = (world.game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var md: Vector3 = (world.market.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var r := ((md - sd) * Vector3(1, 0, 1)).normalized()          # the run
	var f := Vector3(r.z, 0, -r.x)                                 # a camera looking this way sees the run left to right
	var lane := -f                                                 # Marcus a lane over (no two bodies in one place)
	var out := (((world.game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
		- (world.game_shop.get_node("Doorways/Entrance_Inside") as Node3D).global_position) * Vector3(1, 0, 1)).normalized()
	var runners: Array = []
	for nm in ["Eddie", "Marcus"]:
		var body = world.get(nm.to_lower())
		if body and world.animators.has(nm):
			var b := body as Node3D
			if b.get_parent() != world:
				b.reparent(world, true)
			b.visible = true
			var marc: bool = nm == "Marcus"
			b.global_position = sd + out * (-0.3 if marc else 0.7)          # Marcus still in the doorway, Eddie just out
			b.global_rotation.y = atan2(out.x, out.z)
			var off: Vector3 = lane * (1.1 if marc else 0.0)
			world.animators[nm].hold_facing = false
			world.animators[nm].set_mood("scared")
			world.animators[nm].look_target = null
			world.animators[nm].walk_to([sd + out * 2.5 + off, md + off - r * 1.0], 4.0 if marc else 4.2)   # a real run
			runners.append(b)
	_preset(P_APPROACH, true)
	_fade(0.0, 0.0)
	# across the street, 35 deg off square-on, a little ahead of them
	var mid := sd.lerp(md, 0.45)
	var D := 10.0
	var camp := mid - f * D * cos(deg_to_rad(35.0)) + r * D * sin(deg_to_rad(35.0)) + Vector3(0, 1.5, 0)
	# the street cracks first (the ground heaves, a rumble), then the tentacle tears out - behind them, on the far side
	var burst_at := sd + r * 2.5 + f * 2.2
	get_tree().create_timer(1.7).timeout.connect(func(): _crack(burst_at))
	get_tree().create_timer(2.5).timeout.connect(func(): _burst(burst_at))
	_cfg("9_escape", 60.0)
	await _shot(camp, camp + r * 1.2, sd + Vector3(0, 1.2, 0), md + Vector3(0, 1.0, 0), 5.0,
		func(): return ((runners[0] as Node3D).global_position.lerp((runners[-1] as Node3D).global_position, 0.5) + Vector3(0, 1.1, 0)) if not runners.is_empty() else md)
	report["runners_apart"] = runners.size() < 2 or (runners[0] as Node3D).global_position.distance_to((runners[1] as Node3D).global_position) > 0.6
	# inside the store, 3.5 m in and 16 deg off the doors: they run in past the camera, the doors close behind them
	var M: Transform3D = world.market.global_transform
	for i in runners.size():
		var b := runners[i] as Node3D
		var x := 0.3 - 0.6 * i
		b.global_position = M * Vector3(x, 0.04, -1.8 - 1.3 * i)
		b.global_rotation.y = world.market.global_rotation.y
		var nm := "Eddie" if i == 0 else "Marcus"
		world.animators[nm].walk_to([M * Vector3(x, 0.04, 2.0), M * Vector3(x - 0.4, 0.04, 8.5)], 4.2)
	var inside: Vector3 = M * Vector3(1.3, 1.5, 4.0)
	var doors: Vector3 = M * Vector3(0, 1.1, 0.0)
	world._doors_powered = true
	world._auto_open = false
	world._set_auto_doors(true)
	get_tree().create_timer(1.3).timeout.connect(func():
		world._auto_open = true
		for d in world._auto_doors:
			var tw := create_tween()
			tw.tween_property(d[0], "transform", d[1], 0.6))
	_cfg("10_market_doors", 50.0)
	await _shot(inside, inside + (doors - inside).normalized() * 0.3, doors, doors, 2.4)
	for nm in ["Eddie", "Marcus"]:
		if world.animators.has(nm):
			world.animators[nm].walk_to([])


## The road gives first: the ground heaves, cracks open, a deep rumble, the camera trembles.
func _crack(at: Vector3) -> void:
	if aborted:
		return
	var m := VeilTentacleMound.make(world, at, 913, 0.15)
	_spawned.append(m)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(g: float):
		if is_instance_valid(m):
			m.scale = Vector3(1.0, g, 1.0), 0.15, 1.0, 0.8)
	Sfx.play("veil_rumble", at, 4.0, 0.7)
	_shake(0.6, 0.03)


func _burst(at: Vector3) -> void:
	if aborted:
		return
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
	_mats_ok(t, "tentacle")
	t.scale = Vector3.ONE * 0.9
	var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "global_position", at, 0.6)
	Sfx.play("tentacle_hiss", at + Vector3(0, 1, 0), 4.0, 0.8)
	report["tentacle_after_crack"] = true


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
	var y0: float = world.market.global_position.y
	# first person, slow: the flashlight finds the boxes on a dark shelf
	var shelf := _shelf("Merch_box_", world.market)
	if not shelf.is_empty():
		var c: Vector3 = shelf[0]
		var al: Vector3 = shelf[1]
		var nr: Vector3 = shelf[2]
		var hl: float = float(shelf[3]) if shelf.size() > 3 else 1.3
		var p0 := Vector3(c.x, y0 + 1.6, c.z) + nr * _aisle_d(Vector3(c.x, y0 + 1.6, c.z), nr, al, -0.4, 0.2, [1.8, 1.6, 1.4, 1.2, 1.0, 0.85, 0.7]) - al * 0.4
		var tgt := Vector3(c.x, y0 + 1.05, c.z)
		_card_show("Find supplies.", 2.2)
		_cfg("11_dark_shelves", 48.0)
		await _shot(p0, p0 + al * 0.6, tgt - al * minf(1.3, hl * 0.6), tgt + al * minf(1.0, hl * 0.6), 3.4)
	else:
		_skip("dark_shelf")
	await _hold(0.3)
	# pallets shoved up to the loading door: low, three-quarters; they meet the door and settle
	var door_pt: Vector3 = M * Vector3(19.9, 0.6, 15.9)
	var pal := _spawn(PALLETS, M * Vector3(17.4, 0.04, 15.9)) as Node3D
	if pal:
		pal.global_basis = M.basis * Basis(Vector3.UP, PI * 0.5)
		var end: Vector3 = M * Vector3(19.52, 0.04, 15.9)               # the game's own spot for it, against the door
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.4)
		tw.tween_property(pal, "global_position", end, 0.9)
		tw.tween_property(pal, "global_position", end - M.basis.x * 0.03, 0.12)    # the knock back off the door
		tw.tween_property(pal, "global_position", end, 0.25)
		get_tree().create_timer(1.3).timeout.connect(func():
			Sfx.play("door_close", M * Vector3(19.9, 1, 15.9), 2.0, 0.5)
			_shake(0.2, 0.015))
	_card_show("Hold the doors.", 1.8)
	var pc: Vector3 = door_pt + M.basis * (Vector3(-cos(deg_to_rad(35.0)), 0, -sin(deg_to_rad(35.0))) * 4.2) + Vector3(0, 0.05, 0)
	_cfg("12_pallets", 48.0)
	await _shot(pc, pc + (door_pt - pc).normalized() * 0.3, door_pt + Vector3(0, 0.1, 0), door_pt + Vector3(0, 0.05, 0), 2.6)
	await _hold(0.3)
	# Marcus from behind and to the side; something far off makes him turn his head (away from us)
	var marcus = world.get("marcus")
	var sound_at: Vector3 = M * Vector3(-7.0, 0.6, 12.6)                 # where the Skitter is about to cross
	if marcus and world.animators.has("Marcus"):
		var mb := marcus as Node3D
		if mb.get_parent() != world:
			mb.reparent(world, true)
		mb.global_position = M * Vector3(-1.0, 0.04, 10.5)
		mb.global_rotation.y = world.market.global_rotation.y
		var an = world.animators["Marcus"]
		an.walk_to([])
		an.hold_facing = false
		await get_tree().process_frame
		var fw: Vector3 = an.world_forward()
		var mh := mb.global_position + Vector3(0, 1.6, 0)
		var gaze := _mark(mh + fw * 6.0)
		an.look_target = gaze
		var side := signf(fw.cross(sound_at - mh).y)
		var behind := _yaw(-fw, 30.0 * -side)                          # 30 deg off his back, on the side away from the sound
		var mc := mh + behind * 2.7 + Vector3(0, 0.05, 0)
		get_tree().create_timer(0.8).timeout.connect(func():
			Sfx.bank_at("sk_hiss", sound_at, -8.0, 12.0)
			if is_instance_valid(gaze):
				gaze.global_position = sound_at)
		_cfg("13_marcus", 46.0)
		await _shot(mc, mc + (mh - mc).normalized() * 0.25, mh, mh + Vector3(0, -0.02, 0), 2.8)
	else:
		_skip("marcus")
	# the Skitter across the far (back) aisle, right to left: out from behind one gondola end, gone behind the next
	var sx := -1.0
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for i in 29:
		var x: float = -1.0 + (0.5 * ceil(i / 2.0)) * (1.0 if i % 2 == 1 else -1.0)
		var cp: Vector3 = M * Vector3(x, 1.5, 9.0)
		if not _path_clear(cp, M * Vector3(x, 1.5, 9.2)):
			continue
		var seen := true
		for dx in [-0.4, 0.0, 0.4]:
			var rq := PhysicsRayQueryParameters3D.create(cp, M * Vector3(x + dx, 0.45, 12.6), 1)
			if not space.intersect_ray(rq).is_empty():
				seen = false
		if seen:
			sx = x
			break
	report["skitter_aisle_x"] = sx
	var sk := _spawn(SKITTER, M * Vector3(sx - 4.5, 0.04, 12.6)) as Node3D
	if sk:
		VeilCreatureLook.apply_skitter(sk, sk.global_position.y)
		_mats_ok(sk, "skitter")
		VeilCreatureLook.skitter_anim(sk, "scuttle", 8.0)
		var rim := OmniLight3D.new()
		rim.light_color = Color(0.62, 0.72, 0.85)
		rim.light_energy = 1.4
		rim.omni_range = 2.6
		sk.add_child(rim)
		rim.position = Vector3(0.0, 1.0, 0.0)
		var d2 := M.basis * Vector3(1, 0, 0)
		sk.rotation.y = atan2(d2.x, d2.z)
		var ts := create_tween()
		ts.tween_interval(0.6)
		ts.tween_property(sk, "global_position", M * Vector3(sx - 0.6, 0.04, 12.6), 0.45)
		ts.tween_property(sk, "global_position", M * Vector3(sx + 0.6, 0.04, 12.6), 0.6)
		ts.tween_property(sk, "global_position", M * Vector3(sx + 4.5, 0.04, 12.6), 0.45)
		get_tree().create_timer(0.8).timeout.connect(func(): Sfx.bank_at("sk_hiss", sk.global_position, -2.0, 10.0))
		_watch(sk, "skitter_visible")
	_cfg("14_skitter", 48.0)
	await _shot(M * Vector3(sx, 1.5, 9.0), M * Vector3(sx, 1.5, 9.2), M * Vector3(sx - 0.8, 0.7, 12.6), M * Vector3(sx + 0.8, 0.7, 12.6), 2.6)
	_watched.clear()
	# the Hound along the glass, left to right, then into the doors
	var h := _spawn(HOUND, M * Vector3(-14.0, 0.04, -1.6)) as Node3D
	report["hound_seen_before_hit"] = 0.0
	if h:
		_mats_ok(h, "hound")
		var ap := h.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for a in ap.get_animation_list():
				if String(a).contains("Run"):
					ap.play(a)
					break
		var dir := M.basis * Vector3(1, 0, 0)
		h.rotation.y = atan2(dir.x, dir.z)
		var th := create_tween()
		th.tween_property(h, "global_position", M * Vector3(-1.0, 0.04, -1.2), 1.4)
		_watch(h, "hound_visible", true)
		get_tree().create_timer(1.4).timeout.connect(func():
			report["hound_seen_before_hit"] = report.get("hound_visible", 0.0)
			if is_instance_valid(h):
				var into := M.basis * Vector3(0, 0, 1)                      # facing the doors, into the store
				var tr := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tr.tween_property(h, "rotation:y", atan2(into.x, into.z), 0.3)
				if ap and ap.has_animation("Attack_Bite"):
					ap.get_animation("Attack_Bite").loop_mode = Animation.LOOP_LINEAR
					ap.play("Attack_Bite", 0.15)
				report["hound_faces_door"] = true
			Sfx.play("door_close", M * Vector3(0, 1.2, 0), 6.0, 0.45)
			Sfx.bank_at("hound_bark", M * Vector3(0, 1.2, -1), 2.0, 14.0)
			_shake(0.4, 0.05))
	_cfg("15_hound", 50.0)
	await _shot(M * Vector3(1.2, 1.45, 4.0), M * Vector3(1.0, 1.45, 3.6), M * Vector3(-6.0, 1.0, -0.5), M * Vector3(-1.0, 1.0, -0.5), 2.8)
	_watched.clear()
	_preload_wrecks()
	# the bed they made on the office floor: 1.25 m up, looking down ~17 deg, a slow half-metre push
	var bed_at: Vector3 = M * Vector3(-17.95, 0.04, 15.35)
	var bed_yaw: float = world.market.global_rotation.y + PI * 0.5
	_bedroll(bed_at, bed_yaw)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 0.9
	lamp.omni_range = 4.0
	world.add_child(lamp)
	lamp.global_position = bed_at + Vector3(0.6, 0.3, 0.6)
	_spawned.append(lamp)
	torch.visible = false
	# the side with the room for it (the office is small): the longest clear line out from the bed
	var foot := Basis(Vector3.UP, bed_yaw) * Vector3(0, 0, 1)
	var bdir := foot
	var bdist := 0.0
	for deg in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 180.0, 150.0, -150.0, 120.0, -120.0]:
		var dv := _yaw(foot, deg)
		for dd in [3.0, 2.6, 2.2]:
			var cp: Vector3 = bed_at + dv * dd + Vector3(0, 1.25, 0)
			if _path_clear(bed_at + Vector3(0, 1.25, 0) + dv * 0.6, cp):
				if dd > bdist:
					bdist = dd
					bdir = dv
				break
		if bdist >= 3.0:
			break
	if bdist == 0.0:
		bdist = 2.2
	var b0 := bed_at + bdir * bdist + Vector3(0, 1.25, 0)
	var b1 := b0 - bdir * 0.5
	var down := tan(deg_to_rad(16.0))
	var lk := func(p: Vector3) -> Vector3: return p - bdir * (1.21 / down) - Vector3(0, 1.21, 0)
	_card_show("Keep them alive.", 2.4)
	_cfg("16_bed", 46.0)
	await _shot(b0, b1, lk.call(b0), lk.call(b1), 3.2)
	torch.queue_free()
	Sfx.stop_music(2.0)
	_fade(1.0, 0.8)
	await _hold(1.0)


## How far out into the aisle a shelf shot can sit: the first of `ds` (metres off the shelf line, best first)
## whose track from `a_off` to `b_off` along the shelf is clear of the set.
func _aisle_d(c: Vector3, nr: Vector3, al: Vector3, a_off: float, b_off: float, ds: Array) -> float:
	for d in ds:
		if _path_clear(c + nr * float(d) + al * a_off, c + nr * float(d) + al * b_off):
			return float(d)
	return float(ds[0])


func _preload_wrecks() -> void:
	var td = world.get("town_destruction")
	var hn := world.get_node_or_null("Residential/Houses")
	if td == null or hn == null:
		return
	for id in ["HOUSE_14", "PLAYER_HOME"]:
		var hh := hn.get_node_or_null(id) as Node3D
		if hh and td.TARGETS.has(id):
			var path: String = td.DIR + "%s__%s.glb" % [String(hh.scene_file_path).get_file().get_basename(), String(td.TARGETS[id])]
			if ResourceLoader.exists(path):
				ResourceLoader.load_threaded_request(path)


## The wrecked version of a house, for the camera only: the intact shell hidden, the game's wrecked model in its
## place with the house's own materials (the game's swap also builds collision for every piece of rubble - seconds
## of work the trailer doesn't need).
func _wreck_look(h: Node3D, kind: String, td: Node) -> bool:
	var variant := String(h.scene_file_path).get_file().get_basename()
	var path: String = td.DIR + "%s__%s.glb" % [variant, kind]
	if not ResourceLoader.exists(path):
		return false
	var mats := {}
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for i in m.get_surface_count():
			var mt := m.surface_get_material(i)
			if mt and not mats.has(String(mt.resource_name)):
				mats[String(mt.resource_name)] = mt
	if kind == "home":
		var ext := h.find_child("*_Exterior", true, false) as Node3D
		if ext:
			ext.visible = false
	else:
		var house := h.get_node_or_null("House") as Node3D
		if house:
			house.visible = false
		if kind in td.OWN_FURNITURE:
			var fu := h.get_node_or_null("Furnishing") as Node3D
			if fu:
				fu.visible = false
	var d := (load(path) as PackedScene).instantiate() as Node3D
	d.name = "Destroyed"
	h.add_child(d)
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var mt := m3.mesh.surface_get_material(i)
			if mt and mats.has(String(mt.resource_name)):
				m3.set_surface_override_material(i, mats[String(mt.resource_name)])
	return true


## A building's extent in its own space (its meshes together).
func _local_box(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inv := n.global_transform.affine_inverse()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var b: AABB = (inv * m.global_transform) * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-5, 0, -5), Vector3(10, 6, 10))


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
	var td = world.get("town_destruction")
	if td:
		var hn := world.get_node_or_null("Residential/Houses")
		for id in ["HOUSE_14", "PLAYER_HOME"]:
			var hh := hn.get_node_or_null(id) as Node3D if hn else null
			if hh and hh.get_node_or_null("Destroyed") == null and td.TARGETS.has(id):
				report["wrecked_" + id] = _wreck_look(hh, String(td.TARGETS[id]), td)
	# the morning mist, thinned for the camera (the game's roadway mist washes a still shot out to white)
	if ResourceLoader.exists(P_MORNING) and world.has_method("_atmo"):
		var mp: Resource = (load(P_MORNING) as Resource).duplicate()
		mp.set("fog_density", 0.012)
		world._atmo().apply_preset(mp, true)
	world.living.focus_override = Vector3(25, 0, -91)
	_fade(0.0, 1.4)
	var hs: Node3D = world.get_node_or_null("Residential/Houses/HOUSE_14")
	if hs:
		# the stepped-on house, three-quarters from its street side at eye height; a short slide along it
		var box := _local_box(hs)
		var hc: Vector3 = hs.global_transform * (box.get_center() * Vector3(1, 0, 1) + Vector3(0, 2.6, 0))
		var front: Vector3 = (hs.global_basis * Vector3(0, 0, -1) * Vector3(1, 0, 1)).normalized()   # (its drive side)
		var cdir := _yaw(front, 35.0)
		var p0 := hc + cdir * (maxf(box.size.x, box.size.z) * 0.5 + 9.0)
		p0.y = hs.global_position.y + 1.6
		var slide := cdir.cross(Vector3.UP).normalized() * 2.0
		_cfg("17a_stepped_house", 50.0)
		await _shot(p0, p0 + slide, hc, hc + slide * 0.3, 4.4)
	else:
		_skip("stepped_house")
	var home: Node3D = world.get("home")
	if home:
		# the player's own house: from farther back, a push toward the crushed back corner (stops short of rubble)
		var hc: Vector3 = home.global_transform * Vector3(-4.0, 2.4, 9.0)
		var from: Vector3 = home.global_transform * Vector3(-14.5, 2.2, 24.0)
		_cfg("17b_home", 50.0)
		await _shot(from, from.lerp(hc, 0.3), hc, hc + Vector3(0, -0.2, 0), 4.6)
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


## The next shot's name and lens (set just before each _shot).
func _cfg(shot_name: String, fov: float) -> void:
	_next_name = shot_name
	_next_fov = fov


func _shot(a: Vector3, b: Vector3, la: Vector3, lb: Vector3, secs: float, follow := Callable()) -> void:
	if aborted or cam == null:
		return
	report["shots"] = int(report["shots"]) + 1
	var nm := _next_name if _next_name != "" else "shot%d" % int(report["shots"])
	cam.fov = _next_fov
	_next_name = ""
	_next_fov = 48.0
	# clearance: the whole camera path keeps 20 cm off the set; if not, the camera eases toward what it looks at
	# (same framing, a little closer) until it does - and the report says so
	if not _path_clear(a, b):
		var fixed := false
		for i in range(1, 9):
			var k := i * 0.25
			var a2 := a + (la - a).normalized() * k
			var b2 := b + (lb - b).normalized() * k
			if _path_clear(a2, b2):
				a = a2
				b = b2
				fixed = true
				break
		(report["clip_fixed" if fixed else "clip"] as Array).append(nm)
		(report["clip_hits"] as Dictionary)[nm] = _last_hit
	(report["shot_names"] as Array).append(nm)
	var hidden_props := _clear_lens(a, b, la, lb, nm)
	var t := 0.0
	while t < secs and not aborted:
		var k := t / secs
		k = k * k * (3.0 - 2.0 * k)
		var p := a.lerp(b, k)
		var look: Vector3 = follow.call() if follow.is_valid() else la.lerp(lb, k)
		if (look - p).length() > 0.05:
			cam.global_transform = Transform3D(Basis.looking_at(look - p, Vector3.UP), p)
		world.living.focus_override = p if not _focus_lock.is_finite() else _focus_lock
		_watch_tick()
		await get_tree().process_frame
		t += get_process_delta_time()
	for n in hidden_props:
		if is_instance_valid(n):
			(n as Node3D).visible = true


## Small things right in front of the lens along a shot (a lamp globe, a sign, a shelf post: no collision, so the
## clearance sweep doesn't catch them) are hidden for that shot. Actors and creatures are never touched.
func _clear_lens(a: Vector3, b: Vector3, la: Vector3, lb: Vector3, nm: String) -> Array:
	if _props.is_empty():
		for mi in world.find_children("*", "MeshInstance3D", true, false):
			_props.append(mi)
	var out: Array = []
	var mid := a.lerp(b, 0.5)
	var pts: Array = []
	for k in 5:
		var u := k / 4.0
		var p := a.lerp(b, u)
		var dv := (la.lerp(lb, u) - p).normalized()
		for dd in [0.0, 0.35, 0.7, 1.05]:
			pts.append(p + dv * dd)
	for mi in _props:
		if not is_instance_valid(mi) or not (mi as MeshInstance3D).is_visible_in_tree() or (mi as MeshInstance3D).mesh == null:
			continue
		var g := mi as MeshInstance3D
		if g.global_position.distance_to(mid) > 25.0:
			continue
		var box: AABB = g.global_transform * g.mesh.get_aabb()
		if box.get_longest_axis_size() > 3.0:
			continue
		var actor := false
		var up: Node = g
		while up and up.get_parent() != world and up.get_parent() != null:
			up = up.get_parent()
			if up is VeilSurvivorBody or up.is_in_group("veil_creature"):
				actor = true
				break
		if actor or _spawned.has(up):
			continue
		var grown := box.grow(0.12)
		for q in pts:
			if grown.has_point(q):
				g.visible = false
				out.append(g)
				if not report["lens_props"].has(nm):
					report["lens_props"][nm] = []
				(report["lens_props"][nm] as Array).append(String(g.name))
				break
	return out


## True when a 20 cm sphere fits everywhere along a -> b (the world's static and solid geometry, layer 1; the
## hidden player is ignored).
func _path_clear(a: Vector3, b: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = CLEARANCE
	q.shape = s
	q.collision_mask = 1
	q.collide_with_areas = false
	var ex: Array[RID] = []
	for co in world.player.find_children("*", "CollisionObject3D", true, false):
		ex.append((co as CollisionObject3D).get_rid())
	if world.player is CollisionObject3D:
		ex.append((world.player as CollisionObject3D).get_rid())
	q.exclude = ex
	var n := maxi(2, int(ceil(a.distance_to(b) / 0.15)) + 1)
	for i in n:
		q.transform = Transform3D(Basis(), a.lerp(b, float(i) / float(n - 1)))
		var hit := space.intersect_shape(q, 1)
		if not hit.is_empty():
			var co = hit[0].get("collider")
			_last_hit = str(co.get_path()) if co is Node else "?"
			return false
	return true


## Track a creature through a shot: how long it is on screen (in the frame, nothing solid in between).
func _watch(n: Node3D, key: String, see_through := false) -> void:
	_watched.append([n, key, see_through])
	report[key] = 0.0


func _watch_tick() -> void:
	var dt := get_process_delta_time()
	for w in _watched:
		var n = w[0]
		if not is_instance_valid(n) or not (n as Node3D).is_inside_tree():
			continue
		var p: Vector3 = (n as Node3D).global_position + Vector3(0, 0.4, 0)
		if not cam.is_position_in_frustum(p):
			continue
		report[w[1] + "_in_frame"] = float(report.get(w[1] + "_in_frame", 0.0)) + dt
		if not w[2]:
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
			if not world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				continue
		report[w[1]] = float(report[w[1]]) + dt


## Every creature surface has its dark material (no default white).
func _mats_ok(n: Node, key: String) -> void:
	var ok := n != null
	if n:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			for i in m.mesh.get_surface_count():
				if m.get_active_material(i) == null:
					ok = false
	(report["creature_mats"] as Dictionary)[key] = ok


## A marker an actor's eyes can hold on.
func _mark(at: Vector3) -> Node3D:
	var m := Node3D.new()
	world.add_child(m)
	m.global_position = at
	_spawned.append(m)
	return m


## A horizontal direction turned `deg` about the vertical.
static func _yaw(v: Vector3, deg: float) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(deg)) * v


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


func _card_show(text: String, hold: float, left := false) -> void:
	_card.text = text
	# centred, or in the left third (beside a subject framed on the right); anchors keep it in place at any aspect
	_card.anchor_left = 0.06 if left else 0.0
	_card.anchor_right = 0.4 if left else 1.0
	_card.offset_left = 0.0
	_card.offset_right = 0.0
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_CENTER
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
	var at := func(s: float) -> Vector3:
		s = clampf(s, 0.0, total)
		var i := 1
		while i < path.size() - 1 and float(lengths[i]) < s:
			i += 1
		var seg: float = float(lengths[i]) - float(lengths[i - 1])
		var u: float = (s - float(lengths[i - 1])) / maxf(seg, 0.01)
		return (path[i - 1] as Vector3).lerp(path[i], clampf(u, 0.0, 1.0))
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(k: float):
		var s := k * total
		# the body rides a rounded line through the corners (the mean of the path around it), nose along the line
		# from a little behind to a little ahead: a natural turn, the wheels kept on the road height
		var p: Vector3 = (at.call(s - 2.0) + at.call(s) * 2.0 + at.call(s + 2.0)) / 4.0
		var d: Vector3 = at.call(s + 3.0) - at.call(s - 3.0)
		p.y = (path[0] as Vector3).y
		if is_instance_valid(car) and d.length() > 0.01:
			car.global_transform = Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.z)), p), 0.0, 1.0, secs)


func _shelf(prefix: String, inside: Node3D) -> Array:
	var merch = world.get("shop_merch") if inside == world.game_shop else world.get("market_merch")
	var sh := shelf_of(merch, prefix.trim_prefix("Merch_"), inside, true)
	if sh.is_empty():
		return sh
	# which side are the goods actually seen from? from the aisle side the line to them is open; from the back of
	# the gondola a panel is in the way (the camera would film a blank board)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var c: Vector3 = sh[0]
	var open := func(n: Vector3) -> bool:
		var q := PhysicsRayQueryParameters3D.create(c + n * 1.6, c + n * 0.5, 1)
		return space.intersect_ray(q).is_empty()
	var fwd_ok: bool = open.call(sh[2])
	report["shelf_" + prefix] = "ok" if fwd_ok else "flipped"
	if not fwd_ok and open.call(-(sh[2] as Vector3)):
		sh[2] = -(sh[2] as Vector3)
	elif not fwd_ok:
		report["shelf_" + prefix] = "blocked"
	return sh


## A shelf's merchandise: [centre, along it, out into the aisle] - from the store's own layout data (the positions
## the store's merchandise is built from; reading them back from the renderer is not reliable).
static func shelf_of(merch: Node, variant_prefix: String, store: Node3D, one_face := false) -> Array:
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
	if one_face:
		pts = _one_face(merch as Node3D, pts, lay)
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
	if one_face:
		var ahead := 0
		var behind := 0
		var stat_all: Dictionary = lay.get("static", {})
		for v in stat_all:
			for r in stat_all[v]:
				var q: Vector3 = (merch as Node3D).global_transform * Vector3(float(r[0]), float(r[1]), float(r[2]))
				var off := (q - c) * Vector3(1, 0, 1)
				if absf(off.dot(along)) > 2.0:
					continue
				var dn := off.dot(nrm)
				if dn > 0.35 and dn < 1.4:
					ahead += 1
				elif dn < -0.35 and dn > -1.4:
					behind += 1
		if ahead > behind:
			nrm = -nrm
	elif nrm.dot(room - c) < 0.0:
		nrm = -nrm
	var half := 0.0
	for p in pts:
		half = maxf(half, absf(((p as Vector3) - c).dot(along)))
	return [c, along, nrm, half]


## Of a spread of merchandise (several shelves): the one shelf face the first item is on - the items in line with
## it (in the store's x or z, whichever line holds more); the face's normal is then away from its own gondola.
static func _one_face(merch: Node3D, pts: Array, lay: Dictionary) -> Array:
	var inv := merch.global_transform.affine_inverse()
	var p0: Vector3 = inv * (pts[0] as Vector3)
	var on_x: Array = []
	var on_z: Array = []
	for p in pts:
		var l: Vector3 = inv * (p as Vector3)
		if absf(l.x - p0.x) < 0.3:
			on_x.append(p)
		if absf(l.z - p0.z) < 0.3:
			on_z.append(p)
	return on_x if on_x.size() >= on_z.size() else on_z


## The Veil at the end of the street: layered curtains of the game's mist, creeping in.
func _mist_wall(at: Vector3, toward: Vector3, layers: int, density := 0.55) -> void:
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
		mat.set_shader_parameter("density", density + i * 0.18)
		mat.set_shader_parameter("base_color", Color(0.42, 0.45, 0.48))
		mat.set_shader_parameter("edge_color", Color(0.2, 0.22, 0.26))
		qm.material = mat
		mi.mesh = qm
		world.add_child(mi)
		mi.global_transform = Transform3D(face, at - toward * (i * 18.0) + Vector3(0, (70.0 + i * 20.0) * 0.5 - 2.0, 0))
		_spawned.append(mi)
		# each layer drifts at its own pace (and a little sideways): parallax between them
		var side := toward.cross(Vector3.UP).normalized() * (float(i) - 1.0) * 5.0
		var tw := create_tween()
		tw.tween_property(mi, "global_position", mi.global_position + toward * (26.0 + i * 12.0) + side, 14.0)
