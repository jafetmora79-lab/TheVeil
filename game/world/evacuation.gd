extends Node
## THE VEIL - displayed Chapter 10: the supermarket evacuation as ONE directed sequence (owner brief, 2026-11-22). Created by chapter9.gd; chapter9.gd keeps the preparation, the flags, the rendezvous.
##
## PREP -> WARNING -> APPROACH -> PULL -> EVACUATE_AND_WALT -> RETURN_TO_PUSH -> HALF_PUSH -> MARCUS_ATTACK -> CHOICE -> SAVED / LOST -> STAFF_EXIT -> REAR_EXIT -> REGROUP
##
## One controller owns the player (locomotion off, physics off, camera written only by `_process` through `_look`) from the instant the last preparation conversation ends until REGROUP. The only player
## inputs are: the click struggle to pull the shelf (PULL), E in CHOICE, and the optional rescue struggle. Everything else is directed along routes that are swept against the real colliders with the
## actor's own radius; a blocked actor waits, re-routes, and finally reports (`report["failures"]`) before the recovery places it (only out of the camera's sight).
##
## Floor plan (supermarket-local; every number below is a named marker, validated by game/tests/fall_routes_test.gd):
##   the central opening (x 7.6..9.2, wall z 14.3), the staff door (15.0, 14.2), the rear exterior exit (8.0, 17.45) are three separate places; the aisle slides along X from CLOSED_X (across the opening) to OPEN_X.

const HOUND_MUSIC := "res://game/audio/library/music_hound_chase_LOOP.wav"
const LAYER_MUSIC := "res://game/audio/library/music_skitter_chase_LOOP.wav"

enum Phase { IDLE, PREP, WARNING, APPROACH, PULL, EVACUATE_AND_WALT, RETURN_TO_PUSH, HALF_PUSH, MARCUS_ATTACK, CHOICE, SAVED, LOST, STAFF_EXIT, REAR_EXIT, REGROUP, DONE }

## What each phase owns, what the player may do, where the camera looks and what has to be true to advance (also printed / saved with the phase). Recovery is in the phase's own code.
const PHASES := {
	Phase.PREP: {"actors": "player", "doors": "", "input": "none", "camera": "forward", "advance": "controller owns the player (synchronously)"},
	Phase.WARNING: {"actors": "player, hounds", "doors": "", "input": "none", "camera": "front glass", "advance": "three hounds revealed at the glass"},
	Phase.APPROACH: {"actors": "all", "doors": "", "input": "none", "camera": "route look-ahead", "advance": "player + Marcus at the pulling markers, stopped, facing the shelf; the queue formed; Sarah risen"},
	Phase.PULL: {"actors": "player, Marcus, shelf", "doors": "", "input": "click struggle", "camera": "hands and shelf end", "advance": "shelf fully open"},
	Phase.EVACUATE_AND_WALT: {"actors": "Eddie, Ruth, Sarah, Walt, hounds, player, Marcus", "doors": "rear exit, front doors", "input": "none", "camera": "Walt + hound A", "advance": "queue clear of the opening, Walt's attack done, hound C ready"},
	Phase.RETURN_TO_PUSH: {"actors": "player, Marcus", "doors": "", "input": "none", "camera": "route look-ahead", "advance": "both at the pushing markers, facing the shelf"},
	Phase.HALF_PUSH: {"actors": "player, Marcus, shelf", "doors": "", "input": "none", "camera": "hands and shelf end", "advance": "shelf at half"},
	Phase.MARCUS_ATTACK: {"actors": "Marcus, hound C", "doors": "", "input": "none", "camera": "contact, fall, pin", "advance": "Marcus pinned at MARCUS_DOWN, camera settled"},
	Phase.CHOICE: {"actors": "player", "doors": "", "input": "E", "camera": "Marcus", "advance": "E pressed or the trust window ran out"},
	Phase.SAVED: {"actors": "player, Marcus, hound C, shelf", "doors": "", "input": "rescue struggle", "camera": "Marcus", "advance": "shelf closed, both at the staff door"},
	Phase.LOST: {"actors": "Marcus, hound C, player", "doors": "", "input": "none", "camera": "Marcus, then the staff door", "advance": "Marcus gone, player at the staff door"},
	Phase.STAFF_EXIT: {"actors": "player (+ Marcus)", "doors": "staff door", "input": "none", "camera": "the door in use", "advance": "all actors clear of the leaf, door shut"},
	Phase.REAR_EXIT: {"actors": "player (+ Marcus)", "doors": "rear exit", "input": "none", "camera": "the door in use", "advance": "all actors outside, door shut"},
	Phase.REGROUP: {"actors": "everyone", "doors": "", "input": "none", "camera": "forward", "advance": "player at the regroup marker; chapter 9 takes over"},
}

# ---------------------------------------------------------------- markers (supermarket-local)
const AISLE_Z := 13.62
const AISLE_CLOSED_X := 8.8
const AISLE_OPEN_X := 12.0
const AISLE_HALF := 2.12
const Q_EDDIE := Vector3(8.4, 0.04, 12.15)
const Q_RUTH := Vector3(8.4, 0.04, 11.25)
const Q_SARAH := Vector3(8.4, 0.04, 10.35)
const WALT_FREEZE := Vector3(9.4, 0.04, 11.3)
const PLAYER_CLOSED := Vector3(11.52, 0.04, 13.78)
const MARCUS_CLOSED := Vector3(11.52, 0.04, 13.12)
const PLAYER_OPEN := Vector3(14.72, 0.04, 13.78)
const MARCUS_OPEN := Vector3(14.72, 0.04, 13.12)
const MARCUS_DOWN := Vector3(10.2, 0.04, 11.7)
const PLAYER_RESCUE := Vector3(11.1, 0.04, 11.9)
## Validated against the collision geometry (fall_routes_test.gd): the staff doorway is only ~0.8 m wide and centred at x 15.5 (the brief had 15.0); the open leaf lies across x 14.8..15.2, z 14.4..15.4, so the
## clearance point is beside its end, not on it.
const STAFF_APPROACH := Vector3(15.5, 0.04, 13.4)
const STAFF_CLEAR := Vector3(15.6, 0.04, 15.9)
const STAFF_DOOR := Vector3(15.5, 0.04, 14.2)
const REAR_DOOR := Vector3(8.1, 0.04, 17.45)         ## the doorway throat is ~0.8 m wide at x 8.1; the open leaf lies across x 7.4..7.8, z 16.4..16.8
const REAR_INSIDE := Vector3(8.1, 0.04, 16.2)
const REAR_CLOSE_POS := Vector3(8.0, 0.04, 18.6)
const PLAYER_REGROUP := Vector3(8.0, 0.04, 19.6)
const MARCUS_OUTSIDE := Vector3(9.8, 0.04, 20.6)
const OPENING_APPROACH := Vector3(8.4, 0.04, 13.0)
const OPENING_CLEAR := Vector3(8.4, 0.04, 15.0)
const VIEW_ROUTE := [Vector3(14.8, 0.04, 12.55), Vector3(11.1, 0.04, 12.55)]    ## round the south-east end of the open shelf to where Walt's attack can be seen
const MARCUS_VIEW := Vector3(11.8, 0.04, 12.55)
const RECOIL := Vector3(13.1, 0.04, 12.3)                                        ## the player steps back from the attack: from here the pinned Marcus is in plain view past the shelf end
const FRONT_SPAWNS := [Vector3(-1.5, 0.0, -2.4), Vector3(0.2, 0.0, -2.8), Vector3(1.6, 0.0, -2.3)]
const HOUND_B_POST := Vector3(6.6, 0.04, 12.6)                                   ## pressures the barricade area (west end of the shelf)
const HOUND_C_LURK := Vector3(10.6, 0.04, 8.2)
const HOUND_A_POST := Vector3(9.9, 0.04, 10.2)                                  ## south-east of Walt
const WALT_DRAG_TO := Vector3(8.2, 0.04, 8.2)
const PERSON_R := 0.28
const PLAYER_R := 0.28
const HOUND_R := 0.4
const HEIGHTS_PERSON := [0.5, 1.3]
const HEIGHTS_HOUND := [0.7]                                                 # the body above the 15-20 cm kerb outside the doors (a hound steps over it)

var c9: Node
var world: Node
var c8: Node
var c5: Node
var p4: Node
var market: Node3D
var player: Node3D
var hud: Node

var phase: int = Phase.IDLE
var running := false
var hound_a: Node3D
var hound_b: Node3D
var hound_c: Node3D
var _hounds_ready := false
var _assault_on := false
var _look_target: Callable = Callable()
var _look_rate := 6.0
var _door_owner := {}
var _shelf_s := 0.0
var _speech: Array = []
var _speaking := false
var _frenzy_player: AudioStreamPlayer
var _st_won := false
var _st_over := false
var _shown_hint := ""
var last_route_debug := {}


func setup(chapter9: Node) -> void:
	c9 = chapter9
	world = c9.world
	c8 = c9.c8
	c5 = c9.c5
	p4 = c9.p4
	market = c9.market
	player = c9.player
	hud = c9.hud


func ml(p: Vector3) -> Vector3:
	return market.to_global(p)


func st() -> Dictionary:
	return c9.st()


# ================================================================ the one owner of the player and the camera
func _own_player(on: bool) -> void:
	player.set("controls_enabled", not on)
	player.velocity = Vector3.ZERO
	player.set_physics_process(not on)


func _process(delta: float) -> void:
	if not running:
		return
	player.set("controls_enabled", false)                    # nothing (a conversation ending, a dialogue, a prompt) may hand the player back mid-sequence
	if _look_target.is_valid():
		var t: Variant = _look_target.call()
		if t is Vector3:
			var eye: Vector3 = player.camera.global_position
			var v: Vector3 = (t as Vector3) - eye
			if v.length() > 0.2:
				v = v.normalized()
				var yaw1 := atan2(-v.x, -v.z)
				var pitch1 := clampf(asin(clampf(v.y, -1.0, 1.0)), -0.6, 0.45)
				var k := 1.0 - exp(-_look_rate * delta)
				player.set_yaw_pitch(lerp_angle(player.rotation.y, yaw1, k), lerpf(player.head.rotation.x, pitch1, k))


## Aim the camera at a world point or a callable that returns one; wait until it is on it (a smooth turn, 0.35 - 0.8 s).
func _look(target: Variant, rate := 6.0, wait := true) -> void:
	_look_rate = rate
	if target is Callable:
		_look_target = target
	else:
		var p: Vector3 = target
		_look_target = func() -> Vector3: return p
	if not wait:
		return
	var t := 0.0
	while t < 1.2 and _look_error() > 0.05:
		await get_tree().process_frame
		t += get_process_delta_time()


func _look_error() -> float:
	if not _look_target.is_valid():
		return 0.0
	var tv: Variant = _look_target.call()
	if not (tv is Vector3):
		return 0.0
	var v: Vector3 = ((tv as Vector3) - player.camera.global_position).normalized()
	var fwd: Vector3 = -player.camera.global_transform.basis.z
	return acos(clampf(fwd.dot(v), -1.0, 1.0))


# ================================================================ routes, sweeps and movement (collision-safe, actor-sized)
func _space() -> PhysicsDirectSpaceState3D:
	return world.get_world_3d().direct_space_state


## Is the straight step free for a body of this size? (static world + the moving shelf and doors: layer 1, as they are RIGHT NOW)
func _step_clear(from_local: Vector3, to_local: Vector3, radius: float, heights: Array) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	q.shape = sph
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var X := market.global_transform
	for h in heights:
		q.transform = Transform3D(Basis(), X * (from_local + Vector3(0, h, 0)))
		q.motion = X.basis * (to_local - from_local)
		if not _space().intersect_shape(q, 1).is_empty():
			return false
		var r := _space().cast_motion(q)
		if r.size() > 0 and r[0] < 1.0:
			return false
	return true


func _free_at(p_local: Vector3, radius: float, heights: Array) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	q.shape = sph
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	for h in heights:
		q.transform = Transform3D(Basis(), market.global_transform * (p_local + Vector3(0, h, 0)))
		if not _space().intersect_shape(q, 1).is_empty():
			return false
	return true


## A route from `from` to `to` for a body of `radius`: a grid search over the real colliders, string-pulled with swept checks. EMPTY when there is none: nobody falls back to a straight line.
func _route(from: Vector3, to: Vector3, radius: float, heights: Array) -> Array:
	const CELL := 0.2
	var lo := Vector2(minf(from.x, to.x) - 4.0, minf(from.z, to.z) - 4.0)
	var w := int((maxf(from.x, to.x) + 4.0 - lo.x) / CELL) + 1
	var hg := int((maxf(from.z, to.z) + 4.0 - lo.y) / CELL) + 1
	var y := from.y
	var cache := {}
	var free_c := func(c: Vector2i) -> bool:
		if cache.has(c):
			return cache[c]
		var ok := _free_at(Vector3(lo.x + c.x * CELL, y, lo.y + c.y * CELL), radius, heights)
		cache[c] = ok
		return ok
	var cell_of := func(p: Vector3) -> Vector2i: return Vector2i(roundi((p.x - lo.x) / CELL), roundi((p.z - lo.y) / CELL))
	var s: Vector2i = cell_of.call(from)
	var g: Vector2i = cell_of.call(to)
	last_route_debug = {"s": s, "g": g, "g_free": free_c.call(g), "s_free": free_c.call(s), "w": w, "h": hg}
	if not free_c.call(g):
		return []
	if not free_c.call(s):                                   # standing a hair inside something (a shelf edge): the nearest free cell round it
		var found_s := false
		for r in range(1, 6):
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					var c := Vector2i(s.x + dx, s.y + dz)
					if not found_s and c.x >= 0 and c.y >= 0 and c.x < w and c.y < hg and free_c.call(c):
						s = c
						found_s = true
			if found_s:
				break
		if not found_s:
			return []
	var open := {s: 0.0}
	var cost := {s: 0.0}
	var came := {}
	var ok_found := false
	var it := 0
	while not open.is_empty() and it < 60000:
		it += 1
		var cur: Vector2i = s
		var best := INF
		for k in open:
			if open[k] < best:
				best = open[k]
				cur = k
		open.erase(cur)
		if cur == g:
			ok_found = true
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var nb: Vector2i = cur + d
			if nb.x < 0 or nb.y < 0 or nb.x >= w or nb.y >= hg or not free_c.call(nb):
				continue
			if d.x != 0 and d.y != 0 and (not free_c.call(Vector2i(cur.x + d.x, cur.y)) or not free_c.call(Vector2i(cur.x, cur.y + d.y))):
				continue
			var nc: float = cost[cur] + (1.414 if d.x != 0 and d.y != 0 else 1.0)
			if not cost.has(nb) or nc < cost[nb]:
				cost[nb] = nc
				came[nb] = cur
				open[nb] = nc + Vector2(nb - g).length() * 1.25
	last_route_debug["it"] = it
	last_route_debug["found"] = ok_found
	if not ok_found:
		return []
	var cells: Array = [g]
	while cells[0] != s and came.has(cells[0]):
		cells.push_front(came[cells[0]])
	var pts: Array = []
	for c in cells:
		pts.append(Vector3(lo.x + c.x * CELL, y, lo.y + c.y * CELL))
	pts[0] = from
	pts[pts.size() - 1] = to
	var out: Array = []
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _step_clear(pts[i], pts[j], radius, heights):
			j -= 1
		out.append(pts[j])
		i = j
	return out


func _actor(node: Node3D, kind: String) -> Dictionary:
	var a = world.animators.get(String(node.name)) if kind == "person" else null
	return {"node": node, "anim": a, "kind": kind, "radius": HOUND_R if kind == "hound" else PERSON_R, "heights": HEIGHTS_HOUND if kind == "hound" else HEIGHTS_PERSON,
		"done": true, "ok": true}


func _player_actor() -> Dictionary:
	return {"node": player, "anim": null, "kind": "player", "radius": PLAYER_R, "heights": HEIGHTS_PERSON, "done": true, "ok": true}


func _pos(a: Dictionary) -> Vector3:
	var n: Node3D = a["node"]
	return market.to_local(n.global_position) if a["kind"] == "player" else n.position


func _set_pos(a: Dictionary, p: Vector3) -> void:
	var n: Node3D = a["node"]
	if a["kind"] == "player":
		var w := ml(p)
		w.y = player.global_position.y
		player.global_position = w
		player.velocity = Vector3.ZERO
	else:
		n.position = Vector3(p.x, n.position.y, p.z)


## Walk an actor to `dest` (after the optional waypoints `via`): swept every frame with its own radius; fire-and-forget through `_go`, or awaited.
func _move(a: Dictionary, dest: Vector3, speed: float, via: Array = []) -> bool:
	var legs: Array = via.duplicate()
	legs.append(dest)
	for leg in legs:
		if not await _leg(a, leg, speed):
			return false
	return true


func _leg(a: Dictionary, to: Vector3, speed: float) -> bool:
	var n: Node3D = a["node"]
	var kind: String = a["kind"]
	var blocked := 0.0
	var pts: Array = _route(_pos(a), to, a["radius"], a["heights"])
	if pts.is_empty():
		_report("no route for %s to %s" % [n.name, str(to)])
		return false
	var idx := 0
	var anim = a["anim"]
	if anim != null:
		anim.free_walk = true
		anim.turn_to_face = true
		anim.set_mood("scared")
	if kind == "hound":
		c8._hplay(n, "Run", speed)
	var rerouted := 0
	while idx < pts.size():
		var cur: Vector3 = _pos(a)
		var tgt: Vector3 = pts[idx]
		var d: Vector3 = tgt - cur
		d.y = 0.0
		if d.length() < 0.08:
			idx += 1
			continue
		var dt := get_process_delta_time()
		var step: Vector3 = d.normalized() * minf(speed * dt, d.length())
		var nxt := cur + step
		if _step_clear(cur, nxt, a["radius"], a["heights"]):
			blocked = 0.0
			_set_pos(a, nxt)
			if kind == "player":
				_look_rate = 4.5
				var la: Vector3 = nxt + d.normalized() * 2.0
				if idx < pts.size() - 1:
					la = nxt + (((pts[idx + 1] as Vector3) - nxt).normalized() * 0.5 + d.normalized() * 0.5).normalized() * 2.0      # anticipate the next segment
				var look_p := ml(Vector3(la.x, 1.5, la.z))
				_look_target = func() -> Vector3: return look_p
			elif kind == "hound":
				n.rotation.y = atan2(d.x, d.z)
			elif anim != null:
				anim.walk_speed = speed
				anim.walk_to([nxt + d.normalized() * 1.6], speed)
		else:
			blocked += dt
			if blocked > 0.5 and rerouted < 3:                  # something moved into the way (the shelf, a door leaf): a fresh route from here
				rerouted += 1
				blocked = 0.0
				pts = _route(_pos(a), to, a["radius"], a["heights"])
				idx = 0
				if pts.is_empty():
					_report("blocked for good: %s towards %s" % [n.name, str(to)])
					return false
		await get_tree().process_frame
		if not running:
			return false
	if anim != null:
		anim.walk_to([])
	return true


func _go(a: Dictionary, dest: Vector3, speed: float, via: Array = []) -> void:
	a["done"] = false
	a["ok"] = false
	a["ok"] = await _move(a, dest, speed, via)
	a["done"] = true


func _all_done(list: Array) -> bool:
	for a in list:
		if not a["done"]:
			return false
	return true


func _near(a: Dictionary, p: Vector3, d := 0.35) -> bool:
	var c: Vector3 = _pos(a)
	return Vector2(c.x - p.x, c.z - p.z).length() < d


## Wait for a condition with a timeout; a timeout is REPORTED (never silently treated as success).
func _wait_until(label: String, cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
		if not running:
			return false
	if cond.call():
		return true
	_report("timeout: " + label)
	return false


func _report(msg: String) -> void:
	var r: Array = c9.report.get("failures", [])
	r.append("%s: %s" % [Phase.keys()[phase], msg])
	c9.report["failures"] = r
	push_warning("[evacuation] " + msg)


## Recovery for an actor that did not make it: only moved when the camera cannot see it (never a visible teleport); otherwise it waits a little more first.
func _recover(a: Dictionary, dest: Vector3) -> void:
	if _near(a, dest, 0.6):
		return
	var tries := 0
	while tries < 8:
		var n: Node3D = a["node"]
		var in_view: bool = player.camera.is_position_in_frustum(n.global_position + Vector3(0, 1.0, 0))
		if not in_view or tries >= 7:
			_report("recovered %s to %s" % [n.name, str(dest)])
			_set_pos(a, dest)
			return
		await get_tree().create_timer(0.5).timeout
		tries += 1


# ================================================================ phases bookkeeping, speech, music
func _enter(p: int) -> void:
	phase = p
	var d: Dictionary = PHASES.get(p, {})
	st()["evac_phase"] = p
	print("[evacuation] ", Phase.keys()[p], " owns: ", d.get("actors", ""), " doors: ", d.get("doors", ""), " input: ", d.get("input", ""))


## Dialogue is queued and played one at a time (critical lines never overwrite each other); the callers keep moving while the subtitles run.
func _say(id: String) -> void:
	_speech.append(id)
	if not _speaking:
		_speak_loop()


func _speak_loop() -> void:
	_speaking = true
	while not _speech.is_empty() and running:
		while Dialogue.is_busy():
			await get_tree().process_frame
		var id: String = _speech.pop_front()
		Dialogue.say(id, false, true)
		_mix(true)
		await get_tree().process_frame
		while Dialogue.is_busy():
			await get_tree().process_frame
		_mix(false)
	_speaking = false


## The danger music sits under speech: both loops dip while a line is on screen and come back after (a deliberate mix, not two loops at full).
func _mix(speech: bool) -> void:
	if _frenzy_player != null:
		var tw := create_tween()
		tw.tween_property(_frenzy_player, "volume_db", -22.0 if speech else -13.0, 0.25)
	Sfx.trim_music(-7.0 if speech else 0.0)


func _frenzy(on: bool) -> void:
	if on:
		Sfx.play_music(HOUND_MUSIC, true, -5.0, 0.6)
		if _frenzy_player == null:
			_frenzy_player = AudioStreamPlayer.new()
			_frenzy_player.stream = load(LAYER_MUSIC) as AudioStream
			_frenzy_player.volume_db = -13.0
			_frenzy_player.finished.connect(func():
				if _frenzy_player != null and _frenzy_player.has_meta("on"):
					_frenzy_player.play())
			add_child(_frenzy_player)
		_frenzy_player.set_meta("on", true)
		_frenzy_player.play()
	elif _frenzy_player != null:
		_frenzy_player.remove_meta("on")
		_frenzy_player.stop()
		Sfx.trim_music(0.0)


# ================================================================ the shelf
func shelf_set(s_: float) -> void:                      ## 0 = closed across the opening, 1 = open (slid east)
	_shelf_s = s_
	var sp: Node3D = c8._secure_pallet
	sp.position = Vector3(lerpf(AISLE_CLOSED_X, AISLE_OPEN_X, s_), 0.0, AISLE_Z)
	sp.rotation.y = 0.0


func spot(s_: float, who: String) -> Vector3:           ## the contact markers slide with the shelf: east end + 0.6
	var x := lerpf(AISLE_CLOSED_X, AISLE_OPEN_X, s_) + AISLE_HALF + 0.6
	return Vector3(x, 0.04, PLAYER_CLOSED.z if who == "player" else MARCUS_CLOSED.z)


## The two pullers / pushers are attached to the shelf: their position is a function of its progress (continuous, never a snap).
func _attach(s_: float, t: float) -> void:
	shelf_set(s_)
	var bob := sin(t * 9.0) * 0.025
	var pa := _player_actor()
	_set_pos(pa, spot(s_, "player") + Vector3(bob, 0, 0))
	if not st().get("evac_marcus_down", false):
		var ma := _actor(c9.marcus, "person")
		_set_pos(ma, spot(s_, "marcus") + Vector3(-bob, 0, 0))
		if ma["anim"] != null:
			ma["anim"].face_towards(c8._secure_pallet.global_position)


func _shelf_hands() -> Vector3:
	return ml(c8._secure_pallet.position + Vector3(AISLE_HALF - 0.25, 0.95, 0.15))      # the hands on the shelf east end


## The single required struggle: click to pull the shelf clear. A failed attempt slips back a little, continuously, and the same struggle starts again.
func _struggle(title: String, hint: String, seconds: float, per_click: float) -> bool:
	var sg = world.get_node_or_null("Struggle")
	if sg == null:
		sg = load("res://game/encounters/struggle.gd").new()
		sg.name = "Struggle"
		world.add_child(sg)
		sg.setup(world)
	_st_over = false
	_st_won = false
	_struggle_go(sg, title, hint, seconds, per_click)
	return true


func _struggle_go(sg: Node, title: String, hint: String, seconds: float, per_click: float) -> void:
	_st_won = await sg.rescue(title, hint, seconds, "hs_hold", per_click)
	_st_over = true


func _pull() -> void:
	var sg = world.get_node_or_null("Struggle")
	var s_ := 0.0
	var won := false
	while not won and running:
		_struggle("CLICK RAPIDLY  -  PULL THE SHELVES CLEAR OF THE BACK DOOR!", "LEFT CLICK, AGAIN AND AGAIN  -  MARCUS PULLS WITH YOU", 11.0, 0.075)
		sg = world.get_node_or_null("Struggle")
		var base := s_
		var t := 0.0
		_look(func() -> Vector3: return _shelf_hands(), 7.0, false)
		while not _st_over and running:
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			var pr: float = sg.rescue_progress()
			s_ = lerpf(s_, base + (1.0 - base) * pr, 1.0 - exp(-6.0 * dt))
			_attach(s_, t)
			if int(t * 2.0) != int((t - dt) * 2.0):
				p4._play("scrape", ml(c8._secure_pallet.position), -6.0 + 3.0 * pr)
				p4._play("impact", ml(Vector3(0.0, 1.0, 0.3)), 1.0 + 2.0 * pr)
		won = _st_won
		if not won and running:
			p4._play("impact", ml(Vector3(0.0, 1.0, 0.3)), 5.0)                   # the glass takes another blow; the shelf slips back a little, in one smooth slide
			var back_to := s_ * 0.8
			var from_s := s_
			var tw := create_tween()
			tw.tween_method(func(v: float): _attach(v, 0.0), from_s, back_to, 0.55)
			await tw.finished
			s_ = back_to
	_attach(1.0, 0.0)
	await _look(func() -> Vector3: return _shelf_hands(), 7.0, false)


# ================================================================ doors: arrive, open, passable, cross, clear, close
func _claim(door: String, owner_phase: int) -> bool:
	if _door_owner.has(door) and _door_owner[door] != owner_phase:
		_report("door %s already owned by %s" % [door, Phase.keys()[_door_owner[door]]])
		return false
	_door_owner[door] = owner_phase
	return true


func _release(door: String) -> void:
	_door_owner.erase(door)


func _rear_open_xf() -> Transform3D:
	var bd: Node3D = p4.its.get("back_door")
	var base: Transform3D = p4._base["back"]
	var d: float = world._toward_deg(bd, 88.0, ml(Vector3(8.0, 1.0, 16.4)))
	return Transform3D(base.basis * Basis(Vector3.UP, deg_to_rad(d)), base.origin)


func _rear_passable() -> bool:
	var bd: Node3D = p4.its.get("back_door")
	var base: Transform3D = p4._base["back"]
	return Quaternion(base.basis).angle_to(Quaternion(bd.transform.basis)) > deg_to_rad(70.0)


func _open_rear() -> void:
	_claim("rear", phase)
	var bd: Node3D = p4.its.get("back_door")
	var pal: Node3D = p4._pallets.get("back")
	if pal:
		pal.position = c9.BACK_PALLET_SHOVED
		pal.rotation.y = 0.9
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bd, "transform", _rear_open_xf(), 0.5)
	Sfx.play("door_open", ml(REAR_DOOR), -2.0, 0.9)
	await tw.finished
	await _wait_until("rear exit passable", _rear_passable, 1.0)


func _close_rear() -> void:
	var bd: Node3D = p4.its.get("back_door")
	var base: Transform3D = p4._base["back"]
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(bd, "transform", base, 0.5)
	Sfx.play("door_close", ml(REAR_DOOR), 2.0, 0.7)
	await tw.finished
	p4._play("impact", ml(REAR_DOOR + Vector3(0, 0.9, -0.5)), 6.0)
	_release("rear")


func _staff() -> Interactable:
	return p4.its.get("INT_Door_Staff")


func _staff_passable() -> bool:
	var sd: Interactable = _staff()
	if sd == null or sd.target == null:
		return true
	return Quaternion(sd._base.basis).angle_to(Quaternion(sd.target.transform.basis)) > deg_to_rad(sd.open_deg) * 0.8


func _open_staff() -> void:
	_claim("staff", phase)
	var sd: Interactable = _staff()
	if sd == null:
		return
	sd.set_open(true)
	Sfx.play("door_open", ml(STAFF_DOOR + Vector3(0, 1.0, 0)), -2.0, 0.9)
	await get_tree().create_timer(sd.anim_time + 0.05).timeout
	await _wait_until("staff door passable", _staff_passable, 1.0)


## The staff door may close only when no actor is inside its leaf's swing (a 1.0 m arc round the doorway).
func _clear_of_staff(actors: Array) -> bool:
	for a in actors:
		var p: Vector3 = _pos(a)
		if p.z < 15.4 + a["radius"] + 0.05:                 # the leaf sweeps z 14.2..15.4 on the corridor side: everybody is beyond it
			return false
	return true


func _close_staff(actors: Array) -> void:
	await _wait_until("actors clear of the staff leaf", func(): return _clear_of_staff(actors), 3.0)
	var sd: Interactable = _staff()
	if sd:
		sd.set_open(false)
		Sfx.play("door_close", ml(STAFF_DOOR + Vector3(0, 1.0, 0.6)), 0.0, 0.8)
		await get_tree().create_timer(sd.anim_time + 0.05).timeout
		p4._play("impact", ml(STAFF_DOOR + Vector3(0, 1.0, -0.4)), 5.0)
	_release("staff")


# ================================================================ the sequence
func start() -> void:
	if running:
		return
	running = true
	_enter(Phase.PREP)
	_own_player(true)                                   # synchronously: the call that ends the last conversation made this call
	hud.set_marker(null, "")
	hud.set_hint("")
	world.end_conversation()
	for n in [c9.eddie, c9.marcus, c9.ruth, c9.sarah]:
		var a = world.animators.get(String(n.name))
		if a:
			a.set_mood("scared")
	if c8._blocker:
		c8._blocker.collision_layer = 0
	shelf_set(0.0)
	world.save()                                        # safe checkpoint before the sequence
	await _warning()
	await _approach()
	await _pull_phase()
	await _evacuate_and_walt()
	await _return_to_push()
	await _half_push()
	var helped := await _marcus_attack_and_choice()
	var saved := false
	if helped:
		_enter(Phase.SAVED)
		saved = await _rescue()
	if saved:
		await _saved_finish()
	else:
		await _lost()
	await _staff_exit(saved)
	await _rear_exit(saved)
	await _regroup(saved)


func _warning() -> void:
	_enter(Phase.WARNING)
	_frenzy(true)
	_look(ml(Vector3(2.0, 1.5, 6.0)), 6.0, false)
	for k in 3:
		p4._play("impact", ml(Vector3(-14.0 + k * 9.0, 2.0, -9.0)), -10.0 + k * 2.0)
		await get_tree().create_timer(0.8 + k * 0.3).timeout
	p4._play("scrape", ml(Vector3(0.0, 1.0, 0.4)), 2.0)
	p4._flicker_burst(1.0)
	await _look(ml(Vector3(0.0, 1.5, 0.3)), 6.0)                 # a short look at the front glass
	_spawn_hounds()
	_say("c9_warning")
	await get_tree().create_timer(1.8).timeout


func _spawn_hounds() -> void:
	for h in c9.hounds:
		if is_instance_valid(h):
			h.queue_free()
	c9.hounds.clear()
	var made: Array = []
	for i in FRONT_SPAWNS.size():
		var h: Node3D = c8._make_hound(FRONT_SPAWNS[i])
		h.name = "C9_Hound_%s" % ["A", "B", "C"][i]
		h.rotation.y = 0.0
		c9.hounds.append(h)
		made.append(h)
		_assault(h, i)
	hound_a = made[0]
	hound_b = made[1]
	hound_c = made[2]
	c9.hound_in = hound_c
	_assault_on = true


func _assault(h: Node3D, i: int) -> void:
	await get_tree().create_timer(0.3 * i).timeout
	var home: Vector3 = FRONT_SPAWNS[i]
	while _assault_on and is_instance_valid(h) and running:
		c8._hplay(h, "Attack_Bite", 0.0)
		var tw := h.create_tween()
		tw.tween_property(h, "position", home + Vector3(0, 0, 1.5), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		if not is_instance_valid(h):
			return
		p4._play("impact", ml(Vector3(home.x, 1.0, 0.3)), 5.0)
		if i == 1:
			p4._play("scrape", ml(Vector3(home.x, 0.8, 0.4)), 0.0)
		var back := h.create_tween()
		back.tween_property(h, "position", home, 0.5).set_trans(Tween.TRANS_SINE)
		await back.finished
		await get_tree().create_timer(randf_range(0.15, 0.7)).timeout


func _approach() -> void:
	_enter(Phase.APPROACH)
	var injured_serious: bool = String(c9._injured()) == "serious"
	var pa := _player_actor()
	var ma := _actor(c9.marcus, "person")
	var ea := _actor(c9.eddie, "person")
	var ra := _actor(c9.ruth, "person")
	var sa := _actor(c9.sarah, "person")
	var clerk: Node3D = world.cashier
	var wa: Dictionary = {}
	if clerk and is_instance_valid(clerk) and not Game.has_flag("ch9_clerk_dead") and world.animators.has("Cashier"):
		wa = _actor(clerk, "person")
	for a in [ma, ea, ra, sa]:
		c5._reparent(a["node"], market)
	# the assault instructions are spoken ONCE, as the movement begins
	_say("c9_front_assault")
	# Sarah rises first and only moves when she is up; she runs with a limp (worse when the injury is serious)
	var sar = sa["anim"]
	if sar:
		sar.set_downed("")
		sar.limp = 1.0 if injured_serious else 0.7
	_go(ma, MARCUS_CLOSED, 4.4)
	_go(ea, Q_EDDIE, 4.0)
	_go(ra, Q_RUTH, 3.8)
	if not wa.is_empty():
		_go(wa, WALT_FREEZE, 3.2)
	_rise_then_go(sa, Q_SARAH, 2.4 if injured_serious else 3.0)
	_go(pa, PLAYER_CLOSED, 4.6)
	var group: Array = [pa, ma, ea, ra, sa]
	if not wa.is_empty():
		group.append(wa)
	await _wait_until("approach arrivals", func(): return _all_done(group), 16.0)
	# recovery for anyone who did not make it (reported; only out of sight)
	var dests := {"Marcus": MARCUS_CLOSED, "Eddie": Q_EDDIE, "Ruth": Q_RUTH, "Sarah": Q_SARAH}
	for a in [ma, ea, ra, sa]:
		await _recover(a, dests[String(a["node"].name)])
	if not wa.is_empty():
		await _recover(wa, WALT_FREEZE)
	await _recover(pa, PLAYER_CLOSED)
	# stopped, facing the shelf, hand contact ready
	for a in [ma]:
		if a["anim"]:
			a["anim"].walk_to([])
			a["anim"].face_towards(c8._secure_pallet.global_position)
	for a in [ea, ra, sa]:
		if a["anim"]:
			a["anim"].face_towards(ml(Vector3(8.4, 1.0, 14.0)))
	if not wa.is_empty() and wa["anim"]:
		wa["anim"].face_towards(ml(Vector3(0.0, 1.0, 1.0)))
	await _look(func() -> Vector3: return _shelf_hands(), 7.0)
	await _wait_until("facing the shelf", func(): return _look_error() < 0.12, 1.5)
	await get_tree().create_timer(0.3).timeout


func _rise_then_go(a: Dictionary, dest: Vector3, speed: float) -> void:
	a["done"] = false
	await get_tree().create_timer(1.3).timeout                 # the rise completes before any locomotion
	a["ok"] = await _move(a, dest, speed)
	a["done"] = true


func _pull_phase() -> void:
	_enter(Phase.PULL)
	await _pull()


func _evacuate_and_walt() -> void:
	_enter(Phase.EVACUATE_AND_WALT)
	await _open_rear()
	var injured_serious: bool = String(c9._injured()) == "serious"
	var ea := _actor(c9.eddie, "person")
	var ra := _actor(c9.ruth, "person")
	var sa := _actor(c9.sarah, "person")
	var out: Array = c9.OUT_WAIT
	c9._out_waiting = ["Eddie", "Ruth", "Sarah"]
	_say("c9_pass_through")
	# the bottleneck: one person in the opening at a time, released in order with spacing
	var gate_free := func(a: Dictionary) -> bool:
		var p: Vector3 = _pos(a)
		return p.z > OPENING_CLEAR.z or p.z < 12.0
	_go(ea, out[0], 3.6, [OPENING_APPROACH, OPENING_CLEAR])
	# the player and Marcus take the short route round the shelf's south-east end to the viewing point (continuous, swept) and watch
	var pa := _player_actor()
	var ma := _actor(c9.marcus, "person")
	_go(pa, VIEW_ROUTE[1], 4.4, [VIEW_ROUTE[0]])
	_go(ma, MARCUS_VIEW, 4.4, [VIEW_ROUTE[0]])
	await _wait_until("Eddie through the opening", func(): return _pos(ea).z > OPENING_CLEAR.z, 8.0)
	_go(ra, out[1], 3.6, [OPENING_APPROACH, OPENING_CLEAR])
	await _wait_until("Ruth through the opening", func(): return _pos(ra).z > OPENING_CLEAR.z, 8.0)
	var sar = sa["anim"]
	_go(sa, out[2], 2.3 if injured_serious else 3.0, [OPENING_APPROACH, OPENING_CLEAR])
	# the front doors give once the first of them is through
	_burst_done = false
	_front_burst()
	await _wait_until("viewing point reached", func(): return pa["done"] and ma["done"], 14.0)
	await _recover(pa, VIEW_ROUTE[1])
	await _wait_until("front doors burst", func(): return _burst_done, 6.0)
	await _walt()
	await _wait_until("queue clear of the opening", func(): return _pos(sa).z > OPENING_CLEAR.z + 0.5 and sa["done"], 14.0)
	for a in [ea, ra, sa]:
		await _recover(a, out[["Eddie", "Ruth", "Sarah"].find(String(a["node"].name))])
	_assault_on = false
	await _hound_c_ready()


## The front doors burst and the hounds come in, each by its own route and role: A takes Walt, B pressures the barricade, C lurks for Marcus.
func _front_burst() -> void:
	_assault_on = false
	c5._set_doors(true)
	p4._play("impact", ml(Vector3(0.0, 1.0, 0.3)), 9.0)
	c8._dust(ml(Vector3(0.0, 2.4, 0.3)), 34)
	world._shake(player.camera, 0.4, 0.04)
	await get_tree().create_timer(1.0).timeout                 # the leaves reach a passable position before anybody crosses
	var walt_at: Vector3 = WALT_FREEZE
	_hound_role_a(walt_at)
	_hound_role_b()
	_hound_role_c()
	_burst_done = true


func _hound_role_a(_walt_at: Vector3) -> void:
	var a := _actor(hound_a, "hound")
	st()["evac_a"] = true
	_hound_a_ready = await _move(a, HOUND_A_POST, 6.2, [Vector3(1.5, 0.04, 3.0)])


var _burst_done := false
var _hound_a_ready := false
var _hound_b_ready := false
var _hound_c_ready_flag := false


func _hound_role_b() -> void:
	var b := _actor(hound_b, "hound")
	_hound_b_ready = await _move(b, HOUND_B_POST, 6.2, [Vector3(1.5, 0.04, 3.0)])
	while is_instance_valid(hound_b) and running and phase < Phase.REAR_EXIT:
		c8._hplay(hound_b, "Attack_Bite", 0.0)
		p4._play("impact", ml(Vector3(6.8, 1.0, 13.2)), 4.0)
		await get_tree().create_timer(randf_range(0.8, 1.5)).timeout


func _hound_role_c() -> void:
	var c := _actor(hound_c, "hound")
	_hound_c_ready_flag = await _move(c, HOUND_C_LURK, 6.0, [Vector3(1.5, 0.04, 3.0)])
	if is_instance_valid(hound_c):
		c8._hplay(hound_c, "Alert", 0.0)


func _hound_c_ready() -> void:
	await _wait_until("hound C ready", func(): return _hound_c_ready_flag, 8.0)


## Walt froze on the sales floor; hound A takes him in front of the player (both are framed; the shelf's end is not in the way from the viewing point).
func _walt() -> void:
	var clerk: Node3D = world.cashier
	if Game.has_flag("ch9_clerk_dead") or clerk == null or not is_instance_valid(clerk):
		return
	var wa = world.animators.get("Cashier")
	_say("c9_walt_freeze")
	await _wait_until("hound A at the sales floor", func(): return _hound_a_ready or not is_instance_valid(hound_a), 8.0)
	# both Walt and the hound in frame, with a clear line of sight to each
	_look(func() -> Vector3:
		var wp: Vector3 = clerk.global_position + Vector3(0, 1.1, 0)
		var hp: Vector3 = hound_a.global_position + Vector3(0, 0.7, 0) if is_instance_valid(hound_a) else wp
		return wp.lerp(hp, 0.5), 5.0, false)
	await get_tree().create_timer(0.7).timeout
	var vis_ok := _line_clear(player.camera.global_position, clerk.global_position + Vector3(0, 1.1, 0)) and (not is_instance_valid(hound_a) or _line_clear(player.camera.global_position, hound_a.global_position + Vector3(0, 0.7, 0)))
	if not vis_ok:
		_report("Walt's attack is partly hidden from the viewing point")
	# contact: the lunge, the bite
	var dir: Vector3 = (clerk.position - hound_a.position)
	dir.y = 0.0
	hound_a.rotation.y = atan2(dir.x, dir.z)
	c8._hplay(hound_a, "Attack_Bite", 0.0)
	await get_tree().create_timer(0.25).timeout
	Game.set_flag("ch9_clerk_dead")
	_say("c9_clerk_taken")
	Sfx.play("hurt", clerk.global_position + Vector3(0, 1.3, 0), 6.0, 1.3)
	p4._play("impact", clerk.global_position + Vector3(0, 1.0, 0), 2.0)
	if wa:
		wa.walk_to([])
		wa.set_downed("back")
	# dragged along the open lane (x ~8.2 between the shelves), a validated line, out of sight
	await _drag(clerk, hound_a, [Vector3(WALT_DRAG_TO.x, 0.04, WALT_DRAG_TO.z)], 2.2, Vector3(0.9, 0, 0.5))
	clerk.visible = false
	if is_instance_valid(hound_a):
		c8._hplay(hound_a, "Alert", 0.0)
	await _look(ml(Vector3(9.0, 1.2, 11.0)), 5.0, false)


## Drag a body (and its hound beside it) along validated legs: every leg is swept with the dragged body size first; a blocked leg is reported and skipped (never walked through).
func _drag(victim: Node3D, h: Node3D, legs: Array, seconds: float, hound_off: Vector3) -> void:
	var total := 0.0
	var cur: Vector3 = victim.position
	var good: Array = []
	for q in legs:
		if _step_clear(cur, q, 0.3, [0.4]):
			good.append(q)
			total += cur.distance_to(q)
			cur = q
		else:
			_report("drag leg blocked: %s -> %s" % [str(cur), str(q)])
			break
	for q in good:
		var d := victim.position.distance_to(q)
		var dur := seconds * d / maxf(total, 0.1)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(victim, "position", q, dur).set_trans(Tween.TRANS_SINE)
		if h != null and is_instance_valid(h):
			tw.tween_property(h, "position", q + hound_off, dur).set_trans(Tween.TRANS_SINE)
		await tw.finished


func _line_clear(from_w: Vector3, to_w: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from_w, to_w, 1)
	q.exclude = [player.get_rid()]
	return _space().intersect_ray(q).is_empty()


func _return_to_push() -> void:
	_enter(Phase.RETURN_TO_PUSH)
	var pa := _player_actor()
	var ma := _actor(c9.marcus, "person")
	var ea := _actor(c9.eddie, "person")
	var cleared: bool = _pos(ea).z > OPENING_CLEAR.z - 0.5
	if not cleared:
		_report("Eddie had not cleared the opening before the return shove")
	_go(pa, PLAYER_OPEN, 4.4, [VIEW_ROUTE[0]])
	_go(ma, MARCUS_OPEN, 4.4, [VIEW_ROUTE[0]])
	await _wait_until("both at the pushing markers", func(): return pa["done"] and ma["done"], 12.0)
	await _recover(pa, PLAYER_OPEN)
	await _recover(ma, MARCUS_OPEN)
	if ma["anim"]:
		ma["anim"].walk_to([])
		ma["anim"].face_towards(c8._secure_pallet.global_position)
	await _look(func() -> Vector3: return _shelf_hands(), 7.0)


func _half_push() -> void:
	_enter(Phase.HALF_PUSH)
	_say("c9_push_back")
	var tw := create_tween()
	tw.tween_method(func(v: float): _attach(v, (1.0 - v) * 14.0), 1.0, 0.5, 2.2)
	await tw.finished
	_attach(0.5, 0.0)


## A hound (C) comes round the exposed end of the shelf and takes Marcus: contact, the fall, the drag to MARCUS_DOWN; the camera follows it, then settles on him; only then the prompt and its timer.
func _marcus_attack_and_choice() -> bool:
	_enter(Phase.MARCUS_ATTACK)
	st()["evac_marcus_down"] = true
	c9.report["pin_runs"] += 1
	var ma := _actor(c9.marcus, "person")
	var hc := _actor(hound_c, "hound")
	_look(func() -> Vector3:
		var mp: Vector3 = c9.marcus.global_position + Vector3(0, 1.0, 0)
		var hp: Vector3 = hound_c.global_position + Vector3(0, 0.6, 0) if is_instance_valid(hound_c) else mp
		return mp.lerp(hp, 0.5), 4.5, false)
	var near_m := Vector3(ma["node"].position.x + 0.2, 0.04, ma["node"].position.z - 1.5)
	if not await _move(hc, near_m, 6.4):
		_report("hound C could not reach Marcus")
		_set_pos(hc, near_m)
	var dir: Vector3 = c9.marcus.position - hound_c.position
	dir.y = 0.0
	hound_c.rotation.y = atan2(dir.x, dir.z)
	c8._hplay(hound_c, "Attack_Bite", 0.0)
	await get_tree().create_timer(0.3).timeout
	_say("c9_marcus_grabbed")                                   # contact
	Sfx.play("hurt", c9.marcus.global_position + Vector3(0, 1.3, 0), 6.0, 1.0)
	p4._play("impact", c9.marcus.global_position + Vector3(0, 1.0, 0), 2.0)
	if ma["anim"]:
		ma["anim"].free_walk = true
		ma["anim"].set_downed("back")                            # the fall
	await get_tree().create_timer(0.5).timeout
	_go(_player_actor(), RECOIL, 3.6)                             # the player staggers back (south, off the shelf end) so the pinned Marcus is in view
	await _drag(c9.marcus, hound_c, [Vector3(13.0, 0.04, 12.1), MARCUS_DOWN], 1.7, Vector3(0.1, 0, -0.9))
	if ma["anim"]:
		ma["anim"].set_downed("side")                            # the supplied injured-floor animation
	hound_c.rotation.y = atan2(MARCUS_DOWN.x - hound_c.position.x, MARCUS_DOWN.z - hound_c.position.z)
	c8._hplay(hound_c, "Attack_Bite", 0.0)
	await _wait_until("player at the recoil spot", func(): return _near(_player_actor(), RECOIL, 0.3), 3.0)
	if not _line_clear(player.camera.global_position, c9.marcus.global_position + Vector3(0, 0.5, 0)):
		_report("the pinned Marcus is not in view from the recoil spot")
	# the camera settles on him, then the prompt appears and the full window starts
	await _look(func() -> Vector3: return c9.marcus.global_position + Vector3(0, 0.5, 0), 6.0)
	await _wait_until("camera settled on Marcus", func(): return _look_error() < 0.05, 1.5)
	while _speaking or Dialogue.is_busy():                       # let the line finish: the player gets the whole window
		await get_tree().process_frame
	_enter(Phase.CHOICE)
	var window: float = c9.pin_window() * 0.55                  # 3.85 / 5.5 / 7.15 s by trust
	st()["pin_window"] = window
	var left := window
	var helped := false
	while left > 0.0 and running:
		hud.set_hint("E - HELP MARCUS   %d" % ceili(left))
		await get_tree().process_frame
		left -= get_process_delta_time()
		if Input.is_action_just_pressed("interact"):
			helped = true
			break
	hud.set_hint("")
	return helped


func _rescue() -> bool:
	var pa := _player_actor()
	var ok := await _move(pa, PLAYER_RESCUE, 4.6)
	if not ok:
		await _recover(pa, PLAYER_RESCUE)
	await _look(func() -> Vector3: return c9.marcus.global_position + Vector3(0, 0.4, 0), 7.0)
	_struggle("CLICK RAPIDLY  -  PULL MARCUS FREE!", "LEFT CLICK, AGAIN AND AGAIN", 8.0, 0.1)
	while not _st_over and running:
		await get_tree().process_frame
	return _st_won


## The rescue worked: the hound recoils, Marcus gets up, both go back to the shelf and finish closing the opening; Marcus then goes first to the staff door.
func _saved_finish() -> void:
	var ma := _actor(c9.marcus, "person")
	_say("c9_marcus_saved")
	if is_instance_valid(hound_c):
		c8._hplay(hound_c, "Attack_Bite", 0.0)
		p4._play("impact", hound_c.global_position + Vector3(0, 0.8, 0), 2.0)
		var back: Vector3 = hound_c.position + Vector3(-1.4, 0, -1.2)
		if not _step_clear(hound_c.position, back, HOUND_R, HEIGHTS_HOUND):
			back = hound_c.position + Vector3(-0.6, 0, -0.9)
		var tw := hound_c.create_tween()
		tw.tween_property(hound_c, "position", back, 0.5).set_trans(Tween.TRANS_SINE)
	if ma["anim"]:
		ma["anim"].set_downed("")                                # hauled up
		ma["anim"].limp = 0.6
	Game.flags.erase("ch9_marcus_lost")
	Game.set_flag("ch9_marcus_saved")
	st()["marcus_outcome"] = "survived"
	st()["evac_marcus_down"] = false
	await get_tree().create_timer(1.1).timeout                   # up before anybody moves
	var pa := _player_actor()
	var ok_m := ma
	_go(ma, spot(0.5, "marcus"), 4.4)
	await _move(pa, spot(0.5, "player"), 4.6)
	await _wait_until("Marcus back at the shelf", func(): return ok_m["done"], 6.0)
	await _recover(ma, spot(0.5, "marcus"))
	await _look(func() -> Vector3: return _shelf_hands(), 7.0)
	var tw2 := create_tween()
	tw2.tween_method(func(v: float): _attach(v, (1.0 - v) * 14.0), 0.5, 0.0, 2.2)
	for k in 3:
		p4._play("scrape", ml(c8._secure_pallet.position), -4.0)
		await get_tree().create_timer(0.7).timeout
	await tw2.finished
	_attach(0.0, 0.0)
	p4._play("door_close", ml(Vector3(AISLE_CLOSED_X, 1.0, AISLE_Z)), 2.0)
	p4._play("impact", ml(Vector3(AISLE_CLOSED_X - 1.5, 1.0, AISLE_Z - 0.8)), 6.0)
	_hound_b_ready = false


## No help, or the rescue failed: Marcus is dragged away (no black screen); the incomplete shove is abandoned; Eddie stays outside with Ruth and Sarah.
func _lost() -> void:
	_enter(Phase.LOST)
	var ma := _actor(c9.marcus, "person")
	_say("c9_marcus_lost")
	Sfx.play("hurt", c9.marcus.global_position + Vector3(0, 1.3, 0), 6.0, 0.95)
	if ma["anim"]:
		ma["anim"].set_downed("back")
	await _drag(c9.marcus, hound_c, [Vector3(9.0, 0.04, 9.0), Vector3(8.2, 0.04, 6.4)], 2.8, Vector3(0.3, 0, 0.8))
	c9.marcus.visible = false
	Game.flags.erase("ch9_marcus_saved")
	Game.set_flag("ch9_marcus_lost")
	st()["marcus_outcome"] = "lost"
	st()["evac_marcus_down"] = false
	c9.report["lost_runs"] += 1


func _staff_exit(saved: bool) -> void:
	_enter(Phase.STAFF_EXIT)
	var pa := _player_actor()
	var ma := _actor(c9.marcus, "person")
	_claim("staff", Phase.STAFF_EXIT)
	if saved:
		# Marcus reaches the staff door, opens it and crosses first; the player follows
		await _move(ma, STAFF_APPROACH, 4.4)
		await _look(ml(STAFF_DOOR + Vector3(0, 1.3, 0)), 6.0, false)
		await _open_staff()
		_go(ma, STAFF_CLEAR, 4.2)
		await _move(pa, STAFF_APPROACH, 4.6)
		await _wait_until("Marcus across the staff door", func(): return ma["done"], 5.0)
		await _move(pa, STAFF_CLEAR, 4.6)
		await _close_staff([pa, ma])
	else:
		await _move(pa, STAFF_APPROACH, 4.8)
		await _look(ml(STAFF_DOOR + Vector3(0, 1.3, 0)), 6.0)
		await _open_staff()
		await _move(pa, STAFF_CLEAR, 4.8)
		# turn back only after crossing, to see it shut
		await _look(ml(STAFF_DOOR + Vector3(0, 1.3, 0)), 6.0)
		await _close_staff([pa])
	await _look(ml(REAR_INSIDE + Vector3(0, 1.4, 0.0)), 6.0, false)


func _rear_exit(saved: bool) -> void:
	_enter(Phase.REAR_EXIT)
	var pa := _player_actor()
	var ma := _actor(c9.marcus, "person")
	if saved:
		_go(ma, MARCUS_OUTSIDE, 4.4, [REAR_INSIDE])
	await _move(pa, REAR_CLOSE_POS, 4.8, [REAR_INSIDE])
	if saved:
		await _wait_until("Marcus outside", func(): return ma["done"], 6.0)
		await _recover(ma, MARCUS_OUTSIDE)
	await _look(ml(REAR_DOOR + Vector3(0, 1.3, 0)), 6.0)
	await _wait_until("everyone clear of the rear leaf", func(): return _pos(pa).z > REAR_DOOR.z + 0.9, 2.0)
	await _close_rear()


func _regroup(saved: bool) -> void:
	_enter(Phase.REGROUP)
	var pa := _player_actor()
	await _move(pa, PLAYER_REGROUP, 4.0)
	_assault_on = false
	for h in c9.hounds:
		if is_instance_valid(h):
			h.queue_free()
	c9.hounds.clear()
	c9.hound_in = null
	_frenzy(false)
	Sfx.play_music(Sfx.MUSIC_GAMEPLAY, true, -14.0, 3.0)
	_look_target = Callable()
	Game.set_flag("ch9_fall_started")
	_enter(Phase.DONE)
	running = false
	_own_player(false)                                   # the controller lets go; chapter 9 takes over (its look back holds the player again briefly)
	world.save()                                         # safe checkpoint after regrouping
	c9._busy["warning"] = false
	c9._escaped()


# ================================================================ loads
## A load while the evacuation had not finished: Marcus's outcome (and Walt) are never undone. With an outcome stored the sequence resumes at the staff door; otherwise it replays from the warning.
func resume() -> void:
	if running:
		return
	var saved := Game.has_flag("ch9_marcus_saved")
	var lost := Game.has_flag("ch9_marcus_lost")
	if saved and lost:                                   # contradictory flags can never survive a load: the later-written one is not knowable, so the safe reading is "saved"
		Game.flags.erase("ch9_marcus_lost")
		lost = false
	if not (saved or lost):
		start()
		return
	running = true
	_own_player(true)
	shelf_set(0.0 if saved else 0.5)
	world.cashier.visible = false
	var out: Array = c9.OUT_WAIT
	for i in 3:
		var n: Node3D = [c9.eddie, c9.ruth, c9.sarah][i]
		c5._reparent(n, market)
		n.visible = true
		world.place_survivor(n, out[i])
	_open_rear()
	var pa := _player_actor()
	_set_pos(pa, STAFF_APPROACH)
	if saved:
		c5._reparent(c9.marcus, market)
		c9.marcus.visible = true
		world.place_survivor(c9.marcus, STAFF_APPROACH + Vector3(0.6, 0, -0.4))
	else:
		c9.marcus.visible = false
	_frenzy(true)
	await _staff_exit(saved)
	await _rear_exit(saved)
	await _regroup(saved)
