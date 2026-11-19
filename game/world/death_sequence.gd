extends Node
class_name VeilDeathSequence
## THE VEIL - reusable death cinematic (~9.5 s), started once when the player's health reaches zero.
##   0-2 s   collapse: first person drops and rolls to street level (ground-clamped), small shake, sound muffled
##   2-5 s   the last view: the camera tilts up to the sky and rises a little, revealing the street
##   5-8 s   the town belongs to them: the Colossus strides through the fog in the distance (claw-grounded, moving
##           at its walk clip's stance rate), two or three Hounds run along the street; distant calls
##   8-10 s  fade to black, YOU DIED, RETRY (last save) / MAIN MENU
## Outdoors it plays where the player fell. Indoors (or anywhere the street can't be seen) it cuts through black to a
## fixed exterior vignette on Main St - only the camera goes there; the player is never moved and nothing spawns
## inside a building. Creatures are temporary children of this node and are freed with it. No flags, inventory or
## saves are touched; RETRY loads the most recent save.

const COLOSSUS := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Colossus.tscn"
const HOUND := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Hound.tscn"
const COLOSSUS_SCALE := 6.0
const STANCE_RATE := 1.0                 ## Walk_Heavy: a planted foot slides 1 m per animation second (scale 1)
const TIP_Y := 0.06                      ## claw tip height in the stance pose (scale 1)

var world: Node
var cam: Camera3D
var running := false
var report := {}                         ## tests: stages reached, vignette used, creatures, ground clearance
var _sounds: Array = []
var _bus_fx := -1


func play(w: Node) -> void:
	if running:
		return
	running = true
	world = w
	var player: Node3D = w.player
	var hud: Node = w.hud
	player.set("controls_enabled", false)
	player.set("velocity", Vector3.ZERO)
	hud.allow_pause = false
	hud.set_hint("")
	if hud.inv_panel and hud.inv_panel.visible:
		hud.inv_panel.close()
	Dialogue.clear()
	_muffle(true)
	cam = Camera3D.new()
	cam.name = "DeathCam"
	add_child(cam)
	var src: Camera3D = player.get("camera")
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.far = 700.0
	cam.current = true
	report["started"] = true
	# ---- 0-2 s: collapse
	var ground := _ground_y(cam.global_position)
	var down := cam.global_position
	down.y = ground + 0.28                                   # eye just above the road, never inside it
	var yaw := cam.global_rotation.y
	var b0 := cam.global_basis.get_rotation_quaternion()
	var b1 := Basis.from_euler(Vector3(deg_to_rad(-8.0), yaw, deg_to_rad(68.0))).get_rotation_quaternion()
	var p0 := cam.global_position
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var e := k * k * (3.0 - 2.0 * k)
		var j := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.02 * (1.0 - k)
		cam.global_position = p0.lerp(down, e) + j
		cam.global_basis = Basis(b0.slerp(b1, e)), 0.0, 1.0, 1.8)
	Sfx.play("hurt", p0, -4.0, 0.7)
	await tw.finished
	report["min_cam_clearance"] = cam.global_position.y - _ground_y(cam.global_position)
	# indoors, or no open sky above: cut to the exterior vignette (camera only)
	var outdoors: bool = w._outdoors() and _sky_open(cam.global_position) and not _enclosed(cam.global_position)
	report["vignette"] = not outdoors
	if not outdoors:
		await hud.fade_to(1.0, 0.5)
		var spot := _vignette_spot()
		cam.global_position = spot + Vector3(0, 0.28, 0)
		cam.global_basis = Basis.from_euler(Vector3(deg_to_rad(-8.0), _street_yaw(), deg_to_rad(68.0)))
		hud.fade_to(0.0, 0.6)
	# ---- 2-5 s: tilt up to the sky, rise a little
	var street_fwd := -cam.global_basis.z
	street_fwd.y = 0.0
	street_fwd = street_fwd.normalized() if street_fwd.length() > 0.01 else Vector3.FORWARD
	var base := cam.global_position
	var qa := cam.global_basis.get_rotation_quaternion()
	var qb := Basis.from_euler(Vector3(deg_to_rad(62.0), atan2(-street_fwd.x, -street_fwd.z), deg_to_rad(10.0))).get_rotation_quaternion()
	var t2 := create_tween()
	t2.tween_method(func(k: float):
		var e := k * k * (3.0 - 2.0 * k)
		cam.global_position = base + Vector3(0, 0.55 * e, 0) - street_fwd * 0.6 * e
		cam.global_basis = Basis(qa.slerp(qb, e)), 0.0, 1.0, 3.0)
	await t2.finished
	report["sky"] = true
	# ---- 5-8 s: the creatures own the street
	var eye := cam.global_position
	var side := street_fwd.cross(Vector3.UP).normalized()
	var colossus := _spawn_colossus(eye + street_fwd * 30.0 - side * 16.0, side)   # close enough to read in the fog
	var hounds := _spawn_hounds(eye + street_fwd * 9.0, side)
	report["creatures"] = (1 if colossus else 0) + hounds.size()
	_sounds.append(Sfx.play("colossus_call", eye + street_fwd * 40.0 + Vector3(0, 12, 0), 0.0, 0.75))
	var look := eye + street_fwd * 14.0 + Vector3(0, 2.5, 0)
	var qc := cam.global_basis.get_rotation_quaternion()
	var qd := Transform3D(Basis(), cam.global_position).looking_at(look, Vector3.UP).basis.get_rotation_quaternion()
	var qd_tilt := (Basis(qd) * Basis(Vector3.FORWARD, deg_to_rad(-12.0))).get_rotation_quaternion()   # still lying
	var t3 := create_tween()
	t3.tween_method(func(k: float):
		var e := k * k * (3.0 - 2.0 * k)
		cam.global_basis = Basis(qc.slerp(qd_tilt, e)), 0.0, 1.0, 1.6)
	await get_tree().create_timer(1.2).timeout
	_sounds.append(Sfx.play("colossus_step", eye + street_fwd * 30.0, 2.0, 0.65))
	await get_tree().create_timer(1.8).timeout
	report["creatures_shown"] = true
	# ---- 8-10 s: fade, sound out, YOU DIED
	_fade_sounds()
	await hud.fade_to(1.0, 1.2)
	_muffle(false)
	for c in get_children():
		if c != cam and c is Node3D:
			c.queue_free()                                       # nothing stays in the world
	report["fade"] = true
	var panel := VeilChoicePanel.new()
	panel.name = "DeathPanel"
	add_child(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var i: int = await panel.ask("YOU DIED", ["RETRY", "MAIN MENU"])
	report["choice"] = i
	if i == 0:
		retry()
	else:
		w._to_menu()


## RETRY: the most recent save (the game autosaves on every story flag), or a fresh start if there is none.
static func retry() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if Game.load_game():
		Game.load_requested = true
	else:
		Game.new_game()
	tree.change_scene_to_file("res://game/scenes/World.tscn")


# ------------------------------------------------------------------ helpers
func _ground_y(p: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ex: Array[RID] = [world.player.get_rid()]
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 4.0, 0), 1, ex))
	return (hit["position"] as Vector3).y if hit else p.y - 1.6


func _sky_open(p: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ex: Array[RID] = [world.player.get_rid()]
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.3, 0), p + Vector3(0, 40, 0), 1, ex)).is_empty()


## Walls close by on most sides (a room): 8 horizontal rays at knee height, 7 m.
func _enclosed(p: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ex: Array[RID] = [world.player.get_rid()]
	var hits := 0
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector3(cos(a), 0, sin(a)) * 7.0
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.3, 0), p + Vector3(0, 0.3, 0) + d, 1, ex)).is_empty():
			hits += 1
	return hits >= 6


## Main St in front of the supermarket, on the road (market-local z -27 is the street centre line).
func _vignette_spot() -> Vector3:
	var p: Vector3 = world.market.global_transform * Vector3(-4.0, 0.0, -27.0)
	p.y = _ground_y(p + Vector3(0, 2.0, 0))
	return p


func _street_yaw() -> float:
	var x: Vector3 = world.market.global_transform.basis.x
	return atan2(-x.x, -x.z)                                  # looking along Main St


func _spawn_colossus(at: Vector3, dir: Vector3) -> Node3D:
	var ps := load(COLOSSUS) as PackedScene
	if ps == null:
		return null
	var c := ps.instantiate() as Node3D
	add_child(c)
	if c is CollisionObject3D:
		(c as CollisionObject3D).collision_layer = 0
		(c as CollisionObject3D).collision_mask = 0
	c.set_physics_process(false)
	(c.get_node("Model") as Node3D).scale = Vector3.ONE * COLOSSUS_SCALE
	c.rotation.y = atan2(dir.x, dir.z)                        # the model faces +Z
	var g := _ground_y(at + Vector3(0, 3.0, 0))
	report["veil_surfaces"] = VeilCreatureLook.apply_colossus(c, g)
	c.global_position = Vector3(at.x, g - TIP_Y * COLOSSUS_SCALE + 0.02, at.z)   # stance claws on the road
	var ap := c.get_node_or_null(String(c.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
	if ap and ap.has_animation("Walk_Heavy"):
		ap.get_animation("Walk_Heavy").loop_mode = Animation.LOOP_LINEAR
		ap.play("Walk_Heavy")
		ap.speed_scale = 0.5
	var v := STANCE_RATE * COLOSSUS_SCALE * 0.5               # body speed = planted-foot slide: feet stay put
	var tw := c.create_tween()
	tw.tween_property(c, "global_position", c.global_position + dir * v * 12.0, 12.0)
	report["colossus_root_y"] = c.global_position.y - g
	return c


func _spawn_hounds(center: Vector3, dir: Vector3) -> Array:
	var out: Array = []
	var ps := load(HOUND) as PackedScene
	if ps == null:
		return out
	for i in 3:
		var h := ps.instantiate() as Node3D
		add_child(h)
		if h is CollisionObject3D:
			(h as CollisionObject3D).collision_layer = 0
			(h as CollisionObject3D).collision_mask = 0
		h.set_physics_process(false)
		h.scale = Vector3.ONE * 1.35
		report["hound_veil_surfaces"] = report.get("hound_veil_surfaces", 0) + VeilCreatureLook.apply_ground(h, center.y)
		var start: Vector3 = center - dir * (16.0 + i * 3.5) + Vector3(0, 0, 0) + dir.cross(Vector3.UP) * (i - 1) * 1.6
		start.y = _ground_y(start + Vector3(0, 2.0, 0))
		h.global_position = start
		h.rotation.y = atan2(dir.x, dir.z)
		var ap := h.get_node_or_null(String(h.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
		var speed: float = float(h.get_meta("run_speed_mps", 5.0)) * h.scale.x
		if ap and ap.has_animation("Run"):
			ap.play("Run")
			ap.seek(i * 0.13, true)
		var tw := h.create_tween()
		tw.tween_interval(i * 0.35)
		tw.tween_property(h, "global_position", start + dir * speed * 6.0, 6.0)
		out.append(h)
	return out


func _muffle(on: bool) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if on and _bus_fx < 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 900.0
		AudioServer.add_bus_effect(bus, lp)
		_bus_fx = AudioServer.get_bus_effect_count(bus) - 1
	elif not on and _bus_fx >= 0:
		AudioServer.remove_bus_effect(bus, _bus_fx)
		_bus_fx = -1


func _fade_sounds() -> void:
	for p in _sounds:
		if p and is_instance_valid(p):
			var tw := (p as AudioStreamPlayer3D).create_tween()
			tw.tween_property(p, "volume_db", -60.0, 1.0)
			tw.tween_callback(p.queue_free)
	_sounds.clear()
	Sfx.stop_ambience()


func _exit_tree() -> void:
	_muffle(false)                                             # never leave the master bus muffled
