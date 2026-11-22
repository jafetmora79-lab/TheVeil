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
const FRONT_HOUNDS := [Vector3(-1.5, 0.0, -2.4), Vector3(0.2, 0.0, -2.8), Vector3(1.6, 0.0, -2.3)]     ## three of them at the front glass
const CLERK_SPOT := Vector3(3.3, 0.04, 8.9)
const CLERK_NAME := "WALT"
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
const PIN_BY_TRUST := [7.0, 10.0, 13.0]                 ## story pass (approved): trust 0 / 1 / 2 -> how long Marcus holds on
func pin_window() -> float:
	return float(PIN_BY_TRUST[clampi(int(st().get("marcus_trust", marcus_trust())), 0, 2)])        # (the trust recorded when the chapter began)


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
	pack.visible = false                                  # review note #124: the shelter supply bin is the place; no stack of boxes
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
	# (review note #123: the overturned gondola that stood between the group and the doors is gone: it was out of nowhere)
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
	# Sarah: hurt on the floor as the previous chapter left her; she stands once the group moves
	c8._seat_on(sarah, c8._front_box, FRONT_BOX, GROUP_CENTRE + Vector3(1.0, 0, 0))
	_set_rear(false)
	_place_clerk()


## Mid-escape (a load; the fall flag is only set once the group is out): the rear door open, Eddie, Ruth and Sarah waiting in the lot, Marcus beside the player's way out if he lived.
func _apply_fall() -> void:
	_breach_state()
	_place_clerk()
	_set_rear(true)
	var sa = world.animators.get("Sarah")
	if sa:
		sa.limp = 1.0
		sa.set_downed("")
	_out_waiting = ["Eddie", "Ruth", "Sarah"]
	for i in 3:
		var k: String = ["Eddie", "Ruth", "Sarah"][i]
		var n: Node3D = {"Eddie": eddie, "Ruth": ruth, "Sarah": sarah}[k]
		c5._reparent(n, market)
		n.visible = true
		world.place_survivor(n, OUT_WAIT[i])
		_start_follow(k, false)
	if not Game.has_flag("ch9_marcus_lost"):
		c5._reparent(marcus, market)
		world.place_survivor(marcus, OUT_WAIT[0] + Vector3(1.2, 0, 0.8))
		_start_follow("Marcus", false)


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


## The clerk (named WALT): with the group in the store until the run, where he is taken. Never placed after he died.
func _place_clerk() -> void:
	var cl: Node3D = world.cashier
	if cl == null or not is_instance_valid(cl):
		return
	if Game.has_flag("ch9_clerk_dead"):
		cl.visible = false
		return
	_show(cl, CLERK_SPOT, GROUP_CENTRE)


func _start_follow(k: String, snap := true) -> void:
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
	if snap:
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
		sp.position = Vector3(AISLE_CLOSED_X, 0.0, AISLE_Z)       # the aisle across the back doorway (the group left by the staff door)
		sp.rotation.y = 0.0
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
	its["food"].prompt_text = ""
	its["food"].collision_layer = 0
	for k in ["npc_Marcus", "npc_Eddie"]:
		its[k].collision_layer = 8 if its[k].prompt_text != "" else 0
	var pin: bool = _busy.get("pinned", false)
	its["pinned"].prompt_text = "[E] Pull Marcus Free" if pin else ""
	its["pinned"].collision_layer = 8 if pin else 0


func prep_done() -> Dictionary:
	var talked: Dictionary = st().get("talked", {})
	return {"medical": Game.has_flag("ch9_medical_done"), "food": Game.has_flag("ch9_food_done"),
		"light": true,                                  # (review note #125: no flashlight check any more)
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
			t = ml(Vector3(7.8, 1.0, 6.05))
			label = "EMPTY THE SUPPLY BIN"
		elif not p["talks"]:
			for k in ["Eddie", "Ruth", "Sarah"]:
				if not talked.get(k, false):
					t = {"Eddie": eddie, "Ruth": ruth, "Sarah": sarah}[k]
					label = k.to_upper()
					break
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


## Review note #124: emptying the shelter supply bin (taking all its food and water into the pack) is the food-and-water step.
func _check_bin() -> void:
	if not Game.has_flag("ch9_marcus_talked") or Game.has_flag("ch9_food_done") or Game.has_flag("ch9_prepared"):
		return
	var stock := Game.shelter_stock()
	if int(stock.get("food", 0)) > 0 or int(stock.get("water", 0)) > 0:
		return
	st()["food_taken"] = Game.inventory.count("canned_food")
	st()["water_taken"] = Game.inventory.count("water_bottle")
	Game.set_flag("ch9_food_done")
	_hint("The supply bin is empty: everything is in the pack")
	_check_prepared()


func _hint(t: String) -> void:
	if hud.has_method("set_hint"):
		hud.set_hint(t)
		get_tree().create_timer(3.5).timeout.connect(func():
			if is_instance_valid(hud) and hud.hint.text == t:
				hud.set_hint(""))


func _check_prepared() -> void:
	_refresh_prompts()
	var p := prep_done()
	if p["medical"] and p["food"] and p["light"] and p["talks"] and not Game.has_flag("ch9_prepared"):
		Game.set_flag("ch9_prepared")
		_obj_txt = ""
		_guide()
		_warning_later()
	else:
		_guide()


func _warning_later() -> void:
	# right after the last word with the crew: nobody is left free to wander to the doors (the controls stay held until the cinematic has them)
	_hold(true)
	await get_tree().process_frame
	while Dialogue.is_busy() or world.conversing:
		_hold(true)
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
	Sfx.play_music("res://game/audio/library/music_hound_chase_LOOP.wav", true, -6.0, 1.5)         # frantic from here to the rendezvous
	p4._play("scrape", ml(Vector3(0.0, 1.0, 0.4)), 2.0)
	await p4._flicker_burst(1.2)
	# three of them at the FRONT glass, scratching and hitting it
	await c8._turn_to(ml(Vector3(0.0, 1.5, 0.3)), 0.8)
	_spawn_front_hounds()
	Dialogue.say("c9_warning", false, true)
	for n in [eddie, marcus, ruth, sarah]:
		var a = world.animators.get(String(n.name))
		if a:
			a.face_towards(ml(Vector3(0.0, 1.4, 0.0)))
	while Dialogue.is_busy():
		await get_tree().process_frame
	Dialogue.say("c9_front_assault", false, true)
	while Dialogue.is_busy():
		await get_tree().process_frame
	_busy["warning"] = false
	await _run_fall()


## Three hounds at the front doors: they hurl themselves at the glass and claw at it until the group is out (review note #127).
func _spawn_front_hounds() -> void:
	_assault_on = true
	for h in hounds:
		if is_instance_valid(h):
			h.queue_free()
	hounds.clear()
	front_hounds.clear()
	for i in FRONT_HOUNDS.size():
		var h: Node3D = c8._make_hound(FRONT_HOUNDS[i])
		h.name = "C9_FrontHound_%d" % i
		h.rotation.y = 0.0                                  # facing into the store, at the glass
		hounds.append(h)
		front_hounds.append(h)
		_assault_loop(h, i)
	hound_in = front_hounds[0]


var front_hounds: Array = []
var _assault_on := true


func _assault_loop(h: Node3D, i: int) -> void:
	await get_tree().create_timer(0.3 * i).timeout
	var home: Vector3 = FRONT_HOUNDS[i]
	while _assault_on and is_instance_valid(h):
		c8._hplay(h, "Attack_Bite", 0.0)
		var tw := h.create_tween()
		tw.tween_property(h, "position", home + Vector3(0, 0, 1.5), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		if not is_instance_valid(h):
			return
		p4._play("impact", ml(Vector3(home.x, 1.0, 0.3)), 5.0)
		var leaf_tw := create_tween()
		for d in world._auto_doors:
			var leaf: Node3D = d[0]
			var t0: Transform3D = leaf.transform
			leaf_tw.parallel().tween_property(leaf, "position:z", leaf.position.z + 0.04, 0.04)
		await get_tree().create_timer(0.05).timeout
		for d in world._auto_doors:
			(d[0] as Node3D).transform = d[1]
		if i == 1:
			p4._play("scrape", ml(Vector3(home.x, 0.8, 0.4)), 0.0)
		var back := h.create_tween()
		back.tween_property(h, "position", home, 0.5).set_trans(Tween.TRANS_SINE)
		await back.finished
		await get_tree().create_timer(randf_range(0.15, 0.7)).timeout


# ------------------------------------------------------------------ scene 4: the fall (review note #127, reworked twice)
## One scripted sequence. The player is held from the last word with the crew until the group is out; the only things asked of them are one click struggle to pull the aisle clear, a "help Marcus" decision and,
## if they help, a second struggle to get him free. Every path is computed round the real furniture and doors (`world.npc_route`, static colliders), nobody teleports and every line is spoken while the people
## do what it says.
##  1. Eddie, Ruth, Sarah (limping) and Walt the clerk wait by the back doorway; Marcus and the player go to the east end of the aisle that blocks it and PULL it clear (the struggle)
##  2. Eddie leads Ruth and Sarah through the doorway and out the back; the front doors burst; three hounds pour in; the lead one takes Walt, who froze
##  3. Marcus and the player push the aisle back across the doorway behind them; half way a hound takes Marcus: "E - HELP MARCUS"
##  4a. no help: Marcus is dragged off; the player runs through the staff door, along the corridor and out of the rear exit, closing it behind them
##  4b. help: the second struggle (pull him free), they finish the push, Marcus opens the staff door and goes first, the player follows and shuts it, and they leave by the rear exit together
const AISLE_Z := 13.62
const AISLE_CLOSED_X := 8.8                        ## centre of the aisle across the back doorway
const AISLE_OPEN_X := 12.0                         ## slid east: the doorway is clear
const AISLE_HALF := 2.12
const PULL_DZ_PLAYER := 0.28
const PULL_DZ_MARCUS := -0.28
const MARCUS_DOWN := Vector3(10.2, 0.04, 11.7)     ## where the hound drags him: south-east of the aisle, in reach of the pushers
const STAFF_IN := Vector3(15.0, 0.04, 13.4)        ## south of the staff door (store side)
const STAFF_OUT := Vector3(15.0, 0.04, 15.5)       ## north of it (the corridor)


func _aisle_set(s_: float) -> void:                ## 0 = closed (across the doorway), 1 = open (slid east)
	var sp: Node3D = c8._secure_pallet
	sp.position = Vector3(lerpf(AISLE_CLOSED_X, AISLE_OPEN_X, s_), 0.0, AISLE_Z)
	sp.rotation.y = 0.0


## Where a puller / pusher stands: just past the east end of the aisle at progress s_, dz across its depth.
func _end_spot(s_: float, dz: float) -> Vector3:
	return Vector3(lerpf(AISLE_CLOSED_X, AISLE_OPEN_X, s_) + AISLE_HALF + 0.6, 0.04, AISLE_Z + dz)


## A way from `from` to `to` (market-local) round the real furniture, walls and doors as they are right now.
func _route(from: Vector3, to: Vector3) -> Array:
	var r: Array = world.npc_route(market, from, to, null, true)
	if r.is_empty():
		return [to]
	return r


## Send a character along a computed route (market-local), no placing.
func _walk(n: Node3D, a, to: Vector3, speed: float) -> void:
	if a == null:
		return
	c5._reparent(n, market)
	n.visible = true
	a.free_walk = true
	a.turn_to_face = true
	a.set_mood("scared")
	a.walk_to(_route(n.position, to), speed)


func _wait_arrived(anims: Array, timeout: float) -> void:
	var t := 0.0
	while t < timeout:
		var busy := false
		for a in anims:
			if a != null and a.is_walking():
				busy = true
		if not busy:
			return
		await get_tree().process_frame
		t += get_process_delta_time()


## The player runs a computed route (market-local) at a run, looking where they go. Physics stay off until the caller turns them on.
func _player_run(to: Vector3, speed: float) -> void:
	player.set_physics_process(false)
	var pts := _route(market.to_local(player.global_position), to)
	for q in pts:
		var tgt: Vector3 = ml(q)
		tgt.y = player.global_position.y
		while player.global_position.distance_to(tgt) > 0.1:
			var d: Vector3 = tgt - player.global_position
			d.y = 0.0
			var dt := get_process_delta_time()
			player.global_position += d.normalized() * minf(speed * dt, d.length())
			player.velocity = Vector3.ZERO
			player.set_yaw_pitch(lerp_angle(player.rotation.y, atan2(-d.x, -d.z), minf(1.0, 9.0 * dt)), lerpf(player.head.rotation.x, 0.0, 0.1))
			await get_tree().process_frame


## Frantic music for the whole sequence: the hound chase loop plus the skitter chase loop under it.
var _frenzy_player: AudioStreamPlayer


func _frenzy(on: bool) -> void:
	if on:
		Sfx.play_music("res://game/audio/library/music_hound_chase_LOOP.wav", true, -2.0, 0.6)
		if _frenzy_player == null:
			_frenzy_player = AudioStreamPlayer.new()
			_frenzy_player.stream = load("res://game/audio/library/music_skitter_chase_LOOP.wav") as AudioStream
			_frenzy_player.volume_db = -9.0
			_frenzy_player.finished.connect(func(): if _frenzy_player and _frenzy_player.is_inside_tree() and _frenzy_player.has_meta("on"): _frenzy_player.play())
			add_child(_frenzy_player)
		_frenzy_player.set_meta("on", true)
		_frenzy_player.play()
	elif _frenzy_player != null:
		_frenzy_player.remove_meta("on")
		_frenzy_player.stop()


func _run_fall() -> void:
	if Game.has_flag("ch9_fall_started"):
		return
	report["fall_runs"] += 1
	_busy["fall"] = true
	_busy["exit_cine"] = true
	_aisle_shut = false
	_hold(true)
	_frenzy(true)
	if c8._blocker:
		c8._blocker.collision_layer = 0
	var ea = world.animators.get("Eddie")
	var ma = world.animators.get("Marcus")
	var ra = world.animators.get("Ruth")
	var sa = world.animators.get("Sarah")
	var wa = world.animators.get("Cashier")
	var clerk: Node3D = world.cashier
	# 1. everybody moves at once; the lines are spoken while they run
	Dialogue.say("c9_front_assault", false, true)
	if sa:
		sa.set_downed("")                                # Sarah gets up (the clip blends out of the floor)...
		sa.limp = 1.0                                    # ...and runs with a limp
	_walk(eddie, ea, Vector3(8.0, 0.04, 11.7), 4.0)
	_walk(ruth, ra, Vector3(8.8, 0.04, 11.9), 3.8)
	_walk(sarah, sa, Vector3(7.5, 0.04, 11.8), 3.0)
	if clerk and is_instance_valid(clerk) and wa and not Game.has_flag("ch9_clerk_dead"):
		_walk(clerk, wa, Vector3(9.4, 0.04, 11.3), 3.2)
	_walk(marcus, ma, _end_spot(0.0, PULL_DZ_MARCUS), 4.4)
	await _player_run(_end_spot(0.0, PULL_DZ_PLAYER), 4.6)
	await _wait_arrived([ma], 3.0)
	_face_aisle([ma])
	await c8._turn_to(c8._secure_pallet.global_position + Vector3(0, 0.9, 0), 0.35)
	# 2. the first struggle: Marcus and the player pull the aisle clear
	await _pull_aisle()
	_set_rear(true)
	# 3. Eddie takes Ruth and Sarah through; the front doors burst; the hounds pour in
	_pass_through(ea, ra, sa)
	await _front_burst()
	var t_wait := 0.0
	while sarah.position.z < 15.0 and t_wait < 7.0:      # Sarah is through the doorway: now the push
		await get_tree().process_frame
		t_wait += get_process_delta_time()
	# 4. push the aisle back behind them; half way a hound takes Marcus
	await _push_back()


func _face_aisle(units: Array) -> void:
	var c: Vector3 = c8._secure_pallet.global_position + Vector3(0, 0.9, 0)
	for a in units:
		if a != null:
			a.face_towards(c)


## THE first struggle: click to pull the aisle east off the back doorway. Marcus pulls beside the player; if the bar runs out it creeps back and they go again.
func _pull_aisle() -> void:
	var sg = world.get_node_or_null("Struggle")
	if sg == null:
		sg = load("res://game/encounters/struggle.gd").new()
		sg.name = "Struggle"
		world.add_child(sg)
		sg.setup(world)
	var s_ := 0.0
	var won := false
	while not won:
		c8._push_over = false
		c8._push_won = false
		var base := s_
		c8._shove_go(sg, "CLICK RAPIDLY  -  PULL THE SHELVES CLEAR OF THE BACK DOOR!", "LEFT CLICK, AGAIN AND AGAIN  -  MARCUS PULLS WITH YOU", 11.0, 0.075)
		var t := 0.0
		while not c8._push_over:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			var pr: float = sg.rescue_progress()
			s_ = lerpf(s_, base + (1.0 - base) * pr, 1.0 - exp(-6.0 * dt))
			_pullers_at(s_, t)
			if int(t * 2.0) != int((t - dt) * 2.0):
				p4._play("scrape", ml(c8._secure_pallet.position), -6.0 + 3.0 * pr)
				p4._play("impact", ml(Vector3(0.0, 1.0, 0.3)), 2.0 + 2.0 * pr)
				world._shake(get_viewport().get_camera_3d(), 0.1, 0.012)
		won = c8._push_won
		if not won:
			p4._play("impact", ml(Vector3(0.0, 1.0, 0.3)), 6.0)              # the glass takes another blow: the shelves slide back a little
			world._shake(get_viewport().get_camera_3d(), 0.35, 0.05)
			var back_to := s_ * 0.75
			var bk := create_tween()
			bk.tween_method(func(v: float): _pullers_at(v, 0.0), s_, back_to, 0.5)
			await bk.finished
			s_ = back_to
	_pullers_at(1.0, 0.0)


## The two pullers / pushers (the player and Marcus) at the east end of the aisle at progress s_, leaning into it.
func _pullers_at(s_: float, t: float) -> void:
	_aisle_set(s_)
	var bob := sin(t * 9.0) * 0.03
	player.global_position = ml(_end_spot(s_, PULL_DZ_PLAYER) + Vector3(bob, 0, 0))
	player.velocity = Vector3.ZERO
	var c: Vector3 = c8._secure_pallet.global_position + Vector3(0, 0.9, 0)
	var dv: Vector3 = c - player.global_position
	dv.y = 0.0
	player.set_yaw_pitch(lerp_angle(player.rotation.y, atan2(-dv.x, -dv.z), 0.2), -0.12)
	if not _busy.get("marcus_down", false):
		marcus.global_position = ml(_end_spot(s_, PULL_DZ_MARCUS) + Vector3(-bob, 0, 0))
		var ma = world.animators.get("Marcus")
		if ma:
			ma.face_towards(c)


var _out_waiting: Array = []


## Eddie leads Ruth and Sarah (limping) through the doorway, the corridor and out of the rear exit to wait in the lot.
func _pass_through(ea, ra, sa) -> void:
	Dialogue.say("c9_pass_through", false, true)
	_out_waiting = ["Eddie", "Ruth", "Sarah"]
	_walk(eddie, ea, OUT_WAIT[0], 3.6)
	_walk(ruth, ra, OUT_WAIT[1], 3.6)
	_walk(sarah, sa, OUT_WAIT[2], 3.0)


## The front doors give; three hounds come in at a run, each along a route round the furniture. The lead one goes for Walt, who froze by the doorway.
func _front_burst() -> void:
	c5._set_doors(true)
	p4._play("impact", ml(Vector3(0.0, 1.0, 0.3)), 9.0)
	c8._dust(ml(Vector3(0.0, 2.4, 0.3)), 34)
	world._shake(get_viewport().get_camera_3d(), 0.5, 0.06)
	_assault_on = false
	for h in front_hounds:                                # back off a metre so the leaves swing clear
		if is_instance_valid(h):
			c8._hplay(h, "Alert", 0.0)
	await get_tree().create_timer(1.0).timeout
	var clerk: Node3D = world.cashier
	var walt_at := Vector3(9.4, 0.04, 11.3)
	for i in front_hounds.size():
		var h: Node3D = front_hounds[i]
		if not is_instance_valid(h):
			continue
		c8._hplay(h, "Run", 6.2)
		if i == 0:
			_run_to_walt(h, clerk, walt_at)
		else:
			_hound_pace(h, i)
	if clerk and is_instance_valid(clerk) and not Game.has_flag("ch9_clerk_dead"):
		Dialogue.say("c9_walt_freeze", false, true)


func _run_to_walt(h: Node3D, clerk: Node3D, walt_at: Vector3) -> void:
	var door := Vector3(0.0, 0.0, 0.5)
	var route: Array = _route(door, walt_at + Vector3(-1.0, 0, -0.8))
	await c8._hound_run(h, [door] + route, 6.2)
	if not is_instance_valid(h) or clerk == null or not is_instance_valid(clerk) or Game.has_flag("ch9_clerk_dead"):
		return
	Game.set_flag("ch9_clerk_dead")
	var wa = world.animators.get("Cashier")
	c8._hplay(h, "Attack_Bite", 0.0)
	Dialogue.say("c9_clerk_taken", false, true)
	Sfx.play("hurt", clerk.global_position + Vector3(0, 1.3, 0), 6.0, 1.3)
	world._shake(get_viewport().get_camera_3d(), 0.35, 0.05)
	if wa:
		wa.free_walk = true
		wa.set_downed("back")                               # on his front, clawing at the floor, dragged
	var away := clerk.position + Vector3(-3.5, 0, -2.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(clerk, "position", away, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(h, "position", away + Vector3(0.5, 0, 0.7), 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	clerk.visible = false
	if is_instance_valid(h):
		hound_in = h
		c8._hplay(h, "Alert", 0.0)


## The other two run to the west end of the aisle and throw themselves at it.
func _hound_pace(h: Node3D, i: int) -> void:
	var door := Vector3(0.0, 0.0, 0.5)
	var route: Array = _route(door, Vector3(6.6 + i * 0.5, 0.04, 12.6))
	await c8._hound_run(h, [door] + route, 6.2)
	while is_instance_valid(h) and not Game.has_flag("ch9_escaped") and not _aisle_shut:
		c8._hplay(h, "Attack_Bite", 0.0)
		p4._play("impact", ml(Vector3(6.4 + i * 0.6, 1.0, 13.0)), 4.0)
		world._shake(get_viewport().get_camera_3d(), 0.18, 0.025)
		await get_tree().create_timer(randf_range(0.7, 1.4)).timeout


var _aisle_shut := false


## Marcus and the player drive the aisle back across the doorway; half way a hound takes Marcus.
func _push_back() -> void:
	Dialogue.say("c9_push_back", false, true)
	var tw := create_tween()
	tw.tween_method(func(v: float): _pullers_at(v, v * 14.0), 1.0, 0.5, 2.2)
	await tw.finished
	await _marcus_grabbed()


## A hound comes round the end of the aisle and takes Marcus off his feet: dragged a few metres and pinned. Then the decision.
func _marcus_grabbed() -> void:
	_busy["marcus_down"] = true
	report["pin_runs"] += 1
	var ma = world.animators.get("Marcus")
	var h: Node3D = hound_in if is_instance_valid(hound_in) else (front_hounds[0] if front_hounds.size() > 0 else null)
	if h and is_instance_valid(h):
		c8._hplay(h, "Run", 6.4)
		await c8._hound_run(h, _route(h.position, Vector3(marcus.position.x - 0.5, 0.04, marcus.position.z - 1.4)), 6.4)
		if is_instance_valid(h):
			h.rotation.y = atan2(marcus.position.x - h.position.x, marcus.position.z - h.position.z)
			c8._hplay(h, "Attack_Bite", 0.0)
	Dialogue.say("c9_marcus_grabbed", false, true)
	Sfx.play("hurt", marcus.global_position + Vector3(0, 1.3, 0), 6.0, 1.0)
	world._shake(get_viewport().get_camera_3d(), 0.4, 0.05)
	if ma:
		ma.free_walk = true
		ma.set_downed("back")
		ma.set_mood("scared")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(marcus, "position", MARCUS_DOWN, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if h and is_instance_valid(h):
		tw.tween_property(h, "position", MARCUS_DOWN + Vector3(-0.2, 0, -0.9), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if ma:
		ma.set_downed("side")                                  # pinned, hurt, on the floor
	if h and is_instance_valid(h):
		h.rotation.y = atan2(MARCUS_DOWN.x - h.position.x, MARCUS_DOWN.z - h.position.z)
		c8._hplay(h, "Attack_Bite", 0.0)
		hound_in = h
	await c8._turn_to(marcus.global_position + Vector3(0, 0.6, 0), 0.35)
	# the decision: help him (E) or leave him. The player is still held: the answer is the only input.
	var window := maxf(pin_window() * 0.55, 3.5)
	st()["pin_window"] = window
	var left := window
	var helped := false
	while left > 0.0:
		hud.set_hint("E - HELP MARCUS   %d" % ceili(left))
		await get_tree().process_frame
		left -= get_process_delta_time()
		if Input.is_action_just_pressed("interact"):
			helped = true
			break
	hud.set_hint("")
	var freed := false
	if helped:
		freed = await _help_marcus()
	if freed:
		await _marcus_saved_scene()
	else:
		await _marcus_lost_scene()


## The help: the player runs to him and the second struggle starts (pull him free).
func _help_marcus() -> bool:
	await _player_run(Vector3(MARCUS_DOWN.x + 0.9, 0.04, MARCUS_DOWN.z + 0.2), 4.6)
	await c8._turn_to(marcus.global_position + Vector3(0, 0.4, 0), 0.25)
	var sg = world.get_node_or_null("Struggle")
	if sg == null:
		sg = load("res://game/encounters/struggle.gd").new()
		sg.name = "Struggle"
		world.add_child(sg)
		sg.setup(world)
	return await sg.rescue("CLICK RAPIDLY  -  PULL MARCUS FREE!", "LEFT CLICK, AGAIN AND AGAIN", 8.0, "hs_hold", 0.1)


func _marcus_saved_scene() -> void:
	var ma = world.animators.get("Marcus")
	var h := hound_in
	Dialogue.say("c9_marcus_saved", false, true)
	if h and is_instance_valid(h):
		c8._hplay(h, "Attack_Bite", 0.0)
		p4._play("impact", h.global_position + Vector3(0, 0.8, 0), 2.0)
		var tw := h.create_tween()
		tw.tween_property(h, "position", h.position + Vector3(-1.4, 0, -1.2), 0.5).set_trans(Tween.TRANS_SINE)
	if ma:
		ma.set_downed("")                                      # hauled up
		ma.limp = 0.6
	Game.set_flag("ch9_marcus_saved")
	st()["marcus_outcome"] = "survived"
	_busy["marcus_down"] = false
	await get_tree().create_timer(0.7).timeout
	# back to the shelves along a computed route, then the last shoves together
	var spot0 := _end_spot(0.5, PULL_DZ_MARCUS)
	_walk(marcus, ma, spot0, 4.4)
	await _player_run(_end_spot(0.5, PULL_DZ_PLAYER), 4.6)
	await _wait_arrived([ma], 2.0)
	await _finish_aisle(true)
	await _exit_cinematic(true)


## The window ran out or the struggle was lost: he is dragged off into the store (no cut to black).
func _marcus_lost_scene() -> void:
	var ma = world.animators.get("Marcus")
	Dialogue.say("c9_marcus_lost", false, true)
	Sfx.play("hurt", marcus.global_position + Vector3(0, 1.3, 0), 6.0, 0.95)
	if ma:
		ma.set_downed("back")
	var h := hound_in
	var away := marcus.position + Vector3(-4.5, 0, -2.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(marcus, "position", away, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if h and is_instance_valid(h):
		tw.tween_property(h, "position", away + Vector3(0.4, 0, 0.8), 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	marcus.visible = false
	report["lost_runs"] += 1
	Game.set_flag("ch9_marcus_lost")
	st()["marcus_outcome"] = "lost"
	_busy["marcus_down"] = false
	await _exit_cinematic(false)


## The last shoves: the aisle goes from half shut to across the doorway while the hounds hit the other side.
func _finish_aisle(with_marcus: bool) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_pullers_at(v, v * 14.0), 0.5, 0.0, 2.2)
	for k in 3:
		p4._play("scrape", ml(c8._secure_pallet.position), -4.0)
		await get_tree().create_timer(0.7).timeout
	await tw.finished
	_aisle_shut = true
	p4._play("door_close", ml(Vector3(AISLE_CLOSED_X, 1.0, AISLE_Z)), 2.0)
	p4._play("impact", ml(Vector3(AISLE_CLOSED_X - 1.5, 1.0, AISLE_Z - 0.8)), 6.0)
	world._shake(get_viewport().get_camera_3d(), 0.4, 0.05)


## The way out, as a cinematic: the staff door, the corridor, the rear exit. With Marcus: he opens the staff door and goes first, the player follows and shuts it behind them. Alone: the player
## opens it, runs, and shuts the rear door behind them. Everyone left alive is outside afterwards.
func _exit_cinematic(with_marcus: bool) -> void:
	var staff: Interactable = p4.its.get("INT_Door_Staff")
	var ma = world.animators.get("Marcus")
	var out_pt: Vector3 = OUTSIDE + Vector3(0.0, 0.0, 0.6)
	if staff and with_marcus and ma:
		# Marcus runs to the door, opens it and goes through; the player is a few strides behind him
		_walk(marcus, ma, STAFF_IN, 4.4)
		var t0 := 0.0
		while ma.is_walking() and t0 < 4.0:
			await get_tree().process_frame
			t0 += get_process_delta_time()
		staff.set_open(true)
		Sfx.play("door_open", ml(STAFF_IN + Vector3(0, 1.0, 0.8)), -2.0, 0.9)
		await get_tree().create_timer(0.45).timeout
		_walk(marcus, ma, out_pt, 4.4)
		await _player_run(STAFF_IN, 4.8)
	else:
		await _player_run(STAFF_IN, 4.8)
		if staff:
			staff.set_open(true)
			Sfx.play("door_open", ml(STAFF_IN + Vector3(0, 1.0, 0.8)), -2.0, 0.9)
			await get_tree().create_timer(0.45).timeout
	await _player_run(STAFF_OUT, 4.8)
	if staff:                                                 # through: the staff door is shut behind them
		staff.set_open(false)
		Sfx.play("door_close", ml(STAFF_OUT + Vector3(0, 1.0, -0.8)), 0.0, 0.8)
		p4._play("impact", ml(STAFF_IN + Vector3(0, 1.0, -0.4)), 5.0)
		world._shake(get_viewport().get_camera_3d(), 0.3, 0.04)
	await _player_run(out_pt, 4.8)
	if with_marcus and ma:
		await _wait_arrived([ma], 2.5)
	# round, and the rear door is hauled shut behind them
	await c8._turn_to(ml(REAR_EXIT + Vector3(0, 0.4, 0)), 0.45)
	_close_rear_animated()
	await get_tree().create_timer(0.7).timeout
	player.set_physics_process(true)
	_frenzy(false)
	Sfx.play_music(Sfx.MUSIC_GAMEPLAY, true, -14.0, 3.0)
	Game.set_flag("ch9_fall_started")
	_busy["fall"] = false
	_busy["exit_cine"] = false
	_escaped()


func _close_rear_animated() -> void:
	var bd: Node3D = p4.its.get("back_door")
	if bd:
		var base: Transform3D = p4._base["back"]
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(bd, "transform", base, 0.5)
	Sfx.play("door_close", ml(REAR_EXIT), 2.0, 0.7)
	p4._play("impact", ml(REAR_EXIT + Vector3(0, 0.0, -0.6)), 6.0)


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


# ------------------------------------------------------------------ scene 5: Marcus's moment (see _marcus_grabbed above)
func _free_marcus(_b: Node) -> void:
	pass                                                      # (the decision is now the "E - HELP MARCUS" prompt in _marcus_grabbed)


# ------------------------------------------------------------------ scene 6: out into the mist
func _escape_tick() -> void:
	if not Game.has_flag("ch9_fall_started") or Game.has_flag("ch9_escaped") or _busy.get("exit_cine", false):
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
		_start_follow(k, not (k in _out_waiting or k == "Marcus" or (follows[k] as VeilCompanionFollow).active))
	# the door is hauled shut behind them; something slams into it from inside
	_set_rear(false)
	p4._play("impact", ml(REAR_EXIT), 6.0)
	_close_store()
	for h in hounds:
		if is_instance_valid(h):
			h.queue_free()
	hounds.clear()
	_lookback()
	if Game.has_flag("vehicle_repaired"):
		# the repaired car stays at the lot (Chapters 14 and 15 remember it there): said why, once out the back
		get_tree().create_timer(4.5).timeout.connect(func(): Dialogue.say("c9_no_car", false, false))


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
	_tick -= delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	_check_bin()
	_escape_tick()
	_rendezvous_tick()
	if not _busy.get("warning", false):
		_guide()
