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
const MERCH_SCRIPT := preload("res://game/world/store_merch.gd")
## the shopping list: item -> where to find it (pick groups in Pack 04 Merchandise/MERCH_LAYOUT.json)
const GROCERIES := {
	"canned_food": "Soup (aisle 1)",
	"energy_snack": "Snack bar (candy rack, lane 4)",
	"water_bottle": "Water (drinks cooler, back wall)",
}
const EXTRAS := ["cola_bottle", "chocolate_bar"]       ## optional extras, paid at the same checkout

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
	_setup_night()
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
	# the furniture piece: its parent is a house's "Furniture" batch or a scavenge house's "ScavengeFurniture"
	while furn and furn.get_parent() and not (String(furn.get_parent().name) in ["Furniture", "ScavengeFurniture"]):
		furn = furn.get_parent() as Node3D
	if furn == null or furn.get_parent() == null:
		return deg
	var probe := Interactable.aabb_of(door)
	if probe.size.length() < 0.01:
		return deg                     # no mesh bounds (headless): the authored sign is already outward
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


## The fridge is almost empty on purpose (opening beat "Nothing to eat"): one dented can on the lower wire shelf and
## a bottle of water on the upper one. The model itself adds a mustard bottle in a door bin and a box of baking soda.
## Shelf tops are at y 0.78 / 1.18 in the Pack 03 RES_Fridge_Retro model (furniture.py fridge()).
func _stock_fridge() -> void:
	var fridge := home.find_child("Fridge_Retro_01", true, false) as Node3D
	if fridge == null:
		return
	var can := CAN.instantiate() as Node3D
	can.name = "Fridge_Can"
	can.position = Vector3(-0.13, 0.781, -0.08)
	can.rotation.y = 0.5
	fridge.add_child(can)
	var water := WATER.instantiate() as Node3D
	water.name = "Fridge_Water"
	water.position = Vector3(0.11, 1.181, -0.12)
	fridge.add_child(water)
	# interior light: on while the door is open (OmniLight works in the Compatibility renderer)
	var lamp := OmniLight3D.new()
	lamp.name = "Fridge_Light"
	lamp.position = Vector3(0.0, 1.45, -0.05)
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_energy = 0.7
	lamp.omni_range = 0.95
	lamp.shadow_enabled = false
	lamp.visible = interactables.values().any(func(i): return i.label == "Refrigerator" and i.is_open)
	fridge.add_child(lamp)
	# the door's own interaction box swings away with the door: a proxy over the opening lets the player close it
	# while looking into the open fridge (it forwards to the door and mirrors its prompt)
	var fr_it: Interactable = interactables.values().filter(func(i): return i.label == "Refrigerator")[0]
	var opening := Node3D.new()
	opening.name = "Fridge_Opening"
	fridge.add_child(opening)
	var px := Interactable.attach(opening, {"kind": "custom", "label": "Fridge opening", "prompt_text": fr_it.get_prompt()})
	var cs := px.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = Vector3(0.66, 1.46, 0.1)
	cs.position = Vector3(0.0, 0.87, 0.42)          # just in front of the body's collision hull (front at z 0.36)
	cs.disabled = not fr_it.is_open                 # closed: the door's own box answers
	px.used.connect(func(by): fr_it.interact(by))
	fr_it.used.connect(func(_b):
		px.prompt_text = fr_it.get_prompt()
		cs.set_deferred("disabled", not fr_it.is_open))
	interactables["home/fridge_opening"] = px


var _hum: AudioStreamPlayer3D


func _on_fridge(_by: Node) -> void:
	var fridge := home.find_child("Fridge_Retro_01", true, false) as Node3D
	var fr_it: Interactable = interactables.values().filter(func(i): return i.label == "Refrigerator")[0]
	var lamp := fridge.get_node_or_null("Fridge_Light") as OmniLight3D
	if lamp:
		lamp.visible = fr_it.is_open
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
	# stocked shelves: separate product meshes (MultiMesh), only the pick groups are interactive
	market_merch = _merch(market, "supermarket", "market")
	market_merch.taken.connect(func(_g, _i): _grocery_hint())
	for id in GROCERIES:
		if not Game.has_item(id) and not Game.has_flag("groceries_done"):
			market_merch.set_glow(id, _glow_mat())
	_setup_coolers()
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
	shop_merch = _merch(game_shop, "video_game_store", "shop")
	shop_merch.taken.connect(func(g, _i): if g == "horror_game":
		Dialogue.say("game_pick", false, true)
		shop_merch.set_glow("horror_game", null))
	if not Game.has_item("horror_game") and not Game.has_flag("game_bought"):
		shop_merch.set_glow("horror_game", _glow_mat(Color(1.0, 0.35, 0.3)))
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


var _talk_speaker := ""
var _talk_cam: Camera3D
var _talk_id := 0


func _dlg_time(ids: Array) -> float:
	var t := 0.0
	for id in ids:
		for l in Dialogue.data.get(id, {}).get("lines", []):
			t += float(l.get("time", 3.0))
	return t


## Important conversations: subtle cinematic framing of whoever is speaking (VeilFace + gestures play), the
## player is held for the conversation and gets everything back afterwards. The camera moves at most 0.35 m
## toward the speaker (never if a wall is in the way) and narrows the FOV a little: no push into faces.
func talk_shot(seconds: float) -> void:
	if in_car or _encounter_running or not player.visible:
		return
	_end_talk()
	_end_cine()
	_talk_id += 1
	var id := _talk_id
	var base := player.camera.global_transform
	var fov0 := player.camera.fov
	var cam := Camera3D.new()
	cam.name = "TalkCam"
	add_child(cam)
	cam.global_transform = base
	cam.fov = fov0
	cam.current = true
	_talk_cam = cam
	player.controls_enabled = false
	var t := 0.0
	while t < seconds + 0.5 and id == _talk_id and is_instance_valid(cam):
		var dt := get_process_delta_time()
		var want := base
		var fov := fov0
		var head = _speaker_head(_talk_speaker)
		if head != null and t < seconds:
			var to: Vector3 = head - base.origin
			var pos := base.origin + to.normalized() * clampf(to.length() - 1.25, 0.0, 0.35)
			var q := PhysicsRayQueryParameters3D.create(base.origin, pos + to.normalized() * 0.2, 1, [player.get_rid()])
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				pos = base.origin
			want = Transform3D(Basis(), pos).looking_at(head, Vector3.UP)
			fov = 52.0
		cam.global_transform = cam.global_transform.interpolate_with(want, minf(dt * 3.0, 1.0))
		cam.fov = lerpf(cam.fov, fov, minf(dt * 3.0, 1.0))
		await get_tree().process_frame
		t += dt
	if id == _talk_id:
		_end_talk()


func _speaker_head(speaker: String):
	var a = animators.get(speaker)
	if a == null or not is_instance_valid(a) or a.skel == null or not a.root.is_visible_in_tree():
		return null
	return a.skel.global_transform * a.skel.get_bone_global_pose(a.bone("Head")).origin + Vector3(0, 0.08, 0)


func _end_talk() -> void:
	_talk_id += 1
	if _talk_cam and is_instance_valid(_talk_cam):
		_talk_cam.queue_free()
		_talk_cam = null
		player.camera.current = true
		player.controls_enabled = true


func _on_line(speaker: String, _t: String, dur: float) -> void:
	if animators.has(speaker):
		_talk_speaker = speaker
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


## While driving past the store front: the car eases down to ~17 km/h (driver keeps steering), the view turns and
## zooms gently onto the supermarket and its sign, then hands control back; the car rolls on into the lot.
func _arrival_shot() -> void:
	Game.set_flag("arrival_shot")
	sedan.speed_cap = 4.8
	Dialogue.say("town", true)
	await focus_shot(market.global_transform * Vector3(0.0, 4.2, -0.3), 30.0, 2.0, 1.6, "GREYHAVEN MARKET")
	sedan.speed_cap = -1.0


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


var market_merch: Node
var shop_merch: Node


## Products for one store; pick-group interactables are registered as "<prefix>/<group id>".
func _merch(store: Node3D, key: String, prefix: String) -> Node:
	var m: Node3D = MERCH_SCRIPT.new()
	m.name = "Merchandise"
	store.add_child(m)
	m.build(key)
	for gid in m.groups:
		interactables[prefix + "/" + gid] = m.groups[gid]["it"]
	m.taken.connect(func(g, _i): m.set_glow(g, null))
	return m


func _glow_mat(col := Color(1.0, 0.78, 0.32)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter("glow_color", col)
	return mat


## Glass-door drinks coolers (Pack 04 COM_Cooler_Beverage, instanced under Props): every door is a hinge
## ("[E] Open Fridge"), swinging outward; a cold interior light comes on while any door of that cooler is open.
func _setup_coolers() -> void:
	var props := market.get_node_or_null("Props")
	if props == null:
		return
	for cool in props.get_children():
		if not String(cool.name).begins_with("Cooler_Beverage"):
			continue
		var lamp := OmniLight3D.new()
		lamp.name = "CoolerLight"
		lamp.light_color = Color(0.85, 0.95, 1.0)
		lamp.light_energy = 0.9
		lamp.omni_range = 2.2
		lamp.shadow_enabled = false
		lamp.position = Vector3(0, 1.55, 0.05)
		lamp.visible = false
		cool.add_child(lamp)
		var doors: Array = []
		for d in cool.find_children("INT_CoolerDoor_*", "Node3D", true, false):
			var key := "market/%s/%s" % [cool.name, d.name]
			var it := Interactable.attach(d, {"kind": "hinge", "label": "Fridge", "state_key": key, "open_deg": 100.0, "anim_time": 0.5})
			var front := (cool as Node3D).global_transform * Vector3(0, 1.0, 1.6)
			it.open_deg = _toward_deg(d, 100.0, front)
			doors.append(it)
			interactables[key] = it
		for it in doors:
			it.used.connect(func(_b): lamp.visible = doors.any(func(x): return x.is_open))
		lamp.visible = doors.any(func(x): return x.is_open)


func _grocery_hint() -> void:
	if Game.has_flag("groceries_done"):
		return
	var parts := []
	var n := 0
	for id in GROCERIES:
		var got := Game.has_item(id)
		n += int(got)
		parts.append(("[x] " if got else "[  ] ") + GROCERIES[id])
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
	for i in need + EXTRAS:
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
		talk_shot(_dlg_time(["eddie_buy"]))
		Game.set_flag("game_bought")
	else:
		Dialogue.say("eddie_hello", false, true)



# ------------------------------------------------------------------ Phase 3: the Veil arrives (WORKING DRAFT)
## Beat order (all lines are "draft" in dialogue.json):
##   last errand done INSIDE a store -> the Veil rolls in, lights stutter, the cashier is gone
##   ("Something's wrong outside") -> the player steps out -> COLOSSUS ENCOUNTER: a gigantic leg slams down right
##   in front of them, cut to the protagonist's frightened face, the camera follows his gaze up the leg into the
##   mist ceiling (the body is never shown), the legs move on -> control back: GET BACK INSIDE THE STORE, health /
##   stamina appear, mist tentacles hunt in the street -> back inside -> Eddie + Marcus in the game shop ->
##   cross to the supermarket -> shut the jammed doors -> end of the build.
var atmos: Node
var _tentacles: Array = []
var _doors_powered := true
var _p3_shop_talked := false
var _p3_npcs_moved := false
var _encounter_running := false
var _enc_store: Node3D                       ## the store the player stepped out of
var enc_report := {}                         ## measured encounter facts (tests): foot error, body height, ...
var mist_ceiling: Node3D
var shut_it: Interactable

const MARCUS_SHOP_POS := Vector3(-3.6, 0.04, 4.4)        # game-shop local: between the wall shelf and the New Releases rack
const MARKET_EDDIE_POS := Vector3(-1.6, 0.04, 6.2)       # supermarket local, front of the sales floor, facing the doors
const MARKET_MARCUS_POS := Vector3(1.4, 0.04, 6.6)
const PROTAG_PATH := "res://THE_VEIL_ASSETS_V2/06_Characters/Protagonist/CHR_Protagonist.glb"
const PROTAG_FACE_PATH := "res://THE_VEIL_ASSETS_V2/06_Characters/Facial/Faces/T_Face_Protagonist.png"
const TENTACLE_AI := preload("res://game/enemies/tentacle_ai.gd")
const CEILING_SHADER := preload("res://game/world/mist_ceiling.gdshader")
const COLOSSUS_SCALE := 6.0                  ## presentation scale for the encounter (~60 m tall)
const CEILING_LAYERS := [9.0, 12.0, 15.5, 19.5]


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
	player.health_changed.connect(hud.set_health)
	player.stamina_changed.connect(hud.set_stamina)
	player.hurt.connect(func(a):
		hud.damage_flash(clampf(a / 25.0, 0.4, 1.0))
		Sfx.play("hurt", player.global_position + Vector3(0, 1.5, 0), -2.0))
	player.died.connect(_on_player_died)


func _outdoors() -> bool:
	var lm := market.to_local(player.global_position)
	if absf(lm.x) < 20.6 and lm.z > -0.4 and lm.z < 18.0:
		return false
	var ls := game_shop.to_local(player.global_position)
	if absf(ls.x) < 6.0 and ls.z > 0.1 and ls.z < 12.0:
		return false
	return true


func _p3_tick(_delta: float) -> void:
	if mist_ceiling:
		var cam := get_viewport().get_camera_3d()
		if cam:
			mist_ceiling.global_position = Vector3(cam.global_position.x, 0.0, cam.global_position.z)
	if not player.visible or in_car or _encounter_running:
		return
	if not Game.has_flag("p3_mist"):
		if Game.has_flag("groceries_done") and Game.has_flag("game_bought"):
			_p3_start_mist()
	elif not Game.has_flag("p3_stepped_out"):
		if _outdoors():
			_colossus_encounter()
	elif not Game.has_flag("p3_back_inside"):
		if not _outdoors():
			_p3_back_inside()
	elif _p3_shop_talked and not _p3_npcs_moved and _outdoors():
		_p3_flee_together()


func _atmo() -> Node:
	if atmos == null:
		atmos = (load(ATMOS_PATH) as PackedScene).instantiate()
		atmos.name = "VeilAtmosphere"
		add_child(atmos)
	return atmos.get_node("Atmosphere")


## The last errand is done: the Veil arrives while the player is still inside.
func _p3_start_mist() -> void:
	if Game.has_flag("p3_mist"):
		return
	Game.set_flag("phase2_done")
	Game.set_flag("p3_mist")
	hud.set_hint("")
	_clear_beacon("market")
	if cashier:
		cashier.visible = false                 # people are going missing
		interactables["market/cashier"].set_deferred("monitorable", false)
	for k in animators:
		animators[k].set_mood("scared")
	_atmo().apply_preset(night_preset("approach"))
	_build_mist_ceiling()
	Sfx.play("veil_rumble", player.global_position + Vector3(0, 2, 0), -2.0)
	_stutter_lights(market if market.to_local(player.global_position).z > -0.4 else game_shop)
	Dialogue.say("p3_fog", false, true)
	_p3_place_marcus_in_shop()                   # Marcus is in the game shop with Eddie before anything appears
	var sd: Interactable = interactables.get("shop/entrance")
	if sd and not sd.is_open:
		sd.set_open(true)
	if eddie and eddie.get_parent() == game_shop and animators.has("Eddie"):
		animators["Eddie"].walk_to([Vector3(0.9, 0.04, 7.5), Vector3(0.0, 0.04, 5.0), Vector3(-0.4, 0.04, 1.7), Vector3(-2.2, 0.04, 1.3)], 1.7)
	await get_tree().create_timer(5.0).timeout
	_atmo().apply_preset(night_preset("active"))


func _stutter_lights(store: Node3D) -> void:
	var ls: Array = store.get_node("Lights").get_children().filter(func(l): return l is Light3D)
	for i in 6:
		for l in ls:
			(l as Light3D).visible = (i % 2 == 1) or randf() < 0.3
		await get_tree().create_timer(randf_range(0.08, 0.22)).timeout
	for l in ls:
		(l as Light3D).visible = true


## A ceiling of slowly churning mist layers above the town (follows the camera). Seen from below it swallows
## anything taller than the houses: the Colossus's legs vanish upward into it.
func _build_mist_ceiling() -> void:
	if mist_ceiling:
		return
	mist_ceiling = Node3D.new()
	mist_ceiling.name = "MistCeiling"
	add_child(mist_ceiling)
	for i in CEILING_LAYERS.size():
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(320, 320)
		pm.subdivide_width = 0
		mi.mesh = pm
		var mat := ShaderMaterial.new()
		mat.shader = CEILING_SHADER
		mat.set_shader_parameter("density", 0.0)
		mat.set_shader_parameter("seed", float(i) * 7.31)
		mat.set_shader_parameter("tint", Color(0.24, 0.26, 0.27).lerp(Color(0.12, 0.13, 0.14), float(i) / 3.0))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = CEILING_LAYERS[i]
		mist_ceiling.add_child(mi)
		create_tween().tween_method(func(v): mat.set_shader_parameter("density", v), 0.0, 0.62 + 0.1 * i, 6.0)


# ------------------------------------------------------------------ the Colossus encounter
## Front-left claw tips in skeleton space at scale 1 (build_colossus.py LEGS "FL" contact (-6.1, 0, 6.0) and its
## three claws; tip y 0.11 minus the 0.05 tip radius).
const FL_TIPS := [Vector3(-5.55, 0.06, 7.06), Vector3(-6.15, 0.06, 7.52), Vector3(-6.7, 0.06, 6.77)]
const STANCE_RATE := 1.0                 ## Walk_Heavy: a planted foot slides back 1 m per animation second (scale 1)
var _enc_sounds: Array = []              ## encounter audio, faded out when the encounter ends


func _tips_world(sk: Skeleton3D, foot: int) -> Array:
	var rest := sk.get_bone_global_rest(foot)
	var pose := sk.get_bone_global_pose(foot)
	var out: Array = []
	for tp in FL_TIPS:
		out.append(sk.global_transform * (pose * (rest.affine_inverse() * tp)))
	return out


func _min_tip_y(sk: Skeleton3D, foot: int) -> float:
	var y := INF
	for p in _tips_world(sk, foot):
		y = minf(y, p.y)
	return y


## The animation time where the foot's swing ends: tips come back down to their stance height.
func _swing_end(ap: AnimationPlayer, sk: Skeleton3D, foot: int, anim: Animation) -> float:
	var dt := 1.0 / 60.0
	var t := 0.0
	var prev := INF
	var low := INF
	var ys: Array = []
	while t < anim.length:
		ap.seek(t, true)
		sk.force_update_all_bone_transforms()
		var y := _min_tip_y(sk, foot)
		ys.append([t, y])
		low = minf(low, y)
		t += dt
	for i in range(1, ys.size()):
		if ys[i - 1][1] > low + 0.05 and ys[i][1] <= low + 0.01:
			return ys[i][0]
	return 0.0


## Eddie and Marcus react to the impact: startled face, then fear, and they look towards it.
func _npc_fright(at: Vector3) -> void:
	for k in ["Eddie", "Marcus"]:
		if not animators.has(k):
			continue
		var a = animators[k]
		a.set_mood("scared")
		a.face_towards(at)
		a.talk(1.0)                                 # a startled flinch of the arms / head
		var f = faces.get(k)
		if f:
			f.set_expression("shocked")
			f.widen_eyes(2.0)
	await get_tree().create_timer(1.6).timeout
	for k in ["Eddie", "Marcus"]:
		var f = faces.get(k)
		if f:
			f.set_expression("scared")


func _enc_fade_sounds() -> void:
	for p in _enc_sounds:
		if p and is_instance_valid(p):
			var tw := (p as AudioStreamPlayer3D).create_tween()
			tw.tween_property(p, "volume_db", -60.0, 0.8)
			tw.tween_callback(p.queue_free)
	_enc_sounds.clear()


func _colossus_encounter() -> void:
	_encounter_running = true
	Game.set_flag("p3_stepped_out")
	_end_cine()
	_enc_store = market if player.global_position.distance_to(market.global_position) < player.global_position.distance_to(game_shop.global_position) else game_shop
	var door_in: Vector3 = (_enc_store.get_node("Doorways/Entrance_Inside") as Node3D).global_position
	var door_out: Vector3 = (_enc_store.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var n := (door_out - door_in) * Vector3(1, 0, 1)
	n = n.normalized()
	var side := n.cross(Vector3.UP).normalized()
	var P := player.global_position
	var ground := P.y
	var L := P + n * 8.5 + side * 1.6
	L.y = ground
	# --- Stage 1: something enormous moving (sound first), controls held
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	hud.allow_pause = false
	hud.set_hint("")
	_enc_sounds.append(Sfx.play("colossus_call", P + n * 14.0 + Vector3(0, 9, 0), 4.0, 0.8))   # close enough to be heard at once
	var cam := Camera3D.new()
	cam.name = "EncounterCam"
	add_child(cam)
	cam.global_transform = player.camera.global_transform
	cam.fov = player.camera.fov
	cam.far = 700.0
	cam.current = true
	# --- the creature: placed so its front-left foot lands exactly on L
	var c := (load(COLOSSUS_PATH) as PackedScene).instantiate() as Node3D
	c.name = "Colossus_Encounter"
	add_child(c)
	if c is CollisionObject3D:
		(c as CollisionObject3D).collision_layer = 0
		(c as CollisionObject3D).collision_mask = 0
	c.set_physics_process(false)
	var model := c.get_node("Model") as Node3D
	model.scale = Vector3.ONE * COLOSSUS_SCALE
	var walk_dir := side
	c.rotation.y = atan2(walk_dir.x, walk_dir.z)                 # the model faces +Z
	c.global_position = L
	var ap := c.get_node(String(c.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
	var sk := c.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var foot := sk.find_bone("Leg_FL_Foot")
	var body_b := sk.find_bone("Body")
	var anim := ap.get_animation("Walk_Heavy")
	anim.loop_mode = Animation.LOOP_LINEAR
	ap.play("Walk_Heavy", 0.0)
	# contact frame = the end of the front-left foot's swing, measured on its claw tips (the foot bone is the wrist,
	# 2.4 m up the leg; the old "lowest bone" pick landed mid-stance, so the foot never really came down on cue)
	var t_c := _swing_end(ap, sk, foot, anim)
	var place := func():
		ap.seek(t_c, true)
		sk.force_update_all_bone_transforms()
		var tips := _tips_world(sk, foot)
		var mid: Vector3 = (tips[0] + tips[1] + tips[2]) / 3.0
		var dy := _min_tip_y(sk, foot) - (ground + 0.02)        # claw tips rest on the road (2 cm)
		c.global_position += Vector3(L.x - mid.x, -dy, L.z - mid.z)
	place.call()
	# only the near leg may come down by the store: the other three feet must land farther out over the street;
	# if this rig's "left" is the other side, walk the other way (mirror) and place again
	var others := ["Leg_FR_Foot", "Leg_HL_Foot", "Leg_HR_Foot"].map(func(b): return sk.find_bone(b))
	var near_out := INF
	for b in others:
		near_out = minf(near_out, ((sk.global_transform * sk.get_bone_global_pose(b).origin) - P).dot(n))
	if near_out < (L - P).dot(n) + 2.0:
		walk_dir = -walk_dir
		c.rotation.y = atan2(walk_dir.x, walk_dir.z)
		place.call()
		near_out = INF
		for b in others:
			near_out = minf(near_out, ((sk.global_transform * sk.get_bone_global_pose(b).origin) - P).dot(n))
	enc_report["other_feet_min_out_m"] = near_out
	# the foot comes down along the clip's own swing arc: from late swing (high, in the mist) to contact
	const DESCENT := 0.75                                         # animation seconds of swing shown (1.5 s real)
	var t_lift := fposmod(t_c - DESCENT, anim.length)
	ap.seek(t_lift, true)
	ap.speed_scale = 0.5
	# the player instinctively looks at the sound / the darkness ahead
	var tw0 := create_tween()
	var b0 := cam.global_basis.get_rotation_quaternion()
	var b1 := Transform3D(Basis(), cam.global_position).looking_at(L + Vector3(0, 4.0, 0) + side * -1.0, Vector3.UP).basis.get_rotation_quaternion()
	tw0.tween_method(func(k): cam.global_basis = Basis(b0.slerp(b1, k * k * (3.0 - 2.0 * k))), 0.0, 1.0, 1.5)
	var guard := 0.0
	while fposmod(ap.current_animation_position - t_lift, anim.length) < DESCENT - 0.01 and guard < 3.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	ap.seek(t_c, true)                                            # exactly the contact frame
	# --- Stage 2: the footstep (impact) - sound, dust and shake on the contact frame
	sk.force_update_all_bone_transforms()
	var tips_now := _tips_world(sk, foot)
	var mid_now: Vector3 = (tips_now[0] + tips_now[1] + tips_now[2]) / 3.0
	enc_report["foot_error_m"] = Vector2(mid_now.x - L.x, mid_now.z - L.z).length()
	enc_report["foot_height_m"] = _min_tip_y(sk, foot) - ground
	enc_report["body_height_m"] = (sk.global_transform * sk.get_bone_global_pose(body_b).origin).y - ground
	enc_report["ceiling_m"] = CEILING_LAYERS[0]
	enc_report["leg_distance_m"] = Vector2(L.x - P.x, L.z - P.z).length()
	ap.speed_scale = 0.0                                          # planted: the weight comes down on it
	_enc_sounds.append(Sfx.play("colossus_step", L + Vector3(0, 1, 0), 6.0, 0.7))
	_impact_dust(L)
	_shake(cam, 0.35, 0.05)
	_npc_fright(L)
	for l in get_tree().get_nodes_in_group("veil_streetlight"):
		if l is Light3D and l.global_position.distance_to(L) < 45.0:
			(l as Light3D).visible = false
			get_tree().create_timer(randf_range(0.3, 1.2)).timeout.connect(func(): if is_instance_valid(l): l.visible = true)
	await get_tree().create_timer(0.9).timeout
	enc_report["foot_planted_drift_m"] = Vector2(_tips_world(sk, foot)[1].x - tips_now[1].x, _tips_world(sk, foot)[1].z - tips_now[1].z).length()
	# --- Stage 3: the protagonist's face (he is frozen; his eyes go up)
	var d_leg := (L - P) * Vector3(1, 0, 1)
	d_leg = d_leg.normalized()
	var me := _spawn_npc(load(PROTAG_PATH), load(PROTAG_FACE_PATH), self, P, atan2(-d_leg.x, -d_leg.z), "Protagonist")
	me.name = "Protagonist_Cine"
	var ma = animators["Protagonist"]
	ma.set_mood("scared")
	ma.turn_to_face = false
	ma.max_pitch = 1.05
	var gaze := Node3D.new()
	gaze.name = "Gaze"
	add_child(gaze)
	gaze.global_position = L + Vector3(0, 1.2, 0)
	ma.look_target = gaze
	faces["Protagonist"].set_expression("shocked")
	faces["Protagonist"].widen_eyes(2.5)
	var head: Vector3 = (ma.skel.global_transform * ma.skel.get_bone_global_pose(ma.bone("Head")).origin)
	var key := OmniLight3D.new()                                  # soft spill from the shop windows on his face
	key.light_color = Color(0.9, 0.86, 0.78)
	key.light_energy = 0.9
	key.omni_range = 3.0
	add_child(key)
	key.global_position = head + d_leg * 1.2 + side * 0.6 + Vector3(0, 0.3, 0)
	cam.global_position = head + d_leg * 1.05 + side * 0.42 - Vector3(0, 0.04, 0)
	cam.look_at(head + Vector3(0, 0.02, 0), Vector3.UP)
	cam.fov = 42.0
	enc_report["face_cam_distance_m"] = cam.global_position.distance_to(head)
	var tg := create_tween()
	tg.tween_property(gaze, "global_position", L + Vector3(0, 14.0, 0), 2.6).set_trans(Tween.TRANS_SINE)
	faces["Protagonist"].set_expression("scared")
	await get_tree().create_timer(2.8).timeout
	# --- Stage 4: from his eyes, up the leg into the mist. He is hidden for this shot (the camera sits where his
	# eyes are, so nothing of him can cut the frame); the view rotates only (one smooth quaternion slerp, no
	# per-step look_at flips), from a spot that can actually see the leg (moved out from under any awning)
	key.queue_free()
	me.visible = false
	var start := head + d_leg * 0.12
	var space := get_world_3d().direct_space_state
	for k in 7:
		var blocked := false
		for hgt in [3.0, 7.0, 11.0]:
			var q := PhysicsRayQueryParameters3D.create(start, L + Vector3(0, hgt, 0), 1, [player.get_rid()])
			if not space.intersect_ray(q).is_empty():
				blocked = true
		if not blocked:
			break
		start += d_leg * 0.5
	cam.global_position = start
	cam.fov = 60.0
	var look_from := L + Vector3(0, 1.0, 0)
	var look_to := L + Vector3(0, 40.0, 0) + d_leg * 6.0
	var qa := Transform3D(Basis(), start).looking_at(look_from, Vector3.UP).basis.get_rotation_quaternion()
	var qb := Transform3D(Basis(), start).looking_at(look_to, Vector3.UP).basis.get_rotation_quaternion()
	cam.global_basis = Basis(qa)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var e := k * k * (3.0 - 2.0 * k)
		cam.global_basis = Basis(qa.slerp(qb, e))
		cam.fov = lerpf(60.0, 50.0, e), 0.0, 1.0, 4.2)
	tg = create_tween()
	tg.tween_property(gaze, "global_position", L + Vector3(0, 40.0, 0), 4.0)
	await tw.finished
	enc_report["max_look_up_deg"] = rad_to_deg(asin(clampf((look_to - start).normalized().y, -1.0, 1.0)))
	# --- Stage 5: it moves on. The body moves at the clip's stance rate (1 m per animation second at scale 1),
	# so whichever foot is planted stays put while it walks off (no sliding); steps sound on their contacts
	ap.speed_scale = 0.5
	var speed: float = STANCE_RATE * COLOSSUS_SCALE * ap.speed_scale
	var away := c.create_tween()
	away.tween_property(c, "global_position", c.global_position + walk_dir * speed * 30.0, 30.0)
	away.tween_callback(c.queue_free)
	_enc_sounds.append(Sfx.play("colossus_step", L + walk_dir * 6.0, 4.0, 0.65))
	await get_tree().create_timer(2.0).timeout
	_enc_sounds.append(Sfx.play("colossus_step", L + walk_dir * 12.0, 2.0, 0.6))
	await get_tree().create_timer(1.6).timeout                  # frozen for a moment
	# --- Stage 6: back to the first person, eased (no snap); the encounter's sounds fade out with it
	gaze.queue_free()
	me.queue_free()
	animators.erase("Protagonist")
	faces.erase("Protagonist")
	player.set_yaw_pitch(atan2(-d_leg.x, -d_leg.z), deg_to_rad(8.0))
	var fp := player.camera.global_transform
	var tb := create_tween()
	tb.tween_property(cam, "global_transform", fp, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tb.parallel().tween_property(cam, "fov", player.camera.fov, 0.7)
	_enc_fade_sounds()
	await tb.finished
	cam.queue_free()
	player.camera.current = true
	player.controls_enabled = true
	hud.allow_pause = true
	_encounter_running = false
	# --- Stage 7: survival begins
	player.set_survival(true)
	hud.set_survival_visible(true)
	hud.title_card("GET BACK INSIDE THE STORE", 2.2)
	Dialogue.say("p3_colossus", false, true)
	_p3_spawn_tentacles()
	_beacon("store_back", door_out + Vector3(0, 2.4, 0), Color(0.75, 0.85, 1.0))
	save()


func _shake(cam: Camera3D, seconds: float, amount: float) -> void:
	var base := cam.global_position
	var t := 0.0
	while t < seconds and is_instance_valid(cam):
		var k := 1.0 - t / seconds
		cam.global_position = base + Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)) * amount * k
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(cam):
		cam.global_position = base


func _impact_dust(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "ImpactDust"
	p.one_shot = true
	p.amount = 60
	p.lifetime = 2.4
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 2.6
	p.emission_ring_inner_radius = 1.2
	p.emission_ring_height = 0.2
	p.emission_ring_axis = Vector3.UP
	p.direction = Vector3(0, 0.3, 0)
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -0.6, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.32, 0.33, 0.33, 0.5)
	qm.material = mat
	p.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.7))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	add_child(p)
	p.global_position = at + Vector3(0, 0.2, 0)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


func _p3_spawn_tentacles() -> void:
	if not _tentacles.is_empty():
		return
	var a: Vector3 = (game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var b: Vector3 = (market.get_node("Doorways/Entrance_Outside") as Node3D).global_position
	var side := (b - a).cross(Vector3.UP).normalized()
	var ts := load(TENTACLE_PATH) as PackedScene
	for k in [[0.3, 3.2], [0.52, -3.2], [0.75, 3.0]]:
		var t := ts.instantiate() as Node3D
		t.name = "MistTentacle_%d" % _tentacles.size()
		add_child(t)
		t.global_position = a.lerp(b, k[0]) + side * k[1]
		t.global_position.y = 0.15
		t.rotation.y = float(_tentacles.size()) * 2.1
		var ai: Node = TENTACLE_AI.new()
		ai.name = "AI"
		t.add_child(ai)
		ai.target = player
		ai.struck.connect(func(tn: Node3D, dmg: float):
			player.damage(dmg, tn.global_position)
			Sfx.play("tentacle_hiss", tn.global_position + Vector3(0, 1, 0), 0.0)
			Dialogue.say("p3_hit", false, true))
		if t.has_method("emerge"):
			t.emerge()
		_tentacles.append(t)


func _on_player_died() -> void:
	player.controls_enabled = false
	await hud.fade_to(1.0, 0.8)
	var store := _enc_store if _enc_store else game_shop
	var inside: Vector3 = (store.get_node("Doorways/Entrance_Inside") as Node3D).global_position
	var into := (inside - (store.get_node("Doorways/Entrance_Outside") as Node3D).global_position) * Vector3(1, 0, 1)
	player.global_position = inside + into.normalized() * 1.5 + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.health = 60.0
	player.stamina = player.MAX_STAMINA
	player.set_survival(true)
	await get_tree().create_timer(0.6).timeout
	hud.fade_to(0.0, 1.2)
	player.controls_enabled = true
	Dialogue.say("p3_wake_hurt", false, true)


func _p3_back_inside() -> void:
	Game.set_flag("p3_back_inside")
	_clear_beacon("store_back")
	_p3_place_marcus_in_shop()
	if _enc_store == game_shop or game_shop.to_local(player.global_position).z > 0.1 and absf(game_shop.to_local(player.global_position).x) < 6.0:
		_p3_reach_shop()
	else:
		# sheltering in the supermarket first: Eddie calls everyone over to the game shop
		_beacon("shop", (game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position + Vector3(0, 2.4, 0), Color(0.7, 0.85, 1.0))
		await get_tree().create_timer(2.5).timeout
		if not Game.has_flag("p3_in_shop"):
			Dialogue.say("p3_eddie_calls", false, true)


func _p3_car_dead() -> void:
	if not Game.has_flag("p3_mist"):
		_p3_start_mist()
	Sfx.play("static", sedan.global_position + Vector3(0, 1, 0), -4.0)
	Dialogue.say("p3_car_again" if Game.has_flag("said_p3_car_dead_once") else "p3_car_dead", false, true)
	Game.flags["said_p3_car_dead_once"] = true


func _p3_place_marcus_in_shop() -> void:
	if marcus == null:
		marcus = _spawn_npc(load(MARCUS_PATH), load(MARCUS_FACE_PATH), game_shop, MARCUS_SHOP_POS, 0.0, "Marcus")
		animators["Marcus"].set_mood("scared")
		var m_it := Interactable.attach(marcus, {"kind": "custom", "label": "Marcus", "prompt_text": "[E] Talk"})
		m_it.used.connect(func(_b): Dialogue.say("p3_marcus_talk", false, true))
		interactables["p3/marcus"] = m_it


func _p3_reach_shop() -> void:
	if not Game.has_flag("p3_back_inside") or Game.has_flag("p3_in_shop"):
		return
	Game.set_flag("p3_in_shop")
	_clear_beacon("shop")
	_p3_place_marcus_in_shop()
	Dialogue.say("p3_shop", false, true)
	var total := _dlg_time(["p3_shop"])
	talk_shot(total + 0.3 + _dlg_time(["p3_eddie_go"]))
	await get_tree().create_timer(total + 0.3).timeout
	Dialogue.say("p3_eddie_go")
	_p3_shop_talked = true
	# both get ready by the front of the shop: they leave with the protagonist (_p3_flee_together)
	if animators.has("Eddie") and eddie.get_parent() == game_shop:
		npc_walk("Eddie", Vector3(-1.6, 0.04, 1.7), 1.6)
	if animators.has("Marcus") and marcus.get_parent() == game_shop:
		npc_walk("Marcus", Vector3(-2.4, 0.04, 2.4), 1.6)
	_beacon("market", market.global_transform * Vector3(0, 2.6, -0.9), Color(0.7, 0.85, 1.0))


## After the shop talk, once the player is outside: Eddie and Marcus run WITH the protagonist to the supermarket
## (the existing companion follow, breadcrumbs of the player's own path: no wall clipping, no teleport).
var _p3_followers: Array = []


func _p3_flee_together() -> void:
	_p3_npcs_moved = true
	for pair in [[eddie, 1.6], [marcus, 2.8]]:
		var n: Node3D = pair[0]
		if n == null:
			continue
		n.reparent(self, true)
		var f := VeilCompanionFollow.new()
		f.name = "Follow"
		f.gap = pair[1]
		f.walk_speed = 2.2                              # a frightened jog
		f.run_speed = 4.2
		n.add_child(f)
		f.setup(n, player)
		f.start()
		# the way out is through the shop door: seed the trail with it so nobody cuts through the shop front
		var din: Vector3 = (game_shop.get_node("Doorways/Entrance_Inside") as Node3D).global_position
		var dout: Vector3 = (game_shop.get_node("Doorways/Entrance_Outside") as Node3D).global_position
		if game_shop.to_local(n.global_position).z > 0.2:
			f.trail = [n.global_position, din, dout]
		_p3_followers.append(f)
		if animators.has(String(n.name)):
			animators[String(n.name)].set_mood("scared")


func _p3_stop_following() -> void:
	for f in _p3_followers:
		if is_instance_valid(f):
			f.stop()
			f.queue_free()
	_p3_followers.clear()
	for n in [eddie, marcus]:
		if n and n.get_parent() != market:
			n.reparent(market, true)


## Walk an NPC (its parent's local frame) to `to` around furniture and walls: npc_route() on the real colliders.
func npc_walk(speaker: String, to: Vector3, speed := 1.3) -> void:
	var a = animators.get(speaker)
	if a == null:
		return
	var par := a.root.get_parent_node_3d() as Node3D
	a.walk_to(npc_route(par, a.root.position, to), speed)


## Grid A* (0.3 m cells, a 0.28 m body radius at knee and chest height, layer-1 colliders) in `frame`'s local XZ,
## then string-pulled with sphere sweeps. Returns frame-local waypoints ending at `to` (straight line if no path).
func npc_route(frame: Node3D, from: Vector3, to: Vector3) -> Array:
	var space := get_world_3d().direct_space_state
	var sph := SphereShape3D.new()
	sph.radius = 0.28
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var X := frame.global_transform
	var y := from.y
	var CELL := 0.3
	var lo := Vector2(minf(from.x, to.x) - 6.0, minf(from.z, to.z) - 6.0)
	var cache := {}
	var free_at := func(c: Vector2i) -> bool:
		if cache.has(c):
			return cache[c]
		var p := Vector3(lo.x + c.x * CELL, y, lo.y + c.y * CELL)
		var ok := true
		for h in [0.5, 1.3]:
			q.transform = Transform3D(Basis(), X * (p + Vector3(0, h, 0)))
			if not space.intersect_shape(q, 1).is_empty():
				ok = false
				break
		cache[c] = ok
		return ok
	var cell_of := func(p: Vector3) -> Vector2i: return Vector2i(roundi((p.x - lo.x) / CELL), roundi((p.z - lo.y) / CELL))
	var s: Vector2i = cell_of.call(from)
	var g: Vector2i = cell_of.call(to)
	var w := int((maxf(from.x, to.x) + 6.0 - lo.x) / CELL) + 1
	var hgt := int((maxf(from.z, to.z) + 6.0 - lo.y) / CELL) + 1
	var open := {s: 0.0}
	var cost := {s: 0.0}
	var came := {}
	var found := false
	var it := 0
	while not open.is_empty() and it < 9000:
		it += 1
		var cur: Vector2i = s
		var best := INF
		for k in open:
			if open[k] < best:
				best = open[k]
				cur = k
		open.erase(cur)
		if (cur - g).length_squared() <= 1:
			g = cur
			found = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var nb: Vector2i = cur + d
			if nb.x < 0 or nb.y < 0 or nb.x >= w or nb.y >= hgt or not free_at.call(nb):
				continue
			if d.x != 0 and d.y != 0 and (not free_at.call(Vector2i(cur.x + d.x, cur.y)) or not free_at.call(Vector2i(cur.x, cur.y + d.y))):
				continue
			var nc: float = cost[cur] + (1.414 if d.x != 0 and d.y != 0 else 1.0)
			if not cost.has(nb) or nc < cost[nb]:
				cost[nb] = nc
				came[nb] = cur
				open[nb] = nc + Vector2(nb - g).length()
	if not found:
		return [to]
	var cells: Array = [g]
	while cells[0] != s and came.has(cells[0]):
		cells.push_front(came[cells[0]])
	var pts: Array = []
	for c in cells:
		pts.append(Vector3(lo.x + c.x * CELL, y, lo.y + c.y * CELL))
	pts[-1] = to
	# string pulling: keep only the waypoints needed for a clear sphere sweep between them
	var out: Array = []
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1:
			q.transform = Transform3D(Basis(), X * (pts[i] + Vector3(0, 0.8, 0)))
			q.motion = X.basis * (pts[j] - pts[i])
			var r := space.cast_motion(q)
			q.motion = Vector3.ZERO
			if r.size() > 0 and r[0] >= 1.0:
				break
			j -= 1
		out.append(pts[j])
		i = j
	return out


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
	_p3_stop_following()                         # they came in with the player
	Game.set_flag("p3_in_market")
	_set_auto_doors(true)                       # the power dies with the doors open
	_doors_powered = false
	for l in market.get_node("Lights").get_children():
		if l is Light3D and String(l.name).begins_with("Light_"):
			(l as Light3D).light_energy *= 0.35
	shut_it.prompt_text = "[E] Pull the Doors Shut"
	npc_walk("Eddie", Vector3(-1.0, 0.04, 4.3), 1.4)           # around the vestibule wall, carts and baskets
	npc_walk("Marcus", Vector3(1.1, 0.04, 4.7), 1.4)
	for d in _auto_doors:
		_glow(d[0], true, Color(0.7, 0.85, 1.0))
	Dialogue.say("p3_market", false, true)
	talk_shot(_dlg_time(["p3_market"]))


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
		var ai = t.get_node_or_null("AI") if is_instance_valid(t) else null
		if ai:
			ai.set_process(false)
	Dialogue.say("p3_doors", false, true)
	Game.set_flag("p3_doors_shut")
	_start_phase4(false)            # Phase 4 continues the night inside (game/world/phase4.gd)


## Rebuild Phase 3 state after loading a save.
func _p3_restore() -> void:
	if not Game.has_flag("p3_mist"):
		return
	if cashier:
		cashier.visible = false
		interactables["market/cashier"].set_deferred("monitorable", false)
	_clear_beacon("market")
	_atmo().apply_preset(night_preset("active"), true)
	_build_mist_ceiling()
	for k in animators:
		animators[k].set_mood("scared")
	if Game.has_flag("p3_stepped_out"):
		player.set_survival(true)
		hud.set_survival_visible(true)
		if not Game.has_flag("p3_doors_shut"):
			_p3_spawn_tentacles()
	_p3_place_marcus_in_shop()
	if Game.has_flag("p3_in_shop"):
		_p3_shop_talked = true
		_p3_move_npcs_to_market()
	if Game.has_flag("p3_in_market") and not Game.has_flag("p3_doors_shut"):
		_doors_powered = true
		_set_auto_doors(true)
		_doors_powered = false
		shut_it.prompt_text = "[E] Pull the Doors Shut"


# ------------------------------------------------------------------ night (Friday ~7 PM, dark)
const PRESET_SCRIPT := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Atmosphere_Presets/veil_atmosphere_preset.gd"
var headlights: Array = []


## Game-side presets for the Pack 09 atmosphere controller (the pack's own presets stay untouched):
##   night    - ordinary small town at night: dark navy sky, dim cool ambient, lamps carry the light
##   approach - the Veil rolling in: dark grey-green haze, low mist sheets
##   active   - the Veil: dense, DARK depth fog (distant shapes sink into darkness instead of turning flat
##              light grey), thick ground layer, mist sheets; nearby things stay readable under the lamps
func night_preset(kind: String) -> Resource:
	var p: Resource = (load(PRESET_SCRIPT) as Script).new()
	p.set("preset_name", "NIGHT_" + kind.to_upper())
	p.set("sky_top", Color(0.012, 0.016, 0.04))
	p.set("sky_horizon", Color(0.06, 0.065, 0.1))
	p.set("ground_horizon", Color(0.035, 0.035, 0.045))
	p.set("ground_bottom", Color(0.01, 0.01, 0.012))
	p.set("ambient_color", Color(0.17, 0.19, 0.27))
	p.set("ambient_energy", 0.42)
	p.set("sun_color", Color(0.55, 0.62, 0.85))
	p.set("sun_energy", 0.16)
	p.set("sun_pitch", -38.0)
	p.set("sun_yaw", 200.0)
	p.set("sun_shadows", true)
	p.set("shadow_distance", 40.0)
	p.set("fog_color", Color(0.035, 0.04, 0.065))
	p.set("fog_density", 0.006)
	p.set("fog_sky_affect", 0.5)
	p.set("streetlight_energy", 1.0)
	match kind:
		"approach":
			p.set("ambient_color", Color(0.15, 0.17, 0.2))
			p.set("fog_color", Color(0.06, 0.07, 0.075))
			p.set("fog_density", 0.022)
			p.set("fog_height", 2.0)
			p.set("fog_height_density", 0.03)
			p.set("fog_sky_affect", 0.85)
			p.set("mist_enabled", true)
			p.set("mist_color", Color(0.26, 0.29, 0.29))
			p.set("mist_density", 0.35)
			p.set("mist_height", 1.8)
			p.set("mist_cards", 12)
			p.set("flicker_amount", 0.3)
			p.set("sun_energy", 0.1)
		"active":
			p.set("sky_top", Color(0.03, 0.035, 0.04))
			p.set("sky_horizon", Color(0.07, 0.08, 0.08))
			p.set("ambient_color", Color(0.14, 0.16, 0.19))
			p.set("ambient_energy", 0.46)
			p.set("fog_color", Color(0.075, 0.085, 0.09))
			p.set("fog_density", 0.05)
			p.set("fog_height", 3.0)
			p.set("fog_height_density", 0.06)
			p.set("fog_sky_affect", 1.0)
			p.set("mist_enabled", true)
			p.set("mist_color", Color(0.3, 0.33, 0.33))
			p.set("mist_density", 0.75)
			p.set("mist_height", 2.4)
			p.set("mist_cards", 24)
			p.set("flicker_amount", 0.6)
			p.set("streetlight_energy", 0.8)
			p.set("sun_energy", 0.06)
			p.set("sun_shadows", false)
			p.set("corruption_level", 2)
	return p


func _setup_night() -> void:
	# 1) a lamp on every street-lamp post (a few posts had no light); offset learned from posts that have one
	var lamps: Array = []
	var lights: Array = []
	for part in ["Core", "Extension"]:
		for n in get_node(part).find_children("SP_Lamp_*", "Node3D", true, false):
			if String(n.name).begins_with("SP_Lamp_Residential") or String(n.name).begins_with("SP_Lamp_Commercial"):
				if n.get_parent() and not String(n.get_parent().name).begins_with("SP_Lamp_"):
					lamps.append(n)
		for l in get_node(part).find_children("StreetLight_*", "OmniLight3D", true, false):
			lights.append(l)
	var offs := {}
	for l in lights:
		var best: Node3D = null
		var bd := 3.5
		for lp in lamps:
			var d := Vector2(lp.global_position.x - l.global_position.x, lp.global_position.z - l.global_position.z).length()
			if d < bd:
				bd = d
				best = lp
		if best:
			offs[String(best.name).get_slice("_0", 0)] = best.global_transform.affine_inverse() * l.global_position
	var added := 0
	for lp in lamps:
		var has := lights.any(func(l): return Vector2(lp.global_position.x - l.global_position.x, lp.global_position.z - l.global_position.z).length() < 3.5)
		if has:
			continue
		var off: Vector3 = offs.get(String(lp.name).get_slice("_0", 0), Vector3(0, 5.75, 0))
		var nl := OmniLight3D.new()
		nl.name = "StreetLight_auto_%d" % added
		nl.light_color = Color(1, 0.8, 0.55)
		add_child(nl)
		nl.global_position = lp.global_transform * off
		lights.append(nl)
		added += 1
	# 2) lamps carry the night: brighter pools on the road, faded out with distance (cheap on the GL renderer)
	for l in lights:
		var ol := l as OmniLight3D
		ol.light_energy = 2.1
		ol.omni_range = 15.0
		ol.omni_attenuation = 1.15
		ol.shadow_enabled = false
		ol.distance_fade_enabled = true
		ol.distance_fade_begin = 75.0
		ol.distance_fade_length = 25.0
		ol.add_to_group("veil_streetlight")
	# 3) storefront / canopy lights a little stronger; interior lights already show through the windows
	for part in ["Commercial"]:
		for l in get_node(part).find_children("ExtLight_*", "OmniLight3D", true, false):
			(l as OmniLight3D).light_energy = 1.5
			(l as OmniLight3D).omni_range = 9.0
	# 4) sedan headlights + tail lights
	var box := Interactable.aabb_of(sedan)
	var zf := box.position.z if box.size.length() > 0.5 else -2.2
	var zb := box.end.z if box.size.length() > 0.5 else 2.2
	for sx in [-1.0, 1.0]:
		var h := SpotLight3D.new()
		h.name = "Headlight_%s" % ("L" if sx < 0 else "R")
		h.light_color = Color(1.0, 0.93, 0.78)
		h.light_energy = 3.2
		h.spot_range = 42.0
		h.spot_angle = 27.0
		h.spot_attenuation = 0.9
		h.spot_angle_attenuation = 1.6
		h.shadow_enabled = false
		h.position = Vector3(sx * 0.58, 0.68, zf + 0.05)
		h.rotation.x = deg_to_rad(-4.0)
		sedan.add_child(h)
		headlights.append(h)
		var t := OmniLight3D.new()
		t.name = "TailLight_%s" % ("L" if sx < 0 else "R")
		t.light_color = Color(1.0, 0.12, 0.08)
		t.light_energy = 0.5
		t.omni_range = 1.8
		t.position = Vector3(sx * 0.6, 0.75, zb + 0.08)
		sedan.add_child(t)
	# 5) the night sky / ambient / fog through the Pack 09 controller (it takes over the Core environment)
	_atmo().apply_preset(night_preset("night"), true)
	print("[World] night: %d street lights (%d added)" % [lights.size(), added])


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
	# drive-by arrival shot: the road right in front of the supermarket (Main St, heading west)
	_area("Trigger_ArrivalShot", market.global_transform * Vector3(-6.0, 1.0, -27.0), Vector3(16, 6, 12), 4, func(b):
		if b == sedan and in_car and sedan.driven and not Game.has_flag("arrival_shot"):
			_arrival_shot(), market.global_transform.basis)
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
	if Game.has_flag("p3_doors_shut"):
		_start_phase4.call_deferred(true)
	return true


# ------------------------------------------------------------------ Phase 4 hook (the chapter lives in phase4.gd)
var phase4: Node


func _start_phase4(restoring: bool) -> void:
	if phase4 != null:
		return
	phase4 = load("res://game/world/phase4.gd").new()
	phase4.name = "Phase4"
	add_child(phase4)
	phase4.begin(self, restoring)


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
