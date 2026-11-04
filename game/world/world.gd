extends Node3D
## THE VEIL - Phase 1 world controller (Greyhaven, Friday 6:42 PM).
## Wires the existing assets into gameplay: the Player_Home's own interaction metadata (doors, drawers,
## cabinets, light switches, the fridge, the car keys), observation points, story triggers, the sedan,
## save / restore and the opening sequence. No monsters, no mist.

const PLAYER_SCRIPT := preload("res://game/player/player.gd")
const SEDAN_SCRIPT := preload("res://game/vehicles/player_sedan.gd")
const HUD_SCRIPT := preload("res://game/ui/hud.gd")
const CAN := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_CannedFood.glb")
const WATER := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_WaterBottle.glb")

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
	_setup_triggers()
	_apply_view_ranges()
	Game.flag_set.connect(_on_flag)
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
				cfg.merge({"kind": "hinge", "open_deg": float(e.get("open_deg", 90.0))})
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


func _on_fridge(_by: Node) -> void:
	if not Game.has_flag("fridge_checked"):
		Dialogue.say("fridge_empty", false, true)
		Game.set_flag("fridge_checked")
	elif interactables.values().any(func(i): return i.label == "Refrigerator" and i.is_open):
		Dialogue.say("fridge_again", true)


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


func _physics_process(delta: float) -> void:
	if in_car:
		drive_time += delta
		var pk := get_node_or_null("Trigger_Parking") as Area3D
		if pk and pk.overlaps_body(sedan) and absf(sedan.speed) < 0.5 and Game.has_flag("entered_car"):
			_park_t += delta
			if _park_t > 1.0 and not Game.has_flag("parked"):
				Game.set_flag("reached_town")
				Game.set_flag("parked")
				_finish()
		else:
			_park_t = 0.0


func _finish() -> void:
	if _ending:
		return
	_ending = true
	Dialogue.say("parked", true, true)
	Dialogue.say("game_shop", true)
	save()
	await get_tree().create_timer(6.5).timeout
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
	if not in_car:
		return
	if absf(sedan.speed) > 1.0:
		Dialogue.say("no_exit", false, true)
		return
	var spot: Variant = sedan.exit_spot(get_world_3d().direct_space_state, player.get_rid())
	if spot == null:
		Dialogue.say("no_room", false, true)
		return
	sedan.speed = 0.0
	sedan.set_driven(false)
	sedan.swing_door(true, 0.25)
	in_car = false
	player.global_position = spot
	player.set_yaw_pitch(sedan.global_rotation.y, 0.0)
	player.activate(true)
	hud.set_speed(-1.0)
	hud.set_hint("")
	await get_tree().create_timer(0.6).timeout
	sedan.swing_door(false, 0.35)


func _unhandled_input(e: InputEvent) -> void:
	if in_car and e.is_action_pressed("interact"):
		exit_car()


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
	return true


func _to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://game/scenes/MainMenu.tscn")
