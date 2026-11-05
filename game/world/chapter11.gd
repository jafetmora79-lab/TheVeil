extends Node
class_name VeilChapter11
## THE VEIL - displayed CHAPTER 12 "The Farm Road" (internal ids keep the file's numbering: chapter11.gd, flags
## ch11_*, chapter_11_complete). Starts in the mill-worker house right after "No Safe Road" (flag
## chapter_10_complete); created by chapter10.gd. State: story flags + Game.world_state["ch11"].
##
## The morning talk (Marcus's lines only if he survived) -> the farm road across the fields west of town: an
## abandoned pickup, a broken picket fence, an empty country bus shelter (a snack inside, optional) -> a camp
## someone left a day ago: bedroll, cold lantern, an empty can, a small jacket, scuffed earth, and a note (read in
## the inventory's inspect view, like Noah's first note) -> something moves in the field (first person: the view
## is turned and zoomed onto a Hound's silhouette in the fog, then handed back) -> the old abandoned farmhouse
## (Greyhaven's HOUSE_20, a Pack 03 "Weathered abandoned house"): the group waits in the living room while the
## player searches the living room, the kitchen, the back door and the upstairs bedroom, where Noah left a
## message (read in the inventory) -> back with the group -> the encounter: a shape passes the side window, a
## blow on the back door, then a Hound (the Chapter 7 Hound AI: collisions, non-lethal bites, a leash) comes
## round the house while the player leads the group out of the front door to the field -> a light in the farmhouse
## farther down the road (HOUSE_19) flickers; the view is drawn to it; a shape passes behind it; nothing is
## revealed -> "CHAPTER 12 COMPLETE". The next chapter is not started. Noah is not found here.

const STATE := "ch11"
const CHAPTER := 12                                    # displayed number (game/data/chapters.json)
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const HOUND_AI := preload("res://game/enemies/hound_ai.gd")
const PICKUP_TRUCK := preload("res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_Pickup_Abandoned.glb")
const PICKET := preload("res://THE_VEIL_ASSETS_V2/02_Town/Fences/FN_Picket_2.5m.glb")
const BUS_SHELTER := preload("res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/SP_BusShelter.glb")
const BLANKET := preload("res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_Blanket_Folded.glb")
const PILLOW := preload("res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_Pillow.glb")
const LANTERN := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_EmergencyLantern.glb")
const CAN := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_CannedFood.glb")
const BAGS := preload("res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Abandoned_Props/ABN_GroceryBags_Spilled.glb")
const NOTE := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Story_Items/INV_FoldedNote.glb")
const NOTEBOOK := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Story_Items/INV_Notebook.glb")
const SNACK := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_EnergySnack.glb")

# ---- world (collision-mapped: open fields west of x -90; the fenced lots of the west-edge houses at x -86..-68;
# HOUSE_20 (abandoned) at (-77.9, -92), front porch toward -z; HOUSE_19 farther down at (-78, -116))
const ROAD := [Vector3(-91.4, 0.2, 12.0), Vector3(-100.0, 0.2, 2.0), Vector3(-108.0, 0.2, -16.0), Vector3(-113.0, 0.2, -36.0),
	Vector3(-112.0, 0.2, -49.0)]
const TRUCK_POS := Vector3(-103.0, 0.15, -12.0)
const FENCE_POS := Vector3(-117.0, 0.15, -20.0)        # a picket run along the lane, one panel down
const SHELTER_POS := Vector3(-118.5, 0.15, -40.0)
const CAMP := Vector3(-113.0, 0.15, -55.0)
const FIELD_AT := Vector3(-104.0, 0.2, -70.0)          # where something moves in the field
const FIELD_HOUND := [Vector3(-126.0, 0.0, -82.0), Vector3(-138.0, 0.0, -66.0)]
const FARM_WAY := [Vector3(-104.0, 0.2, -72.0), Vector3(-96.0, 0.2, -88.0)]
const SAFE := Vector3(-104.0, 0.2, -99.0)              # the field west of the farmhouses: HOUSE_19's front in view
const SAFE_SPOTS := {"Eddie": Vector3(-105.6, 0.2, -98.0), "Ruth": Vector3(-102.4, 0.2, -97.6), "Sarah": Vector3(-103.2, 0.2, -100.6),
	"Marcus": Vector3(-105.2, 0.2, -101.0)}
const FARM := "HOUSE_20"
const FAR_FARM := "HOUSE_19"
# ---- house-local (RES_House_Abandoned: living room x -3.5..0.6, dining 0.6..3.5, z 3.4..8.6; kitchen z 8.6..11.4;
# upstairs hall x -3.5..-1.3, bedroom 1 x -1.3..3.5, z 3.4..7.6, floor 3.61; front door x -1.3, back door x 0.56)
const PORCH := Vector3(-1.8, 0.05, 0.8)
const AREAS := {"living": [Vector3(0.0, 1.6, 6.0), Vector3(7.0, 2.0, 4.6)], "kitchen": [Vector3(0.0, 1.6, 10.0), Vector3(6.6, 2.0, 2.4)],
	"bedroom": [Vector3(1.1, 4.6, 5.5), Vector3(4.4, 2.0, 3.8)]}
const REAR_SPOT := [Vector3(0.56, 1.5, 10.95), Vector3(1.3, 2.0, 0.6)]
const MESSAGE_AT := Vector3(1.6, 5.4, 5.8)              # dropped onto whatever is below in bedroom 1
## clear of the ways through the room (front door -> kitchen arch at x 1.5..2, z 8.6; front door -> the stairs at x -3)
const WAIT_SPOTS := {"Eddie": Vector3(-1.6, 0.61, 7.6), "Ruth": Vector3(2.9, 0.61, 6.6), "Sarah": Vector3(2.9, 0.61, 5.0),
	"Marcus": Vector3(-1.0, 0.61, 6.6)}
const SIDE_WINDOW := Vector3(-3.5, 1.5, 6.0)
const WINDOW_PASS := [Vector3(-6.5, 0.0, 9.5), Vector3(-6.5, 0.0, 2.5), Vector3(-2.0, 0.0, -3.0)]
const BACK_DOOR := Vector3(0.56, 1.0, 11.3)
const CHASE_SPAWN := Vector3(5.2, 0.0, 6.0)             # outside, east of the house
const FAR_LIGHT := Vector3(1.5, 1.75, 4.4)              # inside HOUSE_19, behind its front wall

var world: Node
var c10: Node
var c9: Node
var c8: Node
var p4: Node
var player: Node3D
var hud: Node
var farm: Node3D
var far_farm: Node3D
var its := {}
var areas := {}
var hound: Node3D
var hound_ai: Node
var far_light: OmniLight3D
var shadow: Node3D
var report := {"field_runs": 0, "attack_runs": 0, "ending_runs": 0, "bites": 0}
var _busy := {}
var _tick := 0.0
var _road_i := 0
var _note_t := 0.0
var _msg_t := 0.0


func begin(w: Node, chapter10: Node, restoring: bool) -> void:
	world = w
	c10 = chapter10
	c9 = c10.c9
	c8 = c10.c8
	p4 = c10.p4
	player = w.player
	hud = w.hud
	farm = w.get_node("Residential/Houses/" + FARM)
	far_farm = w.get_node("Residential/Houses/" + FAR_FARM)
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"roster": c10.group(), "searched": {}}
	_setup_npcs()
	_setup_road()
	_setup_camp()
	_setup_farmhouse()
	_setup_far_light()
	var fresh := not Game.has_flag("ch11_started")
	if fresh:
		Game.set_flag("ch11_started")
	_apply()
	Game.refresh_objective()
	if fresh:
		_title.call_deferred()
		world.save_checkpoint.call_deferred("chapter12_start")    # its own file, never the player's save slot


func _title() -> void:
	await get_tree().create_timer(1.0).timeout
	await hud.chapter_start(CHAPTER)


func st() -> Dictionary:
	return Game.world_state[STATE]


func fl(p: Vector3) -> Vector3:
	return farm.global_transform * p


func alive() -> bool:
	return c10.alive()


func group() -> Array:
	return c10.group()


func _node(k: String) -> Node3D:
	return c10._node(k)


func _floor(p: Vector3) -> float:
	return c10._floor(p)


func _prop(scene: PackedScene, n: String, at: Vector3, yaw: float) -> Node3D:
	return c10._prop(scene, n, at, yaw)


func _spot(n: String, at: Vector3, size: Vector3, cb: Callable, basis := Basis()) -> Interactable:
	return c10._spot(n, at, size, cb, basis)


# ------------------------------------------------------------------ setup
func _setup_npcs() -> void:
	var it: Interactable = p4.its.get("npc_Eddie")
	if it:
		it.used.connect(_talk)
		its["npc_Eddie"] = it


## The farm road: an abandoned pickup, a picket fence with one panel down, an empty country bus shelter (a snack
## left on its bench - optional, taken once).
func _setup_road() -> void:
	_prop(PICKUP_TRUCK, "C11_Pickup", TRUCK_POS, 0.4)
	for i in 4:
		var panel := _prop(PICKET, "C11_Picket", FENCE_POS + Vector3(0, 0, -2.5 * i), PI * 0.5)
		if i == 2:                                        # the broken one lies in the grass
			panel.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5).rotated(Vector3(0, 0, 1), deg_to_rad(84.0)),
				panel.global_position + Vector3(0.9, 0.12, 0))
	_prop(BUS_SHELTER, "C11_BusShelter", SHELTER_POS, PI * 0.5)
	var snack := SNACK.instantiate() as Node3D
	snack.name = "C11_Snack"
	world.add_child(snack)
	snack.global_position = SHELTER_POS + Vector3(-0.2, 1.2, 0.3)
	var sit := Interactable.attach(snack, {"kind": "pickup", "label": "Snack", "item_id": "energy_snack", "state_key": "ch11/snack"})
	var cs := sit.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = (cs.shape as BoxShape3D).size.max(Vector3(0.5, 0.4, 0.5))
	its["snack"] = sit
	_settle.call_deferred([snack])


func _settle(nodes: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for n in nodes:
		var node := n as Node3D
		if not is_instance_valid(node):
			continue
		var ex: Array[RID] = [player.get_rid()]
		for co in node.find_children("*", "CollisionObject3D", true, false):
			ex.append((co as CollisionObject3D).get_rid())
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(node.global_position + Vector3.UP * 0.3,
			node.global_position - Vector3.UP * 2.5, 1, ex))
		if hit:
			node.global_position.y = (hit["position"] as Vector3).y + 0.002
			var it := node.get_node_or_null("Interact") as Interactable
			if it:
				it._base = node.transform


## A camp someone left a day ago: a bedroll, a cold lantern, an empty can, a small jacket, scuffed earth, and a
## note weighted under a stone (picked up, read in the inventory).
func _setup_camp() -> void:
	var camp := Node3D.new()
	camp.name = "C11_Camp"
	world.add_child(camp)
	camp.global_position = Vector3(CAMP.x, _floor(CAMP), CAMP.z)
	var bed := BLANKET.instantiate() as Node3D
	camp.add_child(bed)
	bed.scale = Vector3(1.5, 1.0, 2.4)
	bed.rotation.y = 0.3
	var pil := PILLOW.instantiate() as Node3D
	camp.add_child(pil)
	pil.position = Vector3(-0.45, 0.0, -0.7)
	var lan := LANTERN.instantiate() as Node3D
	camp.add_child(lan)
	lan.position = Vector3(0.9, 0.0, 0.4)
	_prop(BAGS, "C11_CampBags", CAMP + Vector3(1.4, 0, -0.8), 1.2)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.11, 0.09, 0.07)
	dark.roughness = 1.0
	for spec in [[Vector3(0.6, 0.012, 1.6), 0.4], [Vector3(1.4, 0.012, 2.1), 0.7], [Vector3(2.2, 0.012, 2.6), 0.5]]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.012, 0.3)
		m.mesh = bm
		m.material_override = dark
		camp.add_child(m)
		m.position = spec[0]
		m.rotation.y = spec[1]
	var jacket := BLANKET.instantiate() as Node3D
	camp.add_child(jacket)
	jacket.position = Vector3(-1.2, 0.0, 0.9)
	jacket.scale = Vector3(0.55, 0.8, 0.6)
	jacket.rotation.y = 1.1
	var navy := StandardMaterial3D.new()
	navy.albedo_color = Color(0.12, 0.16, 0.3)
	for g in jacket.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_override = navy
	var can := CAN.instantiate() as Node3D
	camp.add_child(can)
	can.position = Vector3(0.6, 0.0, -0.6)
	can.rotation = Vector3(PI * 0.5, 0.4, 0)
	var t := camp.global_transform
	its["camp_jacket"] = _spot("C11_Jacket", t * Vector3(-1.2, 0.3, 0.9), Vector3(0.9, 0.6, 0.9), _inspect.bind("jacket"))
	its["camp_can"] = _spot("C11_Can", t * Vector3(0.6, 0.25, -0.6), Vector3(0.6, 0.5, 0.6), _inspect.bind("can"))
	its["camp_tracks"] = _spot("C11_Tracks", t * Vector3(1.4, 0.2, 2.1), Vector3(1.6, 0.4, 1.8), _inspect.bind("tracks"))
	var note := NOTE.instantiate() as Node3D
	note.name = "C11_CampNote"
	camp.add_child(note)
	note.position = Vector3(0.35, 0.02, 0.15)
	var nit := Interactable.attach(note, {"kind": "pickup", "label": "Note", "item_id": "campsite_note", "state_key": "ch11/campsite_note"})
	var cs := nit.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = (cs.shape as BoxShape3D).size.max(Vector3(0.6, 0.4, 0.6))
	nit.used.connect(func(_b): _got_note())
	its["camp_note"] = nit


const INSPECT_TEXT := {"jacket": "A small jacket. A kid's size, soaked with dew.", "can": "An empty can. Scraped clean with a spoon.",
	"tracks": "Footprints in the soft earth. Two sets: one small, one large. Heading south.",
	"rear": "The back door is bolted from inside. Fresh scratches in the paint around the frame."}


func _inspect(_b: Node, what: String) -> void:
	var seen: Dictionary = st().get("inspected", {})
	seen[what] = true
	st()["inspected"] = seen
	_hint(INSPECT_TEXT.get(what, ""))
	if what == "rear":
		_searched("rear")
	_refresh_prompts()


func _setup_farmhouse() -> void:
	for pair in [["INT_Door_Front", hl_dir(Vector3(-1.3, 1.4, 5.0))], ["INT_Door_Kitchen", hl_dir(Vector3(-1.4, 1.4, 10.0))],
			["INT_Door_Bed1", hl_dir(Vector3(0.0, 4.4, 5.0))]]:
		var d := farm.find_child(pair[0], true, false) as Node3D
		if d == null:
			continue
		var deg: float = world._toward_deg(d, 95.0, pair[1])
		var it := Interactable.attach(d, {"kind": "hinge", "label": String(pair[0]).trim_prefix("INT_Door_").replace("Bed1", "Bedroom") + " Door",
			"open_deg": deg, "hinge_axis": Vector3.UP, "state_key": "ch11/%s/%s" % [FARM, pair[0]]})
		its[pair[0]] = it
	for k in AREAS:
		areas[k] = AREAS[k]
	its["rear"] = _spot("C11_BackDoor", fl(REAR_SPOT[0]), REAR_SPOT[1], _inspect.bind("rear"), farm.global_transform.basis)
	var msg := NOTEBOOK.instantiate() as Node3D
	msg.name = "C11_NoahsMessage"
	world.add_child(msg)
	msg.global_position = fl(MESSAGE_AT)
	msg.rotation.y = 0.5
	var mit := Interactable.attach(msg, {"kind": "pickup", "label": "Message", "item_id": "noahs_message", "state_key": "ch11/noahs_message"})
	var cs := mit.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = (cs.shape as BoxShape3D).size.max(Vector3(0.6, 0.4, 0.6))
	mit.used.connect(func(_b): _got_message())
	its["message"] = mit
	_settle.call_deferred([msg])


func hl_dir(p: Vector3) -> Vector3:
	return fl(p)


## Inside a house-local box (the farmhouse areas).
func in_area(n: Node3D, k: String) -> bool:
	var l := farm.to_local(n.global_position)
	var a: Array = AREAS[k]
	var half: Vector3 = (a[1] as Vector3) * 0.5
	return absf(l.x - a[0].x) <= half.x and absf(l.z - a[0].z) <= half.z and l.y > a[0].y - 1.9 and l.y < a[0].y + 0.6


func _setup_far_light() -> void:
	far_light = OmniLight3D.new()
	far_light.name = "C11_FarLight"
	far_light.light_color = Color(1.0, 0.72, 0.4)
	far_light.light_energy = 0.0
	far_light.omni_range = 7.0
	far_light.shadow_enabled = false
	far_farm.add_child(far_light)
	far_light.position = FAR_LIGHT
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 1.55
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.0, 0.0, 0.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow = MeshInstance3D.new()
	(shadow as MeshInstance3D).mesh = cap
	(shadow as MeshInstance3D).material_override = m
	shadow.name = "C11_Shape"
	far_farm.add_child(shadow)
	shadow.position = FAR_LIGHT + Vector3(-2.2, -0.9, 0.5)
	shadow.visible = false


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	_node("Marcus").visible = alive()
	if Game.has_flag("chapter_11_complete") or (Game.has_flag("ch11_escaped") and Game.has_flag("ch11_light_seen")):
		_place_at_safe()
	elif Game.has_flag("ch11_group_waiting") and not Game.has_flag("ch11_attack_started"):
		_place_waiting()
	elif Game.has_flag("ch11_talk_done"):
		for k in group():
			c9._start_follow(k)
	else:
		c10._place_inside()
	if Game.has_flag("ch11_attack_started") and not Game.has_flag("ch11_escaped"):
		_spawn_chaser(false)                          # a load mid-escape: it prowls by the house, the way out is open
	far_light.light_energy = 1.6 if Game.has_flag("ch11_escaped") else 0.0
	_refresh_prompts()
	_guide()


func _place_waiting() -> void:
	for k in group():
		var n := _node(k)
		(c9.follows[k] as VeilCompanionFollow).stop()
		c9.c5._reparent(n, world)
		n.visible = true
		var a = world.animators.get(k)
		if a:
			a.set_seated(false)
			a.turn_to_face = true
			a.set_mood("scared")
		world.place_survivor(n, fl(WAIT_SPOTS[k]))
		if a:
			a.face_towards(fl(Vector3(0.0, 1.5, 6.0)))


func _place_at_safe() -> void:
	for k in group():
		var n := _node(k)
		(c9.follows[k] as VeilCompanionFollow).stop()
		c9.c5._reparent(n, world)
		n.visible = true
		var a = world.animators.get(k)
		if a:
			a.set_seated(false)
			a.turn_to_face = true
		world.place_survivor(n, SAFE_SPOTS[k])
		if a:
			a.face_towards(far_farm.global_position)


func _refresh_prompts() -> void:
	if its.has("npc_Eddie"):
		var on := not Game.has_flag("ch11_talk_done")
		its["npc_Eddie"].prompt_text = "[E] Talk" if on else ""
		its["npc_Eddie"].collision_layer = 8 if on else 0
	var seen: Dictionary = st().get("inspected", {})
	var camp_on := Game.has_flag("ch11_talk_done")
	for k in ["jacket", "can", "tracks"]:
		var it: Interactable = its["camp_" + k]
		var on: bool = camp_on and not seen.get(k, false)
		it.prompt_text = ("[E] Examine the " + {"jacket": "Jacket", "can": "Empty Can", "tracks": "Tracks"}[k]) if on else ""
		it.collision_layer = 8 if on else 0
	var rear_on: bool = Game.has_flag("ch11_farmhouse_reached") and not seen.get("rear", false)
	its["rear"].prompt_text = "[E] Check the Back Door" if rear_on else ""
	its["rear"].collision_layer = 8 if rear_on else 0


func searched() -> Dictionary:
	return st().get("searched", {})


func _searched(k: String) -> void:
	var s: Dictionary = searched()
	if s.get(k, false):
		return
	s[k] = true
	st()["searched"] = s
	if s.get("living", false) and s.get("kitchen", false) and s.get("bedroom", false) and s.get("rear", false):
		Game.set_flag("ch11_search_done")
	_obj_txt = ""
	_guide()


var _obj_txt := ""


func _guide() -> void:
	var t: Variant = null
	var label := ""
	var p := player.global_position
	if not Game.has_flag("ch11_talk_done"):
		t = _node("Eddie")
		label = "EDDIE"
	elif not Game.has_flag("ch11_campsite_reached"):
		while _road_i < ROAD.size() - 1 and Vector2(p.x - ROAD[_road_i].x, p.z - ROAD[_road_i].z).length() < 4.0:
			_road_i += 1
		t = ROAD[_road_i] + Vector3(0, 1.2, 0)
		label = "FARM ROAD"
	elif not Game.has_flag("ch11_note_read"):
		t = its["camp_note"].global_position + Vector3(0, 0.3, 0) if not Game.has_item("campsite_note") else null
		label = "CAMP"
		if Game.has_item("campsite_note") and hud.has_method("set_hint") and hud.hint.text == "":
			hud.set_hint("TAB  -  INVENTORY: read the note")
	elif not Game.has_flag("ch11_farmhouse_reached"):
		var porch := fl(PORCH)
		t = (FARM_WAY[1] if p.x < FARM_WAY[1].x - 2.0 else porch) + Vector3(0, 1.4, 0)
		label = "FARMHOUSE"
	elif not Game.has_flag("ch11_search_done") or not Game.has_flag("ch11_message_read"):
		var s := searched()
		if not s.get("living", false):
			t = fl(AREAS["living"][0])
			label = "LIVING ROOM"
		elif not s.get("kitchen", false):
			t = fl(AREAS["kitchen"][0])
			label = "KITCHEN"
		elif not s.get("rear", false):
			t = its["rear"].global_position
			label = "BACK DOOR"
		elif not Game.has_flag("ch11_message_found"):
			t = its["message"].global_position + Vector3(0, 0.3, 0)
			label = "BEDROOM"
		if hud.has_method("set_objective") and not Game.has_flag("ch11_search_done"):
			var parts := []
			for k in [["living", "living room"], ["kitchen", "kitchen"], ["bedroom", "bedroom"], ["rear", "back door"]]:
				parts.append(("[x] " if s.get(k[0], false) else "[ ] ") + k[1])
			var txt := "Search the farmhouse  " + "  ".join(parts)
			if txt != _obj_txt:
				_obj_txt = txt
				hud.set_objective(Game.current_goal(), txt)
	elif not Game.has_flag("ch11_regrouped"):
		t = fl(AREAS["living"][0])
		label = "THE OTHERS"
	elif Game.has_flag("ch11_attack_started") and not Game.has_flag("ch11_escaped") and not _busy.get("attack", false):
		t = SAFE + Vector3(0, 1.4, 0)
		label = "GET OUT"
	if hud.has_method("set_marker"):
		hud.set_marker(t, label)


# ------------------------------------------------------------------ scene 1: leaving the refuge
func _talk(_b: Node) -> void:
	if Game.has_flag("ch11_talk_done") or _busy.get("talk", false) or not Game.has_flag("ch11_started"):
		return
	_busy["talk"] = true
	its["npc_Eddie"].prompt_text = ""
	var npcs: Array = [_node("Eddie"), _node("Ruth"), _node("Sarah")]
	if alive():
		npcs.append(_node("Marcus"))
	await c9._talk_group("c11_wake_alive" if alive() else "c11_wake_lost", npcs)
	Game.set_flag("ch11_talk_done")
	for k in group():
		c9._start_follow(k)
	_busy["talk"] = false
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ scenes 2-3: the road, the camp, the note
func _got_note() -> void:
	Game.set_flag("ch11_note_found")
	Game.set_flag("noah_clue_campsite")
	_refresh_prompts()


func _note_tick(delta: float) -> void:
	_read_tick(delta, "campsite_note", "ch11_note_found", "ch11_note_read")
	_read_tick(delta, "noahs_message", "ch11_message_found", "ch11_message_read")


## A note counts as read once it has been on screen in the inventory's inspect view for a moment (Chapter 8 rule).
func _read_tick(delta: float, item: String, found: String, read: String) -> void:
	if not Game.has_flag(found) or Game.has_flag(read):
		return
	var inv = hud.get("inv_panel")
	var showing := false
	if inv and inv.visible:
		var ids: Array = inv.get("_ids")
		var sel: int = inv.get("_sel")
		showing = sel >= 0 and sel < ids.size() and ids[sel] == item
	var key := "_t_" + item
	var t: float = float(_busy.get(key, 0.0))
	t = t + delta if showing else 0.0
	_busy[key] = t
	if t > 1.2:
		Game.set_flag(read)
		if hud.has_method("set_hint"):
			hud.set_hint("")
		if item == "campsite_note":
			_after_note.call_deferred()
		else:
			_guide()


func _after_note() -> void:
	while (hud.get("inv_panel") and hud.inv_panel.visible) or Dialogue.is_busy():
		await get_tree().process_frame
	var npcs: Array = [_node("Marcus"), _node("Eddie")] if alive() else [_node("Ruth")]
	await c9._talk_group("c11_campsite_alive" if alive() else "c11_campsite_lost", npcs)
	_guide()


# ------------------------------------------------------------------ scene 4: something in the field
## First person, the view controlled: it turns toward the sound and zooms gently onto a shape in the fog, which
## is gone before anyone can say what it was; then the FOV and control come back.
func _field() -> void:
	if Game.has_flag("ch11_field_seen") or _busy.get("field", false):
		return
	_busy["field"] = true
	report["field_runs"] += 1
	Game.set_flag("ch11_field_seen")
	world.end_conversation()
	var ps := load(HOUND_PATH) as PackedScene
	var h := ps.instantiate() as Node3D
	h.name = "C11_FieldShape"
	world.add_child(h)
	if h is CollisionObject3D:
		(h as CollisionObject3D).collision_layer = 0
		(h as CollisionObject3D).collision_mask = 0
	h.set_physics_process(false)
	var a: Vector3 = FIELD_HOUND[0]
	h.global_position = Vector3(a.x, _floor(a), a.z)
	VeilCreatureLook.apply_skitter(h, h.global_position.y)
	c8._bark(h.global_position + Vector3(0, 1.0, 0))
	_hold(true)
	await c8._turn_to(h.global_position + Vector3(0, 0.7, 0), 1.3)
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.8, 1.0).set_trans(Tween.TRANS_SINE)
	report["field_min_fov"] = fov0
	c8._hplay(h, "Walk", 0.0)
	var b: Vector3 = FIELD_HOUND[1]
	b.y = _floor(b)
	h.rotation.y = atan2(b.x - h.global_position.x, b.z - h.global_position.z)
	var tw := h.create_tween()
	tw.tween_property(h, "global_position", b, 4.2)
	# the view follows it a little, then it is gone into the fog
	var t := 0.0
	while t < 2.6 and is_instance_valid(h):
		t += get_process_delta_time()
		var v := (h.global_position + Vector3(0, 0.7, 0) - cam.global_position).normalized()
		player.set_yaw_pitch(lerp_angle(player.rotation.y, atan2(-v.x, -v.z), 0.06), player.head.rotation.x)
		report["field_min_fov"] = minf(float(report["field_min_fov"]), cam.fov)
		await get_tree().process_frame
	if is_instance_valid(h):
		h.queue_free()
	var tb := create_tween()
	tb.tween_property(cam, "fov", fov0, 0.8).set_trans(Tween.TRANS_SINE)
	await tb.finished
	cam.fov = fov0
	_hold(false)
	Dialogue.say("c11_field_alive" if alive() else "c11_field_lost", false, true)
	_busy["field"] = false
	report["field_fov_restored"] = absf(cam.fov - fov0) < 0.01


# ------------------------------------------------------------------ scenes 5-6: the farmhouse, Noah's message
func _farm_tick() -> void:
	var p := player.global_position
	if Game.has_flag("ch11_field_seen") and Game.has_flag("ch11_note_read") and not Game.has_flag("ch11_farmhouse_reached") \
			and p.distance_to(fl(PORCH)) < 7.0:
		Game.set_flag("ch11_farmhouse_reached")
		Dialogue.say("c11_farmhouse", false, true)
		_refresh_prompts()
	if not Game.has_flag("ch11_farmhouse_reached") or Game.has_flag("ch11_attack_started"):
		return
	if not Game.has_flag("ch11_group_waiting") and in_area(player, "living"):
		Game.set_flag("ch11_group_waiting")         # the group stays in the living room while the player searches
		_wait_inside()
	for k in ["living", "kitchen", "bedroom"]:
		if not searched().get(k, false) and in_area(player, k):
			_searched(k)
	if Game.has_flag("ch11_search_done") and Game.has_flag("ch11_message_read") and not Game.has_flag("ch11_regrouped") \
			and in_area(player, "living") and not _busy.get("regroup", false) and not Dialogue.is_busy():
		_regroup()


func _wait_inside() -> void:
	var t := 0.0
	while t < 10.0:
		if group().all(func(k): return in_area(_node(k), "living")):
			break
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	_place_waiting()


func _got_message() -> void:
	Game.set_flag("ch11_message_found")
	Game.set_flag("noah_clue_farmhouse")
	_searched("bedroom")
	Dialogue.say("c11_bedroom_found", false, true)
	if hud.has_method("set_hint"):
		hud.set_hint("TAB  -  INVENTORY: read the message")


func _regroup() -> void:
	_busy["regroup"] = true
	_place_waiting()
	var npcs: Array = [_node("Marcus"), _node("Eddie")] if alive() else [_node("Ruth")]
	await c9._talk_group("c11_message_alive" if alive() else "c11_message_lost", npcs)
	Game.set_flag("ch11_regrouped")
	_busy["regroup"] = false
	_attack()


# ------------------------------------------------------------------ scene 7: the farmhouse encounter
func _attack() -> void:
	if Game.has_flag("ch11_attack_started") or _busy.get("attack", false):
		return
	_busy["attack"] = true
	report["attack_runs"] += 1
	Game.set_flag("ch11_attack_started")
	world.end_conversation()
	_hold(true)
	# a sound outside; the view goes to the side window; a shape goes past it in the fog
	var ps := load(HOUND_PATH) as PackedScene
	var h := ps.instantiate() as Node3D
	h.name = "C11_WindowShape"
	world.add_child(h)
	if h is CollisionObject3D:
		(h as CollisionObject3D).collision_layer = 0
		(h as CollisionObject3D).collision_mask = 0
	h.set_physics_process(false)
	var a := fl(WINDOW_PASS[0])
	h.global_position = Vector3(a.x, _floor(a), a.z)
	VeilCreatureLook.apply_skitter(h, h.global_position.y)
	p4._play("scrape", fl(Vector3(-4.5, 1.0, 9.0)), 0.0)
	await c8._turn_to(fl(SIDE_WINDOW), 0.8)
	c8._hplay(h, "Walk", 0.0)
	for i in range(1, WINDOW_PASS.size()):
		var to := fl(WINDOW_PASS[i])
		to.y = _floor(to)
		h.rotation.y = atan2(to.x - h.global_position.x, to.z - h.global_position.z)
		var tw := h.create_tween()
		tw.tween_property(h, "global_position", to, h.global_position.distance_to(to) / 3.0)
		await tw.finished
	h.queue_free()
	await get_tree().create_timer(0.8).timeout
	# a blow on the back door: it jumps in its frame
	await c8._turn_to(fl(BACK_DOOR + Vector3(0, 0.5, 0)), 0.5)
	p4._play("impact", fl(BACK_DOOR), 6.0)
	c8._bark(fl(BACK_DOOR + Vector3(0, 0, 1.2)))
	var bd := farm.find_child("INT_Door_Back", true, false) as Node3D
	if bd:
		var t0 := bd.transform
		var tj := create_tween()
		tj.tween_property(bd, "transform", Transform3D(t0.basis * Basis(Vector3.UP, deg_to_rad(-2.2)), t0.origin), 0.05)
		tj.tween_property(bd, "transform", t0, 0.15)
	var cam := get_viewport().get_camera_3d()
	if cam and world.has_method("_shake"):
		world._shake(cam, 0.25, 0.01)
	for k in group():
		var an = world.animators.get(k)
		if an:
			an.set_mood("scared")
			an.face_towards(fl(BACK_DOOR))
	Dialogue.say("c11_attack", false, true)
	var front: Interactable = its.get("INT_Door_Front")
	if front and not front.is_open:
		front.set_open(true)
	while Dialogue.is_busy():
		await get_tree().process_frame
	# the escape: the group follows the player out of the front door; it comes round the house
	for k in group():
		c9._start_follow(k)
	_spawn_chaser(true)
	_hold(false)
	_busy["attack"] = false
	_guide()


## The Hound outside: the Chapter 7 Hound AI (moves with collisions, never a killing bite, gives up past its leash).
func _spawn_chaser(chasing: bool) -> void:
	if hound and is_instance_valid(hound):
		return
	var ps := load(HOUND_PATH) as PackedScene
	hound = ps.instantiate() as Node3D
	hound.name = "C11_Hound"
	world.add_child(hound)
	var at := fl(CHASE_SPAWN)
	hound.global_position = Vector3(at.x, _floor(at), at.z)
	VeilCreatureLook.apply_skitter(hound, hound.global_position.y)
	hound_ai = HOUND_AI.new()
	hound_ai.name = "AI"
	hound.add_child(hound_ai)
	hound_ai.leash = 26.0
	hound_ai.setup(hound, player, [hound.global_position, fl(Vector3(5.2, 0.0, 12.0))])
	hound_ai.bit.connect(func(_d): report["bites"] = int(report["bites"]) + 1)
	if chasing:
		hound_ai.set("_last_seen", player.global_position)
		hound_ai._start_chase()


## While the group runs, it hears them: it keeps after the player (round the house, with its own collisions) until
## its leash is used up; past that it gives up on its own (Hound AI).
func _pursue() -> void:
	if hound_ai == null or not is_instance_valid(hound_ai) or not is_instance_valid(hound):
		return
	var home: Vector3 = hound_ai.get("home")
	var far_home := Vector2(hound.global_position.x - home.x, hound.global_position.z - home.z).length() > float(hound_ai.get("leash"))
	if hound_ai.state in ["CHASE", "SEARCH", "SUSPICIOUS"] and not far_home:
		hound_ai.set("_last_seen", player.global_position)
		hound_ai.set("_unseen", 0.0)
		if hound_ai.state != "CHASE":
			hound_ai._start_chase()
			hound_ai.state = "CHASE"
	if hound_ai.state == "CHASE":
		report["chased"] = true
		report["closest"] = minf(float(report.get("closest", 99.0)), hound.global_position.distance_to(player.global_position))


func _escape_tick() -> void:
	if not Game.has_flag("ch11_attack_started") or Game.has_flag("ch11_escaped") or _busy.get("attack", false):
		return
	_pursue()
	if player.global_position.distance_to(SAFE) < 6.0:
		Game.set_flag("ch11_escaped")
		st()["roster"] = group()
		if hound_ai and is_instance_valid(hound_ai):
			hound_ai.state = "RETURN"
		var h := hound
		if h and is_instance_valid(h):
			get_tree().create_timer(6.0).timeout.connect(func():
				if is_instance_valid(h):
					h.queue_free())
		hound = null
		far_light.light_energy = 1.6
		world.save_checkpoint("chapter12_after_encounter")    # its own file, never the player's save slot
		_ending()


# ------------------------------------------------------------------ scene 8: the distant light
func _ending() -> void:
	if Game.has_flag("chapter_11_complete") or _busy.get("ending", false):
		return
	_busy["ending"] = true
	report["ending_runs"] += 1
	# the group catches up, then the talk at the roadside (the shared talk camera)
	var t := 0.0
	while t < 8.0 and not group().all(func(k): return _node(k).global_position.distance_to(SAFE) < 8.0):
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	_place_at_safe()
	var npcs: Array = [_node("Eddie"), _node("Ruth"), _node("Marcus") if alive() else _node("Sarah")]
	await c9._talk_group("c11_light_alive" if alive() else "c11_light_lost", npcs)
	Game.set_flag("ch11_light_seen")
	# the view is drawn to the light: it flickers; a shape passes behind it; nothing is explained
	_hold(true)
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	await c8._turn_to(far_light.global_position, 1.2)
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.78, 1.2).set_trans(Tween.TRANS_SINE)
	await tz.finished
	for k in 4:
		far_light.light_energy = 0.3 if k % 2 == 0 else 1.6
		await get_tree().create_timer(0.18).timeout
	shadow.visible = true
	var ts := create_tween()
	ts.tween_property(shadow, "position:x", shadow.position.x + 4.4, 2.2)
	await ts.finished
	shadow.visible = false
	far_light.light_energy = 1.6
	await get_tree().create_timer(0.8).timeout
	var tb := create_tween()
	tb.tween_property(cam, "fov", fov0, 1.0).set_trans(Tween.TRANS_SINE)
	await tb.finished
	cam.fov = fov0
	report["ending_fov_restored"] = absf(cam.fov - fov0) < 0.01
	_hold(false)
	Game.set_flag("chapter_11_complete")             # the next chapter is NOT started here
	st()["completed"] = {"roster": group(), "clues": ["noah_clue_campsite", "noah_clue_farmhouse"]}
	_busy["ending"] = false
	_guide()
	await hud.chapter_complete(CHAPTER)


# ------------------------------------------------------------------ helpers, per tick
func _hint(t: String) -> void:
	c10._hint(t)


func _hold(on: bool) -> void:
	player.set("controls_enabled", not on)
	player.velocity = Vector3.ZERO


func _process(delta: float) -> void:
	_note_tick(delta)
	_tick -= delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	var p := player.global_position
	if Game.has_flag("ch11_talk_done") and not Game.has_flag("ch11_campsite_reached") and p.distance_to(CAMP) < 9.0:
		Game.set_flag("ch11_campsite_reached")
		Dialogue.say("c11_campsite_seen", false, true)
		_refresh_prompts()
	if Game.has_flag("ch11_note_read") and not Game.has_flag("ch11_field_seen") and not Dialogue.is_busy() and not world.conversing \
			and Vector2(p.x - FIELD_AT.x, p.z - FIELD_AT.z).length() < 8.0:
		_field()
	_farm_tick()
	_escape_tick()
	if not _busy.get("field", false) and not _busy.get("attack", false) and not _busy.get("ending", false):
		_guide()
