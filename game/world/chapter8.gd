extends Node
class_name VeilChapter8
## THE VEIL - Chapter 8 "Something at the Doors" (Act III). Starts when the player sleeps after Chapter 7 (flag
## ch7_rested); created by chapter7.gd. State: story flags + Game.world_state["ch8"]; loads rebuild the chapter
## from them without replaying finished events (the attack, the death and the medicine are never repeated).
##
## Eddie (heard it hitting the back door) -> the rear exit: inspect the damaged barricade (displaced pallets, loose
## wood, claw marks, a creak), Marcus -> collect boards (back corridor), duct tape (service counter) and a hammer
## (storage, on the loading-bay pallets) -> first-person repair (pallets back, three boards across the door) ->
## the lights fail (hum, flicker, dark) -> the maintenance panel (the Chapter 4 breaker): inspect, reseat the cable
## -> partial power -> on the way back three impacts on the rear exit (first person, no talk camera), the
## barricade gives way -> a Hound comes through: the temporary survivor (the Chapter 5 survivor, or a stranger who
## came in the night) is caught and dies once; Sarah is hurt -> push a pallet stack across the back doorway (no
## combat); the Hound withdraws -> help Sarah: medicine (a carried painkiller pack or the shelter's medical stock,
## used exactly once) or none (she stays seriously hurt, never dies here) -> everyone gathers -> the talk about
## leaving -> "CHAPTER 8 COMPLETE". Chapter 9 is not started. The supermarket stays usable.
## Every NPC talk goes through world.converse() (the shared talk camera, continue / hold-to-skip controls).

const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const PALLET := preload("res://THE_VEIL_ASSETS_V2/04_Commercial/Shared_Props/COM_PalletStack.glb")
const HAMMER := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Tools/INV_Hammer.glb")
const TAPE := preload("res://THE_VEIL_ASSETS_V2/08_Inventory/Tools/INV_DuctTape.glb")
const BOX := preload("res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_CardboardBox_Closed.glb")
const SPARKS := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Environmental_Effects/ElectricalSparks.tscn"
const WOOD := "res://THE_VEIL_ASSETS_V2/Materials_Godot/Architecture/M_Arch_WoodPlanksAged.tres"
const STATE := "ch8"

# ---- supermarket-local layout (collision-mapped: sales floor z 3.5-13.3, gondola rows z 8-12 with aisles at
# x 1.5-2.5 / 4.5-5.5 / 7-9 / 10.5-14, coolers x <= 6.59 along the back wall (front face z 13.33), back wall face
# z 14.14 with the opening to the back corridor at x 7.6-9.2, back corridor z 14.4-17.3, rear exit leaf x 7.5-8.5
# at z 17.45, breaker panel (Chapter 4) x 16.9 on the back wall, loading-bay pallets at x 19.5)
const EDDIE_SPOT := Vector3(6.2, 0.04, 4.05)
const MARCUS_BACK := Vector3(9.9, 0.04, 15.7)
const RUTH_SPOT := Vector3(8.6, 0.04, 6.8)
const SARAH_SPOT := Vector3(10.4, 0.04, 7.3)
const TEMP_SPOT := Vector3(-5.2, 0.04, 7.1)
const BARRICADE_LOOK := Vector3(8.0, 1.0, 17.3)
const BACK_PALLET_BLOCK := Vector3(8.0, 0.04, 16.917)        # Chapter 4's blocking spot (flush with the leaf)
const BACK_PALLET_DAMAGED := Vector3(8.35, 0.04, 16.55)
const BACK_PALLET_BROKEN := Vector3(9.45, 0.04, 16.25)
const DOOR_INSIDE := Vector3(8.0, 1.0, 16.4)
const BOARDS_POS := Vector3(-2.2, 0.04, 16.45)               # back corridor floor, by the storage boxes
const TAPE_POS := Vector3(5.15, 1.1, 5.0)                    # service counter top (collider top y 1.05)
const HAMMER_POS := Vector3(19.3, 1.6, 15.75)                # on the loading-bay pallets (settled onto their top)
const PANEL := Vector3(16.9, 1.24, 17.37)
# the attack
const DOORWAY := Vector3(8.4, 0.04, 14.2)
const PRE_MARCUS := Vector3(10.0, 0.04, 12.85)
const PRE_TEMP := Vector3(6.4, 0.04, 12.85)
const PRE_SARAH := Vector3(5.6, 0.04, 12.85)
const PRE_EDDIE := Vector3(6.4, 0.04, 6.5)
const PRE_RUTH := Vector3(8.6, 0.04, 6.8)
const CAUGHT_AT := Vector3(8.3, 0.04, 12.9)
const ATTACK_TRIGGER_Z := 11.2                                # back down the aisle toward the front
const HOUND_OUT := Vector3(8.0, 0.0, 19.4)
const HOUND_GUARD := Vector3(8.4, 0.0, 15.6)
const SECURE_START := Vector3(11.1, 0.04, 13.0)
const SECURE_BLOCK := Vector3(8.4, 0.04, 13.62)              # 1.74 m wide (scaled stack) over the 1.6 m opening
const SECURE_SCALE := Vector3(1.45, 1.0, 1.0)
const PUSHER := Vector3(12.85, 0.04, 13.0)
const POST_MARCUS := Vector3(13.4, 0.04, 11.6)
const INJURED_BOX := Vector3(4.95, 0.04, 12.95)
const RUTH_BY_SARAH := Vector3(5.95, 0.04, 12.8)
# the aftermath (front of the store, by the customer-service counter)
const FRONT_BOX := Vector3(2.4, 0.04, 6.4)
const GATHER := {"Eddie": Vector3(5.0, 0.04, 6.3), "Ruth": Vector3(2.9, 0.04, 7.45), "Marcus": Vector3(4.6, 0.04, 7.5)}
const GATHER_CENTRE := Vector3(3.8, 0.04, 6.8)
const PARTIAL_DARK := ["Light_SALES_10", "Light_BACK_00", "Light_BACK_20", "Light_RESTRM"]

var world: Node
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
var temp: Node3D                     ## the temporary survivor (the Chapter 5 "Survivor" body)
var its := {}
var hound: Node3D
var hound_spawns := 0
var deaths := 0                      ## scripted deaths played (tests: exactly one)
var attack_runs := 0
var medical_used := 0
var report := {}
var _busy := {}
var _tick := 0.0
var _streams := {}
var _boards_up: Array = []
var _boards_loose: Array = []
var _secure_pallet: Node3D
var _blocker: StaticBody3D
var _injured_box: Node3D
var _front_box: Node3D
var _bite_t := 0.0
var _lunge_t := 2.0


func begin(w: Node, chapter7: Node, restoring: bool) -> void:
	world = w
	c7 = chapter7
	c6 = c7.c6
	c5 = c7.c5
	p4 = c7.p4
	market = w.market
	player = w.player
	hud = w.hud
	eddie = w.eddie
	marcus = w.marcus
	ruth = c6.ruth
	sarah = c6.sarah
	temp = c5.survivor
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"barricade": "damaged", "power": "on", "injured": "", "ruth_sarah_arrived": false}
	_make_sounds()
	_setup_npcs()
	_setup_barricade()
	_setup_materials()
	_setup_panel()
	_setup_attack_props()
	_setup_rest()
	var fresh := not Game.has_flag("ch8_started")
	if fresh:
		Game.set_flag("ch8_started")
	_apply()
	Game.refresh_objective()
	if fresh:
		_title.call_deferred()
	# an attack cut off by a load before the death plays again from its start; a finished one never does
	if Game.has_flag("ch8_attack_started") and not Game.has_flag("ch8_temp_survivor_died"):
		_run_attack.call_deferred()


func _title() -> void:
	await get_tree().create_timer(2.6).timeout       # after the wake-up fade
	await hud.title_card("CHAPTER 8  -  SOMETHING AT THE DOORS", 2.6)


func st() -> Dictionary:
	return Game.world_state[STATE]


func ml(p: Vector3) -> Vector3:
	return market.global_transform * p


# ------------------------------------------------------------------ setup
func _setup_npcs() -> void:
	for pair in [["npc_Marcus", _talk_marcus], ["npc_Eddie", _talk_eddie]]:
		var it: Interactable = p4.its.get(pair[0])
		if it:
			it.used.connect(pair[1])
			its[pair[0]] = it
	# Sarah: the injured survivor (helped with [E]); one interaction on her body
	var sit := Interactable.attach(sarah, {"kind": "custom", "label": "Sarah", "prompt_text": ""})
	sit.name = "C8_Interact"
	sit.used.connect(_help_sarah)
	its["sarah"] = sit
	# Ruth and Sarah are in the shelter for this chapter: invited in Chapter 6, or (told the way / left) they came to
	# the supermarket during the night; the temporary survivor likewise
	if String(c6.st().get("ruth_sarah", "")) != "shelter":
		st()["ruth_sarah_arrived"] = true


## The back exit as Chapter 4 left it, now damaged: the pallet stack shoved off its spot, the leaf forced a few
## degrees, splintered wood on the floor, claw marks on the leaf. Inspect / repair use Chapter 4's own back-door
## interaction box (re-used: its box covers the leaf and the pallets).
func _setup_barricade() -> void:
	var spot: Interactable = p4.its.get("backdoor")
	if spot:
		spot.used.connect(_use_barricade)
		its["barricade"] = spot
	var pal_it: Interactable = p4.its.get("pallet_back")
	if pal_it:
		pal_it.collision_layer = 0                     # the barricade spot handles the pallets in this chapter
		pal_it.prompt_text = ""
	var wood: Material = load(WOOD)
	for i in 3:                                      # boards across the leaf once repaired (above the pallet stack)
		var b := _plank(Vector3(1.55, 0.13, 0.035), wood)
		b.name = "C8_Board_%d" % i
		market.add_child(b)
		b.position = Vector3(8.0, [1.28, 1.62, 1.96][i], 17.39)
		b.rotation = Vector3(0, 0, deg_to_rad([4.0, -3.0, 2.0][i]))
		_boards_up.append(b)
	for i in 3:                                      # loose wood on the floor (damage) / fallen boards (after the attack)
		var b := _plank(Vector3(0.95, 0.03, 0.13), wood)
		b.name = "C8_LooseWood_%d" % i
		market.add_child(b)
		b.position = [Vector3(9.05, 0.06, 16.05), Vector3(7.15, 0.06, 16.3), Vector3(8.6, 0.09, 15.85)][i]
		b.rotation.y = [0.6, -0.35, 1.2][i]
		_boards_loose.append(b)
	# claw marks on the leaf's inner face by the latch edge (children of the leaf: they swing with it)
	var bd: Node3D = p4.its.get("back_door")
	if bd:
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.05, 0.045, 0.04)
		dark.roughness = 1.0
		for i in 4:
			var m := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.018, 0.42, 0.006)
			m.mesh = bm
			m.material_override = dark
			m.name = "C8_ClawMark_%d" % i
			bd.add_child(m)
			m.global_transform = market.global_transform * Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(14.0 + i * 3.0)),
				Vector3(8.22 + i * 0.055, 1.05 + i * 0.03, 17.43))


func _plank(size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	return m


func _setup_materials() -> void:
	var wood: Material = load(WOOD)
	var boards := Node3D.new()
	boards.name = "C8_Boards"
	market.add_child(boards)
	boards.position = BOARDS_POS
	for i in 3:
		var b := _plank(Vector3(1.4, 0.028, 0.14), wood)
		boards.add_child(b)
		b.position = Vector3(0.0, 0.016 + i * 0.03, (i - 1) * 0.02)
		b.rotation.y = (i - 1) * 0.06
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.4, 0.12, 0.3)
	cs.shape = bx
	var body := StaticBody3D.new()
	body.add_child(cs)
	cs.position.y = 0.06
	boards.add_child(body)
	_pickup(boards, "boards", "repair_boards", "Boards")
	var tape := TAPE.instantiate() as Node3D
	tape.name = "C8_DuctTape"
	market.add_child(tape)
	tape.position = TAPE_POS
	_pickup(tape, "tape", "duct_tape", "Duct Tape")
	var hammer := HAMMER.instantiate() as Node3D
	hammer.name = "C8_Hammer"
	market.add_child(hammer)
	hammer.position = HAMMER_POS
	hammer.rotation.y = 0.5
	_pickup(hammer, "hammer", "hammer", "Hammer")
	_settle.call_deferred([tape, hammer])


func _pickup(n: Node3D, key: String, item: String, label: String) -> void:
	var it := Interactable.attach(n, {"kind": "pickup", "label": label, "item_id": item, "state_key": "ch8/" + key})
	# generous targeting: at least 0.5 m around the item
	var c := it.get_child(0) as CollisionShape3D
	var bs := c.shape as BoxShape3D
	bs.size = bs.size.max(Vector3(0.5, 0.4, 0.5))
	it.used.connect(func(_b): _got_material(key))
	its["mat_" + key] = it


## Items rest on the surface below them (counter top, pallet top): a ray down against the world colliders.
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
		var top := node.global_position + Vector3.UP * 0.4
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top, node.global_position - Vector3.UP * 1.6, 1, ex))
		if hit:
			node.global_position.y = (hit["position"] as Vector3).y + 0.002
			var it := node.get_node_or_null("Interact") as Interactable
			if it:
				it._base = node.transform


## The maintenance panel is Chapter 4's breaker (its interaction box is re-used, the Chapter 4 handler detached).
func _setup_panel() -> void:
	var br: Interactable = p4.its.get("breaker")
	if br == null:
		return
	if br.used.is_connected(p4._throw_breaker):
		br.used.disconnect(p4._throw_breaker)
	br.used.connect(_use_panel)
	its["panel"] = br


func _setup_attack_props() -> void:
	# the pallet stack the player pushes across the back doorway (starts in the aisle by the doorway)
	_secure_pallet = PALLET.instantiate() as Node3D
	_secure_pallet.name = "C8_SecurePallet"
	market.add_child(_secure_pallet)
	_secure_pallet.position = SECURE_START
	_secure_pallet.scale = SECURE_SCALE
	var it := Interactable.attach(_secure_pallet, {"kind": "custom", "label": "Pallets", "prompt_text": ""})
	it.used.connect(_push_secure)
	its["secure"] = it
	# while the Hound guards the opening, nobody walks into the back corridor through it
	_blocker = StaticBody3D.new()
	_blocker.name = "C8_DoorwayBlock"
	var cs := CollisionShape3D.new()
	var bb := BoxShape3D.new()
	bb.size = Vector3(1.8, 2.4, 0.3)
	cs.shape = bb
	_blocker.add_child(cs)
	market.add_child(_blocker)
	_blocker.position = Vector3(DOORWAY.x, 1.2, 14.3)
	_injured_box = BOX.instantiate() as Node3D
	_injured_box.name = "C8_InjuredSeat"
	market.add_child(_injured_box)
	_injured_box.position = INJURED_BOX
	_front_box = BOX.instantiate() as Node3D
	_front_box.name = "C8_FrontSeat"
	market.add_child(_front_box)
	_front_box.position = FRONT_BOX


func _setup_rest() -> void:
	var r: VeilRestPoint = p4.rest
	if r == null:
		return
	if r.slept.is_connected(c7._on_rest):
		r.slept.disconnect(c7._on_rest)
	r.can_rest = func() -> bool: return Game.has_flag("chapter_8_complete")
	r.slept.connect(_on_rest)


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	_place_npcs()
	_apply_barricade()
	_apply_lights()
	var attack_open := Game.has_flag("ch8_temp_survivor_died") and not Game.has_flag("ch8_entrance_secured")
	_set_blocker(attack_open)
	_secure_pallet.visible = Game.has_flag("ch8_attack_started") or Game.has_flag("ch8_entrance_secured")
	_secure_pallet.position = SECURE_BLOCK if Game.has_flag("ch8_entrance_secured") else SECURE_START
	_set_collision(_secure_pallet, _secure_pallet.visible)
	_injured_box.visible = Game.has_flag("ch8_sarah_injured") and not Game.has_flag("ch8_survivor_helped")
	_set_collision(_injured_box, _injured_box.visible)
	_front_box.visible = Game.has_flag("ch8_survivor_helped")
	_set_collision(_front_box, _front_box.visible)
	var staff: Interactable = p4.its.get("INT_Door_Staff")
	if staff:
		staff.collision_layer = 0 if attack_open else 8
		if attack_open and staff.is_open:
			staff.set_open(false, true)
	if attack_open:
		_spawn_hound_guard()
	elif hound and is_instance_valid(hound):
		hound.queue_free()
		hound = null
	if p4.rest:
		p4.rest.get_parent().visible = true
		p4.rest.interactable.prompt_text = "[E] Sleep" if Game.has_flag("chapter_8_complete") else ""
	_refresh_prompts()
	_guide()


func _set_collision(n: Node, on: bool) -> void:
	for co in n.find_children("*", "CollisionObject3D", true, false):
		if co is Interactable:
			continue
		(co as CollisionObject3D).collision_layer = 1 if on else 0


func _set_blocker(on: bool) -> void:
	_blocker.collision_layer = 1 if on else 0


func _show(n: Node3D, at: Vector3, toward: Vector3) -> void:
	c5._reparent(n, market)
	n.visible = true
	var a = world.animators.get(String(n.name))
	if a:
		a.set_seated(false)
		a.turn_to_face = true
	world.place_survivor(n, at)
	if a:
		a.face_towards(ml(toward))


## Where everyone is, from the flags (fresh start and loads). walk_marcus: Marcus (next to the player at the
## barricade when the lights go) walks to his spot instead of being placed there.
func _place_npcs(walk_marcus := false) -> void:
	var died := Game.has_flag("ch8_temp_survivor_died")
	if Game.has_flag("ch8_survivor_helped"):
		_gather_positions()
	elif died:
		_show(eddie, PRE_EDDIE, DOORWAY)
		_show(marcus, POST_MARCUS, DOORWAY)
		_show(ruth, RUTH_BY_SARAH, INJURED_BOX)
		_seat_on(sarah, _injured_box, INJURED_BOX, INJURED_BOX + Vector3(0, 0, -2.0))
	elif Game.has_flag("ch8_power_failed"):
		_show(eddie, PRE_EDDIE, DOORWAY)
		if walk_marcus:
			world.npc_walk("Marcus", PRE_MARCUS, 1.3)
		else:
			_show(marcus, PRE_MARCUS, DOORWAY)
		_show(ruth, PRE_RUTH, DOORWAY)
		_show(sarah, PRE_SARAH, DOORWAY)
		_show(temp, PRE_TEMP, DOORWAY)
	else:
		_show(eddie, EDDIE_SPOT, Vector3(2.0, 1.5, 0.0))
		_show(marcus, MARCUS_BACK, BARRICADE_LOOK)
		_show(ruth, RUTH_SPOT, Vector3(2.0, 1.5, 4.0))
		_show(sarah, SARAH_SPOT, Vector3(8.6, 1.5, 6.8))
		_show(temp, TEMP_SPOT, Vector3(0.0, 1.5, 4.0))
	if died:
		temp.visible = false                          # caught in the attack: gone (no body, no gore)
	for n in [eddie, marcus, ruth, sarah, temp]:
		var a = world.animators.get(String(n.name))
		if a:
			a.set_mood("scared" if Game.has_flag("ch8_barricade_inspected") else "calm")


func _gather_positions() -> void:
	for k in GATHER:
		var n: Node3D = {"Eddie": eddie, "Ruth": ruth, "Marcus": marcus}[k]
		_show(n, GATHER[k], FRONT_BOX)
	_seat_on(sarah, _front_box, FRONT_BOX, GATHER_CENTRE + Vector3(1.0, 0, 0))


## Seat an NPC on a box (front edge, facing `toward`), like the Chapter 4 stock-room seats.
func _seat_on(n: Node3D, box: Node3D, at: Vector3, toward: Vector3) -> void:
	c5._reparent(n, market)
	n.visible = true
	var a = world.animators.get(String(n.name))
	if a == null:
		world.place_survivor(n, at)
		return
	var to2 := toward - at
	to2.y = 0.0
	var top := 0.42
	if box:
		var bb := Interactable.aabb_of(box)
		top = bb.end.y * box.scale.y
	a.walk_to([])
	_set_collision(box, false)                      # the seat's own collider would refuse the body on top of it
	if not world.place_survivor(n, at + to2.normalized() * 0.18):
		world.place_survivor(n, at + to2.normalized() * 0.6)
	_set_collision(box, box.visible)
	a.turn_to_face = false
	n.rotate_y(a.world_forward().signed_angle_to((market.global_transform.basis * to2).normalized(), Vector3.UP))
	a.set_seated(true, top)
	a.set_mood("scared")


func _apply_barricade() -> void:
	var bd: Node3D = p4.its.get("back_door")
	var pal: Node3D = p4._pallets.get("back")
	var state := String(st().get("barricade", "damaged"))
	var base: Transform3D = p4._base.get("back", bd.transform if bd else Transform3D())
	var deg := 0.0
	match state:
		"repaired":
			deg = 0.0
		"broken":
			deg = 34.0
		_:
			deg = 6.0
	if bd:
		var d: float = world._toward_deg(bd, deg, ml(DOOR_INSIDE)) if deg > 0.0 else 0.0
		bd.transform = Transform3D(base.basis * Basis(Vector3.UP, deg_to_rad(d)), base.origin)
	if pal:
		match state:
			"repaired":
				pal.position = BACK_PALLET_BLOCK
				pal.rotation.y = 0.0
			"broken":
				pal.position = BACK_PALLET_BROKEN
				pal.rotation.y = 0.55
			_:
				pal.position = BACK_PALLET_DAMAGED
				pal.rotation.y = 0.2
	for b in _boards_up:
		(b as Node3D).visible = state == "repaired"
	for i in _boards_loose.size():
		var b: Node3D = _boards_loose[i]
		b.visible = state != "repaired"
	report["barricade"] = state


func _apply_lights() -> void:
	if Game.has_flag("ch8_power_restored"):
		_lights("partial")
	elif Game.has_flag("ch8_power_failed"):
		_lights("out")
	else:
		_lights("normal")


## normal: Chapter 4's emergency lighting; out: everything dark but one dying tube by the panel; partial: some back.
func _lights(mode: String) -> void:
	p4._set_power(true)
	for l in p4._lights:
		var light := l as Light3D
		if not light.visible:
			continue
		match mode:
			"out":
				if light.name != "Light_BACK_30":
					light.visible = false
				else:
					light.light_energy *= 0.45
			"partial":
				if String(light.name) in PARTIAL_DARK:
					light.visible = false
	st()["power"] = {"normal": "on", "out": "failed", "partial": "partial"}[mode]
	report["lights_on"] = p4._lights.filter(func(l): return (l as Light3D).visible).size()


func _refresh_prompts() -> void:
	if its.has("npc_Eddie"):
		its["npc_Eddie"].prompt_text = "[E] Talk" if not Game.has_flag("ch8_eddie_talked") else ""
	if its.has("npc_Marcus"):
		its["npc_Marcus"].prompt_text = ""
	if its.has("barricade"):
		var t := ""
		if Game.has_flag("ch8_eddie_talked") and not Game.has_flag("ch8_barricade_inspected"):
			t = "[E] Inspect the Barricade"
		elif Game.has_flag("ch8_barricade_inspected") and not Game.has_flag("ch8_barricade_repaired"):
			t = "[E] Repair the Barricade"
		its["barricade"].prompt_text = t
	if its.has("panel"):
		var p := ""
		if Game.has_flag("ch8_power_failed") and not Game.has_flag("ch8_power_restored"):
			p = "[E] Reseat the Loose Cable" if Game.has_flag("ch8_panel_inspected") else "[E] Inspect the Panel"
		its["panel"].prompt_text = p
	var secure_on := Game.has_flag("ch8_temp_survivor_died") and not Game.has_flag("ch8_entrance_secured")
	its["secure"].prompt_text = "[E] Push the Pallets Across the Doorway" if secure_on else ""
	its["secure"].collision_layer = 8 if secure_on else 0
	var help_on := Game.has_flag("ch8_entrance_secured") and not Game.has_flag("ch8_survivor_helped")
	its["sarah"].prompt_text = "[E] Help Sarah" if help_on else ""
	its["sarah"].collision_layer = 8 if help_on else 0
	for k in ["boards", "tape", "hammer"]:
		var it: Interactable = its["mat_" + k]
		if not it.taken:
			world._glow(it.target, Game.has_flag("ch8_barricade_inspected"))


func _materials_count() -> int:
	var n := 0
	for k in ["boards", "tape", "hammer"]:
		if its["mat_" + k].taken:
			n += 1
	return n


## Beacon + HUD marker: only the current destination; the objective line shows the materials count.
func _guide() -> void:
	var t: Variant = null
	var label := ""
	if not Game.has_flag("ch8_eddie_talked"):
		t = eddie
		label = "EDDIE"
	elif not Game.has_flag("ch8_barricade_inspected"):
		t = ml(BARRICADE_LOOK)
		label = "BACK ENTRANCE"
	elif not Game.has_flag("ch8_materials_collected"):
		var best: Variant = null
		var best_d := INF
		for k in ["boards", "tape", "hammer"]:
			var it: Interactable = its["mat_" + k]
			if it.taken:
				continue
			var d: float = it.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = it.global_position + Vector3(0, 0.3, 0)
				label = it.label.to_upper()
		t = best
	elif not Game.has_flag("ch8_barricade_repaired"):
		t = ml(BARRICADE_LOOK)
		label = "BARRICADE"
	elif Game.has_flag("ch8_power_failed") and not Game.has_flag("ch8_power_restored"):
		t = ml(PANEL)
		label = "PANEL"
	elif Game.has_flag("ch8_power_restored") and not Game.has_flag("ch8_attack_started"):
		t = ml(Vector3(8.2, 1.4, 10.0))
		label = "THE OTHERS"
	elif Game.has_flag("ch8_temp_survivor_died") and not Game.has_flag("ch8_entrance_secured") and not _busy.get("secure", false):
		t = _secure_pallet.global_position + Vector3(0, 1.3, 0)
		label = "PALLETS"
	elif Game.has_flag("ch8_entrance_secured") and not Game.has_flag("ch8_survivor_helped"):
		t = sarah
		label = "SARAH"
	elif Game.has_flag("ch8_survivor_helped") and not Game.has_flag("ch8_aftermath_complete") and not _busy.get("after", false):
		t = ml(GATHER_CENTRE + Vector3(0, 1.4, 0))
		label = "THE OTHERS"
	if hud.has_method("set_marker"):
		hud.set_marker(t, label)
	var step := Game.current_step()
	if String(step.get("id", "")) == "c8_materials" and hud.has_method("set_objective"):
		var txt := "%s (%d/3)" % [step.get("text", ""), _materials_count()]
		if txt != _obj_txt:
			_obj_txt = txt
			hud.set_objective(Game.current_goal(), txt)


var _obj_txt := ""


# ------------------------------------------------------------------ scene 1: Eddie
func _talk_eddie(_b: Node) -> void:
	if Game.has_flag("ch8_eddie_talked") or _busy.get("talk", false) or not Game.has_flag("ch8_started"):
		return
	_busy["talk"] = true
	its["npc_Eddie"].prompt_text = ""
	await c5._talk("c8_eddie", eddie)
	Game.set_flag("ch8_eddie_talked")
	_busy["talk"] = false
	_refresh_prompts()
	_guide()


func _talk_marcus(_b: Node) -> void:
	pass                                              # Marcus talks at the barricade (scene 2) and after the repair


# ------------------------------------------------------------------ scenes 2-3: the barricade
func _use_barricade(_b: Node) -> void:
	if not Game.has_flag("ch8_eddie_talked") or _busy.get("barricade", false):
		return
	if not Game.has_flag("ch8_barricade_inspected"):
		_inspect_barricade()
	elif not Game.has_flag("ch8_barricade_repaired"):
		if _materials_count() < 3:
			if hud.has_method("set_hint"):
				hud.set_hint("Boards, tape and a tool: %d of 3 found" % _materials_count())
				_clear_hint_later()
			return
		_repair()


func _clear_hint_later() -> void:
	await get_tree().create_timer(3.0).timeout
	if hud.has_method("set_hint"):
		hud.set_hint("")


func _inspect_barricade() -> void:
	_busy["barricade"] = true
	its["barricade"].prompt_text = ""
	_hold(true)
	_play("creak", ml(BARRICADE_LOOK), -2.0)
	await _turn_to(ml(Vector3(8.1, 1.05, 17.35)), 0.6)
	await get_tree().create_timer(0.9).timeout
	_play("creak", ml(BARRICADE_LOOK), -5.0)
	await get_tree().create_timer(0.5).timeout
	_hold(false)
	await c5._talk("c8_marcus_damage", marcus)
	Game.set_flag("ch8_barricade_inspected")
	_busy["barricade"] = false
	if _materials_count() == 3:
		Game.set_flag("ch8_materials_collected")
	_refresh_prompts()
	_guide()


func _got_material(key: String) -> void:
	Game.set_flag("ch8_got_" + key)
	world._glow(its["mat_" + key].target, false)
	if _materials_count() == 3 and Game.has_flag("ch8_barricade_inspected"):
		Game.set_flag("ch8_materials_collected")
	_obj_txt = ""
	_refresh_prompts()
	_guide()


## First person: the pallets go back on their spot (three shoves), three boards across the leaf (hammer knocks).
func _repair() -> void:
	_busy["barricade"] = true
	its["barricade"].prompt_text = ""
	_hold(true)
	await _turn_to(ml(Vector3(8.0, 1.0, 17.2)), 0.5)
	var pal: Node3D = p4._pallets.get("back")
	if pal:
		var tw := create_tween()
		for i in 2:
			var a: Vector3 = pal.position.lerp(BACK_PALLET_BLOCK, 0.5 * i)
			tw.tween_callback(p4._play.bind("scrape", ml(a), -6.0 - 2.0 * i))
			tw.tween_property(pal, "position", pal.position.lerp(BACK_PALLET_BLOCK, 0.5 * (i + 1)), 0.5).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(pal, "rotation:y", lerpf(pal.rotation.y, 0.0, 0.5 * (i + 1)), 0.45)
			tw.tween_interval(0.2)
		await tw.finished
	for b in _boards_loose:
		(b as Node3D).visible = false
	await _turn_to(ml(Vector3(8.0, 1.6, 17.4)), 0.4)
	for i in _boards_up.size():
		var b: Node3D = _boards_up[i]
		b.visible = true
		for k in 3:
			p4._play("impact", ml(b.position), -14.0)
			await get_tree().create_timer(0.28).timeout
		await get_tree().create_timer(0.2).timeout
	Game.remove_item("repair_boards")
	Game.remove_item("duct_tape")                     # the hammer stays in the inventory
	st()["barricade"] = "repaired"
	_apply_barricade()
	_hold(false)
	await c5._talk("c8_repaired", marcus)
	Game.set_flag("ch8_barricade_repaired")
	_busy["barricade"] = false
	_refresh_prompts()
	_power_fail()


# ------------------------------------------------------------------ scene 4: the lights fail, the panel
func _power_fail() -> void:
	if Game.has_flag("ch8_power_failed") or _busy.get("power", false):
		return
	_busy["power"] = true
	_play("hum", ml(Vector3(8.0, 3.0, 12.0)), 0.0)
	await p4._flicker_burst(1.4)
	for n in ["Light_SALES_30", "Light_BACK_30", "Light_SALES_00", "Light_BACK_10", "Light_SALES_20"]:
		var l := market.get_node_or_null("Lights/" + n) as Light3D
		if l:
			l.visible = false
		await get_tree().create_timer(0.22).timeout
	_lights_all(false)                               # a moment of complete darkness
	await get_tree().create_timer(1.3).timeout
	Game.set_flag("ch8_power_failed")
	_lights("out")
	# in the dark, everyone moves up to the back aisle, where the next scene finds them
	_place_npcs(true)
	Dialogue.say("c8_power_fail", false, true)
	_busy["power"] = false
	_refresh_prompts()
	_guide()


func _lights_all(on: bool) -> void:
	for l in p4._lights:
		(l as Light3D).visible = on and (l as Light3D).visible


func _use_panel(_b: Node) -> void:
	if not Game.has_flag("ch8_power_failed") or Game.has_flag("ch8_power_restored") or _busy.get("panel", false):
		return
	_busy["panel"] = true
	its["panel"].prompt_text = ""
	_hold(true)
	await _turn_to(ml(PANEL), 0.5)
	if not Game.has_flag("ch8_panel_inspected"):
		_play("hum", ml(PANEL), -10.0)
		if hud.has_method("set_hint"):
			hud.set_hint("The main breaker has tripped. A cable has worked loose from its terminal.")
		await get_tree().create_timer(1.2).timeout
		Game.set_flag("ch8_panel_inspected")
		_hold(false)
		_busy["panel"] = false
		_refresh_prompts()
		return
	if hud.has_method("set_hint"):
		hud.set_hint("")
	var ps := load(SPARKS) as PackedScene
	if ps:
		var sp := ps.instantiate() as Node3D
		market.add_child(sp)
		sp.position = PANEL + Vector3(0, 0.1, -0.12)
		get_tree().create_timer(1.2).timeout.connect(sp.queue_free)
	_play("spark", ml(PANEL), -2.0)
	await get_tree().create_timer(0.7).timeout
	Sfx.play("door_close", ml(PANEL), 2.0, 0.5)       # the breaker thrown back (Chapter 4's clunk)
	await get_tree().create_timer(0.5).timeout
	Game.set_flag("ch8_power_restored")
	_lights("partial")
	p4._flicker_burst(0.8)
	_hold(false)
	_busy["panel"] = false
	_refresh_prompts()
	_guide()
	Dialogue.say("c8_power_back", false, true)


# ------------------------------------------------------------------ scenes 5-6: something outside, the attack
func _attack_tick() -> void:
	if not Game.has_flag("ch8_power_restored") or Game.has_flag("ch8_attack_started") or _busy.get("attack", false):
		return
	var pl: Vector3 = market.to_local(player.global_position)
	# back on the sales floor and on the way down toward the front (well away from the doorway)
	if pl.z < ATTACK_TRIGGER_Z and pl.z > 3.6 and pl.x > -21.0 and pl.x < 21.0 and not Dialogue.is_busy() and not world.conversing:
		_run_attack()


func _run_attack() -> void:
	if _busy.get("attack", false) or Game.has_flag("ch8_temp_survivor_died"):
		return
	_busy["attack"] = true
	attack_runs += 1
	Game.set_flag("ch8_attack_started")
	world.end_conversation()
	_hold(true)
	_refresh_prompts()
	hud.set_marker(null, "")
	for n in [eddie, marcus, ruth, sarah, temp]:
		var a = world.animators.get(String(n.name))
		if a:
			a.set_mood("scared")
			a.face_towards(ml(DOORWAY))
	# 1. a heavy thud from the rear exit, then silence
	await _turn_to(ml(Vector3(DOORWAY.x, 1.45, 15.5)), 0.7)
	await _impact(0.6)
	await get_tree().create_timer(2.4).timeout
	Dialogue.say("c8_impact", false, true)
	# 2. another one
	await get_tree().create_timer(1.6).timeout
	await _impact(0.8)
	world.npc_walk("Survivor", CAUGHT_AT, 1.0)          # the temporary survivor goes to look (the others back away)
	world.npc_walk("Marcus", PRE_MARCUS + Vector3(0.8, 0, -0.5), 1.2)
	world.npc_walk("Sarah", PRE_SARAH + Vector3(-0.2, 0, -0.3), 1.0)
	while Dialogue.is_busy():
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	# 3. the third: the barricade partly gives way (pallets shoved aside, boards down, the leaf forced open)
	await _impact(1.0)
	_give_way()
	# the others back away toward the front of the store
	world.npc_walk("Eddie", PRE_EDDIE + Vector3(-0.8, 0, -1.0), 1.6)
	world.npc_walk("Ruth", PRE_RUTH + Vector3(0.4, 0, -1.2), 1.6)
	await get_tree().create_timer(0.9).timeout
	# 4. it comes through: straight at whoever is in the doorway
	await _hound_burst()
	_busy["attack"] = false


func _impact(strength: float) -> void:
	p4._play("impact", ml(Vector3(8.0, 1.05, 17.0)), 4.0 + 4.0 * strength)
	p4._play("rattle", ml(Vector3(6.6, 1.2, 12.8)), -6.0 + 4.0 * strength)
	p4._flicker_burst(0.4 + 0.4 * strength)
	_dust(ml(Vector3(8.0, 2.3, 17.25)), int(30 * strength) + 10)
	_dust(ml(Vector3(DOORWAY.x, 2.5, 14.2)), int(16 * strength))
	var cam := get_viewport().get_camera_3d()
	if cam and world.has_method("_shake"):
		world._shake(cam, 0.35, 0.012 * strength)
	var bd: Node3D = p4.its.get("back_door")
	var pal: Node3D = p4._pallets.get("back")
	var tw := create_tween()
	if bd:
		var t0: Transform3D = bd.transform
		tw.tween_property(bd, "transform", Transform3D(t0.basis * Basis(Vector3.UP, deg_to_rad(-2.0 * strength)), t0.origin), 0.05)
		tw.tween_property(bd, "transform", t0, 0.14)
	if pal:
		var p0: Vector3 = pal.position
		tw.parallel().tween_property(pal, "position", p0 + Vector3(0, 0, -0.06 * strength), 0.05)
		tw.tween_property(pal, "position", p0, 0.25)
	for b in _boards_up:
		var bn := b as Node3D
		var r0 := bn.rotation
		tw.parallel().tween_property(bn, "rotation:z", r0.z + 0.03 * strength, 0.06)
	await tw.finished
	for b in _boards_up:
		(b as Node3D).rotation.z = clampf((b as Node3D).rotation.z, -0.2, 0.2)
	report["impacts"] = int(report.get("impacts", 0)) + 1


func _give_way() -> void:
	st()["barricade"] = "broken"
	var bd: Node3D = p4.its.get("back_door")
	var pal: Node3D = p4._pallets.get("back")
	var tw := create_tween().set_parallel(true)
	if pal:
		tw.tween_property(pal, "position", BACK_PALLET_BROKEN, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(pal, "rotation:y", 0.55, 0.35)
	if bd:
		var base: Transform3D = p4._base["back"]
		var d: float = world._toward_deg(bd, 34.0, ml(DOOR_INSIDE))
		tw.tween_property(bd, "transform", Transform3D(base.basis * Basis(Vector3.UP, deg_to_rad(d)), base.origin), 0.3)
	for i in _boards_up.size():
		var b: Node3D = _boards_up[i]
		var loose: Node3D = _boards_loose[i]
		tw.tween_property(b, "position", loose.position + Vector3(0, 0.03, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(b, "rotation", Vector3(0, loose.rotation.y, 0), 0.45)
	p4._play("scrape", ml(Vector3(8.6, 0.5, 16.6)), 2.0)
	await tw.finished
	_apply_barricade()


func _hound_burst() -> void:
	hound = _make_hound(HOUND_OUT)
	var h := hound
	_hplay(h, "Run", 6.0)
	_bark(ml(Vector3(8.0, 1.0, 18.5)))
	await _hound_run(h, [Vector3(8.0, 0.0, 16.1), Vector3(8.4, 0.0, 14.8), Vector3(8.35, 0.0, 14.05)], 6.5)
	# the lunge: Attack_Bite at the survivor in the doorway
	_hplay(h, "Attack_Bite", 0.0)
	p4._play("impact", ml(CAUGHT_AT + Vector3(0, 1.0, 0)), 0.0)
	_bark(ml(CAUGHT_AT + Vector3(0, 1.2, 0)))
	var ta = world.animators.get("Survivor")
	if ta:
		ta.set_mood("scared")
	await get_tree().create_timer(0.35).timeout
	# a hard cut to black: the temporary survivor is dragged back through the doorway (no gore on screen)
	await hud.fade_to(1.0, 0.18)
	p4._play("scrape", ml(Vector3(8.2, 0.4, 15.5)), 4.0)
	_kill_temp()
	# Sarah was knocked down in the panic: she ends up on a crate by the coolers, hurt
	Game.set_flag("ch8_sarah_injured")
	st()["injured"] = "sarah"
	_injured_box.visible = true
	_set_collision(_injured_box, true)
	_place_npcs()
	if is_instance_valid(h):
		h.position = HOUND_GUARD
		h.rotation.y = PI
		_hplay(h, "Alert", 0.0)
	_set_blocker(true)
	_secure_pallet.visible = true
	_set_collision(_secure_pallet, true)
	var staff: Interactable = p4.its.get("INT_Door_Staff")
	if staff:
		staff.collision_layer = 0
		if staff.is_open:
			staff.set_open(false, true)
	await get_tree().create_timer(1.1).timeout
	await hud.fade_to(0.0, 0.7)
	_hold(false)
	_refresh_prompts()
	_guide()


func _kill_temp() -> void:
	if Game.has_flag("ch8_temp_survivor_died"):
		return
	deaths += 1
	Game.set_flag("ch8_temp_survivor_died")
	st()["casualty"] = "temporary_survivor"
	st()["casualty_was_ch5_survivor"] = Game.has_flag("c5_survivor_helped")
	temp.visible = false
	var ta = world.animators.get("Survivor")
	if ta:
		ta.walk_to([])


func _make_hound(at: Vector3) -> Node3D:
	var ps := load(HOUND_PATH) as PackedScene
	var h := ps.instantiate() as Node3D
	h.name = "C8_Hound"
	market.add_child(h)
	hound_spawns += 1
	if h is CollisionObject3D:
		(h as CollisionObject3D).collision_layer = 0
		(h as CollisionObject3D).collision_mask = 0
	h.set_physics_process(false)
	h.position = at
	h.rotation.y = PI                                   # the model faces +Z: into the store is -Z
	VeilCreatureLook.apply_skitter(h, h.global_position.y)
	var g := AudioStreamPlayer3D.new()
	g.name = "Growl"
	g.stream = c6._streams.get("growl")
	g.volume_db = -4.0
	g.unit_size = 6.0
	h.add_child(g)
	g.position = Vector3(0, 0.8, 0.8)
	if g.stream:
		g.play()
	return h


func _hap(h: Node3D) -> AnimationPlayer:
	return h.get_node_or_null(String(h.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer


func _hplay(h: Node3D, clip: String, speed: float) -> void:
	var ap := _hap(h)
	if ap == null or not ap.has_animation(clip):
		return
	ap.play(clip, 0.12)
	if clip == "Run" and speed > 0.0:
		ap.speed_scale = speed / maxf(float(h.get_meta("run_speed_mps", 5.0)) * h.scale.x, 0.1)
	else:
		ap.speed_scale = 1.0


func _hound_run(h: Node3D, pts: Array, speed: float) -> void:
	for p in pts:
		if not is_instance_valid(h):
			return
		var to: Vector3 = p
		var d := to - h.position
		d.y = 0.0
		if d.length() < 0.05:
			continue
		h.rotation.y = atan2(d.x, d.z)
		var tw := h.create_tween()
		tw.tween_property(h, "position", Vector3(to.x, h.position.y, to.z), d.length() / speed)
		await tw.finished


func _spawn_hound_guard() -> void:
	if hound and is_instance_valid(hound):
		return
	hound = _make_hound(HOUND_GUARD)
	_hplay(hound, "Alert", 0.0)


## While the doorway is open the Hound holds it: growls, and lunges at the opening every few seconds; a player
## standing right at the doorway is bitten (never fatally) and knocked back.
func _guard_tick(delta: float) -> void:
	if hound == null or not is_instance_valid(hound) or _busy.get("secure", false) or _busy.get("attack", false):
		return
	if Game.has_flag("ch8_entrance_secured") or not Game.has_flag("ch8_temp_survivor_died"):
		return
	_bite_t = maxf(_bite_t - delta, 0.0)
	_lunge_t -= delta
	if _lunge_t > 0.0 or _busy.get("lunge", false):
		return
	_lunge_t = randf_range(2.6, 4.2)
	_lunge()


func _lunge() -> void:
	_busy["lunge"] = true
	var h := hound
	_hplay(h, "Attack_Bite", 0.0)
	_bark(h.global_position + Vector3(0, 1.0, 0))
	var tw := h.create_tween()
	tw.tween_property(h, "position:z", HOUND_GUARD.z - 0.75, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	var pl: Vector3 = market.to_local(player.global_position)
	if Vector2(pl.x - DOORWAY.x, pl.z - 14.0).length() < 1.9 and _bite_t <= 0.0 and player.has_method("damage"):
		_bite_t = 2.0
		var hp = player.get("health")
		var dmg := 14.0 if hp == null else minf(14.0, maxf(float(hp) - 5.0, 0.0))
		player.damage(dmg, h.global_position)
		report["guard_bites"] = int(report.get("guard_bites", 0)) + 1
	if is_instance_valid(h):
		var tb := h.create_tween()
		tb.tween_property(h, "position:z", HOUND_GUARD.z, 0.5).set_trans(Tween.TRANS_SINE)
		await tb.finished
		_hplay(h, "Alert", 0.0)
	_busy["lunge"] = false


## Push the pallet stack across the doorway: three shoves (Chapter 4's pallet push), first person.
func _push_secure(_b: Node) -> void:
	if not Game.has_flag("ch8_temp_survivor_died") or Game.has_flag("ch8_entrance_secured") or _busy.get("secure", false):
		return
	_busy["secure"] = true
	its["secure"].prompt_text = ""
	_hold(true)
	hud.set_marker(null, "")
	while _busy.get("lunge", false):
		await get_tree().process_frame
	# the protagonist gets behind the stack (a short step, never through it), shoulder to it
	await _fp_move(PUSHER, 0.45)
	await _turn_to(ml(Vector3(SECURE_BLOCK.x, 0.9, 13.2)), 0.35)
	var pal := _secure_pallet
	var path := [SECURE_START, SECURE_START.lerp(Vector3(SECURE_BLOCK.x, 0.04, SECURE_START.z), 0.5),
		Vector3(SECURE_BLOCK.x, 0.04, SECURE_START.z), SECURE_BLOCK]
	for i in 3:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		p4._play("scrape", ml(a), -4.0 - 2.0 * i)
		var tw := create_tween()
		tw.tween_property(pal, "position", b, [0.6, 0.55, 0.45][i]).from(a).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(pal, "rotation:y", deg_to_rad([1.5, -1.0, 0.0][i]), 0.4)
		await tw.finished
		# the player follows the stack (one step behind it)
		if i < 2:
			await _fp_move(b + Vector3(1.75, 0, 0), 0.25)
		await get_tree().create_timer(0.2).timeout
	pal.position = SECURE_BLOCK
	pal.rotation.y = 0.0
	Sfx.play("door_close", ml(SECURE_BLOCK), -2.0, 0.55)
	# it hits the stack once from the other side, then gives up and goes back out into the mist
	var h := hound
	if h and is_instance_valid(h):
		_hplay(h, "Attack_Bite", 0.0)
		var tw2 := h.create_tween()
		tw2.tween_property(h, "position:z", 14.75, 0.2)
		await tw2.finished
		p4._play("impact", ml(SECURE_BLOCK + Vector3(0, 0.8, 0.5)), 4.0)
		var tp := create_tween()
		tp.tween_property(pal, "position", SECURE_BLOCK + Vector3(0, 0, -0.05), 0.05)
		tp.tween_property(pal, "position", SECURE_BLOCK, 0.25)
		await get_tree().create_timer(0.8).timeout
		if is_instance_valid(h):
			_hplay(h, "Run", 5.0)
			await _hound_run(h, [Vector3(8.0, 0.0, 16.2), HOUND_OUT + Vector3(0, 0, 3.0)], 5.0)
			if is_instance_valid(h):
				h.queue_free()
	hound = null
	_set_blocker(false)
	var staff: Interactable = p4.its.get("INT_Door_Staff")
	if staff:
		staff.collision_layer = 8
	Game.set_flag("ch8_entrance_secured")
	_hold(false)
	_busy["secure"] = false
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ scene 7: the injured survivor
func _medical_available() -> String:
	if Game.has_item("painkillers"):
		return "inventory"
	if int(Game.shelter_stock().get("medical", 0)) > 0:
		return "shelter"
	return ""


func _help_sarah(_b: Node) -> void:
	if not Game.has_flag("ch8_entrance_secured") or Game.has_flag("ch8_survivor_helped") or _busy.get("help", false):
		return
	_busy["help"] = true
	its["sarah"].prompt_text = ""
	var src := _medical_available()
	if src != "" and not Game.has_flag("ch8_medical_used"):
		# exactly one dose, whichever way the outcome is reached (the flag is set together with the deduction)
		if src == "inventory":
			Game.remove_item("painkillers")
		else:
			var stock := Game.shelter_stock()
			stock["medical"] = int(stock["medical"]) - 1
			Game.world_state["shelter_stock"] = stock
		medical_used += 1
		Game.set_flag("ch8_medical_used")
		st()["medical_source"] = src
		st()["injured_condition"] = "stable"
		Game.set_flag("ch8_sarah_treated")
		Sfx.play("pickup", sarah.global_position + Vector3(0, 0.6, 0), -8.0, 0.8)
		await _talk_group("c8_treated", [sarah, ruth])
	else:
		st()["injured_condition"] = "serious"           # stays hurt into the next chapters; never dies here
		Game.set_flag("ch8_sarah_untreated")
		await _talk_group("c8_untreated", [ruth, sarah, marcus])
	Game.set_flag("ch8_survivor_helped")
	_busy["help"] = false
	# a little later everyone has gathered at the front of the store (the screen dips while they move)
	_busy["after"] = true
	_hold(true)
	await hud.fade_to(1.0, 0.6)
	_apply()
	await get_tree().create_timer(0.6).timeout
	await hud.fade_to(0.0, 0.8)
	_hold(false)
	_busy["after"] = false
	_refresh_prompts()
	_guide()


func _talk_group(id: String, npcs: Array) -> void:
	var ok: bool = await world.converse([id], npcs)
	if not ok:
		Dialogue.say(id, false, true)
	await get_tree().process_frame
	while Dialogue.is_busy() or world.conversing:
		await get_tree().process_frame


# ------------------------------------------------------------------ scene 8: the aftermath, completion
func _gather_tick() -> void:
	if not Game.has_flag("ch8_survivor_helped") or Game.has_flag("ch8_aftermath_complete") or _busy.get("after", false) \
			or _busy.get("final", false) or world.conversing:
		return
	var pl: Vector3 = market.to_local(player.global_position)
	if Vector2(pl.x - GATHER_CENTRE.x, pl.z - GATHER_CENTRE.z).length() < 3.0:
		_aftermath()


func _aftermath() -> void:
	_busy["final"] = true
	var speakers := [marcus, eddie, ruth]
	var ok: bool = await world.converse(["c8_aftermath"], speakers)
	if not ok:
		Dialogue.say("c8_aftermath", false, true)
	await get_tree().process_frame
	while Dialogue.is_busy() or world.conversing:
		await get_tree().process_frame
	Game.set_flag("ch8_aftermath_complete")
	Game.set_flag("shelter_evacuation_concern")
	Game.set_flag("chapter_8_complete")              # Chapter 9 is NOT started here
	st()["completed"] = {"attack": true, "casualty": st().get("casualty", ""), "barricade": st().get("barricade", ""),
		"power": st().get("power", ""), "injured": st().get("injured", ""), "injured_condition": st().get("injured_condition", "")}
	_busy["final"] = false
	_refresh_prompts()
	_guide()
	if p4.rest:
		p4.rest.get_parent().visible = true
		p4.rest.interactable.prompt_text = "[E] Sleep"
	await hud.title_card("CHAPTER 8 COMPLETE  -  SOMETHING AT THE DOORS", 3.2)


func _on_rest(_id: String) -> void:
	var r: Dictionary = p4.record_night("ch8_rested")
	Game.set_flag("ch8_rested")                      # the Chapter 9 checkpoint; nothing starts yet
	if p4.flashlight:
		p4.flashlight.set_on(false)
	await get_tree().create_timer(1.0).timeout
	await hud.fade_to(0.0, 2.0)
	player.set("controls_enabled", true)
	p4.show_night_report(r)
	p4.rest.interactable.prompt_text = "[E] Sleep"


# ------------------------------------------------------------------ first-person helpers
func _hold(on: bool) -> void:
	player.set("controls_enabled", not on)
	player.velocity = Vector3.ZERO


## Turn the first-person view toward a world point (yaw + pitch eased), control stays held by the caller.
func _turn_to(at: Vector3, seconds: float) -> void:
	var eye: Vector3 = player.camera.global_position
	var v := (at - eye).normalized()
	var yaw1 := atan2(-v.x, -v.z)
	var pitch1 := clampf(asin(clampf(v.y, -1.0, 1.0)), -0.7, 0.5)
	var yaw0: float = player.rotation.y
	var pitch0: float = player.head.rotation.x
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		var k := smoothstep(0.0, 1.0, clampf(t / seconds, 0.0, 1.0))
		player.set_yaw_pitch(lerp_angle(yaw0, yaw1, k), lerpf(pitch0, pitch1, k))
		await get_tree().process_frame
	player.set_yaw_pitch(yaw1, pitch1)


## A short scripted step (feet on the floor); the player's own physics paused meanwhile.
func _fp_move(to_local: Vector3, seconds: float) -> void:
	var from: Vector3 = player.global_position
	var to := ml(to_local)
	to.y = from.y
	player.set_physics_process(false)
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		player.global_position = from.lerp(to, smoothstep(0.0, 1.0, clampf(t / seconds, 0.0, 1.0)))
		await get_tree().process_frame
	player.global_position = to
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)


func _dust(at: Vector3, amount: int) -> void:
	if amount <= 0:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.6
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.6, 0.05, 0.1)
	p.direction = Vector3(0, -1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0, -2.2, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.55, 0.52, 0.48, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.mesh = q
	world.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)


func _bark(at: Vector3) -> void:
	if c6.has_method("_play") and c6._streams.has("bark"):
		c6._play("bark", at, 0.0)


# ------------------------------------------------------------------ per tick
func _process(delta: float) -> void:
	_guard_tick(delta)
	_tick -= delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	_attack_tick()
	_gather_tick()
	_guide()
	if hound and is_instance_valid(hound) and not _busy.get("attack", false):
		var g := hound.get_node_or_null("Growl") as AudioStreamPlayer3D
		if g and not g.playing and g.stream:
			g.play()


# ------------------------------------------------------------------ sounds (synthesised)
func _make_sounds() -> void:
	_streams["creak"] = Sfx._make(1.6, _creak_wave)
	_streams["hum"] = Sfx._make(2.6, _hum_wave)
	_streams["spark"] = Sfx._make(0.8, _spark_wave)


## old wood under strain: a slow, irregular groan
func _creak_wave(t: float, i: int) -> float:
	var env := sin(PI * clampf(t / 1.6, 0.0, 1.0))
	var f := 95.0 + 40.0 * sin(t * 3.1) + 15.0 * sin(t * 11.0)
	return (sin(TAU * f * t) * 0.35 + Sfx._noise(i) * 0.12) * env * (0.6 + 0.4 * sin(t * 23.0))


## mains hum rising, then sagging as the power goes
func _hum_wave(t: float, i: int) -> float:
	var env := clampf(t * 3.0, 0.0, 1.0) * clampf((2.6 - t) * 1.5, 0.0, 1.0)
	var sag := 1.0 - clampf((t - 1.6) / 1.0, 0.0, 0.4)
	return (sin(TAU * 60.0 * sag * t) * 0.5 + sin(TAU * 120.0 * sag * t) * 0.25 + Sfx._noise(i) * 0.04) * env


func _spark_wave(t: float, i: int) -> float:
	var crack := exp(-fposmod(t * 9.0, 1.0) * 20.0)
	return Sfx._noise(i) * 0.7 * crack * exp(-t * 2.5)


func _play(id: String, at: Vector3, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = db
	p.unit_size = 8.0
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
