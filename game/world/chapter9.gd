extends Node
class_name VeilChapter9
## THE VEIL - displayed CHAPTER 10 "The Fall of the Supermarket" (Act III; internal ids keep the file's own
## numbering: chapter9.gd, flags ch9_*, chapter_9_complete). Starts when the player sleeps after the previous
## chapter (flag ch8_rested); created by chapter8.gd. State: story flags + Game.world_state["ch9"]; loads rebuild
## the chapter from them without replaying finished events or consuming anything twice.
##
## Marcus's decision talk (Eddie, Ruth join in) -> prepare: medical supplies (the shelter's first-aid stock), food
## and water (from the communal stock: real units, nothing that is not there), the flashlight check (switch it on),
## a word with Eddie, Ruth and Sarah -> the warning (distant impacts, scraping at the back, flicker, a shape in the
## fog beyond the storefront; first person) -> the fall: the doorway barricade gives, a Hound forces its way in,
## another prowls at the front doors -> ESCAPE: the group follows the player (Chapter 5-8 follower) east through
## the store, the staff door, the back corridor and out of the rear exit -> Marcus's moment: a Hound pins him in
## the corridor; how long he can hold on depends on his trust in the protagonist (Chapter 4 "we can't leave Noah",
## Chapter 7 "we'll find him"): 4 / 8 / 12 s for the player to pull him free (Outcome A) or he is dragged away in
## a cut to black (Outcome B; never random) -> outside: a look back at the store, the roll call (reflects who made
## it) -> the temporary rendezvous (Ruth and Sarah's old front yard, Chapter 7's house) -> "CHAPTER 10 COMPLETE".
## The supermarket is lost as a shelter afterwards. The next chapter is not started. Noah is not found here.

const FOLLOW := preload("res://game/npc/companion_follow.gd")
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const FIRST_AID := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Medical/INV_FirstAidKit.glb")
const BOX_STACK := preload("res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_CardboardBox_Stack.glb")
const GONDOLA := preload("res://THE_VEIL_ASSETS_V2/04_Commercial/Shared_Props/COM_Gondola_Shelf.glb")
const PAPERS := preload("res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Abandoned_Props/ABN_ScatteredPapers.glb")
const BAGS := preload("res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Abandoned_Props/ABN_GroceryBags_Spilled.glb")
const STATE := "ch9"
const CHAPTER := 10                                    # displayed number (game/data/chapters.json)

# ---- supermarket-local (collision-mapped; see chapter8.gd for the layout)
const MARCUS_SPOT := Vector3(4.6, 0.04, 7.5)
const EDDIE_SPOT := Vector3(5.0, 0.04, 6.3)
const RUTH_SPOT := Vector3(2.9, 0.04, 7.45)
const FRONT_BOX := Vector3(2.4, 0.04, 6.4)             # Sarah's seat from the previous chapter
const GROUP_CENTRE := Vector3(3.8, 0.04, 6.8)
const KIT_POS := Vector3(6.6, 1.1, 5.0)                # first-aid stock on the service counter (collider top 1.05)
const PACK_POS := Vector3(13.2, 0.04, 4.4)             # the communal food and water, boxed for the road (by the front wall)
const TIPPED_SHELF := Vector3(-0.9, 0.04, 6.6)         # an overturned gondola between the group and the front doors
const STAFF_DOOR := Vector3(15.5, 1.0, 14.2)
const REAR_EXIT := Vector3(8.0, 1.0, 17.45)
const OUTSIDE := Vector3(8.0, 0.04, 19.6)               # beyond the rear exit (open lot behind the store)
const BACK_PALLET_SHOVED := Vector3(5.6, 0.04, 15.5)    # the old barricade pallets, clear of the corridor
const DOORWAY := Vector3(8.4, 0.04, 14.2)
const BREACH_PALLET := Vector3(7.1, 0.04, 12.6)         # the doorway stack after it is forced
const HOUND_IN := Vector3(8.4, 0.0, 15.4)
const PROWL := [Vector3(4.0, 0.0, 12.9), Vector3(-2.0, 0.0, 12.9), Vector3(1.0, 0.0, 12.9)]
const MARCUS_PIN := Vector3(10.6, 0.04, 15.7)
const PIN_TRIGGER_X := 10.0                             # the player near the rear exit, in the corridor
const OUT_WAIT := [Vector3(7.2, 0.04, 20.6), Vector3(8.8, 0.04, 21.2), Vector3(7.8, 0.04, 22.2)]
const ESCAPED_Z := 18.5
const LIGHTS_DEAD := ["Light_SALES_30", "Light_BACK_10"]  # more of them gone overnight
# ---- world: the temporary rendezvous (Ruth and Sarah's front yard, house HOUSE_06, Chapter 7 house-local)
const RV_LOCAL := Vector3(2.6, 0.05, -1.6)              # yard ground level (the house floor is at 0.6)
const RV_SPOTS := {"Eddie": Vector3(1.4, 0.05, -2.4), "Ruth": Vector3(3.6, 0.05, -2.6), "Sarah": Vector3(4.4, 0.05, -1.7),
	"Marcus": Vector3(2.4, 0.05, -3.2)}

var world: Node
var c8: Node
var c7: Node
var c6: Node
var c5: Node
var p4: Node
var market: Node3D
var player: Node3D
var hud: Node
var eddie: Node3D
var marcus: Node3D
var ruth: Node3D
var sarah: Node3D
var its := {}
var follows := {}
var hounds: Array = []
var hound_in: Node3D                  ## the one that breaks in (and pins Marcus)
var report := {"pin_runs": 0, "lost_runs": 0, "warning_runs": 0, "fall_runs": 0}
var _busy := {}
var _tick := 0.0
var _rv_area: Area3D
var _pin_left := -1.0
var _props: Array = []
var _kit: Node3D
var front_hound: Node3D               ## the shape pacing beyond the front glass (outside)
var _flash_on_at_step := false


func begin(w: Node, chapter8: Node, restoring: bool) -> void:
	world = w
	c8 = chapter8
	c7 = c8.c7
	c6 = c8.c6
	c5 = c8.c5
	p4 = c8.p4
	market = w.market
	player = w.player
	hud = w.hud
	eddie = w.eddie
	marcus = w.marcus
	ruth = c8.ruth
	sarah = c8.sarah
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"talked": {}, "medical_taken": 0, "food_taken": 0, "water_taken": 0}
	_setup_npcs()
	_setup_supplies()
	_setup_debris()
	_setup_rest()
	_rv_area = world._area("C9_Rendezvous", c6.hl(RV_LOCAL + Vector3(0, 1.4, 0)), Vector3(8.0, 3.4, 6.0), 2, func(_b): pass,
		c6.rs_house.global_transform.basis)
	if p4.flashlight and not p4.flashlight.changed.is_connected(_on_flashlight):
		p4.flashlight.changed.connect(_on_flashlight)
	var fresh := not Game.has_flag("ch9_started")
	if fresh:
		Game.set_flag("ch9_started")
		st()["marcus_trust"] = marcus_trust()
	_apply()
	if Game.has_flag("chapter_9_complete"):
		_start_chapter10(true)
	Game.refresh_objective()
	if fresh:
		_title.call_deferred()
	# interrupted cinematics: the warning plays again from its start; the fall resumes at the escape
	if Game.has_flag("ch9_warning_started") and not Game.has_flag("ch9_fall_started"):
		_run_warning.call_deferred()


func _title() -> void:
	await get_tree().create_timer(2.6).timeout       # after the wake-up fade
	await hud.chapter_start(CHAPTER)


func st() -> Dictionary:
	return Game.world_state[STATE]


func ml(p: Vector3) -> Vector3:
	return market.global_transform * p


## Marcus's trust in the protagonist, from the established decisions (narrative bible: "his trust depends on actions
## and dialogue"; "Marcus may die during the supermarket evacuation"): standing with him over Noah on the first night
## (p4_choice_noah) and promising to find Noah on the service road (marcus_trust_search).
func marcus_trust() -> int:
	var t := 0
	if Game.has_flag("p4_choice_noah"):
		t += 1
	if Game.has_flag("marcus_trust_search"):
		t += 1
	return t


## Seconds Marcus can hold on when he is pinned: the player always gets a real chance, longer when he trusts them.
## The breakthrough rescue: a ten-second countdown (survival expansion). Marcus's trust (the established choices)
## is still recorded in st().marcus_trust for later chapters.
const PIN_SECONDS := 10.0
func pin_window() -> float:
	return PIN_SECONDS


# ------------------------------------------------------------------ setup
func _setup_npcs() -> void:
	for pair in [["npc_Marcus", _talk_marcus], ["npc_Eddie", _talk_eddie]]:
		var it: Interactable = p4.its.get(pair[0])
		if it:
			it.used.connect(pair[1])
			its[pair[0]] = it
	for pair in [[ruth, "Ruth", _talk_ruth], [sarah, "Sarah", _talk_sarah]]:
		var it := Interactable.attach(pair[0], {"kind": "custom", "label": pair[1], "prompt_text": ""})
		it.name = "C9_Interact"
		it.used.connect(pair[2])
		its["npc_" + pair[1]] = it
	# Marcus's moment: the same body takes the "pull him free" interaction while he is pinned
	var mi := Interactable.attach(marcus, {"kind": "custom", "label": "Marcus", "prompt_text": ""})
	mi.name = "C9_Pinned"
	mi.used.connect(_free_marcus)
	mi.collision_layer = 0
	its["pinned"] = mi
	for pair in [[eddie, "Eddie", 1.4], [ruth, "Ruth", 2.2], [sarah, "Sarah", 3.0], [marcus, "Marcus", 4.0]]:
		var f: VeilCompanionFollow = FOLLOW.new()
		f.name = "C9_Follow"
		f.gap = pair[2]
		f.walk_speed = 2.0
		f.run_speed = 4.6
		pair[0].add_child(f)
		f.setup(pair[0], player)
		follows[pair[1]] = f


func _setup_supplies() -> void:
	var kit := FIRST_AID.instantiate() as Node3D
	_kit = kit
	kit.name = "C9_FirstAid"
	market.add_child(kit)
	kit.position = KIT_POS
	kit.rotation.y = 0.3
	var it := Interactable.attach(kit, {"kind": "custom", "label": "First Aid", "prompt_text": ""})
	_grow(it)
	it.used.connect(_take_medical)
	its["medical"] = it
	var pack := BOX_STACK.instantiate() as Node3D
	pack.name = "C9_FoodWater"
	market.add_child(pack)
	pack.position = PACK_POS
	pack.rotation.y = 0.2
	var it2 := Interactable.attach(pack, {"kind": "custom", "label": "Food and Water", "prompt_text": ""})
	_grow(it2)
	it2.used.connect(_take_food_water)
	its["food"] = it2
	_settle.call_deferred([kit])


func _grow(it: Interactable) -> void:
	var c := it.get_child(0) as CollisionShape3D
	var bs := c.shape as BoxShape3D
	bs.size = bs.size.max(Vector3(0.6, 0.5, 0.6))


func _settle(nodes: Array) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for n in nodes:
		var node := n as Node3D
		var ex: Array[RID] = [player.get_rid()]
		for co in node.find_children("*", "CollisionObject3D", true, false):
			ex.append((co as CollisionObject3D).get_rid())
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(node.global_position + Vector3.UP * 0.4,
			node.global_position - Vector3.UP * 1.6, 1, ex))
		if hit:
			node.global_position.y = (hit["position"] as Vector3).y + 0.002


## The store after the night: an overturned gondola lying between the group and the front doors, papers
## and spilled bags. Existing props only; the gondola keeps its own collision (tipped on its side).
func _setup_debris() -> void:
	var g := GONDOLA.instantiate() as Node3D
	g.name = "C9_TippedShelf"
	market.add_child(g)
	g.position = Vector3.ZERO
	g.rotation = Vector3(-PI * 0.5, 0.12, 0.0)          # on its back, across the way to the front doors
	var bb: AABB = g.transform * Interactable.aabb_of(g)
	g.position = TIPPED_SHELF - Vector3(bb.get_center().x, bb.position.y - TIPPED_SHELF.y, bb.get_center().z)
	_props.append(g)
	for spec in [[PAPERS, Vector3(9.6, 0.04, 6.4), 0.4], [BAGS, Vector3(1.6, 0.04, 12.9), 1.1], [PAPERS, Vector3(-6.0, 0.04, 7.0), 2.0]]:
		var n := (spec[0] as PackedScene).instantiate() as Node3D
		market.add_child(n)
		n.position = spec[1]
		n.rotation.y = spec[2]
		# floor clutter only (papers, spilled bags and cans): walked over, never a wall in the aisle
		for co in n.find_children("*", "CollisionObject3D", true, false):
			(co as CollisionObject3D).collision_layer = 0
			(co as CollisionObject3D).collision_mask = 0
		_props.append(n)


func _setup_rest() -> void:
	var r: VeilRestPoint = p4.rest
	if r == null:
		return
	if r.slept.is_connected(c8._on_rest):
		r.slept.disconnect(c8._on_rest)
	r.can_rest = func() -> bool: return false     # no more nights here
	r.get_parent().visible = false


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	var gone := Game.has_flag("ch9_marcus_lost")
	marcus.visible = not gone
	if Game.has_flag("ch9_escaped"):
		_apply_outside()
	elif Game.has_flag("ch9_fall_started"):
		_apply_fall()
	else:
		_apply_inside()
	_apply_lights()
	_refresh_prompts()
	_guide()


func _show(n: Node3D, at: Vector3, toward: Vector3) -> void:
	c5._reparent(n, market)
	n.visible = true
	var a = world.animators.get(String(n.name))
	if a:
		a.set_seated(false)
		a.turn_to_face = true
		a.set_mood("scared")
	world.place_survivor(n, at)
	if a:
		a.face_towards(ml(toward))


func _apply_inside() -> void:
	for f in follows.values():
		(f as VeilCompanionFollow).stop()
	_show(marcus, MARCUS_SPOT, GROUP_CENTRE)
	_show(eddie, EDDIE_SPOT, GROUP_CENTRE)
	_show(ruth, RUTH_SPOT, GROUP_CENTRE)
	# Sarah: on her crate as the previous chapter left her (hurt either way); she stands once the group moves
	c8._seat_on(sarah, c8._front_box, FRONT_BOX, GROUP_CENTRE + Vector3(1.0, 0, 0))
	_set_rear(false)


## Mid-escape (a load): the breach as it happened, the Hound inside, the group with the player.
func _apply_fall() -> void:
	_breach_state()
	if hound_in == null or not is_instance_valid(hound_in):
		hound_in = _make_hound(PROWL[0])
		_prowl.call_deferred()
	_front_threat()
	_set_rear(true)
	for k in follows:
		if k == "Marcus" and Game.has_flag("ch9_marcus_lost"):
			continue
		_start_follow(k)


func _apply_outside() -> void:
	_breach_state()
	_set_rear(false)
	for h in hounds:
		if is_instance_valid(h):
			h.queue_free()
	hounds.clear()
	if Game.has_flag("ch9_rendezvous_reached"):
		for k in follows:
			(follows[k] as VeilCompanionFollow).stop()
		_place_rendezvous()
	else:
		for k in follows:
			if k == "Marcus" and Game.has_flag("ch9_marcus_lost"):
				continue
			_start_follow(k)
	# the supermarket is no longer a shelter: its rest point, supplies and doors are closed for good
	if Game.has_flag("ch9_supermarket_lost"):
		_close_store()


func _start_follow(k: String) -> void:
	var n: Node3D = {"Eddie": eddie, "Ruth": ruth, "Sarah": sarah, "Marcus": marcus}[k]
	var a = world.animators.get(k)
	if a:
		a.set_seated(false)
		a.turn_to_face = true
		a.set_mood("scared")
	n.visible = true
	var f: VeilCompanionFollow = follows[k]
	if f.active:
		return
	c5._reparent(n, world)
	f.recover_behind(f.gap)
	f.start()


func _place_rendezvous() -> void:
	for k in RV_SPOTS:
		if k == "Marcus" and Game.has_flag("ch9_marcus_lost"):
			continue
		var n: Node3D = {"Eddie": eddie, "Ruth": ruth, "Sarah": sarah, "Marcus": marcus}[k]
		c5._reparent(n, world)
		n.visible = true
		var a = world.animators.get(k)
		if a:
			a.set_seated(false)
			a.turn_to_face = true
		world.place_survivor(n, c6.hl(RV_SPOTS[k]))
		if a:
			a.face_towards(c6.hl(RV_LOCAL))


func _set_rear(open: bool) -> void:
	var bd: Node3D = p4.its.get("back_door")
	if bd == null:
		return
	var base: Transform3D = p4._base["back"]
	var d: float = world._toward_deg(bd, 88.0, ml(Vector3(8.0, 1.0, 16.4))) if open else 0.0
	bd.transform = Transform3D(base.basis * Basis(Vector3.UP, deg_to_rad(d)), base.origin)
	var pal: Node3D = p4._pallets.get("back")
	if pal and open:
		pal.position = BACK_PALLET_SHOVED
		pal.rotation.y = 0.9


func _breach_state() -> void:
	var sp: Node3D = c8._secure_pallet
	if sp:
		sp.position = BREACH_PALLET
		sp.rotation.y = 0.75
	if c8._blocker:
		c8._blocker.collision_layer = 0


func _apply_lights() -> void:
	c8._lights("partial")
	for n in LIGHTS_DEAD:
		var l := market.get_node_or_null("Lights/" + n) as Light3D
		if l:
			l.visible = false


func _close_store() -> void:
	if p4.rest:
		p4.rest.get_parent().visible = false
		p4.rest.interactable.prompt_text = ""
	var sup := market.get_node_or_null("ShelterSupplies") as Node3D
	if sup:
		for it in sup.find_children("*", "Interactable", true, false):
			(it as Interactable).collision_layer = 0
	for k in ["medical", "food"]:
		its[k].collision_layer = 0


func _refresh_prompts() -> void:
	var talked: Dictionary = st().get("talked", {})
	var prep := Game.has_flag("ch9_marcus_talked") and not Game.has_flag("ch9_prepared")
	its["npc_Marcus"].prompt_text = "[E] Talk" if not Game.has_flag("ch9_marcus_talked") else ""
	its["npc_Eddie"].prompt_text = "[E] Talk" if prep and not talked.get("Eddie", false) else ""
	for k in ["Ruth", "Sarah"]:
		var on: bool = prep and not talked.get(k, false)
		its["npc_" + k].prompt_text = "[E] Talk" if on else ""
		its["npc_" + k].collision_layer = 8 if on else 0
	var med_on := prep and not Game.has_flag("ch9_medical_done")
	its["medical"].prompt_text = "[E] Take the Medical Supplies" if med_on else ""
	its["medical"].collision_layer = 8 if med_on else 0
	_kit.visible = not Game.has_flag("ch9_medical_done")
	var food_on := prep and not Game.has_flag("ch9_food_done")
	its["food"].prompt_text = "[E] Pack Food and Water" if food_on else ""
	its["food"].collision_layer = 8 if food_on else 0
	for k in ["npc_Marcus", "npc_Eddie"]:
		its[k].collision_layer = 8 if its[k].prompt_text != "" else 0
	var pin: bool = _busy.get("pinned", false)
	its["pinned"].prompt_text = "[E] Pull Marcus Free" if pin else ""
	its["pinned"].collision_layer = 8 if pin else 0


func prep_done() -> Dictionary:
	var talked: Dictionary = st().get("talked", {})
	return {"medical": Game.has_flag("ch9_medical_done"), "food": Game.has_flag("ch9_food_done"),
		"light": Game.has_flag("ch9_light_checked"),
		"talks": talked.get("Eddie", false) and talked.get("Ruth", false) and talked.get("Sarah", false)}


func _guide() -> void:
	var t: Variant = null
	var label := ""
	if not Game.has_flag("ch9_marcus_talked"):
		t = marcus
		label = "MARCUS"
	elif not Game.has_flag("ch9_prepared"):
		var p := prep_done()
		var talked: Dictionary = st().get("talked", {})
		if not p["medical"]:
			t = its["medical"].global_position + Vector3(0, 0.3, 0)
			label = "MEDICAL SUPPLIES"
		elif not p["food"]:
			t = its["food"].global_position + Vector3(0, 0.9, 0)
			label = "FOOD AND WATER"
		elif not p["talks"]:
			for k in ["Eddie", "Ruth", "Sarah"]:
				if not talked.get(k, false):
					t = {"Eddie": eddie, "Ruth": ruth, "Sarah": sarah}[k]
					label = k.to_upper()
					break
		if hud.has_method("set_objective"):
			var parts := []
			for k in [["medical", "medical"], ["food", "food & water"], ["light", "flashlight"], ["talks", "the others"]]:
				parts.append(("[x] " if p[k[0]] else "[ ] ") + k[1])
			var txt := "Gather essential supplies  " + "  ".join(parts)
			if txt != _obj_txt:
				_obj_txt = txt
				hud.set_objective(Game.current_goal(), txt)
	elif Game.has_flag("ch9_fall_started") and not Game.has_flag("ch9_escaped") and not _busy.get("pinned", false):
		var pl: Vector3 = market.to_local(player.global_position)
		if pl.z < 14.0:
			t = ml(STAFF_DOOR + Vector3(0, 0.4, 0))
			label = "STAFF DOOR"
		else:
			t = ml(REAR_EXIT + Vector3(0, 0.4, 0))
			label = "REAR EXIT"
	elif _busy.get("pinned", false):
		t = marcus
		label = "MARCUS"
	elif Game.has_flag("ch9_escaped") and not Game.has_flag("ch9_rendezvous_reached") and Game.has_flag("ch9_lookback_done"):
		t = c6.hl(RV_LOCAL + Vector3(0, 1.4, 0))
		label = "RENDEZVOUS"
	if hud.has_method("set_marker"):
		hud.set_marker(t, label)


var _obj_txt := ""


# ------------------------------------------------------------------ scene 1: the decision
func _talk_marcus(_b: Node) -> void:
	if Game.has_flag("ch9_marcus_talked") or _busy.get("talk", false) or not Game.has_flag("ch9_started"):
		return
	_busy["talk"] = true
	its["npc_Marcus"].prompt_text = ""
	await _talk_group("c9_decision", [marcus, eddie, ruth])
	Game.set_flag("ch9_marcus_talked")
	_busy["talk"] = false
	_refresh_prompts()
	_guide()


func _talk_group(id: String, npcs: Array) -> void:
	var ok: bool = await world.converse([id], npcs)
	# the speaker could not be framed (a doorway): the same lines as subtitles, movement still held until they end
	var held := false
	if not ok:
		held = world.player.controls_enabled
		world.player.controls_enabled = false
		world.player.velocity = Vector3.ZERO
		Dialogue.say(id, false, true)
	await get_tree().process_frame
	while Dialogue.is_busy() or world.conversing:
		await get_tree().process_frame
	if held:
		world.player.controls_enabled = true


# ------------------------------------------------------------------ scene 2: prepare to evacuate
func _injured() -> String:
	return String(c8.st().get("injured_condition", "stable"))


func _talk_eddie(_b: Node) -> void:
	await _prep_talk("Eddie", eddie, "c9_prep_eddie")


func _talk_ruth(_b: Node) -> void:
	await _prep_talk("Ruth", ruth, "c9_prep_ruth_" + ("serious" if _injured() == "serious" else "stable"))


func _talk_sarah(_b: Node) -> void:
	await _prep_talk("Sarah", sarah, "c9_prep_sarah_" + ("serious" if _injured() == "serious" else "stable"))


func _prep_talk(k: String, n: Node3D, id: String) -> void:
	if not Game.has_flag("ch9_marcus_talked") or Game.has_flag("ch9_prepared") or _busy.get("talk", false):
		return
	var talked: Dictionary = st().get("talked", {})
	if talked.get(k, false):
		return
	_busy["talk"] = true
	its["npc_" + k].prompt_text = ""
	await c5._talk(id, n)
	talked[k] = true
	st()["talked"] = talked
	_busy["talk"] = false
	_check_prepared()


## The shelter's medical stock goes into the player's inventory as real items (one painkiller pack per unit).
func _take_medical(_b: Node) -> void:
	if Game.has_flag("ch9_medical_done") or not Game.has_flag("ch9_marcus_talked"):
		return
	var stock := Game.shelter_stock()
	var n := int(stock.get("medical", 0))
	for i in n:
		Game.add_item("painkillers")
	stock["medical"] = 0
	Game.world_state["shelter_stock"] = stock
	st()["medical_taken"] = n
	Game.set_flag("ch9_medical_done")              # set together with the transfer: never taken twice
	if n > 0:
		Sfx.play("pickup", its["medical"].global_position, -6.0, 0.9)
		_hint("Medical supplies packed: %d" % n)
	else:
		_hint("The first-aid box is empty. No medical supplies left.")
		Dialogue.say("c9_supplies_low", false, true)
	_check_prepared()


## Up to two food and two water units from the communal stock, as real items; whatever is not there is not taken.
func _take_food_water(_b: Node) -> void:
	if Game.has_flag("ch9_food_done") or not Game.has_flag("ch9_marcus_talked"):
		return
	var stock := Game.shelter_stock()
	var food := mini(2, int(stock.get("food", 0)))
	var water := mini(2, int(stock.get("water", 0)))
	for i in food:
		Game.add_item("canned_food")
	for i in water:
		Game.add_item("water_bottle")
	stock["food"] = int(stock.get("food", 0)) - food
	stock["water"] = int(stock.get("water", 0)) - water
	Game.world_state["shelter_stock"] = stock
	st()["food_taken"] = food
	st()["water_taken"] = water
	Game.set_flag("ch9_food_done")
	if food + water > 0:
		Sfx.play("pickup", its["food"].global_position + Vector3(0, 0.8, 0), -6.0, 0.9)
		_hint("Packed: %d food, %d water" % [food, water] + ("  (the shelter is nearly out)" if food < 2 or water < 2 else ""))
	else:
		_hint("Nothing left to pack. The shelves are bare.")
		Dialogue.say("c9_supplies_low", false, true)
	_check_prepared()


## Flashlight and batteries: switching the flashlight on during the preparation counts as the check.
func _on_flashlight(_charge: float, spares: int, on: bool) -> void:
	if not on or Game.has_flag("ch9_light_checked") or not Game.has_flag("ch9_marcus_talked"):
		return
	Game.set_flag("ch9_light_checked")
	st()["spare_batteries"] = spares
	_hint("Flashlight works. Spare batteries: %d" % spares)
	_check_prepared()


func _hint(t: String) -> void:
	if hud.has_method("set_hint"):
		hud.set_hint(t)
		get_tree().create_timer(3.5).timeout.connect(func():
			if is_instance_valid(hud) and hud.hint.text == t:
				hud.set_hint(""))


func _check_prepared() -> void:
	if p4.flashlight == null and not Game.has_flag("ch9_light_checked"):
		Game.set_flag("ch9_light_checked")             # no flashlight carried: nothing to check
		_hint("No flashlight to check.")
	_refresh_prompts()
	var p := prep_done()
	if not Game.has_flag("ch9_light_checked") and p["medical"] and p["food"] and p["talks"] and hud.has_method("set_hint"):
		hud.set_hint("F - check the flashlight")
	if p["medical"] and p["food"] and p["light"] and p["talks"] and not Game.has_flag("ch9_prepared"):
		Game.set_flag("ch9_prepared")
		_obj_txt = ""
		_guide()
		_warning_later()
	else:
		_guide()


func _warning_later() -> void:
	await get_tree().create_timer(3.0).timeout
	while Dialogue.is_busy() or world.conversing:
		await get_tree().process_frame
	_run_warning()


# ------------------------------------------------------------------ scene 3: the warning
func _run_warning() -> void:
	if _busy.get("warning", false) or Game.has_flag("ch9_fall_started"):
		return
	_busy["warning"] = true
	report["warning_runs"] += 1
	Game.set_flag("ch9_warning_started")
	world.end_conversation()
	hud.set_marker(null, "")
	_hold(true)
	for n in [eddie, marcus, ruth, sarah]:
		var a = world.animators.get(String(n.name))
		if a:
			a.set_mood("scared")
	# distant impacts, then scraping at the back
	for k in 3:
		p4._play("impact", ml(Vector3(-14.0 + k * 9.0, 2.0, -9.0)), -10.0 + k * 2.0)
		await get_tree().create_timer(0.9 + k * 0.4).timeout
	p4._play("scrape", ml(Vector3(8.4, 1.0, 15.0)), 2.0)
	await p4._flicker_burst(1.2)
	# a shape in the fog beyond the storefront
	p4._spawn_hound()
	if p4.hound and is_instance_valid(p4.hound):
		front_hound = p4.hound
		hounds.append(p4.hound)
	await c8._turn_to(ml(Vector3(-4.0, 1.6, -1.5)), 0.8)
	Dialogue.say("c9_warning", false, true)
	for n in [eddie, marcus, ruth, sarah]:
		var a = world.animators.get(String(n.name))
		if a:
			a.face_towards(ml(Vector3(-4.0, 1.4, 0.0)))
	while Dialogue.is_busy():
		await get_tree().process_frame
	# a violent impact against the doorway barricade
	await c8._turn_to(ml(Vector3(DOORWAY.x, 1.3, 13.4)), 0.5)
	await c8._impact(1.2)
	_busy["warning"] = false
	await _run_fall()


# ------------------------------------------------------------------ scene 4: the fall
func _run_fall() -> void:
	if Game.has_flag("ch9_fall_started"):
		return
	report["fall_runs"] += 1
	await get_tree().create_timer(0.8).timeout
	# the barricade gives: the stack is forced into the aisle, a Hound comes through and heads away along the coolers
	var sp: Node3D = c8._secure_pallet
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sp, "position", BREACH_PALLET, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "rotation:y", 0.75, 0.35)
	p4._play("impact", ml(DOORWAY + Vector3(0, 1.0, 0)), 6.0)
	p4._play("scrape", ml(DOORWAY + Vector3(0, 0.4, -0.6)), 4.0)
	c8._dust(ml(DOORWAY + Vector3(0, 2.4, 0)), 30)
	await tw.finished
	if c8._blocker:
		c8._blocker.collision_layer = 0
	hound_in = _make_hound(HOUND_IN)
	c8._hplay(hound_in, "Run", 6.0)
	c8._bark(hound_in.global_position + Vector3(0, 1.0, 0))
	await c8._hound_run(hound_in, [Vector3(8.4, 0.0, 13.0), PROWL[0]], 6.0)
	_prowl()
	# another one at the front doors
	_front_threat()
	Dialogue.say("c9_marcus_order", false, true)
	Game.set_flag("ch9_fall_started")
	_set_rear(true)
	for k in ["Eddie", "Ruth", "Sarah", "Marcus"]:
		_start_follow(k)
	_hold(false)
	_refresh_prompts()
	_guide()


func _make_hound(at: Vector3) -> Node3D:
	var h: Node3D = c8._make_hound(at)
	h.name = "C9_Hound"
	hounds.append(h)
	return h


## The Hound inside stalks the far end of the back aisle (away from the escape route) until Marcus's moment.
func _prowl() -> void:
	var h := hound_in
	var i := 1
	while is_instance_valid(h) and not _busy.get("pinned", false) and not Game.has_flag("ch9_marcus_saved") \
			and not Game.has_flag("ch9_marcus_lost") and not Game.has_flag("ch9_escaped"):
		c8._hplay(h, "Walk", 0.0)
		await c8._hound_run(h, [PROWL[i % PROWL.size()]], 1.4)
		if not is_instance_valid(h) or _busy.get("pinned", false):
			return
		c8._hplay(h, "Alert", 0.0)
		await get_tree().create_timer(randf_range(1.0, 2.2)).timeout
		i += 1


## A shape pacing beyond the front glass (outside; never inside the store).
func _front_threat() -> void:
	if front_hound and is_instance_valid(front_hound):
		front_hound.queue_free()                      # the warning's shape has gone; a new one comes past the doors
	p4._spawn_hound()
	if p4.hound and is_instance_valid(p4.hound):
		front_hound = p4.hound
		hounds.append(p4.hound)


# ------------------------------------------------------------------ scene 5: Marcus's moment
func _pin_tick() -> void:
	if not Game.has_flag("ch9_fall_started") or Game.has_flag("ch9_escaped") or Game.has_flag("ch9_marcus_saved") \
			or Game.has_flag("ch9_marcus_lost") or _busy.get("pinned", false):
		return
	var pl: Vector3 = market.to_local(player.global_position)
	if pl.z > 14.6 and pl.x < PIN_TRIGGER_X:
		_pin_marcus()


func _pin_marcus() -> void:
	_pin_left = INF                                    # the countdown starts once he is down and the Hound is on him
	_busy["pinned"] = true
	report["pin_runs"] += 1
	var f: VeilCompanionFollow = follows["Marcus"]
	f.stop()
	# the others go on out of the rear exit and wait in the lot
	for i in 3:
		var k: String = ["Eddie", "Ruth", "Sarah"][i]
		(follows[k] as VeilCompanionFollow).stop()
		world.npc_walk(k, ml(OUT_WAIT[i]), 2.4)
	# Marcus, last in the line, goes down in the corridor; the Hound comes back through the doorway at him
	c5._reparent(marcus, market)
	# he gets there on his own feet (no pop into place): a short run, then he goes down
	if marcus.global_position.distance_to(ml(MARCUS_PIN)) > 0.6:
		world.npc_walk("Marcus", MARCUS_PIN, 3.2)
		var ma0 = world.animators.get("Marcus")
		var tw := 0.0
		while tw < 3.0 and ma0 and ma0.is_walking():
			await get_tree().process_frame
			tw += get_process_delta_time()
	world.place_survivor(marcus, MARCUS_PIN)
	var ma = world.animators.get("Marcus")
	if ma:
		ma.set_seated(true, 0.12)
		ma.set_mood("scared")
		ma.face_towards(ml(DOORWAY))
	var h := hound_in
	if h and is_instance_valid(h):
		c8._hplay(h, "Run", 6.5)
		await c8._hound_run(h, [Vector3(8.4, 0.0, 13.0), Vector3(8.6, 0.0, 14.7)], 6.5)
		if is_instance_valid(h):
			h.rotation.y = atan2(MARCUS_PIN.x - h.position.x, MARCUS_PIN.z - h.position.z)
			c8._hplay(h, "Attack_Bite", 0.0)
			c8._bark(h.global_position + Vector3(0, 1.0, 0))
	_pin_left = pin_window()
	st()["pin_window"] = _pin_left
	_refresh_prompts()
	_guide()


func _pin_countdown(delta: float) -> void:
	if not _busy.get("pinned", false) or _busy.get("resolving", false):
		return
	_pin_left -= delta
	if hud.has_method("set_hint"):
		hud.set_hint("E - PULL MARCUS FREE   %d" % ceili(maxf(_pin_left, 0.0)) if _pin_left < INF else "E - PULL MARCUS FREE")
	if _pin_left <= 0.0:
		_marcus_lost()


func _free_marcus(_b: Node) -> void:
	if not _busy.get("pinned", false) or _busy.get("resolving", false):
		return
	_busy["resolving"] = true
	its["pinned"].prompt_text = ""
	hud.set_hint("")
	_hold(true)
	await c8._turn_to(marcus.global_position + Vector3(0, 0.8, 0), 0.3)
	# the protagonist hauls him up and back; the jaws close on empty air
	var ma = world.animators.get("Marcus")
	if ma:
		ma.set_seated(false)
	var h := hound_in
	if h and is_instance_valid(h):
		c8._hplay(h, "Attack_Bite", 0.0)
		p4._play("impact", h.global_position + Vector3(0, 0.8, 0), 0.0)
		var tw := h.create_tween()
		tw.tween_property(h, "position", h.position + Vector3(-0.3, 0, -0.9), 0.4).set_trans(Tween.TRANS_SINE)
	world.place_survivor(marcus, MARCUS_PIN + Vector3(-1.1, 0, 0.0))
	Game.set_flag("ch9_marcus_saved")
	st()["marcus_outcome"] = "survived"
	_busy["pinned"] = false
	_busy["resolving"] = false
	Dialogue.say("c9_marcus_saved", false, true)
	_hold(false)
	_start_follow("Marcus")
	_refresh_prompts()
	_guide()


func _marcus_lost() -> void:
	_busy["resolving"] = true
	report["lost_runs"] += 1
	its["pinned"].prompt_text = ""
	hud.set_hint("")
	# a hard cut to black: he is dragged back through the doorway (no gore on screen)
	await hud.fade_to(1.0, 0.18)
	p4._play("scrape", ml(DOORWAY + Vector3(0, 0.4, 0.4)), 4.0)
	c8._bark(ml(DOORWAY + Vector3(0, 1.0, 0)))
	marcus.visible = false
	var ma = world.animators.get("Marcus")
	if ma:
		ma.walk_to([])
	if hound_in and is_instance_valid(hound_in):
		hound_in.queue_free()
	Game.set_flag("ch9_marcus_lost")
	st()["marcus_outcome"] = "lost"
	Dialogue.say("c9_marcus_lost", false, true)
	await get_tree().create_timer(1.0).timeout
	await hud.fade_to(0.0, 0.6)
	_busy["pinned"] = false
	_busy["resolving"] = false
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ scene 6: out into the mist
func _escape_tick() -> void:
	if not Game.has_flag("ch9_fall_started") or Game.has_flag("ch9_escaped") or _busy.get("pinned", false):
		return
	if not (Game.has_flag("ch9_marcus_saved") or Game.has_flag("ch9_marcus_lost")):
		return
	var pl: Vector3 = market.to_local(player.global_position)
	if pl.z > ESCAPED_Z:
		_escaped()


func _escaped() -> void:
	Game.set_flag("ch9_escaped")
	Game.set_flag("ch9_supermarket_lost")
	Game.set_flag("shelter_compromised")
	st()["roster"] = roster()
	# the communal stock left behind is lost with the store; what was packed is carried in the inventory
	var stock := Game.shelter_stock()
	st()["abandoned_stock"] = stock.duplicate()
	Game.world_state["shelter_stock"] = {"food": 0, "water": 0, "medical": 0, "batteries": 0}
	for k in ["Eddie", "Ruth", "Sarah", "Marcus"]:
		if k == "Marcus" and Game.has_flag("ch9_marcus_lost"):
			continue
		_start_follow(k)
	# the door is hauled shut behind them; something slams into it from inside
	_set_rear(false)
	p4._play("impact", ml(REAR_EXIT), 6.0)
	_close_store()
	for h in hounds:
		if is_instance_valid(h):
			h.queue_free()
	hounds.clear()
	_lookback()


## A brief first-person look back: the store in the fog, its emergency lights stuttering, the noises inside.
func _lookback() -> void:
	_hold(true)
	await c8._turn_to(ml(Vector3(8.0, 2.4, 17.0)), 0.9)
	var ext := market.get_node_or_null("Lights/ExtLight_4") as Light3D
	if ext:
		ext.visible = true
	for k in 6:
		if ext:
			ext.visible = not ext.visible
		for n in ["Light_BACK_20", "Light_BACK_30"]:
			var l := market.get_node_or_null("Lights/" + n) as Light3D
			if l:
				l.visible = randf() > 0.5
		await get_tree().create_timer(0.25).timeout
	c8._bark(ml(Vector3(4.0, 1.0, 12.0)))
	p4._play("scrape", ml(Vector3(6.0, 1.0, 15.0)), 0.0)
	await get_tree().create_timer(0.8).timeout
	_hold(false)
	Game.set_flag("ch9_lookback_done")
	Dialogue.say("c9_outside_a", false, true)
	await _wait_lines()
	Dialogue.say("c9_outside_lost" if Game.has_flag("ch9_marcus_lost") else "c9_outside_alive", false, true)
	await _wait_lines()
	Dialogue.say("c9_outside_b", false, true)
	_guide()


func _wait_lines() -> void:
	await get_tree().process_frame
	while Dialogue.is_busy():
		await get_tree().process_frame


func roster() -> Array:
	var r := ["Eddie", "Ruth", "Sarah"]
	if not Game.has_flag("ch9_marcus_lost"):
		r.append("Marcus")
	return r


# ------------------------------------------------------------------ scene 7: the road ahead
func _rendezvous_tick() -> void:
	if not Game.has_flag("ch9_escaped") or Game.has_flag("ch9_rendezvous_reached") or _busy.get("rv", false):
		return
	if _rv_area.overlaps_body(player) and not Dialogue.is_busy():
		_rendezvous()


func _rendezvous() -> void:
	_busy["rv"] = true
	Game.set_flag("ch9_rendezvous_reached")
	for k in follows:
		(follows[k] as VeilCompanionFollow).stop()
	_place_rendezvous()
	hud.set_marker(null, "")
	var alive := not Game.has_flag("ch9_marcus_lost")
	var npcs: Array = [marcus, eddie] if alive else [eddie, ruth]
	await _talk_group("c9_road_alive" if alive else "c9_road_lost", npcs)
	st()["roster"] = roster()
	st()["next_destination"] = "farms"
	st()["supplies_carried"] = {"painkillers": Game.inventory.count("painkillers"), "canned_food": Game.inventory.count("canned_food"),
		"water_bottle": Game.inventory.count("water_bottle")}
	Game.set_flag("next_destination_farms")
	Game.set_flag("supermarket_evacuated")
	Game.set_flag("chapter_9_complete")              # the next chapter is NOT started here
	_busy["rv"] = false
	_guide()
	await hud.chapter_complete(CHAPTER)
	_start_chapter10(false)                          # the road out of town starts at the rendezvous (displayed 11)


## The next chapter (displayed CHAPTER 11 "No Safe Road", internally chapter10.gd) starts at the rendezvous.
var chapter10: Node
func _start_chapter10(restoring: bool) -> void:
	if chapter10 != null:
		return
	chapter10 = load("res://game/world/chapter10.gd").new()
	chapter10.name = "Chapter10"
	add_child(chapter10)
	chapter10.begin(world, self, restoring)


# ------------------------------------------------------------------ helpers, per tick
func _hold(on: bool) -> void:
	player.set("controls_enabled", not on)
	player.velocity = Vector3.ZERO


func _process(delta: float) -> void:
	if Game.has_flag("ch10_started"):
		return                                    # the next chapter owns the group and the marker from here on
	_pin_countdown(delta)
	_tick -= delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	_pin_tick()
	_escape_tick()
	_rendezvous_tick()
	if not _busy.get("warning", false):
		_guide()
