extends Node3D
## THE VEIL - Phase 1 world controller (Greyhaven, Friday 6:42 PM).
## Wires the existing assets into gameplay: the Player_Home's own interaction metadata (doors, drawers,
## cabinets, light switches, the fridge, the car keys), observation points, story triggers, the sedan,
## save / restore and the opening sequence. No monsters, no mist.
## Phase 2: after parking, two errands in either order - the supermarket (auto doors, three groceries off the
## shelves, checkout) and the game shop (entrance door, a game off the New Releases rack, Eddie at the counter).
## Phase 3 (Act I opening, WORKING DRAFT): once both errands are done and the player is outdoors, the Veil rolls in
## (Pack 09 atmosphere), the Colossus is glimpsed far off (Pack 07), the sedan will not start, Eddie calls the player
## into the game shop, Marcus is there looking for his son, and everyone shelters in the supermarket.

const PLAYER_SCRIPT := preload("res://game/player/player.gd")
const SEDAN_SCRIPT := preload("res://game/vehicles/player_sedan.gd")
const HUD_SCRIPT := preload("res://game/ui/hud.gd")
const CAN := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_CannedFood.glb")
const WATER := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_WaterBottle.glb")
const SNACK := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_EnergySnack.glb")
const EDDIE := preload("res://THE_VEIL_ASSETS_V2/06_Characters/Commercial_NPCs/CHR_Eddie.glb")
const EDDIE_FACE := preload("res://THE_VEIL_ASSETS_V2/06_Characters/Facial/Faces/T_Face_Eddie.png")
const FACE_SCRIPT := preload("res://THE_VEIL_ASSETS_V2/06_Characters/Facial/veil_face.gd")
const CASHIER := preload("res://THE_VEIL_ASSETS_V2/06_Characters/Commercial_NPCs/CHR_Cashier.glb")
const CASHIER_FACE := preload("res://THE_VEIL_ASSETS_V2/06_Characters/Facial/Faces/T_Face_Cashier.png")
const MARCUS_PATH := "res://THE_VEIL_ASSETS_V2/06_Characters/Marcus/CHR_Marcus.glb"
const MARCUS_FACE_PATH := "res://THE_VEIL_ASSETS_V2/06_Characters/Facial/Faces/T_Face_Marcus.png"
const ATMOS_PATH := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Godot_Scenes/VeilAtmosphere.tscn"
const COLOSSUS_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Colossus.tscn"
const TENTACLE_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn"
const GLOW_SHADER := preload("res://game/world/veil_highlight.gdshader")
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
## supermarket-local shelf spots (Pack 04 com_plans.py: gondolas at x = -11.5 + 3k, z = 10, stock faces +-x)
const GROCERIES := {
	"canned_food": [CAN, "Canned Soup", Vector3(-8.97, 0.52, 9.4), "Soup (aisle 1)"],
	"energy_snack": [SNACK, "Snack Bar", Vector3(-5.97, 0.92, 10.6), "Snack bar (aisle 2)"],
	"water_bottle": [WATER, "Water Bottle", Vector3(-2.03, 0.92, 10.2), "Water (aisle 4)"],
}

const OBSERVE := {
	"AlarmClock_01": ["Alarm Clock", "obs_alarm"], "WallCalendar_01": ["Calendar", "obs_calendar"],
	"TV_CRT_Small_01": ["TV", "obs_tv"], "GameConsole_01": ["Game Console", "obs_console"],
	"CerealBox_01": ["Cereal Box", "obs_cereal"], "Desk_Computer_01": ["Computer", "obs_computer"],
	"Radio_01": ["Radio", "obs_radio"], "WallClock_01": ["Clock", "obs_clock"],
}

var data := {}
var home: Node3D
var player: VeilPlayer
var sedan: PlayerSedan
var hud: VeilHUD
var in_car := false
var drive_time := 0.0
var _park_t := 0.0
var _ending := false
var interactables := {}


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://game/world/world_data.json"))
	home = get_node("Residential/Houses/PLAYER_HOME")
	hud = HUD_SCRIPT.new()
	add_child(hud)
	hud.save_requested.connect(save)
	hud.quit_to_menu.connect(_to_menu)
	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	add_child(player)
	player.prompt_changed.connect(hud.set_prompt)
	sedan = SEDAN_SCRIPT.new()
	sedan.name = "Sedan"
	add_child(sedan)
	sedan.global_transform = (home.get_node("Markers/Sedan_Driveway") as Node3D).global_transform
	sedan.global_position.y += 0.05
	sedan.entry_area.used.connect(func(_b): enter_car())
	sedan.speed_changed.connect(hud.set_speed)
	_setup_home()
	_setup_town()
	_setup_triggers()
	_apply_view_ranges()
	Game.flag_set.connect(_on_flag)
	Sfx.start_ambience()
	print("[World] ready: houses=%d interactables=%d" % [get_node("Residential/Houses").get_child_count(), interactables.size()])
	if OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search")).contains("autotest"):
		_web_autotest.call_deferred()
	if Game.load_requested and _restore():
		await get_tree().process_frame
		hud.fade_to(0.0, 0.8)
		hud.set_objective(Game.current_goal(), Game.current_step().get("text", ""))
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_opening()


# ------------------------------------------------------------------ performance: distance culling
## The whole town is one connected world (no loading screens), so far detail is culled by size:
## small props / furniture disappear first, roads and houses later, ground and big buildings stay.
## (The Compatibility renderer has no occlusion culling; this keeps draw calls browser-friendly.)
func _apply_view_ranges() -> void:
	var n := 0
	for part in ["Core", "Extension", "Residential", "Commercial"]:
		for g in get_node(part).find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if gi.visibility_range_end > 0.0:
				continue
			var a := gi.get_aabb()
			var sz := a.size.length() * maxf(gi.global_transform.basis.get_scale().x, 0.01)
			var r := 0.0
			if sz < 1.2:
				r = 30.0
			elif sz < 3.0:
				r = 55.0
			elif sz < 8.0:
				r = 95.0
			elif sz < 20.0:
				r = 170.0
			if sz < 3.0:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if r > 0.0:
				gi.visibility_range_end = r
				gi.visibility_range_end_margin = 4.0
				n += 1
	var sun := get_node_or_null("Core/Environment/EveningSun") as DirectionalLight3D
	if sun:
		sun.directional_shadow_max_distance = 40.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL   # one shadow pass instead of four splits
	print("view ranges applied: ", n)


# ------------------------------------------------------------------ opening sequence
func _opening() -> void:
	var sp := home.get_node("Markers/Spawn_WakeUp") as Node3D
	player.global_position = sp.global_position
	player.set_yaw_pitch(sp.global_rotation.y, 0.0)
	hud.allow_pause = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.play_wake_up(4.6)
	await get_tree().create_timer(1.0).timeout
	hud.title_card("FRIDAY  —  6:42 PM", 2.4)
	await hud.fade_to(0.0, 3.0)
	Dialogue.say("wake", true)
	await get_tree().create_timer(3.2).timeout
	hud.allow_pause = true
	hud.set_objective(Game.current_goal(), Game.current_step().get("text", ""))
	hud.set_hint("WASD move · Mouse look · Shift sprint · Ctrl crouch · E interact · Tab inventory · Esc pause")
	Dialogue.say("wake_hint", true)
	await get_tree().create_timer(9.0).timeout
	if not in_car:
		hud.set_hint("")


# ------------------------------------------------------------------ house interactions (from Pack 03 metadata)
func _label_for(n: String) -> String:
	if n.contains("Door_Front"):
		return "Front Door"
	if n.contains("Fridge"):
		return "Refrigerator"
	if n.contains("GarageDoor"):
		return "Garage Door"
	if n.begins_with("INT_Door_"):
		return n.trim_prefix("INT_Door_").capitalize() + " Door"
	if n.contains("SlidingDoor"):
		return "Sliding Door"
	if n.contains("Drawer"):
		return "Drawer"
	if n.contains("CabinetDoor") or n.contains("ApplianceDoor"):
		return "Cabinet"
	if n.contains("Window"):
		return "Window"
	return n.trim_prefix("INT_").capitalize()


func _setup_home() -> void:
	var meta: Array = home.get_meta("veil_interactables", [])
	for e in meta:
		var path: String = e["node"]
		var n := (home.get_node_or_null(path) if path.contains("/") else home.find_child(path, true, false)) as Node3D
		if n == null:
			push_warning("interactable not found: " + path)
			continue
		var key := "home/" + path
		var kind: String = e.get("veil_interact", "")
		var cfg := {"label": _label_for(n.name), "state_key": key}
		match kind:
			"hinge":
				var deg := float(e.get("open_deg", 90.0))
				var ax: Vector3 = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}.get(e.get("axis", "y"), Vector3.UP)
				if path.contains("Furniture/"):
					deg = _outward_deg(n, deg, ax)
				cfg.merge({"kind": "hinge", "open_deg": deg, "hinge_axis": ax})
			"slide":
				var ax := Vector3(0, 0, 1)
				if n.name.contains("SlidingDoor"):
					ax = Vector3(1, 0, 0)
				elif n.name.contains("GarageDoor") or n.name.contains("Window"):
					ax = Vector3(0, 1, 0)
				cfg.merge({"kind": "slide", "slide_axis": ax, "slide_dist": float(e.get("distance", 0.35)),
					"anim_time": 0.9 if n.name.contains("Garage") else 0.4})
			"pickup":
				cfg.merge({"kind": "pickup", "label": "Car Keys", "item_id": e.get("item", "car_keys"),
					"story_flag": "has_keys", "dialogue_id": "keys"})
			"toggle":
				var room := String(n.name).trim_prefix("INT_LightSwitch_")
				var light := home.get_node_or_null("Lights/Ceiling_" + room) as Light3D
				if light == null:
					continue
				if light.light_energy <= 0.001:
					light.light_energy = 0.8
					light.visible = false
				cfg.merge({"kind": "toggle", "label": "Light Switch", "light_node": light})
			_:
				continue
		var it := Interactable.attach(n, cfg)
		interactables[key] = it
		if n.name.contains("Fridge"):
			it.used.connect(_on_fridge)
	for nm in OBSERVE:
		var f := home.find_child(nm, true, false) as Node3D
		if f:
			Interactable.attach(f, {"kind": "observe", "label": OBSERVE[nm][0], "dialogue_id": OBSERVE[nm][1]})
	_stock_fridge()


## Pick the swing direction that moves a furniture door / lid away from the piece's body (out in front for
## doors, up for lids, down-and-out for oven doors). Some Pack 03 hinge data has the sign reversed.
func _outward_deg(door: Node3D, deg: float, axis: Vector3) -> float:
	var furn := door
	while furn and furn.get_parent() and furn.get_parent().name != "Furniture":
		furn = furn.get_parent() as Node3D
	if furn == null:
		return deg
	var body := Interactable.aabb_of(furn).get_center()
	var c := Interactable.aabb_of(door).get_center()
	var to_furn := furn.global_transform.affine_inverse() * door.get_parent_node_3d().global_transform
	var best := deg
	var best_d := -INF
	for d in [absf(deg), -absf(deg)]:
		var t := Transform3D(door.transform.basis * Basis(axis, deg_to_rad(d)), door.transform.origin)
		var dist := (to_furn * (t * c)).distance_to(body)
		if dist > best_d:
			best_d = dist
			best = d
	return best


func _stock_fridge() -> void:
	var fridge := home.find_child("Fridge_Retro_01", true, false) as Node3D
	if fridge == null:
		return
	var box := Interactable.aabb_of(fridge)
	var c := box.get_center()
	var shelf := box.position.y + box.size.y * 0.47
	var can := CAN.instantiate() as Node3D
	can.position = Vector3(c.x - box.size.x * 0.16, shelf, c.z + box.size.z * 0.05)
	fridge.add_child(can)
	var water := WATER.instantiate() as Node3D
	water.position = Vector3(c.x + box.size.x * 0.18, box.position.y + box.size.y * 0.18, c.z + box.size.z * 0.05)
	fridge.add_child(water)


var _hum: AudioStreamPlayer3D


func _on_fridge(_by: Node) -> void:
	var fridge := home.find_child("Fridge_Retro_01", true, false) as Node3D
	var fr_it: Interactable = interactables.values().filter(func(i): return i.label == "Refrigerator")[0]
	if fr_it.is_open and _hum == null:
		_hum = Sfx.loop_at(fridge, "fridge_hum", -14.0)
	elif not fr_it.is_open and _hum:
		_hum.queue_free()
		_hum = null
	if not Game.has_flag("fridge_checked"):
		Dialogue.say("fridge_empty", false, true)
		Game.set_flag("fridge_checked")
	elif interactables.values().any(func(i): return i.label == "Refrigerator" and i.is_open):
		Dialogue.say("fridge_again", true)


# ------------------------------------------------------------------ Phase 2: town errands (Pack 04 locations)
var market: Node3D
var game_shop: Node3D
var eddie: Node3D
var eddie_face: Node
var cashier: Node3D
var marcus: Node3D
var faces := {}               ## speaker name -> VeilFace (talks on that speaker's dialogue lines)
var animators := {}           ## speaker name -> NpcAnimator (procedural body: idle, look-at, gestures, walk)
var _auto_doors: Array = []
var _beacons := {}
var _in_market := false
var _auto_open := false


func _setup_town() -> void:
	market = get_node("Commercial/SUPERMARKET")
	game_shop = get_node("Commercial/GAME_SHOP")
	# supermarket: bi-parting automatic doors open while the player stands in front of / inside the vestibule
	for side in [["L", -1.0], ["R", 1.0]]:
		var leaf := market.get_node("Building").find_child("INT_AutoDoor_Entrance_" + side[0], true, false) as Node3D
		if leaf:
			_auto_doors.append([leaf, leaf.transform, Vector3(side[1] * 1.12, 0, 0)])
	var sensor := _area("Trigger_MarketDoors", market.global_transform * Vector3(0, 1.2, 0.2), Vector3(4.4, 2.4, 5.0), 2,
		func(b): if b == player: _set_auto_doors(true), market.global_transform.basis)
	sensor.body_exited.connect(func(b): if b == player: _set_auto_doors(false))
	var inside_m := _area("Trigger_MarketInside", market.global_transform * Vector3(0, 2.0, 9.0), Vector3(40, 4.0, 11.0), 2,
		func(b): if b == player: _on_market_entered(), market.global_transform.basis)
	inside_m.body_exited.connect(func(b): if b == player:
		_in_market = false
		if not Game.has_flag("p3_mist"):
			hud.set_hint(""))
	# three groceries on the gondola shelves
	for id in GROCERIES:
		var g: Array = GROCERIES[id]
		var m := (g[0] as PackedScene).instantiate() as Node3D
		m.name = "Grocery_" + id
		m.position = g[2]
		m.rotation.y = PI * 0.5 if g[2].x < (-11.5 + 3.0 * roundf((g[2].x + 11.5) / 3.0)) else -PI * 0.5
		market.add_child(m)
		var it := Interactable.attach(m, {"kind": "pickup", "label": g[1], "item_id": id, "state_key": "market/" + id})
		if not it.taken:
			_glow(m, true)
		it.used.connect(func(_b): _grocery_hint())
		interactables["market/" + id] = it
	# checkout: lane 4. The cashier is a generic placeholder (no cashier is named in the bible).
	# the cashier stands on the staff side of lane 4 (lane-local (1.0, 0, -0.75)), facing the customer aisle (+x)
	cashier = _spawn_npc(CASHIER, CASHIER_FACE, market, Vector3(-4.25, 0.04, 4.0), -PI * 0.5, "Cashier")
	var c_it := Interactable.attach(cashier, {"kind": "custom", "label": "Cashier", "prompt_text": "[E] Pay for Groceries"})
	c_it.used.connect(_checkout)
	interactables["market/cashier"] = c_it
	# game shop: hinged entrance door, a game off the New Releases rack, Eddie behind the counter
	var door := game_shop.get_node("Building").find_child("INT_Door_Entrance", true, false) as Node3D
	if door:
		var inside := (game_shop.get_node("Doorways/Entrance_Inside") as Node3D).global_position
		var cfg := {"kind": "hinge", "label": "Shop Door", "state_key": "shop/entrance", "open_deg": 95.0}
		var d_it := Interactable.attach(door, cfg)
		d_it.open_deg = _toward_deg(door, 95.0, inside)
		interactables["shop/entrance"] = d_it
	_area("Trigger_ShopInside", game_shop.global_transform * Vector3(0, 1.2, 3.0), Vector3(9, 2.4, 3), 2,
		func(b): if b == player: Dialogue.say("shop_enter", true), game_shop.global_transform.basis)
	var rack := Node3D.new()
	rack.name = "NewReleasePick"
	game_shop.add_child(rack)
	var browse := game_shop.get_node_or_null("Interaction/Browse_1") as Node3D
	rack.position = browse.position if browse else Vector3(-0.75, 1.04, 3.0)
	var pick := Interactable.attach(rack, {"kind": "pickup", "label": "Horror Game", "item_id": "horror_game",
		"dialogue_id": "game_pick", "state_key": "shop/horror_game"})
	pick.target = null           # the copy comes off a full rack: nothing to hide
	interactables["shop/horror_game"] = pick
	var behind := game_shop.get_node_or_null("NavTargets/BehindCounter") as Node3D
	eddie = _spawn_npc(EDDIE, EDDIE_FACE, game_shop, Vector3(behind.position.x, 0.04, behind.position.z) if behind else Vector3(2.8, 0.04, 7.5), 0.0, "Eddie")
	eddie_face = faces["Eddie"]
	var talk := Interactable.attach(eddie, {"kind": "custom", "label": "Eddie", "prompt_text": "[E] Talk to Eddie"})
	talk.used.connect(_talk_eddie)
	interactables["shop/eddie"] = talk
	Dialogue.line_started.connect(_on_line)
	_beacon("market", market.global_transform * Vector3(0, 2.6, -0.9))
	_setup_phase3()


const TALK_STYLE := {"Eddie": ["happy", "happy"], "Cashier": ["happy", "idle"], "Marcus": ["scared", "angry"]}


func _on_line(speaker: String, _t: String, dur: float) -> void:
	var f = faces.get(speaker)
	if f == null or not is_instance_valid(f):
		return
	var st: Array = TALK_STYLE.get(speaker, ["neutral", "idle"])
	if Game.has_flag("p3_mist") and speaker == "Eddie":
		st = ["scared", "scared"]
	f.set_expression(st[0])
	f.say(dur * 0.85, st[1])
	if animators.has(speaker):
		animators[speaker].talk(dur * 0.9)


## Instance an approved Pack 06 character as an NPC: procedural body animation (NpcAnimator) + VeilFace.
## `yaw` is the facing in the parent frame (0 = parent -Z); the animator measures the model's real forward
## from its feet, so the facing is right whatever way the GLB was authored.
func _spawn_npc(scene: PackedScene, face_tex: Texture2D, parent: Node3D, pos: Vector3, yaw: float, speaker: String) -> Node3D:
	var n := scene.instantiate() as Node3D
	n.name = speaker
	parent.add_child(n)
	n.position = pos
	var anim: Node = NPC_ANIM.new()
	anim.name = "Animator"
	n.add_child(anim)
	animators[speaker] = anim
	var want := parent.global_transform.basis * (Basis(Vector3.UP, yaw) * Vector3(0, 0, -1))
	want.y = 0.0
	n.rotate_y(anim.world_forward().signed_angle_to(want.normalized(), Vector3.UP))
	var f: Node = FACE_SCRIPT.new()
	f.name = "VeilFace"
	f.face_atlas = face_tex
	n.add_child(f)
	faces[speaker] = f
	return n


## Soft pulsing rim highlight (additive overlay) on everything under `n`.
func _glow(n: Node, on: bool, col := Color(1.0, 0.78, 0.32)) -> void:
	var mat: ShaderMaterial = null
	if on:
		mat = ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		mat.set_shader_parameter("glow_color", col)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_overlay = mat
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_overlay = mat


## A slowly pulsing warm light marking a destination (store entrance) until the player gets there.
func _beacon(id: String, pos: Vector3, col := Color(1.0, 0.82, 0.45)) -> void:
	_clear_beacon(id)
	var l := OmniLight3D.new()
	l.name = "Beacon_" + id
	l.light_color = col
	l.omni_range = 6.0
	l.light_energy = 0.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 2.2, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 0.5, 1.1).set_trans(Tween.TRANS_SINE)
	_beacons[id] = l


func _clear_beacon(id: String) -> void:
	if _beacons.has(id) and is_instance_valid(_beacons[id]):
		_beacons[id].queue_free()
	_beacons.erase(id)


func _on_market_entered() -> void:
	_in_market = true
	_clear_beacon("market")
	if Game.has_flag("p3_mist"):
		_p3_reach_market()
		return
	Dialogue.say("market_enter", true)
	if not Game.has_flag("groceries_done"):
		_grocery_hint()


# ------------------------------------------------------------------ "view lock": slow look + zoom onto a target
var _cine: Camera3D
var _cine_id := 0
var _cine_tw: Tween


## Borrow the current view, turn slowly to `target` while narrowing the FOV, hold, then hand the view back.
## Player input is paused on foot; leaving the car (or any camera change) ends the shot early.
func focus_shot(target: Vector3, fov_to := 28.0, t_in := 2.6, hold := 1.8, title := "") -> void:
	_end_cine()
	var src := get_viewport().get_camera_3d()
	if src == null:
		return
	var my_id := _cine_id
	var cam := Camera3D.new()
	cam.name = "FocusShot"
	add_child(cam)
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.far = src.far
	cam.near = src.near
	cam.current = true
	_cine = cam
	var was_controls := player.controls_enabled
	if not in_car:
		player.controls_enabled = false
	var b0 := src.global_transform.basis.orthonormalized()
	var b1 := Transform3D(Basis(), cam.global_position).looking_at(target, Vector3.UP).basis
	var f0 := src.fov
	var tw := create_tween()
	_cine_tw = tw
	tw.tween_method(func(k: float):
		if is_instance_valid(cam):
			var e := k * k * (3.0 - 2.0 * k)
			cam.global_basis = Basis(b0.get_rotation_quaternion().slerp(b1.get_rotation_quaternion(), e))
			cam.fov = lerpf(f0, fov_to, e), 0.0, 1.0, t_in)
	await tw.finished
	if my_id != _cine_id:
		return
	if title != "":
		hud.title_card(title, hold)
	await get_tree().create_timer(hold).timeout
	if my_id != _cine_id:
		return
	var tw2 := create_tween()
	_cine_tw = tw2
	tw2.tween_method(func(k: float):
		if is_instance_valid(cam):
			var e := k * k * (3.0 - 2.0 * k)
			cam.global_basis = Basis(b1.get_rotation_quaternion().slerp(b0.get_rotation_quaternion(), e))
			cam.fov = lerpf(fov_to, f0, e), 0.0, 1.0, 0.9)
	await tw2.finished
	if my_id != _cine_id:
		return
	_end_cine()
	if not in_car:
		player.controls_enabled = was_controls or player.controls_enabled


func _end_cine() -> void:
	_cine_id += 1                           # any focus_shot still awaiting sees this and stops
	if _cine_tw and _cine_tw.is_valid():
		_cine_tw.kill()
		_cine_tw.finished.emit()
	_cine_tw = null
	if _cine and is_instance_valid(_cine):
		_cine.queue_free()
		_cine = null
		if in_car and sedan.driven:
			sedan.driver_cam.current = true
		elif player.visible:
			player.camera.current = true
			player.controls_enabled = true


func _set_auto_doors(open: bool) -> void:
	if not _doors_powered:
		return
	if open == _auto_open:
		return
	if not open and get_node("Trigger_MarketDoors").overlaps_body(player):
		return
	_auto_open = open
	for d in _auto_doors:
		var leaf: Node3D = d[0]
		var t: Transform3D = d[1]
		if open:
			t = Transform3D(t.basis, t.origin + t.basis * d[2])
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(leaf, "transform", t, 0.7)
	Sfx.play("door_open" if open else "door_close", market.global_transform * Vector3(0, 1.2, 0.2), -8.0, 0.8)


## Pick the hinge sign that swings the door toward `toward` (into the room).
func _toward_deg(door: Node3D, deg: float, toward: Vector3) -> float:
	var c := Interactable.aabb_of(door).get_center()
	var best := deg
	var best_d := INF
	for d in [absf(deg), -absf(deg)]:
		var t := door.get_parent_node_3d().global_transform * Transform3D(door.transform.basis * Basis(Vector3.UP, deg_to_rad(d)), door.transform.origin)
		var dist := (t * c).distance_to(toward)
		if dist < best_d:
			best_d = dist
			best = d
	return best


func _grocery_hint() -> void:
	if Game.has_flag("groceries_done"):
		return
	var parts := []
	var n := 0
	for id in GROCERIES:
		var got := Game.has_item(id)
		n += int(got)
		parts.append(("[x] " if got else "[  ] ") + GROCERIES[id][3])
	var tail := "  -  then pay the cashier at lane 4, by the doors" if n == 3 else "  -  look for the glowing items"
	if n == 3 and cashier:
		_glow(cashier, true, Color(0.55, 0.9, 0.6))
	hud.set_hint("SHOPPING LIST:   " + "     ".join(parts) + tail)


func _checkout(_by: Node) -> void:
	if Game.has_flag("groceries_done"):
		return
	var need := ["canned_food", "water_bottle", "energy_snack"]
	if not need.all(func(i): return Game.has_item(i)):
		Dialogue.say("market_need_items", false, true)
		return
	for i in need:
		Game.remove_item(i)
	Game.add_item("groceries")
	Sfx.play("pickup", market.global_transform * Vector3(-4.1, 1.1, 4.0))
	_glow(cashier, false)
	Dialogue.say("market_checkout", false, true)
	Dialogue.say("groceries_done")
	hud.set_hint("")
	Game.set_flag("groceries_done")


func _talk_eddie(_by: Node) -> void:
	if Game.has_flag("p3_mist"):
		Dialogue.say("p3_eddie_go" if Game.has_flag("p3_in_shop") else "p3_eddie_hurry", false, true)
		return
	if Game.has_flag("game_bought"):
		Dialogue.say("eddie_after", false, true)
	elif Game.has_item("horror_game"):
		Dialogue.say("eddie_buy", false, true)
		Game.set_flag("game_bought")
	else:
		Dialogue.say("eddie_hello", false, true)



# ------------------------------------------------------------------ Phase 3: the Veil arrives (WORKING DRAFT)
## Beat order (all lines are "draft" in dialogue.json):
##   both errands done + player outdoors -> fog rolls in (Pack 09 VEIL_APPROACHING), the cashier is gone
##   -> the Colossus is glimpsed far off behind the supermarket (view lock) -> VEIL_ACTIVE, mist tentacles in the street
##   -> the sedan is dead -> Eddie calls from the game shop -> Marcus is inside, looking for his son
##   -> cross Main St to the supermarket (Eddie + Marcus take the back way) -> shut the jammed doors -> end of the build.
var atmos: Node
var _tentacles: Array = []
var _hit_cd := 0.0
var _doors_powered := true
var _p3_shop_talked := false
var _p3_npcs_moved := false
var shut_it: Interactable

const MARCUS_SHOP_POS := Vector3(-3.6, 0.04, 4.4)        # game-shop local: between the wall shelf and the New Releases rack
const MARKET_EDDIE_POS := Vector3(-1.6, 0.04, 6.2)       # supermarket local, front of the sales floor, facing the doors
const MARKET_MARCUS_POS := Vector3(1.4, 0.04, 6.6)


func _setup_phase3() -> void:
	var shut := Node3D.new()
	shut.name = "DoorsShut"
	market.add_child(shut)
	shut.position = Vector3(0, 0.1, 0.25)
	shut_it = Interactable.attach(shut, {"kind": "custom", "label": "Doors", "prompt_text": ""})
	var shape := shut_it.get_child(0) as CollisionShape3D
	(shape.shape as BoxShape3D).size = Vector3(2.6, 2.3, 0.5)
	shape.position = Vector3(0, 1.15, 0)
	shut_it.used.connect(_p3_shut_doors)
	interactables["market/doors_shut"] = shut_it
	_area("Trigger_ShopInside_P3", game_shop.global_transform * Vector3(0, 1.2, 4.2), Vector3(10, 2.4, 7.0), 2,
		func(b): if b == player: _p3_reach_shop(), game_shop.global_transform.basis)


func _outdoors() -> bool:
	var lm := market.to_local(player.global_position)
	if absf(lm.x) < 20.6 and lm.z > -0.4 and lm.z < 18.0:
		return false
	var ls := game_shop.to_local(player.global_position)
	if absf(ls.x) < 6.0 and ls.z > 0.1 and ls.z < 12.0:
		return false
	return true


func _p3_tick(delta: float) -> void:
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	if not player.visible or in_car:
		return
	if not Game.has_flag("p3_mist"):
		if Game.has_flag("groceries_done") and Game.has_flag("game_bought") and _outdoors():
			_p3_start_mist()
	elif _p3_shop_talked and not _p3_npcs_moved and _outdoors():
		_p3_move_npcs_to_market()


func _atmo() -> Node:
	if atmos == null:
		atmos = (load(ATMOS_PATH) as PackedScene).instantiate()
		atmos.name = "VeilAtmosphere"
		add_child(atmos)
	return atmos.get_node("Atmosphere")


func _p3_start_mist() -> void:
	if Game.has_flag("p3_mist"):
		return
	Game.set_flag("p3_mist")
	hud.set_hint("")
	_clear_beacon("market")
	if cashier:
		cashier.visible = false                 # people are going missing
		interactables["market/cashier"].set_deferred("monitorable", false)
	for k in animators:
		animators[k].set_mood("scared")
	var a := _atmo()
	a.set_state(0, true)                       # NORMAL, then roll in
	a.set_state(2)                             # VEIL_APPROACHING (tweens over the preset transition time)
	Sfx.play("veil_rumble", player.global_position + Vector3(0, 2, 0), -2.0)
	Dialogue.say("p3_fog", false, true)
	await get_tree().create_timer(6.0).timeout
	_p3_colossus()
	await get_tree().create_timer(8.0).timeout
	_atmo().set_state(3)                       # VEIL_ACTIVE
	_p3_spawn_tentacles()


func _p3_colossus() -> void:
	var c := (load(COLOSSUS_PATH) as PackedScene).instantiate() as Node3D
	c.name = "Colossus_Glimpse"
	add_child(c)
	if c is CollisionObject3D:
		(c as CollisionObject3D).collision_layer = 0
		(c as CollisionObject3D).collision_mask = 0
	c.set_physics_process(false)
	var model := c.get_node_or_null("Model") as Node3D
	if model:
		model.scale = Vector3.ONE * 2.2           # presentation scale for the far-off glimpse (~22 m)
	c.global_position = Vector3(70, 0.15, -86)  # east of / behind the supermarket, clear of its roofline from Main St
	c.rotation.y = PI * 0.5                     # the model faces +Z: walk towards +X
	var ap := c.get_node_or_null(String(c.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
	if ap and ap.has_animation("Walk_Heavy"):
		ap.play("Walk_Heavy")
		ap.speed_scale = 0.6
	var tw := c.create_tween()
	tw.tween_property(c, "global_position", Vector3(118, 0.15, -86), 34.0)
	tw.tween_callback(c.queue_free)
	Sfx.play("colossus_call", player.global_position + Vector3(0, 3, 0), -3.0)
	Dialogue.say("p3_colossus", false, true)
	if not in_car and player.visible:
		focus_shot(c.global_position + Vector3(0, 17, 0), 24.0, 2.6, 2.8)


func _p3_spawn_tentacles() -> void:
	if not _tentacles.is_empty():
		return
	var a: Vector3 = (game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var b: Vector3 = (market.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var side := (b - a).cross(Vector3.UP).normalized()
	var ts := load(TENTACLE_PATH) as PackedScene
	for k in [[0.3, 2.6], [0.52, -2.6], [0.75, 2.4]]:
		var t := ts.instantiate() as Node3D
		t.name = "MistTentacle_%d" % _tentacles.size()
		add_child(t)
		t.global_position = a.lerp(b, k[0]) + side * k[1]
		t.global_position.y = 0.15
		t.rotation.y = float(_tentacles.size()) * 2.1
		if t.has_method("emerge"):
			t.emerge()
		var zone := Area3D.new()
		zone.name = "Hazard"
		zone.collision_layer = 0
		zone.collision_mask = 2
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.8
		cs.shape = sp
		cs.position.y = 1.0
		zone.add_child(cs)
		t.add_child(zone)
		zone.body_entered.connect(func(body): if body == player: _p3_tentacle_hit(t))
		_tentacles.append(t)


## No health system yet: a strike knocks the player back and blinds the screen for a moment.
func _p3_tentacle_hit(t: Node3D) -> void:
	if _hit_cd > 0.0:
		return
	_hit_cd = 1.6
	if t.has_method("play"):
		t.play("Strike")
	var away := (player.global_position - t.global_position) * Vector3(1, 0, 1)
	player.velocity = away.normalized() * 7.5 + Vector3(0, 3.0, 0)
	Sfx.play("tentacle_hiss", t.global_position + Vector3(0, 1, 0), 0.0)
	hud.fade_to(0.7, 0.06)
	get_tree().create_timer(0.25).timeout.connect(func(): hud.fade_to(0.0, 0.6))
	Dialogue.say("p3_hit", false, true)
	get_tree().create_timer(1.3).timeout.connect(func(): if is_instance_valid(t) and t.has_method("play"): t.play("Search"))


func _p3_car_dead() -> void:
	if not Game.has_flag("p3_mist"):
		_p3_start_mist()
	if Game.has_flag("phase2_done"):
		Dialogue.say("p3_car_again", false, true)
		return
	Sfx.play("static", sedan.global_position + Vector3(0, 1, 0), -4.0)
	Dialogue.say("p3_car_dead", false, true)
	Game.set_flag("phase2_done")
	_p3_place_marcus_in_shop()
	var sd: Interactable = interactables.get("shop/entrance")
	if sd and not sd.is_open:
		sd.set_open(true)                       # Eddie holds the door
	if eddie and eddie.get_parent() == game_shop and animators.has("Eddie"):
		# from behind the counter, around it and down the aisle between the rack and the console case
		animators["Eddie"].walk_to([Vector3(0.9, 0.04, 7.5), Vector3(0.0, 0.04, 5.0), Vector3(-0.4, 0.04, 1.7), Vector3(-2.2, 0.04, 1.3)], 1.7)
	_beacon("shop", (game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position + Vector3(0, 2.4, 0), Color(0.7, 0.85, 1.0))
	await get_tree().create_timer(4.5).timeout
	if not Game.has_flag("p3_in_shop"):
		Dialogue.say("p3_eddie_calls", false, true)


func _p3_place_marcus_in_shop() -> void:
	if marcus == null:
		marcus = _spawn_npc(load(MARCUS_PATH), load(MARCUS_FACE_PATH), game_shop, MARCUS_SHOP_POS, 0.0, "Marcus")
		animators["Marcus"].set_mood("scared")
		var m_it := Interactable.attach(marcus, {"kind": "custom", "label": "Marcus", "prompt_text": "[E] Talk"})
		m_it.used.connect(func(_b): Dialogue.say("p3_marcus_talk", false, true))
		interactables["p3/marcus"] = m_it


func _p3_reach_shop() -> void:
	if not Game.has_flag("phase2_done") or Game.has_flag("p3_in_shop"):
		return
	Game.set_flag("p3_in_shop")
	_clear_beacon("shop")
	_p3_place_marcus_in_shop()
	Dialogue.say("p3_shop", false, true)
	var total := 0.0
	for l in Dialogue.data.get("p3_shop", {}).get("lines", []):
		total += float(l.get("time", 3.0))
	await get_tree().create_timer(total + 0.3).timeout
	Dialogue.say("p3_eddie_go")
	_p3_shop_talked = true
	# both head for the back of the shop (they are moved to the supermarket once the player is outside)
	if animators.has("Eddie") and eddie.get_parent() == game_shop:
		animators["Eddie"].walk_to([Vector3(-0.4, 0.04, 1.7), Vector3(0.0, 0.04, 5.0), Vector3(0.3, 0.04, 7.6)], 1.6)
	if animators.has("Marcus") and marcus.get_parent() == game_shop:
		animators["Marcus"].walk_to([Vector3(-3.4, 0.04, 6.8), Vector3(-1.0, 0.04, 7.7)], 1.6)
	_beacon("market", market.global_transform * Vector3(0, 2.6, -0.9), Color(0.7, 0.85, 1.0))


func _p3_move_npcs_to_market() -> void:
	_p3_npcs_moved = true
	for pair in [[eddie, MARKET_EDDIE_POS], [marcus, MARKET_MARCUS_POS]]:
		var n: Node3D = pair[0]
		if n == null:
			continue
		n.reparent(market, false)
		n.position = pair[1]
		var anim = n.get_node_or_null("Animator")
		if anim:
			anim.walk_to([])
			anim.set_mood("scared")
			var want := market.global_transform.basis * Vector3(0, 0, -1)   # face the entrance
			want.y = 0.0
			n.rotate_y(anim.world_forward().signed_angle_to(want.normalized(), Vector3.UP))


func _p3_reach_market() -> void:
	if not Game.has_flag("p3_in_shop") or Game.has_flag("p3_in_market"):
		return
	if not _p3_npcs_moved:
		_p3_move_npcs_to_market()
	Game.set_flag("p3_in_market")
	_set_auto_doors(true)                       # the power dies with the doors open
	_doors_powered = false
	for l in market.get_node("Lights").get_children():
		if l is Light3D and String(l.name).begins_with("Light_"):
			(l as Light3D).light_energy *= 0.35
	shut_it.prompt_text = "[E] Pull the Doors Shut"
	if animators.has("Eddie"):
		animators["Eddie"].walk_to([Vector3(-1.0, 0.04, 4.3)], 1.4)
	if animators.has("Marcus"):
		animators["Marcus"].walk_to([Vector3(1.1, 0.04, 4.7)], 1.4)
	for d in _auto_doors:
		_glow(d[0], true, Color(0.7, 0.85, 1.0))
	Dialogue.say("p3_market", false, true)


func _p3_shut_doors(_by: Node) -> void:
	if not Game.has_flag("p3_in_market") or Game.has_flag("p3_doors_shut"):
		return
	shut_it.prompt_text = ""
	for d in _auto_doors:
		_glow(d[0], false)
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(d[0], "transform", d[1], 1.6)
	_auto_open = false
	Sfx.play("door_close", market.global_transform * Vector3(0, 1.2, 0.2), 0.0, 0.7)
	for t in _tentacles:
		if is_instance_valid(t) and t.has_method("retract"):
			t.retract()
	Dialogue.say("p3_doors", false, true)
	Game.set_flag("p3_doors_shut")
	_finish()


## Rebuild Phase 3 state after loading a save.
func _p3_restore() -> void:
	if not Game.has_flag("p3_mist"):
		return
	if cashier:
		cashier.visible = false
		interactables["market/cashier"].set_deferred("monitorable", false)
	_clear_beacon("market")
	_atmo().set_state(3, true)
	if not Game.has_flag("p3_doors_shut"):
		_p3_spawn_tentacles()
	if Game.has_flag("phase2_done"):
		_p3_place_marcus_in_shop()
	if Game.has_flag("p3_in_shop"):
		_p3_shop_talked = true
		_p3_move_npcs_to_market()
	if Game.has_flag("p3_in_market") and not Game.has_flag("p3_doors_shut"):
		_doors_powered = true
		_set_auto_doors(true)
		_doors_powered = false
		shut_it.prompt_text = "[E] Pull the Doors Shut"

# ------------------------------------------------------------------ triggers
func _area(n: String, pos: Vector3, size: Vector3, mask: int, cb: Callable, basis := Basis()) -> Area3D:
	var a := Area3D.new()
	a.name = n
	a.collision_layer = 0
	a.collision_mask = mask
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	a.add_child(cs)
	add_child(a)
	a.global_transform = Transform3D(basis, pos)
	a.body_entered.connect(cb)
	return a


func _setup_triggers() -> void:
	# front yard band: crossing it with the keys = "left the house"
	var yard := home.global_transform * Vector3(-1.0, 0.8, -3.2)
	_area("Trigger_LeftHouse", yard, Vector3(16, 3, 4), 2, func(b):
		if b == player and Game.has_flag("has_keys"):
			if not Game.has_flag("left_house"):
				Dialogue.say("left_house", true)
			Game.set_flag("left_house"), home.global_transform.basis)
	# entering the town core on Route 9
	_area("Trigger_Town", Vector3(184, 1.0, 36), Vector3(16, 6, 14), 4, func(b):
		if b == sedan and in_car:
			Game.set_flag("reached_town"))
	_area("Trigger_MainSt", Vector3(118, 1.0, 0), Vector3(10, 6, 14), 4, func(b):
		if b == sedan and in_car:
			Game.set_flag("reached_town")
			Dialogue.say("town", true))
	var d: Dictionary = data["destination"]
	var dp: Array = d["parking_center"]
	_area("Trigger_Parking", Vector3(dp[0], dp[1] + 1.0, dp[2]), Vector3(d["trigger_size"][0], 4, d["trigger_size"][2]), 4,
		func(_b): pass)


var _exit_requested := false


func _physics_process(delta: float) -> void:
	_p3_tick(delta)
	if _exit_requested:
		_exit_requested = false
		exit_car()
	if in_car:
		drive_time += delta
		var pk := get_node_or_null("Trigger_Parking") as Area3D
		if pk and pk.overlaps_body(sedan) and absf(sedan.speed) < 0.5 and Game.has_flag("entered_car"):
			_park_t += delta
			if _park_t > 1.0 and not Game.has_flag("parked"):
				Game.set_flag("reached_town")
				Game.set_flag("parked")
				Dialogue.say("parked", true, true)
				save()
				focus_shot(market.global_transform * Vector3(0, 3.0, 0.0), 26.0, 2.8, 1.8, "GREYHAVEN MARKET")
		else:
			_park_t = 0.0


func _finish() -> void:
	if _ending:
		return
	_ending = true
	save()
	await get_tree().create_timer(5.0).timeout
	hud.set_end_text("THE VEIL  -  ACT I", "The mist has swallowed Greyhaven. You are not alone in here.",
		"Act I continues in the next development phase.")
	hud.show_end(drive_time)


# ------------------------------------------------------------------ car
func enter_car() -> void:
	if in_car:
		return
	if not Game.has_item("car_keys"):
		Dialogue.say("need_keys", false, true)
		return
	if not Game.has_flag("fridge_checked"):
		Dialogue.say("need_kitchen", false, true)
		return
	if Game.has_flag("groceries_done") and Game.has_flag("game_bought"):
		_p3_car_dead()
		return
	in_car = true
	player.activate(false)
	await sedan.swing_door(true, 0.3)
	sedan.set_driven(true)
	sedan.swing_door(false, 0.35)
	Game.set_flag("left_house")
	Game.set_flag("entered_car")
	Dialogue.say("in_car", true)
	hud.set_hint("W accelerate · S brake / reverse · A/D steer · Space handbrake · E exit · mouse look")


func exit_car() -> void:
	if not in_car or not sedan.driven:
		return
	if absf(sedan.speed) > 1.0:
		print_debug("[Sedan exit] Vehicle is moving at %.2f m/s" % sedan.speed)
		Dialogue.say("no_exit", false, true)
		return
	var spot: Variant = sedan.exit_spot(get_world_3d().direct_space_state, player.get_rid())
	if spot == null:
		print_debug("[Sedan exit] Neither side has walkable ground and standing clearance at %s" % sedan.global_position)
		Dialogue.say("no_room", false, true)
		return
	_end_cine()
	sedan.speed = 0.0
	sedan.set_driven(false)
	sedan.swing_door(true, 0.25)
	in_car = false
	player.global_position = spot
	player.velocity = Vector3.ZERO
	player.set_yaw_pitch(sedan.global_rotation.y, 0.0)
	player.activate(true)
	hud.set_speed(-1.0)
	hud.set_hint("")
	await get_tree().create_timer(0.6).timeout
	sedan.swing_door(false, 0.35)


func _input(e: InputEvent) -> void:
	if in_car and e.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if sedan.driven and not hud.is_paused():
			_exit_requested = true


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.physical_keycode == KEY_F10:
		# developer aid: state to the console / browser console
		var p := sedan.global_position if in_car else player.global_position
		print("[Debug] pos=%s in_car=%s speed=%.1f step=%s inv=%s" % [p, in_car, sedan.speed * 3.6,
			Game.current_step().get("id", "done"), Game.inventory])


# ------------------------------------------------------------------ save / restore
func _on_flag(f: String) -> void:
	if not f.begins_with("said_") and f != "parked":
		save()


func save() -> void:
	var p := player.global_position
	Game.player_state = {"in_vehicle": in_car, "pos": [p.x, p.y, p.z], "yaw": player.rotation.y}
	Game.vehicle_state = sedan.state()
	Game.save_game()


func _restore() -> bool:
	var ps: Dictionary = Game.player_state
	if ps.is_empty():
		return false
	sedan.restore(Game.vehicle_state)
	var pp: Array = ps.get("pos", [])
	if pp.size() == 3:
		player.global_position = Vector3(pp[0], pp[1] + 0.05, pp[2])
		player.set_yaw_pitch(ps.get("yaw", 0.0), 0.0)
	if ps.get("in_vehicle", false):
		in_car = true
		player.activate(false)
		sedan.set_driven(true)
		hud.set_hint("W accelerate · S brake / reverse · A/D steer · Space handbrake · E exit")
	_p3_restore.call_deferred()
	return true


## Opt-in browser check (play/?autotest): runs the story interactions inside the exported build and logs results.
func _web_autotest() -> void:
	await get_tree().create_timer(12.0).timeout
	var fr: Interactable = interactables.values().filter(func(i): return i.label == "Refrigerator")[0]
	fr.interact(player)
	await get_tree().create_timer(1.0).timeout
	var keys: Interactable = interactables.values().filter(func(i): return i.item_id == "car_keys")[0]
	keys.interact(player)
	interactables["home/INT_Door_Front"].interact(player)
	await get_tree().create_timer(1.0).timeout
	player.global_position = get_node("Trigger_LeftHouse").global_position + Vector3(0, -0.6, 0)
	await get_tree().create_timer(1.0).timeout
	player.global_position = sedan.global_transform * Vector3(-1.6, 0.1, -0.3)
	await get_tree().create_timer(0.5).timeout
	enter_car()
	await get_tree().create_timer(1.5).timeout
	var p0 := sedan.global_position
	sedan.autopilot = func(_d): return Vector3(1.0, 0.0, 0.0)
	await get_tree().create_timer(3.0).timeout
	sedan.autopilot = func(_d): return Vector3(0.0, 1.0, 0.0)
	await get_tree().create_timer(2.0).timeout
	sedan.autopilot = Callable()
	save()
	print("[Autotest] fridge_open=%s fridge_flag=%s keys=%s front_door=%s left_house=%s in_car=%s moved=%.1fm step=%s saved=%s" % [
		fr.is_open, Game.has_flag("fridge_checked"), Game.has_item("car_keys"), interactables["home/INT_Door_Front"].is_open,
		Game.has_flag("left_house"), in_car, sedan.global_position.distance_to(p0), Game.current_step().get("id", ""), Game.has_save()])


func _to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.stop_ambience()
	get_tree().change_scene_to_file("res://game/scenes/MainMenu.tscn")
