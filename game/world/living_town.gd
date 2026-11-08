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
	return world.player.global_position.distance_to(p) < d


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


## A clothing / skin colour variation on a reused model (its own materials, multiplied): an anonymous person.
func _tint(n: Node, col: Color) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).get_surface_override_material_count():
			var src = (mi as MeshInstance3D).get_active_material(s)
			if src is StandardMaterial3D:
				var d := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = d.albedo_color * col
				(mi as MeshInstance3D).set_surface_override_material(s, d)


# ------------------------------------------------------------------ people
func _person(nm: String, model: String, face: String, at: Vector3, tint := Color.WHITE) -> Node3D:
	var body: Node3D = world._spawn_npc(load(model), load(FACES + face), world, _ground(at), 0.0, nm)
	if tint != Color.WHITE:
		_tint(body, tint)
	var a = world.animators[nm]
	people[nm] = {"body": body, "anim": a, "route": [], "i": 0, "wait": 0.0, "state": "routine"}
	report["people"] = people.size()
	return body


func _spawn_people() -> void:
	var sw := 5.4                                   # the shop-row sidewalk (z), between the doors and the kerb
	_person("Frank", FRANK, "T_Face_Frank.png", Vector3(8.0, 0.2, sw))
	people["Frank"]["route"] = [Vector3(8.0, 0.2, sw), Vector3(21.0, 0.2, sw)]
	_person("Civilian_A", CASHIER, "T_Face_Cashier.png", Vector3(30.0, 0.2, sw), Color(0.75, 0.85, 1.0))
	people["Civilian_A"]["route"] = [Vector3(30.0, 0.2, sw), Vector3(48.0, 0.2, sw)]
	_person("Civilian_B", FRANK, "T_Face_Frank.png", Vector3(26.0, 0.2, -23.0), Color(0.85, 0.75, 0.7))
	people["Civilian_B"]["route"] = [Vector3(26.0, 0.2, -23.0), Vector3(40.0, 0.2, -23.0)]
	_person("Officer", POLICE, "T_Face_Police_Officer.png", Vector3(60.0, 0.2, sw))
	people["Officer"]["route"] = []                # stands at the corner, watching the traffic
	_person("Joan", CASHIER, "T_Face_Cashier.png", Vector3(147.0, 0.2, -24.5), Color(1.0, 0.85, 0.85))
	people["Joan"]["route"] = [Vector3(147.0, 0.2, -24.5), Vector3(152.0, 0.2, -24.8)]
	for k in people:
		var b: Node3D = people[k]["body"]
		b.global_position = _ground(b.global_position)


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
	p["i"] = (int(p["i"]) + 1) % route.size()
	a.walk_to([route[p["i"]]], 1.15)
	p["wait"] = randf_range(2.5, 6.0)               # a pause at each end: a look in a window, a phone, the street


## The Veil: routines stop; fear; flight (staggered so the street empties over ~20 s, never at once).
func _panic(delta: float) -> void:
	_panic_t += delta
	var plan := {"Civilian_A": [1.5, "building", Vector3(37.5, 0.2, 6.6)], "Joan": [3.0, "building", Vector3(152.0, 0.2, -26.6)],
		"Civilian_B": [7.0, "fog", Vector3(70.0, 0.2, -23.0)], "Frank": [0.5, "freeze", Vector3.ZERO],
		"Officer": [0.0, "stay", Vector3.ZERO]}
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
		(co as CollisionObject3D).collision_layer = 0   # background traffic: no physics; it stops for the player
		(co as CollisionObject3D).collision_mask = 0
	return car


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
	var c := {"node": car, "path": path, "s": 0.0, "speed": speed, "lane": i}
	_place_car(c)
	cars.append(c)
	report["cars_spawned"] = int(report["cars_spawned"]) + 1
	return c


func _place_car(c: Dictionary) -> void:
	var path: PackedVector3Array = c["path"]
	var total := (path.size() - 1) * path[0].distance_to(path[1])
	var s := clampf(float(c["s"]), 0.0, total - 0.01)
	var seg := path[0].distance_to(path[1])
	var k := int(s / seg)
	var t := (s - k * seg) / seg
	var p := path[k].lerp(path[mini(k + 1, path.size() - 1)], t)
	var ahead := path[mini(k + 1, path.size() - 1)] - path[k]
	var car: Node3D = c["node"]
	var yaw := atan2(ahead.x, ahead.z)
	if c.has("swerve"):
		yaw += float(c["swerve"])
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.02, 0))
	c["total"] = total


func _traffic(delta: float) -> void:
	var veil := Game.has_flag("p3_mist")
	# a new car now and then (before the Veil), one per lane at a time, entering out of view
	_car_t -= delta
	if not veil and _car_t <= 0.0 and cars.size() < 3:
		_car_t = randf_range(6.0, 12.0)
		var which := int(report["cars_spawned"]) % 3
		var path: PackedVector3Array
		match which:
			0:
				path = _lane(MAIN_X.x, MAIN_X.y, -1.8)                      # through town, eastbound
			1:
				path = _lane(MAIN_X.y, MAIN_X.x, 1.8)                       # westbound, past the supermarket
			2:
				path = _lane(60.0, MAIN_X.y, -1.8)                          # out to the east edge of town
		if path.size() > 2 and not _seen(path[0]) and not cars.any(func(c): return c["lane"] == which):
			_spawn_car(path, randf_range(9.0, 12.0), which)
	var keep: Array = []
	for c in cars:
		var car: Node3D = c["node"]
		if not is_instance_valid(car):
			continue
		var sp: float = float(c["speed"]) * (1.7 if veil and not c.has("scripted") else 1.0)
		# stops for the player standing in the road (it never runs anyone over)
		var to_p: Vector3 = world.player.global_position - car.global_position
		var fwd := car.global_basis.z
		if not world.in_car and to_p.dot(fwd) > 0.0 and to_p.dot(fwd) < 9.0 and (to_p - fwd * to_p.dot(fwd)).length() < 1.6:
			sp = 0.0
		c["s"] = float(c["s"]) + sp * delta
		_place_car(c)
		if float(c["s"]) >= float(c["total"]) - 0.1 and not c.has("crash"):
			if not _seen(car.global_position):
				car.queue_free()                    # gone round the far end, out of view
				continue
			c["s"] = float(c["total"]) - 0.1        # waits at the end of its lane until it is out of view
		keep.append(c)
	cars = keep


# ------------------------------------------------------------------ the loop
func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var near: bool = world.player.global_position.distance_to(Vector3(40.0, 0.0, -10.0)) < ACTIVE_RANGE + 80.0
	for nm in people:
		var p: Dictionary = people[nm]
		var b = p["body"]
		if not is_instance_valid(b):
			continue
		var on: bool = near and b.visible
		p["anim"].set_process(on)                    # (people out of range cost nothing)
		if on and not Game.has_flag("p3_mist") and p["state"] == "routine":
			_routine(nm, p, delta)
	if near or not cars.is_empty():
		_traffic(delta)
	if Game.has_flag("p3_mist"):
		_panic(delta)
	_events(delta)


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
	_begin("crash")
	var pl: Vector3 = world.player.global_position
	var x0 := pl.x - 70.0
	var x1 := pl.x + 70.0
	var first := _spawn_car(_lane(x0, x1, -1.8), 15.0, 0)
	if not first.is_empty():
		first["scripted"] = true
	await get_tree().create_timer(1.2).timeout
	var path := _lane(x0, pl.x + 28.0, -1.8)
	var second := _spawn_car(path, 15.0, 1)
	if second.is_empty():
		_end("crash")
		return
	second["scripted"] = true
	second["crash"] = true
	# the swerve: near the end of its run it jinks round something unseen, onto the verge
	var car: Node3D = second["node"]
	while is_instance_valid(car) and float(second["s"]) < float(second.get("total", 99.0)) - 12.0:
		await get_tree().process_frame
	Sfx.play("door_close", car.global_position, 2.0, 0.35)        # tyres / the brakes
	_snd("ev_unknown", car.global_position + Vector3(0, 1, -10), -6.0)
	var tw := create_tween()
	tw.tween_method(func(k: float): second["swerve"] = sin(k * PI * 1.5) * 0.55, 0.0, 1.0, 0.8)
	await tw.finished
	cars.erase(second)
	# into the roadside: a short shove to the kerb side, a jolt, stopped
	var hit := _ground(Vector3(car.global_position.x + 3.0, 0.2, road_z - 5.2))
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
	var drv: Node3D = world._spawn_npc(load(CASHIER), load(FACES + "T_Face_Cashier.png"), world,
		_ground(car.global_transform * Vector3(1.4, 0, 0)), 0.0, "LT_Driver")
	_tint(drv, Color(0.8, 0.8, 0.9))
	var da = world.animators["LT_Driver"]
	da.set_mood("scared")
	da.walk_to([_ground(drv.global_position + Vector3(-18.0, 0, -6.0))], 3.6)
	report["crash_at"] = car.global_position
	_end("crash")
	await get_tree().create_timer(6.0).timeout
	_free_when_unseen(drv, 30.0)


# ------------------------------------------------------------------ 3. the officer and the evacuation
func _police() -> void:
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
	var c1 := _spawn_car(_lane(ob.global_position.x - 60.0, MAIN_X.y, 1.8), 13.0, 0)
	await get_tree().create_timer(1.0).timeout
	var c2 := _spawn_car(_lane(ob.global_position.x - 60.0, MAIN_X.y, -1.8), 12.0, 1)
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
	_begin("window")
	var fig: Node3D = world._spawn_npc(load(CASHIER), load(FACES + "T_Face_Cashier.png"), world, at, 0.0, "LT_Window")
	_tint(fig, Color(0.35, 0.35, 0.4))                     # half seen, against the light
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
