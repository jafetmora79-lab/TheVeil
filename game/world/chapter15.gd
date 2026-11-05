extends Node
class_name VeilChapter15
## THE VEIL - displayed CHAPTER 16 "What Remains", the finale (internal ids keep the file numbering: chapter15.gd,
## flags ch15_*, chapter_15_complete). Starts after "The Last Shelter" (flag chapter_14_complete), created by
## chapter14.gd. State: story flags + Game.world_state["ch15"]; the endings reached go to user://veil_endings.json.
##
## The old maintenance station by the road (a roadside refuge, nothing more): the people who made it out of the
## mill-worker house (never the dead, never whoever was left behind); the map; preparation from what was carried
## (treat, the refuge's last supplies, talks that remember trust and earlier choices) -> the plan -> the road west:
## a few finds (medicine, batteries, water, a last note about earlier escapes) -> the Colossus crosses the fields:
## first person, then cover to cover while it walks and looks (seen in the open: it reacts, the ground shakes, back to
## the last cover - a fair retry) -> the district: a Skitter on the roofs, a Hound up the road behind; the passage ->
## the rubble of Chapter 14's collapse, a gap -> the sealed doorway, open; the ancient passage beyond it (one
## mist-filled pocket to avoid) -> the great chamber: the symbols, the damaged seals, records of earlier containment,
## the stone structure, a shape behind it -> two control points and the final mechanism under falling stone -> the
## decision (ESCAPE / SEAL THE CHAMBER / SEND THE SURVIVORS AHEAD) -> ending A, B or C, the epilogue (from the real
## roster and states), THE VEIL, credits, THANK YOU FOR PLAYING, the menu. No chapter follows.

const STATE := "ch15"
const CHAPTER := 16
const A := "res://THE_VEIL_ASSETS_V2/"
const SKITTER_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const COLOSSUS_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Colossus.tscn"
const HOUND_AI := preload("res://game/enemies/hound_ai.gd")
const ENDINGS_PATH := "user://veil_endings.json"
const ENDING_TITLES := {"A": "ENDING A  -  BEYOND THE MIST", "B": "ENDING B  -  THE SILENCE BELOW", "C": "ENDING C  -  WHAT REMAINS"}
# ---- the refuge: the maintenance station's office (facility-local of chapter12.gd)
const REFUGE_SPOTS := {"Eddie": Vector3(-2.6, 0.05, 2.2), "Ruth": Vector3(-2.4, 0.05, 4.4), "Sarah": Vector3(-0.6, 0.05, 5.0), "Marcus": Vector3(1.2, 0.05, 5.1)}
const REFUGE_PLAYER := Vector3(0.6, 0.1, 1.6)
const REFUGE_FINDS := [["water_bottle", Vector3(-3.3, 0.9, 5.2)], ["batteries", Vector3(-2.0, 0.05, 5.4)]]
# ---- the road west and the fields (world)
const ROUTE := [Vector3(-80.0, 0.2, -22.5), Vector3(-78.6, 0.2, -16.0), Vector3(-82.0, 0.2, -10.0), Vector3(-88.0, 0.2, 0.0), Vector3(-96.5, 0.2, -0.8), Vector3(-103.5, 0.2, -0.8), Vector3(-104.0, 0.2, 2.0)]   # round the pickup from Ch. 15
const FINDS := [["painkillers", Vector3(-84.6, 0.2, -5.0)], ["batteries", Vector3(-92.0, 0.2, 2.8)], ["water_bottle", Vector3(-100.5, 0.2, 0.6)],
	["last_note", Vector3(-96.0, 0.2, 3.6)]]
const COVERS := [Vector3(-104.0, 0.2, 2.0), Vector3(-107.0, 0.2, 6.8), Vector3(-110.5, 0.2, 12.4), Vector3(-114.0, 0.2, 18.0)]
const CROSS_END := Vector3(-121.0, 0.2, 31.0)
const COLOSSUS_X := -152.0
# ---- below: chapter13.gd's underground frame (U); this chapter adds the ancient passage and the great chamber
const GAP := Vector3(12.0, 0.0, 23.0)
const MIST_POCKET := [Vector3(18.0, 0.0, 51.0), 3.6]
const GREAT := Vector3(12.0, 0.0, 78.0)                  # the chamber's centre (x -6..30, z 62..96)
const SEAL := Vector3(12.0, 0.0, 86.0)
const CTRL_A := Vector3(-3.2, 0.0, 74.0)
const CTRL_B := Vector3(27.2, 0.0, 74.0)
const CTRL_C := Vector3(12.0, 0.0, 80.4)
const OUTER := Vector3(30.0, 0.0, 70.0)                 # the outer service tunnel (east wall), out to beyond the town
const OUTER_END := Vector3(44.0, 0.0, 70.0)
const CLUES := {"symbols": [Vector3(-5.6, 2.0, 80.0), "Examine the Symbols"], "seals": [Vector3(8.5, 1.4, 82.2), "Examine the Damaged Seals"],
	"records": [Vector3(26.0, 1.0, 92.0), "Examine the Old Records"], "tunnel": [Vector3(29.2, 1.4, 70.0), "Look Down the Service Tunnel"]}
# ---- beyond the town: the fields south of the farmhouses, looking back north at Greyhaven
const BEYOND := Vector3(-104.0, 0.2, -104.0)
const BEYOND_SPOTS := {"Eddie": Vector3(-105.8, 0.2, -103.0), "Ruth": Vector3(-102.2, 0.2, -102.6), "Sarah": Vector3(-103.0, 0.2, -105.6), "Marcus": Vector3(-105.0, 0.2, -105.8)}

var world: Node
var c14: Node
var c13: Node
var c12: Node
var c10: Node
var c9: Node
var c8: Node
var p4: Node
var player: Node3D
var hud: Node
var below: Node3D
var its := {}
var props := {}
var colossus: Node3D
var col_anim: AnimationPlayer
var silhouette: MeshInstance3D
var seal_slab: Node3D
var outer_block: Node3D
var creatures: Array = []
var report := {"detections": 0, "retries": 0, "debris_hits": 0, "colossus_runs": 0, "ending_runs": 0, "chamber_runs": 0}
var _busy := {}
var _tick := 0.0
var _streams := {}
var _fog0 := -1.0
var _col_phase := "walk"
var _col_t := 0.0
var _last_cover := 0
var _danger_t := -1.0
var _debris_t := 0.0
var _menu: CanvasLayer


func begin(w: Node, chapter14: Node, restoring: bool) -> void:
	world = w
	c14 = chapter14
	c13 = c14.c13
	c12 = c14.c12
	c10 = c14.c10
	c9 = c14.c9
	c8 = c14.c8
	p4 = c14.p4
	player = w.player
	hud = w.hud
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"roster": present(), "talked": {}, "clues": {}, "controls": {}, "decision": "", "ending": "", "endings_seen": []}
	_streams = c13._streams
	_setup_refuge()
	_setup_road()
	_setup_below()
	var fresh := not Game.has_flag("ch15_started")
	if fresh:
		Game.set_flag("ch15_started")
		_opening.call_deferred()
	else:
		_apply()
	Game.refresh_objective()


func st() -> Dictionary:
	return Game.world_state[STATE]


func present() -> Array:
	return c14.present()


func _node(k: String) -> Node3D:
	return c10._node(k)


func _health(k: String) -> String:
	return world.survivors.health(k) if world.survivors else "healthy"


func _trust(k: String) -> int:
	return world.survivors.trust(k) if world.survivors else 50


func F(p: Vector3) -> Vector3:
	return c12.L(p)


func UL(p: Vector3) -> Vector3:
	return c13.UL(p)


## Who speaks for the group: Eddie if he is here, else Ruth, else whoever is.
func voice() -> String:
	for k in ["Eddie", "Ruth", "Sarah", "Marcus"]:
		if k in present():
			return k
	return ""


func _second() -> String:
	for k in ["Ruth", "Sarah", "Marcus", "Eddie"]:
		if k in present() and k != voice():
			return k
	return voice()


## A shared scene's lines for whoever is actually here: "<base>" is written for Eddie and Ruth; "<base>_alt" has the
## same lines spoken by others when either is missing.
func _pick(base: String) -> String:
	if "Eddie" in present() and "Ruth" in present():
		return base
	return base + "_alt" if Dialogue.data.has(base + "_alt") else base


## The shared talk camera, with "@1"/"@2" speakers filled in from who is actually here.
func _tg(id: String, npcs: Array) -> void:
	await c9._talk_group(_cast(id), npcs)


func _cast(id: String) -> String:
	var e: Dictionary = Dialogue.data.get(id, {})
	var lines: Array = e.get("lines", [])
	if not lines.any(func(l): return String(l.get("speaker", "")).begins_with("@")):
		return id
	var cast := {"@1": voice(), "@2": _second()}
	var out := e.duplicate(true)
	for l in out["lines"]:
		var sp := String(l.get("speaker", ""))
		if cast.has(sp):
			l["speaker"] = cast[sp]
	Dialogue.data[id + "__cast"] = out
	return id + "__cast"


# ------------------------------------------------------------------ setup
func _setup_refuge() -> void:
	for i in REFUGE_FINDS.size():
		_pickup(REFUGE_FINDS[i][0], F(REFUGE_FINDS[i][1]), "ch15/refuge%d" % i)
	its["plan"] = c10._spot("C15_Plan", F(Vector3(3.0, 1.0, 3.0)), Vector3(1.6, 1.0, 1.6), _plan)
	its["supplies"] = c10._spot("C15_Supplies", F(Vector3(-3.4, 1.0, 5.3)), Vector3(0.9, 1.4, 0.9), _supplies)
	its["setout"] = c10._spot("C15_SetOut", F(c12.EXIT_DOOR + Vector3(0, 0, 0.35)), Vector3(1.4, 2.2, 0.5), _set_out)
	for k in ["Ruth", "Sarah", "Marcus"]:
		var it := Interactable.attach(_node(k), {"kind": "custom", "label": k + "_c15", "prompt_text": ""})
		it.used.connect(_talk.bind(k))
		its["talk_" + k] = it
	var e: Interactable = p4.its.get("npc_Eddie")
	if e:
		e.used.connect(_talk.bind("Eddie"))
		its["talk_Eddie"] = e


func _pickup(item: String, at: Vector3, key: String) -> void:
	var path := String(Game.item_info(item).get("model", ""))
	var ps := load(path) as PackedScene if path != "" else null
	if ps == null:
		return
	var n := ps.instantiate() as Node3D
	n.name = "C15_" + key.get_file()
	world.add_child(n)
	n.global_position = at
	var it := Interactable.attach(n, {"kind": "pickup", "label": Game.item_info(item).get("name", item), "item_id": item, "state_key": key})
	var cs := it.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = (cs.shape as BoxShape3D).size.max(Vector3(0.6, 0.5, 0.6))
	props[key] = n


func _setup_road() -> void:
	for i in FINDS.size():
		_pickup(FINDS[i][0], FINDS[i][1], "ch15/find%d" % i)
	# cover: three cars between the road and the fields the Colossus crosses (west of each cover point)
	var cars := ["VEH_Sedan_Dusty", "VEH_Sedan_Damaged", "VEH_Pickup_Abandoned"]
	for i in range(1, COVERS.size()):
		var west := Vector3(-0.85, 0, -0.53)
		c13._solid("05_Vehicles/Abandoned_Variants/%s.glb" % cars[i - 1], "C15_Cover%d" % i, COVERS[i] + west * 2.4, atan2(-0.53, 0.85))


## Below: the rubble left by Chapter 14's collapse (a gap to squeeze through), the doorway open, and beyond it the
## ancient passage and the great chamber (stone, symbols, the structure, the controls, the outer tunnel).
func _setup_below() -> void:
	below = Node3D.new()
	below.name = "C15_Below"
	world.add_child(below)
	c13.doorway_slab.global_position = UL(c13.DOORWAY + Vector3(0, -4.2, 0))
	var thr := c13.under.get_node_or_null("Threshold") as CollisionObject3D
	if thr:
		thr.collision_layer = 0
	its["gap"] = c10._spot("C15_Gap", UL(GAP + Vector3(0, 1.2, 0)), Vector3(2.4, 2.2, 1.0), _squeeze)
	# the ancient passage (x 10..14, z 40..62), a mist pocket to its east (x 14..22, z 47..55)
	_b(Vector3(12.0, -0.15, 79.0), Vector3(44.0, 0.3, 80.0), "stone")
	_b(Vector3(9.85, 1.6, 51.0), Vector3(0.3, 3.2, 22.0), "stone")
	_b(Vector3(14.15, 1.6, 44.0), Vector3(0.3, 3.2, 8.0), "stone")
	_b(Vector3(14.15, 1.6, 58.5), Vector3(0.3, 3.2, 7.0), "stone")
	_b(Vector3(18.0, 1.6, 47.0), Vector3(8.0, 3.2, 0.3), "stone")
	_b(Vector3(18.0, 1.6, 55.0), Vector3(8.0, 3.2, 0.3), "stone")
	_b(Vector3(22.0, 1.6, 51.0), Vector3(0.3, 3.2, 8.0), "stone")
	_b(Vector3(16.0, 3.3, 51.0), Vector3(12.6, 0.3, 24.6), "stone")
	# the great chamber (x -6..30, z 62..96, 9 m high)
	for w in [[Vector3(1.5, 4.5, 62.0), Vector3(15.0, 9.0, 0.4)], [Vector3(22.5, 4.5, 62.0), Vector3(15.0, 9.0, 0.4)], [Vector3(12.0, 6.6, 62.0), Vector3(6.0, 4.8, 0.4)],
			[Vector3(12.0, 4.5, 96.0), Vector3(36.4, 9.0, 0.4)], [Vector3(-6.0, 4.5, 79.0), Vector3(0.4, 9.0, 34.0)],
			[Vector3(30.0, 4.5, 65.35), Vector3(0.4, 9.0, 6.7)], [Vector3(30.0, 4.5, 83.65), Vector3(0.4, 9.0, 24.7)], [Vector3(30.0, 5.9, 70.0), Vector3(0.4, 6.2, 2.6)]]:
		_b(w[0], w[1], "stone")
	_b(Vector3(12.0, 9.1, 79.0), Vector3(36.4, 0.3, 34.4), "stone")
	# the outer service tunnel (x 30..44, z 68.8..71.2): out beyond the town
	_b(Vector3(37.0, 1.4, 68.6), Vector3(14.0, 2.8, 0.3), "damp")
	_b(Vector3(37.0, 1.4, 71.4), Vector3(14.0, 2.8, 0.3), "damp")
	_b(Vector3(44.2, 1.4, 70.0), Vector3(0.3, 2.8, 3.0), "damp")
	_b(Vector3(37.0, 2.95, 70.0), Vector3(14.0, 0.3, 3.0), "damp")
	outer_block = _b(Vector3(31.0, 1.4, 70.0), Vector3(0.6, 2.8, 2.6), "stone")
	outer_block.visible = false
	outer_block.collision_layer = 0
	# the structure: a huge stone block, cracked open; the seal stone that can close it
	_b(Vector3(5.5, 3.5, 88.0), Vector3(5.0, 7.0, 8.0), "stone")
	_b(Vector3(18.5, 3.5, 88.0), Vector3(5.0, 7.0, 8.0), "stone")
	_b(Vector3(12.0, 6.0, 88.0), Vector3(8.0, 2.0, 8.0), "stone")
	_b(Vector3(12.0, 3.0, 92.2), Vector3(8.0, 6.0, 0.4), "stone")
	seal_slab = _b(SEAL + Vector3(0, 2.5 + 4.6, 0), Vector3(8.0, 5.0, 0.6), "stone")
	for p in [[Vector3(-5.78, 3.0, 70.0), Vector3(1, 0, 0), 1.4], [Vector3(-5.78, 2.4, 80.0), Vector3(1, 0, 0), 1.0], [Vector3(-5.78, 3.4, 90.0), Vector3(1, 0, 0), 1.6],
			[Vector3(29.78, 3.0, 80.0), Vector3(-1, 0, 0), 1.2], [Vector3(29.78, 3.4, 90.0), Vector3(-1, 0, 0), 1.4], [Vector3(12.0, 5.6, 83.7), Vector3(0, 0, -1), 2.4],
			[Vector3(2.0, 3.0, 95.78), Vector3(0, 0, -1), 1.2], [Vector3(22.0, 3.0, 95.78), Vector3(0, 0, -1), 1.2], [Vector3(11.0, 1.8, 61.8), Vector3(0, 0, -1), 0.8]]:
		c12._decal(UL(p[0]), p[1], p[2], Color(0.07, 0.06, 0.05, 1))
	for p in [Vector3(12.0, 7.5, 70.0), Vector3(0.0, 6.0, 80.0), Vector3(24.0, 6.0, 80.0), Vector3(12.0, 2.6, 50.0)]:
		var l: OmniLight3D = c12._light(UL(p), 0.5, 14.0, Color(0.7, 0.78, 0.95))
		l.reparent(below)
	# the shape behind the seal (dark, indistinct; never a model)
	silhouette = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 2.6
	cap.height = 7.5
	silhouette.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.025, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	silhouette.material_override = m
	below.add_child(silhouette)
	silhouette.global_position = UL(SEAL + Vector3(0, 3.6, 3.2))
	# mist: through the cracks, and the dangerous pocket
	var flow: CPUParticles3D = c13._mist_flow(UL(SEAL + Vector3(0, 2.0, 1.0)), Vector3(0, 0, -1))
	flow.emission_box_extents = Vector3(3.5, 2.0, 0.5)
	flow.reparent(below)
	for k in 3:
		c13._mist_quad(below, UL(MIST_POCKET[0] + Vector3(0, 0.3 + k * 0.7, 0)), Vector2(7.6, 7.6), 0.55 - k * 0.12)
	# props: the controls (existing utility props), old tools
	for c in [[CTRL_A, -PI * 0.5, "02_Town/Utilities/UT_JunctionBox.glb"], [CTRL_B, PI * 0.5, "02_Town/Utilities/UT_JunctionBox.glb"],
			[CTRL_C, PI, "02_Town/Utilities/UT_ElectricalCabinet.glb"]]:
		var o: Node3D = c12._prop(c[2], "C15_Ctrl", UL(c[0]), c[1])
		if o:
			o.reparent(below)
	its["ctrl_A"] = c10._spot("C15_CtrlA", UL(CTRL_A + Vector3(0.4, 1.1, 0)), Vector3(0.9, 1.4, 1.4), _control.bind("A"))
	its["ctrl_B"] = c10._spot("C15_CtrlB", UL(CTRL_B + Vector3(-0.4, 1.1, 0)), Vector3(0.9, 1.4, 1.4), _control.bind("B"))
	its["ctrl_C"] = c10._spot("C15_CtrlC", UL(CTRL_C + Vector3(0, 1.1, -0.5)), Vector3(1.6, 1.6, 0.8), _control.bind("C"))
	its["outer"] = c10._spot("C15_Outer", UL(OUTER_END + Vector3(-0.8, 1.2, 0)), Vector3(0.6, 2.2, 2.4), _leave_tunnel)
	for k in CLUES:
		its["clue_" + k] = c10._spot("C15_Clue_" + k, UL(CLUES[k][0]), Vector3(1.2, 1.4, 1.2), _examine.bind(k))


func _b(p: Vector3, size: Vector3, mat: String) -> StaticBody3D:
	return c12._box(below, "C15", UL(p), size, mat)


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	for k in ["Eddie", "Ruth", "Sarah", "Marcus"]:
		_node(k).visible = k in present()
	if Game.has_flag("ch15_gap_cleared"):
		c13.collapse_block.global_position = UL(c13.COLLAPSE + Vector3(-1.6, 0, 0))
	if not Game.has_flag("ch15_set_out"):
		_place_refuge()
	elif Game.has_flag("ch15_chamber_reached"):
		# a load in the great chamber (the decision checkpoint): the group stands by its entrance
		var i := 0
		for k in present():
			(c9.follows[k] as VeilCompanionFollow).stop()
			c9.c5._reparent(_node(k), world)
			world.place_survivor(_node(k), UL(GREAT + Vector3(-2.0 + 1.4 * i, 0.0, -12.5)))
			i += 1
		for k in present():
			c9._start_follow(k)
		_slow_injured()
	else:
		for k in present():
			c9._start_follow(k)
			c12._rejoin.call_deferred(k)
		_slow_injured()
	for k in st().get("controls", {}):
		_control_done_look(String(k))
	if Game.has_flag("ch15_set_out") and not Game.has_flag("ch15_crossed") and Game.has_flag("ch15_colossus_seen"):
		_spawn_colossus()
		_col_phase = "walk"
	if Game.has_flag("ch15_in_passage"):
		_set_fog(false)
	elif Game.has_flag("ch15_set_out"):
		_set_fog(true, 0.8)
	if Game.has_flag("ch15_mechanism_done") and not Game.has_flag("ch15_decided"):
		_decide.call_deferred()
	_refresh_prompts()
	_guide()


func _place_refuge() -> void:
	for k in present():
		(c9.follows[k] as VeilCompanionFollow).stop()
		c9.c5._reparent(_node(k), world)
		_node(k).visible = true
		world.place_survivor(_node(k), F(REFUGE_SPOTS[k]))
		var a = world.animators.get(k)
		if a:
			a.set_mood("scared" if _health(k) != "healthy" else "calm")


func _slow_injured() -> void:
	for k in present():
		var f: VeilCompanionFollow = c9.follows[k]
		match _health(k):
			"serious":
				f.walk_speed = 1.3
				f.run_speed = 2.8
			"injured":
				f.walk_speed = 1.7
				f.run_speed = 3.6


func _setp(k: String, t: String) -> void:
	var it: Interactable = its.get(k)
	if it:
		it.prompt_text = t
		it.collision_layer = 8 if t != "" else 0


func _refresh_prompts() -> void:
	var prep: bool = Game.has_flag("ch15_opening_done") and not Game.has_flag("ch15_set_out")
	_setp("supplies", "[E] Check What We Carried" if prep else "")
	_setp("plan", "[E] Study the Map Together" if prep and not Game.has_flag("ch15_plan_done") else "")
	_setp("setout", "[E] Set Out" if prep and Game.has_flag("ch15_plan_done") else "")
	for k in ["Eddie", "Ruth", "Sarah", "Marcus"]:
		var on: bool = prep and k in present() and not st().get("talked", {}).get(k, false)
		_setp("talk_" + k, ("[E] Talk to " + k) if on else "")
	_setp("gap", "[E] Squeeze Through the Rubble" if Game.has_flag("ch15_in_passage") and not Game.has_flag("ch15_gap_cleared") else "")
	var ch := Game.has_flag("ch15_chamber_reached") and not Game.has_flag("ch15_decided")
	var c: Dictionary = st().get("controls", {})
	_setp("ctrl_A", "[E] Pull the Old Lever" if ch and not c.has("A") else "")
	_setp("ctrl_B", "[E] Turn the Wheel" if ch and not c.has("B") else "")
	_setp("ctrl_C", "[E] Engage the Mechanism" if ch and c.has("A") and c.has("B") and not c.has("C") else "")
	var seen: Dictionary = st().get("clues", {})
	for k in CLUES:
		_setp("clue_" + k, ("[E] " + String(CLUES[k][1])) if Game.has_flag("ch15_chamber_reached") and not seen.get(k, false) and not _busy.get("final", false) else "")
	_setp("outer", "[E] Climb Out" if _busy.get("outer_open", false) else "")


func _guide() -> void:
	var t: Variant = null
	var label := ""
	var p := player.global_position
	if not Game.has_flag("ch15_opening_done"):
		pass
	elif not Game.has_flag("ch15_plan_done"):
		t = F(Vector3(3.0, 1.2, 3.0))
		label = "THE MAP"
	elif not Game.has_flag("ch15_set_out"):
		t = F(c12.EXIT_DOOR)
		label = "SET OUT"
	elif not Game.has_flag("ch15_colossus_seen"):
		var i := 0
		while i < ROUTE.size() - 1 and Vector2(p.x - ROUTE[i].x, p.z - ROUTE[i].z).length() < 6.0 + 0.0 * i:
			i += 1
		t = ROUTE[mini(i + 1, ROUTE.size() - 1)] + Vector3(0, 1.2, 0)
		label = "THE OLD DISTRICT"
	elif not Game.has_flag("ch15_crossed"):
		t = (COVERS[mini(_last_cover + 1, COVERS.size() - 1)] if _last_cover < COVERS.size() - 1 else CROSS_END) + Vector3(0, 1.0, 0)
		label = "NEXT COVER"
	elif not Game.has_flag("ch15_in_passage"):
		t = c13.D(c13.PASSAGE)
		label = "THE PASSAGE"
	elif not Game.has_flag("ch15_gap_cleared"):
		t = UL(GAP + Vector3(0, 1.2, 0))
		label = "RUBBLE"
	elif not Game.has_flag("ch15_chamber_reached"):
		t = UL(GREAT + Vector3(0, 1.4, -10.0))
		label = "BELOW"
	elif not Game.has_flag("ch15_mechanism_done"):
		var c: Dictionary = st().get("controls", {})
		t = UL((CTRL_A if not c.has("A") else (CTRL_B if not c.has("B") else CTRL_C)) + Vector3(0, 1.2, 0))
		label = "CONTROL"
	if hud.has_method("set_marker"):
		hud.set_marker(t, label)


# ------------------------------------------------------------------ scene 1: nowhere left to run
func _opening() -> void:
	_busy["opening"] = true
	_hold(true)
	await hud.fade_to(1.0, 0.8)
	_place_refuge()
	player.global_position = F(REFUGE_PLAYER)
	player.velocity = Vector3.ZERO
	var v: Vector3 = _node(voice()).global_position - player.global_position
	player.set_yaw_pitch(atan2(-v.x, -v.z), -0.15)
	c12._set_power(true, true)
	hud.location_caption("THE OLD MAINTENANCE STATION  -  A FEW HOURS LATER", 2.6)
	await get_tree().create_timer(1.6).timeout
	await hud.fade_to(0.0, 1.6)
	_play("clank", F(Vector3(20, 4, -30)), 0.0)
	_hold(false)
	await _tg(_pick("c15_open"), [_node(voice()), _node(_second())])
	await _tg("c15_map_under" if "Eddie" in present() else "c15_map_under_alt", [_node(voice())])
	Game.set_flag("ch15_opening_done")
	_busy["opening"] = false
	world.save_checkpoint("chapter16_start")
	_refresh_prompts()
	_guide()
	await hud.chapter_start(CHAPTER)


func _supplies(_b: Node) -> void:
	if _busy.get("supplies", false) or Game.has_flag("ch15_set_out"):
		return
	_busy["supplies"] = true
	while is_inside_tree():
		var c: Dictionary = c14._counts()
		var text := "WHAT WE CARRIED  -  food %d   water %d   painkillers %d   flashlight spares %d" % [c.food, c.water, c.painkillers, c.batteries]
		var ev := []
		for id in ["underground_records", "ancient_rubbing", "maintenance_log", "checkpoint_note", "noahs_message", "last_note"]:
			if Game.has_item(id):
				ev.append(Game.item_info(id).get("name", id))
		text += "\nEvidence: " + (", ".join(ev) if not ev.is_empty() else "none")
		for k in present():
			text += "\n%s  -  %s" % [k, world.survivors.HEALTH_TEXT[_health(k)] if world.survivors else "Healthy"]
		var opts := []
		var acts := []
		for k in present():
			if _health(k) in ["injured", "serious"] and c.painkillers > 0:
				opts.append("Treat %s (1 painkiller)" % k)
				acts.append(["treat", k])
		if c.food + c.water > 0 and not st().get("shared", false):
			opts.append("Share out food and water")
			acts.append(["share", ""])
		opts.append("Done")
		acts.append(["done", ""])
		var i: int = await p4.choice.ask(text, opts, player)
		var a: Array = acts[clampi(i, 0, acts.size() - 1)] if i >= 0 else ["done", ""]
		if a[0] == "treat":
			Game.remove_item("painkillers")
			world.survivors.set_health(a[1], "recovering" if _health(a[1]) == "injured" else "injured")
			world.survivors.award("ch15_treated:%s:%s" % [a[1], _health(a[1])], {a[1]: 5})
			Sfx.play("pickup", player.global_position, -8.0)
		elif a[0] == "share":
			st()["shared"] = true                      # a meal before the road: one food and one water, morale up
			for id in ["canned_food", "energy_snack", "chocolate_bar"]:
				if Game.has_item(id):
					Game.remove_item(id)
					break
			for id in ["water_bottle", "cola_bottle"]:
				if Game.has_item(id):
					Game.remove_item(id)
					break
			if world.survivors:
				world.survivors.award("ch15_shared", {}, 6)
			Dialogue.say("c15_shared", false, true)
		else:
			break
	_busy["supplies"] = false
	_refresh_prompts()


## A short talk that remembers: trust, injuries, Chapter 15's door and fence, Noah's actual status (never found).
func _talk_id(k: String) -> String:
	match k:
		"Eddie":
			return "c15_talk_Eddie" if _trust("Eddie") >= 45 else "c15_talk_Eddie_low"
		"Ruth":
			return "c15_talk_Ruth" if _trust("Ruth") >= 45 else "c15_talk_Ruth_low"
		"Sarah":
			if String(Game.world_state.get("ch14", {}).get("rescue", "")) == "saved" and String(Game.world_state.get("ch14", {}).get("rescue_target", "")) == "Sarah":
				return "c15_talk_Sarah_saved"
			return "c15_talk_Sarah_hurt" if _health("Sarah") in ["injured", "serious"] else "c15_talk_Sarah"
		"Marcus":
			return "c15_talk_Marcus_back" if String(Game.world_state.get("ch14", {}).get("separation", "")) == "went_back" else "c15_talk_Marcus"
	return ""


func _talk(_b: Node, k: String) -> void:
	if Game.has_flag("ch15_set_out") or st().get("talked", {}).get(k, false) or world.conversing or not Game.has_flag("ch15_opening_done"):
		return
	var t: Dictionary = st().get("talked", {})
	t[k] = true
	st()["talked"] = t
	_refresh_prompts()
	await _tg(_talk_id(k), [_node(k)])


func _plan(_b: Node) -> void:
	if Game.has_flag("ch15_plan_done") or _busy.get("plan", false):
		return
	_busy["plan"] = true
	var npcs: Array = [_node(_second()), _node(voice())]
	await _tg(_pick("c15_plan"), npcs)
	if Game.has_item("ancient_rubbing"):
		await _tg("c15_plan_evidence", [_node(voice())])
	Game.set_flag("ch15_plan_done")
	_busy["plan"] = false
	_refresh_prompts()
	_guide()


func _set_out(_b: Node) -> void:
	if not Game.has_flag("ch15_plan_done") or Game.has_flag("ch15_set_out") or _busy.get("door", false):
		return
	_busy["door"] = true
	_hold(true)
	await hud.fade_to(1.0, 0.5)
	player.global_position = c12.OUTSIDE_SPOT
	player.set_yaw_pitch(0.0, 0.0)
	var i := 0
	for k in present():
		world.place_survivor(_node(k), c12.OUTSIDE_SPOT + Vector3(-1.2 + 0.9 * i, 0.0, 1.4 + 0.3 * (i % 2)))
		i += 1
	Game.set_flag("ch15_set_out")
	for k in present():
		c9._start_follow(k)
	_slow_injured()
	_set_fog(true, 0.8)
	await get_tree().create_timer(0.4).timeout
	await hud.fade_to(0.0, 0.7)
	_hold(false)
	_busy["door"] = false
	if Game.has_flag("vehicle_repaired"):
		Dialogue.say("c15_no_car", false, true)       # the repaired car is still at the supermarket lot: on foot
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ the road, the Colossus
func _road_tick(delta: float) -> void:
	if not Game.has_flag("ch15_set_out") or Game.has_flag("ch15_crossed"):
		return
	var p := player.global_position
	if not Game.has_flag("ch15_colossus_seen") and p.distance_to(COVERS[0]) < 5.0 and not Dialogue.is_busy() and not world.conversing \
			and not _busy.get("colossus", false):
		_colossus_reveal()
	if Game.has_flag("ch15_colossus_seen") and not _busy.get("colossus", false):
		_crossing_tick(delta)


func _spawn_colossus() -> void:
	if colossus != null:
		return
	colossus = (load(COLOSSUS_PATH) as PackedScene).instantiate() as Node3D
	colossus.name = "C15_Colossus"
	world.add_child(colossus)
	if colossus is CollisionObject3D:
		(colossus as CollisionObject3D).collision_layer = 0
		(colossus as CollisionObject3D).collision_mask = 0
	colossus.set_physics_process(false)
	var model := colossus.get_node_or_null("Model") as Node3D
	if model:
		model.scale = Vector3.ONE * float(world.COLOSSUS_SCALE)
	VeilCreatureLook.apply_colossus(colossus, 0.15)
	colossus.global_position = Vector3(COLOSSUS_X, 0.15, -18.0)
	colossus.rotation.y = 0.0                         # walking +Z (north), across the fields west of the road
	col_anim = colossus.get_node_or_null(String(colossus.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
	_col_play("Walk_Heavy")


func _col_play(n: String) -> void:
	if col_anim and col_anim.has_animation(n) and col_anim.current_animation != n:
		col_anim.play(n, 0.6)


## First person: the ground trembles, the deep call, the view is turned and drawn up a leg into the mist; then cover.
func _colossus_reveal() -> void:
	_busy["colossus"] = true
	report["colossus_runs"] += 1
	world.save_checkpoint("chapter16_colossus")
	Game.set_flag("ch15_colossus_seen")
	_hold(true)
	_spawn_colossus()
	for k in present():
		(c9.follows[k] as VeilCompanionFollow).stop()
	c12._shake(2.0, 0.03)
	Sfx.play("colossus_call", colossus.global_position + Vector3(0, 12, 0), 6.0, 0.8)
	Sfx.play_music(Sfx.MUSIC_COLOSSUS, false, -6.0, 0.6, Sfx.MUSIC_GAMEPLAY)
	var cam: Camera3D = player.camera
	var far0 := cam.far
	cam.far = maxf(far0, 400.0)
	var fov0 := cam.fov
	await c8._turn_to(colossus.global_position + Vector3(0, 4.0, 10.0), 1.8)
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.6, 2.4).set_trans(Tween.TRANS_SINE)
	var tw := create_tween()
	tw.tween_property(colossus, "global_position", colossus.global_position + Vector3(0, 0, 6.0), 3.0)
	Sfx.play("colossus_step", colossus.global_position, 6.0, 0.7)
	await tz.finished
	await c8._turn_to(colossus.global_position + Vector3(0, 22.0, 12.0), 2.2)
	report["colossus_in_view"] = cam.is_position_in_frustum(colossus.global_position + Vector3(0, 8.0, 6.0))
	await get_tree().create_timer(0.8).timeout
	var tb := create_tween()
	tb.tween_property(cam, "fov", fov0, 0.8)
	await tb.finished
	cam.fov = fov0
	cam.far = far0
	await _tg(_pick("c15_colossus"), [_node(voice())])
	for k in present():
		c9._start_follow(k)
	_hold(false)
	_busy["colossus"] = false
	_col_phase = "walk"
	_col_t = 7.0
	_last_cover = 0
	_hint("Cover to cover. Move while it walks; stay down when it stops and looks.")


func _cover_index(p: Vector3) -> int:
	for i in COVERS.size():
		if Vector2(p.x - COVERS[i].x, p.z - COVERS[i].z).length() < 2.6:
			return i
	return -1


## It walks (safe to move), then stops and looks over the fields (exposed = seen). Seen: it reacts, the ground
## shakes, three seconds to get back into cover - or it is back to the last cover (fade; a little hurt).
func _crossing_tick(delta: float) -> void:
	if colossus == null:
		return
	var p := player.global_position
	var ci := _cover_index(p)
	if ci > _last_cover:
		_last_cover = ci
	if Vector2(p.x - CROSS_END.x, p.z - CROSS_END.z).length() < 4.0 or p.z > CROSS_END.z - 1.0:
		_crossed()
		return
	_col_t -= delta
	if _col_phase == "walk":
		colossus.global_position += Vector3(0, 0, 1.3 * delta)
		if _col_t <= 0.0:
			_col_phase = "look"
			_col_t = 5.0
			_col_play("Alert")
			Sfx.play("colossus_step", colossus.global_position, 4.0, 0.6)
			_hint("DOWN - it's looking!")
	elif _col_phase == "look":
		var to := p - colossus.global_position
		colossus.rotation.y = lerp_angle(colossus.rotation.y, atan2(to.x, to.z), 0.6 * delta)
		if ci < 0 and _danger_t < 0.0:
			_detected()
		if _col_t <= 0.0:
			_col_phase = "walk"
			_col_t = 7.0
			colossus.rotation.y = 0.0
			_col_play("Walk_Heavy")
			_hint("Now - move!")
	if _danger_t >= 0.0:
		_danger_t -= delta
		if ci >= 0:
			_danger_t = -1.0
			_hint("")
		elif _danger_t < 0.0:
			_retry()


func _detected() -> void:
	report["detections"] += 1
	_danger_t = 3.0
	_col_play("Attack_Heavy")
	Sfx.play("colossus_call", colossus.global_position + Vector3(0, 12, 0), 8.0, 0.75)
	c12._shake(1.4, 0.06)
	_hint("IT SAW YOU - GET TO COVER!")


func _retry() -> void:
	report["retries"] += 1
	_busy["colossus"] = true
	_hold(true)
	await hud.fade_to(1.0, 0.4)
	player.damage(8.0, colossus.global_position)
	player.global_position = COVERS[_last_cover] + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	for k in present():
		c12._rejoin(k)
	_col_phase = "walk"
	_col_t = 7.0
	colossus.rotation.y = 0.0
	_col_play("Walk_Heavy")
	await get_tree().create_timer(0.5).timeout
	await hud.fade_to(0.0, 0.6)
	_hold(false)
	_busy["colossus"] = false
	_hint("Wait for it to walk on. Then move.")


func _crossed() -> void:
	if Game.has_flag("ch15_crossed"):
		return
	Game.set_flag("ch15_crossed")
	_hint("")
	_col_play("Walk_Heavy")
	var tw := create_tween()
	tw.tween_property(colossus, "global_position", colossus.global_position + Vector3(0, 0, 80.0), 40.0)
	tw.tween_callback(func(): if is_instance_valid(colossus): colossus.queue_free())    # far in the mist by then
	Sfx.play_music(Sfx.MUSIC_GAMEPLAY, true, -14.0, 3.0)
	_district_pressure()
	_guide()


## The district: a Skitter across a roof, a Hound up the road behind - run for the passage.
func _district_pressure() -> void:
	await get_tree().create_timer(3.0).timeout
	var sk: Node3D = c13._make_skitter("C15_RoofSkitter", c13.D(c13.ROOF_RUN[0]))
	creatures.append(sk)
	var tw := create_tween()
	tw.tween_property(sk, "global_position", c13.D(c13.ROOF_RUN[1]), 2.6)
	tw.tween_property(sk, "global_position", c13.D(c13.ROOF_RUN[2]), 0.7)
	tw.tween_callback(sk.queue_free)                 # down behind the house, out of sight
	Dialogue.say(_cast(_pick("c15_roof")), false, true)
	await get_tree().create_timer(5.0).timeout
	if Game.has_flag("ch15_in_passage"):
		return
	var at := Vector3(-108.0, 0.15, 6.0)
	var h := (load(HOUND_PATH) as PackedScene).instantiate() as Node3D
	h.name = "C15_Hound"
	world.add_child(h)
	h.global_position = at
	VeilCreatureLook.apply_skitter(h, at.y)
	var ai: Node = HOUND_AI.new()
	ai.name = "AI"
	h.add_child(ai)
	ai.leash = 45.0
	ai.setup(h, player, [at, at + Vector3(4, 0, 4)])
	ai.set("_last_seen", player.global_position)
	ai.state = "SUSPICIOUS"
	ai.set("awareness", 0.95)
	creatures.append(h)
	Dialogue.say(_cast(_pick("c15_hound")), false, true)


# ------------------------------------------------------------------ below
func _passage_tick() -> void:
	if not Game.has_flag("ch15_crossed") or Game.has_flag("ch15_in_passage") or _busy.get("passage", false):
		return
	var it: Interactable = c13.its.get("passage")
	if it:
		it.prompt_text = "[E] Into the Passage"
		it.collision_layer = 8
		if not it.used.is_connected(_enter_passage):
			it.used.connect(_enter_passage)


func _enter_passage(_b: Node) -> void:
	if Game.has_flag("ch15_in_passage") or _busy.get("passage", false) or not Game.has_flag("ch15_crossed"):
		return
	_busy["passage"] = true
	_hold(true)
	await hud.fade_to(1.0, 0.5)
	Game.set_flag("ch15_in_passage")
	for c in creatures:
		if is_instance_valid(c):
			c.queue_free()                           # left outside the narrow mouth, out of sight now
	creatures.clear()
	player.global_position = UL(c13.U_ENTRY + Vector3(0, 0, 3.4))
	player.set_yaw_pitch(PI, 0.0)
	var i := 0
	for k in present():
		world.place_survivor(_node(k), UL(c13.U_ENTRY + Vector3(-0.55 + 1.1 * (i % 2), 0.0, 1.5 - 0.9 * (i / 2) + 0.9)))   # behind, in the corridor
		i += 1
	c13.collapse_block.visible = true
	c13.collapse_block.collision_layer = 1
	c13.collapse_block.global_position = UL(c13.COLLAPSE)
	_set_fog(false)
	world.save_checkpoint("chapter16_passage")
	await get_tree().create_timer(0.4).timeout
	await hud.fade_to(0.0, 0.7)
	_hold(false)
	_busy["passage"] = false
	await _tg(_pick("c15_entrance"), [_node(_second()), _node(voice())])
	_refresh_prompts()
	_guide()


func _squeeze(_b: Node) -> void:
	if Game.has_flag("ch15_gap_cleared") or _busy.get("gap", false):
		return
	_busy["gap"] = true
	_hold(true)
	var tw := create_tween()
	tw.tween_property(c13.collapse_block, "global_position", UL(c13.COLLAPSE + Vector3(-1.6, 0, 0)), 1.6)
	c13._play("scrape", UL(c13.COLLAPSE), 2.0)
	await tw.finished
	Game.set_flag("ch15_gap_cleared")
	_hold(false)
	_busy["gap"] = false
	_refresh_prompts()
	_guide()


func _below_tick(delta: float) -> void:
	if not Game.has_flag("ch15_in_passage") or Game.has_flag("ch15_ended"):
		return
	var l: Vector3 = player.global_position - c13.U
	# the mist pocket: it hurts to stay in it (warned, avoidable)
	var mp: Vector3 = MIST_POCKET[0]
	if Vector2(l.x - mp.x, l.z - mp.z).length() < float(MIST_POCKET[1]):
		if not Game.has_flag("ch15_pocket_warned"):
			Game.set_flag("ch15_pocket_warned")
			_hint("The mist here burns your lungs. Get out of it.")
		_debris_t -= delta
		if _debris_t <= 0.0:
			_debris_t = 1.0
			player.damage(4.0, player.global_position + Vector3(1, 0, 0))
	if not Game.has_flag("ch15_chamber_reached") and l.z > 63.0:
		_chamber()


func _chamber() -> void:
	if _busy.get("chamber", false):
		return
	_busy["chamber"] = true
	report["chamber_runs"] += 1
	Game.set_flag("ch15_chamber_reached")
	world.save_checkpoint("chapter16_chamber")
	Sfx.stop_music(2.0)
	Sfx.stop_ambience()
	_hold(true)
	await c8._turn_to(UL(SEAL + Vector3(0, 3.0, 0)), 2.0)
	_hold(false)
	await _tg(_pick("c15_reveal"), [_node(voice())])
	_busy["chamber"] = false
	_refresh_prompts()
	_guide()


func _examine(_b: Node, k: String) -> void:
	var seen: Dictionary = st().get("clues", {})
	if seen.get(k, false) or Dialogue.is_busy():
		return
	seen[k] = true
	st()["clues"] = seen
	var id := "c15_clue_" + k
	if k == "records" and (Game.has_item("underground_records") or Game.has_item("ancient_rubbing")):
		id += "_evidence"                             # what was carried here makes sense of it
	Dialogue.say(id, false, true)
	_refresh_prompts()


## The mechanism: two control points, then the final mechanism (falling stone between them).
func _control(_b: Node, k: String) -> void:
	if _busy.get("seal_mode", false):
		_seal_step(k)
		return
	var c: Dictionary = st().get("controls", {})
	if c.has(k) or not Game.has_flag("ch15_chamber_reached") or _busy.get("ctrl", false):
		return
	if k == "C" and not (c.has("A") and c.has("B")):
		return
	_busy["ctrl"] = true
	if k == "A" and not Game.has_flag("ch15_horror"):
		await _horror()
	c[k] = true
	st()["controls"] = c
	_control_done_look(k)
	Sfx.play("door_open", player.global_position, 2.0, 0.4)
	c12._shake(0.6, 0.04)
	_busy["ctrl"] = false
	if k == "C":
		Game.set_flag("ch15_mechanism_done")
		world.save_checkpoint("chapter16_decision")
		_decide()
	_refresh_prompts()
	_guide()


func _control_done_look(_k: String) -> void:
	pass


## The seal: the camera drawn toward it, the flashlight flickers, a vast shadow moves behind the stone, the chamber
## trembles, "We need to go!" Then control is back (the controls still to work, the debris falling).
func _horror() -> void:
	Game.set_flag("ch15_horror")
	_hold(true)
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	await c8._turn_to(UL(SEAL + Vector3(0, 3.2, 0)), 1.2)
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.7, 2.0)
	c13._flashlight_flicker(2.2)
	c13._play("deep", UL(SEAL + Vector3(0, 0, 4)), 10.0)
	var m := silhouette.material_override as StandardMaterial3D
	var ts := create_tween()
	ts.tween_property(m, "albedo_color:a", 0.7, 1.4)
	ts.tween_property(silhouette, "global_position", UL(SEAL + Vector3(-2.5, 3.6, 1.8)), 2.0)
	c12._shake(2.0, 0.05)
	await ts.finished
	await _tg(_pick("c15_go"), [_node(voice())])
	var tm := create_tween()
	tm.tween_property(m, "albedo_color:a", 0.25, 1.0)
	var tb := create_tween()
	tb.tween_property(cam, "fov", fov0, 0.6)
	await tb.finished
	cam.fov = fov0
	report["horror_fov_restored"] = absf(cam.fov - fov0) < 0.01
	_hold(false)


## Falling stone while the controls are worked: a warning puff of dust, then a block lands (a fair dodge).
func _debris_tick(delta: float) -> void:
	if not Game.has_flag("ch15_horror") or (Game.has_flag("ch15_mechanism_done") and not _busy.get("seal_mode", false)) or Game.has_flag("ch15_ended") \
			or player.global_position.y > c13.U.y + 20.0:
		return
	_debris_t -= delta
	if _debris_t > 0.0:
		return
	_debris_t = randf_range(2.2, 3.6)
	var p := player.global_position
	var at := p + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	at.y = p.y - 1.0
	_drop_stone(at)


func _drop_stone(at: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.amount = 20
	dust.lifetime = 1.2
	dust.one_shot = true
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.4
	dust.gravity = Vector3(0, -3, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	dust.mesh = q
	world.add_child(dust)
	dust.global_position = Vector3(at.x, c13.U.y + 8.6, at.z)
	dust.emitting = true
	await get_tree().create_timer(0.9).timeout
	var stone := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.5, 0.6)
	stone.mesh = bm
	stone.material_override = c12._mat("stone")
	world.add_child(stone)
	stone.global_position = Vector3(at.x, c13.U.y + 8.4, at.z)
	var tw := create_tween()
	tw.tween_property(stone, "global_position:y", c13.U.y + 0.25, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	Sfx.play("door_close", stone.global_position, 2.0, 0.5)
	if Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < 0.8:
		report["debris_hits"] += 1
		player.damage(10.0, stone.global_position)
	dust.queue_free()
	get_tree().create_timer(6.0).timeout.connect(stone.queue_free)


# ------------------------------------------------------------------ the decision
func _decide() -> void:
	if Game.has_flag("ch15_decided") or _busy.get("decide", false):
		return
	_busy["decide"] = true
	await _tg("c15_two_ways", [_node(voice())])
	var i := -1
	while i < 0 and is_inside_tree():
		i = await p4.choice.ask("THE BARRIER WILL NOT HOLD FOR LONG.", ["LEAVE GREYHAVEN  -  escape with everyone through the service tunnel",
			"SEAL THE CHAMBER  -  go back to the mechanism and try to close it", "SEND THE SURVIVORS AHEAD  -  stay and hold the passage"], player)
	var d: String = ["A", "B", "C"][i]
	st()["decision"] = d
	Game.set_flag("ch15_decided")
	Game.set_flag("ch15_choice_" + d.to_lower())
	_busy["decide"] = false
	match d:
		"A":
			await _ending_a()
		"B":
			await _ending_b()
		"C":
			await _ending_c()


func _to_outer(and_player: bool) -> void:
	_hold(true)
	await hud.fade_to(1.0, 0.8)
	_set_fog(true, -0.7)                              # beyond the town: the mist is thinner; the sky shows
	if and_player:
		player.global_position = BEYOND + Vector3(0, 0.1, 0)
		player.set_yaw_pitch(0.0, 0.05)                # facing north: Greyhaven under its fog
	else:
		player.global_position = BEYOND + Vector3(0, 0.1, -9.0)     # Ending C: only an onlooker's view of them
		player.set_yaw_pitch(0.0, -0.05)
	for k in present():
		(c9.follows[k] as VeilCompanionFollow).stop()
		world.place_survivor(_node(k), BEYOND_SPOTS[k])
		_node(k).visible = true
		var a = world.animators.get(k)
		if a:
			a.set_mood("calm")
			a.face_towards(BEYOND + Vector3(0, 1.5, 40.0))
	Sfx.start_ambience()
	await get_tree().create_timer(0.6).timeout
	await hud.fade_to(0.0, 1.6)


func _ending_a() -> void:
	report["ending_runs"] += 1
	_busy["final"] = true
	_hint("Into the service tunnel. Everyone together.")
	_busy["outer_open"] = true
	_refresh_prompts()
	for k in present():
		c9._start_follow(k)
	while _busy.get("outer_open", false):
		await get_tree().process_frame
	await _to_outer(true)
	await _look_back("c15_end_a" + _end_suffix(), 0.0)
	_walk_away()
	await get_tree().create_timer(2.5).timeout
	_mist_edge()
	await get_tree().create_timer(2.5).timeout
	await _finish("A")


func _ending_b() -> void:
	report["ending_runs"] += 1
	_busy["final"] = true
	# back to the mechanism: the chamber comes down around it; two last pulls, then run
	for k in present():
		var f: VeilCompanionFollow = c9.follows[k]
		f.stop()
		world.npc_walk(k, UL(OUTER + Vector3(-2.0, 0.0, 0.6 * present().find(k) - 0.9)), 2.6)
	_hint("Back to the mechanism - close it!")
	st()["seal_steps"] = 0
	var c: Dictionary = st().get("controls", {})
	c.erase("A")
	c.erase("B")
	st()["controls"] = c
	_busy["seal_mode"] = true
	_refresh_seal_prompts()
	while int(st().get("seal_steps", 0)) < 2:
		await get_tree().process_frame
	_busy["seal_mode"] = false
	c13._play("deep", UL(SEAL), 10.0)
	var tw := create_tween()
	tw.tween_property(seal_slab, "global_position", UL(SEAL + Vector3(0, 2.5, -0.2)), 3.0).set_trans(Tween.TRANS_QUAD)
	var m := silhouette.material_override as StandardMaterial3D
	create_tween().tween_property(m, "albedo_color:a", 0.0, 2.0)
	c12._shake(2.4, 0.06)
	await tw.finished
	_hint("RUN - the service tunnel!")
	_busy["outer_open"] = true
	_refresh_prompts()
	while _busy.get("outer_open", false):
		await get_tree().process_frame
	await _to_outer(true)
	# the mist over Greyhaven pulls back - a little
	await _look_back("c15_end_b" + _end_suffix(), 0.0)
	var env := _env()
	if env:
		var tw2 := create_tween()
		tw2.tween_property(env, "fog_density", env.fog_density * 0.55, 6.0)
		await tw2.finished
	await _finish("B")


func _refresh_seal_prompts() -> void:
	var s := int(st().get("seal_steps", 0))
	_setp("ctrl_A", "[E] PULL THE LEVER" if _busy.get("seal_mode", false) and s == 0 else "")
	_setp("ctrl_B", "[E] TURN THE WHEEL" if _busy.get("seal_mode", false) and s == 1 else "")


## B and C: the last pulls (A then B), under falling stone.
func _seal_step(k: String) -> void:
	var s := int(st().get("seal_steps", 0))
	if not _busy.get("seal_mode", false) or (k == "A" and s != 0) or (k == "B" and s != 1):
		return
	st()["seal_steps"] = s + 1
	Sfx.play("door_open", player.global_position, 4.0, 0.35)
	c12._shake(0.8, 0.05)
	_refresh_seal_prompts()


func _ending_c() -> void:
	report["ending_runs"] += 1
	_busy["final"] = true
	var who := voice()
	await _tg("c15_stay_" + who if Dialogue.data.has("c15_stay_" + who) else "c15_stay", [_node(who)])
	# they go (walking; out of sight down the tunnel, then they are on their way)
	for k in present():
		var f: VeilCompanionFollow = c9.follows[k]
		f.stop()
		world.npc_walk(k, UL(OUTER_END + Vector3(-1.5, 0, 0.0)), 2.6)
	st()["seal_steps"] = 0
	var c: Dictionary = st().get("controls", {})
	c.erase("A")
	c.erase("B")
	st()["controls"] = c
	_busy["seal_mode"] = true
	_hint("Hold it. Pull the lever, turn the wheel.")
	_refresh_seal_prompts()
	while int(st().get("seal_steps", 0)) < 2:
		await get_tree().process_frame
	_busy["seal_mode"] = false
	# the way out comes down behind them; the seal closes; the shape is gone; silence
	outer_block.visible = true
	outer_block.collision_layer = 1
	c13._play("deep", UL(OUTER), 8.0)
	c12._dust()
	for k in present():
		_node(k).visible = false                     # beyond the fallen stone, gone from this side
	_hold(true)
	await c8._turn_to(UL(SEAL + Vector3(0, 3.0, 0)), 1.4)
	var tw := create_tween()
	tw.tween_property(seal_slab, "global_position", UL(SEAL + Vector3(0, 2.5, -0.2)), 3.4).set_trans(Tween.TRANS_QUAD)
	var m := silhouette.material_override as StandardMaterial3D
	create_tween().tween_property(m, "albedo_color:a", 0.0, 2.6)
	c13._flashlight_flicker(3.4)
	await tw.finished
	Sfx.stop_ambience()
	await get_tree().create_timer(2.0).timeout
	await c8._turn_to(UL(OUTER + Vector3(0, 1.4, 0)), 2.0)
	await get_tree().create_timer(1.0).timeout
	c13._play("voice", UL(SEAL + Vector3(0, 0, 12.0)), -2.0)
	Dialogue.say("c15_voice", false, true)
	while Dialogue.is_busy():
		await get_tree().process_frame
	await hud.fade_to(1.0, 2.4)
	# the epilogue: the others, beyond the town (seen from a distance; the protagonist is not there)
	await _to_outer(false)
	await _tg("c15_end_c" + _end_suffix(), [_node(voice())])
	_walk_away()
	await get_tree().create_timer(3.0).timeout
	await _finish("C")


func _end_suffix() -> String:
	if "Eddie" in present():
		return ""
	return "_alt"


func _look_back(id: String, _d: float) -> void:
	_hold(true)
	var cam: Camera3D = player.camera
	var far0 := cam.far
	cam.far = maxf(far0, 400.0)
	await c8._turn_to(BEYOND + Vector3(0, 6.0, 120.0), 2.0)
	await get_tree().create_timer(1.0).timeout
	cam.far = far0
	_hold(false)
	await _tg(id, [_node(voice())])


func _walk_away() -> void:
	for k in present():
		world.npc_walk(k, BEYOND_SPOTS[k] + Vector3(0, 0, -14.0), 1.2)


func _mist_edge() -> void:
	var edge: CPUParticles3D = c13._mist_flow(BEYOND + Vector3(0, 1.0, 60.0), Vector3(0, 0, -1))
	edge.emission_box_extents = Vector3(30.0, 2.0, 6.0)
	edge.initial_velocity_min = 0.4
	edge.initial_velocity_max = 0.8


func _leave_tunnel(_b: Node) -> void:
	if not _busy.get("outer_open", false):
		return
	_busy["outer_open"] = false
	_refresh_prompts()


# ------------------------------------------------------------------ the end: epilogue, credits, menu
## One line per survivor, from what is actually true (no invented fates).
func epilogue_lines(ending: String) -> Array:
	var out := []
	var ch14s: Dictionary = Game.world_state.get("ch14", {})
	if ending == "C":
		out.append("They waited at the tunnel mouth until morning. Nobody came out.")
	for k in ["Eddie", "Ruth", "Sarah", "Marcus"]:
		if k == "Marcus" and Game.has_flag("ch9_marcus_lost"):
			out.append("Marcus did not leave the supermarket. He never stopped looking for Noah.")
			continue
		if k in ch14s.get("missing", []):
			out.append("%s was last seen at the fence behind the mill-worker house. What happened after is not known." % k)
			continue
		if not (k in present()):
			continue
		var h := _health(k)
		var line := "%s made it out" % k
		if h == "serious":
			line += ", carried most of the way"
		elif h == "injured":
			line += ", limping, but walking"
		var t := _trust(k)
		line += (". " + ({"Eddie": "He stayed close to the end.", "Ruth": "She counted every step to the next town.", "Sarah": "She did not let go of anyone's hand.",
			"Marcus": "He looked back more than anyone."}[k]) if t >= 50 else ". " + ({"Eddie": "He did not say much on the road.", "Ruth": "She kept her distance.",
			"Sarah": "She walked a little apart from the rest.", "Marcus": "He walked alone, a few steps behind."}[k]))
		out.append(line)
	if not Game.has_flag("ch9_marcus_lost"):
		out.append("Noah was never found.")
	out.append({"A": "Behind them, the mist reached a little farther every night.", "B": "Over Greyhaven the mist thinned. Not gone. Quieter.",
		"C": "Below Greyhaven, something waits behind the stone. Something else waits with it."}[ending])
	return out


func _finish(ending: String) -> void:
	st()["ending"] = ending
	st()["epilogue"] = epilogue_lines(ending)
	Game.set_flag("ch15_ended")
	await hud.title_card(ENDING_TITLES[ending], 3.0)
	await hud.fade_to(1.0, 1.4)
	for l in st()["epilogue"]:
		await hud.title_card(String(l), 2.6)
	Game.set_flag("chapter_15_complete")
	_record_ending(ending)
	report["ended"] = ending
	_credits()


## The endings reached are kept in their own file; the player's save goes back to the moment before the decision
## (so the finale can always be replayed), with the endings seen recorded in it.
func _record_ending(ending: String) -> void:
	var rec := {}
	if FileAccess.file_exists(ENDINGS_PATH):
		var f := FileAccess.open(ENDINGS_PATH, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text())
		rec = d if d is Dictionary else {}
	var seen: Array = rec.get("endings", [])
	if not (ending in seen):
		seen.append(ending)
	rec["endings"] = seen
	rec["last"] = {"ending": ending, "epilogue": st()["epilogue"], "roster": present(), "play_time": Game.play_time}
	var w := FileAccess.open(ENDINGS_PATH, FileAccess.WRITE)
	w.store_string(JSON.stringify(rec, " "))
	w.close()
	var flags_now := Game.flags.duplicate(true)
	var ws_now := Game.world_state.duplicate(true)
	var inv_now := Game.inventory.duplicate()
	var ps_now := Game.player_state.duplicate(true)
	var vs_now := Game.vehicle_state.duplicate(true)
	var pt_now := Game.play_time
	if Game.load_checkpoint("chapter16_decision"):
		var s: Dictionary = Game.world_state.get(STATE, {})
		s["endings_seen"] = seen
		Game.world_state[STATE] = s
		Game.save_game()
	Game.flags = flags_now
	Game.world_state = ws_now
	Game.inventory = inv_now
	Game.player_state = ps_now
	Game.vehicle_state = vs_now
	Game.play_time = pt_now
	_ending_saved = true


var _ending_saved := false


func _credits() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 20
	_menu.name = "C15_Credits"
	add_child(_menu)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	_menu.add_child(v)
	var lines := ["THE VEIL", "", "A project by jafetmora79-lab", "Made with Godot Engine 4.3", "Art, creatures and town: THE VEIL ASSETS V2 (the project's asset library)",
		"Story, code and integration developed with Claude (Anthropic)", "", "THANK YOU FOR PLAYING"]
	for i in lines.size():
		var l: Label = VeilUI.label(lines[i], 34 if i == 0 or i == lines.size() - 1 else 16, Color(0.85, 0.85, 0.82))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	v.add_child(buttons)
	for b in [["Return to Main Menu", _menu_main], ["Replay the Ending", _menu_replay], ["Load Game", _menu_load]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(b[1])
		buttons.add_child(btn)
	v.position = -v.size / 2
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.fade_to(0.0, 0.1)


func _menu_main() -> void:
	world._to_menu()


func _menu_replay() -> void:
	if Game.load_checkpoint("chapter16_decision"):
		Game.load_requested = true
		get_tree().change_scene_to_file("res://game/scenes/World.tscn")


func _menu_load() -> void:
	if Game.load_game():
		Game.load_requested = true
		get_tree().change_scene_to_file("res://game/scenes/World.tscn")


# ------------------------------------------------------------------ helpers
func _env() -> Environment:
	var env: Environment = player.camera.environment if player and player.camera else null
	if env == null:
		var we := world.find_child("WorldEnvironment", true, false) as WorldEnvironment
		env = we.environment if we else null
	return env


func _set_fog(thick: bool, amount := 1.0) -> void:
	var env := _env()
	if env == null:
		return
	if _fog0 < 0.0:
		_fog0 = env.fog_density
	env.fog_density = maxf(_fog0 * (1.0 + 1.6 * amount), _fog0 * 0.2) if thick else _fog0


func _exit_tree() -> void:
	_set_fog(false)


func _hint(t: String) -> void:
	c10._hint(t)


func _hold(on: bool) -> void:
	player.set("controls_enabled", not on)
	player.velocity = Vector3.ZERO


func _play(id: String, at: Vector3, db := 0.0) -> void:
	c13._play(id, at, db)


func _process(delta: float) -> void:
	if world == null:
		return
	_road_tick(delta)
	_below_tick(delta)
	_debris_tick(delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.2
	_passage_tick()
	if not _busy.get("colossus", false) and not _busy.get("chamber", false) and not _busy.get("final", false):
		_guide()
