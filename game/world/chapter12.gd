extends Node
class_name VeilChapter12
## THE VEIL - displayed CHAPTER 13 "The Truth Beneath Greyhaven" (internal ids keep the file numbering: chapter12.gd,
## flags ch12_*, chapter_12_complete). Starts right after "The Farm Road" (flag chapter_11_complete), created by
## chapter11.gd. State: story flags + Game.world_state["ch12"].
##
## Back at the mill-worker house (No Safe Road's refuge, before dawn): the symbol on Noah's message is also on an old
## municipal utility map Eddie found (Marcus's lines only if he survived) -> prepare (a supply summary; Eddie comes
## along, the others stay) -> across the road to the old maintenance station (a small public-works block on the
## field south of the road; a flickering streetlight, distant metal sounds) -> inside (the station's own interior,
## built below the field: office, corridor, storage, control room, access chamber): a worker's radio, an inspection
## report, a maintenance log, an old map of the passages -> the main fuse from the storage locker, the control
## room panel: limited power (lights, a sound from below) -> the access door, a ramp down to the service tunnels
## (pipes, drips, mist on the floor, scratches on the walls), a locker (a battery, painkillers) -> the sealed
## chamber: older stonework behind the concrete, the symbol carved again and again, an ancient sealed passage ->
## the records; scratching in the service shaft; a Skitter comes out through the vent grate -> the run back up,
## the access door shut -> the sound from below (first person; nothing shown) -> take the supplies or leave now ->
## back to the mill house -> the map -> "CHAPTER 13 COMPLETE". Chapter 14 is not started.

const STATE := "ch12"
const CHAPTER := 13
const SKITTER_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const HOUND_PATH := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const HOUND_AI := preload("res://game/enemies/hound_ai.gd")
const A := "res://THE_VEIL_ASSETS_V2/"
# ---- the world: the station stands on the field south of the main road, across from the mill-worker house
const STATION := Vector3(-80.0, 0.0, -28.0)           # building centre (x -84..-76, z -31..-25), door on the north face
const STATION_DOOR := Vector3(-80.0, 1.2, -24.85)
const OUTSIDE_SPOT := Vector3(-80.0, 0.15, -23.4)
const ROUTE := [Vector3(-91.4, 0.2, 9.0), Vector3(-88.0, 0.2, 0.0), Vector3(-82.0, 0.2, -12.0), Vector3(-80.0, 0.2, -22.0)]
const STREETLIGHTS := [Vector3(-86.5, 0.0, -5.5), Vector3(-74.5, 0.0, -23.0)]
const HURRY_PROPS := [["09_Horror_Atmosphere/Abandoned_Props/ABN_PersonalBelongings.tscn", Vector3(-84.5, 0.0, -9.0), 0.6],
	["09_Horror_Atmosphere/Abandoned_Props/ABN_FallenBicycle.glb", Vector3(-81.2, 0.0, -16.5), 2.1],
	["09_Horror_Atmosphere/Abandoned_Props/ABN_ScatteredPapers.glb", Vector3(-78.6, 0.0, -21.0), 0.0]]
# ---- the station's interior (facility-local, origin FAC; the upper floor is y 0, the tunnels y -6)
const FAC := Vector3(-80.0, -40.0, -28.0)
const ENTRY := Vector3(0.0, 0.1, 1.5)
const EXIT_DOOR := Vector3(0.0, 1.2, 0.2)
const LOCKER := Vector3(-6.4, 0.0, 12.0)
const PANEL := Vector3(6.55, 0.0, 12.0)
const ACCESS := Vector3(0.0, 1.3, 28.0)
const CABINET := Vector3(2.55, 0.0, 26.2)
const LOW_LOCKER := Vector3(-0.85, -6.0, 48.0)
const SEAL := Vector3(16.0, -4.8, 61.0)
const RECORDS := Vector3(20.0, -6.0, 56.0)
const VENT := Vector3(24.0, -5.5, 64.7)
const SKITTER_DEN := Vector3(25.9, -6.0, 64.7)
const MARKS := Vector3(8.0, -4.6, 59.95)
const CHASE := [Vector3(23.0, -6.0, 64.2), Vector3(19.0, -6.0, 61.0), Vector3(15.0, -6.0, 61.0), Vector3(0.0, -6.0, 61.0),
	Vector3(0.0, -6.0, 40.5), Vector3(0.0, 0.0, 28.4), Vector3(0.0, 0.0, 26.0)]
const EDDIE_RUN := [Vector3(17.0, -6.0, 61.0), Vector3(0.0, -6.0, 61.0), Vector3(0.0, -6.0, 40.5), Vector3(0.0, 0.0, 28.0),
	Vector3(-1.6, 0.0, 24.0)]
const CLUES := {"radio": [Vector3(2.6, 1.0, 2.2), "Examine the Radio"], "report": [Vector3(2.6, 1.0, 3.8), "Read the Inspection Report"],
	"log": [Vector3(-6.3, 1.0, 14.3), "Read the Maintenance Log"], "map": [Vector3(4.0, 1.0, 14.3), "Examine the Old Map"],
	"marks": [MARKS + Vector3(0, 0, 0.3), "Examine the Markings"], "stone": [Vector3(20.0, -4.6, 66.7), "Examine the Stonework"]}
# ---- the mill-worker house (house-local, chapter10.gd): where the map is spread on the floor
const MAP_SPOT := Vector3(0.3, 0.63, 6.0)

var world: Node
var c11: Node
var c10: Node
var c9: Node
var c8: Node
var p4: Node
var player: Node3D
var hud: Node
var fac: Node3D
var its := {}
var lights: Array = []
var low_lights: Array = []
var access_door: Node3D
var seal_door: Node3D
var grate: Node3D
var records_prop: Node3D
var map_prop: Node3D
var skitter: Node3D
var hound: Node3D
var street_lamps: Array = []
var report := {"chase_runs": 0, "hits": 0, "below_runs": 0, "ending_runs": 0, "skitter_max_step": 0.0, "power_runs": 0}
var _busy := {}
var _tick := 0.0
var _route_i := 0
var _chase_i := 0
var _hit_cd := 0.0
var _noise_t := 8.0
var _drip_t := 3.0
var _flicker_t := 0.0
var _streams := {}
var _mats := {}


func begin(w: Node, chapter11: Node, restoring: bool) -> void:
	world = w
	c11 = chapter11
	c10 = c11.c10
	c9 = c11.c9
	c8 = c11.c8
	p4 = c11.p4
	player = w.player
	hud = w.hud
	if not Game.world_state.has(STATE):
		Game.world_state[STATE] = {"roster": group(), "companion": "Eddie", "expedition": "story", "clues": {}}
	_streams["clank"] = Sfx._make(1.1, func(t, i): return (sin(TAU * 410.0 * t) * 0.4 + sin(TAU * 655.0 * t) * 0.3 + Sfx._noise(i) * 0.2) * exp(-t * 5.0))
	_streams["scratch"] = Sfx._make(1.4, func(t, i): return Sfx._noise(i) * 0.5 * (0.5 + 0.5 * sin(TAU * 11.0 * t)) * minf(t * 6.0, 1.0) * minf((1.4 - t) * 5.0, 1.0))
	_streams["below"] = Sfx._make(5.0, func(t, i): return (sin(TAU * 22.0 * t) * 0.7 + sin(TAU * 33.0 * t + sin(t * 2.0)) * 0.45 + Sfx._noise(i) * 0.1) * minf(t * 0.8, 1.0) * exp(-maxf(t - 3.4, 0.0) * 2.0))
	_streams["hum"] = Sfx._make(2.0, func(t, i): return sin(TAU * 60.0 * t) * 0.12 + sin(TAU * 120.0 * t) * 0.05, true)
	_build_exterior()
	_build_facility()
	var it: Interactable = p4.its.get("npc_Eddie")
	if it:
		it.used.connect(_talk)
		its["npc_Eddie"] = it
	var fresh := not Game.has_flag("ch12_started")
	if fresh:
		Game.set_flag("ch12_started")
		_opening.call_deferred()
	else:
		_apply()
		if Game.has_flag("chapter_12_complete"):
			_start_chapter13.call_deferred(true)
	Game.refresh_objective()


func st() -> Dictionary:
	return Game.world_state[STATE]


func L(p: Vector3) -> Vector3:
	return FAC + p


func alive() -> bool:
	return c10.alive()


func group() -> Array:
	return c10.group()


func _node(k: String) -> Node3D:
	return c10._node(k)


## The companion for the story expedition: Eddie (never lost in the story so far); Ruth if he ever is not here.
func companion() -> String:
	var k := String(st().get("companion", "Eddie"))
	return k if k in group() else "Ruth"


func _comp() -> Node3D:
	return _node(companion())


# ------------------------------------------------------------------ building (simple boxes, existing textures)
func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.roughness = 0.95
	match key:
		"concrete":
			m.albedo_texture = load(A + "01_Textures/Architecture/T_Arch_ConcreteFoundation.png")
			m.uv1_scale = Vector3.ONE * 0.4
		"damp":
			m.albedo_texture = load(A + "01_Textures/Horror/T_Hor_DampWall.png")
			m.uv1_scale = Vector3.ONE * 0.35
		"stone":
			m.albedo_texture = load(A + "01_Textures/Architecture/T_Arch_BrickWeatheredBrown.png")
			m.albedo_color = Color(0.62, 0.6, 0.55)
			m.uv1_scale = Vector3.ONE * 0.5
		"grime":
			m.albedo_texture = load(A + "01_Textures/Horror/T_Hor_GrimeAbandoned.png")
			m.uv1_scale = Vector3.ONE * 0.3
		"steel":
			m.albedo_color = Color(0.33, 0.35, 0.34)
			m.metallic = 0.4
			m.roughness = 0.7
		"rust":
			m.albedo_color = Color(0.36, 0.22, 0.15)
			m.roughness = 0.9
		"pipe":
			m.albedo_color = Color(0.28, 0.3, 0.27)
			m.metallic = 0.3
	_mats[key] = m
	return m


## A solid box (mesh + collision on layer 1). `at` is the centre in `frame`-less world space.
func _box(parent: Node3D, n: String, at: Vector3, size: Vector3, mat: String, collide := true, basis := Basis()) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.collision_layer = 1 if collide else 0
	parent.add_child(b)
	b.global_transform = Transform3D(basis, at)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(mat)
	b.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		b.add_child(cs)
	return b


## Wall along x (z = const) from x0 to x1, floor y0, height h (facility-local).
func _wz(z: float, x0: float, x1: float, y0: float, h: float, mat := "concrete") -> void:
	_box(fac, "Wall", L(Vector3((x0 + x1) * 0.5, y0 + h * 0.5, z)), Vector3(absf(x1 - x0), h, 0.3), mat)


func _wx(x: float, z0: float, z1: float, y0: float, h: float, mat := "concrete") -> void:
	_box(fac, "Wall", L(Vector3(x, y0 + h * 0.5, (z0 + z1) * 0.5)), Vector3(0.3, h, absf(z1 - z0)), mat)


func _slab(x0: float, x1: float, z0: float, z1: float, y: float, mat := "concrete") -> void:
	_box(fac, "Slab", L(Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5)), Vector3(x1 - x0, 0.3, z1 - z0), mat)


func _prop(path: String, n: String, at: Vector3, yaw: float, scale := 1.0) -> Node3D:
	var ps := load(A + path) as PackedScene
	if ps == null:
		return null
	var o := ps.instantiate() as Node3D
	o.name = n
	world.add_child(o)
	o.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), at)
	return o


func _light(at: Vector3, energy: float, rng: float, col := Color(1.0, 0.9, 0.75)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	world.add_child(l)
	l.global_position = at
	return l


func _spot(n: String, at: Vector3, size: Vector3, cb: Callable) -> Interactable:
	return c10._spot(n, at, size, cb)


func _set_prompt(k: String, t: String) -> void:
	var it: Interactable = its.get(k)
	if it:
		it.prompt_text = t
		it.collision_layer = 8 if t != "" else 0


## The symbol (Noah's message, the utility map, the carvings): a ring crossed by a stem with two hooked branches.
static func symbol_image(size: int, ink: Color, paper: Color) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(paper)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var p := Vector2(x, y) - c
			var r := p.length() / (size * 0.5)
			var on := absf(r - 0.72) < 0.07
			on = on or (absf(p.x) < size * 0.035 and absf(p.y) < size * 0.42)
			for s in [-1.0, 1.0]:
				var q := p - Vector2(0, -size * 0.12)
				if absf(q.y + s * q.x * 0.9) < size * 0.035 and q.x * s > 0 and q.x * s < size * 0.26:
					on = true
			if on:
				img.set_pixel(x, y, ink)
	return img


func _decal(at: Vector3, normal: Vector3, size: float, ink: Color, paper := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(symbol_image(48, ink, paper))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	world.add_child(mi)
	mi.global_position = at
	if absf(normal.y) > 0.9:
		mi.rotation = Vector3(-PI * 0.5, 0, 0)
	else:
		mi.look_at(at - normal, Vector3.UP)
	return mi


func _build_exterior() -> void:
	var ext := Node3D.new()
	ext.name = "C12_Station"
	world.add_child(ext)
	var s := STATION
	_box(ext, "Block", s + Vector3(0, 1.8, 0), Vector3(8.0, 3.6, 6.0), "grime")
	_box(ext, "Roof", s + Vector3(0, 3.7, 0), Vector3(8.6, 0.25, 6.6), "concrete")
	_box(ext, "Door", STATION_DOOR + Vector3(0, -0.15, -0.06), Vector3(1.1, 2.1, 0.08), "rust", false)
	var sign := Label3D.new()
	sign.text = "GREYHAVEN PUBLIC WORKS\nMAINTENANCE STATION 3"
	sign.font_size = 28
	sign.pixel_size = 0.004
	sign.modulate = Color(0.75, 0.73, 0.65)
	ext.add_child(sign)
	sign.global_transform = Transform3D(Basis(Vector3.UP, PI), STATION_DOOR + Vector3(0, 1.5, -0.12))
	_decal(STATION_DOOR + Vector3(1.4, 0.1, -0.13), Vector3(0, 0, -1), 0.45, Color(0.12, 0.1, 0.09))
	_prop("02_Town/Utilities/UT_Transformer_PadMount.glb", "C12_Transformer", s + Vector3(5.5, 0.0, 1.0), PI * 0.5)
	_prop("02_Town/Utilities/UT_ElectricalCabinet.glb", "C12_Cabinet", s + Vector3(-4.6, 0.0, 2.6), -PI * 0.5)
	for i in STREETLIGHTS.size():
		_prop("02_Town/Street_Props/SP_UtilityPole_Streetlight.glb", "C12_Pole%d" % i, STREETLIGHTS[i], 0.0)
		street_lamps.append(_light(STREETLIGHTS[i] + Vector3(0, 6.5, 0), 1.2, 14.0, Color(1.0, 0.82, 0.6)))
	for h in HURRY_PROPS:
		_prop(h[0], "C12_Left", h[1], h[2])
	its["station"] = _spot("C12_StationDoor", STATION_DOOR, Vector3(1.4, 2.2, 0.5), _enter)


func _build_facility() -> void:
	fac = Node3D.new()
	fac.name = "C12_Facility"
	world.add_child(fac)
	# --- upper floor (y 0..3.2): office, corridor, storage, control room, access chamber
	_slab(-7.5, 7.5, -0.4, 28.4, -0.15)
	_slab(-7.5, 7.5, -0.4, 28.4, 3.35)
	_wz(0.0, -4.0, 4.0, 0.0, 3.2)
	_wx(-4.0, 0.0, 6.0, 0.0, 3.2)
	_wx(4.0, 0.0, 6.0, 0.0, 3.2)
	_wz(6.0, -4.0, -1.0, 0.0, 3.2)
	_wz(6.0, 1.0, 4.0, 0.0, 3.2)
	for side in [-1.0, 1.0]:
		_wx(side, 6.0, 11.0, 0.0, 3.2)
		_wx(side, 12.6, 22.0, 0.0, 3.2)
		_wz(9.0, side, side * 7.0, 0.0, 3.2)
		_wz(15.0, side, side * 7.0, 0.0, 3.2)
		_wx(side * 7.0, 9.0, 15.0, 0.0, 3.2)
		_wz(22.0, side, side * 3.0, 0.0, 3.2)
		_wx(side * 3.0, 22.0, 28.0, 0.0, 3.2)
		_wz(28.0, side, side * 3.0, 0.0, 3.2)
	_box(fac, "ExitDoor", L(EXIT_DOOR + Vector3(0, -0.15, 0.06)), Vector3(1.1, 2.1, 0.08), "rust", false)
	# --- the ramp down (z 28..40, y 0 -> -6)
	_wx(-1.15, 28.0, 40.0, -6.0, 9.2)
	_wx(1.15, 28.0, 40.0, -6.0, 9.2)
	var ang := atan2(6.0, 12.0)
	_box(fac, "Ramp", L(Vector3(0, -3.0 - 0.15 / cos(ang), 34.0)), Vector3(2.2, 0.3, sqrt(180.0)), "concrete", true, Basis(Vector3.RIGHT, ang))
	_slab(-1.3, 1.3, 28.2, 40.2, 3.35)
	_wz(40.0, -1.2, 1.2, -3.4, 6.6)
	# --- the tunnels (y -6..-3.4) and the sealed chamber (y -6..-2.4)
	_slab(-2.0, 28.0, 39.0, 69.0, -6.15, "damp")
	_slab(-1.4, 16.0, 39.8, 62.4, -3.25, "damp")
	_slab(15.8, 24.3, 54.7, 67.3, -2.25, "stone")
	_slab(23.8, 27.3, 63.4, 66.0, -4.85, "damp")
	_wx(-1.2, 40.0, 62.2, -6.0, 2.6, "damp")
	_wx(1.2, 40.0, 59.8, -6.0, 2.6, "damp")
	_wz(62.2, -1.2, 16.0, -6.0, 2.6, "damp")
	_wz(59.8, 1.2, 16.0, -6.0, 2.6, "damp")
	_wx(16.0, 55.0, 59.8, -6.0, 3.6, "stone")
	_wx(16.0, 62.2, 67.0, -6.0, 3.6, "stone")
	_box(fac, "SealTop", L(Vector3(16.0, -2.95, 61.0)), Vector3(0.3, 0.9, 2.4), "stone")
	_wx(24.0, 55.0, 64.0, -6.0, 3.6, "stone")
	_wx(24.0, 65.4, 67.0, -6.0, 3.6, "stone")
	_box(fac, "VentTop", L(Vector3(24.0, -3.7, 64.7)), Vector3(0.3, 2.6, 1.4), "stone")
	_wz(55.0, 16.0, 24.0, -6.0, 3.6, "stone")
	_wz(67.0, 16.0, 24.0, -6.0, 3.6, "stone")
	_wz(63.6, 24.0, 27.0, -6.0, 1.0, "damp")
	_wz(65.8, 24.0, 27.0, -6.0, 1.0, "damp")
	_wx(27.0, 63.6, 65.8, -6.0, 1.0, "damp")
	# the modern concrete stops short of the old stone: a cast collar around the chamber's walls
	_box(fac, "Collar", L(Vector3(20.0, -2.6, 55.3)), Vector3(8.0, 0.5, 0.4), "concrete")
	_box(fac, "Collar2", L(Vector3(20.0, -2.6, 66.7)), Vector3(8.0, 0.5, 0.4), "concrete")
	# the ancient sealed passage: a stone slab set into the far wall, the symbol cut into it
	_box(fac, "AncientSeal", L(Vector3(20.0, -4.4, 66.75)), Vector3(2.4, 3.2, 0.3), "stone")
	for i in 5:
		_decal(L(Vector3(17.2 + i * 1.6, -3.4 - (i % 2) * 0.9, 55.17)), Vector3(0, 0, 1), 0.5, Color(0.08, 0.07, 0.06, 1))
	_decal(L(Vector3(20.0, -4.0, 66.58)), Vector3(0, 0, -1), 1.3, Color(0.06, 0.05, 0.05, 1))
	_decal(L(Vector3(23.83, -3.6, 59.0)), Vector3(-1, 0, 0), 0.7, Color(0.08, 0.07, 0.06, 1))
	# pipes along the tunnels
	_box(fac, "PipeA", L(Vector3(0.95, -3.75, 51.0)), Vector3(0.18, 0.18, 22.0), "pipe", false)
	_box(fac, "PipeA2", L(Vector3(-0.95, -3.9, 51.0)), Vector3(0.12, 0.12, 22.0), "rust", false)
	_box(fac, "PipeB", L(Vector3(8.6, -3.75, 61.95)), Vector3(14.6, 0.18, 0.18), "pipe", false)
	# low mist on the tunnel floors (cheap transparent quads)
	var mist := StandardMaterial3D.new()
	mist.albedo_texture = load(A + "01_Textures/Horror/T_Hor_GroundMistCorrupted.png")
	mist.albedo_color = Color(0.8, 0.82, 0.85, 0.35)
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.cull_mode = BaseMaterial3D.CULL_DISABLED
	for m in [[Vector3(0, -5.7, 51.0), Vector2(2.3, 22.0)], [Vector3(8.6, -5.7, 61.0), Vector2(14.6, 2.3)], [Vector3(20.0, -5.6, 61.0), Vector2(7.8, 11.8)]]:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = m[1]
		mi.mesh = pm
		mi.material_override = mist
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fac.add_child(mi)
		mi.global_position = L(m[0])
	# doors and moving parts
	access_door = _box(fac, "AccessDoor", L(Vector3(0.0, 1.3, 28.0)), Vector3(2.0, 2.6, 0.22), "steel")
	seal_door = _box(fac, "SealDoor", L(Vector3(16.0, -4.8, 61.0)), Vector3(0.22, 2.4, 2.4), "rust")
	grate = _box(fac, "Grate", L(Vector3(24.0, -5.5, 64.7)), Vector3(0.08, 1.0, 1.4), "steel")
	# furniture and clues (existing props)
	_prop("04_Commercial/Shared_Props/COM_ReceptionDesk.glb", "C12_Desk", L(Vector3(3.0, 0.0, 3.0)), -PI * 0.5)
	_prop("04_Commercial/Shared_Props/COM_FilingCabinet.glb", "C12_Filing", L(Vector3(-3.4, 0.0, 5.3)), PI * 0.5)
	_prop("04_Commercial/Shared_Props/COM_PalletRack.glb", "C12_Rack", L(Vector3(-4.0, 0.0, 14.3)), 0.0)
	_prop("04_Commercial/Shared_Props/COM_DocumentBoxes.glb", "C12_Boxes", L(Vector3(-6.2, 0.0, 9.8)), 0.0)
	_prop("03_Residential/Interactive_Props/RES_IP_StorageChest.glb", "C12_Locker", L(LOCKER), PI * 0.5)
	_prop("02_Town/Utilities/UT_ElectricalCabinet.glb", "C12_Panel", L(PANEL), -PI * 0.5)
	_prop("09_Horror_Atmosphere/Abandoned_Props/ABN_BrokenElectricalBox.tscn", "C12_Broken", L(Vector3(6.6, 0.0, 9.8)), -PI * 0.5)
	_prop("04_Commercial/Shared_Props/COM_ReadingTable.glb", "C12_MapTable", L(Vector3(4.0, 0.0, 14.0)), 0.0)
	_prop("03_Residential/Interactive_Props/RES_IP_CabinetDoorUnit.glb", "C12_SupplyCabinet", L(CABINET), -PI * 0.5)
	_prop("03_Residential/Interactive_Props/RES_IP_StorageChest.glb", "C12_LowLocker", L(LOW_LOCKER), PI * 0.5)
	_prop("04_Commercial/Shared_Props/COM_DocumentBoxes.glb", "C12_Records", L(RECORDS), 0.0)
	records_prop = world.get_node_or_null("C12_Records")
	_prop("09_Horror_Atmosphere/Supernatural_Details/SUP_Markings_Wall.glb", "C12_Marks", L(MARKS), 0.0)
	_prop("09_Horror_Atmosphere/Abandoned_Props/ABN_ScatteredPapers.glb", "C12_Papers", L(Vector3(-1.6, 0.0, 2.6)), 0.4)
	_decal(L(Vector3(4.0, 0.93, 14.0)), Vector3.UP, 0.35, Color(0.15, 0.1, 0.08, 1), Color(0.78, 0.74, 0.62, 1))
	# lights: a dim emergency lamp in the office until the power is back
	lights.append(_light(L(Vector3(0.0, 2.8, 3.0)), 0.35, 7.0, Color(1.0, 0.35, 0.25)))
	for p in [Vector3(0, 2.8, 2.0), Vector3(0, 2.8, 14.0), Vector3(-4.0, 2.8, 12.0), Vector3(4.0, 2.8, 12.0), Vector3(0, 2.8, 25.0)]:
		lights.append(_light(L(p), 0.0, 8.0))
	for p in [Vector3(0, -3.8, 34.0), Vector3(0, -3.8, 46.0), Vector3(0, -3.8, 56.0), Vector3(8.0, -3.8, 61.0), Vector3(20.0, -3.0, 61.0)]:
		low_lights.append(_light(L(p), 0.0, 9.0, Color(0.85, 0.9, 1.0)))
	# interactions
	its["exit"] = _spot("C12_Exit", L(EXIT_DOOR + Vector3(0, 0, 0.3)), Vector3(1.4, 2.2, 0.5), _leave)
	its["locker"] = _spot("C12_LockerUse", L(LOCKER + Vector3(0.3, 0.6, 0)), Vector3(0.9, 1.2, 1.4), _search_locker)
	its["panel"] = _spot("C12_PanelUse", L(PANEL + Vector3(-0.3, 1.1, 0)), Vector3(0.6, 1.6, 1.2), _use_panel)
	its["access"] = _spot("C12_AccessUse", L(Vector3(0.0, 1.3, 27.6)), Vector3(2.0, 2.4, 0.6), _use_access)
	its["low_locker"] = _spot("C12_LowLockerUse", L(LOW_LOCKER + Vector3(0.3, 0.6, 0)), Vector3(0.9, 1.2, 1.4), _search_low_locker)
	its["seal"] = _spot("C12_SealUse", L(SEAL + Vector3(-0.3, 0, 0)), Vector3(0.6, 2.4, 2.4), _force_seal)
	its["records"] = _spot("C12_RecordsUse", L(RECORDS + Vector3(0, 0.6, 0)), Vector3(1.2, 1.2, 1.2), _take_records)
	for k in CLUES:
		its["clue_" + k] = _spot("C12_Clue_" + k, L(CLUES[k][0]), Vector3(0.9, 0.9, 0.9), _examine.bind(k))
	_hum_player = AudioStreamPlayer3D.new()
	_hum_player.stream = _streams["hum"]
	_hum_player.volume_db = -14.0
	world.add_child(_hum_player)
	_hum_player.global_position = L(PANEL + Vector3(-0.5, 1.2, 0))


var _hum_player: AudioStreamPlayer3D


# ------------------------------------------------------------------ state from flags (fresh start and loads)
func _apply() -> void:
	_node("Marcus").visible = alive()
	if Game.has_flag("ch13_started"):
		_set_power(Game.has_flag("ch12_power_on"), true)
		if records_prop and Game.has_flag("ch12_records_taken"):
			records_prop.visible = false
		_place_map()
		_refresh_prompts()
		return                                       # the next chapter places the group from here on
	var power := Game.has_flag("ch12_power_on")
	_set_power(power, true)
	var open_access := Game.has_flag("ch12_access_open") and not Game.has_flag("ch12_door_secured")
	access_door.position = L(Vector3(0.0, 1.3 + (2.5 if open_access else 0.0), 28.0))
	if Game.has_flag("ch12_chamber_open"):
		seal_door.position = L(Vector3(16.0, -4.8, 63.4))
	if Game.has_flag("ch12_chase_started") and is_instance_valid(grate):
		grate.queue_free()
	if records_prop and Game.has_flag("ch12_records_taken"):
		records_prop.visible = false
	var out := Game.has_flag("ch12_set_out") and not Game.has_flag("ch12_returned")
	if out:
		var k := companion()
		c9._start_follow(k)
		for other in group():
			if other != k:
				_stay_inside(other)
		_rejoin.call_deferred(k)
	else:
		c10._place_inside()
	if Game.has_flag("ch12_chase_started") and not Game.has_flag("ch12_door_secured"):
		_start_chase(true)                             # a load mid-escape: it is back down the tunnel
	if Game.has_flag("ch12_supplies_taken") and Game.has_flag("ch12_left_station") and not Game.has_flag("ch12_returned"):
		_spawn_prowler()
	if Game.has_flag("chapter_12_complete"):
		_place_map()
	_refresh_prompts()
	_guide()


## A load during the trip (the screen is still black): the companion stands just behind the player again.
func _rejoin(k: String) -> void:
	var f: VeilCompanionFollow = c9.follows[k]
	f.stop()
	for i in 3:                                      # after the world has put the player back where the save says
		await get_tree().physics_frame
	var back: Vector3 = player.global_transform.basis.z * Vector3(1, 0, 1)
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var placed := false
	for d in [1.6, 1.0]:
		for i in 8:
			if not placed and world.place_survivor(_node(k), player.global_position + back.rotated(Vector3.UP, i * PI * 0.25) * d):
				placed = true
	f.start()


func _stay_inside(k: String) -> void:
	var n := _node(k)
	(c9.follows[k] as VeilCompanionFollow).stop()
	c9.c5._reparent(n, world)
	n.visible = true
	world.place_survivor(n, c10.hl(c10.SPOTS[k]))


func _refresh_prompts() -> void:
	if its.has("npc_Eddie"):
		var talk: bool = Game.has_flag("ch12_started") and not Game.has_flag("ch12_set_out") and companion() == "Eddie"
		_set_prompt("npc_Eddie", "[E] Talk" if talk else "")
	var out := Game.has_flag("ch12_set_out") and not Game.has_flag("ch12_left_station")
	_set_prompt("station", "[E] Enter the Maintenance Station" if out else "")
	_set_prompt("exit", "[E] Leave the Station" if Game.has_flag("ch12_station_reached") and not Game.has_flag("ch12_left_station") else "")
	_set_prompt("locker", "[E] Search the Locker" if Game.has_flag("ch12_station_reached") and not Game.has_flag("ch12_fuse_found") else "")
	_set_prompt("panel", "[E] Check the Power Panel" if Game.has_flag("ch12_station_reached") and not Game.has_flag("ch12_power_on") else "")
	var acc := ""
	if Game.has_flag("ch12_station_reached") and not Game.has_flag("ch12_access_open"):
		acc = "[E] Open the Access Door"
	elif Game.has_flag("ch12_chase_started") and not Game.has_flag("ch12_door_secured"):
		acc = "[E] SHUT THE ACCESS DOOR"
	_set_prompt("access", acc)
	_set_prompt("low_locker", "[E] Search the Locker" if Game.has_flag("ch12_descended") and not Game.has_flag("ch12_low_locker") else "")
	_set_prompt("seal", "[E] Force the Rusted Door" if Game.has_flag("ch12_descended") and not Game.has_flag("ch12_chamber_open") else "")
	_set_prompt("records", "[E] Take the Records" if Game.has_flag("ch12_chamber_open") and not Game.has_flag("ch12_records_taken") else "")
	var seen: Dictionary = st().get("clues", {})
	for k in CLUES:
		var on: bool = Game.has_flag("ch12_station_reached") and not seen.get(k, false)
		if k in ["marks", "stone"]:
			on = on and Game.has_flag("ch12_descended") and not (Game.has_flag("ch12_chase_started") and not Game.has_flag("ch12_door_secured"))
		_set_prompt("clue_" + k, ("[E] " + String(CLUES[k][1])) if on else "")


func _guide() -> void:
	if chapter13 != null:
		return
	var t: Variant = null
	var label := ""
	var p := player.global_position
	if not Game.has_flag("ch12_talk_done"):
		t = _node("Eddie")
		label = "EDDIE"
	elif not Game.has_flag("ch12_set_out"):
		t = _node("Eddie")
		label = "GET READY"
	elif not Game.has_flag("ch12_station_reached"):
		while _route_i < ROUTE.size() - 1 and Vector2(p.x - ROUTE[_route_i].x, p.z - ROUTE[_route_i].z).length() < 4.0:
			_route_i += 1
		t = (ROUTE[_route_i] if _route_i < ROUTE.size() - 1 else STATION_DOOR) + Vector3(0, 1.2, 0)
		label = "MAINTENANCE STATION"
	elif not Game.has_flag("ch12_fuse_found"):
		t = L(LOCKER + Vector3(0, 1.0, 0))
		label = "STORAGE"
	elif not Game.has_flag("ch12_power_on"):
		t = L(PANEL + Vector3(0, 1.2, 0))
		label = "CONTROL ROOM"
	elif not Game.has_flag("ch12_descended"):
		t = L(ACCESS)
		label = "ACCESS DOOR"
	elif not Game.has_flag("ch12_chamber_open"):
		t = L(SEAL)
		label = "TUNNELS"
	elif not Game.has_flag("ch12_records_taken"):
		t = L(RECORDS + Vector3(0, 0.8, 0))
		label = "RECORDS"
	elif not Game.has_flag("ch12_door_secured"):
		t = L(ACCESS) if not _busy.get("records", false) else null
		label = "GET OUT"
	elif not Game.has_flag("ch12_left_station"):
		t = L(EXIT_DOOR) if Game.has_flag("ch12_supply_choice") else null
		label = "EXIT"
	elif not Game.has_flag("ch12_returned"):
		t = c10.hl(c10.PORCH) + Vector3(0, 1.4, 0)
		label = "MILL HOUSE"
	if hud.has_method("set_marker"):
		hud.set_marker(t, label)


# ------------------------------------------------------------------ scene 1: the symbol (the mill-worker house)
func _opening() -> void:
	_busy["opening"] = true
	_hold(true)
	await hud.fade_to(1.0, 1.0)
	# the group walked back to the refuge in the dark (the screen is black while everyone is put in the room)
	c10._place_inside()
	_node("Marcus").visible = alive()
	player.global_position = c10.hl(Vector3(0.6, 0.7, 5.2))
	player.velocity = Vector3.ZERO
	var v: Vector3 = _node("Eddie").global_position - player.global_position
	player.set_yaw_pitch(atan2(-v.x, -v.z), 0.0)
	hud.location_caption("THE MILL HOUSE  -  BEFORE DAWN", 2.2)
	await get_tree().create_timer(1.2).timeout
	await hud.fade_to(0.0, 1.2)
	_hold(false)
	_busy["opening"] = false
	_apply()
	world.save_checkpoint("chapter13_start")            # its own file, never the player's save slot
	await hud.chapter_start(CHAPTER)
	if not Game.has_flag("ch12_talk_done"):
		_hint("Eddie has something to show you.")


func _talk(_b: Node) -> void:
	if not Game.has_flag("ch12_started") or _busy.get("talk", false) or _busy.get("opening", false):
		return
	if Game.has_flag("ch12_talk_done"):
		if not Game.has_flag("ch12_set_out"):
			_prepare()
		return
	_busy["talk"] = true
	if not Game.has_item("utility_map"):
		Game.add_item("utility_map")
	var npcs: Array = [_node("Eddie"), _node("Ruth")]
	await c9._talk_group("c12_symbol", npcs)
	if alive():
		await c9._talk_group("c12_symbol_marcus", [_node("Marcus"), _node("Eddie")])
	Game.set_flag("ch12_talk_done")
	_busy["talk"] = false
	_guide()
	_prepare()


## Before leaving: what the player is carrying (a check, not a requirement), then set out with the companion.
func _prepare() -> void:
	if _busy.get("prep", false) or Game.has_flag("ch12_set_out"):
		return
	_busy["prep"] = true
	var fl := get_tree().get_first_node_in_group("veil_flashlight")
	var spares: int = int(fl.get("spares")) if fl else 0
	var food := 0
	var water := 0
	for id in Game.inventory:
		var r := Game.shelter_resource(id)
		food += 1 if r == "food" else 0
		water += 1 if r == "water" else 0
	var text := "BEFORE YOU GO  -  dark rooms, maybe tunnels, a long walk back\nFlashlight spares %d    Painkillers %d    Food %d    Water %d    Items carried %d" % [
		spares, Game.inventory.count("painkillers"), food, water, Game.inventory.size()]
	var k := companion()
	var i: int = await p4.choice.ask(text, ["Set out with %s" % k, "Check my things first (talk to %s when ready)" % k], player)
	_busy["prep"] = false
	if i != 0:
		if hud.has_method("toggle_inventory") and not hud.inv_panel.visible:
			hud.toggle_inventory()
		return
	Game.set_flag("ch12_set_out")
	st()["expedition"] = "story"
	c9._start_follow(k)
	Dialogue.say("c12_setout", false, true)
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ scene 2: the station
func _enter(_b: Node) -> void:
	if not Game.has_flag("ch12_set_out") or Game.has_flag("ch12_left_station") or _busy.get("door", false):
		return
	var c := _comp()
	if c.global_position.distance_to(player.global_position) > 14.0:
		_hint("Wait for %s." % companion())
		return
	_busy["door"] = true
	Sfx.play("door_open", STATION_DOOR, -4.0, 0.7)
	await _move_through(L(ENTRY), PI, L(Vector3(0.9, 0.05, 0.9)))
	_busy["door"] = false
	if not Game.has_flag("ch12_station_reached"):
		Game.set_flag("ch12_station_reached")
		world.save_checkpoint("chapter13_facility")
		await c9._talk_group("c12_inside", [c])
	_refresh_prompts()
	_guide()


func _leave(_b: Node) -> void:
	if not Game.has_flag("ch12_station_reached") or Game.has_flag("ch12_left_station") or _busy.get("door", false):
		return
	if Game.has_flag("ch12_records_taken") and not Game.has_flag("ch12_supply_choice"):
		return
	if Game.has_flag("ch12_records_taken"):
		Game.set_flag("ch12_left_station")
	_busy["door"] = true
	await _move_through(OUTSIDE_SPOT, 0.0, OUTSIDE_SPOT + Vector3(0.9, 0.0, 1.2))
	_busy["door"] = false
	if Game.has_flag("ch12_left_station") and Game.has_flag("ch12_supplies_taken"):
		_spawn_prowler()
	_refresh_prompts()
	_guide()


## Through a door that leads somewhere else: the screen dips to black, the player and the companion are moved while
## nothing can be seen, then it fades back in.
func _move_through(to: Vector3, yaw: float, comp_at: Vector3) -> void:
	_hold(true)
	await hud.fade_to(1.0, 0.5)
	player.global_position = to
	player.velocity = Vector3.ZERO
	player.set_yaw_pitch(yaw, 0.0)
	var k := companion()
	var f: VeilCompanionFollow = c9.follows[k]
	f.stop()
	world.place_survivor(_comp(), comp_at)
	f.start()
	await get_tree().create_timer(0.3).timeout
	await hud.fade_to(0.0, 0.6)
	_hold(false)


func _examine(_b: Node, k: String) -> void:
	var seen: Dictionary = st().get("clues", {})
	if seen.get(k, false) or Dialogue.is_busy():
		return
	seen[k] = true
	st()["clues"] = seen
	if k == "log" and not Game.has_item("maintenance_log"):
		Game.add_item("maintenance_log")
		Sfx.play("pickup", player.global_position, -8.0)
	if k == "marks":
		await c9._talk_group("c12_scratches", [_comp()])
	else:
		Dialogue.say("c12_clue_" + k, false, true)
	_refresh_prompts()


func _search_locker(_b: Node) -> void:
	if Game.has_flag("ch12_fuse_found"):
		return
	Game.add_item("station_fuse")
	Sfx.play("pickup", player.global_position, -6.0)
	Game.set_flag("ch12_fuse_found")
	Dialogue.say("c12_fuse", false, true)
	_refresh_prompts()
	_guide()


func _use_panel(_b: Node) -> void:
	if Game.has_flag("ch12_power_on") or _busy.get("power", false):
		return
	if not Game.has_item("station_fuse"):
		Dialogue.say("c12_panel_nofuse", false, true)
		return
	_busy["power"] = true
	report["power_runs"] += 1
	Game.remove_item("station_fuse")
	Game.set_flag("ch12_power_on")
	# the lights flicker on; a deep sound from below; the building shakes; the companion reacts
	_hold(true)
	_set_power(true, false)
	await get_tree().create_timer(1.2).timeout
	_play("below", L(Vector3(8.0, -8.0, 50.0)), 4.0)
	await _shake(1.6, 0.05)
	await c9._talk_group("c12_power", [_comp()])
	_hold(false)
	_busy["power"] = false
	_refresh_prompts()
	_guide()


func _set_power(on: bool, instant: bool) -> void:
	if instant:
		for i in lights.size():
			(lights[i] as OmniLight3D).light_energy = (1.1 if i > 0 else 0.35) if on else (0.35 if i == 0 else 0.0)
		for l in low_lights:
			(l as OmniLight3D).light_energy = 0.55 if on else 0.0
		if on and not _hum_player.playing:
			_hum_player.play()
		return
	_hum_player.play()
	for k in 6:
		for i in lights.size():
			(lights[i] as OmniLight3D).light_energy = (1.1 if k % 2 == 1 else 0.15) if i > 0 else 0.35
		await get_tree().create_timer(0.12 + 0.05 * k).timeout
	_set_power(true, true)


func _use_access(_b: Node) -> void:
	if Game.has_flag("ch12_chase_started") and not Game.has_flag("ch12_door_secured"):
		_secure_door()
		return
	if Game.has_flag("ch12_access_open") or _busy.get("access", false):
		return
	if not Game.has_flag("ch12_power_on"):
		Dialogue.say("c12_access_locked", false, true)
		return
	_busy["access"] = true
	Game.set_flag("ch12_access_open")
	Sfx.play("door_open", L(ACCESS), -2.0, 0.5)
	var tw := create_tween()
	tw.tween_property(access_door, "position:y", L(ACCESS).y + 2.5, 2.2).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_busy["access"] = false
	_refresh_prompts()
	_guide()


func _search_low_locker(_b: Node) -> void:
	if Game.has_flag("ch12_low_locker"):
		return
	Game.set_flag("ch12_low_locker")
	Game.add_item("batteries")
	Game.add_item("painkillers")
	Sfx.play("pickup", player.global_position, -6.0)
	Dialogue.say("c12_low_locker", false, true)
	_refresh_prompts()


func _force_seal(_b: Node) -> void:
	if Game.has_flag("ch12_chamber_open") or _busy.get("seal", false):
		return
	var c := _comp()
	if c.global_position.distance_to(player.global_position) > 8.0:
		_hint("It won't move alone. Wait for %s." % companion())
		return
	_busy["seal"] = true
	_hold(true)
	Sfx.play("door_open", L(SEAL), 0.0, 0.4)
	var tw := create_tween()
	tw.tween_property(seal_door, "position:z", L(SEAL).z + 2.4, 2.4).set_trans(Tween.TRANS_SINE)
	await tw.finished
	Game.set_flag("ch12_chamber_open")
	world.save_checkpoint("chapter13_underground")
	_hold(false)
	_busy["seal"] = false
	await c9._talk_group("c12_chamber", [c])
	_refresh_prompts()
	_guide()


# ------------------------------------------------------------------ scene 3: the records, the Skitter
func _take_records(_b: Node) -> void:
	if Game.has_flag("ch12_records_taken") or _busy.get("records", false):
		return
	_busy["records"] = true
	_hold(true)
	# scratching in the shaft, movement behind the grate; "not yet"
	_play("scratch", L(VENT), 2.0)
	await c8._turn_to(L(VENT), 1.0)
	_shake_grate()
	await c9._talk_group("c12_not_yet", [_comp()])
	await c8._turn_to(L(RECORDS + Vector3(0, 0.6, 0)), 0.6)
	if not Game.has_item("underground_records"):
		Game.add_item("underground_records")
	if records_prop:
		records_prop.visible = false
	Sfx.play("pickup", player.global_position, -4.0)
	Game.set_flag("ch12_records_taken")
	# it comes out through the vent (the grate falls), the companion shouts, control is back
	_start_chase(false)
	await get_tree().create_timer(0.5).timeout
	Dialogue.say("c12_move", false, true)
	_hold(false)
	_busy["records"] = false
	_refresh_prompts()
	_guide()


func _shake_grate() -> void:
	if not is_instance_valid(grate):
		return
	var x0 := grate.position.x
	var tw := create_tween()
	for i in 6:
		tw.tween_property(grate, "position:x", x0 + (0.04 if i % 2 == 0 else -0.03), 0.08)
	tw.tween_property(grate, "position:x", x0, 0.08)


func _start_chase(restoring: bool) -> void:
	if skitter != null:
		return
	report["chase_runs"] += 1
	Game.set_flag("ch12_chase_started")
	var ps := load(SKITTER_PATH) as PackedScene
	skitter = ps.instantiate() as Node3D
	skitter.name = "C12_Skitter"
	world.add_child(skitter)
	if skitter is CollisionObject3D:
		(skitter as CollisionObject3D).collision_layer = 0
		(skitter as CollisionObject3D).collision_mask = 0
	skitter.set_physics_process(false)
	var start: Vector3 = L(SKITTER_DEN) if not restoring else L(CHASE[2])
	skitter.global_position = start
	VeilCreatureLook.apply_skitter(skitter, start.y)
	_chase_i = 0 if not restoring else 2
	_skitter_prev = start
	VeilCreatureLook.skitter_anim(skitter, "scuttle", 3.7)
	if not restoring:
		_emerging = 1.2                              # out through the vent: the grate falls first
		if is_instance_valid(grate):
			var tw := create_tween()
			tw.tween_property(grate, "rotation:z", -PI * 0.5, 0.35)
			tw.parallel().tween_property(grate, "position", L(Vector3(23.5, -5.95, 64.7)), 0.35)
			Sfx.play("door_close", L(VENT), 2.0, 1.4)
	# the companion runs for the stairs (ahead of the player)
	var k := companion()
	(c9.follows[k] as VeilCompanionFollow).stop()
	var an = world.animators.get(k)
	if an and not restoring:
		an.walk_to(EDDIE_RUN.map(func(p): return L(p)), 4.6)
	elif restoring:
		c9._start_follow(k)
	_refresh_prompts()


var _emerging := 0.0
var _skitter_prev := Vector3.ZERO


func _chase_tick(delta: float) -> void:
	if skitter == null or not is_instance_valid(skitter):
		return
	if _emerging > 0.0:
		_emerging -= delta
		return
	_hit_cd -= delta
	var pp := player.global_position
	var sp := skitter.global_position
	var speed := 3.7 if _hit_cd <= 0.0 else 0.6
	var target: Vector3
	# along the tunnel chain until it shares the player's stretch, then straight at them
	var see := sp.distance_to(pp) < 7.0 and absf(sp.y - pp.y) < 1.5 and _clear(sp, pp)
	if see or _chase_i >= CHASE.size():
		target = pp
	else:
		target = L(CHASE[_chase_i])
		if Vector2(sp.x - target.x, sp.z - target.z).length() < 0.4:
			_chase_i += 1
			return
	var d := target - sp
	var step := minf(speed * delta, d.length())
	var nxt := sp + d.normalized() * step
	if not see:
		nxt.y = sp.y + (target.y - sp.y) * (step / maxf(d.length(), 0.001))
	else:
		nxt.y = _floor_below(nxt, sp.y)
	skitter.global_position = nxt
	if d.length() > 0.05:
		skitter.rotation.y = atan2(d.x, d.z)
	report["skitter_max_step"] = maxf(float(report["skitter_max_step"]), nxt.distance_to(_skitter_prev) / maxf(delta * 60.0, 1.0))
	_skitter_prev = nxt
	# the chain point it has already passed (while chasing in plain view) is not walked back to
	while _chase_i < CHASE.size() - 1 and (L(CHASE[_chase_i]).distance_to(nxt) < 1.0
			or L(CHASE[_chase_i + 1]).distance_to(nxt) < L(CHASE[_chase_i]).distance_to(L(CHASE[_chase_i + 1]))):
		_chase_i += 1
	if sp.distance_to(pp) < 1.3 and _hit_cd <= 0.0:
		_hit_cd = 1.6
		report["hits"] += 1
		player.damage(12.0, sp)


func _clear(a: Vector3, b: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 0.5, 0), b + Vector3(0, 0.5, 0), 1, [player.get_rid()])
	return space.intersect_ray(q).is_empty()


func _floor_below(p: Vector3, fallback: float) -> float:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p - Vector3(0, 2.0, 0), 1))
	return (hit["position"] as Vector3).y if hit else fallback


func _secure_door() -> void:
	if Game.has_flag("ch12_door_secured") or _busy.get("secure", false):
		return
	var lp := player.global_position - FAC
	if lp.z > 27.6 or lp.y < -0.5:
		_hint("Get through the door first!")
		return
	var c := _comp()
	if (c.global_position - FAC).z > 27.6:
		_hint("Wait for %s!" % companion())
		return
	_busy["secure"] = true
	var tw := create_tween()
	tw.tween_property(access_door, "position:y", L(ACCESS).y, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Sfx.play("door_close", L(ACCESS), 6.0, 0.6)
	Game.set_flag("ch12_door_secured")
	if skitter and is_instance_valid(skitter):
		skitter.queue_free()                         # behind the shut steel door, out of sight
	skitter = null
	_busy["secure"] = false
	_refresh_prompts()
	_sound_below()


## The quiet, then something enormous moves far below (first person; nothing is shown).
func _sound_below() -> void:
	report["below_runs"] += 1
	_hold(true)
	var k := companion()
	var an = world.animators.get(k)
	if an:
		an.walk_to([])
	Sfx.stop_ambience()
	_hum_player.stop()
	await get_tree().create_timer(2.2).timeout
	_play("below", L(Vector3(0.0, -14.0, 40.0)), 8.0)
	_dust()
	_shake(3.0, 0.035)
	await c8._turn_to(L(Vector3(0.0, 1.3, 28.0)), 3.0)
	await get_tree().create_timer(0.4).timeout
	await c9._talk_group("c12_below", [_comp()])
	Sfx.start_ambience()
	_hum_player.play()
	world.save_checkpoint("chapter13_escaped")
	_hold(false)
	_supply_choice()


func _dust() -> void:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(2.5, 0.05, 3.0)
	p.gravity = Vector3(0, -1.2, 0)
	var m := QuadMesh.new()
	m.size = Vector2(0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.68, 0.62)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.material = mat
	p.mesh = m
	world.add_child(p)
	p.global_position = L(Vector3(0.0, 3.1, 25.0))
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)


func _shake(seconds: float, amp: float) -> void:
	var cam: Camera3D = player.camera
	var t := 0.0
	while t < seconds:
		cam.h_offset = randf_range(-amp, amp)
		cam.v_offset = randf_range(-amp, amp)
		await get_tree().process_frame
		t += get_process_delta_time()
	cam.h_offset = 0.0
	cam.v_offset = 0.0


# ------------------------------------------------------------------ scene 4: take the supplies or leave now
func _supply_choice() -> void:
	if Game.has_flag("ch12_supply_choice") or _busy.get("choice", false):
		return
	_busy["choice"] = true
	await c8._turn_to(L(CABINET + Vector3(0, 1.0, 0)), 0.8)
	var i: int = await p4.choice.ask("An equipment cabinet, still shut. Dust is still falling.", ["Take the supplies (it will take a minute)", "Leave now"], player)
	if i == 0:
		_hold(true)
		await hud.fade_to(0.85, 0.5)
		for item in ["batteries", "painkillers", "water_bottle"]:
			Game.add_item(item)
		Sfx.play("pickup", player.global_position, -4.0)
		await get_tree().create_timer(1.6).timeout
		await hud.fade_to(0.0, 0.5)
		_hold(false)
		Game.set_flag("ch12_supplies_taken")
		st()["supplies"] = "taken"
		Dialogue.say("c12_took", false, true)
	else:
		Game.set_flag("ch12_left_now")
		st()["supplies"] = "left"
		Dialogue.say("c12_left", false, true)
	Game.set_flag("ch12_supply_choice")
	var k := companion()
	c9._start_follow(k)
	_busy["choice"] = false
	_refresh_prompts()
	_guide()


## Taking the supplies cost time: something is out by the road on the way back (it can be avoided).
func _spawn_prowler() -> void:
	if hound != null:
		return
	var at := Vector3(-97.0, 0.1, -12.0)
	hound = (load(HOUND_PATH) as PackedScene).instantiate() as Node3D
	hound.name = "C12_Hound"
	world.add_child(hound)
	hound.global_position = at
	VeilCreatureLook.apply_skitter(hound, at.y)
	var ai: Node = HOUND_AI.new()
	ai.name = "AI"
	hound.add_child(ai)
	ai.leash = 16.0
	ai.setup(hound, player, [at, at + Vector3(6.0, 0.0, -6.0)])


# ------------------------------------------------------------------ scene 5: back at the mill house, the map
func _return_tick() -> void:
	if not Game.has_flag("ch12_left_station") or Game.has_flag("ch12_returned") or _busy.get("return", false):
		return
	if not c10.inside_room(player):
		return
	_busy["return"] = true
	Game.set_flag("ch12_returned")
	if hound and is_instance_valid(hound):
		hound.queue_free()
		hound = null
	var k := companion()
	(c9.follows[k] as VeilCompanionFollow).stop()
	world.npc_walk(k, c10.hl(c10.SPOTS[k]), 1.6)
	var a = world.animators.get(k)
	if a:
		a.set_mood("calm")
	world.save_checkpoint("chapter13_return")
	await get_tree().create_timer(1.5).timeout
	await c9._talk_group("c12_return", [_node("Ruth"), _node("Eddie")])
	_busy["return"] = false
	_ending()


func _place_map() -> void:
	if map_prop != null:
		return
	map_prop = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.9, 0.7)
	(map_prop as MeshInstance3D).mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(_map_image())
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	(map_prop as MeshInstance3D).material_override = m
	world.add_child(map_prop)
	map_prop.global_transform = Transform3D(c10.house.global_transform.basis, c10.hl(MAP_SPOT) + Vector3(0, 0.015, 0))


## The recovered underground map: tunnels converging on a district that is not on modern maps.
func _map_image() -> Image:
	var img := Image.create(96, 76, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.76, 0.72, 0.6))
	var c := Vector2(70, 22)
	for s in [Vector2(4, 70), Vector2(10, 8), Vector2(40, 74), Vector2(92, 70), Vector2(4, 36)]:
		for t in 60:
			var p: Vector2 = s.lerp(c, t / 60.0)
			img.set_pixel(int(p.x), int(p.y), Color(0.25, 0.18, 0.12))
			img.set_pixel(mini(int(p.x) + 1, 95), int(p.y), Color(0.25, 0.18, 0.12))
	var sym := symbol_image(16, Color(0.55, 0.08, 0.06), Color(0, 0, 0, 0))
	img.blend_rect(sym, Rect2i(0, 0, 16, 16), Vector2i(int(c.x) - 8, int(c.y) - 8))
	return img


func _ending() -> void:
	if Game.has_flag("chapter_12_complete") or _busy.get("ending", false):
		return
	_busy["ending"] = true
	report["ending_runs"] += 1
	_place_map()
	_hold(true)
	var cam: Camera3D = player.camera
	var fov0 := cam.fov
	await c8._turn_to(map_prop.global_position, 1.4)
	var tz := create_tween()
	tz.tween_property(cam, "fov", fov0 * 0.7, 1.4).set_trans(Tween.TRANS_SINE)
	await tz.finished
	_hold(false)
	var npcs: Array = [_node("Ruth"), _node("Eddie")]
	await c9._talk_group("c12_map", npcs)
	_hold(true)
	await c8._turn_to(map_prop.global_position, 0.4)
	_play("below", map_prop.global_position + Vector3(0, -6.0, 0), -6.0)
	var tm := create_tween()
	tm.tween_property(cam, "fov", fov0 * 0.42, 4.0).set_trans(Tween.TRANS_SINE)
	await tm.finished
	await hud.fade_to(1.0, 1.5)
	cam.fov = fov0
	report["ending_fov_restored"] = absf(cam.fov - fov0) < 0.01
	Game.set_flag("chapter_12_complete")             # Chapter 14 is NOT started here
	st()["completed"] = {"roster": group(), "records": Game.has_item("underground_records"), "supplies": st().get("supplies", "")}
	world.save_checkpoint("chapter13_end")
	await hud.chapter_complete(CHAPTER)
	await hud.title_card("NEXT:  CHAPTER 14  -  INTO THE VEIL", 2.2)
	await hud.fade_to(0.0, 1.2)
	_hold(false)
	_busy["ending"] = false
	_guide()
	_start_chapter13(false)                          # displayed Chapter 14 starts at the mill house


## The next chapter (displayed CHAPTER 14 "Into the Veil", internally chapter13.gd).
var chapter13: Node
func _start_chapter13(restoring: bool) -> void:
	if chapter13 != null:
		return
	chapter13 = load("res://game/world/chapter13.gd").new()
	chapter13.name = "Chapter13"
	add_child(chapter13)
	chapter13.begin(world, self, restoring)


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
	p.unit_size = 18.0
	p.max_distance = 120.0
	world.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


func _process(delta: float) -> void:
	_chase_tick(delta)
	_flicker_t -= delta
	if _flicker_t <= 0.0:
		_flicker_t = randf_range(0.08, 0.6)
		for l in street_lamps:
			(l as OmniLight3D).light_energy = 0.15 if randf() < 0.3 else 1.2
	_tick -= delta
	if _tick > 0.0 or player == null:
		return
	_tick = 0.2
	if its.has("npc_Eddie") and chapter13 == null:
		var talk: bool = Game.has_flag("ch12_started") and not Game.has_flag("ch12_set_out") and not _busy.get("talk", false) \
			and not _busy.get("prep", false) and not _busy.get("opening", false)
		_set_prompt("npc_Eddie", "[E] Talk" if talk else "")
	var p := player.global_position
	var outside: bool = Game.has_flag("ch12_set_out") and not Game.has_flag("ch12_returned") and p.y > -20.0
	# the journey: distant metal sounds, Eddie on the fog (once)
	if outside:
		_noise_t -= 0.2
		if _noise_t <= 0.0:
			_noise_t = randf_range(14.0, 26.0)
			var a := randf() * TAU
			_play("clank", p + Vector3(cos(a), 0.0, sin(a)) * 32.0 + Vector3(0, 3, 0), -2.0)
		if not Game.has_flag("ch12_fog_talk") and not Game.has_flag("ch12_station_reached") and p.distance_to(c10.hl(c10.PORCH)) > 14.0 \
				and not Dialogue.is_busy() and not world.conversing:
			Game.set_flag("ch12_fog_talk")
			Dialogue.say("c12_fog", false, true)
	# drips in the tunnels
	if p.y < -40.0:
		_drip_t -= 0.2
		if _drip_t <= 0.0:
			_drip_t = randf_range(2.5, 6.0)
			Sfx.play("splash", p + Vector3(randf_range(-4, 4), 2.0, randf_range(-4, 4)), -18.0, randf_range(1.4, 2.2))
	if Game.has_flag("ch12_power_on") and not Game.has_flag("ch12_descended") and (p - FAC).z > 30.0 and (p - FAC).y < -2.0:
		Game.set_flag("ch12_descended")
		_refresh_prompts()
	_return_tick()
	if not _busy.get("records", false) and not _busy.get("ending", false):
		_guide()
