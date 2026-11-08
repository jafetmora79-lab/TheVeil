extends Node
class_name VeilWorldEdge
## THE VEIL - the Veil does not let you leave. Far past everything built for play (the town, its roads, houses,
## lots, story places and supply caches) the mist closes in; keep going and a Colossus tentacle takes you.
##   WARN_D  - the mist thickens with distance, a deep call far off, one line: "This road doesn't feel right..."
##             Turning back clears it again.
##   KILL_D  - heavy mist, a rumble, a huge tentacle bursts up in front, grabs and lifts (camera shake), a crushing
##             thud into black, then the usual YOU DIED - RETRY (last save) / MAIN MENU.
## Before the story's Veil this is only local fog (no flags, no chapter change); after it the existing fog is used.
## Never during a cinematic, an encounter, a conversation, a struggle or a death; never saves, never sets a flag.
## Armed only once the player has been inside the playable area (a save far out cannot loop), plus a short grace
## after every load. In the car: it is brought to a stop and the player taken out of driving first.

const WARN_D := 40.0                   ## metres from the nearest built thing
const KILL_D := 62.0
const TENTACLE := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn"
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
	_set_fog(3.0)                                        # the mist closes in
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var at := cam.global_position
	Sfx.play("colossus_step", at + fwd * 25.0, 4.0, 0.6)
	Sfx.play("colossus_call", at + fwd * 40.0 + Vector3(0, 15, 0), 2.0, 0.75)
	world._shake(cam, 0.6, 0.03)
	await get_tree().create_timer(1.1).timeout
	# a tentacle the size of a tree, up out of the ground in front
	var t := (load(TENTACLE) as PackedScene).instantiate() as Node3D
	t.name = "EdgeTentacle"
	t.set("autoplay", "")
	add_child(t)
	t.set_process(false)
	var mats = t.get("_mats")
	if mats is Array:
		for m in mats:
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("mist_level", -50.0)
				(m as ShaderMaterial).set_shader_parameter("fade_height", 0.05)
	var base := Vector3(at.x, _ground_y(at), at.z) + fwd * 5.5
	var face := Basis.looking_at(-fwd, Vector3.UP)
	t.global_transform = Transform3D(face.scaled(Vector3.ONE * 2.6), base - Vector3(0, 9.0, 0))
	var ap := t.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.get_animation_list().size() > 0:
		ap.play(ap.get_animation_list()[0])
	_sting(at)
	var up := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	up.tween_property(t, "global_position", base, 0.7)
	await up.finished
	report["tentacle"] = true
	world._shake(cam, 0.35, 0.05)
	# it lunges and has him: shake, lifted off the ground and pulled toward it
	var lunge := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lunge.tween_property(t, "global_position", base - fwd * 3.2 + Vector3(0, -0.6, 0), 0.22)
	await lunge.finished
	Sfx.play("hurt", at, 0.0, 0.7)
	report["grabbed"] = true
	var lift_to := base + Vector3(0, 6.5, 0) - fwd * 1.0
	var b0 := cam.global_basis.get_rotation_quaternion()
	var b1 := Basis.from_euler(Vector3(deg_to_rad(-55.0), cam.global_rotation.y + 0.6, deg_to_rad(35.0))).get_rotation_quaternion()
	var start := cam.global_position
	var dur := 1.3
	var k := 0.0
	while k < dur:
		k += get_process_delta_time()
		var e := clampf(k / dur, 0.0, 1.0)
		e = e * e * (3.0 - 2.0 * e)
		cam.global_position = start.lerp(lift_to, e) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.06
		cam.global_basis = Basis(b0.slerp(b1, e))
		t.global_position = base.lerp(base + Vector3(0, 2.5, 0), e)
		await get_tree().process_frame
	report["lifted"] = true
	await hud.fade_to(1.0, 0.18)
	Sfx.play("colossus_step", cam.global_position, 6.0, 0.5)   # the crush, in the dark
	Sfx.play("hurt", cam.global_position, 4.0, 0.5)
	report["fade"] = true
	await get_tree().create_timer(1.0).timeout
	t.queue_free()
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
