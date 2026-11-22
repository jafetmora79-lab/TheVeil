extends Node
class_name VeilChapter14
## THE VEIL - displayed CHAPTER 15 "The Last Shelter" (internal ids keep the file numbering: chapter14.gd, flags ch14_*,
## chapter_14_complete). Starts at the mill-worker house (the group's shelter since No Safe Road) after "Into the
## Veil" (flag chapter_13_complete), created by chapter13.gd. State: story flags + Game.world_state["ch14"].
##
## A deep vibration wakes the protagonist; "you need to see this"; the window: the mist is close, a vast shape moves
## between far buildings -> the meeting (every living survivor in the room) -> three preparations in any order:
## check the supplies (the carried inventory; treat the injured with painkillers; pack provisions; a short emergency
## run if it is not enough - faster danger, a Hound from the fog, the companion's warnings), reinforce the entrances
## (front door, front window, back door: each recorded), prepare the escape route (the back way; the car is used only
## if it is really here) -> the calm: optional talks -> keep watch: Skitters at the window (a braced window holds
## longer), Hounds out of the fog at the weakest door, it breaks; a survivor is caught: ten seconds to shove the
## table across (control first, then the timer) - saved, or seriously hurt (never killed here) -> the Shellcrawler
## comes out from behind the pickup by the road and blocks the front: out the back (forced open if it was not
## prepared) -> the evacuation on foot, injured survivors slower -> someone is caught behind a fallen fence: go back
## for them or keep moving (they are left behind, missing - their fate is for the next chapter) -> the field: the
## shelter disappears into the mist -> "CHAPTER 15 COMPLETE", NEXT: CHAPTER 16 - WHAT REMAINS (not started).

const STATE := "ch14"
const CHAPTER := 15
const A := "res://THE_VEIL_ASSETS_V2/"
const SKITTER_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const CRAB_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Shellcrawler.tscn"
const HOUND_AI := preload("res://game/enemies/hound_ai.gd")
# ---- the mill-worker house (house-local; floor y 0.61): living room x -3..3, z 3.2..8.4; kitchen behind it
const BED := Vector3(1.4, 0.61, 6.0)                   # where the protagonist slept (No Safe Road's rest spot)
const FRONT_IN := Vector3(1.1, 0.61, 4.3)              # just inside the front door
const BACK_IN := Vector3(-2.25, 0.61, 10.6)            # just inside the back door (kitchen)
const BACK_OUT := Vector3(-2.25, 0.0, 13.6)
const FRONT_OUT := Vector3(1.1, 0.0, 1.6)
const WINDOW_OUT := Vector3(-1.4, 0.0, 1.8)
const SUPPLIES := Vector3(2.4, 0.61, 7.6)
const TABLE := Vector3(0.6, 0.61, 5.2)                  # the table shoved across the broken door
const SAFE_LIGHT := Vector3(-0.5, 2.3, 6.0)
# ---- the world around it
const PICKUP_POS := Vector3(-99.0, 0.15, 3.0)          # the abandoned pickup by the road (the Shellcrawler waits behind it)
const CRAB_HIDE := Vector3(-102.5, 0.0, 2.0)
const HOUND_FROM := [Vector3(-100.0, 0.0, -14.0), Vector3(-84.0, 0.0, -14.0)]
const ESCAPE := [Vector3(-94.25, 0.2, 28.0), Vector3(-98.0, 0.2, 40.0), Vector3(-102.0, 0.2, 56.0)]
const FENCE_AT := Vector3(-95.4, 0.15, 38.2)
const SAFE := Vector3(-102.0, 0.2, 56.0)
const SAFE_SPOTS := {"Eddie": Vector3(-103.6, 0.2, 57.2), "Ruth": Vector3(-100.4, 0.2, 57.4), "Sarah": Vector3(-101.2, 0.2, 58.8), "Marcus": Vector3(-103.0, 0.2, 59.0)}
const RUN_CACHES := [["canned_food", Vector3(-84.0, 0.2, -4.0)], ["water_bottle", Vector3(-78.4, 0.2, -22.6)], ["painkillers", Vector3(-85.5, 0.2, -21.0)],
	["batteries", Vector3(-74.0, 0.2, -26.0)], ["water_bottle", Vector3(-82.5, 0.2, -12.0)]]

var world: Node
var c13: Node
var c12: Node
var c10: Node
var c9: Node
var c8: Node
var p4: Node
var player: Node3D
var hud: Node
var house: Node3D
var its := {}
var props := {}
var skitters: Array = []
var hounds: Array = []
var crab: CharacterBody3D
var run_hound: Node3D
var shape: MeshInstance3D
var lamp: OmniLight3D
var report := {"rescue_runs": 0, "siege_runs": 0, "ending_runs": 0, "hound_max_step": 0.0, "evac_runs": 0, "decision_runs": 0}
var _busy := {}
var _tick := 0.0
var _streams := {}
var _fog0 := -1.0
var _run_t := 0.0
var _rescue_left := -1.0


func begin(w: Node, chapter13: Node, restoring: bool) -> void:
	world = w
	c13 = chapter13
	c12 = c13.c12
	c10 = c13.c10
	c9 = c13.c9
	c8 = c13.c8
	p4 = c13.p4
	player = w.player
	hud = w.hud
	house = c10.house
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"roster": present(), "defenses": {}, "escape": "", "provisions": "", "rescue": "", "rescue_target": "",
			"separated": "", "separation": "", "missing": [], "talked": {}, "run": ""}
	_streams = c13._streams
	_setup()
	_ensure_present.call_deferred()
	var fresh := not Game.has_flag("ch14_started")
	if fresh:
		Game.set_flag("ch14_started")
		_opening.call_deferred()
	else:
		_apply()
		if Game.has_flag("chapter_14_complete"):
			_start_chapter15.call_deferred(true)
	Game.refresh_objective()


## The nearest bit of clear floor to `p` (house frame, up to 3 m away): a capsule check against the house's real collision.
func _clear_floor_near(p: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	q.shape = cap
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var best := hl(p)
	var best_d := 1e9
	var x := -3.0
	while x <= 3.0:
		var z := -3.0
		while z <= 3.0:
			var d := Vector2(x, z).length()
			if d < best_d:
				var pt := Vector3(p.x + x, p.y, p.z + z)
				q.transform = Transform3D(Basis(), hl(pt + Vector3(0, 0.95, 0)))
				var free := true
				for h in space.intersect_shape(q, 6):
					if not (h["collider"] is VeilSurvivorBody):
						free = false
						break
				if free and _in_room(pt) and Vector2(pt.x, pt.z).distance_to(Vector2(FRONT_IN.x, FRONT_IN.z)) > 1.0:
					best = hl(pt)
					best_d = d
			z += 0.25
		x += 0.25
	return best


## Whoever is part of the group is in the house, seen and standing on clear floor, however the chapter was entered (review note #61: Ruth talked without being there when the chapter was
## picked from the menu).
func _ensure_present() -> void:
	await get_tree().process_frame
	for k in present():
		var n := _node(k)
		if n == null:
			continue
		n.visible = true
		if n.global_position.distance_to(house.global_position) > 14.0 or n.global_position.y < -1.0:
			world.place_survivor(n, hl(spot(k)))


func st() -> Dictionary:
	return Game.world_state[STATE]


func hl(p: Vector3) -> Vector3:
	return c10.hl(p)


func alive() -> bool:
	return c10.alive()


## The survivors actually with the group: alive (Marcus only if he made it out) and not left behind.
func present() -> Array:
	var out := []
	for k in c10.group():
		if not (k in Game.world_state.get(STATE, {}).get("missing", [])):
			out.append(k)
	return out


func _node(k: String) -> Node3D:
	return c10._node(k)


func _health(k: String) -> String:
	return world.survivors.health(k) if world.survivors else "healthy"


## Who is caught by the broken door: Sarah if she is here, else Ruth (never Eddie, who speaks for the group).
func rescue_target() -> String:
	if String(st().get("rescue_target", "")) != "":
		return String(st()["rescue_target"])
	for k in ["Sarah", "Ruth"]:
		if k in present():
			return k
	return "Ruth"


## Who is cut off on the way out: not the one already threatened at the door (Marcus first if he is here).
func separation_target() -> String:
	if String(st().get("separated", "")) != "":
		return String(st()["separated"])
	for k in ["Marcus", "Ruth", "Sarah"]:
		if k in present() and k != rescue_target():
			return k
	return ""


# ------------------------------------------------------------------ setup
func _setup() -> void:
	# the kitchen and back doors become real doors (the back way out); open doors do not block
	for n in ["INT_Door_Kitchen", "INT_Door_Back"]:
		var d := house.find_child(n, true, false) as Node3D
		if d:
			var deg: float = world._toward_deg(d, 95.0, hl(Vector3(-1.6, 1.4, 9.8)))
			var it := Interactable.attach(d, {"kind": "hinge", "label": n.trim_prefix("INT_Door_") + " Door", "open_deg": deg, "hinge_axis": Vector3.UP,
				"state_key": "ch14/MILL_HOUSE/" + n})
			it.used.connect(func(_b): _door_collision.call_deferred(it))
			_door_collision.call_deferred(it)
			its[n] = it
	lamp = c12._light(hl(SAFE_LIGHT), 0.6, 7.0, Color(1.0, 0.78, 0.5))
	_dress_house()
	props["pickup"] = c13._solid("05_Vehicles/Abandoned_Variants/VEH_Pickup_Abandoned.glb", "C14_Pickup", PICKUP_POS, 0.4)
	props["fence"] = c12._prop("02_Town/Fences/FN_Picket_2.5m.glb", "C14_Fence", FENCE_AT, 1.2)
	props["supplies"] = c12._prop("03_Residential/Interactive_Props/RES_IP_StorageBin.glb", "C14_Supplies", hl(SUPPLIES), 0.0)
	for k in [["supplies", hl(SUPPLIES + Vector3(0, 0.5, 0)), Vector3(1.0, 1.0, 1.0), _check_supplies],
			["front", hl(FRONT_IN + Vector3(0, 0.9, -0.5)), Vector3(1.4, 2.0, 0.6), _defend.bind("front")],
			["window", hl(c10.WINDOW + Vector3(0, 0, 0.6)), Vector3(1.6, 1.4, 0.6), _defend.bind("window")],
			["back", hl(BACK_IN + Vector3(0, 0.9, 0.3)), Vector3(1.4, 2.0, 0.6), _defend.bind("back")],
			["escape", hl(BACK_IN + Vector3(0, 0.9, 0.9)), Vector3(1.0, 2.0, 0.5), _check_escape],
			["watch", hl(c10.WINDOW + Vector3(1.2, 0, 0.7)), Vector3(1.0, 1.4, 0.6), _keep_watch],
			["brace", hl(c10.WINDOW + Vector3(0, -0.1, 0.65)), Vector3(1.8, 1.6, 0.7), _brace_window],
			["shove", hl(TABLE + Vector3(0, 0.6, 0)), Vector3(1.4, 1.2, 1.4), _shove],
			["force", hl(BACK_IN + Vector3(0, 0.9, 0.2)), Vector3(1.4, 2.0, 0.6), _force_back]]:
		its[k[0]] = c10._spot("C14_" + String(k[0]), k[1], k[2], k[3])
	for k in ["Ruth", "Sarah", "Marcus"]:
		var it := Interactable.attach(_node(k), {"kind": "custom", "label": k, "prompt_text": ""})
		it.used.connect(_talk.bind(k))
		its["talk_" + k] = it
	var e: Interactable = p4.its.get("npc_Eddie")
	if e:
		e.used.connect(_talk.bind("Eddie"))
		its["talk_Eddie"] = e
	# the distant shape (never a model: a dark, indistinct mass in the fog)
	shape = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 6.0
	cap.height = 22.0
	shape.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.035, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shape.material_override = m
	world.add_child(shape)
	shape.global_position = Vector3(-60.0, 9.0, -70.0)
	# the emergency run's finds (one-time pickups)
	for i in RUN_CACHES.size():
		var c: Array = RUN_CACHES[i]
		var path := String(Game.item_info(c[0]).get("model", ""))
		var ps := load(path) as PackedScene if path != "" else null
		if ps == null:
			continue
		var n := ps.instantiate() as Node3D
		n.name = "C14_Find%d" % i
		world.add_child(n)
		n.global_position = c[1]
		Interactable.attach(n, {"kind": "pickup", "label": Game.item_info(c[0]).get("name", c[0]), "item_id": c[0], "state_key": "ch14/find%d" % i})
		n.visible = Game.has_flag("ch14_run_started")
		props["find%d" % i] = n


## The shelter lived in: papers (the plans, Noah's log, the map) drifted over the floor and the furniture, a few more things left about.
func _dress_house() -> void:
	var root := Node3D.new()
	root.name = "C14_Clutter"
	house.add_child(root)
	for it in [["Pile_A", Vector3(1.9, 0.62, 8.1), 0.6], ["Pile_B", Vector3(-1.1, 0.62, 6.9), 2.1], ["Pile_C", Vector3(0.9, 0.62, 9.7), 1.3],
			["Sheet_A", Vector3(-2.3, 0.62, 5.7), 0.4], ["Sheet_A", Vector3(1.6, 0.62, 5.0), 2.8], ["Pile_A", Vector3(-0.2, 0.62, 4.4), 0.2],
			["Pile_B", Vector3(-2.0, 0.62, 10.2), 1.7], ["Sheet_A", Vector3(2.3, 0.62, 10.8), 0.9]]:
		_put(PROPS + "PRP_Paper_%s.glb" % it[0], root, it[1], it[2], 0.0, 0.0, "Paper")


## Where each survivor stands in the house: spread over the living room and the kitchen (clear floor, not on the bed, the supplies, the table or a door),
## each near their own post, never closer than ~2 m to one another. Worked out once from the house's real collision.
const CROWD_ANCHORS := {"Eddie": Vector3(-2.2, 0.61, 4.5), "Sarah": Vector3(2.2, 0.61, 4.7), "Ruth": Vector3(2.3, 0.61, 9.0),
	"Marcus": Vector3(-1.0, 0.61, 8.4), "Noah": Vector3(-0.4, 0.61, 7.0)}
var _spots := {}


func spot(k: String) -> Vector3:
	if _spots.is_empty():
		_compute_spots()
	return _spots.get(k, c10.SPOTS.get(k, Vector3(0.0, 0.61, 7.0)))


func _in_room(p: Vector3) -> bool:
	var half: Vector3 = c10.ROOM[1] * 0.5
	return absf(p.x - c10.ROOM[0].x) <= half.x - 0.45 and absf(p.z - c10.ROOM[0].z) <= half.z - 0.45


func _compute_spots() -> void:
	var keep := [[BED, 1.2], [SUPPLIES, 1.0], [TABLE, 1.2], [FRONT_IN, 1.5], [BACK_IN, 2.2], [Vector3(-1.6, 0.61, 9.8), 1.4], [Vector3(-2.0, 0.61, 8.6), 1.2], [Vector3(c10.WINDOW.x, 0.61, c10.WINDOW.z + 0.9), 0.9]]
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.5
	q.shape = cap
	q.collision_mask = 1
	var cand: Array = []
	var x := -2.8
	while x <= 2.8:
		var z := 3.9
		while z <= 11.2:
			var pt := Vector3(x, 0.61, z)
			var ok := _in_room(pt)                                   # (inside the room's real walls: some spots were outside it, so people stood in the wall, unseen)
			for kp in keep:
				if Vector2(pt.x - kp[0].x, pt.z - kp[0].z).length() < float(kp[1]):
					ok = false
			if ok:
				q.transform = Transform3D(Basis(), hl(pt + Vector3(0, 0.95, 0)))
				for h in space.intersect_shape(q, 6):
					if not (h["collider"] is VeilSurvivorBody) and h["collider"] != player:
						ok = false
			if ok:
				cand.append(pt)
			z += 0.35
		x += 0.35
	var chosen: Array = []
	for k in ["Eddie", "Marcus", "Sarah", "Ruth", "Noah"]:
		var anchor: Vector3 = CROWD_ANCHORS[k]
		var best := Vector3.INF
		var best_d := 1e9
		for c in cand:
			var far := true
			for o in chosen:
				if Vector2(c.x - o.x, c.z - o.z).length() < 2.0:
					far = false
			if not far:
				continue
			var d := Vector2(c.x - anchor.x, c.z - anchor.z).length()
			if d < best_d:
				best_d = d
				best = c
		if best.is_finite():
			_spots[k] = best
			chosen.append(best)
	report["crowd_spots"] = _spots.size()


func _spread() -> void:
	for k in present():
		var n := _node(k)
		if n == null:
			continue
		world.place_survivor(n, hl(spot(k)))
		var a = world.animators.get(k)
		if a:
			a.face_towards(hl(Vector3(0.0, 1.5, 6.5)))
	var nn := _noah_node()
	if nn != null and _spots.has("Noah"):
		nn.global_position = hl(spot("Noah"))


## An open door does not block (the same rule as the farmhouse); a closed one does.
func _door_collision(it: Interactable) -> void:
	c12.c11._door_collision(it)


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	_node("Marcus").visible = alive()
	for k in st().get("missing", []):
		_node(k).visible = false
	if Game.has_flag("ch15_started"):
		_house_gone(true)
		_refresh_prompts()
		return                                       # the finale places the group from here on
	for k in st().get("defenses", {}):
		_place_defense(k, true)
	if Game.has_flag("chapter_14_complete") or Game.has_flag("ch14_evac_started"):
		_house_gone(Game.has_flag("chapter_14_complete"))
	if Game.has_flag("chapter_14_complete"):
		_place_at_safe()
	elif Game.has_flag("ch14_evac_started"):
		_start_evac(true)
	else:
		c10._place_inside()
		_spread()
		for k in st().get("missing", []):
			_node(k).visible = false
		if Game.has_flag("ch14_run_started") and not Game.has_flag("ch14_run_done"):
			_end_run()
		if Game.has_flag("ch14_siege_started"):
			_siege.call_deferred()                    # the attack resumes from its last completed stage
	_refresh_prompts()
	_guide()


func _place_at_safe() -> void:
	for k in present():
		(c9.follows[k] as VeilCompanionFollow).stop()
		c9.c5._reparent(_node(k), world)
		_node(k).visible = true
		world.place_survivor(_node(k), SAFE_SPOTS[k])


func _refresh_prompts() -> void:
	var prep: bool = Game.has_flag("ch14_meeting_done") and not Game.has_flag("ch14_siege_started")
	_setp("supplies", "[E] Check the Supplies" if prep else "")
	var d: Dictionary = st().get("defenses", {})
	_setp("front", "[E] Barricade the Front Door" if prep and not d.has("front") else "")
	_setp("window", "[E] Board Up the Window" if prep and not d.has("window") else "")
	_setp("back", "[E] Wedge the Back Door" if prep and not d.has("back") and Game.has_flag("ch14_escape_ready") else "")
	_setp("escape", "[E] Check the Back Way" if prep and not Game.has_flag("ch14_escape_ready") else "")
	_setp("watch", "[E] Keep Watch Tonight" if prep and _prep_done() else "")
	_setp("brace", "[E] BRACE THE WINDOW" if _busy.get("brace_open", false) else "")
	_setp("shove", "[E] SHOVE THE TABLE ACROSS" if _rescue_left > 0.0 else "")
	_setp("force", "[E] FORCE THE BACK DOOR OPEN" if _busy.get("force_open", false) else "")
	# a barricaded door is not a door any more (review note #60: it could be opened straight through the planks and furniture)
	for pair in [["front", c10.its.get("door")], ["back", its.get("INT_Door_Back")]]:
		var dit = pair[1]
		if dit != null and is_instance_valid(dit) and d.has(pair[0]) and not (dit as Interactable).is_open:
			(dit as Interactable).collision_layer = 0
	for k in ["Ruth", "Sarah", "Marcus", "Eddie"]:
		var on: bool = prep and k in present() and _prep_done() and not st().get("talked", {}).get(k, false) and Dialogue.data.has(_talk_id(k))
		_setp("talk_" + k, ("[E] Talk to " + k) if on else "")


func _setp(k: String, t: String) -> void:
	var it: Interactable = its.get(k)
	if it:
		it.prompt_text = t
		it.collision_layer = 8 if t != "" else 0


func _prep_done() -> bool:
	return Game.has_flag("ch14_supplies_checked") and Game.has_flag("ch14_escape_ready")


var _obj := ""


func _guide() -> void:
	if chapter15 != null:
		return
	var t: Variant = null
	var label := ""
	if not Game.has_flag("ch14_window_seen"):
		t = hl(c10.WINDOW)
		label = "WINDOW"
	elif Game.has_flag("ch14_meeting_done") and not Game.has_flag("ch14_siege_started"):
		var d: Dictionary = st().get("defenses", {})
		var txt := "Prepare  %s supplies  %s entrances (%d/3)  %s escape route" % ["[x]" if Game.has_flag("ch14_supplies_checked") else "[ ]",
			"[x]" if d.size() >= 3 else "[ ]", d.size(), "[x]" if Game.has_flag("ch14_escape_ready") else "[ ]"]
		if txt != _obj and hud.has_method("set_objective"):
			_obj = txt
			hud.set_objective(Game.current_goal(), txt)
		if Game.has_flag("ch14_run_started") and not Game.has_flag("ch14_run_done"):
			t = hl(c10.PORCH) + Vector3(0, 1.4, 0)
			label = "BACK TO THE HOUSE"
		elif not Game.has_flag("ch14_supplies_checked"):
			t = hl(SUPPLIES + Vector3(0, 0.6, 0))
			label = "SUPPLIES"
		elif not Game.has_flag("ch14_escape_ready"):
			t = hl(BACK_IN + Vector3(0, 1.2, 0))
			label = "BACK WAY"
		elif _prep_done():
			t = hl(c10.WINDOW)
			label = "KEEP WATCH"
	elif Game.has_flag("ch14_evac_started") and not Game.has_flag("ch14_safe"):
		t = SAFE + Vector3(0, 1.4, 0)
		label = "GET EVERYONE OUT"
	if hud.has_method("set_marker"):
		hud.set_marker(t, label)


# ------------------------------------------------------------------ scene 1: something is coming
func _opening() -> void:
	_busy["opening"] = true
	_hold(true)
	await hud.fade_to(1.0, 0.6)
	c10._place_inside()
	_spread()
	for k in present():
		_node(k).visible = true                                      # (everyone in the group is seen: Ruth was missing when the chapter was started from the menu)
	_node("Marcus").visible = alive()
	player.global_position = _clear_floor_near(BED) + Vector3(0, 0.1, 0)      # on clear floor, not on whatever stands where the bed was (the player appeared on top of a table)
	player.velocity = Vector3.ZERO
	player.set_yaw_pitch(0.0, -0.9)                  # lying down, looking at the ceiling
	lamp.light_energy = 0.15
	await get_tree().create_timer(0.8).timeout
	await hud.fade_to(0.0, 2.0)
	_play("deep", hl(Vector3(0, -8, 0)), 6.0)
	c12._shake(2.4, 0.03)
	await get_tree().create_timer(1.6).timeout
	_play("clank", hl(Vector3(-20, 3, -18)), 0.0)
	var cam: Camera3D = player.camera
	var tw := create_tween()
	tw.tween_method(func(p): player.set_yaw_pitch(0.0, p), -0.9, 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	lamp.light_energy = 0.6
	Dialogue.say("c14_wake_noah" if _noah_node() != null else "c14_wake", false, true)       # Noah wakes you when he is in the house (story pass B5)
	while Dialogue.is_busy():
		await get_tree().process_frame
	_hold(false)
	_busy["opening"] = false
	world.save_checkpoint("chapter15_start")
	_apply()
	await hud.chapter_start(CHAPTER)
	_hint("Go to the window.")


func _window_tick() -> void:
	if Game.has_flag("ch14_window_seen") or _busy.get("opening", false) or _busy.get("window", false):
		return
	if player.global_position.distance_to(hl(c10.WINDOW)) < 2.2:
		_window_scene()


func _window_scene() -> void:
	_busy["window"] = true
	_hold(true)
	Game.set_flag("ch14_window_seen")
	_set_fog(true, 0.2)                                              # (thin: there has to be something to SEE through the glass: review note #61)
	# the window is small (0.8 m): the player is eased square behind it and the shape is put straight out through it,
	# so the whole pass reads through the glass instead of past the frame
	var view := hl(c10.WINDOW + Vector3(0.0, 0.0, 1.15))
	view.y = player.global_position.y
	if Vector2(view.x - player.global_position.x, view.z - player.global_position.z).length() > 0.2:
		player.set_physics_process(false)
		var te := create_tween()
		te.tween_property(player, "global_position", view, 0.8).set_trans(Tween.TRANS_SINE)
		await te.finished
		player.set_physics_process(true)
	shape.global_position = hl(c10.WINDOW + Vector3(4.0, 7.0, -58.0))
	var across := -house_basis_x() * 9.0
	await c8._turn_to(shape.global_position, 1.4)
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.7, 1.4)
	var m := shape.material_override as StandardMaterial3D
	# pairs of pale eyes low in the fog and a flash of light behind the shape, so the street clearly holds something
	var eyes := []
	for i in 5:
		var e := OmniLight3D.new()
		e.light_color = Color(0.9, 0.95, 1.0)
		e.light_energy = 1.4
		e.omni_range = 5.0
		world.add_child(e)
		e.global_position = hl(c10.WINDOW + Vector3(-6.0 + i * 3.0, -0.2 + 0.4 * (i % 2), -9.0 - i * 2.0))
		eyes.append(e)
	var ts := create_tween()
	ts.tween_property(m, "albedo_color:a", 0.85, 1.4)
	ts.tween_property(shape, "global_position", shape.global_position + across, 3.0)
	ts.parallel().tween_property(m, "albedo_color:a", 0.0, 3.0)
	_play("deep", shape.global_position, 8.0)
	await ts.finished
	for e in eyes:
		(e as Node).queue_free()
	var tb := create_tween()
	tb.tween_property(cam, "fov", fov0, 0.8)
	await tb.finished
	cam.fov = fov0
	_hold(false)
	await c9._talk_group(_pick("c14_window"), [_node("Eddie"), _node("Ruth")])
	_busy["window"] = false
	_meeting()


func house_basis_x() -> Vector3:
	var x := hl(Vector3.RIGHT) - hl(Vector3.ZERO)
	x.y = 0.0
	return x.normalized() if x.length() > 0.01 else Vector3.RIGHT


func _meeting() -> void:
	if Game.has_flag("ch14_meeting_done") or _busy.get("meeting", false):
		return
	_busy["meeting"] = true
	var npcs: Array = [_node("Ruth"), _node("Eddie")]
	await c9._talk_group(_pick("c14_meeting"), npcs)
	_play("deep", hl(Vector3(-30, 0, -20)), 8.0)
	c12._shake(0.8, 0.04)
	await c9._talk_group("c14_meeting_end", npcs)
	# what the group already knows about itself (earlier choices): one line, if there is one to say
	var r := _recall_line()
	if r != "":
		await c9._talk_group(r, npcs)
	await _noah_meeting()
	Game.set_flag("ch14_meeting_done")
	_busy["meeting"] = false
	_refresh_prompts()
	_guide()


## The rescued Noah (null when the storyline went on without the rescue): the watch log, and his evacuation partner and the route (story pass B5).
func _noah_node() -> Node3D:
	if not Game.has_flag("ch12_noah_found") or c12 == null or c12.get("noah") == null:
		return null
	var n: Variant = c12.noah.get("noah")
	return n as Node3D if n != null and is_instance_valid(n) else null


func _noah_meeting() -> void:
	var nn := _noah_node()
	if nn == null:
		return
	await c9._talk_group("c14_noah_log", [nn, _node("Eddie")])
	var partner := "Ruth"
	if "Marcus" in present() and _health("Marcus") != "serious":
		partner = "Marcus"
	elif not ("Ruth" in present()):
		partner = "Sarah"
	st()["noah_partner"] = partner
	if Dialogue.data.has("c14_partner_" + partner) and partner in present():
		await c9._talk_group("c14_partner_" + partner, [_node(partner), nn])


## A line that remembers what happened before (Chapter 14's choice, injuries, the trip back from the station).
func _recall_line() -> String:
	var c13s: Dictionary = Game.world_state.get("ch13", {})
	if String(c13s.get("choice", "")) == "evidence":
		return "c14_recall_evidence"
	if String(c13s.get("choice", "")) == "help":
		return "c14_recall_help"
	return ""


## The variant of a shared scene that fits who is actually here (lines with Marcus/Sarah only if present).
func _pick(base: String) -> String:
	if "Marcus" in present() and Dialogue.data.has(base + "_marcus"):
		return base + "_marcus"
	return base


# ------------------------------------------------------------------ the preparations (any order)
func _check_supplies(_b: Node) -> void:
	if _busy.get("supplies", false) or Game.has_flag("ch14_siege_started"):
		return
	_busy["supplies"] = true
	while is_inside_tree():
		var c := _counts()
		var need: int = present().size() + 1
		var text := "WHAT WE HAVE  -  food %d   water %d   painkillers %d   batteries %d" % [c.food, c.water, c.painkillers, c.batteries]
		text += "\nEnough for everyone on the move: %s" % ("yes" if c.food >= need and c.water >= need else "no - %d of each needed" % need)
		for k in present():
			text += "\n%s  -  %s" % [k, world.survivors.HEALTH_TEXT[_health(k)] if world.survivors else "Healthy"]
		var opts := []
		var acts := []
		for k in present():
			if _health(k) in ["injured", "serious"] and c.painkillers > 0:
				opts.append("Treat %s (1 painkiller)" % k)
				acts.append(["treat", k])
		opts.append("Pack emergency provisions")
		acts.append(["pack", ""])
		if not Game.has_flag("ch14_run_started"):
			opts.append("Go out for emergency supplies (the mist is close)")
			acts.append(["run", ""])
		opts.append("Done")
		acts.append(["done", ""])
		var i: int = await p4.choice.ask(text, opts, player)
		var a: Array = acts[clampi(i, 0, acts.size() - 1)] if i >= 0 else ["done", ""]
		match String(a[0]):
			"treat":
				Game.remove_item("painkillers")
				world.survivors.set_health(a[1], "recovering" if _health(a[1]) == "injured" else "injured")
				world.survivors.award("ch14_treated:%s:%s" % [a[1], _health(a[1])], {a[1]: 5})
				Sfx.play("pickup", player.global_position, -8.0)
			"pack":
				st()["provisions"] = "enough" if c.food >= need and c.water >= need else "short"
				Game.set_flag("ch14_supplies_checked")
				Dialogue.say("c14_pack_" + String(st()["provisions"]), false, true)
				break
			"run":
				_busy["supplies"] = false
				_start_run()
				return
			_:
				Game.set_flag("ch14_supplies_checked")
				if String(st().get("provisions", "")) == "":
					st()["provisions"] = "enough" if c.food >= need and c.water >= need else "short"
				break
	_busy["supplies"] = false
	_refresh_prompts()
	_guide()
	_check_prep_done()


func _counts() -> Dictionary:
	var out := {"food": 0, "water": 0, "painkillers": Game.inventory.count("painkillers"), "batteries": 0}
	for id in Game.inventory:
		var r := Game.shelter_resource(id)
		if r == "food" or r == "water":
			out[r] += 1
	var fl := get_tree().get_first_node_in_group("veil_flashlight")
	out["batteries"] = int(fl.get("spares")) if fl else 0
	return out


func _defend(_b: Node, k: String) -> void:
	if st().get("defenses", {}).has(k) or _busy.get("defend", false):
		return
	_busy["defend"] = true
	_hold(true)
	await hud.fade_to(0.7, 0.35)
	var d: Dictionary = st().get("defenses", {})
	d[k] = true
	st()["defenses"] = d
	_place_defense(k, false)
	Sfx.play("door_close", player.global_position, -4.0, 0.7)
	await get_tree().create_timer(0.5).timeout
	await hud.fade_to(0.0, 0.35)
	_hold(false)
	_busy["defend"] = false
	Dialogue.say("c14_defend_" + k, false, true)
	_refresh_prompts()
	_guide()
	_check_prep_done()


## The defence itself: nailed planks (Blender models, game/prototypes/story_props) across the opening, with real furniture from the packs shoved
## in front of it (a dresser and a chair at the front door, a tall bookshelf and a chair at the back, a chair and boards at the window).
## Built in the house's own frame, so it sits right wherever the house stands.
const PROPS := "res://game/prototypes/story_props/"
const FURN := "res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/"


func _put(path: String, parent: Node3D, pos: Vector3, yaw := 0.0, roll := 0.0, pitch := 0.0, nm := "") -> Node3D:
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var o := ps.instantiate() as Node3D
	if nm != "":
		o.name = nm
	parent.add_child(o)
	o.transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), pos)
	return o


## Where a door sits, in the house's frame (from the door node's own geometry).
func _door_local(n: String, fallback: Vector3) -> Vector3:
	var d := house.find_child(n, true, false) as Node3D
	if d == null:
		return fallback
	var box := AABB()
	var first := true
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var a := m.global_transform * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return fallback
	var c := house.to_local(box.get_center())
	return Vector3(c.x, fallback.y, c.z)


## `dirz` is +1 when the room is on the +Z side of the wall (front door, window), -1 when it is on the -Z side (the back door).
func _barricade(kind: String, wall: Vector3, dirz: float, _width: float, bottom: float, height: float) -> Node3D:
	var root := Node3D.new()
	root.name = "C14_Barricade_" + kind
	house.add_child(root)
	var yaw := 0.0 if dirz > 0.0 else PI
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var models := ["PRP_Plank_1.4.glb", "PRP_Plank_1.0_Broken.glb", "PRP_Plank_1.6_Dark.glb", "PRP_Plank_1.4.glb", "PRP_Plank_1.6_Dark.glb"]
	var n := 5 if height > 1.8 else 4
	for i in n:
		var y := bottom + 0.22 + (height - 0.44) * float(i) / float(n - 1)
		var path: String = PROPS + String(models[i % models.size()])
		_put(path, root, Vector3(wall.x + rng.randf_range(-0.07, 0.07), y, wall.z + dirz * (0.1 + 0.012 * float(i % 2))), yaw, rng.randf_range(-0.06, 0.06), 0.0, "Plank%d" % i)
	for sgn in [-1.0, 1.0]:                                           # two diagonal braces across the boards
		_put(PROPS + "PRP_Plank_1.6_Dark.glb", root, Vector3(wall.x, bottom + height * 0.5, wall.z + dirz * 0.16), yaw, deg_to_rad(40.0) * sgn * dirz, 0.0, "Brace")
	match kind:
		"front":
			_put(FURN + "RES_Dresser.glb", root, Vector3(wall.x, 0.61, wall.z + dirz * 0.5), yaw, 0.0, 0.0, "Dresser")
			_put(FURN + "RES_DiningChair_Wood.glb", root, Vector3(wall.x + 0.75, 0.61, wall.z + dirz * 0.55), yaw + 0.5, 0.0, 0.0, "Chair")
			_put(FURN + "RES_DiningChair_Wood.glb", root, Vector3(wall.x - 0.7, 0.61 + 0.24, wall.z + dirz * 0.9), yaw - 0.4, 1.35, 0.0, "ChairOver")
		"back":
			_put(FURN + "RES_Bookshelf_Tall.glb", root, Vector3(wall.x, 0.61, wall.z + dirz * 0.35), yaw, 0.0, 0.0, "Shelf")
			_put(FURN + "RES_DiningChair_Wood.glb", root, Vector3(wall.x + 0.8, 0.61, wall.z + dirz * 0.6), yaw - 0.3, 0.0, 0.0, "Chair")
		"window":
			_put(FURN + "RES_DiningChair_Wood.glb", root, Vector3(wall.x - 0.3, 0.61, wall.z + dirz * 0.7), yaw + 0.25, 0.0, 0.0, "Chair")
	return root


func _place_defense(k: String, _instant: bool) -> void:
	if props.has("def_" + k):
		return
	var n: Node3D
	match k:
		"front":
			var d := _door_local("INT_Door_Front", Vector3(0.85, 0.61, 3.3))
			n = _barricade("front", Vector3(d.x, 0.61, d.z), 1.0, 0.95, 0.61, 2.1)
		"window":
			n = _barricade("window", Vector3(c10.WINDOW.x, 0.61, c10.WINDOW.z + 0.04), 1.0, 1.15, c10.WINDOW.y - 0.62, 1.25)
		"back":
			var b := _door_local("INT_Door_Back", Vector3(BACK_IN.x, 0.61, 11.6))
			n = _barricade("back", Vector3(b.x, 0.61, b.z), -1.0, 0.95, 0.61, 2.1)
	props["def_" + k] = n


func _check_escape(_b: Node) -> void:
	if Game.has_flag("ch14_escape_ready") or _busy.get("escape", false):
		return
	_busy["escape"] = true
	_hold(true)
	await hud.fade_to(0.8, 0.4)
	# the back way: the kitchen door, the back door, the field behind (the debris outside moved aside)
	for n in ["INT_Door_Kitchen"]:
		var it: Interactable = its.get(n)
		if it and not it.is_open:
			it.set_open(true, true)
			_door_collision(it)
	var car: bool = Game.has_flag("vehicle_repaired") and world.sedan.global_position.distance_to(house.global_position) < 80.0
	st()["escape"] = "car" if car else "on_foot"
	Game.set_flag("ch14_escape_ready")
	await get_tree().create_timer(0.6).timeout
	await hud.fade_to(0.0, 0.4)
	_hold(false)
	_busy["escape"] = false
	await c9._talk_group("c14_escape", [_node("Ruth"), _node("Eddie")])
	if Game.has_flag("vehicle_repaired") and not car:
		Dialogue.say("c14_no_car", false, true)       # the repaired car is still at the supermarket lot
	_refresh_prompts()
	_guide()
	_check_prep_done()


func _check_prep_done() -> void:
	if _prep_done() and not Game.has_flag("ch14_prepared"):
		Game.set_flag("ch14_prepared")
		world.save_checkpoint("chapter15_prepared")
		_hint("Ready as you'll ever be. Talk to the others, or keep watch at the window.")
		_refresh_prompts()


# ------------------------------------------------------------------ the emergency run (optional)
func _start_run() -> void:
	Game.set_flag("ch14_run_started")
	st()["run"] = "out"
	_run_t = 0.0
	for i in RUN_CACHES.size():
		if props.has("find%d" % i) and is_instance_valid(props["find%d" % i]):
			props["find%d" % i].visible = not Game.world_state.get("ch14/find%d" % i, {}).get("taken", false)
	if "Eddie" in present() and _health("Eddie") != "serious":
		c9._start_follow("Eddie")
	_set_fog(true, 0.4)
	_hint("Quick. The old station and the road - and back before the mist closes in.")
	_refresh_prompts()
	_guide()


func _run_tick(delta: float) -> void:
	if not Game.has_flag("ch14_run_started") or Game.has_flag("ch14_run_done"):
		return
	var out: bool = not c10.inside_room(player) and player.global_position.distance_to(house.global_position) > 10.0
	if out:
		_run_t += delta
		if _run_t > 20.0 and not Game.has_flag("ch14_run_warned") and not Dialogue.is_busy():
			Game.set_flag("ch14_run_warned")
			Dialogue.say("c14_run_warn" if "Eddie" in present() else "c14_run_warn_alone", false, true)
		if _run_t > 35.0 and run_hound == null:
			_spawn_run_hound()
	elif _run_t > 2.0 and c10.inside_room(player):
		_end_run()


func _spawn_run_hound() -> void:
	var p := player.global_position
	var back := player.global_transform.basis.z * Vector3(1, 0, 1)
	var at := p + back.normalized() * 30.0
	at.y = c10._floor(at)
	run_hound = (load(VeilMeshyNpcs.monster_scene(HOUND_PATH)) as PackedScene).instantiate() as Node3D
	run_hound.name = "C14_RunHound"
	world.add_child(run_hound)
	run_hound.global_position = at
	VeilCreatureLook.apply_skitter(run_hound, at.y)
	var ai: Node = HOUND_AI.new()
	ai.name = "AI"
	run_hound.add_child(ai)
	ai.leash = 40.0
	ai.setup(run_hound, player, [at, at + Vector3(5, 0, 5)])
	ai.set("_last_seen", p)
	ai.state = "SUSPICIOUS"
	_play("clank", at + Vector3(0, 1, 0), 0.0)


func _end_run() -> void:
	Game.set_flag("ch14_run_done")
	st()["run"] = "back"
	if run_hound and is_instance_valid(run_hound):
		run_hound.queue_free()                       # the door is shut on it; out in the fog
		run_hound = null
	if "Eddie" in present():
		(c9.follows["Eddie"] as VeilCompanionFollow).stop()
		world.npc_walk("Eddie", hl(spot("Eddie")), 1.4)
	_set_fog(false)
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ the calm: optional talks
func _talk_id(k: String) -> String:
	if k == "Marcus":
		return "c14_calm_Marcus"
	return "c14_calm_" + k


func _talk(_b: Node, k: String) -> void:
	if not _prep_done() or Game.has_flag("ch14_siege_started") or st().get("talked", {}).get(k, false) or world.conversing:
		return
	var t: Dictionary = st().get("talked", {})
	t[k] = true
	st()["talked"] = t
	_refresh_prompts()
	await c9._talk_group(_talk_id(k), [_node(k)])


# ------------------------------------------------------------------ the siege
func _keep_watch(_b: Node) -> void:
	if not _prep_done() or Game.has_flag("ch14_siege_started"):
		return
	Game.set_flag("ch14_siege_started")
	world.save_checkpoint("chapter15_siege")
	_refresh_prompts()
	_siege()


func _siege() -> void:
	if _busy.get("siege", false) or Game.has_flag("ch14_evac_started"):
		return
	_busy["siege"] = true
	report["siege_runs"] += 1
	if not Game.has_flag("ch14_skitters_done"):
		await _skitters()
	if not Game.has_flag("ch14_hounds_done"):
		await _hounds()
	if not Game.has_flag("ch14_crab_seen"):
		await _crab()
	elif not Game.has_flag("ch14_evac_started"):
		# a load at the "before the evacuation" checkpoint: the front is blocked, out the back
		if Game.has_flag("ch14_escape_ready"):
			_open_back()
			_start_evac(false)
		else:
			_busy["force_open"] = true
			_refresh_prompts()
	_busy["siege"] = false


func _make(path: String, n: String, at: Vector3) -> Node3D:
	var c := (load(path) as PackedScene).instantiate() as Node3D
	c.name = n
	world.add_child(c)
	if c is CollisionObject3D:
		(c as CollisionObject3D).collision_layer = 0
		(c as CollisionObject3D).collision_mask = 0
	c.set_physics_process(false)
	c.global_position = at
	VeilCreatureLook.apply_skitter(c, at.y)
	return c


func _anim(c: Node3D, contains: String) -> void:
	var ap := c.find_children("*", "AnimationPlayer", true, false)
	if ap.is_empty():
		return
	for an in (ap[0] as AnimationPlayer).get_animation_list():
		if String(an).to_lower().contains(contains.to_lower()):
			(ap[0] as AnimationPlayer).play(an)
			return


## Moves a creature along points at a speed (yaw toward the way it goes); returns when it arrives.
func _move(c: Node3D, pts: Array, speed: float) -> void:
	for p in pts:
		var from := c.global_position
		var to: Vector3 = p
		var d := to - from
		if d.length() < 0.05:
			continue
		c.rotation.y = atan2(d.x, d.z)
		var tw := create_tween()
		tw.tween_property(c, "global_position", to, d.length() / speed)
		await tw.finished


func _skitters() -> void:
	_hold(true)
	_play("skitter", hl(WINDOW_OUT), 6.0)
	await get_tree().create_timer(1.0).timeout
	var s1 := _make(SKITTER_PATH, "C14_Skitter1", hl(WINDOW_OUT + Vector3(-7.0, 0, -6.0)))
	skitters.append(s1)
	_anim(s1, "crawl")
	await c8._turn_to(hl(c10.WINDOW + Vector3(0, -0.4, -1.0)), 1.0)
	await _move(s1, [hl(WINDOW_OUT)], 3.0)
	_anim(s1, "lunge")
	_play("claw", hl(c10.WINDOW), 6.0)
	c12._shake(0.4, 0.03)
	if props.has("def_window") and props["def_window"]:
		var b: Node3D = props["def_window"]
		var tw := create_tween()
		tw.tween_property(b, "position:z", b.position.z + 0.04, 0.06)
		tw.tween_property(b, "position:z", b.position.z, 0.1)
	await c9._talk_group(_pick("c14_skitter"), [_node("Ruth")])
	var s2 := _make(SKITTER_PATH, "C14_Skitter2", hl(BACK_OUT + Vector3(8.0, 0, 6.0)))
	skitters.append(s2)
	_anim(s2, "crawl")
	_move(s2, [hl(BACK_OUT + Vector3(1.0, 0, 0.5))], 2.6)
	_play("skitter", hl(BACK_OUT), 4.0)
	_hold(false)
	# brace it: a boarded window gives more time
	var t := 14.0 if st().get("defenses", {}).has("window") else 7.0
	_busy["brace_open"] = true
	_refresh_prompts()
	_hint("BRACE THE WINDOW!")
	while t > 0.0 and _busy.get("brace_open", false):
		await get_tree().process_frame
		t -= get_process_delta_time()
		if randf() < 0.02:
			_anim(s1, "lunge")
			_play("claw", hl(c10.WINDOW), 2.0)
	if _busy.get("brace_open", false):
		_busy["brace_open"] = false
		st()["window"] = "broke"                      # glass in the room; the bracing came late
		Sfx.play("door_close", hl(c10.WINDOW), 6.0, 1.8)
		if world.survivors:
			world.survivors.award("ch14_window_broke", {}, -5)
	else:
		st()["window"] = "held"
	_refresh_prompts()
	# they back off into the fog (moving; removed once nobody can see them)
	for s in skitters:
		_anim(s, "scuttle")
		_move(s, [s.global_position + (s.global_position - house.global_position).normalized() * 26.0], 6.0)
	await get_tree().create_timer(4.5).timeout
	_free_unseen(skitters)
	Game.set_flag("ch14_skitters_done")


var _mash_on := false
var _mash_count := 0


func _input(e: InputEvent) -> void:
	if _mash_on and ((e.is_action_pressed("interact") and not e.is_echo()) or (e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)):
		_mash_count += 1
		c12._shake(0.12, 0.012)
		Sfx.play("door_close", player.global_position + Vector3(0, 1.0, 0), -8.0, randf_range(0.5, 0.8))
		get_viewport().set_input_as_handled()


## A struggle you can SEE the effect of: press E / click repeatedly, `need` presses in `secs` seconds, with the count on screen. Returns whether it was won.
func _mash(label: String, need: int, secs: float) -> bool:
	_mash_on = true
	_mash_count = 0
	var t := secs
	while t > 0.0 and _mash_count < need:
		_hint("%s   [%s%s]   E / CLICK, FAST   %d" % [label, "#".repeat(_mash_count), "-".repeat(maxi(need - _mash_count, 0)), ceili(t)])
		await get_tree().process_frame
		t -= get_process_delta_time()
	_mash_on = false
	_hint("")
	return _mash_count >= need


func _brace_window(_b: Node) -> void:
	if not _busy.get("brace_open", false) or _busy.get("bracing", false):
		return
	_busy["bracing"] = true
	# hold the window: the plank goes across as you press (review note #63: a click used to do nothing at all)
	Sfx.play("door_close", hl(c10.WINDOW), 2.0, 0.6)
	var ok := await _mash("BRACE THE WINDOW", 8, 7.0)
	_busy["bracing"] = false
	if ok:
		_busy["brace_open"] = false
		if not props.has("def_window"):
			_place_defense("window", true)
		Sfx.play("door_close", hl(c10.WINDOW), 6.0, 0.5)
		c12._shake(0.3, 0.03)
		_hint("It holds.")
		get_tree().create_timer(2.0).timeout.connect(func(): _hint(""))
	_refresh_prompts()


func _free_unseen(list: Array) -> void:
	for c in list.duplicate():
		if not is_instance_valid(c):
			list.erase(c)
			continue
		var cam := world.get_viewport().get_camera_3d()
		if cam == null or not cam.is_position_in_frustum((c as Node3D).global_position + Vector3(0, 0.5, 0)) \
				or (c as Node3D).global_position.distance_to(player.global_position) > 24.0:
			(c as Node3D).queue_free()
			list.erase(c)


## Which door goes first: the one that was not barricaded (the front if both or neither were).
func weak_door() -> String:
	var d: Dictionary = st().get("defenses", {})
	if d.has("front") and not d.has("back"):
		return "back"
	return "front"


func _hounds() -> void:
	var door := weak_door()
	var out_pt: Vector3 = hl(FRONT_OUT) if door == "front" else hl(BACK_OUT)
	var in_pt: Vector3 = hl(FRONT_IN) if door == "front" else hl(BACK_IN)
	var target := rescue_target()
	st()["rescue_target"] = target
	# the survivor nearest that door is holding it (walked there, not placed)
	world.npc_walk(target, (hl(FRONT_IN + Vector3(-0.7, 0, 0.9)) if door == "front" else hl(BACK_IN + Vector3(0.7, 0, -0.9))), 1.6)
	_play("clank", hl(Vector3(0, 1, -20)), 2.0)
	await get_tree().create_timer(1.5).timeout
	for i in 2:
		var h := _make(VeilMeshyNpcs.monster_scene(HOUND_PATH), "C14_Hound%d" % i, HOUND_FROM[i])
		hounds.append(h)
		_anim(h, "run")
	_hold(true)
	await c8._turn_to(hl(FRONT_OUT + Vector3(0, 0.8, -6.0)) if door == "front" else hl(c10.WINDOW + Vector3(0, -0.4, -4.0)), 1.0)
	_move(hounds[0], [out_pt + (out_pt - in_pt).normalized() * 2.0], 6.5)
	_move(hounds[1], [hl(WINDOW_OUT + Vector3(-5.0, 0, -4.0))], 5.0)
	await c9._talk_group(_pick("c14_hounds"), [_node("Eddie"), _node(target)])
	_hold(false)
	# it throws itself at the door: a barricaded door holds longer
	_anim(hounds[0], "attack")
	var hold_s := 9.0 if st().get("defenses", {}).has(door) else 4.0
	var t := 0.0
	while t < hold_s:
		_play("claw", out_pt + Vector3(0, 1, 0), 4.0)
		c12._shake(0.25, 0.02)
		await get_tree().create_timer(1.1).timeout
		t += 1.1
	await c9._talk_group("c14_failing", [_node(target)])
	# it breaks: the door gives, the barricade goes over, the Hound forces its way in
	var it: Interactable = c10.its.get("door") if door == "front" else its.get("INT_Door_Back")
	if it and not it.is_open:
		it.set_open(true, true)
		_door_collision(it)
	if props.has("def_" + door) and props["def_" + door]:
		(props["def_" + door] as Node3D).rotate_x(0.9)
	Sfx.play("door_close", in_pt, 8.0, 0.5)
	_hold(true)
	await _move(hounds[0], [out_pt, in_pt], 5.0)
	_anim(hounds[0], "attack")
	var a = world.animators.get(target)
	if a:
		a.set_mood("scared")
	await c8._turn_to(in_pt + Vector3(0, 0.6, 0), 0.6)
	_hold(false)
	await _rescue(in_pt, out_pt)
	Game.set_flag("ch14_hounds_done")


## Ten seconds from the moment control is back: shove the table across the doorway. The Hound is on the survivor, the survivor is shaken about; press E / click fast to heave the table
## across (review note #64: there was no button, failing showed nothing).
func _rescue(in_pt: Vector3, out_pt: Vector3) -> void:
	report["rescue_runs"] += 1
	var target := rescue_target()
	_rescue_left = 10.0
	_busy["shoved"] = false
	_refresh_prompts()
	var tn := _node(target)
	var a0 = world.animators.get(target)
	if a0:
		a0.set_mood("scared")
	var drag := create_tween().set_loops()
	drag.tween_property(tn, "rotation:z", 0.25, 0.18)
	drag.tween_property(tn, "rotation:z", -0.25, 0.18)
	var won := await _mash("SAVE %s - HEAVE THE TABLE" % target.to_upper(), 12, 10.0)
	drag.kill()
	tn.rotation.z = 0.0
	_busy["shoved"] = won
	if won:
		Sfx.play("door_close", player.global_position, 6.0, 0.5)
		c12._shake(0.3, 0.04)
		if hounds.size() > 0:
			var pushed := create_tween()
			pushed.tween_property(hounds[0], "global_position", hounds[0].global_position + (out_pt - in_pt).normalized() * 1.5, 0.3)
	else:
		_play("claw", in_pt, 8.0)                             # too slow: the Hound drags them down before it is driven off (hurt, never killed)
		Sfx.play("hurt", tn.global_position + Vector3(0, 1, 0), 2.0)
		var fall := create_tween()
		fall.tween_property(tn, "rotation:x", -1.35, 0.35)
		c12._shake(0.6, 0.06)
		await get_tree().create_timer(1.2).timeout
		tn.rotation.x = 0.0
	_rescue_left = -1.0
	var saved: bool = _busy.get("shoved", false)
	_refresh_prompts()
	if saved:
		st()["rescue"] = "saved"
		Game.set_flag("ch14_rescue_saved")
		if world.survivors:
			world.survivors.award("ch14_saved_" + target, {target: 10}, 5)
			world.survivors.remember(target, "saved_at_the_door")
	else:
		st()["rescue"] = "hurt"
		Game.set_flag("ch14_rescue_failed")
		if world.survivors:
			world.survivors.set_health(target, "serious")      # badly hurt: never killed here
			world.survivors.award("ch14_hurt_" + target, {}, -8)
			world.survivors.remember(target, "mauled_at_the_door")
		player.damage(10.0, in_pt)
	# it is driven back out (the table across the door, or the group together); both run off into the fog
	_anim(hounds[0], "run")
	await _move(hounds[0], [out_pt, out_pt + (out_pt - in_pt).normalized() * 25.0], 6.0)
	for h in hounds:
		_move(h, [h.global_position + (h.global_position - house.global_position).normalized() * 25.0], 6.0)
	await get_tree().create_timer(4.0).timeout
	_free_unseen(hounds)
	world.npc_walk(target, hl(spot(target)), 1.0 if not saved else 1.5)
	await c9._talk_group("c14_after_" + ("saved" if saved else "hurt"), [_node(target), _node("Eddie")])


func _shove(_b: Node) -> void:
	if _rescue_left <= 0.0:
		return
	_busy["shoved"] = true
	_rescue_left = 0.0
	Sfx.play("door_close", player.global_position, 6.0, 0.5)
	c12._shake(0.3, 0.04)


func _crab() -> void:
	_hold(true)
	_play("deep", hl(BACK_OUT + Vector3(0, 0, 4)), 8.0)
	c12._shake(1.0, 0.05)
	await c9._talk_group("c14_impact", [_node("Ruth")])
	crab = (load(VeilMeshyNpcs.monster_scene(CRAB_PATH)) as PackedScene).instantiate() as CharacterBody3D
	crab.name = "C14_Shellcrawler"
	world.add_child(crab)
	crab.collision_layer = 0
	crab.collision_mask = 1
	crab.global_position = CRAB_HIDE
	VeilCreatureLook.apply_ground(crab, crab.global_position.y)
	var ap := crab.get_node_or_null("Model/AnimationPlayer") as AnimationPlayer
	await c8._turn_to(hl(c10.WINDOW + Vector3(-1.0, -0.5, -6.0)), 1.0)
	if ap and ap.has_animation("Crawl_Sideways"):
		ap.play("Crawl_Sideways")
	_play("scrape", CRAB_HIDE, 6.0)
	await _move(crab, [hl(FRONT_OUT + Vector3(-1.5, 0, -2.6))], 2.2)
	if ap and ap.has_animation("Attack_Grasp"):
		ap.play("Attack_Grasp")
	_play("claw", hl(FRONT_OUT), 8.0)
	c12._shake(0.6, 0.06)
	await c9._talk_group("c14_crab", [_node("Eddie")])
	Game.set_flag("ch14_crab_seen")
	world.save_checkpoint("chapter15_evacuation")
	_hold(false)
	# the front is blocked: out the back. Prepared: it opens. Not prepared: force it under pressure.
	if Game.has_flag("ch14_escape_ready"):
		_open_back()
		_start_evac(false)
	else:
		_busy["force_open"] = true
		_refresh_prompts()
		_hint("The front is blocked! Force the back door!")


func _force_back(_b: Node) -> void:
	if not _busy.get("force_open", false):
		return
	_busy["force_open"] = false
	_hold(true)
	Sfx.play("door_close", hl(BACK_IN), 6.0, 0.6)
	c12._shake(0.5, 0.05)
	await get_tree().create_timer(1.2).timeout
	_hold(false)
	st()["escape"] = "forced"
	_open_back()
	_start_evac(false)


func _open_back() -> void:
	for n in ["INT_Door_Kitchen", "INT_Door_Back"]:
		var it: Interactable = its.get(n)
		if it and not it.is_open:
			it.set_open(true, false)
			_door_collision.call_deferred(it)
	if props.has("def_back") and props["def_back"]:
		(props["def_back"] as Node3D).visible = false


# ------------------------------------------------------------------ the evacuation, the last decision
func _start_evac(restoring: bool) -> void:
	if not restoring:
		Game.set_flag("ch14_evac_started")
	report["evac_runs"] += 1
	if restoring:
		_open_back()
		if Game.has_flag("ch14_separation") and not Game.has_flag("ch14_separation_made"):
			# (QA-003) saved mid-separation: a choice already made keeps its consequences (applied once) and is
			# completed; otherwise the decision is offered again at the fence.
			if String(st().get("separation", "")) != "":
				Game.set_flag("ch14_separation_made")
			else:
				Game.flags.erase("ch14_separation")
				st().erase("separated")
	if not restoring:
		_spread()                                                      # (review note #65: after the attack everyone stood in one kitchen corner, inside each other)
	for k in present():
		var f: VeilCompanionFollow = c9.follows[k]
		c9._start_follow(k)
		match _health(k):
			"serious":
				f.walk_speed = 1.2
				f.run_speed = 2.6
			"injured":
				f.walk_speed = 1.6
				f.run_speed = 3.4
		if restoring:
			c12._rejoin.call_deferred(k)
	var nn := _noah_node()
	if nn != null:                                                  # Noah goes with the group (he is never the one caught at the door or the fence)
		nn.visible = true
		if not c12.noah.noah_follow.active:
			c12.noah.noah_follow.start()
	if not restoring:
		await c9._talk_group(_pick("c14_go"), [_node("Eddie")])
	_set_fog(true, 0.7)
	_refresh_prompts()
	_guide()
	_pressure()


## Pressure on the way out, from places it can come from (no endless spawning): the Shellcrawler rounds the house,
## a Skitter crosses the field at a distance, a Hound calls in the fog.
func _pressure() -> void:
	await get_tree().create_timer(5.0).timeout
	if crab and is_instance_valid(crab):
		_move(crab, [hl(Vector3(5.5, 0, 6.0)), hl(Vector3(5.0, 0, 13.5))], 1.8)
	if world.expedition and not Game.has_flag("ch14_safe"):
		world.expedition.skitter_crossing(Vector3(-80.0, 0.2, 48.0), Vector3(-118.0, 0.2, 40.0))
	await get_tree().create_timer(8.0).timeout
	_play("clank", player.global_position + Vector3(20, 1, -10), 0.0)


func _evac_tick() -> void:
	if not Game.has_flag("ch14_evac_started") or Game.has_flag("ch14_safe"):
		return
	var p := player.global_position
	if not Game.has_flag("ch14_separation") and p.distance_to(FENCE_AT) < 6.0 and not _busy.get("decide", false) and not Dialogue.is_busy() \
			and not world.conversing:
		_separation()
	if Game.has_flag("ch14_separation_made") and p.distance_to(SAFE) < 6.0 and not _busy.get("ending", false):
		_ending()
	# a survivor left behind slips from sight only once nobody can see them
	var k := String(st().get("left_pending", ""))
	if k != "":
		var cam := world.get_viewport().get_camera_3d()
		var n := _node(k)
		if cam and (not cam.is_position_in_frustum(n.global_position + Vector3(0, 1, 0)) or n.global_position.distance_to(p) > 30.0):
			n.visible = false
			st()["left_pending"] = ""


## Two Hounds and a Skitter come out of the fog and close in on the one caught behind the fence: the ring tightens, they snap and lunge, the survivor backs against the fence.
var _chasers: Array = []


func _surround(k: String) -> void:
	_hold(true)
	var n := _node(k)
	var c: Vector3 = n.global_position
	await c8._turn_to(c + Vector3(0, 1.2, 0), 0.8)
	var specs := [[HOUND_PATH, Vector3(9.0, 0, -4.0)], [HOUND_PATH, Vector3(-8.0, 0, -6.0)], [SKITTER_PATH, Vector3(1.0, 0, 10.0)]]
	for i in specs.size():
		var h := _make(VeilMeshyNpcs.monster_scene(String(specs[i][0])), "C14_Chaser%d" % i, c + specs[i][1])
		_chasers.append(h)
		_anim(h, "run" if i < 2 else "scuttle")
		var ring: Vector3 = c + Vector3(cos(TAU * i / 3.0 + 0.6), 0, sin(TAU * i / 3.0 + 0.6)) * 1.5
		_move(h, [ring], 6.5)
	_play("claw", c, 4.0)
	await get_tree().create_timer(1.6).timeout
	for h in _chasers:
		_anim(h, "attack")
		h.look_at(Vector3(c.x, h.global_position.y, c.z), Vector3.UP)
	var a = world.animators.get(k)
	if a:
		a.set_mood("scared")
	c12._shake(0.8, 0.03)
	_play("claw", c, 6.0)
	await get_tree().create_timer(1.2).timeout
	_hold(false)


func _tragedy(k: String) -> void:
	_hold(true)
	var n := _node(k)
	var c: Vector3 = n.global_position
	# the player turns away from them and runs: the camera swings round, the screams carry on behind
	var away := (player.global_position - c) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	await c8._turn_to(player.global_position + away * 8.0 + Vector3(0, 1.4, 0), 1.0)
	for h in _chasers:
		_anim(h, "attack")
	var run_to: Vector3 = player.global_position + away * 7.0
	var tw := create_tween()
	tw.tween_property(player, "global_position", run_to, 2.4).set_trans(Tween.TRANS_SINE)
	for i in 4:
		_play("claw", c, 6.0 - i)
		Sfx.play("hurt", c + Vector3(0, 1, 0), 3.0 - i, 0.8)
		c12._shake(0.5, 0.03)
		await get_tree().create_timer(0.6).timeout
	await tw.finished
	var cam := world.get_viewport().get_camera_3d()
	var blk := StaticBody3D.new()                                   # no going back for them: the way is shut behind the player
	blk.name = "C14_NoGoingBack"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(14.0, 4.0, 0.8)
	cs.shape = bx
	blk.add_child(cs)
	world.add_child(blk)
	blk.global_position = FENCE_AT + Vector3(0, 2.0, 0)
	_hint("There is nothing you can do for them now.")
	get_tree().create_timer(4.0).timeout.connect(func(): _hint(""))
	_hold(false)


func _separation() -> void:
	var k := separation_target()
	Game.set_flag("ch14_separation")
	if k == "":
		# nobody else can be put at risk here: the packs are lost in the scramble instead
		for item in ["canned_food", "water_bottle"]:
			if Game.has_item(item):
				Game.remove_item(item)
		st()["separation"] = "supplies"
		Game.set_flag("ch14_separation_made")
		Dialogue.say("c14_lost_supplies", false, true)
		return
	_busy["decide"] = true
	report["decision_runs"] += 1
	st()["separated"] = k
	var f: VeilCompanionFollow = c9.follows[k]
	f.stop()
	var a = world.animators.get(k)
	if a:
		a.walk_to([])
		a.set_mood("scared")
	await _surround(k)                                              # review note #66: first SEE why they are left: monsters close in round them behind the fence
	await c9._talk_group("c14_trapped_" + k, [_node(k)])
	var i := -1
	while i < 0 and is_inside_tree():
		i = await p4.choice.ask("%s is caught behind the fence. Something is coming." % k, ["Go back for %s" % k, "Keep moving"], player)
	if i == 0:
		st()["separation"] = "went_back"
		_hold(true)
		await hud.fade_to(0.85, 0.4)
		player.damage(15.0, player.global_position + Vector3(0, 0, -2))
		await get_tree().create_timer(1.2).timeout
		await hud.fade_to(0.0, 0.4)
		_hold(false)
		c9._start_follow(k)
		if world.survivors:
			world.survivors.award("ch14_went_back_" + k, {k: 10}, 5)
			world.survivors.remember(k, "came_back_for_me")
		await c9._talk_group("c14_went_back", [_node(k)])
	else:
		st()["separation"] = "left"
		await _tragedy(k)                                           # you turn your back and run; they are overwhelmed; and there is no going back
		var miss: Array = st().get("missing", [])
		if not (k in miss):
			miss.append(k)
		st()["missing"] = miss
		st()["left_pending"] = k
		Game.set_flag("ch14_%s_missing" % k.to_lower())
		if world.survivors:
			world.survivors.award("ch14_left_" + k, {}, -10)
			for other in present():
				world.survivors.remember(other, "left_%s_behind" % k)
		await c9._talk_group("c14_kept_moving", [_node("Eddie")])
	Game.set_flag("ch14_separation_made")
	_busy["decide"] = false


# ------------------------------------------------------------------ the end: the shelter falls
func _ending() -> void:
	if Game.has_flag("chapter_14_complete") or _busy.get("ending", false):
		return
	_busy["ending"] = true
	report["ending_runs"] += 1
	Game.set_flag("ch14_safe")
	world.save_checkpoint("chapter15_safe")
	var t := 0.0
	while t < 8.0 and not present().all(func(k): return _node(k).global_position.distance_to(SAFE) < 7.0):
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	_hold(true)
	if _noah_node() != null:
		c12.noah.noah_follow.stop()
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	await c8._turn_to(house.global_position + Vector3(0, 3.0, 0), 1.6)
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.72, 1.6)
	await tz.finished
	_play("deep", house.global_position, 10.0)
	for i in 6:
		lamp.light_energy = 1.4 if i % 2 == 0 else 0.0
		await get_tree().create_timer(0.2).timeout
	c12._shake(1.2, 0.03)
	_set_fog(true, 1.6)
	c12._dust()
	await get_tree().create_timer(1.6).timeout
	_house_gone(true)                                  # gone into the fog
	_play("deep", house.global_position + Vector3(0, -6, 0), 6.0)
	await get_tree().create_timer(1.6).timeout
	_set_fog(true, 0.7)
	var tb := create_tween()
	tb.tween_property(cam, "fov", fov0, 1.0)
	await tb.finished
	cam.fov = fov0
	_hold(false)
	var npcs: Array = [_node("Eddie")]
	for k in ["Ruth", "Sarah", "Marcus"]:
		if k in present():
			npcs.append(_node(k))
			break
	await c9._talk_group(_pick_end(), npcs)
	_hold(true)
	await c8._turn_to(player.global_position + Vector3(0, -1.0, 0) - player.global_transform.basis.z * 0.6, 1.2)
	Dialogue.say("c14_back", false, true)
	while Dialogue.is_busy():
		await get_tree().process_frame
	await hud.fade_to(1.0, 1.6)
	report["ending_fov_restored"] = absf(cam.fov - fov0) < 0.01
	_set_fog(false)
	Game.set_flag("chapter_14_complete")             # Chapter 16 is NOT started here
	st()["completed"] = {"roster": present(), "missing": st().get("missing", []), "rescue": st().get("rescue", ""), "separation": st().get("separation", ""),
		"defenses": st().get("defenses", {}).keys(), "escape": st().get("escape", "")}
	world.save_checkpoint("chapter15_end")
	await hud.chapter_complete(CHAPTER)
	await hud.title_card("NEXT:  CHAPTER 16  -  WHAT REMAINS", 2.2)
	await hud.fade_to(0.0, 1.2)
	_hold(false)
	_busy["ending"] = false
	_guide()
	_start_chapter15(false)                          # the finale: displayed Chapter 16


## The next (last) chapter: displayed CHAPTER 16 "What Remains", internally chapter15.gd.
var chapter15: Node
func _start_chapter15(restoring: bool) -> void:
	if chapter15 != null:
		return
	chapter15 = load("res://game/world/chapter15.gd").new()
	chapter15.name = "Chapter15"
	add_child(chapter15)
	chapter15.begin(world, self, restoring)


func _pick_end() -> String:
	if "Marcus" in present():
		return "c14_end_Marcus"
	if "Sarah" in present():
		return "c14_end_Sarah"
	return "c14_end_Ruth"


## The shelter is gone: hidden (it went into the fog), and none of it blocks any more.
func _house_gone(gone: bool) -> void:
	if not gone:
		return
	house.visible = false
	lamp.light_energy = 0.0
	for co in house.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0
	for n in props:
		if String(n).begins_with("def_") and props[n]:
			(props[n] as Node3D).visible = false


func _set_fog(thick: bool, amount := 1.0) -> void:
	var env: Environment = player.camera.environment if player and player.camera else null
	if env == null:
		var we := world.find_child("WorldEnvironment", true, false) as WorldEnvironment
		env = we.environment if we else null
	if env == null:
		return
	if _fog0 < 0.0:
		_fog0 = world.fog_zones.base_density(env) if world.get("fog_zones") else env.fog_density    # (unscaled by the local fog)
	env.fog_density = _fog0 * (1.0 + 1.6 * amount) if thick else _fog0


func _exit_tree() -> void:
	_set_fog(false)


# ------------------------------------------------------------------ helpers, per tick
func _hint(t: String) -> void:
	c10._hint(t)


func _hold(on: bool) -> void:
	player.set("controls_enabled", not on)
	player.velocity = Vector3.ZERO


func _play(id: String, at: Vector3, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[id]
	p.volume_db = db
	p.unit_size = 16.0
	p.max_distance = 120.0
	world.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


func _process(delta: float) -> void:
	if world == null:
		return
	_run_tick(delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.2
	if not Game.has_flag("chapter_14_complete"):
		_window_tick()
	_evac_tick()
	if _rescue_left > 0.0:
		_refresh_prompts()
	if not _busy.get("window", false) and not _busy.get("ending", false):
		_guide()
	if its.has("talk_Eddie") and not _busy.get("siege", false) and chapter15 == null:
		var on: bool = _prep_done() and not Game.has_flag("ch14_siege_started") and not st().get("talked", {}).get("Eddie", false)
		_setp("talk_Eddie", "[E] Talk to Eddie" if on else "")
