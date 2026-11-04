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
const SERVICE_FLASHLIGHT := Vector3(5.7, 1.09, 5.8)       # customer service counter (Interaction/Counter_48)
const SERVICE_BATTERIES := Vector3(6.3, 1.09, 5.8)
const BREAKER := Vector3(19.83, 1.24, 14.9)               # RES_ElectricalPanel face (x 19.77-19.90, y 0.94-1.54)
const LOADING_HANDLE := Vector3(19.55, 0.9, 16.35)          # clear of the breaker panel (z 14.7-15.1)
const BACKDOOR_HANDLE := Vector3(8.0, 1.05, 17.0)          # covers the ajar leaf as well
const LOADING_PALLET := [Vector3(17.9, 0.04, 16.8), Vector3(19.3, 0.04, 16.45), PI * 0.5]   # start, blocking, yaw
const BACK_PALLET := [Vector3(10.4, 0.04, 15.9), Vector3(8.0, 0.04, 16.95), 0.0]
const BEDROLL := Vector3(-18.4, 0.04, 15.75)              # office floor, between the drawers and the desk
const EDDIE_POS := Vector3(-1.0, 0.04, 4.3)
const MARCUS_POS := Vector3(1.1, 0.04, 4.7)
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
	_make_sounds()
	_take_over_npcs()
	_setup_lights()
	_setup_doors()
	_setup_pickups()
	_setup_back_room()
	_setup_rest()
	Dialogue.choices_offered.connect(_on_choices)
	if Game.has_item("flashlight"):
		_attach_flashlight()
	if not Game.has_flag("p4_started"):
		Game.set_flag("p4_started")
		_apply()
		Dialogue.say("p4_start", false, true)
		world._beacon("p4", market.global_transform * (SERVICE_FLASHLIGHT + Vector3(0, 0.8, 0)), Color(0.8, 0.9, 1.0))
	else:
		_apply()
		if Game.has_flag("p4_talk_done") and not Game.has_flag("p4_threat_done"):
			_run_threat.call_deferred()            # an interrupted event plays again; completed ones never do
	hud.set_objective(Game.current_goal(), Game.current_step().get("text", ""))


func ml(p: Vector3) -> Vector3:
	return market.global_transform * p


# ------------------------------------------------------------------ setup
func _take_over_npcs() -> void:
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
			n.reparent(market, false)
		n.position = pair[2]
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
		"state_key": "p4/flashlight"})
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
	if not fl_it.taken:
		world._glow(fl, true)


func _setup_back_room() -> void:
	var br := _spot("P4_Breaker", BREAKER, Vector3(0.35, 0.75, 0.6), "[E] Throw the Breaker", _throw_breaker)
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
	var bl := BLANKET.instantiate() as Node3D
	bl.scale = Vector3(1.6, 1.0, 2.6)                  # unfolded into a makeshift bedroll
	bed.add_child(bl)
	var pl := PILLOW.instantiate() as Node3D
	pl.position = Vector3(-0.55, 0.0, 0.0)
	bed.add_child(pl)
	rest = REST_SCRIPT.new()
	rest.name = "RestPoint"
	rest.shelter_id = "supermarket_office"
	rest.prompt = "[E] Sleep"
	bed.add_child(rest)
	rest.setup(Vector3(1.6, 0.6, 1.0), choice, hud, player)
	rest.can_rest = func() -> bool: return Game.has_flag("p4_threat_done")
	rest.refused.connect(func(_id): Dialogue.say("p4_not_tired", false, true))
	rest.slept.connect(_on_slept)
	bed.visible = Game.has_flag("p4_threat_done")


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
		rest.interactable.prompt_text = "" if Game.has_flag("p4_slept") else "[E] Sleep"
	if Game.has_flag("p4_flashlight"):
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
	world._glow(its["flashlight"].target, false)
	world._clear_beacon("p4")
	_attach_flashlight()
	flashlight.set_on(true)
	Dialogue.say("p4_flashlight", false, true)


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


func _throw_breaker(_b: Node) -> void:
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
	var ld: Node3D = its["loading_door"]
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(ld, "transform", _base["loading"], 1.4)
	_play("rattle", ml(LOADING_HANDLE), -2.0)
	await tw.finished
	Game.set_flag("p4_loading_down")
	Dialogue.say("p4_loading_down", false, true)
	_check_exits()


func _close_back(_b: Node) -> void:
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
	var need := "p4_loading_down" if which == "loading" else "p4_backexit_closed"
	var done_flag := "p4_loading_secured" if which == "loading" else "p4_backexit_secured"
	if Game.has_flag(done_flag):
		return
	if not Game.has_flag(need):
		Dialogue.say("p4_need_close", false, true)
		return
	its["pallet_" + which].prompt_text = ""
	var spec: Array = LOADING_PALLET if which == "loading" else BACK_PALLET
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pallets[which], "position", spec[1], 1.6)
	_play("scrape", _pallets[which].global_position, -6.0)
	await tw.finished
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
	if not (Game.has_flag("p4_breaker") and Game.has_flag("p4_exits_secured")):
		Dialogue.say("p4_eddie_busy" if Game.has_flag("p4_breaker") else "p4_wait_talk", false, true)
		return
	for k in ["npc_Eddie", "npc_Marcus"]:
		its[k].prompt_text = ""
	Dialogue.say("p4_talk", false, true)


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
	await get_tree().create_timer(float(cfg.get("threat", {}).get("delay_after_talk", 5.0))).timeout
	_run_threat()


# ------------------------------------------------------------------ something outside (no combat)
func _run_threat() -> void:
	if _threat_running or Game.has_flag("p4_threat_done"):
		return
	_threat_running = true
	threat_runs += 1
	var anims: Dictionary = world.animators
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
	# 3. it hits the barricaded rear exit
	_play("impact", ml(BACKDOOR_HANDLE), 6.0)
	var bd: Node3D = its["back_door"]
	var tw := create_tween()
	for i in 3:
		tw.tween_property(bd, "transform", Transform3D(_base["back"].basis * Basis(Vector3.UP, deg_to_rad(-1.5 if i % 2 == 0 else 1.0)), _base["back"].origin), 0.06)
	tw.tween_property(bd, "transform", _base["back"], 0.08)
	_flicker_burst(1.0)
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
	Dialogue.say("p4_rest_hint", false, true)
	world._beacon("p4_rest", ml(BEDROLL + Vector3(0, 1.4, 0)), Color(0.8, 0.85, 1.0))


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
	hound.rotation.y = -PI * 0.5                          # walk along the glass towards +x
	var ap := hound.get_node_or_null(String(hound.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
	if ap and ap.has_animation("Walk"):
		ap.play("Walk")
		ap.speed_scale = 0.7
	var tw := hound.create_tween()
	tw.tween_property(hound, "position:x", 2.0, 6.0)
	tw.tween_property(hound, "position:z", -5.5, 1.2)


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


# ------------------------------------------------------------------ sleep -> Saturday
func _on_slept(_id: String) -> void:
	world._clear_beacon("p4_rest")
	Game.world_state["day"] = "saturday"
	Game.set_flag("p4_slept")
	if flashlight:
		flashlight.set_on(false)
	await get_tree().create_timer(1.0).timeout
	await hud.title_card("SATURDAY", 2.8)
	await hud.fade_to(0.0, 2.0)
	player.set("controls_enabled", true)
	Dialogue.say("p4_wake", false, true)
	await get_tree().create_timer(2.5).timeout
	hud.set_end_text("THE VEIL  -  ACT I", "You made it through the first night.",
		"Saturday continues in the next development phase.")
	hud.show_end(world.drive_time)


# ------------------------------------------------------------------ sounds (synthesised, original)
func _make_sounds() -> void:
	_streams["scrape"] = Sfx._make(2.6, _scrape_wave)
	_streams["impact"] = Sfx._make(1.2, _impact_wave)
	_streams["rattle"] = Sfx._make(1.4, _rattle_wave)


func _scrape_wave(t: float, i: int) -> float:
	var env := sin(PI * clampf(t / 2.6, 0.0, 1.0))
	return Sfx._noise(i) * 0.45 * env * (0.6 + 0.4 * sin(t * 37.0)) + sin(TAU * 140.0 * t + sin(t * 9.0) * 3.0) * 0.08 * env


func _impact_wave(t: float, i: int) -> float:
	return (sin(TAU * 48.0 * t) * 0.9 + Sfx._noise(i) * 0.6) * exp(-t * 6.0) + Sfx._noise(i) * 0.15 * exp(-t * 2.0)


func _rattle_wave(t: float, i: int) -> float:
	return Sfx._noise(i) * 0.35 * (0.5 + 0.5 * sin(t * 60.0)) * (1.0 - t / 1.4)


func _play(id: String, at: Vector3, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = db
	p.unit_size = 8.0
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
