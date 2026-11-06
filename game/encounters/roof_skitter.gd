extends Node

const HOUSE_ID:= "HOUSE_03"            ## the ranch house in the row behind the supermarket (same model as Codex's first pick)
const SEEN:= "egg_roof_skitter_seen"
const MODEL:= preload("res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn")
const SOUND:= preload("res://game/encounters/skitter_rattle.wav")
const CLICKS:= 12
const STRUGGLE_S:= 3.0
const HISS:= preload("res://game/encounters/skitter_hiss.wav")
const STING:= preload("res://game/audio/the_veil_jumpscare_sting.wav")
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
const HISS_S:= 1.4                                  ## the hiss at the player before it scatters
const DROP_S:= 0.45                                 ## off the gable to the yard
const RUSH_SPEED:= 9.0                              ## the run at the player, m/s
const LEAP_FROM:= 3.2                               ## it leaps from this far out
const LEAP_S:= 0.42
const CHEST_H:= 0.28                                ## the player's chest, lying down
const LYING_EYE:= 0.32                              ## the eye height, lying on the back
const PINNED_PITCH:= 0.55                           ## looking up at it
var grounded:= false
## The house's collision is a simplified block whose top stands well above the visible pitched roof (the creature
## crawled on it in mid-air). On the roof everything is measured against a collision copy of the VISIBLE roof meshes,
## on a layer of its own, built only while the encounter runs.
const VIS_LAYER:= 1 << 19
var on_roof:= false
var _vis_bodies: Array = []
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
	# any time after the Veil has rolled in (any chapter), whenever the player walks up to that house on their own:
	# never in a story scene, a conversation, the car, another encounter or the run from the game shop
	var veil: bool = Game.has_flag("p3_mist")
	var story_run: bool = Game.has_flag("p3_fled_together") and not Game.has_flag("p3_in_market")
	return (veil and not story_run and not Game.has_flag(SEEN) and not running
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
func _build_visual_roof() -> void:
	for mi in house.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null or "Furnishing" in String(mi.get_path()): continue
		var body:= StaticBody3D.new()
		body.collision_layer = VIS_LAYER
		body.collision_mask = 0
		var cs:= CollisionShape3D.new()
		cs.shape = m.create_trimesh_shape()
		body.add_child(cs)
		world.add_child(body)
		body.global_transform = (mi as MeshInstance3D).global_transform
		_vis_bodies.append(body)
	report["visual_roof_bodies"] = _vis_bodies.size()


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
	var hit:= space.intersect_ray(PhysicsRayQueryParameters3D.create(creature.global_position + Vector3.UP * 1.5, creature.global_position - Vector3.UP * 3.0, VIS_LAYER if on_roof else 1))
	if on_roof:
		report["roof_contact_frames" if not hit.is_empty() else "roof_miss_frames"] = int(report.get("roof_contact_frames" if not hit.is_empty() else "roof_miss_frames", 0)) + 1
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
	var at:= house.to_global(Vector3(6.0, 0, 11.0))     # on the visible front gable (the old spot had no roof)
	var query:= PhysicsRayQueryParameters3D.create(at + Vector3.UP * 25, at + Vector3.UP * 0.5, VIS_LAYER)
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
	var hit:= house.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 25, at + Vector3.UP * 0.5, VIS_LAYER))
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
	_build_visual_roof()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn()
	_sting(-12.0)                                     # it appears: the horror sting (no high rattle)
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
	var crawl_start:= _roof_at(11.0, 6.0) - Vector3.UP * feet_y
	if animation: animation.speed_scale = clampf(crawl_start.distance_to(_roof_at(11.6, 2.5) - Vector3.UP * feet_y) / 2.8 / CRAWL_NATIVE, 0.5, 4.0)
	grounded = true
	on_roof = true
	report["roof_visible_frames"] = 0
	creature.global_position = crawl_start
	t = 0.0
	while t < 2.8:
		t += get_process_delta_time()
		var k:= clampf(t / 2.8, 0, 1)
		creature.global_position = _roof_at(lerpf(11.0, 11.6, k), lerpf(6.0, 2.5, k)) - Vector3.UP * feet_y
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
	on_roof = false
	# ---- off the roof, across the yard at a run, and the leap: the player goes down on their back, pinned
	var cam0:= cam.position
	var ground_at:= _ground(saved_position)
	var face_dir:= (saved_position - creature.global_position) * Vector3(1, 0, 1)
	face_dir = face_dir.normalized()
	# the drop from the gable edge to the yard below
	var drop_from:= creature.global_position
	var drop_to:= _ground(drop_from + face_dir * 2.2)
	creature.rotation = Vector3(0, atan2(face_dir.x, face_dir.z), 0)
	# a fence (or anything solid) between the yard and the player: no run through it - one leap from the roof instead
	var rush_to:= (saved_position - drop_to) * Vector3(1, 0, 1)
	var open_yard:= _clear_run(drop_to, _ground(drop_to + rush_to.normalized() * maxf(rush_to.length() - LEAP_FROM, 0.0)))
	report["open_yard"] = open_yard
	_play("Attack_Lunge")
	t = 0.0
	while open_yard and t < DROP_S:
		t += get_process_delta_time()
		var k:= clampf(t / DROP_S, 0, 1)
		creature.global_position = drop_from.lerp(drop_to, k) + Vector3.UP * sin(k * PI) * 0.6
		_aim_at_creature(cam, p, 0.3)
		cam.fov = lerpf(43.0, 58.0, k)
		await get_tree().process_frame
	if open_yard:
		creature.global_position = drop_to
		grounded = true
		_snap()
	# the run straight at the player
	if open_yard: _play("Scuttle_Fast")
	if animation: animation.speed_scale = RUSH_SPEED / SCUTTLE_NATIVE
	var run_from:= creature.global_position
	var to_player:= (saved_position - run_from) * Vector3(1, 0, 1)
	var run_to:= _ground(run_from + to_player.normalized() * maxf(to_player.length() - LEAP_FROM, 0.0))
	if not open_yard: run_to = run_from
	var run_s:= maxf(run_from.distance_to(run_to) / RUSH_SPEED, 0.05) if open_yard else 0.0
	report["rush_m"] = run_from.distance_to(run_to)
	report["rush_s"] = run_s
	t = 0.0
	while t < run_s:
		t += get_process_delta_time()
		creature.global_position = _ground(run_from.lerp(run_to, clampf(t / run_s, 0, 1)))
		creature.rotation = Vector3(0, atan2(to_player.x, to_player.z), 0)
		_snap()
		_aim_at_creature(cam, p, 0.35)
		_hold_still(p)
		cam.fov = lerpf(58.0, saved_fov, clampf(t / run_s, 0, 1))
		await get_tree().process_frame
	grounded = false
	# the leap: it lands on the chest as the player falls backwards
	if animation: animation.speed_scale = 1.4
	_play("Attack_Lunge")
	var leap_from:= creature.global_position
	var fwd:= to_player.normalized()                     # from it to the player: the player falls this way (backwards)
	var chest:= Vector3(saved_position.x, ground_at.y + CHEST_H, saved_position.z)
	var eye_drop:= cam.global_position.y - (ground_at.y + feet_y + LYING_EYE)
	var down_back:= Vector3.DOWN * eye_drop + fwd * 0.55      # the head ends up on the ground, behind where they stood
	var yaw_hold:= atan2(fwd.x, fwd.z)                 # still facing it, now along the body (the camera looks along -z)
	var pitch0: float = p.head.rotation.x
	var leap_s:= LEAP_S if open_yard else LEAP_S * 1.6
	var fov_start:= cam.fov
	var arc:= maxf(1.1, Vector2(leap_from.x - chest.x, leap_from.z - chest.z).length() * 0.3)    # well over any fence
	t = 0.0
	while t < leap_s:
		t += get_process_delta_time()
		var k:= clampf(t / leap_s, 0, 1)
		var fall:= smoothstep(0.15, 1.0, k)
		creature.global_position = leap_from.lerp(chest, k) + Vector3.UP * sin(k * PI) * arc
		creature.rotation = Vector3(-0.5 * sin(k * PI), atan2(fwd.x, fwd.z), 0)
		p.set_yaw_pitch(yaw_hold, lerpf(pitch0, PINNED_PITCH, fall))
		_hold_still(p)
		cam.position = cam0 + p.head.global_basis.inverse() * (down_back * fall)
		cam.rotation.z = sin(fall * PI) * 0.25
		cam.fov = lerpf(fov_start, 64.0, fall)
		await get_tree().process_frame
	Sfx.play("hurt", cam.global_position, 0.0, 0.8)
	creature.global_position = chest
	report["pinned"] = true
	report["landing_snap_m"] = 0.0
	report["high_leap"] = true
	report["camera_on_ground_m"] = cam.global_position.y - ground_at.y - feet_y
	if animation and animation.has_animation("Attack_Lunge"):
		var bite: Animation = animation.get_animation("Attack_Lunge").duplicate(true)
		bite.loop_mode = Animation.LOOP_LINEAR
		var library:= AnimationLibrary.new()
		library.add_animation("Bite", bite)
		animation.add_animation_library("Struggle", library)
		animation.speed_scale = 1.8
		animation.play("Struggle/Bite", 0.08)
		report["biting_loop"] = true
	sound.stream = HISS                               # on top of the player: its own low hiss (the sting was its entrance)
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
		# on top of the player: it rocks and lunges down at the face; the view thrashes under it
		var lunge:= maxf(0.0, sin(t * TAU * 1.8))
		var side:= fwd.cross(Vector3.UP).normalized()
		creature.global_position = chest + side * sin(t * 28.0) * 0.05 + fwd * lunge * 0.12 + Vector3.UP * sin(t * 34.0) * 0.02
		creature.rotation.x = 0.1 + lunge * 0.3                # head down at the face
		var aim:= (creature.global_position + Vector3.UP * 0.25 - cam.global_position).normalized()
		p.set_yaw_pitch(yaw_hold, lerpf(p.head.rotation.x, clampf(asin(clampf(aim.y, -1, 1)), 0.2, 1.35), 0.2))
		cam.rotation.z = sin(t * 38.0) * 0.06
		_hold_still(p)
		cam.position = cam0 + p.head.global_basis.inverse() * (down_back + Vector3(sin(t * 31.0) * 0.02, sin(t * 23.0) * 0.015, 0))
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

	creature.rotation.x = 0.0
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
		creature.rotation.z = sin(k * PI) * 0.7
		cam.position = cam0 + p.head.global_basis.inverse() * (down_back * (1.0 - smoothstep(0.0, 1.0, k)))    # back on their feet
		_hold_still(p)
		_track_ground(cam, p, k)
		await get_tree().process_frame
	creature.global_position = landing
	creature.rotation.z = 0
	cam.position = cam0
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
	while t < HISS_S:                                   # it rears up facing the player and hisses, in plain view
		t += get_process_delta_time()
		var aim := (cam.global_position-creature.global_position) * Vector3(1,0,1)
		creature.rotation.y = atan2(aim.x,aim.z)
		_snap()
		_aim_at_creature(cam, p, 0.25)
		cam.rotation.z = 0.0
		_hold_still(p)
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
		var hop:= 0.0 if _open_line(last, destination) else 1.5      # a fence in the way: over it
		if hop > 0.0: report["escape_hops"] = int(report.get("escape_hops", 0)) + 1
		var distance:= last.distance_to(destination)
		creature.rotation.y = atan2(destination.x - last.x, destination.z - last.z)
		t = 0.0
		var duration:= maxf(distance / ESCAPE_SPEED, 0.35 if hop > 0.0 else 0.04)
		while t < duration:
			t += get_process_delta_time()
			var kk:= clampf(t / duration, 0, 1)
			creature.global_position = _ground(last.lerp(destination, kk)) + Vector3.UP * sin(kk * PI) * hop
			if hop == 0.0: _snap()
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
	for offset in [0.0, -0.6, 0.6, 1.2, -1.2]:
		for lateral in [3.0, 2.2, 4.0, 5.0, 6.0]:
			var landing := _ground(saved_position - right.normalized() * lateral + away * offset)
			if not _open_line(saved_position, landing): continue       # never thrown through a fence
			var route := _zigzag_home(landing)
			if not route.is_empty(): return [landing,route[-1],route]
	# fenced in: a clear landing on the player's side, then the way home, hopping whatever is in the way
	for offset in [0.0, -0.6, 0.6, 1.2, -1.2]:
		for lateral in [3.0, 2.2, 4.0, 1.6, 5.0]:
			for side in [1.0, -1.0]:
				var landing := _ground(saved_position - right.normalized() * lateral * side + away * offset)
				if _open_line(saved_position, landing):
					var route := _direct_home(landing)
					return [landing, route[-1], route]
	var fallback := _ground(saved_position - right.normalized() * 1.6)
	return [fallback, fallback, _direct_home(fallback)]

## Round the house's left side and behind it, in short steps (no clearance demands: blocked steps are hopped).
func _direct_home(start: Vector3) -> Array:
	var controls: Array = [start, _ground(house.to_global(Vector3(-8.0, 0, 15.5))), _ground(house.to_global(Vector3(-8.0, 0, -2.0))),
		_ground(house.to_global(Vector3(-3.0, 0, -2.0)))]
	var route: Array = []
	for section in range(1, controls.size()):
		var a: Vector3 = controls[section - 1]
		var b: Vector3 = controls[section]
		var steps := maxi(2, ceili(a.distance_to(b) / 1.8))
		for i in range(1, steps + 1):
			route.append(_ground(a.lerp(b, float(i) / steps)))
	return route

## Nothing solid (a fence, a wall) between two ground points, at knee and chest height.
func _open_line(a: Vector3, b: Vector3) -> bool:
	var space:= house.get_world_3d().direct_space_state
	var ex: Array = [world.player.get_rid()]
	for h in [0.4, 1.0]:
		var q:= PhysicsRayQueryParameters3D.create(Vector3(a.x, _ground(a).y + feet_y + h, a.z), Vector3(b.x, _ground(b).y + feet_y + h, b.z), 1, ex)
		if not space.intersect_ray(q).is_empty(): return false
	return true

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

## The player's body stays exactly where they stood while it happens (it is all in the view).
func _hold_still(p: Node) -> void:
	p.global_position = saved_position
	p.velocity = Vector3.ZERO

func _sting(db: float) -> void:
	var st:= AudioStreamPlayer.new()
	st.stream = STING
	st.volume_db = db
	add_child(st)
	st.finished.connect(st.queue_free)
	st.play()

func _aim_at_creature(cam: Camera3D, p: Node, rate: float) -> void:
	var aim:= (creature.global_position + Vector3.UP * 0.35 - cam.global_position).normalized()
	p.set_yaw_pitch(lerp_angle(p.rotation.y, atan2(-aim.x, -aim.z), rate), lerpf(p.head.rotation.x, asin(clampf(aim.y, -1, 1)), rate))

func _track_ground(cam: Camera3D, p: Node, k: float) -> void :
	var aim:= (creature.global_position + Vector3.UP * 0.25 - cam.global_position).normalized()
	p.set_yaw_pitch(lerp_angle(p.rotation.y, atan2( - aim.x, - aim.z), 0.12), lerpf(p.head.rotation.x, asin(clampf(aim.y, -1, 1)), 0.12))
	cam.rotation.z *= 1.0 - k

func _cleanup() -> void :
	grounded = false
	on_roof = false
	for b in _vis_bodies:
		if is_instance_valid(b): b.queue_free()
	_vis_bodies.clear()
	for light in test_lights:
		if is_instance_valid(light): light.visible = false
	if is_instance_valid(creature): creature.queue_free()
	if is_instance_valid(layer): layer.queue_free()
	if is_instance_valid(world) and is_instance_valid(world.player):
		var p = world.player
		p.camera.rotation.z = 0.0
		p.camera.position = Vector3.ZERO
		p.camera.fov = saved_fov
		p.set_yaw_pitch(saved_yaw, saved_pitch)
		p.global_position = saved_position
		p.controls_enabled = saved_controls
		p.look_enabled = saved_look

func _exit_tree() -> void :
	if running: _cleanup()
	for light in test_lights:
		if is_instance_valid(light): light.queue_free()
