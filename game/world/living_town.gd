extends Node
class_name VeilLivingTown
## THE VEIL - Greyhaven before and as the Veil arrives: a few people and cars, then panic, then five one-time
## scripted horror moments. Waypoints and tweens only - no traffic or crowd simulation.
##   before the Veil: Frank on the shop sidewalk, Joan at the gas station, a police officer at the corner, two
##     anonymous civilians by the storefronts (max 5 people); 3 cars on the main street (one at a time per lane)
##   the Veil (p3_mist): routines stop, people turn scared, flee into buildings or the fog over ~20 s; traffic ends
##   events (flags lt_*_done, saved; never twice; one at a time; never during a story scene):
##     frank  - Colossus reveal over: Frank runs past, a Skitter leaps from behind a car, pins him, drags him off
##     crash  - right after: a car races off, a second swerves into the roadside and stops; the driver runs
##     police - the run to the supermarket: the officer waves two cars through, a distant sound, he runs with
##              a civilian into the mist
##     joan   - post-Veil, near the gas station: door slam, Joan runs to the trees, a Hound after her, a scream
##     window - on a supply run, by a two-storey house: someone at an upstairs window, the light dies, a thump
## The scripted creatures are not the threat director's: they never hunt, and the director waits while one plays.

const FRANK := "res://THE_VEIL_ASSETS_V2/06_Characters/Commercial_NPCs/CHR_Frank.glb"
const CASHIER := "res://THE_VEIL_ASSETS_V2/06_Characters/Commercial_NPCs/CHR_Cashier.glb"
const POLICE := "res://THE_VEIL_ASSETS_V2/06_Characters/Police/CHR_Police_Officer.glb"
const FACES := "res://THE_VEIL_ASSETS_V2/06_Characters/Facial/Faces/"
const CARS := ["res://THE_VEIL_ASSETS_V2/05_Vehicles/Traffic_Variants/VEH_Sedan_Traffic_Beige.glb",
	"res://THE_VEIL_ASSETS_V2/05_Vehicles/Traffic_Variants/VEH_Sedan_Traffic_Green.glb"]
const SKITTER := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const HOUND := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const ACTIVE_RANGE := 110.0               ## people and cars only move while the player is this close to town
const MAIN_X := Vector2(-110.0, 200.0)    ## the main street's extent (x) used by traffic
const EAST_LANE := 1.8                    ## right-hand traffic: heading +x you drive on the +z side of the centre
const WEST_LANE := -1.8

var world: Node
var people := {}                          ## name -> {"body", "anim", "route", "i", "wait"}
var cars: Array = []                      ## {"node", "path", "s", "speed", "lane", "rest"}
var road_z := 0.0                         ## main street centre line (z), found on the real road surfaces
var report := {"people": 0, "cars_spawned": 0, "events": []}
var _busy := ""                           ## the event playing now ("" = none)
var _car_t := 2.0
var _panic_t := -1.0
var _event_t := 0.0
var _frank_ready_t := -1.0


func setup(w: Node) -> void:
	world = w
	road_z = _find_road_z(14.0)
	if not Game.has_flag("p3_mist"):
		_spawn_people()
	else:
		_restore_after_veil()


# ------------------------------------------------------------------ helpers
func _space() -> PhysicsDirectSpaceState3D:
	return world.get_world_3d().direct_space_state


func _ground(p: Vector3) -> Vector3:
	var h := _space().intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 6.0, p - Vector3.UP * 6.0, 1, [world.player.get_rid()]))
	return (h["position"] as Vector3) if h else p


func _on_road(p: Vector3) -> bool:
	var h := _space().intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p - Vector3.UP * 3.0, 1, [world.player.get_rid()]))
	if h.is_empty():
		return false
	var n := String((h["collider"] as Node).name)
	return n.begins_with("RD_") and not n.contains("Parking") and not n.contains("Alley") and not n.contains("Lot")


## The main street's centre (z) at `x`: the middle of the road surface between the shop row and the supermarket.
func _find_road_z(x: float) -> float:
	var hits: Array = []
	var z := 6.0
	while z > -26.0:
		if _on_road(Vector3(x, 0.2, z)):
			hits.append(z)
		z -= 0.5
	if hits.is_empty():
		return -4.0
	report["road_span"] = [hits.min(), hits.max()]
	return (float(hits.min()) + float(hits.max())) * 0.5


func _seen(p: Vector3, margin := 1.0) -> bool:
	var cam := world.get_viewport().get_camera_3d()
	return cam != null and cam.is_position_in_frustum(p + Vector3.UP * margin) and cam.global_position.distance_to(p) < 70.0


func _player_near(p: Vector3, d: float) -> bool:
	return focus().distance_to(p) < d


## Where the player is: the car while driving or seated in it (their body is left where they got in), else the body.
func focus() -> Vector3:
	return world.sedan.global_position if world.in_car and world.sedan else world.player.global_position


func _story_busy() -> bool:
	return world.get("_encounter_running") == true or world.get("conversing") == true or world.get("_cine") != null \
		or _struggling() or not world.player.visible and not world.in_car


## A struggle actually under way (the controller node itself stays in the world once made).
func _struggling() -> bool:
	var s := world.get_node_or_null("Struggle")
	return s != null and s.get("active") == true


func _say(id: String) -> void:
	if Dialogue.data.has(id):
		Dialogue.say(id, false, false)


func _snd(id: String, at: Vector3, db := 0.0) -> AudioStreamPlayer3D:
	if Sfx.bank(id):
		return Sfx.bank_at(id, at, db, 10.0)
	return Sfx.play(id, at, db)


## A looping sound (a *_LOOP / *_loop file) is stopped by the scene that started it - never left playing.
func _stop(p) -> void:
	if p != null and is_instance_valid(p):
		(p as AudioStreamPlayer3D).stop()
		(p as AudioStreamPlayer3D).queue_free()


func _anim(n: Node) -> AnimationPlayer:
	return n.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _clip(n: Node, clip: String, speed := 1.0) -> void:
	var ap := _anim(n)
	if ap and ap.has_animation(clip):
		ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		ap.play(clip, 0.15, speed)


## A small variation on a reused model, so nobody reads as a second Frank or a second cashier: its clothes, hair and
## badge recoloured (skin and face untouched) and a slightly different height. One look per index, never repeated.
const LOOKS := [
	{"Top": Color(0.55, 0.62, 0.95), "Shirt": Color(0.9, 0.9, 0.95), "Pants": Color(0.45, 0.45, 0.5), "Hair": Color(0.55, 0.42, 0.3), "Badge": Color(0.55, 0.62, 0.95), "h": 1.03},
	{"Top": Color(0.62, 0.8, 0.6), "Shirt": Color(0.95, 0.9, 0.75), "Pants": Color(0.42, 0.42, 0.6), "Hair": Color(0.45, 0.45, 0.45), "Badge": Color(0.62, 0.8, 0.6), "Gear": Color(0.5, 0.5, 0.5), "h": 0.97},
	{"Top": Color(0.95, 0.62, 0.6), "Shirt": Color(0.95, 0.85, 0.85), "Pants": Color(0.35, 0.33, 0.4), "Hair": Color(0.75, 0.55, 0.35), "Badge": Color(0.95, 0.62, 0.6), "h": 0.98},
	{"Top": Color(0.8, 0.7, 0.5), "Shirt": Color(0.8, 0.85, 0.95), "Pants": Color(0.3, 0.32, 0.38), "Hair": Color(0.3, 0.25, 0.22), "Badge": Color(0.8, 0.7, 0.5), "Gear": Color(0.35, 0.35, 0.35), "h": 1.02},
	{"Top": Color(0.5, 0.75, 0.85), "Shirt": Color(0.95, 0.95, 0.85), "Pants": Color(0.55, 0.48, 0.4), "Hair": Color(0.6, 0.6, 0.6), "Badge": Color(0.5, 0.75, 0.85), "h": 0.96},
	{"Top": Color(0.85, 0.55, 0.85), "Shirt": Color(0.9, 0.9, 0.9), "Pants": Color(0.4, 0.4, 0.45), "Hair": Color(0.25, 0.22, 0.2), "Badge": Color(0.85, 0.55, 0.85), "Gear": Color(0.45, 0.4, 0.35), "h": 1.04},
	{"Top": Color(0.7, 0.7, 0.72), "Shirt": Color(0.75, 0.85, 0.75), "Pants": Color(0.5, 0.45, 0.38), "Hair": Color(0.65, 0.5, 0.35), "Badge": Color(0.7, 0.7, 0.72), "h": 0.99},
	{"Top": Color(0.9, 0.8, 0.55), "Shirt": Color(0.95, 0.9, 0.9), "Pants": Color(0.3, 0.35, 0.45), "Hair": Color(0.4, 0.3, 0.25), "Badge": Color(0.9, 0.8, 0.55), "Gear": Color(0.5, 0.45, 0.4), "h": 1.01},
]
const LOOK_OF := {"Civilian_A": 0, "Civilian_B": 1, "Joan": 2, "Res_Walker": 3, "Res_Neighbour": 4, "Res_Driveway": 5, "LT_Driver": 6}
var _look_i := 6                          ## drivers take the remaining looks in turn


func _vary(n: Node, idx := -1) -> void:
	if idx < 0:
		idx = _look_i
		_look_i = 6 + (_look_i - 5) % 2       # (drivers: 6, 7, 6, 7 ...)
	var look: Dictionary = LOOKS[idx % LOOKS.size()]
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var src := m.get_active_material(s) as StandardMaterial3D
			if src == null:
				continue
			var nm := src.resource_name
			var part := nm.get_slice("_", nm.count("_"))       # "Frank_Top" -> "Top", "Police_Officer_Hair" -> "Hair"
			if part == "TopCuff":
				part = "Top"
			elif part == "PantsHem":
				part = "Pants"
			if look.has(part):
				var d := src.duplicate() as StandardMaterial3D
				d.albedo_color = src.albedo_color * (look[part] as Color)
				m.set_surface_override_material(s, d)
	var model := n.get_child(0) as Node3D
	if model:
		model.scale = Vector3.ONE * float(look["h"])


# ------------------------------------------------------------------ people
func _person(nm: String, model: String, face: String, at: Vector3, tint := Color.WHITE) -> Node3D:
	var body: Node3D = world._spawn_npc(load(model), load(FACES + face), world, _ground(at), 0.0, nm)
	if tint != Color.WHITE:
		_vary(body, LOOK_OF.get(nm, -1))             # (a reused model: its own fixed look)
	var a = world.animators[nm]
	people[nm] = {"body": body, "anim": a, "route": [], "i": 0, "wait": 0.0, "state": "routine", "talk_t": 0.0}
	report["people"] = people.size()
	var it := Interactable.attach(body, {"kind": "custom", "label": nm, "prompt_text": ""})
	it.used.connect(func(_b): _talk(nm))
	people[nm]["it"] = it
	return body


## Every house's footprint (the protagonist's home first), grown a little: no townsperson stands or walks in one.
## (Roofs have no collision, so "under a roof" alone let a spot inside the home pass for outdoors.)
var _house_rects: Array = []


func house_rects() -> Array:
	if _house_rects.is_empty():
		var nodes: Array = []
		var h = world.get("home")
		if h is Node3D:
			nodes.append(h)
		var hn := world.get_node_or_null("Residential/Houses")
		if hn:
			nodes.append_array(hn.get_children())
		for n in nodes:
			if not (n is Node3D) or not (n as Node3D).visible:
				continue
			var a: AABB = (n as Node3D).global_transform * Interactable.aabb_of(n as Node3D)
			if a.size.x > 3.0 and a.size.z > 3.0 and a.size.x < 40.0 and a.size.z < 40.0:
				_house_rects.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z).grow(0.6))
	return _house_rects


func in_house(p: Vector3) -> bool:
	var v := Vector2(p.x, p.z)
	return house_rects().any(func(r): return (r as Rect2).has_point(v))


## A straight walk from a to b that would cut through a house (sampled every half metre).
func _through_house(a: Vector3, b: Vector3) -> bool:
	var n := maxi(1, ceili(a.distance_to(b) / 0.5))
	for i in n + 1:
		if in_house(a.lerp(b, float(i) / n)):
			return true
	return false


## The nearest spot to `p` a person can stand on: not on the road, nothing solid there (a parked car, a bin, a
## wall), never inside a house. Tries the spot itself, then rings round it out to 2.5 m. INF = none.
func safe_point(p: Vector3) -> Vector3:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.5
	q.shape = cap
	q.collision_mask = 1
	q.exclude = [world.player.get_rid()]
	for r in [0.0, 0.6, 1.2, 1.8, 2.5]:
		for k in (1 if r == 0.0 else 8):
			var a := TAU * k / 8.0
			var c: Vector3 = _ground(p + Vector3(cos(a), 0, sin(a)) * r)
			if _on_road(c) or in_house(c):
				continue
			q.transform = Transform3D(Basis(), c + Vector3.UP * 0.95)
			var clear := true
			for h in _space().intersect_shape(q, 4):
				if not (h["collider"] is VeilSurvivorBody):
					clear = false
			if clear:
				return c
	return Vector3.INF


## Off along a route leg: round anything in the way (the world's collision-checked route, the player's car
## included), never through it; if there is no way, they wait and try the other end later.
func _walk_leg(p: Dictionary, to: Vector3, speed: float) -> bool:
	var body: Node3D = p["body"]
	var goal := safe_point(to)
	if not goal.is_finite():
		return false
	var path: Array = world.npc_route(world, body.global_position, goal, body as VeilSurvivorBody, false)
	if path.is_empty():
		if not _segment_clear(body.global_position, goal):
			return false
		path = [goal]
	var from: Vector3 = body.global_position
	for wp in path:
		if _through_house(from, wp):
			return false                                # never through a house (doors, the home): they stay put
		from = wp
	p["anim"].walk_to(path, speed)
	return true


func _segment_clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.3
	q.shape = s
	q.collision_mask = 1
	q.exclude = [world.player.get_rid()]
	q.transform = Transform3D(Basis(), a + Vector3.UP * 0.9)
	q.motion = b - a
	var r := _space().cast_motion(q)
	return r.size() > 0 and r[0] >= 0.999


## [E] Talk: a line, a look at the player, a pause in their walk. Never while fleeing or in a scene.
func can_talk(nm: String) -> bool:
	var p: Dictionary = people.get(nm, {})
	if p.is_empty() or not is_instance_valid(p["body"]) or not p["body"].visible:
		return false
	if _busy != "" or _story_busy() or Dialogue.is_busy():
		return false
	return String(p["state"]) in ["routine", "stay", "freeze"]


func _talk(nm: String) -> void:
	if not can_talk(nm):
		return
	var p: Dictionary = people[nm]
	var veil := Game.has_flag("p3_mist")
	var key := String(nm).to_lower()
	if key.begins_with("res_"):
		key = "resident"
	elif key.begins_with("civilian"):
		key = "civilian"
	var id := "lt_talk_%s_%s" % [key, "post" if veil else "pre"]
	if not Dialogue.data.has(id):
		id = "lt_talk_civilian_%s" % ("post" if veil else "pre")
	p["anim"].walk_to([], 0.0)
	p["anim"].face_towards(world.player.global_position)
	p["wait"] = 4.0
	Dialogue.say(id, false, true)
	report["talks"] = int(report.get("talks", 0)) + 1


func _update_prompts() -> void:
	for nm in people:
		var p: Dictionary = people[nm]
		if not p.has("it") or not is_instance_valid(p["it"]):
			continue
		var on := can_talk(nm)
		(p["it"] as Interactable).prompt_text = "[E] Talk" if on else ""
		(p["it"] as Interactable).collision_layer = 8 if on else 0


func _spawn_people() -> void:
	var sw := 5.4                                   # the shop-row sidewalk (z), between the doors and the kerb
	_person("Frank", FRANK, "T_Face_Frank.png", Vector3(8.0, 0.2, sw))
	people["Frank"]["route"] = [Vector3(8.0, 0.2, sw), Vector3(21.0, 0.2, sw)]
	_person("Civilian_A", CASHIER, "T_Face_Cashier.png", Vector3(30.0, 0.2, sw), Color(0.9, 0.9, 0.9))
	people["Civilian_A"]["route"] = [Vector3(30.0, 0.2, sw), Vector3(48.0, 0.2, sw)]
	_person("Civilian_B", FRANK, "T_Face_Frank.png", Vector3(24.0, 0.2, -25.4), Color(0.85, 0.75, 0.7))
	people["Civilian_B"]["route"] = [Vector3(24.0, 0.2, -25.4), Vector3(29.0, 0.2, -25.4)]   # the store front, clear of the lot
	_person("Officer", POLICE, "T_Face_Police_Officer.png", Vector3(60.0, 0.2, sw))
	people["Officer"]["route"] = []                # stands at the corner, watching the traffic
	_person("Joan", CASHIER, "T_Face_Cashier.png", Vector3(147.0, 0.2, -24.5), Color(1.0, 0.85, 0.85))
	people["Joan"]["route"] = [Vector3(147.0, 0.2, -24.5), Vector3(152.0, 0.2, -24.8)]
	for k in people:
		var b: Node3D = people[k]["body"]
		var sp := safe_point(b.global_position)
		b.global_position = sp if sp.is_finite() else _ground(b.global_position)
		var safe: Array = []
		for wp in people[k]["route"]:
			var s := safe_point(wp)
			if s.is_finite():
				safe.append(s)
		people[k]["route"] = safe
	_spawn_neighbours()


## Near the protagonist's home (the opening street): three neighbours on short routes, found on the real ground
## (outdoors, off the road, nothing solid there).
func _spawn_neighbours() -> void:
	var home_n := world.get_node_or_null("Trigger_LeftHouse") as Node3D
	if home_n == null:
		return
	var home := home_n.global_position
	var spots: Array = []
	for i in 48:
		var a := TAU * i / 48.0
		for r in [7.0, 11.0, 15.0, 19.0]:
			var c: Vector3 = home + Vector3(cos(a), 0, sin(a)) * r
			var g := _ground(c)
			if absf(g.y - home.y) > 1.2:
				continue
			if not _space().intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3.UP, g + Vector3.UP * 12.0, 1)).is_empty():
				continue
			var s := safe_point(g)
			if s.is_finite() and s.distance_to(world.player.global_position) < 3.0:
				continue                            # never on the player's own start spot
			if s.is_finite() and s.distance_to(g) < 0.3 and not [Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(0, 0, 1.5), Vector3(0, 0, -1.5)].any(func(o): return _on_road(s + o)):
				spots.append(s)                     # (a clear metre and a half from any kerb)
	report["home_spots"] = spots.size()
	if spots.size() < 4:
		return
	spots.shuffle()
	var used: Array = []
	var pick := func(near: Vector3, dmin: float, dmax: float) -> Vector3:
		for s in spots:
			if near.is_finite() and (s.distance_to(near) < dmin or s.distance_to(near) > dmax or not _segment_clear(near, s)):
				continue
			if used.any(func(u): return (u as Vector3).distance_to(s) < 3.0):
				continue
			if near.is_finite() and _through_house(near, s):
				continue
			used.append(s)
			return s
		return Vector3.INF
	var a0: Vector3 = pick.call(Vector3.INF, 0.0, 0.0)
	var a1: Vector3 = pick.call(a0, 8.0, 15.0)
	if a0.is_finite() and a1.is_finite():
		_person("Res_Walker", CASHIER, "T_Face_Cashier.png", a0, Color(0.8, 0.9, 0.8))
		people["Res_Walker"]["route"] = [a0, a1]
		people["Res_Walker"]["home"] = true
	var b0: Vector3 = pick.call(Vector3.INF, 0.0, 0.0)
	if b0.is_finite():
		_person("Res_Neighbour", FRANK, "T_Face_Frank.png", b0, Color(0.7, 0.8, 0.95))
		people["Res_Neighbour"]["route"] = []
		people["Res_Neighbour"]["home"] = true
	# the third walks to (beside) a parked car and back
	var parked := Vector3.INF
	for n in world.find_children("VEH_*", "Node3D", true, false):
		if n != world.sedan and (n as Node3D).global_position.distance_to(home) < 30.0:
			parked = (n as Node3D).global_position
			break
	var c0: Vector3 = pick.call(Vector3.INF, 0.0, 0.0)
	if c0.is_finite():
		var c1: Vector3 = safe_point(parked + (c0 - parked).normalized() * 2.2) if parked.is_finite() else pick.call(c0, 6.0, 12.0)
		if c1.is_finite() and _through_house(c0, c1):
			c1 = pick.call(c0, 6.0, 12.0)
		if c1.is_finite():
			_person("Res_Driveway", CASHIER, "T_Face_Cashier.png", c0, Color(0.95, 0.85, 0.7))
			people["Res_Driveway"]["route"] = [c0, c1]
			people["Res_Driveway"]["home"] = true


func _restore_after_veil() -> void:
	# after a load past the Veil: only what is still to come is put back (out of the way, hidden until needed)
	if not Game.has_flag("lt_joan_done"):
		_person("Joan", CASHIER, "T_Face_Cashier.png", Vector3(152.0, 0.2, -27.5), Color(1.0, 0.85, 0.85))
		people["Joan"]["body"].visible = false
	if Game.world_state.has("lt_crash"):
		var c: Array = Game.world_state["lt_crash"]
		var car := _car_node(int(c[4]))
		car.global_transform = Transform3D(Basis(Vector3.UP, float(c[3])) * Basis(Vector3.RIGHT, 0.04), Vector3(c[0], c[1], c[2]))
		car.name = "LT_AbandonedCar"


func _routine(nm: String, p: Dictionary, delta: float) -> void:
	var a = p["anim"]
	var route: Array = p["route"]
	if route.is_empty():
		var c := Vector3(60.0, 0.0, road_z)
		a.face_towards(c + Vector3(-8.0 if fmod(Time.get_ticks_msec() / 7000.0, 2.0) < 1.0 else 8.0, 0, 0))
		return
	if a.is_walking():
		return
	p["wait"] = float(p["wait"]) - delta
	if float(p["wait"]) > 0.0:
		return
	var nxt := (int(p["i"]) + 1) % route.size()
	if _walk_leg(p, route[nxt], 1.15):
		p["i"] = nxt
		p["wait"] = randf_range(2.5, 6.0)           # a pause at each end: a look in a window, a phone, the street
	else:
		p["wait"] = 3.0                             # the way is blocked (a car pulled in): wait, try again


## The Veil: routines stop; fear; flight (staggered so the street empties over ~20 s, never at once).
func _panic(delta: float) -> void:
	_panic_t += delta
	var plan := {"Civilian_A": [1.5, "building", Vector3(37.5, 0.2, 6.6)], "Joan": [3.0, "building", Vector3(152.0, 0.2, -26.6)],
		"Civilian_B": [7.0, "fog", Vector3(70.0, 0.2, -23.0)], "Frank": [0.5, "freeze", Vector3.ZERO],
		"Officer": [0.0, "stay", Vector3.ZERO], "Res_Walker": [2.0, "hide", Vector3.ZERO],
		"Res_Neighbour": [4.0, "hide", Vector3.ZERO], "Res_Driveway": [6.0, "hide", Vector3.ZERO]}
	for nm in plan:
		if not people.has(nm):
			continue
		var p: Dictionary = people[nm]
		var b = p["body"]
		if not is_instance_valid(b) or not b.visible:
			continue
		var step: Array = plan[nm]
		if p["state"] == "routine" and _panic_t >= float(step[0]):
			p["state"] = String(step[1])
			p["anim"].set_mood("scared")
			p["anim"].walk_to([], 0.0)
			if step[1] in ["building", "fog"]:
				p["anim"].walk_to([step[2]], 3.4)
		elif p["state"] == "hide" and not _seen(b.global_position):
			b.visible = false                      # indoors (far from town when it comes; never in view)
			p["state"] = "inside"
		elif p["state"] == "building" and not p["anim"].is_walking() and not _seen(b.global_position):
			b.visible = false                      # in through the door (never vanishes in view)
			p["state"] = "inside"
		elif p["state"] == "fog" and not p["anim"].is_walking() and (not _seen(b.global_position) or b.global_position.distance_to(world.player.global_position) > 45.0):
			b.visible = false
			p["state"] = "gone"


# ------------------------------------------------------------------ traffic
func _car_node(i: int) -> Node3D:
	var car := (load(CARS[i % CARS.size()]) as PackedScene).instantiate() as Node3D
	world.add_child(car)
	for co in car.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0   # background traffic: no physics; it brakes for things instead
		(co as CollisionObject3D).collision_mask = 0
	return car


## Someone at the wheel: a reused model on the car's own driver-seat marker, seated, facing the way it drives
## (the cars run along their -Z, a person's model faces its +Z), carried with the car.
const SEAT_DROP := 0.51
var _drivers := 0


func _add_driver(car: Node3D) -> Node3D:
	var seat := car.find_child("Marker_Seat_Driver", true, false) as Node3D
	if seat == null:
		return null
	_drivers += 1
	var nm := "LT_Drv_%d" % _drivers
	var body: Node3D = world._spawn_npc(load(CASHIER if _drivers % 2 == 0 else FRANK), load(FACES + ("T_Face_Cashier.png" if _drivers % 2 == 0 else "T_Face_Frank.png")),
		world, seat.global_position, 0.0, nm)
	_vary(body)
	if body is CollisionObject3D:
		(body as CollisionObject3D).collision_layer = 0
		(body as CollisionObject3D).collision_mask = 0
	body.reparent(seat, false)
	body.global_transform = Transform3D(car.global_basis * Basis(Vector3.UP, PI), seat.global_position - Vector3(0, SEAT_DROP, 0))
	var an = world.animators[nm]
	an.walk_to([])
	an.hold_facing = true
	an.set_seated(true, 0.45)
	return body


## A lane on the main street from x0 to x1 (all on the road surface), z offset from the centre line.
func _lane(x0: float, x1: float, offset: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var n := int(absf(x1 - x0) / 4.0)
	for k in n + 1:
		var x := lerpf(x0, x1, float(k) / n)
		var p := Vector3(x, 0.2, road_z + offset)
		if not _on_road(p):
			if pts.size() > 2:
				break
			continue
		pts.append(_ground(p))
	return pts


func _spawn_car(path: PackedVector3Array, speed: float, i: int) -> Dictionary:
	if path.size() < 3:
		return {}
	var car := _car_node(i)
	var c := {"node": car, "path": path, "s": 0.0, "speed": speed, "lane": i, "v": speed, "ray_t": 0.0, "block": 99.0,
		"wheels": car.find_children("Wheel_*", "Node3D", true, false)}
	_place_car(c)
	c["driver"] = _add_driver(car)
	cars.append(c)
	report["cars_spawned"] = int(report["cars_spawned"]) + 1
	return c


## The point `s` metres along an evenly spaced path.
func _at(path: PackedVector3Array, s: float) -> Vector3:
	var seg := path[0].distance_to(path[1])
	var total := (path.size() - 1) * seg
	s = clampf(s, 0.0, total)
	var k := mini(int(s / seg), path.size() - 2)
	return path[k].lerp(path[k + 1], (s - k * seg) / seg)


func _place_car(c: Dictionary) -> void:
	var path: PackedVector3Array = c["path"]
	var total := (path.size() - 1) * path[0].distance_to(path[1])
	var s := clampf(float(c["s"]), 0.0, total - 0.01)
	var p := _at(path, s)
	var ahead := _at(path, s + 2.2) - _at(path, s - 0.6)    # heading from a short look-ahead: smooth in the turns
	if ahead.length() < 0.05:
		ahead = path[path.size() - 1] - path[path.size() - 2]
	var car: Node3D = c["node"]
	var yaw := atan2(-ahead.x, -ahead.z)              # the car models' front is their -Z: it points where it goes
	if c.has("swerve"):
		yaw += float(c["swerve"])
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.02, 0))
	c["total"] = total


func _traffic(delta: float) -> void:
	var veil := Game.has_flag("p3_mist")
	# a new car now and then (before the Veil), one per lane at a time, entering out of view
	_car_t -= delta
	if not veil and _car_t <= 0.0 and cars.size() < 3:
		_car_t = randf_range(5.0, 10.0)
		var which := int(report["cars_spawned"]) % 3
		var drive := _drive()
		var path: PackedVector3Array = drive.get("pts", PackedVector3Array())
		if path.size() > 2 and not _seen(path[0]) and focus().distance_to(path[0]) > 45.0 \
				and not cars.any(func(c): return (c["node"] as Node3D).global_position.distance_to(path[0]) < 25.0):
			var c := _spawn_car(path, randf_range(9.0, 11.5), which)
			if not c.is_empty():
				c["limit"] = drive["limit"]
	var keep: Array = []
	for c in cars:
		var car: Node3D = c["node"]
		if not is_instance_valid(car):
			continue
		var want: float = float(c["speed"]) * (1.7 if veil and not c.has("scripted") else 1.0)
		if c.has("limit"):
			var lim: PackedFloat32Array = c["limit"]
			var li := clampi(int(float(c["s"]) / 1.0), 0, lim.size() - 1)
			want = minf(want, lim[li])                  # slows for the corners ahead
		var gap := _clear_ahead(c, delta)
		c["gap"] = gap
		want *= clampf((gap - 5.0) / 8.0, 0.0, 1.0)  # slows from 13 m, stopped 5 m short; waits, never clips
		var v: float = c["v"]
		v = move_toward(v, want, (9.0 if want < v else 3.0) * delta)
		c["v"] = v
		c["s"] = float(c["s"]) + v * delta
		_place_car(c)
		for wh in c["wheels"]:
			if is_instance_valid(wh):
				(wh as Node3D).rotation.x -= v * delta / 0.31
		if float(c["s"]) >= float(c["total"]) - 0.1 and not c.has("crash"):
			if not _seen(car.global_position):
				_drop_car(c)                        # gone round the far end, out of view
				continue
			c["s"] = float(c["total"]) - 0.1        # waits at the end of its lane until it is out of view
		keep.append(c)
	cars = keep


## Metres of free road ahead in the car's lane: the cars in front, the player's car, the player on foot, anyone
## walking, and (a ray every 0.2 s) anything solid - a parked car, a bin, a wall.
func _clear_ahead(c: Dictionary, delta: float) -> float:
	var car: Node3D = c["node"]
	var fwd := -car.global_basis.z
	var at := car.global_position
	var best := 99.0
	var obs: Array = []
	for o in cars:
		if o != c and is_instance_valid(o["node"]):
			obs.append((o["node"] as Node3D).global_position)
	if world.sedan:
		obs.append(world.sedan.global_position)
	if world.player.visible:
		obs.append(world.player.global_position)
	for nm in people:
		var b = people[nm]["body"]
		if is_instance_valid(b) and b.visible and b.get_parent() == world:
			obs.append((b as Node3D).global_position)
	for o in obs:
		var rel: Vector3 = (o as Vector3) - at
		rel.y = 0.0
		var along := rel.dot(fwd)
		if along > 0.5 and along < best and (rel - fwd * along).length() < 1.3:
			best = along
	c["ray_t"] = float(c["ray_t"]) - delta
	if float(c["ray_t"]) <= 0.0:
		c["ray_t"] = 0.2
		var from := at + Vector3.UP * 0.8 + fwd * 2.5
		var h := _space().intersect_ray(PhysicsRayQueryParameters3D.create(from, from + fwd * 14.0, 1, [world.player.get_rid()]))
		c["block"] = (from.distance_to(h["position"]) + 2.5) if h else 99.0
	return minf(best, float(c["block"]))


func _drop_car(c: Dictionary) -> void:
	var d = c.get("driver")
	if d and is_instance_valid(d):
		_unregister(d)
	if is_instance_valid(c["node"]):
		(c["node"] as Node).queue_free()


# ------------------------------------------------------------------ the street network
## Junctions = the town's own intersection tiles; a street links two of them when they line up and the road surface
## runs unbroken between them. Built once (a few hundred rays).
var junctions: Array = []                 ## Vector3
var links := {}                           ## index -> [index]
const LANE := 1.8
const JUNCTION_HALF := 7.0                ## a lane starts / ends this far from a junction's centre
const TURN_SPEED := 5.0


func _build_network() -> void:
	junctions.clear()
	links.clear()
	for part in ["Core", "Extension"]:
		var root := world.get_node_or_null(part)
		if root == null:
			continue
		for n in root.find_children("RD_Intersection_*", "Node3D", true, false):
			if n.get_parent() and String(n.get_parent().name).begins_with("RD_"):
				continue
			var p: Vector3 = (n as Node3D).global_position
			if p.x < -130.0 or p.x > 210.0 or p.z < -130.0 or p.z > 60.0:
				continue                              # (the town; not the farm roads far out)
			if junctions.any(func(q): return (q as Vector3).distance_to(p) < 3.0):
				continue
			junctions.append(_ground(p))
	for i in junctions.size():
		links[i] = []
	for i in junctions.size():
		for j in junctions.size():
			if i == j:
				continue
			var a: Vector3 = junctions[i]
			var b: Vector3 = junctions[j]
			var straight := absf(a.x - b.x) < 1.5 or absf(a.z - b.z) < 1.5
			if not straight or a.distance_to(b) > 140.0:
				continue
			# nearest along that line only (no skipping over a junction in between)
			var between := false
			for k in junctions.size():
				if k != i and k != j:
					var q: Vector3 = junctions[k]
					if (absf(q.x - a.x) < 1.5 and absf(a.x - b.x) < 1.5 or absf(q.z - a.z) < 1.5 and absf(a.z - b.z) < 1.5) \
							and q.distance_to(a) < a.distance_to(b) and q.distance_to(b) < a.distance_to(b):
						between = true
			if between:
				continue
			var ok := true
			var n := int(a.distance_to(b) / 3.0)
			for k in range(1, n):
				var d := (b - a).normalized()
				var side := d.cross(Vector3.UP) * LANE
				var m := a.lerp(b, float(k) / n)
				if not _on_road(m + side) or not _on_road(m - side):
					ok = false
					break
			if ok:
				(links[i] as Array).append(j)
	report["junctions"] = junctions.size()
	report["links"] = links.values().reduce(func(acc, l): return acc + (l as Array).size(), 0)


## A drive: from a junction, 3-5 streets, no U-turns. {"pts": 1 m spaced path in the right-hand lane with the
## corners rounded, "limit": speed limit per metre (slow through the turns)}.
func _drive() -> Dictionary:
	if junctions.is_empty():
		_build_network()
	var starts: Array = range(junctions.size()).filter(func(i): return not (links[i] as Array).is_empty())
	if starts.is_empty():
		return {}
	var cur: int = starts[randi() % starts.size()]
	var prev := -1
	var nodes: Array = [cur]
	for step in randi_range(3, 5):
		var options: Array = (links[cur] as Array).filter(func(j): return j != prev)
		if options.is_empty():
			break
		var nxt: int = options[randi() % options.size()]
		prev = cur
		cur = nxt
		nodes.append(cur)
	if nodes.size() < 2:
		return {}
	var raw := PackedVector3Array()
	var turn_at: Array = []                           # raw-path indices of corner arcs
	for i in nodes.size() - 1:
		var a: Vector3 = junctions[nodes[i]]
		var b: Vector3 = junctions[nodes[i + 1]]
		var d := (b - a)
		d.y = 0.0
		d = d.normalized()
		var r := d.cross(Vector3.UP) * LANE           # right-hand lane
		var p0 := a + d * JUNCTION_HALF + r
		var p1 := b - d * JUNCTION_HALF + r
		if i == 0:
			raw.append(p0)
		raw.append(p1)
		if i + 1 < nodes.size() - 1:
			var c: Vector3 = junctions[nodes[i + 2]]
			var d2 := (c - b)
			d2.y = 0.0
			d2 = d2.normalized()
			var r2 := d2.cross(Vector3.UP) * LANE
			var q0 := b + d2 * JUNCTION_HALF + r2
			if d.dot(d2) > 0.9:
				raw.append(q0)                            # straight across
			else:
				var ctrl := b + r + r2                    # where the two lanes cross: a rounded corner through it
				turn_at.append(raw.size())
				for k in range(1, 8):
					var t := k / 8.0
					raw.append(p1.lerp(ctrl, t).lerp(ctrl.lerp(q0, t), t))
				raw.append(q0)
	# resample every metre, ground-snapped; a speed limit per metre (slow from 9 m before a corner to its end)
	var cum: Array = [0.0]
	for i in range(1, raw.size()):
		cum.append(float(cum[i - 1]) + raw[i - 1].distance_to(raw[i]))
	var corner_s: Array = turn_at.map(func(ix): return float(cum[maxi(int(ix) - 1, 0)]))
	var pts := PackedVector3Array()
	var k := 0
	var sd := 0.0
	var total: float = cum[cum.size() - 1]
	while sd <= total:
		while k < raw.size() - 2 and float(cum[k + 1]) < sd:
			k += 1
		var span: float = float(cum[k + 1]) - float(cum[k])
		pts.append(raw[k].lerp(raw[k + 1], (sd - float(cum[k])) / span if span > 0.001 else 0.0))
		sd += 1.0
	for i in pts.size():
		pts[i] = _ground(pts[i])
	var limit := PackedFloat32Array()
	limit.resize(pts.size())
	for i in pts.size():
		var v := 99.0
		for cs in corner_s:
			var dd: float = float(i) - float(cs)
			if dd > -9.0 and dd < 10.0:
				v = minf(v, TURN_SPEED + maxf(-dd - 3.0, 0.0) * 0.8)
		limit[i] = v
	report["turns"] = int(report.get("turns", 0)) + corner_s.size()
	return {"pts": pts, "limit": limit, "nodes": nodes}


# ------------------------------------------------------------------ the loop
func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var f := focus()
	var near: bool = f.distance_to(Vector3(40.0, 0.0, -10.0)) < ACTIVE_RANGE + 80.0
	for nm in people:
		var p: Dictionary = people[nm]
		var b = p["body"]
		if not is_instance_valid(b):
			continue
		var on: bool = b.visible and f.distance_to(b.global_position) < ACTIVE_RANGE
		p["anim"].set_process(on)                    # (people out of range cost nothing)
		if on and not Game.has_flag("p3_mist") and p["state"] == "routine":
			_routine(nm, p, delta)
	if near or not cars.is_empty():
		_traffic(delta)
	if Game.has_flag("p3_mist"):
		_panic(delta)
	_prompt_t -= delta
	if _prompt_t <= 0.0:
		_prompt_t = 0.3
		_update_prompts()
	_events(delta)
var _prompt_t := 0.0


func _events(delta: float) -> void:
	_event_t -= delta
	if _busy != "" or _event_t > 0.0:
		return
	_event_t = 0.25
	if _story_busy():
		return
	var outdoors: bool = world.has_method("_outdoors") and world._outdoors()
	if Game.has_flag("p3_stepped_out") and not Game.has_flag("lt_frank_done") and outdoors and Game.has_flag("p3_mist") \
			and not Game.has_flag("p3_back_inside"):
		if _frank_ready_t < 0.0:
			_frank_ready_t = 0.6                  # a breath after the Colossus scene hands control back
		_frank_ready_t -= 0.25
		if _frank_ready_t <= 0.0:
			_frank()
	elif Game.has_flag("lt_frank_done") and not Game.has_flag("lt_crash_done") and outdoors and Game.has_flag("p3_mist"):
		_crash()
	elif Game.has_flag("p3_fled_together") and not Game.has_flag("p3_in_market") and not Game.has_flag("lt_police_done") and outdoors:
		_police()
	elif Game.has_flag("c5_started") and not Game.has_flag("lt_joan_done") and outdoors and _player_near(Vector3(152.0, 0.2, -26.0), 38.0):
		_joan()
	elif Game.has_flag("c5_started") and not Game.has_flag("lt_window_done") and outdoors and world.expedition and world.expedition.active():
		_window()


func _begin(id: String) -> void:
	_busy = id
	(report["events"] as Array).append(id)
	# the threat director waits: no new creature while a scripted one is out
	var ex = world.get("expedition")
	if ex:
		var el := float(ex.st().get("elapsed", 0.0))
		ex._next_hunt = maxf(ex._next_hunt, el + 25.0)
		ex._next_roam = maxf(ex._next_roam, el + 25.0)


func _end(id: String) -> void:
	Game.set_flag("lt_%s_done" % id)
	_busy = ""
	_event_t = 4.0


func _free_when_unseen(n: Node3D, far := 30.0) -> void:
	while is_instance_valid(n) and _seen(n.global_position) and n.global_position.distance_to(world.player.global_position) < far:
		await get_tree().create_timer(0.3).timeout
	if is_instance_valid(n):
		_unregister(n)
		n.queue_free()


## A person leaving the game for good: out of the world's NPC tables too (saves walk them).
func _unregister(n: Node) -> void:
	for k in (world.animators as Dictionary).keys():
		var a = world.animators[k]
		if a == null or not is_instance_valid(a) or a.root == n:
			world.animators.erase(k)
			if world.faces.has(k):
				world.faces.erase(k)


func _move(n: Node3D, to: Vector3, secs: float, trans := Tween.TRANS_LINEAR) -> void:
	var tw := create_tween().set_trans(trans)
	tw.tween_property(n, "global_position", to, secs)
	await tw.finished


func _face(n: Node3D, dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() > 0.01:
		n.global_rotation.y = atan2(dir.x, dir.z)


# ------------------------------------------------------------------ 1. Frank and the Skitter
## One controller, both actors, in the player's view (they have just come out after the Colossus):
##   run   - Frank runs across the street ahead of them, a look back, a stumble
##   hunt  - the Skitter breaks from cover (a parked car, else the mist) at a scuttle and hisses
##   leap  - an arc onto him: he goes down on his back on the pavement, it lands straddling his chest
##   pin   - ~1.5 s: it tears at him, he thrashes, he screams
##   drag  - it grips his shoulders and runs into the mist, dragging him head-first, feet trailing; it speeds up
##   gone  - both removed only once out of sight or deep in the fog
## Every sound fires on its action. The Skitter wears its approved look (VeilCreatureLook.apply_skitter) and its own
## clips (VeilCreatureLook.skitter_anim, speed matched to the motion).
var frank_report := {"states": []}


func _fstate(s: String) -> void:
	(frank_report["states"] as Array).append(s)


## Frank lying on his back: feet at `feet`, head towards `head_dir` (flat), face up. Root slightly lifted so his
## back rests on the ground (the model's depth), never sunk in or floating.
func _lying(feet: Vector3, head_dir: Vector3) -> Transform3D:
	var y := head_dir.normalized()
	var x := y.cross(Vector3.UP).normalized()
	return Transform3D(Basis(x, y, Vector3.UP), feet + Vector3.UP * 0.12)


func _frank() -> void:
	if _busy != "":
		return
	if not people.has("Frank") or not is_instance_valid(people["Frank"]["body"]):
		Game.set_flag("lt_frank_done")
		return
	_begin("frank")
	var p: Dictionary = people["Frank"]
	var body: Node3D = p["body"]
	var a = p["anim"]
	# --- staging, from where the player is looking: the street ahead, ~11 m out
	var cam := world.get_viewport().get_camera_3d()
	var eye: Vector3 = cam.global_position if cam else world.player.global_position
	var fwd: Vector3 = (-cam.global_basis.z if cam else Vector3.FORWARD) * Vector3(1, 0, 1)
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	var pin := safe_point(_ground(world.player.global_position + fwd * 11.0))
	if not pin.is_finite():
		pin = _ground(world.player.global_position + fwd * 11.0)
	var start := _ground(pin + side * 13.0)
	var mid := _ground(pin + side * 5.0)
	frank_report["pin"] = pin
	# --- run: across the view, a look back, a stumble
	_fstate("run")
	body.visible = true
	body.global_transform = Transform3D(Basis(), start)
	a.set_process(true)
	a.set_seated(false)
	a.set_mood("scared")
	p["state"] = "event"
	a.walk_to([mid], 4.4)
	_say("lt_frank_help")
	while a.is_walking():
		await get_tree().process_frame
	a.face_towards(start)                              # a look back over his shoulder
	await get_tree().create_timer(0.3).timeout
	a.walk_to([pin], 3.2)                              # the stumble: he loses his pace
	# --- hunt: from cover, a fast scuttle and a hiss
	var cover := _cover_near(pin)
	if cover.distance_to(eye) < 6.0:
		cover = _ground(pin + fwd * 9.0 - side * 3.0)
	var sk := (load(SKITTER) as PackedScene).instantiate() as Node3D
	sk.name = "LT_Skitter"
	world.add_child(sk)
	VeilCreatureLook.apply_skitter(sk, cover.y)        # its approved look (not the pale raw atlas)
	for co in sk.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0
	if sk is CollisionObject3D:
		(sk as CollisionObject3D).collision_layer = 0
		(sk as CollisionObject3D).collision_mask = 0
	sk.global_position = cover
	var crouch := _ground(pin - side * 2.6 + fwd * 0.6)    # where it springs from: behind him on his line
	_face(sk, crouch - cover)
	_fstate("hunt")
	var run_d := cover.distance_to(crouch)
	var run_t := clampf(run_d / 7.5, 0.35, 1.4)
	VeilCreatureLook.skitter_anim(sk, "scuttle", run_d / run_t)
	_snd("sk_fury", cover + Vector3.UP * 0.4, 3.0)      # the hiss, as it breaks cover
	if world.has_method("focus_shot"):
		world.focus_shot(pin + Vector3.UP * 0.6, 42.0, 0.7, 3.4)   # the view goes to it (the existing focus)
	var hunt := create_tween()
	hunt.tween_method(func(k: float):
		if is_instance_valid(sk):
			sk.global_position = _ground(cover.lerp(crouch, k)), 0.0, 1.0, run_t)
	await hunt.finished
	# --- leap: an arc onto his back; he goes down face up, head away from it; it lands astride his chest
	_fstate("leap")
	var d := (pin - crouch) * Vector3(1, 0, 1)
	d = d.normalized() if d.length() > 0.1 else -side
	a.walk_to([], 0.0)
	var feet := _ground(body.global_position)
	var chest := feet + d * 1.15
	var land := _ground(feet + d * 0.95)
	_face(sk, d)
	VeilCreatureLook.skitter_anim(sk, "attack")
	_snd("ss_rush", crouch + Vector3.UP * 0.5, 3.0)
	var from := sk.global_position
	var leap := create_tween()
	leap.tween_method(func(k: float):
		if is_instance_valid(sk):
			sk.global_position = from.lerp(land, k) + Vector3.UP * (sin(k * PI) * 1.0 + 0.3 * k)
			sk.rotation.x = lerpf(-0.35, 0.25, k), 0.0, 1.0, 0.36)
	await leap.finished
	# impact: both together, now
	_fstate("impact")
	a.set_process(false)                               # (the scene owns his body from here)
	var down := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	down.tween_property(body, "global_transform", _lying(feet, d), 0.22)
	_snd("ss_impact", chest, 4.0)
	Sfx.play("hurt", chest + Vector3.UP * 0.4, 4.0, 0.85)    # his cry, on the hit
	await down.finished
	sk.rotation.x = 0.0
	sk.global_position = land + Vector3.UP * 0.3
	if world.has_method("_shake") and cam:
		world._shake(cam, 0.2, 0.02)
	frank_report["skitter_to_chest_m"] = Vector2(sk.global_position.x - chest.x, sk.global_position.z - chest.z).length()
	frank_report["frank_root_above_ground_m"] = body.global_position.y - _ground(feet).y
	# --- pin: ~1.5 s, both moving
	_fstate("pin")
	var hold_snd := _snd("ss_hold", chest, 0.0)
	var lie := _lying(feet, d)
	var t := 0.0
	var next_scream := 0.5
	while t < 1.5:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		body.global_transform = Transform3D(lie.basis.rotated(d, sin(t * 21.0) * 0.09), lie.origin)
		sk.global_position = land + Vector3.UP * (0.3 + absf(sin(t * 13.0)) * 0.06)
		if fmod(t, 0.45) < dt:
			VeilCreatureLook.skitter_anim(sk, "attack", 0.0, 0.05)    # it tears at him again
		if t >= next_scream:
			next_scream = 99.0
			Sfx.play("hurt", chest + Vector3.UP * 0.4, 2.0, 1.15)
	# --- drag: it turns, grips his shoulders and runs into the mist; he trails feet-first behind it
	_fstate("drag")
	_stop(hold_snd)
	_say("lt_eddie_frank")
	var away := (pin - eye) * Vector3(1, 0, 1)
	away = (away.normalized() + d * 0.4).normalized()
	_face(sk, away)
	_snd("ss_retreat", chest, 2.0)
	var move_snd := _snd("sk_move_loop", chest, -2.0)
	var travelled := 0.0
	var speed := 1.2
	var head_gap := 0.55                               # its rear legs at his shoulders
	var max_sep := 0.0
	var span := 0.0
	while travelled < 60.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		speed = minf(speed + 5.5 * dt, 8.0)             # it accelerates away
		travelled += speed * dt
		span += dt
		var lead := _ground(land + away * travelled)
		sk.global_position = lead + Vector3.UP * 0.05
		if move_snd and is_instance_valid(move_snd):
			move_snd.global_position = lead + Vector3.UP * 0.4     # the scuttle goes with it
		VeilCreatureLook.skitter_anim(sk, "scuttle", speed)
		var head := lead - away * head_gap
		var f := head - away * 1.75
		var lying := _lying(_ground(f), away)
		body.global_transform = Transform3D(lying.basis.rotated(away, sin(span * 9.0) * 0.06), lying.origin)
		var sep := Vector2(sk.global_position.x - head.x, sk.global_position.z - head.z).length()
		max_sep = maxf(max_sep, absf(sep - head_gap))
		var gone_far := lead.distance_to(world.player.global_position) > 32.0
		if travelled > 22.0 and (gone_far or not _seen(lead, 0.4)):
			break
	frank_report["drag_m"] = travelled
	frank_report["drag_attach_error_m"] = max_sep
	# --- gone: out of sight / deep in the fog; only now are they removed
	_fstate("gone")
	_stop(move_snd)
	frank_report["loops_stopped"] = not (is_instance_valid(move_snd) and move_snd.playing) and not (is_instance_valid(hold_snd) and hold_snd.playing)
	body.visible = false
	p["state"] = "taken"
	_unregister(body)
	sk.queue_free()
	report["frank_pin"] = pin
	_end("frank")


## Somewhere to hide behind near `at` on the far side of the street from the player: a parked vehicle if any.
func _cover_near(at: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := 14.0
	for n in world.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if not (nm.begins_with("VEH_") or nm.contains("Sedan") or nm.contains("Pickup") or nm.contains("Van")) or n == world.sedan:
			continue
		var d := (n as Node3D).global_position.distance_to(at)
		if d < bd and d > 3.0:
			bd = d
			best = (n as Node3D).global_position
	if best.is_finite():
		var away: Vector3 = (best - world.player.global_position) * Vector3(1, 0, 1)
		return _ground(best + away.normalized() * 1.6)   # behind it, as seen from the player
	return _ground(at + Vector3(4.0, 0, -6.0))


# ------------------------------------------------------------------ 2. panic on the road: the crash
func _crash() -> void:
	if _busy != "":
		return
	_begin("crash")
	var pl: Vector3 = world.player.global_position
	var x0 := pl.x - 70.0
	var x1 := pl.x + 70.0
	var first := _spawn_car(_lane(x0, x1, EAST_LANE), 15.0, 0)
	if not first.is_empty():
		first["scripted"] = true
	await get_tree().create_timer(1.2).timeout
	var path := _lane(x0, pl.x + 28.0, EAST_LANE)
	var second := _spawn_car(path, 15.0, 1)
	if second.is_empty():
		_end("crash")
		return
	second["scripted"] = true
	second["crash"] = true
	# the swerve: near the end of its run it jinks round something unseen, onto the verge
	var car: Node3D = second["node"]
	var wait := 0.0
	while is_instance_valid(car) and float(second["s"]) < float(second.get("total", 99.0)) - 12.0 and wait < 12.0:
		await get_tree().process_frame
		wait += get_process_delta_time()
	if not is_instance_valid(car) or wait >= 12.0:
		second.erase("crash")                       # held up (something in the road): it just drives on
		_end("crash")
		return
	Sfx.play("door_close", car.global_position, 2.0, 0.35)        # tyres / the brakes
	_snd("ev_unknown", car.global_position + Vector3(0, 1, -10), -6.0)
	var tw := create_tween()
	tw.tween_method(func(k: float): second["swerve"] = sin(k * PI * 1.5) * 0.55, 0.0, 1.0, 0.8)
	await tw.finished
	cars.erase(second)
	# into the roadside: a short shove to the kerb side, a jolt, stopped
	var hit := _ground(Vector3(car.global_position.x + 3.0, 0.2, road_z + 4.4))   # off its own (right-hand) kerb
	var stop := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	stop.tween_property(car, "global_position", hit + Vector3(0, 0.02, 0), 0.35)
	stop.parallel().tween_property(car, "rotation", car.rotation + Vector3(0.05, -0.5, 0.03), 0.35)
	await stop.finished
	_snd("ev_metal", car.global_position, 4.0)
	Sfx.play("door_close", car.global_position, 6.0, 0.5)
	car.name = "LT_AbandonedCar"
	Game.world_state["lt_crash"] = [car.global_position.x, car.global_position.y, car.global_position.z, car.global_rotation.y, 1]
	# the driver gets out and runs (an anonymous civilian), into the mist
	await get_tree().create_timer(0.8).timeout
	Sfx.play("door_open", car.global_position, 0.0, 1.2)
	var seated = second.get("driver")
	if seated and is_instance_valid(seated):
		_unregister(seated)
		seated.queue_free()                         # (the one at the wheel is the one who gets out)
	var drv: Node3D = world._spawn_npc(load(CASHIER), load(FACES + "T_Face_Cashier.png"), world,
		_ground(car.global_transform * Vector3(-1.5, 0, -0.3)), 0.0, "LT_Driver")
	_vary(drv)
	var da = world.animators["LT_Driver"]
	da.set_mood("scared")
	da.walk_to([_ground(drv.global_position + Vector3(-18.0, 0, -6.0))], 3.6)
	report["crash_at"] = car.global_position
	_end("crash")
	await get_tree().create_timer(6.0).timeout
	_free_when_unseen(drv, 30.0)


# ------------------------------------------------------------------ 3. the officer and the evacuation
func _police() -> void:
	if _busy != "":
		return
	if not people.has("Officer") or not is_instance_valid(people["Officer"]["body"]) or not people["Officer"]["body"].visible:
		Game.set_flag("lt_police_done")
		return
	_begin("police")
	var o: Dictionary = people["Officer"]
	var ob: Node3D = o["body"]
	var oa = o["anim"]
	o["state"] = "event"
	oa.set_mood("scared")
	oa.face_towards(Vector3(ob.global_position.x - 20.0, 0, road_z))
	oa.talk(2.0)
	_say("lt_officer_go")
	var c1 := _spawn_car(_lane(ob.global_position.x - 60.0, MAIN_X.y, EAST_LANE), 13.0, 0)
	await get_tree().create_timer(1.0).timeout
	var c2 := _spawn_car(_lane(ob.global_position.x - 60.0, MAIN_X.y, EAST_LANE), 12.0, 1)
	for c in [c1, c2]:
		if not c.is_empty():
			c["scripted"] = true
	# the second brakes hard and swerves as it reaches him; he waves it on
	if not c2.is_empty():
		var car: Node3D = c2["node"]
		while is_instance_valid(car) and car.global_position.x < ob.global_position.x - 8.0:
			await get_tree().process_frame
		var sp: float = c2["speed"]
		Sfx.play("door_close", car.global_position, 0.0, 0.4)
		var tw := create_tween()
		tw.tween_method(func(k: float):
			c2["speed"] = lerpf(sp, 3.0, sin(k * PI))
			c2["swerve"] = sin(k * PI * 2.0) * 0.25, 0.0, 1.0, 1.4)
		oa.talk(1.4)
		await tw.finished
		c2.erase("swerve")
	# a sound from the mist: he turns; takes the nearest person with him and runs
	var src := ob.global_position + Vector3(25.0, 2.0, -20.0)
	_snd("ev_unknown", src, 0.0)
	oa.face_towards(src)
	await get_tree().create_timer(1.0).timeout
	var flee := _ground(ob.global_position + Vector3(30.0, 0, 0))
	oa.walk_to([flee], 3.8)
	if people.has("Civilian_B") and is_instance_valid(people["Civilian_B"]["body"]):
		var cb: Dictionary = people["Civilian_B"]
		cb["body"].visible = true
		cb["state"] = "event"
		cb["body"].global_position = _ground(ob.global_position + Vector3(-1.5, 0, -1.0))
		cb["anim"].set_mood("scared")
		cb["anim"].walk_to([flee + Vector3(-1.0, 0, 1.0)], 3.6)
		_free_when_unseen(cb["body"], 35.0)
	_free_when_unseen(ob, 35.0)
	_end("police")


# ------------------------------------------------------------------ 4. Joan and the Hound
func _joan() -> void:
	if _busy != "":
		return
	if not people.has("Joan") or not is_instance_valid(people["Joan"]["body"]):
		_person("Joan", CASHIER, "T_Face_Cashier.png", Vector3(152.0, 0.2, -27.5), Color(1.0, 0.85, 0.85))
	_begin("joan")
	var p: Dictionary = people["Joan"]
	var jb: Node3D = p["body"]
	var ja = p["anim"]
	var door := _ground(Vector3(152.0, 0.2, -25.7))
	Sfx.play("door_close", door + Vector3.UP, 6.0, 0.8)           # a door slams
	await get_tree().create_timer(0.6).timeout
	jb.global_position = door
	jb.visible = true
	ja.set_process(true)
	ja.set_mood("scared")
	p["state"] = "event"
	_say("lt_joan_scream")
	# out, a look back, then round the building towards the trees behind it (a collision-checked route)
	var trees := _ground(Vector3(164.0, 0.2, -52.0))
	var route: Array = world.npc_route(world, door, trees, null, true)
	if route.is_empty():
		route = [_ground(door + Vector3(8.0, 0, 2.0)), trees]
	ja.walk_to([_ground(door + Vector3(0, 0, 2.0))], 3.0)
	while ja.is_walking():
		await get_tree().process_frame
	ja.face_towards(door + Vector3(-6.0, 0, -4.0))
	await get_tree().create_timer(0.4).timeout
	ja.walk_to(route, 4.4)
	# the Hound bursts round the corner and follows her line (always on her path, a few metres back)
	var h := (load(HOUND) as PackedScene).instantiate() as Node3D
	h.name = "LT_Hound"
	world.add_child(h)
	for co in h.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0
	if h is CollisionObject3D:
		(h as CollisionObject3D).collision_layer = 0
	var trail: Array = [door + Vector3(-7.0, 0, -3.0)]
	h.global_position = _ground(trail[0])
	_clip(h, "Run", 1.3)
	_snd("hound_bark", h.global_position + Vector3.UP, 4.0)
	var run_snd := _snd("hound_run_loop", h.global_position, -2.0)
	var t := 0.0
	while t < 12.0 and is_instance_valid(h) and is_instance_valid(jb):
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		trail.append(jb.global_position)
		var goal: Vector3 = trail[maxi(trail.size() - 26, 0)]     # about 0.4 s behind her, on her line
		var d := goal - h.global_position
		if d.length() > 0.05:
			_face(h, d)
			h.global_position = _ground(h.global_position + d.limit_length(6.5 * dt))
		if not ja.is_walking() and (not _seen(jb.global_position) or jb.global_position.distance_to(world.player.global_position) > 40.0):
			break
	# out of sight among the trees: a scream, far off; her fate unknown
	await get_tree().create_timer(1.0).timeout
	_snd("ev_unknown", trees + Vector3.UP * 1.5, -4.0)
	Sfx.play("hurt", trees + Vector3.UP * 1.5, -8.0, 1.6)
	_stop(run_snd)
	jb.visible = false
	p["state"] = "gone"
	_free_when_unseen(h, 20.0)
	report["joan_route"] = route.size()
	_end("joan")


# ------------------------------------------------------------------ 5. the upstairs window
func _window() -> void:
	var hs := world.get_node_or_null("Residential/Houses")
	if hs == null:
		return
	var pl: Vector3 = world.player.global_position
	for h in hs.get_children():
		var info: Dictionary = (h as Node).get_meta("veil_house", {})
		if not info.has("rooms"):
			continue
		var hn := h as Node3D
		var d := Vector2(hn.global_position.x - pl.x, hn.global_position.z - pl.z).length()
		if d < 12.0 or d > 26.0:
			continue
		for r in info["rooms"]:
			if float(r.get("floor_y", 0.0)) < 2.0:
				continue
			var rc: Array = r["rect"]
			var lp := hn.to_local(pl)
			# the room's wall facing the player; the figure half a metre inside it
			var cx := clampf(lp.x, float(rc[0]) + 0.6, float(rc[2]) - 0.6)
			var cz := clampf(lp.z, float(rc[1]) + 0.6, float(rc[3]) - 0.6)
			var at := hn.to_global(Vector3(cx, float(r["floor_y"]), cz))
			if not _seen(at, 1.6):
				continue
			await _window_scene(at)
			return


func _window_scene(at: Vector3) -> void:
	if _busy != "":
		return
	_begin("window")
	var fig: Node3D = world._spawn_npc(load(CASHIER), load(FACES + "T_Face_Cashier.png"), world, at, 0.0, "LT_Window")
	_vary(fig)                     # half seen, against the light
	fig.global_position = at
	var fa = world.animators["LT_Window"]
	fa.face_towards(world.player.global_position)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.4
	lamp.omni_range = 4.0
	world.add_child(lamp)
	lamp.global_position = at + Vector3.UP * 2.2 - (world.player.global_position - at).normalized() * Vector3(1, 0, 1) * 1.2
	await get_tree().create_timer(1.2).timeout
	fa.talk(2.4)                                          # waving, calling (unheard through the glass)
	await get_tree().create_timer(2.0).timeout
	# behind them, something: the light stutters, dies; a muffled thump; nothing moves again
	for k in [0.2, 1.4, 0.0, 1.1, 0.0]:
		lamp.light_energy = k
		await get_tree().create_timer(0.09).timeout
	Sfx.play("door_close", at + Vector3.UP, -8.0, 0.4)
	fig.visible = false
	await get_tree().create_timer(0.5).timeout
	lamp.queue_free()
	report["window_at"] = at
	_end("window")


## A cinematic is about to be shot from `cam` looking along `dirs` (world directions): anyone standing in front of it
## within `radius` (Frank on the shop sidewalk, a neighbour) is moved out of the frame - beside / behind the camera,
## on safe ground - and stops where they are. Returns the names moved (tests).
func clear_shot(cam_pos: Vector3, dirs: Array, radius := 16.0) -> Array:
	var moved: Array = []
	for nm in people:
		var p: Dictionary = people[nm]
		var b = p.get("body")
		if not is_instance_valid(b) or not (b as Node3D).visible:
			continue
		var at: Vector3 = (b as Node3D).global_position
		var to := (at - cam_pos) * Vector3(1, 0, 1)
		if to.length() > radius or to.length() < 0.01:
			continue
		var in_view := false
		for d in dirs:
			var f: Vector3 = (d as Vector3) * Vector3(1, 0, 1)
			if f.length() > 0.01 and f.normalized().dot(to.normalized()) > cos(deg_to_rad(55.0)):
				in_view = true
		if not in_view:
			continue
		var fwd: Vector3 = ((dirs[0] as Vector3) * Vector3(1, 0, 1)).normalized()
		var side := fwd.cross(Vector3.UP).normalized() * (1.0 if fwd.cross(Vector3.UP).dot(to) >= 0.0 else -1.0)
		var spot := Vector3.INF
		for c in [cam_pos - fwd * 3.0 + side * 2.5, cam_pos - fwd * 4.5 - side * 2.5, cam_pos - fwd * 6.0, cam_pos + side * 5.0 - fwd * 2.0]:
			var s := safe_point(_ground(c))
			if s.is_finite():
				spot = s
				break
		if not spot.is_finite():
			(b as Node3D).visible = false                # nowhere safe behind: out of sight for the shot
			p["hidden_for_shot"] = true
		else:
			if p.get("anim"):
				p["anim"].walk_to([], 1.0)               # stop where it stands (no walking back into the shot)
			(b as Node3D).global_position = spot
			if p.get("anim") and p["anim"].has_method("face_towards"):
				p["anim"].face_towards(cam_pos + fwd * 10.0)
		if String(p.get("state", "")) == "routine":
			p["state"] = "shot"                          # out of the routine until the shot is over
		moved.append(nm)
	report["shot_cleared"] = moved
	return moved


func restore_after_shot() -> void:
	for nm in people:
		if String(people[nm].get("state", "")) == "shot":
			people[nm]["state"] = "routine"
		if people[nm].get("hidden_for_shot", false):
			people[nm].erase("hidden_for_shot")
			if is_instance_valid(people[nm]["body"]):
				(people[nm]["body"] as Node3D).visible = true
