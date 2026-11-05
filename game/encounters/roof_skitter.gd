extends Node

const HOUSE_ID:= "EXT_HOUSE_12"
const SEEN:= "egg_roof_skitter_seen"
const MODEL:= preload("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn")
const SOUND:= preload("res://game/encounters/skitter_rattle.wav")
const CLICKS:= 12
const STRUGGLE_S:= 3.0
const HISS:= preload("res://game/encounters/skitter_hiss.wav")
var world: Node
var house: Node3D
var creature: Node3D
var animation: AnimationPlayer
var roof:= Vector3.ZERO
var running:= false
var struggling:= false
var clicks:= 0
var report:= {}
var layer: CanvasLayer
var prompt: Label
var progress: ProgressBar
var click_hint: Label
var feet_y:= 0.0
var test_lights: Array = []
var sound: AudioStreamPlayer3D
var saved_controls:= true
var saved_look:= true
var saved_fov:= 72.0
var saved_yaw:= 0.0
var saved_pitch:= 0.0
var saved_position:= Vector3.ZERO
## Ground contact (Claude): while on the roof or the ground the body is tilted to the surface and set so its lowest
## animated foot touches it, every frame (the skinned mesh's padded AABB had left it floating).
const CRAWL_NATIVE:= 0.472                       ## CRT_Skitter.tscn metadata: crawl / scuttle speed at speed_scale 1
const SCUTTLE_NATIVE:= 2.588
const ESCAPE_SPEED:= 12.0
var grounded:= false
var _skel: Skeleton3D
var _feet: Array = []
var _tip_drop:= 0.0

func setup(w: Node) -> void :
	world = w
	house = w.get_node_or_null("Residential/Houses/" + HOUSE_ID)
	if house:
		for at in [Vector3(0, 3.4, 7), Vector3(0, 7, 1)]:
			var light:= OmniLight3D.new()
			house.add_child(light)
			light.position = at
			light.light_color = Color(1.0, 0.85, 0.65)
			light.light_energy = 2.8
			light.omni_range = 19.0
			light.shadow_enabled = false
			light.visible = false                # only while the encounter plays (a lit house all game long reads oddly)
			test_lights.append(light)
		_test_pointer()

## A test aid, only in a save that carries the flag "dev_roof_skitter_pointer" (never set by the game itself): a
## tall turquoise beam and a label over the house's front, gone once the encounter starts.
var _pointer: Node3D
func _test_pointer() -> void:
	if not Game.has_flag("dev_roof_skitter_pointer") or Game.has_flag(SEEN): return
	_pointer = Node3D.new()
	_pointer.name = "RoofSkitterTestPointer"
	world.add_child(_pointer)
	_pointer.global_position = house.to_global(Vector3(0, 0, 14.0))
	var beam:= MeshInstance3D.new()
	var cyl:= CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.18
	cyl.height = 30.0
	beam.mesh = cyl
	var m:= StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 1.0, 0.9, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true                          # the mist would swallow it otherwise
	beam.material_override = m
	_pointer.add_child(beam)
	beam.position = Vector3(0, 15.0, 0)
	var label:= Label3D.new()
	label.text = "SKITTER TEST\nwalk up to the front of this house"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 48
	label.modulate = Color(0.1, 1.0, 0.9)
	_pointer.add_child(label)
	label.position = Vector3(0, 4.5, 0)


func eligible() -> bool:
	if not is_instance_valid(world) or not is_instance_valid(house): return false
	var p = world.player
	return (Game.has_flag("p3_mist") and not Game.has_flag(SEEN) and not running
		and p.visible and p.controls_enabled and p.look_enabled and p.health > 0
		and not world.in_car and not world.conversing and not world.get_tree().paused
		and not world.get("_encounter_running")
		and not (world.get("_cine") and is_instance_valid(world.get("_cine"))))

func near_porch() -> bool:
	var p: Vector3 = house.to_local(world.player.global_position)



	return absf(p.x) < 5.5 and p.z > 12.0 and p.z < 26.0 and p.y < 2.0 and p.y > -1.0   # out to the street side of the yard fence (z 13.7)

func _process(_delta: float) -> void :
	if running:
		_snap()
	elif eligible() and near_porch(): _encounter()


## The Skitter's feet: the six Foot bones, and how far below a Foot bone its claw tip reaches (rest pose: the
## lowest mesh vertex vs the lowest Foot bone, in the creature's own frame).
func _measure_feet() -> void:
	var rigs:= creature.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty(): return
	_skel = rigs[0]
	_feet.clear()
	for i in _skel.get_bone_count():
		if _skel.get_bone_name(i).ends_with("_Foot"): _feet.append(i)
	# each claw tip: the lowest vertex close (horizontally) to its Foot bone, in the rest pose
	var inv:= creature.global_transform.affine_inverse()
	var verts: Array = []
	for mi in creature.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null: continue
		var xf: Transform3D = inv * (mi as MeshInstance3D).global_transform
		for si in m.get_surface_count():
			for v in m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				verts.append(xf * v)
	var drops: Array = []
	for b in _feet:
		var f: Vector3 = inv * (_skel.global_transform * _skel.get_bone_global_rest(b).origin)
		var low:= f.y
		for v in verts:
			if Vector2(v.x - f.x, v.z - f.z).length() < 0.25 and v.y < low: low = v.y
		drops.append(f.y - low)
	if not drops.is_empty():
		var sum:= 0.0
		for d in drops: sum += d
		_tip_drop = sum / drops.size()
	report["tip_drop"] = _tip_drop


func _lowest_foot() -> float:
	var low:= INF
	for b in _feet:
		low = minf(low, (_skel.global_transform * _skel.get_bone_global_pose(b).origin).y)
	return low - _tip_drop * creature.scale.y


func _snap() -> void:
	if not grounded or not is_instance_valid(creature) or creature.get_parent() != world or _skel == null or _feet.is_empty(): return
	var space:= house.get_world_3d().direct_space_state
	var hit:= space.intersect_ray(PhysicsRayQueryParameters3D.create(creature.global_position + Vector3.UP * 1.5, creature.global_position - Vector3.UP * 3.0, 1))
	if hit.is_empty(): return
	var n: Vector3 = hit.normal
	var fwd: Vector3 = creature.global_basis.z
	fwd = (fwd - n * fwd.dot(n)).normalized()
	if fwd.length() > 0.1:
		var b:= Basis(n.cross(fwd).normalized(), n, fwd)
		creature.global_basis = b.scaled(creature.scale)
	var dy: float = float(hit.position.y) - _lowest_foot()
	report["max_contact_fix"] = maxf(float(report.get("max_contact_fix", 0.0)), absf(dy))
	creature.global_position.y += dy
	report["grounded_frames"] = int(report.get("grounded_frames", 0)) + 1

func _input(event: InputEvent) -> void :
	if not struggling: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: clicks += 1
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()

func _play(name: String) -> void :
	if animation and animation.has_animation(name): animation.play(name)

func _spawn() -> void :
	var at:= house.to_global(Vector3(-4.0, 0, 10.0))
	var query:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 25, at + Vector3.UP * 2, 1)
	var hit:= house.get_world_3d().direct_space_state.intersect_ray(query)
	roof = hit.position if not hit.is_empty() else house.to_global(Vector3(0, 4.5, 2.5))
	creature = MODEL.instantiate()
	creature.name = "OptionalRoofSkitter"
	world.add_child(creature)
	creature.collision_layer = 0
	creature.collision_mask = 0
	creature.set_physics_process(false)
	VeilCreatureLook.apply_skitter(creature, house.global_position.y)
	for mesh in creature.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat = mesh.get_surface_override_material(i)
			if mat is ShaderMaterial:
				mat.set_shader_parameter("albedo_mul", 1.0)
				mat.set_shader_parameter("distance_fade", 0.0)
				mat.set_shader_parameter("ambient", 0.8)
				mat.set_shader_parameter("key_energy", 0.9)
	var bounds:= Interactable.aabb_of(creature)
	feet_y = bounds.position.y
	creature.global_position = roof - Vector3(0, bounds.position.y, 0)
	var toward: Vector3 = world.player.global_position - roof
	creature.rotation.y = atan2(toward.x, toward.z)
	animation = creature.get_node_or_null("Model/AnimationPlayer")
	_measure_feet()
	for light in test_lights: light.visible = true
	_play("Alert")
	sound = AudioStreamPlayer3D.new()
	sound.stream = SOUND
	sound.unit_size = 10.0
	creature.add_child(sound)
	report["rooftop"] = creature.global_position.y > house.global_position.y + 2.0

func _ui() -> void :
	layer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var panel:= Control.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt = Label.new()
	panel.add_child(prompt)
	var viewport_size:= get_viewport().get_visible_rect().size
	prompt.position = Vector2(0, viewport_size.y * 0.5 - 40)
	prompt.size = Vector2(viewport_size.x, 70)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	VeilUI.style_text(prompt, 52, Color(1, 0.08, 0.06))
	prompt.text = "GET IT OFF!"
	click_hint = Label.new()
	panel.add_child(click_hint)
	click_hint.position = Vector2(0, viewport_size.y * 0.5 + 35)
	click_hint.size = Vector2(viewport_size.x, 40)
	click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	VeilUI.style_text(click_hint, 26)
	progress = ProgressBar.new()
	panel.add_child(progress)
	progress.position = Vector2(viewport_size.x * 0.5 - 180, viewport_size.y * 0.5 + 83)
	progress.size = Vector2(360, 12)
	progress.max_value = CLICKS
	progress.show_percentage = false
	var fill:= StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.04, 0.03)
	progress.add_theme_stylebox_override("fill", fill)
	var background:= StyleBoxFlat.new()
	background.bg_color = Color(0.06, 0.02, 0.02, 0.9)
	progress.add_theme_stylebox_override("background", background)
	report["pixel_font"] = prompt.get_theme_font("font") == VeilUI.font()

func _roof_at(z: float, x:= 0.0) -> Vector3:
	var at:= house.to_global(Vector3(x, 0, z))
	var hit:= house.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 25, at + Vector3.UP * 2, 1))
	return hit.position if not hit.is_empty() else Vector3(at.x, roof.y, at.z)

func _encounter() -> void :
	running = true
	if is_instance_valid(_pointer): _pointer.queue_free()
	Game.set_flag(SEEN)
	var p = world.player
	var cam: Camera3D = p.camera
	saved_controls = p.controls_enabled
	saved_look = p.look_enabled
	saved_fov = cam.fov
	saved_yaw = p.rotation.y
	saved_pitch = p.head.rotation.x
	saved_position = p.global_position
	p.controls_enabled = false
	p.look_enabled = false
	p.velocity = Vector3.ZERO
	_spawn()
	sound.play()
	var direction:= (creature.global_position + Vector3.UP * 0.3 - cam.global_position).normalized()
	var yaw:= atan2( - direction.x, - direction.z)
	var pitch:= asin(clampf(direction.y, -1, 1))
	var t:= 0.0
	while t < 0.3:
		t += get_process_delta_time()
		var k:= clampf(t / 0.3, 0, 1)
		p.set_yaw_pitch(lerp_angle(saved_yaw, yaw, k), lerpf(saved_pitch, pitch, k))
		cam.fov = lerpf(saved_fov, 55.0, k)
		await get_tree().process_frame

	_play("Crawl")
	var crawl_start:= _roof_at(10.0, -4.0) - Vector3.UP * feet_y
	if animation: animation.speed_scale = clampf(crawl_start.distance_to(_roof_at(10.8, 0.0) - Vector3.UP * feet_y) / 2.8 / CRAWL_NATIVE, 0.5, 4.0)
	grounded = true
	report["roof_visible_frames"] = 0
	creature.global_position = crawl_start
	t = 0.0
	while t < 2.8:
		t += get_process_delta_time()
		var k:= clampf(t / 2.8, 0, 1)
		creature.global_position = _roof_at(lerpf(10.0, 10.8, k), lerpf(-4.0, 0.0, k)) - Vector3.UP * feet_y
		_snap()
		var visible_ray:= PhysicsRayQueryParameters3D.create(cam.global_position, creature.global_position + Vector3.UP * 0.4, 1)
		if house.get_world_3d().direct_space_state.intersect_ray(visible_ray).is_empty(): report["roof_visible_frames"] += 1
		var aim:= (creature.global_position + Vector3.UP * 0.3 - cam.global_position).normalized()
		yaw = atan2( - aim.x, - aim.z)
		pitch = asin(clampf(aim.y, -1, 1))
		p.set_yaw_pitch(yaw, pitch)
		cam.fov = lerpf(55.0, 43.0, smoothstep(0, 1, minf(t / 0.7, 1)))
		await get_tree().process_frame
	roof = creature.global_position
	report["crawl_distance"] = crawl_start.distance_to(roof)
	report["crawl_s"] = t
	if animation: animation.speed_scale = 1.0
	grounded = false
	_play("Attack_Lunge")
	var start:= creature.global_position
	var jump_rotation:= creature.quaternion
	var top_pitch:= pitch
	t = 0.0
	while t < 0.65:
		t += get_process_delta_time()
		var k:= clampf(t / 0.65, 0, 1)
		p.set_yaw_pitch(yaw, lerpf(top_pitch, 0.0, smoothstep(0.0, 1.0, k)))
		cam.fov = lerpf(43.0, saved_fov, smoothstep(0.0, 1.0, k))
		var landing:= cam.to_global(Vector3(0, -0.3, -0.85))
		creature.global_position = start.lerp(landing, k) + Vector3.UP * sin(k * PI) * 2.0
		creature.quaternion = jump_rotation.slerp(cam.global_basis.get_rotation_quaternion(), k)
		creature.scale = Vector3.ONE * lerpf(1.0, 0.55, k)
		await get_tree().process_frame
	var landed_at:= creature.global_position
	creature.reparent(cam)
	report["landing_snap_m"] = creature.global_position.distance_to(landed_at)
	report["high_leap"] = true
	if animation and animation.has_animation("Attack_Lunge"):
		var bite: Animation = animation.get_animation("Attack_Lunge").duplicate(true)
		bite.loop_mode = Animation.LOOP_LINEAR
		var library:= AnimationLibrary.new()
		library.add_animation("Bite", bite)
		animation.add_animation_library("Struggle", library)
		animation.speed_scale = 1.8
		animation.play("Struggle/Bite", 0.08)
		report["biting_loop"] = true
	sound.play()
	_ui()
	struggling = true
	t = 0.0
	while t < STRUGGLE_S and clicks < CLICKS:
		t += get_process_delta_time()
		prompt.text = "GET IT OFF!"
		var pulse:= 0.65 + 0.35 * (sin(t * 15.0) * 0.5 + 0.5)
		prompt.modulate = Color(1, pulse, pulse, 0.75 + 0.25 * sin(t * 15.0) * sin(t * 15.0))
		click_hint.text = "CLICK FAST  %d / %d   %.1fs" % [clicks, CLICKS, maxf(0, STRUGGLE_S - t)]
		progress.value = clicks
		cam.rotation.z = sin(t * 38.0) * 0.025
		creature.position.x = sin(t * 28.0) * 0.035
		creature.position.y = -0.3 + sin(t * 34.0) * 0.018
		creature.position.z = -0.85 + maxf(0.0, sin(t * TAU * 1.8)) * 0.07
		await get_tree().process_frame
	struggling = false
	var won:= clicks >= CLICKS
	report["won"] = won
	report["health_before"] = p.health
	if not won:
		p.health *= 0.5
		p.health_changed.emit(p.health, p.MAX_HEALTH)
	report["health_after"] = p.health
	prompt.text = "YOU THREW IT OFF" if won else "IT BIT YOU!"
	prompt.modulate = Color.WHITE
	click_hint.text = ""

	creature.reparent(world)
	var thrown_from:= creature.global_position
	var forward:= - cam.global_basis.z * Vector3(1, 0, 1)
	forward = forward.normalized()
	var right:= cam.global_basis.x.normalized()
	var plan:= _escape_plan(right)
	var landing: Vector3 = plan[0]
	var exit: Vector3 = plan[1]
	report["escape_clear"] = not plan[2].is_empty()
	report["throw_side"] = signf((landing - saved_position).dot(right))
	if animation: animation.speed_scale = 1.0
	_play("Hit_React")
	t = 0.0
	while t < 0.55:
		t += get_process_delta_time()
		var k:= clampf(t / 0.55, 0, 1)
		creature.global_position = thrown_from.lerp(landing, k) + Vector3.UP * sin(k * PI) * 0.7
		creature.scale = Vector3.ONE * lerpf(0.55, 1.0, k)
		creature.rotation.z = sin(k * PI) * 0.7
		_track_ground(cam, p, k)
		await get_tree().process_frame
	creature.global_position = landing
	creature.rotation.z = 0
	grounded = true
	report["ground_landing"] = absf(creature.global_position.y - _ground(landing).y) < 0.05
	# Frame the threat from its front, using the actual lens, not the capsule.
	var facing := (cam.global_position - creature.global_position) * Vector3(1,0,1)
	creature.rotation = Vector3(0, atan2(facing.x,facing.z), 0)
	_play("Alert")
	if animation: animation.seek(0.25, true)
	report["front_legs_raised"] = animation != null and animation.has_animation("Alert")
	sound.stream = HISS
	sound.play()
	report["hissed"] = sound.playing
	t = 0.0
	while t < 0.6:
		t += get_process_delta_time()
		var aim := (cam.global_position-creature.global_position) * Vector3(1,0,1)
		creature.rotation.y = atan2(aim.x,aim.z)
		_snap()
		_track_ground(cam,p,1.0)
		await get_tree().process_frame
	var toward_lens := ((cam.global_position-creature.global_position)*Vector3(1,0,1)).normalized()
	report["facing_lens_dot"] = creature.global_basis.z.normalized().dot(toward_lens)
	for rig in creature.find_children("*","Skeleton3D",true,false):
		var head: int = rig.find_bone("Head")
		var body: int = rig.find_bone("Body")
		if head>=0 and body>=0:
			var anatomy: Vector3 = rig.global_basis * (rig.get_bone_global_pose(head).origin-rig.get_bone_global_pose(body).origin)
			anatomy.y=0
			report["anatomical_facing_dot"] = anatomy.normalized().dot(toward_lens)
	report["faced_player_for_hiss"] = report.get("anatomical_facing_dot",0.0)>0.85
	_play("Scuttle_Fast")
	if animation: animation.speed_scale = ESCAPE_SPEED / SCUTTLE_NATIVE      # the legs keep pace with the run
	var route: Array = plan[2]
	report["zigzag_segments"] = route.size()
	report["escape_segments_clear"] = true
	var last:= landing
	for destination in route:
		if not _clear_run(last, destination):
			report["escape_segments_clear"] = false
			break
		var distance:= last.distance_to(destination)
		creature.rotation.y = atan2(destination.x - last.x, destination.z - last.z)
		t = 0.0
		var duration:= maxf(distance / ESCAPE_SPEED, 0.04)
		while t < duration:
			t += get_process_delta_time()
			creature.global_position = _ground(last.lerp(destination, clampf(t / duration, 0, 1)))
			_snap()
			_track_ground(cam,p,1.0)
			await get_tree().process_frame
		last = destination
	report["returned_toward_house"] = last.distance_to(house.global_position) < landing.distance_to(house.global_position)
	report["escaped_left"] = house.to_local(last).x < house.to_local(saved_position).x
	var occlusion := house.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position,last + Vector3.UP * 0.3,1))
	report["hidden_behind_house"] = not occlusion.is_empty()
	if not occlusion.is_empty(): report["occluder"] = String(occlusion.collider.name)
	_cleanup()
	report["escaped"] = true
	running = false

func _escape_plan(right: Vector3) -> Array:
	var away := house.global_basis.z.normalized()
	# Always the player's LEFT. Never choose an arbitrary side or retreat behind
	# the player's back; try nearby clear spots in the same sideward sector.
	for offset in [0.0, -0.6, 0.6, 1.2]:
		for lateral in [3.0, 4.0, 5.0, 6.0]:
			var landing := _ground(saved_position - right.normalized() * lateral + away * offset)
			var route := _zigzag_home(landing)
			if not route.is_empty(): return [landing,route[-1],route]
	return [_ground(saved_position-right*3.0), _ground(saved_position-right*3.0), []]

func _zigzag_home(start: Vector3) -> Array:
	# Run around the house's left exterior, then behind its far wall. Endpoints
	# remain outside the house footprint (x -5.57..6.45, z 0..12.8).
	for flank in [-8.0,-9.0,-10.0,-7.2]:
		for front_z in [15.5,17.0,14.5,19.0]:
			for amplitude in [0.55,0.3,0.15]:
				var controls: Array = [start, _ground(house.to_global(Vector3(flank,0,front_z))),
					_ground(house.to_global(Vector3(flank,0,-2.0))), _ground(house.to_global(Vector3(-3.0,0,-2.0)))]
				var route: Array = []
				var last := start
				var clear := true
				var zig := 0
				for section in range(1,controls.size()):
					var begin: Vector3 = controls[section-1]
					var end: Vector3 = controls[section]
					var sideways := (end-begin).normalized().cross(Vector3.UP)
					var steps := maxi(2,ceili(begin.distance_to(end)/1.8))
					for i in range(1,steps+1):
						var at := begin.lerp(end,float(i)/steps)
						if i < steps: at += sideways * amplitude * (1.0 if zig%2==0 else -1.0)
						zig += 1
						at = _ground(at)
						if not _clear_run(last,at):
							clear = false
							break
						route.append(at)
						last = at
					if not clear: break
				if clear: return route
	return []

func _ground(at: Vector3) -> Vector3:
	var hit:= house.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at - Vector3.UP * 5.0, 1))
	return Vector3(at.x, float(hit.position.y) - feet_y, at.z) if not hit.is_empty() else Vector3(at.x, saved_position.y, at.z)

func _clear_run(start: Vector3, end: Vector3) -> bool:
	var query:= PhysicsShapeQueryParameters3D.new()
	var sphere:= SphereShape3D.new()
	sphere.radius = 0.95
	query.shape = sphere
	query.transform = Transform3D(Basis(), start + Vector3.UP * 1.0)
	query.motion = end - start
	query.collision_mask = 1
	var space:= house.get_world_3d().direct_space_state
	var motion:= query.motion
	query.motion = Vector3.ZERO
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.motion = motion
	var result:= space.cast_motion(query)
	return result.size() == 2 and result[0] >= 0.99

func _track_ground(cam: Camera3D, p: Node, k: float) -> void :
	var aim:= (creature.global_position + Vector3.UP * 0.25 - cam.global_position).normalized()
	p.set_yaw_pitch(lerp_angle(p.rotation.y, atan2( - aim.x, - aim.z), 0.12), lerpf(p.head.rotation.x, asin(clampf(aim.y, -1, 1)), 0.12))
	cam.rotation.z *= 1.0 - k

func _cleanup() -> void :
	grounded = false
	for light in test_lights:
		if is_instance_valid(light): light.visible = false
	if is_instance_valid(creature): creature.queue_free()
	if is_instance_valid(layer): layer.queue_free()
	if is_instance_valid(world) and is_instance_valid(world.player):
		var p = world.player
		p.camera.rotation.z = 0.0
		p.camera.fov = saved_fov
		p.set_yaw_pitch(saved_yaw, saved_pitch)
		p.global_position = saved_position
		p.controls_enabled = saved_controls
		p.look_enabled = saved_look

func _exit_tree() -> void :
	if running: _cleanup()
	for light in test_lights:
		if is_instance_valid(light): light.queue_free()
