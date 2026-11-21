extends Node
class_name VeilWorldEdge
## THE VEIL - the Veil does not let you leave. Far past everything built for play (the town, its roads, houses,
## lots, story places and supply caches) the mist closes in; keep going and a Colossus tentacle takes you.
##   WARN_D  - the mist thickens with distance, a deep call far off, one line: "This road doesn't feel right..."
##             Turning back clears it again.
##   KILL_D  - heavy mist, a rumble, the Veil rises slowly ahead, a pack of hounds runs straight at you out of it and jumps you, into
##             black, then the usual YOU DIED - RETRY (last save) / MAIN MENU.
## Before the story's Veil this is only local fog (no flags, no chapter change); after it the existing fog is used.
## Never during a cinematic, an encounter, a conversation, a struggle or a death; never saves, never sets a flag.
## Armed only once the player has been inside the playable area (a save far out cannot loop), plus a short grace
## after every load. In the car: it is brought to a stop and the player taken out of driving first.

const WARN_D := 40.0                   ## metres from the nearest built thing
const KILL_D := 62.0
const TENTACLE := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn"
const HOUND := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const STING := "res://game/audio/the_veil_jumpscare_sting.wav"
const SKIP_NAMES := ["Scatter", "VeilAtmosphere"]

var world: Node
var points := PackedVector2Array()
var state := "idle"                    ## idle / warned / taken
var armed := false
var running := false
var report := {}                       ## tests: distance, stages
var _grace := 5.0
var _tick := 0.0
var _said := false
var _fog0 := -1.0
var _fog_on0 := true
var _env: Environment


func setup(w: Node) -> void:
	world = w
	for i in 3:
		await get_tree().process_frame
	_collect()


## Everything placed for play, as ground points: every instanced piece (roads, sidewalks, lots, fences, props,
## houses, shops), the west dirt roads, the map's story places. The woods' scattered trees do not count.
func _collect() -> void:
	var pts: Array = []
	for n in world.find_children("*", "Node3D", true, false):
		var n3 := n as Node3D
		if n3.scene_file_path == "" or SKIP_NAMES.has(String(n3.name)):
			continue
		var f := n3.scene_file_path.get_file()
		if f.begins_with("CRT_") or f.begins_with("CHR_") or f.begins_with("Greyhaven_") or f.begins_with("TOWN_Ground"):
			continue
		if _under_skip(n3) or _moves(n3):
			continue
		pts.append(Vector2(n3.global_position.x, n3.global_position.z))
	for line in VeilNavMap.WEST_ROADS:
		for i in (line as Array).size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var k := maxi(1, ceili(a.distance_to(b) / 5.0))
			for j in k + 1:
				pts.append(a.lerp(b, float(j) / k))
	for pl in VeilNavMap.PLACES:
		if pl[1] is Vector2:
			pts.append(pl[1])
	points = PackedVector2Array(pts)
	report["points"] = points.size()


## The player's car (and anything riding in it) and the town's moving traffic are not landmarks.
func _moves(n: Node) -> bool:
	var car = world.get("sedan")
	if car and (n == car or (car as Node).is_ancestor_of(n)):
		return true
	var lt = world.get("living")
	if lt and lt is Node and (lt as Node).is_ancestor_of(n):
		return true
	return false


func _under_skip(n: Node) -> bool:
	var p := n.get_parent()
	while p and p != world:
		if SKIP_NAMES.has(String(p.name)):
			return true
		p = p.get_parent()
	return false


func distance(at: Vector3) -> float:
	var v := Vector2(at.x, at.z)
	var best := INF
	for p in points:
		best = minf(best, v.distance_squared_to(p))
	return sqrt(best)


func _focus() -> Vector3:
	return world.sedan.global_position if world.in_car and world.sedan else world.player.global_position


func _busy() -> bool:
	if get_tree().paused or world.get("death") != null or world.get("_encounter_running") == true or world.get("conversing") == true:
		return true
	var cine = world.get("_cine")
	if cine != null and is_instance_valid(cine):
		return true
	var s := world.get_node_or_null("Struggle")
	if s != null and s.get("active") == true:
		return true                                      # (the controller node stays once made: only a live struggle)
	var p: Node3D = world.player
	if not world.in_car and (not p.visible or p.get("controls_enabled") == false):
		return true
	if world.in_car and world.sedan and world.sedan.drive_script.is_valid():
		return true                                      # a scripted drive (arrival, parking)
	return false


func _process(delta: float) -> void:
	if running or points.is_empty() or world == null:
		return
	if _grace > 0.0:
		_grace -= delta
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	if _busy():
		return
	var at := _focus()
	var d := distance(at)
	report["distance"] = d
	if d < WARN_D - 6.0:
		armed = true
		if state == "warned":
			_set_fog(0.0)
			state = "idle"
		return
	if not armed:
		return
	if d > WARN_D:
		if state == "idle":
			state = "warned"
			report["warned"] = true
			_warn(at)
		_set_fog(clampf((d - WARN_D) / (KILL_D - WARN_D), 0.0, 1.0) * 1.6)
		if d > KILL_D:
			_take.call_deferred()


func _warn(at: Vector3) -> void:
	var out := Vector3(at.x, 0, at.z) - _nearest3(at)
	out = out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	Sfx.play("colossus_call", at + out * 90.0 + Vector3(0, 10, 0), -4.0, 0.7)
	if not _said:
		_said = true
		if Dialogue.data.has("edge_warn"):
			Dialogue.say("edge_warn", false, true)


func _nearest3(at: Vector3) -> Vector3:
	var v := Vector2(at.x, at.z)
	var best := INF
	var bp := v
	for p in points:
		var d2 := v.distance_squared_to(p)
		if d2 < best:
			best = d2
			bp = p
	return Vector3(bp.x, 0, bp.y)


## The world fog, thickened by `amount` (0 = as the story has it); before the Veil it is switched on only here.
func _set_fog(amount: float) -> void:
	if _env == null:
		var cam: Camera3D = world.player.get("camera")
		_env = cam.environment if cam and cam.environment else null
		if _env == null:
			var we := world.find_child("WorldEnvironment", true, false) as WorldEnvironment
			_env = we.environment if we else null
		if _env == null:
			return
	if _fog0 < 0.0:
		_fog0 = world.fog_zones.base_density(_env) if world.get("fog_zones") else _env.fog_density
		_fog_on0 = _env.fog_enabled
	if amount <= 0.0:
		_env.fog_density = _fog0
		_env.fog_enabled = _fog_on0
		_fog0 = -1.0
		return
	_env.fog_enabled = true
	_env.fog_density = maxf(_fog0, 0.012) * (1.0 + 3.0 * amount)


# ------------------------------------------------------------------ the grab
func _take() -> void:
	if running:
		return
	running = true
	state = "taken"
	report["taken"] = true
	var hud: Node = world.hud
	hud.allow_pause = false
	hud.set_hint("")
	Dialogue.clear()
	if world.in_car:
		_out_of_car()
	var p: Node3D = world.player
	p.set("controls_enabled", false)
	p.set("look_enabled", false)
	p.set("velocity", Vector3.ZERO)
	var src: Camera3D = p.get("camera")
	var cam := Camera3D.new()
	cam.name = "EdgeCam"
	add_child(cam)
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.environment = src.environment
	cam.current = true
	report["cam"] = true
	# the Veil comes up slowly in front of him: the mist thickens round him and curtains of it rise across the way ahead
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var at := cam.global_position
	var ground := _ground_y(at)
	var curtains: Array = []
	if world.has_method("_enc_mist"):
		curtains = world._enc_mist(Vector3(at.x, ground, at.z), fwd, ground)
		for c in curtains:
			((c as MeshInstance3D).mesh as QuadMesh).material.set_shader_parameter("density", 0.0)
	var rise := create_tween().set_parallel(true)
	rise.tween_method(func(v: float): _set_fog(v), 0.0, 3.0, 4.2)
	for c in curtains:
		var cm := ((c as MeshInstance3D).mesh as QuadMesh).material as ShaderMaterial
		rise.tween_method(func(v: float): cm.set_shader_parameter("density", v), 0.0, 0.78, 4.2)
	Sfx.play("colossus_call", at + fwd * 60.0 + Vector3(0, 14, 0), 0.0, 0.6)
	await get_tree().create_timer(2.6).timeout
	Sfx.play("colossus_step", at + fwd * 25.0, 2.0, 0.6)
	# a pack of hounds comes out of it, running straight at him
	var hounds := _hounds(at, fwd, ground)
	report["hounds"] = hounds.size()
	var lead: Node3D = hounds[0] if not hounds.is_empty() else null
	var guard := 0.0
	while is_instance_valid(lead) and guard < 9.0 and lead.global_position.distance_to(at) > 3.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	report["pack_arrived"] = true
	# they jump him: the lead hound goes for the throat, the others close in; the view is thrown back
	Sfx.bank_at("hound_bark", at + fwd * 2.0, 4.0, 20.0)
	Sfx.play("hurt", at, 2.0, 0.8)
	_sting(at)
	world._shake(cam, 0.5, 0.09)
	var q0 := cam.global_basis.get_rotation_quaternion()
	var q1 := Basis.from_euler(Vector3(deg_to_rad(38.0), cam.global_rotation.y, deg_to_rad(18.0))).get_rotation_quaternion()
	var jump := create_tween().set_parallel(true)
	for i in hounds.size():
		var h: Node3D = hounds[i]
		if is_instance_valid(h):
			if h.has_meta("tween"):
				(h.get_meta("tween") as Tween).kill()
			var land := at + fwd * 0.5 + cam.global_basis.x * (i - hounds.size() / 2.0) * 0.5 + Vector3(0, 0.3 + 0.35 * i, 0)
			jump.tween_property(h, "global_position", land, 0.3 + 0.05 * i).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	jump.tween_method(func(k: float): cam.global_basis = Basis(q0.slerp(q1, k)), 0.0, 1.0, 0.35)
	await get_tree().create_timer(0.38).timeout
	report["jumped"] = true
	await hud.fade_to(1.0, 0.25)
	Sfx.play("hurt", cam.global_position, 4.0, 0.5)
	report["fade"] = true
	await get_tree().create_timer(1.2).timeout
	for h in hounds:
		if is_instance_valid(h):
			h.queue_free()
	for c in curtains:
		if is_instance_valid(c):
			c.queue_free()
	var panel := VeilChoicePanel.new()
	panel.name = "DeathPanel"
	world.add_child(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	report["death_panel"] = true
	var i: int = await panel.ask("YOU DIED", ["RETRY", "MAIN MENU"])
	get_tree().paused = false
	if i == 0:
		(func(): VeilDeathSequence.retry()).call_deferred()      # the last save: never one made out here
	else:
		world.call("_to_menu")


## Five hounds out of the mist ahead, running straight at `at`, fanned a little; each runs on its own tween until it reaches him.
func _hounds(at: Vector3, fwd: Vector3, ground: float) -> Array:
	var out: Array = []
	var ps := load(VeilMeshyNpcs.monster_scene(HOUND)) as PackedScene
	if ps == null:
		return out
	var side := fwd.cross(Vector3.UP).normalized()
	for i in 5:
		var h := ps.instantiate() as Node3D
		add_child(h)
		if h is CollisionObject3D:
			(h as CollisionObject3D).collision_layer = 0
			(h as CollisionObject3D).collision_mask = 0
		h.set_physics_process(false)
		h.scale = Vector3.ONE * 1.35
		VeilCreatureLook.apply_ground(h, ground)
		var start := at + fwd * (52.0 + i * 3.0) + side * ((i - 2) * 2.6)
		start.y = ground
		h.global_position = start
		var dv := (Vector3(at.x, ground, at.z) + side * (i - 2) * 0.3) - start
		h.rotation.y = atan2(dv.x, dv.z)                    # (the hound runs along +Z)
		var ap := h.get_node_or_null(String(h.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
		var run_v := 9.0
		var base_v: float = float(h.get_meta("run_speed_mps", 3.2)) * h.scale.x
		if ap and ap.has_animation("Run"):
			ap.play("Run")
			ap.speed_scale = run_v / maxf(base_v, 0.5)
			ap.seek(i * 0.13, true)
		var to := Vector3(at.x, ground, at.z) + side * (i - 2) * 0.3
		var tw := h.create_tween()
		tw.tween_interval(i * 0.2)
		tw.tween_property(h, "global_position", to, start.distance_to(to) / run_v)
		h.set_meta("tween", tw)
		out.append(h)
	return out


## Out of the car without the usual checks (it may be off the road, in thick mist): stopped, the player beside it.
func _out_of_car() -> void:
	var car = world.sedan
	car.speed = 0.0
	car.autopilot = Callable()
	car.set_driven(false)
	world.in_car = false
	var p: Node3D = world.player
	var spot: Variant = car.exit_spot(world.get_world_3d().direct_space_state, p.get_rid())
	p.global_position = spot if spot != null else car.global_transform * Vector3(-1.8, 0.1, 0.0)
	p.set("velocity", Vector3.ZERO)
	if p.has_method("set_yaw_pitch"):
		p.set_yaw_pitch(car.global_rotation.y, 0.0)
	if p.has_method("activate"):
		p.activate(true)
	world.hud.set_speed(-1.0)
	report["left_car"] = true


func _sting(at: Vector3) -> void:
	if not ResourceLoader.exists(STING):
		return
	var a := AudioStreamPlayer.new()
	a.stream = load(STING)
	a.volume_db = -2.0
	add_child(a)
	a.play()


func _ground_y(p: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ex: Array[RID] = [world.player.get_rid()]
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 6.0, 0), 1, ex))
	return (hit["position"] as Vector3).y if hit else p.y - 1.6
