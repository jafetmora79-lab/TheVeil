extends Node
class_name VeilChapter13
## THE VEIL - displayed CHAPTER 14 "Into the Veil" (internal ids keep the file numbering: chapter13.gd, flags ch13_*,
## chapter_13_complete). Starts at the mill-worker house after "The Truth Beneath Greyhaven" (flag
## chapter_12_complete), created by chapter12.gd. State: story flags + Game.world_state["ch13"].
##
## The recovered map, the road that is not on modern maps (only speakers who are alive and present) -> preparation and
## a companion (whoever is alive and fit; Eddie first) -> the road west into thicker fog: a broken street sign, and
## later the same sign again -> the abandoned district (built from existing houses, cars, barricades and walls):
## dense mist zones (Mist Exposure: muffled sound, a soft distortion, a heartbeat, misleading sounds; it falls in
## clear air and indoors; it never takes control or health away) -> a Skitter crosses a roof and drops out of sight;
## a second one comes out from behind a car and patrols the street (sneak past; a lunge hurts, it never kills) ->
## the checkpoint gate: the office, the note, the crank, the manual release -> the courtyard: the Shellcrawler comes
## out from behind the collapsed shed (first person), lunges; run round the debris to the maintenance passage, too
## narrow for it -> the passage of echoes (a voice that is not who it sounds like; landmarks mark the way) -> the
## ancient entrance: the winch, the beam, the doorway opens; the mist moves; a vast shape in the dark -> the
## collapse: help the companion (more exposure, a lost supply) or secure the evidence (the companion is hurt, trust
## falls) -> out by the storm drain, through the district in thick fog, back to the mill house -> late that night,
## the window, the mist rolling in -> "CHAPTER 14 COMPLETE", NEXT: CHAPTER 15 - THE LAST SHELTER (not started).

const STATE := "ch13"
const CHAPTER := 14
const A := "res://THE_VEIL_ASSETS_V2/"
const SKITTER_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const CRAB_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Shellcrawler.tscn"
# ---- the district: district-local frame (x across, z away from the road), origin where the old road enters it
const D_ORIGIN := Vector3(-125.0, 0.0, 30.0)
const D_YAW := 0.0
const ROAD := [Vector3(-97.0, 0.2, 2.0), Vector3(-104.0, 0.2, 2.0), Vector3(-114.0, 0.2, 18.0), Vector3(-121.0, 0.2, 31.0)]   # past the town's dead-end sign
const SIGN_1 := Vector3(-101.5, 0.0, 6.0)               # world: by the main road
const SIGN_2 := Vector3(-2.6, 0.0, 6.0)                 # district-local: the same sign again
const HOUSES := [["RES_House_Abandoned", Vector3(-6.8, 0.0, 12.0), -PI * 0.5], ["RES_House_Cottage_B", Vector3(6.8, 0.0, 14.0), PI * 0.5],
	["RES_House_Bungalow", Vector3(-6.8, 0.0, 28.0), -PI * 0.5], ["RES_House_MillWorker_B", Vector3(6.8, 0.0, 31.0), PI * 0.5]]   # backs to the fences
const CARS := [["VEH_Sedan_Damaged", Vector3(-5.0, 0.0, 8.0), 0.3], ["VEH_Pickup_Abandoned", Vector3(-4.5, 0.0, 30.5), -0.2],
	["VEH_Sedan_Dusty", Vector3(6.0, 0.0, 55.0), 1.2], ["VEH_PoliceCruiser_Abandoned", Vector3(-7.0, 0.0, 66.0), 2.0]]
const MIST_ZONES := [[Vector3(-3.5, 0.0, 13.0), 4.5], [Vector3(5.0, 0.0, 26.0), 4.5], [Vector3(0.0, 0.0, 60.0), 5.0]]
const CLEAR_ZONES := [[Vector3(0.0, 0.0, 2.0), 4.0], [Vector3(9.0, 0.0, 40.0), 3.5]]     # the old road's lamp; the checkpoint office
const ROOF_RUN := [Vector3(13.5, 7.6, 9.5), Vector3(13.5, 7.6, 18.5), Vector3(18.0, 3.0, 19.0)]
const SKITTER_PATROL := [Vector3(-1.5, 0.0, 34.0), Vector3(-1.5, 0.0, 22.0), Vector3(2.5, 0.0, 19.0), Vector3(-1.5, 0.0, 22.0)]
const WALL_Z := 44.0
const OFFICE := [Vector3(9.0, 0.0, 40.0), Vector3(6.0, 3.0, 6.0)]                     # centre (floor), size
const CRANK_AT := Vector3(10.9, 0.0, 41.6)
const RELEASE_AT := Vector3(3.2, 1.2, 43.5)
const NOTE_AT := Vector3(7.0, 0.95, 42.2)
const CRAB_HIDE := Vector3(9.5, 0.0, 73.2)
const SHED := Vector3(9.5, 0.0, 69.0)
const PASSAGE := Vector3(0.0, 1.2, 75.6)
const DRAIN := Vector3(-8.0, 0.0, 47.5)
const COURT_ROUTE := [Vector3(0.0, 0.0, 47.0), Vector3(-9.0, 0.0, 55.0), Vector3(-10.0, 0.0, 70.0), Vector3(-2.0, 0.0, 73.5)]
# ---- the passage and the ancient entrance: underground-local frame (deep below the district)
const U := Vector3(-125.0, -45.0, 120.0)
const U_ENTRY := Vector3(0.0, 0.1, 1.2)
const U_VOICE := Vector3(-9.0, 1.5, 8.0)               # the dead end the voice comes from
const WINCH := Vector3(19.4, 0.0, 33.0)
const BEAM := Vector3(13.6, 0.0, 38.4)
const DOORWAY := Vector3(12.0, 2.0, 40.0)
const PLAQUE := Vector3(4.4, 1.5, 34.0)
const EVIDENCE := Vector3(17.0, 0.05, 38.8)
const CRAWL := Vector3(4.0, 0.0, 30.0)                  # the damaged passage out (west wall)
const COLLAPSE := Vector3(12.0, 1.6, 25.2)
const VOID_SHAPE := Vector3(12.0, 4.0, 62.0)
# ---- the mill-worker house (house-local): the window for the last scene
const NIGHT_LIGHT := Vector3(-60.0, 4.0, -40.0)

var world: Node
var c12: Node
var c10: Node
var c9: Node
var c8: Node
var p4: Node
var player: Node3D
var hud: Node
var dist: Node3D
var under: Node3D
var its := {}
var skitters: Array = []            # {"node", "mode", "i", "t", "cd"}
var crab: CharacterBody3D
var crab_anim: AnimationPlayer
var void_shape: MeshInstance3D
var gate: Node3D
var collapse_block: Node3D
var doorway_slab: Node3D
var beam: Node3D
var night_light: OmniLight3D
var report := {"skitter_hits": 0, "crab_hits": 0, "exposure_max": 0.0, "crab_runs": 0, "mist_runs": 0, "ending_runs": 0, "decision_runs": 0,
	"crab_max_step": 0.0, "sign_seen": false}
var _busy := {}
var _tick := 0.0
var _route_i := 0
var _streams := {}
var _fog0 := -1.0
var _overlay: ColorRect
var _heart: AudioStreamPlayer
var _lp_idx := -1
var _false_t := 9.0
var _crab_prev := Vector3.ZERO
var _crab_burst := 0.0
var _crab_burst_dir := Vector3.ZERO
var _crab_cd := 0.0
var _crab_next_burst := 2.5


func begin(w: Node, chapter12: Node, restoring: bool) -> void:
	world = w
	c12 = chapter12
	c10 = c12.c10
	c9 = c12.c9
	c8 = c12.c8
	p4 = c12.p4
	player = w.player
	hud = w.hud
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"roster": group(), "companion": "", "expedition": "story", "exposure": 0.0, "choice": "", "clues": {}}
	_streams["heart"] = Sfx._make(1.0, func(t, i): return (sin(TAU * 48.0 * t) * exp(-t * 18.0) + sin(TAU * 44.0 * maxf(t - 0.28, 0.0)) * exp(-maxf(t - 0.28, 0.0) * 18.0) * 0.8 * (1.0 if t > 0.28 else 0.0)) * 0.9, true)
	_streams["voice"] = Sfx._make(2.2, func(t, i): return sin(TAU * (190.0 + 30.0 * sin(t * 5.0)) * t) * 0.18 * sin(PI * t / 2.2) * (0.6 + 0.4 * sin(TAU * 7.0 * t)) + Sfx._noise(i) * 0.04)
	_streams["claw"] = Sfx._make(0.6, func(t, i): return (Sfx._noise(i) * 0.6 + sin(TAU * 140.0 * t) * 0.4) * exp(-t * 7.0))
	_streams["scrape"] = Sfx._make(1.6, func(t, i): return Sfx._noise(i) * 0.4 * (0.6 + 0.4 * sin(TAU * 23.0 * t)) * minf(t * 4.0, 1.0) * minf((1.6 - t) * 3.0, 1.0))
	_streams["deep"] = c12._streams["below"]
	_streams["clank"] = c12._streams["clank"]
	_streams["skitter"] = c12._streams["scratch"]
	_build_district()
	_build_under()
	_build_exposure_fx()
	var it: Interactable = p4.its.get("npc_Eddie")
	if it:
		it.used.connect(_talk)
		its["npc_Eddie"] = it
	var fresh := not Game.has_flag("ch13_started")
	if fresh:
		Game.set_flag("ch13_started")
		_opening.call_deferred()
	else:
		_apply()
	Game.refresh_objective()


func st() -> Dictionary:
	return Game.world_state[STATE]


func D(p: Vector3) -> Vector3:
	return D_ORIGIN + Basis(Vector3.UP, D_YAW) * p


func UL(p: Vector3) -> Vector3:
	return U + p


func alive() -> bool:
	return c10.alive()


func group() -> Array:
	return c10.group()


func _node(k: String) -> Node3D:
	return c10._node(k)


## Who can come: alive, here, not seriously hurt (survivor health); Eddie first.
func companion_options() -> Array:
	var out := []
	for k in ["Eddie", "Sarah", "Ruth", "Marcus"]:
		if k in group() and not (world.survivors and world.survivors.health(k) == "serious"):
			out.append(k)
	return out


func companion() -> String:
	var k := String(st().get("companion", ""))
	if k in group():
		return k
	var o := companion_options()
	return o[0] if not o.is_empty() else "Eddie"


func _comp() -> Node3D:
	return _node(companion())


## A line for the companion: their own variant if the dialogue has one, else the shared one (spoken by Eddie's
## lines only when Eddie is the one there).
func _cid(base: String) -> String:
	var k := companion()
	return base + "_" + k if Dialogue.data.has(base + "_" + k) else base


# ------------------------------------------------------------------ building
func _box(parent: Node3D, n: String, at: Vector3, size: Vector3, mat: String, collide := true, basis := Basis()) -> StaticBody3D:
	return c12._box(parent, n, at, size, mat, collide, basis)


## District-local box (yaw of the district applied).
func _dbox(n: String, p: Vector3, size: Vector3, mat: String, collide := true) -> StaticBody3D:
	return _box(dist, n, D(p), size, mat, collide, Basis(Vector3.UP, D_YAW))


func _ubox(n: String, p: Vector3, size: Vector3, mat: String, collide := true) -> StaticBody3D:
	return _box(under, n, UL(p), size, mat, collide)


func _prop(path: String, n: String, at: Vector3, yaw: float, scale := 1.0) -> Node3D:
	return c12._prop(path, n, at, yaw, scale)


## A prop with a box collider around its visible bounds (houses and cars placed here have no collision of their own).
func _solid(path: String, n: String, at: Vector3, yaw: float) -> Node3D:
	var o: Node3D = _prop(path, n, at, yaw)
	if o == null:
		return null
	var ab := AABB()
	var first := true
	var inv := o.global_transform.affine_inverse()
	for mi in o.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (inv * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		ab = bb if first else ab.merge(bb)
		first = false
	if not first and ab.size.length() > 0.1:
		var b := StaticBody3D.new()
		b.name = "Solid"
		o.add_child(b)
		b.position = ab.get_center()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = ab.size * Vector3(0.94, 1.0, 0.94)
		cs.shape = sh
		b.add_child(cs)
	return o


func _spot(n: String, at: Vector3, size: Vector3, cb: Callable) -> Interactable:
	return c10._spot(n, at, size, cb)


func _set_prompt(k: String, t: String) -> void:
	var it: Interactable = its.get(k)
	if it:
		it.prompt_text = t
		it.collision_layer = 8 if t != "" else 0


func _mist_quad(parent: Node3D, at: Vector3, size: Vector2, alpha: float, vertical := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(A + "01_Textures/Horror/T_Hor_GroundMistCorrupted.png")
	m.albedo_color = Color(0.82, 0.84, 0.86, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if vertical:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		q.orientation = PlaneMesh.FACE_Z
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	return mi


func _build_district() -> void:
	dist = Node3D.new()
	dist.name = "C13_District"
	world.add_child(dist)
	# the road in: the broken sign (seen again later, inside the district)
	for at in [SIGN_1, D(SIGN_2)]:
		_prop("09_Horror_Atmosphere/Abandoned_Props/ABN_FallenStreetSign.tscn", "C13_Sign", at, 0.35)
	its["sign2"] = _spot("C13_Sign2", D(SIGN_2) + Vector3(0, 1.0, 0), Vector3(4.0, 2.0, 4.0), func(_b): pass)
	_set_prompt("sign2", "")
	# boundary walls (the district was closed off long ago), the checkpoint wall with its gate, the back wall
	for side in [-1.0, 1.0]:
		_dbox("Fence", Vector3(side * 19.5, 1.6, 40.0), Vector3(0.4, 3.2, 72.0), "grime")
	_dbox("Wall", Vector3(-11.0, 1.75, WALL_Z), Vector3(17.0, 3.5, 0.5), "concrete")
	_dbox("Wall", Vector3(11.0, 1.75, WALL_Z), Vector3(17.0, 3.5, 0.5), "concrete")
	gate = _dbox("Gate", Vector3(0.0, 1.6, WALL_Z), Vector3(5.0, 3.2, 0.3), "steel")
	_dbox("BackWall", Vector3(-10.5, 2.0, 76.0), Vector3(18.0, 4.0, 0.5), "concrete")
	_dbox("BackWall", Vector3(10.5, 2.0, 76.0), Vector3(18.0, 4.0, 0.5), "concrete")
	_dbox("PassageHut", Vector3(0.0, 3.0, 76.0), Vector3(3.0, 2.0, 0.5), "concrete")
	_dbox("PassageSide", Vector3(-1.45, 1.0, 77.2), Vector3(0.3, 2.0, 2.4), "concrete")
	_dbox("PassageSide", Vector3(1.45, 1.0, 77.2), Vector3(0.3, 2.0, 2.4), "concrete")
	_dbox("PassageBack", Vector3(0.0, 1.0, 78.4), Vector3(2.6, 2.0, 0.3), "grime")
	_dbox("PassageRoof", Vector3(0.0, 2.1, 77.2), Vector3(3.2, 0.2, 2.6), "concrete")
	# the street: houses left in a hurry, cars, barricades, warning signs
	for h in HOUSES:
		_solid("03_Residential/House_Variants/%s.tscn" % h[0], "C13_" + String(h[0]), D(h[1]), D_YAW + float(h[2]))
	for c in CARS:
		_solid("05_Vehicles/Abandoned_Variants/%s.glb" % c[0], "C13_" + String(c[0]), D(c[1]), D_YAW + float(c[2]))
	_prop("09_Horror_Atmosphere/Abandoned_Props/ABN_EmptyBarricade.tscn", "C13_Barricade", D(Vector3(7.0, 0.0, 38.5)), D_YAW + 0.2)
	_prop("09_Horror_Atmosphere/Abandoned_Props/ABN_PersonalBelongings.tscn", "C13_Belongings", D(Vector3(-8.5, 0.0, 15.0)), 0.7)
	_prop("09_Horror_Atmosphere/Abandoned_Props/ABN_RoadCones_Abandoned.tscn", "C13_Cones", D(Vector3(-1.5, 0.0, 41.0)), 0.0)
	_prop("09_Horror_Atmosphere/Abandoned_Props/ABN_ScatteredPapers.glb", "C13_Papers", D(Vector3(2.0, 0.0, 24.0)), 1.1)
	_prop("09_Horror_Atmosphere/Abandoned_Props/ABN_DamagedStreetlight.tscn", "C13_Lamp", D(Vector3(-1.8, 0.0, 2.0)), 0.0)
	var lamp: OmniLight3D = c12._light(D(Vector3(-1.0, 4.2, 2.0)), 0.9, 10.0, Color(1.0, 0.8, 0.55))
	lamp.name = "C13_ClearLamp"
	for i in 3:
		var sign := Label3D.new()
		sign.text = ["RESTRICTED AREA\nNO ENTRY", "BY ORDER OF THE\nTOWN OF GREYHAVEN", "DANGER\nKEEP OUT"][i]
		sign.font_size = 30
		sign.pixel_size = 0.004
		sign.modulate = Color(0.7, 0.62, 0.45)
		dist.add_child(sign)
		sign.global_transform = Transform3D(Basis(Vector3.UP, D_YAW + PI), D(Vector3([-6.0, 6.0, -12.0][i], 2.2, [WALL_Z - 0.3, WALL_Z - 0.3, 4.0][i])))
	# the checkpoint office (south of the wall): a concrete room, its door on the street side
	var o: Vector3 = OFFICE[0]
	_dbox("Office", o + Vector3(0, 3.1, 0), Vector3(6.2, 0.2, 6.2), "concrete")
	_dbox("Office", o + Vector3(3.0, 1.5, 0), Vector3(0.25, 3.0, 6.0), "concrete")
	_dbox("Office", o + Vector3(0, 1.5, -3.0), Vector3(6.0, 3.0, 0.25), "concrete")
	_dbox("Office", o + Vector3(-3.0, 1.5, -1.9), Vector3(0.25, 3.0, 2.2), "concrete")
	_dbox("Office", o + Vector3(-3.0, 1.5, 1.9), Vector3(0.25, 3.0, 2.2), "concrete")
	_prop("04_Commercial/Shared_Props/COM_ReceptionDesk.glb", "C13_Desk", D(Vector3(7.0, 0.0, 42.3)), D_YAW + PI)
	_prop("03_Residential/Interactive_Props/RES_IP_StorageChest.glb", "C13_Locker", D(CRANK_AT), D_YAW - PI * 0.5)
	_prop("02_Town/Utilities/UT_ElectricalCabinet.glb", "C13_Release", D(RELEASE_AT - Vector3(0, 1.2, 0.35)), D_YAW + PI)
	c12._light(D(o + Vector3(0, 2.6, 0)), 0.5, 6.0, Color(0.9, 0.85, 0.7))
	its["note"] = _spot("C13_Note", D(NOTE_AT), Vector3(0.8, 0.6, 0.8), _read_note)
	its["crank"] = _spot("C13_Crank", D(CRANK_AT + Vector3(0, 0.6, 0)), Vector3(1.2, 1.2, 1.2), _take_crank)
	its["release"] = _spot("C13_ReleaseUse", D(RELEASE_AT + Vector3(0, 0, -0.75)), Vector3(1.2, 1.6, 0.6), _use_release)
	# the courtyard: a collapsed shed (the Shellcrawler waits behind it), debris, a storm drain
	_dbox("Shed", SHED + Vector3(0, 1.3, 0), Vector3(5.0, 2.6, 3.0), "grime")
	_dbox("Debris", Vector3(3.5, 0.6, 61.5), Vector3(3.0, 1.2, 1.6), "concrete")
	_dbox("Debris", Vector3(-3.0, 0.5, 52.0), Vector3(2.2, 1.0, 2.0), "concrete")
	_dbox("Debris", Vector3(-12.0, 0.7, 62.0), Vector3(2.6, 1.4, 1.8), "grime")
	_box(dist, "Slab", D(Vector3(6.5, 0.9, 65.0)), Vector3(4.0, 0.25, 2.0), "concrete", true, Basis(Vector3.UP, D_YAW).rotated(Vector3.FORWARD, 0.35))
	_prop("02_Town/Street_Props/SP_DrainGrate.glb", "C13_Drain", D(DRAIN), D_YAW)
	its["passage"] = _spot("C13_Passage", D(PASSAGE + Vector3(0, 0, 0.6)), Vector3(2.4, 2.0, 1.2), _enter_passage)
	# dense mist (visible), lighter wisps; the mist the chapter thickens on the way back is the world fog
	for z in MIST_ZONES:
		var c: Vector3 = z[0]
		for k in 3:
			_mist_quad(dist, D(c + Vector3(0, 0.25 + k * 0.6, 0)), Vector2(z[1] * 2.2, z[1] * 2.2), 0.5 - k * 0.12)
		for k in 4:
			var a := k * PI * 0.5
			_mist_quad(dist, D(c + Vector3(cos(a), 0, sin(a)) * z[1] * 0.5 + Vector3(0, 1.4, 0)), Vector2(z[1] * 1.6, 2.8), 0.28, true)


func _build_under() -> void:
	under = Node3D.new()
	under.name = "C13_Under"
	world.add_child(under)
	# corridors (x -1.2..1.2 wide, 2.8 high): entry south-north z 0..12, a dead end west at z 8 (the voice), east at
	# z 12 to x 12, north to the chamber at z 24, a dead end east at z 18
	_ubox("Floor", Vector3(5.0, -0.15, 22.0), Vector3(40.0, 0.3, 50.0), "damp")
	_ubox("Ceiling", Vector3(5.0, 3.0, 13.0), Vector3(40.0, 0.3, 26.5), "damp")
	var walls := [
		[Vector3(-1.2, 1.4, 3.4), Vector3(0.3, 2.8, 6.8)], [Vector3(1.2, 1.4, 5.5), Vector3(0.3, 2.8, 11.0)],
		[Vector3(-1.2, 1.4, 11.2), Vector3(0.3, 2.8, 4.0)], [Vector3(-5.6, 1.4, 6.8), Vector3(9.0, 2.8, 0.3)],
		[Vector3(-5.6, 1.4, 9.2), Vector3(9.0, 2.8, 0.3)], [Vector3(-10.0, 1.4, 8.0), Vector3(0.3, 2.8, 2.6)],
		[Vector3(0.0, 1.4, 0.0), Vector3(2.6, 2.8, 0.3)], [Vector3(4.85, 1.4, 13.2), Vector3(11.9, 2.8, 0.3)],
		[Vector3(6.6, 1.4, 10.8), Vector3(10.8, 2.8, 0.3)], [Vector3(13.2, 1.4, 14.2), Vector3(0.3, 2.8, 6.8)],
		[Vector3(10.8, 1.4, 18.4), Vector3(0.3, 2.8, 11.2)],
		[Vector3(13.2, 1.4, 22.5), Vector3(0.3, 2.8, 3.0)], [Vector3(16.6, 1.4, 16.8), Vector3(7.0, 2.8, 0.3)],
		[Vector3(16.6, 1.4, 19.2), Vector3(7.0, 2.8, 0.3)], [Vector3(20.0, 1.4, 18.0), Vector3(0.3, 2.8, 2.6)]]
	for w in walls:
		_ubox("Wall", w[0], w[1], "concrete")
	# the chamber (x 4..20, z 24..40, 5 m high): concrete with old stone behind it; the doorway in the far wall
	_ubox("ChamberRoof", Vector3(12.0, 5.2, 32.0), Vector3(16.6, 0.3, 16.6), "stone")
	_ubox("CWall", Vector3(7.4, 2.5, 24.0), Vector3(6.8, 5.0, 0.3), "concrete")
	_ubox("CWall", Vector3(16.6, 2.5, 24.0), Vector3(6.8, 5.0, 0.3), "concrete")
	_ubox("CWallTop", Vector3(12.0, 4.0, 24.0), Vector3(2.4, 2.0, 0.3), "concrete")
	_ubox("CWall", Vector3(20.0, 2.5, 32.0), Vector3(0.3, 5.0, 16.0), "stone")
	_ubox("CWall", Vector3(4.0, 2.5, 26.4), Vector3(0.3, 5.0, 4.8), "stone")
	_ubox("CWall", Vector3(4.0, 2.5, 35.6), Vector3(0.3, 5.0, 8.8), "stone")
	_ubox("CWallTop", Vector3(4.0, 3.5, 30.0), Vector3(0.3, 3.0, 2.4), "stone")
	_ubox("FarWall", Vector3(7.0, 2.5, 40.0), Vector3(6.0, 5.0, 0.4), "stone")
	_ubox("FarWall", Vector3(17.0, 2.5, 40.0), Vector3(6.0, 5.0, 0.4), "stone")
	_ubox("FarWallTop", Vector3(12.0, 4.6, 40.0), Vector3(4.0, 1.2, 0.4), "stone")
	doorway_slab = _ubox("Doorway", DOORWAY, Vector3(4.0, 4.0, 0.35), "stone")
	beam = _ubox("Beam", BEAM + Vector3(0, 1.2, 0), Vector3(0.4, 0.4, 3.4), "rust")
	beam.rotation = Vector3(0.6, 0.0, 0.0)
	# the dark beyond the doorway; the vast shape in it (unlit, never detailed)
	_ubox("VoidFloor", Vector3(12.0, -0.15, 60.0), Vector3(30.0, 0.3, 40.0), "damp", false)
	var stop: StaticBody3D = _ubox("Threshold", Vector3(12.0, 2.0, 40.9), Vector3(4.0, 4.0, 0.3), "stone")     # not this chapter: an
	(stop.get_child(0) as MeshInstance3D).visible = false                                         # unseen stop past the sill
	void_shape = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 5.0
	cap.height = 16.0
	void_shape.mesh = cap
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color(0.02, 0.02, 0.025, 0.0)
	vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_shape.material_override = vm
	under.add_child(void_shape)
	void_shape.global_position = UL(VOID_SHAPE)
	void_shape.rotation = Vector3(0, 0, 0.25)
	# the damaged passage out (west wall at z 30): a crawlway, then the storm drain
	_ubox("Crawl", Vector3(0.0, 1.0, 28.8), Vector3(8.0, 2.0, 0.3), "damp")
	_ubox("Crawl", Vector3(0.0, 1.0, 31.2), Vector3(8.0, 2.0, 0.3), "damp")
	_ubox("CrawlEnd", Vector3(-4.0, 1.0, 30.0), Vector3(0.3, 2.0, 2.6), "damp")
	_ubox("CrawlRoof", Vector3(0.0, 2.1, 30.0), Vector3(8.0, 0.2, 2.6), "damp")
	collapse_block = _ubox("Collapse", COLLAPSE + Vector3(0, 6.0, 0), Vector3(2.6, 3.2, 1.2), "concrete")
	collapse_block.visible = false
	collapse_block.collision_layer = 0
	# landmarks on the right way: lamps; the symbol cut into the stone
	for p in [Vector3(0, 2.6, 6.0), Vector3(6.0, 2.6, 12.0), Vector3(12.0, 2.6, 19.0), Vector3(12.0, 4.2, 32.0)]:
		c12._light(UL(p), 0.7, 8.0, Color(0.85, 0.9, 1.0))
	for p in [[Vector3(12.0, 2.2, 39.78), Vector3(0, 0, -1), 2.0], [Vector3(19.83, 2.4, 28.0), Vector3(-1, 0, 0), 0.8],
			[Vector3(4.17, 2.6, 37.0), Vector3(1, 0, 0), 0.6], [Vector3(10.95, 1.6, 22.0), Vector3(1, 0, 0), 0.4]]:
		c12._decal(UL(p[0]), p[1], p[2], Color(0.07, 0.06, 0.05, 1))
	var plaque := Label3D.new()
	plaque.text = "GREYHAVEN PUBLIC WORKS\nSERVICE GALLERY 7  -  19##\nTHIS CHAMBER IS N"
	plaque.font_size = 22
	plaque.pixel_size = 0.004
	plaque.modulate = Color(0.55, 0.5, 0.42)
	under.add_child(plaque)
	plaque.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), UL(PLAQUE))
	for p in [Vector3(9.0, 0.15, 36.0), Vector3(15.5, 0.2, 35.0), Vector3(13.0, 0.12, 30.5)]:
		_ubox("Fragment", p, Vector3(0.6, 0.3, 0.45), "stone")
	_prop("02_Town/Utilities/UT_JunctionBox.glb", "C13_Winch", UL(WINCH), -PI * 0.5)
	_prop("08_Inventory/Story_Items/INV_FoldedNote.glb", "C13_Evidence", UL(EVIDENCE), 0.4)
	for k in [["winch", WINCH + Vector3(-0.4, 1.0, 0), Vector3(0.8, 1.4, 1.2), _use_winch], ["beam", BEAM + Vector3(0, 1.0, 0), Vector3(1.2, 1.6, 2.6), _move_beam],
			["plaque", PLAQUE, Vector3(0.6, 1.0, 1.6), _examine.bind("plaque")], ["markings", Vector3(19.6, 2.0, 28.0), Vector3(0.6, 1.6, 1.6), _examine.bind("markings")],
			["fragments", Vector3(9.0, 0.6, 36.0), Vector3(1.2, 1.0, 1.2), _examine.bind("fragments")], ["evidence", EVIDENCE + Vector3(0, 0.3, 0), Vector3(0.9, 0.9, 0.9), _take_evidence],
			["crawl", CRAWL + Vector3(-1.5, 1.0, 0), Vector3(1.0, 1.8, 2.2), _use_crawl], ["help", Vector3(-1.0, 1.0, 30.0), Vector3(1.4, 1.8, 2.2), _help_companion]]:
		its[k[0]] = _spot("C13_" + String(k[0]), UL(k[1]), k[2], k[3])
	# low mist in the gallery
	for m in [[Vector3(0, 0.25, 6.0), Vector2(2.3, 12.0)], [Vector3(6.0, 0.25, 12.0), Vector2(12.0, 2.3)], [Vector3(12.0, 0.3, 32.0), Vector2(15.0, 15.0)]]:
		_mist_quad(under, UL(m[0]), m[1], 0.35)


# ------------------------------------------------------------------ Mist Exposure (this chapter's hazard)
## 0..100. Rises in the dense mist zones, falls in clear air, indoors and below ground; soft effects only.
func exposure() -> float:
	return float(st().get("exposure", 0.0))


func _build_exposure_fx() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	cl.name = "C13_ExposureFX"
	add_child(cl)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float amount = 0.0;
uniform sampler2D screen : hint_screen_texture, filter_linear;
void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 18.0 + TIME * 1.7) * 0.0025 * amount;
	uv.y += cos(uv.x * 14.0 + TIME * 1.3) * 0.0018 * amount;
	vec3 c = texture(screen, uv).rgb;
	float g = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, vec3(g) * vec3(0.92, 0.96, 1.0), 0.35 * amount);
	float v = smoothstep(0.35, 0.95, distance(SCREEN_UV, vec2(0.5)));
	c = mix(c, vec3(0.78, 0.8, 0.82), v * 0.55 * amount);
	COLOR = vec4(c, 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_overlay.material = m
	_overlay.visible = false
	cl.add_child(_overlay)
	_heart = AudioStreamPlayer.new()
	_heart.stream = _streams["heart"]
	_heart.volume_db = -40.0
	add_child(_heart)


func _zone_at(p: Vector3, zones: Array) -> bool:
	for z in zones:
		var c := D(z[0])
		if Vector2(p.x - c.x, p.z - c.z).length() < float(z[1]):
			return true
	return false


func _exposure_tick(delta: float) -> void:
	var p := player.global_position
	var e := exposure()
	var active: bool = Game.has_flag("ch13_set_out") and not Game.has_flag("ch13_returned")
	if active and p.y > -20.0 and _zone_at(p, MIST_ZONES):
		e += 9.0 * delta
		if not Game.has_flag("ch13_mist_warned"):
			Game.set_flag("ch13_mist_warned")
			_hint("The mist is thick here. Stay in it too long and it gets into your head. Clear air helps.")
	elif p.y < -20.0 and Game.has_flag("ch13_entrance_open") and not Game.has_flag("ch13_out_of_passage"):
		e += 1.5 * delta                             # the mist pouring out of the doorway
	elif p.y < -20.0 or _zone_at(p, CLEAR_ZONES) or c10.inside_room(player):
		e -= 14.0 * delta
	else:
		e -= 2.5 * delta
	e = clampf(e, 0.0, 100.0)
	st()["exposure"] = e
	report["exposure_max"] = maxf(float(report["exposure_max"]), e)
	_apply_exposure(e, delta)


func _apply_exposure(e: float, delta := 0.0) -> void:
	var amt := clampf((e - 20.0) / 80.0, 0.0, 1.0)
	_overlay.visible = amt > 0.01
	(_overlay.material as ShaderMaterial).set_shader_parameter("amount", amt)
	# muffled sound (a low-pass on the master bus while exposed; removed when it is gone)
	if amt > 0.01 and _lp_idx < 0:
		var lp := AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(0, lp)
		_lp_idx = AudioServer.get_bus_effect_count(0) - 1
	if _lp_idx >= 0:
		if amt <= 0.01:
			AudioServer.remove_bus_effect(0, _lp_idx)
			_lp_idx = -1
		else:
			(AudioServer.get_bus_effect(0, _lp_idx) as AudioEffectLowPassFilter).cutoff_hz = lerpf(9000.0, 900.0, amt)
	# a heartbeat from moderate exposure; misleading distant sounds at high exposure
	if e > 45.0:
		if not _heart.playing:
			_heart.play()
		_heart.volume_db = lerpf(-22.0, -6.0, clampf((e - 45.0) / 55.0, 0.0, 1.0))
		_heart.pitch_scale = lerpf(1.0, 1.5, clampf((e - 45.0) / 55.0, 0.0, 1.0))
	elif _heart.playing:
		_heart.stop()
	if e > 70.0 and delta > 0.0:
		_false_t -= delta
		if _false_t <= 0.0:
			_false_t = randf_range(5.0, 10.0)
			var a := randf() * TAU
			_play(["skitter", "clank", "voice"][randi() % 3], player.global_position + Vector3(cos(a), 1.0, sin(a)) * 14.0, -6.0)


func _clear_exposure_fx() -> void:
	if _lp_idx >= 0:
		AudioServer.remove_bus_effect(0, _lp_idx)
		_lp_idx = -1
	if _overlay:
		_overlay.visible = false
	if _heart:
		_heart.stop()


func _exit_tree() -> void:
	_clear_exposure_fx()
	_set_fog(false)


## The world fog thickens near the district and while the mist spreads (restored afterwards).
func _set_fog(thick: bool, amount := 1.0) -> void:
	var env: Environment = player.camera.environment if player and player.camera else null
	if env == null:
		var we := world.find_child("WorldEnvironment", true, false) as WorldEnvironment
		env = we.environment if we else null
	if env == null:
		return
	if _fog0 < 0.0:
		_fog0 = env.fog_density
	env.fog_density = _fog0 * (1.0 + 1.6 * amount) if thick else _fog0


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	_node("Marcus").visible = alive()
	if Game.has_flag("ch13_gate_open"):
		_open_gate(true)
	if Game.has_flag("ch13_beam_moved"):
		beam.rotation = Vector3(0, 0, 0)
		beam.position = UL(BEAM + Vector3(-2.0, 0.2, -2.0))
	if Game.has_flag("ch13_entrance_open"):
		doorway_slab.position = UL(DOORWAY + Vector3(0, -4.2, 0))
	if Game.has_flag("ch13_collapsed"):
		_drop_collapse(true)
	var out: bool = Game.has_flag("ch13_set_out") and not Game.has_flag("ch13_returned")
	var k := companion()
	if out:
		c9._start_follow(k)
		for other in group():
			if other != k:
				c12._stay_inside(other)
		c12._rejoin.call_deferred(k)
		if Game.has_flag("ch13_choice_evidence"):
			_slow_companion()
	else:
		c10._place_inside()
	if Game.has_flag("ch13_district_reached") and not Game.has_flag("ch13_returned"):
		_set_fog(true, 0.6)
	if Game.has_flag("ch13_collapsed") and not Game.has_flag("ch13_choice_made"):
		_decide.call_deferred()
	if Game.has_flag("ch13_street_seen") and not Game.has_flag("ch13_returned") and not Game.has_flag("ch13_in_passage"):
		_spawn_patroller()
	if Game.has_flag("ch13_gate_open") and not Game.has_flag("ch13_in_passage"):
		_spawn_crab(true)
	_apply_exposure(exposure())
	_refresh_prompts()
	_guide()


func _refresh_prompts() -> void:
	if its.has("npc_Eddie"):
		var talk: bool = Game.has_flag("ch13_started") and not Game.has_flag("ch13_set_out") and not _busy.get("talk", false) \
			and not _busy.get("prep", false) and not _busy.get("opening", false)
		_set_prompt("npc_Eddie", "[E] Talk" if talk else "")
	var d := Game.has_flag("ch13_district_reached")
	_set_prompt("note", "[E] Read the Note" if d and not Game.has_item("checkpoint_note") else "")
	_set_prompt("crank", "[E] Search the Locker" if d and not Game.has_flag("ch13_crank_found") else "")
	_set_prompt("release", "[E] Use the Manual Release" if d and not Game.has_flag("ch13_gate_open") else "")
	_set_prompt("passage", "[E] Squeeze into the Passage" if Game.has_flag("ch13_gate_open") and not Game.has_flag("ch13_in_passage") else "")
	var u := Game.has_flag("ch13_in_passage")
	var seen: Dictionary = st().get("clues", {})
	for k in ["plaque", "markings", "fragments"]:
		_set_prompt(k, ("[E] Examine the " + k.capitalize()) if u and Game.has_flag("ch13_chamber_reached") and not seen.get(k, false) else "")
	_set_prompt("winch", "[E] Turn the Winch" if Game.has_flag("ch13_chamber_reached") and not Game.has_flag("ch13_winch_turned") else "")
	_set_prompt("beam", "[E] Shift the Fallen Beam" if Game.has_flag("ch13_chamber_reached") and not Game.has_flag("ch13_beam_moved") else "")
	var deciding: bool = Game.has_flag("ch13_collapsed") and not Game.has_flag("ch13_choice_made")
	_set_prompt("evidence", "[E] Secure the Evidence" if deciding else "")
	_set_prompt("help", "[E] Help %s Through" % companion() if deciding else "")
	_set_prompt("crawl", "[E] Crawl Out Through the Damaged Passage" if Game.has_flag("ch13_choice_made") and not Game.has_flag("ch13_out_of_passage") else "")


func _guide() -> void:
	var t: Variant = null
	var label := ""
	var p := player.global_position
	if not Game.has_flag("ch13_talk_done") or not Game.has_flag("ch13_set_out"):
		t = _node("Eddie")
		label = "THE MAP"
	elif not Game.has_flag("ch13_district_reached"):
		while _route_i < ROAD.size() - 1 and Vector2(p.x - ROAD[_route_i].x, p.z - ROAD[_route_i].z).length() < 4.0:
			_route_i += 1
		t = ROAD[_route_i] + Vector3(0, 1.2, 0)
		label = "THE OLD ROAD"
	elif not Game.has_flag("ch13_gate_open"):
		t = D(OFFICE[0] + Vector3(-3.0, 1.2, 0.0)) if not Game.has_flag("ch13_crank_found") else D(RELEASE_AT)
		label = "CHECKPOINT"
	elif not Game.has_flag("ch13_in_passage"):
		t = D(PASSAGE)
		label = "PASSAGE"
	elif not Game.has_flag("ch13_chamber_reached"):
		t = UL(Vector3(12.0, 1.6, 26.0))
		label = "FOLLOW THE LAMPS"
	elif not Game.has_flag("ch13_entrance_open"):
		t = UL(DOORWAY)
		label = "SEALED DOORWAY"
	elif Game.has_flag("ch13_choice_made") and not Game.has_flag("ch13_out_of_passage"):
		t = UL(CRAWL + Vector3(-1.5, 1.0, 0))
		label = "WAY OUT"
	elif Game.has_flag("ch13_out_of_passage") and not Game.has_flag("ch13_returned"):
		t = c10.hl(c10.PORCH) + Vector3(0, 1.4, 0)
		label = "MILL HOUSE"
	if hud.has_method("set_marker"):
		hud.set_marker(t, label)


# ------------------------------------------------------------------ scene 1: the map, preparation
func _opening() -> void:
	_busy["opening"] = true
	_hold(true)
	await hud.fade_to(1.0, 0.8)
	c10._place_inside()
	_node("Marcus").visible = alive()
	c12._place_map()
	var mp: Vector3 = c12.map_prop.global_position
	player.global_position = c10.hl(Vector3(0.6, 0.7, 4.9))
	player.velocity = Vector3.ZERO
	var v: Vector3 = mp - player.camera.global_position
	player.set_yaw_pitch(atan2(-v.x, -v.z), asin(clampf(v.normalized().y, -1.0, 1.0)))
	hud.location_caption("THE MILL HOUSE  -  THE NEXT DAY", 2.2)
	await get_tree().create_timer(1.0).timeout
	await hud.fade_to(0.0, 1.0)
	_hold(false)
	_busy["opening"] = false
	_apply()
	world.save_checkpoint("chapter14_start")
	await hud.chapter_start(CHAPTER)
	if not Game.has_flag("ch13_talk_done"):
		_hint("The group is waiting by the map.")


func _talk(_b: Node) -> void:
	if not Game.has_flag("ch13_started") or _busy.get("talk", false) or _busy.get("opening", false) or Game.has_flag("ch13_set_out"):
		return
	if Game.has_flag("ch13_talk_done"):
		_prepare()
		return
	_busy["talk"] = true
	await c9._talk_group("c13_road", [_node("Eddie"), _node("Ruth")])
	if alive():
		await c9._talk_group("c13_road_marcus", [_node("Marcus")])
	Game.set_flag("ch13_talk_done")
	_busy["talk"] = false
	_prepare()


func _prepare() -> void:
	if _busy.get("prep", false) or Game.has_flag("ch13_set_out"):
		return
	_busy["prep"] = true
	var opts := companion_options()
	var fl := get_tree().get_first_node_in_group("veil_flashlight")
	var food := 0
	var water := 0
	for id in Game.inventory:
		food += 1 if Game.shelter_resource(id) == "food" else 0
		water += 1 if Game.shelter_resource(id) == "water" else 0
	var text := "INTO THE VEIL  -  thick mist, the old district, maybe a long way back\nFlashlight spares %d    Painkillers %d    Food %d    Water %d    Items carried %d" % [
		int(fl.get("spares")) if fl else 0, Game.inventory.count("painkillers"), food, water, Game.inventory.size()]
	var labels := []
	for k in opts:
		var h: String = world.survivors.HEALTH_TEXT[world.survivors.health(k)] if world.survivors else "Healthy"
		labels.append("Set out with %s (%s)" % [k, h.to_lower()])
	labels.append("Not yet (check my things)")
	var i: int = await p4.choice.ask(text, labels, player)
	_busy["prep"] = false
	if i < 0 or i >= opts.size():
		if hud.has_method("toggle_inventory") and not hud.inv_panel.visible:
			hud.toggle_inventory()
		return
	st()["companion"] = opts[i]
	Game.set_flag("ch13_set_out")
	c9._start_follow(opts[i])
	Dialogue.say(_cid("c13_setout"), false, true)
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ scene 2-3: the road, the district
func _journey_tick() -> void:
	var p := player.global_position
	if not Game.has_flag("ch13_set_out") or Game.has_flag("ch13_returned"):
		return
	var dl := Basis(Vector3.UP, D_YAW).inverse() * (p - D_ORIGIN)
	if not Game.has_flag("ch13_sign1") and p.distance_to(SIGN_1) < 7.0:
		Game.set_flag("ch13_sign1")
	if not Game.has_flag("ch13_district_reached") and dl.z > -2.0 and absf(dl.x) < 19.0 and dl.z < 40.0 and p.y > -10.0:
		Game.set_flag("ch13_district_reached")
		world.save_checkpoint("chapter14_district")
		hud.location_caption("THE OLD DISTRICT", 2.4)
		_set_fog(true, 0.6)
		_refresh_prompts()
	if Game.has_flag("ch13_sign1") and not Game.has_flag("ch13_sign_again") and p.distance_to(D(SIGN_2)) < 6.0 and not Dialogue.is_busy() and not world.conversing:
		Game.set_flag("ch13_sign_again")
		report["sign_seen"] = true
		c9._talk_group(_cid("c13_sign"), [_comp()])
	if Game.has_flag("ch13_district_reached") and not Game.has_flag("ch13_street_seen") and dl.z > 9.0 and dl.z < 30.0 and not Dialogue.is_busy() \
			and not world.conversing:
		_roof_skitter()


## A Skitter crosses the roofline (seen), then drops out of sight behind it; a second comes out from behind the
## pickup and starts to walk the street.
func _roof_skitter() -> void:
	if _busy.get("roof", false) or Game.has_flag("ch13_street_seen"):
		return
	_busy["roof"] = true
	Game.set_flag("ch13_street_seen")
	var sk := _make_skitter("C13_RoofSkitter", D(ROOF_RUN[0]))
	var tw := create_tween()
	tw.tween_property(sk, "global_position", D(ROOF_RUN[1]), 2.6)
	tw.tween_property(sk, "global_position", D(ROOF_RUN[2]), 0.7)
	sk.rotation.y = D_YAW
	Dialogue.say(_cid("c13_roof"), false, true)
	await tw.finished
	sk.queue_free()                                  # behind the house, below the roofline: out of sight
	await get_tree().create_timer(1.4).timeout
	_spawn_patroller(true)
	_busy["roof"] = false


func _make_skitter(n: String, at: Vector3) -> Node3D:
	var sk := (load(SKITTER_PATH) as PackedScene).instantiate() as Node3D
	sk.name = n
	world.add_child(sk)
	if sk is CollisionObject3D:
		(sk as CollisionObject3D).collision_layer = 0
		(sk as CollisionObject3D).collision_mask = 0
	sk.set_physics_process(false)
	sk.global_position = at
	VeilCreatureLook.apply_skitter(sk, at.y)
	var ap := sk.find_children("*", "AnimationPlayer", true, false)
	if not ap.is_empty():
		for an in (ap[0] as AnimationPlayer).get_animation_list():
			if String(an).to_lower().contains("run"):
				(ap[0] as AnimationPlayer).play(an)
				break
	return sk


func _spawn_patroller(emerge := false) -> void:
	for s in skitters:
		if s["kind"] == "patrol":
			return
	var at := D(SKITTER_PATROL[0] + Vector3(-1.5, 0, 1.5)) if emerge else D(SKITTER_PATROL[0])
	var sk := _make_skitter("C13_StreetSkitter", at)
	skitters.append({"node": sk, "kind": "patrol", "i": 1, "mode": "patrol", "t": 0.0, "cd": 0.0})


## The street Skitter walks its round; it notices the player close in front of it (farther in thick mist / when
## exposed), lunges, and goes back to its round. A hit hurts (never lethal on its own: it backs off).
func _skitter_tick(delta: float) -> void:
	for s in skitters:
		var sk: Node3D = s["node"]
		if not is_instance_valid(sk):
			continue
		s["cd"] = maxf(float(s["cd"]) - delta, 0.0)
		var sp := sk.global_position
		var pp := player.global_position
		var to_p := (pp - sp) * Vector3(1, 0, 1)
		var fwd := Vector3(sin(sk.rotation.y), 0, cos(sk.rotation.y))
		var sense := 7.0 + (4.0 if exposure() > 70.0 else 0.0)
		var crouch: bool = bool(player.get("crouching")) if player.get("crouching") != null else false
		if crouch:
			sense *= 0.55
		var noticed: bool = to_p.length() < sense and (fwd.dot(to_p.normalized()) > 0.2 or to_p.length() < 2.5) and absf(pp.y - sp.y) < 2.0
		var target: Vector3
		var speed := 1.6
		match String(s["mode"]):
			"patrol":
				target = D(SKITTER_PATROL[int(s["i"])])
				if Vector2(sp.x - target.x, sp.z - target.z).length() < 0.5:
					s["i"] = (int(s["i"]) + 1) % SKITTER_PATROL.size()
				if noticed and float(s["cd"]) <= 0.0:
					s["mode"] = "chase"
					s["t"] = 4.0
					_play("skitter", sp, 0.0)
			"chase":
				target = pp
				speed = 4.4
				s["t"] = float(s["t"]) - delta
				if to_p.length() < 1.2 and float(s["cd"]) <= 0.0:
					player.damage(10.0, sp)
					report["skitter_hits"] += 1
					s["cd"] = 3.0
					s["mode"] = "patrol"
				elif float(s["t"]) <= 0.0:
					s["mode"] = "patrol"
					s["cd"] = 2.0
		var d := (target - sp) * Vector3(1, 0, 1)
		if d.length() > 0.05:
			var nxt := sp + d.normalized() * minf(speed * delta, d.length())
			if c12._clear(sp, nxt):
				sk.global_position = Vector3(nxt.x, sp.y, nxt.z)
			sk.rotation.y = atan2(d.x, d.z)


# ------------------------------------------------------------------ scene 4: the checkpoint gate
func _read_note(_b: Node) -> void:
	if Game.has_item("checkpoint_note"):
		return
	Game.add_item("checkpoint_note")
	Sfx.play("pickup", player.global_position, -6.0)
	Dialogue.say("c13_note", false, true)
	_refresh_prompts()


func _take_crank(_b: Node) -> void:
	if Game.has_flag("ch13_crank_found"):
		return
	Game.set_flag("ch13_crank_found")
	Game.add_item("gate_crank")
	Sfx.play("pickup", player.global_position, -6.0)
	Dialogue.say("c13_crank", false, true)
	_refresh_prompts()
	_guide()


func _use_release(_b: Node) -> void:
	if Game.has_flag("ch13_gate_open") or _busy.get("gate", false):
		return
	if not Game.has_item("gate_crank"):
		Dialogue.say("c13_release_jammed", false, true)
		return
	_busy["gate"] = true
	Game.remove_item("gate_crank")
	Sfx.play("door_open", D(Vector3(0, 1.5, WALL_Z)), 2.0, 0.45)
	await _open_gate(false)
	Game.set_flag("ch13_gate_open")
	_spawn_crab(false)
	world.save_checkpoint("chapter14_courtyard")
	_busy["gate"] = false
	_refresh_prompts()
	_guide()


func _open_gate(instant: bool) -> void:
	var to: Vector3 = D(Vector3(5.2, 1.6, WALL_Z + 0.4))
	if instant:
		gate.global_position = to
		return
	var tw := create_tween()
	tw.tween_property(gate, "global_position", to, 2.8).set_trans(Tween.TRANS_SINE)
	await tw.finished


# ------------------------------------------------------------------ scene 5: the Shellcrawler
func _spawn_crab(restoring: bool) -> void:
	if crab != null:
		return
	crab = (load(CRAB_PATH) as PackedScene).instantiate() as CharacterBody3D
	crab.name = "C13_Shellcrawler"
	world.add_child(crab)
	crab.collision_layer = 0
	crab.collision_mask = 1
	crab.global_position = D(CRAB_HIDE)
	crab.rotation.y = D_YAW + PI
	crab.set_meta("hidden", not restoring and not Game.has_flag("ch13_crab_seen"))
	VeilCreatureLook.apply_ground(crab, crab.global_position.y)
	crab_anim = crab.get_node_or_null("Model/AnimationPlayer") as AnimationPlayer
	_crab_play("Idle")
	_crab_prev = crab.global_position
	if Game.has_flag("ch13_crab_seen"):
		crab.global_position = D(Vector3(4.0, 0.0, 70.0))     # a load mid-escape: it is between the shed and the passage
		crab.set_meta("hunting", true)


func _crab_play(n: String) -> void:
	if crab_anim and crab_anim.has_animation(n) and crab_anim.current_animation != n:
		crab_anim.play(n)


func _crab_reveal() -> void:
	if _busy.get("crab", false) or Game.has_flag("ch13_crab_seen"):
		return
	_busy["crab"] = true
	report["crab_runs"] += 1
	_hold(true)
	# a claw scraping concrete, then it moves sideways out from behind the shed; the companion backs away
	_play("scrape", D(CRAB_HIDE + Vector3(0, 0.5, 0)), 4.0)
	await c8._turn_to(D(CRAB_HIDE + Vector3(-2.0, 0.6, 0)), 1.2)
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.8, 1.0)
	_crab_play("Crawl_Sideways")
	var tw := create_tween()
	tw.tween_property(crab, "global_position", D(CRAB_HIDE + Vector3(-4.5, 0, -1.0)), 2.6)
	var k := companion()
	var an = world.animators.get(k)
	if an:
		(c9.follows[k] as VeilCompanionFollow).stop()
		var back := (_comp().global_position - crab.global_position) * Vector3(1, 0, 1)
		an.walk_to([_comp().global_position + back.normalized() * 1.6], 1.2)
	await tw.finished
	_crab_play("Idle")
	await c9._talk_group(_cid("c13_crab"), [_comp()])
	_crab_play("Attack_Grasp")
	_play("claw", crab.global_position, 4.0)
	var tl := create_tween()
	tl.tween_property(crab, "global_position", crab.global_position + (player.global_position - crab.global_position) * Vector3(1, 0, 1) * 0.3, 0.35)
	await tl.finished
	Dialogue.say(_cid("c13_run"), false, true)
	var tb := create_tween()
	tb.tween_property(cam, "fov", fov0, 0.4)
	await tb.finished
	cam.fov = fov0
	Game.set_flag("ch13_crab_seen")
	crab.set_meta("hidden", false)
	crab.set_meta("hunting", true)
	_crab_prev = crab.global_position
	c9._start_follow(k)
	(c9.follows[k] as VeilCompanionFollow).run_speed = 5.0
	_hold(false)
	_busy["crab"] = false
	_guide()


## Heavy, deliberate steps toward the player; every few seconds a sudden sideways burst. It slides along walls
## (its own collision), cannot fit the passage, and a hit hurts (never lethal on its own: it backs off).
func _crab_tick(delta: float) -> void:
	if crab == null or not is_instance_valid(crab) or not crab.get_meta("hunting", false) or Game.has_flag("ch13_in_passage"):
		return
	var pp := player.global_position
	var cp := crab.global_position
	var to_p := (pp - cp) * Vector3(1, 0, 1)
	_crab_cd = maxf(_crab_cd - delta, 0.0)
	_crab_next_burst -= delta
	var vel := Vector3.ZERO
	if _crab_burst > 0.0:
		_crab_burst -= delta
		vel = _crab_burst_dir * 5.2
		_crab_play("Crawl_Sideways")
	elif _crab_cd > 1.2:
		vel = -to_p.normalized() * 0.8                # backs off after a hit
		_crab_play("Defend")
	else:
		vel = to_p.normalized() * 2.5
		_crab_play("Crawl_Forward")
		if _crab_next_burst <= 0.0 and to_p.length() < 14.0:
			_crab_next_burst = randf_range(2.6, 4.2)
			_crab_burst = 0.55
			_crab_burst_dir = to_p.normalized().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	# the passage mouth is too narrow: it stops short of it
	var dl := Basis(Vector3.UP, D_YAW).inverse() * (cp - D_ORIGIN)
	if dl.z > 72.5 and vel.dot(Basis(Vector3.UP, D_YAW) * Vector3(0, 0, 1)) > 0.0:
		vel = Vector3.ZERO
	crab.velocity = Vector3(vel.x, crab.velocity.y - 9.8 * delta, vel.z)
	crab.move_and_slide()
	if crab.is_on_floor():
		crab.velocity.y = 0.0
	if to_p.length() > 0.1:
		crab.rotation.y = lerp_angle(crab.rotation.y, atan2(to_p.x, to_p.z), 3.0 * delta)
	report["crab_max_step"] = maxf(float(report["crab_max_step"]), crab.global_position.distance_to(_crab_prev) / maxf(delta * 60.0, 1.0))
	_crab_prev = crab.global_position
	if to_p.length() < 2.4 and _crab_cd <= 0.0:
		_crab_cd = 2.4
		report["crab_hits"] += 1
		_crab_play("Attack_Grasp")
		_play("claw", cp, 2.0)
		player.damage(16.0, cp)


# ------------------------------------------------------------------ scene 6: the passage of echoes
func _enter_passage(_b: Node) -> void:
	if Game.has_flag("ch13_in_passage") or _busy.get("passage", false) or not Game.has_flag("ch13_gate_open"):
		return
	if _comp().global_position.distance_to(player.global_position) > 12.0:
		_hint("Wait for %s." % companion())
		return
	_busy["passage"] = true
	# its claws strike the mouth of the passage as they squeeze in; then it gives up
	if crab and is_instance_valid(crab) and crab.global_position.distance_to(player.global_position) < 14.0:
		_crab_play("Attack_Grasp")
		_play("claw", D(PASSAGE), 6.0)
		c12._shake(0.5, 0.04)
	Game.set_flag("ch13_in_passage")
	await c12._move_through(UL(U_ENTRY), PI, UL(U_ENTRY + Vector3(0.6, 0.0, -0.6) + Vector3(0, 0, 0.9)))
	if crab and is_instance_valid(crab):
		crab.queue_free()                            # it went back behind the shed while nobody could see it
		crab = null
	for s in skitters:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	skitters.clear()
	_set_fog(false)
	_busy["passage"] = false
	await get_tree().create_timer(2.0).timeout
	_voice()
	_refresh_prompts()
	_guide()


## A voice from the dead end, like someone the protagonist knows (someone alive, back at the house: so it cannot
## be them). The companion says not to follow it.
func _voice() -> void:
	if Game.has_flag("ch13_voice_heard"):
		return
	Game.set_flag("ch13_voice_heard")
	_play("voice", UL(U_VOICE), 4.0)
	Dialogue.say("c13_voice_alt" if companion() == "Ruth" else "c13_voice", false, true)
	while Dialogue.is_busy():
		await get_tree().process_frame
	await c9._talk_group(_cid("c13_voice_react"), [_comp()])


func _passage_tick() -> void:
	if not Game.has_flag("ch13_in_passage") or Game.has_flag("ch13_out_of_passage"):
		return
	var l := player.global_position - U
	if not Game.has_flag("ch13_chamber_reached") and l.z > 24.6 and l.x > 4.5 and l.x < 19.5:
		Game.set_flag("ch13_chamber_reached")
		c9._talk_group(_cid("c13_chamber"), [_comp()])
		_refresh_prompts()


func _examine(_b: Node, k: String) -> void:
	var seen: Dictionary = st().get("clues", {})
	if seen.get(k, false) or Dialogue.is_busy():
		return
	seen[k] = true
	st()["clues"] = seen
	Dialogue.say("c13_clue_" + k, false, true)
	_refresh_prompts()


func _use_winch(_b: Node) -> void:
	if Game.has_flag("ch13_winch_turned"):
		return
	Game.set_flag("ch13_winch_turned")
	Sfx.play("door_open", UL(WINCH), 0.0, 0.5)
	Dialogue.say("c13_winch", false, true)
	_refresh_prompts()
	_check_entrance()


func _move_beam(_b: Node) -> void:
	if Game.has_flag("ch13_beam_moved") or _busy.get("beam", false):
		return
	if _comp().global_position.distance_to(player.global_position) > 8.0:
		_hint("Too heavy alone. Wait for %s." % companion())
		return
	_busy["beam"] = true
	var tw := create_tween()
	tw.tween_property(beam, "rotation", Vector3.ZERO, 1.0)
	tw.parallel().tween_property(beam, "position", UL(BEAM + Vector3(-2.0, 0.2, -2.0)), 1.0)
	_play("scrape", UL(BEAM), 0.0)
	await tw.finished
	Game.set_flag("ch13_beam_moved")
	_busy["beam"] = false
	_refresh_prompts()
	_check_entrance()


func _check_entrance() -> void:
	if Game.has_flag("ch13_winch_turned") and Game.has_flag("ch13_beam_moved") and not Game.has_flag("ch13_entrance_open"):
		_mist_reacts()


## The doorway opens: stillness, the mist drawn toward it, a deep sound, the flashlight flickers, the companion
## steps back; a vast shape in the dark, gone; then the mist flows out. Control comes back.
func _mist_reacts() -> void:
	if _busy.get("mist", false):
		return
	_busy["mist"] = true
	report["mist_runs"] += 1
	world.save_checkpoint("chapter14_entrance")
	_hold(true)
	Sfx.stop_ambience()
	var tw := create_tween()
	tw.tween_property(doorway_slab, "global_position", UL(DOORWAY + Vector3(0, -4.2, 0)), 3.5).set_trans(Tween.TRANS_SINE)
	_play("scrape", UL(DOORWAY), 4.0)
	await c8._turn_to(UL(DOORWAY), 1.6)
	await tw.finished
	Game.set_flag("ch13_entrance_open")
	var flow: CPUParticles3D = _mist_flow(UL(Vector3(12.0, 1.0, 34.0)), Vector3(0, 0, 1))
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.62, 3.0).set_trans(Tween.TRANS_SINE)
	_play("deep", UL(VOID_SHAPE), 10.0)
	_flashlight_flicker(2.4)
	var k := companion()
	var an = world.animators.get(k)
	if an:
		(c9.follows[k] as VeilCompanionFollow).stop()
		an.walk_to([_comp().global_position + Vector3(0, 0, -1.4)], 0.9)
	await tz.finished
	await c8._turn_to(UL(VOID_SHAPE + Vector3(0, -2.0, 0)), 1.0)
	var vm := void_shape.material_override as StandardMaterial3D
	var ts := create_tween()
	ts.tween_property(vm, "albedo_color:a", 0.75, 1.6)
	ts.tween_interval(1.2)
	ts.tween_property(void_shape, "global_position", UL(VOID_SHAPE + Vector3(9.0, 0, 6.0)), 2.4).set_trans(Tween.TRANS_SINE)
	ts.parallel().tween_property(vm, "albedo_color:a", 0.0, 2.4)
	await ts.finished
	await c9._talk_group(_cid("c13_shadow"), [_comp()])
	flow.queue_free()
	_mist_flow(UL(Vector3(12.0, 1.0, 42.0)), Vector3(0, 0, -1))
	var tb := create_tween()
	tb.tween_property(cam, "fov", fov0, 1.0)
	await tb.finished
	cam.fov = fov0
	report["mist_fov_restored"] = absf(cam.fov - fov0) < 0.01
	Sfx.start_ambience()
	_hold(false)
	_busy["mist"] = false
	_collapse()


func _mist_flow(at: Vector3, dir: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5.0, 1.0, 4.0)
	p.direction = dir
	p.spread = 12.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	var m := QuadMesh.new()
	m.size = Vector2(1.2, 1.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(A + "01_Textures/Horror/T_Hor_GroundMistCorrupted.png")
	mat.albedo_color = Color(0.85, 0.86, 0.9, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.material = mat
	p.mesh = m
	world.add_child(p)
	p.global_position = at
	p.emitting = true
	return p


func _flashlight_flicker(seconds: float) -> void:
	var fl := get_tree().get_first_node_in_group("veil_flashlight")
	var lights: Array = fl.find_children("*", "Light3D", true, false) if fl else []
	if lights.is_empty():
		return
	var e0: Array = lights.map(func(l): return (l as Light3D).light_energy)
	var t := 0.0
	while t < seconds:
		for i in lights.size():
			(lights[i] as Light3D).light_energy = e0[i] * (0.1 if randf() < 0.45 else 1.0)
		await get_tree().create_timer(0.09).timeout
		t += 0.09
	for i in lights.size():
		(lights[i] as Light3D).light_energy = e0[i]


# ------------------------------------------------------------------ scene 7: the collapse, the decision
func _collapse() -> void:
	if Game.has_flag("ch13_collapsed"):
		return
	_hold(true)
	_play("deep", UL(COLLAPSE), 6.0)
	c12._shake(1.4, 0.06)
	await _drop_collapse(false)
	Game.set_flag("ch13_collapsed")
	world.save_checkpoint("chapter14_decision")
	# the companion is caught on the far side of the damaged crawlway; the evidence is by the doorway
	var k := companion()
	(c9.follows[k] as VeilCompanionFollow).stop()
	if _in_view(UL(Vector3(-2.6, 1.0, 30.0))) or _in_view(_comp().global_position + Vector3(0, 1.0, 0)):
		world.npc_walk(k, UL(Vector3(-2.6, 0.05, 30.0)), 3.5)
	else:
		world.place_survivor(_comp(), UL(Vector3(-2.6, 0.05, 30.0)))
	await c9._talk_group(_cid("c13_trapped"), [_comp()])
	_hold(false)
	_refresh_prompts()
	_hint("The way back is gone. Help %s through the damaged passage, or secure the evidence first." % k)
	_decide()


func _in_view(p: Vector3) -> bool:
	var cam: Camera3D = world.get_viewport().get_camera_3d()
	return cam != null and cam.is_position_in_frustum(p) and c12._clear(cam.global_position - Vector3(0, 0.5, 0), p - Vector3(0, 0.5, 0))


func _drop_collapse(instant: bool) -> void:
	collapse_block.visible = true
	collapse_block.collision_layer = 1
	if instant:
		collapse_block.global_position = UL(COLLAPSE)
		return
	var tw := create_tween()
	tw.tween_property(collapse_block, "global_position", UL(COLLAPSE), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	c12._dust()


## The choice itself (mandatory: the panel stays until one is picked).
func _decide() -> void:
	if Game.has_flag("ch13_choice_made") or _busy.get("decide", false):
		return
	_busy["decide"] = true
	report["decision_runs"] += 1
	var k := companion()
	var i: int = -1
	while i < 0 and is_inside_tree():
		i = await p4.choice.ask("The passage is coming down.", ["Help %s through the damaged passage" % k, "Secure the evidence first"], player)
	if i == 0:
		await _help_companion(null)
	else:
		await _take_evidence(null)
	_busy["decide"] = false


func _help_companion(_b: Variant) -> void:
	if Game.has_flag("ch13_choice_made"):
		return
	Game.set_flag("ch13_choice_made")
	Game.set_flag("ch13_choice_help")
	st()["choice"] = "help"
	_hold(true)
	await hud.fade_to(0.85, 0.5)
	# it takes time in the mist: exposure rises; something in the packs is lost in the rubble
	st()["exposure"] = minf(exposure() + 30.0, 95.0)
	for item in ["water_bottle", "canned_food", "energy_snack", "chocolate_bar", "cola_bottle"]:
		if Game.has_item(item):
			Game.remove_item(item)
			st()["lost_item"] = item
			break
	if world.survivors:
		world.survivors.award("ch13_helped", {companion(): 5})
		world.survivors.remember(companion(), "helped_in_collapse")
	world.place_survivor(_comp(), UL(Vector3(1.0, 0.05, 30.0)))
	await get_tree().create_timer(1.2).timeout
	await hud.fade_to(0.0, 0.5)
	_hold(false)
	await c9._talk_group(_cid("c13_helped"), [_comp()])
	c9._start_follow(companion())
	_refresh_prompts()
	_guide()


func _take_evidence(_b: Variant) -> void:
	if Game.has_flag("ch13_choice_made"):
		return
	Game.set_flag("ch13_choice_made")
	Game.set_flag("ch13_choice_evidence")
	st()["choice"] = "evidence"
	_hold(true)
	await c8._turn_to(UL(EVIDENCE), 0.8)
	if not Game.has_item("ancient_rubbing"):
		Game.add_item("ancient_rubbing")
	Sfx.play("pickup", player.global_position, -4.0)
	var ev := world.get_node_or_null("C13_Evidence")
	if ev:
		ev.visible = false
	_play("deep", UL(Vector3(-2.0, 2.0, 30.0)), 4.0)
	await get_tree().create_timer(1.0).timeout
	_hold(false)
	# meanwhile the crawlway gave way on the companion: hurt (not killed), and they saw who came first
	if world.survivors:
		world.survivors.set_health(companion(), "injured")
		world.survivors.award("ch13_evidence_first", {companion(): -10})
		world.survivors.remember(companion(), "left_in_collapse")
	await c9._talk_group(_cid("c13_hurt"), [_comp()])
	c9._start_follow(companion())
	_slow_companion()
	_refresh_prompts()
	_guide()


func _slow_companion() -> void:
	var f: VeilCompanionFollow = c9.follows[companion()]
	f.walk_speed = 1.5
	f.run_speed = 3.4
	var a = world.animators.get(companion())
	if a:
		a.set_mood("scared")


# ------------------------------------------------------------------ scene 8: out, the district in the mist, back
func _use_crawl(_b: Node) -> void:
	if not Game.has_flag("ch13_choice_made") or Game.has_flag("ch13_out_of_passage") or _busy.get("crawl", false):
		return
	_busy["crawl"] = true
	Game.set_flag("ch13_out_of_passage")
	var out := D(DRAIN + Vector3(0.0, 0.15, -1.6))
	await c12._move_through(out, D_YAW + PI, out + Basis(Vector3.UP, D_YAW) * Vector3(1.0, 0.0, 1.0))
	_set_fog(true, 1.0)
	hud.location_caption("THE MIST IS SPREADING", 2.4)
	_busy["crawl"] = false
	_refresh_prompts()
	_guide()
	# the escape: thick fog, Skitter sounds, one or two crossing at a distance (no endless spawning)
	await get_tree().create_timer(4.0).timeout
	if world.expedition and not Game.has_flag("ch13_returned"):
		world.expedition.skitter_crossing(D(Vector3(-16.0, 0.0, 30.0)), D(Vector3(16.0, 0.0, 36.0)))
	await get_tree().create_timer(10.0).timeout
	if world.expedition and not Game.has_flag("ch13_returned"):
		world.expedition.skitter_crossing(D(Vector3(16.0, 0.0, 8.0)), D(Vector3(-16.0, 0.0, 14.0)))


func _escape_tick() -> void:
	if not Game.has_flag("ch13_out_of_passage") or Game.has_flag("ch13_returned"):
		return
	var p := player.global_position
	if randf() < 0.04:
		var a := randf() * TAU
		_play("skitter", p + Vector3(cos(a), 0.5, sin(a)) * 22.0, -8.0)
	if c10.inside_room(player) and not _busy.get("return", false):
		_return_home()


func _return_home() -> void:
	_busy["return"] = true
	Game.set_flag("ch13_returned")
	_set_fog(false)
	for s in skitters:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	skitters.clear()
	var k := companion()
	(c9.follows[k] as VeilCompanionFollow).stop()
	world.npc_walk(k, c10.hl(c10.SPOTS[k]), 1.4)
	world.save_checkpoint("chapter14_return")
	await get_tree().create_timer(1.5).timeout
	if k == "Eddie":
		await c9._talk_group("c13_return", [_node("Ruth"), _node("Eddie")])
	else:
		await c9._talk_group("c13_return_other", [_node("Eddie"), _comp()])
	await c9._talk_group("c13_explain_" + String(st().get("choice", "help")), [_node("Ruth")])
	_busy["return"] = false
	_night()


# ------------------------------------------------------------------ scene 9: late that night, the window
func _night() -> void:
	if Game.has_flag("chapter_13_complete") or _busy.get("night", false):
		return
	_busy["night"] = true
	report["ending_runs"] += 1
	_hold(true)
	await hud.fade_to(1.0, 1.2)
	st()["exposure"] = 0.0
	_apply_exposure(0.0)
	player.global_position = c10.hl(c10.WINDOW + Vector3(0.4, -0.8, 1.3))
	player.velocity = Vector3.ZERO
	var k := companion()
	world.place_survivor(_comp(), c10.hl(c10.WINDOW + Vector3(1.4, -0.89, 2.6)))
	night_light = c12._light(NIGHT_LIGHT, 0.0, 40.0, Color(1.0, 0.85, 0.6))
	var wv: Vector3 = c10.hl(c10.WINDOW) - player.camera.global_position
	player.set_yaw_pitch(atan2(-wv.x, -wv.z) + 0.6, 0.0)
	hud.location_caption("LATE THAT NIGHT", 2.2)
	Sfx.stop_ambience()
	await get_tree().create_timer(1.2).timeout
	await hud.fade_to(0.0, 1.2)
	_play("deep", NIGHT_LIGHT + Vector3(0, -2, 0), 6.0)
	await c8._turn_to(c10.hl(c10.WINDOW) + (c10.hl(c10.WINDOW) - player.camera.global_position).normalized() * 30.0, 2.4)
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	_set_fog(true, 0.4)
	for i in 6:
		night_light.light_energy = 2.4 if i % 2 == 0 else 0.2
		await get_tree().create_timer(0.25).timeout
	var roll: CPUParticles3D = _mist_flow(NIGHT_LIGHT.lerp(c10.hl(c10.WINDOW), 0.5) + Vector3(0, -2.5, 0), (c10.hl(c10.WINDOW) - NIGHT_LIGHT).normalized())
	roll.emission_box_extents = Vector3(14.0, 1.0, 10.0)
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.75, 3.0).set_trans(Tween.TRANS_SINE)
	_play("deep", NIGHT_LIGHT + Vector3(20, 0, -10), 2.0)
	await tz.finished
	_hold(false)
	await c9._talk_group(_cid("c13_night"), [_comp()])
	_hold(true)
	await c8._turn_to(c12.map_prop.global_position if c12.map_prop else c10.hl(Vector3(0.3, 0.6, 6.0)), 1.6)
	Dialogue.say("c13_ready", false, true)
	while Dialogue.is_busy():
		await get_tree().process_frame
	await hud.fade_to(1.0, 1.6)
	cam.fov = fov0
	report["ending_fov_restored"] = absf(cam.fov - fov0) < 0.01
	roll.queue_free()
	_set_fog(false)
	night_light.light_energy = 0.0
	Game.set_flag("chapter_13_complete")             # Chapter 15 is NOT started here
	st()["completed"] = {"roster": group(), "companion": k, "choice": st().get("choice", ""), "evidence": Game.has_item("ancient_rubbing")}
	world.save_checkpoint("chapter14_end")
	await hud.chapter_complete(CHAPTER)
	await hud.title_card("NEXT:  CHAPTER 15  -  THE LAST SHELTER", 2.2)
	Sfx.start_ambience()
	await hud.fade_to(0.0, 1.2)
	_hold(false)
	_busy["night"] = false
	_guide()


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


func _physics_process(delta: float) -> void:
	_crab_tick(delta)


func _process(delta: float) -> void:
	if world == null:
		return
	_skitter_tick(delta)
	_exposure_tick(delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.2
	if its.has("npc_Eddie"):
		var talk: bool = Game.has_flag("ch13_started") and not Game.has_flag("ch13_set_out") and not _busy.get("talk", false) \
			and not _busy.get("prep", false) and not _busy.get("opening", false)
		_set_prompt("npc_Eddie", "[E] Talk" if talk else "")
	_journey_tick()
	# the courtyard: it shows itself once the player is through the gate
	if crab and is_instance_valid(crab) and crab.get_meta("hidden", false) and not _busy.get("crab", false) and not Dialogue.is_busy() \
			and not world.conversing:
		var dl := Basis(Vector3.UP, D_YAW).inverse() * (player.global_position - D_ORIGIN)
		if dl.z > WALL_Z + 3.0 and player.global_position.y > -10.0:
			_crab_reveal()
	_passage_tick()
	_escape_tick()
	if not _busy.get("mist", false) and not _busy.get("night", false) and not _busy.get("crab", false):
		_guide()
