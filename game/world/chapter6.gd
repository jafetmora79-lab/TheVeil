extends Node
class_name VeilChapter6
## THE VEIL - Chapter 6 "Voices in the Mist" (Act II). Starts when the player sleeps after Chapter 5 (flag
## c5_rested); created by chapter5.gd. All state lives in story flags + Game.world_state["ch6"], so loads rebuild
## the chapter without replaying finished events.
##
## Marcus heard a voice -> Eddie -> check supplies, head out (Eddie follows: VeilCompanionFollow from Chapter 5) ->
## the bungalow HOUSE_06 two lots past the cottage: Ruth + Sarah at their door (3 choices; "invite" = they follow)
## -> a voice deeper in the houses (subtitles + restrained audio; source never shown) -> investigate (Hound in the
## back alley) or retreat (Hound on the east route home) -> avoid / escape it (VeilHoundAI; no kill needed) ->
## back inside -> report to Marcus (line depends on the survivor choice) -> "CHAPTER 6 COMPLETE". No Chapter 7.
## Dialogue: the approved Chapter 6 script (game/data/dialogue.json, ids c6_*).

const FOLLOW := preload("res://game/npc/companion_follow.gd")
const HOUND_AI := preload("res://game/enemies/hound_ai.gd")
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const RUTH_PATH := "res://THE_VEIL_ASSETS_V2/06_Characters/Civilians/CHR_Ruth.glb"
const SARAH_PATH := "res://THE_VEIL_ASSETS_V2/06_Characters/Civilians/CHR_Sarah.glb"
const RUTH_FACE := "res://THE_VEIL_ASSETS_V2/06_Characters/Facial/Faces/T_Face_Ruth.png"
const SARAH_FACE := "res://THE_VEIL_ASSETS_V2/06_Characters/Facial/Faces/T_Face_Sarah.png"
const STATE := "ch6"

const RS_HOUSE := "HOUSE_06"                          # single-storey bungalow, front door (2.6, 3.2) house-local
# supermarket-local
const MARCUS_WATCH := Vector3(-2.3, 0.04, 4.5)         # watching the entrance, clear of the exit spot
const EDDIE_SHELTER := Vector3(6.2, 0.04, 4.9)
const RUTH_SPOT := Vector3(3.0, 0.04, 4.3)
const SARAH_SPOT := Vector3(3.9, 0.04, 5.1)
# HOUSE_06-local
const RUTH_DOOR := Vector3(2.6, 0.6, 4.2)
const SARAH_DOOR := Vector3(1.9, 0.6, 4.9)
const YARD := [Vector3(0.0, 1.5, -1.6), Vector3(10.0, 3.0, 9.2)]   # front yard, from the fence gap to the porch
# world (measured on the collision map: open alley z -76..-77 behind the first house row, side street x 56-67)
const INVESTIGATE_SPOT := Vector3(47.0, 0.2, -77.0)
const ALLEY_PATROL := [Vector3(35.0, 0.2, -76.9), Vector3(46.0, 0.2, -76.9)]   # straight, clear of the fence posts
const RETREAT_PATROL := [Vector3(61.0, 0.2, -36.0), Vector3(65.0, 0.2, -27.0), Vector3(58.0, 0.2, -30.0)]
# where the branch's Hound scene begins: the player's own position must enter these (checked every tick)
const INVESTIGATE_AREA := [Vector3(47.0, 1.5, -77.0), Vector3(7.0, 3.0, 3.6)]      # end of the alley, under the marker
const RETREAT_AREA := [Vector3(58.5, 1.5, -47.5), Vector3(11.0, 3.0, 4.0)]         # east route home, by the store's corner
const INVESTIGATE_HOUND := Vector3(37.0, 0.2, -76.9)    # it comes out of the fog ~10 m ahead, in view
const ESCAPE_DISTANCE := 24.0                          # out of the Hound's reach: encounter over
const CHECKPOINT_HEALTH := 22.0                        # below this a bite ends in the safe checkpoint, not death

var world: Node
var c5: Node
var p4: Node
var market: Node3D
var player: Node3D
var hud: Node
var rs_house: Node3D
var eddie: Node3D
var marcus: Node3D
var ruth: Node3D
var sarah: Node3D
var ruth_follow: VeilCompanionFollow
var sarah_follow: VeilCompanionFollow
var hound: CharacterBody3D
var hound_ai: Node
var hound_spawns := 0
var voice_runs := 0
var its := {}
var _yard: Area3D
var _door: Interactable
var _streams := {}
var _busy := {}
var _tick := 0.0
var _growl: AudioStreamPlayer3D
var _inv_area: Area3D
var _ret_area: Area3D


func begin(w: Node, chapter5: Node, restoring: bool) -> void:
	world = w
	c5 = chapter5
	p4 = c5.p4
	market = w.market
	player = w.player
	hud = w.hud
	rs_house = w.get_node("Residential/Houses/" + RS_HOUSE)
	eddie = w.eddie
	marcus = w.marcus
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"eddie": "shelter", "ruth_sarah": "house"}
	_make_sounds()
	_setup_npcs()
	_setup_ruth_sarah()
	_setup_rest()
	Dialogue.choices_offered.connect(_on_choices)
	if not Game.has_flag("ch6_started"):
		Game.set_flag("ch6_started")
	_apply(restoring)
	if Game.has_flag("ch6_rested"):
		_start_chapter7(true)
	Game.refresh_objective()


## Chapter 7 continues after the night that follows Chapter 6; it is a child of this node.
var chapter7: Node
func _start_chapter7(restoring: bool) -> void:
	if chapter7 != null:
		return
	chapter7 = load("res://game/world/chapter7.gd").new()
	chapter7.name = "Chapter7"
	add_child(chapter7)
	chapter7.begin(world, self, restoring)


func st() -> Dictionary:
	return Game.world_state[STATE]


func hl(p: Vector3) -> Vector3:
	return rs_house.global_transform * p


# ------------------------------------------------------------------ setup
func _setup_npcs() -> void:
	for pair in [["npc_Eddie", _talk_eddie], ["npc_Marcus", _talk_marcus]]:
		var it: Interactable = p4.its.get(pair[0])
		if it:
			it.used.connect(pair[1])
			its[pair[0]] = it
	c5.its["stash"].used.connect(_check_supplies)
	c5.its["exit"].used.connect(_head_out)
	c5.eddie_follow.run_speed = 4.6                   # keeps up with a sprinting player during the chase


func _setup_ruth_sarah() -> void:
	ruth = world._spawn_npc(load(RUTH_PATH), load(RUTH_FACE), rs_house, RUTH_DOOR, 0.0, "Ruth")
	sarah = world._spawn_npc(load(SARAH_PATH), load(SARAH_FACE), rs_house, SARAH_DOOR, 0.0, "Sarah")
	ruth_follow = FOLLOW.new()
	ruth_follow.gap = 3.6
	ruth.add_child(ruth_follow)
	ruth_follow.setup(ruth, player)
	sarah_follow = FOLLOW.new()
	sarah_follow.gap = 4.8
	sarah.add_child(sarah_follow)
	sarah_follow.setup(sarah, player)
	for f in [ruth_follow, sarah_follow]:
		f.run_speed = 4.6
	# their front door opens only for the conversation; the house itself is not explorable (doorway blocked)
	var fd := rs_house.find_child("INT_Door_Front", true, false) as Node3D
	if fd:
		var deg: float = world._toward_deg(fd, 95.0, hl(Vector3(2.0, 1.6, 5.0)))
		_door = Interactable.attach(fd, {"kind": "hinge", "label": "Front Door", "open_deg": deg, "hinge_axis": Vector3.UP,
			"state_key": "ch6/%s/INT_Door_Front" % RS_HOUSE})
		_door.collision_layer = 0
		var block := StaticBody3D.new()
		block.name = "C6_RuthSarahDoorway"
		var cs := CollisionShape3D.new()
		var bb := BoxShape3D.new()
		bb.size = Vector3(1.3, 2.2, 0.5)
		cs.shape = bb
		block.add_child(cs)
		rs_house.add_child(block)
		block.position = Vector3(2.6, 1.7, 3.45)
	_yard = world._area("C6_RuthSarahYard", hl(YARD[0]), YARD[1], 2, func(b): if b == player: _ruth_sarah(), rs_house.global_transform.basis)
	_inv_area = world._area("C6_InvestigateArea", INVESTIGATE_AREA[0], INVESTIGATE_AREA[1], 2, func(_b): pass)
	_ret_area = world._area("C6_RetreatRouteArea", RETREAT_AREA[0], RETREAT_AREA[1], 2, func(_b): pass)


func _setup_rest() -> void:
	var r: VeilRestPoint = p4.rest
	if r == null:
		return
	if r.slept.is_connected(c5._on_rest):
		r.slept.disconnect(c5._on_rest)
	r.can_rest = func() -> bool: return Game.has_flag("chapter_6_complete")
	r.slept.connect(_on_rest)


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply(restoring: bool) -> void:
	var s := st()
	var out := Game.has_flag("ch6_left_supermarket") and not Game.has_flag("ch6_returned_to_supermarket")
	if String(s.get("eddie", "shelter")) == "following":
		c5._reparent(eddie, world)
		c5.eddie_follow.recover_behind(2.4)
		c5.eddie_follow.start()
	else:
		c5._reparent(eddie, market)
		eddie.position = EDDIE_SHELTER
		world.animators["Eddie"].face_towards(c5.ml(c5.STASH))
	if marcus:
		c5._reparent(marcus, market)
		marcus.position = MARCUS_WATCH
		world.animators["Marcus"].face_towards(c5.ml(Vector3(0.0, 1.5, 0.0)))
	match String(s.get("ruth_sarah", "house")):
		"following":
			for pair in [[ruth, ruth_follow, 3.6], [sarah, sarah_follow, 4.8]]:
				c5._reparent(pair[0], world)
				pair[0].visible = true
				pair[1].recover_behind(pair[2])
				pair[1].start()
		"shelter":
			for pair in [[ruth, RUTH_SPOT], [sarah, SARAH_SPOT]]:
				c5._reparent(pair[0], market)
				pair[0].position = pair[1]
				pair[0].visible = true
		_:
			var shown := Game.has_flag("ch6_ruth_sarah_heard") and not Game.has_flag("ch6_ruth_sarah_met")
			ruth.visible = shown
			sarah.visible = shown
	# saves made before this fix: an encounter already under way counts as its area reached
	if Game.has_flag("ch6_hound_encounter_started") and not Game.has_flag("ch6_hound_encounter_complete"):
		if Game.has_flag("ch6_voice_choice_investigate") and not Game.has_flag("ch6_investigation_reached"):
			Game.flags["ch6_investigation_reached"] = true
		if Game.has_flag("ch6_voice_choice_retreat") and not Game.has_flag("ch6_retreat_route_reached"):
			Game.flags["ch6_retreat_route_reached"] = true
	if Game.has_flag("ch6_voice_choice_made") and not Game.has_flag("ch6_voice_resolved") and Game.has_flag("ch6_investigation_reached"):
		Game.flags["ch6_voice_resolved"] = true
	# the Hound: only once its branch area was reached, never two; a load mid-encounter puts it back on patrol
	if _area_reached() and not Game.has_flag("ch6_hound_encounter_complete"):
		_spawn_hound()
		if restoring:
			hound_ai.reset_to_patrol(player.global_position)
	_refresh_prompts()
	_guide()


func _refresh_prompts() -> void:
	if its.has("npc_Marcus"):
		var talk := not Game.has_flag("ch6_marcus_briefing_complete") or \
			(Game.has_flag("ch6_returned_to_supermarket") and not Game.has_flag("chapter_6_complete"))
		its["npc_Marcus"].prompt_text = "[E] Talk" if talk else ""
	if its.has("npc_Eddie"):
		its["npc_Eddie"].prompt_text = "[E] Talk" if Game.has_flag("ch6_marcus_briefing_complete") and not Game.has_flag("ch6_eddie_talked") else ""
	c5.its["stash"].prompt_text = "[E] Check the Supplies" if Game.has_flag("ch6_eddie_talked") and not Game.has_flag("ch6_eddie_ready") else ""
	c5.its["exit"].prompt_text = Interactable.key_hint() + "OPEN DOOR" if Game.has_flag("ch6_eddie_ready") and String(st().get("eddie", "")) != "following" \
		and not Game.has_flag("ch6_returned_to_supermarket") else ""


## One destination marker at a time, so the player never has to guess where to go.
func _guide() -> void:
	world._clear_beacon("c6")
	if Game.has_flag("ch6_left_supermarket") and not Game.has_flag("ch6_house_found"):
		world._beacon("c6", hl(Vector3(2.6, 3.0, 1.0)), Color(0.8, 0.9, 1.0))
	elif Game.has_flag("ch6_voice_choice_investigate") and not Game.has_flag("ch6_investigation_reached"):
		world._beacon("c6", INVESTIGATE_SPOT + Vector3(0, 2.5, 0), Color(0.8, 0.9, 1.0))
	elif (Game.has_flag("ch6_hound_encounter_complete") or Game.has_flag("ch6_voice_choice_retreat")) \
			and not Game.has_flag("ch6_returned_to_supermarket"):
		world._beacon("c6", c5.ml(Vector3(0, 3.0, -1.5)), Color(0.8, 0.9, 1.0))


## The HUD destination marker (Chapter 5 polish system): only the current objective's target. Hidden while the
## Hound hunts the player, so the encounter keeps its tension.
func _update_marker() -> void:
	if not hud.has_method("set_marker"):
		return
	var t: Variant = null
	var label := ""
	if not Game.has_flag("ch6_marcus_briefing_complete"):
		t = marcus
		label = "MARCUS"
	elif not Game.has_flag("ch6_eddie_talked"):
		t = eddie
		label = "EDDIE"
	elif not Game.has_flag("ch6_eddie_ready"):
		t = c5.ml(c5.STASH + Vector3(0, 0.3, 0))
		label = "SUPPLIES"
	elif not Game.has_flag("ch6_eddie_following"):
		t = c5.ml(c5._door_spot())
		label = "EXIT"
	elif not Game.has_flag("ch6_left_supermarket"):
		t = c5.ml(Vector3(0, 1.4, -2.5))
		label = "EXIT"
	elif not Game.has_flag("ch6_ruth_sarah_met"):
		t = hl(Vector3(2.6, 1.6, 3.0))
		label = "HOUSE"
	elif not Game.has_flag("ch6_voice_choice_made"):
		t = null
	elif Game.has_flag("ch6_voice_choice_investigate") and not Game.has_flag("ch6_investigation_reached"):
		t = INVESTIGATE_SPOT + Vector3(0, 1.4, 0)
		label = "VOICE"
	elif Game.has_flag("ch6_voice_choice_investigate") and not Game.has_flag("ch6_hound_encounter_complete"):
		t = null                                      # at the spot: the Hound scene, no marker
	elif Game.has_flag("ch6_hound_encounter_started") and not Game.has_flag("ch6_hound_encounter_complete"):
		t = null
	elif not Game.has_flag("ch6_returned_to_supermarket"):
		t = c5.ml(Vector3(0, 1.4, -1.5)) if not c5._in_store(market.to_local(player.global_position)) else c5.ml(Vector3(0, 1.4, 5.0))
		label = "SUPERMARKET"
	elif not Game.has_flag("chapter_6_complete"):
		t = marcus
		label = "MARCUS"
	hud.set_marker(t, label)


# ------------------------------------------------------------------ scenes 1-2: Marcus, Eddie, preparing
func _talk_marcus(_b: Node) -> void:
	if _busy.get("talk", false):
		return
	if Game.has_flag("ch6_returned_to_supermarket") and not Game.has_flag("chapter_6_complete"):
		_report()
		return
	if Game.has_flag("ch6_marcus_briefing_complete"):
		return
	_busy["talk"] = true
	its["npc_Marcus"].prompt_text = ""
	await c5._talk("c6_marcus", marcus)
	Game.set_flag("ch6_marcus_briefing_complete")
	_busy["talk"] = false
	_refresh_prompts()


func _talk_eddie(_b: Node) -> void:
	if not Game.has_flag("ch6_marcus_briefing_complete") or Game.has_flag("ch6_eddie_talked") or _busy.get("talk", false):
		return
	_busy["talk"] = true
	its["npc_Eddie"].prompt_text = ""
	await c5._talk("c6_eddie", eddie)
	Game.set_flag("ch6_eddie_talked")
	_busy["talk"] = false
	_refresh_prompts()


func _check_supplies(_b: Node) -> void:
	if not Game.has_flag("ch6_eddie_talked") or Game.has_flag("ch6_eddie_ready"):
		return
	if not hud.inv_panel.visible:
		hud.toggle_inventory()
	Sfx.play("pickup", c5.ml(c5.STASH), -12.0, 0.7)
	Game.set_flag("ch6_eddie_ready")                  # Eddie is ready to follow once the supplies are checked
	_refresh_prompts()


func _head_out(_b: Node) -> void:
	if not Game.has_flag("ch6_eddie_ready") or String(st().get("eddie", "")) == "following" or _busy.get("out", false) \
			or Game.has_flag("ch6_returned_to_supermarket"):
		return
	_busy["out"] = true
	var i: int = await p4.choice.ask("Head out with Eddie now?", ["Let's go", "Not yet"], player)
	if i != 0:
		_busy["out"] = false
		return
	if hud.inv_panel.visible:
		hud.toggle_inventory()
	c5.its["exit"].prompt_text = ""
	c5._set_doors(true)
	var a: Node = world.animators["Eddie"]
	a.walk_to([Vector3(1.5, 0.04, 4.3)], 1.5)
	await c5._wait_for(func(): return not a.is_walking(), 8.0)
	st()["eddie"] = "following"
	c5._reparent(eddie, world)
	c5.eddie_follow.start()
	Game.set_flag("ch6_eddie_following")
	_busy["out"] = false
	_refresh_prompts()


# ------------------------------------------------------------------ scenes 3-4: the street, Ruth and Sarah
func _ruth_sarah() -> void:
	if not Game.has_flag("ch6_left_supermarket") or Game.has_flag("ch6_ruth_sarah_met") or _busy.get("rs", false):
		return
	_busy["rs"] = true                                # runtime only: a load before the choice offers it again
	if not Game.has_flag("ch6_house_found"):
		Game.set_flag("ch6_house_found")
	_guide()
	if Dialogue.is_busy():
		await c5._wait_for(func(): return not Dialogue.is_busy(), 20.0)
	Game.set_flag("ch6_ruth_sarah_heard")
	Sfx.play("door_close", hl(Vector3(2.4, 1.2, 4.6)), -10.0, 0.7)
	await get_tree().create_timer(1.0).timeout
	ruth.visible = true
	sarah.visible = true
	if _door and not _door.is_open:
		_door.set_open(true)
	world.converse(["c6_ruth_sarah"], [ruth])


func _on_choices(id: String, choices: Array) -> void:
	if id == "c6_ruth_sarah" and not Game.has_flag("ch6_ruth_sarah_met"):
		var c := await _ask(choices)
		var key := String(c["flag"]).trim_prefix("ch6_ruth_sarah_choice_")
		st()["ruth_sarah_choice"] = key                 # ch6_ruth_sarah_choice = "invite" / "directions" / "leave"
		Game.set_flag(c["flag"])
		await c5._say_wait(c["next"])
		if key == "invite":
			st()["ruth_sarah"] = "following"            # they gather their things and walk behind the group
			for pair in [[ruth, ruth_follow], [sarah, sarah_follow]]:
				c5._reparent(pair[0], world)
				pair[1].start()
		else:
			await get_tree().create_timer(1.0).timeout
			if _door and _door.is_open:
				_door.set_open(false)
			ruth.visible = false
			sarah.visible = false
		Game.set_flag("ch6_ruth_sarah_met")
		_refresh_prompts()
	elif id == "c6_voice_eddie" and not Game.has_flag("ch6_voice_choice_made"):
		var c2 := await _ask(choices)
		var key2 := String(c2["flag"]).trim_prefix("ch6_voice_choice_")
		st()["voice_choice"] = key2                     # ch6_voice_choice = "investigate" / "retreat"
		Game.set_flag(c2["flag"])
		await c5._say_wait(c2["next"])
		# no Hound yet: investigate keeps "Investigate the distant voice" active until the player walks into the
		# investigation area; retreat starts the way home (its Hound waits on the east route)
		Game.set_flag("ch6_voice_choice_made")
		if key2 == "retreat":
			Game.set_flag("ch6_voice_resolved")
		_guide()


func _ask(choices: Array) -> Dictionary:
	var texts: Array = []
	for c in choices:
		texts.append(c["text"])
	var i: int = await p4.choice.ask("", texts, player)
	return choices[clampi(i, 0, choices.size() - 1)]


# ------------------------------------------------------------------ scene 5: the voice (once; source never shown)
func _voice() -> void:
	if Game.has_flag("ch6_voice_heard") or _busy.get("voice", false):
		return
	_busy["voice"] = true
	voice_runs += 1
	Game.set_flag("ch6_voice_heard")
	var src := Vector3(40.0, 1.6, -84.0)               # deeper in the houses, behind the alley fences: never shown
	_play("breath", src, -6.0)
	await c5._say_wait("c6_voice")
	await get_tree().create_timer(0.8).timeout
	_busy["voice_reoffer"] = true
	Dialogue.say("c6_voice_eddie", false, true)
	_busy["voice"] = false


# ------------------------------------------------------------------ scene 6: the Hound
func _spawn_hound() -> void:
	if hound != null and is_instance_valid(hound):
		return
	var ps := load(HOUND_PATH) as PackedScene
	hound = ps.instantiate() as CharacterBody3D
	hound.name = "C6_Hound"
	world.add_child(hound)
	hound_spawns += 1
	var investigate := Game.has_flag("ch6_voice_choice_investigate")
	var pts: Array = (ALLEY_PATROL if investigate else RETREAT_PATROL).duplicate()
	hound.global_position = INVESTIGATE_HOUND if investigate else pts[0]
	hound_ai = HOUND_AI.new()
	hound_ai.name = "AI"
	hound.add_child(hound_ai)
	hound_ai.setup(hound, player, pts)
	hound_ai.noticed.connect(_on_noticed)
	hound_ai.bit.connect(_on_bit)
	_growl = AudioStreamPlayer3D.new()
	_growl.stream = _streams["growl"]
	_growl.volume_db = -8.0
	_growl.unit_size = 5.0
	_growl.max_distance = 30.0
	hound.add_child(_growl)
	_growl.position = Vector3(0, 0.9, 0.8)
	_growl.play()


func _on_noticed() -> void:
	_play("bark", hound.global_position + Vector3(0, 1.0, 0), 0.0)
	Dialogue.say("c6_hound_noticed", false, true)


func _on_bit(_dmg: float) -> void:
	_play("bark", hound.global_position + Vector3(0, 1.0, 0), -2.0)
	await get_tree().process_frame
	if player.get("health") != null and float(player.get("health")) <= CHECKPOINT_HEALTH:
		_checkpoint()


## A bad bite never ends the game here: fade, the group is back at the edge of the encounter, the Hound back on
## patrol, health partly restored (Chapter 6 checkpoint rule).
func _checkpoint() -> void:
	if _busy.get("checkpoint", false):
		return
	_busy["checkpoint"] = true
	player.set("controls_enabled", false)
	await hud.fade_to(1.0, 0.6)
	var safe := Vector3(60.0, 0.4, -56.0)              # side-street corner, out of both patrols
	player.global_position = safe
	player.velocity = Vector3.ZERO
	if player.has_method("heal"):
		player.heal(50.0)
	hound_ai.reset_to_patrol(safe)
	for f in [c5.eddie_follow, ruth_follow, sarah_follow]:
		if f.active:
			f.recover_behind(2.4 if f == c5.eddie_follow else f.gap)
	await get_tree().create_timer(0.5).timeout
	await hud.fade_to(0.0, 1.0)
	player.set("controls_enabled", true)
	_busy["checkpoint"] = false


func _area_reached() -> bool:
	if Game.has_flag("ch6_voice_choice_investigate"):
		return Game.has_flag("ch6_investigation_reached")
	if Game.has_flag("ch6_voice_choice_retreat"):
		return Game.has_flag("ch6_retreat_route_reached")
	return false


## The branch's scene begins only when the PLAYER (not Eddie, not a timer) is inside its area, once.
func _branch_area_tick() -> void:
	if not Game.has_flag("ch6_voice_choice_made") or Game.has_flag("ch6_hound_encounter_complete") or _area_reached():
		return
	if Game.has_flag("ch6_voice_choice_investigate") and _inv_area.overlaps_body(player):
		Game.set_flag("ch6_investigation_reached")
		Game.set_flag("ch6_voice_resolved")           # "Investigate the distant voice" is done: the player is there
		_spawn_hound()
		_guide()
	elif Game.has_flag("ch6_voice_choice_retreat") and _ret_area.overlaps_body(player):
		Game.set_flag("ch6_retreat_route_reached")
		_spawn_hound()
		_guide()


func _encounter_tick() -> void:
	if hound == null or not is_instance_valid(hound) or Game.has_flag("ch6_hound_encounter_complete") or not _area_reached():
		return
	var d := player.global_position.distance_to(hound.global_position)
	if not Game.has_flag("ch6_hound_encounter_started"):
		var seen: bool = d < 20.0 and _los(player.global_position + Vector3(0, 1.5, 0), hound.global_position + Vector3(0, 0.8, 0))
		if seen or d < 9.0 or hound_ai.state == "CHASE":
			Game.set_flag("ch6_hound_encounter_started")
			_guide()
			Dialogue.say("c6_hound_seen", false, true)
		return
	# over once the player is clear of it and it is not hunting them
	if d > ESCAPE_DISTANCE and hound_ai.state != "CHASE":
		_complete_encounter()


func _complete_encounter() -> void:
	if Game.has_flag("ch6_hound_encounter_complete"):
		return
	Game.set_flag("ch6_hound_encounter_complete")
	_guide()
	# it slinks back into the fog and is gone: no pursuit across the map, nothing left to respawn on load
	if hound and is_instance_valid(hound):
		hound_ai.set_physics_process(false)
		var tw := hound.create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(hound.queue_free)


func _los(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.exclude = [hound.get_rid(), (player as CollisionObject3D).get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ per tick: departure, triggers, doors, return
func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	if Game.has_flag("ch7_started"):
		return                                    # Chapter 7 owns the doors and the marker from here on
	_update_marker()
	if not Game.has_flag("ch6_eddie_following"):
		return
	var pl: Vector3 = market.to_local(player.global_position)
	var el: Vector3 = market.to_local(eddie.global_position)
	var rs_following := String(st().get("ruth_sarah", "")) == "following"
	# front doors: open while anyone of the group is at them, shut when everyone is clear
	var near: bool = c5._near_doors(pl) or c5._near_doors(el)
	if rs_following:
		near = near or c5._near_doors(market.to_local(ruth.global_position)) or c5._near_doors(market.to_local(sarah.global_position))
	if near != c5._doors_open and (c5._near_doors(pl) or not near):
		c5._set_doors(near)
	if not Game.has_flag("ch6_left_supermarket") and c5._away_from_store(pl, 3.0) and c5.eddie_follow.active:
		Game.set_flag("ch6_left_supermarket")
		_guide()
	if Game.has_flag("ch6_left_supermarket") and not Game.has_flag("ch6_walk_said") and c5._away_from_store(pl, 12.0) \
			and not Dialogue.is_busy():
		Game.set_flag("ch6_walk_said")
		Dialogue.say("c6_walk", false, true)
	# the voice: once the group has left Ruth and Sarah's yard
	if Game.has_flag("ch6_ruth_sarah_met") and not Game.has_flag("ch6_voice_heard") and not _yard.overlaps_body(player) \
			and player.global_position.distance_to(hl(Vector3(2.6, 0.6, 3.2))) > 9.0 and not Dialogue.is_busy():
		_voice()
	if _yard.overlaps_body(player):
		_ruth_sarah()
	# a load between the voice and the choice: the voice is not replayed, Eddie's reaction (and the choice) is
	if Game.has_flag("ch6_voice_heard") and not Game.has_flag("ch6_voice_choice_made") and not _busy.get("voice", false) \
			and not _busy.get("voice_reoffer", false) and not Dialogue.is_busy() and not p4.choice.is_open():
		_busy["voice_reoffer"] = true
		Dialogue.say("c6_voice_eddie", false, true)
	_branch_area_tick()
	_encounter_tick()
	# RETREAT only: getting home without ever meeting the Hound ends the encounter (it was avoided by the west lane)
	if Game.has_flag("ch6_voice_choice_retreat") and not Game.has_flag("ch6_hound_encounter_complete") \
			and (c5._near_doors(pl) or c5._in_store(pl)) and (hound == null or hound_ai.state != "CHASE"):
		if not Game.has_flag("ch6_hound_encounter_started"):
			Game.set_flag("ch6_hound_encounter_started")
		_complete_encounter()
	if Game.has_flag("ch6_hound_encounter_complete") and not Game.has_flag("ch6_return_said") \
			and not c5._away_from_store(pl, 30.0) and not Dialogue.is_busy():
		Game.set_flag("ch6_return_said")
		Dialogue.say("c6_return", false, true)
	if Game.has_flag("ch6_hound_encounter_complete") and not Game.has_flag("ch6_returned_to_supermarket"):
		var player_in: bool = c5._in_store(pl)
		c5.eddie_follow.gap = 1.0 if player_in else 2.4
		ruth_follow.gap = 1.6 if player_in else 3.6
		sarah_follow.gap = 2.2 if player_in else 4.8
		var rs_ok: bool = not rs_following or (c5._in_store(market.to_local(ruth.global_position), 0.1) and c5._in_store(market.to_local(sarah.global_position), 0.1))
		if player_in and c5._in_store(el, 0.1) and rs_ok:
			_returned()


func _returned() -> void:
	world._clear_beacon("c6")
	c5.eddie_follow.stop()
	c5._reparent(eddie, market)
	st()["eddie"] = "shelter"
	world.animators["Eddie"].walk_to([EDDIE_SHELTER], 1.3)
	if String(st().get("ruth_sarah", "")) == "following":
		st()["ruth_sarah"] = "shelter"
		for pair in [[ruth, ruth_follow, RUTH_SPOT], [sarah, sarah_follow, SARAH_SPOT]]:
			pair[1].stop()
			c5._reparent(pair[0], market)
			world.animators[pair[0].name].walk_to([pair[2]], 1.2)
	Game.set_flag("ch6_returned_to_supermarket")      # saves with everyone back inside
	_refresh_prompts()


# ------------------------------------------------------------------ scene 8: report, completion
func _report() -> void:
	if Game.has_flag("chapter_6_complete") or _busy.get("report", false):
		return
	_busy["report"] = true
	its["npc_Marcus"].prompt_text = ""
	await c5._talk("c6_report_a", marcus)
	await c5._say_wait("c6_report_" + String(st().get("ruth_sarah_choice", "leave")))
	await c5._say_wait("c6_report_b")
	Game.set_flag("chapter_6_complete")              # Chapter 7 is NOT started here
	_busy["report"] = false
	_refresh_prompts()
	if p4.rest:
		p4.rest.get_parent().visible = true
		p4.rest.interactable.prompt_text = "[E] Sleep"
	await hud.title_card("CHAPTER 6 COMPLETE  -  VOICES IN THE MIST", 3.2)


func _on_rest(_id: String) -> void:
	# the next morning is Chapter 7 (game/world/chapter7.gd); started while the screen is still black
	Game.set_flag("ch6_rested")
	_start_chapter7(false)
	if p4.flashlight:
		p4.flashlight.set_on(false)
	await get_tree().create_timer(1.0).timeout
	await hud.fade_to(0.0, 2.0)
	player.set("controls_enabled", true)
	p4.rest.interactable.prompt_text = "[E] Sleep"


# ------------------------------------------------------------------ sounds (synthesised, no voices)
func _make_sounds() -> void:
	_streams["growl"] = Sfx._make(3.0, _growl_wave, true)
	_streams["bark"] = Sfx._make(0.7, _bark_wave)
	_streams["breath"] = Sfx._make(5.0, _breath_wave)


func _growl_wave(t: float, i: int) -> float:
	var env := 0.5 + 0.5 * sin(t * TAU / 3.0)
	return (sin(TAU * 58.0 * t + sin(t * 31.0) * 1.5) * 0.35 + Sfx._noise(i) * 0.12) * env * 0.6


func _bark_wave(t: float, i: int) -> float:
	var env := exp(-t * 7.0) * clampf(t * 60.0, 0.0, 1.0)
	return (sin(TAU * (220.0 - t * 160.0) * t) * 0.6 + Sfx._noise(i) * 0.35) * env


## restrained environmental audio under the voice subtitles: a faint, wind-like exhale far off (not a voice)
func _breath_wave(t: float, i: int) -> float:
	var env := sin(PI * clampf(t / 5.0, 0.0, 1.0)) * (0.5 + 0.5 * sin(t * 1.7))
	return Sfx._noise(i) * 0.18 * env


func _play(id: String, at: Vector3, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = db
	p.unit_size = 6.0
	p.max_distance = 60.0
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
