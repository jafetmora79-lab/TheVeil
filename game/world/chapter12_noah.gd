extends Node
## THE VEIL - displayed Chapter 13, scene 13.0: THE NOAH RESCUE (story pass B4, approved; docs/story/B4_act4_ch12-14.md).
## Owned by chapter12.gd (the "Truth Beneath Greyhaven" chapter), which calls: eddie_talk() (Eddie's [E]), tick() (every 0.2 s), restore() (after a load),
## rescue_open() / active() (state), guide_target() (the objective marker).
##
## First light at the mill house: Eddie hands over the ribbon he took off the fence post (the mark + "KNOCK 3 + 1") -> who goes (Eddie, or alone; Marcus, if
## alive, comes and waits at the fence) -> the field to HOUSE_19, one Hound patrolling in front of it (the existing Hound AI; a bite or being found only sends
## the group back to the mill house to try again) -> the porch: [E] Knock (three short, one long) -> Noah behind the door asks a question only the family
## could answer (the bag: "the colour"; a keychain is the fallback) -> he opens -> his account, the farmer's journal -> Marcus's reunion, or the bereavement
## -> back to the mill house with Noah -> "why now, and why under the ground" (13.1) -> the chapter's own map talk goes on.
## State: flags ch12_rescue_started, ch12_ribbon_read, ch12_house19_entered, ch12_noah_found (repeat-safe milestone, checkpoint chapter12_noah),
## ch12_noah_home, ch12_below_explained; ch12_noah_na (the rescue does not apply to this storyline); Game.world_state["noah"] {status, role}.
## Noah is never a casualty: nothing here can hurt, lose or leave him behind.
const FOLLOW := preload("res://game/npc/companion_follow.gd")
const HOUND_AI := preload("res://game/enemies/hound_ai.gd")
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const OLD_PATH := "res://THE_VEIL_ASSETS_V2/06_Characters/Civilians/CHR_Ruth.glb"          # (the old-NPC fallback body; Noah is a Meshy model by default)
const OLD_FACE := "res://THE_VEIL_ASSETS_V2/06_Characters/Facial/Faces/T_Face_Ruth.png"
const NOAH_HOME_SPOT := Vector3(-1.5, 0.7, 7.3)          # mill-house local: the window end of the living room
const DOOR_NAME := "INT_Door_Front"
const KNOCK := [0.2, 0.35, 0.35, 0.85]                   # gaps before each knock: three short, one long
const SEE_FIRST := 62.0                                  # metres from the porch at which the Hound starts its rounds

var c12: Node
var world: Node
var player: Node3D
var hud: Node
var c9: Node
var c10: Node
var c11: Node
var p4: Node
var noah: Node3D
var noah_follow: VeilCompanionFollow
var hound: Node3D
var hound_ai: Node
var door_it: Interactable
var knock_it: Interactable
var companion := ""
var report := {"ribbon": false, "hound_resets": 0, "knock_tries": 0, "test_wrong": 0, "found": false, "home": false, "solo": false, "marcus_at_gate": false}
var _busy := {}
var _last_safe := Vector3.ZERO


func setup(chapter12: Node) -> void:
	c12 = chapter12
	world = c12.world
	player = c12.player
	hud = c12.hud
	c9 = c12.c9
	c10 = c12.c10
	c11 = c12.c11
	p4 = c12.p4
	if not Game.world_state.has("noah"):
		Game.world_state["noah"] = {"status": "unknown", "role": "", "companion": ""}


# ------------------------------------------------------------------ state
func noah_state() -> Dictionary:
	return Game.world_state.get("noah", {})


## The rescue may begin: the chapter is in its mill-house stage (fresh, or an older save still there) and it has not been done or ruled out.
func rescue_open() -> bool:
	return Game.has_flag("ch12_started") and not Game.has_flag("ch12_rescue_started") and not Game.has_flag("ch12_noah_found") and not Game.has_flag("ch12_noah_na") \
		and not Game.has_flag("chapter_12_complete") and not Game.has_flag("ch13_started") and not (Game.has_flag("ch12_set_out") and not Game.has_flag("ch12_returned"))


func active() -> bool:
	return Game.has_flag("ch12_rescue_started") and not Game.has_flag("ch12_noah_home")


func porch_point() -> Vector3:
	var d := _door()
	var out := _outward()
	return (d.global_position if d else c11.far_farm.global_position) + out * 1.7


func goal_point() -> Variant:
	if not Game.has_flag("ch12_ribbon_read"):
		return c12._node("Eddie")
	if not Game.has_flag("ch12_noah_found"):
		return porch_point() + Vector3(0, 1.5, 0)
	return c10.hl(c10.PORCH) + Vector3(0, 1.4, 0)


func _door() -> Node3D:
	return c11.far_farm.find_child(DOOR_NAME, true, false) as Node3D


## The way out of HOUSE_19's front door (the house's inside is +Z in its own space: the light and Noah's room, chapter11.gd FAR_LIGHT).
func _outward() -> Vector3:
	var b: Basis = c11.far_farm.global_transform.basis
	return (b * Vector3(0, 0, -1)).normalized()


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, c10._floor(p), p.z)


func _say(id: String) -> void:
	Dialogue.say(id, false, true)
	await get_tree().process_frame
	while Dialogue.is_busy():
		await get_tree().process_frame


func _talk(id: String, npcs: Array) -> void:
	await c9._talk_group(id, npcs)


# ------------------------------------------------------------------ Eddie's [E]: the ribbon, then reminders
func eddie_talk() -> bool:
	if _busy.get("ribbon", false) or _busy.get("knock", false) or _busy.get("arrive", false):
		return true
	if rescue_open():
		_ribbon()
		return true
	if active():
		c12._hint("First light. HOUSE_19: knock three short, one long.")
		return true
	return false


func _ribbon() -> void:
	_busy["ribbon"] = true
	Game.set_flag("ch12_rescue_started")
	Game.add_item("noahs_ribbon")
	Game.refresh_objective()
	var lost := Game.has_flag("ch9_marcus_lost")
	var npcs: Array = [c12._node("Eddie"), c12._node("Ruth")]
	if not lost:
		npcs.append(c12._node("Marcus"))
	await _talk("c12_ribbon_lost" if lost else "c12_ribbon_alive", npcs)
	Game.set_flag("ch12_ribbon_read")
	report["ribbon"] = true
	# who goes: Eddie (default) or alone; Marcus, alive, comes anyway and waits at the fence
	var i: int = await p4.choice.ask("TO HOUSE_19  -  WHO GOES?", ["Go with Eddie", "Go alone"], player)
	c12._hold(false)
	companion = "Eddie" if i == 0 else ""
	noah_state()["companion"] = companion
	if companion == "":
		report["solo"] = true
		await _say("c12_solo")
	for k in c12.group():
		if k == companion:
			c9._start_follow(k)
		elif k == "Marcus" and not lost:
			await _say("c12_marcus_insists")
			c9._start_follow(k)
		else:
			c12._stay_inside(k)
	_last_safe = player.global_position
	_busy["ribbon"] = false
	c12._guide()
	c12._hint("Cross the field to HOUSE_19. Crouch (Ctrl) and keep to the fences. It circles the two houses.")


# ------------------------------------------------------------------ the field, the Hound, the porch
func tick(_dt: float) -> void:
	if not active() or _busy.get("ribbon", false) or _busy.get("arrive", false):
		return
	var p := player.global_position
	var porch := porch_point()
	if not Game.has_flag("ch12_noah_found"):
		if Game.has_flag("ch12_ribbon_read") and (hound == null or not is_instance_valid(hound)) and Vector2(p.x - porch.x, p.z - porch.z).length() < SEE_FIRST:
			_spawn_hound()
		if hound_ai != null and is_instance_valid(hound_ai):
			if int(report.get("hound_bit", 0)) > 0 and not _busy.get("reset", false):
				_try_again()
		_marcus_gate(p)
		if not Game.has_flag("ch12_house19_entered") and Vector2(p.x - porch.x, p.z - porch.z).length() < 2.6 and not _busy.get("reset", false):
			Game.set_flag("ch12_house19_entered")
			_offer_knock()
			Game.refresh_objective()
			c12._guide()
		if Game.has_flag("ch12_house19_entered") and knock_it != null and is_instance_valid(knock_it):
			var ok: bool = not _busy.get("knock", false) and not Dialogue.is_busy() and not world.conversing
			knock_it.prompt_text = "[E] Knock  (three short, one long)" if ok else ""
			knock_it.collision_layer = 8 if ok else 0
		if p.distance_to(porch) > 30.0 and not (hound_ai != null and is_instance_valid(hound_ai) and str(hound_ai.get("state")) in ["CHASE", "SEARCH"]):
			_last_safe = p
	else:
		_return_tick(p)


func _spawn_hound() -> void:
	var ps := load(VeilMeshyNpcs.monster_scene(HOUND_PATH)) as PackedScene
	hound = ps.instantiate() as Node3D
	hound.name = "C12_Rescue_Hound"
	world.add_child(hound)
	var out := _outward()
	var side := out.cross(Vector3.UP).normalized()
	var base: Vector3 = c11.far_farm.global_position + out * 12.0
	var a := _ground(base + side * 13.0)
	var b := _ground(base - side * 13.0)
	hound.global_position = a
	VeilCreatureLook.apply_skitter(hound, a.y)
	hound_ai = HOUND_AI.new()
	hound_ai.name = "AI"
	hound.add_child(hound_ai)
	hound_ai.leash = 22.0
	hound_ai.setup(hound, player, [a, b])
	hound_ai.bit.connect(func(_d): report["hound_bit"] = int(report.get("hound_bit", 0)) + 1)


## Found and bitten (never fatal): the group falls back to the mill house with the Hound back on its rounds (13.0c fair recovery).
func _try_again() -> void:
	_busy["reset"] = true
	report["hound_bit"] = 0
	report["hound_resets"] = int(report["hound_resets"]) + 1
	c12._hold(true)
	await hud.fade_to(1.0, 0.6)
	player.global_position = _last_safe if _last_safe != Vector3.ZERO else c10.hl(c10.PORCH)
	player.velocity = Vector3.ZERO
	if is_instance_valid(hound):
		hound.queue_free()
	hound = null
	hound_ai = null
	for k in ["Eddie", "Marcus"]:
		if c9.follows.has(k) and c9.follows[k].active:
			c9.follows[k].recover_behind(c9.follows[k].gap)
	await get_tree().create_timer(0.4).timeout
	await hud.fade_to(0.0, 0.7)
	c12._hold(false)
	Dialogue.say("c12_try_again", false, true)
	_busy["reset"] = false


## Marcus (alive) stays at the fence: he comes with the group but not to the door ("He won't open for a voice. He'll open for a knock.").
func _marcus_gate(p: Vector3) -> void:
	if Game.has_flag("ch9_marcus_lost") or _busy.get("marcus_gate", false) or not c9.follows.has("Marcus") or not c9.follows["Marcus"].active:
		return
	if Vector2(p.x - porch_point().x, p.z - porch_point().z).length() < 26.0:
		_busy["marcus_gate"] = true
		c9.follows["Marcus"].stop()
		report["marcus_at_gate"] = true
		var a = world.animators.get("Marcus")
		if a:
			a.face_towards(c11.far_farm.global_position)
		Dialogue.say("c12_marcus_wait", false, true)


func _offer_knock() -> void:
	if knock_it != null and is_instance_valid(knock_it):
		return
	var d := _door()
	var at := porch_point() + Vector3(0, 1.0, 0) - _outward() * 0.7
	knock_it = c10._spot("C12_Knock", at, Vector3(1.6, 2.0, 1.4), func(_b): _knock())


func _knock() -> void:
	if _busy.get("knock", false) or Game.has_flag("ch12_noah_found"):
		return
	_busy["knock"] = true
	report["knock_tries"] = int(report["knock_tries"]) + 1
	c12._hold(true)
	var d := _door()
	var at: Vector3 = d.global_position + Vector3(0, 1.3, 0) if d else porch_point()
	var i_k := 0
	for gap in KNOCK:
		await get_tree().create_timer(gap).timeout
		Sfx.play("door_close", at, -4.0, 2.0 if i_k < 3 else 1.1)
		i_k += 1
	await get_tree().create_timer(1.2).timeout
	_ensure_noah()
	await _say("c12_noah_ask")
	await _say("c12_noah_ask_lost" if Game.has_flag("ch9_marcus_lost") else "c12_noah_ask_alive")
	await _say("c12_noah_test")
	var passed := false
	var tries := 0
	while not passed:
		var opts := ["The color.", "The zipper.", "The straps."]
		if tries > 0:
			opts.append("[Hold up the little bus keychain, one eye missing]")
		var i: int = await p4.choice.ask("NOAH:  \"Say what's wrong with the bag.\"", opts, player)
		c12._hold(true)
		if i == 0:
			passed = true
		elif i == 3:
			await _say("c12_noah_keychain")
			passed = true
		else:
			tries += 1
			report["test_wrong"] = int(report["test_wrong"]) + 1
			await _say("c12_noah_wrong")
	await _say("c12_noah_open")
	await _open_door()
	await _found()


func _open_door() -> void:
	var d := _door()
	if d == null:
		return
	var inside: Vector3 = c11.far_farm.global_position - _outward() * 3.0
	var deg: float = world._toward_deg(d, 95.0, inside)
	door_it = Interactable.attach(d, {"kind": "hinge", "label": "Front Door", "open_deg": deg, "hinge_axis": Vector3.UP, "state_key": "ch12/HOUSE_19/" + DOOR_NAME})
	door_it.set_open(true)
	await get_tree().create_timer(1.2).timeout


func _ensure_noah(at := Vector3.INF) -> void:
	if noah != null and is_instance_valid(noah):
		return
	var spot := at
	if not spot.is_finite():
		spot = _ground(c11.far_farm.global_position - _outward() * 2.6)       # just inside the front door
	noah = world._spawn_npc(load(OLD_PATH), load(OLD_FACE), world, spot, 0.0, "Noah")
	noah.visible = true
	var a = world.animators.get("Noah")
	if a:
		a.set_mood("scared")
	noah_follow = FOLLOW.new()
	noah_follow.gap = 3.0
	noah.add_child(noah_follow)
	noah_follow.setup(noah, player)
	noah_follow.run_speed = 4.6


func _found() -> void:
	var lost := Game.has_flag("ch9_marcus_lost")
	# in the doorway, facing the player
	var door_out := _ground(porch_point() - _outward() * 0.6)
	noah.global_position = door_out
	var a = world.animators.get("Noah")
	if a:
		a.face_towards(player.global_position)
	await _talk("c12_noah_why", [noah])
	await _talk("c12_noah_account", [noah])
	Game.add_item("farmers_journal")
	Sfx.play("pickup", player.global_position, -2.0)
	c12._hint("Noah gives you the farmer's journal.")
	if not lost:
		var m: Node3D = c12._node("Marcus")
		c9._start_follow("Marcus")
		var w := 0.0
		while m.global_position.distance_to(noah.global_position) > 4.5 and w < 14.0:
			await get_tree().create_timer(0.25).timeout
			w += 0.25
		await _talk("c12_reunion_alive", [m, noah])
	else:
		await _say("c12_bereave")
		var i: int = await p4.choice.ask("NOAH:  \"Where's my dad?\"", ["\"He didn't make it.\"", "\"He was looking for you until the end.\"", "[Hand him the backpack]"], player)
		c12._hold(true)
		await _say(["c12_bereave_a", "c12_bereave_b", "c12_bereave_c"][clampi(i, 0, 2)])
		await _say("c12_noah_held")
		await _say("c12_noah_comfort")
	Game.set_flag("ch12_noah_found")
	noah_state().merge({"status": "found", "role": "signaller", "companion": companion}, true)
	report["found"] = true
	noah_follow.start()
	c12._hold(false)
	_busy["knock"] = false
	if knock_it != null and is_instance_valid(knock_it):
		knock_it.prompt_text = ""
		knock_it.collision_layer = 0
	world.save_checkpoint("chapter12_noah")              # the repeat-safe milestone: never replayed
	Game.refresh_objective()
	c12._guide()
	c12._hint("Bring Noah back to the mill house.")


# ------------------------------------------------------------------ the way back, and 13.1
func _return_tick(p: Vector3) -> void:
	if _busy.get("arrive", false) or noah == null or not is_instance_valid(noah):
		return
	var porch: Vector3 = c10.hl(c10.PORCH)
	if p.distance_to(porch) < 7.0 and noah.global_position.distance_to(p) < 12.0:
		_arrive()


func _arrive() -> void:
	_busy["arrive"] = true
	c12._hold(true)
	noah_follow.stop()
	for k in c12.group():
		if c9.follows.has(k) and c9.follows[k].active:
			c9.follows[k].stop()
	c10._place_inside()
	_place_noah_home()
	Game.set_flag("ch12_noah_home")
	noah_state()["status"] = "home"
	report["home"] = true
	var npcs: Array = [c12._node("Eddie"), c12._node("Ruth"), noah]
	await _talk("c12_arrive_lost" if Game.has_flag("ch9_marcus_lost") else "c12_arrive_alive", npcs)
	var all: Array = [noah, c12._node("Eddie"), c12._node("Ruth"), c12._node("Sarah")]
	await _talk("c12_below_why", all)
	if not Game.has_flag("ch9_marcus_lost"):
		await _talk("c12_below_marcus", [c12._node("Marcus"), noah])
	Game.set_flag("ch12_below_explained")
	c12._hold(false)
	_busy["arrive"] = false
	Game.refresh_objective()
	c12._guide()
	c12._hint("Eddie has the map.")
	world.save_checkpoint("chapter12_noah_home")


func _place_noah_home() -> void:
	_ensure_noah(c10.hl(NOAH_HOME_SPOT))
	noah.global_position = _ground(c10.hl(NOAH_HOME_SPOT))
	noah.visible = true
	var a = world.animators.get("Noah")
	if a:
		a.set_mood("calm")
		a.face_towards(c10.hl(c10.WINDOW))
	if noah_follow != null and noah_follow.active:
		noah_follow.stop()


## After a load: Noah is wherever the milestone says.
func restore() -> void:
	if Game.has_flag("ch12_noah_home"):
		_place_noah_home()
	elif Game.has_flag("ch12_noah_found"):
		_ensure_noah(player.global_position + Vector3(2.0, 0, 2.0))
		noah_follow.start()
	if Game.has_flag("ch12_rescue_started") and not Game.has_flag("ch12_noah_found") and Game.has_flag("ch12_ribbon_read"):
		var lost := Game.has_flag("ch9_marcus_lost")
		for k in c12.group():
			if k == String(noah_state().get("companion", "")) or (k == "Marcus" and not lost):
				c9._start_follow(k)
			else:
				c12._stay_inside(k)
