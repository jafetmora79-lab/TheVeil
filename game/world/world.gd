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
var fog_zones: Node
var drive_time := 0.0
var _park_t := 0.0
var _ending := false
var interactables := {}


func _ready() -> void:
	add_to_group("veil_world")
	Sfx.play_music(Sfx.MUSIC_GAMEPLAY, true, -14.0, 2.5)     # in-game exploration (seamless loop)
	# a conversation cut off by a load / quit never resumes half-way: no queued lines, no confirm mode, no lock
	Dialogue.clear()
	Dialogue.confirm_mode = false
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
	sedan.radio_changed.connect(func(station: String):
		hud.set_hint("RADIO — " + (station if station != "" else "OFF"))
		get_tree().create_timer(2.5).timeout.connect(func(): if in_car and hud: hud.set_hint("W accelerate · S brake / reverse · A/D steer · Space handbrake · Q radio · E exit")))
	sedan.name = "Sedan"
	add_child(sedan)
	sedan.global_transform = (home.get_node("Markers/Sedan_Driveway") as Node3D).global_transform
	sedan.global_position.y += 0.05
	sedan.entry_area.used.connect(func(_b): enter_car())
	sedan.speed_changed.connect(hud.set_speed)
	for furniture in find_children("Furnishing", "Node3D", true, false):
		for collider in furniture.find_children("*", "CollisionObject3D", true, false):
			collider.add_to_group("veil_furniture")
	_setup_home()
	_setup_town()
	_setup_triggers()
	expedition = EXPEDITION.new()
	expedition.name = "Expedition"
	add_child(expedition)
	expedition.setup.call_deferred(self)
	survivors = SURVIVORS.new()
	survivors.name = "Survivors"
	add_child(survivors)
	survivors.setup.call_deferred(self)
	# a hidden Easter egg in the woods before town (isolated: game/easter_egg/)
	var egg: Node = load("res://game/easter_egg/golden_peek.gd").new()
	egg.name = "EasterEggGolden"
	add_child(egg)
	egg.setup.call_deferred(self)
	# an optional rooftop Skitter at a house in town (after the mist; once; isolated: game/encounters/)
	var roof_egg: Node = load("res://game/encounters/roof_skitter.gd").new()
	roof_egg.name = "OptionalRoofSkitterEncounter"
	add_child(roof_egg)
	roof_egg.setup.call_deferred(self)
	# the store manager's handgun (self-defence on supply runs; game/world/sidearm.gd)
	sidearm = load("res://game/world/sidearm.gd").new()
	sidearm.name = "Sidearm"
	add_child(sidearm)
	sidearm.setup.call_deferred(self)
	# navigation help: the way back to the shelter, and the town map on M (game/ui/nav_map.gd)
	nav = load("res://game/ui/nav_map.gd").new()
	nav.name = "NavMap"
	add_child(nav)
	nav.setup.call_deferred(self)
	# the generated walk / driveway paving lay 1 cm above the sidewalks and the intersection near the game shop
	# (coplanar enough to flicker): it now tucks 3 cm lower, under them, where they overlap
	var lc := find_child("RES_LotConnections_Game", true, false) as Node3D
	if lc and not lc.has_meta("tucked"):
		lc.set_meta("tucked", true)
		lc.position.y -= 0.03
	# floating arrows at the turns of the opening drive (game/world/road_arrows.gd)
	var ra = load("res://game/world/road_arrows.gd").new()
	ra.name = "RoadArrows"
	add_child(ra)
	ra.setup.call_deferred(self)
	var sf = load("res://game/world/sign_fix.gd").new()             # no mirrored text anywhere
	sf.name = "SignFix"
	add_child(sf)
	var og = load("res://game/world/opening_guide.gd").new()      # the opening: markers, the front door, reminders
	og.name = "OpeningGuide"
	add_child(og)
	og.setup.call_deferred(self)
	var fz = load("res://game/world/fog_zones.gd").new()           # lighter fog underground and by the station
	fz.name = "FogZones"
	add_child(fz)
	fz.setup.call_deferred(self)
	fog_zones = fz
	var sm = load("res://game/world/store_markers.gd").new()       # [E] over the store's real interactions
	sm.name = "StoreMarkers"
	add_child(sm)
	sm.setup.call_deferred(self)
	_apply_view_ranges()
	_setup_night()
	_light_budget_all()
	# the filler ground (TOWN_Ground_Game) was coplanar with the parking lots / drives laid over it (both at LOT_Y),
	# so where a ground cell was only partly covered the two z-fought (the brown strips in the supermarket lot).
	# It sits 5 cm lower now: paved surfaces always win (1.5 cm still flickered at a distance and at grazing angles,
	# with the camera's 4 cm near plane); walking is unaffected.
	var tg := find_child("TOWN_Ground_Game", true, false) as Node3D
	if tg:
		tg.position.y -= GROUND_DROP
		ground_dropped = true
	get_tree().node_added.connect(_on_node_added)
	Game.flag_set.connect(_on_flag)
	Sfx.start_ambience()
	VeilStairAssist.apply(get_node("Residential/Houses"))     # solid stair collision over the two-storey houses
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
	# items picked up are saved straight away (only flags used to save: anything found after the last story step
	# was lost on Continue). Not before the restore above, which must read the saved player state first.
	_world_live = true
	Game.inventory_changed.connect(_save_soon)


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
	player.play_wake_up(4.6, false)
	await get_tree().create_timer(1.0).timeout
	hud.chapter_start(1, 2.8)                     # CHAPTER 1 (upper screen) with the time card below it
	hud.title_card("FRIDAY  —  6:42 PM", 2.4)
	await hud.fade_to(0.0, 3.0)
	Dialogue.say("wake", true)
	await get_tree().create_timer(0.7).timeout       # the wake-up look-around ends (4.6 s): straight into the wash
	await bathroom.wash_face()                       # first: the bathroom, a splash of water, the mirror
	player.controls_enabled = true                   # control only now (also if the wash was already done)
	player.look_enabled = true
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


var bathroom: VeilHomeBathroom
func _setup_home() -> void:
	bathroom = VeilHomeBathroom.new()                 # bathroom layout + working mirror + the first-day wash
	bathroom.name = "HomeBathroom"
	add_child(bathroom)
	bathroom.setup(self, home)
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
const CASHIER_AT := Vector3(-4.85, 0.04, 4.0)     ## market-local: behind lane 4's register (x -4.1), between the lanes


## The checkout is only there while it means something: paid (groceries_done) -> no prompt; the cashier gone
## (the Veil, p3_mist) -> hidden and not interactable at all (also after a load).
func _cashier_state() -> void:
	var it: Interactable = interactables.get("market/cashier")
	if it == null:
		return
	if Game.has_flag("groceries_done") or Game.has_flag("p3_mist"):
		it.prompt_text = ""
	if Game.has_flag("p3_mist"):
		if cashier:
			cashier.visible = false
		it.collision_layer = 0
		it.set_deferred("monitorable", false)
var marcus: Node3D
var faces := {}               ## speaker name -> VeilFace (talks on that speaker's dialogue lines)
var animators := {}           ## speaker name -> NpcAnimator (procedural body: idle, look-at, gestures, walk)
var _auto_doors: Array = []
var _beacons := {}
var _in_market := false
var _auto_open := false


## LIGHT BUDGET (root cause of the inconsistent lighting). The Compatibility renderer draws at most
## max_renderable_lights per frame and max_lights_per_object per mesh; the excess is silently dropped in an order
## that changes with the camera. The town had 160 lights and 87 omni lights with no distance fade, so 90-112 of
## them competed from anywhere in town against a cap of 32: stores, houses and street lamps blinked in and out
## depending on where you stood. Every omni / spot light now fades out with distance (interiors sooner than street
## lamps) so only nearby lights compete, and project.godot raises the caps (64 per frame, 16 per object) so a
## large mesh near several lamps keeps all of them. Nothing is brightened: energies are untouched.
const LIGHT_FADE_INTERIOR := Vector2(26.0, 10.0)      # begin, length (m) for lights with range <= 8 m
const LIGHT_FADE_EXTERIOR := Vector2(40.0, 12.0)


const GROUND_DROP := 0.05
var ground_dropped := false


func _light_budget(l: Light3D) -> void:
	if l is DirectionalLight3D or l.distance_fade_enabled:
		return
	var rng: float = (l as OmniLight3D).omni_range if l is OmniLight3D else ((l as SpotLight3D).spot_range if l is SpotLight3D else 10.0)
	var f := LIGHT_FADE_INTERIOR if rng <= 8.0 else LIGHT_FADE_EXTERIOR
	l.distance_fade_enabled = true
	l.distance_fade_begin = f.x
	l.distance_fade_length = f.y
	l.distance_fade_shadow = f.x * 0.6


func _light_budget_all() -> void:
	for l in find_children("*", "Light3D", true, false):
		_light_budget(l as Light3D)


func _on_node_added(n: Node) -> void:
	if n is Light3D and is_ancestor_of(n):
		_light_budget.call_deferred(n)            # after the spawner has set its range


## Window glass: the panes are a material inside each building's exterior mesh and had no collision above the sills,
## so cameras and line-of-sight checks went straight through them (Eddie "talking through the glass"). Thin static
## boxes from game/data/glass_panes.json (extracted from the GLBs by game/tools/extract_glass.py) close them.
func _add_glass_colliders() -> void:
	var f := FileAccess.open("res://game/data/glass_panes.json", FileAccess.READ)
	if f == null:
		return
	var panes: Dictionary = JSON.parse_string(f.get_as_text())
	var n := 0
	for node in get_node("Commercial").find_children("*", "Node3D", true, false):
		var src: String = node.scene_file_path
		if src == "" or not panes.has(src):
			continue
		var body := StaticBody3D.new()
		body.name = "GlassPanes"
		body.collision_layer = 1
		body.collision_mask = 0
		node.add_child(body)
		for b in panes[src]:
			var mn := Vector3(b[0][0], b[0][1], b[0][2])
			var mx := Vector3(b[1][0], b[1][1], b[1][2])
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = (mx - mn).max(Vector3.ONE * 0.04)
			cs.shape = bs
			cs.position = (mn + mx) * 0.5
			body.add_child(cs)
			n += 1
	glass_panes = n


var glass_panes := 0
var _light_glass: Dictionary = {}


## Story-critical windows (the game shop front, the mill house): the dirty glass keeps its texture and PSX look but
## its grime is thinned, so what is behind it reads. Material swap only (shared, cached) - no new transparency cost.
func clear_story_glass(root: Node) -> void:
	if root == null:
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null or not m.resource_name.contains("WindowGlassDirty"):
				continue
			var light: StandardMaterial3D = _light_glass.get(m)
			if light == null:
				light = m.duplicate() as StandardMaterial3D
				light.albedo_color = Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b, m.albedo_color.a * 0.4)
				_light_glass[m] = light
			mi.set_surface_override_material(i, light)


## The parking-lot edge piece right in front of the supermarket entrance carries a strip of dry grass that reads as
## a stray patch on the forecourt: its grass surface gets the sidewalk concrete instead.
func _pave_forecourt() -> void:
	var conc := load("res://THE_VEIL_ASSETS_V2/Materials_Godot/Roads/M_Road_SidewalkConcrete.tres")
	for mi in find_children("SW_ParkingLotEdge_10m_Mesh", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.global_position.distance_to(market.global_position) > 14.0 or m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i)
			if src and String(src.resource_path).contains("Grass") and conc:
				m.set_surface_override_material(i, conc)


## The lot modules' concrete wheel stops (10 cm, centred in each stall of the far row) had no collision: the car
## drove through them. Each gets a box on its own layer (64), which only the car checks - people step over them.
func _wheel_stop_colliders() -> void:
	for lot in find_children("RD_ParkingLot_10x20m*", "Node3D", true, false):
		var body := StaticBody3D.new()
		body.name = "WheelStops"
		body.collision_layer = 64
		body.collision_mask = 0
		lot.add_child(body)
		for x in [-3.75, -1.25, 1.25, 3.75]:
			for z in [19.1]:                     # (the far row; the street-side row has no stops - cars cross it)
				var cs := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				bx.size = Vector3(1.7, 0.1, 0.16)
				cs.shape = bx
				cs.position = Vector3(x, 0.2, z)
				body.add_child(cs)


func _setup_town() -> void:
	market = get_node("Commercial/SUPERMARKET")
	game_shop = get_node("Commercial/GAME_SHOP")
	clear_story_glass(game_shop)
	_pave_forecourt.call_deferred()
	_wheel_stop_colliders()
	_add_glass_colliders()
	# supermarket: bi-parting automatic doors open while the player stands in front of / inside the vestibule
	for side in [["L", -1.0], ["R", 1.0]]:
		var leaf := market.get_node("Building").find_child("INT_AutoDoor_Entrance_" + side[0], true, false) as Node3D
		if leaf:
			_auto_doors.append([leaf, leaf.transform, Vector3(side[1] * 1.12, 0, 0)])
	var sensor := _area("Trigger_MarketDoors", market.global_transform * Vector3(0, 1.2, 0.2), Vector3(4.4, 2.4, 5.0), 2,
		func(b): if b == player or b is VeilSurvivorBody: _set_auto_doors(true), market.global_transform.basis)
	sensor.body_exited.connect(func(b):
		if (b == player or b is VeilSurvivorBody) and not sensor.get_overlapping_bodies().any(func(o): return o != b and (o == player or o is VeilSurvivorBody)):
			_set_auto_doors(false))                   # shut only once nobody is in the doorway
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
	# Stand just off the lane 4 approach, with a clear interaction line from the aisle.
	cashier = _spawn_npc(CASHIER, CASHIER_FACE, market, CASHIER_AT, -PI * 0.5, "Cashier")
	_place_exact(cashier, market.to_global(CASHIER_AT))       # behind lane 4's till (Register_45), facing the lane
	var c_it := Interactable.attach(cashier, {"kind": "custom", "label": "Cashier", "prompt_text": "[E] Pay for Groceries"})
	var c_cs := c_it.get_child(0) as CollisionShape3D
	(c_cs.shape as BoxShape3D).size = (c_cs.shape as BoxShape3D).size.max(Vector3(3.4, 1.8, 3.4))   # reachable across the belt
	c_it.used.connect(_checkout)
	interactables["market/cashier"] = c_it
	_cashier_state()
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
	var eddie_at := Vector3(behind.position.x, 0.04, behind.position.z) if behind else Vector3(2.8, 0.04, 7.5)
	eddie = _spawn_npc(EDDIE, EDDIE_FACE, game_shop, eddie_at, 0.0, "Eddie")
	if not Game.has_flag("p3_mist"):
		_place_exact(eddie, game_shop.to_global(eddie_at))              # behind his counter, as before
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


## STANDARD NPC CONVERSATION - the one shared path for every spoken exchange with an NPC in Chapters 1-8.
## converse(ids, npcs):
##   1. refuses (returns false) only when a wall, door or window really separates the player from the NPC spoken
##      to (several sight lines: head, face, chest; one clear line is enough, so a door frame no longer blocks it);
##   2. the player stops (velocity 0, movement and interaction locked) and the NPCs turn to face the protagonist;
##   3. the talk camera stays at the protagonist's own eye position (it never moves toward the NPC, so it cannot
##      clip into a head, a counter or a wall) and only turns toward the current speaker's face and upper body,
##      with a subtle zoom (FOV -10 %) over ~0.4 s; a new speaker gets a gentler re-aim;
##   4. VeilFace talking + gestures play (_on_line); speaker name + subtitle on the HUD;
##   5. every line waits for the player (Dialogue.confirm_mode): E / left click = next line, HOLD E = skip the
##      remaining lines up to (never past) a choice; choices always wait for the player's pick;
##   6. choices and follow-up lines queued during the talk stay inside it (the camera holds while anything is
##      queued or the choice panel is open);
##   7. after the last line the view eases back (~0.4 s) to the player's normal view, the FOV is restored, and
##      control comes back - also when the talk was skipped, ended in a choice, or was cut by a scripted event
##      (end_conversation()); a watchdog releases any lock left over (talk_watchdog()).
## Exceptions keep their own camera: driving, creature encounters, chase scenes and cinematics (converse() only
## queues the lines there).
## the survival expansion's shared expedition controller (game/world/expedition.gd)
const EXPEDITION := preload("res://game/world/expedition.gd")
var expedition: Node
## survivor trust / health / morale / companions (game/world/survivors.gd)
const SURVIVORS := preload("res://game/world/survivors.gd")
var survivors: Node
var sidearm: Node
var nav: Node
var conversing := false
var talk_report := {"count": 0, "blocked": 0, "cam_hits": 0, "min_face_dist": 99.0, "max_fov_drop": 0.0, "zoom_ins": 0,
	"zoom_outs": 0, "released": 0, "watchdog": 0}
const TALK_RANGE := 12.0              ## a talk started by an approach (a doorway, a yard) can begin a few metres off
const TALK_FOV_SCALE := 0.9            ## subtle zoom: 10 % narrower field of view
const TALK_EASE_IN := 7.0              ## exponential rates: ~0.4 s to settle on a speaker
const TALK_EASE_SPEAKER := 4.5         ## gentler re-aim when the speaker changes
const TALK_EASE_OUT := 8.0


## Points on an NPC the player can see it by (head, face, chest).
func _talk_points(npc: Node3D) -> Array:
	var head = _speaker_head(String(npc.name))
	var h: Vector3 = head if head != null else npc.global_position + Vector3(0, 1.6, 0)
	var base := npc.global_position
	return [h, h - Vector3(0, 0.15, 0), Vector3(base.x, lerpf(base.y, h.y, 0.72), base.z)]


## Line of sight from the player's eyes to an NPC (window glass counts: see _add_glass_colliders). Any one of the
## sample points being in plain view is enough.
func can_talk(npc: Node3D) -> bool:
	if npc == null or not is_instance_valid(npc) or not npc.is_visible_in_tree():
		return false
	var eye := player.camera.global_position
	var ex: Array[RID] = [player.get_rid()]
	if npc is CollisionObject3D:
		ex.append((npc as CollisionObject3D).get_rid())
	for p in _talk_points(npc):
		if eye.distance_to(p) > TALK_RANGE:
			continue
		var hit := _talk_ray(eye, p, ex)
		if hit.is_empty() or (hit["collider"] as Node).is_ancestor_of(npc) or npc.is_ancestor_of(hit["collider"]):
			return true
	return false


## A sight line for conversations. Invisible blockers that only keep the player out of a space (group
## "veil_talk_transparent", e.g. Ruth and Sarah's doorway) do not hide anyone; real walls, doors and glass do.
func _talk_ray(from: Vector3, to: Vector3, ex: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, ex)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	for _i in 3:
		if hit.is_empty() or not (hit["collider"] as Node).is_in_group("veil_talk_transparent"):
			break
		q.exclude = q.exclude + [(hit["collider"] as CollisionObject3D).get_rid()]
		hit = space.intersect_ray(q)
	return hit


## True while a normal conversation may take the camera (no driving, encounter, hidden player or cinematic).
func _talk_camera_allowed() -> bool:
	return not in_car and not _encounter_running and player.visible and not (_cine and is_instance_valid(_cine))


## Returns false only when refused (the NPC spoken to is out of sight behind a wall / door / window).
func converse(ids: Array, npcs: Array = []) -> bool:
	if conversing:
		# already talking (a scripted follow-up): the new lines take over inside the same talk camera
		for i in ids.size():
			Dialogue.say(ids[i], false, i == 0)
		return true
	if not _talk_camera_allowed():
		for i in ids.size():
			Dialogue.say(ids[i], false, i == 0)
		return true                              # spoken as plain timed lines (an exception keeps its own camera)
	if not npcs.is_empty() and not can_talk(npcs[0]):      # the one spoken to must be in plain view
		talk_report["blocked"] += 1
		return false
	conversing = true
	talk_report["count"] += 1
	_talk_speaker = String(npcs[0].name) if not npcs.is_empty() else _talk_speaker
	for n in npcs:
		var a = animators.get(String(n.name))
		if a:
			a.face_towards(player.global_position)
	Dialogue.confirm_mode = true
	for i in ids.size():
		Dialogue.say(ids[i], false, i == 0)
	await _talk_camera()
	Dialogue.confirm_mode = false
	conversing = false
	return true


func _choice_open() -> bool:
	if phase4 != null and is_instance_valid(phase4) and phase4.get("choice") != null and phase4.choice.is_open():
		return true
	for c in get_tree().get_nodes_in_group("veil_choice_panel"):
		if c.has_method("is_open") and c.is_open():
			return true
	return false


## The direction to look for the current speaker: the face and upper body (a little below the head bone).
func _talk_target():
	var head = _speaker_head(_talk_speaker)
	if head == null:
		return null
	return (head as Vector3) - Vector3(0, 0.12, 0)


func _talk_camera() -> void:
	_end_talk()
	_end_cine()
	_talk_id += 1
	var id := _talk_id
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	var src := player.camera
	var fov0 := src.fov
	var cam := Camera3D.new()
	cam.name = "TalkCam"
	add_child(cam)
	cam.global_transform = src.global_transform
	cam.fov = fov0
	cam.near = src.near
	cam.far = src.far
	cam.environment = src.environment
	cam.attributes = src.attributes
	cam.cull_mask = src.cull_mask
	cam.current = true
	_talk_cam = cam
	talk_report["zoom_ins"] += 1
	var idle := 0.0
	var aimed := ""
	var rate := TALK_EASE_IN
	while id == _talk_id and is_instance_valid(cam):
		var dt := get_process_delta_time()
		var busy := Dialogue.is_busy() or _choice_open()
		idle = 0.0 if busy else idle + dt
		if idle > 0.45:                         # nothing more queued: hand the view back
			break
		var eye := src.global_position          # the protagonist's own eyes: the camera never travels
		var want := Transform3D(cam.global_transform.basis, eye)
		var fov := fov0
		var at = _talk_target()
		if at != null and idle == 0.0:
			fov = fov0 * TALK_FOV_SCALE
			# a speaker hidden from the protagonist's eyes (behind a wall beside a doorway, behind another NPC) is
			# never framed: the view stays on the last visible speaker instead of turning to a wall
			var hit := _talk_ray(eye, at, [player.get_rid()])
			var hidden: bool = not hit.is_empty() and eye.distance_to(hit["position"]) < eye.distance_to(at) - 0.45
			if hidden:
				talk_report["hidden_speaker"] = int(talk_report.get("hidden_speaker", 0)) + 1
			else:
				if _talk_speaker != aimed:
					rate = TALK_EASE_IN if aimed == "" else TALK_EASE_SPEAKER
					aimed = _talk_speaker
				var to: Vector3 = at - eye
				if to.length() > 0.3:
					want = Transform3D(Basis(), eye).looking_at(at, Vector3.UP)
				talk_report["min_face_dist"] = minf(talk_report["min_face_dist"], eye.distance_to(at))
		# the camera is aimed at a speaker the player cannot see (should never happen: tests)
		if aimed != "" and aimed == _talk_speaker and at != null and idle == 0.0:
			var chk := _talk_ray(eye, at, [player.get_rid()])
			if not chk.is_empty() and eye.distance_to(chk["position"]) < eye.distance_to(at) - 0.45 and cam.global_transform.basis.z.dot(-(at - eye).normalized()) > 0.99:
				talk_report["cam_hits"] += 1
		var k := 1.0 - exp(-rate * dt)
		cam.global_transform = Transform3D(cam.global_transform.basis.slerp(want.basis.orthonormalized(), k).orthonormalized(), eye)
		cam.fov = lerpf(cam.fov, fov, k)
		talk_report["max_fov_drop"] = maxf(talk_report["max_fov_drop"], 1.0 - cam.fov / fov0)
		player.controls_enabled = false           # held for the whole talk (a closing choice panel re-enables them)
		player.velocity = Vector3.ZERO
		await get_tree().process_frame
	# ease back to the first-person view (the player's own camera, unchanged during the talk), then hand back control
	var t := 0.0
	while t < 0.4 and id == _talk_id and is_instance_valid(cam):
		var dt2 := get_process_delta_time()
		var k2 := 1.0 - exp(-TALK_EASE_OUT * dt2)
		cam.global_transform = Transform3D(cam.global_transform.basis.slerp(src.global_transform.basis.orthonormalized(), k2).orthonormalized(),
			src.global_position)
		cam.fov = lerpf(cam.fov, fov0, k2)
		player.velocity = Vector3.ZERO
		await get_tree().process_frame
		t += dt2
	if id == _talk_id:
		talk_report["zoom_outs"] += 1
		_end_talk()


## A scripted event that must take over in the middle of a conversation: the talk ends at once, the queued lines
## are dropped, the view and the controls are handed back (the event then takes the camera it needs).
func end_conversation() -> void:
	if _talk_cam and is_instance_valid(_talk_cam):
		Dialogue.clear()
	Dialogue.confirm_mode = false
	_end_talk()
	conversing = false


## Safety net (every frame): a talk camera or a conversation lock never outlives its conversation.
func talk_watchdog() -> void:
	if _talk_cam and is_instance_valid(_talk_cam) and not conversing and not Dialogue.is_busy() and not _choice_open():
		_talk_stale += get_physics_process_delta_time()
		if _talk_stale > 1.5:
			talk_report["watchdog"] += 1
			_end_talk()
	else:
		_talk_stale = 0.0
	if not conversing and Dialogue.confirm_mode and not Dialogue.is_busy():
		Dialogue.confirm_mode = false


var _talk_stale := 0.0


## Older timed entry point (kept for callers that only need the framing for a fixed time).
func talk_shot(seconds: float) -> void:
	if in_car or _encounter_running or not player.visible:
		return
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	Dialogue.confirm_mode = false
	while Time.get_ticks_msec() < until and Dialogue.is_busy():
		await get_tree().process_frame


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
		player.velocity = Vector3.ZERO
		talk_report["released"] += 1


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
	var n := VeilSurvivorBody.new()
	n.name = speaker
	n.position = pos
	n.add_child(scene.instantiate())
	parent.add_child(n)
	if not n.place_at(parent.to_global(pos)):
		n.hide()
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


# Called at authored scene transitions and when reconstructing story state from a save.
func place_survivor(npc: Node3D, local_point: Vector3) -> bool:
	var body := npc as VeilSurvivorBody
	if body == null:
		return false
	var animator := body.get_node_or_null("Animator") as NpcAnimator
	if animator:
		animator.walk_to([])
	var requested := body.get_parent_node_3d().to_global(local_point)
	var key := "%s:%s" % [get_path_to(body.get_parent()), local_point]
	var record: Dictionary = Game.world_state.get("shelter_npc_positions", {}).get(String(body.name), {})
	var saved: Array = record.get("feet", [])
	var restored := false
	if _restoring_survivors and record.get("home", "") == key and saved.size() == 3:
		var point := Vector3(saved[0], saved[1], saved[2])
		var floor_point := VeilSurvivorBody.floor_at(get_world_3d().direct_space_state, point)
		if floor_point.is_finite() and floor_point.distance_to(point) < 0.15 \
				and point.distance_to(requested) <= 30.0 and body.is_clear(floor_point):
			restored = body.place_at(floor_point)
	var ok := restored or body.place_at(requested)
	if ok and body.get_parent() == market:
		body.set_meta("shelter_home", key)
		body.set_meta("shelter_feet", body.global_position)
	if not ok and not body.is_clear(body.global_position):
		body.hide()
	return ok


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
		hud.location_caption(title, hold)          # small caption: the storefront sign stays the focus
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


## While driving past the store front: the car eases smoothly down to 5 km/h (driver keeps steering), the view turns
## and zooms gently onto the supermarket and its sign, then hands control back; the car rolls on into the lot.
const ARRIVAL_SPEED := 1.39          # m/s = 5 km/h
## Approaching the store front (before the arrival shot): a speed cap that follows a gentle braking curve
## (1.4 m/s^2) so the car is down to 5 km/h when it reaches the shot point. Only while heading towards it.
func _arrival_ease() -> void:
	if not in_car or not sedan.driven or Game.has_flag("arrival_shot") or _auto_parking:
		return
	var tr := get_node_or_null("Trigger_ArrivalShot") as Area3D
	if tr == null:
		return
	var to := tr.global_position - sedan.global_position
	to.y = 0.0
	var d := to.length() - 6.0
	var fwd := -sedan.global_transform.basis.z
	if d < 60.0 and sedan.speed > 0.5 and to.normalized().dot(fwd) > 0.5:
		sedan.speed_cap = sqrt(ARRIVAL_SPEED * ARRIVAL_SPEED + 2.0 * 1.4 * maxf(d, 0.0))
	elif sedan.speed_cap > 0.0 and not _cine:
		sedan.speed_cap = -1.0


func _arrival_shot() -> void:
	Game.set_flag("arrival_shot")
	sedan.speed_cap = ARRIVAL_SPEED
	Dialogue.say("town", true)
	hud.chapter_start(2, 2.6)                     # upper screen: the zoom's target (the sign) stays clear
	await focus_shot(market.global_transform * Vector3(0.0, 4.2, -0.3), 30.0, 2.0, 1.6, "GREYHAVEN MARKET")
	sedan.speed_cap = -1.0


# ------------------------------------------------------------------ automatic reverse parking
## Once the sedan rolls into the middle of the supermarket lot, the driver parks it: a scripted approach along the
## aisle past the chosen stall (two spaces east of the entrance, store-side row), a stop, the wheel turned while
## stationary, a reverse arc into the space, straightening, a stop at the wheel stop and the parking brake. The car is
## driven through its own physics the whole time (pure-pursuit path tracking, no teleport). Plays once
## (flag `auto_parked`); a blocked path or a timeout hands control back and the manual parking trigger still works.
const PARK_LOT := "RD_ParkingLot_10x20m_003"     # the lot module in front of the entrance (local z 0 = Main St)
const PARK_STALL_X := -3.70                      # stall centre (lot-local x): two stalls east of the entrance
const PARK_FINAL_Z := 16.6                       # car centre at rest: half a metre clear of the wheel stop and the cart row
const PARK_STRAIGHT := 1.5                       # straight reverse after the arc
const PARK_R := 4.5                              # reverse arc radius (car centre), ~31 deg of steering
const PARK_BRAKE := 5.0                          # m/s^2: how firmly the parking takeover slows a car caught at speed
var _auto_parking := false
var park_report := {}


func _park_lot_xf() -> Transform3D:
	var lot := find_child(PARK_LOT, true, false) as Node3D
	return lot.global_transform if lot else Transform3D(Basis(Vector3.UP, PI), Vector3(31, 0, -6))


## The standard plan (approach along the aisle towards -x, reverse in): world-space car-centre polylines.
func park_paths() -> Dictionary:
	return _park_plan(-1.0, Vector2(22.0, PARK_FINAL_Z - PARK_STRAIGHT - PARK_R), Vector2(-1, 0), 0.0)


## The manoeuvre from where the car really is (lot-local p0, heading h, speed v): a straight stretch in which it
## brakes (5 m/s^2) along its own heading, a smooth curve into the aisle, the aisle to the stop beside the stall,
## then a short reverse arc and a straight into the stall. side -1: travelling towards -x along the aisle (stop past
## the stall on that side); +1: the mirror image. Returns {} when the plan would leave the tarmac.
func _park_plan(side: float, p0: Vector2, h: Vector2, v: float) -> Dictionary:
	var L := _park_lot_xf()
	var zl := PARK_FINAL_Z - PARK_STRAIGHT - PARK_R
	var xs := PARK_STALL_X + side * PARK_R
	var lane := Vector2(side, 0.0)
	var stop := Vector2(xs, zl)
	var pts: Array[Vector2] = []
	var sb := maxf(0.0, (v * v - 9.0) / (2.0 * PARK_BRAKE)) + 0.5
	var a := p0 + h * sb
	for k in 6:
		pts.append(p0.lerp(a, k / 5.0))
	var q := stop - lane * 3.0                           # the last 3 m along the aisle, straight
	if (q - a).dot(lane) < 1.0:
		return {}                                        # the stop is not ahead along this way down the aisle
	var d := 0.4 * a.distance_to(q)
	var c1 := a + h * d
	var c2 := q - lane * d
	for k in range(1, 25):
		var t := k / 24.0
		var u := 1.0 - t
		pts.append(u * u * u * a + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * q)
	for k in range(1, 7):
		pts.append(q.lerp(stop, k / 6.0))
	for pt in pts:                                       # car centre at least ~1.2 m inside the tarmac (all 4 modules)
		if pt.x < -13.8 or pt.x > 23.8 or pt.y < 1.4 or pt.y > 18.6:
			return {}
	var approach: Array[Vector3] = []
	for pt in pts:
		approach.append(L * Vector3(pt.x, 0.0, pt.y))
	var rev: Array[Vector3] = []
	var c := Vector2(xs, PARK_FINAL_Z - PARK_STRAIGHT)
	var ph1 := -PI / 2 - side * PI / 2
	for k in range(0, 31):
		var ph := lerpf(-PI / 2, ph1, k / 30.0)
		rev.append(L * Vector3(c.x + PARK_R * cos(ph), 0.0, c.y + PARK_R * sin(ph)))
	for k in range(1, 11):
		rev.append(L * Vector3(PARK_STALL_X, 0.0, PARK_FINAL_Z - PARK_STRAIGHT + PARK_STRAIGHT * k / 10.0))
	return {"approach": approach, "reverse": rev, "final_fwd": L.basis * Vector3(0, 0, -1)}


## The best plan for the car as it is now: the way down the aisle it is already heading first.
func _park_plan_now() -> Dictionary:
	var L := _park_lot_xf()
	var inv := L.affine_inverse()
	var lp := inv * sedan.global_position
	var f := -sedan.global_transform.basis.z
	if sedan.speed < -0.3:
		f = -f
	var lf := inv.basis * f
	var h := Vector2(lf.x, lf.z).normalized()
	var v := absf(sedan.speed)
	var first := -1.0 if h.x <= 0.0 else 1.0
	for side in [first, -first]:
		var plan := _park_plan(side, Vector2(lp.x, lp.z), h, v)
		if not plan.is_empty():
			return plan
	return {}


## Pure-pursuit tracker on a polyline. dir = +1 forward / -1 reverse. Returns Vector2(target speed, steer angle).
func _pursue(path: Array[Vector3], st: Dictionary, dir: float, v_max: float, ld: float, decel := 0.7) -> Vector2:
	var p := sedan.global_position
	var p2 := Vector2(p.x, p.z)
	var i: int = st["i"]
	while i < path.size() - 1 and Vector2(path[i + 1].x, path[i + 1].z).distance_to(p2) <= Vector2(path[i].x, path[i].z).distance_to(p2):
		i += 1
	st["i"] = i
	# remaining length along the path (from the closest point)
	var rem := Vector2(path[i].x, path[i].z).distance_to(p2) if i == path.size() - 1 else 0.0
	for j in range(i, path.size() - 1):
		rem += Vector2(path[j].x, path[j].z).distance_to(Vector2(path[j + 1].x, path[j + 1].z))
	# past the end (projection beyond the last point)?
	var end := Vector2(path[-1].x, path[-1].z)
	var prev := Vector2(path[-2].x, path[-2].z)
	if (p2 - end).dot(end - prev) > 0.0:
		rem = 0.0
	st["rem"] = rem
	var tgt := end
	var acc := 0.0
	for j in range(i, path.size() - 1):
		var a := Vector2(path[j].x, path[j].z)
		var b := Vector2(path[j + 1].x, path[j + 1].z)
		acc += a.distance_to(b)
		if acc >= ld:
			tgt = b
			break
	if rem < ld:                                    # extend the last segment so the car keeps tracking the line
		tgt = end + (end - prev).normalized() * (ld - rem)
	var fwd := -sedan.global_transform.basis.z
	var d := Vector2(fwd.x, fwd.z).normalized() * dir           # motion direction
	var to := (tgt - p2)
	var la := maxf(to.length(), 0.5)
	# y-up rotation moves d towards (d.y, -d.x) in (x, z): sin(alpha) = to . that / |to|
	var left := Vector2(d.y, -d.x)
	var sin_a := to.normalized().dot(left)
	if to.normalized().dot(d) < 0.0:                # target behind the motion direction: full lock that way
		sin_a = signf(sin_a) if absf(sin_a) > 0.01 else 1.0
	var kappa := 2.0 * sin_a / la
	var steer_ang := atan(kappa * PlayerSedan.WHEELBASE * dir)
	var v := minf(v_max, sqrt(maxf(2.0 * decel * rem, 0.0)))     # eases to a stop at the end of the leg
	if rem < 0.06:
		v = 0.0
	return Vector2(v * dir, steer_ang)


func _maybe_auto_park(b: Node) -> void:
	if b != sedan or not in_car or not sedan.driven or _auto_parking or _ending:
		return
	if Game.has_flag("auto_parked") or Game.has_flag("parked") or not Game.has_flag("entered_car"):
		return
	_auto_park()


func _auto_park() -> void:
	_auto_parking = true
	park_report = {"started": true}
	var paths := _park_plan_now()
	# coming in over the pavement or the grass, or so that no clean path fits on the tarmac: the car is put straight
	# into the stall behind a short fade (if the manoeuvre fails or ends off the tarmac, the same fade places it)
	if paths.is_empty() or not car_on_asphalt():
		if paths.is_empty():
			paths = park_paths()
		park_report["placed"] = true
		await _fade_park(paths)
		return
	var S := {"phase": "approach", "st": {"i": 0, "rem": 99.0}}      # shared with the drive lambda (by reference)
	var t := 0.0
	var stuck_t := 0.0
	var last := sedan.global_position
	var max_dev := 0.0
	hud.set_hint("Parking...")
	# elevated shot over the open lot (nothing between it and the stall); used only while its view of the car is clear
	var pcam := Camera3D.new()
	pcam.name = "ParkCam"
	pcam.fov = 48.0
	pcam.far = 400.0
	add_child(pcam)
	var lot_xf := _park_lot_xf()
	pcam.global_position = lot_xf * Vector3(1.0, 6.5, 6.0)
	park_report["cam_blocked_frames"] = 0
	sedan.script_decel = PARK_BRAKE
	sedan.drive_script = func(_dt: float) -> Vector2:
		match S["phase"]:
			"approach":
				return _pursue(paths["approach"], S["st"], 1.0, 4.5, 4.5, 1.2)    # a parking pace, not a crawl
			"turn":                                     # steer while stationary before reversing
				var c := _pursue(paths["reverse"], {"i": 0, "rem": 99.0}, -1.0, 0.0, 2.6)
				return Vector2(0.0, c.y)
			"reverse":
				return _pursue(paths["reverse"], S["st"], -1.0, 2.0, 2.6, 1.0)
		return Vector2(0.0, 0.0)
	var ok := true
	while true:
		await get_tree().physics_frame
		if not is_instance_valid(sedan) or not in_car:
			ok = false
			break
		var dt := get_physics_process_delta_time()
		t += dt
		var phase: String = S["phase"]
		var st: Dictionary = S["st"]
		if sedan.global_position.distance_to(last) < 0.002 and phase in ["approach", "reverse"] and st["rem"] > 0.2 and t > 3.0:
			stuck_t += dt
		else:
			stuck_t = 0.0
		last = sedan.global_position
		var aim := sedan.global_position + Vector3.UP * 0.7
		pcam.look_at(aim, Vector3.UP)
		var clear := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(pcam.global_position, aim, 1 | 2, [sedan.get_rid(), player.get_rid()])).is_empty()
		if clear and _cine == null:
			pcam.current = true
		elif not clear:
			park_report["cam_blocked_frames"] += 1
			sedan.driver_cam.current = true
		if phase == "reverse":
			var p := sedan.global_position
			var best := 99.0
			for q in paths["reverse"]:
				best = minf(best, Vector2(q.x, q.z).distance_to(Vector2(p.x, p.z)))
			max_dev = maxf(max_dev, best)
		if stuck_t > 1.5 or t > 45.0:
			ok = false
			break
		if phase == "approach" and st["rem"] < 0.06 and absf(sedan.speed) < 0.03:
			S["phase"] = "turn"
			S["st"] = {"i": 0, "rem": 99.0}
			park_report["stop_err"] = Vector2(sedan.global_position.x, sedan.global_position.z).distance_to(
				Vector2(paths["approach"][-1].x, paths["approach"][-1].z))
		elif phase == "turn":
			var want := _pursue(paths["reverse"], {"i": 0, "rem": 99.0}, -1.0, 0.0, 2.6).y
			if absf(sedan.steer - clampf(want, -PlayerSedan.MAX_STEER, PlayerSedan.MAX_STEER)) < 0.03:
				S["phase"] = "reverse"
		elif phase == "reverse" and st["rem"] < 0.06 and absf(sedan.speed) < 0.03:
			break
	sedan.drive_script = Callable()
	sedan.script_decel = PlayerSedan.SCRIPT_ACCEL
	sedan.speed = 0.0
	_auto_parking = false
	hud.set_hint("")
	if is_instance_valid(sedan) and in_car:
		sedan.driver_cam.current = true
	pcam.queue_free()
	var fin := sedan.global_position
	var endp: Vector3 = paths["reverse"][-1]
	var f := -sedan.global_transform.basis.z
	park_report.merge({"ok": ok, "time": t, "pos_err": Vector2(fin.x, fin.z).distance_to(Vector2(endp.x, endp.z)),
		"yaw_err_deg": rad_to_deg(absf(Vector2(f.x, f.z).angle_to(Vector2(paths["final_fwd"].x, paths["final_fwd"].z)))),
		"max_dev": max_dev}, true)
	if not ok or not car_on_asphalt():
		# the manoeuvre did not end in the stall (blocked, off the tarmac): put it there behind a fade instead
		park_report["placed"] = true
		_auto_parking = true
		await _fade_park(paths)
		return
	sedan.parking_brake = true
	Sfx.play("door_close", sedan.global_position, -14.0, 0.6)     # handbrake ratchet stand-in
	Game.set_flag("auto_parked")
	Game.set_flag("reached_town")
	Game.set_flag("parked")
	Dialogue.say("parked", true, true)
	await get_tree().create_timer(1.4).timeout
	if in_car and sedan.driven and absf(sedan.speed) < 0.2:
		exit_car()                                 # parked: the player gets out by themselves
	save()


## Into the stall behind a short fade (nose out, square to the bay, on the tarmac), then the usual parked state.
func _fade_park(paths: Dictionary) -> void:
	sedan.drive_script = Callable()
	sedan.script_decel = PlayerSedan.SCRIPT_ACCEL
	hud.set_hint("")
	await hud.fade_to(1.0, 0.45)
	var endp: Vector3 = paths["reverse"][-1]
	var fwd: Vector3 = paths["final_fwd"]
	sedan.speed = 0.0
	sedan.steer = 0.0
	sedan.velocity = Vector3.ZERO
	var space := get_world_3d().direct_space_state
	var g0 := space.intersect_ray(PhysicsRayQueryParameters3D.create(sedan.global_position + Vector3.UP, sedan.global_position - Vector3.UP * 4.0, 1, [sedan.get_rid()]))
	var g1 := space.intersect_ray(PhysicsRayQueryParameters3D.create(endp + Vector3.UP * 3.0, endp - Vector3.UP * 4.0, 1, [sedan.get_rid()]))
	var lift: float = sedan.global_position.y - ((g0["position"] as Vector3).y if g0 else sedan.global_position.y)
	var y: float = ((g1["position"] as Vector3).y if g1 else endp.y) + lift
	sedan.global_transform = Transform3D(Basis.looking_at(fwd * Vector3(1, 0, 1), Vector3.UP), Vector3(endp.x, y, endp.z))
	for i in 3:
		await get_tree().physics_frame
	if in_car:
		sedan.driver_cam.current = true
	_auto_parking = false
	sedan.parking_brake = true
	Sfx.play("door_close", sedan.global_position, -14.0, 0.6)
	Game.set_flag("auto_parked")
	Game.set_flag("reached_town")
	Game.set_flag("parked")
	await hud.fade_to(0.0, 0.6)
	Dialogue.say("parked", true, true)
	await get_tree().create_timer(1.4).timeout
	if in_car and sedan.driven and absf(sedan.speed) < 0.2:
		exit_car()
	save()


## All four corners of the car over road or parking-lot surface (not the grass, the pavement or a kerb).
func car_on_asphalt() -> bool:
	var space := get_world_3d().direct_space_state
	for c in [Vector3(-0.85, 0, -2.1), Vector3(0.85, 0, -2.1), Vector3(-0.85, 0, 2.1), Vector3(0.85, 0, 2.1)]:
		var at: Vector3 = sedan.global_transform * c
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.5, 0), at - Vector3(0, 2.0, 0), 1, [sedan.get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return false
		var n := String((hit["collider"] as Node).name)
		if not (n.begins_with("RD_") or n.contains("Road") or n.contains("Parking")):
			return false
	return true


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


## A companion following the player reached the supermarket's entrance while the doors are shut: they open (the
## powered sensor, or pulled open by hand once the power is gone), so nobody walks into the glass. Scripted
## door-closing scenes are left alone (the doors are shut on purpose there).
func companion_at_market_doors(at: Vector3) -> void:
	if market == null or Game.has_flag("p3_doors_shut") and not Game.has_flag("c5_started"):
		return
	if expedition != null and expedition.doors_held():
		return                                   # shelter time: a companion never opens the exit on its own
	var o := market.get_node_or_null("Doorways/Entrance_Outside") as Node3D
	var i := market.get_node_or_null("Doorways/Entrance_Inside") as Node3D
	if o == null or i == null or minf(at.distance_to(o.global_position), at.distance_to(i.global_position)) > 2.6:
		return
	if _doors_powered:
		_set_auto_doors(true)
	elif phase4 and phase4.chapter5 and not phase4.chapter5._doors_open:
		phase4.chapter5._set_doors(true)


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
		converse(["market_need_items"], [cashier])
		return
	for i in need + EXTRAS:
		Game.remove_item(i)
	Game.add_item("groceries")
	Sfx.play("pickup", market.global_transform * Vector3(-4.1, 1.1, 4.0))
	_glow(cashier, false)
	_cashier_state()
	if can_talk(cashier):
		converse(["market_checkout", "groceries_done"], [cashier])
	else:
		Dialogue.say("market_checkout", false, true)
		Dialogue.say("groceries_done")
	hud.set_hint("")
	Game.set_flag("groceries_done")


func _talk_eddie(_by: Node) -> void:
	if Game.has_flag("p3_mist"):
		converse(["p3_eddie_go" if Game.has_flag("p3_in_shop") else "p3_eddie_hurry"], [eddie])
		return
	if Game.has_flag("game_bought"):
		converse(["eddie_after"], [eddie])
	elif Game.has_item("horror_game"):
		var refused: int = talk_report["blocked"]
		await converse(["eddie_buy"], [eddie])
		if talk_report["blocked"] == refused:      # not when a wall / window was in the way
			Game.set_flag("game_bought")
	else:
		converse(["eddie_hello"], [eddie])



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
const STOMP_QUICKEN := 1.45                     ## the Colossus foot's descent: a heavy, fast fall (the rest unchanged)
var _doors_powered := true
var _p3_shop_talked := false
var _p3_npcs_moved := false
var _encounter_running := false
var _enc_store: Node3D                       ## the store the player stepped out of
var enc_report := {}                         ## measured encounter facts (tests): foot error, body height, ...
var mist_ceiling: Node3D
var shut_it: Interactable

const MARCUS_SHOP_POS := Vector3(-3.6, 0.04, 4.4)        # game-shop local: between the wall shelf and the New Releases rack
const MARKET_EDDIE_POS := Vector3(6.2, 0.04, 4.05)       # staff side of customer service
const MARKET_MARCUS_POS := Vector3(-2.0, 0.04, 6.9)
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
	if not player.visible or in_car or _encounter_running or conversing:   # the Veil waits for a conversation to end
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
		_p3_escape_tentacle()


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
	hud.chapter_start(3)
	hud.set_hint("")
	_clear_beacon("market")
	if cashier:
		cashier.visible = false                 # people are going missing
	_cashier_state()
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
const CAM_R := 0.16
const SHOP_EDDIE_WAIT := Vector3(-2.2, 0.04, 1.3)       # game-shop local: by the door, clear of the leaf's swing
const SHOP_EDDIE_OPEN := Vector3(-3.95, 0.04, 1.05)     # handle side, outside the leaf's swing (radius 0.97)
const SHOP_A_SPOT := Vector3(-2.9, 0.04, 2.3)           # where the protagonist waits while Eddie opens up
const SHOP_EDDIE_ASIDE := Vector3(-4.3, 0.04, 0.95)
const SHOP_EDDIE_DOOR := Vector3(-3.2, 0.04, -0.15)     # on the threshold, outside the glass line
const SHOP_OUT_SPOT := Vector3(-3.2, 0.04, -1.7)        # where the protagonist stands on the sidewalk
const SHOP_TALK := {"Eddie": Vector3(-0.4, 0.04, 1.5), "Protagonist": Vector3(-2.0, 0.04, 1.45), "Marcus": Vector3(0.2, 0.04, 2.5)}
const SHOP_G_CAMS := [Vector3(0.6, 1.75, 3.0), Vector3(0.2, 1.8, 3.6), Vector3(1.2, 1.8, 2.4), Vector3(-0.6, 1.8, 3.2),
	Vector3(0.9, 1.7, 1.1), Vector3(1.6, 1.7, 1.6), Vector3(0.0, 1.7, 2.1), Vector3(2.2, 1.75, 1.2)]
## the fore claw tips of the Colossus in skeleton space at scale 1 (build_colossus.py: LEGS "FL" contact
## (-6.1, 0, 6.0), claws (dlat, dfw, ln) -> tip y 0.11 minus the 0.05 tip radius)
## front-left paw contact points (skeleton space, scale 1, build_colossus.py): the palm pad's underside (the
## weight-bearing surface, y 0.06) and the three claw tips (also y 0.06, just touching)
const FL_TIPS := [Vector3(-6.1, 0.06, 6.2), Vector3(-5.55, 0.06, 7.36), Vector3(-6.15, 0.06, 7.82), Vector3(-6.7, 0.06, 7.07)]
const FL_FOOT_REST := Vector3(-6.0, 2.4, 5.6)            # Leg_FL_Foot rest origin (sanity check, tests)
const VEIL_SHADER := preload("res://game/world/colossus_veil.gdshader")
var _cam_prev := Vector3.INF
var _cam_shot := ""


func _sphere_q(p: Vector3, motion := Vector3.ZERO) -> PhysicsShapeQueryParameters3D:
	var sph := SphereShape3D.new()
	sph.radius = CAM_R
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	q.collision_mask = 1
	q.exclude = [player.get_rid(), sedan.get_rid()]
	q.transform = Transform3D(Basis(), p)
	q.motion = motion
	return q


## A camera may sit at p: no world geometry (incl. glass) within CAM_R, not inside any NPC's body.
func cam_point_ok(p: Vector3) -> bool:
	if not get_world_3d().direct_space_state.intersect_shape(_sphere_q(p), 1).is_empty():
		return false
	for k in animators:
		var a = animators[k]
		if a == null or not is_instance_valid(a) or a.root == null or not a.root.is_visible_in_tree():
			continue
		var r: Vector3 = a.root.global_position
		if Vector2(p.x - r.x, p.z - r.z).length() < 0.36 and p.y > r.y - 0.05 and p.y < r.y + 1.95:
			return false
	return true


## A camera may travel a -> b: a sphere sweep that hits nothing, and no NPC body on the way.
func cam_path_ok(a: Vector3, b: Vector3) -> bool:
	var r := get_world_3d().direct_space_state.cast_motion(_sphere_q(a, b - a))
	if r.size() == 0 or r[0] < 1.0:
		return false
	var n := maxi(1, int(ceil(a.distance_to(b) / 0.1)))
	for i in n + 1:
		if not cam_point_ok(a.lerp(b, float(i) / n)):
			return false
	return true


func sight_ok(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1, [player.get_rid(), sedan.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## First candidate where a camera can sit and see every point in `must_see`.
func pick_anchor(cands: Array, must_see: Array) -> Variant:
	for c in cands:
		if not cam_point_ok(c):
			continue
		if must_see.all(func(m): return sight_ok(c, m)):
			return c
	return null


## Watchdog (runs every frame while the encounter owns the view).
func _cam_watch() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam == player.camera:
		_cam_prev = Vector3.INF
		return
	var p := cam.global_position
	enc_report["cam_frames"] = enc_report.get("cam_frames", 0) + 1
	var bad := not cam_point_ok(p)
	if not bad and _cam_prev != Vector3.INF and _cam_prev.distance_to(p) > 0.001 and _cam_prev.distance_to(p) < 2.0:
		bad = not sight_ok(_cam_prev, p)                  # crossed a surface since the last frame (cuts are > 2 m)
	if bad:
		enc_report["cam_violations"] = enc_report.get("cam_violations", 0) + 1
		var where: Array = enc_report.get("cam_violation_shots", [])
		if not _cam_shot in where:
			where.append(_cam_shot)
		enc_report["cam_violation_shots"] = where
	_cam_prev = p


## Move a camera along a validated path (sphere-swept segments); segments that cannot be travelled are cut.
func _cam_travel(cam: Camera3D, pts: Array, speed: float, look: Callable) -> void:
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		if not cam_path_ok(a, b):
			enc_report["cam_cuts"] = enc_report.get("cam_cuts", 0) + 1
			cam.global_position = b
			cam.look_at(look.call(b), Vector3.UP)
			await get_tree().process_frame
			continue
		var t := 0.0
		var dur := maxf(a.distance_to(b) / speed, 0.05)
		while t < dur:
			var k := t / dur
			var p := a.lerp(b, k)
			cam.global_position = p
			var want := Transform3D(Basis(), p).looking_at(look.call(p), Vector3.UP).basis
			cam.global_basis = Basis(cam.global_basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), minf(get_process_delta_time() * 5.0, 1.0)))
			await get_tree().process_frame
			t += get_process_delta_time()
		cam.global_position = b


## Wait for authored movement without a visible teleport if the path is blocked.
func _walk_wait(speaker: String, pts: Array, speed: float, timeout: float) -> void:
	var a = animators.get(speaker)
	if a == null:
		return
	a.walk_to(pts, speed)
	var t := 0.0
	while a.is_walking() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	if a.is_walking():
		a.walk_to([])


## The creature's encounter look: its own textures through colossus_veil.gdshader (see there).
func _veil_colossus(c: Node3D, ground: float) -> void:
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i) as BaseMaterial3D
			var sm := ShaderMaterial.new()
			sm.shader = VEIL_SHADER
			if src:
				sm.set_shader_parameter("albedo_tex", src.albedo_texture)
				sm.set_shader_parameter("emission_tex", src.emission_texture if src.emission_enabled else null)
			sm.set_shader_parameter("ground_y", ground)
			m.set_surface_override_material(i, sm)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	enc_report["veil_shader"] = true


## Fog cards (Pack 09 billboards) fade out close to the camera during the cinematic, so no card's flat edge can
## fill the frame as a pale polygon. Returns a restore callable.
func _soften_fog_cards() -> Callable:
	var cards := _atmo().get_parent().find_child("FogCards", true, false) as CPUParticles3D
	if cards == null or cards.mesh == null or not (cards.mesh.material is StandardMaterial3D):
		return func(): pass
	var m := cards.mesh.material as StandardMaterial3D
	var old := [m.distance_fade_mode, m.distance_fade_min_distance, m.distance_fade_max_distance]
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 5.0
	m.distance_fade_max_distance = 16.0
	enc_report["fog_cards_softened"] = true
	return func():
		m.distance_fade_mode = old[0]
		m.distance_fade_min_distance = old[1]
		m.distance_fade_max_distance = old[2]


const STANCE_RATE := 1.0                 ## Walk_Heavy: a planted foot slides back 1 m per animation second (scale 1)
var _enc_sounds: Array = []              ## encounter audio, faded out when the encounter ends


func _tips_world(sk: Skeleton3D, foot: int) -> Array:
	var rest := sk.get_bone_global_rest(foot)
	var pose := sk.get_bone_global_pose(foot)
	var out: Array = []
	for tp in FL_TIPS:
		out.append(sk.global_transform * (pose * (rest.affine_inverse() * tp)))
	return out


## Walk-in check: every touchdown of any of the four feet before the hero contact, and whether the camera saw it.
const FOOT_BONES := ["Leg_FL_Foot", "Leg_FR_Foot", "Leg_HL_Foot", "Leg_HR_Foot"]
func _feet_watch_setup(ap: AnimationPlayer, sk: Skeleton3D, anim: Animation) -> Dictionary:
	var lows := {}
	var t0 := ap.current_animation_position
	for b in FOOT_BONES:
		lows[b] = INF
	var t := 0.0
	while t < anim.length:
		ap.seek(t, true)
		sk.force_update_all_bone_transforms()
		for b in FOOT_BONES:
			lows[b] = minf(lows[b], sk.get_bone_global_pose(sk.find_bone(b)).origin.y)
		t += anim.length / 90.0
	ap.seek(t0, true)
	return {"lows": lows, "down": {}, "events": [], "ground": sk.global_position.y}


func _feet_watch_tick(w: Dictionary, sk: Skeleton3D, cam: Camera3D) -> void:
	var s := sk.global_transform.basis.get_scale().y
	for b in FOOT_BONES:
		var local := sk.get_bone_global_pose(sk.find_bone(b)).origin
		var rel: float = (local.y - float(w["lows"][b])) * s
		var was_down: bool = w["down"].get(b, true)
		if not was_down and rel < 0.08 * COLOSSUS_SCALE:
			var p := sk.global_transform * local
			p.y = float(w["ground"])                   # where the claws meet the road (the bone is the wrist, high up)
			w["events"].append({"foot": b, "seen": cam.is_position_in_frustum(p + Vector3(0, 0.5, 0)),
				"dist": cam.global_position.distance_to(p), "pos": p})
		if rel < 0.08 * COLOSSUS_SCALE:
			w["down"][b] = true
		elif rel > 0.5 * COLOSSUS_SCALE:
			w["down"][b] = false


func _min_tip_y(sk: Skeleton3D, foot: int) -> float:
	var y := INF
	for p in _tips_world(sk, foot):
		y = minf(y, p.y)
	return y


## The animation time where the foot's swing ends: tips come back down to their stance height.
func _near_shop_door() -> bool:
	if eddie == null or eddie.get_parent() != game_shop:
		return false
	var l := game_shop.to_local(player.global_position)
	return absf(l.x + 3.2) < 1.1 and l.z > 0.35 and l.z < 2.3


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
	var L := P + n * 15.0 + side * 1.6                 # across the street, well clear of the storefront
	L.y = ground
	# --- Stage 1: something enormous moving (sound first), controls held
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	hud.allow_pause = false
	hud.set_hint("")
	_enc_sounds.append(Sfx.play("colossus_call", P + n * 14.0 + Vector3(0, 9, 0), 4.0, 0.8))   # close enough to be heard at once
	Sfx.play_music(Sfx.MUSIC_COLOSSUS, false, -6.0, 0.6, Sfx.MUSIC_GAMEPLAY)   # the reveal theme, then back to the loop
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
	enc_report["veil_surfaces"] = VeilCreatureLook.apply_colossus(c, ground)   # dark, textured, sinks into the mist
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
	var place := func(at: float):
		ap.seek(at, true)
		sk.force_update_all_bone_transforms()
		var tips := _tips_world(sk, foot)
		var mid: Vector3 = (tips[0] + tips[1] + tips[2]) / 3.0
		var dy := _min_tip_y(sk, foot) - (ground + 0.02)        # claw tips rest on the road (2 cm)
		c.global_position += Vector3(L.x - mid.x, -dy, L.z - mid.z)
	place.call(t_c)
	# only the near leg may come down by the store: the other three feet must land farther out over the street;
	# if this rig's "left" is the other side, walk the other way (mirror) and place again
	var others := ["Leg_FR_Foot", "Leg_HL_Foot", "Leg_HR_Foot"].map(func(b): return sk.find_bone(b))
	var near_out := INF
	for b in others:
		near_out = minf(near_out, ((sk.global_transform * sk.get_bone_global_pose(b).origin) - P).dot(n))
	if near_out < (L - P).dot(n) + 2.0:
		walk_dir = -walk_dir
		c.rotation.y = atan2(walk_dir.x, walk_dir.z)
		place.call(t_c)
		near_out = INF
		for b in others:
			near_out = minf(near_out, ((sk.global_transform * sk.get_bone_global_pose(b).origin) - P).dot(n))
	enc_report["other_feet_min_out_m"] = near_out
	# contact = the first frame the claw tips reach the road (not the end of the swing: the foot touches down
	# before it stops); the leg comes down from the top of its swing, up in the mist
	var t_touch := t_c
	var t_apex := fposmod(t_c - anim.length * 0.5, anim.length)
	var y_c := 0.0
	ap.seek(t_c, true)
	sk.force_update_all_bone_transforms()
	y_c = _min_tip_y(sk, foot)
	var best_y := -INF
	var scan := 0.0
	while scan < anim.length * 0.5:
		var tt := fposmod(t_c - scan, anim.length)
		ap.seek(tt, true)
		sk.force_update_all_bone_transforms()
		var yy := _min_tip_y(sk, foot)
		if yy <= y_c + 0.04 * COLOSSUS_SCALE:
			t_touch = tt                                         # still touching: contact is at or before this
		if yy > best_y:
			best_y = yy
			t_apex = tt
		scan += 1.0 / 120.0
	t_c = t_touch
	place.call(t_c)                                               # claw tips on L, on the road, at first touch
	var contact_pos := c.global_position
	# ONE leg event: the near front leg comes down once, from the top of its swing in the mist, onto L. (The old
	# walk-in showed one full stride first: the same leg touched down silently ~21 m away, in view, before the
	# real step - the "duplicate leg".) The stride's time is kept as a held beat: the call, the look, the silence;
	# the creature is not shown until its swing begins, high above (see DROP below), so the leg comes down out of
	# the mist from above and stops on the road instead of appearing or fading in. Parts beyond 40 m stay in the
	# mist (far_hide) until the face close-up.
	const SPEED := 0.5
	var descent := fposmod(t_c - t_apex, anim.length)
	var span := descent                                           # animation seconds shown before contact
	var rate := STANCE_RATE * COLOSSUS_SCALE                       # metres per animation second
	c.global_position = contact_pos - walk_dir * rate * span
	ap.seek(fposmod(t_c - span, anim.length), true)
	ap.speed_scale = 0.0
	c.visible = false
	var veil_mats: Array = []
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh:
			for i in m.mesh.get_surface_count():
				var sm := m.get_surface_override_material(i) as ShaderMaterial
				if sm:
					veil_mats.append(sm)
	var set_far := func(m: float):                               # staging: the far legs stay in the mist for now
		for sm in veil_mats:
			sm.set_shader_parameter("far_hide", m)
	set_far.call(40.0)
	var set_band := func(k: float):                              # 0: everything above the road is in the mist; 1: normal
		for sm in veil_mats:
			sm.set_shader_parameter("dissolve_start", lerpf(-2.0, 10.0, k))
			sm.set_shader_parameter("dissolve_end", lerpf(0.5, 17.0, k))
	set_band.call(0.0)
	# the player instinctively looks at the sound / the darkness ahead
	var tw0 := create_tween()
	var b0 := cam.global_basis.get_rotation_quaternion()
	var b1 := Transform3D(Basis(), cam.global_position).looking_at(L + Vector3(0, 4.0, 0) + side * -1.0, Vector3.UP).basis.get_rotation_quaternion()
	tw0.tween_method(func(q): cam.global_basis = Basis(b0.slerp(b1, q * q * (3.0 - 2.0 * q))), 0.0, 1.0, 1.5)
	await get_tree().create_timer(anim.length / SPEED * 0.55).timeout   # the held beat (a little shorter than a stride)
	# the leg comes DOWN FROM ABOVE and stops: no fade. The whole creature starts DROP metres higher (the foot above
	# the mist ceiling, out of sight) and comes down accelerating (y offset DROP * (1 - k^2)), so the foot drops out of
	# the mist and stops hard on the road on the contact frame; the horizontal stance-rate walk is unchanged.
	const DROP := 12.0
	set_band.call(1.0)
	var walk_from := c.global_position
	c.global_position = walk_from + Vector3.UP * DROP
	c.visible = true
	ap.speed_scale = SPEED * STOMP_QUICKEN
	var feet_watch := _feet_watch_setup(ap, sk, anim)
	feet_watch["ground"] = L.y
	ap.seek(fposmod(t_c - span, anim.length), true)
	var elapsed := 0.0
	var dur := span / (SPEED * STOMP_QUICKEN)                     # the descent ~12% quicker, the pose still lands on t_c
	while elapsed < dur:                                          # to the very contact frame: no last-frame snap
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var k := clampf(elapsed / dur, 0.0, 1.0)
		c.global_position = walk_from.lerp(contact_pos, k) + Vector3.UP * DROP * (1.0 - k * k)
		_feet_watch_tick(feet_watch, sk, cam)
	enc_report["walkin_touchdowns"] = feet_watch["events"]
	enc_report["leg_drop_m"] = DROP
	# touchdowns the camera could see before the real step (the hero contact itself, at L, is not one of them)
	var extra := 0
	for e in feet_watch["events"]:
		var ep: Vector3 = e["pos"]
		if e["seen"] and float(e["dist"]) < 40.0 and Vector2(ep.x - L.x, ep.z - L.z).length() > 10.0:
			extra += 1
	enc_report["walkin_extra_seen"] = extra
	c.global_position = contact_pos
	ap.seek(t_c, true)                                            # exactly the touch-down frame
	# --- Stage 2: the footstep (impact) - sound, dust and shake on the contact frame
	sk.force_update_all_bone_transforms()
	var tips_now := _tips_world(sk, foot)
	var mid_now: Vector3 = (tips_now[0] + tips_now[1] + tips_now[2]) / 3.0
	enc_report["foot_error_m"] = Vector2(mid_now.x - L.x, mid_now.z - L.z).length()
	enc_report["foot_height_m"] = _min_tip_y(sk, foot) - ground
	enc_report["body_height_m"] = (sk.global_transform * sk.get_bone_global_pose(body_b).origin).y - ground
	enc_report["ceiling_m"] = CEILING_LAYERS[0]
	enc_report["leg_distance_m"] = Vector2(L.x - P.x, L.z - P.z).length()
	enc_report["walk_in_m"] = rate * span
	enc_report["apex_height_m"] = best_y - ground
	ap.speed_scale = 0.0                                          # planted: the weight comes down on it
	_enc_sounds.append(Sfx.play("colossus_step", L + Vector3(0, 1, 0), 6.0, 0.7))
	_impact_dust(L)
	_crush_lamp(L)
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
	_cine_double(me, P)                         # a stand-in: exactly here, no collision (it overlaps the player)
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
	var unhide := c.create_tween()
	unhide.tween_method(set_far, 40.0, 400.0, 2.6)
	unhide.tween_callback(set_far.bind(100000.0))
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


func _shop_regroup(cam: Camera3D, me: Node3D, P: Vector3, n: Vector3, side: Vector3) -> void:
	var X := game_shop.global_transform
	_p3_place_marcus_in_shop()
	if animators.has("Marcus"):
		animators["Marcus"].turn_to_face = false
	# ---- F: Eddie on the threshold, calling him back; the camera sees Eddie past the protagonist
	_cam_shot = "F"
	await _walk_wait("Eddie", [Vector3(-3.2, 0.04, 0.75), SHOP_EDDIE_DOOR], 1.8, 3.0)
	animators["Eddie"].face_towards(P)
	await get_tree().process_frame
	var eh = _speaker_head("Eddie")
	var e_head: Vector3 = eh if eh != null else X * (SHOP_EDDIE_DOOR + Vector3(0, 1.65, 0))
	var f_cands := []
	for k in [2.6, 3.2, 2.0]:
		for s_ in [1.4, -1.4, 0.9, -0.9]:
			f_cands.append(e_head + n * k + side * s_ - Vector3(0, 0.1, 0))
	var me_axis := me.global_position
	var f_at = null
	for cnd in f_cands:
		if not cam_point_ok(cnd) or not sight_ok(cnd, e_head):
			continue
		# the protagonist must not stand in the line of sight
		var seg: Vector3 = e_head - cnd
		var tt := clampf((me_axis - cnd).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var closest: Vector3 = cnd + seg * tt
		if Vector2(closest.x - me_axis.x, closest.z - me_axis.z).length() < 0.55:
			continue
		f_at = cnd
		break
	enc_report["eddie_call_anchor_found"] = f_at != null
	cam.global_position = f_at if f_at != null else e_head + n * 2.6 + side * 1.4
	cam.look_at(e_head, Vector3.UP)
	cam.fov = 46.0
	enc_report["eddie_call_cam_clear"] = sight_ok(cam.global_position, e_head)
	Dialogue.say("p3_eddie_calls", false, true)
	animators["Protagonist"].look_target = eddie
	await get_tree().create_timer(2.4).timeout
	# ---- G: both go back in; Eddie shuts the door behind them; Marcus comes over
	_cam_shot = "G"
	var g_pts := []
	for g in SHOP_G_CAMS:
		g_pts.append(X * g)
	# must see them come in past the open leaf (its free end is at z 1.34) and the talk spot
	var g_see := [X * Vector3(-3.05, 1.3, 1.8), X * (SHOP_TALK["Protagonist"] + Vector3(0, 1.5, 0))]
	var g_at = pick_anchor(g_pts, g_see)
	enc_report["regroup_anchor_found"] = g_at != null
	if g_at == null:
		var why := []
		for g in g_pts:
			why.append("%s:%s/%s/%s" % [game_shop.to_local(g).snapped(Vector3.ONE * 0.1), cam_point_ok(g), sight_ok(g, g_see[0]), sight_ok(g, g_see[1])])
		enc_report["regroup_anchor_why"] = why
	cam.global_position = g_at if g_at != null else g_pts[0]
	cam.fov = 55.0
	Dialogue.say("p3_colossus", false, true)
	animators["Protagonist"].look_target = null
	animators["Eddie"].walk_to([Vector3(-3.2, 0.04, 0.7), Vector3(-3.1, 0.04, 1.75), Vector3(-2.4, 0.04, 1.55), SHOP_TALK["Eddie"]], 1.9)
	await get_tree().create_timer(0.5).timeout
	animators["Protagonist"].walk_to([Vector3(-3.2, 0.04, -0.35), Vector3(-3.2, 0.04, 0.9), Vector3(-3.05, 0.04, 1.8), SHOP_TALK["Protagonist"]], 1.9)
	if animators.has("Marcus"):
		animators["Marcus"].walk_to([Vector3(-3.0, 0.04, 3.0), Vector3(-1.0, 0.04, 3.0), SHOP_TALK["Marcus"]], 1.3)
	var sd: Interactable = interactables.get("shop/entrance")
	var hinge := X * Vector3(-2.71, 0.04, 0.37)
	var closed := false
	var t := 0.0
	var names := ["Eddie", "Protagonist", "Marcus"]
	while t < 9.0:
		var mids: Vector3 = Vector3.ZERO
		var cnt := 0
		for k in ["Eddie", "Protagonist"]:
			mids += animators[k].root.global_position
			cnt += 1
		cam.global_basis = Basis(cam.global_basis.get_rotation_quaternion().slerp(
			Transform3D(Basis(), cam.global_position).looking_at(mids / cnt + Vector3(0, 1.3, 0), Vector3.UP).basis.get_rotation_quaternion(),
			minf(get_process_delta_time() * 3.0, 1.0)))
		if not closed and sd and sd.is_open:
			var clear_of_leaf := ["Eddie", "Protagonist"].all(func(k):
				var r: Vector3 = animators[k].root.global_position
				return game_shop.to_local(r).z > 0.5 and Vector2(r.x - hinge.x, r.z - hinge.z).length() > 1.15)
			if clear_of_leaf:
				sd.set_open(false)                              # the door returns to its normal (closed) state
				Sfx.play("door_close", sd.global_position, 0.0, 0.9)
				closed = true
		if names.all(func(k): return not animators.has(k) or not animators[k].is_walking()) and (closed or sd == null):
			break
		await get_tree().process_frame
		t += get_process_delta_time()
	for k in names:                                         # never left half-way (timeout only)
		if animators.has(k) and animators[k].is_walking():
			animators[k].walk_to([])
	if sd and sd.is_open:
		sd.set_open(false)
	enc_report["door_closed_after_regroup"] = sd == null or not sd.is_open
	# everyone faces each other
	var pe: Vector3 = X * SHOP_TALK["Eddie"]
	var pp: Vector3 = X * SHOP_TALK["Protagonist"]
	var pm: Vector3 = X * SHOP_TALK["Marcus"]
	animators["Eddie"].face_towards(pp)
	animators["Protagonist"].face_towards(pe)
	if animators.has("Marcus"):
		animators["Marcus"].face_towards((pe + pp) * 0.5)
	var tf := 0.0
	while tf < 2.2:
		var fe: Vector3 = animators["Eddie"].world_forward()
		var want_e: Vector3 = ((animators["Protagonist"].root.global_position - animators["Eddie"].root.global_position) * Vector3(1, 0, 1)).normalized()
		if tf > 0.5 and fe.angle_to(want_e) < deg_to_rad(12.0):
			break
		await get_tree().process_frame
		tf += get_process_delta_time()
	var r_e: Vector3 = animators["Eddie"].root.global_position
	var r_p: Vector3 = animators["Protagonist"].root.global_position
	enc_report["regroup_dist_m"] = Vector2(r_e.x - r_p.x, r_e.z - r_p.z).length()
	enc_report["regroup_inside"] = game_shop.to_local(r_e).z > 0.5 and game_shop.to_local(r_p).z > 0.5
	enc_report["regroup_facing_deg"] = rad_to_deg(animators["Eddie"].world_forward().angle_to(((r_p - r_e) * Vector3(1, 0, 1)).normalized()))
	# hand over to H: the player stands where the protagonist stood, facing Eddie
	player.global_position = r_p + Vector3(0, 0.02, 0)
	player.velocity = Vector3.ZERO
	var eh2 = _speaker_head("Eddie")
	var to_e: Vector3 = (eh2 if eh2 != null else r_e + Vector3(0, 1.6, 0)) - player.camera.global_position
	player.set_yaw_pitch(atan2(-to_e.x, -to_e.z), clampf(asin(clampf(to_e.normalized().y, -1.0, 1.0)), -0.3, 0.3))
	if animators.has("Marcus"):
		animators["Marcus"].turn_to_face = true
	animators["Eddie"].turn_to_face = true


## Put an NPC exactly at its authored spot (behind a counter): the survivor-body safe placement would push it out
## because its capsule touches the counter. It keeps its collision.
func _place_exact(n: Node3D, at: Vector3) -> void:
	if n == null:
		return
	n.set("_placement_valid", true)
	n.global_position = at
	n.show()


## A cinematic stand-in for the protagonist: the shot is framed on it, so it stands exactly where asked (the safe
## placement of survivor bodies would move it away from the player it overlaps, or hide it) and collides with nothing.
func _cine_double(me: Node3D, at: Vector3) -> void:
	if me.has_method("place_at"):
		me.set("_placement_valid", true)
	me.global_position = at
	me.show()                                       # (showing a survivor body re-enables its layer: cleared after)
	if me is CollisionObject3D:
		(me as CollisionObject3D).collision_layer = 0
		(me as CollisionObject3D).collision_mask = 0


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


## The street lamp the foot comes down by (the nearest within 15 m of the footfall): its light dies for good in a
## burst of sparks, its post (the lamp model standing under the light) crushed and knocked over.
func _crush_lamp(at: Vector3) -> void:
	var best: Light3D = null
	var bd := 15.0
	for l in get_tree().get_nodes_in_group("veil_streetlight"):
		if l is Light3D:
			var d := Vector2(l.global_position.x - at.x, l.global_position.z - at.z).length()
			if d < bd:
				bd = d
				best = l
	if best == null:
		return
	var post: Node3D = null
	var pd := 2.0
	for n in find_children("*Lamp*", "Node3D", true, false):
		if n is Light3D or n is MeshInstance3D or n is CollisionObject3D:
			continue
		var dd := Vector2(n.global_position.x - best.global_position.x, n.global_position.z - best.global_position.z).length()
		if dd < pd:
			pd = dd
			post = n
	enc_report["lamp_crushed"] = String(post.name) if post else String(best.name)
	var spark_at := best.global_position
	best.remove_from_group("veil_streetlight")
	best.visible = false
	var sp := CPUParticles3D.new()
	sp.one_shot = true
	sp.amount = 40
	sp.lifetime = 0.9
	sp.explosiveness = 0.95
	sp.direction = Vector3(0, 1, 0)
	sp.spread = 80.0
	sp.initial_velocity_min = 3.0
	sp.initial_velocity_max = 7.0
	sp.gravity = Vector3(0, -9.8, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.75, 0.35)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	sp.mesh = q
	add_child(sp)
	sp.global_position = spark_at
	sp.emitting = true
	get_tree().create_timer(2.0).timeout.connect(sp.queue_free)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.5)
	flash.light_energy = 4.0
	flash.omni_range = 8.0
	add_child(flash)
	flash.global_position = spark_at
	get_tree().create_timer(0.12).timeout.connect(flash.queue_free)
	Sfx.play("door_close", spark_at, 4.0, 0.5)
	if post and post != self:
		var away := (post.global_position - at) * Vector3(1, 0, 1)
		var axis := Vector3.UP.cross(away.normalized() if away.length() > 0.1 else Vector3.FORWARD).normalized()
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var b0 := post.global_basis
		tw.tween_method(func(k: float):
			if is_instance_valid(post):
				post.global_basis = Basis(axis, k * 1.35) * b0.scaled(Vector3(1.0, lerpf(1.0, 0.55, k), 1.0)), 0.0, 1.0, 0.45)


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
		_ground_burst(t.global_position)
		_tentacles.append(t)


## Where a tentacle comes up through the road: the asphalt breaks - a dark broken patch with a ragged edge at its
## base (so it never stands on clean, unbroken tarmac), chunks thrown up that fall back, a heavy crack, a jolt.
func _ground_burst(at: Vector3) -> void:
	var patch := MeshInstance3D.new()
	patch.name = "TentacleCrack"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.95
	pm.bottom_radius = 0.95
	pm.height = 0.02
	pm.radial_segments = 9                            # a ragged nine-sided hole, not a clean disc
	pm.rings = 1
	patch.mesh = pm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.045, 0.04)
	dark.roughness = 1.0
	patch.material_override = dark
	add_child(patch)
	patch.global_position = Vector3(at.x, at.y + 0.012, at.z)
	patch.rotation.y = randf() * TAU
	var chunk_mat := StandardMaterial3D.new()
	chunk_mat.albedo_color = Color(0.16, 0.16, 0.17)
	for i in 6:
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.12, 0.3), randf_range(0.04, 0.08), randf_range(0.12, 0.28))
		c.mesh = bm
		c.material_override = chunk_mat
		add_child(c)
		var a := TAU * i / 6.0 + randf() * 0.5
		var out := Vector3(cos(a), 0, sin(a))
		c.global_position = at + out * 0.4 + Vector3(0, 0.05, 0)
		var land := at + out * randf_range(1.1, 1.9)
		land.y = at.y + 0.04
		var tw := c.create_tween()
		tw.tween_property(c, "global_position", c.global_position.lerp(land, 0.5) + Vector3(0, randf_range(0.6, 1.1), 0), 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "rotation", Vector3(randf() * 3.0, randf() * 3.0, randf() * 3.0), 0.5)
		tw.tween_property(c, "global_position", land, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Sfx.play("door_close", at + Vector3(0, 0.3, 0), 4.0, 0.45)     # a heavy crack (the asphalt breaking)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(at) < 30.0:
		_shake(cam, 0.25, 0.03)


## Health reached zero: the death cinematic (game/world/death_sequence.gd) plays once, then YOU DIED with RETRY
## (last save) / MAIN MENU. Damage cannot retrigger it (player.damage ignores a dead player).
var death: VeilDeathSequence


func _on_player_died() -> void:
	if death != null:
		return
	_end_cine()
	death = VeilDeathSequence.new()
	death.name = "DeathSequence"
	add_child(death)
	death.play(self)


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
		m_it.used.connect(func(_b): converse(["p3_marcus_talk"], [marcus]))
		interactables["p3/marcus"] = m_it


func _p3_reach_shop() -> void:
	if not Game.has_flag("p3_back_inside") or Game.has_flag("p3_in_shop"):
		return
	Game.set_flag("p3_in_shop")
	_clear_beacon("shop")
	_p3_place_marcus_in_shop()
	await _shop_seated_talk()                     # sit away from the windows, talk, 2 HOURS LATER, the lights
	_p3_shop_talked = true
	# both get ready by the front of the shop: they leave with the protagonist (_p3_flee_together)
	if animators.has("Eddie") and eddie.get_parent() == game_shop:
		npc_walk("Eddie", Vector3(-1.6, 0.04, 1.7), 1.6)
	if animators.has("Marcus") and marcus.get_parent() == game_shop:
		npc_walk("Marcus", Vector3(-2.4, 0.04, 2.4), 1.6)
	_beacon("market", market.global_transform * Vector3(0, 2.6, -0.9), Color(0.7, 0.85, 1.0))


# ------------------------------------------------------------------ the game shop: retreat to the stock room, talk, two hours later
## game-shop local (Pack 04 com_plans GAME_SHOP): the stock room behind the sales floor (x -5.6..0.8, z 8.4..11.6),
## its door at x -2.0 (hinge -2.465, 8.43, opens -95 deg into the room). Seats are the room's own furniture:
## the closed cardboard box (-0.6, 9.3; 0.40 m) and the document-box stack (-5.0, 9.2; 0.80 m). No seat is spawned;
## there are two, so Eddie stays on his feet.
const STOCK_DOOR_OUT := Vector3(-2.0, 0.04, 7.55)
const STOCK_IN := Vector3(-2.0, 0.04, 9.45)
const SEAT_BOX := Vector3(-0.6, 0.04, 9.3)
const SEAT_DOCS := Vector3(-5.0, 0.04, 9.2)
const STOCK_CIRCLE := Vector3(-2.7, 0.04, 9.6)
const EDDIE_STAND := Vector3(-2.6, 0.04, 10.4)
const SEATED_EYE := 1.22                      # box top 0.44 + seated eye height
const STAND_EYE := 1.62
var seated_report := {}
var _steps_on := false


## First person along a collision-free route (A* in the shop's frame): the camera rides on the protagonist's body.
func _fp_walk(cam: Camera3D, to_local: Vector3, speed: float, eye := STAND_EYE) -> void:
	var X := game_shop.global_transform
	var from := game_shop.to_local(player.global_position)
	from.y = to_local.y
	var pts: Array = npc_route(game_shop, from, to_local)
	player.set_physics_process(false)             # scripted steps (the route is already collision-free)
	for q in pts:
		var target: Vector3 = X * (q as Vector3)
		# never loops forever: done within 15 cm, or when its time is up (then he is put on the point)
		var budget := ((target - player.global_position) * Vector3(1, 0, 1)).length() / maxf(speed, 0.1) + 1.5
		var spent := 0.0
		while true:
			var d := (target - player.global_position) * Vector3(1, 0, 1)
			if d.length() < 0.15 or spent > budget:
				if spent > budget:
					player.global_position = Vector3(target.x, player.global_position.y, target.z)
				break
			var dt := get_process_delta_time()
			spent += dt
			var stepv := d.normalized() * minf(speed * dt, d.length())
			player.global_position += stepv
			var want := Transform3D(Basis(), cam.global_position).looking_at(cam.global_position + d.normalized() + Vector3(0, -0.08, 0), Vector3.UP).basis
			cam.global_basis = Basis(cam.global_basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), minf(dt * 7.0, 1.0)))
			cam.global_position = player.global_position + Vector3(0, eye - 0.15 + sin(Time.get_ticks_msec() * 0.012) * 0.025 * speed / 4.0, 0)
			await get_tree().process_frame
	player.set_physics_process(true)


func _fp_look(cam: Camera3D, at: Vector3, seconds: float) -> void:
	var b0 := cam.global_basis.get_rotation_quaternion()
	var b1 := Transform3D(Basis(), cam.global_position).looking_at(at, Vector3.UP).basis.get_rotation_quaternion()
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		var k := clampf(t / seconds, 0.0, 1.0)
		cam.global_basis = Basis(b0.slerp(b1, k * k * (3.0 - 2.0 * k)))
		await get_tree().process_frame


func _fp_track(cam: Camera3D, at: Vector3, rate: float) -> void:
	var want := Transform3D(Basis(), cam.global_position).looking_at(at, Vector3.UP).basis.get_rotation_quaternion()
	cam.global_basis = Basis(cam.global_basis.get_rotation_quaternion().slerp(want, minf(get_process_delta_time() * rate, 1.0)))


func _stock_door(open: bool, seconds := 0.45) -> void:
	var leaf := game_shop.find_child("INT_Door_StockRoom", true, false) as Node3D
	if leaf == null:
		return
	if not leaf.has_meta("closed_xf"):
		leaf.set_meta("closed_xf", leaf.transform)
	var base: Transform3D = leaf.get_meta("closed_xf")
	var t := base if not open else Transform3D(base.basis * Basis(Vector3.UP, deg_to_rad(-95.0)), base.origin)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(leaf, "transform", t, seconds)
	Sfx.play("door_open" if open else "door_close", leaf.global_position, -4.0)
	await tw.finished
	seated_report["door_open" if open else "door_closed"] = true


func _shop_seated_talk() -> void:
	var X := game_shop.global_transform
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	hud.allow_pause = false
	var cam := Camera3D.new()
	cam.name = "RetreatCam"
	add_child(cam)
	cam.global_transform = player.camera.global_transform
	cam.fov = player.camera.fov
	cam.current = true
	seated_report["spawned_seats"] = 0
	# 1. panic: away from the storefront, a run for the stock room in first person; Eddie and Marcus come too
	for k in ["Eddie", "Marcus"]:
		if animators.has(k):
			animators[k].set_mood("scared")
			animators[k].turn_to_face = false
	npc_walk("Eddie", STOCK_DOOR_OUT + Vector3(-0.7, 0, -0.9), 3.4)
	npc_walk("Marcus", STOCK_DOOR_OUT + Vector3(0.6, 0, -1.1), 3.2)
	await _fp_look(cam, X * (STOCK_DOOR_OUT + Vector3(0, 1.5, 0)), 0.45)
	await _fp_walk(cam, STOCK_DOOR_OUT, 4.2)
	await _fp_look(cam, X * (STOCK_IN + Vector3(0, 1.4, 0.6)), 0.2)
	await _stock_door(true, 0.35)                 # shoved open
	# Eddie and Marcus go in first; the protagonist holds the door (a step aside) and goes in last
	npc_walk("Eddie", EDDIE_STAND, 3.0)
	npc_walk("Marcus", SEAT_DOCS + Vector3(0.62, 0, 0.0), 3.0)
	await _fp_walk(cam, STOCK_DOOR_OUT + Vector3(0.85, 0, -0.35), 2.4)
	var t := 0.0
	var inside := func(k: String) -> bool:
		return not animators.has(k) or game_shop.to_local(animators[k].root.global_position).z > 8.9
	while t < 6.0 and not (inside.call("Eddie") and inside.call("Marcus")):
		_fp_track(cam, X * (STOCK_IN + Vector3(0, 1.3, 0)), 5.0)
		await get_tree().process_frame
		t += get_process_delta_time()
	for pair in [["Eddie", EDDIE_STAND], ["Marcus", SEAT_DOCS + Vector3(0.62, 0, 0.0)]]:
		if not inside.call(pair[0]):                       # never left outside: put in (rare; logged)
			animators[pair[0]].walk_to([])
			animators[pair[0]].root.position = pair[1]
			seated_report["snapped_inside"] = seated_report.get("snapped_inside", 0) + 1
	seated_report["others_in_first"] = inside.call("Eddie") and inside.call("Marcus")
	await _fp_walk(cam, STOCK_IN, 3.0)
	seated_report["fp_retreat"] = true
	# 2. inside last: turn, pull the door shut
	await _fp_look(cam, X * (STOCK_DOOR_OUT + Vector3(0, 1.3, 0.6)), 0.45)
	await _stock_door(false, 0.6)
	_colossus_step_outside(cam, 0.8)
	await get_tree().create_timer(1.4).timeout   # everyone holds still, listening
	# 3. take a seat: the protagonist on the cardboard box, Marcus on the document boxes, Eddie stands
	await _fp_walk(cam, SEAT_BOX + Vector3(-0.55, 0, 0.0), 1.4)
	var circle := X * (STOCK_CIRCLE + Vector3(0, 1.0, 0))
	await _fp_look(cam, circle, 0.4)
	var tw_sit := create_tween()
	tw_sit.tween_property(cam, "global_position", X * (SEAT_BOX + Vector3(-0.05, SEATED_EYE, 0)), 0.8).set_trans(Tween.TRANS_SINE)
	t = 0.0
	while t < 5.0 and ["Eddie", "Marcus"].any(func(k): return animators.has(k) and animators[k].is_walking()):
		await get_tree().process_frame
		t += get_process_delta_time()
	_seat("Marcus", SEAT_DOCS, 0.80, STOCK_CIRCLE)
	if animators.has("Eddie"):
		animators["Eddie"].walk_to([])
		animators["Eddie"].face_towards(X * STOCK_CIRCLE)
	await tw_sit.finished
	await _fp_look(cam, circle, 0.5)
	seated_report["seated"] = animators.has("Marcus") and animators["Marcus"].seated
	seated_report["anchor"] = true
	# the conversation (approved lines), quiet, the creature still walking outside
	_steps_on = true
	_distant_steps(cam)
	Dialogue.confirm_mode = true
	await _say_all("p3_seated_a")
	_colossus_step_outside(cam, 1.0)
	await get_tree().create_timer(1.2).timeout
	await _say_all("p3_seated_b")
	Dialogue.confirm_mode = false
	# 4. hold, slow fade, the store goes quiet, 2 HOURS LATER
	await get_tree().create_timer(2.0).timeout
	_steps_on = false
	await hud.fade_to(1.0, 3.0)
	Sfx.stop_ambience()
	var lbl := VeilUI.label("2 HOURS LATER", 30)   # the game's title font (as the chapter cards)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.modulate.a = 0.0
	hud.add_child(lbl)                            # above the fade layer
	var tl := create_tween()
	tl.tween_property(lbl, "modulate:a", 1.0, 0.8)
	tl.tween_interval(2.0)
	tl.tween_property(lbl, "modulate:a", 0.0, 0.8)
	await tl.finished
	lbl.queue_free()
	seated_report["time_skip"] = true
	Game.set_flag("p3_two_hours_later")
	for n in find_children("Colossus_Encounter", "", true, false):
		n.queue_free()                            # it has gone: no more footsteps
	if market_merch and market_merch.has_method("loot"):
		market_merch.loot()                       # people raided the supermarket in the meantime
	_tip_carts()
	# 5. a short third-person look at the three of them, from inside the room (validated camera point)
	var me := _spawn_npc(load(PROTAG_PATH), load(PROTAG_FACE_PATH), game_shop, SEAT_BOX + Vector3(0.05, 0, 0), 0.0, "Protagonist")
	_cine_double(me, game_shop.to_global(SEAT_BOX + Vector3(0.05, 0, 0)))                         # a stand-in: exactly here, no collision (it overlaps the player)
	me.name = "Protagonist_Seated"
	_seat("Protagonist", SEAT_BOX, 0.44, STOCK_CIRCLE)
	var must := [X * (STOCK_CIRCLE + Vector3(0, 1.0, 0)), X * (SEAT_BOX + Vector3(0, 1.1, 0)), X * (SEAT_DOCS + Vector3(0.3, 1.4, 0)),
		X * (EDDIE_STAND + Vector3(0, 1.5, 0))]
	var c_at = pick_anchor([X * Vector3(0.35, 2.2, 8.75), X * Vector3(0.4, 2.35, 10.1), X * Vector3(-5.2, 2.25, 8.75),
		X * Vector3(-3.6, 2.5, 8.7), X * Vector3(-0.4, 2.45, 10.6), X * Vector3(-1.4, 2.5, 8.7)], must)
	seated_report["third_anchor"] = c_at != null
	var cam3 := Camera3D.new()
	cam3.name = "StockRoomCam"
	add_child(cam3)
	cam3.global_position = c_at if c_at != null else X * Vector3(-1.4, 2.4, 8.75)
	cam3.look_at(X * (STOCK_CIRCLE + Vector3(0, 0.9, 0)), Vector3.UP)
	cam3.fov = 62.0
	cam3.current = true
	Sfx.start_ambience()
	await hud.fade_to(0.0, 2.0)
	await get_tree().create_timer(2.4).timeout
	# 6. first person again: up, out to the front window - the supermarket's lights across the street
	await hud.fade_to(1.0, 0.5)
	me.queue_free()
	animators.erase("Protagonist")
	faces.erase("Protagonist")
	cam.current = true
	cam3.queue_free()
	if animators.has("Marcus"):
		animators["Marcus"].set_seated(false)
		place_survivor(animators["Marcus"].root, SEAT_DOCS + Vector3(0.75, 0, 0.1))   # stood up clear of the boxes (screen black)
	cam.global_position = X * (SEAT_BOX + Vector3(-0.05, STAND_EYE, 0))
	await hud.fade_to(0.0, 0.8)
	await _fp_look(cam, X * (STOCK_IN + Vector3(0, 1.4, -0.8)), 0.6)
	await _fp_walk(cam, STOCK_IN, 1.6)
	await _stock_door(true, 0.6)
	npc_walk("Eddie", Vector3(-1.4, 0.04, 1.3), 1.4)
	npc_walk("Marcus", Vector3(-2.3, 0.04, 2.1), 1.3)
	await _fp_walk(cam, Vector3(-0.6, 0.04, 2.0), 1.6)
	await _fp_look(cam, market.global_transform * Vector3(0.0, 4.0, -0.3), 0.9)
	Dialogue.confirm_mode = true
	await _say_all("p3_lights")
	Dialogue.confirm_mode = false
	seated_report["lights_talk"] = true
	# control back where the protagonist stands (inside the shop)
	var dm: Vector3 = (market.global_position - player.global_position) * Vector3(1, 0, 1)
	player.set_yaw_pitch(atan2(-dm.x, -dm.z), 0.0)
	player.visible = true
	cam.queue_free()
	player.camera.current = true
	for k in ["Eddie", "Marcus"]:
		if animators.has(k):
			animators[k].turn_to_face = true
	hud.allow_pause = true
	player.controls_enabled = true


## Sit a character on an existing seat (shop-local), facing `toward`.
func _seat(speaker: String, seat: Vector3, height: float, toward: Vector3, edge := 0.22) -> void:
	var a = animators.get(speaker)
	if a == null:
		return
	var X := game_shop.global_transform
	var to2: Vector3 = toward - seat
	to2.y = 0.0
	a.walk_to([])
	if not place_survivor(a.root, seat + to2.normalized() * edge):
		return          # on the seat's front edge, not inside the box
	a.turn_to_face = false
	a.face_towards(X * toward)
	a.root.rotate_y(a.world_forward().signed_angle_to((X.basis * to2).normalized(), Vector3.UP))
	a.set_seated(true, height)
	a.set_mood("scared")


func _say_all(id: String) -> void:
	Dialogue.say(id, false, true)
	await get_tree().process_frame
	while Dialogue.is_busy():
		await get_tree().process_frame


## One heavy Colossus footstep somewhere outside the shop front (sound + a restrained shake of the shot).
func _colossus_step_outside(cam: Camera3D, strength := 0.6) -> void:
	var out: Vector3 = game_shop.global_transform * Vector3(randf_range(-14.0, 14.0), 2.0, -24.0)
	Sfx.play("colossus_step", out, 2.0 * strength, 0.66)
	if is_instance_valid(cam):
		_shake(cam, 0.3, 0.018 * strength)


func _distant_steps(cam: Camera3D) -> void:
	while _steps_on and is_instance_valid(cam):
		await get_tree().create_timer(randf_range(3.5, 5.5)).timeout
		if _steps_on:
			_colossus_step_outside(cam, 0.6)


## A couple of the supermarket's shopping carts lie on their side after the raid.
func _tip_carts() -> void:
	if market.has_meta("carts_tipped"):
		return
	market.set_meta("carts_tipped", true)
	var k := 0
	for n in market.find_children("Cart_*", "Node3D", true, false):
		if k >= 2:
			break
		var c := n as Node3D
		if c is RigidBody3D:
			(c as RigidBody3D).freeze = true
		c.rotation.z = 1.5 if k == 0 else -1.45
		c.position.y += 0.28
		k += 1


## After the shop talk, once the player is outside: Eddie and Marcus run WITH the protagonist to the supermarket
## (the existing companion follow, breadcrumbs of the player's own path: no wall clipping, no teleport).
var _p3_followers: Array = []


const TENTACLE_ESCAPE_SHOT := preload("res://game/world/tentacle_escape_shot.gd")


func _p3_escape_tentacle() -> void:
	if _encounter_running:
		return                                           # (the tick asks every frame while the shot plays)
	_encounter_running = true
	var was_controls := player.controls_enabled
	var was_look := player.look_enabled
	var was_pause := hud.allow_pause
	player.controls_enabled = false
	player.look_enabled = false
	player.velocity = Vector3.ZERO
	hud.allow_pause = false
	var suspended: Array[Node] = []
	for tentacle in _tentacles:
		var ai := tentacle.get_node_or_null("AI") as Node
		if ai and ai.is_processing():
			ai.set_process(false)
			suspended.append(ai)
	var shot := TENTACLE_ESCAPE_SHOT.new()
	shot.name = "TentacleEscapeShot"
	add_child(shot)
	enc_report["tentacle_escape_shot"] = await shot.play(self)
	shot.queue_free()
	player.camera.make_current()
	player.controls_enabled = was_controls
	player.look_enabled = was_look
	hud.allow_pause = was_pause
	for ai in suspended:
		if is_instance_valid(ai):
			ai.set_process(true)
	_encounter_running = false
	_p3_flee_together()


func _p3_flee_together() -> void:
	_p3_npcs_moved = true
	Game.set_flag("p3_fled_together")             # the run to the supermarket begins (chapter 4)
	hud.chapter_start(4)
	_chase_start()
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
		# Follow the collision-checked route to the door before joining the outdoor trail.
		var din := game_shop.get_node("Doorways/Entrance_Inside") as Node3D
		var dout := game_shop.get_node("Doorways/Entrance_Outside") as Node3D
		var body := n as VeilSurvivorBody
		var via: Array = []
		if game_shop.to_local(n.global_position).z > 0.2 and body:
			var safe := body.nearest_safe(din.global_position)
			if safe.is_finite():
				via = npc_route(game_shop, game_shop.to_local(n.global_position), game_shop.to_local(safe), body)
				via = via.map(func(point): return game_shop.to_global(point))
				if not via.is_empty():
					via.append(dout.global_position)
		f.start(via)
		if f.anim:
			f.anim.physical = false                      # the trail is the player's own footsteps: no jamming
		_p3_followers.append(f)
		if animators.has(String(n.name)):
			animators[String(n.name)].set_mood("scared")


## The run to the supermarket: RUN TO THE STORE!, the chase track, the three tentacles on the road between the
## two stores awake and striking (their own wind-up / strike / recovery, game/enemies/tentacle_ai.gd). It ends at
## the supermarket's doors: the music fades and the tentacles stop striking (they retract when the doors shut).
const CHASE_MUSIC := preload("res://game/audio/the_veil_tentacle_chase_FAST.wav")
var _chase_music: AudioStreamPlayer


func _chase_start() -> void:
	if Game.has_flag("p3_in_market"):
		return
	_p3_spawn_tentacles()
	hud.set_hint("RUN TO THE STORE!")
	get_tree().create_timer(4.0).timeout.connect(func():
		if hud.hint.text == "RUN TO THE STORE!":
			hud.set_hint(""))
	if _chase_music == null:
		_chase_music = AudioStreamPlayer.new()
		_chase_music.stream = CHASE_MUSIC
		_chase_music.volume_db = -10.0
		add_child(_chase_music)
		_chase_music.finished.connect(func():
			if Game.has_flag("p3_fled_together") and not Game.has_flag("p3_in_market"):
				_chase_music.play())
		_chase_music.play()


func _chase_end() -> void:
	for t in _tentacles:
		var ai = t.get_node_or_null("AI") if is_instance_valid(t) else null
		if ai:
			ai.set_process(false)                      # safe inside: no more strikes
	if _chase_music and _chase_music.playing:
		var tw := create_tween()
		tw.tween_property(_chase_music, "volume_db", -40.0, 2.0)
		tw.tween_callback(_chase_music.stop)


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
	var body := a.root as VeilSurvivorBody
	# scripted walks route around the static world only (walls, counters, doors): the player and the other NPCs
	# are moving and must not make the route "blocked" (an empty route left Eddie standing outside the stock room)
	speed *= 1.2                                     # NPCs a little quicker
	var path := npc_route(par, a.root.position, to, body, true)
	if path.is_empty() and body:
		var safe := body.nearest_safe(par.to_global(to))
		if safe.is_finite():
			path = npc_route(par, a.root.position, par.to_local(safe), body, true)
	if not path.is_empty():
		a.walk_to(path, speed)
		return
	# no route: never walk through a wall. A clear straight line is walked; otherwise the NPC is put there, and only
	# while the camera cannot see it (else it stays and is placed at the next unseen moment)
	var from_w: Vector3 = a.root.global_position
	var to_w := par.to_global(to)
	var space := get_world_3d().direct_space_state
	var clear := true
	for h in [0.5, 1.3]:
		var rq := PhysicsRayQueryParameters3D.create(from_w + Vector3(0, h, 0), to_w + Vector3(0, h, 0), 1, [player.get_rid()])
		if not space.intersect_ray(rq).is_empty():
			clear = false
	if clear:
		a.walk_to([to], speed)
		return
	_place_unseen(a.root, to)


## Put an NPC at `to` (its parent's frame) once neither its spot nor the target is in view.
func _place_unseen(n: Node3D, to: Vector3) -> void:
	var par := n.get_parent_node_3d()
	for i in 600:
		var cam := get_viewport().get_camera_3d()
		if cam == null or not (cam.is_position_in_frustum(n.global_position + Vector3(0, 1, 0)) or cam.is_position_in_frustum(par.to_global(to) + Vector3(0, 1, 0))):
			break
		await get_tree().create_timer(0.1).timeout
	if is_instance_valid(n) and n.has_method("place_at"):
		place_survivor(n, to)


## Reuse the local XZ grid search for survivor capsules and cinematic camera routes.
## Survivor searches return an empty path when the requested route is obstructed.
func npc_route(frame: Node3D, from: Vector3, to: Vector3, body: VeilSurvivorBody = null, static_only := false) -> Array:
	var space := get_world_3d().direct_space_state
	var sph := SphereShape3D.new()
	sph.radius = 0.28
	var q := PhysicsShapeQueryParameters3D.new()
	var ex_rid: Array[RID] = [player.get_rid()]
	if body:
		ex_rid.append(body.get_rid())
	if static_only:
		# scripted walks: the original check (a sphere at knee and chest height, static world only). The full capsule
		# started 3.5 cm above the floor, so the 15 cm kerb at the supermarket entrance counted as a wall and every
		# route into the store failed.
		body = null
	q.shape = body.capsule if body else sph
	q.collision_mask = 1 if static_only else (VeilSurvivorBody.SOLIDS if body else 1 | VeilSurvivorBody.LAYER)
	q.exclude = ex_rid
	var heights := [VeilSurvivorBody.HEIGHT * 0.5 + VeilSurvivorBody.FOOT_CLEARANCE] if body else [0.5, 1.3]
	var X := frame.global_transform
	var y := from.y
	var CELL := 0.3
	var lo := Vector2(minf(from.x, to.x) - 6.0, minf(from.z, to.z) - 6.0)
	if body:
		var end := Vector2(to.x, to.z)
		lo = end + (lo - end).snapped(Vector2.ONE * CELL)
	var cache := {}
	var free_at := func(c: Vector2i) -> bool:
		if cache.has(c):
			return cache[c]
		var p := Vector3(lo.x + c.x * CELL, y, lo.y + c.y * CELL)
		var ok := not body or VeilSurvivorBody.floor_at(space, X * p).is_finite()
		for h in heights:
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
		if cur == g or (not body and (cur - g).length_squared() <= 1):
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
		return [] if body else [to]
	var cells: Array = [g]
	while cells[0] != s and came.has(cells[0]):
		cells.push_front(came[cells[0]])
	var pts: Array = []
	for c in cells:
		pts.append(Vector3(lo.x + c.x * CELL, y, lo.y + c.y * CELL))
	if pts.size() == 1:
		return [to]
	pts[-1] = to
	# String pulling: keep only the waypoints needed for clear shape sweeps.
	pts[0] = from
	var out: Array = []
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1:
			q.transform = Transform3D(Basis(), X * (pts[i] + Vector3(0, heights[0] if body else 0.8, 0)))
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
		n.reparent(market, true)
		place_survivor(n, pair[1])
		var anim = n.get_node_or_null("Animator")
		if anim:
			anim.walk_to([])
			anim.set_mood("scared")
			var want := market.global_transform.basis * Vector3(0, 0, -1)   # face the entrance
			want.y = 0.0
			n.rotate_y(anim.world_forward().signed_angle_to(want.normalized(), Vector3.UP))


func _p3_reach_market() -> void:
	if _encounter_running or not Game.has_flag("p3_in_shop") or Game.has_flag("p3_in_market"):
		return
	if not _p3_npcs_moved:
		_p3_move_npcs_to_market()
	_p3_stop_following()                         # they came in with the player
	_chase_end()
	Game.set_flag("p3_in_market")
	_set_auto_doors(true)                       # the power dies with the doors open
	_doors_powered = false
	_market_blackout()
	shut_it.prompt_text = "[E] Pull the Doors Shut"
	npc_walk("Eddie", MARKET_EDDIE_POS, 1.4)           # around the vestibule wall, carts and baskets
	npc_walk("Marcus", MARKET_MARCUS_POS, 1.4)
	for d in _auto_doors:
		_glow(d[0], true, Color(0.7, 0.85, 1.0))
	Dialogue.say("p3_market", false, true)
	talk_shot(_dlg_time(["p3_market"]))


## The main power is already gone when the group gets in: every store light is off (the street lamps outside stay
## on). The windows, the night outside and, soon, the flashlight are what there is to see by; the back-room
## breaker (Phase 4) brings the emergency lights back, as before.
func _market_blackout() -> void:
	for l in market.get_node("Lights").get_children():
		if l is Light3D:
			(l as Light3D).visible = false


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
	if Game.has_flag("p3_two_hours_later") or Game.has_flag("p3_in_market"):
		if market_merch and market_merch.has_method("loot"):
			market_merch.loot()
		_tip_carts()
	if Game.has_flag("p3_in_shop"):
		_p3_shop_talked = true
		_p3_move_npcs_to_market()
	if Game.has_flag("p3_in_market") and not Game.has_flag("p3_doors_shut"):
		_doors_powered = true
		_set_auto_doors(true)
		_doors_powered = false
		_market_blackout()
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
		ol.distance_fade_begin = 50.0          # light budget: see _light_budget (was 75 + 25 m)
		ol.distance_fade_length = 15.0
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
	# automatic reverse parking starts in the middle of the lot (west / centre modules, the aisle between the rows)
	var lot := _park_lot_xf()
	_area("Trigger_AutoPark", lot * Vector3(6.5, 1.0, 10.0), Vector3(17.0, 4.0, 9.0), 4, _maybe_auto_park, lot.basis)


var _exit_requested := false


func _physics_process(delta: float) -> void:
	talk_watchdog()
	_p3_tick(delta)
	_arrival_ease()
	if _exit_requested:
		_exit_requested = false
		exit_car()
	if in_car:
		drive_time += delta
		var pk := get_node_or_null("Trigger_Parking") as Area3D
		if pk and pk.overlaps_body(sedan) and absf(sedan.speed) < 0.5 and Game.has_flag("entered_car"):
			_park_t += delta
			if _park_t > 1.0 and not Game.has_flag("parked") and not car_on_asphalt():
				if hud.hint.text == "":
					hud.set_hint("Park on the tarmac - not on the grass or the pavement.")
				_park_t = 0.0
			elif _park_t > 1.0 and not Game.has_flag("parked"):
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
	if Game.has_flag("groceries_done") and Game.has_flag("game_bought") and not Game.has_flag("vehicle_repaired"):
		if expedition and expedition.dead_car():
			return                                   # the survival expansion: inspect / repair the dead car
		_p3_car_dead()
		return
	if expedition and expedition.has_method("car_menu") and await expedition.car_menu():
		return                                       # refuelled / patched / looked at it, not getting in now
	in_car = true
	player.activate(false)
	await sedan.swing_door(true, 0.3)
	if survivors and survivors.has_method("board_car"):
		await survivors.board_car()                  # a trip companion takes the passenger seat before we drive off
	sedan.set_driven(true)
	sedan.swing_door(false, 0.35)
	Game.set_flag("left_house")
	Game.set_flag("entered_car")
	Dialogue.say("in_car", true)
	hud.set_hint("W accelerate · S brake / reverse · A/D steer · Space handbrake · Q radio · E exit · mouse look"
		+ ("\n" + sedan.status_text() if sedan.survival else ""))


func exit_car() -> void:
	if not in_car or not sedan.driven or _auto_parking:
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
	if survivors and survivors.has_method("leave_car"):
		survivors.leave_car()
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


func can_heal_with(id: String) -> bool:
	return Game.has_item(id) and float(Game.item_info(id).get("heal_amount", 0)) > 0.0 \
		and player.health > 0.0 and player.health < VeilPlayer.MAX_HEALTH and not in_car

func use_healing_item(id: String) -> bool:
	if not can_heal_with(id):
		return false
	player.heal(float(Game.item_info(id)["heal_amount"]))
	Game.remove_item(id)
	save()
	return true

func shelter_roster() -> Array:
	var roster := []
	for speaker in animators:
		var body := (animators[speaker] as NpcAnimator).root as VeilSurvivorBody
		if is_instance_valid(body) and body.visible and body.get_parent() == market \
				and speaker != "Cashier":
			roster.append(speaker)
	roster.sort()
	return roster

func deposit_shelter_item(id: String) -> bool:
	var resource := Game.shelter_resource(id)
	if resource.is_empty() or not Game.has_item(id) or not Game.has_flag("p4_started"):
		return false
	if id == "batteries":
		var flashlight := get_tree().get_first_node_in_group("veil_flashlight") as VeilFlashlight
		if flashlight == null or flashlight.spares <= 0:
			return false
		flashlight.add_spares(-1)
		if flashlight.spares == 0:
			Game.remove_item(id)
		else:
			Game.inventory_changed.emit()
	else:
		Game.remove_item(id)
	var stock := Game.shelter_stock()
	stock[resource] = int(stock[resource]) + 1
	Game.world_state["shelter_stock"] = stock
	save()
	return true


var _restoring_survivors := false

## A chapter checkpoint (user://checkpoints/<name>.json): the same contents as a save, in its own file, so the
## player's own save slot is never overwritten by the story.
func save_checkpoint(checkpoint: String) -> void:
	save(Game.checkpoint_path(checkpoint))


func save(path := "") -> void:
	var positions := {}
	for speaker in animators:
		var body := (animators[speaker] as NpcAnimator).root as VeilSurvivorBody
		if is_instance_valid(body) and body.get_parent() == market and body.visible and body.has_meta("shelter_home"):
			var feet: Vector3 = body.get_meta("shelter_feet")
			var an = animators.get(speaker)
			if an and not an.is_walking():
				feet = body.global_position          # where they stand now: they stay there after a load
			positions[speaker] = {"home": body.get_meta("shelter_home"), "feet": [feet.x, feet.y, feet.z]}
	Game.world_state["shelter_npc_positions"] = positions
	if Game.has_flag("p4_started"):
		Game.world_state["shelter_roster"] = shelter_roster()
	var p := player.global_position
	Game.player_state = {"in_vehicle": in_car, "pos": [p.x, p.y, p.z], "yaw": player.rotation.y, "health": player.health}
	Game.vehicle_state = sedan.state()
	Game.save_game(path if path != "" else Game.SAVE_PATH)


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
		hud.set_hint("W accelerate · S brake / reverse · A/D steer · Space handbrake · Q radio · E exit")
	player.health = clampf(float(ps.get("health", VeilPlayer.MAX_HEALTH)), 0.0, VeilPlayer.MAX_HEALTH)
	player.health_changed.emit(player.health, VeilPlayer.MAX_HEALTH)
	_restore_survivor_story.call_deferred()
	return true


func _restore_survivor_story() -> void:
	_restoring_survivors = true
	_p3_restore()
	if Game.has_flag("p3_doors_shut"):
		_start_phase4(true)
	_restoring_survivors = false


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


var _world_live := false
var _save_pending := false


## One save a moment after the inventory changes (several pickups in a row make one save).
func _save_soon() -> void:
	if _save_pending or not _world_live:
		return
	_save_pending = true
	await get_tree().create_timer(0.5, true).timeout
	_save_pending = false
	save_if_alive()


## Leaving (main menu, quit, closing the window) keeps what was found; never while dead (the death screen reloads).
func save_if_alive() -> void:
	if _world_live and is_instance_valid(player) and player.health > 0.0:
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_if_alive()


func _to_menu() -> void:
	save_if_alive()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.stop_ambience()
	get_tree().change_scene_to_file("res://game/scenes/MainMenu.tscn")
