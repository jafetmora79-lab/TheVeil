extends Node
class_name VeilPhase4
## THE VEIL - Phase 4, Act I: the first night in the supermarket (WORKING DRAFT, not canon).
## Starts when Phase 3 sets `p3_doors_shut` (world.gd adds this node). Objective chain "Secure the supermarket":
##   flashlight (customer service desk) -> breaker (back room, emergency lights) -> loading bay door (pull down,
##   push pallets) -> rear exit (close, push pallets) -> Eddie / Marcus argue about Noah (dialogue choice, flag
##   only) -> something outside (scrape, shadow behind the glass, flicker, a hit on the back door, silence)
##   -> sleep in the office -> "SATURDAY" -> end of Phase 4.
## Every step is a flag; `_apply()` rebuilds the world from the flags, so loading a save restores the state
## and completed events are never replayed. Reuses: Interactable, Dialogue (+ choices), objectives, NPC animators,
## Pack 04 doors / pallets, Pack 08 flashlight + batteries, Pack 09 presets + flicker, Pack 07 Hound, Pack 03 blanket.

const CFG_PATH := "res://game/data/phase4.json"
const FLASHLIGHT := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Story_Items/INV_Flashlight.glb")
const BATTERY_PACK := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Food_And_Supplies/INV_SpareBatteries.glb")
const BATTERY := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Story_Items/INV_FlashlightBattery.glb")
const PALLET := preload("res://THE_VEIL_ASSETS_V2/04_Commercial/Shared_Props/COM_PalletStack.glb")
const BLANKET := preload("res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_Blanket_Folded.glb")
const PILLOW := preload("res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_Pillow.glb")
const FLICKER := preload("res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Lighting/veil_flicker.gd")
const PRESET_PATH := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Atmosphere_Presets/LGT_Empty_Supermarket.tres"
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const FLASHLIGHT_SCRIPT := preload("res://game/player/flashlight.gd")
const CHOICE_SCRIPT := preload("res://game/ui/choice_panel.gd")
const REST_SCRIPT := preload("res://game/world/rest_point.gd")

# supermarket-local layout (verified against COM_Supermarket.glb / the furnishing mesh)
# on the customer-service counter top (COM_ServiceCounter at (6.0, 5.0): collider x 4.5-7.5, z 4.6-5.4, top
# y 1.05). They used to sit at z 5.8, i.e. 0.4 m behind the counter in mid-air. _settle_items() drops them
# onto the collider below.
const SERVICE_FLASHLIGHT := Vector3(5.7, 1.1, 5.1)
const SERVICE_BATTERIES := Vector3(6.35, 1.1, 5.05)
const BREAKER := Vector3(16.9, 1.24, 17.37)               # RES_ElectricalPanel face on the back wall (z 17.37, y 0.94-1.54)
## the breaker's interaction box sits in FRONT of the panel (the panel's own collider would otherwise catch the
## player's ray first) and is generous (0.8 x 0.9 m face), but stays on the room side of the wall
const BREAKER_BOX := [Vector3(16.9, 1.24, 17.2), Vector3(0.8, 0.9, 0.3)]
const LOADING_HANDLE := Vector3(19.55, 0.9, 16.35)          # clear of the breaker panel (z 14.7-15.1)
const BACKDOOR_HANDLE := Vector3(8.0, 1.05, 17.0)          # covers the ajar leaf as well
# start, blocking, yaw. Blocking spots are flush with the leaves (3 cm off; COM_PalletStack is 1.2 x 1.0 m):
# roll-up door inner face x 20.05 (z 14.5-17.3, centre 15.9); rear exit leaf inner face z 17.447 (x 7.5-8.5)
const LOADING_PALLET := [Vector3(17.9, 0.04, 16.8), Vector3(19.52, 0.04, 15.9), PI * 0.5]
const BACK_PALLET := [Vector3(10.4, 0.04, 15.9), Vector3(8.0, 0.04, 16.917), 0.0]
const BACKDOOR_OUTSIDE_Z := 17.613                                 # rear exit leaf outer face
const BEDROLL := Vector3(-17.95, 0.04, 15.35)             # office floor, the clear patch between the drawers and the desk
## The night's bed is made, not found: flattened cardboard and a blanket + pillow taken from the piles by the office,
## laid out on the office floor ("[E] Make a Bed"), then "[E] Sleep". Eddie and Marcus fetch theirs from the same
## piles and lay them in clear spots outside the office. Saved: p4_bed_card, p4_bed_soft, p4_bed_made.
const BED_PILE_CARD := Vector3(-15.6, 0.04, 12.6)
const BED_PILE_SOFT := Vector3(-17.0, 0.04, 12.6)
const BED_LEN := 1.6
const BED_W := 0.8
const CARDBOARD_MAT := "res://THE_VEIL_ASSETS_V2/Materials_Godot/Furniture/M_Furn_Cardboard.tres"
const CARD_STACK := "res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_CardboardBox_Stack.glb"
const COMPANION_BEDS := {"Eddie": [Vector3(-14.5, 0.04, 16.0), Vector3(-15.5, 0.04, 16.0), Vector3(-14.0, 0.04, 12.9)],
	"Marcus": [Vector3(-16.0, 0.04, 15.6), Vector3(-13.5, 0.04, 13.2), Vector3(-15.2, 0.04, 13.7)]}
const EDDIE_POS := Vector3(6.2, 0.04, 4.05)
const MARCUS_POS := Vector3(-2.0, 0.04, 6.9)
const LOADING_GAP := 0.9                                   # metres the roll-up door is left open

var world: Node
var market: Node3D
var player: Node3D
var hud: Node
var cfg := {}
var choice: VeilChoicePanel
var flashlight: VeilFlashlight
var its := {}
var rest: VeilRestPoint
var hound: Node3D
var threat_runs := 0
var _lights: Array = []
var _base := {}
var _pallets := {}
var _streams := {}
var _threat_running := false


func begin(w: Node, restoring: bool) -> void:
	world = w
	market = w.market
	player = w.player
	hud = w.hud
	var f := FileAccess.open(CFG_PATH, FileAccess.READ)
	cfg = JSON.parse_string(f.get_as_text()) if f else {}
	choice = CHOICE_SCRIPT.new()
	choice.name = "Phase4Choice"
	add_child(choice)
	# the front doors were pulled shut by hand (p3_doors_shut): their sensor stays unpowered. The Phase 3 restore
	# only cuts the power for the not-yet-shut case, so after a load the sensor would open them again.
	world._doors_powered = false
	_make_sounds()
	_take_over_npcs(restoring)
	_setup_lights()
	_setup_doors()
	garage = VeilGarageTentacle.new()                # the loading-bay tentacle (game/world/garage_tentacle.gd)
	garage.name = "GarageTentacle"
	add_child(garage)
	garage.setup(self)
	_setup_pickups()
	_setup_back_room()
	_setup_rest()
	_spot("ShelterSupplies", Vector3(7.8, 0.85, 6.05), Vector3(0.65, 0.7, 0.55),
		"[E] Shelter Supplies", func(_body): _open_supplies())
	Dialogue.choices_offered.connect(_on_choices)
	if Game.has_item("flashlight"):
		_attach_flashlight()
		if not Game.has_flag("p4_flashlight"):
			Game.set_flag("p4_flashlight")           # already carried: that step is done, no second flashlight
	if not Game.has_flag("p4_started"):
		Game.set_flag("p4_started")
		hud.chapter_start(5)
		_apply()
		Dialogue.say("p4_start", false, true)
	else:
		_apply()
		if Game.has_flag("p4_talk_done") and not Game.has_flag("p4_threat_done"):
			_run_threat.call_deferred()            # an interrupted event plays again; completed ones never do
	if Game.has_flag("p4_slept"):
		_start_chapter5(true)
	hud.set_objective(Game.current_goal(), Game.current_step().get("text", ""))


func ml(p: Vector3) -> Vector3:
	return market.global_transform * p


# ------------------------------------------------------------------ setup
func _take_over_npcs(restoring: bool) -> void:
	# Phase 3 talk prompts (shop lines) are switched off; Phase 4 has its own
	for k in ["shop/eddie", "p3/marcus"]:
		if world.interactables.has(k):
			# the old prompt sits on the same NPC with the same box and would win the player's ray
			var it: Interactable = world.interactables[k]
			world.interactables.erase(k)
			it.collision_layer = 0
			it.queue_free()
	for pair in [[world.eddie, "Eddie", EDDIE_POS], [world.marcus, "Marcus", MARCUS_POS]]:
		var n: Node3D = pair[0]
		if n == null:
			continue
		if n.get_parent() != market:
			n.reparent(market, true)
		if restoring:
			world.place_survivor(n, pair[2])
		else:
			world.npc_walk(pair[1], pair[2])
		var it := Interactable.attach(n, {"kind": "custom", "label": pair[1], "prompt_text": "[E] Talk"})
		it.used.connect(_talk)
		its["npc_" + pair[1]] = it
		if world.animators.has(pair[1]):
			world.animators[pair[1]].set_mood("scared")


func _setup_lights() -> void:
	for l in market.get_node("Lights").get_children():
		if l is Light3D:
			_lights.append(l)
			_base[l.name] = (l as Light3D).light_energy


func _setup_doors() -> void:
	var b := market.get_node("Building")
	for d in [["INT_Door_Staff", "Staff Door", Vector3(15.5, 1.0, 15.6)], ["INT_Door_Office", "Office Door", Vector3(-18.5, 1.0, 15.9)],
			["INT_Door_Restroom", "Restroom Door", Vector3(-15.7, 1.0, 15.9)]]:
		var door := b.find_child(d[0], true, false) as Node3D
		if door == null:
			push_warning("Phase 4: door missing " + d[0])
			continue
		var it := Interactable.attach(door, {"kind": "hinge", "label": d[1], "state_key": "p4/" + d[0], "open_deg": 95.0})
		it.open_deg = world._toward_deg(door, 95.0, ml(d[2]))
		its[d[0]] = it
	var staff: Interactable = its.get("INT_Door_Staff")
	if staff:
		staff.used.connect(func(_b): Dialogue.say("p4_staff_door", true))
	var ld := b.find_child("INT_GarageDoor_Loading", true, false) as Node3D
	var bd := b.find_child("INT_Door_BackExit", true, false) as Node3D
	_base["loading"] = ld.transform
	_base["back"] = bd.transform
	its["loading_door"] = ld
	its["back_door"] = bd
	_base["back_ajar_deg"] = world._toward_deg(bd, 38.0, ml(Vector3(8.0, 1.0, 16.6)))
	its["loading"] = _spot("P4_LoadingHandle", LOADING_HANDLE, Vector3(0.5, 1.6, 1.7), "[E] Pull the Loading Door Down", _pull_loading)
	its["backdoor"] = _spot("P4_BackDoor", BACKDOOR_HANDLE, Vector3(1.4, 2.0, 1.1), "[E] Close the Back Door", _close_back)
	# a gap under the loading door: the mist creeps in
	var gap: Area3D = world._area("P4_LoadingGapSeen", ml(Vector3(18.0, 1.0, 15.9)), Vector3(4.0, 2.0, 3.2), 2,
		func(bb): if bb == player and not Game.has_flag("p4_loading_down"): Dialogue.say("p4_loading_gap", true), market.global_transform.basis)
	gap.reparent(self)
	var bk: Area3D = world._area("P4_BackRoomSeen", ml(Vector3(8.0, 1.0, 15.9)), Vector3(5.0, 2.0, 3.0), 2,
		func(bb):
			if bb == player and not Game.has_flag("p4_backexit_closed"):
				Dialogue.say("p4_back_ajar", true)
			if bb == player and not Game.has_flag("p4_breaker") and not (flashlight and flashlight.on):
				Dialogue.say("p4_dark_back", true), market.global_transform.basis)
	bk.reparent(self)


func _spot(n: String, pos: Vector3, size: Vector3, prompt: String, cb: Callable) -> Interactable:
	var s := Node3D.new()
	s.name = n
	market.add_child(s)
	s.position = pos
	var it := Interactable.attach(s, {"kind": "custom", "label": n, "prompt_text": prompt})
	var cs := it.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = size
	cs.position = Vector3.ZERO
	it.used.connect(cb)
	return it


func _setup_pickups() -> void:
	var fl := FLASHLIGHT.instantiate() as Node3D
	fl.name = "P4_Flashlight"
	market.add_child(fl)
	fl.position = SERVICE_FLASHLIGHT
	fl.rotation.y = 0.4
	var fl_it := Interactable.attach(fl, {"kind": "pickup", "label": "Flashlight", "item_id": "flashlight",
		"state_key": "p4/flashlight", "prompt_text": Interactable.key_hint() + "Pick Up Flashlight"})
	if Game.has_item("flashlight") and not fl_it.taken:
		fl_it._take(true)                             # carried already: no second one on the counter
	fl_it.used.connect(func(_b): _got_flashlight())
	its["flashlight"] = fl_it
	var bp := BATTERY_PACK.instantiate() as Node3D
	bp.name = "P4_Batteries"
	market.add_child(bp)
	bp.position = SERVICE_BATTERIES
	var bp_it := Interactable.attach(bp, {"kind": "pickup", "label": "Batteries", "item_id": "batteries",
		"state_key": "p4/batteries"})
	bp_it.used.connect(func(_b): _got_batteries(int(cfg.get("flashlight", {}).get("spares_in_pack", 2))))
	its["batteries"] = bp_it
	_settle_items.call_deferred()


## Items rest on the surface actually below them (counter top, pallet top): a ray down from just above each spot
## against the world colliders; the Pack 08 items have their origin at their base. placement = metres each item
## was off the surface before settling (tests; positive = floating).
var placement := {}


func _settle_items() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for k in ["flashlight", "batteries", "battery_single"]:
		var it: Interactable = its.get(k)
		if it == null or it.target == null:
			continue
		var n: Node3D = it.target
		var ex: Array[RID] = [player.get_rid()]
		for co in n.find_children("*", "CollisionObject3D", true, false):
			ex.append((co as CollisionObject3D).get_rid())
		var top := n.global_position + Vector3.UP * 0.3
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top, n.global_position - Vector3.UP * 0.6, 1, ex))
		if hit.is_empty():
			placement[k] = INF
			continue
		placement[k] = n.global_position.y - hit.position.y
		n.global_position.y = hit.position.y + 0.002
		it._base = n.transform                        # the pickup's own rest transform follows


func _setup_back_room() -> void:
	var br := _spot("P4_Breaker", BREAKER_BOX[0], BREAKER_BOX[1], "[E] Throw the Breaker", _throw_breaker)
	its["breaker"] = br
	for pair in [["loading", LOADING_PALLET], ["back", BACK_PALLET]]:
		var p := PALLET.instantiate() as Node3D
		p.name = "P4_Pallet_" + pair[0]
		market.add_child(p)
		p.position = pair[1][0]
		p.rotation.y = pair[1][2]
		_pallets[pair[0]] = p
		var it := Interactable.attach(p, {"kind": "custom", "label": "Pallets", "prompt_text": "[E] Push the Pallets Against the Door"})
		it.used.connect(_push_pallet.bind(pair[0]))
		its["pallet_" + pair[0]] = it
	# one spare battery on top of the loading-bay pallets (forgiving: there is always another battery)
	var bt := BATTERY.instantiate() as Node3D
	bt.name = "P4_Battery"
	_pallets["loading"].add_child(bt)
	bt.position = Vector3(0.2, 1.35, 0.1)
	var bt_it := Interactable.attach(bt, {"kind": "pickup", "label": "Battery", "item_id": "batteries",
		"state_key": "p4/battery_single"})
	bt_it.used.connect(func(_b): _got_batteries(int(cfg.get("flashlight", {}).get("spares_single", 1))))
	its["battery_single"] = bt_it


func _setup_rest() -> void:
	var bed := Node3D.new()
	bed.name = "P4_Bedroll"
	market.add_child(bed)
	bed.position = BEDROLL
	bed.rotation.y = PI * 0.5                          # its length along the office's clear patch
	var made := _bedroll(bed, "Made")
	made.visible = bed_made()
	rest = REST_SCRIPT.new()
	rest.name = "RestPoint"
	rest.shelter_id = "supermarket_office"
	rest.prompt = "[E] Sleep"
	bed.add_child(rest)
	rest.setup(Vector3(1.0, 0.6, BED_LEN), choice, hud, player)
	rest.can_rest = func() -> bool: return Game.has_flag("p4_threat_done") and bed_made()
	rest.refused.connect(func(_id): Dialogue.say("p4_not_tired", false, true))
	rest.slept.connect(_on_slept)
	bed.visible = Game.has_flag("p4_threat_done")
	# the bedding piles outside the office, and the spot the bed is made
	var card := Node3D.new()
	card.name = "P4_BedPile_Card"
	market.add_child(card)
	card.position = BED_PILE_CARD
	if ResourceLoader.exists(CARD_STACK):
		card.add_child((load(CARD_STACK) as PackedScene).instantiate())
	its["bed_card"] = Interactable.attach(card, {"kind": "custom", "label": "Cardboard", "prompt_text": "[E] Take Flattened Cardboard"})
	its["bed_card"].used.connect(func(_b): _take_bedding("card"))
	var soft := Node3D.new()
	soft.name = "P4_BedPile_Soft"
	market.add_child(soft)
	soft.position = BED_PILE_SOFT
	soft.add_child(BLANKET.instantiate())
	var pil := PILLOW.instantiate() as Node3D
	pil.position = Vector3(0.0, 0.12, 0.05)
	soft.add_child(pil)
	its["bed_soft"] = Interactable.attach(soft, {"kind": "custom", "label": "Blanket", "prompt_text": "[E] Take Blanket and Pillow"})
	its["bed_soft"].used.connect(func(_b): _take_bedding("soft"))
	var mk := Node3D.new()
	mk.name = "P4_MakeBed"
	bed.add_child(mk)
	mk.position = Vector3(0, 0.3, 0)
	its["bed_make"] = Interactable.attach(mk, {"kind": "custom", "label": "Bed", "prompt_text": ""})
	var cs := its["bed_make"].get_child(0) as CollisionShape3D
	if cs and cs.shape is BoxShape3D:
		(cs.shape as BoxShape3D).size = Vector3(BED_W + 0.3, 0.6, BED_LEN)
	its["bed_make"].used.connect(func(_b): _make_bed())
	_bed_state()


func bed_made() -> bool:
	return Game.has_flag("p4_bed_made") or Game.has_flag("p4_slept")


## A makeshift bed: two sheets of flattened cardboard, a blanket over most of it, a pillow at the head (local -Z).
func _bedroll(parent: Node3D, nm: String) -> Node3D:
	var root := Node3D.new()
	root.name = nm
	parent.add_child(root)
	var cmat: Material = load(CARDBOARD_MAT) if ResourceLoader.exists(CARDBOARD_MAT) else null
	for k in 2:
		var sheet := MeshInstance3D.new()
		sheet.name = "Card_%d" % k
		var bm := BoxMesh.new()
		bm.size = Vector3(BED_W, 0.012, BED_LEN * 0.5 + 0.02)
		bm.material = cmat
		sheet.mesh = bm
		sheet.position = Vector3(0.02 * (1 - 2 * k), 0.006, (k - 0.5) * BED_LEN * 0.5)
		sheet.rotation.y = 0.03 * (1 - 2 * k)
		root.add_child(sheet)
	var bl := MeshInstance3D.new()
	bl.name = "Blanket"
	var bb := BoxMesh.new()
	bb.size = Vector3(BED_W - 0.06, 0.03, BED_LEN * 0.72)
	bb.material = _blanket_mat()
	bl.mesh = bb
	bl.position = Vector3(0.0, 0.027, BED_LEN * 0.14)
	root.add_child(bl)
	var pil := PILLOW.instantiate() as Node3D
	pil.name = "Pillow"
	pil.position = Vector3(0.0, 0.012, -BED_LEN * 0.36)
	root.add_child(pil)
	return root


func _blanket_mat() -> Material:
	var b := BLANKET.instantiate()
	var mat: Material = null
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m and m.get_surface_count() > 0:
			mat = m.surface_get_material(0)
			break
	b.free()
	return mat


func _take_bedding(which: String) -> void:
	var it: Interactable = its["bed_card" if which == "card" else "bed_soft"]
	if not Game.has_flag("p4_threat_done") or Game.has_flag("p4_bed_" + which):
		return
	Game.set_flag("p4_bed_" + which)
	Sfx.play("pickup", (it as Node3D).global_position, -6.0, 0.9)
	_bed_state()
	if Game.has_flag("p4_bed_card") and Game.has_flag("p4_bed_soft"):
		Game.set_flag("p4_bed_gathered")
		Dialogue.say("p4_bed_gathered", false, true)
	_rest_beacon()


## [E] Make a Bed: down on the office floor, the cardboard laid out sheet by sheet, the blanket shaken out over it,
## the pillow dropped at the head. Then the bed is there to sleep in.
func _make_bed() -> void:
	if bed_made() or not (Game.has_flag("p4_bed_card") and Game.has_flag("p4_bed_soft")) or _bed_busy:
		return
	_bed_busy = true
	its["bed_make"].prompt_text = ""
	player.set("controls_enabled", false)
	player.set("look_enabled", false)
	player.set("velocity", Vector3.ZERO)
	var bed := rest.get_parent() as Node3D
	var made := bed.get_node("Made") as Node3D
	var to: Vector3 = bed.global_position
	var eye: Vector3 = player.camera.global_position
	var v := (to - eye).normalized()
	player.set_yaw_pitch(atan2(-v.x, -v.z), clampf(asin(clampf(v.y, -1.0, 1.0)), -1.1, 0.2))
	made.visible = true
	var parts: Array = [made.get_node("Card_0"), made.get_node("Card_1"), made.get_node("Blanket"), made.get_node("Pillow")]
	for p in parts:
		(p as Node3D).visible = false
	for i in parts.size():
		var n: Node3D = parts[i]
		var end := n.position
		n.position = end + Vector3(0, 0.55, 0.15)
		n.visible = true
		if n.name == "Blanket":
			n.scale = Vector3(1.0, 1.0, 0.25)             # folded, then shaken out
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position", end, 0.45)
		if n.name == "Blanket":
			tw.parallel().tween_property(n, "scale", Vector3.ONE, 0.55)
		Sfx.play("pickup", n.global_position, -10.0, 0.6 + 0.1 * i)
		await tw.finished
	Game.set_flag("p4_bed_made")
	_bed_busy = false
	player.set("controls_enabled", true)
	player.set("look_enabled", true)
	_bed_state()
	_rest_beacon()
	_companion_beds(false)


var _bed_busy := false


## What shows: the piles until taken, the make-bed prompt once both are in hand, then the bed and [E] Sleep.
func _bed_state() -> void:
	var threat := Game.has_flag("p4_threat_done")
	if Game.has_flag("p4_slept"):
		for f in ["p4_bed_card", "p4_bed_soft", "p4_bed_gathered", "p4_bed_made"]:
			Game.flags[f] = true                         # (older saves: they slept, so the bed was made)
	for k in ["card", "soft"]:
		var it: Interactable = its.get("bed_" + k)
		if it == null:
			continue
		var taken := Game.has_flag("p4_bed_" + k)
		(it as Node3D).visible = threat and not taken
		it.prompt_text = "" if taken or not threat else ("[E] Take Flattened Cardboard" if k == "card" else "[E] Take Blanket and Pillow")
		it.collision_layer = 8 if threat and not taken else 0
	var ready := threat and Game.has_flag("p4_bed_card") and Game.has_flag("p4_bed_soft") and not bed_made()
	if its.has("bed_make"):
		its["bed_make"].prompt_text = "[E] Make a Bed" if ready else ""
		its["bed_make"].collision_layer = 8 if ready else 0
	if rest:
		var made := (rest.get_parent() as Node3D).get_node_or_null("Made") as Node3D
		if made:
			made.visible = bed_made()
		rest.interactable.prompt_text = "[E] Sleep" if bed_made() and not Game.has_flag("p4_slept") else ""
		rest.interactable.collision_layer = 8 if bed_made() else 0
	if bed_made():
		_companion_beds(true)


## Where the night's objective points: the bedding piles, then the office floor, then the bed.
func _rest_beacon() -> void:
	if not Game.has_flag("p4_threat_done") or Game.has_flag("p4_slept"):
		return
	if not Game.has_flag("p4_bed_card"):
		world._beacon("p4_rest", ml(BED_PILE_CARD + Vector3(0, 1.4, 0)), Color(0.8, 0.85, 1.0))
	elif not Game.has_flag("p4_bed_soft"):
		world._beacon("p4_rest", ml(BED_PILE_SOFT + Vector3(0, 1.4, 0)), Color(0.8, 0.85, 1.0))
	else:
		world._beacon("p4_rest", ml(BEDROLL + Vector3(0, 1.4, 0)), Color(0.8, 0.85, 1.0))


## Eddie and Marcus make theirs: each walks to the piles, then to a clear spot outside the office, where his bed
## is laid (instant: after a load, the beds are simply there).
func _companion_beds(instant: bool) -> void:
	for nm in COMPANION_BEDS:
		if market.get_node_or_null("P4_Bed_" + nm) != null:
			continue
		var spot: Vector3 = _clear_bed_spot(COMPANION_BEDS[nm])
		if not spot.is_finite():
			continue
		var holder := Node3D.new()
		holder.name = "P4_Bed_" + nm
		market.add_child(holder)
		holder.position = spot
		holder.rotation.y = PI * 0.5
		var bedr := _bedroll(holder, "Made")
		bedr.visible = instant
		if not instant and world.animators.has(nm):
			_lay_companion_bed(nm, spot, bedr)
		else:
			bedr.visible = true


func _lay_companion_bed(nm: String, spot: Vector3, bedr: Node3D) -> void:
	world.npc_walk(nm, BED_PILE_CARD + Vector3(0.6, 0, -0.6), 1.6)
	var a = world.animators[nm]
	var t := 0.0
	while t < 9.0 and a.is_walking():
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().create_timer(0.6).timeout              # (picking it up)
	world.npc_walk(nm, spot + Vector3(0.0, 0, 0.9), 1.4)
	t = 0.0
	while t < 12.0 and a.is_walking():
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(bedr):
		bedr.visible = true
		Sfx.play("pickup", bedr.global_position, -12.0, 0.7)


## The first candidate with a clear bed-sized patch of floor (nothing solid there but the floor itself).
func _clear_bed_spot(cands: Array) -> Vector3:
	var space: PhysicsDirectSpaceState3D = (world.get_world_3d() as World3D).direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(BED_LEN, 0.35, BED_W)
	q.shape = bx
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	for c in cands:
		q.transform = Transform3D(market.global_basis, ml(c + Vector3(0, 0.3, 0)))
		if space.intersect_shape(q, 1).is_empty():
			return c
	return Vector3.INF


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	_set_power(Game.has_flag("p4_breaker"))
	var ld: Node3D = its["loading_door"]
	ld.transform = _base["loading"] if Game.has_flag("p4_loading_down") else \
		Transform3D(_base["loading"].basis, _base["loading"].origin + Vector3(0, LOADING_GAP, 0))
	var bd: Node3D = its["back_door"]
	var tb: Transform3D = _base["back"]
	bd.transform = tb if Game.has_flag("p4_backexit_closed") else \
		Transform3D(tb.basis * Basis(Vector3.UP, deg_to_rad(_base["back_ajar_deg"])), tb.origin)
	for k in ["loading", "back"]:
		var done := Game.has_flag("p4_loading_secured" if k == "loading" else "p4_backexit_secured")
		var spec: Array = LOADING_PALLET if k == "loading" else BACK_PALLET
		_pallets[k].position = spec[1] if done else spec[0]
		its["pallet_" + k].prompt_text = "" if done else "[E] Push the Pallets Against the Door"
	its["breaker"].prompt_text = "" if Game.has_flag("p4_breaker") else "[E] Throw the Breaker"
	its["loading"].prompt_text = "" if Game.has_flag("p4_loading_down") else "[E] Pull the Loading Door Down"
	its["backdoor"].prompt_text = "" if Game.has_flag("p4_backexit_closed") else "[E] Close the Back Door"
	for k in ["npc_Eddie", "npc_Marcus"]:
		if its.has(k):
			its[k].prompt_text = "" if Game.has_flag("p4_talk_done") else "[E] Talk"
	if rest:
		rest.get_parent().visible = Game.has_flag("p4_threat_done")
		_bed_state()
	# the flashlight on the service desk: the game's ordinary pickup diamond until it is taken (no white glow / light)
	if its.has("flashlight"):
		var fl_on: bool = not Game.has_flag("p4_flashlight") and not (its["flashlight"] as Interactable).taken
		hud.world_diamond("p4_flashlight", its["flashlight"] if fl_on else null)
	world._clear_beacon("p4")


func _set_power(on: bool) -> void:
	var em: Dictionary = cfg.get("emergency_lights", {})
	var col: Array = em.get("color", [1.0, 0.74, 0.56])
	var flick: Dictionary = em.get("flicker", {})
	for l in _lights:
		var light := l as Light3D
		for c in light.get_children():
			if c.get_script() == FLICKER:
				c.queue_free()
		if not on or String(light.name).begins_with("ExtLight") or light.name == "Light_VEST":
			light.visible = false                          # outside / vestibule lights stay dead
			continue
		light.visible = true
		light.light_energy = float(em.get("energy", 0.26)) * float(_base[light.name])
		light.light_color = Color(col[0], col[1], col[2])
		if flick.has(String(light.name)):
			var fl: Node = FLICKER.new()
			fl.mode = FLICKER.Mode.get(flick[String(light.name)], FLICKER.Mode.FLUORESCENT)
			fl.amount = 0.8
			fl.seed = light.name.hash()
			light.add_child(fl)


func _atmo_preset(instant: bool) -> void:
	var p = load(PRESET_PATH)
	if p:
		world._atmo().apply_preset(p, instant)


# ------------------------------------------------------------------ story steps
func _got_flashlight() -> void:
	Game.set_flag("p4_flashlight")
	hud.world_diamond("p4_flashlight", null)
	world._clear_beacon("p4")
	_attach_flashlight()
	flashlight.set_on(true)
	Dialogue.say("p4_flashlight", false, true)
	hud.set_hint("Flashlight: F turns it on / off  ·  R puts in fresh batteries  ·  Tab: inventory")
	get_tree().create_timer(6.0).timeout.connect(func(): if is_instance_valid(hud): hud.set_hint(""))


func _got_batteries(n: int) -> void:
	if flashlight == null:
		_attach_flashlight()
	flashlight.add_spares(n)


func _attach_flashlight() -> void:
	if flashlight:
		return
	flashlight = FLASHLIGHT_SCRIPT.new()
	flashlight.name = "Flashlight"
	player.add_child(flashlight)
	flashlight.setup(player, cfg.get("flashlight", {}))


## The night's work (breaker, back door, pallets) waits for the flashlight: it is pitch dark back there.
func _need_light() -> bool:
	if Game.has_flag("p4_flashlight") or Game.has_item("flashlight"):
		return false
	hud.set_hint("Too dark to work back here. Find a flashlight first - the customer service desk.")
	get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(hud): hud.set_hint(""))
	return true


func _throw_breaker(_b: Node) -> void:
	if _need_light():
		return
	if Game.has_flag("p4_breaker"):
		Dialogue.say("p4_breaker_again", false, true)
		return
	Sfx.play("door_close", ml(BREAKER), 2.0, 0.5)
	Dialogue.say("p4_breaker", false, true)
	await get_tree().create_timer(1.2).timeout
	Game.set_flag("p4_breaker")
	_apply()
	_flicker_burst(1.2)


func _pull_loading(_b: Node) -> void:
	if Game.has_flag("p4_loading_down"):
		return
	its["loading"].prompt_text = ""
	if garage:
		garage.on_close_started()
	var ld: Node3D = its["loading_door"]
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(ld, "transform", _base["loading"], 1.4)
	_play("rattle", ml(LOADING_HANDLE), -2.0)
	await tw.finished
	Game.set_flag("p4_loading_down")
	Dialogue.say("p4_loading_down", false, true)
	_check_exits()


func _close_back(_b: Node) -> void:
	if _need_light():
		return
	if Game.has_flag("p4_backexit_closed"):
		return
	its["backdoor"].prompt_text = ""
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(its["back_door"], "transform", _base["back"], 0.6)
	Sfx.play("door_close", ml(BACKDOOR_HANDLE), 0.0, 0.8)
	await tw.finished
	Game.set_flag("p4_backexit_closed")
	Dialogue.say("p4_back_closed", false, true)
	_check_exits()


func _push_pallet(_b: Node, which: String) -> void:
	if _need_light():
		return
	var need := "p4_loading_down" if which == "loading" else "p4_backexit_closed"
	var done_flag := "p4_loading_secured" if which == "loading" else "p4_backexit_secured"
	if Game.has_flag(done_flag):
		return
	if not Game.has_flag(need):
		Dialogue.say("p4_need_close", false, true)
		return
	its["pallet_" + which].prompt_text = ""
	var spec: Array = LOADING_PALLET if which == "loading" else BACK_PALLET
	var pal: Node3D = _pallets[which]
	# the protagonist puts his shoulder to it: control is held, the view turns to the stack
	player.controls_enabled = false
	var look: Vector3 = pal.global_position + Vector3(0, 0.8, 0) - player.camera.global_position
	player.set_yaw_pitch(atan2(-look.x, -look.z), clampf(asin(clampf(look.normalized().y, -1.0, 1.0)), -0.5, 0.2))
	# three heavy shoves (ease in / out each, short pauses), a scrape per shove, a slight twist that settles square
	var p0: Vector3 = pal.position
	var p1: Vector3 = spec[1]
	var yaw0: float = spec[2]
	var tw := create_tween()
	for i in 3:
		var a: Vector3 = p0.lerp(p1, [0.0, 0.42, 0.78][i])
		var b: Vector3 = p0.lerp(p1, [0.42, 0.78, 1.0][i])
		var wob: float = deg_to_rad([1.6, -1.1, 0.0][i])
		tw.tween_callback(_play.bind("drag", ml(a), -2.0 - 1.5 * i))   # wood on concrete, one per shove
		tw.tween_property(pal, "position", b, float([0.55, 0.5, 0.42][i])).from(a).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(pal, "rotation:y", yaw0 + wob, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.22 if i < 2 else 0.0)
	tw.tween_property(pal, "rotation:y", yaw0, 0.18)
	await tw.finished
	_play("thud", ml(p1), 0.0)                        # home against the door: one solid thud
	pal.position = p1
	pal.rotation.y = yaw0
	player.controls_enabled = true
	Game.set_flag(done_flag)
	Dialogue.say("p4_pallet", false, true)
	_check_exits()


func _check_exits() -> void:
	if Game.has_flag("p4_loading_secured") and Game.has_flag("p4_backexit_secured") and not Game.has_flag("p4_exits_secured"):
		Game.set_flag("p4_exits_secured")
		Dialogue.say("p4_exits_done")


func _talk(_b: Node) -> void:
	if Game.has_flag("p4_talk_done"):
		return
	var both := [world.eddie, world.marcus].filter(func(n): return n != null)
	if not (Game.has_flag("p4_breaker") and Game.has_flag("p4_exits_secured")):
		world.converse(["p4_eddie_busy" if Game.has_flag("p4_breaker") else "p4_wait_talk"], [world.eddie])
		return
	# survivors face the protagonist; the standard talk camera holds through the lines, the choice and the reply
	if not world.can_talk(world.eddie):
		return
	for k in ["npc_Eddie", "npc_Marcus"]:
		its[k].prompt_text = ""
	world.converse(["p4_talk"], both)


func _on_choices(id: String, choices: Array) -> void:
	if id != "p4_talk" or Game.has_flag("p4_choice_made"):
		return
	var texts: Array = []
	for c in choices:
		texts.append(c["text"])
	var i: int = await choice.ask("", texts, player)
	var c: Dictionary = choices[clampi(i, 0, choices.size() - 1)]
	Game.set_flag(c.get("flag", "p4_choice_" + str(i)))           # recorded for later chapters; no branching yet
	Game.set_flag("p4_choice_made")
	Dialogue.say(c["next"], false, true)
	while Dialogue.is_busy():
		await get_tree().process_frame
	Game.set_flag("p4_talk_done")
	if not Game.has_flag("p4_choice_noah"):           # "we can't leave Noah": the outside scene starts at once
		await get_tree().create_timer(float(cfg.get("threat", {}).get("delay_after_talk", 5.0))).timeout
	_run_threat()


# ------------------------------------------------------------------ something outside (no combat)
func _run_threat() -> void:
	if _threat_running or Game.has_flag("p4_threat_done"):
		return
	_threat_running = true
	threat_runs += 1
	var anims: Dictionary = world.animators
	# the player's choice decides the night: "wait until morning" = nobody goes out, no creature at all (only
	# banging at the back door in the night, see _on_slept); "we can't leave Noah" = they step outside and a Hound
	# charges them (_hound_charge)
	if Game.has_flag("p4_choice_wait"):
		Game.set_flag("p4_threat_done")
		_threat_running = false
		_apply()
		Dialogue.say("p4_bed_hint", false, true)
		_bed_state()
		_rest_beacon()
		return
	if Game.has_flag("p4_choice_noah"):
		await _hound_charge()
		Sfx.stop_ambience()
		await get_tree().create_timer(3.0).timeout
		Sfx.start_ambience()
		Dialogue.say("p4_threat_after", false, true)
		while Dialogue.is_busy():
			await get_tree().process_frame
		Game.set_flag("p4_threat_done")
		_threat_running = false
		_apply()
		Dialogue.say("p4_bed_hint", false, true)
		_bed_state()
		_rest_beacon()
		return
	# 1. scraping along the outside wall, lights stutter
	_play("scrape", ml(Vector3(-12.0, 1.2, -1.0)), 2.0)
	_flicker_burst(2.5)
	Dialogue.say("p4_threat_scrape", false, true)
	for k in anims:
		anims[k].set_mood("scared")
		anims[k].face_towards(ml(Vector3(0, 1.2, -4.0)))
	# 2. a shape passes behind the front glass, half lost in the mist
	_spawn_hound()
	await get_tree().create_timer(7.5).timeout
	# 3. it hits the barricaded rear exit: wind-up, the strike's contact frame = impact (sound, the leaf jolts
	#    against the pallets and rebounds, lights flicker), recovery, then it is gone
	await _door_strike()
	Dialogue.say("p4_threat_hit", false, true)
	if is_instance_valid(hound):
		hound.queue_free()
	# 4. silence
	Sfx.stop_ambience()
	await get_tree().create_timer(5.0).timeout
	Sfx.start_ambience()
	Dialogue.say("p4_threat_after", false, true)
	while Dialogue.is_busy():
		await get_tree().process_frame
	Game.set_flag("p4_threat_done")
	_threat_running = false
	_apply()
	Dialogue.say("p4_bed_hint", false, true)
	_bed_state()
	_rest_beacon()


## ACCEPT: first person throughout. The protagonist and Marcus step out of the front doors; a moment of quiet; a
## Skitter (Pack 07, dark creature look) comes out of the fog at a sprint; the protagonist turns, runs back in with
## Marcus, turns and the doors slide shut; it slams into the shut leaves (impact, doors and view shake), recoils,
## shakes itself, turns left and scuttles off into the fog. Once (flag p4_hound_charged, kept for old saves).
const SKITTER_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const EYE := 1.62
var charge_report := {}


func _fp_to(cam: Camera3D, pts: Array, speed: float) -> void:
	player.set_physics_process(false)             # scripted steps: the body's own physics would push back on kerbs
	for q in pts:
		var target: Vector3 = ml(q)
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
			var np: Vector3 = player.global_position + d.normalized() * minf(speed * dt, d.length())
			np.y = move_toward(player.global_position.y, _floor_y(np) + 0.0, dt * 2.5)
			player.global_position = np
			var want := Transform3D(Basis(), cam.global_position).looking_at(cam.global_position + d.normalized() + Vector3(0, -0.06, 0), Vector3.UP).basis
			cam.global_basis = Basis(cam.global_basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), minf(dt * 8.0, 1.0)))
			cam.global_position = player.global_position + Vector3(0, EYE - 0.15 + sin(Time.get_ticks_msec() * 0.013) * 0.02 * speed / 4.0, 0)
			await get_tree().process_frame
	player.set_physics_process(true)


func _fp_face(cam: Camera3D, at: Vector3, seconds: float) -> void:
	var b0 := cam.global_basis.get_rotation_quaternion()
	var b1 := Transform3D(Basis(), cam.global_position).looking_at(at, Vector3.UP).basis.get_rotation_quaternion()
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		var k := clampf(t / seconds, 0.0, 1.0)
		cam.global_basis = Basis(b0.slerp(b1, k * k * (3.0 - 2.0 * k)))
		await get_tree().process_frame


func _floor_y(p: Vector3) -> float:
	var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.0, 0), p + Vector3(0, -3.0, 0), 1))
	return (hit["position"] as Vector3).y if hit else p.y


## Moves the Skitter on the ground to `to_local` (market frame) at `speed`, feet on the floor, gait matched.
func _skitter_run(sk: Node3D, ap: AnimationPlayer, to_local: Vector3, speed: float) -> void:
	var target := ml(to_local)
	var authored := float(sk.get_meta("scuttle_speed_mps", 2.6)) * sk.scale.x
	if ap and ap.has_animation("Scuttle_Fast"):
		if ap.current_animation != "Scuttle_Fast":
			ap.play("Scuttle_Fast", 0.1)
		ap.speed_scale = speed / maxf(authored, 0.1)
	while is_instance_valid(sk):
		var d := (target - sk.global_position) * Vector3(1, 0, 1)
		if d.length() < 0.05:
			break
		var dt := get_process_delta_time()
		var p := sk.global_position + d.normalized() * minf(speed * dt, d.length())
		p.y = _floor_y(p) - float(sk.get_meta("feet_y", 0.0))       # its lowest point (the feet) on the ground
		sk.global_position = p
		sk.rotation.y = lerp_angle(sk.rotation.y, atan2(d.x, d.z), minf(dt * 10.0, 1.0))   # the model faces +Z
		charge_report["max_speed"] = maxf(float(charge_report.get("max_speed", 0.0)), speed)
		await get_tree().process_frame


## Turn the first-person camera towards `at` a little each frame (follows a moving thing smoothly).
func _fp_track(cam: Camera3D, at: Vector3, rate: float) -> void:
	var want := Transform3D(Basis(), cam.global_position).looking_at(at, Vector3.UP).basis.get_rotation_quaternion()
	cam.global_basis = Basis(cam.global_basis.get_rotation_quaternion().slerp(want, minf(get_process_delta_time() * rate, 1.0)))


## The building to the left of the game store (Storefront_A), across the street from the supermarket doors.
const ROOF_BUILDING := "COM_Storefront_A_Exterior"
const ROOF_X := [3.0, 5.0, 1.5, 7.0]           ## market-local x of the roof spots tried (nearest the doors' axis first)
const LANDINGS := [Vector3(2.5, 0, -24.0), Vector3(1.0, 0, -22.0), Vector3(4.0, 0, -20.0), Vector3(0.5, 0, -18.0)]
const EXITS := [Vector3(-30.0, 0.0, -6.0), Vector3(-26.0, 0.0, -10.0), Vector3(-22.0, 0.0, -14.0), Vector3(-30.0, 0.0, -3.0)]


## Highest visual surface of `mesh` straight below/above `wp` (the roof has no collision to ray-cast against).
func _mesh_top(m: MeshInstance3D, wp: Vector3) -> float:
	var inv := m.global_transform.affine_inverse()
	var a := inv * (wp + Vector3(0, 60, 0))
	var b := inv * (wp - Vector3(0, 60, 0))
	var best := -INF
	var f: PackedVector3Array = m.get_meta("faces") if m.has_meta("faces") else m.mesh.get_faces()
	m.set_meta("faces", f)
	for i in range(0, f.size(), 3):
		var hit = Geometry3D.segment_intersects_triangle(a, b, f[i], f[i + 1], f[i + 2])
		if hit != null:
			best = maxf(best, (m.global_transform * (hit as Vector3)).y)
	return best


## A box the size of the Skitter's body and legs swept from a to b touches nothing in the static world: no car, fence, wall.
func _run_clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.45, 1.6)
	q.shape = box
	q.collision_mask = 1
	# the back-room pallet stacks (inside, 15+ m behind the front doors) are left out: their convex collision hull
	# reports a false overlap at the entrance in this query, though nothing of them is anywhere near the street
	var ex: Array[RID] = [player.get_rid()]
	for k in _pallets:
		for sb in (_pallets[k] as Node).find_children("*", "StaticBody3D", true, false):
			ex.append((sb as StaticBody3D).get_rid())
	q.exclude = ex
	var dir := (b - a) * Vector3(1, 0, 1)
	# bottom ~0.38 m above its feet: it steps up a kerb (~0.15 m); cars, fences and walls are all taller than that
	q.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), a + Vector3(0, 0.6, 0))
	q.motion = dir
	var r := player.get_world_3d().direct_space_state.cast_motion(q)
	return r[0] >= 0.999


## Places the Skitter crouched on the real roof surface, ~2.5 m back from its front edge (out of the street's view
## line until it creeps forward); picks a landing on the road and checks the jump, the run to the doors and the
## run away against the world's collision. Returns [skitter, animation player] or [].
func _spawn_roof_skitter(doors_z: float) -> Array:
	var ps := load(SKITTER_PATH) as PackedScene
	var bld := world.find_child(ROOF_BUILDING, true, false) as MeshInstance3D
	if ps == null or bld == null:
		charge_report["roof_error"] = "missing Skitter or %s" % ROOF_BUILDING
		return []
	var edge := Vector3.INF
	var back := Vector3.INF
	var roof_y := 0.0
	for x in ROOF_X:
		# walk from the street towards the building (market-local -z) to the facade, then take the highest point of
		# its front metre: the top of the parapet (4.68 m; the flat roof behind it is 1.2 m lower and out of sight)
		var z := doors_z - 30.0
		var found := false
		while z > doors_z - 40.0:
			var y := _mesh_top(bld, ml(Vector3(x, 0, z)))
			if y > market.global_position.y + 3.0:
				var best_y := y
				var best_z := z
				var zz := z
				while zz > z - 1.0:
					var yy := _mesh_top(bld, ml(Vector3(x, 0, zz)))
					if yy > best_y + 0.01:
						best_y = yy
						best_z = zz
					zz -= 0.05
				edge = ml(Vector3(x, 0, best_z))
				edge.y = best_y
				back = edge                              # it waits crouched ON the parapet, not behind it
				roof_y = best_y
				found = true
				break
			z -= 0.1
		if found:
			break
	if not edge.is_finite():
		charge_report["roof_error"] = "no flat roof edge found"
		return []
	var sk := ps.instantiate() as Node3D
	sk.name = "P4_Skitter_Charge"
	world.add_child(sk)
	if sk is CollisionObject3D:
		(sk as CollisionObject3D).collision_layer = 0
		(sk as CollisionObject3D).collision_mask = 0
	sk.set_physics_process(false)
	charge_report["dark_surfaces"] = VeilCreatureLook.apply_skitter(sk, market.global_position.y)
	sk.set_meta("feet_y", Interactable.aabb_of(sk).position.y * sk.scale.y)
	charge_report["feet_y"] = sk.get_meta("feet_y")
	sk.global_position = back - Vector3(0, float(sk.get_meta("feet_y")), 0)
	var face := (ml(Vector3(0, 0, doors_z)) - edge) * Vector3(1, 0, 1)
	sk.rotation.y = atan2(face.x, face.z)                       # the model faces +Z: towards the supermarket
	sk.set_meta("roof_edge", edge - Vector3(0, float(sk.get_meta("feet_y")), 0))
	sk.set_meta("roof_y", roof_y - float(sk.get_meta("feet_y")))
	var ap := sk.get_node_or_null(String(sk.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
	if ap and ap.has_animation("Idle_Twitch"):
		ap.play("Idle_Twitch")
	# landing + runs: the first candidate whose jump line and both runs are clear of the world's collision
	var hit_at := ml(Vector3(0.1, 0.0, doors_z - 1.2))
	var space := player.get_world_3d().direct_space_state
	var chosen := Vector3.INF
	for c in LANDINGS:
		var land := ml(c + Vector3(0, 0, doors_z))
		land.y = _floor_y(land)
		var jump := space.intersect_ray(PhysicsRayQueryParameters3D.create(edge + Vector3(0, 0.5, 0), land + Vector3(0, 0.6, 0), 1, [player.get_rid()]))
		if jump.is_empty() and _run_clear(land, hit_at):
			chosen = land
			break
	charge_report["landing_found"] = chosen.is_finite()
	if not chosen.is_finite():
		chosen = ml(LANDINGS[0] + Vector3(0, 0, doors_z))
		chosen.y = _floor_y(chosen)
	sk.set_meta("landing", chosen - Vector3(0, float(sk.get_meta("feet_y")), 0))
	charge_report["run_clear"] = _run_clear(chosen, hit_at)
	var exit_to: Vector3 = EXITS[0] + Vector3(0, 0, doors_z)
	for e in EXITS:
		if _run_clear(hit_at, ml(e + Vector3(0, 0, doors_z))):
			exit_to = e + Vector3(0, 0, doors_z)
			charge_report["exit_clear"] = true
			break
	sk.set_meta("exit_local", exit_to)
	var scuttle := AudioStreamPlayer3D.new()
	scuttle.name = "Scuttle"
	scuttle.stream = _streams["scuttle"]
	scuttle.unit_size = 5.0
	scuttle.max_distance = 60.0
	scuttle.volume_db = 2.0
	sk.add_child(scuttle)
	charge_report["spawned"] = true
	charge_report["creature"] = "Skitter"
	charge_report["start"] = "roof"
	charge_report["roof_building"] = ROOF_BUILDING
	return [sk, ap]


var garage: VeilGarageTentacle
var _cam_held: Camera3D
## While a scripted first-person shot owns `cam`: it stays the current camera and the player can neither move nor look.
func _hold_cam(cam: Camera3D) -> void:
	_cam_held = cam
	while is_instance_valid(cam) and _cam_held == cam:
		if not cam.current:
			cam.current = true
		player.set("controls_enabled", false)
		player.set("look_enabled", false)
		await get_tree().process_frame


var _music_player: AudioStreamPlayer
## Non-positional cinematic music (sting / chase); the ambience is ducked under it.
func _music(id: String, db := 0.0) -> void:
	if id == "sting":
		var st := AudioStreamPlayer.new()
		st.stream = _streams["sting"]
		st.volume_db = db - 8.0
		add_child(st)
		st.finished.connect(st.queue_free)
		st.play()
		return
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		add_child(_music_player)
	_music_player.stream = _streams[id]
	_music_player.volume_db = db
	_music_player.play()
	Sfx.stop_ambience()
	Sfx.stop_music(0.4)                               # the soundtrack gives way to the chase


func _music_stop(fade: float) -> void:
	if _music_player and _music_player.playing:
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", -40.0, fade)
		tw.tween_callback(_music_player.stop)
		tw.tween_callback(func(): Sfx.play_music(Sfx.MUSIC_GAMEPLAY, true, -14.0, 3.0))


func _hound_charge() -> void:                   # (name kept: the accept branch's creature is now the Skitter)
	if Game.has_flag("p4_hound_charged"):
		return
	Game.set_flag("p4_hound_charged")
	# the Noah-choice conversation is still easing out: when it ends it hands the view and mouse-look back to the
	# player (that is how the mouse could turn away from the Skitter). Let it finish first, then take the camera.
	if world.has_method("end_conversation"):
		world.end_conversation()
	var wt := 0.0
	while wt < 3.0 and (world.get("conversing") or world.get("_talk_cam") != null):
		await get_tree().process_frame
		wt += get_process_delta_time()
	player.set("controls_enabled", false)
	player.set("look_enabled", false)
	player.set("velocity", Vector3.ZERO)
	var src: Camera3D = player.get("camera")
	var cam := Camera3D.new()
	cam.name = "ChargeCam"                         # first person: rides on the protagonist's body
	world.add_child(cam)
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.current = true
	_hold_cam(cam)                                 # nothing else can take the view or give mouse-look back
	var doors_z: float = market.to_local((world._auto_doors[0][0] as Node3D).global_position).z if not world._auto_doors.is_empty() else 0.2
	var set_doors := func(v: bool):
		world._doors_powered = true
		world._set_auto_doors(v)
		world._doors_powered = false
	# 0. the Skitter is already out there, crouched back from the roof edge across the street (placed before the
	# doors open: nothing appears in view)
	var sk: Node3D = null
	var ap: AnimationPlayer = null
	var spawned := _spawn_roof_skitter(doors_z)
	if not spawned.is_empty():
		sk = spawned[0]
		ap = spawned[1]
	# 1. out of the front doors with Marcus (Eddie waits inside)
	set_doors.call(true)
	await get_tree().create_timer(0.8).timeout     # the leaves are fully apart before anyone walks through
	world.npc_walk("Marcus", Vector3(1.1, 0.04, doors_z - 2.0), 1.4)
	await _fp_to(cam, [Vector3(1.5, 0.04, 4.4), Vector3(1.5, 0.04, 1.8), Vector3(0.3, 0.04, 1.0), Vector3(0.3, 0.04, doors_z - 2.4)], 1.7)
	await _fp_face(cam, ml(Vector3(-1.5, 1.5, doors_z - 14.0)), 0.8)
	await get_tree().create_timer(1.6).timeout     # the street is quiet
	# 2. a sound on the roof across the street (the building to the left of the game store): the protagonist looks
	# up; the Skitter creeps to the roof edge and crouches; a short focus (first-person zoom) on its silhouette
	var front := 0.9
	if sk:
		var bb := Interactable.aabb_of(sk)
		front = maxf(bb.end.z, 0.3) * sk.scale.z
	var hit_at := Vector3(0.1, 0.0, doors_z - 0.02 - front)      # its snout stops on the glass (~2-3 cm), not through it
	if sk:
		_play("scrape", sk.global_position + Vector3(0, 0.3, 0), 6.0)
		if ap and ap.has_animation("Alert"):
			ap.play("Alert", 0.2)
		var look_at := sk.global_position + Vector3(0, 0.35, 0)
		await _fp_face(cam, look_at, 0.9)
		var edge: Vector3 = sk.get_meta("roof_edge")
		if ap and ap.has_animation("Crawl"):
			ap.play("Crawl", 0.15)
			ap.speed_scale = 1.0
		var tc := sk.create_tween()                       # on the ledge already: it rises a little, alert
		tc.tween_property(sk, "global_position", edge + Vector3(0, 0.04, 0), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var tz := 0.0
		while tz < 1.1:                                 # the eyes follow it to the edge
			await get_tree().process_frame
			tz += get_process_delta_time()
			_fp_track(cam, sk.global_position + Vector3(0, 0.35, 0), 6.0)
		if ap and ap.has_animation("Idle_Twitch"):
			ap.play("Idle_Twitch", 0.2)
		var fov0 := cam.fov
		var tf := create_tween()
		tf.tween_property(cam, "fov", fov0 * 0.6, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		Dialogue.say("p4_skitter_seen", false, true)      # barks (no conversation camera, the action goes on)
		var hold := 0.0
		while hold < 1.5:                               # zoom in (0.6 s) + recognise the silhouette (0.9 s)
			await get_tree().process_frame
			hold += get_process_delta_time()
			_fp_track(cam, sk.global_position + Vector3(0, 0.3, 0), 8.0)
		var eye := cam.global_position
		var at := sk.global_position + Vector3(0, 0.3, 0)
		var los := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at, 1, [player.get_rid()]))
		charge_report["roof_in_view"] = cam.is_position_in_frustum(at)
		charge_report["roof_line_of_sight"] = los.is_empty()
		charge_report["roof_distance_m"] = eye.distance_to(at)
		charge_report["zoom_fov"] = cam.fov
		charge_report["roof_feet_gap_m"] = sk.global_position.y - float(sk.get_meta("roof_y"))
		# 3. the leap: a jump arc from the roof edge down to the road, its feet on the street at the landing
		var land: Vector3 = sk.get_meta("landing")
		var from := sk.global_position
		var dist_air := Vector2(land.x - from.x, land.z - from.z).length()
		var t_air := clampf(dist_air / 9.0, 0.6, 1.1)
		var peak := 1.2
		if ap and ap.has_animation("Attack_Lunge"):
			ap.play("Attack_Lunge", 0.05)
			ap.speed_scale = 1.0 / t_air
		_music("sting", -2.0)                             # a sharp sting as it leaps (the zoom stays on it)
		var dir := (land - from) * Vector3(1, 0, 1)
		sk.rotation.y = atan2(dir.x, dir.z)
		var tj := 0.0
		var max_dip := 0.0
		while tj < t_air:
			await get_tree().process_frame
			tj += get_process_delta_time()
			var k := clampf(tj / t_air, 0.0, 1.0)
			var pos := from.lerp(land, k) + Vector3(0, 4.0 * peak * k * (1.0 - k), 0)
			sk.global_position = pos
			max_dip = maxf(max_dip, _floor_y(pos) - pos.y)       # never below the ground under it
			_fp_track(cam, pos + Vector3(0, 0.3, 0), 7.0)
		sk.global_position = land
		charge_report["air_time_s"] = t_air
		charge_report["air_max_dip_m"] = max_dip
		charge_report["landing_gap_m"] = land.y - _floor_y(land)
		_play("impact", land, -2.0)                              # sharp, on the contact frame
		world._shake(cam, 0.18, 0.025)
		charge_report["landed"] = true
		# it charges: zoom back out, frantic music, Marcus shouts, run
		var tr := create_tween()
		tr.tween_property(cam, "fov", fov0, 0.4).set_trans(Tween.TRANS_SINE)
		_music("chase", -3.0)
		Dialogue.say("p4_skitter_run", false, true)
		charge_report["chase_music"] = true
		var sc := sk.get_node_or_null("Scuttle") as AudioStreamPlayer3D
		if sc:
			sc.play()
	# 4. it sprints at them: turn, run back inside with Marcus, turn, the doors slide shut
	var t0 := Time.get_ticks_msec()
	var closing := func() -> void:
		world.npc_walk("Marcus", Vector3(1.6, 0.04, 4.6), 4.2)
		await _fp_face(cam, ml(Vector3(0.6, 1.5, 3.0)), 0.35)
		await _fp_to(cam, [Vector3(0.3, 0.04, 1.2), Vector3(0.6, 0.04, 2.5)], 4.6)
		await _fp_face(cam, ml(Vector3(0.2, 1.3, doors_z - 3.0)), 0.35)
		var wm := 0.0                                 # Marcus is through before the doors close
		while wm < 1.5 and market.to_local(world.marcus.global_position).z < doors_z + 0.9:
			await get_tree().process_frame
			wm += get_process_delta_time()
		set_doors.call(false)
		await get_tree().create_timer(0.75).timeout
		charge_report["doors_closed"] = true
	closing.call()
	# the Skitter covers the rest so that it arrives just after the doors are shut
	if sk:
		var dist := ml(hit_at).distance_to(sk.global_position)
		await _skitter_run(sk, ap, hit_at, dist / 2.9)
	while not charge_report.get("doors_closed", false):
		await get_tree().process_frame
	charge_report["closed_before_hit"] = true
	charge_report["inside_at_hit"] = market.to_local(player.global_position).z > doors_z + 0.8
	# 4. the slam: on the shut doors (sound, leaves and view shake, lights)
	charge_report["slam"] = true
	if sk:
		charge_report["hit_gap_m"] = ml(Vector3(0, 0, doors_z)).z - (sk.global_position + sk.global_transform.basis.z.normalized() * front).z
		if ap and ap.has_animation("Attack_Lunge"):
			ap.play("Attack_Lunge", 0.05)
			ap.speed_scale = 1.6
	_play("impact", ml(Vector3(0, 1.0, doors_z)), 8.0)
	world._shake(cam, 0.5, 0.07)
	_flicker_burst(0.8)
	for d in world._auto_doors:
		var leaf: Node3D = d[0]
		var base: Transform3D = d[1]
		var tl := create_tween()
		for j in 4:
			var o := Vector3(0, 0, [0.07, -0.04, 0.02, 0.0][j])
			tl.tween_property(leaf, "transform", Transform3D(base.basis, base.origin + base.basis * o), [0.05, 0.08, 0.08, 0.1][j])
	if sk and is_instance_valid(sk):
		var scut := sk.get_node_or_null("Scuttle") as AudioStreamPlayer3D
		if scut:
			scut.stop()
		# 5. recoils, shakes itself, recovers
		if ap and ap.has_animation("Hit_React"):
			ap.play("Hit_React", 0.05)
			ap.speed_scale = 1.0
		var back := sk.global_position - sk.global_transform.basis.z.normalized() * 0.9
		var ts := sk.create_tween()
		ts.tween_property(sk, "global_position", back, 0.3).set_trans(Tween.TRANS_SINE)
		ts.tween_property(sk, "rotation:z", 0.16, 0.08)
		ts.tween_property(sk, "rotation:z", -0.14, 0.09)
		ts.tween_property(sk, "rotation:z", 0.08, 0.08)
		ts.tween_property(sk, "rotation:z", 0.0, 0.08)
		await ts.finished
		await get_tree().create_timer(0.35).timeout
		# 6. turns left and scuttles off into the fog
		if scut:
			scut.play()
		await _skitter_run(sk, ap, sk.get_meta("exit_local", Vector3(-30.0, 0.0, doors_z - 6.0)), 9.0)
		charge_report["left_into_fog"] = true
		if is_instance_valid(sk):
			sk.queue_free()
	_music_stop(1.6)
	charge_report["gone"] = true
	charge_report["ms"] = Time.get_ticks_msec() - t0
	# control back, looking at the doors
	var fwd := -cam.global_transform.basis.z
	player.call("set_yaw_pitch", atan2(-fwd.x, -fwd.z), 0.0)
	_cam_held = null
	cam.queue_free()
	src.current = true
	player.set("controls_enabled", true)
	player.set("look_enabled", true)


## REFUSE: during the night, heavy irregular banging at the back door; nobody goes to see what it was.
func _night_banging() -> void:
	var bd: Node3D = its.get("back_door")
	var base: Transform3D = _base.get("back", bd.transform if bd else Transform3D())
	for k in 6:
		await get_tree().create_timer([0.9, 1.6, 0.5, 2.2, 0.7, 1.4][k]).timeout
		_play("impact", ml(BACKDOOR_HANDLE), 3.0 - k * 0.5)
		if bd:
			var tw := create_tween()
			tw.tween_property(bd, "transform", Transform3D(base.basis * Basis(Vector3.UP, deg_to_rad(-1.6)), base.origin), 0.05)
			tw.tween_property(bd, "transform", base, 0.12)
	night_bangs += 1


var night_bangs := 0


func _spawn_hound() -> void:
	var ps := load(HOUND_PATH) as PackedScene
	if ps == null:
		return
	hound = ps.instantiate() as Node3D
	hound.name = "P4_Hound_Silhouette"
	market.add_child(hound)
	if hound is CollisionObject3D:
		(hound as CollisionObject3D).collision_layer = 0
		(hound as CollisionObject3D).collision_mask = 0
	hound.set_physics_process(false)
	hound.scale = Vector3.ONE * 1.35                     # bigger than a dog: the survivors only see a shape
	for g in hound.find_children("*", "GeometryInstance3D", true, false):
		var m := StandardMaterial3D.new()                 # unlit near-black: a silhouette behind the glass
		m.albedo_color = Color(0.02, 0.02, 0.025)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(g as GeometryInstance3D).material_override = m
	hound.position = Vector3(-16.0, 0.0, -2.6)            # outside the storefront, in the mist
	hound.rotation.y = PI * 0.5                           # the model faces +Z: turn it to face +x, the way it walks
	var ap := hound.get_node_or_null(String(hound.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
	# gait speed matched to the tween so the feet don't slide (Run is authored at run_speed_mps, scaled with the model)
	var along := 18.0 / 6.0
	var gait := "Run" if ap and ap.has_animation("Run") else "Walk"
	var authored := float(hound.get_meta("run_speed_mps" if gait == "Run" else "walk_speed_mps", 1.0)) * hound.scale.x
	if ap and ap.has_animation(gait):
		ap.play(gait)
		ap.speed_scale = along / maxf(authored, 0.1)
	var tw := hound.create_tween()
	tw.tween_property(hound, "position:x", 2.0, 6.0)
	tw.tween_property(hound, "rotation:y", PI, 0.45).set_trans(Tween.TRANS_SINE)   # turn away from the glass first...
	tw.tween_property(hound, "position:z", -5.5, 1.2)                              # ...then lope off into the mist


var strike_report := {}


## The hound (out of view behind the building) rears and lunges at the rear exit. Its head is placed so that at the
## Attack_Bite contact frame (head furthest forward, measured from the rig) it meets the leaf's outer face - no
## swing at empty air, no clipping through. Everything inside reacts on that exact frame.
func _door_strike() -> void:
	var bd: Node3D = its["back_door"]
	var ps := load(HOUND_PATH) as PackedScene
	var h: Node3D = ps.instantiate() as Node3D if ps else null
	var t_hit := 0.55
	if h:
		h.name = "P4_Hound_Door"
		market.add_child(h)
		if h is CollisionObject3D:
			(h as CollisionObject3D).collision_layer = 0
			(h as CollisionObject3D).collision_mask = 0
		h.set_physics_process(false)
		h.scale = Vector3.ONE * 1.35
		h.rotation.y = PI                               # the model faces +Z: face -Z, into the door
		var ap := h.get_node_or_null(String(h.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
		var sk := h.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D if not h.find_children("*", "Skeleton3D", true, false).is_empty() else null
		if ap and sk and ap.has_animation("Attack_Bite"):
			var head := sk.find_bone("Head")
			var anim := ap.get_animation("Attack_Bite")
			ap.play("Attack_Bite", 0.0)
			# contact frame: the head's furthest reach toward the door (local -Z of the market = toward the inside)
			h.position = Vector3(8.0, 0.0, BACKDOOR_OUTSIDE_Z + 3.0)
			var best := INF
			var tt := 0.0
			while tt < anim.length:
				ap.seek(tt, true)
				var hz: float = market.to_local(sk.global_transform * sk.get_bone_global_pose(head).origin).z
				if hz < best:
					best = hz
					t_hit = tt
				tt += 1.0 / 60.0
			# head reach + snout (~0.25 m past the head bone at this scale) ends on the leaf's outer face
			h.position.z += (BACKDOOR_OUTSIDE_Z + 0.25) - best
			ap.seek(0.0, true)
			strike_report["contact_t"] = t_hit
			strike_report["sk"] = sk
			_play("scrape", ml(Vector3(8.0, 1.0, BACKDOOR_OUTSIDE_Z + 1.0)), 0.0)   # it comes up to the door
			ap.play("Attack_Bite", 0.1)
	await get_tree().create_timer(t_hit).timeout
	# contact: measured, not assumed (snout ~0.25 m past the head bone)
	var skc = strike_report.get("sk")
	if skc and is_instance_valid(skc):
		var hz: float = market.to_local(skc.global_transform * skc.get_bone_global_pose(skc.find_bone("Head")).origin).z
		strike_report["snout_to_door_m"] = (hz - 0.25) - BACKDOOR_OUTSIDE_Z
	strike_report.erase("sk")
	strike_report["impact_synced"] = true
	_play("impact", ml(BACKDOOR_HANDLE), 6.0)
	_flicker_burst(1.0)
	var base: Transform3D = _base["back"]
	var tw := create_tween()
	for i in 4:                                         # jolt inward against the pallets, damped rebound
		var ang: float = [-2.2, 1.2, -0.6, 0.25][i]
		tw.tween_property(bd, "transform", Transform3D(base.basis * Basis(Vector3.UP, deg_to_rad(ang)), base.origin), float([0.05, 0.08, 0.09, 0.1][i]))
	tw.tween_property(bd, "transform", base, 0.12)
	var pal: Node3D = _pallets.get("back")
	if pal:
		var pp: Vector3 = pal.position
		var tp := create_tween()
		tp.tween_property(pal, "position", pp + Vector3(0, 0, -0.025), 0.05)
		tp.tween_property(pal, "position", pp, 0.25).set_trans(Tween.TRANS_SINE)
	await tw.finished
	# recovery: it backs off and is gone into the mist
	if h and is_instance_valid(h):
		var ap2 := h.get_node_or_null(String(h.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
		if ap2 and ap2.has_animation("Alert"):
			ap2.play("Alert", 0.2)
		var tb := h.create_tween()
		tb.tween_property(h, "position:z", h.position.z + 2.5, 1.2).set_trans(Tween.TRANS_SINE)
		tb.tween_callback(h.queue_free)


func _flicker_burst(seconds: float) -> void:
	var on_lights := _lights.filter(func(l): return (l as Light3D).visible)
	var t := 0.0
	var rng := RandomNumberGenerator.new()
	while t < seconds:
		for l in on_lights:
			(l as Light3D).visible = rng.randf() > 0.55
		var dt := rng.randf_range(0.04, 0.14)
		await get_tree().create_timer(dt).timeout
		t += dt
	for l in on_lights:
		(l as Light3D).visible = true


var _supplies_open := false

func _open_supplies() -> void:
	if _supplies_open or choice.is_open():
		return
	_supplies_open = true
	while is_inside_tree():
		var stock := Game.shelter_stock()
		# communal stores only: food, water, medicine (batteries stay the player's own - the flashlight's spares)
		var text := "SHELTER SUPPLIES"
		if world.expedition and world.expedition.shelter() != "":
			var need: Dictionary = world.expedition.supply_need()
			text += "\nFood: %d / %d    Water: %d / %d   (tonight)\nMedical: %d" % [need["food"], need["need"], need["water"], need["need"], int(stock.medical)]
			if int(need["food"]) < int(need["need"]):
				text += "\nShort of food for tonight"
			if int(need["water"]) < int(need["need"]):
				text += "\nShort of water for tonight"
		else:
			text += "\nFood: %d    Water: %d    Medical: %d" % [int(stock.food), int(stock.water), int(stock.medical)]
			var roster: Array = world.shelter_roster()
			var rates: Dictionary = cfg.get("shelter_consumption", {})
			if int(stock.food) < roster.size() * int(rates.get("food", 1)):
				text += "\nLow food"
			if int(stock.water) < roster.size() * int(rates.get("water", 1)):
				text += "\nLow water"
		var last: Dictionary = Game.world_state.get("shelter_latest_report", {})
		if not last.is_empty():
			text += "\n\n" + _supply_report(last)
		var acts: Array = []
		var options: Array = []
		var fw := Game.inventory.filter(func(i): return Game.shelter_resource(i) in ["food", "water"])
		if not fw.is_empty():
			acts.append(["all", ""])
			options.append("Deposit All Food and Water (%d)" % fw.size())
		var seen: Array = []
		for id in Game.inventory:
			if Game.shelter_resource(id) in ["food", "water", "medical"] and not (id in seen):
				seen.append(id)
				acts.append(["put", id])
				options.append("Deposit one %s (%d carried)" % [Game.item_info(id).name, Game.inventory.count(id)])
		for r in ["food", "water", "medical"]:
			if int(stock.get(r, 0)) > 0:
				acts.append(["take", r])
				options.append("Take one %s from the stores (%d stored)" % [Game.item_info(SUPPLY_ITEM[r]).name, int(stock[r])])
		if int(stock.get("batteries", 0)) > 0:          # stored by older saves: handed back, never lost
			acts.append(["take", "batteries"])
			options.append("Take back the stored batteries (%d)" % int(stock.batteries))
		if world.survivors:
			acts.append(["group", ""])
			options.append("Check on the Group")
		acts.append(["close", ""])
		options.append("Close")
		var selected: int = await choice.ask(text, options, player)
		var act: Array = acts[clampi(selected, 0, acts.size() - 1)] if selected >= 0 else ["close", ""]
		match String(act[0]):
			"group":
				_supplies_open = false
				await world.survivors.open_panel(choice)
				return
			"close":
				break
			"all":
				var got := {"food": 0, "water": 0}
				for i in Game.inventory.duplicate():
					var r := Game.shelter_resource(i)
					if r in ["food", "water"] and world.deposit_shelter_item(i):
						got[r] += 1
				hud.set_hint("Deposited %d Food and %d Water." % [got["food"], got["water"]])
				get_tree().create_timer(3.0).timeout.connect(func(): hud.set_hint(""))
			"put":
				world.deposit_shelter_item(String(act[1]))
			"take":
				_withdraw(String(act[1]))
	_supplies_open = false

## One unit of a communal resource back into the player's inventory (food -> canned food, water -> a bottle,
## medical -> painkillers; legacy batteries -> one flashlight spare). Counts move, nothing is created.
const SUPPLY_ITEM := {"food": "canned_food", "water": "water_bottle", "medical": "painkillers", "batteries": "batteries"}


func _withdraw(r: String) -> void:
	var stock := Game.shelter_stock()
	if int(stock.get(r, 0)) <= 0:
		return
	if r == "batteries":
		var fl := get_tree().get_first_node_in_group("veil_flashlight") as VeilFlashlight
		if fl == null:
			return
		fl.add_spares(1)
		Game.add_item("batteries")
		Game.inventory_changed.emit()
	else:
		Game.add_item(String(SUPPLY_ITEM[r]))
	stock[r] = int(stock[r]) - 1
	Game.world_state["shelter_stock"] = stock
	world.save()


func record_night(transition: String) -> Dictionary:
	var extra := 0
	# survival rule (expedition): from the first scavenging day on, the protagonist eats and drinks too
	if world.expedition and String(world.expedition.cfg.get("sleep_requires_supplies_from_flag", "")) != "" \
			and Game.has_flag(String(world.expedition.cfg.get("sleep_requires_supplies_from_flag", ""))):
		extra = 1
	return Game.record_shelter_night(transition, world.shelter_roster(), cfg.get("shelter_consumption", {}), extra)

func _supply_report(report: Dictionary) -> String:
	var text := "OVERNIGHT SUPPLY REPORT\nFood used: %d  |  Water used: %d\nFood remaining: %d  |  Water remaining: %d" % [
		report.food_used, report.water_used, report.food_left, report.water_left]
	if report.food_used < report.food_needed or report.water_used < report.water_needed:
		text += "\nSupplies ran short overnight"
	return text

func show_night_report(report: Dictionary) -> void:
	if not report.is_empty():
		hud.location_caption(_supply_report(report), 5.0)


# ------------------------------------------------------------------ sleep -> Saturday
func _on_slept(_id: String) -> void:
	world._clear_beacon("p4_rest")
	Game.world_state["day"] = "saturday"
	var report := record_night("p4_slept")
	Game.set_flag("p4_slept")
	if flashlight:
		flashlight.set_on(false)
	await get_tree().create_timer(1.0).timeout
	if Game.has_flag("p4_choice_wait") and not Game.has_flag("p4_night_banging"):
		Game.set_flag("p4_night_banging")
		await _night_banging()                        # in the dark: something at the back door, all night
		await get_tree().create_timer(1.0).timeout
	await hud.title_card("SATURDAY", 2.8)
	_start_chapter5(false)                         # still black: the morning positions are set before the fade
	await hud.fade_to(0.0, 2.0)
	player.set("controls_enabled", true)
	show_night_report(report)
	Dialogue.say("p4_wake", false, true)


## Chapter 5 (game/world/chapter5.gd) continues from the first night; it is a child of this node.
var chapter5: Node
func _start_chapter5(restoring: bool) -> void:
	if chapter5 != null:
		return
	chapter5 = load("res://game/world/chapter5.gd").new()
	chapter5.name = "Chapter5"
	add_child(chapter5)
	chapter5.begin(world, self, restoring)


# ------------------------------------------------------------------ sounds (synthesised, original)
func _make_sounds() -> void:
	_streams["scrape"] = Sfx._make(2.6, _scrape_wave)
	_streams["drag"] = Sfx._make(0.65, _drag_wave)
	_streams["thud"] = Sfx._make(0.45, _thud_wave)
	_streams["impact"] = Sfx._make(1.2, _impact_wave)
	_streams["rattle"] = Sfx._make(1.4, _rattle_wave)
	_streams["scuttle"] = Sfx._make(1.2, _scuttle_wave, true)
	_streams["sting"] = load("res://game/audio/the_veil_jumpscare_sting.wav")    # the lower horror sting (was a synthesized high one)
	_streams["chase"] = Sfx._make(3.0, _chase_wave, true)
	_streams["slither"] = Sfx._make(3.0, _slither_wave)


## a sharp dissonant stab: a low hit and a cluster of detuned tones, fast decay
func _sting_wave(t: float, i: int) -> float:
	var cl := 0.0
	for f in [233.0, 247.0, 349.0, 370.0, 523.0]:
		cl += sin(TAU * f * t)
	return (cl * 0.09 + sin(TAU * 55.0 * t) * 0.6 + Sfx._noise(i) * 0.25 * exp(-t * 20.0)) * exp(-t * 2.4) * minf(t * 200.0, 1.0)


## frantic chase loop (160 bpm): pounding low drum on every beat, noise hits on the off-beats, a dissonant pulse
func _chase_wave(t: float, i: int) -> float:
	var beat := 60.0 / 160.0
	var ph := fposmod(t, beat) / beat
	var off := fposmod(t + beat * 0.5, beat) / beat
	var kick := sin(TAU * (48.0 + 60.0 * exp(-ph * 18.0)) * ph * beat) * exp(-ph * 7.0) * 0.8
	var hit := Sfx._noise(i) * exp(-off * 22.0) * 0.28
	var pulse := (sin(TAU * 110.0 * t) + sin(TAU * 116.5 * t)) * 0.07 * (0.5 + 0.5 * sin(TAU * t / beat * 0.25))
	return kick + hit + pulse


## wet dragging: noisy, slow swells, low and moist
func _slither_wave(t: float, i: int) -> float:
	var env := sin(PI * clampf(t / 3.0, 0.0, 1.0))
	return Sfx._noise(i) * 0.4 * env * (0.45 + 0.55 * absf(sin(t * 5.3 + sin(t * 1.7) * 2.0))) + sin(TAU * 62.0 * t) * 0.08 * env


## A wooden pallet stack dragged over concrete: low, grainy friction (coarse noise, no tone) that catches and slips,
## under a dull body rumble. One shove's worth (0.65 s).
func _drag_wave(t: float, i: int) -> float:
	var env := sin(PI * clampf(t / 0.65, 0.0, 1.0))
	var grain := Sfx._noise(i / 7) * 0.55 + Sfx._noise(i / 3) * 0.25          # coarse noise: low, woody
	var catch := pow(absf(sin(TAU * 11.0 * t + sin(t * 23.0) * 1.5)), 3.0)   # stick-slip judder
	return (grain * (0.35 + 0.65 * catch) + sin(TAU * 52.0 * t) * 0.18 * catch) * env


## The stack lands against the door: one short solid thud.
func _thud_wave(t: float, i: int) -> float:
	return (sin(TAU * 62.0 * t) * 0.9 + Sfx._noise(i / 4) * 0.5) * exp(-t * 14.0)


func _scrape_wave(t: float, i: int) -> float:
	var env := sin(PI * clampf(t / 2.6, 0.0, 1.0))
	return Sfx._noise(i) * 0.45 * env * (0.6 + 0.4 * sin(t * 37.0)) + sin(TAU * 140.0 * t + sin(t * 9.0) * 3.0) * 0.08 * env


func _impact_wave(t: float, i: int) -> float:
	return (sin(TAU * 48.0 * t) * 0.9 + Sfx._noise(i) * 0.6) * exp(-t * 6.0) + Sfx._noise(i) * 0.15 * exp(-t * 2.0)


## many hard little feet on asphalt: dense irregular clicks (loops while it runs)
func _scuttle_wave(t: float, i: int) -> float:
	var ph := fposmod(t * 23.0 + sin(t * 7.0) * 0.6, 1.0)
	var ph2 := fposmod(t * 31.0 + 0.37, 1.0)
	return Sfx._noise(i) * (exp(-ph * 40.0) * 0.6 + exp(-ph2 * 55.0) * 0.4) + sin(TAU * 900.0 * t) * exp(-ph * 60.0) * 0.15


func _rattle_wave(t: float, i: int) -> float:
	return Sfx._noise(i) * 0.35 * (0.5 + 0.5 * sin(t * 60.0)) * (1.0 - t / 1.4)


func _play(id: String, at: Vector3, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = db
	if id == "scrape":
		p.pitch_scale = 0.55                          # a heavy object dragged, not a squeal
	elif id == "sting":
		p.volume_db = db - 8.0                         # the sample is much louder than the old synthesized sting
	p.unit_size = 8.0
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
