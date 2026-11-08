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
		or world.get_node_or_null("Struggle") != null or not world.player.visible and not world.in_car


func _say(id: String) -> void:
	if Dialogue.data.has(id):
		Dialogue.say(id, false, false)


func _snd(id: String, at: Vector3, db := 0.0) -> void:
	if Sfx.bank(id):
		Sfx.bank_at(id, at, db, 10.0)
	else:
		Sfx.play(id, at, db)


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


## The nearest spot to `p` a person can stand on: not on the road, nothing solid there (a parked car, a bin, a
## wall). Tries the spot itself, then rings round it out to 2.5 m. INF = none.
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
			if _on_road(c):
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
	var pl: Vector3 = world.player.global_position
	# he comes running along the street in front of the player: from the east, out of the mist
	var along := Vector3(-1, 0, 0)
	var start := _ground(Vector3(pl.x + 16.0, 0.2, road_z + 2.5))
	var pin := _ground(Vector3(pl.x + 5.0, 0.2, road_z + 2.5))
	body.visible = true
	body.global_position = start
	a.set_mood("scared")
	p["state"] = "event"
	_say("lt_frank_help")
	_snd("pl_effort", start + Vector3.UP, -6.0)
	a.walk_to([pin + Vector3(2.5, 0, 0)], 4.2)
	while a.is_walking():
		await get_tree().process_frame
	# a look back; he stumbles
	a.face_towards(start)
	await get_tree().create_timer(0.35).timeout
	a.walk_to([pin], 3.0)
	# the Skitter: from behind a parked car (or the kerb's shadow) on the far side, a low run, then the leap
	var cover := _cover_near(pin)
	var sk := (load(SKITTER) as PackedScene).instantiate() as Node3D
	sk.name = "LT_Skitter"
	world.add_child(sk)
	for co in sk.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0
	if sk is CollisionObject3D:
		(sk as CollisionObject3D).collision_layer = 0
	sk.global_position = cover
	_face(sk, pin - cover)
	_clip(sk, "Scuttle_Fast", 1.3)
	_snd("sk_prepare", cover + Vector3.UP * 0.5, 2.0)
	var crouch := cover.lerp(pin, 0.45)
	crouch = _ground(crouch)
	await _move(sk, crouch, 0.3)
	_clip(sk, "Attack_Lunge", 1.4)
	_snd("ss_rush", crouch + Vector3.UP * 0.5, 3.0)
	var leap := create_tween()
	leap.tween_method(func(k: float):
		if is_instance_valid(sk):
			var q := crouch.lerp(pin, k)
			sk.global_position = q + Vector3.UP * sin(k * PI) * 1.1, 0.0, 1.0, 0.42)
	await leap.finished
	# impact: he goes down, pinned
	_snd("ss_impact", pin + Vector3.UP * 0.5, 4.0)
	_snd("hurt", pin + Vector3.UP, 2.0)
	a.walk_to([], 0.0)
	a.set_process(false)
	var lie := Transform3D(Basis(Vector3.UP, body.global_rotation.y) * Basis(Vector3.RIGHT, -PI * 0.5), pin + Vector3.UP * 0.18)
	var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(body, "global_transform", lie, 0.3)
	await fall.finished
	sk.global_position = pin + Vector3.UP * 0.25
	_clip(sk, "Attack_Lunge", 2.0)
	_snd("ss_hold", pin + Vector3.UP * 0.5, 0.0)
	# the struggle (short)
	var t := 0.0
	while t < 1.4:
		await get_tree().process_frame
		t += get_process_delta_time()
		body.global_position = pin + Vector3.UP * 0.18 + Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03))
	_say("lt_eddie_frank")
	# dragged off into the mist, the Skitter backing away with him (always touching)
	var away: Vector3 = _ground(pin + Vector3(0, 0, -9.0) + along * -6.0)
	_clip(sk, "Crawl", -1.6)
	_snd("ss_retreat", pin + Vector3.UP * 0.5, 0.0)
	var drag := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	drag.tween_method(func(k: float):
		if is_instance_valid(sk) and is_instance_valid(body):
			var q: Vector3 = _ground(pin.lerp(away, k))
			sk.global_position = q + Vector3.UP * 0.05 + (away - pin).normalized() * 0.6
			body.global_position = q + Vector3.UP * 0.18, 0.0, 1.0, 3.2)
	await drag.finished
	body.visible = false
	p["state"] = "taken"
	_free_when_unseen(sk, 25.0)
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
	_snd("hound_run_loop", h.global_position, -2.0)
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
